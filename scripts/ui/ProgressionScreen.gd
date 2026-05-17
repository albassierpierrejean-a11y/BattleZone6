extends CanvasLayer
class_name ProgressionScreen

# ── Palette ──────────────────────────────────────────────────────────────────
const C_BG      := Color(0.016, 0.020, 0.014, 1.0)
const C_SURFACE := Color(0.028, 0.034, 0.024, 0.97)
const C_ACCENT  := Color(0.831, 0.525, 0.102, 1.0)
const C_WHITE   := Color(0.941, 0.925, 0.894, 1.0)
const C_DIM     := Color(0.290, 0.322, 0.282, 1.0)
const C_GREEN   := Color(0.455, 0.655, 0.390, 1.0)
const C_BORDER  := Color(0.561, 0.659, 0.541, 0.09)
const C_DONE    := Color(0.455, 0.655, 0.390, 0.85)

# ── Refs ─────────────────────────────────────────────────────────────────────
var _root:    Control
var _xp_fill: ColorRect
var _rank_lbl:Label
var _level_lbl:Label
var _xp_lbl:  Label
var _stat_vals:   Dictionary = {}
var _rank_rows:   Array      = []
var _next_rank_lbl: Label
var _xp_need_lbl:   Label

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 6
	_build_ui()
	_populate()
	_animate_in()

# ── UI BUILD ─────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scan := ColorRect.new()
	scan.color = Color(1, 1, 1, 1)
	scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan.material = _scanline_material()
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_build_header()

	var body := HBoxContainer.new()
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_top    = 72.0
	body.offset_left   = 0.0
	body.offset_right  = 0.0
	body.offset_bottom = 0.0
	body.add_theme_constant_override("separation", 0)
	_root.add_child(body)

	var left := _build_left_panel()
	left.custom_minimum_size.x = 400.0
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(left)

	var sep := ColorRect.new()
	sep.custom_minimum_size.x = 1.0
	sep.color = Color(0.12, 0.14, 0.10, 0.15)
	sep.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sep)

	var right := _build_right_panel()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)

# ── Header ────────────────────────────────────────────────────────────────────
func _build_header() -> void:
	var header := PanelContainer.new()
	header.set_anchors_preset(Control.PRESET_TOP_WIDE)
	header.offset_bottom = 72.0
	var h_sbox := StyleBoxFlat.new()
	h_sbox.bg_color = Color(C_SURFACE.r, C_SURFACE.g, C_SURFACE.b, 0.98)
	h_sbox.border_width_bottom = 1
	h_sbox.border_color = Color(C_ACCENT, 0.18)
	header.add_theme_stylebox_override("panel", h_sbox)
	_root.add_child(header)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 0)
	header.add_child(hrow)

	var back_btn := Button.new()
	back_btn.text = "← RETOUR"
	back_btn.custom_minimum_size = Vector2(160, 72)
	back_btn.add_theme_font_size_override("font_size", 13)
	_style_back_btn(back_btn)
	back_btn.pressed.connect(_on_back)
	hrow.add_child(back_btn)

	var accent_bar := ColorRect.new()
	accent_bar.color = C_ACCENT
	accent_bar.custom_minimum_size = Vector2(3, 0)
	accent_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hrow.add_child(accent_bar)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(m)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	m.add_child(col)

	var sup := _lbl("BATTLEZONE 6", 10, Color(C_ACCENT, 0.7))
	col.add_child(sup)
	var title := _lbl("PROGRESSION", 28, C_WHITE)
	col.add_child(title)

