extends CanvasLayer
class_name LoadoutScreen

# ── Palette ──────────────────────────────────────────────────────────────────
const C_BG     := Color(0.016, 0.020, 0.014, 0.97)
const C_ACCENT := Color(0.831, 0.525, 0.102, 1.0)
const C_WHITE  := Color(0.941, 0.925, 0.894, 1.0)
const C_DIM    := Color(0.290, 0.322, 0.282, 1.0)
const C_INK    := Color(0.039, 0.047, 0.035, 1.0)
const C_RED    := Color(0.753, 0.220, 0.169, 1.0)
const C_GREEN  := Color(0.455, 0.655, 0.390, 1.0)
const C_BLUE   := Color(0.310, 0.565, 0.780, 1.0)
const C_BORDER := Color(0.120, 0.140, 0.100, 1.0)

const C_ASSAULT := Color(0.831, 0.525, 0.102, 1.0)
const C_RECON   := Color(0.310, 0.565, 0.780, 1.0)
const C_SUPPORT := Color(0.455, 0.655, 0.390, 1.0)

const FACTION_COL: Dictionary = { 0: C_ASSAULT, 1: C_RECON,   2: C_SUPPORT }
const FACTION_LBL: Dictionary = { 0: "ASSAULT",  1: "RECON",   2: "SUPPORT" }

const SLOT_LBL := ["OPTIQUE", "CANON", "SOUS-CANON", "CHARGEUR", "CROSSE"]

const WTYPE_LBL: Dictionary = {
	0: "FUSIL D'ASSAUT", 1: "SMG",      2: "MITRAILLEUSE",
	3: "SNIPER",         4: "SHOTGUN",  5: "DMR",
	6: "PISTOLET",       7: "REVOLVER", 8: "LANCE-ROQUETTES"
}
const WTYPE_COL: Dictionary = {
	0: Color(0.831, 0.525, 0.102),  # AR  → orange
	1: Color(0.310, 0.565, 0.780),  # SMG → bleu
	2: Color(0.680, 0.300, 0.280),  # LMG → rouge
	3: Color(0.455, 0.655, 0.390),  # SNI → vert
	4: Color(0.680, 0.540, 0.280),  # SHO → or
	5: Color(0.455, 0.655, 0.390),  # DMR → vert
	6: Color(0.550, 0.550, 0.550),  # PI  → gris
	7: Color(0.750, 0.400, 0.300),  # REV → brique
	8: Color(0.753, 0.220, 0.169),  # RPG → rouge vif
}

const ITEM_TYPE_LBL: Dictionary = { 0: "LÉTHAL", 1: "TACTIQUE", 2: "SUPPORT", 3: "KILLSTREAK" }
const ITEM_TYPE_COL: Dictionary = {
	0: Color(0.753, 0.220, 0.169),
	1: Color(0.310, 0.565, 0.780),
	2: Color(0.455, 0.655, 0.390),
	3: Color(0.831, 0.525, 0.102),
}

# ── State ────────────────────────────────────────────────────────────────────
var _cur_tab: int = 0
var _tab_btns: Array = []
var _tab_panels: Array = []
var _root: Control
var _picker: Control

# Onglet opérateur
var _sel_op: String = ""
var _faction_f: int = -1
var _op_panels: Dictionary = {}
var _op_cards: Dictionary  = {}
var _faction_btns: Array   = []
var _detail_col: Control   = null

# Onglet armes
var _sel_weapon: String    = "assault_rifle"
var _wpn_cards: Dictionary = {}
var _wpn_panels: Dictionary = {}
var _slot_btns: Array      = []
var _wpn_detail_col: Control = null
var _stat_fills: Dictionary  = {}   # stat_key -> ColorRect

# ── Init ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer    = 5
	_sel_op  = LoadoutManager.operator_id
	_sel_weapon = LoadoutManager.primary_id
	_build_ui()

func _build_ui() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var top_line := ColorRect.new()
	top_line.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_line.offset_bottom = 2.0
	top_line.color = C_ACCENT
	top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_line)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	_root.add_child(vb)

	vb.add_child(_build_header())
	vb.add_child(_hsep(C_BORDER, 1.0))
	vb.add_child(_build_tab_bar())
	vb.add_child(_hsep(C_BORDER, 1.0))

	# Zone contenu
	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(content)

	_tab_panels.clear()
	for builder in [_build_operator_tab, _build_weapons_tab, _build_equipment_tab]:
		var panel: Control = builder.call()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		content.add_child(panel)
		_tab_panels.append(panel)

	# Picker overlay partagé
	_picker = Control.new()
	_picker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker.visible = false
	_picker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_picker)

	_show_tab(0)

	_root.modulate.a = 0.0
	_root.position.y = 20.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.32).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "position:y", 0.0, 0.28).set_ease(Tween.EASE_OUT)

# ══════════════════════════════════════════════════════════════════════════════
# HEADER
# ══════════════════════════════════════════════════════════════════════════════
func _build_header() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 62)
	hb.add_theme_constant_override("separation", 0)

	var pad_l := Control.new()
	pad_l.custom_minimum_size = Vector2(28, 0)
	hb.add_child(pad_l)

	var title := _lbl("PRÉPARATION AU DÉPLOIEMENT", 16, Color(C_DIM, 0.70))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(title)

	var btn_back := _make_btn("← RETOUR", 13, C_DIM, Color(C_WHITE, 0.06), func(): _on_back())
	btn_back.custom_minimum_size = Vector2(130, 40)
	hb.add_child(btn_back)
	hb.add_child(_sp_h(8))

	var btn_conf := _make_btn("CONFIRMER →", 13, C_INK, C_ACCENT, func(): _on_confirm())
	btn_conf.custom_minimum_size = Vector2(150, 40)
	hb.add_child(btn_conf)
	hb.add_child(_sp_h(16))

	return hb

# ══════════════════════════════════════════════════════════════════════════════
# BARRE D'ONGLETS
# ══════════════════════════════════════════════════════════════════════════════
func _build_tab_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 44)
	hb.add_theme_constant_override("separation", 0)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(20, 0)
	hb.add_child(pad)

	_tab_btns.clear()
	var labels := ["OPÉRATEUR", "ARMES", "ÉQUIPEMENT"]
	for i in labels.size():
		var idx := i
		var btn := Button.new()
		btn.text = labels[i]
		btn.custom_minimum_size = Vector2(150, 44)
		btn.add_theme_font_size_override("font_size", 12)
		for st in ["focus"]:
			btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		btn.pressed.connect(func(): _show_tab(idx))
		_tab_btns.append(btn)
		hb.add_child(btn)

	_style_tab_btns()
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	return hb

