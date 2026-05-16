extends CanvasLayer
class_name HUD

# ─── Node refs ───────────────────────────────────────────────────────────────
@onready var health_bar: ProgressBar     = $Bottom/HealthBar
@onready var armor_bar: ProgressBar      = $Bottom/ArmorBar
@onready var health_label: Label         = $Bottom/HealthLabel
@onready var ammo_current: Label         = $Bottom/AmmoBox/CurrentAmmo
@onready var ammo_reserve: Label         = $Bottom/AmmoBox/ReserveAmmo
@onready var weapon_name_label: Label    = $Bottom/WeaponName
@onready var crosshair: Control          = $Crosshair
@onready var hit_indicator: ColorRect    = $HitIndicator
@onready var kill_feed: VBoxContainer    = $TopRight/KillFeed
@onready var scoreboard: Control         = $Scoreboard
@onready var alpha_tickets: Label        = $Top/AlphaTickets
@onready var bravo_tickets: Label        = $Top/BravoTickets
@onready var round_timer: Label          = $Top/RoundTimer
@onready var flag_icons: HBoxContainer   = $Top/FlagIcons
@onready var minimap: SubViewportContainer = $Minimap
@onready var vehicle_hud: Control        = $VehicleHUD
@onready var vehicle_hp_bar: ProgressBar = $VehicleHUD/VehicleHP
@onready var speed_label: Label          = $VehicleHUD/SpeedLabel
@onready var respawn_overlay: Control    = $RespawnOverlay
@onready var respawn_timer: Label        = $RespawnOverlay/TimerLabel
@onready var kill_streak_label: Label    = $KillStreak/Label

# ─── State ───────────────────────────────────────────────────────────────────
var _kill_feed_entries:  Array           = []
var _kill_streak:        int             = 0
var _player:             PlayerController = null
var _dmg_indicators:     Array[ColorRect] = []
var _dmg_tweens:         Array[Tween]     = []
var _hit_marker_lines:   Array[ColorRect] = []
var _hit_marker_tween:   Tween            = null
var _minimap_root:       Control          = null
var _flag_icon_nodes:    Array[ColorRect] = []
var _flag_hud_icons:     Array[Panel]     = []
var _stamina_bar:        ColorRect        = null
var _stamina_bg:         ColorRect        = null
var _suppress_overlay:   ColorRect        = null
var _scope_overlay:      ColorRect        = null
var _damage_vignette:    ColorRect        = null
var _vignette_tween:     Tween            = null
var _low_health_t:       float            = 0.0
var _reload_bar:         ColorRect        = null
var _reload_tween:       Tween            = null
var _crosshair_lines:    Array[ColorRect] = []
var _crosshair_base_pos: Array[Vector2]   = []
var _spread:             float            = 0.0

func _ready() -> void:
	scoreboard.visible     = false
	vehicle_hud.visible    = false
	respawn_overlay.visible = false
	kill_streak_label.visible = false
	var pp := get_node_or_null("PostProcess")
	if not pp:
		pp = _build_post_process()
	if pp:
		pp.add_to_group("post_process")
	_apply_styles()
	_connect_signals()

func _build_post_process() -> ColorRect:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float suppress_str : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 col = texture(TEXTURE, UV);
	float grey = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	col.rgb = mix(col.rgb, vec3(grey), suppress_str * 0.7);
	vec2 uv = UV - 0.5;
	float vig = dot(uv, uv) * suppress_str * 2.2;
	col.rgb *= max(1.0 - vig, 0.0);
	COLOR = col;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	var pp := ColorRect.new()
	pp.name = "PostProcess"
	pp.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pp.color        = Color(1, 1, 1, 1)
	pp.material     = mat
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pp)
	move_child(pp, 0)
	return pp

