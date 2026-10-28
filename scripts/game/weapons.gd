extends RefCounted
## Weapon definitions and first-person viewmodels.
## Gun meshes: Quaternius "Toon Shooter Game Kit" (CC0) AK and Sniper models,
## rescaled to real-world length. The kit has no first-person arms, so the
## arms are simple capsule sleeves and gloves.
## Models are built at real-world size and scaled by VIEW_SCALE so they sit
## inside the player's collision radius and never clip into walls.

const VIEW_SCALE := 0.2
const MODELS := {
	"ar": "res://assets/quaternius/guns/AK.gltf",
	"sniper": "res://assets/quaternius/guns/Sniper.gltf",
}
## Real-world length (m), barrel height and sight height in the raw model's units.
const SHAPE := {
	"ar": {"length": 0.9, "barrel_y": 0.13, "sight_y": 0.3, "fore_x": -0.55},
	"sniper": {"length": 1.18, "barrel_y": 0.1, "sight_y": 0.36, "fore_x": -0.75},
}

const DEFS := [
	{
		"id": "ar", "name": "VX-4 ASSAULT RIFLE", "short": "VX-4", "auto": true,
		"mag": 30, "reserve": 180, "max_reserve": 300, "kill_bonus": 30,
		"damage": 21.0, "head_mult": 2.0, "rate": 0.092, "reload": 1.9,
		"hip_spread": 2.2, "ads_spread": 0.3, "recoil": 0.55, "recoil_yaw": 0.25,
		"ads_fov": 55.0, "range": 220.0, "sound": "ar_fire", "noise": 50.0,
		"kick_back": 0.016, "kick_rot": 0.07, "shake": 0.12,
		"hip_pos": Vector3(0.072, -0.078, -0.165), "ads_pos": Vector3(0.0, -0.02, -0.11),
	},
	{
		"id": "sniper", "name": "HX-50 SNIPER RIFLE", "short": "HX-50", "auto": false,
		"mag": 5, "reserve": 25, "max_reserve": 40, "kill_bonus": 5,
		"damage": 95.0, "head_mult": 2.5, "rate": 1.3, "reload": 2.8,
		"hip_spread": 5.0, "ads_spread": 0.0, "recoil": 3.2, "recoil_yaw": 0.6,
		"ads_fov": 14.0, "range": 500.0, "sound": "sniper_fire", "noise": 85.0,
		"kick_back": 0.035, "kick_rot": 0.25, "shake": 0.5,
		"hip_pos": Vector3(0.072, -0.08, -0.165), "ads_pos": Vector3(0.0, -0.024, -0.1),
	},
]


## Rigged, textured FPS arms + AK-74M ("FPS AK-74m animations" by Cransh, CC-BY 4.0).
const RIG_SCENE := "res://assets/fps_ak74m/scene.gltf"
const RIG_SCALE := 0.11        # shrink around the camera: same image, never clips walls
const CAM_SCENE := Vector3(0.0, 0.43, 0.0)        # Head_Cam bone, scene units
const SIGHT_SCENE := Vector3(-0.072, 0.352, 0.0)  # iron-sight line (rear notch / front post)
const MUZZLE_SCENE := Vector3(-0.086, 0.245, 1.96)
const HIP_OFFSET := Vector3(0.13, -0.07, 0.02)     # camera space, scene units: carry low-right
const HIP_ROT := Vector3(0.0, 0.07, 0.03)          # small inward yaw so the muzzle points near the crosshair
const ADS_PUSH := 0.2                              # eye relief behind the rear sight
const ADS_DROP := 0.026                            # fine vertical trim of the sight picture
const RIG_ANIMS := {
	"idle": "Rig|AK_Idle", "walk": "Rig|AK_Walk", "run": "Rig|AK_Run", "shot": "Rig|AK_Shot",
	"reload": "Rig|AK_Reload", "reload_empty": "Rig|AK_Reload_full", "draw": "Rig|AK_Draw",
}


## Builds the animated arms viewmodel. The rig's own camera bone (Head_Cam) is
## re-anchored to the game camera every frame by `update_rig()`, so the
## animator's framing, hand placement and weapon sway are preserved.
## M700 sniper ("Free Sniper Rifle M700" by Stein Games, CC0), real-size metres, barrel +Z.
const M700_SCENE := "res://assets/m700/SKM_SniperR700.fbx"
const M700_SCALE := 2.84                          # metres -> rig scene units (same as the AK)
const M700_GRIP := Vector3(0.0, -0.034, -0.033)   # pistol-grip wrist, M700 metres
const AK_GRIP := Vector3(-0.086, 0.12, 0.24)      # where the right hand holds the AK, scene units
const M700_RAIL_TOP := 0.051                      # M700 metres
const M700_RAIL_Z := 0.14
const M700_MUZZLE_Z := 0.737
const SNIPER_HIP_EXTRA := Vector3(0.08, -0.15, -0.28)   # camera space: right, down, forward


