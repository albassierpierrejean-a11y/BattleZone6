extends CanvasLayer
class_name AfterMatch

const C_ACCENT := Color(0.831, 0.525, 0.102, 1.0)
const C_WHITE  := Color(0.941, 0.925, 0.894, 1.0)
const C_GREEN  := Color(0.561, 0.659, 0.541, 1.0)
const C_DIM    := Color(0.290, 0.322, 0.282, 1.0)
const C_INK    := Color(0.039, 0.047, 0.035, 1.0)
const C_RED    := Color(0.753, 0.220, 0.169, 1.0)

var _root: Control
var _xp_bar_bg: ColorRect
var _xp_bar_prev: ColorRect
var _xp_bar_gain: ColorRect

func _ready() -> void:
	layer   = 10
	visible = false

func show_result(won: bool, map_name: String, mode_name: String,
		breakdown: Dictionary, prev_xp_pct: float, new_xp_pct: bool) -> void:
	visible = true
	_build_ui(won, map_name, mode_name, breakdown)

func _build_ui(won: bool, map_name: String, mode_name: String, breakdown: Dictionary) -> void:
	# Clear previous
	for c in get_children():
		c.queue_free()

	# Dark overlay
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color       = Color(0.020, 0.023, 0.018, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Orange top line
	var top_line := ColorRect.new()
	top_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_bottom = 2.0
	top_line.color = C_ACCENT
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_line)

	# Center content column
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var col := VBoxContainer.new()
	col.anchor_left   = 0.5
	col.anchor_right  = 0.5
	col.anchor_top    = 0.5
	col.anchor_bottom = 0.5
	col.offset_left   = -240.0
	col.offset_right  =  240.0
	col.offset_top    = -340.0
	col.offset_bottom =  340.0
	col.add_theme_constant_override("separation", 0)
	_root.add_child(col)

	# Result title
	var result_lbl := Label.new()
	result_lbl.text = "VICTOIRE" if won else "DÉFAITE"
	result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_lbl.add_theme_font_size_override("font_size", 52)
	result_lbl.add_theme_color_override("font_color", C_ACCENT if won else C_RED)
	col.add_child(result_lbl)

	# Map + mode subtitle
	var sub := Label.new()
	sub.text = "%s  ·  %s" % [map_name.to_upper(), mode_name.to_upper()]
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 9)
	sub.add_theme_color_override("font_color", C_DIM)
	col.add_child(sub)

	_add_spacer(col, 28)

	# Level up block
	var pm := get_node_or_null("/root/ProgressionManager")
	if pm:
		var lv_container := _make_level_block(pm)
		col.add_child(lv_container)
		_add_spacer(col, 20)

	# XP breakdown
	var total_xp := 0
	for k in breakdown.keys():
		total_xp += breakdown[k]
		col.add_child(_make_xp_row(k, "+ %d XP" % breakdown[k], false))
	col.add_child(_make_divider())
	col.add_child(_make_xp_row("XP TOTAL GAGNÉ", "+ %d XP" % total_xp, true))
	_add_spacer(col, 16)

	# XP bar
	if pm:
		col.add_child(_make_xp_bar(pm))
		_add_spacer(col, 24)

	# Continue button
	var btn := Button.new()
	btn.text = "CONTINUER →"
	btn.custom_minimum_size = Vector2(480, 52)
	var s_n := StyleBoxFlat.new()
	s_n.bg_color = C_WHITE
	var s_h := StyleBoxFlat.new()
	s_h.bg_color = C_ACCENT
	s_h.content_margin_left   = 16.0
	s_h.content_margin_right  = 16.0
	s_h.content_margin_top    = 6.0
	s_h.content_margin_bottom = 6.0
	s_n.content_margin_left   = 16.0
	s_n.content_margin_right  = 16.0
	s_n.content_margin_top    = 6.0
	s_n.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal",  s_n)
	btn.add_theme_stylebox_override("hover",   s_h)
	btn.add_theme_stylebox_override("pressed", s_h)
	btn.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color",       C_INK)
	btn.add_theme_color_override("font_hover_color", C_WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	btn.pressed.connect(_on_continue)
	col.add_child(btn)

	# Entrance animation
	_root.modulate.a    = 0.0
	_root.position.y    = 24.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "position:y", 0.0, 0.38).set_ease(Tween.EASE_OUT)

	# Animate XP bar after short delay
	if _xp_bar_prev and _xp_bar_gain:
		_animate_xp_bar()

