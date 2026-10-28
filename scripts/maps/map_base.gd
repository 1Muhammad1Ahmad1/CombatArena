extends Node3D
## Base class for procedurally constructed arenas.
## Everything with collision is placed under a NavigationRegion3D whose
## NavigationMesh is baked from static colliders at load time.

const Mats = preload("res://scripts/maps/mats.gd")

var nav_region: NavigationRegion3D
var decor: Node3D
var env: Environment
var sun: DirectionalLight3D
var player_spawns: Array = []      # Array of [Vector3 position, float yaw]
var bot_spawns: Array = []         # Array of Vector3
var patrol_points: Array = []      # Array of Vector3
var vision_range := 50.0
var preferred_range := 15.0
var ambient_sound := "ambient_wind"
var volumetric_density := 0.0     # > 0 enables volumetric fog (light shafts) on Epic
var _box_meshes := {}
var _window_xforms: Array = []


func _init() -> void:
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Nav"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.agent_radius = 0.45
	nm.agent_height = 1.8
	nm.agent_max_climb = 0.35
	nm.agent_max_slope = 40.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nav_region.navigation_mesh = nm
	add_child(nav_region)
	decor = Node3D.new()
	decor.name = "Decor"
	add_child(decor)


## Override: build geometry, spawns, lighting.
func build() -> void:
	pass


func bake_navigation() -> void:
	nav_region.bake_navigation_mesh(false)


func nav_polygon_count() -> int:
	return nav_region.navigation_mesh.get_polygon_count()


var _spots: Array = []


func apply_quality(q: Dictionary) -> void:
	if env:
		env.ssao_enabled = q.ssao
		env.glow_enabled = q.glow
		env.ssr_enabled = q.get("ssr", false)
		env.ssil_enabled = q.get("ssil", false)
		env.volumetric_fog_enabled = q.get("vol_fog", false) and volumetric_density > 0.0
	if sun:
		sun.directional_shadow_max_distance = q.shadow_dist
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS \
			if q.get("hq_shadows", false) and q.get("sun_splits", 4) == 4 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	# Shadowed spot lamps only on High / Epic; Low / Medium keep the light without shadows.
	for s in _spots:
		s.shadow_enabled = q.get("hq_shadows", false)
	_hq_shadows = q.get("facade_shadows", false)   # full facade shadows: Epic only (proxy boxes otherwise)
	_apply_facade_shadows()


# ------------------------------------------------------------------ CC0 props

const PROP_DIR := "res://assets/quaternius/env/"
static var _prop_scenes := {}
static var _prop_boxes := {}