static func _m700_material() -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = load("res://assets/m700/T_SniperR700_C.png")
	m.normal_enabled = true
	m.normal_texture = load("res://assets/m700/T_SniperR700_N.png")
	m.orm_texture = load("res://assets/m700/T_SniperR700_ORM.png")
	return m


## Scope modelled from a revolved (lathe) profile: eyepiece, tube, turret saddle and
## objective bell, plus turrets, rings and tinted lenses. Units: metres, axis +Z.
static func build_scope() -> Node3D:
	var root := Node3D.new()
	var body := StandardMaterial3D.new()
	body.albedo_color = Color(0.035, 0.037, 0.04)
	body.metallic = 0.65
	body.roughness = 0.38
	body.clearcoat_enabled = true
	body.clearcoat = 0.25
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = Color(0.02, 0.02, 0.02)
	rubber.roughness = 0.9
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.1, 0.2, 0.28, 0.65)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic = 0.9
	glass.roughness = 0.04
	glass.emission_enabled = true
	glass.emission = Color(0.05, 0.12, 0.2)
	# profile: (radius, z) from eyepiece (z=-0.17) to objective (z=+0.17)
	var tube := [
		Vector2(0.0, -0.172), Vector2(0.019, -0.172), Vector2(0.021, -0.168), Vector2(0.021, -0.13),
		Vector2(0.0195, -0.122), Vector2(0.017, -0.11), Vector2(0.015, -0.1), Vector2(0.015, -0.035),
		Vector2(0.0175, -0.03), Vector2(0.0175, 0.03), Vector2(0.015, 0.035), Vector2(0.015, 0.075),
		Vector2(0.02, 0.105), Vector2(0.025, 0.125), Vector2(0.026, 0.165), Vector2(0.024, 0.172), Vector2(0.0, 0.172),
	]
	root.add_child(_lathe(tube, body, 40))
	# rubber eye cup
	root.add_child(_lathe([Vector2(0.0205, -0.19), Vector2(0.0225, -0.19), Vector2(0.0222, -0.168), Vector2(0.02, -0.168)], rubber, 32))
	# lenses
	for z in [-0.169, 0.169]:
		var lens := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.019 if z < 0.0 else 0.023
		cm.bottom_radius = cm.top_radius
		cm.height = 0.002
		cm.radial_segments = 32
		lens.mesh = cm
		lens.material_override = glass
		lens.rotation.x = PI / 2.0
		lens.position.z = z
		root.add_child(lens)
	# elevation (top) and windage (side) turrets
	var turret := [Vector2(0.0, 0.0), Vector2(0.012, 0.0), Vector2(0.012, 0.012), Vector2(0.014, 0.014),
		Vector2(0.014, 0.024), Vector2(0.012, 0.026), Vector2(0.0, 0.026)]
	var top := _lathe(turret, body, 24)
	top.rotation.x = -PI / 2.0
	top.position = Vector3(0, 0.016, 0)
	root.add_child(top)
	var side := _lathe(turret, body, 24)
	side.rotation.y = PI / 2.0
	side.position = Vector3(0.016, 0, 0)
	root.add_child(side)
	# rings + bases down to the rail
	for z in [-0.06, 0.06]:
		var ring := _lathe([Vector2(0.0158, -0.009), Vector2(0.021, -0.009), Vector2(0.021, 0.009), Vector2(0.0158, 0.009)], body, 32)
		ring.position.z = z
		root.add_child(ring)
		var base := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.022, 0.03, 0.018)
		base.mesh = bm
		base.material_override = body
		base.position = Vector3(0, -0.03, z)
		root.add_child(base)
	return root


