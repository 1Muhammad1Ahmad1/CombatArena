extends Node
## Application flow: main menu -> map select -> match, plus settings overlay.
## Run with `-- --run-tests` to execute the automated acceptance suite.

const MainMenu = preload("res://scripts/ui/main_menu.gd")
const MapSelect = preload("res://scripts/ui/map_select.gd")
const SettingsMenu = preload("res://scripts/ui/settings_menu.gd")
const Match = preload("res://scripts/game/match.gd")
const MapRegistry = preload("res://scripts/maps/map_registry.gd")
const UiKit = preload("res://scripts/ui/ui_kit.gd")

var ui_layer: CanvasLayer
var current_menu: Control
var settings_menu: Control
var match_node: Node3D
var test_match_duration := 0.0   # > 0 only in automated tests
var loading: Control
var current_map := 0


func _ready() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)
	var args := OS.get_cmdline_user_args()
	var tool_script := ""
	if "--run-tests" in args:
		tool_script = "res://tests/test_suite.gd"
	elif "--debug-nav" in args:
		tool_script = "res://tests/debug_nav.gd"
	for a in args:
		if a.begins_with("--photo-tour="):
			tool_script = "res://tests/photo_tour.gd"
		if a.begins_with("--viewmodel-tour="):
			tool_script = "res://tests/viewmodel_tour.gd"
		if a.begins_with("--bot-tour="):
			tool_script = "res://tests/bot_tour.gd"
		if a.begins_with("--quality-probe="):
			tool_script = "res://tests/quality_probe.gd"
		if a.begins_with("--results-tour="):
			tool_script = "res://tests/results_tour.gd"
	if tool_script != "":
		var script = load(tool_script)
		if script == null or not script.can_instantiate():
			printerr("Test suite failed to load")
			get_tree().quit(2)
			return
		var suite = script.new()
		suite.main = self
		add_child(suite)
		return
	for a in args:
		if a.begins_with("--scene-stats="):   # diagnostics: triangle totals per model on a map, then quit
			_scene_stats(int(a.get_slice("=", 1)))
			return
		if a.begins_with("--showcase="):
			var id := clampi(int(a.get_slice("=", 1)), 0, MapRegistry.MAPS.size() - 1)
			start_match(id)
			if "--benchmark" in args:
				_benchmark(id)
			return
	show_main_menu()


## Measures the real rendered frame rate (VSync off) over 10 s of live combat.
var _ab_list := PackedStringArray()
## Repeatable benchmark route per map (eye positions; the camera is moved along it).
const BENCH_ROUTES := [
	[Vector3(30, 0, 2), Vector3(12, 0, -2), Vector3(-8, 0, 0), Vector3(-26, 0, 12), Vector3(-20, 3.5, 20), Vector3(20, 3.5, 20), Vector3(28, 0, -2)],
	[Vector3(0, 0, -36), Vector3(0, 0, -6), Vector3(-30, 0, 0), Vector3(0, 0, 0), Vector3(30, 0, 0), Vector3(0, 0, 4), Vector3(0, 0, 34)],
	[Vector3(0, 0, -43), Vector3(0, 0, -20), Vector3(-30, 0, -30), Vector3(-34, 0, 12), Vector3(0, 0, 30), Vector3(32, 0, 30), Vector3(34, 0, -8)],
]
const BENCH_ROUTE_SECS := 24.0


