extends CanvasLayer

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var nav_panel:      VBoxContainer = $NavPanel
@onready var player_name_lbl:Label         = $NavPanel/PlayerCard/PlayerRow/PlayerInfo/PlayerName
@onready var xp_fill:        ColorRect     = $NavPanel/PlayerCard/XPFill
@onready var xp_current_lbl: Label         = $NavPanel/PlayerCard/XPLabels/XPCurrent
@onready var server_status:  Label         = $NavPanel/FooterRow/ServerStatus

@onready var nav_play:       Button        = $NavPanel/NavItems/NavPlay
@onready var nav_operator:   Button        = $NavPanel/NavItems/NavOperator
@onready var nav_progression:Button        = $NavPanel/NavItems/NavProgression
@onready var nav_settings:   Button        = $NavPanel/NavItems/NavSettings
@onready var nav_quit:       Button        = $NavPanel/NavItems/NavQuit

@onready var play_panel:     VBoxContainer = $PlayPanel
@onready var host_panel:     VBoxContainer = $HostPanel
@onready var join_panel:     VBoxContainer = $JoinPanel
@onready var settings_panel: VBoxContainer = $SettingsPanel

@onready var name_input:     LineEdit      = $PlayPanel/NameInput
@onready var team_alpha:     Button        = $PlayPanel/TeamRow/TeamAlpha
@onready var team_bravo:     Button        = $PlayPanel/TeamRow/TeamBravo
@onready var host_btn:       Button        = $PlayPanel/ModeRow/HostBtn
@onready var join_btn:       Button        = $PlayPanel/ModeRow/JoinBtn
@onready var play_back:      Button        = $PlayPanel/PlayBack

@onready var host_port:      SpinBox       = $HostPanel/PortSpin
@onready var host_confirm:   Button        = $HostPanel/ConfirmBtn
@onready var host_back:      Button        = $HostPanel/BackBtn

@onready var join_address:   LineEdit      = $JoinPanel/AddressInput
@onready var join_port:      SpinBox       = $JoinPanel/JoinPortSpin
@onready var join_confirm:   Button        = $JoinPanel/ConnectBtn
@onready var join_back:      Button        = $JoinPanel/JoinBackBtn

@onready var status_label:   Label         = $StatusLabel
@onready var map_info_panel: VBoxContainer = $MapInfoPanel

# ─── Palette ─────────────────────────────────────────────────────────────────
const C_ACCENT  := Color(0.831, 0.525, 0.102, 1.0)  # orange
const C_ACCENT_H:= Color(0.960, 0.655, 0.200, 1.0)
const C_WHITE   := Color(0.941, 0.925, 0.894, 1.0)
const C_GREEN   := Color(0.561, 0.659, 0.541, 1.0)
const C_DIM     := Color(0.290, 0.322, 0.282, 1.0)
const C_INK     := Color(0.039, 0.047, 0.035, 1.0)
const C_SURFACE := Color(0.055, 0.065, 0.048, 0.96)
const C_SURFACE_H := Color(0.075, 0.090, 0.065, 0.98)
const C_BLUE    := Color(0.290, 0.561, 0.753, 1.0)
const C_RED     := Color(0.753, 0.220, 0.169, 1.0)
const C_BORDER  := Color(0.561, 0.659, 0.541, 0.09)

const MAPS := {
	"TEST MAP" : "res://scenes/maps/TestMap.tscn",
	"OASIS"    : "res://scenes/maps/Oasis.tscn",
}
var _selected_map: String = "res://scenes/maps/TestMap.tscn"
var _all_panels: Array

func _ready() -> void:
	_all_panels = [play_panel, host_panel, join_panel, settings_panel]
	_hide_all_panels()
	_apply_styles()
	_connect_signals()
	name_input.text = "SOLDAAT_%d" % randi_range(100, 999)
	player_name_lbl.text = name_input.text
	_animate_intro()
	_build_map_selector()