# ─── Modern HUD styling ───────────────────────────────────────────────────────
func _apply_styles() -> void:
	# ── Bandeaux de fond derrière les barres haut et bas ──
	var top_bg := ColorRect.new()
	top_bg.anchor_right  = 1.0
	top_bg.offset_bottom = 60.0
	top_bg.color = Color(0.0, 0.02, 0.04, 0.72)
	top_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_bg)
	move_child(top_bg, 0)

	var bot_bg := ColorRect.new()
	bot_bg.anchor_right  = 1.0
	bot_bg.anchor_top    = 1.0
	bot_bg.anchor_bottom = 1.0
	bot_bg.offset_top    = -82.0
	bot_bg.color = Color(0.0, 0.02, 0.04, 0.72)
	bot_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_bg)
	move_child(bot_bg, 1)

	# ── Lignes d'accentuation de la barre du haut ──
	var top_line := ColorRect.new()
	top_line.anchor_right  = 1.0
	top_line.offset_top    = 58.0
	top_line.offset_bottom = 60.0
	top_line.color = Color(0.18, 0.72, 0.38, 0.35)
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_line)
	move_child(top_line, 2)

	var bot_line := ColorRect.new()
	bot_line.anchor_right  = 1.0
	bot_line.anchor_top    = 1.0
	bot_line.anchor_bottom = 1.0
	bot_line.offset_top    = -82.0
	bot_line.offset_bottom = -80.0
	bot_line.color = Color(0.18, 0.72, 0.38, 0.35)
	bot_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bot_line)
	move_child(bot_line, 3)

	# ── Barre de vie ──
	var hp_fill := StyleBoxFlat.new()
	hp_fill.bg_color = Color(0.14, 0.82, 0.34, 1.0)
	hp_fill.set_corner_radius_all(2)
	var hp_bg := StyleBoxFlat.new()
	hp_bg.bg_color = Color(0.03, 0.1, 0.05, 0.85)
	hp_bg.border_width_left   = 1
	hp_bg.border_width_right  = 1
	hp_bg.border_width_top    = 1
	hp_bg.border_width_bottom = 1
	hp_bg.border_color = Color(0.1, 0.35, 0.16, 0.5)
	hp_bg.set_corner_radius_all(2)
	if health_bar:
		health_bar.add_theme_stylebox_override("fill",       hp_fill)
		health_bar.add_theme_stylebox_override("background", hp_bg)

	# ── Barre d'armure ──
	var armor_fill := StyleBoxFlat.new()
	armor_fill.bg_color = Color(0.18, 0.55, 1.0, 1.0)
	armor_fill.set_corner_radius_all(2)
	var armor_bg := StyleBoxFlat.new()
	armor_bg.bg_color = Color(0.03, 0.06, 0.16, 0.85)
	armor_bg.border_width_left   = 1
	armor_bg.border_width_right  = 1
	armor_bg.border_width_top    = 1
	armor_bg.border_width_bottom = 1
	armor_bg.border_color = Color(0.1, 0.2, 0.5, 0.5)
	armor_bg.set_corner_radius_all(2)
	if armor_bar:
		armor_bar.add_theme_stylebox_override("fill",       armor_fill)
		armor_bar.add_theme_stylebox_override("background", armor_bg)

	# ── Barre de vie véhicule ──
	var veh_fill := StyleBoxFlat.new()
	veh_fill.bg_color = Color(1.0, 0.68, 0.08, 1.0)
	veh_fill.set_corner_radius_all(2)
	var veh_bg := StyleBoxFlat.new()
	veh_bg.bg_color = Color(0.12, 0.08, 0.02, 0.85)
	veh_bg.set_corner_radius_all(2)
	if vehicle_hp_bar:
		vehicle_hp_bar.add_theme_stylebox_override("fill",       veh_fill)
		vehicle_hp_bar.add_theme_stylebox_override("background", veh_bg)

	# ── Label de vie ──
	if health_label:
		health_label.add_theme_color_override("font_color", Color(0.14, 0.9, 0.38, 1.0))
		health_label.add_theme_font_size_override("font_size", 20)

	# ── Munitions ──
	if ammo_current:
		ammo_current.add_theme_color_override("font_color", Color(0.92, 0.96, 0.93, 1.0))
		ammo_current.add_theme_font_size_override("font_size", 34)
	if ammo_reserve:
		ammo_reserve.add_theme_color_override("font_color", Color(0.38, 0.5, 0.42, 0.85))
		ammo_reserve.add_theme_font_size_override("font_size", 18)
	if weapon_name_label:
		weapon_name_label.add_theme_color_override("font_color", Color(0.65, 0.82, 0.68, 0.9))
		weapon_name_label.add_theme_font_size_override("font_size", 12)

	# ── Tickets d'équipe ──
	if alpha_tickets:
		alpha_tickets.add_theme_color_override("font_color", Color(0.35, 0.68, 1.0, 1.0))
		alpha_tickets.add_theme_font_size_override("font_size", 26)
	if bravo_tickets:
		bravo_tickets.add_theme_color_override("font_color", Color(1.0, 0.32, 0.32, 1.0))
		bravo_tickets.add_theme_font_size_override("font_size", 26)
	if round_timer:
		round_timer.add_theme_color_override("font_color", Color(0.88, 0.92, 0.88, 1.0))
		round_timer.add_theme_font_size_override("font_size", 28)

	# ── Viseur — colore et mémorise les lignes du crosshair ──
	if crosshair:
		_crosshair_lines.clear()
		_crosshair_base_pos.clear()
		for child in crosshair.get_children():
			if child is ColorRect:
				child.color = Color(0.85, 1.0, 0.88, 0.9)
				_crosshair_lines.append(child as ColorRect)
				_crosshair_base_pos.append((child as ColorRect).position)

	# ── Bordure de la minimap ──
	if minimap:
		var mm_style := StyleBoxFlat.new()
		mm_style.bg_color     = Color(0.0, 0.0, 0.0, 0.0)
		mm_style.border_width_left   = 1
		mm_style.border_width_right  = 1
		mm_style.border_width_top    = 1
		mm_style.border_width_bottom = 1
		mm_style.border_color = Color(0.18, 0.72, 0.38, 0.45)
		mm_style.set_corner_radius_all(2)

	# ── Overlay de réapparition ──
	if respawn_timer:
		respawn_timer.add_theme_color_override("font_color",        Color(0.92, 0.96, 0.88, 1.0))
		respawn_timer.add_theme_color_override("font_shadow_color", Color(0.9, 0.2, 0.1, 0.45))
		respawn_timer.add_theme_constant_override("shadow_outline_size", 10)
		respawn_timer.add_theme_font_size_override("font_size", 40)

	# ── Label de série de kills ──
	if kill_streak_label:
		kill_streak_label.add_theme_color_override("font_color",        Color(1.0, 0.82, 0.1, 1.0))
		kill_streak_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.5, 0.0, 0.5))
		kill_streak_label.add_theme_constant_override("shadow_outline_size", 8)
		kill_streak_label.add_theme_font_size_override("font_size", 34)
	_build_damage_indicators()
	_build_hit_marker()
	_build_minimap_panel()
	_build_stamina_bar()
	_build_suppress_overlay()
	_build_damage_vignette()
	_build_reload_bar()
	_build_scope_overlay()