## Moves the (invulnerable) player along the map's route for 24 s while the bots fight,
## turning toward the travel direction with a +/-35 degree sweep. Reports average FPS,
## 1 % low FPS (mean of the slowest 1 % of frames), 99th-percentile frame time, GPU time
## and video memory.
func _bench_path(id: int) -> void:
	var route: Array = BENCH_ROUTES[id]
	var pl = match_node.player
	pl.health.hp = 1.0e9
	pl.set_physics_process(false)
	var lengths: Array = []
	var total := 0.0
	for i in route.size() - 1:
		var l: float = (route[i + 1] - route[i]).length()
		lengths.append(l)
		total += l
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var times := PackedFloat32Array()
	var gpu := 0.0
	var t0 := Time.get_ticks_usec()
	var last := t0
	while true:
		var now := Time.get_ticks_usec()
		var t := (now - t0) / 1_000_000.0
		if t >= BENCH_ROUTE_SECS:
			break
		var d := t / BENCH_ROUTE_SECS * total
		var seg := 0
		while seg < lengths.size() - 1 and d > lengths[seg]:
			d -= lengths[seg]
			seg += 1
		var a: Vector3 = route[seg]
		var b: Vector3 = route[seg + 1]
		var pos := a.lerp(b, clampf(d / maxf(lengths[seg], 0.01), 0.0, 1.0))
		var dir := (b - a).normalized()
		pl.global_position = pos
		pl.rotation.y = atan2(-dir.x, -dir.z) + sin(t * 1.3) * deg_to_rad(35.0)
		pl.pitch = sin(t * 0.7) * 0.08
		await get_tree().process_frame
		var after := Time.get_ticks_usec()
		times.append((after - last) / 1000.0)
		last = after
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
	times = times.slice(5)   # skip the first frames after teleporting
	var sorted := times.duplicate()
	sorted.sort()
	var n := sorted.size()
	var sum := 0.0
	for x in sorted:
		sum += x
	var worst := 0.0
	var k := maxi(1, n / 100)
	for i in k:
		worst += sorted[n - 1 - i]
	var vram := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	var tex := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0
	var internal := Vector2(get_viewport().size) * get_viewport().scaling_3d_scale
	var line := "PATH map=%s quality=%s window=%s internal=%dx%d avg_fps=%.1f low1_fps=%.1f p99_ms=%.1f max_ms=%.1f gpu_ms=%.2f vram_mb=%.0f tex_mb=%.0f frames=%d gpu=%s" % [
		MapRegistry.MAPS[id].name, Settings.QUALITY_NAMES[int(Settings.data.quality)], get_window().size, internal.x, internal.y,
		1000.0 * n / sum, 1000.0 / (worst / k), sorted[int(n * 0.99)], sorted[n - 1], gpu / maxf(times.size(), 1),
		vram, tex, n, RenderingServer.get_video_adapter_name()]
	print(line)
	var f := FileAccess.open("user://benchmark.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://benchmark.txt") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()


func _benchmark(id: int) -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-quality="):
			Settings.data.quality = clampi(int(a.get_slice("=", 1)), 0, 3)
			Settings.apply()
		if a.begins_with("--bench-res="):
			var wh := a.get_slice("=", 1).split("x")
			DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	while match_node == null or not match_node.started:
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bench-off="):   # profiling: switch features off to measure their cost
			_bench_off(match_node, a.get_slice("=", 1).split(","))
		if a.begins_with("--bench-ab="):
			_ab_list = a.get_slice("=", 1).split(",")
		if a.begins_with("--bench-spot="):   # fixed camera: x,y,z,yaw (player made invulnerable)
			var v := a.get_slice("=", 1).split(",")
			var pl = match_node.player
			pl.spawn_at(Vector3(float(v[0]), float(v[1]), float(v[2])), float(v[3]))
			pl.health.hp = 1.0e9
			pl.set_physics_process(false)
			await get_tree().create_timer(1.0).timeout
	if not _ab_list.is_empty():
		await _bench_ab(_ab_list)
		get_tree().quit()
		return
	if "--bench-path" in OS.get_cmdline_user_args():
		await _bench_path(id)
		get_tree().quit()
		return
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var cpu_ms := 0.0
	var gpu_ms := 0.0
	var samples := 0
	var frames0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	var worst := 0.0
	var last := t0
	while Time.get_ticks_usec() - t0 < 10_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		worst = maxf(worst, (now - last) / 1000.0)
		last = now
		cpu_ms += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
		samples += 1
	var secs := (Time.get_ticks_usec() - t0) / 1_000_000.0
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var line := "BENCH map=%s quality=%s res=%s avg_fps=%.1f worst_frame_ms=%.1f tris=%dk draws=%d render_cpu_ms=%.1f render_gpu_ms=%.1f gpu=%s" % [
		MapRegistry.MAPS[id].name, Settings.QUALITY_NAMES[int(Settings.data.quality)], get_window().size,
		(Engine.get_frames_drawn() - frames0) / secs, worst, prims / 1000, draws, cpu_ms / maxi(samples, 1), gpu_ms / maxi(samples, 1), RenderingServer.get_video_adapter_name()]
	print(line)
	var f := FileAccess.open("user://benchmark.txt", FileAccess.READ_WRITE if FileAccess.file_exists("user://benchmark.txt") else FileAccess.WRITE)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()
	get_tree().quit()


