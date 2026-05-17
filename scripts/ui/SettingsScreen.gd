extends CanvasLayer
class_name SettingsScreen

# ── Palette ───────────────────────────────────────────────────────────────────
const C_BG      := Color(0.016, 0.020, 0.014, 1.0)
const C_SURFACE := Color(0.028, 0.034, 0.024, 0.97)
const C_ACCENT  := Color(0.831, 0.525, 0.102, 1.0)
const C_WHITE   := Color(0.941, 0.925, 0.894, 1.0)
const C_DIM     := Color(0.290, 0.322, 0.282, 1.0)
const C_GREEN   := Color(0.455, 0.655, 0.390, 1.0)
const C_BORDER  := Color(0.561, 0.659, 0.541, 0.09)

# ── State ─────────────────────────────────────────────────────────────────────
var _root: Control
var _cur_tab: int = 0
var _tab_btns:   Array = []
var _tab_panels: Array = []
var _dirty: bool = false   # unsaved changes

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer = 6
	_build_ui()
	_animate_in()

# ── Build ─────────────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scan := ColorRect.new()
	scan.color = Color(1, 1, 1, 1)
	scan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scan.material = _scanline_mat()
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scan)

	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.add_theme_constant_override("separation", 0)
	_root.add_child(vb)

	vb.add_child(_build_header())

	var tab_sep := ColorRect.new()
	tab_sep.color = Color(0.12, 0.14, 0.10, 0.15)
	tab_sep.custom_minimum_size = Vector2(0, 1)
	vb.add_child(tab_sep)

	vb.add_child(_build_tab_bar())

	var sep2 := ColorRect.new()
	sep2.color = Color(0.12, 0.14, 0.10, 0.15)
	sep2.custom_minimum_size = Vector2(0, 1)
	vb.add_child(sep2)

	var content := Control.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(content)

	_tab_panels.clear()
	var builders := [_build_audio_tab, _build_graphics_tab, _build_gameplay_tab]
	for b in builders:
		var panel: Control = b.call()
		panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		panel.visible = false
		content.add_child(panel)
		_tab_panels.append(panel)

	_show_tab(0)

# ── Header ────────────────────────────────────────────────────────────────────
func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 72)
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(C_SURFACE.r, C_SURFACE.g, C_SURFACE.b, 0.98)
	sbox.border_width_bottom = 1
	sbox.border_color = Color(C_ACCENT, 0.18)
	panel.add_theme_stylebox_override("panel", sbox)

	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 0)
	panel.add_child(hrow)

	var back_btn := Button.new()
	back_btn.text = "← RETOUR"
	back_btn.custom_minimum_size = Vector2(160, 72)
	back_btn.add_theme_font_size_override("font_size", 13)
	_style_back_btn(back_btn)
	back_btn.pressed.connect(_on_back)
	hrow.add_child(back_btn)

	var bar := ColorRect.new()
	bar.color = C_ACCENT
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hrow.add_child(bar)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 28)
	m.add_theme_constant_override("margin_top", 12)
	m.add_theme_constant_override("margin_bottom", 12)
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(m)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	m.add_child(col)
	col.add_child(_lbl("BATTLEZONE 6", 10, Color(C_ACCENT, 0.7)))
	col.add_child(_lbl("PARAMÈTRES", 28, C_WHITE))

	var save_btn := Button.new()
	save_btn.text = "SAUVEGARDER"
	save_btn.custom_minimum_size = Vector2(180, 72)
	save_btn.add_theme_font_size_override("font_size", 13)
	_style_save_btn(save_btn)
	save_btn.pressed.connect(_on_save)
	hrow.add_child(save_btn)

	return panel

# ── Tab bar ───────────────────────────────────────────────────────────────────
func _build_tab_bar() -> Control:
	var hb := HBoxContainer.new()
	hb.custom_minimum_size = Vector2(0, 48)
	hb.add_theme_constant_override("separation", 0)

	var pad := Control.new()
	pad.custom_minimum_size = Vector2(24, 0)
	hb.add_child(pad)

	_tab_btns.clear()
	var labels := ["AUDIO", "GRAPHISMES", "GAMEPLAY"]
	for i in labels.size():
		var idx := i
		var btn := Button.new()
		btn.text = labels[i]
		btn.custom_minimum_size = Vector2(160, 48)
		btn.add_theme_font_size_override("font_size", 12)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(func(): _show_tab(idx))
		_tab_btns.append(btn)
		hb.add_child(btn)

	_refresh_tab_btns()
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(fill)
	return hb