# ── Left panel ────────────────────────────────────────────────────────────────
func _build_left_panel() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = 4

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(vbox)

	# — Badge card
	var badge_vbox := VBoxContainer.new()
	badge_vbox.add_theme_constant_override("separation", 10)
	badge_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_add_card(vbox, badge_vbox, Vector2(0, 200))

	var hex_wrap := CenterContainer.new()
	var hex := _build_hex_badge()
	hex_wrap.add_child(hex)
	badge_vbox.add_child(hex_wrap)

	_rank_lbl = _lbl("RECRUE", 22, C_ACCENT)
	_rank_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_vbox.add_child(_rank_lbl)

	_level_lbl = _lbl("NIVEAU 1", 13, Color(C_WHITE, 0.5))
	_level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_vbox.add_child(_level_lbl)

	# XP bar
	var xp_vbox := VBoxContainer.new()
	xp_vbox.add_theme_constant_override("separation", 6)
	xp_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_vbox.add_child(xp_vbox)

	var xp_hdr := HBoxContainer.new()
	xp_vbox.add_child(xp_hdr)
	var xp_title := _lbl("EXPÉRIENCE", 9, Color(C_DIM, 0.8))
	xp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_hdr.add_child(xp_title)
	_xp_lbl = _lbl("0 / 5000", 9, Color(C_ACCENT, 0.9))
	xp_hdr.add_child(_xp_lbl)

	var bar_wrap := Control.new()
	bar_wrap.custom_minimum_size = Vector2(0, 6)
	bar_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	xp_vbox.add_child(bar_wrap)

	var bar_bg := ColorRect.new()
	bar_bg.color = Color(C_ACCENT, 0.12)
	bar_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_wrap.add_child(bar_bg)

	_xp_fill = ColorRect.new()
	_xp_fill.color = C_ACCENT
	_xp_fill.anchor_top    = 0.0
	_xp_fill.anchor_bottom = 1.0
	_xp_fill.anchor_left   = 0.0
	_xp_fill.anchor_right  = 0.0
	_xp_fill.offset_left   = 0.0
	_xp_fill.offset_right  = 0.0
	_xp_fill.offset_top    = 0.0
	_xp_fill.offset_bottom = 0.0
	bar_wrap.add_child(_xp_fill)

	# — Stats card
	var stats_vbox := VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 0)
	var stats_outer := _add_card(vbox, stats_vbox, Vector2(0, 0))
	stats_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	stats_vbox.add_child(_section_title("STATISTIQUES"))

	var stat_grid := GridContainer.new()
	stat_grid.columns = 2
	stat_grid.add_theme_constant_override("h_separation", 0)
	stat_grid.add_theme_constant_override("v_separation", 0)
	stats_vbox.add_child(stat_grid)

	var stat_defs := [
		["ÉLIMINATIONS", "kills",   C_ACCENT],
		["MORTS",        "deaths",  Color(C_DIM, 0.9)],
		["RATIO K/D",    "kd",      C_WHITE],
		["VICTOIRES",    "wins",    C_GREEN],
		["PARTIES",      "games",   Color(C_WHITE, 0.7)],
		["TAUX VICTOIRE","winrate", C_GREEN],
		["XP TOTAL",     "xp_total",Color(C_ACCENT, 0.85)],
	]
	for sd in stat_defs:
		var pair := _stat_row(sd[0], sd[1], sd[2])
		stat_grid.add_child(pair[0])
		stat_grid.add_child(pair[1])

	return scroll