func _make_level_block(pm: Node) -> Control:
	var box := VBoxContainer.new()
	box.theme_override_constants__separation = 3
	var s := StyleBoxFlat.new()
	s.bg_color = Color(C_ACCENT, 0.06)
	s.border_width_left   = 1; s.border_width_right  = 1
	s.border_width_top    = 1; s.border_width_bottom = 1
	s.border_color = Color(C_ACCENT, 0.35)
	s.content_margin_left   = 24.0; s.content_margin_right  = 24.0
	s.content_margin_top    = 14.0; s.content_margin_bottom = 14.0
	var inner := Panel.new()
	inner.custom_minimum_size = Vector2(480, 0)
	inner.add_theme_stylebox_override("panel", s)
	var inner_col := VBoxContainer.new()
	inner_col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_col.theme_override_constants__separation = 3
	var lbl_tag := Label.new()
	lbl_tag.text = "NIVEAU ATTEINT"
	lbl_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_tag.add_theme_font_size_override("font_size", 8)
	lbl_tag.add_theme_color_override("font_color", C_GREEN)
	inner_col.add_child(lbl_tag)
	var lbl_lvl := Label.new()
	lbl_lvl.text = str(pm.level)
	lbl_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lvl.add_theme_font_size_override("font_size", 52)
	lbl_lvl.add_theme_color_override("font_color", C_ACCENT)
	inner_col.add_child(lbl_lvl)
	var lbl_rank := Label.new()
	lbl_rank.text = pm.get_rank_title()
	lbl_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_rank.add_theme_font_size_override("font_size", 10)
	lbl_rank.add_theme_color_override("font_color", C_WHITE)
	inner_col.add_child(lbl_rank)
	inner.add_child(inner_col)
	box.add_child(inner)
	return box

func _make_xp_row(label: String, value: String, total: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(480, 0)
	var lbl := Label.new()
	lbl.text = label
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 13 if not total else 11)
	lbl.add_theme_color_override("font_color", C_WHITE if not total else C_WHITE)
	var val := Label.new()
	val.text = value
	val.add_theme_font_size_override("font_size", 18 if total else 13)
	val.add_theme_color_override("font_color", C_ACCENT)
	row.add_child(lbl)
	row.add_child(val)
	if total:
		var s := StyleBoxFlat.new()
		s.border_width_top = 1
		s.border_color = Color(C_ACCENT, 0.2)
		s.content_margin_top    = 10.0
		s.content_margin_bottom = 10.0
	return row

func _make_divider() -> ColorRect:
	var d := ColorRect.new()
	d.custom_minimum_size = Vector2(0, 1)
	d.color = Color(C_ACCENT, 0.18)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return d

func _make_xp_bar(pm: Node) -> VBoxContainer:
	var wrap := VBoxContainer.new()
	wrap.custom_minimum_size = Vector2(480, 0)
	wrap.theme_override_constants__separation = 4
	var labels := HBoxContainer.new()
	var l1 := Label.new()
	l1.text = "NIV. %d" % (pm.level - 1)
	l1.add_theme_font_size_override("font_size", 8)
	l1.add_theme_color_override("font_color", C_DIM)
	var l2 := Label.new()
	l2.text = "NIV. %d" % pm.level
	l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l2.add_theme_font_size_override("font_size", 8)
	l2.add_theme_color_override("font_color", C_DIM)
	labels.add_child(l1)
	labels.add_child(l2)
	wrap.add_child(labels)
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(480, 6)
	track.color = Color(C_GREEN, 0.08)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(track)
	_xp_bar_bg = track
	_xp_bar_prev = ColorRect.new()
	_xp_bar_prev.color         = Color(C_ACCENT, 0.3)
	_xp_bar_prev.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_xp_bar_prev.custom_minimum_size = Vector2(0, 6)
	track.add_child(_xp_bar_prev)
	_xp_bar_gain = ColorRect.new()
	_xp_bar_gain.color         = C_ACCENT
	_xp_bar_gain.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_xp_bar_gain.custom_minimum_size = Vector2(0, 6)
	track.add_child(_xp_bar_gain)
	return wrap

func _animate_xp_bar() -> void:
	var pm := get_node_or_null("/root/ProgressionManager")
	if not pm: return
	await get_tree().create_timer(0.5).timeout
	var track_w := 480.0
	var prev_pct := maxf(0.0, pm.get_xp_progress() - 0.25)
	var gain_pct := pm.get_xp_progress()
	_xp_bar_prev.size = Vector2(0.0, 6.0)
	_xp_bar_gain.size = Vector2(0.0, 6.0)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_xp_bar_prev, "size:x", track_w * prev_pct, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(_xp_bar_gain, "size:x", track_w * gain_pct, 1.0).set_delay(0.15).set_ease(Tween.EASE_OUT)

func _add_spacer(parent: Control, h: float) -> void:
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, h)
	parent.add_child(sp)

func _on_continue() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(func():
		visible = false
		get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
	)