# ─── Intro animation ─────────────────────────────────────────────────────────
func _animate_intro() -> void:
	nav_panel.modulate.a    = 0.0
	map_info_panel.modulate.a = 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nav_panel, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(nav_panel, "position:y", 0.0, 0.55).set_ease(Tween.EASE_OUT).from(22.0)
	tw.tween_property(map_info_panel, "modulate:a", 1.0, 0.9).set_delay(0.3)

# ─── Styles ──────────────────────────────────────────────────────────────────
func _apply_styles() -> void:
	var no_focus := StyleBoxEmpty.new()

	# Nav items
	for btn: Button in [nav_play, nav_operator, nav_progression, nav_settings, nav_quit]:
		var s_n := _nav_sbox(false)
		var s_h := _nav_sbox(true)
		btn.add_theme_stylebox_override("normal",  s_n)
		btn.add_theme_stylebox_override("hover",   s_h)
		btn.add_theme_stylebox_override("pressed", s_h)
		btn.add_theme_stylebox_override("focus",   no_focus)
		btn.add_theme_color_override("font_color",         Color(C_WHITE, 0.55))
		btn.add_theme_color_override("font_hover_color",   C_WHITE)
		btn.add_theme_color_override("font_pressed_color", C_WHITE)
		btn.add_theme_font_size_override("font_size", 22)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	nav_quit.add_theme_color_override("font_color",       Color(C_DIM, 0.7))
	nav_quit.add_theme_color_override("font_hover_color", Color(0.9, 0.28, 0.28))

	# Player avatar
	var av_sbox := StyleBoxFlat.new()
	av_sbox.bg_color = Color(C_ACCENT, 0.08)
	av_sbox.border_width_left   = 1
	av_sbox.border_width_right  = 1
	av_sbox.border_width_top    = 1
	av_sbox.border_width_bottom = 1
	av_sbox.border_color = Color(C_ACCENT, 0.4)
	$NavPanel/PlayerCard/PlayerRow/PlayerAvatar.add_theme_stylebox_override("panel", av_sbox)

	# Map info panel styling
	var map_sbox := StyleBoxFlat.new()
	map_sbox.bg_color = Color(0.02, 0.025, 0.018, 0.0)
	$MapInfoPanel/MapPreview.add_theme_stylebox_override("panel", _map_preview_sbox())

	# Map stats cells
	for child in $MapInfoPanel/MapStatsRow.get_children():
		var cell_sbox := StyleBoxFlat.new()
		cell_sbox.bg_color    = Color(0.036, 0.042, 0.032, 0.92)
		cell_sbox.border_width_left   = 1
		cell_sbox.border_width_right  = 1
		cell_sbox.border_width_top    = 1
		cell_sbox.border_width_bottom = 1
		cell_sbox.border_color = C_BORDER

	# Action panels
	_style_action_panels()

func _nav_sbox(hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color           = C_ACCENT * Color(1,1,1, 0.04) if hover else Color(0,0,0,0)
	s.border_width_left  = 3
	s.border_color       = C_ACCENT if hover else Color(0,0,0,0)
	s.content_margin_left   = 42.0
	s.content_margin_right  = 16.0
	s.content_margin_top    = 0.0
	s.content_margin_bottom = 0.0
	return s

func _map_preview_sbox() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.028, 0.034, 0.022, 0.88)
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color = C_BORDER
	return s

