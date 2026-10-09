class_name TaskPanel
extends CanvasLayer
## Fenster der Spielmodi im HUD-Stil: vor dem ersten Versuch die Aufgabe (Ziel, Steuerung, Tipp,
## Schwellen für Bronze/Silber/Gold), nach jedem Versuch das Ergebnis. Tasten: Leertaste = Los bzw.
## Nochmal, N = nächste Aufgabe, Esc = Startseite. Läuft auch während der Pause.

signal go_pressed
signal next_pressed
signal home_pressed

var mobile := false
var open_changed: Callable         # main.gd: Handy-Finger bedienen das Fenster, Pad aus
var _dim: ColorRect
var _panel: PanelContainer
var _head: Label
var _title: Label
var _result: Label
var _result_medal: Medal
var _result_row: HBoxContainer
var _text: Label
var _medals: Array[Medal] = []
var _medal_labels: Array[Label] = []
var _go: Button
var _mgrid: GridContainer        # Medaillen-Schwellen (hochkant untereinander)
var _next: Button
var _font: Font


## Runde Medaille (gezeichnet – Sonderzeichen fehlen in der Web-Schrift).
class Medal extends Control:
	var level := 0                 # 0 keine, 1 Bronze, 2 Silber, 3 Gold

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c: Color = Training.MEDAL_COLORS[level]
		if level > 0:
			draw_circle(size * 0.5, r, c)
			draw_circle(size * 0.5, r * 0.62, c.lightened(0.25))
		draw_arc(size * 0.5, r - 1.5, 0.0, TAU, 40, Color(c, 1.0) if level > 0 else Color(1, 1, 1, 0.35), 3.0, true)

	func set_level(l: int) -> void:
		level = l
		queue_redraw()


