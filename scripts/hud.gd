class_name Hud
extends CanvasLayer
## Anzeige im Spiel. Oben in der Mitte die wichtigen Werte: Zeit, Seilzug (groß, mit
## Warnbereich) und Punkte. Unten rechts klein die Technik-Angaben, unten links die Hilfe.

const HELP := """A / D   Kante: lenken   (in der Luft: drehen)
W   Kante belasten: mehr Grip, weite Bögen, mehr Zug
S   Kante lösen = Driften: Brett rutscht quer, dreht schneller (gut für die Wende)
Leertaste halten + loslassen   Absprung
Enter  Start (Runde 7:30)     R  zurück zum Steg (−5:00)     + / -  Anlagentempo
Nach Sturz:  W halten = zur Handle schwimmen     Leertaste = sofort weiter (−3:00)
C  Kamera     Maus: umsehen (Klick fängt Maus, Esc gibt frei), Rad: Zoom
P  Autopilot     M  Ton aus/an     H  Hilfe ein/aus
Vor dem Start:   T  Terminal (T1/T2)     F  Feature-Setup     Tab  Feature-Übersicht"""

const HELP_MOBILE := """Handy neigen   lenken
Finger halten + loslassen   Absprung
Tippen   Start"""

const ACCENT := Color(0.55, 0.82, 0.22)          # Wakeport-Grün
const PANEL := Color(0.05, 0.07, 0.09, 0.66)
const WARN := Color(1.0, 0.62, 0.15)
const DANGER := Color(1.0, 0.22, 0.15)

enum TimeState { IDLE, RUNNING, LOW, OVER }

var _center: Label
var _trick: Label
var _help: Label
var _board: Label
var _debug: Label
var _trick_time := 0.0
var _setup_box: Control

var _time_label: Label
var _time_value: Label
var _time_state := TimeState.IDLE
var _score_value: Label
var _score_gain: Label
var _score_shown := 0.0
var _score_target := 0
var _score_pop := 0.0
var _gain_time := 0.0
var _gauge: TensionGauge
var _top_bar: Control
var _font: Font
var _t := 0.0


func _ready() -> void:
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial"])
	sf.font_weight = 700
	_font = sf
	_build_top_bar()

	_center = _label(34)
	_center.anchor_right = 1.0
	_center.anchor_top = 0.32
	_center.anchor_bottom = 0.32
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_trick = _label(42)
	_trick.anchor_right = 1.0
	_trick.anchor_top = 0.2
	_trick.anchor_bottom = 0.2
	_trick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trick.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	_help = _label(16)
	_help.text = HELP
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -175
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))

	# Technik-Angaben klein unten rechts
	_debug = _label(14)
	_debug.anchor_left = 1.0
	_debug.anchor_right = 1.0
	_debug.anchor_top = 1.0
	_debug.anchor_bottom = 1.0
	_debug.offset_left = -420
	_debug.offset_right = -14
	_debug.offset_bottom = -10
	_debug.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_debug.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_debug.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_debug.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_debug.add_theme_constant_override("outline_size", 4)


## Leiste oben: Zeit | Seilzug | Punkte
func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left = 0.5
	bar.anchor_right = 0.5
	bar.offset_top = 12
	bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	_top_bar = bar

	var tp := _panel(bar, 170)
	_time_label = _small(tp, "ZEIT")
	_time_value = _big(tp, "7:30")

	var gp := _panel(bar, 440)
	_gauge = TensionGauge.new()
	_gauge.custom_minimum_size = Vector2(416, 74)
	_gauge.font = _font
	gp.add_child(_gauge)

	var sp := _panel(bar, 170)
	_small(sp, "PUNKTE")
	_score_value = _big(sp, "0")
	_score_value.pivot_offset = Vector2(75, 24)

	# Brettzustand (Drift/Kante) klein unter dem Seilzug, Punkte-Zuwachs unter den Punkten
	_board = Label.new()
	_board.add_theme_font_override("font", _font)
	_board.add_theme_font_size_override("font_size", 16)
	_board.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	_board.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_board.add_theme_constant_override("outline_size", 5)
	_board.anchor_left = 0.5
	_board.anchor_right = 0.5
	_board.offset_left = -300
	_board.offset_right = 300
	_board.offset_top = 112
	_board.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_board)
	_score_gain = Label.new()
	_score_gain.add_theme_font_override("font", _font)
	_score_gain.add_theme_font_size_override("font_size", 22)
	_score_gain.add_theme_color_override("font_color", ACCENT)
	_score_gain.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_score_gain.add_theme_constant_override("outline_size", 5)
	_score_gain.anchor_left = 0.5
	_score_gain.anchor_right = 0.5
	_score_gain.offset_left = 230
	_score_gain.offset_right = 410
	_score_gain.offset_top = 110
	_score_gain.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_score_gain)