func _show_tab(idx: int) -> void:
	_cur_tab = idx
	for i in _tab_panels.size():
		_tab_panels[i].visible = (i == idx)
	_style_tab_btns()
	if idx == 1:
		_refresh_weapon_detail()
	elif idx == 2:
		_refresh_equip_tab()

func _style_tab_btns() -> void:
	for i in _tab_btns.size():
		var btn: Button = _tab_btns[i]
		var active := (i == _cur_tab)
		var sn := StyleBoxFlat.new()
		sn.bg_color = Color(C_ACCENT, 0.08) if active else Color(0, 0, 0, 0)
		sn.border_width_bottom = 2 if active else 0
		sn.border_color = C_ACCENT
		var sh := StyleBoxFlat.new()
		sh.bg_color = Color(C_WHITE, 0.04)
		btn.add_theme_stylebox_override("normal",  sn)
		btn.add_theme_stylebox_override("hover",   sh)
		btn.add_theme_stylebox_override("pressed", sn)
		btn.add_theme_color_override("font_color",
			C_ACCENT if active else Color(C_DIM, 0.75))
		btn.add_theme_color_override("font_hover_color", C_WHITE)

# ══════════════════════════════════════════════════════════════════════════════
# ONGLET OPÉRATEUR
# ══════════════════════════════════════════════════════════════════════════════
func _build_operator_tab() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.add_child(_build_op_left_col())
	hb.add_child(_vsep())
	_detail_col = _build_op_center_col()
	hb.add_child(_detail_col)
	hb.add_child(_vsep())
	hb.add_child(_build_op_right_col())
	return hb

# ── Colonne gauche : cartes opérateurs ───────────────────────────────────────
func _build_op_left_col() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.add_theme_stylebox_override("panel", _sbox_bg(Color(C_WHITE, 0.012)))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)

	# Padding haut
	vb.add_child(_sp(14))

	# Filtres faction
	var frow := HBoxContainer.new()
	frow.add_theme_constant_override("separation", 6)
	var pad := Control.new(); pad.custom_minimum_size = Vector2(14, 0)
	frow.add_child(pad)

	_faction_btns.clear()
	var filters := [[-1, "TOUS"], [0, "ASSAULT"], [1, "RECON"], [2, "SUPPORT"]]
	for f in filters:
		var fid: int = f[0]
		var flbl: String = f[1]
		var btn := Button.new()
		btn.text = flbl
		btn.add_theme_font_size_override("font_size", 9)
		btn.custom_minimum_size = Vector2(70, 24)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_style_filter_btn(btn, fid == _faction_f)
		btn.pressed.connect(func(): _on_faction_filter(fid))
		_faction_btns.append({"btn": btn, "id": fid})
		frow.add_child(btn)
	vb.add_child(frow)
	vb.add_child(_sp(10))

	# Scroll
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var card_vb := VBoxContainer.new()
	card_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vb.add_theme_constant_override("separation", 6)
	scroll.add_child(card_vb)

	_op_panels.clear()
	_op_cards.clear()
	var pad2 := Control.new(); pad2.custom_minimum_size = Vector2(0, 0)
	card_vb.add_child(pad2)

	for op: OperatorData in LoadoutManager.operators.values():
		var op_id := op.id
		var locked: bool = op.unlock_level > ProgressionManager.level
		var selected: bool = (op_id == _sel_op)
		var f_col: Color = FACTION_COL.get(int(op.faction), C_ACCENT)

		var card := Panel.new()
		card.custom_minimum_size = Vector2(390, 68)
		card.add_theme_stylebox_override("panel", _card_sbox(selected, locked, f_col))
		_op_panels[op_id] = card
		_op_cards[op_id]  = card

		# Padding interne
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.add_theme_constant_override("separation", 3)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 8)
		name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var nml := _lbl(op.display_name, 14, C_ACCENT if selected else C_WHITE)
		nml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nml.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(nml)
		if locked:
			name_row.add_child(_lbl("NIV. %d" % op.unlock_level, 9, Color(C_RED, 0.75)))
		inner.add_child(name_row)

		var tag_row := HBoxContainer.new()
		tag_row.add_theme_constant_override("separation", 6)
		tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ftag := _lbl(FACTION_LBL.get(int(op.faction), ""), 8, Color(f_col, locked and 0.3 or 0.75))
		tag_row.add_child(ftag)
		var desc_short := _lbl(op.description.left(48) + ("…" if op.description.length() > 48 else ""), 8, Color(C_DIM, 0.60))
		desc_short.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_row.add_child(desc_short)
		inner.add_child(tag_row)
		card.add_child(inner)

		# Overlay cliquable
		var click := Button.new()
		click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		for st in ["normal", "hover", "pressed", "focus"]:
			click.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		click.mouse_filter = Control.MOUSE_FILTER_STOP
		click.disabled = locked
		click.pressed.connect(func(): _select_op(op_id))
		card.add_child(click)

		var row_pad := MarginContainer.new()
		row_pad.add_theme_constant_override("margin_left",  14)
		row_pad.add_theme_constant_override("margin_right", 14)
		row_pad.add_theme_constant_override("margin_top",    3)
		row_pad.add_theme_constant_override("margin_bottom", 3)
		row_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_pad.add_child(card)
		card_vb.add_child(row_pad)

		if _faction_f != -1 and int(op.faction) != _faction_f:
			row_pad.visible = false

	card_vb.add_child(_sp(14))
	return panel

# ── Colonne centre : détail opérateur ────────────────────────────────────────
func _build_op_center_col() -> Control:
	var col := Control.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_detail_into(col)
	return col

func _refresh_detail() -> void:
	if not _detail_col:
		return
	for c in _detail_col.get_children():
		c.queue_free()
	_refresh_detail_into(_detail_col)

