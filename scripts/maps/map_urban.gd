extends "res://scripts/maps/map_base.gd"
## MAP 2 - URBAN WARFARE
## 80 x 80 m city block: crossing streets, four building quadrants separated by
## alleys, a plaza, a low building with an accessible rooftop, barricades and
## wrecked cars. Medium-range combat with flanking routes.
## Buildings are assembled from the Poly Haven modular apartment / factory
## facade kits; streets have raised paving with kerbs, decals, debris, rubble,
## overhead cables, poles and street furniture. Footprints, cover and spawns
## are unchanged from the original layout.

const KERB := 0.12   # sidewalk height


func build() -> void:
	vision_range = 60.0
	preferred_range = 16.0
	ambient_sound = "ambient_wind"
	volumetric_density = 0.012
	setup_environment(Color(0.36, 0.52, 0.74), Color(0.8, 0.8, 0.78), Color(0.25, 0.24, 0.22),
		-32.0, -35.0, Color(1.0, 0.9, 0.76), 1.75, 0.55, Color(0.72, 0.72, 0.7), 0.0025)
	env.tonemap_exposure = 1.05

	var asphalt := Mats.asphalt()
	var paving := Mats.acg("PavingStones138", 1.6, Color(0.43, 0.42, 0.41))
	paving.resource_name = "PavingStones138"
	var kerb := Mats.acg("Concrete034", 1.0, Color(0.55, 0.54, 0.52))
	var line := Mats.flat(Color(0.86, 0.85, 0.78), 0.7)
	var yellow_line := Mats.flat(Color(0.82, 0.66, 0.16), 0.7)

	box(Vector3(0, -0.25, 0), Vector3(84, 0.5, 84), asphalt).get_child(1).visible = false   # collision; plane below is the visual
	floor_plane(Vector3(0, 0, 0), Vector2(84, 84), "Asphalt025C", 4.0, Color(0.78, 0.78, 0.78))
	# raised sidewalks with kerbs along the two streets
	sidewalk(6, 40, 6, 40, KERB, [["x", 6.0, 6.0, 40.0, -1.0], ["z", 6.0, 6.0, 40.0, -1.0]], paving, kerb)
	sidewalk(-40, -6, 6, 40, KERB, [["x", 6.0, -40.0, -6.0, -1.0], ["z", -6.0, 6.0, 40.0, 1.0]], paving, kerb)
	sidewalk(6, 40, -40, -6, KERB, [["x", -6.0, 6.0, 40.0, 1.0], ["z", 6.0, -40.0, -6.0, -1.0]], paving, kerb)
	sidewalk(-40, -6, -40, -6, KERB, [["x", -6.0, -40.0, -6.0, 1.0], ["z", -6.0, -40.0, -6.0, 1.0]], paving, kerb)
	# road markings: dashed centre lines, stop lines, zebra crossings, a yellow no-parking line
	for i in range(-36, 37, 6):
		if absi(i) > 8:
			box(Vector3(0, 0.005, i), Vector3(0.14, 0.01, 2.8), line, false)
			box(Vector3(i, 0.005, 0), Vector3(2.8, 0.01, 0.14), line, false)
	for i in range(-5, 6, 1):
		for z in [7.4, -7.4]:
			box(Vector3(i, 0.006, z), Vector3(0.5, 0.01, 2.2), line, false)
			box(Vector3(z, 0.006, i), Vector3(2.2, 0.01, 0.5), line, false)
	box(Vector3(-23, 0.005, -5.4), Vector3(30, 0.01, 0.12), yellow_line, false)
	# manholes
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for p in [Vector3(0, 0, 21), Vector3(-21, 0, 0.5), Vector3(21, 0, -0.5), Vector3(0.5, 0, -21)]:
		prop("ph:water_manhole_cover", p + Vector3(0, 0.002, 0), rng.randf() * TAU, 1.0, false, Vector3.ZERO, 50.0)

	# boundary walls: collision unchanged; inner faces dressed as building facades
	var boundary := Mats.brick(Color(0.45, 0.3, 0.25))
	for w in [[-41, 41, 40, 41], [-41, 41, -41, -40], [-41, -40, -40, 40], [40, 41, -40, 40]]:
		block(w[0], w[1], w[2], w[3], 10, boundary).visible = false
	facade_building(-40, 40, 40, 41, 12.0, "apartment", 11, [false, false, true, false], null, false, 0.25)
	facade_building(-40, 40, -41, -40, 12.0, "factory", 12, [true, false, false, false], null, false, 0.2)
	facade_building(-41, -40, -40, 40, 12.0, "apartment", 13, [false, true, false, false], null, false, 0.25)
	facade_building(40, 41, -40, 40, 12.0, "apartment", 14, [false, false, false, true], null, false, 0.2)
	# skyline beyond the walls (visual only): taller blocks seen over the boundary
	for sb in [[-44, -14, 46, 58, 21.0, 21], [-10, 18, 48, 60, 24.0, 22], [20, 44, 46, 56, 18.0, 23],
			[-60, -46, -36, 4, 21.0, 24], [-58, -46, 8, 40, 18.0, 25], [46, 58, -40, -6, 24.0, 26], [46, 60, 0, 36, 21.0, 27],
			[-40, -8, -58, -46, 18.0, 28], [-4, 26, -60, -46, 21.0, 29], [30, 52, -56, -46, 15.0, 30]]:
		var sides := [sb[3] <= -46, sb[1] <= -46, sb[2] >= 46, sb[0] >= 46]   # only the face looking into the map
		facade_building(sb[0], sb[1], sb[2], sb[3], sb[4], "factory", sb[5], sides, null, false)   # lighter kit for distant blocks

	# city blocks (same footprints as before; heights rounded to whole storeys)
	var buildings := [
		[-38, -22, 8, 22, 12.0, "apartment", 0.3], [-18, -8, 8, 20, 9.0, "shop", 0.1],
		[-38, -26, 26, 38, 15.0, "apartment", 0.0], [-22, -8, 26, 38, 9.0, "factory", 0.4],
		[28, 38, 18, 38, 12.0, "apartment", 0.2], [10, 24, 28, 38, 9.0, "shop", 0.5],
		[8, 20, -38, -26, 12.0, "factory", 0.2], [24, 38, -38, -20, 15.0, "apartment", 0.1], [8, 18, -22, -10, 9.0, "shop", 0.6],
		[22, 38, -16, -8, 6.0, "factory", 0.3], [-38, -24, -38, -24, 12.0, "apartment", 0.2], [-20, -8, -38, -28, 9.0, "shop", 0.4],
		[-38, -26, -20, -8, 9.0, "factory", 0.2],
	]
	var seed_i := 100
	for b in buildings:
		seed_i += 1
		facade_building(b[0], b[1], b[2], b[3], b[4], b[5], seed_i, [true, true, true, true], null, true, b[6])
		rooftop_clutter(b[0], b[1], b[2], b[3], b[4], seed_i)

	# NE: low building with accessible rooftop (parapet, ramp on the east side)
	var trim := Mats.concrete(Color(0.55, 0.55, 0.53), 2.0, false)
	facade_building(10, 24, 10, 22, 4.0, "factory", 77, [true, true, true, true], Mats.acg("Concrete044D", 3.0, Color(0.75, 0.75, 0.74)), true, 0.3)
	block(10, 24, 10, 10.4, 1.0, trim, 4.0)
	block(10, 24, 21.6, 22, 1.0, trim, 4.0)
	block(10, 10.4, 10, 22, 1.0, trim, 4.0)
	block(23.6, 24, 10, 14.3, 1.0, trim, 4.0)
	block(23.6, 24, 17.7, 22, 1.0, trim, 4.0)
	ramp(Vector3(31.5, KERB, 16), Vector3(24.0, 4.0, 16), 3.2, Mats.acg("MetalWalkway014", 1.0), false)
	prop("ph:exterior_aircon_unit", Vector3(14, 4.0, 19), PI, 1.0, true, Vector3.ZERO, 70.0)
	sandbags(Vector3(18, 4.0, 13), 3.0)

	# plaza (SW) with fountain and barricades
	var stone := Mats.acg("Concrete034", 1.5, Color(0.8, 0.79, 0.76))
	cylinder(Vector3(-15, KERB, -16), 2.2, 0.8, stone)
	cylinder(Vector3(-15, KERB + 0.8, -16), 0.4, 1.4, stone)
	sandbags(gy(Vector3(-11, 0, -11)), 3.0, 0.3)
	sandbags(gy(Vector3(-19, 0, -21)), 3.0, -0.3)

	# street cover
	jersey(Vector3(-2.5, 0, 14))
	jersey(Vector3(2.5, 0, -14))
	jersey(Vector3(16, 0, 2.5), PI / 2.0)
	jersey(Vector3(-16, 0, -2.5), PI / 2.0)
	jersey(Vector3(-30, 0, 2.0), PI / 2.0)
	jersey(Vector3(30, 0, -2.0), PI / 2.0)
	car(Vector3(3.0, 0, 24), 0.1)
	car(Vector3(-3.0, 0, -26), -0.15)
	car(Vector3(24, 0, -3.0), PI / 2.0 + 0.2)
	car(Vector3(-24, 0, 3.0), PI / 2.0 - 0.1)
	car(gy(Vector3(18, 0, 25)), 1.3)
	sandbags(Vector3(0, 0, 33), 4.0)
	sandbags(Vector3(0, 0, -33), 4.0)
	sandbags(Vector3(33, 0, 0), 4.0, PI / 2.0)
	sandbags(Vector3(-33, 0, 0), 4.0, PI / 2.0)

	# alley clutter: corrugated-steel dumpsters, bins, tyre stacks, hydrants, utility boxes
	var dumpster := Mats.container(Color(0.24, 0.34, 0.26))
	box(gy(Vector3(-20, 0.75, 15)), Vector3(1.3, 1.5, 2.4), dumpster)
	box(gy(Vector3(26, 0.75, 27)), Vector3(1.3, 1.5, 2.4), dumpster)
	box(gy(Vector3(21, 0.75, -24)), Vector3(2.4, 1.5, 1.3), dumpster)
	box(gy(Vector3(-22, 0.75, -32)), Vector3(1.3, 1.5, 2.4), dumpster)
	for p in [Vector3(-20.6, 0, 17.2), Vector3(25.4, 0, 29.1), Vector3(19.0, 0, -24.4), Vector3(-7.0, 0, 24.0), Vector3(7.0, 0, -18.0)]:
		prop("ph:metal_trash_can", gy(p), p.x, 1.0, true, Vector3.ZERO, 60.0)
	tyres(gy(Vector3(-18.6, 0, 21)), 3)
	tyres(gy(Vector3(25.5, 0, -18.5)), 4)
	for p in [Vector3(7.0, 0, 9.0), Vector3(-7.0, 0, -9.0), Vector3(9.0, 0, -7.0), Vector3(-9.0, 0, 7.0)]:
		prop("ph:fire_hydrant", gy(p), p.x * 0.3, 1.0, true, Vector3.ZERO, 60.0)
	for p in [Vector3(-8.3, 0, 21), Vector3(8.3, 0, -21), Vector3(-21, 0, -8.3)]:
		prop("ph:utility_box_01", gy(p), 0.0 if absf(p.x) > absf(p.z) else PI / 2.0, 1.0, true, Vector3.ZERO, 60.0)
	for p in [Vector3(-12.4, 0, -10.6), Vector3(-17.8, 0, -21.6)]:
		barrel(gy(p))
	for p in [Vector3(-15, 0, 23.5), Vector3(-13.8, 0, 23.5), Vector3(32, 0, -18), Vector3(-30, 0, -22),
			Vector3(14, 0, -24), Vector3(-6.8, 0, 30), Vector3(6.8, 0, -30)]:
		crate(gy(p))
	# street lights (CC0 model, thin pole collision; arm reaches over the road)
	for sl in [[Vector3(7, 0, 15), PI / 2.0], [Vector3(-7, 0, -15), -PI / 2.0], [Vector3(15, 0, -7), PI],
			[Vector3(-15, 0, 7), 0.0], [Vector3(7, 0, -30), PI / 2.0], [Vector3(-7, 0, 30), -PI / 2.0]]:
		var p: Vector3 = gy(sl[0])
		prop("ph:street_lamp_01", p, sl[1], 1.3, false, Vector3.ZERO, 0.0, true)
		blocker(p + Vector3(0, 1.5, 0), Vector3(0.35, 3.0, 0.35))

	# fire escapes and wall-mounted detail on street-facing facades
	fire_escape(Vector3(-30, 3.2, 22), Vector3(0, 0, 1))
	fire_escape(Vector3(31, 3.2, -20), Vector3(0, 0, -1))
	fire_escape(Vector3(-8, 3.0, -33), Vector3(1, 0, 0))
	for w in [[Vector3(-22, 5.5, 12), Vector3(1, 0, 0)], [Vector3(-8, 4.0, 16), Vector3(1, 0, 0)], [Vector3(8, 6.5, -32), Vector3(-1, 0, 0)],
			[Vector3(24, 7.0, -30), Vector3(-1, 0, 0)], [Vector3(-26, 8.0, -14), Vector3(1, 0, 0)], [Vector3(15, 4.2, -10), Vector3(0, 0, -1)],
			[Vector3(31, 5.0, 18), Vector3(0, 0, -1)], [Vector3(-14, 4.0, 26), Vector3(0, 0, -1)]]:
		var n: Vector3 = w[1]
		prop("ph:exterior_aircon_unit", w[0] + n * 0.45, atan2(n.x, n.z), 1.0, false, Vector3.ZERO, 70.0)
	for w in [[Vector3(-13, 2.9, 8), Vector3(0, 0, -1)], [Vector3(13, 2.9, -10), Vector3(0, 0, -1)], [Vector3(-8, 2.9, 32), Vector3(1, 0, 0)],
			[Vector3(28, 2.9, 28), Vector3(-1, 0, 0)], [Vector3(-24, 2.9, -31), Vector3(1, 0, 0)]]:
		var n: Vector3 = w[1]
		prop("ph:security_light", w[0] + n * 0.1, atan2(n.x, n.z), 1.0, false, Vector3.ZERO, 60.0, true)

	# utility poles along the streets and sagging cables across them
	var tops: Array = []
	for pp in [[Vector3(-6.6, 0, 26), "preset_01_"], [Vector3(6.6, 0, 27), "preset_02_"], [Vector3(-6.6, 0, -24), "preset_03_"],
			[Vector3(6.6, 0, -25), "preset_01_"], [Vector3(-26, 0, 6.6), "preset_02_"], [Vector3(25, 0, -6.6), "preset_03_"]]:
		tops.append(power_pole(pp[1], gy(pp[0]), 0.0 if absf(pp[0].z) > absf(pp[0].x) else PI / 2.0))
	wire(tops[0], tops[1] + Vector3(0, -0.2, 0), 0.9)
	wire(tops[0] + Vector3(0, -0.5, 0), tops[1] + Vector3(0, -0.6, 0), 1.0)
	wire(tops[2], tops[3], 0.9)
	wire(tops[2] + Vector3(0, -0.5, 0), tops[3] + Vector3(0, -0.4, 0), 1.1)
	wire(tops[0], tops[2], 1.6)
	wire(tops[1], tops[3], 1.6)
	wire(tops[4], tops[5], 1.8)
	wire(tops[4] + Vector3(0, -0.5, 0), Vector3(-8, 7.5, 8.2), 0.6)
	wire(tops[5] + Vector3(0, -0.5, 0), Vector3(22.2, 5.5, -8), 0.5)
	for c in [[Vector3(-8, 8.2, 14), Vector3(8.2, 8.6, 16)], [Vector3(-8, 7.6, 18), Vector3(10, 8.4, 20)],
			[Vector3(-8.2, 8.0, -34), Vector3(8, 8.8, -30)], [Vector3(-22, 9.0, 8), Vector3(-20, 8.5, -8)],
			[Vector3(22, 5.6, -8), Vector3(24, 6.2, 10)]]:
		wire(c[0], c[1], 0.7)

	# war damage: rubble heaps against walls, debris along the gutters
	var conc := Mats.acg("Concrete044D", 1.6, Color(0.8, 0.78, 0.75))
	for r in [[Vector3(-20.5, KERB, 21.0), Vector3(3.0, 0.9, 2.2), 1], [Vector3(18.5, KERB, -16.5), Vector3(2.6, 0.8, 2.6), 2],
			[Vector3(-9.0, KERB, 36.0), Vector3(2.4, 0.7, 2.6), 3], [Vector3(37.0, KERB, -18.5), Vector3(3.0, 1.0, 2.2), 4],
			[Vector3(-37.0, KERB, -6.8), Vector3(2.2, 0.7, 2.0), 5]]:
		rubble(r[0], r[1], r[2])
	for g in [[Vector3(-5.2, 0, 12), 2.2], [Vector3(5.2, 0, -16), 2.2], [Vector3(12, 0, 5.3), 2.0], [Vector3(-14, 0, -5.3), 2.0],
			[Vector3(-4.8, 0, -30), 2.5], [Vector3(4.8, 0, 30), 2.5], [Vector3(30, 0, 5), 2.0], [Vector3(-30, 0, -5), 2.0],
			[Vector3(0, 0, 0), 4.0]]:
		debris(g[0], g[1], 40, 0.05, 0.22, conc, int(g[0].x * 13 + g[0].z))
	for g in [Vector3(-14, KERB, -12), Vector3(20, KERB, 24), Vector3(-30, KERB, 24), Vector3(30, KERB, -24)]:
		debris(g, 3.0, 50, 0.05, 0.25, conc, int(g.x * 7 + g.z))

	flush_kit()

	player_spawns = [[Vector3(0, 0, -37), 0.0], [Vector3(37, 0, 0), 0.0], [Vector3(-37, 0, 0), 0.0], [Vector3(0, 0, 37), 0.0]]
	bot_spawns = [Vector3(-30, 0, 0), Vector3(30, 0, 2), Vector3(0, 0, 30), Vector3(0, 0, -30),
		gy(Vector3(-15, 0, -11)), Vector3(17, 4.0, 16), gy(Vector3(-20, 0, 24)), gy(Vector3(26, 0, 24)),
		gy(Vector3(29, 0, -18)), gy(Vector3(-22, 0, -36)), gy(Vector3(20, 0, -20))]
	patrol_points = bot_spawns + [Vector3(0, 0, 0), Vector3(-20, 0, 2), Vector3(20, 0, -2), Vector3(2, 0, 18),
		Vector3(-2, 0, -18), gy(Vector3(-15, 0, -20)), Vector3(-20, 0, 4), gy(Vector3(26, 0, 12)), Vector3(32, 0, -5.5)]


## Ground height at a point: the raised sidewalk quadrants are KERB above the road.
func gy(p: Vector3) -> Vector3:
	if absf(p.x) > 6.0 and absf(p.z) > 6.0 and p.y < KERB:
		return p + Vector3(0, KERB, 0)
	return p


## Roof furniture: an AC unit on most roofs (visual only, kept off the edges).
func rooftop_clutter(x0: float, x1: float, z0: float, z1: float, h: float, s: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = s * 31
	if rng.randf() < 0.7:
		var p := Vector3(rng.randf_range(x0 + 2.0, x1 - 2.0), h, rng.randf_range(z0 + 2.0, z1 - 2.0))
		prop("ph:exterior_aircon_unit", p, rng.randf() * TAU, 1.0, false, Vector3.ZERO, 60.0)


## Steel fire escape (Poly Haven kit, assembled) bolted to a facade. `pos` is the
## wall point under the lowest platform, `n` the wall's outward normal.
func fire_escape(pos: Vector3, n: Vector3) -> void:
	var holder: Node3D = prop("ph:modular_fire_escape", pos, atan2(n.x, n.z), 1.0, false, Vector3.ZERO, 90.0, true)
	holder.position = pos + n * 0.78