func _show_tab(idx: int) -> void:
	_cur_tab = idx
	for i in _tab_panels.size():
		_tab_panels[i].visible = (i == idx)
	_refresh_tab_btns()

func _refresh_tab_btns() -> void:
	for i in _tab_btns.size():
		var btn: Button = _tab_btns[i]
		var active := (i == _cur_tab)
		var n := StyleBoxFlat.new()
		n.bg_color = Color(C_ACCENT, 0.10) if active else Color(0, 0, 0, 0)
		n.border_width_bottom = 3 if active else 0
		n.border_color = C_ACCENT
		n.content_margin_left   = 16.0
		n.content_margin_right  = 16.0
		n.content_margin_top    = 0.0
		n.content_margin_bottom = 0.0
		btn.add_theme_stylebox_override("normal",  n)
		btn.add_theme_stylebox_override("hover",   n)
		btn.add_theme_stylebox_override("pressed", n)
		btn.add_theme_color_override("font_color",       C_ACCENT if active else Color(C_WHITE, 0.45))
		btn.add_theme_color_override("font_hover_color", C_WHITE)

# ══════════════════════════════════════════════════════════════════════════════
# TAB : AUDIO
# ══════════════════════════════════════════════════════════════════════════════
func _build_audio_tab() -> Control:
	var root := _tab_scroll()
	var vb   := _tab_vbox(root)

	var sm := SettingsManager
	vb.add_child(_section("NIVEAUX SONORES"))
	vb.add_child(_slider_row("Volume Maître", sm.volume_master,
		func(v): SettingsManager.set_volume_master(v); _mark_dirty()))
	vb.add_child(_slider_row("Musique", sm.volume_music,
		func(v): SettingsManager.set_volume_music(v); _mark_dirty()))
	vb.add_child(_slider_row("Effets Sonores", sm.volume_sfx,
		func(v): SettingsManager.set_volume_sfx(v); _mark_dirty()))
	_add_bottom_pad(vb)
	return root

# ══════════════════════════════════════════════════════════════════════════════
# TAB : GRAPHISMES
# ══════════════════════════════════════════════════════════════════════════════
func _build_graphics_tab() -> Control:
	var root := _tab_scroll()
	var vb   := _tab_vbox(root)
	var sm   := SettingsManager

	vb.add_child(_section("QUALITÉ"))
	vb.add_child(_preset_row(sm.graphics_preset))

	vb.add_child(_section("IMAGE"))
	vb.add_child(_slider_row("Champ de vision (FOV)", sm.fov,
		func(v): SettingsManager.set_fov(v); _mark_dirty(),
		"%.0f°", 55.0, 110.0))

	vb.add_child(_section("AFFICHAGE"))
	vb.add_child(_toggle_row("Plein écran", sm.fullscreen,
		func(v): SettingsManager.set_fullscreen(v); _mark_dirty()))
	vb.add_child(_toggle_row("VSync", sm.vsync,
		func(v): SettingsManager.set_vsync(v); _mark_dirty()))
	vb.add_child(_fps_row(sm.max_fps))
	_add_bottom_pad(vb)
	return root

func _preset_row(current: int) -> Control:
	var card := _row_card()
	var inner := card.get_child(0).get_child(0) as HBoxContainer

	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 3)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(name_col)
	name_col.add_child(_lbl("Qualité graphique", 14, C_WHITE))
	name_col.add_child(_lbl("Ombres, SSAO, Bloom, Rendu global", 10, Color(C_DIM, 0.7)))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	inner.add_child(btn_row)

	var labels := ["MIN", "FAIBLE", "MOYEN", "ÉLEVÉ", "ULTRA"]
	for i in labels.size():
		var idx := i
		var btn := Button.new()
		btn.text = labels[i]
		btn.custom_minimum_size = Vector2(72, 36)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		btn.pressed.connect(func():
			SettingsManager.set_graphics_preset(idx)
			_mark_dirty()
			_rebuild_tab(1)
		)
		var active := (i == current)
		_style_preset_btn(btn, active)
		btn_row.add_child(btn)

	return card

