extends CharacterBody3D
## First-person player controller.
## Explicit STAND / CROUCH / PRONE state machine with a distinct collision shape
## per stance (capsule, short capsule, flat box oriented with the body), a
## two-weapon inventory (assault rifle + sniper), hitscan shooting and health.

signal died(killer)

const Health = preload("res://scripts/game/health.gd")
const Weapons = preload("res://scripts/game/weapons.gd")
const Fx = preload("res://scripts/game/fx.gd")

enum Stance { STAND, CROUCH, PRONE }
const STANCE_NAMES := ["STANDING", "CROUCHED", "PRONE"]
const EYE_HEIGHT := [1.62, 1.08, 0.36]
const MOVE_SPEED := [5.6, 3.0, 1.1]
const SPRINT_SPEED := 8.6
const JUMP_VELOCITY := 5.4
const BASE_FOV := 78.0
const EQUIP_TIME := 0.45
const STEP_LENGTH := [2.3, 1.6, 1.1]
const STEP_NOISE := [11.0, 4.0, 1.5]
const STEP_VOLUME := [-11.0, -21.0, -27.0]
const SPREAD_STANCE := [1.0, 0.75, 0.55]
const RECOIL_STANCE := [1.0, 0.8, 0.6]
const PRONE_HEAD_Z := -0.45
const WORLD_MASK := 1
const BOT_MASK := 4
const REGEN_DELAY := 5.0
const REGEN_RATE := 14.0
const SLIDE_TAP_WINDOW := 0.3    # two C presses within this many seconds = slide
const SLIDE_MIN_SPEED := 4.0     # must be walking or sprinting on the first tap
const SLIDE_SPEED := 11.0
const SLIDE_TIME := 0.75

var match_ref: Node
var health: Node
var stance: int = Stance.STAND
var alive := false
var controls_enabled := true
var head: Node3D
var camera: Camera3D
var weapon_pivot: Node3D
var shape_node: CollisionShape3D
var shapes: Array = []
var shape_offsets: Array = []
var weapons: Array = []
var views: Array = []
var cur := 0
var equip_t := 0.0
var reloading := false
var reload_t := 0.0
var ads := 0.0
var aiming := false
var sprinting := false
var pitch := 0.0
var pending_yaw := 0.0
var game_time := 0.0
var last_damage_time := -100.0
var auto_reload_at := -1.0
var fire_block := false
var shots_fired := 0
var hits_landed := 0
var step_acc := 0.0
var bob_t := 0.0
var kick := 0.0
var kick_roll := 0.0
var force_aim := false   # capture/test hook: aim without a held mouse button
var sway := Vector2.ZERO
var flash_t := 0.0
var shake := 0.0
var _fire_was_down := false
var _gravity := 9.8
var slide_t := 0.0
var slide_dir := Vector3.ZERO
var _crouch_tap_t := -100.0
var _crouch_tap_speed := 0.0


func display_name() -> String:
	return "allied_warrior"   # Match.PLAYER_NAME


func _ready() -> void:
	add_to_group("player")
	add_to_group("combatants")
	collision_layer = 2
	collision_mask = WORLD_MASK | BOT_MASK
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50.0)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.died.connect(_on_died)

	var stand := CapsuleShape3D.new()
	stand.radius = 0.35
	stand.height = 1.8
	var crouch := CapsuleShape3D.new()
	crouch.radius = 0.35
	crouch.height = 1.2
	var prone := BoxShape3D.new()
	prone.size = Vector3(0.62, 0.42, 1.75)
	shapes = [stand, crouch, prone]
	shape_offsets = [Vector3(0, 0.9, 0), Vector3(0, 0.6, 0), Vector3(0, 0.22, 0.42)]
	shape_node = CollisionShape3D.new()
	shape_node.name = "Shape"
	add_child(shape_node)
	_apply_shape()

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, EYE_HEIGHT[0], 0)
	add_child(head)
	camera = Camera3D.new()
	camera.fov = BASE_FOV
	camera.near = 0.01
	camera.far = 700.0
	head.add_child(camera)
	camera.current = true
	weapon_pivot = Node3D.new()
	camera.add_child(weapon_pivot)
	for def in Weapons.DEFS:
		weapons.append({"def": def, "ammo": int(def.mag), "reserve": int(def.reserve), "next_fire": 0.0})
		var v: Node3D = Weapons.build_rig_viewmodel(def.id)
		v.visible = false
		weapon_pivot.add_child(v)
		views.append(v)
	views[0].visible = true


