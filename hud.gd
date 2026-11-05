extends CanvasLayer
class_name CxHud
## All 2D UI: field HUD, quest log, survey map, title, pause, result cards and
## the mobile control rig.

const PARCH := Color(0.91, 0.78, 0.57)
const INK := Color(0.09, 0.07, 0.05)
const TEAL := Color(0.25, 0.92, 0.82)
const AMBER := Color(1.0, 0.63, 0.20)
const HAZARD := Color(1.0, 0.36, 0.10)
const PANEL_BG := Color(0.10, 0.075, 0.055, 0.84)
const PANEL_EDGE := Color(0.70, 0.49, 0.26, 0.95)

var game
var disp_font: FontFile

var play_ui: Control
var touch_ui: Control
var map_ui: Control
var title_ui: Control
var pause_ui: Control
var over_ui: Control
var help_panel: PanelContainer

var hp_bar: ProgressBar
var st_bar: ProgressBar
var camp_bar: ProgressBar
var tonic_label: Label
var herb_label: Label
var evidence_label: Label
var weather_label: Label
var phase_label: Label
var log_lines: Array[Label] = []
var prompt_label: Label
var prompt_wrap: PanelContainer
var toast_label: Label
var banner_title: Label
var banner_sub: Label
var banner_box: VBoxContainer
var map_view: CxMap
var over_title: Label
var over_body: Label
var joypad: CxJoypad

var sprint_held := false
var touch_mode := false
var _attack := false
var _dodge := false
var _potion := false
var _interact := false
var toast_t := 0.0
var banner_t := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	disp_font = load("res://assets/fonts/RussoOne.ttf")
	_build_play()
	_build_touch()
	_build_map()
	_build_title()
	_build_pause()
	_build_over()
	if OS.has_feature("mobile"):
		enable_touch()


# ------------------------------------------------------------------ factories
func _sb(bg: Color, edge: Color, radius: int = 7, border: int = 2, pad: int = 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


func _panel(pad: int = 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(PANEL_BG, PANEL_EDGE, 8, 2, pad))
	return p


func _label(text: String, size: int, col: Color, use_disp: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	if use_disp and disp_font != null:
		l.add_theme_font_override("font", disp_font)
	return l


func _btn(text: String, w: float = 250.0, h: float = 58.0, accent: Color = AMBER) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, h)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	if disp_font != null:
		b.add_theme_font_override("font", disp_font)
	b.add_theme_color_override("font_color", PARCH)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(0.55, 0.48, 0.40))
	b.add_theme_stylebox_override("normal", _sb(Color(0.14, 0.10, 0.07, 0.92), accent, 6, 2, 12))
	b.add_theme_stylebox_override("hover", _sb(Color(0.26, 0.17, 0.09, 0.96), accent.lightened(0.25), 6, 2, 12))
	b.add_theme_stylebox_override("pressed", _sb(accent, accent.darkened(0.3), 6, 3, 12))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.12, 0.10, 0.09, 0.7), Color(0.35, 0.30, 0.25), 6, 2, 12))
	return b


func _bar(col: Color, w: float = 208.0) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, 15)
	pb.max_value = 100.0
	pb.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.05, 0.04, 0.9)
	bg.set_corner_radius_all(4)
	bg.border_color = Color(0.45, 0.33, 0.20, 0.9)
	bg.set_border_width_all(1)
	var fl := StyleBoxFlat.new()
	fl.bg_color = col
	fl.set_corner_radius_all(4)
	pb.add_theme_stylebox_override("background", bg)
	pb.add_theme_stylebox_override("fill", fl)
	return pb


