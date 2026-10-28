extends RefCounted
## PBR materials. Concrete, corrugated steel, bricks, plaster, asphalt, sand, wood and
## steel plate use scanned CC0 texture sets from ambientCG (`acg()`); the rest
## (painted metal, sandbags, HESCO, rock, camo, gun parts) are generated at runtime.
## Everything is cached for the session.

static var _cache := {}


static func _noise(size: int, freq: float, noise_seed: int, octaves := 4) -> PackedFloat32Array:
	var n := FastNoiseLite.new()
	n.seed = noise_seed
	n.frequency = freq
	n.fractal_octaves = octaves
	var img := n.get_seamless_image(size, size)
	img.convert(Image.FORMAT_L8)
	var bytes := img.get_data()
	var out := PackedFloat32Array()
	out.resize(size * size)
	for i in size * size:
		out[i] = bytes[i] / 255.0
	return out


static func _arrays(size: int) -> Array:
	var h := PackedFloat32Array()
	h.resize(size * size)
	var c := PackedColorArray()
	c.resize(size * size)
	return [h, c]


static func _build(size: int, heights: PackedFloat32Array, colors: PackedColorArray, bump: float) -> Array:
	var alb := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	var nor := Image.create_empty(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var i := y * size + x
			alb.set_pixel(x, y, colors[i])
			var hx := heights[y * size + (x + 1) % size] - heights[y * size + (x - 1 + size) % size]
			var hy := heights[((y + 1) % size) * size + x] - heights[((y - 1 + size) % size) * size + x]
			var n := Vector3(-hx * bump, hy * bump, 1.0).normalized()
			nor.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	alb.generate_mipmaps()
	nor.generate_mipmaps()
	return [ImageTexture.create_from_image(alb), ImageTexture.create_from_image(nor)]


static func _material(tex: Array, rough: float, metal: float, tile: float, world := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex[0]
	m.normal_enabled = true
	m.normal_texture = tex[1]
	m.normal_scale = 0.9
	m.roughness = rough
	m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = world
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Scanned/photo PBR set from ambientCG (CC0): colour, OpenGL normal, roughness and
## (when present) AO, world-space triplanar so texel density is consistent on
## every box size. `tile` = metres covered by one texture repeat.
static func acg(id: String, tile: float, tint := Color.WHITE, metal := 0.0, normal_strength := 1.0) -> StandardMaterial3D:
	var key := "acg%s%s%s%s" % [id, tile, tint.to_html(), metal]
	if _cache.has(key):
		return _cache[key]
	var dir := acg_dir(id)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(dir + "Color.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(dir + "NormalGL.jpg")
	m.normal_scale = normal_strength
	m.roughness_texture = load(dir + "Roughness.jpg")
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	m.roughness = 1.0
	if ResourceLoader.exists(dir + "AmbientOcclusion.jpg"):
		m.ao_enabled = true
		m.ao_texture = load(dir + "AmbientOcclusion.jpg")
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
	if ResourceLoader.exists(dir + "Metalness.jpg"):
		m.metallic_texture = load(dir + "Metalness.jpg")
		m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GRAYSCALE
		m.metallic = 1.0
	else:
		m.metallic = metal
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[key] = m
	return m


## Same ambientCG set mapped with plain UVs for a flat PlaneMesh of `size` metres:
## one texture fetch per map instead of three (triplanar) on large floor areas.
static func acg_planar(id: String, tile: float, size: Vector2, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "acgp%s%s%s%s" % [id, tile, size, tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := acg(id, tile, tint).duplicate() as StandardMaterial3D
	m.uv1_triplanar = false
	m.uv1_world_triplanar = false
	m.uv1_scale = Vector3(size.x / tile, size.y / tile, 1.0)
	m.metallic_specular = 0.22   # rough stone/asphalt: no glare at grazing angles toward the sun
	_cache[key] = m
	return m


## File prefix of an ambientCG set: first batch in assets/ambientcg/, map-overhaul
## batch (downloaded with NDM) in assets/downloads/<map>/<materials|decals>/.
static func acg_dir(id: String) -> String:
	for d in ["res://assets/ambientcg/%s/", "res://assets/downloads/urban/materials/%s/", "res://assets/downloads/desert/materials/%s/",
			"res://assets/downloads/warehouse/materials/%s/", "res://assets/downloads/shared/materials/%s/",
			"res://assets/downloads/shared/decals/%s/", "res://assets/downloads/urban/decals/%s/"]:
		var p: String = (d % id) + "%s_1K-JPG_" % id
		if ResourceLoader.exists(p + "Color.jpg"):
			return p
	push_error("ambientCG set not found: " + id)
	return ""


static func flat(color: Color, rough := 0.8, metal := 0.0) -> StandardMaterial3D:
	var key := "flat%s%s%s" % [color.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m


static func emissive(color: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "emis%s%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.16, 0.22, 0.27)
	m.metallic = 0.6
	m.roughness = 0.08
	_cache["glass"] = m
	return m


static func concrete(tint := Color(0.62, 0.62, 0.6), tile := 4.0, seams := true) -> StandardMaterial3D:
	return acg("Concrete034", clampf(tile * 0.7, 2.0, 3.5), _rel(tint, Color(0.62, 0.62, 0.6)))
	var key := "concrete%s%s%s" % [tint.to_html(), tile, seams]
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.03, 11)
	var f := _noise(s, 0.2, 12, 2)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			var v := n[i] * 0.7 + f[i] * 0.3
			var seam := seams and (x % 64 < 1 or y % 64 < 1)
			h[i] = v * 0.25 - (1.0 if seam else 0.0)
			var stain := smoothstep(0.62, 0.9, n[i]) * 0.1
			var shade := 0.9 + v * 0.14 - stain - (0.22 if seam else 0.0)
			c[i] = Color(tint.r * shade, tint.g * shade, tint.b * shade)
	var m := _material(_build(s, h, c, 1.4), 0.82, 0.0, tile)
	_cache[key] = m
	return m


static func container(color: Color) -> StandardMaterial3D:
	return acg("CorrugatedSteel007A", 2.4, _rel(color, Color(0.55, 0.55, 0.55)))
	var key := "container%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.04, 21)
	var rust := _noise(s, 0.06, 22, 3)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			var ridge := smoothstep(-0.35, 0.35, sin(float(x) / s * TAU * 8.0))
			h[i] = ridge + n[i] * 0.08
			var col := color * (0.74 + ridge * 0.26)
			col = col.darkened(n[i] * 0.18)
			if rust[i] > 0.7:
				col = col.lerp(Color(0.4, 0.23, 0.13), clampf((rust[i] - 0.7) * 3.5, 0.0, 1.0))
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 3.0), 0.55, 0.45, 2.6)
	_cache[key] = m
	return m


static func brick(color := Color(0.55, 0.27, 0.2)) -> StandardMaterial3D:
	return acg("Bricks076C", 1.6, _rel(color, Color(0.55, 0.27, 0.2)))
	var key := "brick%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.08, 31, 3)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			var row := y / 16
			var off := 16 if row % 2 == 1 else 0
			var bx := (x + off) % 32
			var by := y % 16
			var mortar := bx < 2 or by < 2
			var bid := ((x + off) / 32) % 4 + row * 5
			var hv := fposmod(sin(float(bid) * 12.9898) * 43758.5453, 1.0)
			if mortar:
				h[i] = -0.6
				c[i] = Color(0.62, 0.6, 0.56) * (0.8 + n[i] * 0.2)
			else:
				h[i] = n[i] * 0.25
				var col := color * (0.78 + hv * 0.32 + n[i] * 0.12)
				col.a = 1.0
				c[i] = col
	var m := _material(_build(s, h, c, 2.5), 0.85, 0.0, 2.0)
	_cache[key] = m
	return m


static func plaster(color: Color) -> StandardMaterial3D:
	return acg("Plaster001", 2.5, _rel(color, Color(0.75, 0.73, 0.7)))
	var key := "plaster%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.05, 41)
	var f := _noise(s, 0.3, 42, 1)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			h[i] = f[i] * 0.18 + n[i] * 0.12
			var streak := 0.07 * smoothstep(0.55, 0.9, n[i])
			var col := color * (0.93 + f[i] * 0.07 - streak)
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 1.2), 0.9, 0.0, 3.0)
	_cache[key] = m
	return m


static func asphalt() -> StandardMaterial3D:
	return acg("Asphalt025C", 4.0)
	if _cache.has("asphalt"):
		return _cache["asphalt"]
	var s := 128
	var n := _noise(s, 0.04, 51)
	var f := _noise(s, 0.45, 52, 1)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			h[i] = f[i] * 0.4
			var v := 0.18 + n[i] * 0.06 + (0.08 if f[i] > 0.78 else 0.0)
			c[i] = Color(v, v, v * 1.03)
	var m := _material(_build(s, h, c, 1.5), 0.92, 0.0, 3.0)
	_cache["asphalt"] = m
	return m


static func sand() -> StandardMaterial3D:
	return acg("Ground054", 4.0)
	if _cache.has("sand"):
		return _cache["sand"]
	var s := 256
	var n := _noise(s, 0.015, 61)
	var f := _noise(s, 0.25, 62, 2)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	var base := Color(0.82, 0.68, 0.47)
	for y in s:
		for x in s:
			var i := y * s + x
			var r := sin((float(x) + n[i] * 90.0) / s * TAU * 7.0)
			h[i] = r * 0.4 + f[i] * 0.3
			var col := base * (0.86 + r * 0.05 + n[i] * 0.16 + f[i] * 0.05)
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 1.5), 0.95, 0.0, 8.0)
	_cache["sand"] = m
	return m