func _team_color(team: int) -> Color:
	match team:
		1: return Color(0.22, 0.55, 1.00)   # Alpha — bleu
		2: return Color(1.00, 0.25, 0.20)   # Bravo — rouge
		_: return Color(0.68, 0.68, 0.68)   # neutre — gris

func _build_minimap_panel() -> void:
	if not minimap:
		return
	# Fond sombre
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color        = Color(0.02, 0.06, 0.04, 0.84)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.add_child(bg)
	# Bordure verte militaire
	var border_sbox := StyleBoxFlat.new()
	border_sbox.bg_color          = Color(0, 0, 0, 0)
	border_sbox.border_color      = Color(0.18, 0.72, 0.38, 0.55)
	border_sbox.border_width_left   = 1
	border_sbox.border_width_right  = 1
	border_sbox.border_width_top    = 1
	border_sbox.border_width_bottom = 1
	var border_panel := Panel.new()
	border_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	border_panel.add_theme_stylebox_override("panel", border_sbox)
	border_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.add_child(border_panel)
	# Dot joueur local (toujours au centre)
	var pdot := ColorRect.new()
	pdot.name          = "PlayerDot"
	pdot.size          = Vector2(7, 7)
	pdot.color         = Color(0.18, 0.92, 0.38)
	pdot.anchor_left   = 0.5
	pdot.anchor_top    = 0.5
	pdot.anchor_right  = 0.5
	pdot.anchor_bottom = 0.5
	pdot.offset_left   = -3
	pdot.offset_top    = -3
	pdot.offset_right  =  4
	pdot.offset_bottom =  4
	pdot.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	minimap.add_child(pdot)
	_minimap_root = minimap

func _setup_minimap_flags() -> void:
	if not _minimap_root:
		return
	for dot in _flag_icon_nodes:
		dot.queue_free()
	_flag_icon_nodes.clear()
	for cp in get_tree().get_nodes_in_group("capture_points"):
		var dot          := ColorRect.new()
		dot.size          = Vector2(8, 8)
		dot.color         = _team_color(cp.owner_team if "owner_team" in cp else 0)
		dot.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		_minimap_root.add_child(dot)
		_flag_icon_nodes.append(dot)