func _row(icon_col: Color, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var dot := ColorRect.new()
	dot.color = icon_col
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(dot)
	h.add_child(_label(text, 14, PARCH))
	return h


# ----------------------------------------------------------------- field HUD
func _build_play() -> void:
	play_ui = Control.new()
	play_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	play_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_ui.visible = false
	add_child(play_ui)

	# vitals, top-left
	var stats := _panel(12)
	stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
	stats.offset_left = 18
	stats.offset_top = 16
	play_ui.add_child(stats)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 5)
	stats.add_child(sv)
	sv.add_child(_label("SURVEYOR VITALS", 13, AMBER, true))
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.add_child(_label("HP", 13, PARCH))
	hp_bar = _bar(Color(0.85, 0.27, 0.20))
	hb.add_child(hp_bar)
	sv.add_child(hb)
	var sb2 := HBoxContainer.new()
	sb2.add_theme_constant_override("separation", 8)
	sb2.add_child(_label("ST", 13, PARCH))
	st_bar = _bar(TEAL)
	sb2.add_child(st_bar)
	sv.add_child(sb2)
	var cb := HBoxContainer.new()
	cb.add_theme_constant_override("separation", 8)
	cb.add_child(_label("CP", 13, PARCH))
	camp_bar = _bar(Color(0.95, 0.76, 0.30))
	cb.add_child(camp_bar)
	sv.add_child(cb)
	var inv := HBoxContainer.new()
	inv.add_theme_constant_override("separation", 14)
	tonic_label = _label("TONIC 1", 14, Color(0.60, 0.95, 0.70))
	herb_label = _label("HERBS 0", 14, Color(0.80, 0.92, 0.60))
	inv.add_child(tonic_label)
	inv.add_child(herb_label)
	sv.add_child(inv)

	# quest log, top-right
	var logp := _panel(12)
	logp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	logp.offset_left = -262
	logp.offset_right = -18
	logp.offset_top = 16
	logp.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	play_ui.add_child(logp)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 6)
	logp.add_child(lv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_label("FIELD LOG", 13, AMBER, true))
	evidence_label = _label("0/3", 13, TEAL, true)
	head.add_child(evidence_label)
	lv.add_child(head)
	var sep := ColorRect.new()
	sep.color = Color(0.70, 0.49, 0.26, 0.6)
	sep.custom_minimum_size = Vector2(0, 2)
	lv.add_child(sep)
	for i in range(4):
		var l := _label("", 14, PARCH)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(228, 0)
		log_lines.append(l)
		lv.add_child(l)
	var sep2 := ColorRect.new()
	sep2.color = Color(0.70, 0.49, 0.26, 0.4)
	sep2.custom_minimum_size = Vector2(0, 2)
	lv.add_child(sep2)
	weather_label = _label("CLEAR BASIN", 13, Color(0.95, 0.85, 0.65), true)
	lv.add_child(weather_label)
	phase_label = _label("PHASE 1 - AMBER SURVEY", 12, Color(0.80, 0.68, 0.52))
	lv.add_child(phase_label)

	# interaction prompt
	var pbar := Control.new()
	pbar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pbar.offset_top = -178
	pbar.offset_bottom = -118
	pbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	play_ui.add_child(pbar)
	var pcenter := CenterContainer.new()
	pcenter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pcenter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pbar.add_child(pcenter)
	prompt_wrap = _panel(10)
	prompt_wrap.visible = false
	pcenter.add_child(prompt_wrap)
	prompt_label = _label("", 17, PARCH, true)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_wrap.add_child(prompt_label)

	# toast
	toast_label = _label("", 19, AMBER, true)
	toast_label.set_anchors_preset(Control.PRESET_CENTER)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast_label.offset_top = 128
	toast_label.modulate.a = 0.0
	play_ui.add_child(toast_label)

	# banner
	banner_box = VBoxContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner_box.offset_top = 84
	banner_box.alignment = BoxContainer.ALIGNMENT_CENTER
	banner_box.modulate.a = 0.0
	play_ui.add_child(banner_box)
	banner_title = _label("", 40, HAZARD, true)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_sub = _label("", 17, PARCH)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_box.add_child(banner_title)
	banner_box.add_child(banner_sub)

	# desktop control hint
	var hint := _label("WASD move   SHIFT sprint   LMB cut   SPACE dodge   E interact   Q tonic   M map   ESC pause", 13, Color(0.86, 0.75, 0.58))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.offset_top = -34
	hint.offset_bottom = -12
	hint.name = "Hint"
	play_ui.add_child(hint)


