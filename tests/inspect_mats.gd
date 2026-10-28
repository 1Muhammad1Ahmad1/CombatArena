extends SceneTree
## Diagnostic: material settings (transparency, textures) used by kit models.


func _init() -> void:
	for id in OS.get_cmdline_user_args():
		var path := ""
		for dir in ["res://assets/downloads/urban/models/", "res://assets/downloads/warehouse/models/", "res://assets/downloads/desert/models/", "res://assets/downloads/shared/models/"]:
			if ResourceLoader.exists("%s%s/%s_1k.gltf" % [dir, id, id]):
				path = "%s%s/%s_1k.gltf" % [dir, id, id]
		var inst: Node = load(path).instantiate()
		var seen := {}
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			for sidx in mi.mesh.get_surface_count():
				var m = mi.mesh.surface_get_material(sidx)
				if m and not seen.has(m):
					seen[m] = true
					print(id, " mat=", m.resource_name, " transp=", m.transparency, " cull=", m.cull_mode, " albedo=", m.albedo_texture.get_width() if m.albedo_texture else 0, " used_by=", mi.name)
		inst.free()
	quit()
