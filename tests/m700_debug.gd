extends SceneTree
## Imports the M700 FBX, prints its bounds and renders it from the side / top.


func _initialize() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.55, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 0.9)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	var inst: Node3D = load("res://assets/m700/SKM_SniperR700.fbx").instantiate()
	root.add_child(inst)
	_run.call_deferred(inst)


func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first := true
	var t := xf * (n as Node3D).transform if n is Node3D else xf
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


func _run(inst: Node3D) -> void:
	await process_frame
	var box := _aabb(inst, Transform3D.IDENTITY)
	print("M700 aabb ", box)
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		print("mesh ", m.name, " surfaces=", m.mesh.get_surface_count(), " skin=", m.skin != null)
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		var s := sk as Skeleton3D
		var names: Array = []
		for i in s.get_bone_count():
			names.append(s.get_bone_name(i))
		print("bones ", names)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var c := box.get_center()
	var dist := box.size.length() * 0.9
	for view in [["side_x", Vector3(dist, 0, 0)], ["side_z", Vector3(0, 0, dist)], ["top", Vector3(0, dist, 0.001)]]:
		cam.global_position = c + view[1]
		cam.look_at(c, Vector3.UP if view[0] != "top" else Vector3.FORWARD)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://screenshots/m700_%s.png" % view[0])
	quit()