func _fps_row(current: int) -> Control:
	var card := _row_card()
	var inner := card.get_child(0).get_child(0) as HBoxContainer

	var name_col := VBoxContainer.new()
	name_col.add_theme_constant_override("separation", 3)
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(name_col)
	name_col.add_child(_lbl("FPS maximum", 14, C_WHITE))
	name_col.add_child(_lbl("0 = illimité", 10, Color(C_DIM, 0.7)))

	var opt := OptionButton.new()
	opt.custom_minimum_size = Vector2(120, 40)
	opt.add_theme_font_size_override("font_size", 13)
	opt.add_theme_color_override("font_color", C_WHITE)
	opt.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var fps_opts := [0, 30, 60, 90, 120, 144, 165, 240]
	var sel := 0
	for i in fps_opts.size():
		var v := fps_opts[i]
		opt.add_item("Illimité" if v == 0 else "%d FPS" % v, i)
		if v == current:
			sel = i
	opt.select(sel)
	opt.item_selected.connect(func(idx: int):
		SettingsManager.set_max_fps(fps_opts[idx])
		_mark_dirty()
	)
	inner.add_child(opt)

	return card

# ══════════════════════════════════════════════════════════════════════════════
# TAB : GAMEPLAY
# ══════════════════════════════════════════════════════════════════════════════
func _build_gameplay_tab() -> Control:
	var root := _tab_scroll()
	var vb   := _tab_vbox(root)
	var sm   := SettingsManager

	vb.add_child(_section("CONTRÔLES"))
	vb.add_child(_slider_row("Sensibilité souris", sm.mouse_sensitivity,
		func(v): SettingsManager.set_mouse_sensitivity(v); _mark_dirty(),
		"%.2f", 0.01, 1.0))
	vb.add_child(_slider_row("Sensibilité en visée (ADS)", sm.ads_sensitivity,
		func(v): SettingsManager.set_ads_sensitivity(v); _mark_dirty(),
		"%.2f", 0.01, 1.0))
	vb.add_child(_toggle_row("Inverser l'axe Y", sm.invert_y,
		func(v): SettingsManager.set_invert_y(v); _mark_dirty()))
	_add_bottom_pad(vb)
	return root

# ══════════════════════════════════════════════════════════════════════════════
# WIDGETS
# ══════════════════════════════════════════════════════════════════════════════