func _panel(parent: Control, w: float) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(14)
	sb.border_width_bottom = 3
	sb.border_color = ACCENT
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(w, 0)
	parent.add_child(pc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -4)
	pc.add_child(vb)
	return vb


func _small(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _big(parent: Control, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", 44)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


## Die wichtigen Werte oben: Zeit (Text + Zustand), Punkte, Seilzug in N und Anteil bis zum Abriss.
func set_stats(time_text: String, time_state: TimeState, score: int, tension_n: float, tension_ratio: float) -> void:
	_time_value.text = time_text
	_time_state = time_state
	_time_label.text = "ZEIT UM" if time_state == TimeState.OVER else "ZEIT"
	if score > _score_target:
		_score_gain.text = "+%d" % (score - _score_target)
		_gain_time = 1.6
		_score_pop = 1.0
	elif score < _score_target:
		_score_shown = score               # neue Runde
	_score_target = score
	_gauge.set_value(tension_n, tension_ratio)


## Technik-Angaben (klein, unten rechts).
func set_debug(text: String) -> void:
	_debug.text = text


func set_center(text: String) -> void:
	_center.text = text


func show_trick(text: String) -> void:
	_trick.text = text
	_trick_time = 2.0


## Auswahl vor dem Start (Terminal, Feature-Setup), rechts unter der Leiste. Liefert die Auswahlbox.
func add_menu_choice(title_text: String, names: Array, current: int, on_select: Callable) -> OptionButton:
	if _setup_box == null:
		var vb := VBoxContainer.new()
		vb.anchor_left = 1.0
		vb.anchor_right = 1.0
		vb.offset_left = -330
		vb.offset_right = -16
		vb.offset_top = 140
		add_child(vb)
		_setup_box = vb
	var box := _setup_box
	var title := _label(18)
	title.text = title_text
	title.reparent(box)
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 20)
	opt.custom_minimum_size = Vector2(300, 44)
	for n: String in names:
		opt.add_item(n)
	opt.select(current)
	opt.item_selected.connect(on_select)
	opt.focus_mode = Control.FOCUS_NONE         # Tastatur bleibt beim Spiel
	box.add_child(opt)
	return opt


func show_setup_menu(on: bool) -> void:
	if _setup_box:
		_setup_box.visible = on


func set_help(text: String) -> void:
	_help.text = text


func toggle_help() -> void:
	_help.visible = not _help.visible


func set_board(text: String) -> void:
	_board.text = text


func _process(delta: float) -> void:
	_t += delta
	# schmale Bildschirme (Handy): Leiste passend verkleinern
	var vw := get_viewport().get_visible_rect().size.x
	var k := minf(1.0, (vw - 16.0) / maxf(_top_bar.size.x, 1.0))
	_top_bar.pivot_offset = Vector2(_top_bar.size.x * 0.5, 0.0)
	_top_bar.scale = Vector2(k, k)
	_trick_time -= delta
	_trick.visible = _trick_time > 0.0
	# Punkte zählen hoch, kurzes "Aufpoppen"
	_score_shown = move_toward(_score_shown, _score_target, maxf(absf(_score_target - _score_shown) * 6.0, 30.0) * delta)
	_score_value.text = str(int(round(_score_shown)))
	_score_pop = maxf(_score_pop - delta * 3.0, 0.0)
	_score_value.scale = Vector2.ONE * (1.0 + 0.25 * _score_pop)
	_score_value.add_theme_color_override("font_color", Color.WHITE.lerp(ACCENT, _score_pop))
	_gain_time -= delta
	_score_gain.visible = _gain_time > 0.0
	_score_gain.modulate.a = clampf(_gain_time / 0.5, 0.0, 1.0)
	# Zeit: knapp = orange pulsierend, vorbei = rot, vor dem Start gedimmt
	var c := Color.WHITE
	match _time_state:
		TimeState.IDLE:
			c = Color(1, 1, 1, 0.55)
		TimeState.LOW:
			c = Color.WHITE.lerp(WARN, 0.6 + 0.4 * sin(_t * 6.0))
		TimeState.OVER:
			c = DANGER
	_time_value.add_theme_color_override("font_color", c)


## Großer Seilzug-Anzeiger: Segmente von grün über gelb nach rot, Spitzenwert-Marke,
## ab 85 % blinkt der Rahmen rot (gleich reißt die Handle aus der Hand).
class TensionGauge extends Control:
	const SEGMENTS := 24
	var font: Font
	var _n := 0.0
	var _ratio := 0.0
	var _peak := 0.0
	var _t := 0.0

	func set_value(n: float, ratio: float) -> void:
		_n = n
		_ratio = clampf(ratio, 0.0, 1.2)
		_peak = maxf(_peak, _ratio)

	func _process(delta: float) -> void:
		_t += delta
		_peak = maxf(_peak - delta * 0.35, _ratio)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		# Kopfzeile: Titel links, Wert rechts
		var f := font if font else get_theme_default_font()
		draw_string(f, Vector2(2, 18), "SEILZUG", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		var val := "%s N" % _thousands(roundi(_n))
		var col := _color(_ratio)
		draw_string(f, Vector2(0, 22), val, HORIZONTAL_ALIGNMENT_RIGHT, w - 2, 26, Color.WHITE.lerp(col, clampf(_ratio * 1.2, 0.0, 1.0)))
		# Segmente
		var top := 32.0
		var h := size.y - top - 4.0
		var gap := 3.0
		var sw := (w - gap * (SEGMENTS - 1)) / SEGMENTS
		var lit := int(ceil(clampf(_ratio, 0.0, 1.0) * SEGMENTS))
		for i in SEGMENTS:
			var x := i * (sw + gap)
			var frac := (i + 0.5) / SEGMENTS
			var c := _color(frac)
			if i >= lit:
				c = Color(c.r, c.g, c.b, 0.16)
			# leicht ansteigende Segmenthöhe: wirkt wie eine Skala
			var sh := h * (0.55 + 0.45 * frac)
			draw_rect(Rect2(x, top + h - sh, sw, sh), c)
		# Spitzenwert
		if _peak > 0.02:
			var px := clampf(_peak, 0.0, 1.0) * w
			draw_rect(Rect2(px - 2.0, top - 2.0, 3.0, h + 4.0), Color(1, 1, 1, 0.85))
		# Warnung kurz vor dem Abriss
		if _ratio > 0.85:
			var a := 0.5 + 0.5 * sin(_t * 18.0)
			draw_rect(Rect2(-6, -2, w + 12, size.y + 4), Color(DANGER.r, DANGER.g, DANGER.b, a), false, 3.0)

	static func _color(frac: float) -> Color:
		if frac < 0.55:
			return ACCENT.lerp(Color(0.95, 0.85, 0.2), frac / 0.55)
		return Color(0.95, 0.85, 0.2).lerp(DANGER, clampf((frac - 0.55) / 0.35, 0.0, 1.0))

	static func _thousands(v: int) -> String:
		var s := str(v)
		var out := ""
		while s.length() > 3:
			out = "." + s.substr(s.length() - 3) + out
			s = s.substr(0, s.length() - 3)
		return s + out