## Revolves a (radius, z) profile around the Z axis into a smooth-shaded mesh.
static func _lathe(profile: Array, mat: Material, segments: int) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size() - 1:
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		for s in segments:
			var t0 := TAU * s / segments
			var t1 := TAU * (s + 1) / segments
			var p00 := Vector3(cos(t0) * a.x, sin(t0) * a.x, a.y)
			var p01 := Vector3(cos(t1) * a.x, sin(t1) * a.x, a.y)
			var p10 := Vector3(cos(t0) * b.x, sin(t0) * b.x, b.y)
			var p11 := Vector3(cos(t1) * b.x, sin(t1) * b.x, b.y)
			st.add_vertex(p00)
			st.add_vertex(p10)
			st.add_vertex(p11)
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p01)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func build_rig_viewmodel(kind := "ar") -> Node3D:
	var root := Node3D.new()
	var holder := Node3D.new()
	holder.name = "Holder"
	holder.scale = Vector3.ONE * RIG_SCALE
	root.add_child(holder)
	var inst: Node3D = load(RIG_SCENE).instantiate()
	holder.add_child(inst)
	_no_shadows(inst)
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var anim: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	for key in ["idle", "walk", "run"]:
		anim.get_animation(RIG_ANIMS[key]).loop_mode = Animation.LOOP_LINEAR
	anim.play(RIG_ANIMS.idle)
	anim.advance(0.0)
	var cam_bone := skel.find_bone("Head_Cam_014")
	var rif := skel.find_bone("Rif_059")
	var rif_end := skel.find_bone("Rif_end_079")
	# Camera frame at rest: located at the Head_Cam bone, looking along the barrel,
	# with "up" being the scene's up axis expressed in skeleton space.
	var cam_pose := skel.get_bone_global_pose(cam_bone)
	# In the scene's own space the rifle points along +Z with +Y up (the skeleton
	# itself is Z-up after the FBX conversion), so express those axes in skeleton space.
	var chain := _chain(inst, skel)
	var fwd_skel := (chain.basis.inverse() * Vector3.BACK).normalized()
	var up_skel := (chain.basis.inverse() * Vector3.UP).normalized()
	var view := Transform3D(Basis.looking_at(fwd_skel, up_skel), cam_pose.origin)
	root.set_meta("rig", true)
	root.set_meta("inst", inst)
	root.set_meta("skel", skel)
	root.set_meta("anim", anim)
	root.set_meta("cam_bone", cam_bone)
	root.set_meta("cam_offset", cam_pose.affine_inverse() * view)   # view frame relative to the bone
	# Measured on the model (scene units): muzzle tip and iron-sight line.
	# Camera bone is at (0, 0.43, 0); the sights run at x = -0.086, y = 0.35.
	var muzzle_pt := chain.affine_inverse() * MUZZLE_SCENE
	# aim: shift the rig so the sight line passes through the camera centre
	# (camera-space x is the scene's -X, hence the sign)
	root.set_meta("ads_offset", (Vector3(SIGHT_SCENE.x, CAM_SCENE.y - SIGHT_SCENE.y - ADS_DROP, -ADS_PUSH) - HIP_OFFSET) * RIG_SCALE)
	root.set_meta("hip_offset", HIP_OFFSET * RIG_SCALE)
	root.set_meta("hip_rot", HIP_ROT)
	if kind == "sniper":
		muzzle_pt = chain.affine_inverse() * _mount_m700(root, inst, skel, chain)
	# muzzle point stored relative to the rifle bone; follows the bone in every animation
	root.set_meta("rif_bone", rif)
	root.set_meta("muzzle_local", skel.get_bone_global_pose(rif).affine_inverse() * muzzle_pt)
	# unscaled marker in viewmodel space so the shared flash/tracer code keeps working
	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	root.add_child(muzzle)
	var flash := Node3D.new()
	flash.name = "Flash"
	flash.visible = false
	flash.add_child(preload("res://scripts/game/fx.gd").muzzle_flash(0.3))
	muzzle.add_child(flash)
	update_rig(root)
	return root


