extends SceneTree
## Prints the merged mesh AABB of every imported glTF asset (run with -s).


func _initialize() -> void:
	var paths: Array = []
	for d in DirAccess.get_directories_at("res://assets/polyhaven"):
		paths.append("res://assets/polyhaven/%s/%s_1k.gltf" % [d, d])
	for p in paths:
		if true:
			var f: String = p.get_file()
			var ps: PackedScene = load(p)
			var inst: Node3D = ps.instantiate()
			root.add_child(inst)
			var box := _aabb(inst, Transform3D.IDENTITY)
			var anim := ""
			var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
			if ap:
				anim = " anims=%d" % ap.get_animation_list().size()
			print("%-28s size=%s pos=%s%s" % [f, box.size.snapped(Vector3.ONE * 0.01), box.position.snapped(Vector3.ONE * 0.01), anim])
			inst.queue_free()
	quit()


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		out = t * (n as MeshInstance3D).get_aabb()
		first = false
	for c in n.get_children():
		var a := _aabb(c, t)
		if a.size == Vector3.ZERO:
			continue
		out = a if first else out.merge(a)
		first = false
	return out