static func wood() -> StandardMaterial3D:
	return acg("Planks023A", 1.4)
	if _cache.has("wood"):
		return _cache["wood"]
	var s := 128
	var n := _noise(s, 0.06, 71)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	var base := Color(0.55, 0.4, 0.24)
	for y in s:
		for x in s:
			var i := y * s + x
			var gap := y % 32 < 2
			var grain := sin(float(x) * 0.35 + n[i] * 10.0) * 0.5 + 0.5
			h[i] = -1.0 if gap else grain * 0.2
			var col := base * (0.42 if gap else (0.82 + grain * 0.18 + n[i] * 0.1))
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 2.0), 0.8, 0.0, 1.2)
	_cache["wood"] = m
	return m


static func sandbag() -> StandardMaterial3D:
	if _cache.has("sandbag"):
		return _cache["sandbag"]
	var s := 128
	var n := _noise(s, 0.12, 81, 2)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	var base := Color(0.6, 0.53, 0.38)
	for y in s:
		for x in s:
			var i := y * s + x
			var row := y / 32
			var off := 32 if row % 2 == 1 else 0
			var u := float((x + off) % 64) / 64.0 * 2.0 - 1.0
			var v := float(y % 32) / 32.0 * 2.0 - 1.0
			var bulge := sqrt(maxf(0.0, 1.0 - u * u * u * u - v * v))
			h[i] = bulge + n[i] * 0.15
			var col := base * (0.55 + bulge * 0.45 + n[i] * 0.1)
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 3.0), 0.95, 0.0, 1.0)
	_cache["sandbag"] = m
	return m