static func _merged_aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		out = t * (n as MeshInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var a := _merged_aabb(c, t)
		if a.size == Vector3.ZERO:
			continue
		out = a if first else out.merge(a)
		first = false
	return out


## Places a Quaternius prop. Collision is a single box fitted to the model's
## bounds (cheap, and keeps navmesh baking predictable). `size` (optional)
## rescales non-uniformly so the bounds match exactly.
func prop(prop_name: String, pos: Vector3, yaw := 0.0, scale := 1.0, collide := true, size := Vector3.ZERO, view_range := 0.0, keep_origin := false) -> Node3D:
	if not _prop_scenes.has(prop_name):
		var path := PROP_DIR + prop_name + ".gltf"
		if prop_name.begins_with("ph:"):   # Poly Haven (CC0, real-world scale, PBR)
			path = ph_path(prop_name.substr(3))
		_prop_scenes[prop_name] = load(path)
	var inst: Node3D = _prop_scenes[prop_name].instantiate()
	var bounds := _merged_aabb(inst, Transform3D.IDENTITY)
	_lighten(inst, clampf(pow(bounds.size.length() * maxf(scale, 0.01), 1.5) * 1300.0, 600.0, PROP_MAX_TRIS) / maxf(_tri_count(inst), 1.0))
	if not _prop_boxes.has(prop_name):
		_prop_boxes[prop_name] = _merged_aabb(inst, Transform3D.IDENTITY)
	var raw: AABB = _prop_boxes[prop_name]
	var sc := Vector3.ONE * scale
	if size != Vector3.ZERO:
		sc = Vector3(size.x / maxf(raw.size.x, 0.01), size.y / maxf(raw.size.y, 0.01), size.z / maxf(raw.size.z, 0.01))
	inst.scale = sc
	# centre the model's footprint on `pos`, resting on the ground
	var c := raw.get_center()
	if keep_origin:
		c = Vector3.ZERO
	inst.position = -Vector3(c.x * sc.x, raw.position.y * sc.y, c.z * sc.z)
	if view_range > 0.0:
		_set_view_range(inst, view_range)
	if bounds.size.length() * scale < 1.2:   # small props: SSAO grounds them, skip the sun shadow pass
		_no_shadow(inst)
	var holder: Node3D
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = raw.size * sc
		cs.shape = bs
		cs.position.y = bs.size.y * 0.5
		sb.add_child(cs)
		holder = sb
		nav_region.add_child(sb)
	else:
		holder = Node3D.new()
		decor.add_child(holder)
	holder.add_child(inst)
	holder.position = pos
	holder.rotation.y = yaw
	return holder


## Poly Haven models live in assets/polyhaven/<id>/ (first batch) or
## assets/downloads/<map>/models/<id>/ (map overhaul batch).
static func ph_path(id: String) -> String:
	for dir in ["res://assets/polyhaven/", "res://assets/downloads/urban/models/", "res://assets/downloads/warehouse/models/",
			"res://assets/downloads/desert/models/", "res://assets/downloads/shared/models/"]:
		var p := "%s%s/%s_1k.gltf" % [dir, id, id]
		if ResourceLoader.exists(p):
			return p
	push_error("Poly Haven model not found: " + id)
	return ""


const PROP_MAX_TRIS := 6000


## Scanned props are very dense (a fire hydrant is ~86k triangles). Each prop gets a
## triangle budget from its physical size (about 800 for a 0.5 m box up to
## PROP_MAX_TRIS for a car); every part is swapped for the import-time LOD level
## that brings the whole prop within budget.
static func _lighten(n: Node, ratio: float) -> void:
	if ratio >= 1.0:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		mi.mesh = Kit.lod_mesh(mi.mesh, ratio)
	for c in n.get_children():
		_lighten(c, ratio)


static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


static func _tri_count(n: Node) -> int:
	var t := 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		for s in (n as MeshInstance3D).mesh.get_surface_count():
			t += (n as MeshInstance3D).mesh.surface_get_array_index_len(s) / 3
	for c in n.get_children():
		t += _tri_count(c)
	return t


func _set_view_range(n: Node, r: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).visibility_range_end = r
		(n as GeometryInstance3D).visibility_range_end_margin = 4.0
		(n as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	for ch in n.get_children():
		_set_view_range(ch, r)


## A 20 ft or 40 ft shipping container: collision box of the given size with the
## CC0 container model stretched over it.
func container_prop(center: Vector3, size: Vector3) -> void:
	# Corrugated-steel PBR box (ambientCG CorrugatedSteel007A) with a darker frame.
	var tint: Color = CONTAINER_TINTS[_container_count % CONTAINER_TINTS.size()]
	_container_count += 1
	box(center, size, Mats.container(tint))
	# corner posts in the container's paint, slightly darker
	var post := Mats.painted_metal(tint.darkened(0.35))
	for sx in [-0.5, 0.5]:
		for sz in [-0.5, 0.5]:
			box(center + Vector3(size.x * sx, 0, size.z * sz), Vector3(0.14, size.y + 0.02, 0.14), post, false)


const CONTAINER_TINTS := [Color(0.62, 0.2, 0.15), Color(0.2, 0.33, 0.52), Color(0.26, 0.4, 0.27), Color(0.75, 0.42, 0.14)]
var _container_count := 0
static var _tint_cache := {}


func _tint_red(n: Node, tint: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i) as StandardMaterial3D
			if m and m.albedo_color.r > m.albedo_color.g * 1.6 and m.albedo_color.r > 0.3:
				var key := "%s%s" % [m.get_instance_id(), tint.to_html()]
				if not _tint_cache.has(key):
					var d := m.duplicate() as StandardMaterial3D
					d.albedo_color = tint
					_tint_cache[key] = d
				mi.set_surface_override_material(i, _tint_cache[key])
	for c in n.get_children():
		_tint_red(c, tint)


## Cheap fake light shaft: an additive, softly fading column of light.
func light_shaft(top: Vector3, bottom: Vector3, width: float, color: Color) -> void:
	var m := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, top.distance_to(bottom))
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var g := Gradient.new()
	g.set_color(0, Color(color.r, color.g, color.b, 0.0))
	g.set_color(1, Color(color.r, color.g, color.b, 0.0))
	g.add_point(0.5, Color(color.r, color.g, color.b, color.a))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	t.width = 64
	t.height = 4
	mat.albedo_texture = t
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.position = (top + bottom) * 0.5
	decor.add_child(m)


func spot_lamp(pos: Vector3, color: Color, energy: float, reach: float) -> void:
	var s := SpotLight3D.new()
	s.light_color = color
	s.light_energy = energy
	s.spot_range = reach
	s.spot_angle = 55.0
	s.spot_attenuation = 0.8
	s.position = pos
	s.rotation.x = -PI / 2.0
	s.shadow_enabled = false
	decor.add_child(s)
	_spots.append(s)
	# Poly Haven hanging industrial lamp (origin at the ceiling hook, hangs 1.34 m)
	prop("ph:hanging_industrial_lamp", pos, 0.0, 1.0, false, Vector3.ZERO, 0.0, true)
	var bulb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.1
	bulb.mesh = sm
	bulb.material_override = Mats.emissive(color, 6.0)
	bulb.position = pos + Vector3(0, 0.08, 0)
	decor.add_child(bulb)


# ------------------------------------------------------------------ helpers

func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "%s" % size
	if not _box_meshes.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_box_meshes[key] = bm
	return _box_meshes[key]


func box(center: Vector3, size: Vector3, mat: Material, collide := true, yaw := 0.0) -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = mat
	if not collide:
		mi.position = center
		mi.rotation.y = yaw
		decor.add_child(mi)
		return mi
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.add_child(mi)
	sb.position = center
	sb.rotation.y = yaw
	nav_region.add_child(sb)
	return sb


## Invisible collision only (e.g. a pole under a decorative model).
func blocker(center: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = center
	nav_region.add_child(sb)


## Box given by its floor-level footprint corners and height (y0 = base).
func block(x0: float, x1: float, z0: float, z1: float, h: float, mat: Material, y0 := 0.0, collide := true) -> Node3D:
	return box(Vector3((x0 + x1) * 0.5, y0 + h * 0.5, (z0 + z1) * 0.5), Vector3(absf(x1 - x0), h, absf(z1 - z0)), mat, collide)


func cylinder(base: Vector3, radius: float, height: float, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = 16
	mi.mesh = cm
	mi.material_override = mat
	if collide:
		var sb := StaticBody3D.new()
		sb.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		sb.add_child(cs)
		sb.add_child(mi)
		sb.position = base + Vector3(0, height * 0.5, 0)
		nav_region.add_child(sb)
	else:
		mi.position = base + Vector3(0, height * 0.5, 0)
		decor.add_child(mi)


## Walkable slope between two floor points (centre-line), with the top surface
## passing through both points. Optional visual steps are added.
func ramp(bottom: Vector3, top: Vector3, width: float, mat: Material, steps := false) -> void:
	var dir := top - bottom
	var length := dir.length()
	var b := Basis.looking_at(dir.normalized(), Vector3.UP)
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 0.3, length + 0.2)
	cs.shape = bs
	sb.add_child(cs)
	sb.transform = Transform3D(b, (bottom + top) * 0.5 - b.y * 0.15)
	nav_region.add_child(sb)
	if not steps:
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(bs.size)
		mi.material_override = mat
		sb.add_child(mi)
		return
	var rise := top.y - bottom.y
	var count := maxi(2, int(rise / 0.25))
	var flat := Vector3(dir.x, 0, dir.z)
	var yaw := atan2(-flat.x, -flat.z)
	for i in count:
		var t := (float(i) + 0.5) / count
		var h := rise * (float(i) + 1.0) / count
		var p := bottom + flat * t
		box(Vector3(p.x, bottom.y + h * 0.5, p.z), Vector3(width, h, flat.length() / count + 0.02), mat, false, yaw)


func railing(a: Vector3, b: Vector3, mat: Material, height := 1.05) -> void:
	var mid := (a + b) * 0.5
	var flat := b - a
	var yaw := atan2(-flat.x, -flat.z)
	var length := flat.length()
	box(mid + Vector3(0, height * 0.5, 0), Vector3(0.08, height, length), mat, true, yaw)
	box(mid + Vector3(0, height, 0), Vector3(0.12, 0.08, length + 0.05), mat, false, yaw)


func light(pos: Vector3, color: Color, energy: float, radius: float, lamp := true) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	l.omni_attenuation = 1.2
	l.position = pos
	decor.add_child(l)
	if lamp:
		box(pos + Vector3(0, 0.25, 0), Vector3(0.9, 0.12, 0.5), Mats.painted_metal(Color(0.2, 0.22, 0.2)), false)
		box(pos + Vector3(0, 0.16, 0), Vector3(0.8, 0.05, 0.4), Mats.emissive(color, 4.0), false)


func windows_on(x0: float, x1: float, z0: float, z1: float, h: float, spacing := 3.0, y_start := 2.0) -> void:
	## Collect window panes for all four facades of a building block.
	var floors := int((h - y_start) / 3.2) + 1
	for f in floors:
		var y := y_start + f * 3.2
		if y + 0.8 > h:
			break
		var nx := int((x1 - x0 - 1.0) / spacing)
		for i in nx:
			var x := x0 + (x1 - x0 - (nx - 1) * spacing) * 0.5 + i * spacing
			_window_xforms.append(Transform3D(Basis(), Vector3(x, y, z0 - 0.04)))
			_window_xforms.append(Transform3D(Basis(), Vector3(x, y, z1 + 0.04)))
		var nz := int((z1 - z0 - 1.0) / spacing)
		for i in nz:
			var z := z0 + (z1 - z0 - (nz - 1) * spacing) * 0.5 + i * spacing
			_window_xforms.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x0 - 0.04, y, z)))
			_window_xforms.append(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x1 + 0.04, y, z)))


