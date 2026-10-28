extends CanvasLayer
## In-game HUD. Every value is read from live gameplay state each frame.

const UiKit = preload("res://scripts/ui/ui_kit.gd")

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float strength = 0.0;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.6, 1.0);
	float a = smoothstep(0.35, 0.95, length(p)) * strength;
	COLOR = vec4(0.75, 0.0, 0.0, a);
}
"""

const SCOPE_SHADER := """
shader_type canvas_item;
uniform float aspect = 1.777;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p);
	float outside = smoothstep(0.425, 0.432, r);
	float edge = smoothstep(0.30, 0.43, r) * 0.55;
	float line = 0.0;
	if (abs(p.x) < 0.0012 || abs(p.y) < 0.0012) line = 1.0;
	if ((abs(p.x) < 0.005 && abs(p.y) > 0.11) || (abs(p.y) < 0.005 && abs(p.x) > 0.11)) line = 1.0;
	float mil = 0.0;
	for (int i = 1; i < 6; i++) {
		float m = float(i) * 0.02;
		if (abs(abs(p.y) - m) < 0.0012 && abs(p.x) < 0.008) mil = 1.0;
	}
	float a = max(outside, max(edge, max(line, mil)));
	COLOR = vec4(0.0, 0.0, 0.0, a);
}
"""


class Cross extends Control:
	var gap := 8.0
	var show_cross := true

	func _draw() -> void:
		if not show_cross:
			return
		var c := size * 0.5
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			var a: Vector2 = c + d * gap
			var b: Vector2 = c + d * (gap + 10.0)
			draw_line(a + Vector2(1, 1), b + Vector2(1, 1), Color(0, 0, 0, 0.55), 3.0)
			draw_line(a, b, Color(1, 1, 1, 0.95), 2.0)
		draw_rect(Rect2(c - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, 0.95))


class HitMarker extends Control:
	var t := 0.0
	var kill := false
	var head := false

	func _draw() -> void:
		if t <= 0.0:
			return
		var c := size * 0.5
		var col := UiKit.DANGER if kill else (UiKit.ACCENT if head else Color.WHITE)
		col.a = clampf(t / 0.2, 0.0, 1.0)
		var s := 1.0 + (0.4 if kill else 0.0)
		for d in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var dir: Vector2 = d.normalized()
			draw_line(c + dir * 9.0 * s, c + dir * 20.0 * s, col, 3.0 if kill else 2.0)


class DamageIndicator extends Control:
	var hud: Node
	var hits: Array = []   # [world_pos, time_left]

	func _draw() -> void:
		var p = hud.match_ref.player if hud and hud.match_ref else null
		if p == null:
			return
		var c := size * 0.5
		for h in hits:
			var local: Vector3 = p.global_transform.basis.inverse() * (h[0] - p.global_position)
			var ang := atan2(local.x, -local.z)
			var dir := Vector2(sin(ang), -cos(ang))
			var side := Vector2(-dir.y, dir.x)
			var r := 150.0
			var tip := c + dir * (r + 34.0)
			var a := clampf(float(h[1]), 0.0, 1.0)
			draw_colored_polygon(PackedVector2Array([c + dir * r + side * 30.0, tip, c + dir * r - side * 30.0]), Color(0.9, 0.1, 0.05, 0.75 * a))


var match_ref: Node
var root: Control
var cross: Cross
var hitmarker_ctl: HitMarker
var damage_ind: DamageIndicator
var vignette: ColorRect
var scope: ColorRect
var hp_label: Label
var hp_bar: ProgressBar
var hp_fill: StyleBoxFlat
var ammo_label: Label
var reserve_label: Label
var weapon_label: Label
var slot_labels: Array = []
var stance_label: Label
var hint_label: Label
var score_label: Label
var timer_label: Label
var enemies_label: Label
var feed: VBoxContainer
var center_msg: Label
var toast_label: Label
var fps_label: Label
var score_rows: Array = []
var board_t := 0.0
var death_t := 0.0
var toast_t := 0.0
var dmg_flash := 0.0


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiKit.get_theme()
	add_child(root)

	vignette = _shader_rect(VIGNETTE_SHADER)
	scope = _shader_rect(SCOPE_SHADER)
	scope.visible = false
	cross = Cross.new()
	hitmarker_ctl = HitMarker.new()
	damage_ind = DamageIndicator.new()
	damage_ind.hud = self
	for c in [cross, hitmarker_ctl, damage_ind]:
		c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(c)

	# bottom-left: health
	var hpbox := _corner(Control.PRESET_BOTTOM_LEFT, Vector2(36, -36), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN, true)
	hpbox.add_child(UiKit.label("HEALTH", 18, UiKit.MUTED))
	hp_label = UiKit.label("100", 64)
	hpbox.add_child(hp_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(320, 12)
	hp_bar.show_percentage = false
	hp_bar.max_value = 100
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.skew = Vector2(-0.3, 0)
	hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.4, 0.9, 0.45)
	hp_fill.skew = Vector2(-0.3, 0)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", hp_fill)
	hpbox.add_child(hp_bar)
	stance_label = UiKit.label("STANDING", 18, UiKit.MUTED)
	hpbox.add_child(stance_label)

	# bottom-right: weapon
	var wbox := _corner(Control.PRESET_BOTTOM_RIGHT, Vector2(-36, -36), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN, true)
	var slots := HBoxContainer.new()
	slots.alignment = BoxContainer.ALIGNMENT_END
	slots.add_theme_constant_override("separation", 10)
	wbox.add_child(slots)
	for i in 2:
		var s := UiKit.label("", 17)
		slots.add_child(s)
		slot_labels.append(s)
	weapon_label = UiKit.label("", 24)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wbox.add_child(weapon_label)
	var ammo_row := HBoxContainer.new()
	ammo_row.alignment = BoxContainer.ALIGNMENT_END
	wbox.add_child(ammo_row)
	ammo_label = UiKit.label("30", 72)
	reserve_label = UiKit.label("/ 180", 30, UiKit.MUTED)
	reserve_label.size_flags_vertical = Control.SIZE_SHRINK_END
	ammo_row.add_child(ammo_label)
	ammo_row.add_child(reserve_label)
	hint_label = UiKit.label("Q SWITCH   R RELOAD", 16, UiKit.MUTED)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wbox.add_child(hint_label)

	# top-centre: score
	var top := _corner(Control.PRESET_CENTER_TOP, Vector2(0, 18), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END, true)
	timer_label = UiKit.label("10:00", 40, UiKit.ACCENT)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(timer_label)
	score_label = UiKit.label("", 30)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(score_label)
	enemies_label = UiKit.label("", 18, UiKit.DANGER)
	enemies_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(enemies_label)

	# top-right: kill feed
	feed = _corner(Control.PRESET_TOP_RIGHT, Vector2(-40, 30), Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	feed.alignment = BoxContainer.ALIGNMENT_BEGIN

	# centre messages
	var mid := _corner(Control.PRESET_CENTER, Vector2(0, 90), Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	center_msg = UiKit.label("", 40, UiKit.DANGER)
	center_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(center_msg)
	toast_label = UiKit.label("", 22, UiKit.ACCENT)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(toast_label)

	# top-left: compact free-for-all scoreboard
	var tl := _corner(Control.PRESET_TOP_LEFT, Vector2(24, 20), Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END, true)
	var head := HBoxContainer.new()
	tl.add_child(head)
	head.add_child(_cell("FREE-FOR-ALL", 150, 15, UiKit.ACCENT))
	head.add_child(_cell("K", 36, 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	head.add_child(_cell("D", 36, 15, UiKit.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	for i in 4:
		var row := HBoxContainer.new()
		tl.add_child(row)
		var cells := [_cell("", 150, 19), _cell("", 36, 19, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT), _cell("", 36, 19, UiKit.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)]
		for c in cells:
			row.add_child(c)
		score_rows.append(cells)
	fps_label = UiKit.label("", 14, Color(1, 1, 1, 0.45))
	tl.add_child(fps_label)


func _cell(text: String, width: float, size: int, color := UiKit.TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := UiKit.label(text, size, color)
	l.custom_minimum_size = Vector2(width, 0)
	l.horizontal_alignment = align
	return l


func _shader_rect(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	root.add_child(r)
	return r


## Anchored container; with `plate` it sits on a dark translucent panel for readability.
func _corner(preset: int, offset: Vector2, grow_h: int, grow_v: int, plate := false) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	var holder: Control = v
	if plate:
		var p := PanelContainer.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.03, 0.035, 0.04, 0.55)
		sb.border_color = Color(1.0, 0.62, 0.15, 0.8)
		sb.border_width_left = 3
		sb.set_corner_radius_all(3)
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		p.add_theme_stylebox_override("panel", sb)
		p.add_child(v)
		holder = p
	root.add_child(holder)
	holder.set_anchors_preset(preset)
	holder.grow_horizontal = grow_h
	holder.grow_vertical = grow_v
	holder.offset_left = offset.x
	holder.offset_right = offset.x
	holder.offset_top = offset.y
	holder.offset_bottom = offset.y
	return v


# ------------------------------------------------------------------ events

func hitmarker(head: bool, kill: bool) -> void:
	hitmarker_ctl.t = 0.3 if kill else 0.18
	hitmarker_ctl.kill = kill
	hitmarker_ctl.head = head


func damage_from(pos: Vector3) -> void:
	damage_ind.hits.append([pos, 1.4])
	dmg_flash = 0.6


func feed_add(text: String, good: bool) -> void:
	var l := UiKit.label(text, 20, UiKit.ACCENT if good else UiKit.DANGER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	feed.add_child(l)
	while feed.get_child_count() > 5:
		feed.get_child(0).free()
	var tw := l.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)


func toast(text: String) -> void:
	toast_label.text = text
	toast_t = 1.5


func show_death(seconds: float) -> void:
	death_t = seconds


func hide_death() -> void:
	death_t = 0.0
	center_msg.text = ""


# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	if match_ref == null or match_ref.player == null:
		return
	var p = match_ref.player
	var w: Dictionary = p.weapons[p.cur]
	var def: Dictionary = w.def
	var hp := ceili(float(p.health.hp))
	hp_label.text = str(hp)
	hp_bar.value = hp
	hp_fill.bg_color = Color(0.4, 0.9, 0.45) if hp > 35 else UiKit.DANGER
	ammo_label.text = str(w.ammo)
	ammo_label.add_theme_color_override("font_color", UiKit.DANGER if int(w.ammo) == 0 else UiKit.TEXT)
	reserve_label.text = "/ %d" % int(w.reserve)
	weapon_label.text = def.name
	for i in 2:
		var d: Dictionary = p.weapons[i].def
		slot_labels[i].text = "[%d] %s" % [i + 1, d.short]
		slot_labels[i].add_theme_color_override("font_color", UiKit.ACCENT if i == p.cur else UiKit.MUTED)
	stance_label.text = ["STANDING", "CROUCHED", "PRONE"][p.stance] + ("  ·  SPRINT" if p.sprinting else "")
	if p.reloading:
		hint_label.text = "RELOADING..."
	elif int(w.ammo) == 0:
		hint_label.text = "PRESS R TO RELOAD" if int(w.reserve) > 0 else "NO AMMO - PRESS Q"
	else:
		hint_label.text = "Q SWITCH   R RELOAD   C CROUCH   Z PRONE"
	var clock: String = match_ref.format_time(match_ref.time_left)
	if clock != timer_label.text:   # only touches the label once a second
		timer_label.text = clock
		timer_label.add_theme_color_override("font_color", UiKit.DANGER if match_ref.time_left <= 30.0 else UiKit.ACCENT)
	score_label.text = "KILLS  %d      DEATHS  %d" % [match_ref.kills, match_ref.deaths]
	enemies_label.text = "BOTS ALIVE  %d / %d" % [match_ref.active_bot_count(), match_ref.bot_count]
	fps_label.text = "%d FPS" % Engine.get_frames_per_second()
	board_t -= delta
	if board_t <= 0.0:
		board_t = 0.2
		var rows: Array = match_ref.scoreboard()
		for i in score_rows.size():
			var cells: Array = score_rows[i]
			if i >= rows.size():
				for c in cells:
					c.text = ""
				continue
			var r: Dictionary = rows[i]
			var col: Color = UiKit.ACCENT if r.player else UiKit.TEXT
			if not r.alive:
				col = col.darkened(0.45)
			cells[0].text = ("%d  %s" % [i + 1, r.name]) + ("" if r.alive else "  †")
			cells[1].text = str(r.kills)
			cells[2].text = str(r.deaths)
			for c in cells:
				c.add_theme_color_override("font_color", col)

	# crosshair gap follows real weapon spread
	var spread_px := tan(deg_to_rad(p.current_spread_deg())) / tan(deg_to_rad(p.camera.fov * 0.5)) * root.size.y * 0.5
	cross.gap = clampf(spread_px, 4.0, 120.0)
	cross.show_cross = p.alive and p.ads < 0.5
	cross.queue_redraw()
	scope.visible = p.is_scoped()
	(scope.material as ShaderMaterial).set_shader_parameter("aspect", root.size.x / maxf(root.size.y, 1.0))

	hitmarker_ctl.t = maxf(0.0, hitmarker_ctl.t - delta)
	hitmarker_ctl.queue_redraw()
	for h in damage_ind.hits:
		h[1] = float(h[1]) - delta
	damage_ind.hits = damage_ind.hits.filter(func(h): return float(h[1]) > 0.0)
	damage_ind.queue_redraw()
	dmg_flash = maxf(0.0, dmg_flash - delta)
	var low := clampf((40.0 - float(p.health.hp)) / 40.0, 0.0, 1.0) * 0.7
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", maxf(low, dmg_flash))

	if death_t > 0.0:
		death_t = maxf(0.0, death_t - delta)
		center_msg.text = "ELIMINATED\nRESPAWNING IN %d" % ceili(death_t)
	toast_t -= delta
	if toast_t <= 0.0:
		toast_label.text = ""
