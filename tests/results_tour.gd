extends "res://tests/test_suite.gd"
## Captures the HUD clock and the end-of-match results screen (short test match).
## Run (GPU window):  Godot --path . --resolution 1280x720 -- --results-tour=<dir>

var out_dir := ""


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--results-tour="):
			out_dir = a.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	main.test_match_duration = 7.0
	main.start_match(1)
	var m = await _wait_match(null)
	m.player.health.hp = 1.0e9
	await _secs(1.0)
	m.bots[0].health.apply_damage(99999.0, m.player)
	m.bots[1].health.apply_damage(99999.0, m.bots[2])
	await _secs(1.0)
	await _shot("hud_clock.png")
	while not m.ended:
		await _frames(1)
	await _secs(0.8)
	await _shot("results.png")
	get_tree().quit(0)


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
	print("saved ", file)