# ------------------------------------------------------------------ spawning

func spawn_at(pos: Vector3, yaw := 0.0) -> void:
	global_position = pos
	rotation = Vector3(0, yaw, 0)
	velocity = Vector3.ZERO
	health.reset()
	alive = true
	stance = Stance.STAND
	_apply_shape()
	pitch = 0.0
	pending_yaw = 0.0
	head.position = Vector3(0, EYE_HEIGHT[0], 0)
	head.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	for w in weapons:
		w.ammo = int(w.def.mag)
		w.reserve = int(w.def.reserve)
		w.next_fire = 0.0
	views[cur].visible = false
	cur = 0
	views[0].visible = true
	equip_t = 0.3
	reloading = false
	ads = 0.0
	sprinting = false
	slide_t = 0.0
	_crouch_tap_t = -100.0
	last_damage_time = -100.0
	auto_reload_at = -1.0
	fire_block = true
	weapon_pivot.visible = true


func on_kill() -> void:
	for w in weapons:
		w.reserve = mini(int(w.reserve) + int(w.def.kill_bonus), int(w.def.max_reserve))


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if not alive or not controls_enabled:
		return
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var s: float = 0.0022 * Settings.sensitivity() * (camera.fov / BASE_FOV)
			pending_yaw -= event.relative.x * s
			pitch = clampf(pitch - event.relative.y * s, _pitch_min(), deg_to_rad(88.0))
			sway += event.relative * 0.0015
	elif event is InputEventMouseButton:
		if event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("switch_weapon"):
		switch_weapon()
	elif event.is_action_pressed("reload"):
		start_reload()
	elif event.is_action_pressed("crouch"):
		if game_time - _crouch_tap_t < SLIDE_TAP_WINDOW and try_slide():
			_crouch_tap_t = -100.0
		else:
			_crouch_tap_t = game_time
			_crouch_tap_speed = Vector2(velocity.x, velocity.z).length()
			toggle_crouch()
	elif event.is_action_pressed("prone"):
		toggle_prone()


func _pitch_min() -> float:
	return deg_to_rad(-35.0) if stance == Stance.PRONE else deg_to_rad(-88.0)


# ------------------------------------------------------------------ stances

func _apply_shape() -> void:
	shape_node.shape = shapes[stance]
	shape_node.position = shape_offsets[stance]


func _shape_fits(st: int, xform: Transform3D) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shapes[st]
	q.transform = xform * Transform3D(Basis(), shape_offsets[st] + Vector3(0, 0.06, 0))
	q.collision_mask = WORLD_MASK | BOT_MASK
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func can_enter(st: int) -> bool:
	return _shape_fits(st, global_transform)


func set_stance(st: int) -> bool:
	if st == stance or not alive:
		return st == stance
	if not _shape_fits(st, global_transform):
		_toast("NO ROOM TO " + ["STAND", "CROUCH", "GO PRONE"][st])
		return false
	stance = st
	_apply_shape()
	if st != Stance.STAND:
		sprinting = false
	Sfx.play("switch", -16.0, 0.7)
	return true


func toggle_crouch() -> bool:
	return set_stance(Stance.STAND if stance == Stance.CROUCH else Stance.CROUCH)


## Double-tap C while moving: a short crouched slide that keeps the run's momentum.
func try_slide() -> bool:
	if not alive or not is_on_floor() or stance == Stance.PRONE or _crouch_tap_speed < SLIDE_MIN_SPEED:
		return false
	if stance != Stance.CROUCH and not set_stance(Stance.CROUCH):
		return false
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	slide_dir = hv.normalized() if hv.length() > 0.5 else -transform.basis.z
	slide_t = SLIDE_TIME
	sprinting = false
	Sfx.play("step1", -8.0, 0.6)
	if match_ref:
		match_ref.report_noise(global_position, 12.0, self)
	return true


func toggle_prone() -> bool:
	return set_stance(Stance.STAND if stance == Stance.PRONE else Stance.PRONE)


func _toast(text: String) -> void:
	if match_ref and match_ref.hud:
		match_ref.hud.toast(text)


# ------------------------------------------------------------------ physics

