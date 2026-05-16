extends CanvasLayer

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var main_panel:    VBoxContainer = $ContentArea/MainPanel
@onready var host_panel:    VBoxContainer = $ContentArea/HostPanel
@onready var join_panel:    VBoxContainer = $ContentArea/JoinPanel
@onready var settings_panel:VBoxContainer = $ContentArea/SettingsPanel
@onready var name_input:    LineEdit      = $ContentArea/MainPanel/NameInput
@onready var host_btn:      Button        = $ContentArea/MainPanel/HostBtn
@onready var join_btn:      Button        = $ContentArea/MainPanel/JoinBtn
@onready var quit_btn:      Button        = $ContentArea/MainPanel/QuitBtn
@onready var host_port:     SpinBox       = $ContentArea/HostPanel/PortSpin
@onready var host_confirm:  Button        = $ContentArea/HostPanel/ConfirmBtn
@onready var host_back:     Button        = $ContentArea/HostPanel/BackBtn
@onready var join_address:  LineEdit      = $ContentArea/JoinPanel/AddressInput
@onready var join_port:     SpinBox       = $ContentArea/JoinPanel/PortSpin
@onready var join_confirm:  Button        = $ContentArea/JoinPanel/ConnectBtn
@onready var join_back:     Button        = $ContentArea/JoinPanel/BackBtn
@onready var status_label:  Label         = $StatusLabel
@onready var team_alpha:    Button        = $ContentArea/MainPanel/TeamRow/TeamAlpha
@onready var team_bravo:    Button        = $ContentArea/MainPanel/TeamRow/TeamBravo
@onready var content_area:  VBoxContainer = $ContentArea

const MAPS := {
	"TEST MAP"  : "res://scenes/maps/TestMap.tscn",
	"OASIS"     : "res://scenes/maps/Oasis.tscn",
}
var _selected_map: String = "res://scenes/maps/TestMap.tscn"

# ─── Palette ─────────────────────────────────────────────────────────────────
const C_GREEN     := Color(0.18, 0.72, 0.38, 1.0)
const C_GREEN_HL  := Color(0.28, 0.95, 0.52, 1.0)
const C_GREEN_DIM := Color(0.10, 0.38, 0.20, 1.0)
const C_SURFACE   := Color(0.04, 0.07, 0.11, 0.90)
const C_SURFACE_H := Color(0.07, 0.12, 0.18, 0.95)
const C_BLUE      := Color(0.22, 0.54, 1.00, 1.0)
const C_BLUE_HL   := Color(0.32, 0.70, 1.00, 1.0)
const C_RED       := Color(1.00, 0.28, 0.28, 1.0)
const C_RED_HL    := Color(1.00, 0.44, 0.44, 1.0)
const C_TEXT      := Color(0.82, 0.92, 0.84, 1.0)
const C_TEXT_DIM  := Color(0.40, 0.52, 0.44, 0.80)

func _ready() -> void:
	_show_panel(main_panel)
	_apply_styles()
	_connect_buttons()
	_connect_network()
	name_input.text = "SOLDIER_%d" % randi_range(100, 999)
	_animate_intro()

