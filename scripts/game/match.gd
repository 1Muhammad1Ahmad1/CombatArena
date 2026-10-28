extends Node3D
## One match on one map: builds the arena, spawns the player and three pooled
## bots, tracks kills/deaths, handles respawns, noise and pausing. A match lasts
## MATCH_SECONDS of active play (the countdown stops while paused); when it
## reaches zero the match ends once, the world freezes and the ranked results
## are shown from a frozen snapshot.

signal restart_requested
signal main_menu_requested
signal match_ended(standings)

const Player = preload("res://scripts/game/player.gd")
const Bot = preload("res://scripts/game/bot.gd")
const Hud = preload("res://scripts/ui/hud.gd")
const PauseMenu = preload("res://scripts/ui/pause_menu.gd")
const ResultsScreen = preload("res://scripts/ui/results_screen.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const MapRegistry = preload("res://scripts/maps/map_registry.gd")
const Fx = preload("res://scripts/game/fx.gd")

const BOT_COUNT := 3
const RESPAWN_TIME := 3.0
const BOT_ROSTER := [
	{"name": "VIPER", "character": "Soldier"},
	{"name": "RAVEN", "character": "Enemy"},
	{"name": "HAZARD", "character": "Hazmat"},
]
const MATCH_SECONDS := 600.0
const PLAYER_NAME := "allied_warrior"
## Call-signs the bots draw from (three unique per match).
const BOT_NAME_POOL := ["VIPER", "RAVEN", "HAZARD", "GHOST", "BLAZE", "NOMAD", "FALCON", "REAPER", "SABLE", "TITAN",
	"ONYX", "VORTEX", "KESTREL", "BANSHEE", "WARDEN", "HUNTER", "ECHO", "COBALT", "MAVERICK", "RAPTOR",
	"SPECTRE", "JACKAL", "STRYKER", "TALON", "BISHOP", "GRIZZLY", "PHANTOM", "OUTLAW", "DRIFTER", "VANDAL"]

var map_id := 0
var map: Node3D
var player: CharacterBody3D
var bots: Array = []
var hud: CanvasLayer
var pause_layer: CanvasLayer
var pause_menu: Control
var settings_menu: Control
var bot_count := BOT_COUNT
var kills := 0
var deaths := 0
var started := false
var nav_ready := false
var bot_death_events := 0
var player_death_events := 0
var match_duration := MATCH_SECONDS   # tests may shorten it before start()
var time_left := MATCH_SECONDS
var ended := false
var end_count := 0                    # how many times the end ran (must stay 1)
var final_standings: Array = []       # frozen at the end; never changes afterwards
var results: Control
var mouse_released := false


func start() -> void:
	Sfx.world = self
	var info: Dictionary = MapRegistry.MAPS[map_id]
	map = load(info.script).new()
	map.name = "Map"
	add_child(map)
	map.build()
	# Bots must not query the navigation map before its first synchronisation.
	var nav_map := get_world_3d().navigation_map
	map.bake_navigation()
	# The map syncs on a worker thread, so wait on wall-clock time (max 30 s), not frames.
	# The answer must come from THIS map's region: after a restart the previous
	# match's navmesh can linger in the navigation map until the next sync.
	var region_rid: RID = map.nav_region.get_rid()
	var probes: Array = [map.bot_spawns[0], map.bot_spawns[map.bot_spawns.size() - 1]]
	var deadline := Time.get_ticks_msec() + 30000
	nav_ready = false
	while Time.get_ticks_msec() < deadline and not nav_ready:
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(nav_map) == 0:
			continue
		nav_ready = true
		for pr in probes:
			var probe: Vector3 = pr
			var cp := NavigationServer3D.map_get_closest_point(nav_map, probe)
			if NavigationServer3D.map_get_closest_point_owner(nav_map, probe) != region_rid \
					or Vector2(cp.x - probe.x, cp.z - probe.z).length() > 1.0:
				nav_ready = false
	if not nav_ready:
		push_error("Navigation map did not become ready for %s" % info.name)
	await get_tree().physics_frame

	player = Player.new()
	player.name = "Player"
	player.match_ref = self
	add_child(player)
	player.died.connect(_on_player_died)
	_respawn_player()

	time_left = match_duration
	var names := pick_bot_names(BOT_COUNT)
	for i in BOT_COUNT:
		var b = Bot.new()
		b.name = "Bot%d" % (i + 1)
		b.bot_name = names[i]
		b.character = BOT_ROSTER[i].character
		b.match_ref = self
		add_child(b)
		b.killed.connect(_on_bot_killed)
		bots.append(b)
		b.respawn(_bot_spawn_pos(b))

	hud = Hud.new()
	hud.match_ref = self
	add_child(hud)
	pause_layer = CanvasLayer.new()
	pause_layer.layer = 20
	pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_layer)
	pause_menu = PauseMenu.new()
	pause_layer.add_child(pause_menu)
	pause_menu.resume_pressed.connect(func(): set_paused(false))
	pause_menu.restart_pressed.connect(func(): restart_requested.emit())
	pause_menu.settings_pressed.connect(open_settings)
	pause_menu.main_menu_pressed.connect(func(): main_menu_requested.emit())

	await _warm_up_effects()
	Sfx.ambient(map.ambient_sound)
	_capture_mouse(true)
	started = true


