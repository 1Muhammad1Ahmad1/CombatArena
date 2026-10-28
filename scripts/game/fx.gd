extends RefCounted
## Combat effects: muzzle flashes, tracers, impact dust + sparks, blood puffs
## and bullet holes. Textures are small generated gradients; meshes and
## materials are shared so effects stay cheap.

static var _tracer_mesh: BoxMesh
static var _spark_mesh: BoxMesh
static var _puff_mesh: QuadMesh
static var _hole_mesh: QuadMesh
static var _hole_mat: StandardMaterial3D
static var _flash_mat: StandardMaterial3D
static var _mats := {}
static var _puff_mats := {}
static var _holes: Array = []


static func _unshaded(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


static func _radial(inner: Color, outer: Color, size := 64) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	return t


static func _valid(parent: Node) -> bool:
	return parent != null and is_instance_valid(parent) and parent.is_inside_tree()


## Muzzle flash: three crossed additive quads (star shape from the side, disc
## from the front) plus a short-range light. Scale 1 = viewmodel size.
static func muzzle_flash(scale := 1.0) -> Node3D:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_flash_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash_mat.albedo_texture = _radial(Color(1.0, 0.95, 0.7, 1.0), Color(1.0, 0.45, 0.05, 0.0))
		_flash_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_flash_mat.no_depth_test = false
	var root := Node3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.16) * scale
	for i in 2:
		var m := MeshInstance3D.new()
		m.mesh = q
		m.material_override = _flash_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.rotation = Vector3(PI / 2.0, 0, i * PI / 2.0)
		m.position.z = -0.06 * scale
		root.add_child(m)
	var disc := QuadMesh.new()
	disc.size = Vector2(0.09, 0.09) * scale
	var d := MeshInstance3D.new()
	d.mesh = disc
	d.material_override = _flash_mat
	d.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(d)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 2.2
	light.omni_range = 3.5 * maxf(scale, 1.0)
	light.shadow_enabled = false
	root.add_child(light)
	return root


static func tracer(parent: Node, from: Vector3, to: Vector3, color := Color(1.0, 0.86, 0.55, 0.8)) -> void:
	var length := from.distance_to(to)
	if length < 0.6 or not _valid(parent):
		return
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.014, 0.014, 1.0)
	var m := MeshInstance3D.new()
	m.mesh = _tracer_mesh
	m.material_override = _unshaded(color)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var dir := (to - from) / length
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	m.global_transform = Transform3D(Basis.looking_at(dir, up), (from + to) * 0.5)
	m.scale = Vector3(1.0, 1.0, length)
	parent.get_tree().create_timer(0.05, false).timeout.connect(m.queue_free)


static func _sparks(parent: Node, pos: Vector3, normal: Vector3, color: Color, amount: int, speed: float) -> void:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3(0.025, 0.025, 0.06)
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.material_override = _unshaded(color)
	p.amount = amount
	p.lifetime = 0.35
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = normal
	p.spread = 35.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	parent.add_child(p)
	p.global_position = pos + normal * 0.03
	p.emitting = true
	parent.get_tree().create_timer(0.8, false).timeout.connect(p.queue_free)


static func _puff(parent: Node, pos: Vector3, normal: Vector3, color: Color, size: float) -> void:
	if _puff_mesh == null:
		_puff_mesh = QuadMesh.new()
		_puff_mesh.size = Vector2(1, 1)
	var key := color.to_html()
	if not _puff_mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = _radial(Color(1, 1, 1, 0.9), Color(1, 1, 1, 0.0))
		m.albedo_color = color
		_puff_mats[key] = m
	var p := CPUParticles3D.new()
	p.mesh = _puff_mesh
	p.material_override = _puff_mats[key]
	p.amount = 5
	p.lifetime = 0.6
	p.one_shot = true
	p.explosiveness = 0.9
	p.direction = normal
	p.spread = 25.0
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0, 0.3, 0)
	p.damping_min = 2.0
	p.damping_max = 3.0
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(1, 1.0))
	p.scale_amount_curve = curve
	p.scale_amount_min = size
	p.scale_amount_max = size * 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = fade
	parent.add_child(p)
	p.global_position = pos + normal * 0.05
	p.emitting = true
	parent.get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)


static func impact(parent: Node, pos: Vector3, normal: Vector3, color := Color(0.78, 0.72, 0.62), hole := true) -> void:
	if not _valid(parent):
		return
	_puff(parent, pos, normal, Color(color.r, color.g, color.b, 0.7), 0.35)
	_sparks(parent, pos, normal, Color(1.0, 0.82, 0.45), 6, 6.0)
	if hole:
		_bullet_hole(parent, pos, normal)


static func blood(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if not _valid(parent):
		return
	_puff(parent, pos, normal, Color(0.55, 0.04, 0.03, 0.85), 0.3)
	_sparks(parent, pos, normal, Color(0.6, 0.05, 0.03), 5, 3.0)


static func _bullet_hole(parent: Node, pos: Vector3, normal: Vector3) -> void:
	if _hole_mesh == null:
		_hole_mesh = QuadMesh.new()
		_hole_mesh.size = Vector2(0.09, 0.09)
		_hole_mat = StandardMaterial3D.new()
		_hole_mat.albedo_texture = _radial(Color(0.02, 0.02, 0.02, 0.95), Color(0.05, 0.05, 0.05, 0.0), 32)
		_hole_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hole_mat.roughness = 1.0
	var q := MeshInstance3D.new()
	q.mesh = _hole_mesh
	q.material_override = _hole_mat
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(q)
	var up := Vector3.UP if absf(normal.y) < 0.98 else Vector3.FORWARD
	q.global_transform = Transform3D(Basis.looking_at(-normal, up), pos + normal * 0.012)
	_holes.append(q)
	while _holes.size() > 60:
		var old = _holes.pop_front()
		if is_instance_valid(old):
			old.queue_free()