func _setup_flag_hud_icons() -> void:
	if not flag_icons:
		return
	for child in flag_icons.get_children():
		child.queue_free()
	_flag_hud_icons.clear()
	flag_icons.add_theme_constant_override("separation", 5)
	for cp in get_tree().get_nodes_in_group("capture_points"):
		var icon           := Panel.new()
		icon.custom_minimum_size = Vector2(22, 22)
		var sbox           := StyleBoxFlat.new()
		sbox.bg_color       = _team_color(cp.owner_team if "owner_team" in cp else 0)
		sbox.border_color   = Color(0.18, 0.72, 0.38, 0.45)
		sbox.border_width_left   = 1
		sbox.border_width_right  = 1
		sbox.border_width_top    = 1
		sbox.border_width_bottom = 1
		sbox.set_corner_radius_all(2)
		icon.add_theme_stylebox_override("panel", sbox)
		icon.set_meta("sbox", sbox)
		icon.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		flag_icons.add_child(icon)
		_flag_hud_icons.append(icon)

func _update_minimap() -> void:
	if not _minimap_root or not _player:
		return
	var mm_size  := _minimap_root.size
	var center   := mm_size * 0.5
	const SCALE  := 0.70   # pixels par unité monde (vue ~200 unités autour du joueur)
	var pp       := _player.global_position
	var flags    := get_tree().get_nodes_in_group("capture_points")
	for i in mini(flags.size(), _flag_icon_nodes.size()):
		var fp   := (flags[i] as Node3D).global_position
		var dot  := _flag_icon_nodes[i]
		dot.position = center + Vector2((fp.x - pp.x) * SCALE, (fp.z - pp.z) * SCALE) - Vector2(4, 4)
		if "owner_team" in flags[i]:
			dot.color = _team_color(flags[i].owner_team)

func _update_flag_hud() -> void:
	var flags := get_tree().get_nodes_in_group("capture_points")
	for i in mini(flags.size(), _flag_hud_icons.size()):
		if "owner_team" in flags[i]:
			var sbox := _flag_hud_icons[i].get_meta("sbox") as StyleBoxFlat
			if sbox:
				sbox.bg_color = _team_color(flags[i].owner_team)

func _build_damage_indicators() -> void:
	# 4 indicateurs de bord : devant(haut), droite, derrière(bas), gauche — indices 0-3
	var configs: Array = [
		# [ancre_g, ancre_h, ancre_d, ancre_b, déc_g, déc_h, déc_d, déc_b]
		[0.5, 0.0, 0.5, 0.0,  -100,   8,  100,  72],  # top
		[1.0, 0.5, 1.0, 0.5,   -72, -100,   -8, 100],  # right
		[0.5, 1.0, 0.5, 1.0,  -100, -72,   100,  -8],  # bottom
		[0.0, 0.5, 0.0, 0.5,     8, -100,   72, 100],  # left
	]
	for cfg in configs:
		var rect              := ColorRect.new()
		rect.color             = Color(0.9, 0.05, 0.05, 0.0)
		rect.mouse_filter      = Control.MOUSE_FILTER_IGNORE
		rect.anchor_left       = cfg[0]
		rect.anchor_top        = cfg[1]
		rect.anchor_right      = cfg[2]
		rect.anchor_bottom     = cfg[3]
		rect.offset_left       = cfg[4]
		rect.offset_top        = cfg[5]
		rect.offset_right      = cfg[6]
		rect.offset_bottom     = cfg[7]
		add_child(rect)
		_dmg_indicators.append(rect)

func _build_hit_marker() -> void:
	var container         := Control.new()
	container.anchor_left  = 0.5
	container.anchor_top   = 0.5
	container.anchor_right = 0.5
	container.anchor_bottom = 0.5
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	# [position, taille] pour les lignes haut / droite / bas / gauche
	var lines: Array = [
		[Vector2(-1, -17), Vector2(2, 12)],   # top (vertical)
		[Vector2(5,   -1), Vector2(12, 2)],   # right (horizontal)
		[Vector2(-1,   5), Vector2(2, 12)],   # bottom (vertical)
		[Vector2(-17, -1), Vector2(12, 2)],   # left (horizontal)
	]
	for l in lines:
		var rect          := ColorRect.new()
		rect.position      = l[0]
		rect.size          = l[1]
		rect.color         = Color(1.0, 1.0, 1.0, 0.0)
		rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)
		_hit_marker_lines.append(rect)

func _connect_signals() -> void:
	GameManager.scores_updated.connect(_on_scores_updated)
	GameManager.player_died_event.connect(_on_kill_event)
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("scoreboard"):
		scoreboard.visible = true
	if Input.is_action_just_released("scoreboard"):
		scoreboard.visible = false
	_update_minimap()
	_update_flag_hud()
	_update_scope(delta)
	_update_low_health_vignette(delta)
	_update_vehicle_hud()
	_update_crosshair_spread(delta)