func _slider_row(label: String, value: float, on_change: Callable,
		fmt: String = "%d%%", min_v: float = 0.0, max_v: float = 1.0) -> Control:
	var card  := _row_card()
	var inner := card.get_child(0).get_child(0) as HBoxContainer

	var name_lbl := _lbl(label, 14, C_WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(name_lbl)

	var val_lbl := _lbl(_fmt_slider(value, fmt, min_v, max_v), 14, C_ACCENT)
	val_lbl.custom_minimum_size = Vector2(56, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inner.add_child(val_lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step      = 0.01
	slider.value     = clampf((value - min_v) / (max_v - min_v), 0.0, 1.0)
	slider.custom_minimum_size = Vector2(220, 36)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(slider)
	slider.value_changed.connect(func(v: float):
		var real := min_v + v * (max_v - min_v)
		val_lbl.text = _fmt_slider(real, fmt, min_v, max_v)
		on_change.call(real)
	)
	inner.add_child(slider)

	return card

func _toggle_row(label: String, value: bool, on_change: Callable) -> Control:
	var card  := _row_card()
	var inner := card.get_child(0).get_child(0) as HBoxContainer

	var name_lbl := _lbl(label, 14, C_WHITE)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(name_lbl)

	var btn := Button.new()
	btn.toggle_mode  = true
	btn.button_pressed = value
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_style_toggle_btn(btn, value)
	btn.toggled.connect(func(pressed: bool):
		_style_toggle_btn(btn, pressed)
		on_change.call(pressed)
	)
	inner.add_child(btn)

	return card

func _row_card() -> MarginContainer:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_left",   32)
	outer.add_theme_constant_override("margin_right",  32)
	outer.add_theme_constant_override("margin_top",    0)
	outer.add_theme_constant_override("margin_bottom", 0)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	var sbox := StyleBoxFlat.new()
	sbox.bg_color = Color(0, 0, 0, 0)
	sbox.border_width_bottom = 1
	sbox.border_color = Color(0.12, 0.14, 0.10, 0.12)
	sbox.content_margin_left   = 0.0
	sbox.content_margin_right  = 0.0
	sbox.content_margin_top    = 0.0
	sbox.content_margin_bottom = 0.0
	panel.add_theme_stylebox_override("panel", sbox)
	outer.add_child(panel)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(hb)

	return outer

func _section(title: String) -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left",   32)
	mc.add_theme_constant_override("margin_right",  32)
	mc.add_theme_constant_override("margin_top",    20)
	mc.add_theme_constant_override("margin_bottom", 4)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	mc.add_child(hb)
	var bar := ColorRect.new()
	bar.color = C_ACCENT
	bar.custom_minimum_size = Vector2(3, 0)
	bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hb.add_child(bar)
	hb.add_child(_lbl(title, 10, Color(C_ACCENT, 0.7)))
	return mc

# ── Style helpers ─────────────────────────────────────────────────────────────
func _style_toggle_btn(btn: Button, active: bool) -> void:
	btn.text = "ACTIVÉ" if active else "DÉSACTIVÉ"
	var n := StyleBoxFlat.new()
	n.bg_color = Color(C_GREEN, 0.15) if active else Color(C_DIM, 0.08)
	n.border_width_left   = 1; n.border_width_right  = 1
	n.border_width_top    = 1; n.border_width_bottom = 1
	n.border_color = Color(C_GREEN, 0.5) if active else Color(C_DIM, 0.25)
	n.content_margin_left   = 12.0; n.content_margin_right  = 12.0
	n.content_margin_top    = 6.0;  n.content_margin_bottom = 6.0
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   n)
	btn.add_theme_stylebox_override("pressed", n)
	btn.add_theme_color_override("font_color",         C_GREEN if active else Color(C_DIM, 0.7))
	btn.add_theme_color_override("font_hover_color",   C_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_WHITE)

func _style_preset_btn(btn: Button, active: bool) -> void:
	var n := StyleBoxFlat.new()
	n.bg_color = Color(C_ACCENT, 0.18) if active else Color(C_DIM, 0.08)
	n.border_width_left   = 1; n.border_width_right  = 1
	n.border_width_top    = 1; n.border_width_bottom = 1
	n.border_color = Color(C_ACCENT, 0.6) if active else Color(C_DIM, 0.2)
	n.content_margin_left = 8.0; n.content_margin_right  = 8.0
	n.content_margin_top  = 4.0; n.content_margin_bottom = 4.0
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   n)
	btn.add_theme_stylebox_override("pressed", n)
	btn.add_theme_color_override("font_color",         C_ACCENT if active else Color(C_DIM, 0.6))
	btn.add_theme_color_override("font_hover_color",   C_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_WHITE)

func _style_slider(slider: HSlider) -> void:
	var grab := StyleBoxFlat.new()
	grab.bg_color = C_ACCENT
	grab.set_corner_radius_all(4)
	grab.content_margin_left   = 6.0; grab.content_margin_right  = 6.0
	grab.content_margin_top    = 6.0; grab.content_margin_bottom = 6.0
	var track := StyleBoxFlat.new()
	track.bg_color = Color(C_DIM, 0.25)
	track.content_margin_top    = 2.0
	track.content_margin_bottom = 2.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(C_ACCENT, 0.65)
	fill.content_margin_top    = 2.0
	fill.content_margin_bottom = 2.0
	slider.add_theme_stylebox_override("grabber_area",      fill)
	slider.add_theme_stylebox_override("grabber_area_highlight", fill)
	slider.add_theme_stylebox_override("slider",            track)
	slider.add_theme_icon_override("grabber",               _grabber_icon())

func _grabber_icon() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in 16:
		for x in 16:
			var dx := float(x) - 7.5
			var dy := float(y) - 7.5
			if dx * dx + dy * dy <= 36.0:
				img.set_pixel(x, y, C_ACCENT)
	return ImageTexture.create_from_image(img)

func _style_back_btn(btn: Button) -> void:
	var no_focus := StyleBoxEmpty.new()
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0, 0, 0, 0)
	n.content_margin_left  = 24.0; n.content_margin_right = 24.0
	var h := StyleBoxFlat.new()
	h.bg_color = Color(C_ACCENT, 0.07)
	h.border_width_right = 1
	h.border_color = Color(C_ACCENT, 0.25)
	h.content_margin_left  = 24.0; h.content_margin_right = 24.0
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   no_focus)
	btn.add_theme_color_override("font_color",         Color(C_WHITE, 0.5))
	btn.add_theme_color_override("font_hover_color",   C_WHITE)
	btn.add_theme_color_override("font_pressed_color", C_WHITE)

