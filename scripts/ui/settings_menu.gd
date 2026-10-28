extends Control
## Settings overlay. Every change is applied immediately and saved to user://settings.cfg.

signal closed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var quality_opt: OptionButton
var res_opt: OptionButton
var fullscreen_chk: CheckButton
var vsync_chk: CheckButton
var taa_chk: CheckButton
var sens_slider: HSlider
var master_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var diff_opt: OptionButton
var back_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.75)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 0)
	center.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)
	col.add_child(UiKit.label("SETTINGS", 48))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	col.add_child(grid)
	var d: Dictionary = Settings.data

	quality_opt = _option(grid, "GRAPHICS QUALITY", Settings.QUALITY_NAMES, int(d.quality))
	quality_opt.item_selected.connect(func(i): Settings.set_value("quality", i))
	var res_names: Array = []
	for r in Settings.RESOLUTIONS:
		res_names.append("%d x %d" % [r.x, r.y])
	res_opt = _option(grid, "RESOLUTION", res_names, int(d.resolution))
	res_opt.item_selected.connect(func(i): Settings.set_value("resolution", i))
	fullscreen_chk = _check(grid, "FULLSCREEN", bool(d.fullscreen))
	fullscreen_chk.toggled.connect(func(on): Settings.set_value("fullscreen", on))
	vsync_chk = _check(grid, "VSYNC", bool(d.vsync))
	vsync_chk.toggled.connect(func(on): Settings.set_value("vsync", on))
	taa_chk = _check(grid, "TEMPORAL AA (MEDIUM/EPIC)", bool(d.get("taa", true)))
	taa_chk.toggled.connect(func(on): Settings.set_value("taa", on))
	sens_slider = _slider(grid, "MOUSE SENSITIVITY", 0.2, 3.0, float(d.sensitivity))
	sens_slider.value_changed.connect(func(v): Settings.set_value("sensitivity", v))
	master_slider = _slider(grid, "MASTER VOLUME", 0.0, 1.0, float(d.master))
	master_slider.value_changed.connect(func(v): Settings.set_value("master", v))
	music_slider = _slider(grid, "MUSIC VOLUME", 0.0, 1.0, float(d.music))
	music_slider.value_changed.connect(func(v): Settings.set_value("music", v))
	sfx_slider = _slider(grid, "SOUND EFFECTS VOLUME", 0.0, 1.0, float(d.sfx))
	sfx_slider.value_changed.connect(func(v): Settings.set_value("sfx", v))
	diff_opt = _option(grid, "BOT DIFFICULTY", Settings.DIFFICULTY_NAMES, int(d.difficulty))
	diff_opt.item_selected.connect(func(i): Settings.set_value("difficulty", i))

	col.add_child(UiKit.label("Resolution applies in windowed mode; in fullscreen it sets the 3D render resolution.", 16, UiKit.MUTED))
	back_btn = UiKit.button("BACK", 260)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_btn.pressed.connect(close)
	col.add_child(back_btn)
	UiKit.fade_in(self)
	quality_opt.grab_focus.call_deferred()


func close() -> void:
	Settings.save_settings()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func _row_label(grid: GridContainer, text: String) -> void:
	var l := UiKit.label(text, 20, UiKit.MUTED)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(l)


func _option(grid: GridContainer, text: String, items: Array, selected: int) -> OptionButton:
	_row_label(grid, text)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(clampi(selected, 0, items.size() - 1))
	o.custom_minimum_size = Vector2(320, 46)
	grid.add_child(o)
	return o


func _check(grid: GridContainer, text: String, on: bool) -> CheckButton:
	_row_label(grid, text)
	var c := CheckButton.new()
	c.button_pressed = on
	c.text = "ON" if on else "OFF"
	c.toggled.connect(func(v): c.text = "ON" if v else "OFF")
	grid.add_child(c)
	return c


func _slider(grid: GridContainer, text: String, lo: float, hi: float, value: float) -> HSlider:
	_row_label(grid, text)
	var h := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(260, 30)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := UiKit.label("%.2f" % value, 18)
	v.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(x): v.text = "%.2f" % x)
	h.add_child(s)
	h.add_child(v)
	grid.add_child(h)
	return s