func _refresh_detail_into(col: Control) -> void:
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	col.add_child(vb)
	vb.add_child(_sp(22))

	var op := LoadoutManager.operators.get(_sel_op) as OperatorData
	if not op:
		vb.add_child(_lbl("Sélectionnez un opérateur", 14, Color(C_DIM, 0.5)))
		return

	var f_col: Color = FACTION_COL.get(int(op.faction), C_ACCENT)

	# Faction tag + nom
	var ftag_row := HBoxContainer.new()
	ftag_row.add_theme_constant_override("separation", 10)
	ftag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad_l := Control.new(); pad_l.custom_minimum_size = Vector2(28, 0)
	ftag_row.add_child(pad_l)
	var faction_pill := Panel.new()
	faction_pill.custom_minimum_size = Vector2(0, 22)
	var psb := StyleBoxFlat.new()
	psb.bg_color = Color(f_col, 0.18)
	psb.border_width_left = 2; psb.border_color = Color(f_col, 0.8)
	psb.content_margin_left = 8.0; psb.content_margin_right = 8.0
	psb.content_margin_top = 2.0; psb.content_margin_bottom = 2.0
	faction_pill.add_theme_stylebox_override("panel", psb)
	var tag_lbl := _lbl(FACTION_LBL.get(int(op.faction), ""), 9, Color(f_col, 0.90))
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	faction_pill.add_child(tag_lbl)
	ftag_row.add_child(faction_pill)
	vb.add_child(ftag_row)
	vb.add_child(_sp(8))

	var nm_row := HBoxContainer.new()
	nm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm_row.add_child(Control.new())
	(nm_row.get_child(0) as Control).custom_minimum_size = Vector2(28, 0)
	var nm_lbl := _lbl(op.display_name, 36, C_WHITE)
	nm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm_row.add_child(nm_lbl)
	vb.add_child(nm_row)
	vb.add_child(_sp(6))

	var desc_row := HBoxContainer.new()
	desc_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd := Control.new(); pd.custom_minimum_size = Vector2(28, 0)
	desc_row.add_child(pd)
	var desc_lbl := _lbl(op.description, 11, Color(C_DIM, 0.80))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_row.add_child(desc_lbl)
	var pdr := Control.new(); pdr.custom_minimum_size = Vector2(20, 0)
	desc_row.add_child(pdr)
	vb.add_child(desc_row)
	vb.add_child(_sp(22))
	vb.add_child(_hsep_padded(C_BORDER, 1.0, 28))
	vb.add_child(_sp(18))

	# Stats rapides
	var stats_row := HBoxContainer.new()
	stats_row.add_theme_constant_override("separation", 0)
	stats_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd2 := Control.new(); pd2.custom_minimum_size = Vector2(28, 0)
	stats_row.add_child(pd2)
	for pair: Array in [["PV", str(op.max_health)], ["ARMURE", str(op.armor)], ["VITESSE", "×%.2f" % op.move_speed]]:
		stats_row.add_child(_stat_pill(str(pair[0]), str(pair[1]), f_col))
		stats_row.add_child(_sp_h(14))
	vb.add_child(stats_row)
	vb.add_child(_sp(22))
	vb.add_child(_hsep_padded(C_BORDER, 1.0, 28))
	vb.add_child(_sp(18))

	# Capacité
	var abil_row := HBoxContainer.new()
	abil_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd3 := Control.new(); pd3.custom_minimum_size = Vector2(28, 0)
	abil_row.add_child(pd3)
	var abil_col := VBoxContainer.new()
	abil_col.add_theme_constant_override("separation", 5)
	abil_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	abil_col.add_child(_lbl("CAPACITÉ SPÉCIALE", 9, Color(C_DIM, 0.70)))
	abil_col.add_child(_lbl(op.ability_name, 18, C_ACCENT))
	var abil_desc := _lbl(op.ability_description, 11, Color(C_WHITE, 0.75))
	abil_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	abil_desc.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	abil_col.add_child(abil_desc)
	abil_col.add_child(_lbl("Recharge : %.0f s" % op.ability_cooldown, 9, Color(C_DIM, 0.55)))
	abil_row.add_child(abil_col)
	vb.add_child(abil_row)

# ── Colonne droite : équipement ───────────────────────────────────────────────
func _build_op_right_col() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(340, 0)
	panel.add_theme_stylebox_override("panel", _sbox_bg(Color(C_WHITE, 0.012)))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)
	vb.add_child(_sp(20))

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd := Control.new(); pd.custom_minimum_size = Vector2(18, 0)
	row.add_child(pd)
	var sect := _section_lbl("ÉQUIPEMENT")
	sect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sect)
	vb.add_child(row)
	vb.add_child(_sp(14))

	# Léthal
	vb.add_child(_item_slot_btn(false))
	vb.add_child(_sp(8))
	# Tactique
	vb.add_child(_item_slot_btn(true))
	vb.add_child(_sp(24))
	vb.add_child(_hsep_padded(C_BORDER, 1.0, 18))
	vb.add_child(_sp(18))

	# Arme principale (lecture seule, renvoi vers onglet ARMES)
	var pa_row := HBoxContainer.new()
	pa_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd2 := Control.new(); pd2.custom_minimum_size = Vector2(18, 0)
	pa_row.add_child(pd2)
	var pa_sect := _section_lbl("ARMES")
	pa_sect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pa_row.add_child(pa_sect)
	vb.add_child(pa_row)
	vb.add_child(_sp(10))

	var pw: WeaponData = LoadoutManager.get_primary()
	var sw: WeaponData = LoadoutManager.get_secondary()
	vb.add_child(_wpn_summary_row("PRIMAIRE",   pw.display_name if pw else "─", pw))
	vb.add_child(_sp(6))
	vb.add_child(_wpn_summary_row("SECONDAIRE", sw.display_name if sw else "─", sw))
	vb.add_child(_sp(8))

	var goto_btn := _make_btn("Modifier les armes →", 11, C_ACCENT, Color(0,0,0,0),
		func(): _show_tab(1))
	var pd3 := Control.new(); pd3.custom_minimum_size = Vector2(18, 0)
	var btn_row := HBoxContainer.new()
	btn_row.add_child(pd3)
	btn_row.add_child(goto_btn)
	vb.add_child(btn_row)

	return panel