func flush_windows() -> void:
	if _window_xforms.is_empty():
		return
	var frame := BoxMesh.new()
	frame.size = Vector3(1.3, 1.7, 0.1)
	frame.material = Mats.glass()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = frame
	mm.instance_count = _window_xforms.size()
	for i in _window_xforms.size():
		mm.set_instance_transform(i, _window_xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	decor.add_child(mmi)
	_window_xforms.clear()


## Cover crates: two stacked Poly Haven military crates (real size, 1.24 x 0.92 x 0.52 m).
## `size` > 1.0 adds a small ammo/supply crate on top.
func crate(pos: Vector3, size := 1.2) -> void:
	var yaw := fposmod(pos.x * 1.7 + pos.z, 0.3) - 0.15
	if pos.y > 0.5:   # old "stacked crate" placements sit on another crate
		prop("ph:wooden_crate_02", pos - Vector3(0, 0.25, 0), yaw + PI / 2.0, 1.0, false, Vector3.ZERO, 70.0)
		return
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.24, 0.92, 0.6)
	cs.shape = bs
	cs.position.y = 0.46
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	nav_region.add_child(sb)
	for i in 2:
		var c: Node3D = prop("ph:wooden_military_crate", Vector3(0, i * 0.46, 0), (0.04 if i == 1 else 0.0), 1.0, false, Vector3.ZERO, 80.0)
		c.reparent(sb, false)
	if size > 1.15:
		var top: Node3D = prop("ph:ammo_box", Vector3(0.3, 0.92, 0.05), 1.2, 1.0, false, Vector3.ZERO, 40.0)
		top.reparent(sb, false)


func barrel(pos: Vector3, _color := Color.WHITE) -> void:
	var h := int(absf(pos.x * 3.0 + pos.z * 7.0)) % 2
	prop("ph:Barrel_01" if h == 0 else "ph:Barrel_02", pos, fposmod(pos.x + pos.z, TAU), 1.0, true, Vector3.ZERO, 70.0)


## Concrete road barrier pair (Poly Haven, 2 x 1.55 m) along local X.
func jersey(pos: Vector3, yaw := 0.0) -> void:
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.1, 0.83, 0.64)
	cs.shape = bs
	cs.position.y = 0.415
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = yaw
	nav_region.add_child(sb)
	for x in [-0.78, 0.78]:
		var b: Node3D = prop("ph:concrete_road_barrier", Vector3(x, 0, 0), 0.0, 1.0, false)
		b.reparent(sb, false)


