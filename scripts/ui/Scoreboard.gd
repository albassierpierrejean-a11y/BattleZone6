extends Control

@onready var alpha_list: VBoxContainer = $Panel/AlphaTeam/PlayerList
@onready var bravo_list: VBoxContainer = $Panel/BravoTeam/PlayerList
@onready var alpha_score: Label        = $Panel/AlphaTeam/Score
@onready var bravo_score: Label        = $Panel/BravoTeam/Score
@onready var round_timer: Label        = $Panel/RoundTimer

const C_ALPHA := Color(0.35, 0.68, 1.0, 1.0)
const C_BRAVO := Color(1.0,  0.32, 0.32, 1.0)
const C_DIM   := Color(0.48, 0.58, 0.50, 0.75)
const C_TEXT  := Color(0.82, 0.92, 0.84, 1.0)

func _ready() -> void:
	_apply_panel_style()
	GameManager.scores_updated.connect(_refresh)
	GameManager.player_died_event.connect(func(_a, _b): _refresh_players())

func _apply_panel_style() -> void:
	var panel := get_node_or_null("Panel")
	if not panel:
		return
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = Color(0.18, 0.72, 0.38, 0.3)
	s.set_corner_radius_all(2)
	if panel is PanelContainer:
		panel.add_theme_stylebox_override("panel", s)

	if alpha_score:
		alpha_score.add_theme_color_override("font_color", C_ALPHA)
		alpha_score.add_theme_font_size_override("font_size", 28)
	if bravo_score:
		bravo_score.add_theme_color_override("font_color", C_BRAVO)
		bravo_score.add_theme_font_size_override("font_size", 28)
	if round_timer:
		round_timer.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85, 0.9))
		round_timer.add_theme_font_size_override("font_size", 18)

func _refresh(alpha: int, bravo: int) -> void:
	if alpha_score: alpha_score.text = str(alpha)
	if bravo_score: bravo_score.text = str(bravo)
	_refresh_players()

func _refresh_players() -> void:
	_clear_list(alpha_list)
	_clear_list(bravo_list)
	var sorted := GameManager.get_sorted_scoreboard()
	for data in sorted:
		var row := _make_row(data)
		if data.team == GameManager.Team.ALPHA:
			alpha_list.add_child(row)
		else:
			bravo_list.add_child(row)

func _make_row(data: GameManager.PlayerData) -> Control:
	var root := PanelContainer.new()

	var is_local := (data.id == multiplayer.get_unique_id())
	var is_alpha := (data.team == GameManager.Team.ALPHA)

	var row_style := StyleBoxFlat.new()
	if is_local:
		row_style.bg_color    = Color(0.1, 0.16, 0.08, 0.6)
		row_style.border_width_left = 2
		row_style.border_color = Color(0.18, 0.72, 0.38, 0.8)
	else:
		row_style.bg_color = Color(0.03, 0.05, 0.07, 0.4)
	row_style.set_corner_radius_all(1)
	root.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 0)
	root.add_child(hbox)

	var name_col := C_ALPHA if (is_local and is_alpha) else (C_BRAVO if (is_local and not is_alpha) else C_TEXT)
	var lbl_name  := _cell(data.name.to_upper(), 160, name_col)
	var lbl_kd    := _cell("%d / %d" % [data.kills, data.deaths], 90, C_DIM)
	var lbl_score := _cell(str(data.score), 60, Color(0.88, 0.96, 0.72, 0.95))

	if is_local:
		lbl_name.add_theme_color_override("font_color", Color(0.95, 1.0, 0.7, 1.0))

	hbox.add_child(lbl_name)
	hbox.add_child(lbl_kd)
	hbox.add_child(lbl_score)
	return root

func _cell(txt: String, min_w: float, col: Color) -> Label:
	var l := Label.new()
	l.text = txt
	l.custom_minimum_size.x = min_w
	l.add_theme_color_override("font_color", col)
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_constant_override("margin_left",  8)
	l.add_theme_constant_override("margin_right", 8)
	l.add_theme_constant_override("margin_top",   4)
	l.add_theme_constant_override("margin_bottom", 4)
	return l

func _clear_list(list: VBoxContainer) -> void:
	if not list:
		return
	for child in list.get_children():
		child.queue_free()