func _style_action_panels() -> void:
	var no_focus := StyleBoxEmpty.new()
	# Primary action buttons (HOST / JOIN / CONNECT)
	for btn: Button in [host_btn, join_btn, host_confirm, join_confirm]:
		_style_btn(btn, _action_sbox(C_ACCENT, false), _action_sbox(C_ACCENT, true),
			no_focus, C_INK, C_WHITE, 14)
	# Secondary
	for btn: Button in [play_back, host_back, join_back]:
		_style_btn(btn, _dim_sbox(), _dim_sbox_h(), no_focus, C_DIM, C_WHITE, 11)
	# Play panel host/join selector
	for btn: Button in [host_btn, join_btn]:
		_style_btn(btn, _outline_sbox(C_BORDER, Color(C_ACCENT, 0.0)),
			_outline_sbox(Color(C_ACCENT, 0.3), Color(C_ACCENT, 0.06)),
			no_focus, Color(C_WHITE, 0.6), C_WHITE, 14)
	# Team buttons
	var s_alpha_n := _outline_sbox(Color(C_BLUE, 0.35), Color(C_BLUE, 0.05))
	var s_alpha_p := _outline_sbox(Color(C_BLUE, 0.8),  Color(C_BLUE, 0.18))
	_style_btn(team_alpha, s_alpha_n, s_alpha_p, no_focus, Color(C_BLUE, 0.7), C_WHITE, 13)
	team_alpha.add_theme_stylebox_override("pressed", s_alpha_p)
	var s_bravo_n := _outline_sbox(Color(C_RED, 0.35), Color(C_RED, 0.05))
	var s_bravo_p := _outline_sbox(Color(C_RED, 0.8),  Color(C_RED, 0.18))
	_style_btn(team_bravo, s_bravo_n, s_bravo_p, no_focus, Color(C_RED, 0.7), C_WHITE, 13)
	team_bravo.add_theme_stylebox_override("pressed", s_bravo_p)
	# Inputs
	for le: LineEdit in [name_input, join_address]:
		le.add_theme_stylebox_override("normal", _input_sbox(Color(C_ACCENT, 0.35)))
		le.add_theme_stylebox_override("focus",  _input_sbox(C_ACCENT))
		le.add_theme_color_override("font_color",             C_WHITE)
		le.add_theme_color_override("font_placeholder_color", Color(C_DIM, 0.6))
		le.add_theme_color_override("caret_color",            C_ACCENT)
		le.add_theme_font_size_override("font_size", 14)

