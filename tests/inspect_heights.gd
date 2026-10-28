extends SceneTree
## Diagnostic: rest heights of neck/head bones on each soldier, and IK classes available.

func _init() -> void:
	for f in ["swat", "gas_mask", "swat_guy"]:
		var inst: Node = load("res://assets/mixamo/%s.fbx" % f).instantiate()
		var sk: Skeleton3D = inst.get_node("Skeleton3D")
		var out := []
		for b in ["mixamorig_Neck", "mixamorig_Head", "mixamorig_HeadTop_End", "mixamorig_Spine2"]:
			var i := sk.find_bone(b)
			if i != -1:
				out.append("%s=%.3f" % [b.trim_prefix("mixamorig_"), sk.get_bone_global_rest(i).origin.y])
		print(f, " ", out)
		inst.free()
	for c in ["TwoBoneIK3D", "SkeletonIK3D", "LookAtModifier3D", "SkeletonModifier3D", "CCDIK3D", "FABRIK3D"]:
		print(c, " exists=", ClassDB.class_exists(c))
	quit()
