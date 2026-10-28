extends SceneTree
## Prints key bone positions (skeleton space, idle frame 0) of the FPS arms rig.


func _initialize() -> void:
	var inst: Node3D = load("res://assets/fps_ak74m/scene.gltf").instantiate()
	root.add_child(inst)
	var skel: Skeleton3D = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	ap.play("Rig|AK_Idle")
	ap.advance(0.0)
	await_frame()
	var chain := Transform3D.IDENTITY
	var n: Node = skel
	while n != inst:
		if n is Node3D:
			chain = (n as Node3D).transform * chain
		n = n.get_parent()
	print("skeleton->inst basis: ", chain.basis, " origin ", chain.origin)
	for b in ["Root_01", "Head_Cam_014", "Head_Cam_end_066", "Rif_059", "Rif_end_079", "Hand_R_037", "Hand_L_016", "Pmag_062", "Arm_R_08", "Forearm_R_010"]:
		var i := skel.find_bone(b)
		var gp := skel.get_bone_global_pose(i)
		print("%-18s pos=%s  inst=%s  Y=%s Z=%s" % [b, gp.origin.snapped(Vector3.ONE * 0.001), (chain * gp.origin).snapped(Vector3.ONE * 0.001), gp.basis.y.normalized().snapped(Vector3.ONE * 0.01), gp.basis.z.normalized().snapped(Vector3.ONE * 0.01)])
	for mi in skel.find_children("*", "MeshInstance3D", true, false):
		print("mesh ", mi.name, " aabb ", (mi as MeshInstance3D).get_aabb())
	quit()


func await_frame() -> void:
	pass