# -------------------------------------------------------------- touch rig
func _build_touch() -> void:
	touch_ui = Control.new()
	touch_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_ui.visible = false
	add_child(touch_ui)

	var look := Control.new()
	look.set_anchors_preset(Control.PRESET_FULL_RECT)
	look.offset_left = 0
	look.offset_bottom = -210
	look.mouse_filter = Control.MOUSE_FILTER_STOP
	look.gui_input.connect(_on_look_input)
	touch_ui.add_child(look)

	joypad = CxJoypad.new()
	joypad.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joypad.offset_left = 22
	joypad.offset_top = -198
	joypad.offset_right = 198
	joypad.offset_bottom = -22
	touch_ui.add_child(joypad)

	var pad := GridContainer.new()
	pad.columns = 2
	pad.add_theme_constant_override("h_separation", 12)
	pad.add_theme_constant_override("v_separation", 12)
	pad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pad.offset_left = -236
	pad.offset_top = -214
	pad.offset_right = -18
	pad.offset_bottom = -18
	pad.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pad.grow_vertical = Control.GROW_DIRECTION_BEGIN
	touch_ui.add_child(pad)

	var b_tonic := _btn("TONIC", 100, 68, Color(0.45, 0.90, 0.60))
	b_tonic.pressed.connect(func() -> void: _potion = true)
	pad.add_child(b_tonic)
	var b_use := _btn("USE", 100, 68, TEAL)
	b_use.pressed.connect(func() -> void: _interact = true)
	pad.add_child(b_use)
	var b_dodge := _btn("DODGE", 100, 84, Color(0.55, 0.75, 1.0))
	b_dodge.pressed.connect(func() -> void: _dodge = true)
	pad.add_child(b_dodge)
	var b_cut := _btn("CUT", 100, 84, HAZARD)
	b_cut.pressed.connect(func() -> void: _attack = true)
	pad.add_child(b_cut)

	var b_sprint := _btn("SPRINT", 110, 62, AMBER)
	b_sprint.toggle_mode = true
	b_sprint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	b_sprint.offset_left = 214
	b_sprint.offset_top = -92
	b_sprint.offset_right = 324
	b_sprint.offset_bottom = -30
	b_sprint.toggled.connect(func(on: bool) -> void: sprint_held = on)
	touch_ui.add_child(b_sprint)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.offset_top = 16
	touch_ui.add_child(top)
	var b_map := _btn("MAP", 92, 48, AMBER)
	b_map.pressed.connect(toggle_map)
	top.add_child(b_map)
	var b_pause := _btn("PAUSE", 104, 48, AMBER)
	b_pause.pressed.connect(_press_pause)
	top.add_child(b_pause)


func _on_look_input(event: InputEvent) -> void:
	if game == null or game.player == null:
		return
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		game.player.orbit(d.relative.x, d.relative.y)
	elif event is InputEventMouseMotion:
		var m := event as InputEventMouseMotion
		if m.button_mask != 0:
			game.player.orbit(m.relative.x, m.relative.y)


func enable_touch() -> void:
	if touch_mode:
		return
	touch_mode = true
	touch_ui.visible = play_ui.visible
	var hint := play_ui.get_node_or_null("Hint")
	if hint != null:
		(hint as Label).visible = false


# ---------------------------------------------------------------- map screen
func _build_map() -> void:
	map_ui = Control.new()
	map_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_ui.visible = false
	map_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(map_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.015, 0.78)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_ui.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map_ui.add_child(center)
	var p := _panel(16)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title := _label("CINDERHORN BASIN - SURVEY MAP", 24, AMBER, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	map_view = CxMap.new()
	map_view.custom_minimum_size = Vector2(430, 430)
	v.add_child(map_view)
	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 18)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_child(_row(TEAL, "You / Camp"))
	legend.add_child(_row(AMBER, "Trace site"))
	legend.add_child(_row(HAZARD, "Cinderhorn"))
	legend.add_child(_row(Color(0.55, 0.92, 0.55), "Salt herb"))
	v.add_child(legend)
	var close := _btn("CLOSE MAP  [M]", 230, 50, AMBER)
	close.pressed.connect(toggle_map)
	var cc := CenterContainer.new()
	cc.add_child(close)
	v.add_child(cc)


