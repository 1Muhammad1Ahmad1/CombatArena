extends Control
## Map selection: exactly three map cards and a BACK button.

signal map_chosen(map_id: int)
signal back_pressed

const UiKit = preload("res://scripts/ui/ui_kit.gd")
const MapRegistry = preload("res://scripts/maps/map_registry.gd")

var cards: Array = []
var back_btn: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.get_theme()
	add_child(UiKit.background())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 120)
	margin.add_theme_constant_override("margin_top", 100)
	margin.add_theme_constant_override("margin_bottom", 80)
	add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)
	col.add_child(UiKit.label("SELECT MAP", 64))
	col.add_child(UiKit.label("Five hostile bots per match. Bots respawn 3 seconds after elimination.", 22, UiKit.MUTED))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	col.add_child(spacer)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 34)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	for i in MapRegistry.MAPS.size():
		var card := _card(i, MapRegistry.MAPS[i])
		row.add_child(card)
		cards.append(card)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)
	back_btn = UiKit.button("BACK", 260)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back_btn.pressed.connect(func(): back_pressed.emit())
	col.add_child(back_btn)
	UiKit.fade_in(self)
	restore_focus.call_deferred()


func restore_focus() -> void:
	if not cards.is_empty() and cards[0].is_inside_tree():
		cards[0].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		back_pressed.emit()


func _card(idx: int, info: Dictionary) -> Button:
	var b := UiKit.button("", 470)
	b.custom_minimum_size = Vector2(470, 400)
	b.pressed.connect(func(): map_chosen.emit(idx))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 26
	v.offset_right = -26
	v.offset_top = 24
	v.offset_bottom = -20
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var preview := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, info.color_a)
	grad.set_color(1, info.color_b)
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 1)
	preview.texture = tex
	preview.custom_minimum_size = Vector2(0, 180)
	preview.stretch_mode = TextureRect.STRETCH_SCALE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(preview)
	var num := UiKit.label("0%d" % (idx + 1), 64, Color(1, 1, 1, 0.85))
	num.position = Vector2(16, 90)
	preview.add_child(num)
	v.add_child(UiKit.label(info.name, 30))
	v.add_child(UiKit.label(info.range, 18, UiKit.ACCENT))
	var d := UiKit.label(info.desc, 18, UiKit.MUTED)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(400, 0)
	v.add_child(d)
	return b