## Renders every combat effect once in front of the camera while the loading
## screen is still up, so their shaders compile before the first firefight.
func _warm_up_effects() -> void:
	var cam: Camera3D = player.camera
	var p := cam.global_position - cam.global_transform.basis.z * 2.0
	var n := cam.global_transform.basis.z   # facing back toward the camera
	Fx.impact(self, p, n)
	Fx.blood(self, p + Vector3(0.3, 0, 0), n)
	Fx.tracer(self, p + Vector3(-1, 0, 0), p + Vector3(1, 0, 0))
	var flash := Fx.muzzle_flash(1.0)
	add_child(flash)
	flash.global_position = p
	for b in bots:
		b.flash.visible = true
	for v in player.views:
		v.get_node("Muzzle/Flash").visible = true
	for i in 3:
		await get_tree().process_frame
	flash.queue_free()
	for b in bots:
		b.flash.visible = false
	for v in player.views:
		v.get_node("Muzzle/Flash").visible = false


## Three (or `count`) unique random call-signs; never the player's name.
static func pick_bot_names(count: int) -> Array:
	var pool: Array = BOT_NAME_POOL.filter(func(n): return n != PLAYER_NAME)
	pool.shuffle()
	return pool.slice(0, count)


## "MM:SS", rounding up so the clock reads 10:00 at the start and 00:00 only at the end.
static func format_time(seconds: float) -> String:
	var s := maxi(0, ceili(seconds - 0.0001))
	return "%02d:%02d" % [s / 60, s % 60]


## Ranks rows by most kills, then fewest deaths. Equal kills and deaths share a
## rank (standard competition ranking: 1, 1, 3). Returns new dictionaries.
static func rank_rows(rows: Array) -> Array:
	var out: Array = []
	for r in rows:
		out.append({"name": r.name, "kills": int(r.kills), "deaths": int(r.deaths), "player": bool(r.get("player", false))})
	out.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	for i in out.size():
		if i > 0 and out[i].kills == out[i - 1].kills and out[i].deaths == out[i - 1].deaths:
			out[i]["rank"] = out[i - 1].rank
		else:
			out[i]["rank"] = i + 1
	return out


## Counts down only while the match is running; this node is pausable, so the
## pause menu (tree paused) stops the clock.
func _process(delta: float) -> void:
	if not started or ended:
		return
	time_left = maxf(0.0, time_left - delta)
	if time_left <= 0.0:
		end_match()


## Ends the match exactly once: freezes the world (combat, damage, respawn timers),
## snapshots the ranked results, releases the mouse and shows the results screen.
func end_match() -> void:
	if ended:
		return
	ended = true
	end_count += 1
	time_left = 0.0
	final_standings = rank_rows(scoreboard())
	if hud:
		hud.timer_label.text = format_time(0.0)   # the HUD stops updating once the world freezes
	if settings_menu:
		_close_settings()
	if pause_menu:
		pause_menu.visible = false
	get_tree().paused = true
	_capture_mouse(false)
	mouse_released = true
	results = ResultsScreen.new()
	results.setup(final_standings.duplicate(true))
	pause_layer.add_child(results)
	results.play_again_pressed.connect(func(): restart_requested.emit())
	results.main_menu_pressed.connect(func(): main_menu_requested.emit())
	results.quit_pressed.connect(func(): get_tree().quit())
	match_ended.emit(final_standings)


func _exit_tree() -> void:
	if get_tree():
		get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if started and not ended and not get_tree().paused and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		set_paused(true)


func set_paused(p: bool) -> void:
	if ended:
		return   # the results screen owns the frozen state
	get_tree().paused = p
	pause_menu.visible = p
	if p:
		_capture_mouse(false)
		pause_menu.focus_first()
	else:
		_close_settings()
		_capture_mouse(true)
		if player:
			player.fire_block = true


