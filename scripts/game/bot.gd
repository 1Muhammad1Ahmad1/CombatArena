extends CharacterBody3D
## Free-for-all bot. Every other living combatant (the player and the other
## bots) is an opponent.
## AI: state machine (PATROL / INVESTIGATE / COMBAT / DEAD) with shared
## combatant targeting: vision cone + line-of-sight raycasts against walls,
## stance-aware awareness, hearing, recent-attacker memory and sticky target
## choice. Navigation via NavigationAgent3D, tactical strafing, burst fire with
## real hitscan traces that can hit the player or other bots, magazine +
## reload, hit reactions, death animation and pooled respawn (node reused).
## Visuals: Mixamo soldier (Adobe, royalty-free) driven by Mixamo rifle clips.
## Walk_Shoot / Run_Shoot are composited at load: legs from the locomotion
## clip, spine and arms from Firing Rifle. The AK-74M from the viewmodel pack
## is placed between the hands every frame, so it follows any clip.

signal killed(bot, source)

const Health = preload("res://scripts/game/health.gd")
const Fx = preload("res://scripts/game/fx.gd")
const BotHands = preload("res://scripts/game/bot_hands.gd")

enum S { PATROL, INVESTIGATE, COMBAT, DEAD }
const STATE_NAMES := ["PATROL", "INVESTIGATE", "COMBAT", "DEAD"]
const CHARACTERS := {
	"Soldier": "res://assets/mixamo/swat.fbx",
	"Enemy": "res://assets/mixamo/gas_mask.fbx",
	"Hazmat": "res://assets/mixamo/swat_guy.fbx",
}
const CLIP_DIR := "res://assets/mixamo/"
const CLIPS := {"Idle": "idle", "Walk": "walk", "Run": "run", "Idle_Shoot": "fire", "HitReact": "hit", "Death": "death"}
const LOOPED := ["Idle", "Idle_Shoot", "Run", "Run_Shoot", "Walk", "Walk_Shoot"]
const CLIP_HIPS := 1.011051   # hips rest height of the skeleton the clips were exported on
const RIFLE_SCENE := "res://assets/fps_ak74m/scene.gltf"
const RIFLE_MESHES := ["Object_97", "Object_99"]   # AK body, magazine (arms mesh left out)
const RIFLE_SCALE := 0.68     # mesh is 1.39 units long; AK-74M is 0.94 m
const RIFLE_GRIP := Vector3(0.0, -0.02, 0.27)    # mesh units: pistol grip, held by the right hand
const RIFLE_MUZZLE := Vector3(0.0, 0.035, -0.45)
const RIFLE_HANDGUARD := Vector3(0.0, -0.035, -0.06)   # mesh units: where the left wrist sits
static var _libs := {}
static var _rifle_meshes: Array = []
const MAG := 25
const RELOAD_TIME := 2.2
const HEAD_HEIGHT := 1.49   # fallback; the live neck bone height is used when available
const EYE_HEIGHT := 1.6
const PATROL_SPEED := 2.4
const COMBAT_SPEED := 3.4
const CHASE_SPEED := 4.6
const TARGET_MIN_HOLD := 1.5      # seconds before a visible target may be swapped
const ATTACKER_MEMORY := 4.0
const DIFF := [
	{"spread": 4.0, "damage": 6.0, "reaction": 0.9, "burst_pause": 1.4, "aim_lag": 4.5},
	{"spread": 2.7, "damage": 8.0, "reaction": 0.55, "burst_pause": 1.0, "aim_lag": 7.0},
	{"spread": 1.8, "damage": 10.0, "reaction": 0.35, "burst_pause": 0.7, "aim_lag": 10.0},
]

var match_ref: Node
var bot_name := "BOT"
var character := "Soldier"
var health: Node
var agent: NavigationAgent3D
var shape_node: CollisionShape3D
var model: Node3D
var anim: AnimationPlayer
var skel: Skeleton3D
var rifle: Node3D
var hand_r := -1
var hand_l := -1
var neck := -1
var ik_error := 0.0   # left hand to handguard after IK (diagnostics)
var muzzle: Node3D
var flash: Node3D
var name_label: Label3D
var meshes: Array = []
var hurt_overlay: StandardMaterial3D

