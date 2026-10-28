extends Node
## Automated acceptance tests. They drive the real game code paths (menus,
## match loading, input actions, hitscan traces, AI) and record PASS / FAIL /
## NOT TESTED with evidence.
##
## Run:  Godot_v4.7.2-stable_win64_console.exe --headless --path . --fixed-fps 60 -- --run-tests

const MapRegistry = preload("res://scripts/maps/map_registry.gd")

var main: Node
var results: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _run() -> void:
	await _frames(10)
	await _test_menus()
	for id in MapRegistry.MAPS.size():
		await _test_map(id)
	await _test_pause_flow()
	await _test_timed_matches()
	await _test_aa_setting()
	_write_report()
	var failed := 0
	for r in results:
		if r[2] == "FAIL":
			failed += 1
	print("TESTS DONE: %d results, %d failed" % [results.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


# ------------------------------------------------------------------ helpers

func rec(cat: String, test_name: String, status: String, evidence: String) -> void:
	results.append([cat, test_name, status, evidence])
	print("[%s] %s | %s | %s" % [status, cat, test_name, evidence])


func check(cat: String, test_name: String, ok: bool, evidence: String) -> void:
	rec(cat, test_name, "PASS" if ok else "FAIL", evidence)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _secs(t: float) -> void:
	await _frames(int(t * 60.0))


func _tap(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await _frames(2)


func _fire_once() -> void:
	Input.action_press("fire")
	await _frames(1)
	Input.action_release("fire")
	await _frames(1)


func _hspeed(p) -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()


func _release_all() -> void:
	for a in ["fire", "aim", "move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(a)


func _freeze_bots(m, frozen: bool) -> void:
	for b in m.bots:
		b.ai_enabled = not frozen


func _spawn_ok(m, pos: Vector3) -> bool:
	var map_rid: RID = m.get_world_3d().navigation_map
	var cp := NavigationServer3D.map_get_closest_point(map_rid, pos)
	# The baked navmesh floats ~0.5 m above the walkable surface (voxel rounding).
	if Vector2(cp.x - pos.x, cp.z - pos.z).length() > 0.8 or absf(cp.y - pos.y) > 0.9:
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	q.shape = cap
	q.transform = Transform3D(Basis(), pos + Vector3(0, 0.98, 0))
	q.collision_mask = 1
	return m.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _aim(m, point: Vector3) -> void:
	var p = m.player
	p.shake = 0.0
	p.camera.rotation = Vector3.ZERO
	for i in 2:
		var d: Vector3 = point - p.camera.global_position
		p.rotation.y = atan2(-d.x, -d.z)
		p.pitch = atan2(d.y, Vector2(d.x, d.z).length())
		p.head.rotation.x = p.pitch


func _setup_duel(m, bot, dist: float) -> bool:
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var map_rid: RID = m.get_world_3d().navigation_map
	var candidates: Array = []
	for ps in m.map.player_spawns:
		candidates.append(ps[0])
	candidates.append_array(m.map.patrol_points)
	for c in candidates:
		var cpos: Vector3 = c
		if not _spawn_ok(m, cpos):
			continue
		for k in 16:
			var a := k * TAU / 16.0
			var bp := cpos + Vector3(cos(a), 0, sin(a)) * dist
			var cp := NavigationServer3D.map_get_closest_point(map_rid, bp)
			if Vector2(cp.x - bp.x, cp.z - bp.z).length() > 0.3 or absf(cp.y - cpos.y - 0.5) > 0.35:
				continue
			if not _spawn_ok(m, bp):
				continue
			var eye := cpos + Vector3(0, 1.62, 0)
			var clear := true
			for h in [1.1, 1.65]:
				var q := PhysicsRayQueryParameters3D.create(eye, bp + Vector3(0, h, 0), 1)
				if not space.intersect_ray(q).is_empty():
					clear = false
			if not clear:
				continue
			m.player.spawn_at(cpos, 0.0)
			if not bot.alive:
				bot.respawn(bp)
			bot.global_position = bp + Vector3(0, 0.05, 0)
			bot.velocity = Vector3.ZERO
			bot.rotation.y = atan2(-(cpos.x - bp.x), -(cpos.z - bp.z))
			bot.yaw_target = bot.rotation.y
			return true
	return false


func _open_spot(m) -> Array:
	# A spot with 8 m of clear, walkable space in some direction.
	var space: PhysicsDirectSpaceState3D = m.get_world_3d().direct_space_state
	var candidates: Array = []
	for ps in m.map.player_spawns:
		candidates.append(ps[0])
	candidates.append_array(m.map.patrol_points)
	for c in candidates:
		var cpos: Vector3 = c
		if not _spawn_ok(m, cpos):
			continue
		for k in 8:
			var a := k * TAU / 8.0
			var dir := Vector3(cos(a), 0, sin(a))
			var clear := true
			# 3 m of room to each side for the strafe checks
			for side_dir in [Vector3(-dir.z, 0, dir.x), Vector3(dir.z, 0, -dir.x)]:
				var sq := PhysicsRayQueryParameters3D.create(cpos + Vector3(0, 1.0, 0), cpos + Vector3(0, 1.0, 0) + side_dir * 3.0, 1)
				if not space.intersect_ray(sq).is_empty():
					clear = false
			for h in [0.3, 1.0, 1.7]:
				for s in [-0.5, 0.0, 0.5]:
					var side: Vector3 = Vector3(-dir.z, 0, dir.x) * float(s)
					var from: Vector3 = cpos + side + Vector3(0, float(h), 0)
					var q := PhysicsRayQueryParameters3D.create(from, from + dir * 8.0, 1)
					if not space.intersect_ray(q).is_empty():
						clear = false
			# floor must continue
			var fq := PhysicsRayQueryParameters3D.create(cpos + dir * 7.0 + Vector3(0, 1, 0), cpos + dir * 7.0 + Vector3(0, -1, 0), 1)
			if clear and not space.intersect_ray(fq).is_empty():
				return [cpos, atan2(-dir.x, -dir.z)]
	return []


func _wait_match(old) -> Node:
	for i in 1500:
		await get_tree().physics_frame
		var m = main.match_node
		if m != null and m != old and m.started:
			return m
	return null


# ------------------------------------------------------------------ menus

func _test_menus() -> void:
	var C := "MENUS"
	main.show_main_menu()
	await _frames(3)
	var mm = main.current_menu
	check(C, "Main menu shows START GAME / SETTINGS / EXIT GAME",
		mm != null and mm.start_btn.text == "START GAME" and mm.settings_btn.text == "SETTINGS" and mm.exit_btn.text == "EXIT GAME",
		"buttons: %s / %s / %s" % [mm.start_btn.text, mm.settings_btn.text, mm.exit_btn.text])
	mm.start_btn.pressed.emit()
	await _frames(3)
	var ms = main.current_menu
	check(C, "Start Game opens map selection", ms != null and ms.has_signal("map_chosen"), "current menu script: %s" % ms.get_script().resource_path)
	check(C, "Map selection lists exactly 3 maps", ms.cards.size() == 3, "%d map cards" % ms.cards.size())
	ms.back_btn.pressed.emit()
	await _frames(3)
	check(C, "Back returns to main menu", main.current_menu.has_signal("start_pressed"), "current menu script: %s" % main.current_menu.get_script().resource_path)
	main.current_menu.settings_btn.pressed.emit()
	await _frames(3)
	var sm = main.settings_menu
	check(C, "Settings opens from main menu", sm != null, "settings overlay present: %s" % (sm != null))
	if sm == null:
		return
	var old_sens: float = Settings.data.sensitivity
	sm.sens_slider.value = 1.75
	await _frames(2)
	var cfg := ConfigFile.new()
	cfg.load(Settings.PATH)
	var saved = cfg.get_value("settings", "sensitivity", -1)
	check(C, "Settings change applies and persists to disk",
		is_equal_approx(float(Settings.data.sensitivity), 1.75) and is_equal_approx(float(saved), 1.75),
		"sensitivity runtime=%.2f saved=%s (%s)" % [Settings.data.sensitivity, saved, ProjectSettings.globalize_path(Settings.PATH)])
	sm.quality_opt.select(2)
	sm.quality_opt.item_selected.emit(2)
	await _frames(2)
	var vp := get_tree().root
	check(C, "Graphics preset applies", int(Settings.data.quality) == 2 and vp.scaling_3d_mode == Viewport.SCALING_3D_MODE_FSR2 		and is_equal_approx(vp.scaling_3d_scale, 0.67),
		"quality=%d scaling_mode=%d scale=%.2f (High = FSR 2 at 67 %%)" % [Settings.data.quality, vp.scaling_3d_mode, vp.scaling_3d_scale])
	sm.sens_slider.value = old_sens
	sm.quality_opt.select(1)
	sm.quality_opt.item_selected.emit(1)
	sm.back_btn.pressed.emit()
	await _frames(3)
	check(C, "Settings BACK closes overlay", main.settings_menu == null, "overlay present: %s" % (main.settings_menu != null))
	rec(C, "Exit Game quits application", "NOT TESTED",
		"EXIT GAME is connected to SceneTree.quit(); not pressed here because it would end the test process")


# ------------------------------------------------------------------ maps

func _test_map(id: int) -> void:
	var map_name: String = MapRegistry.MAPS[id].name
	main.show_map_select()
	await _frames(2)
	var old = main.match_node
	main.current_menu.cards[id].pressed.emit()
	var m = await _wait_match(old)
	check("MAPS", "%s loads" % map_name, m != null and m.map != null and m.player != null, "match started: %s" % (m != null))
	if m == null:
		return
	var nav: int = m.map.nav_polygon_count()
	check("MAPS", "%s navigation mesh baked and synced" % map_name, nav > 50 and m.nav_ready, "%d navmesh polygons, map ready=%s" % [nav, m.nav_ready])

	var bad: Array = []
	for sp in m.map.bot_spawns:
		if not _spawn_ok(m, sp):
			bad.append(sp)
	for ps in m.map.player_spawns:
		if not _spawn_ok(m, ps[0]):
			bad.append(ps[0])
	check("MAPS", "%s spawn locations valid (on navmesh, no geometry overlap)" % map_name, bad.is_empty(),
		("invalid: %s" % str(bad)) if not bad.is_empty() else "%d bot + %d player spawns valid" % [m.map.bot_spawns.size(), m.map.player_spawns.size()])

	var map_rid: RID = m.get_world_3d().navigation_map
	var start := NavigationServer3D.map_get_closest_point(map_rid, m.map.bot_spawns[0])
	var unreachable: Array = []
	var targets: Array = m.map.patrol_points.duplicate()
	for ps in m.map.player_spawns:
		targets.append(ps[0])
	for t in targets:
		var tp: Vector3 = t
		var path := NavigationServer3D.map_get_path(map_rid, start, tp, true)
		if path.is_empty() or path[path.size() - 1].distance_to(tp) > 1.5:
			unreachable.append(tp)
	check("MAPS", "%s navigation connects all spawns/patrol points (no inaccessible bot positions)" % map_name, unreachable.is_empty(),
		("unreachable: %s" % str(unreachable)) if not unreachable.is_empty() else "%d targets reachable from %s" % [targets.size(), start])

	check("BOTS", "%s exactly 3 active bot slots" % map_name, m.active_bot_count() == 3 and get_tree().get_nodes_in_group("bots").size() == 3,
		"active=%d nodes=%d" % [m.active_bot_count(), get_tree().get_nodes_in_group("bots").size()])

	m.player.health.hp = 1.0e9   # keep the player alive while bots roam
	var p0: Array = []
	for b in m.bots:
		p0.append(b.global_position)
	await _secs(4.0)
	var moved := 0
	for i in m.bots.size():
		if m.bots[i].global_position.distance_to(p0[i]) > 1.5:
			moved += 1
	check("BOTS", "%s bots move and navigate" % map_name, moved >= 2, "%d/3 bots moved > 1.5 m in 4 s" % moved)

	await _combat_tests(m, map_name)
	await _ffa_tests(m, map_name)
	await _movement_tests(m, map_name)
	_release_all()
	await _secs(3.5)
	check("BOTS", "%s still exactly 3 bots after deaths/respawns (no duplicates)" % map_name,
		m.active_bot_count() == 3 and get_tree().get_nodes_in_group("bots").size() == 3,
		"active=%d nodes=%d bot deaths=%d" % [m.active_bot_count(), get_tree().get_nodes_in_group("bots").size(), m.bot_death_events])


func _combat_tests(m, map_name: String) -> void:
	var p = m.player
	_freeze_bots(m, true)
	var bot = m.bots[0]
	if not _setup_duel(m, bot, 10.0):
		rec("COMBAT", "%s duel setup" % map_name, "FAIL", "no clear 10 m firing position found")
		return
	await _frames(25)
	Input.action_press("aim")
	await _frames(30)
	_aim(m, bot.global_position + Vector3(0, 1.15, 0))
	var hp0: float = bot.health.hp
	var ammo0: int = p.weapons[0].ammo
	await _fire_once()
	check("WEAPONS", "%s assault rifle fires and damages bot" % map_name, bot.health.hp < hp0 and p.weapons[0].ammo == ammo0 - 1,
		"bot HP %.0f -> %.0f, AR ammo %d -> %d" % [hp0, bot.health.hp, ammo0, p.weapons[0].ammo])

	var deaths0: int = m.bot_death_events
	var kills0: int = m.kills
	var shots := 0
	while bot.alive and shots < 40:
		_aim(m, bot.global_position + Vector3(0, 1.15, 0))
		await _fire_once()
		await _frames(6)
		shots += 1
	check("COMBAT", "%s bot health reaches 0 and bot dies" % map_name, not bot.alive and m.bot_death_events == deaths0 + 1 and m.kills == kills0 + 1,
		"alive=%s after %d more shots, death events +%d, kills +%d" % [bot.alive, shots, m.bot_death_events - deaths0, m.kills - kills0])
	bot.take_hit(500.0, 1.0, p, bot.global_position + Vector3(0, 1, 0), Vector3.ZERO)
	bot.health.apply_damage(500.0, p)
	await _frames(3)
	check("COMBAT", "%s no repeated bot death events" % map_name, m.bot_death_events == deaths0 + 1 and m.kills == kills0 + 1,
		"death events +%d after extra damage on corpse" % (m.bot_death_events - deaths0))
	await _frames(2)
	check("HUD", "%s kill counter updates" % map_name, m.hud.score_label.text.contains("KILLS  %d" % m.kills), "label: '%s'" % m.hud.score_label.text)
	await _secs(2.75)
	var alive_early: bool = bot.alive
	await _secs(0.45)
	check("BOTS", "%s bot respawns after 3 seconds" % map_name, not alive_early and bot.alive and m.active_bot_count() == 3,
		"alive at ~2.9 s: %s, alive at ~3.3 s: %s, active=%d" % [alive_early, bot.alive, m.active_bot_count()])
	Input.action_release("aim")
	await _frames(10)

	# Q switching + ammo persistence
	var ar_ammo: int = p.weapons[0].ammo
	await _tap("switch_weapon")
	await _secs(0.5)
	var on_sniper: bool = p.cur == 1
	await _tap("switch_weapon")
	await _secs(0.5)
	check("WEAPONS", "%s Q switches to sniper and back" % map_name, on_sniper and p.cur == 0, "after 1st Q cur=%s, after 2nd Q cur=%d" % [on_sniper, p.cur])
	check("WEAPONS", "%s ammo persists across switches" % map_name, p.weapons[0].ammo == ar_ammo, "AR ammo %d -> %d" % [ar_ammo, p.weapons[0].ammo])

	# switching must not bypass the sniper's fire rate
	await _tap("switch_weapon")
	await _secs(0.5)
	p.pitch = 0.6
	var s0: int = p.shots_fired
	await _fire_once()
	var first_ok: bool = p.shots_fired == s0 + 1
	await _tap("switch_weapon")
	await _frames(28)
	await _tap("switch_weapon")
	await _frames(28)
	await _fire_once()
	var blocked: bool = p.shots_fired == s0 + 1
	await _secs(0.4)
	await _fire_once()
	check("WEAPONS", "%s switching cannot bypass fire rate" % map_name, first_ok and blocked and p.shots_fired == s0 + 2,
		"shot1=%s, shot ~1.1 s later blocked=%s, shot after 1.3 s fired=%s" % [first_ok, blocked, p.shots_fired == s0 + 2])

	# sniper: scope + headshot
	var bot2 = m.bots[1]
	if not (_setup_duel(m, bot2, 25.0) or _setup_duel(m, bot2, 15.0)):
		rec("WEAPONS", "%s sniper duel setup" % map_name, "FAIL", "no clear firing position")
	else:
		await _frames(25)
		await _tap("switch_weapon")
		await _secs(0.5)
		Input.action_press("aim")
		await _secs(0.5)
		await _frames(2)
		check("WEAPONS", "%s sniper scope works" % map_name, p.is_scoped() and p.camera.fov < 20.0 and m.hud.scope.visible,
			"scoped=%s fov=%.1f overlay=%s" % [p.is_scoped(), p.camera.fov, m.hud.scope.visible])
		_aim(m, bot2.global_position + Vector3(0, 1.65, 0))
		var hp2: float = bot2.health.hp
		var k0: int = m.kills
		await _fire_once()
		check("WEAPONS", "%s sniper fires and headshot kills" % map_name, not bot2.alive and m.kills == k0 + 1,
			"bot HP %.0f -> %.0f (95 dmg x2.5 head)" % [hp2, bot2.health.hp])
		Input.action_release("aim")
		await _frames(10)

	# reload
	p.spawn_at(p.global_position, p.rotation.y)
	await _frames(25)
	p.weapons[0].ammo = 3
	var res0: int = p.weapons[0].reserve
	await _tap("reload")
	var started: bool = p.reloading
	await _secs(2.1)
	check("WEAPONS", "%s reload refills magazine from reserve" % map_name, started and p.weapons[0].ammo == 30 and p.weapons[0].reserve == res0 - 27,
		"started=%s ammo=%d reserve %d -> %d" % [started, p.weapons[0].ammo, res0, p.weapons[0].reserve])
	await _frames(2)
	check("HUD", "%s HUD shows real health and ammo" % map_name,
		m.hud.hp_label.text == str(ceili(p.health.hp)) and m.hud.ammo_label.text == str(p.weapons[p.cur].ammo),
		"hp label '%s' (hp %.0f), ammo label '%s' (ammo %d)" % [m.hud.hp_label.text, p.health.hp, m.hud.ammo_label.text, p.weapons[p.cur].ammo])

	# bot -> player damage (other bots benched so the player is the only opponent)
	var b3 = m.bots[2]
	m.bots[0].bench()
	m.bots[1].bench()
	if not _setup_duel(m, b3, 12.0):
		rec("COMBAT", "%s bot attack setup" % map_name, "FAIL", "no clear position")
		return
	await _frames(5)
	b3.ai_enabled = true
	var dmg := [0]
	var cb := func(_a, _s, _h, _f): dmg[0] += 1
	p.health.damaged.connect(cb)
	var hp_start: float = p.health.hp
	var min_hp := hp_start
	for i in 720:
		await get_tree().physics_frame
		min_hp = minf(min_hp, p.health.hp)
		if dmg[0] >= 2:
			break
	p.health.damaged.disconnect(cb)
	check("BOTS", "%s bot detects player" % map_name, b3.state == 2, "bot state=%s awareness=%.2f" % [["PATROL", "INVESTIGATE", "COMBAT", "DEAD"][b3.state], b3.awareness])
	check("BOTS", "%s bot aims and fires" % map_name, b3.shots_fired > 0, "%d shots fired" % b3.shots_fired)
	check("COMBAT", "%s bot bullets reduce player health" % map_name, dmg[0] > 0 and min_hp < hp_start,
		"player HP %.0f -> %.0f, %d hits / %d shots" % [hp_start, min_hp, b3.hits_on_player, b3.shots_fired])
	await _frames(2)
	check("HUD", "%s damage indicator shown" % map_name, m.hud.damage_ind.hits.size() > 0 or dmg[0] == 0, "%d active indicators" % m.hud.damage_ind.hits.size())
	_freeze_bots(m, true)

	# player death + single death event + respawn
	var d0: int = m.deaths
	p.health.apply_damage(1000.0, b3)
	p.health.apply_damage(1000.0, b3)
	p.take_hit(50.0, 1.0, b3, p.global_position, p.global_position)
	await _frames(3)
	check("COMBAT", "%s player death counted exactly once" % map_name, m.deaths == d0 + 1 and not p.alive,
		"deaths %d -> %d, alive=%s" % [d0, m.deaths, p.alive])
	check("HUD", "%s death counter updates" % map_name, m.hud.score_label.text.contains("DEATHS  %d" % m.deaths), "label: '%s'" % m.hud.score_label.text)
	await _secs(3.3)
	check("COMBAT", "%s player respawns with 100 HP" % map_name, p.alive and is_equal_approx(p.health.hp, 100.0),
		"alive=%s hp=%.0f" % [p.alive, p.health.hp])
	for bb in [m.bots[0], m.bots[1]]:
		if not bb.alive:
			bb.respawn(m._bot_spawn_pos(bb))
	_freeze_bots(m, true)


## Encloses the player in a sealed box so no bot can see them.
func _hide_player(m) -> StaticBody3D:
	var p = m.player
	var cage := StaticBody3D.new()
	var c: Vector3 = p.global_position
	for spec in [[Vector3(0, 3.0, 0), Vector3(3.4, 0.2, 3.4)], [Vector3(1.6, 1.5, 0), Vector3(0.2, 3.2, 3.4)],
			[Vector3(-1.6, 1.5, 0), Vector3(0.2, 3.2, 3.4)], [Vector3(0, 1.5, 1.6), Vector3(3.4, 3.2, 0.2)],
			[Vector3(0, 1.5, -1.6), Vector3(3.4, 3.2, 0.2)]]:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = spec[1]
		cs.shape = bs
		cs.position = spec[0]
		cage.add_child(cs)
	m.add_child(cage)
	cage.global_position = c
	return cage


func _ffa_tests(m, map_name: String) -> void:
	var p = m.player
	_freeze_bots(m, true)
	var a = m.bots[0]
	var b = m.bots[1]
	var c3 = m.bots[2]
	for bot in [a, b]:
		if not bot.alive:
			bot.respawn(m.map.bot_spawns[0])
	c3.bench()   # duel is strictly A vs B
	# no self-damage
	var hp_a: float = a.health.hp
	var self_res: Dictionary = a.take_hit(30.0, 1.0, a, a.global_position + Vector3(0, 1, 0), a.global_position)
	check("FFA", "%s bots cannot damage themselves" % map_name, not self_res.get("hit", true) and is_equal_approx(a.health.hp, hp_a),
		"self hit result=%s hp %.0f -> %.0f" % [self_res.get("hit"), hp_a, a.health.hp])

	# bot-vs-bot duel with the player sealed away
	if not _setup_duel(m, a, 12.0):
		rec("FFA", "%s bot duel setup" % map_name, "FAIL", "no clear position")
		return
	var a_pos: Vector3 = p.global_position
	# park the player at the spawn farthest from the duel spot (B takes the duel spot)
	var far_spawn: Vector3 = m.map.player_spawns[0][0]
	for ps in m.map.player_spawns:
		if (ps[0] as Vector3).distance_to(a_pos) > far_spawn.distance_to(a_pos):
			far_spawn = ps[0]
	p.spawn_at(far_spawn, 0.0)
	p.health.hp = 1.0e9
	await _frames(3)
	var cage := _hide_player(m)
	b.global_position = a_pos + Vector3(0, 0.05, 0)
	b.velocity = Vector3.ZERO
	b.rotation.y = atan2(-(a.global_position.x - a_pos.x), -(a.global_position.z - a_pos.z))
	b.yaw_target = b.rotation.y
	b.health.reset()
	a.health.reset()
	var a_k0: int = a.kills
	var b_k0: int = b.kills
	var player_k0: int = m.kills
	var a_d0: int = a.deaths
	var b_d0: int = b.deaths
	var deaths0: int = m.bot_death_events
	var bot_dmg := [0]
	var player_dmg := [0]
	var cb_a := func(_amt, src, _h, _f): bot_dmg[0] += (1 if src == b else 0)
	var cb_b := func(_amt, src, _h, _f): bot_dmg[0] += (1 if src == a else 0)
	var hit_log: Array = []
	var cb_p := func(_amt, src, _h, f):
		player_dmg[0] += 1
		if hit_log.size() < 3:
			hit_log.append("%s from %s at player %s" % [src.name if src else "?", f.snapped(Vector3.ONE * 0.1), p.global_position.snapped(Vector3.ONE * 0.1)])
	a.health.damaged.connect(cb_a)
	b.health.damaged.connect(cb_b)
	p.health.damaged.connect(cb_p)
	await _frames(5)
	a.ai_enabled = true
	b.ai_enabled = true
	var acquired_at := -1.0
	var t := 0.0
	while t < 60.0 and m.bot_death_events == deaths0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if acquired_at < 0.0 and (a.target == b or b.target == a):
			acquired_at = t
	a.health.damaged.disconnect(cb_a)
	b.health.damaged.disconnect(cb_b)
	check("FFA", "%s bots acquire each other as targets" % map_name, acquired_at >= 0.0,
		"first acquisition after %.2f s (A target=%s, B target=%s)" % [acquired_at, a.target.display_name() if a.target else "none", b.target.display_name() if b.target else "none"])
	check("FFA", "%s bots fire at and damage each other" % map_name, a.shots_fired + b.shots_fired > 0 and bot_dmg[0] > 0,
		"shots A=%d B=%d, bot-on-bot damage events=%d" % [a.shots_fired, b.shots_fired, bot_dmg[0]])
	var someone_died: bool = m.bot_death_events == deaths0 + 1
	var killer = a if b.deaths > b_d0 else b
	var victim = b if killer == a else a
	var killer_k0: int = a_k0 if killer == a else b_k0
	check("FFA", "%s bot-vs-bot kill credited to the real attacker" % map_name,
		someone_died and killer.kills == killer_k0 + 1 and (a.deaths - a_d0) + (b.deaths - b_d0) == 1 and m.kills == player_k0,
		"after %.1f s: %s killed %s (killer kills %d -> %d, victim deaths +1, player kills unchanged %d)" % [t, killer.bot_name, victim.bot_name, killer_k0, killer.kills, m.kills])
	await _frames(20)
	check("FFA", "%s killer drops the dead target" % map_name, killer.target != victim,
		"killer target now: %s" % (killer.target.display_name() if killer.target else "none"))
	await _secs(3.2)
	check("FFA", "%s bot killed by a bot respawns after 3 s, still 3 slots" % map_name,
		victim.alive and get_tree().get_nodes_in_group("bots").size() == 3,
		"victim alive=%s active=%d nodes=%d" % [victim.alive, m.active_bot_count(), get_tree().get_nodes_in_group("bots").size()])

	# free observation: all three bots active, player sealed out of sight
	c3.respawn(m._bot_spawn_pos(c3))
	_freeze_bots(m, false)
	var kills0 := 0
	for bot in m.bots:
		kills0 += bot.kills
	var deaths_before: int = m.bot_death_events
	var bad_self := 0
	var bad_dead := 0
	var switches := 0
	var last_targets: Array = []
	var dead_since := {}
	for bot in m.bots:
		last_targets.append(bot.target)
	var dur := 60.0
	var steps := int(dur * 60.0)
	for i in steps:
		await get_tree().physics_frame
		for j in m.bots.size():
			var bot = m.bots[j]
			if bot.target == bot:
				bad_self += 1
			if bot.target != null and not bot.target.alive:
				dead_since[j] = int(dead_since.get(j, 0)) + 1
				if int(dead_since[j]) > 12:   # > 0.2 s still aiming at a corpse
					bad_dead += 1
			else:
				dead_since[j] = 0
			if bot.target != last_targets[j] and bot.target != null and last_targets[j] != null:
				switches += 1
			last_targets[j] = bot.target
	p.health.damaged.disconnect(cb_p)
	var kills_after := 0
	for bot in m.bots:
		kills_after += bot.kills
	check("FFA", "%s observed match: bots fight each other with the player hidden" % map_name,
		kills_after > kills0 and player_dmg[0] == 0,
		"%.0f s: %d bot-vs-bot kills, %d bot deaths, player hit %d times %s, scoreboard %s" % [dur, kills_after - kills0, m.bot_death_events - deaths_before, player_dmg[0], hit_log, _board(m)])
	check("FFA", "%s no self-targeting and no lingering dead targets" % map_name, bad_self == 0 and bad_dead == 0,
		"self-target frames=%d, frames aiming at a corpse >0.2 s=%d" % [bad_self, bad_dead])
	check("FFA", "%s target selection is stable" % map_name, switches <= int(dur) * m.bots.size() / 4,
		"%d live-to-live target switches across 3 bots in %.0f s" % [switches, dur])
	cage.queue_free()
	_freeze_bots(m, true)
	await _frames(3)


func _board(m) -> String:
	var parts: Array = []
	for r in m.scoreboard():
		parts.append("%s %d/%d" % [r.name, r.kills, r.deaths])
	return ", ".join(parts)


func _movement_tests(m, map_name: String) -> void:
	var p = m.player
	_freeze_bots(m, true)
	var spot := _open_spot(m)
	if spot.is_empty():
		rec("MOVEMENT", "%s open area" % map_name, "FAIL", "no open spot found")
		return
	p.spawn_at(spot[0], spot[1])
	p.health.hp = 1.0e9
	await _frames(25)
	var fwd: Vector3 = -p.global_transform.basis.z
	var right: Vector3 = p.global_transform.basis.x
	var o: Vector3 = p.global_position
	Input.action_press("move_forward")
	await _secs(0.6)
	Input.action_release("move_forward")
	await _frames(12)
	var d_fwd: Vector3 = p.global_position - o
	o = p.global_position
	Input.action_press("move_back")
	await _secs(0.4)
	Input.action_release("move_back")
	await _frames(12)
	var d_back: Vector3 = p.global_position - o
	o = p.global_position
	Input.action_press("move_right")
	await _secs(0.4)
	Input.action_release("move_right")
	await _frames(12)
	var d_right: Vector3 = p.global_position - o
	o = p.global_position
	Input.action_press("move_left")
	await _secs(0.4)
	Input.action_release("move_left")
	await _frames(12)
	var d_left: Vector3 = p.global_position - o
	check("MOVEMENT", "%s WASD movement" % map_name,
		d_fwd.dot(fwd) > 2.0 and d_back.dot(fwd) < -1.0 and d_right.dot(right) > 1.0 and d_left.dot(right) < -1.0,
		"W %.2f m, S %.2f m, D %.2f m, A %.2f m (along facing axes)" % [d_fwd.dot(fwd), d_back.dot(fwd), d_right.dot(right), d_left.dot(right)])

	p.spawn_at(spot[0], spot[1])
	p.health.hp = 1.0e9
	await _frames(25)
	Input.action_press("move_forward")
	await _secs(0.4)
	var walk_speed := _hspeed(p)
	Input.action_press("sprint")
	await _secs(0.4)
	var sprint_speed := _hspeed(p)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(20)
	check("MOVEMENT", "%s sprint is faster than walking" % map_name, sprint_speed > walk_speed + 2.0,
		"walk %.2f m/s, sprint %.2f m/s" % [walk_speed, sprint_speed])

	p.spawn_at(spot[0], spot[1])
	p.health.hp = 1.0e9
	await _frames(25)
	var y0: float = p.global_position.y
	var max_y := y0
	var e := InputEventAction.new()
	e.action = "jump"
	e.pressed = true
	Input.parse_input_event(e)
	for i in 30:
		await get_tree().physics_frame
		max_y = maxf(max_y, p.global_position.y)
	Input.action_release("jump")
	await _frames(40)
	check("MOVEMENT", "%s jump" % map_name, max_y > y0 + 0.6, "peak height %.2f m" % (max_y - y0))

	# crouch
	await _tap("crouch")
	await _frames(25)
	var cap = p.shape_node.shape
	check("MOVEMENT", "%s C crouches (1.2 m capsule, lowered camera)" % map_name,
		p.stance == 1 and cap is CapsuleShape3D and is_equal_approx(cap.height, 1.2) and p.head.position.y < 1.2,
		"stance=%d shape=%s height=%.2f eye=%.2f" % [p.stance, cap.get_class(), cap.height if cap is CapsuleShape3D else -1.0, p.head.position.y])
	Input.action_press("move_forward")
	await _secs(0.4)
	var crouch_speed := _hspeed(p)
	Input.action_release("move_forward")
	await _frames(15)
	var s0: int = p.shots_fired
	await _fire_once()
	check("MOVEMENT", "%s crouched: slower movement and shooting works" % map_name, crouch_speed < 3.3 and crouch_speed > 1.5 and p.shots_fired == s0 + 1,
		"crouch speed %.2f m/s, shot fired=%s" % [crouch_speed, p.shots_fired == s0 + 1])
	await _tap("crouch")
	await _frames(15)
	check("MOVEMENT", "%s C again stands up" % map_name, p.stance == 0 and is_equal_approx(p.shape_node.shape.height, 1.8),
		"stance=%d" % p.stance)

	# slide: double-tap C while sprinting
	p.spawn_at(spot[0], spot[1])
	p.health.hp = 1.0e9
	await _frames(25)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _secs(0.5)
	var run_speed := _hspeed(p)
	await _tap("crouch")
	await _tap("crouch")
	var sliding: bool = p.slide_t > 0.0
	var slide_peak := 0.0
	for i in 6:
		await get_tree().physics_frame
		slide_peak = maxf(slide_peak, _hspeed(p))
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _secs(1.0)
	check("MOVEMENT", "%s double-tap C slides (faster than a run, ends crouched)" % map_name,
		sliding and slide_peak > run_speed and p.slide_t <= 0.0 and p.stance == 1,
		"run %.2f m/s, slide peak %.2f m/s, started=%s, stance after=%d" % [run_speed, slide_peak, sliding, p.stance])
	p.spawn_at(spot[0], spot[1])
	p.health.hp = 1.0e9
	await _frames(25)
	await _tap("crouch")
	await _tap("crouch")
	var still_slide: float = p.slide_t
	var still_stance: int = p.stance
	await _frames(10)
	check("MOVEMENT", "%s double-tap C standing still just toggles crouch (no slide)" % map_name,
		still_slide <= 0.0 and still_stance == 0 and _hspeed(p) < 0.5,
		"stance=%d slide_t=%.2f speed=%.2f" % [still_stance, still_slide, _hspeed(p)])

	# prone
	p.spawn_at(spot[0], spot[1])
	p.health.hp = 1.0e9
	await _frames(25)
	await _tap("prone")
	await _frames(30)
	check("MOVEMENT", "%s Z goes prone (box collision, camera near floor)" % map_name,
		p.stance == 2 and p.shape_node.shape is BoxShape3D and p.head.position.y < 0.6,
		"stance=%d shape=%s eye=%.2f" % [p.stance, p.shape_node.shape.get_class(), p.head.position.y])
	o = p.global_position
	Input.action_press("move_forward")
	await _secs(1.0)
	Input.action_release("move_forward")
	await _frames(10)
	var crawl: float = (p.global_position - o).length()
	check("MOVEMENT", "%s prone crawling works (slow)" % map_name, crawl > 0.5 and crawl < 1.6, "crawled %.2f m in 1 s" % crawl)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _secs(0.4)
	var prone_sprint := _hspeed(p)
	Input.action_release("sprint")
	Input.action_release("move_forward")
	var yp: float = p.global_position.y
	await _tap("jump")
	await _frames(15)
	check("MOVEMENT", "%s cannot sprint or jump while prone" % map_name, prone_sprint < 1.3 and p.global_position.y < yp + 0.1 and p.stance == 2,
		"speed with sprint held %.2f m/s, height change %.2f" % [prone_sprint, p.global_position.y - yp])
	s0 = p.shots_fired
	await _fire_once()
	var fired: bool = p.shots_fired == s0 + 1
	await _tap("switch_weapon")
	await _secs(0.5)
	var switched: bool = p.cur == 1
	p.weapons[1].ammo = 2
	await _tap("reload")
	var reloading: bool = p.reloading
	await _secs(3.0)
	var reloaded: bool = p.weapons[1].ammo == 5
	Input.action_press("aim")
	await _secs(0.5)
	var scoped: bool = p.is_scoped()
	Input.action_release("aim")
	await _frames(10)
	check("MOVEMENT", "%s prone: shoot, switch, reload and scope all work" % map_name, fired and switched and reloading and reloaded and scoped,
		"fire=%s switch=%s reload=%s/%s scope=%s" % [fired, switched, reloading, reloaded, scoped])

	# clearance checks under a low ceiling
	var ceiling := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4, 0.2, 4)
	cs.shape = bs
	ceiling.add_child(cs)
	m.add_child(ceiling)
	ceiling.global_position = p.global_position + Vector3(0, 0.95, 0.4)
	await _frames(3)
	await _tap("prone")
	await _frames(5)
	var stayed1: bool = p.stance == 2
	await _tap("crouch")
	await _frames(5)
	var stayed2: bool = p.stance == 2
	ceiling.queue_free()
	await _frames(3)
	await _tap("prone")
	await _frames(10)
	check("MOVEMENT", "%s stand-up clearance check (blocked under 0.85 m ceiling, allowed after)" % map_name,
		stayed1 and stayed2 and p.stance == 0,
		"stayed prone on Z=%s, on C=%s, stance after ceiling removed=%d" % [stayed1, stayed2, p.stance])
	p.health.hp = 100.0


# ------------------------------------------------------------------ pause flow

func _test_pause_flow() -> void:
	var C := "MENUS"
	var m = main.match_node
	if m == null:
		rec(C, "Pause flow", "FAIL", "no match running")
		return
	m.set_paused(true)
	await _frames(3)
	var t0: float = m.player.game_time
	await _frames(10)
	check(C, "Pause opens pause menu and freezes gameplay", get_tree().paused and m.pause_menu.visible and is_equal_approx(m.player.game_time, t0),
		"paused=%s menu visible=%s player time advanced=%s" % [get_tree().paused, m.pause_menu.visible, not is_equal_approx(m.player.game_time, t0)])
	m.pause_menu.settings_btn.pressed.emit()
	await _frames(3)
	var opened: bool = m.settings_menu != null
	if opened:
		m.settings_menu.back_btn.pressed.emit()
	await _frames(3)
	check(C, "Settings from pause menu opens and closes", opened and m.settings_menu == null and get_tree().paused,
		"opened=%s closed=%s still paused=%s" % [opened, m.settings_menu == null, get_tree().paused])
	m.pause_menu.resume_btn.pressed.emit()
	await _frames(3)
	check(C, "Resume unpauses", not get_tree().paused and not m.pause_menu.visible, "paused=%s" % get_tree().paused)
	await _tap("pause")
	var p1: bool = get_tree().paused
	await _tap("pause")
	var p2: bool = get_tree().paused
	check(C, "ESC toggles pause", p1 and not p2, "after 1st ESC paused=%s, after 2nd ESC paused=%s" % [p1, p2])
	m.set_paused(true)
	await _frames(2)
	m.pause_menu.restart_btn.pressed.emit()
	var m2 = await _wait_match(m)
	check(C, "Restart Match reloads the map", m2 != null and m2.kills == 0 and m2.active_bot_count() == 3 and not get_tree().paused,
		"new match=%s kills=%s bots=%s" % [m2 != null, m2.kills if m2 else -1, m2.active_bot_count() if m2 else -1])
	if m2 == null:
		return
	m2.set_paused(true)
	await _frames(2)
	m2.pause_menu.menu_btn.pressed.emit()
	await _frames(6)
	check(C, "Main Menu returns to title screen", main.match_node == null and main.current_menu != null and main.current_menu.has_signal("start_pressed") and not get_tree().paused,
		"match freed=%s menu=%s paused=%s" % [main.match_node == null, main.current_menu.get_script().resource_path if main.current_menu else "none", get_tree().paused])


# ------------------------------------------------------------------ timed matches

func _kill(victim, source) -> void:
	victim.health.apply_damage(99999.0, source, false, victim.global_position + Vector3(0, 1, 2))
	await _frames(2)


func _feed_text(m) -> String:
	var out := ""
	for l in m.hud.feed.get_children():
		out += String(l.text) + " | "
	return out


func _valid_names(m) -> Array:
	var names: Array = m.bots.map(func(b): return String(b.bot_name))
	var unique := {}
	for n in names:
		unique[n] = true
	var ok: bool = names.size() == 3 and unique.size() == 3 and not names.has(m.PLAYER_NAME) \
		and names.all(func(n): return m.BOT_NAME_POOL.has(n))
	return [ok, names]


func _test_timed_matches() -> void:
	var C := "MATCH"
	var Match = load("res://scripts/game/match.gd")
	# formatting and ranking (pure functions)
	check(C, "Normal match length is 600 s and reads 10:00", Match.MATCH_SECONDS == 600.0 and Match.format_time(600.0) == "10:00"
		and Match.format_time(0.0) == "00:00" and Match.format_time(59.4) == "01:00" and Match.format_time(0.3) == "00:01",
		"600=%s 0=%s 59.4=%s 0.3=%s" % [Match.format_time(600.0), Match.format_time(0.0), Match.format_time(59.4), Match.format_time(0.3)])
	var ranked: Array = Match.rank_rows([{"name": "A", "kills": 5, "deaths": 2}, {"name": "D", "kills": 1, "deaths": 0},
		{"name": "C", "kills": 5, "deaths": 3}, {"name": "B", "kills": 5, "deaths": 2, "player": true}])
	var ranks: Array = ranked.map(func(r): return "%s#%d" % [r.name, r.rank])
	check(C, "Ranking: kills, then fewest deaths; full ties share a rank", ranks == ["A#1", "B#1", "C#3", "D#4"], ", ".join(PackedStringArray(ranks)))
	var all_tied: Array = Match.rank_rows([{"name": "A", "kills": 0, "deaths": 0}, {"name": "B", "kills": 0, "deaths": 0}])
	check(C, "Ranking: everyone tied are joint first", all_tied.all(func(r): return r.rank == 1), str(all_tied.map(func(r): return r.rank)))
	var many_ok := true
	for i in 200:
		var n: Array = Match.pick_bot_names(3)
		var u := {}
		for x in n:
			u[x] = true
		if u.size() != 3 or n.has(Match.PLAYER_NAME):
			many_ok = false
	check(C, "Bot name draw: 3 unique names, never allied_warrior (200 draws)", many_ok, "pool=%d names" % Match.BOT_NAME_POOL.size())

	# a normal (600 s) match: clock, names, feed, pause
	main.test_match_duration = 0.0
	main.start_match(1)
	var m = await _wait_match(null)
	if m == null:
		rec(C, "Timed match starts", "FAIL", "match did not start")
		return
	await _frames(2)
	check(C, "Countdown starts at 10:00 when gameplay begins", m.match_duration == 600.0 and m.time_left > 599.0 and m.time_left <= 600.0
		and m.hud.timer_label.text in ["10:00", "09:59"], "time_left=%.2f label=%s" % [m.time_left, m.hud.timer_label.text])
	var nv: Array = _valid_names(m)
	var rows: Array = m.scoreboard()
	var player_rows: Array = rows.filter(func(r): return r.player)
	check(C, "Player is allied_warrior; bots have 3 unique pool names", m.player.display_name() == "allied_warrior"
		and player_rows.size() == 1 and player_rows[0].name == "allied_warrior" and nv[0], "bots=%s" % [nv[1]])
	var b0 = m.bots[0]
	var b0_name: String = b0.bot_name
	await _kill(b0, m.player)
	await _kill(m.player, m.bots[1])
	var feed := _feed_text(m)
	check(C, "Kill feed uses allied_warrior for kills and deaths", feed.contains("allied_warrior  ✖  %s" % b0_name)
		and feed.contains("%s  ✖  allied_warrior" % m.bots[1].bot_name), feed)
	await _secs(3.6)
	check(C, "Bot keeps its name through death and respawn", b0.alive and b0.bot_name == b0_name, "alive=%s name=%s" % [b0.alive, b0.bot_name])
	m.set_paused(true)
	var t_paused: float = m.time_left
	await _secs(1.5)
	var held: bool = is_equal_approx(m.time_left, t_paused)
	m.set_paused(false)
	await _secs(1.0)
	check(C, "Countdown pauses with the pause menu and resumes", held and m.time_left < t_paused - 0.8 and m.time_left > t_paused - 1.2,
		"paused at %.2f, held=%s, after 1 s running %.2f" % [t_paused, held, m.time_left])

	# full flow on every map with a test-only short duration (4 s)
	for id in MapRegistry.MAPS.size():
		var mname: String = MapRegistry.MAPS[id].name
		main.test_match_duration = 4.0
		var old = main.match_node
		main.start_match(id)
		m = await _wait_match(old)
		if m == null:
			rec(C, "%s timed match flow" % mname, "FAIL", "match did not start")
			continue
		check(C, "%s: fresh match (scores 0, clock reset, new names)" % mname, m.kills == 0 and m.deaths == 0
			and m.bots.all(func(b): return b.kills == 0 and b.deaths == 0) and m.time_left <= 4.0 and m.time_left > 3.5
			and not m.ended and _valid_names(m)[0], "time_left=%.2f names=%s" % [m.time_left, _valid_names(m)[1]])
		await _kill(m.bots[0], m.player)
		var waited := 0
		while not m.ended and waited < 600:
			await _frames(1)
			waited += 1
		var st: Array = m.final_standings
		var names: Array = st.map(func(r): return r.name)
		check(C, "%s: timer expiry ends the match once and freezes the world" % mname, m.ended and m.end_count == 1 and get_tree().paused
			and m.time_left == 0.0 and m.hud.timer_label.text == "00:00" and m.mouse_released,
			"ended=%s count=%d paused=%s clock=%s after %d frames" % [m.ended, m.end_count, get_tree().paused, m.hud.timer_label.text, waited])
		var res = m.results
		var player_kills: int = st.filter(func(r): return r.player)[0].kills if names.has("allied_warrior") else -1
		check(C, "%s: results screen lists all 4 with rank/name/kills/deaths" % mname, res != null and res.visible and res.row_labels.size() == 4
			and names.has("allied_warrior") and st[0].rank == 1 and player_kills == 1 and res.winner_text != "",
			"rows=%s winner=%s" % [st.map(func(r): return "#%d %s %d/%d" % [r.rank, r.name, r.kills, r.deaths]), res.winner_text if res else ""])
		var snap := str(st)
		var k0: int = m.kills
		m._on_bot_killed(m.bots[1], m.player)
		m._on_player_died(m.bots[2])
		m.end_match()
		m.bots[2].bench()
		m._respawn_bot(m.bots[2])
		await _secs(3.5)
		check(C, "%s: no scoring, respawn or second end after the match ends" % mname, m.kills == k0 and str(m.final_standings) == snap
			and m.end_count == 1 and not m.bots[2].alive and get_tree().paused, "kills %d->%d end_count=%d" % [k0, m.kills, m.end_count])
		if id < MapRegistry.MAPS.size() - 1:
			var prev_names: Array = _valid_names(m)[1]
			res.play_btn.pressed.emit()
			var m2 = await _wait_match(m)
			check(C, "%s: Play Again restarts with fresh scores, timer and names" % mname, m2 != null and not get_tree().paused
				and m2.kills == 0 and m2.deaths == 0 and m2.time_left > 3.5 and not m2.ended and _valid_names(m2)[0],
				"names before=%s after=%s" % [prev_names, _valid_names(m2)[1] if m2 else []])
		else:
			check(C, "Quit button is wired to quit the game", res.quit_btn.pressed.get_connections().size() > 0 and res.quit_pressed.get_connections().size() > 0,
				"connections=%d (not pressed: it would end the test run)" % res.quit_pressed.get_connections().size())
			res.menu_btn.pressed.emit()
			await _frames(6)
			check(C, "Main Menu from results returns cleanly to the title screen", main.match_node == null and main.current_menu != null
				and main.current_menu.has_signal("start_pressed") and not get_tree().paused, "match freed=%s paused=%s" % [main.match_node == null, get_tree().paused])
	main.test_match_duration = 0.0


func _test_aa_setting() -> void:
	var C := "MENUS"
	var vp := get_tree().root
	var q0: int = int(Settings.data.quality)
	var t0: bool = bool(Settings.data.get("taa", true))
	Settings.set_value("quality", 1)
	Settings.set_value("taa", true)
	var on_ok: bool = vp.use_taa and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_DISABLED
	Settings.set_value("taa", false)
	var off_ok: bool = not vp.use_taa and vp.screen_space_aa == Viewport.SCREEN_SPACE_AA_FXAA
	Settings.set_value("taa", t0)
	Settings.set_value("quality", q0)
	check(C, "Temporal AA setting: Medium uses TAA, switching it off falls back to FXAA", on_ok and off_ok,
		"taa on -> use_taa+no FXAA: %s, taa off -> FXAA: %s" % [on_ok, off_ok])

# ------------------------------------------------------------------ report

func _write_report() -> void:
	var lines: Array = ["# CombatArena automated test run", "",
		"Generated: %s  |  Godot %s  |  headless, fixed 60 fps" % [Time.get_datetime_string_from_system(), Engine.get_version_info().string], "",
		"| Category | Test | Result | Evidence |", "|---|---|---|---|"]
	for r in results:
		lines.append("| %s | %s | **%s** | %s |" % [r[0], r[1], r[2], str(r[3]).replace("|", "/")])
	var pass_n := 0
	var fail_n := 0
	for r in results:
		if r[2] == "PASS":
			pass_n += 1
		elif r[2] == "FAIL":
			fail_n += 1
	lines.append("")
	lines.append("Totals: %d PASS, %d FAIL, %d NOT TESTED" % [pass_n, fail_n, results.size() - pass_n - fail_n])
	# From the editor binary the report goes into the project; from the exported exe into user://.
	var path := ProjectSettings.globalize_path("res://TEST_RESULTS_AUTOMATED.md") if OS.has_feature("editor") \
		else "user://TEST_RESULTS_EXPORTED.md"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lines) + "\n")
		f.close()
