extends "res://tests/test_suite.gd"
## Captures the three bots side by side in each animation for visual review.
## Run (GPU window):  Godot --path . --resolution 1280x720 -- --bot-tour=<dir>

const SETS := [
	["01_idle_fire_walkfire", ["Idle", "Idle_Shoot", "Walk_Shoot"], 0.5],
	["02_walk_runfire_run", ["Walk", "Run_Shoot", "Run"], 0.4],
	["03_hit", ["HitReact", "HitReact", "HitReact"], 0.35],
	["04_death", ["Death", "Death", "Death"], 1.6],
]

var out_dir := ""


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot-tour="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	main.start_match(1)
	var m = await _wait_match(null)
	_freeze_bots(m, true)
	var p = m.player
	await _secs(3.5)
	p.spawn_at(Vector3(0, 0, -25), PI)
	p.health.hp = 1.0e9
	await _secs(0.3)
	p.set_process(false)
	for yaw in [0.55, -2.3]:
		for s in SETS:
			for i in 3:
				var b = m.bots[i]
				b.respawn(Vector3(-1.2 + i * 1.2, 0.0, -21.9))
				await _frames(1)
				b.set_physics_process(false)
				b.rotation.y = yaw
				b._play(s[1][i], 0.0)
			p.pitch = -0.2
			for v in p.views:
				v.visible = false
			await _secs(s[2])
			await _shot("%s_%s.png" % [s[0], "front" if yaw > 0 else "back"])
			for i in 3:
				var b = m.bots[i]
				var rf: Vector3 = -b.rifle.global_basis.z
				var bf: Vector3 = -b.global_basis.z
				print("AIM %s %s yaw_off=%.0f deg pitch=%.0f deg left_hand_ik_error=%.3f m" % [b.bot_name, s[1][i],
					rad_to_deg(Vector2(bf.x, bf.z).angle_to(Vector2(rf.x, rf.z))), rad_to_deg(asin(rf.y)), b.ik_error])
	for i in 3:
		m.bots[i].bench()
	var c = m.bots[1]
	for yaw_i in 4:
		c.respawn(Vector3(0.0, 0.0, -22.9))
		await _frames(1)
		c.set_physics_process(false)
		c.rotation.y = yaw_i * PI / 2.0
		c._play("Idle_Shoot", 0.0)
		p.pitch = -0.08
		await _secs(0.4)
		await _shot("05_closeup_fire_yaw%d.png" % (yaw_i * 90))
	get_tree().quit(0)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)