var stance := 0                   # bots always stand (shared combatant interface)
var kills := 0
var deaths := 0
var state: int = S.PATROL
var alive := false
var ai_enabled := true
var awareness := 0.0
var target: Node = null
var target_since := -100.0
var sees_target := false
var suspect: Node = null
var last_attacker: Node = null
var last_attacked_time := -100.0
var last_seen_pos := Vector3.ZERO
var last_seen_time := -100.0
var time := 0.0
var think_t := 0.0
var wait_t := 0.0
var aim_point := Vector3.ZERO
var ammo := MAG
var reload_t := 0.0
var burst_left := 0
var next_shot := 0.0
var strafe_t := 0.0
var hurt_t := 0.0
var flash_t := 0.0
var death_t := 0.0
var yaw_target := 0.0
var stuck_t := 0.0
var shots_fired := 0
var hits_landed := 0
var hits_on_player := 0
var _gravity := 9.8


func _ready() -> void:
	add_to_group("bots")
	add_to_group("combatants")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50.0)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	shape_node = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.85
	shape_node.shape = cap
	shape_node.position.y = 0.925
	add_child(shape_node)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.7
	agent.target_desired_distance = 1.0
	agent.radius = 0.45
	agent.height = 1.8
	agent.path_max_distance = 3.0
	add_child(agent)
	health = Health.new()
	health.name = "Health"
	add_child(health)
	health.died.connect(_on_died)
	health.damaged.connect(_on_damaged)
	hurt_overlay = StandardMaterial3D.new()
	hurt_overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hurt_overlay.albedo_color = Color(1.0, 0.2, 0.15, 0.45)
	hurt_overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_build_model()
	visible = false
	set_physics_process(false)


func display_name() -> String:
	return bot_name


func _diff() -> Dictionary:
	return DIFF[Settings.difficulty()]


# ------------------------------------------------------------------ model

func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var inst: Node3D = load(CHARACTERS.get(character, CHARACTERS["Soldier"])).instantiate()
	inst.rotation.y = PI   # Mixamo characters face +Z, Godot forward is -Z
	model.add_child(inst)
	skel = inst.get_node("Skeleton3D")
	hand_r = skel.find_bone("mixamorig_RightHand")
	hand_l = skel.find_bone("mixamorig_LeftHand")
	neck = skel.find_bone("mixamorig_Neck")
	anim = inst.get_node("AnimationPlayer")
	for l in anim.get_animation_library_list():
		anim.remove_animation_library(l)
	anim.add_animation_library("", _anim_lib(character, skel))
	_collect_meshes(inst)
	rifle = _build_rifle()
	model.add_child(rifle)
	var hands := BotHands.new()
	hands.bot = self
	skel.add_child(hands)
	muzzle = Marker3D.new()
	rifle.add_child(muzzle)
	muzzle.position = (RIFLE_MUZZLE - RIFLE_GRIP) * RIFLE_SCALE
	flash = Fx.muzzle_flash(1.6)
	flash.visible = false
	muzzle.add_child(flash)
	name_label = Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.pixel_size = 0.003
	name_label.font_size = 40
	name_label.outline_size = 10
	name_label.modulate = Color(1.0, 0.35, 0.28)
	name_label.position = Vector3(0, 2.15, 0)
	name_label.visibility_range_end = 45.0
	add_child(name_label)


## One library per character: hip height is rescaled to that skeleton so the
## feet stay on the floor, and the two fire-while-moving clips are composited.
static func _anim_lib(ch: String, sk: Skeleton3D) -> AnimationLibrary:
	if _libs.has(ch):
		return _libs[ch]
	var hips_scale := sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin.y / CLIP_HIPS
	var clips := {}
	for key in CLIPS:
		var src: Node = load(CLIP_DIR + CLIPS[key] + ".fbx").instantiate()
		var a: Animation = src.get_node("AnimationPlayer").get_animation("mixamo_com").duplicate(true)
		src.free()
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				for k in a.track_get_key_count(t):
					a.track_set_key_value(t, k, a.track_get_key_value(t, k) * hips_scale)
		clips[key] = a
	# The fire clip stands bladed: turn it so the rifle (right hand -> left hand) points straight ahead.
	var fire: Animation = clips["Idle_Shoot"]
	var aim := _hand_vector(fire, sk, fire.length * 0.5)
	var c := Quaternion(Vector3.UP, -atan2(aim.x, aim.z))
	for t in fire.get_track_count():
		if fire.track_get_path(t).get_concatenated_subnames() != "mixamorig_Hips":
			continue
		for k in fire.track_get_key_count(t):
			fire.track_set_key_value(t, k, c * fire.track_get_key_value(t, k))
	clips["Walk_Shoot"] = _upper_body(clips["Walk"], fire, sk)
	clips["Run_Shoot"] = _upper_body(clips["Run"], fire, sk)
	var lib := AnimationLibrary.new()
	for key in clips:
		var a: Animation = clips[key]
		a.loop_mode = Animation.LOOP_LINEAR if key in LOOPED else Animation.LOOP_NONE
		lib.add_animation(key, a)
	_libs[ch] = lib
	return lib


