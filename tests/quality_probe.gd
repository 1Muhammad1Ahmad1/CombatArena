extends "res://tests/test_suite.gd"
## Image-quality probe: one fixed camera, one setting changed at a time. For each
## configuration it saves a still and a 12-frame slow pan (for shimmer analysis
## in tools/quality_metrics.py). Bots are hidden so only the camera moves.
## Run (GPU window):  Godot --path . --resolution 1280x720 -- --quality-probe=<dir> [--probe-map=0] [--probe-configs=a,b]

const VIEWS := [
	[Vector3(30, 0, 2), PI / 2.0, 0.02],      # warehouse: down the hall toward the far wall and roof
	[Vector3(0, 0, -36), PI, 0.03],           # urban: street canyon
	[Vector3(0, 0, -43), PI, 0.02],           # desert: compound and hills
]
const ALL := ["base", "fog_off", "shafts_off", "ssao_off", "ssao_q2", "aniso16", "aa_none", "aa_taa", "aa_msaa2", "mip_bias_neg"]

var out_dir := ""
var fog_default := true


func _run() -> void:
	var map_id := 0
	var configs: Array = ALL
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality-probe="):
			out_dir = a.get_slice("=", 1)
		if a.begins_with("--probe-map="):
			map_id = int(a.get_slice("=", 1))
		if a.begins_with("--probe-configs="):
			configs = Array(a.get_slice("=", 1).split(","))
	DirAccess.make_dir_recursive_absolute(out_dir)
	await _frames(5)
	main.start_match(map_id)
	var m = await _wait_match(null)
	_freeze_bots(m, true)
	for b in m.bots:
		b.bench()
	var p = m.player
	p.health.hp = 1.0e9
	p.set_physics_process(false)
	var view: Array = VIEWS[map_id]
	fog_default = m.map.env.fog_enabled
	for c in configs:
		_reset(m)
		_apply(m, c)
		p.spawn_at(view[0], view[1])
		p.set_physics_process(false)
		p.pitch = view[2]
		await _frames(40)   # let TAA / SSAO / exposure settle
		await _shot("%s_still.png" % c)
		for i in 12:
			p.rotation.y = view[1] + i * 0.0015
			await _frames(1)
			await _shot("%s_pan%02d.png" % [c, i])
		print("probe ", c, " done")
	if "--probe-ghost" in OS.get_cmdline_user_args():
		await _ghost(m, view)
	get_tree().quit(0)


## TAA ghosting check: a bot runs across the view at sprint speed (4.6 m/s) 7 m away.
func _ghost(m, view: Array) -> void:
	_reset(m)
	var p = m.player
	p.spawn_at(view[0], view[1])
	p.set_physics_process(false)
	p.pitch = 0.0
	var fwd := Vector3(-sin(view[1]), 0, -cos(view[1]))
	var side := fwd.cross(Vector3.UP)
	var b = m.bots[0]
	b.respawn(view[0] + fwd * 7.0 - side * 4.0)
	await _frames(1)
	b.set_physics_process(false)
	b.rotation.y = atan2(-side.x, -side.z)
	b._play("Run", 0.0)
	for i in 70:
		b.global_position = view[0] + fwd * 7.0 - side * 4.0 + side * (i * 4.6 / 60.0)
		await _frames(1)
		if i in [40, 50, 60]:
			await _shot("ghost_%02d.png" % i)
	print("probe ghost done")


func _reset(m) -> void:
	Settings.apply()   # back to the saved preset
	var vp := get_viewport()
	vp.texture_mipmap_bias = 0.0
	var e: Environment = m.map.env
	e.fog_enabled = fog_default
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, true, 0.5, 1, 50.0, 300.0)
	for n in m.find_children("*", "MeshInstance3D", true, false):
		if n.mesh is QuadMesh:
			n.visible = true


func _apply(m, c: String) -> void:
	var vp := get_viewport()
	var e: Environment = m.map.env
	match c:
		"fog_off":
			e.fog_enabled = false
		"shafts_off":
			for n in m.find_children("*", "MeshInstance3D", true, false):
				if n.mesh is QuadMesh:
					n.visible = false
		"ssao_off":
			e.ssao_enabled = false
		"ssao_q2":
			RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_MEDIUM, true, 0.5, 2, 50.0, 300.0)
		"aniso16":
			vp.anisotropic_filtering_level = Viewport.ANISOTROPY_16X
		"aa_none":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		"aa_taa":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.use_taa = true
		"aa_smaa":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA
		"aa_msaa2":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			vp.msaa_3d = Viewport.MSAA_2X
		"mip_bias_neg":   # what FSR 2 at 67 % does on High (about -0.58)
			vp.texture_mipmap_bias = -0.58


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file))