func link_player(player: PlayerController) -> void:
	_player = player
	player.health.health_changed.connect(_on_health_changed)
	player.health.armor_changed.connect(_on_armor_changed)
	player.health.damaged.connect(_on_damaged)
	player.health.died.connect(_on_player_died)
	if player.weapon_manager:
		player.weapon_manager.ammo_updated.connect(_on_ammo_updated)
		player.weapon_manager.weapon_switched.connect(_on_weapon_switched)
	player.entered_vehicle.connect(_on_entered_vehicle)
	player.exited_vehicle.connect(_on_exited_vehicle)
	player.stamina_changed.connect(_on_stamina_changed)
	_connect_weapon_signals(player)
	_setup_minimap_flags()
	_setup_flag_hud_icons()
	_update_health_display(100.0, 100.0)
	# Connecte le SuppressSystem si présent
	var ss := player.find_child("SuppressSystem", true, false) as SuppressSystem
	if ss:
		ss.suppression_changed.connect(_on_suppression_changed)

func _connect_weapon_signals(player: PlayerController) -> void:
	if not player.weapon_manager:
		return
	for w in player.weapon_manager.weapons:
		if not w.hit_confirmed.is_connected(_on_hit_confirmed):
			w.hit_confirmed.connect(_on_hit_confirmed)
		if not w.reload_started.is_connected(_on_reload_started):
			w.reload_started.connect(_on_reload_started)
		if not w.fired.is_connected(_on_weapon_fired):
			w.fired.connect(_on_weapon_fired)

func _on_health_changed(current: float, max_hp: float) -> void:
	_update_health_display(current, max_hp)

func _update_health_display(current: float, max_hp: float) -> void:
	if health_bar:
		var pct := current / max_hp
		health_bar.value = pct * 100.0
		# Vire au rouge quand la vie est basse
		var fill := StyleBoxFlat.new()
		fill.set_corner_radius_all(2)
		fill.bg_color = Color(0.14, 0.82, 0.34, 1.0).lerp(Color(0.9, 0.18, 0.14, 1.0), 1.0 - pct)
		health_bar.add_theme_stylebox_override("fill", fill)
	if health_label:
		health_label.text = str(int(current))

func _on_armor_changed(current: float, max_armor: float) -> void:
	if armor_bar:
		armor_bar.value = (current / max_armor) * 100.0

func _on_damaged(_amount: float, source_id: int) -> void:
	if hit_indicator:
		hit_indicator.modulate.a = 0.45
		var tween := create_tween()
		tween.tween_property(hit_indicator, "modulate:a", 0.0, 0.55)
	_flash_damage_vignette()
	_show_damage_direction(source_id)

func _show_damage_direction(source_id: int) -> void:
	if not _player or _dmg_indicators.is_empty():
		return
	var attacker: Node3D = null
	for p in get_tree().get_nodes_in_group("players"):
		if "peer_id" in p and p.peer_id == source_id:
			attacker = p as Node3D
			break
	if not attacker:
		return
	var to_src := attacker.global_position - _player.global_position
	to_src.y    = 0.0
	if to_src.length_squared() < 0.01:
		return
	to_src      = to_src.normalized()
	var fwd     := -_player.global_transform.basis.z
	var right   := _player.global_transform.basis.x
	var dot_f   := to_src.dot(fwd)
	var dot_r   := to_src.dot(right)
	# weights[i] = 0=devant(haut), 1=droite, 2=derrière(bas), 3=gauche
	var weights := [maxf(dot_f, 0.0), maxf(dot_r, 0.0),
					maxf(-dot_f, 0.0), maxf(-dot_r, 0.0)]
	for i in 4:
		if weights[i] > 0.35:
			_pulse_indicator(i, weights[i])

func _pulse_indicator(idx: int, strength: float) -> void:
	if idx >= _dmg_indicators.size():
		return
	var rect  := _dmg_indicators[idx]
	while _dmg_tweens.size() <= idx:
		_dmg_tweens.append(null)
	if _dmg_tweens[idx] and _dmg_tweens[idx].is_valid():
		_dmg_tweens[idx].kill()
	rect.color.a   = clampf(strength * 0.78, 0.22, 0.75)
	var t          := create_tween()
	t.tween_property(rect, "color:a", 0.0, 0.65)
	_dmg_tweens[idx] = t

