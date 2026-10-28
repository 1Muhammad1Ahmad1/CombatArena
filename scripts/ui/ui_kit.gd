extends RefCounted
## Shared UI theme (dark military style) and widget helpers.

const ACCENT := Color(1.0, 0.62, 0.15)
const TEXT := Color(0.92, 0.93, 0.9)
const MUTED := Color(0.62, 0.65, 0.62)
const DANGER := Color(1.0, 0.3, 0.25)

static var _theme: Theme
static var _font: SystemFont

const BG_SHADER := """
shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	vec3 col = mix(vec3(0.075, 0.085, 0.09), vec3(0.02, 0.024, 0.028), uv.y);
	float stripe = step(0.5, fract((uv.x * 1.6 - uv.y) * 22.0 + TIME * 0.04)) * 0.016;
	col += stripe * smoothstep(0.35, 1.0, uv.x);
	col += vec3(1.0, 0.55, 0.1) * 0.11 * smoothstep(0.85, 0.0, distance(uv, vec2(0.0, 1.0)));
	float grid = step(0.985, fract(uv.x * 40.0)) + step(0.985, fract(uv.y * 22.5));
	col += grid * 0.012;
	col *= 1.0 - 0.45 * pow(distance(uv, vec2(0.5)), 1.6);
	COLOR = vec4(col, 1.0);
}
"""


static func font() -> SystemFont:
	if _font == null:
		_font = SystemFont.new()
		_font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
		_font.font_weight = 600
	return _font


static func _sb(bg: Color, border: Color, left := 4, others := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = left
	s.border_width_top = others
	s.border_width_right = others
	s.border_width_bottom = others
	s.content_margin_left = 22
	s.content_margin_right = 22
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.skew = Vector2(-0.12, 0.0)
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 22
	var normal := _sb(Color(0.11, 0.12, 0.13, 0.88), Color(1, 1, 1, 0.1))
	var hover := _sb(Color(0.2, 0.16, 0.09, 0.96), ACCENT, 8, 1)
	var pressed := _sb(Color(0.32, 0.22, 0.08, 1.0), ACCENT, 8, 2)
	var focus := _sb(Color(0, 0, 0, 0), ACCENT, 8, 2)
	focus.draw_center = false
	for cls in ["Button", "OptionButton", "CheckButton"]:
		t.set_stylebox("normal", cls, normal)
		t.set_stylebox("hover", cls, hover)
		t.set_stylebox("pressed", cls, pressed)
		t.set_stylebox("hover_pressed", cls, pressed)
		t.set_stylebox("focus", cls, focus)
		t.set_stylebox("disabled", cls, normal)
		t.set_color("font_color", cls, TEXT)
		t.set_color("font_hover_color", cls, ACCENT)
		t.set_color("font_focus_color", cls, ACCENT)
		t.set_color("font_pressed_color", cls, Color.WHITE)
		t.set_color("font_hover_pressed_color", cls, Color.WHITE)
	t.set_font_size("font_size", "Button", 28)
	t.set_font_size("font_size", "OptionButton", 20)
	t.set_font_size("font_size", "CheckButton", 20)
	t.set_color("font_color", "Label", TEXT)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.07, 0.08, 0.085, 0.97)
	panel.border_color = Color(1, 1, 1, 0.08)
	panel.set_border_width_all(1)
	panel.border_width_top = 4
	panel.border_color = ACCENT
	panel.set_content_margin_all(28)
	t.set_stylebox("panel", "PanelContainer", panel)
	var popup := StyleBoxFlat.new()
	popup.bg_color = Color(0.1, 0.11, 0.12)
	popup.set_border_width_all(1)
	popup.border_color = Color(1, 1, 1, 0.15)
	popup.set_content_margin_all(6)
	t.set_stylebox("panel", "PopupMenu", popup)
	var hl := StyleBoxFlat.new()
	hl.bg_color = Color(0.3, 0.2, 0.06)
	t.set_stylebox("hover", "PopupMenu", hl)
	t.set_color("font_hover_color", "PopupMenu", ACCENT)
	t.set_font_size("font_size", "PopupMenu", 20)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.2, 0.21, 0.22)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	_theme = t
	return t


static func background() -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BG_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return r


static func label(text: String, size := 22, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 6 if size >= 30 else 4)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.65))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String, min_w := 400.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 60)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_entered.connect(func(): _hover(b))
	b.focus_entered.connect(func(): _focused(b))
	b.focus_exited.connect(func(): _nudge(b, 1.0))
	b.pressed.connect(func(): Sfx.play("ui_click", -5.0))
	return b


static func _hover(c: Control) -> void:
	if c.is_inside_tree() and c.is_visible_in_tree():
		c.grab_focus()


static func _focused(c: Control) -> void:
	Sfx.play("ui_hover", -10.0)
	_nudge(c, 1.04)


static func _nudge(c: Control, s: float) -> void:
	if not c.is_inside_tree():
		return
	c.pivot_offset = Vector2(0, c.size.y * 0.5)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2(s, s), 0.08)


static func fade_in(c: Control) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.25)


static func title(size := 110) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 0)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := label("COMBAT", size, TEXT)
	var b := label("ARENA", size, ACCENT)
	for l in [a, b]:
		l.add_theme_constant_override("outline_size", 10)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	h.add_child(a)
	h.add_child(b)
	return h