func _style_save_btn(btn: Button) -> void:
	var no_focus := StyleBoxEmpty.new()
	var n := StyleBoxFlat.new()
	n.bg_color = Color(C_ACCENT, 0.12)
	n.border_width_left = 1
	n.border_color = Color(C_ACCENT, 0.3)
	n.content_margin_left  = 24.0; n.content_margin_right = 24.0
	var h := StyleBoxFlat.new()
	h.bg_color = C_ACCENT
	h.content_margin_left  = 24.0; h.content_margin_right = 24.0
	btn.add_theme_stylebox_override("normal",  n)
	btn.add_theme_stylebox_override("hover",   h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.add_theme_stylebox_override("focus",   no_focus)
	btn.add_theme_color_override("font_color",         C_ACCENT)
	btn.add_theme_color_override("font_hover_color",   Color(0.039, 0.047, 0.035, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(0.039, 0.047, 0.035, 1.0))

# ── Utilities ─────────────────────────────────────────────────────────────────
func _tab_scroll() -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.get_v_scroll_bar().custom_minimum_size.x = 4
	return sc

func _tab_vbox(parent: ScrollContainer) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 0)
	parent.add_child(vb)
	return vb

func _add_bottom_pad(vb: VBoxContainer) -> void:
	var bot := Control.new()
	bot.custom_minimum_size = Vector2(0, 24)
	vb.add_child(bot)

func _fmt_slider(real: float, fmt: String, min_v: float, max_v: float) -> String:
	if fmt == "%d%%":
		return "%d%%" % int(real * 100.0)
	return fmt % real

func _mark_dirty() -> void:
	_dirty = true

func _rebuild_tab(idx: int) -> void:
	if idx >= _tab_panels.size():
		return
	var old: Control = _tab_panels[idx]
	var parent := old.get_parent()
	var insert_idx := old.get_index()
	parent.remove_child(old)
	old.queue_free()
	var builders := [_build_audio_tab, _build_graphics_tab, _build_gameplay_tab]
	var panel: Control = builders[idx].call()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.visible = (idx == _cur_tab)
	parent.add_child(panel)
	parent.move_child(panel, insert_idx)
	_tab_panels[idx] = panel

func _lbl(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _scanline_mat() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	var sh  := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat line = mod(FRAGCOORD.y, 4.0);\n\tCOLOR = vec4(0.0, 0.0, 0.0, line < 1.0 ? 0.018 : 0.0);\n}\n"
	mat.shader = sh
	return mat

func _animate_in() -> void:
	_root.modulate.a = 0.0
	_root.position.y = 16.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, 0.40).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "position:y", 0.0, 0.30).set_ease(Tween.EASE_OUT)

func _on_save() -> void:
	SettingsManager.save()
	_dirty = false
	var tw := create_tween()
	tw.tween_interval(0.08)
	tw.tween_callback(func(): pass)

func _on_back() -> void:
	if _dirty:
		SettingsManager.save()
	get_tree().change_scene_to_file("res://scenes/main/MainMenu.tscn")
