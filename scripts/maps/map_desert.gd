extends "res://scripts/maps/map_base.gd"
## MAP 3 - DESERT OUTPOST
## 96 x 96 m desert with a fortified compound (HESCO walls, four gates, command
## post, barracks, fuel depot) and four climbable watchtowers. Open terrain with
## rocks and wrecks gives long sightlines for the sniper rifle.
## Generated heightmap terrain (flat play field, sand ridges over the berms,
## dunes and rocky hills beyond), scanned Namaqualand boulders and cliffs,
## segmented HESCO cells, stacked sandbags, dry vegetation and haze. Collision
## volumes, cover and spawns are unchanged from the original layout.

const PLAY := 46.0   # half-size of the flat play field


func build() -> void:
	vision_range = 85.0
	preferred_range = 24.0
	ambient_sound = "ambient_wind"
	volumetric_density = 0.006
	setup_environment(Color(0.3, 0.52, 0.82), Color(0.9, 0.82, 0.68), Color(0.5, 0.42, 0.3),
		-40.0, 40.0, Color(1.0, 0.88, 0.7), 1.9, 0.7, Color(0.86, 0.78, 0.64), 0.003)
	env.tonemap_exposure = 0.95

	var sand := Mats.acg("Ground080", 5.0, Color(0.95, 0.88, 0.76))
	box(Vector3(0, -0.25, 0), Vector3(112, 0.5, 112), sand).get_child(1).visible = false
	for w in [[-49, 49, 48, 49], [-49, 49, -49, -48], [-49, -48, -48, 48], [48, 49, -48, 48]]:
		block(w[0], w[1], w[2], w[3], 4.0, sand).visible = false   # berm collision, terrain ridge is the visual
	terrain(sand)
	# scanned cliffs on the hills and boulder fields outside the berms (visual only)
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 14:
		var a := float(i) / 14.0 * TAU + rng.randf_range(-0.1, 0.1)
		var r := rng.randf_range(78.0, 96.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = _height(p.x, p.z) - 1.0
		prop("ph:namaqualand_cliff_02" if i % 2 == 0 else "ph:namaqualand_cliff_01", p, rng.randf() * TAU,
			rng.randf_range(1.6, 2.6), false, Vector3.ZERO, 0.0, true)
	for i in 30:
		var a := rng.randf() * TAU
		var r := rng.randf_range(53.0, 70.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		p.y = _height(p.x, p.z) - 0.2
		prop(["ph:namaqualand_boulder_04", "ph:namaqualand_boulder_02", "ph:namaqualand_boulder_05"][i % 3], p,
			rng.randf() * TAU, rng.randf_range(0.8, 2.2), false, Vector3.ZERO, 140.0, true)

	# compound perimeter: HESCO barriers with four gates (collision unchanged)
	for s in [-1.0, 1.0]:
		hesco_wall(-22.6, -3, s * 22 - 0.6, s * 22 + 0.6, 1.4)
		hesco_wall(3, 22.6, s * 22 - 0.6, s * 22 + 0.6, 1.4)
		hesco_wall(s * 22 - 0.6, s * 22 + 0.6, -21.4, -3, 1.4)
		hesco_wall(s * 22 - 0.6, s * 22 + 0.6, 3, 21.4, 1.4)

	# watchtowers (stairs lead into the compound)
	tower(Vector3(19, 0, 19), Vector3(-1, 0, 0))
	tower(Vector3(-19, 0, 19), Vector3(1, 0, 0))
	tower(Vector3(19, 0, -19), Vector3(-1, 0, 0))
	tower(Vector3(-19, 0, -19), Vector3(1, 0, 0))

	# buildings: plastered blocks built from the factory kit, sand-tinted, flat roofs
	var roof := Mats.acg("Concrete044D", 3.0, Color(0.82, 0.76, 0.66))
	var plaster := Mats.acg("Plaster001", 2.5, Color(0.92, 0.8, 0.64)).duplicate() as StandardMaterial3D
	plaster.vertex_color_use_as_albedo = true   # still takes the MultiMesh tint
	wall_override = plaster
	_tint_override = Color(1.0, 0.97, 0.92)
	facade_building(-6, 6, -4, 4, 3.6, "factory", 301, [true, true, true, true], roof, true, 0.2)
	facade_building(-17, -3, -14, -8, 3.5, "factory", 302, [true, true, true, true], roof, true, 0.3)
	facade_building(3, 17, 8, 14, 3.5, "factory", 303, [true, true, true, true], roof, true, 0.3)
	facade_building(8, 14, -14, -9, 3.0, "factory", 304, [true, true, true, true], roof, true, 0.4)
	_tint_override = Color(0, 0, 0, 0)
	wall_override = null
	block(-6.2, 6.2, -4.2, 4.2, 0.4, roof, 3.6)   # command post: parapet slab (old height 4.0 kept)
	box(Vector3(3, 5.2, 0), Vector3(0.12, 2.4, 0.12), Mats.painted_metal(Color(0.3, 0.3, 0.3)), false)   # antenna
	sandbags(Vector3(-4.5, 4.0, 3.6), 3.0, 0.0, 0.5)
	# fuel depot
	var tank := Mats.painted_metal(Color(0.5, 0.52, 0.42))
	for x in [-13.0, -9.6]:
		cylinder(Vector3(x, 0, 11), 1.3, 2.6, tank)
		for y in [0.4, 2.2]:
			cylinder(Vector3(x, y, 11), 1.33, 0.08, Mats.painted_metal(Color(0.3, 0.3, 0.28)), false)
	sandbags(Vector3(-11.3, 0, 14.0), 6.0)

	# compound cover
	sandbags(Vector3(0, 0, 8), 4.0)
	sandbags(Vector3(0, 0, -8), 4.0)
	sandbags(Vector3(-11, 0, 3), 3.0, PI / 2.0)
	sandbags(Vector3(11, 0, -3), 3.0, PI / 2.0)
	jersey(Vector3(0, 0, 17))
	jersey(Vector3(0, 0, -17))
	jersey(Vector3(17, 0, 0), PI / 2.0)
	jersey(Vector3(-17, 0, 0), PI / 2.0)
	for p in [Vector3(-14, 0, -3), Vector3(-12.7, 0, -3), Vector3(13, 0, 3), Vector3(5, 0, -16),
			Vector3(-5, 0, 16), Vector3(16, 0, -5.5)]:
		crate(p)
	truck(Vector3(-12, 0, 6.5), PI / 2.0)
	truck(Vector3(12.5, 0, 15.9), -PI / 2.0 + 0.05)

	# outside: scanned boulders over the old rock collision boxes, wrecks, ruins and checkpoints
	for r in [[30, 10, 4.5, 2.4, 3.5, 0.3], [-32, -12, 5.0, 2.8, 3.0, 1.1], [10, 34, 3.5, 2.0, 4.0, 0.7],
			[-14, -34, 4.0, 2.2, 3.0, 2.0], [36, -30, 5.5, 3.0, 4.0, 0.5], [-36, 32, 4.0, 2.6, 5.0, 1.4],
			[26, -40, 3.0, 1.8, 3.0, 0.2], [-28, 41, 3.5, 2.0, 2.5, 0.9], [40, 24, 3.0, 1.6, 3.0, 1.9],
			[-41, -36, 4.0, 2.0, 3.0, 0.4], [-40, 6, 2.5, 1.6, 2.5, 0.8], [6, -40, 3.0, 1.5, 2.0, 1.2]]:
		box(Vector3(r[0], r[3] * 0.5 - 0.1, r[1]), Vector3(r[2], r[3], r[4]), sand, true, r[5]).get_child(1).visible = false
		var size := Vector3(r[2] * 1.08, r[3] * 1.05, r[4] * 1.08)
		var main: Node3D = prop("ph:namaqualand_boulder_04", Vector3(r[0], -0.15, r[1]), r[5], 1.0, false, size, 160.0)
		main.rotation.y = r[5]
		var side: Node3D = prop("ph:namaqualand_boulder_02", Vector3(r[0], -0.1, r[1]) + Basis(Vector3.UP, r[5]) * Vector3(r[2] * 0.45, 0, -r[4] * 0.3),
			r[5] + 0.9, 1.0, false, Vector3(r[2] * 0.6, r[3] * 0.45, r[4] * 0.6), 120.0)
		side.rotation.y = r[5] + 0.9
	car(Vector3(-26, 0, 20), 0.6)
	car(Vector3(28, 0, -18), -0.9)
	truck(Vector3(-4, 0, 38), 0.3)
	var ruin := Mats.acg("Plaster001", 2.0, Color(0.8, 0.7, 0.56))
	block(30, 38, 36, 36.5, 2.6, ruin)
	block(30, 30.5, 30, 36, 1.8, ruin)
	block(-38, -32, -26, -25.5, 2.2, ruin)
	block(-32.5, -32, -26, -21, 1.5, ruin)
	rubble(Vector3(33.5, 0, 34.8), Vector3(3.0, 0.7, 2.0), 61)
	rubble(Vector3(-34.5, 0, -24.4), Vector3(2.6, 0.6, 2.0), 62)
	for z in [-33.0, 33.0]:
		jersey(Vector3(-3.5, 0, z))
		jersey(Vector3(3.5, 0, z))
	for x in [-33.0, 33.0]:
		jersey(Vector3(x, 0, -3.5), PI / 2.0)
		jersey(Vector3(x, 0, 3.5), PI / 2.0)
	sandbags(Vector3(40, 0, 40), 4.0, PI / 4.0)
	sandbags(Vector3(-40, 0, -40), 4.0, PI / 4.0)

	# CC0 detail: fuel drums, tyres, a gas tank at the depot; vegetation and stones
	for p in [Vector3(-15.5, 0, 9.0), Vector3(-15.2, 0, 13.0), Vector3(15, 0, -15.5), Vector3(-24.5, 0, 25), Vector3(26, 0, -24)]:
		barrel(p)
	for p in [Vector3(-7.5, 0, 12.6), Vector3(-7.0, 0, 13.1), Vector3(-7.9, 0, 13.2)]:
		prop("ph:propane_tank", p, p.x, 1.0, true, Vector3.ZERO, 50.0)
	tyres(Vector3(24, 0, 12), 3)
	tyres(Vector3(-25, 0, -14), 4)
	for p in [Vector3(-5.6, 0, -16.6), Vector3(5.3, 0, 16.5), Vector3(15.6, 0, -14.6)]:
		prop("ph:metal_jerrycan", p, p.z, 1.0, false, Vector3.ZERO, 40.0)
	for p in [Vector3(-9, 0, -40.5), Vector3(-10.6, 0, -40.5)]:
		prop("ph:concrete_road_barrier_02", p, 0.0, 1.0, true)
	for p in [Vector3(40.5, 0, 12), Vector3(40.5, 0, 13.6)]:
		prop("ph:concrete_road_barrier_02", p, PI / 2.0, 1.0, true)
	vegetation(rng)
	flush_kit()

	player_spawns = [[Vector3(0, 0, -43), 0.0], [Vector3(43, 0, 0), 0.0], [Vector3(-43, 0, 0), 0.0], [Vector3(0, 0, 43), 0.0]]
	bot_spawns = [Vector3(0, 0, 30), Vector3(32, 0, 30), Vector3(-30, 0, -30), Vector3(34, 0, -8),
		Vector3(-34, 0, 12), Vector3(0, 0, -6), Vector3(10, 0, 4), Vector3(19, 5.0, 19),
		Vector3(-19, 5.0, -19), Vector3(30, 0, -34), Vector3(-30, 0, 34), Vector3(-8, 0, -6)]
	patrol_points = bot_spawns + [Vector3(0, 0, 20), Vector3(0, 0, -20), Vector3(20, 0, 0), Vector3(-20, 0, 0),
		Vector3(-19, 5.0, 19), Vector3(19, 5.0, -19), Vector3(25, 0, 25), Vector3(-25, 0, -25), Vector3(-8, 0, -6)]


## Terrain height: flat play field, a sand ridge over the berms (crest ~4.5 m at
## 48.5 m), rolling dunes beyond and hills rising toward the horizon.
var _noise: FastNoiseLite


func _height(x: float, z: float) -> float:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 77
		_noise.frequency = 0.018
		_noise.fractal_octaves = 4
	var d := maxf(absf(x), absf(z))
	if d <= PLAY:
		return 0.0
	var n := _noise.get_noise_2d(x, z)
	var ridge := 4.6 * exp(-pow((d - 48.5) / 2.6, 2.0))
	var outer := smoothstep(PLAY, 56.0, d)
	var dunes := (n * 0.5 + 0.5) * 6.0 * outer
	var hills := pow(smoothstep(60.0, 120.0, d), 1.5) * 26.0 * (0.75 + 0.5 * n)
	return maxf(ridge + dunes + hills, 0.0) * smoothstep(PLAY, PLAY + 1.5, d)


## Generated terrain mesh (2 m grid, 240 m square) with world-space UVs.
func terrain(mat: StandardMaterial3D) -> void:
	var half := 120.0
	var step := 2.0
	var n := int(half * 2.0 / step)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n + 1:
		for i in n + 1:
			var x := -half + i * step
			var z := -half + j * step
			st.set_uv(Vector2(x, z) / 5.0)
			st.add_vertex(Vector3(x, _height(x, z), z))
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			st.add_index(a); st.add_index(a + 1); st.add_index(a + n + 1)
			st.add_index(a + 1); st.add_index(a + n + 2); st.add_index(a + n + 1)
	st.generate_normals()
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := mat.duplicate() as StandardMaterial3D
	m.uv1_triplanar = false
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3.ONE
	m.metallic_specular = 0.2
	mi.material_override = m
	decor.add_child(mi)


## HESCO bastion wall: 1.05 m wire-mesh cells (sand-filled fabric liner, steel
## mesh posts, sand showing on top). Collision box unchanged.
func hesco_wall(x0: float, x1: float, z0: float, z1: float, h: float) -> void:
	blocker(Vector3((x0 + x1) * 0.5, h * 0.5, (z0 + z1) * 0.5), Vector3(x1 - x0, h, z1 - z0))
	var along_x := (x1 - x0) > (z1 - z0)
	var length := (x1 - x0) if along_x else (z1 - z0)
	var depth := (z1 - z0) if along_x else (x1 - x0)
	var cells := maxi(1, roundi(length / 1.05))
	var cw := length / cells
	var liner := Mats.hesco()
	var post := Mats.painted_metal(Color(0.42, 0.4, 0.34))
	var top := Mats.acg("Ground080", 2.0, Color(0.9, 0.82, 0.68))
	for i in cells:
		var t := (x0 if along_x else z0) + cw * (i + 0.5)
		var c := Vector3(t, h * 0.5, (z0 + z1) * 0.5) if along_x else Vector3((x0 + x1) * 0.5, h * 0.5, t)
		var size := Vector3(cw - 0.04, h, depth) if along_x else Vector3(depth, h, cw - 0.04)
		var sag := Vector3(0.0, -0.04 * float(i % 3), 0.0)
		box(c + sag * 0.5, size + sag, liner, false)
		box(c + Vector3(0, h * 0.5 - 0.02, 0) + sag, Vector3(size.x - 0.08, 0.06, size.z - 0.08), top, false)
		for e in [-0.5, 0.5]:
			for f in [-0.5, 0.5]:
				var off := Vector3(cw * e, 0, depth * f) if along_x else Vector3(depth * f, 0, cw * e)
				strut(Vector3(c.x, 0, c.z) + off, Vector3(c.x, h + 0.02, c.z) + off, 0.035, post)
	flush_struts()


## Scattered dry bushes, dead quiver trunks, branches and stones (visual only; kept off lanes).
func vegetation(rng: RandomNumberGenerator) -> void:
	var spots: Array = []
	for i in 70:
		var p := Vector3(rng.randf_range(-45, 45), 0, rng.randf_range(-45, 45))
		if maxf(absf(p.x), absf(p.z)) < 24.0:
			continue   # keep the compound clear
		spots.append(p)
	var kinds := [["wild_rooibos_bush", "wild_rooibos_bush_a"], ["wild_rooibos_bush", "wild_rooibos_bush_b"],
		["wild_rooibos_bush", "wild_rooibos_bush_c"], ["dry_branches_medium_01", "dry_branches_medium_01_a"],
		["namaqualand_rocks_01", "namaqualand_rocks_02_a"], ["namaqualand_boulders_01", "namaqualand_rocks_01_b"]]
	for i in spots.size():
		var k: Array = kinds[i % kinds.size()]
		var p: Dictionary = Kit.piece(k[0], k[1])
		var aabb: AABB = p.xf * (p.mesh as Mesh).get_aabb()
		var s := rng.randf_range(1.2, 2.6) if i % kinds.size() < 3 else rng.randf_range(1.5, 3.5)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), spots[i]) \
			* Transform3D(Basis(), -Vector3(aabb.get_center().x, aabb.position.y, aabb.get_center().z))
		_queue_piece({"mesh": Kit.lod_mesh(p.mesh, 3000.0 / maxf(p.mesh.surface_get_array_index_len(0) / 3.0, 1.0)), "xf": p.xf}, xf, false)
	for i in 8:
		var p := Vector3(rng.randf_range(-44, 44), 0, rng.randf_range(-44, 44))
		if maxf(absf(p.x), absf(p.z)) < 25.0:
			continue
		prop("ph:dead_quiver_trunk", p, rng.randf() * TAU, rng.randf_range(1.0, 1.6), false, Vector3.ZERO, 120.0)
	flush_kit(140.0)