## Sandbag wall: collision box (same as before) with individually stacked,
## rounded bags in a running-bond pattern two bags deep.
func sandbags(pos: Vector3, length: float, yaw := 0.0, height := 1.0) -> void:
	_rot_blocker(pos + Vector3(0, height * 0.5, 0), Vector3(length, height, 0.7), yaw)
	var b := Basis(Vector3.UP, yaw)
	var rows := maxi(1, roundi(height / 0.155))
	var bag_l := 0.58
	var xs: Array = []
	var h := fposmod(pos.x * 13.1 + pos.z * 7.7, 1.0)
	for r in rows:
		var per := maxi(1, int(length / bag_l))
		var off := (bag_l * 0.5) if r % 2 == 1 else 0.0
		for i in per:
			var x := -length * 0.5 + bag_l * 0.5 + i * (length - bag_l) / maxf(per - 1, 1) + (off if i < per - 1 else 0.0)
			for d in [-0.17, 0.17]:
				var jitter := fposmod(h * 31.0 + i * 1.7 + r * 3.1 + d, 1.0) - 0.5
				var t := Basis(Vector3.UP, jitter * 0.25) * Basis(Vector3.BACK, jitter * 0.06)
				xs.append(Transform3D(b * t, pos + b * Vector3(x, 0.075 + r * 0.15, d)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _bag_mesh()
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mats.sandbag()
	mmi.visibility_range_end = 120.0
	decor.add_child(mmi)


func _rot_blocker(center: Vector3, size: Vector3, yaw: float) -> void:
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	sb.add_child(cs)
	sb.position = center
	sb.rotation.y = yaw
	nav_region.add_child(sb)


static var _bag: Mesh


## One filled sandbag: a squashed, slightly tapered sphere (0.6 x 0.16 x 0.36 m).
static func _bag_mesh() -> Mesh:
	if _bag:
		return _bag
	var sm := SphereMesh.new()
	sm.radial_segments = 14
	sm.rings = 7
	var arr := sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var p := v[i]   # unit sphere, radius 0.5
		var bulge := 1.0 - 0.35 * absf(p.y * 2.0) * absf(p.y * 2.0)   # squared-off pillow sides
		v[i] = Vector3(p.x * 1.22 * bulge, p.y * 0.36, p.z * 0.74 * bulge)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = null
	var st := SurfaceTool.new()
	st.create_from_arrays(arr)
	st.generate_normals()
	_bag = st.commit()
	return _bag


## Tarp-covered car (Poly Haven, 1.79 x 1.41 x 4.38 m, length along local Z).
func car(pos: Vector3, yaw: float, _color := Color.WHITE, _burnt := false) -> void:
	prop("ph:covered_car", pos, yaw, 1.0, true)


## Stack of old tyres lying flat.
func tyres(pos: Vector3, count := 3) -> void:
	blocker(pos + Vector3(0, count * 0.08, 0), Vector3(0.62, count * 0.16, 0.62))
	for i in count:
		var t: Node3D = prop("ph:old_tyre", pos + Vector3(0.02 * i, 0.0, 0.0), 0.0, 1.0, false)
		t.rotation = Vector3(PI / 2.0, i * 0.7, 0)
		t.position.y = 0.08 + i * 0.16


func setup_environment(sky_top: Color, sky_horizon: Color, ground: Color, sun_pitch: float, sun_yaw: float,
		sun_color: Color, sun_energy: float, ambient: float, fog_color: Color, fog_density: float) -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = sky_top
	psm.sky_horizon_color = sky_horizon
	psm.ground_bottom_color = ground
	psm.ground_horizon_color = sky_horizon
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = ambient
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.3
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.0
	env.tonemap_white = 6.0
	env.fog_aerial_perspective = 0.1   # less distance veil (measured washed-out far surfaces)
	env.fog_sun_scatter = 0.04
	env.ssr_max_steps = 48
	env.ssr_fade_out = 1.6
	env.ssil_radius = 4.0
	env.ssil_intensity = 0.9
	env.volumetric_fog_density = volumetric_density
	env.volumetric_fog_albedo = fog_color
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_sky_affect = 0.0
	psm.sun_angle_max = 25.0
	psm.sun_curve = 0.1
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(sun_pitch, sun_yaw, 0)
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.2
	add_child(sun)
	add_to_group("quality_env")
	apply_quality(Settings.quality_params())


# ------------------------------------------------------------------ modular architecture
# Buildings are assembled from Poly Haven modular facade kits (CC0): 3 m wide,
# 3 m tall modules with real window/door openings, separate frames, cornices,
# crowns and plinths. Pieces are batched per mesh into MultiMeshes.

const Kit = preload("res://scripts/maps/kit.gd")
const APARTMENTS := "modular_urban_apartments_facade"
const FACTORY := "modular_factory_facade"
## module key -> [kit, [piece names], module origin inside the kit file]
const MODULES := {
	"apt_wall": [APARTMENTS, ["wall_standard_standard_01"], Vector3(-3, 0, 0)],
	"apt_win_large": [APARTMENTS, ["wall_window_centered_large_01", "window_centered_large_01"], Vector3(8, 4, 0)],
	"apt_win_small": [APARTMENTS, ["wall_window_centered_small_01", "window_centered_small_01"], Vector3(12, 4, 0)],
	"apt_win_double": [APARTMENTS, ["wall_window_centered_double_01", "window_centered_double_01"], Vector3(16, 4, 0)],
	"apt_win_offset": [APARTMENTS, ["wall_window_offset_small_01", "window_offset_small_01"], Vector3(20, 4, 0)],
	"apt_french": [APARTMENTS, ["wall_door_window_small_01", "door_window_small_01"], Vector3(24, 4, 0)],
	"apt_door_large": [APARTMENTS, ["wall_door_centered_large_01", "door_centered_large_01"], Vector3(8, 0, 0)],
	"apt_door_small": [APARTMENTS, ["wall_door_centered_small_01", "door_centered_small_01"], Vector3(12, 0, 0)],
	"apt_crown": [APARTMENTS, ["crown_standard_standard_01"], Vector3(-3, 4, 0)],
	"apt_cornice": [APARTMENTS, ["cornice_standard_standard_01"], Vector3(-3, 3.4, 0)],
	"apt_base": [APARTMENTS, ["base_standard_01"], Vector3(-3, -2, 0)],
	"apt_pier": [APARTMENTS, ["wall_pier_corner_01"], Vector3(-19.925, 0, -0.075)],
	"fac_wall": [FACTORY, ["wall_standard_standard_01"], Vector3(-20, 0, 0)],
	"fac_win_tall": [FACTORY, ["wall_window_tall_large_01", "window_tall_large_01"], Vector3(-12, 4, 0)],
	"fac_win_tall_small": [FACTORY, ["wall_window_tall_small_01", "window_tall_small_01"], Vector3(-4, 4, 0)],
	"fac_win_large": [FACTORY, ["wall_window_centered_large_01", "window_centered_large_01"], Vector3(0, 4, 0)],
	"fac_win_double": [FACTORY, ["wall_window_centered_double_01", "window_centered_double_01"], Vector3(12, 4, 0)],
	"fac_win_medium": [FACTORY, ["wall_window_centered_medium_01", "window_centered_medium_01"], Vector3(4, 4, 0)],
	"fac_door": [FACTORY, ["wall_door_recessed_large_01"], Vector3(8, 0, 0)],
	"fac_garage": [FACTORY, ["wall_door_garage_centered_01"], Vector3(-16, 0, 0)],
	"fac_crown": [FACTORY, ["crown_standard_standard_01"], Vector3(-20, 7, 0)],
	"fac_cornice": [FACTORY, ["cornice01_standard_standard_01"], Vector3(-20, 6, 0)],
	"fac_base": [FACTORY, ["base_standard_standard_01"], Vector3(-20, -2, 0)],
	"fac_pier": [FACTORY, ["cornice02_pier_corner_01"], Vector3(-28.925, 4.98, -0.065)],
	"shutter": ["rollershutter_window_01", ["rollershutter_window_01"], Vector3(-1.5, -0.3, 0)],
	"shutter_graffiti": ["rollershutter_window_01", ["rollershutter_window_01_graffiti"], Vector3(1.5, -0.3, 0)],
}
## per-building style: window palette for upper floors and the ground floor
const STYLES := {
	"apartment": {"prefix": "apt", "upper": ["apt_win_large", "apt_win_double", "apt_win_small", "apt_win_offset"],
		"ground": ["apt_win_small", "apt_wall", "apt_win_large"], "doors": ["apt_door_large", "apt_door_small"], "french": true},
	"shop": {"prefix": "apt", "upper": ["apt_win_large", "apt_win_double", "apt_win_small"],
		"ground": ["apt_win_large"], "doors": ["apt_door_large"], "french": true, "shutters": true},
	"hall": {"prefix": "fac", "upper": ["fac_win_tall", "fac_win_tall_small"],
		"ground": ["fac_wall", "fac_wall", "fac_win_medium"], "doors": ["fac_door"], "french": false},
	"factory": {"prefix": "fac", "upper": ["fac_win_tall", "fac_win_tall_small", "fac_win_large", "fac_win_double", "fac_win_medium"],
		"ground": ["fac_wall", "fac_win_medium", "fac_win_large"], "doors": ["fac_door"], "french": false},
}

var _batch := {}           # Mesh -> {xforms: Array[Transform3D], shadow: bool}
## window opening widths (m) for modules that can be boarded up
const BOARD_WIDTH := {"apt_win_large": 2.1, "apt_win_small": 1.1, "apt_win_double": 2.6, "fac_win_large": 2.2, "fac_win_medium": 1.6}


func _queue(key: String, piece_idx: int, xf: Transform3D, shadow := true) -> void:
	var m: Array = MODULES[key]
	var p := Kit.piece(m[0], m[1][piece_idx])
	if p.is_empty():
		return
	var mesh: Mesh = p.mesh if wall_override == null else _with_walls(p.mesh, wall_override)
	if not _batch.has(mesh):
		_batch[mesh] = {"xforms": [], "shadow": shadow}
	_batch[mesh].xforms.append(xf * Transform3D(Basis(), -m[2]) * p.xf)
	_batch[mesh]["tint"] = _tint


## Places one module (all its pieces) with its kit origin at `xf`.
func module(key: String, xf: Transform3D) -> void:
	var m: Array = MODULES[key]
	for i in m[1].size():
		_queue(key, i, xf, i == 0)   # frames/doors (piece 1) are too small to cast useful shadows


## Flushes queued kit pieces as one MultiMeshInstance3D per mesh (one draw call each).
func flush_kit(view_range := 0.0) -> void:
	for mesh in _batch:
		var xs: Array = _batch[mesh].xforms
		var far_mesh := Kit.lod_mesh(mesh)
		# near: full detail; far (beyond facade_lod_dist): the simplified LOD copy
		for variant in ([mesh] if far_mesh == mesh else [mesh, far_mesh]):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = variant
			mm.instance_count = xs.size()
			for i in xs.size():
				mm.set_instance_transform(i, xs[i])
				mm.set_instance_color(i, _batch[mesh].get("tint", Color.WHITE))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			# facades cast sun shadows only on Epic (a per-building proxy box does it otherwise)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if _batch[mesh].shadow:
				_facade_casters.append(mmi)
			if far_mesh != mesh:
				if variant == mesh:
					mmi.visibility_range_end = facade_lod_dist
				else:
					mmi.visibility_range_begin = facade_lod_dist
			if view_range > 0.0:
				mmi.visibility_range_end = view_range
			decor.add_child(mmi)
	_batch.clear()
	_apply_facade_shadows()


var _facade_casters: Array = []
var facade_lod_dist := 32.0   # near/far facade switch distance (maps may lower it)
## wall-colour variations multiplied into the facade brick/plaster (1 = as scanned)
const FACADE_TINTS := [Color(1, 1, 1), Color(0.82, 0.78, 0.76), Color(1.12, 1.04, 0.94), Color(0.86, 0.9, 0.95),
	Color(1.0, 0.86, 0.78), Color(0.7, 0.68, 0.66)]
var _tint := Color.WHITE
var _tint_override := Color(0, 0, 0, 0)   # alpha > 0: use this wall tint instead of the per-building palette
var wall_override: Material = null          # replaces the kit's brick/plaster wall surfaces (e.g. desert plaster)
static var _overridden := {}


## Copy of `mesh` whose tintable wall surfaces use `mat` (cached per mesh and material).
static func _with_walls(mesh: Mesh, mat: Material) -> Mesh:
	var key := "%s|%s" % [mesh.get_rid().get_id(), mat.get_instance_id()]
	if _overridden.has(key):
		return _overridden[key]
	var out := mesh.duplicate() as Mesh
	for s in out.get_surface_count():
		var m := out.surface_get_material(s) as BaseMaterial3D
		if m and m.vertex_color_use_as_albedo:
			out.surface_set_material(s, mat)
	_overridden[key] = out
	return out
var _hq_shadows := false


func _apply_facade_shadows() -> void:
	for m in _facade_casters:
		(m as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _hq_shadows 			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A whole building on the footprint x0..x1 / z0..z1, `h` tall: collision box
## (same gameplay volume as before), kit facades on the given sides (+Z, +X,
## -Z, -X), dark interior behind the windows, roof slab, crown, piers,
## balconies and an occluder. `rng_seed` picks the window layout.
func facade_building(x0: float, x1: float, z0: float, z1: float, h: float, style := "apartment", rng_seed := 0,
		sides := [true, true, true, true], roof_mat: Material = null, collide := true, damage := 0.0) -> void:
	var st: Dictionary = STYLES[style]
	var pre: String = st.prefix
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	_tint = _tint_override if _tint_override.a > 0.0 else FACADE_TINTS[rng_seed % FACADE_TINTS.size()]
	if collide:
		blocker(Vector3((x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, h, z1 - z0))
	var storeys := maxi(1, roundi(h / 3.0))
	var sy := h / (storeys * 3.0)
	var upper: Array = st.upper
	var main_win: String = upper[rng.randi() % upper.size()]
	var alt_win: String = upper[rng.randi() % upper.size()]
	var cx := (x0 + x1) * 0.5
	var cz := (z0 + z1) * 0.5
	var defs := [[Vector3(0, 0, 1), x1 - x0, Vector3(cx, 0, z1)], [Vector3(1, 0, 0), z1 - z0, Vector3(x1, 0, cz)],
		[Vector3(0, 0, -1), x1 - x0, Vector3(cx, 0, z0)], [Vector3(-1, 0, 0), z1 - z0, Vector3(x0, 0, cz)]]
	for si in 4:
		if not sides[si]:
			continue
		var n: Vector3 = defs[si][0]
		var length: float = defs[si][1]
		var along := Vector3.UP.cross(n)
		var start: Vector3 = defs[si][2] - along * length * 0.5
		var basis := Basis(along, Vector3.UP, n)
		var count := maxi(1, roundi(length / 3.0))
		var sx := length / (count * 3.0)
		var door_at := count / 2
		for i in count:
			var o0 := start + along * (i * 3.0 * sx)
			var band := Basis(along * sx, Vector3.UP, n)
			module(pre + "_crown", Transform3D(band, o0 + Vector3(0, h, 0)))
			module(pre + "_base", Transform3D(band, o0))
			for s in storeys:
				var key: String
				var r := rng.randf()
				if s == 0:
					key = st.doors[rng.randi() % st.doors.size()] if i == door_at else st.ground[rng.randi() % st.ground.size()]
				else:
					key = main_win if r < 0.7 else (alt_win if r < 0.85 else pre + "_wall")
					if st.french and r > 0.93:
						key = "apt_french"
				var o := o0 + Vector3(0, s * 3.0 * sy, 0)
				module(key, Transform3D(Basis(along * sx, Vector3.UP * sy, n), o))
				if s == 0 and st.get("shutters", false) and key == "apt_win_large" and rng.randf() < 0.75:
					module("shutter_graffiti" if rng.randf() < 0.4 else "shutter", Transform3D(Basis(along * sx, Vector3.UP * sy, n), o))
				elif s == 0 and BOARD_WIDTH.has(key) and rng.randf() < damage:
					boarded(o + along * 1.5 * sx + Vector3(0, 1.2 * sy, 0), n, BOARD_WIDTH[key] * sx, 2.3 * sy, rng.randi())
				if rng.randf() < 0.05 + damage * 0.08:
					wall_decal(["Leaking003", "Leaking008"][rng.randi() % 2], o + along * 1.5 * sx + Vector3(0, 1.6 * sy, 0) + n * 0.05,
						n, rng.randf_range(2.0, 3.0) * sx, rng.randf_range(2.4, 3.0) * sy, Color(1, 1, 1, rng.randf_range(0.6, 0.95)))
				if key == "apt_french":
					balcony(o + along * 1.5 * sx + n * 0.55, basis, 2.6 * sx)
				if s >= 1:
					module(pre + "_cornice", Transform3D(band, o))
		flush_kit()   # one batch per side: the building's own occluder hides its far sides
	for c in [Vector3(x0, 0, z0), Vector3(x1, 0, z0), Vector3(x0, 0, z1), Vector3(x1, 0, z1)]:
		module(pre + "_pier", Transform3D(Basis().scaled(Vector3(1, h / 3.0, 1)), c))
	# dark interior seen through the window openings, roof slab, occluder
	var inset := minf(1.2, minf(x1 - x0, z1 - z0) * 0.6)
	var interior := box(Vector3(cx, h * 0.5, cz), Vector3(x1 - x0 - inset, h - 0.1, z1 - z0 - inset),
		Mats.flat(Color(0.05, 0.05, 0.055), 0.95), false) as GeometryInstance3D
	interior.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	box(Vector3(cx, h - 0.05, cz), Vector3(x1 - x0 - 0.05, 0.12, z1 - z0 - 0.05),
		roof_mat if roof_mat else Mats.concrete(Color(0.45, 0.45, 0.44), 3.0), false)
	var occ := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(maxf(x1 - x0 - 1.4, 0.3), h - 0.4, maxf(z1 - z0 - 1.4, 0.3))
	occ.occluder = bo
	occ.position = Vector3(cx, h * 0.5, cz)
	decor.add_child(occ)
	var proxy := box(Vector3(cx, h * 0.5, cz), Vector3(x1 - x0, h, z1 - z0), Mats.flat(Color.GRAY), false) as GeometryInstance3D
	proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	flush_kit()   # one batch per building so frustum and occlusion culling work per building


## Concrete balcony slab with a steel railing (visual only; above head height).
func balcony(center: Vector3, b: Basis, width: float) -> void:
	var slab := MeshInstance3D.new()
	slab.mesh = _box_mesh(Vector3(width, 0.14, 1.1))
	slab.material_override = Mats.concrete(Color(0.6, 0.59, 0.57), 2.0, false)
	slab.transform = Transform3D(b, center + Vector3(0, 0.07, 0))
	decor.add_child(slab)
	var rail := Mats.painted_metal(Color(0.12, 0.12, 0.12))
	for k in [-0.5, 0.5]:
		var p: Vector3 = center + b.x * width * k - b.z * 0.5
		_rail_bar(p, p + b.z * 1.05, rail, 0.95)
	_rail_bar(center - b.x * width * 0.5 + b.z * 0.52, center + b.x * width * 0.5 + b.z * 0.52, rail, 0.95)


func _rail_bar(a: Vector3, b2: Vector3, mat: Material, height: float) -> void:
	var length := a.distance_to(b2)
	var dir := (b2 - a).normalized()
	var top := MeshInstance3D.new()
	top.mesh = _box_mesh(Vector3(0.05, 0.05, length))
	top.material_override = mat
	top.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), (a + b2) * 0.5 + Vector3(0, height, 0))
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(top)
	var bars := maxi(2, int(length / 0.14))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _box_mesh(Vector3(0.018, height, 0.018))
	mm.instance_count = bars + 1
	for i in bars + 1:
		mm.set_instance_transform(i, Transform3D(Basis(), a.lerp(b2, float(i) / bars) + Vector3(0, height * 0.5, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mmi)


# ------------------------------------------------------------------ environment detail

static var _decal_tex := {}


## Projected decal (ambientCG CC0 colour + opacity merged to RGBA, plus normal map).
## `size` is the projector box (x, depth, z); the decal projects along its local -Y.
func decal(id: String, xf: Transform3D, size: Vector3, modulate := Color.WHITE, fade := 60.0) -> void:
	if not _decal_tex.has(id):
		var dir := Mats.acg_dir(id)
		_decal_tex[id] = [load(dir.get_base_dir() + "/%s_Decal.png" % id), load(dir + "NormalGL.jpg")]
	var d := Decal.new()
	d.texture_albedo = _decal_tex[id][0]
	d.texture_normal = _decal_tex[id][1]
	d.size = size
	d.modulate = modulate
	d.normal_fade = 0.3
	d.distance_fade_enabled = true
	d.distance_fade_begin = fade
	d.distance_fade_length = 10.0
	d.cull_mask = 1
	d.transform = xf
	decor.add_child(d)


## Decal on a vertical wall facing `normal`, centred at `pos`.
func wall_decal(id: String, pos: Vector3, normal: Vector3, w: float, h: float, modulate := Color.WHITE) -> void:
	# decals project along local -Y, so +Y points out of the wall; image top stays up
	var x := Vector3.UP.cross(normal).normalized()
	decal(id, Transform3D(Basis(x, normal, x.cross(normal)), pos), Vector3(w, 0.6, h), modulate)


## Decal lying on the ground.
func ground_decal(id: String, pos: Vector3, yaw: float, w: float, l: float, modulate := Color.WHITE) -> void:
	decal(id, Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, 0.1, 0)), Vector3(w, 0.5, l), modulate)


static var _chunks: Array = []


## A few irregular broken-concrete chunk meshes (jittered low-poly spheres, flat
## bottoms, smooth normals) shared by every debris scatter.
static func _chunk_meshes() -> Array:
	if not _chunks.is_empty():
		return _chunks
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for v in 5:
		var sm := SphereMesh.new()
		sm.radial_segments = 7
		sm.rings = 4
		var arr := sm.get_mesh_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var jitter := {}
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var squash := Vector3(rng.randf_range(0.8, 1.4), rng.randf_range(0.45, 0.8), rng.randf_range(0.7, 1.2))
		for i in idx:
			var p: Vector3 = verts[i]
			var key := p.snapped(Vector3.ONE * 0.001)
			if not jitter.has(key):
				jitter[key] = Vector3(rng.randf_range(-0.18, 0.18), rng.randf_range(-0.12, 0.12), rng.randf_range(-0.18, 0.18))
			var q: Vector3 = (p + jitter[key]) * squash
			q.y = maxf(q.y, -0.15)
			st.add_vertex(q)
		st.generate_normals()
		_chunks.append(st.commit())
	return _chunks


## Scatter of concrete/brick debris chunks (MultiMesh per chunk shape, no collision).
func debris(center: Vector3, radius: float, count: int, min_size: float, max_size: float, mat: Material, rng_seed := 1) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var meshes := _chunk_meshes()
	var per: Array = []
	for m in meshes:
		per.append([])
	for i in count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * radius
		var s := rng.randf_range(min_size, max_size)
		var p := center + Vector3(cos(a) * r, s * 0.12, sin(a) * r)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		per[i % meshes.size()].append(Transform3D(b.scaled(Vector3.ONE * s), p))
	for k in meshes.size():
		var xs: Array = per[k]
		if xs.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.visibility_range_end = 70.0
		if max_size < 0.35:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor.add_child(mmi)


## Rubble heap against a wall: a low mound of large broken slabs and chunks
## with smaller debris around it. Collision is a low box so it stays walkable
## around but does not block lanes (keep `size` modest).
func rubble(center: Vector3, size: Vector3, rng_seed := 1, collide := true) -> void:
	var mat := Mats.acg("Concrete044D", 1.6, Color(0.82, 0.8, 0.77))
	debris(center, maxf(size.x, size.z) * 0.45, 26, 0.35, 0.9, mat, rng_seed)
	debris(center, maxf(size.x, size.z) * 0.8, 60, 0.08, 0.3, mat, rng_seed + 7)
	var brick := Mats.acg("Bricks076C", 1.2, Color(0.9, 0.85, 0.8))
	debris(center, maxf(size.x, size.z) * 0.7, 24, 0.12, 0.3, brick, rng_seed + 13)
	var mound := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radial_segments = 12
	sm.rings = 6
	mound.mesh = sm
	mound.material_override = Mats.acg("Ground108", 2.0)
	mound.scale = Vector3(size.x * 0.5, size.y, size.z * 0.5)
	mound.position = center
	decor.add_child(mound)
	if collide:
		blocker(center + Vector3(0, size.y * 0.3, 0), Vector3(size.x * 0.6, size.y * 0.6, size.z * 0.6))


## Sagging overhead cable between two anchor points (catenary-like parabola).
func wire(a: Vector3, b: Vector3, sag := 0.8, thickness := 0.018, mat: Material = null) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 16
	var pts: Array = []
	for i in segs + 1:
		var t := float(i) / segs
		pts.append(a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0))
	for i in segs:
		var p0: Vector3 = pts[i]
		var p1: Vector3 = pts[i + 1]
		var d := (p1 - p0).normalized()
		var side := d.cross(Vector3.UP).normalized() * thickness
		var up := side.cross(d).normalized() * thickness
		for q in [[side, up], [up, -side], [-side, -up], [-up, side]]:
			var o0: Vector3 = q[0]
			var o1: Vector3 = q[1]
			st.add_vertex(p0 + o0); st.add_vertex(p1 + o0); st.add_vertex(p1 + o1)
			st.add_vertex(p0 + o0); st.add_vertex(p1 + o1); st.add_vertex(p0 + o1)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat if mat else Mats.flat(Color(0.04, 0.04, 0.04), 0.6)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mi)


