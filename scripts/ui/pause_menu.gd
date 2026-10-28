extends Control
## In-match pause menu: RESUME / RESTART MATCH / SETTINGS / MAIN MENU.

signal resume_pressed
signal restart_pressed
signal settings_pressed
signal main_menu_pressed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var resume_btn: Button
var restart_btn: Button
var settings_btn: Button
var menu_btn: Button
var blocked := false   # true while the settings overlay is open


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 140)
	margin.add_theme_constant_override("margin_top", 220)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.add_child(UiKit.label("PAUSED", 72))
	var bar := ColorRect.new()
	bar.color = UiKit.ACCENT
	bar.custom_minimum_size = Vector2(120, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(bar)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)
	resume_btn = UiKit.button("RESUME")
	restart_btn = UiKit.button("RESTART MATCH")
	settings_btn = UiKit.button("SETTINGS")
	menu_btn = UiKit.button("MAIN MENU")
	for b in [resume_btn, restart_btn, settings_btn, menu_btn]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(b)
	resume_btn.pressed.connect(func(): resume_pressed.emit())
	restart_btn.pressed.connect(func(): restart_pressed.emit())
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	menu_btn.pressed.connect(func(): main_menu_pressed.emit())
	visible = false


func focus_first() -> void:
	if resume_btn.is_inside_tree():
		resume_btn.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and not blocked and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()