func tower(base: Vector3, stair_dir: Vector3) -> void:
	var wood := Mats.acg("Planks023A", 1.2, Color(0.8, 0.72, 0.6))
	var steel := Mats.painted_metal(Color(0.4, 0.38, 0.34))
	box(base + Vector3(0, 4.85, 0), Vector3(4, 0.3, 4), wood)
	for sx in [-1.7, 1.7]:
		for sz in [-1.7, 1.7]:
			box(base + Vector3(sx, 2.35, sz), Vector3(0.3, 4.7, 0.3), steel)
			box(base + Vector3(sx, 6.3, sz), Vector3(0.15, 2.6, 0.15), steel, false)
	# cross bracing between the legs
	for e in [[Vector3(-1.7, 0.3, -1.7), Vector3(1.7, 4.6, -1.7)], [Vector3(1.7, 0.3, 1.7), Vector3(-1.7, 4.6, 1.7)],
			[Vector3(-1.7, 0.3, 1.7), Vector3(-1.7, 4.6, -1.7)], [Vector3(1.7, 0.3, -1.7), Vector3(1.7, 4.6, 1.7)]]:
		strut(base + e[0], base + e[1], 0.08, steel)
	flush_struts()
	box(base + Vector3(0, 7.65, 0), Vector3(4.8, 0.12, 4.8), Mats.acg("CorrugatedSteel007A", 1.5, Color(0.6, 0.55, 0.45), 0.6), false)
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		if d.is_equal_approx(stair_dir):
			continue
		sandbags(base + d * 1.8 + Vector3(0, 5.0, 0), 4.0, 0.0 if d.x == 0.0 else PI / 2.0, 0.9)
	var top := base + stair_dir * 2.0 + Vector3(0, 5.0, 0)
	var bottom := base + stair_dir * 12.5
	ramp(bottom, top, 2.0, wood, true)