## Raised sidewalk slab (paving top, granite kerb on the road edges). The
## collision top is flat at `h` with 45-degree chamfers along the kerbs so the
## player (capsule or prone box) and bots step up without a ledge.
func sidewalk(x0: float, x1: float, z0: float, z1: float, h: float, kerbs: Array, paving: Material, kerb_mat: Material) -> void:
	floor_plane(Vector3((x0 + x1) * 0.5, h, (z0 + z1) * 0.5), Vector2(x1 - x0, z1 - z0), paving.resource_name, 1.6, paving.albedo_color)
	var sb := StaticBody3D.new()
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(x1 - x0, h, z1 - z0)
	cs.shape = bs
	cs.position = Vector3((x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5)
	sb.add_child(cs)
	nav_region.add_child(sb)
	# kerbs: [axis, coordinate, from, to, outward sign]
	for k in kerbs:
		var along_x: bool = k[0] == "x"
		var c: float = k[1]
		var a: float = k[2]
		var b: float = k[3]
		var s: float = k[4]
		var length := b - a
		var mid := (a + b) * 0.5
		var kerb_center := Vector3(mid, h * 0.5 + 0.005, c - s * 0.12) if along_x else Vector3(c - s * 0.12, h * 0.5 + 0.005, mid)
		var kerb_size := Vector3(length, h + 0.01, 0.25) if along_x else Vector3(0.25, h + 0.01, length)
		box(kerb_center, kerb_size, kerb_mat, false)
		var wedge := ConvexPolygonShape3D.new()
		var pts := PackedVector3Array()
		for e in [-0.5, 0.5]:
			var t: float = mid + e * length
			if along_x:
				pts.append_array([Vector3(t, 0, c + s * h), Vector3(t, 0, c), Vector3(t, h, c)])
			else:
				pts.append_array([Vector3(c + s * h, 0, t), Vector3(c, 0, t), Vector3(c, h, t)])
		wedge.points = pts
		var wc := CollisionShape3D.new()
		wc.shape = wedge
		sb.add_child(wc)


## Wooden planks nailed over a ground-floor opening (wall plane at `center`, facing `normal`).
func boarded(center: Vector3, normal: Vector3, w: float, h: float, rng_seed := 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var along := Vector3.UP.cross(normal).normalized()
	var wood := Mats.acg("Planks023A", 1.5, Color(0.8, 0.74, 0.66))
	for i in 5:
		var y := -h * 0.4 + i * h * 0.2 + rng.randf_range(-0.05, 0.05)
		var tilt := rng.randf_range(-0.25, 0.25)
		var b := Basis(along, Vector3.UP, normal) * Basis(Vector3.BACK, tilt)
		var mi := MeshInstance3D.new()
		mi.mesh = _box_mesh(Vector3(w + 0.3, 0.2, 0.035))
		mi.material_override = wood
		mi.transform = Transform3D(b, center + Vector3(0, y, 0) + normal * (0.06 + i * 0.012))
		decor.add_child(mi)


## Wooden electricity pole assembled from one of the kit's presets ("preset_01_".."03"),
## standing at `pos`, cross-arm turned to `yaw`. Returns the world positions of the
## top of the pole (for hanging wires). Thin collision post.
func power_pole(preset: String, pos: Vector3, yaw: float) -> Vector3:
	var kit := "modular_electricity_poles"
	var names: Array = Kit.names(kit, preset)
	var pole: Dictionary = Kit.piece(kit, preset + "pole")
	var aabb: AABB = pole.xf * (pole.mesh as Mesh).get_aabb()
	var origin := Vector3(aabb.get_center().x, 0.0, aabb.get_center().z)
	var base := Transform3D(Basis(Vector3.UP, yaw), pos) * Transform3D(Basis(), -origin)
	for nm in names:
		var p: Dictionary = Kit.piece(kit, nm)
		var mi := MeshInstance3D.new()
		mi.mesh = p.mesh
		mi.transform = base * p.xf
		mi.visibility_range_end = 110.0
		decor.add_child(mi)
	blocker(pos + Vector3(0, 1.5, 0), Vector3(0.3, 3.0, 0.3))
	return pos + Vector3(0, aabb.size.y - 0.5, 0)


## Flat floor surface (visual) at height `y`: UV-mapped plane, no triplanar cost.
func floor_plane(center: Vector3, size: Vector2, id: String, tile: float, tint := Color.WHITE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	mi.mesh = pm
	mi.material_override = Mats.acg_planar(id, tile, size, tint)
	mi.position = center
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mi)
	return mi


# ------------------------------------------------------------------ industrial structure

var _struts := {}   # Material -> Array[Transform3D] (unit-box members, batched)


## Queues a straight steel member of square section `t` from `a` to `b`.
func strut(a: Vector3, b: Vector3, t: float, mat: Material) -> void:
	var d := b - a
	var up := Vector3.UP if absf(d.normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(d.normalized(), up).scaled_local(Vector3(t, t, d.length()))
	if not _struts.has(mat):
		_struts[mat] = []
	_struts[mat].append(Transform3D(basis, (a + b) * 0.5))


## Queues an I-beam (two flanges + web) from `a` to `b`; `h` deep, `w` wide, web vertical
## (or along X for vertical columns).
func ibeam(a: Vector3, b: Vector3, h: float, w: float, mat: Material) -> void:
	var d := (b - a).normalized()
	var side := d.cross(Vector3.UP).normalized() if absf(d.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var up := side.cross(d).normalized()
	var f := 0.025
	for s in [-1.0, 1.0]:
		var o: Vector3 = up * (h * 0.5 - f * 0.5) * s
		_member(a + o, b + o, Vector3(w, f, 0.0), side, up, mat)
	_member(a, b, Vector3(0.018, h - f * 2.0, 0.0), side, up, mat)


func _member(a: Vector3, b: Vector3, section: Vector3, side: Vector3, up: Vector3, mat: Material) -> void:
	var d := b - a
	var basis := Basis(side * section.x, up * section.y, d)
	if not _struts.has(mat):
		_struts[mat] = []
	_struts[mat].append(Transform3D(basis, (a + b) * 0.5))


func flush_struts() -> void:
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	for mat in _struts:
		var xs: Array = _struts[mat]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = mat
		decor.add_child(mmi)
	_struts.clear()


## Pratt roof truss spanning from `a` to `b` (same height), `depth` deep, panels ~`panel` m.
func truss(a: Vector3, b: Vector3, depth: float, panel: float, mat: Material) -> void:
	var n := maxi(2, roundi(a.distance_to(b) / panel))
	var top := Vector3(0, depth, 0)
	ibeam(a, b, 0.22, 0.14, mat)
	ibeam(a + top, b + top, 0.22, 0.14, mat)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		strut(p, p + top, 0.08, mat)
		if i < n:
			var q := a.lerp(b, float(i + 1) / n)
			if i < n / 2:
				strut(p + top, q, 0.07, mat)
			else:
				strut(p, q + top, 0.07, mat)


## Run of rectangular air duct (Poly Haven kit, 1.8 m segments) hung with wire braces.
func duct_run(a: Vector3, b: Vector3) -> void:
	var kit := "modular_airduct_rectangular_01"
	var seg := Kit.piece(kit, "modular_airduct_rectangular_01_tripple_01")
	var brace := Kit.piece(kit, "modular_airduct_rectangular_01_brace_wire_01")
	var d := b - a
	var count := maxi(1, int(d.length() / 1.8))
	var yaw := atan2(d.x, d.z)
	var seg_origin := Vector3(-1.0, 0.0, -0.15)   # piece centre inside the kit file
	var brace_origin := Vector3(-1.0, -0.0, 0.95)
	for i in count:
		var c := a + d.normalized() * (0.9 + i * 1.8)
		var xf := Transform3D(Basis(Vector3.UP, yaw), c)
		_queue_piece({"mesh": Kit.lod_mesh(seg.mesh, 0.3), "xf": seg.xf}, xf * Transform3D(Basis(), -seg_origin), true)   # seen from 7 m below
		_queue_piece(brace, xf * Transform3D(Basis(), -brace_origin), false)
	flush_kit()


func _queue_piece(p: Dictionary, xf: Transform3D, shadow: bool) -> void:
	if p.is_empty():
		return
	var mesh: Mesh = p.mesh
	if not _batch.has(mesh):
		_batch[mesh] = {"xforms": [], "shadow": shadow}
	_batch[mesh].xforms.append(xf * p.xf)


## Steel pipe along a polyline with flanges at joints and wall brackets.
func pipe(points: Array, radius: float, mat: Material) -> void:
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = a.distance_to(b)
		cm.radial_segments = 12
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = mat
		var d := (b - a).normalized()
		var x := d.cross(Vector3.FORWARD if absf(d.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
		mi.transform = Transform3D(Basis(x, d, x.cross(d)), (a + b) * 0.5)
		decor.add_child(mi)
		var flange := MeshInstance3D.new()
		var fm := CylinderMesh.new()
		fm.top_radius = radius * 1.6
		fm.bottom_radius = radius * 1.6
		fm.height = 0.05
		fm.radial_segments = 12
		flange.mesh = fm
		flange.material_override = mat
		flange.transform = Transform3D(Basis(x, d, x.cross(d)), b)
		decor.add_child(flange)


## Wooden pallet (1.2 x 0.8 m, 0.15 m tall): deck boards on three runners.
func pallet(pos: Vector3, yaw: float, wood: Material) -> void:
	var b := Basis(Vector3.UP, yaw)
	for z in [-0.35, 0.0, 0.35]:
		strut(pos + b * Vector3(-0.6, 0.05, z), pos + b * Vector3(0.6, 0.05, z), 0.1, wood)
	for i in 7:
		var x := -0.54 + i * 0.18
		var p := pos + b * Vector3(x, 0.125, 0)
		_member(p - b * Vector3(0, 0, 0.4), p + b * Vector3(0, 0, 0.4), Vector3(0.12, 0.022, 0), b.x, Vector3.UP, wood)


## See-through steel floor grating (ambientCG MetalWalkway014, alpha-tested).
static func grating() -> StandardMaterial3D:
	var m := Mats.acg("MetalWalkway014", 1.0).duplicate() as StandardMaterial3D
	m.albedo_texture = load("res://assets/downloads/warehouse/materials/MetalWalkway014/MetalWalkway014_ColorAlpha.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Open steel railing (posts, top and mid rail, toe board) with an invisible collision box.
func open_railing(a: Vector3, b: Vector3, mat: Material, height := 1.05) -> void:
	var flat := b - a
	var yaw := atan2(-flat.x, -flat.z)
	_rot_blocker((a + b) * 0.5 + Vector3(0, height * 0.5, 0), Vector3(0.08, height, flat.length()), yaw)
	var posts := maxi(1, int(flat.length() / 1.5))
	for i in posts + 1:
		var p := a.lerp(b, float(i) / posts)
		strut(p, p + Vector3(0, height, 0), 0.05, mat)
	strut(a + Vector3(0, height, 0), b + Vector3(0, height, 0), 0.05, mat)
	strut(a + Vector3(0, height * 0.5, 0), b + Vector3(0, height * 0.5, 0), 0.035, mat)
	strut(a + Vector3(0, 0.06, 0), b + Vector3(0, 0.06, 0), 0.12, mat)