## Hides the AK in the arms rig and mounts the M700 (+ scope) on the rifle bone so
## the right hand sits on its grip. Returns the muzzle point in scene units.
static func _mount_m700(root: Node3D, inst: Node3D, skel: Skeleton3D, chain: Transform3D) -> Vector3:
	for mi in skel.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).mesh.surface_get_material(0)
		if mat and "ak74m" in mat.resource_name:
			mi.visible = false
	var rif := skel.find_bone("Rif_059")
	var att := BoneAttachment3D.new()
	att.bone_name = "Rif_059"
	skel.add_child(att)
	var gun := Node3D.new()
	gun.name = "M700Mount"
	att.add_child(gun)
	var m700: Node3D = load(M700_SCENE).instantiate()
	gun.add_child(m700)
	var mat := _m700_material()
	for mi in m700.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = mat
	_no_shadows(m700)
	var scope := build_scope()
	scope.position = Vector3(0, M700_RAIL_TOP + 0.034, M700_RAIL_Z)
	gun.add_child(scope)
	_no_shadows(scope)
	# placement in scene space: uniform scale, grip onto the AK grip position
	var off := AK_GRIP - M700_GRIP * M700_SCALE
	var t_scene := Transform3D(Basis().scaled(Vector3.ONE * M700_SCALE), off)
	gun.transform = (chain * skel.get_bone_global_pose(rif)).affine_inverse() * t_scene
	# ADS along the scope axis
	var scope_y := off.y + (M700_RAIL_TOP + 0.034) * M700_SCALE
	# the scoped rifle is carried lower and further right at the hip than the AK
	var hip := HIP_OFFSET + SNIPER_HIP_EXTRA
	root.set_meta("hip_offset", hip * RIG_SCALE)
	root.set_meta("ads_offset", (Vector3(off.x, CAM_SCENE.y - scope_y, -0.05) - hip) * RIG_SCALE)
	# bolt + magazine bones of the M700's own skeleton
	var msk: Skeleton3D = m700.find_children("*", "Skeleton3D", true, false)[0]
	root.set_meta("m700_skel", msk)
	root.set_meta("m700_bolt", msk.find_bone("BOLT"))
	root.set_meta("m700_mag", msk.find_bone("MAGAZINE"))
	root.set_meta("m700_to_skel", _chain(m700, msk))
	root.set_meta("bolt_t", -1.0)
	root.set_meta("m700_mount", gun)
	# reference poses for driving the M700 magazine from the rig's magazine bone
	var pmag := skel.find_bone("Pmag_062")
	root.set_meta("pmag_bone", pmag)
	root.set_meta("pmag_ref", chain * skel.get_bone_global_pose(pmag))
	var mag := msk.find_bone("MAGAZINE")
	if mag >= 0:
		var scene_from_mskel := chain * skel.get_bone_global_pose(rif) * gun.transform * _chain(m700, msk)
		root.set_meta("mag_ref", scene_from_mskel * msk.get_bone_global_pose(mag))
	return off + Vector3(0, 0.031, M700_MUZZLE_Z) * M700_SCALE


## Bolt-action cycle after a sniper shot: lift, pull back, push, lock (0.75 s).
static func start_bolt(root: Node3D) -> void:
	if root.has_meta("m700_skel"):
		root.set_meta("bolt_t", 0.0)


static func _animate_m700(root: Node3D, delta: float) -> void:
	var msk: Skeleton3D = root.get_meta("m700_skel")
	var bolt: int = root.get_meta("m700_bolt")
	if bolt < 0:
		return
	var t: float = root.get_meta("bolt_t")
	var lift := 0.0
	var pull := 0.0
	if t >= 0.0:
		t += delta
		root.set_meta("bolt_t", t if t < 0.75 else -1.0)
		lift = smoothstep(0.0, 0.12, t) * (1.0 - smoothstep(0.6, 0.72, t))
		pull = smoothstep(0.14, 0.32, t) * (1.0 - smoothstep(0.38, 0.56, t))
	var to_skel: Transform3D = root.get_meta("m700_to_skel")
	var rest := msk.get_bone_rest(bolt)
	var parent := msk.get_bone_parent(bolt)
	var parent_g := msk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var back_skel := to_skel.basis.inverse() * Vector3(0, 0, -0.075)   # rearward, model metres
	var axis_skel := (to_skel.basis.inverse() * Vector3(0, 0, 1)).normalized()
	var local_back := parent_g.basis.inverse() * back_skel
	var local_axis := (parent_g.basis.inverse() * axis_skel).normalized()
	msk.set_bone_pose_position(bolt, rest.origin + local_back * pull)
	msk.set_bone_pose_rotation(bolt, Quaternion(local_axis, -deg_to_rad(70.0) * lift) * rest.basis.get_rotation_quaternion())