## Military cargo truck: cab, chassis, canvas-covered bed, six wheels, bumper and glass.
func truck(pos: Vector3, yaw: float) -> void:
	var rb := Basis(Vector3.UP, yaw)
	var olive := Mats.painted_metal(Color(0.36, 0.38, 0.26))
	var dark := Mats.painted_metal(Color(0.12, 0.12, 0.11))
	box(pos + rb * Vector3(0, 1.3, -2.3), Vector3(2.3, 1.8, 1.9), olive, true, yaw)
	box(pos + rb * Vector3(0, 1.0, 1.0), Vector3(2.4, 1.2, 4.4), olive, true, yaw)
	box(pos + rb * Vector3(0, 2.1, 1.0), Vector3(2.4, 1.0, 4.4), Mats.camo(false), false, yaw)
	box(pos + rb * Vector3(0, 1.75, -3.26), Vector3(1.9, 0.6, 0.05), Mats.glass(), false, yaw)
	box(pos + rb * Vector3(0, 0.55, -3.35), Vector3(2.4, 0.25, 0.2), dark, false, yaw)
	box(pos + rb * Vector3(0, 0.55, -0.2), Vector3(1.2, 0.3, 6.0), dark, false, yaw)
	for wz in [-2.4, 0.6, 2.0]:
		for wx in [-1.05, 1.05]:
			var w := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.5
			cm.bottom_radius = 0.5
			cm.height = 0.35
			cm.radial_segments = 16
			w.mesh = cm
			w.material_override = Mats.flat(Color(0.08, 0.08, 0.08), 0.9)
			w.transform = Transform3D(rb * Basis(Vector3.BACK, PI / 2.0), pos + rb * Vector3(wx, 0.5, wz))
			decor.add_child(w)