func _on_hit_confirmed(is_headshot: bool) -> void:
	var col := Color(1.0, 0.18, 0.18) if is_headshot else Color(1.0, 1.0, 1.0)
	for line in _hit_marker_lines:
		line.color   = col
		line.color.a = 0.92
	if _hit_marker_tween and _hit_marker_tween.is_valid():
		_hit_marker_tween.kill()
	_hit_marker_tween = create_tween()
	_hit_marker_tween.tween_interval(0.055)
	for line in _hit_marker_lines:
		_hit_marker_tween.parallel().tween_property(line, "color:a", 0.0, 0.14)

func _on_player_died(_source: int) -> void:
	_kill_streak = 0
	respawn_overlay.visible = true
	var t := 0.0
	while t < GameManager.RESPAWN_TIME:
		t += get_process_delta_time()
		respawn_timer.text = "RESPAWNING IN  %d" % int(GameManager.RESPAWN_TIME - t)
		await get_tree().process_frame
	respawn_overlay.visible = false
	_fade_in_from_black()

func _fade_in_from_black() -> void:
	var fade := ColorRect.new()
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.color       = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.85)
	tween.tween_callback(fade.queue_free)

func _on_ammo_updated(current: int, reserve: int) -> void:
	if ammo_current:
		ammo_current.text = str(current)
		var wm := _player.get_node_or_null("Head/Camera3D/WeaponManager") as WeaponManager if _player else null
		var low := wm != null and wm.get_current_weapon() != null and current <= int(wm.get_current_weapon().mag_size * 0.25)
		var col := Color(0.95, 0.18, 0.08, 1.0) if low else Color(0.92, 0.96, 0.93, 1.0)
		ammo_current.add_theme_color_override("font_color", col)
		if low:
			var t := create_tween()
			t.tween_property(ammo_current, "modulate:a", 0.3, 0.08)
			t.tween_property(ammo_current, "modulate:a", 1.0, 0.08)
	if ammo_reserve: ammo_reserve.text = "/ " + str(reserve)

func _on_weapon_switched(_slot: int, weapon: WeaponBase) -> void:
	if weapon_name_label and weapon:
		weapon_name_label.text = weapon.weapon_name.to_upper()

func _on_scores_updated(alpha: int, bravo: int) -> void:
	if alpha_tickets: alpha_tickets.text = str(alpha)
	if bravo_tickets: bravo_tickets.text = str(bravo)

func _on_kill_event(victim_id: int, killer_id: int) -> void:
	var killer_data := GameManager.get_player_data(killer_id)
	var victim_data := GameManager.get_player_data(victim_id)
	if not killer_data or not victim_data:
		return
	_add_killfeed_entry(killer_data.name, victim_data.name)
	if killer_id == multiplayer.get_unique_id():
		_kill_streak += 1
		_show_kill_streak()

func _add_killfeed_entry(killer: String, victim: String) -> void:
	var label := Label.new()
	label.text = "%s  ›  %s" % [killer.to_upper(), victim.to_upper()]
	label.add_theme_color_override("font_color", Color(0.88, 0.96, 0.72, 0.95))
	label.add_theme_font_size_override("font_size", 12)
	kill_feed.add_child(label)
	_kill_feed_entries.append(label)
	if _kill_feed_entries.size() > 5:
		_kill_feed_entries[0].queue_free()
		_kill_feed_entries.remove_at(0)
	var tween := create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)

func _show_kill_streak() -> void:
	if _kill_streak < 2:
		return
	var messages := {2: "DOUBLE KILL", 3: "TRIPLE KILL", 4: "QUAD KILL", 5: "KILLSTREAK!"}
	kill_streak_label.text = messages.get(_kill_streak, "KILLING SPREE!")
	kill_streak_label.visible = true
	kill_streak_label.modulate.a = 1.0
	kill_streak_label.scale = Vector2.ONE
	var tween := create_tween()
	tween.tween_property(kill_streak_label, "scale", Vector2(1.25, 1.25), 0.12)
	tween.tween_property(kill_streak_label, "scale", Vector2(1.0,  1.0),  0.1)
	tween.tween_interval(2.2)
	tween.tween_property(kill_streak_label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func(): kill_streak_label.visible = false)

func update_round_timer(seconds: float) -> void:
	if round_timer:
		round_timer.text = "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _on_game_state_changed(_new_state: GameManager.GameState) -> void:
	pass