## Legs and hips from `base`, spine and everything above it from `upper`
## (tiled a whole number of times over the base clip so the loop is seamless).
## The spine also takes over the upper clip's hip rotation, so the torso and
## rifle face the same way as in the standing fire clip.
static func _upper_body(base: Animation, upper: Animation, sk: Skeleton3D) -> Animation:
	var spine := sk.find_bone("mixamorig_Spine")
	var bones := {}
	for b in sk.get_bone_count():
		var p := b
		while p != -1 and p != spine:
			p = sk.get_bone_parent(p)
		if p == spine:
			bones[sk.get_bone_name(b)] = true
	var out: Animation = base.duplicate(true)
	for t in range(out.get_track_count() - 1, -1, -1):
		if bones.has(out.track_get_path(t).get_concatenated_subnames()):
			out.remove_track(t)
	var hips_u := upper.find_track(NodePath("Skeleton3D:mixamorig_Hips"), Animation.TYPE_ROTATION_3D)
	var hips_b := base.find_track(NodePath("Skeleton3D:mixamorig_Hips"), Animation.TYPE_ROTATION_3D)
	var hb_inv: Quaternion = base.rotation_track_interpolate(hips_b, 0.0).inverse()
	var reps := maxi(1, roundi(base.length / upper.length))
	var period := base.length / reps
	var stretch := period / upper.length
	for t in upper.get_track_count():
		if upper.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		var bone := upper.track_get_path(t).get_concatenated_subnames()
		if not bones.has(bone):
			continue
		var nt := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(nt, upper.track_get_path(t))
		for r in reps:
			for k in upper.track_get_key_count(t):
				var ut := upper.track_get_key_time(t, k)
				var q: Quaternion = upper.track_get_key_value(t, k)
				if bone == "mixamorig_Spine":
					q = hb_inv * upper.rotation_track_interpolate(hips_u, ut) * q
				out.rotation_track_insert_key(nt, r * period + ut * stretch, q)
	return out


## Skeleton-space vector from the right hand to the left hand at time `t`
## (forward kinematics over the clip's rotation tracks).
static func _hand_vector(a: Animation, sk: Skeleton3D, t: float) -> Vector3:
	var glob := {}
	for b in sk.get_bone_count():
		var rest := sk.get_bone_rest(b)
		var xf := Transform3D(rest.basis, rest.origin)
		var path := NodePath("Skeleton3D:" + sk.get_bone_name(b))
		var rt := a.find_track(path, Animation.TYPE_ROTATION_3D)
		if rt != -1:
			xf.basis = Basis(a.rotation_track_interpolate(rt, t))
		var pt := a.find_track(path, Animation.TYPE_POSITION_3D)
		if pt != -1:
			xf.origin = a.position_track_interpolate(pt, t)
		var p := sk.get_bone_parent(b)
		glob[b] = glob[p] * xf if p != -1 else xf
	return glob[sk.find_bone("mixamorig_LeftHand")].origin - glob[sk.find_bone("mixamorig_RightHand")].origin


static func _rifle_parts() -> Array:
	if _rifle_meshes.is_empty():
		var src: Node = load(RIFLE_SCENE).instantiate()
		for n in RIFLE_MESHES:
			_rifle_meshes.append((src.find_child(n, true, false) as MeshInstance3D).mesh)
		src.free()
	return _rifle_meshes