func _physics_process(delta: float) -> void:
	game_time += delta
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not alive:
		velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
		move_and_slide()
		return
	_apply_pending_yaw()

	var input := Vector2.ZERO
	if controls_enabled:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := transform.basis * Vector3(input.x, 0.0, input.y)
	dir.y = 0.0
	if dir.length() > 1.0:
		dir = dir.normalized()
	var fire_down := controls_enabled and Input.is_action_pressed("fire")
	sprinting = controls_enabled and stance == Stance.STAND and Input.is_action_pressed("sprint") \
		and input.y < -0.3 and ads < 0.3 and not fire_down and not reloading
	var speed: float = SPRINT_SPEED if sprinting else float(MOVE_SPEED[stance])
	if aiming:
		speed *= 0.65
	var accel := 14.0 if is_on_floor() else 3.0
	if slide_t > 0.0 and (stance != Stance.CROUCH or not is_on_floor()):
		slide_t = 0.0
	if slide_t > 0.0:
		slide_t -= delta
		var sp := lerpf(float(MOVE_SPEED[Stance.CROUCH]), SLIDE_SPEED, maxf(slide_t, 0.0) / SLIDE_TIME)
		velocity.x = slide_dir.x * sp
		velocity.z = slide_dir.z * sp
	else:
		velocity.x = lerpf(velocity.x, dir.x * speed, minf(1.0, accel * delta))
		velocity.z = lerpf(velocity.z, dir.z * speed, minf(1.0, accel * delta))
	if controls_enabled and Input.is_action_just_pressed("jump") and is_on_floor():
		if stance == Stance.STAND:
			velocity.y = JUMP_VELOCITY
		elif stance == Stance.CROUCH:
			slide_t = 0.0
			set_stance(Stance.STAND)
	move_and_slide()
	if slide_t > 0.0 and get_real_velocity().length() < 1.0:
		slide_t = 0.0   # ran into a wall
	_footsteps(delta)
	_update_weapons(delta, fire_down)
	if game_time - last_damage_time > REGEN_DELAY:
		health.heal(REGEN_RATE * delta)


func _apply_pending_yaw() -> void:
	if pending_yaw == 0.0:
		return
	if stance == Stance.PRONE:
		# The prone body is long; refuse to rotate it into walls.
		var t := global_transform
		t.basis = Basis(Vector3.UP, rotation.y + pending_yaw)
		if not _shape_fits(Stance.PRONE, t):
			pending_yaw = 0.0
			return
	rotation.y += pending_yaw
	pending_yaw = 0.0


func _footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var hs := Vector2(velocity.x, velocity.z).length()
	if hs < 0.5:
		return
	step_acc += hs * delta
	var step_len: float = 2.9 if sprinting else float(STEP_LENGTH[stance])
	if step_acc >= step_len:
		step_acc = 0.0
		var vol: float = float(STEP_VOLUME[stance]) + (4.0 if sprinting else 0.0)
		Sfx.play("step%d" % randi_range(0, 2), vol, randf_range(0.9, 1.1))
		if match_ref:
			match_ref.report_noise(global_position, 16.0 if sprinting else float(STEP_NOISE[stance]), self)


# ------------------------------------------------------------------ weapons

func current_def() -> Dictionary:
	return weapons[cur].def


func is_scoped() -> bool:
	return alive and current_def().id == "sniper" and ads > 0.9


func current_spread_deg() -> float:
	var def := current_def()
	var s: float = lerpf(float(def.hip_spread), float(def.ads_spread), ads)
	var hs := Vector2(velocity.x, velocity.z).length()
	if ads < 0.5:
		s *= 1.0 + hs / 4.0
	if not is_on_floor():
		s *= 2.5
	return s * float(SPREAD_STANCE[stance])


func _update_weapons(delta: float, fire_down: bool) -> void:
	if equip_t > 0.0:
		equip_t -= delta
	if reloading:
		reload_t -= delta
		if reload_t <= 0.0:
			_finish_reload()
	if auto_reload_at > 0.0 and game_time >= auto_reload_at:
		auto_reload_at = -1.0
		start_reload()
	aiming = controls_enabled and (Input.is_action_pressed("aim") or force_aim) and equip_t <= 0.0 and not reloading and not sprinting
	ads = move_toward(ads, 1.0 if aiming else 0.0, delta * 6.0)
	camera.fov = lerpf(BASE_FOV, float(current_def().ads_fov), ads)
	if not fire_down:
		fire_block = false
	if fire_down and not fire_block and (bool(current_def().auto) or not _fire_was_down):
		try_fire()
	_fire_was_down = fire_down