## Product of local transforms from `ancestor` down to `node` (works outside the tree).
static func _chain(ancestor: Node, node: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n := node
	while n != null and n != ancestor:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


## Re-anchors the rig so its (animated) camera bone sits exactly on the game camera,
## and moves the unscaled muzzle marker onto the rifle's muzzle.
static func update_rig(root: Node3D) -> void:
	var inst: Node3D = root.get_meta("inst")
	var holder: Node3D = inst.get_parent()
	var skel: Skeleton3D = root.get_meta("skel")
	var off: Transform3D = root.get_meta("cam_offset")
	var skel_in_inst := _chain(inst, skel)
	var cam_in_inst := skel_in_inst * skel.get_bone_global_pose(int(root.get_meta("cam_bone"))) * off
	var unscaled := Transform3D(cam_in_inst.basis.orthonormalized(), cam_in_inst.origin)
	inst.transform = unscaled.affine_inverse()
	var rif_pose := skel.get_bone_global_pose(int(root.get_meta("rif_bone")))
	var p_inst: Vector3 = skel_in_inst * (rif_pose * (root.get_meta("muzzle_local") as Vector3))
	var muzzle: Node3D = root.get_node("Muzzle")
	muzzle.position = holder.transform * (inst.transform * p_inst)
	if root.has_meta("m700_skel"):
		_animate_m700(root, root.get_process_delta_time() if root.is_inside_tree() else 0.0)
		_follow_magazine(root, skel, skel_in_inst)


## During a reload the M700's box magazine follows the rig's magazine bone, so
## the left hand visibly pulls and seats it; otherwise it stays in the rifle.
static func _follow_magazine(root: Node3D, skel: Skeleton3D, chain: Transform3D) -> void:
	if not root.has_meta("mag_ref"):
		return
	var msk: Skeleton3D = root.get_meta("m700_skel")
	var mag: int = root.get_meta("m700_mag")
	if not root.get_meta("reloading", false):
		msk.reset_bone_pose(mag)
		return
	var pmag_now := chain * skel.get_bone_global_pose(int(root.get_meta("pmag_bone")))
	var delta: Transform3D = pmag_now * (root.get_meta("pmag_ref") as Transform3D).affine_inverse()
	var target: Transform3D = delta * (root.get_meta("mag_ref") as Transform3D)
	var gun: Node3D = root.get_meta("m700_mount")
	var m700: Node3D = gun.get_child(0)
	var scene_from_mskel := chain * skel.get_bone_global_pose(skel.find_bone("Rif_059")) * gun.transform * _chain(m700, msk)
	msk.set_bone_global_pose(mag, scene_from_mskel.affine_inverse() * target)


static func _no_shadows(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadows(c)


static func _limb(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = a.distance_to(b) + radius * 2.0
	cm.radial_segments = 12
	cm.rings = 4
	m.mesh = cm
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var dir := (b - a).normalized()
	# CapsuleMesh is aligned to +Y.
	var x := dir.cross(Vector3.FORWARD)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(dir).normalized()
	m.transform = Transform3D(Basis(x, dir, z), (a + b) * 0.5)


static func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	return m


static func build_viewmodel(id: String) -> Node3D:
	var root := Node3D.new()
	var model := Node3D.new()
	model.scale = Vector3.ONE * VIEW_SCALE
	root.add_child(model)
	var shape: Dictionary = SHAPE[id]
	var gun: Node3D = load(MODELS[id]).instantiate()
	var raw_len := 1.42 if id == "ar" else 2.05
	var s: float = float(shape.length) / raw_len
	gun.scale = Vector3.ONE * s
	gun.rotation.y = -PI / 2.0     # model barrel points -X; viewmodel forward is -Z
	model.add_child(gun)
	_no_shadows(gun)

	var sleeve := _mat(Color(0.26, 0.29, 0.21), 0.9)
	var glove := _mat(Color(0.08, 0.08, 0.075), 0.7)
	var grip := Vector3(0.0, -0.06, 0.06)
	var fore := Vector3(0.0, 0.0, float(shape.fore_x) * s)
	_limb(model, grip + Vector3(0.0, -0.02, 0.0), grip + Vector3(0.0, -0.02, 0.02), 0.045, glove)
	_limb(model, grip + Vector3(0.02, -0.06, 0.06), grip + Vector3(0.1, -0.26, 0.42), 0.055, sleeve)
	_limb(model, fore + Vector3(0.0, -0.035, 0.0), fore + Vector3(-0.02, -0.04, 0.04), 0.042, glove)
	_limb(model, fore + Vector3(-0.03, -0.07, 0.04), fore + Vector3(-0.22, -0.28, 0.4), 0.052, sleeve)

	var muzzle := Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0, float(shape.barrel_y) * s, -(1.03 if id == "ar" else 1.59) * s) * VIEW_SCALE
	root.add_child(muzzle)
	var flash := Node3D.new()
	flash.name = "Flash"
	flash.visible = false
	flash.add_child(preload("res://scripts/game/fx.gd").muzzle_flash(0.35))
	muzzle.add_child(flash)
	root.set_meta("sight_y", float(shape.sight_y) * s * VIEW_SCALE)
	return root