## Rifle root sits on the pistol grip; the scaled mesh hangs off it.
func _build_rifle() -> Node3D:
	var root := Node3D.new()
	root.name = "Rifle"
	var body := Node3D.new()
	body.scale = Vector3.ONE * RIFLE_SCALE
	body.position = -RIFLE_GRIP * RIFLE_SCALE
	root.add_child(body)
	for m in _rifle_parts():
		var mi := MeshInstance3D.new()
		mi.mesh = m
		body.add_child(mi)
	return root


## Called by BotHands after the animation: grip in the right hand, barrel
## pointing through the (animated) left hand, then the left arm is bent so the
## left hand lands on the handguard.
func _hands_modify(sk: Skeleton3D) -> void:
	var st := sk.global_transform
	var r := st * sk.get_bone_global_pose(hand_r).origin
	var l := st * sk.get_bone_global_pose(hand_l).origin
	var fwd := l - r
	if fwd.length() < 0.05:
		fwd = -model.global_basis.z
	fwd = fwd.normalized()
	var up := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.95 else -model.global_basis.z
	var b := Basis.looking_at(fwd, up)
	rifle.global_transform = Transform3D(b, r + b * Vector3(0.0, -0.035, -0.05))
	var target: Vector3 = st.affine_inverse() * (rifle.global_transform * ((RIFLE_HANDGUARD - RIFLE_GRIP) * RIFLE_SCALE))
	_two_bone_ik(sk, hand_l, target)
	ik_error = sk.get_bone_global_pose(hand_l).origin.distance_to(target)


## Analytic two-bone IK in skeleton space; keeps the elbow in its animated plane.
static func _two_bone_ik(sk: Skeleton3D, end: int, target: Vector3) -> void:
	var mid := sk.get_bone_parent(end)
	var root := sk.get_bone_parent(mid)
	var ga := sk.get_bone_global_pose(root)
	var gb := sk.get_bone_global_pose(mid)
	var gc := sk.get_bone_global_pose(end)
	var a := ga.origin
	var l1 := a.distance_to(gb.origin)
	var l2 := gb.origin.distance_to(gc.origin)
	var to_t := target - a
	var d := clampf(to_t.length(), absf(l1 - l2) + 0.001, l1 + l2 - 0.001)
	var dir := to_t.normalized()
	var bend := (gb.origin - a) - dir * (gb.origin - a).dot(dir)
	if bend.length() < 0.0001:
		bend = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	bend = bend.normalized()
	var along := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var elbow := a + dir * along + bend * sqrt(maxf(l1 * l1 - along * along, 0.0))
	var r1 := Quaternion((gb.origin - a).normalized(), (elbow - a).normalized())
	var root_g := Basis(r1) * ga.basis
	var mid_g := Basis(r1) * gb.basis
	var hand_now := elbow + Basis(r1) * (gc.origin - gb.origin)
	var r2 := Quaternion((hand_now - elbow).normalized(), (a + dir * d - elbow).normalized())
	mid_g = Basis(r2) * mid_g
	var pr := sk.get_bone_parent(root)
	var parent_g := sk.get_bone_global_pose(pr).basis if pr != -1 else Basis()
	sk.set_bone_pose_rotation(root, (parent_g.inverse() * root_g).get_rotation_quaternion())
	sk.set_bone_pose_rotation(mid, (root_g.inverse() * mid_g).get_rotation_quaternion())


## Height of the neck above the feet in the current pose (headshot line);
## follows the head down when the firing clip leans into the rifle.
func _neck_height() -> float:
	if skel == null or neck == -1:
		return HEAD_HEIGHT
	return (skel.global_transform * skel.get_bone_global_pose(neck).origin).y - global_position.y


func _collect_meshes(n: Node) -> void:
	if n is MeshInstance3D:
		meshes.append(n)
	for c in n.get_children():
		_collect_meshes(c)