func toggle_map() -> void:
	if game != null and not game.running() and not map_ui.visible:
		return
	map_ui.visible = not map_ui.visible
	if map_ui.visible:
		map_view.game = game
		map_view.queue_redraw()
	if game != null:
		game.sfx_click()


# --------------------------------------------------------------- title screen
func _build_title() -> void:
	title_ui = Control.new()
	title_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_ui)
	var bg := TextureRect.new()
	bg.texture = load("res://assets/tex/title_bg.png")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.05, 0.03, 0.02, 0.52)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 10)
	center.add_child(v)

	var kicker := _label("FIELD EXPEDITION  No. 07", 16, AMBER, true)
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(kicker)
	var t := _label("CINDERHORN ATLAS", 62, PARCH, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("Track the armored six-legged Cinderhorn across the amber salt basin.\nRead its charge, dodge, counter — document three evidence sets, then reach the forge.", 16, Color(0.90, 0.82, 0.68))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(620, 0)
	v.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	v.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var start := _btn("BEGIN EXPEDITION", 290, 62, AMBER)
	start.pressed.connect(_press_start)
	row.add_child(start)
	var helpb := _btn("BRIEFING", 180, 62, TEAL)
	helpb.pressed.connect(_toggle_help)
	row.add_child(helpb)

	help_panel = _panel(14)
	help_panel.visible = false
	v.add_child(help_panel)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 4)
	help_panel.add_child(hv)
	hv.add_child(_label("KEYBOARD + MOUSE", 17, AMBER, true))
	hv.add_child(_label("WASD / Arrows - move      SHIFT - sprint      SPACE - dodge roll", 15, PARCH))
	hv.add_child(_label("LEFT MOUSE / F - field cutter      E - interact      Q - drink tonic", 15, PARCH))
	hv.add_child(_label("RIGHT-MOUSE DRAG - orbit camera      M - survey map      ESC - pause", 15, PARCH))
	hv.add_child(_label("TOUCH", 17, AMBER, true))
	hv.add_child(_label("Left stick moves, drag the screen to look, right pad cuts / dodges / uses.", 15, PARCH))
	hv.add_child(_label("THE RULE OF THE BASIN", 17, HAZARD, true))
	hv.add_child(_label("A glowing lane on the ground means a charge. Dodge OUT of the lane and\nthe Cinderhorn over-runs, crashes and opens its vents for three seconds.\nThat is the only moment the cutter does real damage.", 15, PARCH))

	var press := _label("Press SPACE or ENTER, or tap anywhere, to start", 15, Color(0.95, 0.85, 0.62))
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(press)


func _press_start() -> void:
	if game != null:
		game.start_run()


func _press_pause() -> void:
	if game != null:
		game.toggle_pause()


func _press_restart() -> void:
	if game != null:
		game.restart()


func _press_title() -> void:
	if game != null:
		game.to_title()


func _toggle_help() -> void:
	help_panel.visible = not help_panel.visible
	if game != null:
		game.sfx_click()