func _item_slot_btn(is_tactical: bool) -> Control:
	var tac := is_tactical
	var lbl_txt := "TACTIQUE" if tac else "LÉTHAL"
	var it: ItemData = (LoadoutManager.get_tactical() if tac else LoadoutManager.get_lethal())
	var it_name := it.display_name if it else "─── AUCUN ───"

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var pd := Control.new(); pd.custom_minimum_size = Vector2(18, 0)
	row.add_child(pd)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(290, 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(C_WHITE, 0.035)
	sn.border_width_left = 2
	sn.border_color = ITEM_TYPE_COL.get(1 if tac else 0, C_ACCENT)
	sn.content_margin_left = 14.0; sn.content_margin_right = 14.0
	sn.content_margin_top  = 6.0;  sn.content_margin_bottom = 6.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(C_WHITE, 0.06)
	sh.border_width_left = 2
	sh.border_color = sn.border_color
	sh.content_margin_left = 14.0; sh.content_margin_right = 14.0
	sh.content_margin_top  = 6.0;  sh.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 2)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(_lbl(lbl_txt, 8, Color(C_DIM, 0.70)))
	inner.add_child(_lbl(it_name, 13, C_WHITE))
	btn.add_child(inner)
	btn.pressed.connect(func(): _open_item_picker(tac))
	row.add_child(btn)
	return row

func _wpn_summary_row(slot_lbl: String, name: String, _wpn: WeaponData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var pd := Control.new(); pd.custom_minimum_size = Vector2(18, 0)
	row.add_child(pd)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_lbl(slot_lbl, 8, Color(C_DIM, 0.55)))
	var wtype_col := C_WHITE
	if _wpn:
		wtype_col = WTYPE_COL.get(int(_wpn.weapon_type), C_WHITE)
	vb.add_child(_lbl(name, 13, wtype_col))
	row.add_child(vb)
	return row

# ══════════════════════════════════════════════════════════════════════════════
# ONGLET ARMES
# ══════════════════════════════════════════════════════════════════════════════
func _build_weapons_tab() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.add_child(_build_wpn_left_col())
	hb.add_child(_vsep())
	_wpn_detail_col = _build_wpn_right_col()
	hb.add_child(_wpn_detail_col)
	return hb

# ── Colonne gauche : liste des armes ─────────────────────────────────────────
func _build_wpn_left_col() -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(400, 0)
	panel.add_theme_stylebox_override("panel", _sbox_bg(Color(C_WHITE, 0.012)))

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	panel.add_child(vb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var card_vb := VBoxContainer.new()
	card_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vb.add_theme_constant_override("separation", 4)
	scroll.add_child(card_vb)

	card_vb.add_child(_sp(16))

	_wpn_cards.clear()
	_wpn_panels.clear()

	for slot_id in [WeaponData.WeaponSlot.PRIMARY, WeaponData.WeaponSlot.SECONDARY]:
		var slot_lbl := "── PRIMAIRE ──────────────────" if slot_id == WeaponData.WeaponSlot.PRIMARY else "── SECONDAIRE ────────────────"
		var lbl_row := HBoxContainer.new()
		var pd := Control.new(); pd.custom_minimum_size = Vector2(14, 0)
		lbl_row.add_child(pd)
		lbl_row.add_child(_lbl(slot_lbl, 9, Color(C_DIM, 0.55)))
		card_vb.add_child(lbl_row)
		card_vb.add_child(_sp(6))

		var all_weapons := LoadoutManager.get_unlocked_weapons(slot_id)
		var cur_id := LoadoutManager.primary_id if slot_id == WeaponData.WeaponSlot.PRIMARY else LoadoutManager.secondary_id

		for wpn: WeaponData in all_weapons:
			var wpn_id := wpn.id
			var selected: bool = (wpn_id == _sel_weapon)
			var wtype_col: Color = WTYPE_COL.get(int(wpn.weapon_type), C_WHITE)

			var card := Panel.new()
			card.custom_minimum_size = Vector2(370, 60)
			card.add_theme_stylebox_override("panel", _wpn_card_sbox(selected, wtype_col))
			_wpn_panels[wpn_id] = card

			var inner := VBoxContainer.new()
			inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			inner.add_theme_constant_override("separation", 3)
			inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var nrow := HBoxContainer.new()
			nrow.add_theme_constant_override("separation", 8)
			nrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var nml := _lbl(wpn.display_name, 14, C_ACCENT if selected else C_WHITE)
			nml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nml.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nrow.add_child(nml)
			if wpn_id == cur_id:
				nrow.add_child(_lbl("✓", 11, Color(C_GREEN, 0.85)))
			inner.add_child(nrow)
			inner.add_child(_lbl(WTYPE_LBL.get(int(wpn.weapon_type), ""), 9,
				Color(wtype_col, 0.70)))
			card.add_child(inner)

			# Overlay cliquable
			var click := Button.new()
			click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			for st in ["normal", "hover", "pressed", "focus"]:
				click.add_theme_stylebox_override(st, StyleBoxEmpty.new())
			click.pressed.connect(func(): _select_weapon(wpn_id))
			card.add_child(click)

			var marg := MarginContainer.new()
			marg.add_theme_constant_override("margin_left",  14)
			marg.add_theme_constant_override("margin_right", 14)
			marg.add_theme_constant_override("margin_top",    0)
			marg.add_theme_constant_override("margin_bottom", 0)
			marg.mouse_filter = Control.MOUSE_FILTER_IGNORE
			marg.add_child(card)
			card_vb.add_child(marg)

			_wpn_cards[wpn_id] = inner

		card_vb.add_child(_sp(14))

	return panel

# ── Colonne droite : détail arme + accessoires ───────────────────────────────
func _build_wpn_right_col() -> Control:
	var col := Control.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_wpn_detail_into(col)
	return col

func _refresh_weapon_detail() -> void:
	if not _wpn_detail_col:
		return
	for c in _wpn_detail_col.get_children():
		c.queue_free()
	_build_wpn_detail_into(_wpn_detail_col)

func _build_wpn_detail_into(col: Control) -> void:
	_stat_fills.clear()
	_slot_btns.clear()

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	col.add_child(vb)

	var wpn: WeaponData = LoadoutManager.weapons.get(_sel_weapon) as WeaponData
	if not wpn:
		vb.add_child(_sp(40))
		vb.add_child(_lbl("Sélectionnez une arme", 14, Color(C_DIM, 0.5)))
		return

	var wtype_col: Color = WTYPE_COL.get(int(wpn.weapon_type), C_WHITE)
	vb.add_child(_sp(22))

	# Type tag + nom
	var tag_row := HBoxContainer.new()
	tag_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd := Control.new(); pd.custom_minimum_size = Vector2(28, 0)
	tag_row.add_child(pd)
	var type_pill := _make_tag_pill(WTYPE_LBL.get(int(wpn.weapon_type), ""), wtype_col)
	tag_row.add_child(type_pill)
	vb.add_child(tag_row)
	vb.add_child(_sp(8))

	var nm_row := HBoxContainer.new()
	nm_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd2 := Control.new(); pd2.custom_minimum_size = Vector2(28, 0)
	nm_row.add_child(pd2)
	nm_row.add_child(_lbl(wpn.display_name, 34, C_WHITE))
	vb.add_child(nm_row)
	vb.add_child(_sp(8))

	var desc_row := HBoxContainer.new()
	desc_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd3 := Control.new(); pd3.custom_minimum_size = Vector2(28, 0)
	desc_row.add_child(pd3)
	var desc_lbl := _lbl(wpn.description, 11, Color(C_DIM, 0.80))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_row.add_child(desc_lbl)
	var pd4 := Control.new(); pd4.custom_minimum_size = Vector2(20, 0)
	desc_row.add_child(pd4)
	vb.add_child(desc_row)
	vb.add_child(_sp(20))
	vb.add_child(_hsep_padded(C_BORDER, 1.0, 28))
	vb.add_child(_sp(16))

	# Barres de stats
	var stats := [
		["DÉGÂTS",   wpn.stat_damage,    C_RED],
		["CADENCE",  wpn.stat_fire_rate,  C_ACCENT],
		["PORTÉE",   wpn.stat_range,      C_GREEN],
		["MOBILITÉ", wpn.stat_mobility,   C_BLUE],
		["PRÉCISION",wpn.stat_accuracy,   Color(0.75, 0.55, 0.85)],
	]
	for stat_data: Array in stats:
		vb.add_child(_build_stat_row(str(stat_data[0]), int(stat_data[1]), stat_data[2] as Color))
		vb.add_child(_sp(7))

	vb.add_child(_sp(18))
	vb.add_child(_hsep_padded(C_BORDER, 1.0, 28))
	vb.add_child(_sp(16))

	# Section accessoires
	var acc_row := HBoxContainer.new()
	acc_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd5 := Control.new(); pd5.custom_minimum_size = Vector2(28, 0)
	acc_row.add_child(pd5)
	acc_row.add_child(_section_lbl("ACCESSOIRES"))
	vb.add_child(acc_row)
	vb.add_child(_sp(12))

	for i in SLOT_LBL.size():
		var acc: AccessoryData = LoadoutManager.get_accessory_in_slot(_sel_weapon, i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 46)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_style_slot_btn(btn, acc != null)
		if acc:
			btn.text = "▶  %s  /  %s" % [SLOT_LBL[i], acc.display_name]
		else:
			btn.text = "   %s  ─── AUCUN ───" % SLOT_LBL[i]
		var idx := i
		btn.pressed.connect(func(): _open_accessory_picker(idx))
		_slot_btns.append(btn)

		var marg := MarginContainer.new()
		marg.add_theme_constant_override("margin_left",  28)
		marg.add_theme_constant_override("margin_right", 28)
		marg.add_theme_constant_override("margin_top",    0)
		marg.add_theme_constant_override("margin_bottom", 0)
		marg.add_child(btn)
		vb.add_child(marg)
		vb.add_child(_sp(5))

func _build_stat_row(label: String, value: int, col: Color) -> Control:
	const TRACK_W := 200.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pd := Control.new(); pd.custom_minimum_size = Vector2(28, 0)
	row.add_child(pd)
	var lbl := _lbl(label, 9, Color(C_DIM, 0.70))
	lbl.custom_minimum_size = Vector2(80, 0)
	row.add_child(lbl)
	row.add_child(_sp_h(8))
	# Track
	var track := ColorRect.new()
	track.custom_minimum_size = Vector2(TRACK_W, 5)
	track.color = Color(C_WHITE, 0.06)
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.custom_minimum_size = Vector2(TRACK_W * value / 100.0, 5)
	fill.color = Color(col, 0.82)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)
	_stat_fills[label] = fill
	row.add_child(track)
	row.add_child(_sp_h(10))
	row.add_child(_lbl(str(value), 9, Color(C_WHITE, 0.65)))
	return row