func _on_entered_vehicle(vehicle: Node) -> void:
	vehicle_hud.visible = true
	if vehicle.has_signal("health_changed"):
		vehicle.health_changed.connect(_on_vehicle_hp)

func _on_exited_vehicle() -> void:
	vehicle_hud.visible = false

func _on_vehicle_hp(current: float, max_hp: float) -> void:
	if vehicle_hp_bar:
		vehicle_hp_bar.value = (current / max_hp) * 100.0

func _update_vehicle_hud() -> void:
	if not speed_label or not _player:
		return
	var v := _player.current_vehicle
	if not v or not vehicle_hud.visible:
		return
	var kmh := 0.0
	if v.has_method("get_speed_kmh"):
		kmh = v.get_speed_kmh()
	elif "linear_velocity" in v:
		kmh = (v as Node3D).get("linear_velocity", Vector3.ZERO).length() * 3.6
	speed_label.text = "%d km/h" % int(kmh)

func _build_stamina_bar() -> void:
	_stamina_bg = ColorRect.new()
	_stamina_bg.anchor_bottom = 1.0
	_stamina_bg.anchor_top    = 1.0
	_stamina_bg.anchor_left   = 0.0
	_stamina_bg.anchor_right  = 0.0
	_stamina_bg.offset_left   = 14.0
	_stamina_bg.offset_right  = 134.0
	_stamina_bg.offset_top    = -72.0
	_stamina_bg.offset_bottom = -65.0
	_stamina_bg.color         = Color(0.04, 0.06, 0.05, 0.7)
	_stamina_bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bg)

	_stamina_bar = ColorRect.new()
	_stamina_bar.anchor_bottom = 1.0
	_stamina_bar.anchor_top    = 1.0
	_stamina_bar.anchor_left   = 0.0
	_stamina_bar.anchor_right  = 0.0
	_stamina_bar.offset_left   = 14.0
	_stamina_bar.offset_right  = 134.0
	_stamina_bar.offset_top    = -72.0
	_stamina_bar.offset_bottom = -65.0
	_stamina_bar.color         = Color(0.18, 0.72, 0.38, 0.85)
	_stamina_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_stamina_bar)

func _build_suppress_overlay() -> void:
	_suppress_overlay = ColorRect.new()
	_suppress_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_suppress_overlay.color       = Color(0.0, 0.0, 0.0, 0.0)
	_suppress_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_suppress_overlay)

func _on_stamina_changed(current: float, max_val: float) -> void:
	if not _stamina_bar or not _stamina_bg:
		return
	var pct := current / max_val
	var full_w := 120.0
	_stamina_bar.offset_right = 14.0 + full_w * pct
	_stamina_bar.color = Color(0.18, 0.72, 0.38, 0.85) if pct > 0.3 else Color(0.9, 0.4, 0.1, 0.9)

func _on_suppression_changed(level: float) -> void:
	if not _suppress_overlay:
		return
	_suppress_overlay.color = Color(0.0, 0.0, 0.0, level * 0.18)

func _update_scope(_delta: float) -> void:
	if not _scope_overlay or not _player:
		return
	var wm := _player.get_node_or_null("Head/Camera3D/WeaponManager") as WeaponManager
	if not wm:
		_scope_overlay.visible = false
		return
	var w := wm.get_current_weapon()
	var scoped := w != null and w.weapon_name == "SR-98" and _player.is_aiming
	_scope_overlay.visible = scoped
	if crosshair:
		crosshair.visible = not scoped

func _on_weapon_fired() -> void:
	_spread = minf(_spread + 6.0, 18.0)

func _update_crosshair_spread(delta: float) -> void:
	_spread = maxf(_spread - delta * 22.0, 0.0)
	if _crosshair_lines.is_empty():
		return
	# Les 4 directions: [0]=haut, [1]=droite, [2]=bas, [3]=gauche
	var dirs := [Vector2(0, -1), Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]
	for i in mini(_crosshair_lines.size(), 4):
		if i < _crosshair_base_pos.size():
			_crosshair_lines[i].position = _crosshair_base_pos[i] + dirs[i] * _spread