# ─── Style factory ───────────────────────────────────────────────────────────
func _sbox(bg: Color, border_l: Color, bw: int = 3, corner: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_width_left   = bw
	s.border_color        = border_l
	s.set_corner_radius_all(corner)
	s.content_margin_left   = 16.0
	s.content_margin_right  = 16.0
	s.content_margin_top    = 7.0
	s.content_margin_bottom = 7.0
	return s

func _sbox_outline(bg: Color, border: Color, bw: int = 1, corner: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = bg
	s.border_width_left   = bw
	s.border_width_right  = bw
	s.border_width_top    = bw
	s.border_width_bottom = bw
	s.border_color        = border
	s.set_corner_radius_all(corner)
	s.content_margin_left   = 16.0
	s.content_margin_right  = 16.0
	s.content_margin_top    = 7.0
	s.content_margin_bottom = 7.0
	return s

func _input_sbox(b_col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = Color(0.02, 0.04, 0.07, 0.95)
	s.border_width_bottom = 2
	s.border_color        = b_col
	s.set_corner_radius_all(1)
	s.content_margin_left   = 12.0
	s.content_margin_right  = 12.0
	s.content_margin_top    = 9.0
	s.content_margin_bottom = 9.0
	return s

func _apply_styles() -> void:
	var no_focus := StyleBoxEmpty.new()

	# ── Primary action buttons (HOST / JOIN) ──────────────────────────────────
	var s_n := _sbox(C_SURFACE,                          C_GREEN,    3)
	var s_h := _sbox(C_SURFACE_H,                        C_GREEN_HL, 3)
	var s_p := _sbox(Color(0.02, 0.06, 0.08, 0.95),     C_GREEN_DIM, 4)
	for btn: Button in [host_btn, join_btn]:
		_style_btn(btn, s_n, s_h, s_p, no_focus, C_TEXT, C_GREEN_HL, 15)

	# ── Confirm buttons ───────────────────────────────────────────────────────
	var s_cn := _sbox(Color(0.03, 0.14, 0.07, 0.95), C_GREEN,    3)
	var s_ch := _sbox(Color(0.05, 0.20, 0.10, 0.95), C_GREEN_HL, 3)
	for btn: Button in [host_confirm, join_confirm]:
		_style_btn(btn, s_cn, s_ch, s_p, no_focus, Color(0.65, 1.0, 0.72), C_GREEN_HL, 15)

	# ── Back buttons ─────────────────────────────────────────────────────────
	var s_bn := _sbox(Color(0.03, 0.04, 0.07, 0.55), Color(0.20, 0.26, 0.22, 0.35), 2)
	var s_bh := _sbox(Color(0.05, 0.07, 0.10, 0.70), Color(0.28, 0.36, 0.30, 0.55), 2)
	for btn: Button in [host_back, join_back]:
		_style_btn(btn, s_bn, s_bh, s_bn, no_focus, C_TEXT_DIM, C_TEXT, 12)

	# ── Quit button ───────────────────────────────────────────────────────────
	var s_qn := _sbox(Color(0.03, 0.04, 0.06, 0.60), Color(0.22, 0.28, 0.24, 0.35), 2)
	var s_qh := _sbox(Color(0.05, 0.07, 0.09, 0.75), Color(0.30, 0.40, 0.32, 0.55), 2)
	_style_btn(quit_btn, s_qn, s_qh, s_qn, no_focus, C_TEXT_DIM, C_TEXT, 12)

	# ── Team ALPHA ────────────────────────────────────────────────────────────
	var s_an := _sbox_outline(Color(0.04, 0.08, 0.18, 0.88), Color(0.18, 0.48, 1.0, 0.40), 1)
	var s_ap := _sbox(Color(0.06, 0.14, 0.34, 0.95), C_BLUE_HL, 4)
	_style_btn(team_alpha, s_an, s_ap, s_ap, no_focus, Color(0.48, 0.70, 1.0), C_BLUE_HL, 12)
	team_alpha.add_theme_stylebox_override("pressed", s_ap)

	# ── Team BRAVO ────────────────────────────────────────────────────────────
	var s_rn := _sbox_outline(Color(0.16, 0.04, 0.04, 0.88), Color(1.0, 0.26, 0.26, 0.40), 1)
	var s_rp := _sbox(Color(0.28, 0.04, 0.04, 0.95), C_RED_HL, 4)
	_style_btn(team_bravo, s_rn, s_rp, s_rp, no_focus, Color(1.0, 0.50, 0.50), C_RED_HL, 12)
	team_bravo.add_theme_stylebox_override("pressed", s_rp)

	# ── Inputs ────────────────────────────────────────────────────────────────
	for le: LineEdit in [name_input, join_address]:
		if not le: continue
		le.add_theme_stylebox_override("normal", _input_sbox(Color(0.18, 0.72, 0.38, 0.40)))
		le.add_theme_stylebox_override("focus",  _input_sbox(C_GREEN_HL))
		le.add_theme_color_override("font_color",             C_TEXT)
		le.add_theme_color_override("font_placeholder_color", Color(0.26, 0.36, 0.29, 0.55))
		le.add_theme_color_override("caret_color",            C_GREEN_HL)
		le.add_theme_font_size_override("font_size", 14)

	# ── Title shadow/glow ─────────────────────────────────────────────────────
	for lbl_path in ["ContentArea/TitleBATTLE", "ContentArea/TitleZONE/ZoneLabel"]:
		var lbl := get_node_or_null(lbl_path) as Label
		if lbl:
			lbl.add_theme_color_override("font_shadow_color", Color(0.18, 0.72, 0.38, 0.18))
			lbl.add_theme_constant_override("shadow_offset_x",    0)
			lbl.add_theme_constant_override("shadow_offset_y",    2)
			lbl.add_theme_constant_override("shadow_outline_size", 18)

	var six := get_node_or_null("ContentArea/TitleZONE/SixLabel") as Label
	if six:
		six.add_theme_color_override("font_shadow_color", Color(0.18, 0.72, 0.38, 0.5))
		six.add_theme_constant_override("shadow_outline_size", 22)

func _style_btn(btn: Button,
		n: StyleBoxFlat, h: StyleBoxFlat, p: StyleBoxFlat,
		f: StyleBox, col: Color, col_h: Color, sz: int) -> void:
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", p)
	btn.add_theme_stylebox_override("focus",   f)
	btn.add_theme_color_override("font_color",         col)
	btn.add_theme_color_override("font_hover_color",   col_h)
	btn.add_theme_color_override("font_pressed_color", col)
	btn.add_theme_font_size_override("font_size", sz)

# ─── Intro animation ─────────────────────────────────────────────────────────
func _animate_intro() -> void:
	# Glissement + fondu de la zone de contenu (enfant direct du CanvasLayer — position fonctionne)
	var start_y := content_area.position.y
	content_area.modulate.a  = 0.0
	content_area.position.y  = start_y + 28.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(content_area, "modulate:a",  1.0,     0.65).set_ease(Tween.EASE_OUT)
	tw.tween_property(content_area, "position:y",  start_y, 0.5 ).set_ease(Tween.EASE_OUT)

# ─── Panel transitions ────────────────────────────────────────────────────────
func _switch_panel(next: VBoxContainer) -> void:
	var current: VBoxContainer = null
	for p: VBoxContainer in [main_panel, host_panel, join_panel, settings_panel]:
		if p and p.visible:
			current = p
			break
	if current:
		var tw_out := create_tween()
		tw_out.tween_property(current, "modulate:a", 0.0, 0.14)
		tw_out.tween_callback(func():
			_show_panel(next)
			next.modulate.a = 0.0
			var tw_in := create_tween()
			tw_in.tween_property(next, "modulate:a", 1.0, 0.20).set_ease(Tween.EASE_OUT)
		)
	else:
		_show_panel(next)

func _show_panel(panel: VBoxContainer) -> void:
	for p: VBoxContainer in [main_panel, host_panel, join_panel, settings_panel]:
		if p:
			p.visible = (p == panel)

# ─── Buttons ─────────────────────────────────────────────────────────────────
func _connect_buttons() -> void:
	host_btn.pressed.connect(func(): _switch_panel(host_panel))
	join_btn.pressed.connect(func(): _switch_panel(join_panel))
	quit_btn.pressed.connect(get_tree().quit)
	host_back.pressed.connect(func(): _switch_panel(main_panel))
	join_back.pressed.connect(func(): _switch_panel(main_panel))
	host_confirm.pressed.connect(_on_host_pressed)
	join_confirm.pressed.connect(_on_join_pressed)
	_build_map_selector()
	team_alpha.pressed.connect(func(): _select_team(GameManager.Team.ALPHA))
	team_bravo.pressed.connect(func(): _select_team(GameManager.Team.BRAVO))

func _connect_network() -> void:
	NetworkManager.server_created.connect(_on_server_created)
	NetworkManager.joined_server.connect(_on_joined_server)
	NetworkManager.connection_failed.connect(_on_connection_failed)

# ─── Network ─────────────────────────────────────────────────────────────────
func _on_host_pressed() -> void:
	NetworkManager.local_player_name = name_input.text
	NetworkManager.current_map_scene = _selected_map
	var err := NetworkManager.create_server(int(host_port.value))
	_set_status("Starting server…" if err == OK else "Failed: " + str(err))

func _on_join_pressed() -> void:
	NetworkManager.local_player_name = name_input.text
	var addr := join_address.text.strip_edges()
	if addr.is_empty(): addr = "127.0.0.1"
	var err := NetworkManager.join_server(addr, int(join_port.value))
	_set_status("Connecting to %s…" % addr if err == OK else "Error: " + str(err))

func _on_server_created() -> void:
	_set_status("Server active — loading map…")
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file(_selected_map)

func _on_joined_server() -> void:
	_set_status("Connected — loading map…")
	await get_tree().create_timer(1.2).timeout
	get_tree().change_scene_to_file(NetworkManager.current_map_scene)

func _on_connection_failed() -> void:
	_set_status("Connection failed. Check address and try again.")

func _build_map_selector() -> void:
	var host_panel := get_node_or_null("ContentArea/HostPanel") as VBoxContainer
	if not host_panel:
		return

	var lbl := Label.new()
	lbl.text = "MAP"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.3, 0.42, 0.34, 0.7))

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(360, 40)
	opt.add_theme_font_size_override("font_size", 14)
	opt.add_theme_color_override("font_color", C_TEXT)

	var keys := MAPS.keys()
	for i in keys.size():
		opt.add_item(keys[i], i)
		if MAPS[keys[i]] == _selected_map:
			opt.select(i)

	opt.item_selected.connect(func(idx: int):
		_selected_map = MAPS[keys[idx]]
	)

	# Insère avant ConfirmBtn
	var confirm_btn := host_panel.get_node_or_null("ConfirmBtn")
	var insert_pos  := host_panel.get_child_count()
	if confirm_btn:
		insert_pos = confirm_btn.get_index()

	host_panel.add_child(lbl)
	host_panel.move_child(lbl, insert_pos)
	host_panel.add_child(opt)
	host_panel.move_child(opt, insert_pos + 1)

func _select_team(team: int) -> void:
	NetworkManager.local_player_team = team
	team_alpha.button_pressed = (team == GameManager.Team.ALPHA)
	team_bravo.button_pressed = (team == GameManager.Team.BRAVO)

func _set_status(text: String) -> void:
	if status_label:
		status_label.text = text