func try_fire() -> bool:
	if not alive:
		return false
	var w: Dictionary = weapons[cur]
	var def: Dictionary = w.def
	if equip_t > 0.0 or reloading or game_time < float(w.next_fire):
		return false
	if int(w.ammo) <= 0:
		Sfx.play("dry", -6.0)
		w.next_fire = game_time + 0.25
		if int(w.reserve) > 0:
			start_reload()
		return false
	sprinting = false
	w.ammo = int(w.ammo) - 1
	w.next_fire = game_time + float(def.rate)
	shots_fired += 1
	_shoot_ray(def)
	var rk: float = float(RECOIL_STANCE[stance]) * (0.6 if ads > 0.5 else 1.0)
	pitch = clampf(pitch + deg_to_rad(float(def.recoil)) * rk, _pitch_min(), deg_to_rad(88.0))
	pending_yaw += deg_to_rad(randf_range(-float(def.recoil_yaw), float(def.recoil_yaw))) * rk
	kick = 1.0
	kick_roll = randf_range(-0.08, 0.08)
	flash_t = 0.05
	shake += float(def.shake)
	Sfx.play(def.sound, -3.0, randf_range(0.96, 1.04))
	if views[cur].has_meta("rig"):
		_rig_play(views[cur], "shot", 0.02, 1.3, true)
	if def.id == "sniper":
		Weapons.start_bolt(views[cur])
		get_tree().create_timer(0.15, false).timeout.connect(func(): Sfx.play("bolt", -8.0))
	if match_ref:
		match_ref.report_noise(global_position, float(def.noise), self)
	if int(w.ammo) == 0 and int(w.reserve) > 0:
		auto_reload_at = game_time + 0.3
	return true


func _shoot_ray(def: Dictionary) -> void:
	var spread := deg_to_rad(current_spread_deg())
	var b := camera.global_transform.basis
	var r := tan(spread) * sqrt(randf())
	var a := randf() * TAU
	var dir := (-b.z + b.x * r * cos(a) + b.y * r * sin(a)).normalized()
	var from := camera.global_position
	var to := from + dir * float(def.range)
	var q := PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK | BOT_MASK, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	if not hit.is_empty():
		end = hit.position
		var col = hit.collider
		if col != null and col.has_method("take_hit"):
			var res: Dictionary = col.take_hit(float(def.damage), float(def.head_mult), self, end, from)
			if res.get("hit", false):
				hits_landed += 1
				Fx.blood(match_ref, end, hit.normal)
				var head_hit: bool = res.get("head", false)
				var killed: bool = res.get("killed", false)
				if killed:
					Sfx.play("kill", -2.0)
				elif head_hit:
					Sfx.play("headshot", -3.0)
				else:
					Sfx.play("hit", -5.0)
				if match_ref and match_ref.hud:
					match_ref.hud.hitmarker(head_hit, killed)
		else:
			Fx.impact(match_ref, end, hit.normal)
			Sfx.play_at("impact", end, -10.0, randf_range(0.8, 1.2), 30.0)
	var muzzle: Node3D = views[cur].get_node("Muzzle")
	var start := muzzle.global_position if not is_scoped() else from - b.y * 0.15
	Fx.tracer(match_ref, start, end)


func start_reload() -> bool:
	if reloading or equip_t > 0.0 or not alive:
		return false
	var w: Dictionary = weapons[cur]
	if int(w.ammo) >= int(w.def.mag) or int(w.reserve) <= 0:
		return false
	reloading = true
	reload_t = float(w.def.reload)
	var v: Node3D = views[cur]
	if v.has_meta("rig"):
		# Tactical reload uses the gameplay reload time; an empty magazine plays the
		# longer full reload (chambering) at the same speed, and gameplay waits for it.
		var anim: AnimationPlayer = v.get_meta("anim")
		var speed := anim.get_animation(Weapons.RIG_ANIMS.reload).length / float(w.def.reload)
		var key := "reload_empty" if int(w.ammo) == 0 else "reload"
		reload_t = anim.get_animation(Weapons.RIG_ANIMS[key]).length / speed
		_rig_play(v, key, 0.1, speed, true)
	Sfx.play("reload", -6.0, 1.0 if cur == 0 else 0.85)
	return true