# ── Right panel ────────────────────────────────────────────────────────────────
func _build_right_panel() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.get_v_scroll_bar().custom_minimum_size.x = 4

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 0)
	scroll.add_child(vbox)

	# — Rank ladder card
	var ladder_vbox := VBoxContainer.new()
	ladder_vbox.add_theme_constant_override("separation", 0)
	var ladder_outer := _add_card(vbox, ladder_vbox, Vector2(0, 0))
	ladder_outer.size_flags_vertical = Control.SIZE_EXPAND_FILL

	ladder_vbox.add_child(_section_title("PARCOURS DE GRADE"))

	var ladder_grid := GridContainer.new()
	ladder_grid.columns = 2
	ladder_grid.add_theme_constant_override("h_separation", 0)
	ladder_grid.add_theme_constant_override("v_separation", 0)
	ladder_vbox.add_child(ladder_grid)

	for i in ProgressionManager.RANKS.size():
		var rd := _rank_row(i, ProgressionManager.RANKS[i], i + 1)
		_rank_rows.append(rd)
		ladder_grid.add_child(rd.left)
		ladder_grid.add_child(rd.right)

	# — Next milestone card
	var m_vbox := VBoxContainer.new()
	m_vbox.add_theme_constant_override("separation", 8)
	_add_card(vbox, m_vbox, Vector2(0, 0))

	m_vbox.add_child(_section_title("PROCHAIN GRADE"))

	var next_row := HBoxContainer.new()
	next_row.add_theme_constant_override("separation", 20)
	m_vbox.add_child(next_row)

	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 4)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_row.add_child(name_col)
	name_col.add_child(_lbl("PROCHAIN GRADE", 9, Color(C_DIM, 0.7)))
	_next_rank_lbl = _lbl("—", 18, C_WHITE)
	name_col.add_child(_next_rank_lbl)

	var xp_col := VBoxContainer.new()
	xp_col.add_theme_constant_override("separation", 4)
	next_row.add_child(xp_col)
	xp_col.add_child(_lbl("XP REQUISE", 9, Color(C_DIM, 0.7)))
	_xp_need_lbl = _lbl("—", 18, Color(C_ACCENT, 0.9))
	xp_col.add_child(_xp_need_lbl)

	return scroll

# ── Rank row ──────────────────────────────────────────────────────────────────
func _rank_row(idx: int, rank_name: String, lvl_req: int) -> Dictionary:
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(72, 0)
	left.add_theme_constant_override("separation", 0)

	var badge_wrap := CenterContainer.new()
	badge_wrap.custom_minimum_size = Vector2(72, 54)
	var badge := Label.new()
	badge.text = "◆" if idx == 0 else "◇"
	badge.add_theme_font_size_override("font_size", 18)
	badge.add_theme_color_override("font_color", Color(C_DIM, 0.35))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_wrap.add_child(badge)
	left.add_child(badge_wrap)

	if idx < ProgressionManager.RANKS.size() - 1:
		var line := ColorRect.new()
		line.color = Color(C_DIM, 0.15)
		line.custom_minimum_size = Vector2(2, 0)
		line.size_flags_vertical = Control.SIZE_EXPAND_FILL
		line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		left.add_child(line)

	var right := MarginContainer.new()
	right.add_theme_constant_override("margin_left",   12)
	right.add_theme_constant_override("margin_right",  24)
	right.add_theme_constant_override("margin_top",    0)
	right.add_theme_constant_override("margin_bottom", 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner_vbox := VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 2)
	right.add_child(inner_vbox)

	var row_panel := PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 54)
	var row_sbox := StyleBoxFlat.new()
	row_sbox.bg_color = Color(0, 0, 0, 0)
	row_panel.add_theme_stylebox_override("panel", row_sbox)
	inner_vbox.add_child(row_panel)

	var text_col := VBoxContainer.new()
	text_col.add_theme_constant_override("separation", 3)
	row_panel.add_child(text_col)

	var name_lbl := _lbl(rank_name, 15, Color(C_WHITE, 0.35))
	text_col.add_child(name_lbl)
	var req_lbl := _lbl("NIV. %d" % lvl_req, 10, Color(C_DIM, 0.40))
	text_col.add_child(req_lbl)

	return { "left": left, "right": right, "badge": badge,
			 "name_lbl": name_lbl, "req_lbl": req_lbl, "row_panel": row_panel }