static func hesco() -> StandardMaterial3D:
	if _cache.has("hesco"):
		return _cache["hesco"]
	var s := 128
	var n := _noise(s, 0.05, 91)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	var base := Color(0.66, 0.58, 0.42)
	for y in s:
		for x in s:
			var i := y * s + x
			var wire := x % 16 < 1 or y % 16 < 1
			var post := x % 64 < 3
			h[i] = (0.6 if wire else 0.0) + (0.8 if post else 0.0) + n[i] * 0.3
			var col := base * (0.85 + n[i] * 0.2)
			if wire or post:
				col = Color(0.42, 0.42, 0.4)
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 2.0), 0.9, 0.1, 1.6)
	_cache["hesco"] = m
	return m


static func metal_plate(color := Color(0.42, 0.44, 0.46)) -> StandardMaterial3D:
	return acg("MetalPlates006", 1.6, _rel(color, Color(0.42, 0.44, 0.46)))
	var key := "plate%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.05, 101)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			var cx := x % 16
			var cy := y % 16
			var flip := ((x / 16) + (y / 16)) % 2 == 0
			var tread := absi(cx - cy) < 2 if flip else absi(cx + cy - 15) < 2
			h[i] = (0.7 if tread else 0.0) + n[i] * 0.1
			var col := color * (0.8 + n[i] * 0.25 + (0.12 if tread else 0.0))
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 2.0), 0.45, 0.75, 1.0)
	_cache[key] = m
	return m


