extends Control
## Title screen: START GAME / SETTINGS / EXIT GAME.

signal start_pressed
signal settings_pressed
signal exit_pressed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var start_btn: Button
var settings_btn: Button
var exit_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.get_theme()
	add_child(UiKit.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 140)
	margin.add_theme_constant_override("margin_top", 120)
	margin.add_theme_constant_override("margin_bottom", 70)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)
	col.add_child(UiKit.title(120))
	var bar := ColorRect.new()
	bar.color = UiKit.ACCENT
	bar.custom_minimum_size = Vector2(160, 6)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(bar)
	col.add_child(UiKit.label("OFFLINE TACTICAL ARENA SHOOTER", 26, UiKit.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	col.add_child(spacer)
	start_btn = UiKit.button("START GAME")
	settings_btn = UiKit.button("SETTINGS")
	exit_btn = UiKit.button("EXIT GAME")
	for b in [start_btn, settings_btn, exit_btn]:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		col.add_child(b)
	start_btn.pressed.connect(func(): start_pressed.emit())
	settings_btn.pressed.connect(func(): settings_pressed.emit())
	exit_btn.pressed.connect(func(): exit_pressed.emit())
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	col.add_child(UiKit.label("WASD MOVE   ·   SHIFT SPRINT   ·   Q SWITCH WEAPON   ·   C CROUCH   ·   Z PRONE   ·   RMB AIM", 18, UiKit.MUTED))
	col.add_child(UiKit.label("v1.0  ·  Single-player  ·  No internet required", 16, Color(0.45, 0.47, 0.45)))
	col.add_child(UiKit.label("Arms & AK-74M: \"FPS AK-74m animations\" by Cransh (CC-BY 4.0)  ·  M700: Stein Games (CC0)  ·  Props: Poly Haven (CC0)  ·  Textures: ambientCG (CC0)  ·  Soldiers & animations: Mixamo (Adobe)", 13, Color(0.45, 0.47, 0.45)))
	UiKit.fade_in(self)
	restore_focus.call_deferred()


func restore_focus() -> void:
	if is_instance_valid(start_btn) and start_btn.is_inside_tree():
		start_btn.grab_focus()