func _init() -> void:
	layer = 18
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial"])
	sf.font_weight = 700
	_font = sf
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.35)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.93)
	sb.set_corner_radius_all(16)
	sb.border_width_bottom = 3
	sb.border_color = Hud.ACCENT
	sb.content_margin_left = 26
	sb.content_margin_right = 26
	sb.content_margin_top = 16
	sb.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", sb)
	_dim.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	_head = _label(16, Color(1, 1, 1, 0.6))
	v.add_child(_head)
	_title = _label(32, Hud.ACCENT)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_result_row = HBoxContainer.new()
	_result_row.add_theme_constant_override("separation", 14)
	v.add_child(_result_row)
	_result_medal = Medal.new()
	_result_medal.custom_minimum_size = Vector2(54, 54)
	_result_row.add_child(_result_medal)
	_result = _label(30, Color.WHITE)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_row.add_child(_result)
	_text = _label(19, Color(1, 1, 1, 0.9))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	var mrow := GridContainer.new()
	mrow.columns = 3
	mrow.add_theme_constant_override("h_separation", 18)
	mrow.add_theme_constant_override("v_separation", 6)
	v.add_child(mrow)
	_mgrid = mrow
	for i in 3:
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mrow.add_child(box)
		var m := Medal.new()
		m.custom_minimum_size = Vector2(30, 30)
		m.set_level(i + 1)
		box.add_child(m)
		_medals.append(m)
		var l := _label(17, Color(1, 1, 1, 0.85))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(l)
		_medal_labels.append(l)
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	v.add_child(brow)
	_go = _button("LOS", true)
	_go.pressed.connect(func() -> void: go_pressed.emit())
	brow.add_child(_go)
	_next = _button("Nächste Aufgabe", false)
	_next.pressed.connect(func() -> void: next_pressed.emit())
	brow.add_child(_next)
	var home := _button("Startseite", false)
	home.pressed.connect(func() -> void: home_pressed.emit())
	brow.add_child(home)
	get_viewport().size_changed.connect(_layout)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 21)
	b.custom_minimum_size = Vector2(0, 54)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Hud.ACCENT if primary else Color(0.14, 0.17, 0.2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	for st: String in ["normal", "hover", "pressed", "focus"]:
		var s2 := sb.duplicate() as StyleBoxFlat
		if st == "hover":
			s2.bg_color = s2.bg_color.lightened(0.12)
		elif st == "pressed":
			s2.bg_color = s2.bg_color.darkened(0.2)
		b.add_theme_stylebox_override(st, s2)
	var fc := Color(0.04, 0.07, 0.03) if primary else Color.WHITE
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	return b


## Aufgabe vorstellen (vor dem ersten Versuch). best: [Medaille, Bestwert].
func show_intro(mode_name: String, idx: int, count: int, task: Dictionary, best: Array, has_next: bool) -> void:
	_fill(mode_name, idx, count, task, best, has_next)
	_result_row.visible = false
	var keys: String = task.get("keys_mobile", task["keys"]) if mobile else task["keys"]
	_text.text = "%s\n\nSteuerung:  %s\nTipp:  %s" % [task["goal"], keys, task["tip"]]
	_go.text = "LOS" + ("" if mobile else "  (Leertaste)")
	_open()


## Ergebnis eines Versuchs. medal 0 = keine; text z. B. "2,4 m" oder "Gestürzt".
func show_result(mode_name: String, idx: int, count: int, task: Dictionary, best: Array, has_next: bool,
		medal: int, text: String, new_best: bool) -> void:
	_fill(mode_name, idx, count, task, best, has_next)
	_result_row.visible = true
	_result_medal.set_level(medal)
	_result.text = ("%s!   %s" % [Training.MEDALS[medal].to_upper(), text]) if medal > 0 else text
	_result.add_theme_color_override("font_color", Training.MEDAL_COLORS[medal] if medal > 0 else Color(1, 1, 1, 0.9))
	var b := "Bestwert: " + (Training.format_value(task, best[1]) if not is_nan(float(best[1])) else "–")
	if new_best:
		b = "Neue Bestleistung!   " + b
	_text.text = b
	_go.text = "NOCHMAL" + ("" if mobile else "  (Leertaste)")
	_open()


func _fill(mode_name: String, idx: int, count: int, task: Dictionary, best: Array, has_next: bool) -> void:
	_head.text = "%s   ·   AUFGABE %d / %d" % [mode_name.to_upper(), idx + 1, count]
	_title.text = task["title"]
	for i in 3:
		_medal_labels[i].text = "%s  %s" % [Training.MEDALS[i + 1], Training.format_threshold(task, i)]
		_medals[i].modulate.a = 1.0 if int(best[0]) > i else 0.45
	_next.visible = has_next
	_next.text = "Nächste Aufgabe" + ("" if mobile else "  (N)")


func _open() -> void:
	_dim.visible = true
	if open_changed.is_valid():
		open_changed.call(true)
	_layout()


func close() -> void:
	if not _dim.visible:
		return
	_dim.visible = false
	if open_changed.is_valid():
		open_changed.call(false)


func is_open() -> bool:
	return _dim.visible


## Mittig, 720 breit (hochkant 500, damit die Schrift groß bleibt); passend skaliert.
func _layout() -> void:
	if _panel == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var w := 500.0 if vs.x < vs.y else 720.0
	_mgrid.columns = 1 if vs.x < vs.y else 3
	var k := clampf(minf(vs.y / 720.0, vs.x / 760.0), 0.5, 3.0) * (1.25 if mobile else 1.0)
	k = minf(k, (vs.x - 24.0) / w)
	_panel.custom_minimum_size = Vector2(w, 0)
	_panel.size = Vector2(w, 0)
	_panel.reset_size()
	_panel.scale = Vector2(k, k)
	await get_tree().process_frame
	var size := _panel.get_combined_minimum_size()
	_panel.size = size
	_panel.position = (vs - size * k) * 0.5


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
			go_pressed.emit()
		KEY_N:
			if _next.visible:
				next_pressed.emit()
		KEY_ESCAPE:
			home_pressed.emit()
		_:
			return
	get_viewport().set_input_as_handled()