# ══════════════════════════════════════════════════════════════════════════════
# ONGLET ÉQUIPEMENT
# ══════════════════════════════════════════════════════════════════════════════
func _build_equipment_tab() -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	var left := _build_equip_col(ItemData.ItemType.LETHAL, "LÉTHAL", C_RED)
	var right := _build_equip_col(ItemData.ItemType.TACTICAL, "TACTIQUE", C_BLUE)
	hb.add_child(left)
	hb.add_child(_vsep())
	hb.add_child(right)
	return hb

func _build_equip_col(item_type: ItemData.ItemType, col_label: String, accent: Color) -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	col.add_child(_sp(18))
	var hrow := HBoxContainer.new()
	var pd := Control.new(); pd.custom_minimum_size = Vector2(22, 0)
	hrow.add_child(pd)
	hrow.add_child(_section_lbl(col_label))
	col.add_child(hrow)
	col.add_child(_sp(14))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var card_vb := VBoxContainer.new()
	card_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_vb.add_theme_constant_override("separation", 8)
	scroll.add_child(card_vb)

	var cur_id := LoadoutManager.tactical_id if item_type == ItemData.ItemType.TACTICAL else LoadoutManager.lethal_id
	var all_items: Array[ItemData] = LoadoutManager.get_unlocked_items(item_type)

	for it: ItemData in all_items:
		var it_id := it.id
		var selected: bool = (it_id == cur_id)
		card_vb.add_child(_build_item_card(it, selected, accent, func():
			if item_type == ItemData.ItemType.TACTICAL:
				LoadoutManager.set_tactical(it_id)
			else:
				LoadoutManager.set_lethal(it_id)
			_refresh_equip_tab()
		))

	card_vb.add_child(_sp(14))
	return col