# ── Populate ──────────────────────────────────────────────────────────────────
func _populate() -> void:
	var pm        := ProgressionManager
	var cur_lvl   := pm.level
	var cur_xp    := pm.xp
	var cur_rank  := mini(cur_lvl - 1, pm.RANKS.size() - 1)

	_rank_lbl.text  = pm.get_rank_title()
	_level_lbl.text = "NIVEAU %d" % cur_lvl

	var xp_prev  := pm.get_xp_for_level(cur_lvl - 1) if cur_lvl > 1 else 0
	var xp_next  := pm.get_xp_for_level(cur_lvl)
	_xp_lbl.text = "%d / %d XP" % [cur_xp - xp_prev, xp_next - xp_prev]

	var progress := pm.get_xp_progress()
	_xp_fill.anchor_right = clampf(progress, 0.0, 1.0)

	var kd  := "%.2f" % (float(pm.kills) / maxf(float(pm.deaths), 1.0))
	var wr  := "%d%%" % int(float(pm.wins) / maxf(float(pm.games), 1.0) * 100.0)
	_set_stat("kills",    str(pm.kills))
	_set_stat("deaths",   str(pm.deaths))
	_set_stat("kd",       kd)
	_set_stat("wins",     str(pm.wins))
	_set_stat("games",    str(pm.games))
	_set_stat("winrate",  wr)
	_set_stat("xp_total", _fmt_xp(cur_xp))

	for i in _rank_rows.size():
		var rd: Dictionary = _rank_rows[i]
		var is_done    := i < cur_rank
		var is_current := i == cur_rank
		if is_done:
			rd.badge.text = "◆"
			rd.badge.add_theme_color_override("font_color", C_DONE)
			rd.name_lbl.add_theme_color_override("font_color", Color(C_WHITE, 0.55))
			rd.req_lbl.add_theme_color_override("font_color",  Color(C_GREEN, 0.55))
		elif is_current:
			rd.badge.text = "◆"
			rd.badge.add_theme_font_size_override("font_size", 22)
			rd.badge.add_theme_color_override("font_color", C_ACCENT)
			rd.name_lbl.add_theme_font_size_override("font_size", 17)
			rd.name_lbl.add_theme_color_override("font_color", C_ACCENT)
			rd.req_lbl.add_theme_color_override("font_color", Color(C_ACCENT, 0.6))
			var cur_sbox := StyleBoxFlat.new()
			cur_sbox.bg_color          = Color(C_ACCENT, 0.06)
			cur_sbox.border_width_left = 3
			cur_sbox.border_color      = C_ACCENT
			cur_sbox.content_margin_left   = 12
			cur_sbox.content_margin_top    = 8
			cur_sbox.content_margin_bottom = 8
			rd.row_panel.add_theme_stylebox_override("panel", cur_sbox)

	var next_idx := cur_rank + 1
	if next_idx < pm.RANKS.size():
		_next_rank_lbl.text = pm.RANKS[next_idx]
		var needed := pm.get_xp_for_level(next_idx + 1) - cur_xp
		_xp_need_lbl.text = "%s XP" % _fmt_xp(maxi(needed, 0))
	else:
		_next_rank_lbl.text = "GRADE MAX"
		_xp_need_lbl.text   = "—"

# ── Animate ────────────────────────────────────────────────────────────────────
func _animate_in() -> void:
	_root.modulate.a = 0.0
	_root.position.y = 18.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "position:y", 0.0, 0.35).set_ease(Tween.EASE_OUT)

	var target_w := clampf(ProgressionManager.get_xp_progress(), 0.0, 1.0)
	_xp_fill.anchor_right = 0.0
	var fill_tw := create_tween()
	fill_tw.tween_interval(0.5)
	fill_tw.tween_property(_xp_fill, "anchor_right", target_w, 0.8)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)

	for i in _rank_rows.size():
		var rd: Dictionary = _rank_rows[i]
		rd.left.modulate.a  = 0.0
		rd.right.modulate.a = 0.0
		var t := 0.15 + i * 0.04
		create_tween().tween_property(rd.left,  "modulate:a", 1.0, 0.3).set_delay(t)
		create_tween().tween_property(rd.right, "modulate:a", 1.0, 0.3).set_delay(t)

# ── Helpers ───────────────────────────────────────────────────────────────────