func _finish_reload() -> void:
	reloading = false
	var w: Dictionary = weapons[cur]
	var take := mini(int(w.def.mag) - int(w.ammo), int(w.reserve))
	w.ammo = int(w.ammo) + take
	w.reserve = int(w.reserve) - take


func switch_weapon() -> bool:
	if not alive or equip_t > 0.0:
		return false
	# A reload in progress is cancelled; magazine contents are kept as they were.
	reloading = false
	auto_reload_at = -1.0
	views[cur].visible = false
	cur = 1 - cur
	views[cur].visible = true
	equip_t = EQUIP_TIME
	ads = 0.0
	if views[cur].has_meta("rig"):
		var anim: AnimationPlayer = views[cur].get_meta("anim")
		_rig_play(views[cur], "draw", 0.0, anim.get_animation(Weapons.RIG_ANIMS.draw).length / EQUIP_TIME, true)
	Sfx.play("switch", -6.0)
	return true


# ------------------------------------------------------------------ damage

func get_target_points() -> Array:
	var p := global_position
	match stance:
		Stance.STAND:
			return [p + Vector3(0, 1.55, 0), p + Vector3(0, 1.1, 0)]
		Stance.CROUCH:
			return [p + Vector3(0, 1.0, 0), p + Vector3(0, 0.65, 0)]
	return [global_transform * Vector3(0, 0.3, -0.4), global_transform * Vector3(0, 0.25, 0.4)]


func take_hit(amount: float, head_mult: float, source: Node, hit_pos: Vector3, from_pos: Vector3) -> Dictionary:
	if not alive:
		return {"hit": false}
	var head_hit := stance == Stance.STAND and hit_pos.y - global_position.y > 1.45
	var dmg := amount * (head_mult if head_hit else 1.0)
	last_damage_time = game_time
	if health.apply_damage(dmg, source, head_hit, from_pos):
		shake += 0.5
		Sfx.play("hurt", -7.0, randf_range(0.9, 1.1))
		if match_ref and match_ref.hud:
			match_ref.hud.damage_from(from_pos)
	return {"hit": true, "head": head_hit, "killed": health.dead}


func _on_died(source: Node) -> void:
	alive = false
	reloading = false
	aiming = false
	ads = 0.0
	sprinting = false
	weapon_pivot.visible = false
	Sfx.play("death", -2.0)
	died.emit(source)


# ------------------------------------------------------------------ presentation

func _process(delta: float) -> void:
	if not alive:
		head.position = head.position.lerp(Vector3(0, 0.3, 0), minf(1.0, delta * 4.0))
		camera.rotation.z = lerpf(camera.rotation.z, 0.5, minf(1.0, delta * 3.0))
		return
	var eye := Vector3(0, float(EYE_HEIGHT[stance]), PRONE_HEAD_Z if stance == Stance.PRONE else 0.0)
	head.position = head.position.lerp(eye, minf(1.0, delta * 10.0))
	head.rotation.x = pitch
	shake = move_toward(shake, 0.0, delta * 3.0)
	camera.rotation = Vector3(randf_range(-1, 1) * shake * 0.008, randf_range(-1, 1) * shake * 0.008,
		0.06 * clampf(slide_t / SLIDE_TIME * 3.0, 0.0, 1.0))
	kick = move_toward(kick, 0.0, delta * 8.0)
	sway = sway.lerp(Vector2.ZERO, minf(1.0, delta * 8.0))

	var def := current_def()
	var hs := Vector2(velocity.x, velocity.z).length()
	if is_on_floor():
		bob_t += delta * hs * 1.7
	var bob_amt := clampf(hs / 5.6, 0.0, 1.5) * (1.0 - ads * 0.85)
	var hip: Vector3 = def.hip_pos
	var v: Node3D = views[cur]
	if v.has_meta("rig"):
		_process_rig(v, delta, hs, bob_amt)
		return
	var adsp := Vector3(0.0, -float(v.get_meta("sight_y", 0.02)), float(def.ads_pos.z))
	var e_ads := ads * ads * (3.0 - 2.0 * ads)   # smoothstep for a softer aim transition
	var pos := hip.lerp(adsp, e_ads)
	pos += Vector3(sin(bob_t) * 0.006, -absf(cos(bob_t)) * 0.005, 0.0) * bob_amt
	pos += Vector3(-sway.x * 0.01, sway.y * 0.01, 0.0) * (1.0 - ads * 0.85)
	pos.z += kick * float(def.kick_back)
	pos.y += kick * float(def.kick_back) * 0.25
	var rot := Vector3(kick * float(def.kick_rot), -sway.x * 0.05, kick * kick_roll)
	if equip_t > 0.0:
		var e := equip_t / EQUIP_TIME
		pos.y -= e * 0.12
		rot.x -= e * 0.9
	if reloading:
		var p := 1.0 - reload_t / float(def.reload)
		var k := sin(p * PI)
		pos.y -= k * 0.03
		rot.x += k * 0.3
		rot.z += k * 0.55
	if sprinting:
		pos += Vector3(-0.02, -0.015, 0.01)
		rot += Vector3(-0.2, 0.6, 0.15)
	v.position = pos
	v.rotation = rot
	v.visible = not is_scoped()
	flash_t -= delta
	var flash: Node3D = v.get_node("Muzzle/Flash")
	flash.visible = flash_t > 0.0
	flash.rotation.z = randf() * TAU


