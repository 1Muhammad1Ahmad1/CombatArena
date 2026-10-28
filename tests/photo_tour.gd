extends "res://tests/test_suite.gd"
## Captures matching screenshots from fixed viewpoints on every map.
## Run (with a GPU window):  Godot --path . -- --photo-tour=<output dir>
## View A: a wide look across the map.
## View B: a bot frozen 6 m in front of the camera, rifle at the hip.

const VIEWS := [
	{"a": [Vector3(30, 0, 2), PI / 2.0], "b": [Vector3(10, 0, -1), PI / 2.0],
		"c": [Vector3(0, 3.5, 20), 0.0, -0.12], "d": [Vector3(-28.5, 0, -18), PI * 0.75, 0.05]},
	{"a": [Vector3(0, 0, -36), PI], "b": [Vector3(0, 0, -25), PI],
		"c": [Vector3(-36, 0, 1), -PI / 2.0, 0.08], "d": [Vector3(17, 4.0, 16), PI / 4.0, -0.05]},
	{"a": [Vector3(0, 0, -43), PI], "b": [Vector3(0, 0, -43), PI],
		"c": [Vector3(19, 5.0, -19), PI * 0.75, -0.08], "d": [Vector3(40, 0, 30), PI / 2.0, 0.02]},
]

var out_dir := ""


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--photo-tour="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	var only := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tour-map="):
			only = int(a.get_slice("=", 1))
	for id in MapRegistry.MAPS.size():
		if only >= 0 and id != only:
			continue
		main.start_match(id)
		var m = await _wait_match(main.match_node if id > 0 else null)
		if m == null:
			continue
		_freeze_bots(m, true)
		var p = m.player
		p.health.hp = 1.0e9
		for b in m.bots:
			b.set_physics_process(false)
			b.visible = false
		await _secs(3.5)   # let any pending respawn timer fire before posing
		var sp: Vector3 = VIEWS[id].a[0]
		var yaw: float = VIEWS[id].a[1]
		p.spawn_at(sp, yaw)
		p.health.hp = 1.0e9
		await _frames(40)
		await _shot("map%d_a.png" % id)
		for k in ["c", "d"]:
			p.spawn_at(VIEWS[id][k][0], VIEWS[id][k][1])
			p.health.hp = 1.0e9
			await _frames(5)
			p.pitch = VIEWS[id][k][2]
			await _frames(30)
			await _shot("map%d_%s.png" % [id, k])
		sp = VIEWS[id].b[0]
		yaw = VIEWS[id].b[1]
		p.spawn_at(sp, yaw)
		p.health.hp = 1.0e9
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var b0 = m.bots[0]
		b0.set_physics_process(false)   # posed model, no simulation
		b0.visible = true
		b0.velocity = Vector3.ZERO
		b0.global_position = sp + fwd * 6.0
		if "anim" in b0 and b0.anim:
			b0.anim.play("Idle_Shoot")
		b0.rotation.y = yaw + PI
		b0.yaw_target = b0.rotation.y
		p.pitch = -0.05
		await _frames(30)
		print("bot0 pos=", b0.global_position, " visible=", b0.is_visible_in_tree(), " alive=", b0.alive, " cam=", p.camera.global_position)
		await _shot("map%d_b.png" % id)
	get_tree().quit(0)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("saved ", out_dir.path_join(file))
