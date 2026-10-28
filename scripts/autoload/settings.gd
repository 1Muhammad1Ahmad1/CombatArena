extends Node
## Persistent player settings (user://settings.cfg), input map and audio buses.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440)]
const QUALITY_NAMES := ["Low", "Medium", "High", "Epic"]
const DIFFICULTY_NAMES := ["Recruit", "Regular", "Veteran"]
const DISPLAY_KEYS := ["resolution", "fullscreen", "vsync", "quality", "taa"]

var data := {
	"quality": 1,
	"resolution": 0,
	"fullscreen": false,
	"vsync": true,
	"taa": true,   # temporal AA on Medium/Epic (stable thin geometry); off = FXAA, ~2 ms cheaper on a P2000
	"sensitivity": 1.0,
	"master": 0.8,
	"music": 0.5,
	"sfx": 0.85,
	"difficulty": 1,
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_buses()
	load_settings()
	apply()


func _setup_input() -> void:
	var keys := {
		"move_forward": KEY_W, "move_back": KEY_S, "move_left": KEY_A, "move_right": KEY_D,
		"sprint": KEY_SHIFT, "jump": KEY_SPACE, "crouch": KEY_C, "prone": KEY_Z,
		"switch_weapon": KEY_Q, "reload": KEY_R, "pause": KEY_ESCAPE,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var ev := InputEventKey.new()
		ev.physical_keycode = keys[action]
		InputMap.action_add_event(action, ev)
	for pair in [["fire", MOUSE_BUTTON_LEFT], ["aim", MOUSE_BUTTON_RIGHT]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
		var mb := InputEventMouseButton.new()
		mb.button_index = pair[1]
		InputMap.action_add_event(pair[0], mb)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		data.resolution = _default_resolution()
		return
	for key in data.keys():
		data[key] = cfg.get_value("settings", key, data[key])


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in data.keys():
		cfg.set_value("settings", key, data[key])
	cfg.save(PATH)


func set_value(key: String, value) -> void:
	data[key] = value
	if key in DISPLAY_KEYS:
		apply()
	else:
		_apply_audio()
		changed.emit()
	save_settings()


func apply() -> void:
	_apply_audio()
	if DisplayServer.get_name() != "headless":
		_apply_display()
	_apply_quality()
	changed.emit()


func sensitivity() -> float:
	return float(data.sensitivity)


func difficulty() -> int:
	return clampi(int(data.difficulty), 0, 2)


func quality_params() -> Dictionary:
	match clampi(int(data.quality), 0, 3):
		0:
			return {"msaa": Viewport.MSAA_DISABLED, "fxaa": true, "scale": 0.75, "shadow": 1024,
				"soft": RenderingServer.SHADOW_QUALITY_HARD, "ssao": false, "glow": false, "shadow_dist": 45.0, "ssr": false, "ssil": false, "vol_fog": false}
		1:
			# Medium keeps half-resolution SSAO for contact shadows (grounding); no glow, no shadowed spot lamps.
			return {"msaa": Viewport.MSAA_DISABLED, "fxaa": true, "taa": true, "scale": 1.0, "shadow": 2048,
				"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "ssao": true, "hq_shadows": false, "glow": false, "shadow_dist": 80.0, "ssr": false, "ssil": false, "vol_fog": false}
		2:
			# High: FSR 2 "Quality" upscaling from 67 % (also anti-aliases thin wires/railings), no MSAA.
			return {"msaa": Viewport.MSAA_DISABLED, "fxaa": false, "scale": 0.67, "fsr2": true, "shadow": 4096,
				"soft": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "ssao": true, "hq_shadows": true, "sun_splits": 2, "glow": true, "shadow_dist": 100.0, "ssr": false, "ssil": false, "vol_fog": false}
	return {"msaa": Viewport.MSAA_4X, "fxaa": false, "taa": true, "scale": 1.0, "shadow": 4096,
		"soft": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "ssao": true, "hq_shadows": true, "facade_shadows": true, "glow": true, "shadow_dist": 150.0, "ssr": true, "ssil": true, "vol_fog": true}


func _default_resolution() -> int:
	if DisplayServer.get_name() == "headless":
		return 0
	var usable := DisplayServer.screen_get_usable_rect().size
	var best := 0
	for i in RESOLUTIONS.size():
		var r: Vector2i = RESOLUTIONS[i]
		if r.x < usable.x and r.y < usable.y:
			best = i
	return best


func _apply_audio() -> void:
	_set_bus("Master", float(data.master))
	_set_bus("Music", float(data.music))
	_set_bus("SFX", float(data.sfx))


func _set_bus(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)


func _apply_display() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if data.vsync else DisplayServer.VSYNC_DISABLED)
	if data.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var res: Vector2i = RESOLUTIONS[clampi(int(data.resolution), 0, RESOLUTIONS.size() - 1)]
	DisplayServer.window_set_size(res)
	var usable := DisplayServer.screen_get_usable_rect()
	DisplayServer.window_set_position(usable.position + (usable.size - res) / 2)


func _apply_quality() -> void:
	var q := quality_params()
	var vp := get_tree().root
	vp.msaa_3d = q.msaa
	# TAA (when the preset allows it and the player has not switched it off) replaces FXAA:
	# measured 58-70 % less shimmer on thin roof/railing geometry in motion, 32 % less grain.
	var taa: bool = q.get("taa", false) and bool(data.get("taa", true))
	vp.use_taa = taa
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q.fxaa and not taa else Viewport.SCREEN_SPACE_AA_DISABLED
	var scale: float = q.scale
	if data.fullscreen and DisplayServer.get_name() != "headless":
		var screen := DisplayServer.screen_get_size()
		var res: Vector2i = RESOLUTIONS[clampi(int(data.resolution), 0, RESOLUTIONS.size() - 1)]
		if screen.y > 0:
			scale *= minf(1.0, float(res.y) / float(screen.y))
	if q.get("fsr2", false):
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = scale
	RenderingServer.directional_shadow_atlas_set_size(q.shadow, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(q.soft)
	RenderingServer.positional_soft_shadow_filter_set_quality(q.soft)
	get_tree().call_group("quality_env", "apply_quality", q)