func _build_item_card(it: ItemData, selected: bool, accent: Color, on_press: Callable) -> Control:
	var marg := MarginContainer.new()
	marg.add_theme_constant_override("margin_left",  22)
	marg.add_theme_constant_override("margin_right", 22)
	marg.add_theme_constant_override("margin_top",    0)
	marg.add_theme_constant_override("margin_bottom", 0)

	var card := Panel.new()
	card.custom_minimum_size = Vector2(0, 76)
	var csb := StyleBoxFlat.new()
	csb.bg_color = Color(accent, 0.08) if selected else Color(C_WHITE, 0.025)
	csb.border_width_left = 3 if selected else 1
	csb.border_color = Color(accent, 0.75) if selected else Color(C_BORDER, 1.0)
	csb.content_margin_left   = 14.0; csb.content_margin_right  = 14.0
	csb.content_margin_top    = 10.0; csb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", csb)

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 8)
	nrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nml := _lbl(it.display_name, 14, Color(accent, 0.9) if selected else C_WHITE)
	nml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nml.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nrow.add_child(nml)
	if it.cooldown > 0.0:
		nrow.add_child(_lbl("%.0f s" % it.cooldown, 9, Color(C_DIM, 0.55)))
	if selected:
		nrow.add_child(_lbl("✓", 11, Color(accent, 0.85)))
	inner.add_child(nrow)
	var desc_lbl := _lbl(it.description, 10, Color(C_DIM, 0.70))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	inner.add_child(desc_lbl)
	if it.max_stack > 1:
		inner.add_child(_lbl("× %d" % it.max_stack, 9, Color(C_DIM, 0.45)))
	card.add_child(inner)

	var click := Button.new()
	click.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for st in ["normal", "hover", "pressed", "focus"]:
		click.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	click.pressed.connect(on_press)
	card.add_child(click)

	marg.add_child(card)
	return marg

func _refresh_equip_tab() -> void:
	if _tab_panels.size() < 3:
		return
	var equip_panel: Control = _tab_panels[2]
	for c in equip_panel.get_children():
		c.queue_free()
	equip_panel.add_child(_build_equip_col(ItemData.ItemType.LETHAL,    "LÉTHAL",   C_RED))
	equip_panel.add_child(_vsep())
	equip_panel.add_child(_build_equip_col(ItemData.ItemType.TACTICAL,  "TACTIQUE", C_BLUE))

# ══════════════════════════════════════════════════════════════════════════════
# ACTIONS
# ══════════════════════════════════════════════════════════════════════════════
func _select_op(op_id: String) -> void:
	_sel_op = op_id
	_refresh_op_cards()
	var tw := create_tween()
	tw.tween_property(_detail_col, "modulate:a", 0.0, 0.08)
	tw.tween_callback(_refresh_detail)
	tw.tween_property(_detail_col, "modulate:a", 1.0, 0.18)

func _select_weapon(wpn_id: String) -> void:
	_sel_weapon = wpn_id
	var w: WeaponData = LoadoutManager.weapons.get(wpn_id) as WeaponData
	if w:
		if w.weapon_slot == WeaponData.WeaponSlot.PRIMARY:
			LoadoutManager.set_primary(wpn_id)
		else:
			LoadoutManager.set_secondary(wpn_id)
	_refresh_wpn_cards()
	if _wpn_detail_col:
		var tw := create_tween()
		tw.tween_property(_wpn_detail_col, "modulate:a", 0.0, 0.08)
		tw.tween_callback(_refresh_weapon_detail)
		tw.tween_property(_wpn_detail_col, "modulate:a", 1.0, 0.18)

func _on_faction_filter(f_id: int) -> void:
	_faction_f = f_id
	for entry in _faction_btns:
		_style_filter_btn(entry["btn"] as Button, entry["id"] == f_id)
	for op_id in _op_cards:
		var op: OperatorData = LoadoutManager.operators[op_id]
		var card_marg: Node = (_op_cards[op_id] as Control).get_parent()
		if card_marg and card_marg is CanvasItem:
			(card_marg as CanvasItem).visible = (f_id == -1 or int(op.faction) == f_id)