# Builds a styled card, adds it to parent, returns the inner VBox.
# Also returns the outer MarginContainer via its parent chain if needed.
func _add_card(parent: VBoxContainer, content: Control, min_size: Vector2) -> MarginContainer:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   20)
	outer.add_theme_constant_override("margin_right",  20)
	outer.add_theme_constant_override("margin_top",    16)
	outer.add_theme_constant_override("margin_bottom", 4)
	outer.custom_minimum_size = min_size
	parent.add_child(outer)

	var panel := PanelContainer.new()
	panel.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sbox := StyleBoxFlat.new()
	sbox.bg_color            = C_SURFACE
	sbox.border_width_left   = 1
	sbox.border_width_right  = 1
	sbox.border_width_top    = 1
	sbox.border_width_bottom = 1
	sbox.border_color        = C_BORDER
	panel.add_theme_stylebox_override("panel", sbox)
	outer.add_child(panel)

	var inner_m := MarginContainer.new()
	inner_m.add_theme_constant_override("margin_left",   20)
	inner_m.add_theme_constant_override("margin_right",  20)
	inner_m.add_theme_constant_override("margin_top",    16)
	inner_m.add_theme_constant_override("margin_bottom", 16)
	inner_m.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	inner_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(inner_m)
	inner_m.add_child(content)

	return outer

func _section_title(text: String) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_bottom", 12)
	mc.add_theme_constant_override("margin_top",    4)
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	mc.add_child(hbox)
	var bar := ColorRect.new()
	bar.color = C_ACCENT
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(bar)
	hbox.add_child(_lbl(text, 10, Color(C_ACCENT, 0.7)))
	return mc

func _stat_row(label_text: String, key: String, col: Color) -> Array:
	var sep_sbox := StyleBoxFlat.new()
	sep_sbox.bg_color = Color(0, 0, 0, 0)
	sep_sbox.border_width_bottom = 1
	sep_sbox.border_color = Color(0.12, 0.14, 0.10, 0.06)

	var lbl_mc := MarginContainer.new()
	lbl_mc.custom_minimum_size = Vector2(0, 40)
	var lbl_panel := PanelContainer.new()
	lbl_panel.add_theme_stylebox_override("panel", sep_sbox.duplicate())
	lbl_mc.add_child(lbl_panel)
	lbl_panel.add_child(_lbl(label_text, 10, Color(C_DIM, 0.75)))

	var val_mc := MarginContainer.new()
	val_mc.custom_minimum_size = Vector2(0, 40)
	var val_panel := PanelContainer.new()
	val_panel.add_theme_stylebox_override("panel", sep_sbox.duplicate())
	val_mc.add_child(val_panel)
	var val_lbl := _lbl("—", 16, col)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_panel.add_child(val_lbl)
	_stat_vals[key] = val_lbl

	return [lbl_mc, val_mc]

func _set_stat(key: String, val: String) -> void:
	if _stat_vals.has(key):
		_stat_vals[key].text = val

func _fmt_xp(n: int) -> String:
	if n >= 1000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)

func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _build_hex_badge() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(96, 96)
	var lbl := Label.new()
	lbl.text = "★"
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", C_ACCENT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	c.add_child(lbl)
	return c

func _scanline_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh  := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat line = mod(FRAGCOORD.y, 4.0);\n\tfloat alpha = (line < 1.0) ? 0.018 : 0.0;\n\tCOLOR = vec4(0.0, 0.0, 0.0, alpha);\n}\n"
	mat.shader = sh
	return mat

func _style_back_btn(btn: Button) -> void:
	var no_focus := StyleBoxEmpty.new()
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.content_margin_left  = 24.0
	n.content_margin_right = 24.0
	var h := StyleBoxFlat.new()
	h.bg_color = Color(C_ACCENT, 0.07)
	h.border_width_right = 1
	h.border_color = Color(C_ACCENT, 0.25)
	h.content_margin_left  = 24.0
	h.content_margin_right = 24.0
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   no_focus)
	btn.add_theme_color_override("font_color",         Color(C_WHITE, 0.5))
	btn.add_theme_color_override("font_hover_color",   C_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_WHITE)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