func _action_sbox(col: Color, hover: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col if hover else Color(col, 0.15)
	s.content_margin_left   = 16.0
	s.content_margin_right  = 16.0
	s.content_margin_top    = 6.0
	s.content_margin_bottom = 6.0
	return s

func _outline_sbox(border: Color, bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.border_color        = border
	s.content_margin_left   = 16.0
	s.content_margin_right  = 16.0
	s.content_margin_top    = 6.0
	s.content_margin_bottom = 6.0
	return s

func _dim_sbox() -> StyleBoxFlat:
	return _outline_sbox(Color(C_GREEN, 0.12), Color(C_INK, 0.4))

func _dim_sbox_h() -> StyleBoxFlat:
	return _outline_sbox(Color(C_GREEN, 0.25), Color(C_INK, 0.6))

func _input_sbox(border: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = Color(0.028, 0.034, 0.022, 0.95)
	s.border_width_bottom = 2
	s.border_color        = border
	s.content_margin_left   = 12.0
	s.content_margin_right  = 12.0
	s.content_margin_top    = 8.0
	s.content_margin_bottom = 8.0
	return s

func _style_btn(btn: Button, n: StyleBox, h: StyleBox, f: StyleBox,
		col: Color, col_h: Color, sz: int) -> void:
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   f)
	btn.add_theme_color_override("font_color",         col)
	btn.add_theme_color_override("font_hover_color",   col_h)
	btn.add_theme_color_override("font_pressed_color", col_h)
	btn.add_theme_font_size_override("font_size", sz)

# ─── Signals ─────────────────────────────────────────────────────────────────
func _connect_signals() -> void:
	nav_play.pressed.connect(func(): _open_panel(play_panel))
	nav_operator.pressed.connect(_on_operator_pressed)
	nav_progression.pressed.connect(_on_progression_pressed)
	nav_settings.pressed.connect(func(): _open_panel(settings_panel))
	nav_quit.pressed.connect(get_tree().quit)
	play_back.pressed.connect(_hide_all_panels)
	host_btn.pressed.connect(func(): _open_panel(host_panel))
	join_btn.pressed.connect(func(): _open_panel(join_panel))
	host_back.pressed.connect(func(): _open_panel(play_panel))
	join_back.pressed.connect(func(): _open_panel(play_panel))
	host_confirm.pressed.connect(_on_host_pressed)
	join_confirm.pressed.connect(_on_join_pressed)
	team_alpha.pressed.connect(func(): _select_team(GameManager.Team.ALPHA))
	team_bravo.pressed.connect(func(): _select_team(GameManager.Team.BRAVO))
	name_input.text_changed.connect(func(t): player_name_lbl.text = t if not t.is_empty() else "SOLDAAT")
	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)

# ─── Panel transitions ────────────────────────────────────────────────────────
func _hide_all_panels() -> void:
	for p in _all_panels:
		p.visible = false

func _open_panel(panel: VBoxContainer) -> void:
	var prev: VBoxContainer = null
	for p: VBoxContainer in _all_panels:
		if p.visible:
			prev = p
			break
	_hide_all_panels()
	panel.visible    = true
	panel.modulate.a = 0.0
	var tw := create_tween()
	if prev:
		tw.tween_property(panel, "modulate:a", 1.0, 0.18).set_ease(Tween.EASE_OUT)
	else:
		tw.tween_property(panel, "modulate:a", 1.0, 0.28).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(panel, "position:y", panel.position.y, 0.22).set_ease(Tween.EASE_OUT).from(panel.position.y + 14.0)

# ─── Nav callbacks ────────────────────────────────────────────────────────────
func _on_operator_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/LoadoutScreen.tscn")

func _on_progression_pressed() -> void:
	_set_status("Progression — bientôt disponible")

# ─── Network ─────────────────────────────────────────────────────────────────
func _on_host_pressed() -> void:
	NetworkManager.local_player_name = name_input.text
	NetworkManager.current_map_scene = _selected_map
	var err := NetworkManager.create_server(int(host_port.value))
	_set_status("Démarrage serveur…" if err == OK else "Erreur : " + str(err))

func _on_join_pressed() -> void:
	NetworkManager.local_player_name = name_input.text
	var addr := join_address.text.strip_edges()
	if addr.is_empty(): addr = "127.0.0.1"
	var err := NetworkManager.join_server(addr, int(join_port.value))
	_set_status(("Connexion à %s…" % addr) if err == OK else "Erreur : " + str(err))

func _on_server_created() -> void:
	_set_status("Serveur actif — chargement de la carte…")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(_selected_map)

func _on_joined_server() -> void:
	_set_status("Connecté — chargement…")
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file(NetworkManager.current_map_scene)

func _on_connection_failed() -> void:
	_set_status("Connexion échouée. Vérifiez l'adresse.")

func _select_team(team: int) -> void:
	NetworkManager.local_player_team = team
	team_alpha.button_pressed = (team == GameManager.Team.ALPHA)
	team_bravo.button_pressed = (team == GameManager.Team.BRAVO)

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text

# ─── Map selector ─────────────────────────────────────────────────────────────
func _build_map_selector() -> void:
	var lbl := Label.new()
	lbl.text = "CARTE"
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(C_DIM, 0.8))

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(0, 44)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_theme_font_size_override("font_size", 14)
	opt.add_theme_color_override("font_color", C_WHITE)

	var keys := MAPS.keys()
	for i in keys.size():
		opt.add_item(keys[i], i)
		if MAPS[keys[i]] == _selected_map:
			opt.select(i)
	opt.item_selected.connect(func(idx: int):
		_selected_map = MAPS[keys[idx]]
		$MapInfoPanel/MapStatsRow/StatMap/StatMapVal.text = keys[idx]
	)

	var confirm_btn := host_panel.get_node_or_null("ConfirmBtn")
	var pos := confirm_btn.get_index() if confirm_btn else host_panel.get_child_count()
	host_panel.add_child(lbl)
	host_panel.move_child(lbl, pos)
	host_panel.add_child(opt)
	host_panel.move_child(opt, pos + 1)
