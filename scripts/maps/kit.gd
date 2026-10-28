extends RefCounted
## Pulls individual pieces out of Poly Haven modular kits (one glTF holding many
## named meshes laid out side by side). Each piece is cached as its mesh plus
## the transform it had inside the kit file, so callers can place it relative
## to the kit's own module origin.

static var _kits := {}


static func piece(kit_id: String, piece_name: String) -> Dictionary:
	if not _kits.has(kit_id):
		var path := _path(kit_id)
		var inst: Node3D = load(path).instantiate()
		var pieces := {}
		_collect(inst, Transform3D.IDENTITY, pieces)
		inst.free()
		_kits[kit_id] = pieces
	var p: Dictionary = _kits[kit_id].get(piece_name, {})
	if p.is_empty() and piece_name != "":
		push_error("Kit piece not found: %s/%s" % [kit_id, piece_name])
	return p


## All piece names in a kit that start with `prefix`.
static func names(kit_id: String, prefix: String) -> Array:
	piece(kit_id, "")   # makes sure the kit is loaded and cached
	var out: Array = []
	for k in _kits[kit_id]:
		if String(k).begins_with(prefix):
			out.append(k)
	return out


static func _collect(n: Node, xf: Transform3D, out: Dictionary) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mesh: Mesh = (n as MeshInstance3D).mesh
		for s in mesh.get_surface_count():
			_optimise(mesh.surface_get_material(s) as BaseMaterial3D)
		out[String(n.name)] = {"mesh": mesh, "xf": t}
	for c in n.get_children():
		_collect(c, t, out)


static func _path(id: String) -> String:
	for dir in ["res://assets/downloads/urban/models/", "res://assets/downloads/warehouse/models/",
			"res://assets/downloads/desert/models/", "res://assets/downloads/shared/models/", "res://assets/polyhaven/"]:
		var p := "%s%s/%s_1k.gltf" % [dir, id, id]
		if ResourceLoader.exists(p):
			return p
	return ""


## Facades are only seen from outside: single-sided, and the window glass is
## made opaque (dark, glossy) so it stays in the cheap opaque pass and reads as
## glass against the dark interiors.
static func _optimise(m: BaseMaterial3D) -> void:
	if m == null or m.has_meta("kit_optimised"):
		return
	m.set_meta("kit_optimised", true)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	# wall surfaces take the per-building tint (MultiMesh instance colour)
	var nm := m.resource_name
	if nm.ends_with("_plaster") or nm.ends_with("_brick") or nm.ends_with("_brick_doors"):
		m.vertex_color_use_as_albedo = true
	if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color = Color(0.05, 0.06, 0.07)
		m.albedo_texture = null
		m.roughness = 0.08
		m.metallic = 0.5


static var _lods := {}


## A permanently simplified copy of `mesh` built from the LOD index buffers Godot
## generated at import (first LOD at or below `ratio` of the original triangle
## count). Used for facade sides seen from a distance. Returns the mesh itself
## when it is already light or has no usable LOD.
static func lod_mesh(mesh: Mesh, ratio := 0.35) -> Mesh:
	var key := "%d|%.2f" % [mesh.get_rid().get_id(), snappedf(ratio, 0.05)]
	if _lods.has(key):
		return _lods[key]
	var out := ArrayMesh.new()
	var reduced := false
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var full: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var surf := RenderingServer.mesh_get_surface(mesh.get_rid(), si)
		var verts: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var best: PackedByteArray
		for lod in surf.get("lods", []):   # ordered from most to least detailed
			var data: PackedByteArray = lod["index_data"]
			var count := data.size() / (2 if verts <= 65535 else 4)
			if count < 36:
				break
			best = data   # falls back to the smallest usable level
			if count <= full.size() * ratio:
				break
		if best.size() > 0 and full.size() > 1200:
			var idx := PackedInt32Array()
			if verts <= 65535:
				idx.resize(best.size() / 2)
				for i in idx.size():
					idx[i] = best.decode_u16(i * 2)
			else:
				idx = best.to_int32_array()
			arrays[Mesh.ARRAY_INDEX] = idx
			reduced = true
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_lods[key] = out if reduced else mesh
	return _lods[key]
