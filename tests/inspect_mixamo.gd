extends SceneTree
## Diagnostic: prints node tree, skeleton, animations and bounds of the Mixamo imports.
## Run: Godot --headless --path . --script res://tests/inspect_mixamo.gd

const FILES := ["swat", "swat_guy", "gas_mask", "idle", "walk", "run", "fire", "hit", "death"]


func _init() -> void:
	for f in FILES:
		var inst: Node = load("res://assets/mixamo/%s.fbx" % f).instantiate()
		print("=== ", f)
		_tree(inst, 0)
		var sk: Skeleton3D = inst.find_child("*", true, false) as Skeleton3D
		for n in inst.find_children("*", "Skeleton3D", true, false):
			sk = n
		if sk:
			print("  bones=", sk.get_bone_count(), " hips_rest=", sk.get_bone_rest(sk.find_bone("mixamorig_Hips")).origin,
				" first=", sk.get_bone_name(0), " skel_scale=", sk.scale, " path=", inst.get_path_to(sk))
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			for a in ap.get_animation_list():
				var an: Animation = ap.get_animation(a)
				var kinds := {}
				for t in an.get_track_count():
					var k := an.track_get_type(t)
					kinds[k] = kinds.get(k, 0) + 1
				print("  anim '", a, "' len=", an.length, " tracks=", an.get_track_count(), " types=", kinds,
					" t0=", an.track_get_path(0), " root=", ap.root_node)
		var aabb := AABB()
		var first := true
		for m in inst.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var b: AABB = mi.global_transform * mi.get_aabb() if mi.is_inside_tree() else mi.transform * mi.get_aabb()
			aabb = b if first else aabb.merge(b)
			first = false
			print("  mesh ", mi.name, " surfaces=", mi.mesh.get_surface_count(), " verts~", mi.mesh.surface_get_array_len(0))
		if not first:
			print("  aabb=", aabb)
		inst.free()
	quit()


func _tree(n: Node, d: int) -> void:
	if d > 4:
		return
	print("  ".repeat(d + 1), n.name, " (", n.get_class(), ") ", n.get("transform").basis.get_scale() if n is Node3D else "")
	for c in n.get_children():
		if not (n is Skeleton3D and c is MeshInstance3D and d > 3):
			_tree(c, d + 1)
