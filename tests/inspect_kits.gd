extends SceneTree
## Diagnostic: lists the pieces (meshes) of Poly Haven modular kits with their bounds.


func _init() -> void:
	var ids := OS.get_cmdline_user_args()
	for id in ids:
		var inst: Node3D = load(_path(id)).instantiate()
		print("=== ", id)
		_walk(inst, Transform3D.IDENTITY, 0)
		inst.free()
	quit()


func _walk(n: Node, xf: Transform3D, d: int) -> void:
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var b: AABB = t * mi.get_aabb()
		var tris := 0
		for s in mi.mesh.get_surface_count():
			tris += mi.mesh.surface_get_array_index_len(s) / 3
		print("  ".repeat(d), n.name, " pos=", b.position.snapped(Vector3.ONE * 0.01), " size=", b.size.snapped(Vector3.ONE * 0.01), " tris=", tris)
	elif d < 3:
		print("  ".repeat(d), n.name, " (", n.get_class(), ")")
	for c in n.get_children():
		_walk(c, t, d + 1)


func _path(id: String) -> String:
	for dir in ["res://assets/polyhaven/", "res://assets/downloads/urban/models/", "res://assets/downloads/warehouse/models/",
			"res://assets/downloads/desert/models/", "res://assets/downloads/shared/models/"]:
		var p := "%s%s/%s_1k.gltf" % [dir, id, id]
		if ResourceLoader.exists(p):
			return p
	return ""
