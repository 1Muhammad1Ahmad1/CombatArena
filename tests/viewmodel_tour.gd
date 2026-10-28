extends "res://tests/test_suite.gd"
## Captures first-person frames across the weapon animations for visual review.
## Run (GPU window):  Godot --path . --resolution 1280x720 -- --viewmodel-tour=<dir>

var out_dir := ""


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--viewmodel-tour="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	main.start_match(1)
	var m = await _wait_match(null)
	_freeze_bots(m, true)
	for b in m.bots:
		b.bench()
	var p = m.player
	await _secs(3.5)
	p.spawn_at(Vector3(0, 0, -25), PI)
	p.health.hp = 1.0e9
	p.pitch = -0.04
	await _secs(1.2)
	await _shot("01_ar_hip_idle.png")
	p.force_aim = true
	await _secs(0.6)
	await _shot("02_ar_ads.png")
	p.force_aim = false
	await _secs(0.5)
	Input.action_press("fire")
	await _frames(3)
	await _shot("03_ar_fire.png")
	Input.action_release("fire")
	await _secs(0.6)
	p.pitch = -0.04
	p.weapons[0].ammo = 10
	await _tap("reload")
	await _secs(0.45)
	await _shot("04_ar_reload_25.png")
	await _secs(0.5)
	await _shot("05_ar_reload_50.png")
	await _secs(0.5)
	await _shot("06_ar_reload_75.png")
	await _secs(1.0)
	p.weapons[0].ammo = 0
	await _tap("reload")
	await _secs(1.2)
	await _shot("07_ar_reload_empty_mid.png")
	await _secs(2.0)
	await _tap("switch_weapon")
	await _frames(6)
	await _shot("08_switch_to_sniper.png")
	await _secs(0.6)
	await _shot("09_sniper_hip.png")
	p.force_aim = true
	await _frames(9)
	await _shot("09b_sniper_ads_transition.png")
	p.force_aim = false
	await _secs(0.5)
	Input.action_press("fire")
	await _frames(2)
	Input.action_release("fire")
	await _frames(14)
	await _shot("09c_sniper_bolt_open.png")
	await _secs(1.2)
	p.weapons[1].ammo = 2
	await _tap("reload")
	await _secs(1.2)
	await _shot("09d_sniper_reload_mid.png")
	await _secs(2.0)
	p.force_aim = true
	await _secs(0.6)
	await _shot("10_sniper_scope.png")
	p.force_aim = false
	await _secs(0.4)
	await _tap("switch_weapon")
	await _frames(10)
	await _shot("11_switch_to_ar_draw.png")
	await _secs(0.8)
	Input.action_press("move_forward")
	await _secs(0.5)
	await _shot("12_ar_walk.png")
	Input.action_press("sprint")
	await _secs(0.5)
	await _shot("13_ar_sprint.png")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	get_tree().quit(0)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)