# ------------------------------------------------------------------ animated arms rig

func _rig_play(v: Node3D, key: String, blend := 0.12, speed := 1.0, restart := false) -> void:
	var anim: AnimationPlayer = v.get_meta("anim")
	var clip: String = Weapons.RIG_ANIMS[key]
	if restart or anim.current_animation != clip:
		anim.speed_scale = 1.0
		anim.play(clip, blend, speed)
		if restart:
			anim.seek(0.0, true)


## Drives the rigged arms: one-shot clips (shot / reload / draw) play to the end,
## otherwise idle, walk or run loop. Hands stay on the rifle because every clip
## is authored on the same IK rig; the rig is re-anchored to the camera each frame.
func _process_rig(v: Node3D, delta: float, hs: float, bob_amt: float) -> void:
	var def := current_def()
	var anim: AnimationPlayer = v.get_meta("anim")
	var cur_anim := anim.current_animation
	var busy := (cur_anim == Weapons.RIG_ANIMS.shot or cur_anim == Weapons.RIG_ANIMS.reload
		or cur_anim == Weapons.RIG_ANIMS.reload_empty or cur_anim == Weapons.RIG_ANIMS.draw) and anim.is_playing()
	if not busy:
		if sprinting:
			_rig_play(v, "run", 0.2)
		elif hs > 0.8 and is_on_floor() and ads < 0.5:
			_rig_play(v, "walk", 0.2)
		else:
			_rig_play(v, "idle", 0.25)
		# calmer idle sway while aiming
		anim.speed_scale = lerpf(1.0, 0.25, ads) if cur_anim == Weapons.RIG_ANIMS.idle else 1.0
	v.set_meta("reloading", reloading)
	Weapons.update_rig(v)
	# aiming: move the rig so the iron sights line up with the screen centre
	var e_ads := ads * ads * (3.0 - 2.0 * ads)
	var ads_off: Vector3 = v.get_meta("ads_offset", Vector3.ZERO)
	var hip_off: Vector3 = v.get_meta("hip_offset", Vector3.ZERO)
	var hip_rot: Vector3 = v.get_meta("hip_rot", Vector3.ZERO)
	var pos := hip_off + ads_off * e_ads
	var rot := hip_rot * (1.0 - e_ads)
	pos += Vector3(sin(bob_t) * 0.003, -absf(cos(bob_t)) * 0.003, 0.0) * bob_amt
	pos += Vector3(-sway.x * 0.006, sway.y * 0.006, 0.0) * (1.0 - ads * 0.9)
	pos.z += kick * float(def.kick_back) * (0.5 if ads > 0.5 else 1.0)
	rot += Vector3(kick * float(def.kick_rot) * (0.4 if ads > 0.5 else 1.0), -sway.x * 0.03, kick * kick_roll * 0.5)
	v.position = pos
	v.rotation = rot
	v.visible = not is_scoped()
	flash_t -= delta
	var flash: Node3D = v.get_node("Muzzle/Flash")
	flash.visible = flash_t > 0.0
	flash.rotation.z = randf() * TAU