func _build_reload_bar() -> void:
	# Barre de rechargement fine sous le compteur de munitions (coin bas droit)
	var bg := ColorRect.new()
	bg.anchor_right  = 1.0
	bg.anchor_top    = 1.0
	bg.anchor_bottom = 1.0
	bg.anchor_left   = 0.0
	bg.offset_left   = 0.0
	bg.offset_right  = 0.0
	bg.offset_top    = -83.0
	bg.offset_bottom = -80.0
	bg.color         = Color(0.04, 0.06, 0.04, 0.65)
	bg.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_reload_bar = ColorRect.new()
	_reload_bar.anchor_right  = 0.0
	_reload_bar.anchor_top    = 1.0
	_reload_bar.anchor_bottom = 1.0
	_reload_bar.anchor_left   = 0.0
	_reload_bar.offset_left   = 0.0
	_reload_bar.offset_right  = 0.0
	_reload_bar.offset_top    = -83.0
	_reload_bar.offset_bottom = -80.0
	_reload_bar.color         = Color(0.18, 0.72, 0.38, 0.9)
	_reload_bar.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_reload_bar.visible       = false
	add_child(_reload_bar)

func _on_reload_started(duration: float) -> void:
	if not _reload_bar:
		return
	if _reload_tween and _reload_tween.is_valid():
		_reload_tween.kill()
	var vp_w := get_viewport().get_visible_rect().size.x
	_reload_bar.offset_right = 0.0
	_reload_bar.visible      = true
	_reload_tween = create_tween()
	_reload_tween.tween_property(_reload_bar, "offset_right", vp_w, duration)
	_reload_tween.tween_callback(func():
		_reload_bar.visible       = false
		_reload_bar.offset_right  = 0.0)

func _build_damage_vignette() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.85, 0.05, 0.05, 0.0);
void fragment() {
	vec2 uv = UV - 0.5;
	float d = dot(uv, uv) * 4.0;
	COLOR = vec4(tint.rgb, tint.a * smoothstep(0.0, 1.0, d));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_damage_vignette = ColorRect.new()
	_damage_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_damage_vignette.material    = mat
	_damage_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_vignette.color        = Color(1, 1, 1, 0)
	add_child(_damage_vignette)

func _update_low_health_vignette(delta: float) -> void:
	if not _damage_vignette or not _player:
		return
	var hp_pct := 1.0
	if _player.health and "hp" in _player.health:
		hp_pct = clampf(_player.health.hp / 100.0, 0.0, 1.0)
	if hp_pct < 0.30:
		_low_health_t += delta * 2.2
		var pulse := (sin(_low_health_t) * 0.5 + 0.5) * (0.30 - hp_pct) / 0.30
		var mat := _damage_vignette.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("tint", Color(0.85, 0.05, 0.05, pulse * 0.55))
	else:
		_low_health_t = 0.0
		if _vignette_tween == null or not _vignette_tween.is_valid():
			var mat := _damage_vignette.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("tint", Color(0.85, 0.05, 0.05, 0.0))

func _flash_damage_vignette() -> void:
	if not _damage_vignette:
		return
	if _vignette_tween and _vignette_tween.is_valid():
		_vignette_tween.kill()
	var mat := _damage_vignette.material as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("tint", Color(0.85, 0.05, 0.05, 0.72))
	_vignette_tween = create_tween()
	_vignette_tween.tween_method(
		func(a: float): mat.set_shader_parameter("tint", Color(0.85, 0.05, 0.05, a)),
		0.72, 0.0, 0.5)

func _build_scope_overlay() -> void:
	var scope := ColorRect.new()
	scope.name = "ScopeOverlay"
	scope.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scope.visible = false
	var shader := Shader.new()
	shader.code = \
"""shader_type canvas_item;
uniform float aspect : hint_range(0.5, 3.0) = 1.778;

void fragment() {
    vec2 uv  = UV - 0.5;
    uv.x    *= aspect;
    float d  = length(uv);
    float r  = 0.30;
    float outside  = smoothstep(r - 0.006, r + 0.006, d);
    float vignette = smoothstep(0.0, r, d) * 0.20 * (1.0 - outside);
    vec2 uvr = UV - 0.5;
    float gap = 0.036;
    float h = step(abs(uvr.y), 0.0009) * step(gap, abs(uvr.x)) * (1.0 - outside);
    float v = step(abs(uvr.x), 0.0009 / aspect) * step(gap, abs(uvr.y)) * (1.0 - outside);
    float ch = clamp(h + v, 0.0, 1.0);
    COLOR = vec4(0.0, 0.72, 0.22, outside + ch * 0.90 + vignette);
}"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	scope.material = mat
	add_child(scope)
	_scope_overlay = scope

func show_objective_message(text: String, duration: float = 3.0) -> void:
	var label := Label.new()
	label.text = text.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.7, 1.0))
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	label.position = Vector2(get_viewport().size.x * 0.5 - 200.0, 190.0)
	var tween := create_tween()
	tween.tween_interval(duration)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