func _scene_stats(id: int) -> void:
	start_match(id)
	while match_node == null or not match_node.started:
		await get_tree().process_frame
	var sums := {}
	for n in match_node.find_children("*", "GeometryInstance3D", true, false):
		var mesh: Mesh = null
		var count := 1
		if n is MeshInstance3D:
			mesh = n.mesh
		elif n is MultiMeshInstance3D and n.multimesh:
			mesh = n.multimesh.mesh
			count = n.multimesh.instance_count
		if mesh == null:
			continue
		var tris := 0
		for s in mesh.get_surface_count():
			var a := mesh.surface_get_arrays(s)
			tris += (a[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if a[Mesh.ARRAY_INDEX] else (a[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		var key := "%s/%s" % [n.get_parent().name, n.name] if n is MeshInstance3D else "MMI:" + String(mesh.resource_name)
		var owner_scene := n.owner.scene_file_path.get_file() if n.owner else ""
		if owner_scene != "":
			key = owner_scene
		sums[key] = sums.get(key, 0) + tris * count
	var keys := sums.keys()
	keys.sort_custom(func(a, b): return sums[a] > sums[b])
	var total := 0
	for k in keys:
		total += sums[k]
	print("SCENE TOTAL tris=%dk" % (total / 1000))
	for k in keys.slice(0, 25):
		print("STAT %8dk  %s" % [sums[k] / 1000, k])
	get_tree().quit()


func _bench_off(root: Node, what: PackedStringArray, on := false) -> void:
	for n in [root] + root.find_children("*", "", true, false):
		if "decals" in what and n is Decal:
			n.visible = on
		if "mmi" in what and n is MultiMeshInstance3D:
			n.visible = on
		if "props" in what and n is MeshInstance3D and n.get_parent() is Node3D and not (n.get_parent() is StaticBody3D):
			n.visible = on
		if "taa" in what and n == root:
			get_viewport().use_taa = on
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED if on else Viewport.SCREEN_SPACE_AA_FXAA
		if "smaa" in what and n == root:
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_SMAA if on else Viewport.SCREEN_SPACE_AA_FXAA
		if "lights" in what and (n is OmniLight3D or n is SpotLight3D):
			n.visible = on
		if "shafts" in what and n is MeshInstance3D and n.mesh is QuadMesh:
			n.visible = on
		if "boxes" in what and n is MeshInstance3D and n.mesh is BoxMesh and not (n.get_parent() is StaticBody3D):
			n.visible = on
		if "gltf" in what and n is MeshInstance3D and n.owner and n.owner.scene_file_path != "" and not n.owner is CharacterBody3D:
			n.visible = on
		if "ssao_radius" in what and n is WorldEnvironment:
			n.environment.ssao_radius = 1.2 if on else 0.8
		if "ssao_detail" in what and n is WorldEnvironment:
			n.environment.ssao_detail = 0.5 if on else 0.0
		if "shadow" in what and n is DirectionalLight3D:
			n.shadow_enabled = on
		if n is WorldEnvironment:
			var e: Environment = n.environment
			if "ssao" in what or "env" in what:
				e.ssao_enabled = on
			if "glow" in what or "env" in what:
				e.glow_enabled = on
			if "fog" in what or "env" in what:
				e.fog_enabled = on


## A/B profiling inside one run (cancels laptop thermal drift): alternates each
## feature off/on in 2 s windows, three rounds, and reports the GPU-time saving.
func _bench_ab(features: PackedStringArray) -> void:
	var vp_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	for f in features:
		var on_ms := 0.0
		var off_ms := 0.0
		for r in 3:
			for state in [true, false]:
				_bench_off(match_node, PackedStringArray([f]), state)
				await get_tree().create_timer(0.5).timeout
				var sum := 0.0
				var n := 0
				var t0 := Time.get_ticks_msec()
				while Time.get_ticks_msec() - t0 < 2000:
					await get_tree().process_frame
					sum += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
					n += 1
				if state:
					on_ms += sum / n
				else:
					off_ms += sum / n
		_bench_off(match_node, PackedStringArray([f]), true)
		print("AB %s gpu_on=%.2f gpu_off=%.2f cost=%.2f ms" % [f, on_ms / 3.0, off_ms / 3.0, (on_ms - off_ms) / 3.0])


func _set_menu(m: Control) -> void:
	if current_menu:
		current_menu.queue_free()
	current_menu = m
	if m:
		ui_layer.add_child(m)


func _end_match() -> void:
	get_tree().paused = false
	if match_node:
		remove_child(match_node)
		match_node.queue_free()
		match_node = null


func show_main_menu() -> void:
	_end_match()
	_close_settings()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var m := MainMenu.new()
	m.start_pressed.connect(show_map_select)
	m.settings_pressed.connect(open_settings)
	m.exit_pressed.connect(func(): get_tree().quit())
	_set_menu(m)
	Sfx.ambient("")
	Sfx.music(true)


func show_map_select() -> void:
	var m := MapSelect.new()
	m.map_chosen.connect(start_match)
	m.back_pressed.connect(show_main_menu)
	_set_menu(m)


func open_settings() -> void:
	if settings_menu:
		return
	settings_menu = SettingsMenu.new()
	ui_layer.add_child(settings_menu)
	settings_menu.closed.connect(_close_settings)


func _close_settings() -> void:
	if settings_menu:
		settings_menu.queue_free()
		settings_menu = null
		if current_menu and current_menu.has_method("restore_focus"):
			current_menu.restore_focus()


func start_match(map_id: int) -> void:
	current_map = map_id
	_end_match()
	_set_menu(null)
	_show_loading(MapRegistry.MAPS[map_id].name)
	await get_tree().process_frame
	await get_tree().process_frame
	match_node = Match.new()
	match_node.name = "Match"
	match_node.map_id = map_id
	if test_match_duration > 0.0:   # automated tests only; normal matches use Match.MATCH_SECONDS
		match_node.match_duration = test_match_duration
	add_child(match_node)
	match_node.restart_requested.connect(func(): start_match(current_map), CONNECT_DEFERRED)
	match_node.main_menu_requested.connect(show_main_menu, CONNECT_DEFERRED)
	Sfx.music(false)
	await match_node.start()
	_hide_loading()


func _show_loading(map_name: String) -> void:
	_hide_loading()
	loading = Control.new()
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.theme = UiKit.get_theme()
	loading.add_child(UiKit.background())
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loading.add_child(c)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	var a := UiKit.label("DEPLOYING TO", 26, UiKit.MUTED)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(a)
	var b := UiKit.label(map_name, 64, UiKit.ACCENT)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(b)
	ui_layer.add_child(loading)


func _hide_loading() -> void:
	if loading:
		loading.queue_free()
		loading = null
