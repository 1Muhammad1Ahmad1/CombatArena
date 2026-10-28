extends "res://scripts/maps/map_base.gd"
## MAP 1 - INDUSTRIAL WAREHOUSE
## Indoor hall (64 x 44 m) with shipping containers, a raised catwalk along the
## north wall, a south mezzanine, an office block with corridors, crates and
## skylights. Close- and medium-range combat with several routes.
## Brick factory-kit walls with tall windows, steel roof trusses and purlins,
## I-beam columns, grating catwalks with open railings, an overhead crane,
## ducts, pipes, shelving, pallets and machinery. Collision volumes, cover and
## spawns are unchanged from the original layout.

func build() -> void:
	vision_range = 45.0
	preferred_range = 10.0
	ambient_sound = "ambient_indoor"
	volumetric_density = 0.03
	facade_lod_dist = 18.0   # indoors the hall walls are close; their far LOD keeps bricks and windows
	setup_environment(Color(0.38, 0.5, 0.66), Color(0.62, 0.64, 0.66), Color(0.16, 0.15, 0.14),
		-64.0, 25.0, Color(1.0, 0.9, 0.74), 1.9, 0.3, Color(0.42, 0.4, 0.37), 0.012)
	env.tonemap_exposure = 1.1
	env.fog_enabled = false   # indoors: fog washed out the far end (far contrast 25.8 -> 42.3 without it) and cost 0.8 ms

	var floor_mat := Mats.floor_concrete(Color(0.8, 0.8, 0.78))
	var steel := Mats.acg("Metal041B", 1.5, Color(0.55, 0.57, 0.6))
	var dark_steel := Mats.painted_metal(Color(0.22, 0.24, 0.26))
	var yellow := Mats.painted_metal(Color(0.85, 0.62, 0.12))
	var grate := grating()
	var wood := Mats.acg("Planks023A", 1.2, Color(0.85, 0.78, 0.66))

	# floor, walls (collision unchanged; brick factory facades on the inside faces)
	box(Vector3(0, -0.25, 0), Vector3(66, 0.5, 46), floor_mat).get_child(1).visible = false   # collision; plane below is the visual
	floor_plane(Vector3(0, 0, 0), Vector2(66, 46), "Concrete044B", 3.0, Color(0.8, 0.8, 0.78))
	for w in [[-33, 33, 22, 23], [-33, 33, -23, -22], [-33, -32, -22, 22], [32, 33, -22, 22]]:
		block(w[0], w[1], w[2], w[3], 9.5, floor_mat).visible = false
	facade_building(-33, 33, 22, 23, 9.5, "hall", 41, [false, false, true, false], null, false, 0.0)
	facade_building(-33, 33, -23, -22, 9.5, "hall", 42, [true, false, false, false], null, false, 0.0)
	facade_building(-33, -32, -22, 22, 9.5, "hall", 43, [false, true, false, false], null, false, 0.0)
	facade_building(32, 33, -22, 22, 9.5, "hall", 44, [false, false, false, true], null, false, 0.0)
	# corrugated roof panels with skylight gaps, steel trusses and purlins
	var roof := Mats.acg("CorrugatedSteel007A", 2.0, Color(0.45, 0.46, 0.47), 0.6)
	for seg in [[-23.0, -14.0], [-10.0, -2.0], [2.0, 10.0], [14.0, 23.0]]:
		# underside seen from the hall (UV-mapped, no triplanar cost) + thin top for the outside/shadows
		var under := floor_plane(Vector3(0, 9.5, (seg[0] + seg[1]) * 0.5), Vector2(66, seg[1] - seg[0]), "CorrugatedSteel007A", 2.0, Color(0.45, 0.46, 0.47))
		under.rotation.x = PI
		under.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		block(-33, 33, seg[0], seg[1], 0.3, roof, 9.5, false).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	for x in range(-28, 29, 8):
		truss(Vector3(x, 8.0, -22), Vector3(x, 8.0, 22), 1.4, 2.0, dark_steel)
	for z in range(-21, 22, 3):
		ibeam(Vector3(-32, 9.45, z), Vector3(32, 9.45, z), 0.14, 0.08, dark_steel)
	# lane markings
	var paint := Mats.flat(Color(0.82, 0.66, 0.16), 0.7)
	for z in [-7.5, 7.5]:
		box(Vector3(0, 0.005, z), Vector3(50, 0.01, 0.15), paint, false)
	for x in range(-24, 25, 6):
		box(Vector3(x, 0.005, 0), Vector3(0.12, 0.01, 1.2), paint, false)
	# roller doors in the end walls
	for d in [[Vector3(-20, 2.5, 21.9), PI], [Vector3(20, 2.5, -21.9), 0.0]]:
		box(d[0], Vector3(5, 5, 0.12), Mats.container(Color(0.35, 0.38, 0.4)), false)
		box(d[0] + Vector3(0, 2.65, 0), Vector3(5.4, 0.4, 0.4), dark_steel, false)

	# north catwalk on steel beams (grating deck, collision unchanged) + stairs
	var deck := box(Vector3(0, 3.35, 20), Vector3(58, 0.3, 3), grate)
	(deck.get_child(1) as MeshInstance3D).mesh = _box_mesh(Vector3(58, 0.04, 3))
	(deck.get_child(1) as MeshInstance3D).position.y = 0.13
	for z in [18.6, 21.4]:
		ibeam(Vector3(-29, 3.32, z), Vector3(29, 3.32, z), 0.3, 0.15, dark_steel)
	for x in [-24, -12, 0, 12, 24]:
		box(Vector3(x, 1.6, 18.7), Vector3(0.3, 3.2, 0.3), steel).get_child(1).visible = false
		ibeam(Vector3(x, 0, 18.7), Vector3(x, 3.2, 18.7), 0.25, 0.25, dark_steel)
	ramp(Vector3(-27.5, 0, 9.5), Vector3(-27.5, 3.5, 18.6), 2.6, steel, true)
	ramp(Vector3(27.5, 0, 9.5), Vector3(27.5, 3.5, 18.6), 2.6, steel, true)
	open_railing(Vector3(-26.0, 3.5, 18.55), Vector3(26.0, 3.5, 18.55), yellow)
	open_railing(Vector3(-29.0, 3.5, 18.6), Vector3(-29.0, 3.5, 21.5), yellow)
	open_railing(Vector3(29.0, 3.5, 18.6), Vector3(29.0, 3.5, 21.5), yellow)

	# south mezzanine + stairs
	var mez := box(Vector3(0, 2.85, -19.5), Vector3(18, 0.3, 5), grate)
	(mez.get_child(1) as MeshInstance3D).mesh = _box_mesh(Vector3(18, 0.04, 5))
	(mez.get_child(1) as MeshInstance3D).position.y = 0.13
	for z in [-17.2, -21.8]:
		ibeam(Vector3(-9, 2.82, z), Vector3(9, 2.82, z), 0.3, 0.15, dark_steel)
	for x in [-8.5, 0.0, 8.5]:
		box(Vector3(x, 1.35, -17.2), Vector3(0.3, 2.7, 0.3), steel).get_child(1).visible = false
		ibeam(Vector3(x, 0, -17.2), Vector3(x, 2.7, -17.2), 0.25, 0.25, dark_steel)
	ramp(Vector3(7.5, 0, -9.6), Vector3(7.5, 3.0, -17.1), 2.4, steel, true)
	open_railing(Vector3(-9.0, 3.0, -17.05), Vector3(6.2, 3.0, -17.05), yellow)
	open_railing(Vector3(-9.0, 3.0, -17.1), Vector3(-9.0, 3.0, -22.0), yellow)

	# office block (SW) with doors and a corridor
	var office := Mats.acg("Plaster001", 2.0, Color(0.78, 0.76, 0.7))
	block(-32, -26, -8.2, -7.8, 4.0, office)
	block(-24, -18, -8.2, -7.8, 4.0, office)
	block(-18.2, -17.8, -22, -16, 4.0, office)
	block(-18.2, -17.8, -14, -7.8, 4.0, office)
	block(-25.2, -24.8, -22, -14, 4.0, office)
	box(Vector3(-25, 4.1, -15), Vector3(14.4, 0.2, 14.4), Mats.acg("MetalPlates006", 2.0), false)
	crate(Vector3(-30.5, 0, -12))
	crate(Vector3(-20, 0, -20))
	box(Vector3(-21.5, 0.4, -11), Vector3(2.0, 0.8, 1.0), wood)
	prop("ph:worn_metal_rack", Vector3(-31.4, 0, -20.5), PI / 2.0, 1.0, true, Vector3.ZERO, 40.0)
	prop("ph:industrial_storage_cart", Vector3(-22.6, 0, -20.8), 0.1, 1.0, false, Vector3.ZERO, 40.0)

	# shipping containers (6.1 x 2.6 x 2.44)
	var cont_x := Vector3(6.1, 2.6, 2.44)
	var cont_z := Vector3(2.44, 2.6, 6.1)
	for c in [[Vector3(-12, 1.3, 5), cont_x], [Vector3(-12, 3.9, 5), cont_x], [Vector3(-18, 1.3, -3), cont_z],
			[Vector3(10, 1.3, 4), cont_x], [Vector3(18, 1.3, -6), cont_z], [Vector3(18, 3.9, -6), cont_z],
			[Vector3(2, 1.3, -6), cont_x], [Vector3(21, 1.3, 10), cont_x], [Vector3(-24, 1.3, 8), cont_z],
			[Vector3(-4, 1.3, 14), cont_x], [Vector3(24, 1.3, -16), cont_x]]:
		container_prop(c[0], c[1])

	# steel columns (collision unchanged; I-beam visual with base plates)
	for p in [Vector3(-8, 0, 10), Vector3(8, 0, 10), Vector3(-8, 0, -10), Vector3(12, 0, -10), Vector3(-20, 0, 1.5)]:
		box(p + Vector3(0, 4.75, 0), Vector3(0.4, 9.5, 0.4), steel).get_child(1).visible = false
		ibeam(p, p + Vector3(0, 8.0, 0), 0.38, 0.32, dark_steel)
		box(p + Vector3(0, 0.02, 0), Vector3(0.6, 0.04, 0.6), dark_steel, false)

	# crates, pallets, barrels
	for p in [Vector3(-4, 0, -12), Vector3(-2.7, 0, -12), Vector3(14, 0, -14), Vector3(15.3, 0, -14),
			Vector3(-10, 0, -4), Vector3(-30.5, 0, 16), Vector3(-30.5, 0, 14.7), Vector3(14, 0, 16),
			Vector3(12.7, 0, 16), Vector3(4, 0, 9), Vector3(28, 0, 4), Vector3(-6, 0, 19)]:
		crate(p)
	crate(Vector3(-3.35, 1.2, -12), 1.1)
	crate(Vector3(14.6, 1.2, -14), 1.1)
	for p in [Vector3(-6, 0, -16), Vector3(-6.7, 0, -15.4), Vector3(28, 0, 0), Vector3(28.7, 0, -0.6),
			Vector3(-28, 0, 3), Vector3(5, 0, 18), Vector3(22, 0, 3)]:
		barrel(p)
	box(Vector3(26, 0.7, 4.5), Vector3(2.4, 1.4, 1.3), Mats.container(Color(0.25, 0.35, 0.26)))  # skip bin

	# under-catwalk storage: shelving units along the north wall, pallets with boxes
	for x in [-22.0, -21.4, -20.8, -16.0, -15.4, -14.8, 8.0, 8.6, 9.2, 19.0, 19.6, 20.2]:
		prop("ph:steel_frame_shelves_02", Vector3(x, 0, 21.6), PI, 1.0, false, Vector3.ZERO, 45.0)
	for seg in [[-22.3, -14.5], [7.7, 9.5], [18.7, 20.5]]:
		blocker(Vector3((seg[0] + seg[1]) * 0.5, 1.07, 21.6), Vector3(seg[1] - seg[0], 2.14, 0.5))
	for pp in [[Vector3(-27.6, 0, -2.0), 0.0], [Vector3(30.2, 0, 12.5), PI / 2.0], [Vector3(30.2, 0, 14.0), PI / 2.0],
			[Vector3(-3.0, 0, -20.6), 0.0], [Vector3(2.5, 0, -20.6), 0.1]]:
		pallet(pp[0], pp[1], wood)
		blocker(pp[0] + Vector3(0, 0.35, 0), Vector3(1.2, 0.7, 0.8) if pp[1] == 0.0 else Vector3(0.8, 0.7, 1.2))
		for i in 3:
			var o := Basis(Vector3.UP, pp[1]) * Vector3(-0.3 + (i % 2) * 0.6, 0.15 + (i / 2) * 0.3, 0)
			prop("ph:cardboard_box_01", pp[0] + o, pp[1] + i * 0.2, 1.0, false, Vector3.ZERO, 40.0)
	flush_struts()

	# machinery and handling equipment against the walls
	prop("ph:portable_generator", Vector3(30.9, 0, -9.0), -PI / 2.0, 1.0, true, Vector3.ZERO, 50.0)
	prop("ph:old_military_compressor", Vector3(30.6, 0, 9.0), PI, 1.0, true, Vector3.ZERO, 50.0)
	prop("ph:hand_truck", Vector3(29.6, 0, -3.4), 0.6, 1.0, false, Vector3.ZERO, 40.0)
	prop("ph:industrial_storage_cart", Vector3(-28.6, 0, 6.0), 0.2, 1.0, true, Vector3.ZERO, 40.0)
	prop("ph:barrel_03", Vector3(-27.4, 0, 4.4), 0.0, 1.0, true, Vector3.ZERO, 50.0)

	# overhead crane on its runway, ducts and pipe runs
	for z in [-4.0, 4.0]:
		ibeam(Vector3(-31, 7.6, z), Vector3(31, 7.6, z), 0.4, 0.25, yellow)
	prop("ph:overhead_crane", Vector3(4.0, 7.8, 0.0), PI / 2.0, 1.0, false, Vector3.ZERO, 80.0, true)
	duct_run(Vector3(-30, 7.2, -10.5), Vector3(30, 7.2, -10.5))
	duct_run(Vector3(-30, 7.2, 10.5), Vector3(30, 7.2, 10.5))
	var pipe_mat := Mats.painted_metal(Color(0.3, 0.42, 0.35))
	var red_pipe := Mats.painted_metal(Color(0.55, 0.12, 0.1))
	pipe([Vector3(-31.6, 0.0, -6.0), Vector3(-31.6, 5.5, -6.0), Vector3(-31.6, 5.5, 21.6), Vector3(31.6, 5.5, 21.6), Vector3(31.6, 5.5, -21.6)], 0.12, pipe_mat)
	pipe([Vector3(-31.7, 6.2, -21.7), Vector3(31.7, 6.2, -21.7), Vector3(31.7, 0.0, -21.7)], 0.08, red_pipe)
	pipe([Vector3(31.6, 0.0, 6.0), Vector3(31.6, 4.6, 6.0), Vector3(31.6, 4.6, -18.0)], 0.06, red_pipe)
	flush_struts()

	# lighting: skylights (sun + light shafts, volumetric on Epic), shadowed spot lamps over the
	# main lanes, fluorescent fittings under the trusses, cheap omni fills
	for gap in [-12.0, 0.0, 12.0]:
		for x in [-18.0, 0.0, 18.0]:
			light_shaft(Vector3(x, 9.4, gap), Vector3(x + 3.0, 0.2, gap), 3.6, Color(1.0, 0.92, 0.75, 0.06))
	for p in [Vector3(-16, 7.8, -7), Vector3(16, 7.8, -7), Vector3(-16, 7.8, 8), Vector3(16, 7.8, 8)]:
		spot_lamp(p, Color(1.0, 0.82, 0.58), 6.0, 14.0)
	for p in [Vector3(0, 7.6, 1), Vector3(-25, 3.6, -15), Vector3(0, 7.6, -16), Vector3(-26, 7.0, 16), Vector3(26, 7.0, 16)]:
		light(p, Color(1.0, 0.86, 0.7), 1.7, 11.0, false)
	for x in range(-28, 29, 8):
		for z in [-16.0, 16.0]:
			prop("ph:mounted_fluorescent_lights", Vector3(x + 0.3, 7.95, z), PI / 2.0, 1.0, false, Vector3.ZERO, 60.0, true)
			box(Vector3(x + 0.3, 7.9, z), Vector3(0.06, 0.03, 0.9), Mats.emissive(Color(0.85, 0.92, 1.0), 4.0), false)

	# floor wear: oil and water stains
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	for i in 14:
		var p := Vector3(rng.randf_range(-28, 28), 0, rng.randf_range(-18, 18))
		ground_decal(["Leaking003", "Leaking008"][i % 2], p, rng.randf() * TAU, rng.randf_range(1.5, 3.0), rng.randf_range(2.0, 4.0),
			Color(0.35, 0.33, 0.3, rng.randf_range(0.5, 0.8)))

	# edge clutter (Poly Haven CC0 props, kept against walls, out of the combat lanes)
	for p in [Vector3(30.5, 0, -6), Vector3(30.95, 0, -5.55), Vector3(30.35, 0, -5.3)]:
		prop("ph:propane_tank", p, p.x, 1.0, true, Vector3.ZERO, 50.0)
	for base in [Vector3(-30.6, 0, 9.5), Vector3(30.9, 0, -12), Vector3(-6, 0, -21.2), Vector3(-29.6, 0, -6)]:
		blocker(base + Vector3(0, 0.39, 0), Vector3(0.34, 0.78, 0.45))
		for i in 3:
			prop("ph:plastic_crate_01", base + Vector3(0, i * 0.26, 0), 0.05 * i, 1.0, false, Vector3.ZERO, 50.0)
	for p in [Vector3(-31.7, 0, -2.5), Vector3(31.7, 0, 3.0), Vector3(-17.6, 0, -11.5)]:
		prop("ph:utility_box_01", p, PI / 2.0 if p.x < 0.0 else -PI / 2.0, 1.0, true, Vector3.ZERO, 60.0)
	for p in [Vector3(-5.3, 0, -15.6), Vector3(29.3, 0, 0.6), Vector3(-27.4, 0, 3.6)]:
		prop("ph:metal_jerrycan", p, p.z, 1.0, false, Vector3.ZERO, 40.0)
	tyres(Vector3(29.5, 0, 7.5), 3)
	tyres(Vector3(-10, 0, 20.6), 2)
	flush_kit()

	player_spawns = [[Vector3(-28.5, 0, -18), PI * 0.75], [Vector3(30.5, 0, 16), PI * 0.5],
		[Vector3(30, 0, -19), PI * 0.25], [Vector3(-12, 0, 18), PI]]
	bot_spawns = [Vector3(28, 0, -2), Vector3(-12, 0, -14), Vector3(0, 0, 8), Vector3(14, 0, 14),
		Vector3(-14, 0, 16), Vector3(0, 3.5, 20), Vector3(-29, 0, -2), Vector3(12, 0, -2),
		Vector3(0, 3.0, -20), Vector3(26, 0, -10), Vector3(-2, 0, 2)]
	patrol_points = bot_spawns + [Vector3(-20, 3.5, 20), Vector3(20, 3.5, 20), Vector3(-21, 0, -12),
		Vector3(-28, 0, -18), Vector3(6, 0, -3), Vector3(-8, 0, 0), Vector3(20, 0, 0), Vector3(-26, 0, 12)]
