extends Control
## End-of-match results: winner / joint-winner banner, ranked table of all four
## participants (rank, name, kills, deaths) with the human player highlighted,
## and PLAY AGAIN / MAIN MENU / QUIT. Built once from a frozen snapshot.

signal play_again_pressed
signal main_menu_pressed
signal quit_pressed

const UiKit = preload("res://scripts/ui/ui_kit.gd")

var standings: Array = []    # rows from Match.rank_rows(): {rank, name, kills, deaths, player}
var winner_text := ""
var row_labels: Array = []   # [rank, name, kills, deaths] Label per row (read by tests)
var play_btn: Button
var menu_btn: Button
var quit_btn: Button


func setup(rows: Array) -> void:
	standings = rows


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.03, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := UiKit.label("MATCH OVER", 64)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var bar := ColorRect.new()
	bar.color = UiKit.ACCENT
	bar.custom_minimum_size = Vector2(160, 5)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(bar)
	var winners: Array = standings.filter(func(r): return int(r.rank) == 1)
	var names: Array = winners.map(func(r): return String(r.name))
	if names.size() == 1:
		winner_text = "WINNER:  %s" % names[0]
	else:
		winner_text = "JOINT WINNERS:  %s" % " & ".join(PackedStringArray(names))
	var banner := UiKit.label(winner_text, 34, UiKit.ACCENT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(banner)

	var table := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.055, 0.06, 0.9)
	sb.border_color = Color(1.0, 0.62, 0.15, 0.8)
	sb.border_width_left = 4
	sb.set_corner_radius_all(3)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	table.add_theme_stylebox_override("panel", sb)
	col.add_child(table)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 8)
	table.add_child(grid)
	for h in ["RANK", "NAME", "KILLS", "DEATHS"]:
		grid.add_child(_cell(h, 18, UiKit.MUTED, h != "NAME"))
	for r in standings:
		var color: Color = UiKit.ACCENT if r.player else UiKit.TEXT
		var name_text: String = String(r.name) + ("   (YOU)" if r.player else "")
		var cells := [_cell("#%d" % int(r.rank), 28, color, true), _cell(name_text, 28, color, false),
			_cell(str(r.kills), 28, color, true), _cell(str(r.deaths), 28, color, true)]
		cells[1].custom_minimum_size = Vector2(320, 0)
		for c in cells:
			grid.add_child(c)
		row_labels.append(cells)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 18)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)
	play_btn = UiKit.button("PLAY AGAIN", 240.0)
	menu_btn = UiKit.button("MAIN MENU", 240.0)
	quit_btn = UiKit.button("QUIT", 240.0)
	for b in [play_btn, menu_btn, quit_btn]:
		buttons.add_child(b)
	play_btn.pressed.connect(func(): play_again_pressed.emit())
	menu_btn.pressed.connect(func(): main_menu_pressed.emit())
	quit_btn.pressed.connect(func(): quit_pressed.emit())
	UiKit.fade_in(self)
	play_btn.grab_focus.call_deferred()


func _cell(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := UiKit.label(text, size, color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l