static func painted_metal(color: Color) -> StandardMaterial3D:
	var key := "pmetal%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.06, 111)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			h[i] = n[i] * 0.15
			var col := color * (0.85 + n[i] * 0.2)
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 1.0), 0.5, 0.55, 2.0)
	_cache[key] = m
	return m


static func rock() -> StandardMaterial3D:
	if _cache.has("rock"):
		return _cache["rock"]
	var s := 128
	var n := _noise(s, 0.04, 121, 5)
	var f := _noise(s, 0.18, 122, 3)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	var base := Color(0.6, 0.5, 0.4)
	for y in s:
		for x in s:
			var i := y * s + x
			h[i] = n[i] * 0.8 + f[i] * 0.4
			var col := base * (0.62 + n[i] * 0.35 + f[i] * 0.12)
			col.a = 1.0
			c[i] = col
	var m := _material(_build(s, h, c, 4.0), 0.9, 0.0, 3.0)
	_cache["rock"] = m
	return m


static func camo(local := true) -> StandardMaterial3D:
	var key := "camo%s" % local
	if _cache.has(key):
		return _cache[key]
	var s := 128
	var n := _noise(s, 0.05, 131, 3)
	var f := _noise(s, 0.09, 132, 3)
	var g := _noise(s, 0.4, 133, 1)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for y in s:
		for x in s:
			var i := y * s + x
			var col := Color(0.42, 0.42, 0.3)
			if n[i] > 0.62:
				col = Color(0.27, 0.3, 0.2)
			if f[i] > 0.66:
				col = Color(0.36, 0.29, 0.2)
			if n[i] < 0.28:
				col = Color(0.52, 0.5, 0.38)
			h[i] = g[i] * 0.3
			c[i] = col * (0.9 + g[i] * 0.15)
	var m := _material(_build(s, h, c, 1.5), 0.92, 0.0, 0.6, not local)
	_cache[key] = m
	return m


static func gun_metal() -> StandardMaterial3D:
	if _cache.has("gun_metal"):
		return _cache["gun_metal"]
	var s := 64
	var n := _noise(s, 0.2, 141, 2)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for i in s * s:
		h[i] = n[i] * 0.1
		var v := 0.1 + n[i] * 0.04
		c[i] = Color(v, v, v * 1.05)
	var m := _material(_build(s, h, c, 1.0), 0.38, 0.75, 0.2, false)
	_cache["gun_metal"] = m
	return m


static func gun_polymer(color := Color(0.16, 0.16, 0.15)) -> StandardMaterial3D:
	var key := "gun_poly%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var s := 64
	var n := _noise(s, 0.5, 151, 1)
	var arr := _arrays(s)
	var h: PackedFloat32Array = arr[0]
	var c: PackedColorArray = arr[1]
	for i in s * s:
		h[i] = n[i] * 0.4
		var col := color * (0.9 + n[i] * 0.15)
		col.a = 1.0
		c[i] = col
	var m := _material(_build(s, h, c, 1.5), 0.72, 0.05, 0.1, false)
	_cache[key] = m
	return m


## Tint relative to the colour the old generated material was designed around,
## so per-map colour choices carry over to the scanned textures.
static func _rel(c: Color, base: Color) -> Color:
	return Color(clampf(c.r / base.r, 0.2, 1.6), clampf(c.g / base.g, 0.2, 1.6), clampf(c.b / base.b, 0.2, 1.6))


static func floor_concrete(tint := Color.WHITE) -> StandardMaterial3D:
	return acg("Concrete044B", 3.0, tint)