func _play(anim_name: String, blend := 0.18, speed := 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if anim.current_animation != anim_name:
		anim.play(anim_name, blend, speed)
	else:
		anim.speed_scale = speed


# ------------------------------------------------------------------ lifecycle

func respawn(pos: Vector3) -> void:
	global_position = pos + Vector3(0, 0.05, 0)
	velocity = Vector3.ZERO
	health.reset()
	alive = true
	state = S.PATROL
	awareness = 0.0
	target = null
	suspect = null
	sees_target = false
	last_attacker = null
	last_attacked_time = -100.0
	last_seen_time = -100.0
	ammo = MAG
	reload_t = 0.0
	burst_left = 0
	next_shot = time + 1.0
	hurt_t = 0.0
	stuck_t = 0.0
	think_t = 0.0
	shape_node.set_deferred("disabled", false)
	collision_layer = 4
	model.position = Vector3.ZERO
	name_label.text = bot_name
	name_label.visible = true
	rotation = Vector3(0, randf() * TAU, 0)
	yaw_target = rotation.y
	visible = true
	_set_overlay(null)
	_play("Idle", 0.0)
	set_physics_process(true)
	_pick_patrol()


## Takes the bot out of play without a death event (used by automated tests to
## isolate a duel). `respawn()` brings it back.
func bench() -> void:
	alive = false
	state = S.DEAD
	death_t = 10.0
	target = null
	visible = false
	shape_node.set_deferred("disabled", true)
	collision_layer = 0
	set_physics_process(false)


func _on_died(source: Node) -> void:
	alive = false
	state = S.DEAD
	death_t = 0.0
	velocity = Vector3.ZERO
	target = null
	sees_target = false
	shape_node.set_deferred("disabled", true)
	collision_layer = 0
	flash.visible = false
	name_label.visible = false
	_set_overlay(null)
	_play("Death", 0.1)
	Sfx.play_at("death", global_position + Vector3(0, 1.2, 0), -4.0)
	killed.emit(self, source)


func _on_damaged(_amount: float, source: Node, _headshot: bool, from_pos: Vector3) -> void:
	hurt_t = 0.12
	_set_overlay(hurt_overlay)
	var push := global_position - from_pos
	push.y = 0.0
	model.position = push.normalized() * 0.06
	if health.dead:
		return
	if source != null and is_instance_valid(source) and source != self and source is Node3D:
		last_attacker = source
		last_attacked_time = time
		last_seen_pos = source.global_position
		last_seen_time = time
		yaw_target = _yaw_to(source.global_position)
		# Turn on the attacker unless already fighting someone in plain view.
		if state != S.COMBAT or target == null or not sees_target:
			_set_target(source)
			_enter_combat()


func _set_overlay(mat: Material) -> void:
	for m in meshes:
		m.material_overlay = mat


# ------------------------------------------------------------------ combatant interface

func get_target_points() -> Array:
	var p := global_position
	return [p + Vector3(0, 1.6, 0), p + Vector3(0, 1.15, 0)]


func take_hit(amount: float, head_mult: float, source: Node, hit_pos: Vector3, from_pos: Vector3) -> Dictionary:
	if not alive or source == self:
		return {"hit": false}
	var head_hit := hit_pos.y - global_position.y >= _neck_height()
	var dmg := amount * (head_mult if head_hit else 1.0)
	health.apply_damage(dmg, source, head_hit, from_pos)
	return {"hit": true, "head": head_hit, "killed": health.dead, "damage": dmg}


# ------------------------------------------------------------------ AI loop

func _physics_process(delta: float) -> void:
	time += delta
	if state == S.DEAD:
		_death_anim(delta)
		return
	if hurt_t > 0.0:
		hurt_t -= delta
		if hurt_t <= 0.0:
			_set_overlay(null)
	model.position = model.position.lerp(Vector3.ZERO, minf(1.0, delta * 10.0))
	flash_t -= delta
	flash.visible = flash_t > 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	if not ai_enabled:
		velocity.x = 0.0
		velocity.z = 0.0
		think_t = 0.0
		move_and_slide()
		_animate(0.0)
		return
	if target != null and (not is_instance_valid(target) or not target.alive):
		_drop_target()

	think_t -= delta
	if think_t <= 0.0:
		think_t = 0.1
		_perceive(0.1)

	var desired := Vector3.ZERO
	match state:
		S.PATROL:
			desired = _patrol(delta)
		S.INVESTIGATE:
			desired = _investigate(delta)
		S.COMBAT:
			desired = _combat(delta)
	desired += _separation()
	_shoot_logic(delta)

	rotation.y = lerp_angle(rotation.y, yaw_target, minf(1.0, delta * 9.0))
	velocity.x = lerpf(velocity.x, desired.x, minf(1.0, delta * 10.0))
	velocity.z = lerpf(velocity.z, desired.z, minf(1.0, delta * 10.0))
	var before := global_position
	move_and_slide()
	var moved := before.distance_to(global_position)
	if desired.length() > 0.5 and moved < desired.length() * delta * 0.25:
		stuck_t += delta
		if stuck_t > 1.2:
			stuck_t = 0.0
			_unstick()
	else:
		stuck_t = 0.0
	_animate(moved / maxf(delta, 0.0001))


# ------------------------------------------------------------------ perception / targeting

func _opponents() -> Array:
	var out: Array = []
	if match_ref == null:
		return out
	for c in match_ref.combatants():
		if c != self and is_instance_valid(c) and c.alive:
			out.append(c)
	return out


## Same rules for every opponent: range, view cone (skipped for the current
## target and a recent attacker), and line of sight that only walls block.
func _can_see(c: Node) -> bool:
	var to: Vector3 = c.global_position - global_position
	var dist := to.length()
	if dist > match_ref.map.vision_range:
		return false
	var alerted := (state == S.COMBAT and c == target) or dist < 3.5 \
		or (c == last_attacker and time - last_attacked_time < ATTACKER_MEMORY)
	if not alerted:
		var flat := Vector3(to.x, 0, to.z).normalized()
		if (-global_transform.basis.z).dot(flat) < cos(deg_to_rad(65.0)):
			return false
	var eye := global_position + Vector3(0, EYE_HEIGHT, 0)
	var space := get_world_3d().direct_space_state
	for pt in c.get_target_points():
		var q := PhysicsRayQueryParameters3D.create(eye, pt, 1, [get_rid()])
		if space.intersect_ray(q).is_empty():
			return true
	return false


func _score(c: Node) -> float:
	var s := 100.0 - global_position.distance_to(c.global_position)
	if c == last_attacker and time - last_attacked_time < ATTACKER_MEMORY:
		s += 40.0
	if c == target:
		s += 25.0
	return s


func _perceive(dt: float) -> void:
	var best: Node = null
	var best_score := -INF
	var target_visible := false
	for c in _opponents():
		if not _can_see(c):
			continue
		if c == target:
			target_visible = true
		var s := _score(c)
		if s > best_score:
			best_score = s
			best = c
	sees_target = target_visible
	if target_visible:
		last_seen_pos = target.global_position
		last_seen_time = time

	if state == S.COMBAT:
		if best != null and best != target:
			# Keep the current target while it stays visible; switch only after a
			# minimum hold time, or immediately when the target is out of sight.
			var hold_over := time - target_since > TARGET_MIN_HOLD
			if target == null or not target_visible or (hold_over and best_score > _score(target) + 15.0):
				_set_target(best)
				sees_target = true
				last_seen_pos = best.global_position
				last_seen_time = time
		if target == null and best == null and time - last_seen_time > 8.0:
			state = S.PATROL
			awareness = 0.3
			_pick_patrol()
		return

	if best == null:
		awareness = maxf(0.0, awareness - dt * 0.4)
		return
	suspect = best
	last_seen_pos = best.global_position
	last_seen_time = time
	var vision: float = match_ref.map.vision_range
	var dist := global_position.distance_to(best.global_position)
	var stance_f: float = [1.0, 0.75, 0.45][clampi(int(best.stance), 0, 2)]
	var dist_f := clampf(1.0 - dist / vision, 0.15, 1.0) * 1.6
	var move_f := 1.0 + Vector2(best.velocity.x, best.velocity.z).length() / 6.0
	awareness += dt * stance_f * dist_f * move_f / float(_diff().reaction)
	if awareness >= 1.0:
		_set_target(best)
		sees_target = true
		_enter_combat()


func _set_target(c: Node) -> void:
	if c == self or c == null or not is_instance_valid(c) or not c.alive:
		return
	if c != target:
		target = c
		target_since = time
		burst_left = 0
		var pts: Array = c.get_target_points()
		aim_point = pts[1] + Vector3(randf_range(-1.5, 1.5), randf_range(-0.5, 1.0), randf_range(-1.5, 1.5))


func _drop_target() -> void:
	target = null
	sees_target = false
	burst_left = 0
	think_t = 0.0   # look for the next opponent right away


func hear(pos: Vector3, radius: float) -> void:
	if not alive or not ai_enabled or state == S.COMBAT:
		return
	var d := global_position.distance_to(pos)
	if d > radius:
		return
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, EYE_HEIGHT, 0), pos + Vector3(0, 0.5, 0), 1, [get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty() and d > radius * 0.6:
		return
	state = S.INVESTIGATE
	awareness = maxf(awareness, 0.5)
	wait_t = 0.0
	yaw_target = _yaw_to(pos)
	_set_nav_target(pos)


func _enter_combat() -> void:
	state = S.COMBAT
	awareness = 1.0
	strafe_t = 0.0
	next_shot = maxf(next_shot, time + float(_diff().reaction) * 0.6)


## A bot that has glimpsed someone stops and turns toward the spot while its
## awareness builds, instead of walking on with its back turned.
func _suspicious() -> bool:
	if awareness > 0.05 and time - last_seen_time < 1.5:
		yaw_target = _yaw_to(last_seen_pos)
		return true
	return false


func _patrol(delta: float) -> Vector3:
	if _suspicious():
		return Vector3.ZERO
	if wait_t > 0.0:
		wait_t -= delta
		yaw_target += delta * 0.6
		if wait_t <= 0.0:
			_pick_patrol()
		return Vector3.ZERO
	if agent.is_navigation_finished():
		wait_t = randf_range(0.8, 2.5)
		return Vector3.ZERO
	var v := _follow_path(PATROL_SPEED)
	if v.length() > 0.1:
		yaw_target = atan2(-v.x, -v.z)
	return v


func _investigate(delta: float) -> Vector3:
	if _suspicious():
		return Vector3.ZERO
	if agent.is_navigation_finished():
		wait_t += delta
		yaw_target += delta * 1.5
		if wait_t > 2.5:
			wait_t = 0.0
			state = S.PATROL
			_pick_patrol()
		return Vector3.ZERO
	var v := _follow_path(CHASE_SPEED * 0.85)
	if v.length() > 0.1:
		yaw_target = atan2(-v.x, -v.z)
	return v


func _combat(delta: float) -> Vector3:
	if target != null and sees_target:
		yaw_target = _yaw_to(target.global_position)
		var to_t: Vector3 = target.global_position - global_position
		to_t.y = 0.0
		var dist := to_t.length()
		to_t = to_t.normalized()
		strafe_t -= delta
		if strafe_t <= 0.0 or agent.is_navigation_finished():
			strafe_t = randf_range(1.2, 2.6)
			var pref: float = match_ref.map.preferred_range
			var side := Vector3(-to_t.z, 0, to_t.x) * (1.0 if randf() < 0.5 else -1.0)
			var radial := 0.0
			if dist > pref * 1.3:
				radial = 4.0
			elif dist < pref * 0.6:
				radial = -3.0
			_set_nav_target(global_position + side * randf_range(2.5, 5.0) + to_t * radial)
		return _follow_path(COMBAT_SPEED)
	if time - last_seen_time < 8.0:
		if agent.target_position.distance_to(last_seen_pos) > 1.5:
			_set_nav_target(last_seen_pos)
		if agent.is_navigation_finished():
			yaw_target += delta * 2.0
			return Vector3.ZERO
		var v := _follow_path(CHASE_SPEED)
		if v.length() > 0.1:
			yaw_target = atan2(-v.x, -v.z)
		return v
	state = S.PATROL
	target = null
	awareness = 0.3
	_pick_patrol()
	return Vector3.ZERO


func _shoot_logic(delta: float) -> void:
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = MAG
		return
	if state != S.COMBAT or not sees_target or target == null or not target.alive:
		burst_left = 0
		return
	var pts: Array = target.get_target_points()
	var aim_at: Vector3 = pts[1] if randf() < 0.75 else pts[0]
	aim_point = aim_point.lerp(aim_at, minf(1.0, delta * float(_diff().aim_lag)))
	if absf(angle_difference(rotation.y, yaw_target)) > deg_to_rad(20.0) or time < next_shot:
		return
	if burst_left <= 0:
		burst_left = randi_range(3, 5)
	_fire_at(aim_point)
	burst_left -= 1
	ammo -= 1
	if ammo <= 0:
		reload_t = RELOAD_TIME
		burst_left = 0
		Sfx.play_at("reload", global_position + Vector3(0, 1.2, 0), -6.0, 0.9, 25.0)
		return
	next_shot = time + (0.13 if burst_left > 0 else float(_diff().burst_pause) * randf_range(0.7, 1.3))


func _fire_at(aim: Vector3) -> void:
	# Trace from inside the bot's own capsule so a gun poking through cover can't shoot through it.
	var from := global_position + Vector3(0, 1.45, 0)
	var dir := (aim - from).normalized()
	var spread := deg_to_rad(float(_diff().spread))
	if target != null and "sprinting" in target and target.sprinting:
		spread *= 1.3
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var r := tan(spread) * sqrt(randf())
	var a := randf() * TAU
	dir = (dir + side * r * cos(a) + up * r * sin(a)).normalized()
	var to := from + dir * 160.0
	# World, player and bots: free-for-all, so bot bullets hit any combatant.
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to
	shots_fired += 1
	if not hit.is_empty():
		end = hit.position
		var col = hit.collider
		if col != null and col != self and col.has_method("take_hit"):
			var res: Dictionary = col.take_hit(float(_diff().damage), 1.0, self, end, from)
			if res.get("hit", false):
				hits_landed += 1
				if col.is_in_group("player"):
					hits_on_player += 1
				Fx.blood(match_ref, end, hit.normal)
		else:
			Fx.impact(match_ref, end, hit.normal)
	Fx.tracer(match_ref, muzzle.global_position, end, Color(1.0, 0.6, 0.3, 0.85))
	flash_t = 0.05
	Sfx.play_at("bot_fire", muzzle.global_position, -1.0, randf_range(0.92, 1.06))
	match_ref.report_noise(global_position, 40.0, self)


# ------------------------------------------------------------------ navigation

func _set_nav_target(pos: Vector3) -> void:
	var map_rid := get_world_3d().navigation_map
	agent.target_position = NavigationServer3D.map_get_closest_point(map_rid, pos)


func _follow_path(speed: float) -> Vector3:
	if agent.is_navigation_finished():
		return Vector3.ZERO
	var next := agent.get_next_path_position()
	var d := next - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return Vector3.ZERO
	return d.normalized() * speed


func _pick_patrol() -> void:
	if match_ref == null or match_ref.map == null:
		return
	var pts: Array = match_ref.map.patrol_points
	if pts.is_empty():
		return
	for i in 4:
		var p: Vector3 = pts[randi() % pts.size()]
		if p.distance_to(global_position) > 6.0:
			_set_nav_target(p)
			return
	_set_nav_target(pts[randi() % pts.size()])


func _unstick() -> void:
	if state == S.COMBAT:
		var a := randf() * TAU
		_set_nav_target(global_position + Vector3(cos(a), 0, sin(a)) * 4.0)
		strafe_t = 1.5
	else:
		_pick_patrol()


func _separation() -> Vector3:
	var push := Vector3.ZERO
	for b in get_tree().get_nodes_in_group("bots"):
		if b == self or not b.alive:
			continue
		var d: Vector3 = global_position - b.global_position
		d.y = 0.0
		var l := d.length()
		if l < 1.4 and l > 0.001:
			push += d / l * (1.4 - l) * 2.0
	return push


func _yaw_to(pos: Vector3) -> float:
	var d := pos - global_position
	return atan2(-d.x, -d.z)


# ------------------------------------------------------------------ animation

func _animate(speed: float) -> void:
	var fighting := state == S.COMBAT and sees_target
	if hurt_t > 0.0 and speed < 0.5:
		_play("HitReact", 0.05)
	elif speed > 3.0:
		_play("Run_Shoot" if fighting else "Run", 0.2, clampf(speed / 4.6, 0.7, 1.3))
	elif speed > 0.3:
		_play("Walk_Shoot" if fighting else "Walk", 0.2, clampf(speed / 2.4, 0.7, 1.4))
	else:
		_play("Idle_Shoot" if fighting else "Idle", 0.25)


func _death_anim(delta: float) -> void:
	death_t += delta
	if death_t > 2.3:
		model.position.y = -(death_t - 2.3) * 0.8
	if death_t > 2.8:
		visible = false
		set_physics_process(false)