# ---------------------------------------------------------------------- pause
func _build_pause() -> void:
	pause_ui = Control.new()
	pause_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.visible = false
	add_child(pause_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.015, 0.74)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_ui.add_child(center)
	var p := _panel(20)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var t := _label("CAMP REST", 40, PARCH, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := _label("The basin waits.", 15, Color(0.85, 0.75, 0.60))
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var r := _btn("RESUME", 260, 56, AMBER)
	r.pressed.connect(_press_pause)
	v.add_child(r)
	var rs := _btn("RESTART EXPEDITION", 260, 52, TEAL)
	rs.pressed.connect(_press_restart)
	v.add_child(rs)
	var q := _btn("ABANDON TO TITLE", 260, 52, Color(0.80, 0.45, 0.35))
	q.pressed.connect(_press_title)
	v.add_child(q)


# --------------------------------------------------------------- result cards
func _build_over() -> void:
	over_ui = Control.new()
	over_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_ui.visible = false
	add_child(over_ui)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.02, 0.015, 0.80)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_ui.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_ui.add_child(center)
	var p := _panel(22)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	over_title = _label("", 48, PARCH, true)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_title)
	over_body = _label("", 17, Color(0.90, 0.82, 0.68))
	over_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	over_body.custom_minimum_size = Vector2(540, 0)
	v.add_child(over_body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var again := _btn("NEW EXPEDITION  [R]", 300, 58, AMBER)
	again.pressed.connect(_press_restart)
	row.add_child(again)
	var home := _btn("TITLE", 150, 58, TEAL)
	home.pressed.connect(_press_title)
	row.add_child(home)


# -------------------------------------------------------------------- runtime
func show_title() -> void:
	title_ui.visible = true
	play_ui.visible = false
	touch_ui.visible = false
	pause_ui.visible = false
	over_ui.visible = false
	map_ui.visible = false


func show_play() -> void:
	title_ui.visible = false
	play_ui.visible = true
	touch_ui.visible = touch_mode
	pause_ui.visible = false
	over_ui.visible = false


func show_pause(on: bool) -> void:
	pause_ui.visible = on


func show_result(win: bool, body: String) -> void:
	play_ui.visible = false
	touch_ui.visible = false
	map_ui.visible = false
	over_ui.visible = true
	over_title.text = "ATLAS COMPLETE" if win else "EXPEDITION LOST"
	over_title.add_theme_color_override("font_color", TEAL if win else HAZARD)
	over_body.text = body


func toast(text: String) -> void:
	toast_label.text = text
	toast_t = 2.6


func banner(title: String, sub: String, col: Color) -> void:
	banner_title.text = title
	banner_title.add_theme_color_override("font_color", col)
	banner_sub.text = sub
	banner_t = 3.2


func show_prompt(text: String) -> void:
	if prompt_wrap == null:
		return
	if text == "":
		prompt_wrap.visible = false
	else:
		prompt_wrap.visible = true
		prompt_label.text = text


func move_vec() -> Vector2:
	if joypad == null:
		return Vector2.ZERO
	return joypad.value


func consume_attack() -> bool:
	var v := _attack
	_attack = false
	return v


func consume_dodge() -> bool:
	var v := _dodge
	_dodge = false
	return v


func consume_potion() -> bool:
	var v := _potion
	_potion = false
	return v


func consume_interact() -> bool:
	var v := _interact
	_interact = false
	return v


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not touch_mode:
		enable_touch()


func _process(delta: float) -> void:
	if toast_t > 0.0:
		toast_t -= delta
		toast_label.modulate.a = clampf(toast_t / 0.6, 0.0, 1.0)
	else:
		toast_label.modulate.a = 0.0
	if banner_t > 0.0:
		banner_t -= delta
		banner_box.modulate.a = clampf(banner_t / 0.7, 0.0, 1.0)
		banner_box.scale = Vector2.ONE
	else:
		banner_box.modulate.a = 0.0
	if map_ui.visible:
		map_view.queue_redraw()
	if game != null and play_ui.visible:
		_refresh()


func _refresh() -> void:
	var p = game.player
	if p == null:
		return
	hp_bar.value = p.health
	st_bar.value = p.stamina
	camp_bar.value = game.camp_hp
	tonic_label.text = "TONIC %d" % p.potions
	herb_label.text = "HERBS %d" % p.herbs
	evidence_label.text = "%d/3" % game.evidence
	weather_label.text = game.weather_name()
	phase_label.text = "PHASE %d - %s" % [game.phase, game.phase_name()]
	var lines: Array = game.log_lines()
	for i in range(log_lines.size()):
		if i < lines.size():
			log_lines[i].text = lines[i]
			log_lines[i].add_theme_color_override("font_color", TEAL if lines[i].begins_with("[x]") else PARCH)
		else:
			log_lines[i].text = ""