func _on_back() -> void:
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.22)
	tw.tween_callback(func(): get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn"))

func _on_confirm() -> void:
	if not _sel_op.is_empty():
		LoadoutManager.set_operator(_sel_op)
	_on_back()

func _refresh_op_cards() -> void:
	for op_id in _op_panels:
		var op: OperatorData = LoadoutManager.operators[op_id]
		var locked: bool     = op.unlock_level > ProgressionManager.level
		var selected: bool   = (op_id == _sel_op)
		var f_col: Color     = FACTION_COL.get(int(op.faction), C_ACCENT)
		(_op_panels[op_id] as Panel).add_theme_stylebox_override("panel", _card_sbox(selected, locked, f_col))

func _refresh_wpn_cards() -> void:
	for wpn_id in _wpn_panels:
		var wpn: WeaponData = LoadoutManager.weapons.get(wpn_id) as WeaponData
		if not wpn:
			continue
		var selected: bool  = (wpn_id == _sel_weapon)
		var wtype_col: Color = WTYPE_COL.get(int(wpn.weapon_type), C_WHITE)
		(_wpn_panels[wpn_id] as Panel).add_theme_stylebox_override("panel", _wpn_card_sbox(selected, wtype_col))

func _refresh_slot_btns() -> void:
	for i in _slot_btns.size():
		var acc: AccessoryData = LoadoutManager.get_accessory_in_slot(_sel_weapon, i)
		var btn: Button = _slot_btns[i]
		_style_slot_btn(btn, acc != null)
		if acc:
			btn.text = "▶  %s  /  %s" % [SLOT_LBL[i], acc.display_name]
		else:
			btn.text = "   %s  ─── AUCUN ───" % SLOT_LBL[i]

# ══════════════════════════════════════════════════════════════════════════════
# PICKERS
# ══════════════════════════════════════════════════════════════════════════════
func _open_accessory_picker(slot_idx: int) -> void:
	for c in _picker.get_children():
		c.queue_free()

	var backdrop := Button.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for st in ["normal","hover","pressed","focus"]:
		backdrop.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	backdrop.pressed.connect(_close_picker)
	_picker.add_child(backdrop)

	var modal := _build_picker_modal(SLOT_LBL[slot_idx])
	_picker.add_child(modal)

	var scroll_vb := modal.get_meta("scroll_vb") as VBoxContainer
	var cur_acc: AccessoryData = LoadoutManager.get_accessory_in_slot(_sel_weapon, slot_idx)

	scroll_vb.add_child(_picker_item_row("─── AUCUN ───", "", cur_acc == null, func():
		LoadoutManager.set_accessory(_sel_weapon, slot_idx, "")
		_refresh_slot_btns()
		_close_picker()
	))

	var all_acc: Array[AccessoryData] = LoadoutManager.get_unlocked_accessories(slot_idx)
	for acc: AccessoryData in all_acc:
		var sel: bool = (cur_acc != null and cur_acc.id == acc.id)
		var acc_id := acc.id
		var si     := slot_idx
		scroll_vb.add_child(_picker_acc_row(acc, sel, func():
			LoadoutManager.set_accessory(_sel_weapon, si, acc_id)
			_refresh_slot_btns()
			_close_picker()
		))

	_show_picker()


func _open_item_picker(is_tactical: bool) -> void:
	for c in _picker.get_children():
		c.queue_free()

	var backdrop := Button.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for st in ["normal","hover","pressed","focus"]:
		backdrop.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	backdrop.pressed.connect(_close_picker)
	_picker.add_child(backdrop)

	var title := "TACTIQUE" if is_tactical else "LÉTHAL"
	var modal  := _build_picker_modal(title)
	_picker.add_child(modal)

	var scroll_vb := modal.get_meta("scroll_vb") as VBoxContainer
	var item_type := (ItemData.ItemType.TACTICAL if is_tactical else ItemData.ItemType.LETHAL)
	var cur_id: String = (LoadoutManager.tactical_id if is_tactical else LoadoutManager.lethal_id)

	var all_items: Array[ItemData] = LoadoutManager.get_unlocked_items(item_type)
	for it: ItemData in all_items:
		var sel: bool = (it.id == cur_id)
		var it_id  := it.id
		var tac    := is_tactical
		scroll_vb.add_child(_picker_acc_row_item(it, sel, func():
			if tac: LoadoutManager.set_tactical(it_id)
			else:   LoadoutManager.set_lethal(it_id)
			_close_picker()
		))

	_show_picker()


func _build_picker_modal(title: String) -> CenterContainer:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var modal := Panel.new()
	modal.custom_minimum_size = Vector2(680, 460)
	modal.mouse_filter        = Control.MOUSE_FILTER_STOP
	var msbox := StyleBoxFlat.new()
	msbox.bg_color = Color(0.030, 0.036, 0.026, 0.98)
	msbox.border_width_left   = 1; msbox.border_width_right  = 1
	msbox.border_width_top    = 2; msbox.border_width_bottom = 1
	msbox.border_color        = Color(C_ACCENT, 0.40)
	msbox.content_margin_left   = 26.0; msbox.content_margin_right  = 26.0
	msbox.content_margin_top    = 22.0; msbox.content_margin_bottom = 22.0
	modal.add_theme_stylebox_override("panel", msbox)
	center.add_child(modal)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	modal.add_child(vb)

	var hdr := HBoxContainer.new()
	hdr.add_theme_constant_override("separation", 0)
	var ttl := _lbl(title, 18, C_WHITE)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr.add_child(ttl)
	var xbtn := Button.new()
	xbtn.text = "✕"
	xbtn.add_theme_font_size_override("font_size", 15)
	xbtn.add_theme_color_override("font_color",       Color(C_DIM, 0.6))
	xbtn.add_theme_color_override("font_hover_color", C_WHITE)
	for st in ["normal","hover","pressed","focus"]:
		xbtn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	xbtn.pressed.connect(_close_picker)
	hdr.add_child(xbtn)
	vb.add_child(hdr)
	vb.add_child(_sp(6))
	vb.add_child(_hsep(Color(C_ACCENT, 0.18), 1.0))
	vb.add_child(_sp(14))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var scroll_vb := VBoxContainer.new()
	scroll_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vb.add_theme_constant_override("separation", 6)
	scroll.add_child(scroll_vb)

	center.set_meta("scroll_vb", scroll_vb)
	return center


func _picker_item_row(label: String, _id: String, selected: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text                   = label
	btn.custom_minimum_size    = Vector2(0, 42)
	btn.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	btn.alignment              = HORIZONTAL_ALIGNMENT_LEFT
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color",         C_WHITE if selected else Color(C_DIM, 0.8))
	btn.add_theme_color_override("font_hover_color",   C_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_WHITE)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(C_ACCENT, 0.10) if selected else Color(C_WHITE, 0.0)
	sn.border_width_left = 2 if selected else 0
	sn.border_color      = C_ACCENT
	sn.content_margin_left   = 14.0; sn.content_margin_right  = 14.0
	sn.content_margin_top    = 4.0;  sn.content_margin_bottom = 4.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(C_WHITE, 0.04)
	sh.content_margin_left   = 14.0; sh.content_margin_right  = 14.0
	sh.content_margin_top    = 4.0;  sh.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.pressed.connect(on_press)
	return btn


func _picker_acc_row(acc: AccessoryData, selected: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size   = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(C_ACCENT, 0.08) if selected else Color(C_WHITE, 0.0)
	sn.border_width_left = 2 if selected else 0
	sn.border_color      = C_ACCENT
	sn.content_margin_left   = 14.0; sn.content_margin_right  = 14.0
	sn.content_margin_top    = 8.0;  sn.content_margin_bottom = 8.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(C_WHITE, 0.035)
	sh.content_margin_left   = 14.0; sh.content_margin_right  = 14.0
	sh.content_margin_top    = 8.0;  sh.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	var inner_vb := VBoxContainer.new()
	inner_vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_vb.add_theme_constant_override("separation", 3)
	inner_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var nml := _lbl(acc.display_name, 13, C_ACCENT if selected else C_WHITE)
	nml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nml.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(nml)
	name_row.add_child(_lbl("NIV. %d" % acc.unlock_level, 9, Color(C_DIM, 0.6)))
	inner_vb.add_child(name_row)
	var desc_lbl := _lbl(acc.description, 9, Color(C_DIM, 0.75))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	inner_vb.add_child(desc_lbl)
	btn.add_child(inner_vb)
	btn.pressed.connect(on_press)
	return btn


func _picker_acc_row_item(it: ItemData, selected: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size   = Vector2(0, 56)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(C_ACCENT, 0.08) if selected else Color(0,0,0,0)
	sn.border_width_left = 2 if selected else 0
	sn.border_color      = C_ACCENT
	sn.content_margin_left   = 14.0; sn.content_margin_right  = 14.0
	sn.content_margin_top    = 8.0;  sn.content_margin_bottom = 8.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(C_WHITE, 0.035)
	sh.content_margin_left   = 14.0; sh.content_margin_right  = 14.0
	sh.content_margin_top    = 8.0;  sh.content_margin_bottom = 8.0
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.add_theme_constant_override("separation", 3)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override("separation", 8)
	var nml := _lbl(it.display_name, 13, C_ACCENT if selected else C_WHITE)
	nml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nml.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_child(nml)
	name_row.add_child(_lbl("NIV. %d" % it.unlock_level, 9, Color(C_DIM, 0.6)))
	inner.add_child(name_row)
	var dl := _lbl(it.description, 9, Color(C_DIM, 0.7))
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	inner.add_child(dl)
	btn.add_child(inner)
	btn.pressed.connect(on_press)
	return btn


func _show_picker() -> void:
	_picker.visible  = true
	_picker.modulate.a = 0.0
	create_tween().tween_property(_picker, "modulate:a", 1.0, 0.16)


func _close_picker() -> void:
	var tw := create_tween()
	tw.tween_property(_picker, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func():
		_picker.visible = false
		for c in _picker.get_children():
			c.queue_free()
	)

# ══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ══════════════════════════════════════════════════════════════════════════════
func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _section_lbl(text: String) -> Label:
	return _lbl(text, 10, Color(C_DIM, 0.85))

func _sp(h: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

func _sp_h(w: float) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(w, 0)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s

func _hsep(col: Color, alpha: float) -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size = Vector2(0, 1)
	r.color               = Color(col, alpha)
	r.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	return r

func _hsep_padded(col: Color, alpha: float, pad: float) -> Control:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 0)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pl := Control.new(); pl.custom_minimum_size = Vector2(pad, 0)
	var pr := Control.new(); pr.custom_minimum_size = Vector2(pad, 0)
	var sep := _hsep(col, alpha)
	sep.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(pl); hb.add_child(sep); hb.add_child(pr)
	return hb

func _vsep() -> ColorRect:
	var r := ColorRect.new()
	r.custom_minimum_size   = Vector2(1, 0)
	r.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	r.color                 = Color(C_BORDER, 1.0)
	r.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	return r

func _sbox_bg(col: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = col
	return s

func _card_sbox(selected: bool, locked: bool, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent, 0.08) if selected else Color(C_WHITE, locked and 0.01 or 0.025)
	s.border_width_left = 3 if selected else 1
	s.border_color = Color(accent, 0.80) if selected else Color(C_BORDER, locked and 0.3 or 1.0)
	s.content_margin_left   = 12.0; s.content_margin_right  = 12.0
	s.content_margin_top    = 8.0;  s.content_margin_bottom = 8.0
	return s

func _wpn_card_sbox(selected: bool, accent: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(accent, 0.10) if selected else Color(C_WHITE, 0.025)
	s.border_width_left = 3 if selected else 1
	s.border_color = Color(accent, 0.80) if selected else Color(C_BORDER, 1.0)
	s.content_margin_left   = 12.0; s.content_margin_right  = 12.0
	s.content_margin_top    = 8.0;  s.content_margin_bottom = 8.0
	return s

func _style_slot_btn(btn: Button, has_acc: bool) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(C_ACCENT, 0.06) if has_acc else Color(C_WHITE, 0.02)
	sn.border_width_left = 2 if has_acc else 1
	sn.border_color = Color(C_ACCENT, 0.55) if has_acc else Color(C_BORDER, 1.0)
	sn.content_margin_left   = 14.0; sn.content_margin_right  = 14.0
	sn.content_margin_top    = 4.0;  sn.content_margin_bottom = 4.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(C_WHITE, 0.055)
	sh.border_width_left = 2; sh.border_color = Color(C_ACCENT, 0.40)
	sh.content_margin_left   = 14.0; sh.content_margin_right  = 14.0
	sh.content_margin_top    = 4.0;  sh.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.add_theme_color_override("font_color",       C_ACCENT if has_acc else Color(C_DIM, 0.70))
	btn.add_theme_color_override("font_hover_color", C_WHITE)

func _style_filter_btn(btn: Button, active: bool) -> void:
	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(C_ACCENT, 0.12) if active else Color(C_WHITE, 0.02)
	sn.border_width_bottom = 2 if active else 0
	sn.border_color = C_ACCENT
	sn.content_margin_left = 8.0; sn.content_margin_right  = 8.0
	sn.content_margin_top  = 2.0; sn.content_margin_bottom = 2.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(C_WHITE, 0.05)
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sn)
	btn.add_theme_color_override("font_color",       C_ACCENT if active else Color(C_DIM, 0.70))
	btn.add_theme_color_override("font_hover_color", C_WHITE)

func _make_btn(text: String, size: int, txt_col: Color, bg: Color, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", size)
	btn.add_theme_color_override("font_color",       txt_col)
	btn.add_theme_color_override("font_hover_color", C_WHITE)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var sn := StyleBoxFlat.new()
	sn.bg_color = bg
	sn.content_margin_left = 14.0; sn.content_margin_right  = 14.0
	sn.content_margin_top  = 6.0;  sn.content_margin_bottom = 6.0
	var sh := StyleBoxFlat.new()
	sh.bg_color = Color(bg.r + 0.06, bg.g + 0.06, bg.b + 0.06, minf(bg.a + 0.15, 1.0))
	sh.content_margin_left = 14.0; sh.content_margin_right  = 14.0
	sh.content_margin_top  = 6.0;  sh.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal",  sn)
	btn.add_theme_stylebox_override("hover",   sh)
	btn.add_theme_stylebox_override("pressed", sh)
	btn.pressed.connect(on_press)
	return btn

func _stat_pill(label: String, value: String, col: Color) -> Control:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.08)
	sb.border_width_bottom = 1; sb.border_color = Color(col, 0.35)
	sb.content_margin_left = 10.0; sb.content_margin_right  = 10.0
	sb.content_margin_top  = 4.0;  sb.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_lbl(label, 7, Color(C_DIM, 0.65)))
	vb.add_child(_lbl(value, 14, Color(col, 0.90)))
	panel.add_child(vb)
	return panel

func _make_tag_pill(text: String, col: Color) -> Panel:
	var pill := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.15)
	sb.border_width_left = 2; sb.border_color = Color(col, 0.75)
	sb.content_margin_left = 10.0; sb.content_margin_right  = 10.0
	sb.content_margin_top  = 3.0;  sb.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", sb)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lbl := _lbl(text, 9, Color(col, 0.90))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(lbl)
	return pill
