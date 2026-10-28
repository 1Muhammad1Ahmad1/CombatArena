extends SceneTree
## Renders the FPS rig from outside (side / top / front) with the camera bone marked.
## Run with a GPU window:  Godot --path . -s res://tests/rig_debug.gd


var inst: Node3D
var skel: Skeleton3D
var cam: Camera3D


func _initialize() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.55, 0.6)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	root.add_child(sun)
	inst = load("res://assets/fps_ak74m/scene.gltf").instantiate()
	root.add_child(inst)
	skel = inst.find_children("*", "Skeleton3D", true, false)[0]
	var ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
	ap.play("Rig|AK_Idle")
	ap.seek(0.5, true)
	cam = Camera3D.new()
	root.add_child(cam)
	cam.current = true
	_run.call_deferred()


func _marker(p: Vector3, c: Color) -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.03
	s.height = 0.06
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	root.add_child(m)
	m.global_position = p


func _run() -> void:
	await process_frame
	await process_frame
	var b := func(n: String) -> Vector3: return (skel.global_transform * skel.get_bone_global_pose(skel.find_bone(n))).origin
	_marker(b.call("Head_Cam_014"), Color.RED)
	_marker(b.call("Head_Cam_end_066"), Color.ORANGE)
	_marker(b.call("Rif_059"), Color.BLUE)
	_marker(b.call("Rif_end_079"), Color.CYAN)
	_marker(b.call("Hand_R_037"), Color.GREEN)
	_marker(b.call("Hand_L_016"), Color.YELLOW)
	for n in ["Head_Cam_014", "Rif_059", "Rif_end_079", "Hand_R_037", "Hand_L_016"]:
		print(n, " world=", (b.call(n) as Vector3).snapped(Vector3.ONE * 0.001))
	var c: Vector3 = b.call("Rif_059")
	for view in [["side", Vector3(3, 0, 0)], ["top", Vector3(0, 3, 0.01)], ["front", Vector3(0, 0, 3)], ["back", Vector3(0, 0.3, -3)]]:
		cam.global_position = c + view[1]
		cam.look_at(c, Vector3.UP if view[0] != "top" else Vector3.FORWARD)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://screenshots/rig_%s.png" % view[0])
		print("saved ", view[0])
	quit()