func open_settings() -> void:
	if settings_menu:
		return
	settings_menu = SettingsMenu.new()
	pause_layer.add_child(settings_menu)
	pause_menu.blocked = true
	settings_menu.closed.connect(_close_settings)


func _close_settings() -> void:
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null
	if pause_menu:
		pause_menu.blocked = false
		if pause_menu.visible:
			pause_menu.focus_first()


func _capture_mouse(on: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ queries

## Everyone who can fight: the player and every bot slot.
func combatants() -> Array:
	var out: Array = []
	if player:
		out.append(player)
	out.append_array(bots)
	return out


## Scoreboard rows sorted by kills (then fewest deaths).
func scoreboard() -> Array:
	var rows: Array = [{"name": PLAYER_NAME, "kills": kills, "deaths": deaths, "player": true, "alive": player != null and player.alive}]
	for b in bots:
		rows.append({"name": b.bot_name, "kills": b.kills, "deaths": b.deaths, "player": false, "alive": b.alive})
	rows.sort_custom(func(a, b): return a.kills > b.kills or (a.kills == b.kills and a.deaths < b.deaths))
	return rows


func active_bot_count() -> int:
	var n := 0
	for b in bots:
		if b.alive:
			n += 1
	return n


func report_noise(pos: Vector3, radius: float, source: Node) -> void:
	for b in bots:
		if b != source:
			b.hear(pos, radius)


func _visible_from(eye: Vector3, pos: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(eye, pos + Vector3(0, 1.5, 0), 1)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


# ------------------------------------------------------------------ spawning

## Scores a spawn point by its distance to the nearest living opponent and
## whether any opponent could see it. `who` is the combatant being spawned.
func _spawn_score(p: Vector3, who: Node) -> float:
	var score := randf() * 8.0
	var nearest := 60.0
	for c in combatants():
		if c == who or not c.alive:
			continue
		var d := p.distance_to(c.global_position)
		nearest = minf(nearest, d)
		if d < 4.0:
			score -= 200.0
		if _visible_from(c.global_position + Vector3(0, 1.6, 0), p):
			score -= 50.0
	score += nearest
	if nearest < 12.0:
		score -= 80.0
	return score


func _bot_spawn_pos(who: Node = null) -> Vector3:
	var best := Vector3.ZERO
	var best_score := -INF
	for sp in map.bot_spawns:
		var p: Vector3 = sp
		var score := _spawn_score(p, who)
		if score > best_score:
			best_score = score
			best = p
	return best


func _player_spawn() -> Vector3:
	var best := Vector3.ZERO
	var best_score := -INF
	for sp in map.player_spawns:
		var p: Vector3 = sp[0]
		var score := _spawn_score(p, player)
		if score > best_score:
			best_score = score
			best = p
	return best


func _respawn_player() -> void:
	if not is_inside_tree() or ended:
		return
	var pos := _player_spawn()
	var to_center := -Vector3(pos.x, 0, pos.z)
	player.spawn_at(pos + Vector3(0, 0.05, 0), atan2(-to_center.x, -to_center.z))
	if hud:
		hud.hide_death()


## Credits a kill to the actual attacker (player or bot). Returns its name.
func _credit_kill(source: Node, victim: Node) -> String:
	if ended:
		return "?"
	if source == null or not is_instance_valid(source) or source == victim:
		return "?"
	if source == player:
		kills += 1
		player.on_kill()
	elif source.is_in_group("bots"):
		source.kills += 1
	return source.display_name()


func _on_bot_killed(bot: Node, source: Node) -> void:
	if ended:
		return   # results are frozen
	bot_death_events += 1
	bot.deaths += 1
	var who := _credit_kill(source, bot)
	if hud:
		hud.feed_add("%s  ✖  %s" % [who, bot.bot_name], source == player)
	get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn_bot.bind(bot))


func _respawn_bot(bot: Node) -> void:
	if ended or not is_inside_tree() or not is_instance_valid(bot) or bot.alive:
		return
	bot.respawn(_bot_spawn_pos(bot))


func _on_player_died(killer: Node) -> void:
	if ended:
		return
	deaths += 1
	player_death_events += 1
	var who := _credit_kill(killer, player)
	if hud:
		hud.feed_add("%s  ✖  %s" % [who, PLAYER_NAME], false)
		hud.show_death(RESPAWN_TIME)
	get_tree().create_timer(RESPAWN_TIME, false).timeout.connect(_respawn_player)
