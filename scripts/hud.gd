class_name Hud
extends CanvasLayer
## Anzeige im Spiel. Oben in der Mitte die wichtigen Werte: Zeit, Seilzug (groß, mit
## Warnbereich) und Punkte. Unten rechts klein die Technik-Angaben, unten links die Hilfe.

const HELP := """← / →   lenken   (in der Luft und beim Raley: drehen; auf dem Slider: Boardslide ↔ 50-50 umspringen)
↑ / ↓   in der Luft: Frontroll / Backroll (beim Invert gleich nach dem Absprung: ↑ S-Bend, ↓ Backroll)     auf dem Slider: Nosepress / Tailpress     im Drift: Drift-Press     Sprung-Start: auf dem Steg ↓ halten, bis das Seil losreißt (Brett längs: Nolli, quer: Raley Start)
Strg (oder Alt)   Driften: man rutscht geradeaus weiter (lenken geht nicht), das Brett dreht frei, etwas schneller; quer vom Slider ins Wasser nur mit Drift
Leertaste halten + loslassen   Absprung (Ollie; voll aufgeladen mit Seilzug über der Marke RALEY und ohne Feature voraus: Invert = Raley – Höhe aus Seilzug + Tempo)
Start mit Countdown 3 – 2 – 1 – GO (Runde 7:30)     R  zurück zum Steg (−2:00, dann Countdown), in den Spielmodi: neuer Versuch     + / -  Anlagentempo
Nach Sturz:  Leertaste halten = zur Handle schwimmen     Strg = sofort weiter (−1:00)     R = Steg (−2:00)
C  Kamera     Maus: umsehen (Klick fängt Maus), Rad: Zoom     Esc  Pause     O  Einstellungen
Z  Szenario würfeln     P  Autopilot     M  Ton aus/an     G  Seil-Abreißen an/aus (aus: keine Rangliste)     H  Hilfe ein/aus     F11  Vollbild     F3  Hitboxen (Debug)     F4  Parameter (Debug, nur lokal)
Tab  Startseite (Terminal, Feature-Setup, Einstellungen)     Menüs: Tab / Pfeile wählen, Leertaste drücken, Enter Start, Esc zurück
Gamepad: Stick/Steuerkreuz lenken, Kreuz oder R2 (analog) Sprung, Kreis Drift, L1/R1 Tempo (in der Luft: schnelle 180), rechter Stick umsehen (R3 halten: Zoom), Touchpad Steg, Share Szenario würfeln, PS Pause, Options Einstellungen"""

const HELP_MOBILE := """Start mit Countdown          ← / → (bzw. Handy neigen mit Lenkung: Gyro)   lenken (auf dem Slider: Tipp bzw. deutlich neigen = Boardslide ↔ 50-50)
SPRUNG (links) halten + loslassen   Absprung (voll aufgeladen, Seilzug über RALEY: Raley)
Pfeil ↑ / ↓   in der Luft Frontroll / Backroll (Invert: ▲ S-Bend, ▼ Backroll), auf dem Slider Nose- / Tailpress, im Drift Drift-Press, auf dem Steg ▼ halten = Sprung-Start (längs Nolli, quer Raley Start)
DRIFT (links, über SPRUNG)   Kante lösen        Nach Sturz: SCHWIMMEN halten = schwimmen, SKIP = sofort weiter (−1:00)
☰   Menü (pausiert): Einstellungen, Hilfe, Zurück zum Steg (Spielmodi: neuer Versuch), Startseite, Ton, Szenario würfeln, Seil-Abreißen an/aus (aus: keine Rangliste)"""

const ACCENT := Color(0.55, 0.82, 0.22)          # Wakeport-Grün
const PANEL := Color(0.05, 0.07, 0.09, 0.66)
const WARN := Color(1.0, 0.62, 0.15)
const DANGER := Color(1.0, 0.22, 0.15)
const ACH_TIME := 4.5             # s Meldung "Geheimer Erfolg"

enum TimeState { IDLE, RUNNING, LOW, OVER }

var _center: Label
var _trick: Label
var _help: Label
var _help_hint: Label
var _board: Label
var _debug: Label
var _trick_time := 0.0
var _setup_box: Control
var _mobile_help := false
var _recovery: PanelContainer     # nach einem Sturz: was jetzt geht und was es kostet
var _rec_title: Label
var _rec_grid: GridContainer
var _rec_key := ""
var _ach: PanelContainer          # Meldung "Geheimer Erfolg" (oben, unter der Leiste)
var _ach_name: Label
var _ach_time := 0.0

var _time_label: Label
var time_title := "ZEIT"          # Spielmodi: "VERSUCH"
var _count: Label                 # Countdown 3 – 2 – 1 – GO
var _task: Label                  # Spielmodi: Aufgabe und Messwert unter der Leiste
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
var _bar_panels: Array = []       # Zeit, Seilzug, Tempo, Punkte
var _bar_cols: Array = []         # hochkant: zwei Spalten
var _portrait := false
var _bar_k := 1.0                 # Maßstab der Leiste
var _speed: SpeedGauge
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
	_help.visible = false                       # beim Start aus, H blendet ein
	_help_hint = _label(16)
	_help_hint.text = "H  Hilfe"
	_help_hint.anchor_top = 1.0
	_help_hint.anchor_bottom = 1.0
	_help_hint.offset_left = 16
	_help_hint.offset_top = -34
	_help_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))

	_build_recovery()
	_build_achievement()

	_count = _label(150)
	_count.anchor_right = 1.0
	_count.anchor_top = 0.3
	_count.anchor_bottom = 0.3
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_font_override("font", _font)
	_count.add_theme_constant_override("outline_size", 14)
	_count.visible = false

	_task = _label(22)
	_task.add_theme_font_override("font", _font)
	_task.anchor_right = 1.0
	_task.offset_top = 104          # direkt unter der Leiste (Brettzustand rückt darunter)
	_task.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_task.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))

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


## Panel nach einem Sturz (unten in der Mitte): Titel und je Zeile Taste – Aktion – Zeitkosten.
func _build_recovery() -> void:
	_recovery = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.9)
	sb.set_corner_radius_all(16)
	sb.border_width_bottom = 3
	sb.border_color = ACCENT
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 14
	sb.content_margin_bottom = 16
	_recovery.add_theme_stylebox_override("panel", sb)
	_recovery.anchor_left = 0.5
	_recovery.anchor_right = 0.5
	_recovery.anchor_top = 1.0
	_recovery.anchor_bottom = 1.0
	_recovery.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_recovery.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_recovery.offset_bottom = -36
	_recovery.visible = false
	add_child(_recovery)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_recovery.add_child(v)
	_rec_title = Label.new()
	_rec_title.add_theme_font_override("font", _font)
	_rec_title.add_theme_font_size_override("font_size", 26)
	_rec_title.add_theme_color_override("font_color", ACCENT)
	_rec_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_rec_title)
	_rec_grid = GridContainer.new()
	_rec_grid.columns = 3
	_rec_grid.add_theme_constant_override("h_separation", 18)
	_rec_grid.add_theme_constant_override("v_separation", 8)
	v.add_child(_rec_grid)


## Nach einem Sturz anzeigen. rows: [[Taste, Aktion, Kosten, teuer?], …]; leerer Titel = ausblenden.
func show_recovery(title: String, rows: Array) -> void:
	if title == "":
		_recovery.visible = false
		_rec_key = ""
		return
	_recovery.visible = true
	# hochkant (Handy): Titel zweizeilig, je Zeile links die Taste, rechts Aktion und darunter die Kosten –
	# drei Spalten wären ca. 750 px breit und würden unleserlich klein gestaucht
	var tall := _portrait
	_rec_title.text = title.replace("  –  ", "\n") if tall else title
	var key := str(rows) + str(tall)
	if key == _rec_key:
		return
	_rec_key = key
	_rec_grid.columns = 2 if tall else 3
	for c in _rec_grid.get_children():
		_rec_grid.remove_child(c)
		c.queue_free()
	for row: Array in rows:
		var k := Label.new()
		k.text = " %s " % row[0]
		k.add_theme_font_override("font", _font)
		k.add_theme_font_size_override("font_size", 22)
		k.add_theme_color_override("font_color", Color(0.04, 0.07, 0.03))
		var kb := StyleBoxFlat.new()
		kb.bg_color = Color(1, 1, 1, 0.92)
		kb.set_corner_radius_all(8)
		kb.content_margin_left = 8
		kb.content_margin_right = 8
		kb.content_margin_top = 2
		kb.content_margin_bottom = 2
		k.add_theme_stylebox_override("normal", kb)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		k.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_rec_grid.add_child(k)
		var a := Label.new()
		a.text = row[1]
		a.add_theme_font_override("font", _font)
		a.add_theme_font_size_override("font_size", 24)
		a.add_theme_color_override("font_color", Color.WHITE)
		var c := Label.new()
		c.text = row[2]
		c.add_theme_font_override("font", _font)
		c.add_theme_font_size_override("font_size", 22 if tall else 24)
		c.add_theme_color_override("font_color", WARN if row[3] else ACCENT)
		if tall:
			var ac := VBoxContainer.new()
			ac.add_theme_constant_override("separation", -4)
			ac.add_child(a)
			ac.add_child(c)
			_rec_grid.add_child(ac)
		else:
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_rec_grid.add_child(a)
			_rec_grid.add_child(c)
	_recovery.offset_left = 0.0           # Breite neu aus dem Inhalt (wächst um die Mitte)
	_recovery.offset_right = 0.0


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

	# Tempo: genauso wichtig wie der Seilzug (Raley, Drift-Press, Sprunghöhe hängen daran)
	var vp := _panel(bar, 280)
	_speed = SpeedGauge.new()
	_speed.custom_minimum_size = Vector2(256, 74)
	_speed.font = _font
	vp.add_child(_speed)

	var sp := _panel(bar, 170)
	_small(sp, "PUNKTE")
	_score_value = _big(sp, "0")
	_score_value.pivot_offset = Vector2(75, 24)
	_bar_panels = [tp.get_parent(), gp.get_parent(), vp.get_parent(), sp.get_parent()]
	# hochkant (Handy): zwei Spalten – links Zeit über Punkte, rechts Seilzug über Tempo
	for i in 2:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.visible = false
		bar.add_child(col)
		_bar_cols.append(col)

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
func set_stats(time_text: String, time_state: TimeState, score: int, tension_n: float, tension_limit: float) -> void:
	_time_value.text = time_text
	_time_state = time_state
	_time_label.text = "ZEIT UM" if time_state == TimeState.OVER else time_title
	if score > _score_target:
		_score_gain.text = "+%d" % (score - _score_target)
		_gain_time = 1.6
		_score_pop = 1.0
	elif score < _score_target:
		_score_shown = score               # neue Runde
	_score_target = score
	_gauge.set_value(tension_n, tension_n / tension_limit, tension_limit)


## Fahrer-Tempo (km/h) für die Tempo-Anzeige.
func set_speed(kmh: float) -> void:
	_speed.set_value(kmh)


## Technik-Angaben (klein, unten rechts).
func set_debug(text: String) -> void:
	_debug.text = text


## Countdown groß in der Mitte ("" = aus). GO in Grün.
func show_count(text: String) -> void:
	_count.visible = text != ""
	_count.text = text
	_count.add_theme_color_override("font_color", ACCENT if text == "GO" else Color.WHITE)


## Spielmodi: Aufgabe und aktueller Messwert unter der Leiste ("" = aus).
func set_task(text: String) -> void:
	_task.text = text


func set_center(text: String) -> void:
	_center.text = text


func show_trick(text: String) -> void:
	_trick.text = text
	_trick_time = 2.0


## Geheimer Erfolg freigeschaltet: Meldung in der Mitte (unteres Drittel), ACH_TIME Sekunden.
func show_achievement(title: String) -> void:
	_ach_name.text = title
	_ach_time = ACH_TIME


func _build_achievement() -> void:
	var holder := Control.new()
	holder.anchor_right = 1.0
	holder.anchor_top = 0.6           # unter Trick-Name und Countdown, über dem Sturz-Panel
	holder.anchor_bottom = 0.6
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_TOP_WIDE)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(c)
	_ach = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(1.0, 0.82, 0.2)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	_ach.add_theme_stylebox_override("panel", sb)
	_ach.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ach.visible = false
	c.add_child(_ach)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", -2)
	_ach.add_child(vb)
	var head := _small(vb, "GEHEIMER ERFOLG FREIGESCHALTET")
	head.add_theme_color_override("font_color", Color(1.0, 0.82, 0.2))
	_ach_name = _big(vb, "")
	_ach_name.add_theme_font_size_override("font_size", 34)


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


## Handy: eigener Hilfetext, ein-/ausblenden übers Menü (☰) statt H.
func set_help(text: String) -> void:
	_help.text = text
	_help.visible = false
	_help_hint.visible = false
	_mobile_help = true
	# Sturz-Panel in die Mitte (unten sind die Tasten)
	_recovery.anchor_top = 0.58
	_recovery.anchor_bottom = 0.58
	_recovery.offset_bottom = 0
	_recovery.grow_vertical = Control.GROW_DIRECTION_BOTH
	_debug.visible = false        # Handy: Platz für die Tasten


func toggle_help() -> void:
	_help.visible = not _help.visible
	_help_hint.visible = not _help.visible and not _mobile_help


## Obergrenze für die Skalierung von Menüs und Fenstern am Desktop: sie wachsen nicht mit großen
## Auflösungen mit (man sieht mehr vom Hintergrund), nur mit der Bildschirmskalierung (HiDPI).
static func desktop_ui_max() -> float:
	var s := DisplayServer.screen_get_scale()
	if OS.get_name() == "Windows":
		s = maxf(s, DisplayServer.screen_get_dpi() / 96.0)
	return maxf(1.0, s)


func set_board(text: String) -> void:
	_board.text = text


## Leiste passend zum Bildschirm: quer eine Reihe (schmal: verkleinert), hochkant zwei Spalten über die
## ganze Breite. Aufgabenzeile, Brettzustand und Punkte-Zuwachs rücken an die echte Unterkante.
func _layout_bar() -> void:
	var vs := get_viewport().get_visible_rect().size
	var portrait := vs.x < vs.y
	if portrait != _portrait:
		_arrange_bar(portrait)
	var w := maxf(_top_bar.size.x, 1.0)
	_bar_k = clampf((vs.x - 16.0) / w, 0.3, 2.5) if portrait else minf(1.0, (vs.x - 16.0) / w)
	_top_bar.pivot_offset = Vector2(w * 0.5, 0.0)
	_top_bar.scale = Vector2(_bar_k, _bar_k)
	var fk := maxf(_bar_k, 1.0) if portrait else 1.0      # Schrift unter der Leiste wächst am Handy mit
	var bottom := bar_bottom()
	var sp: Control = _bar_panels[3]
	var r := sp.get_global_rect()
	_score_gain.offset_left = r.get_center().x - vs.x * 0.5 - 90.0
	_score_gain.offset_right = _score_gain.offset_left + 180.0
	_score_gain.offset_top = r.end.y - 4.0 * fk
	_score_gain.add_theme_font_size_override("font_size", int(22 * fk))
	var gap := 26.0 * fk if portrait else 0.0              # hochkant: Platz für den Punkte-Zuwachs links
	_task.offset_top = bottom + 2.0 * fk + gap
	_task.add_theme_font_size_override("font_size", int(22 * fk))
	_board.offset_top = bottom + gap + (34.0 * fk if _task.text != "" else 10.0 * fk)
	_board.add_theme_font_size_override("font_size", int(16 * fk))


func _arrange_bar(portrait: bool) -> void:
	_portrait = portrait
	var tp: Control = _bar_panels[0]
	var gp: Control = _bar_panels[1]
	var vp: Control = _bar_panels[2]
	var sp: Control = _bar_panels[3]
	if portrait:
		tp.reparent(_bar_cols[0], false)
		sp.reparent(_bar_cols[0], false)
		gp.reparent(_bar_cols[1], false)
		vp.reparent(_bar_cols[1], false)
		_gauge.custom_minimum_size.x = 316.0
		gp.custom_minimum_size.x = 340.0
		vp.custom_minimum_size.x = 340.0
	else:
		for i in 4:
			var p: Control = _bar_panels[i]
			p.reparent(_top_bar, false)
			_top_bar.move_child(p, i)
		_gauge.custom_minimum_size.x = 416.0
		gp.custom_minimum_size.x = 440.0
		vp.custom_minimum_size.x = 280.0
	for c: Control in _bar_cols:
		c.visible = portrait
	_top_bar.offset_left = 0.0           # neu um die Mitte wachsen lassen
	_top_bar.offset_right = 0.0


## Unterkante der HUD-Leiste (Bildschirm-Pixel).
func bar_bottom() -> float:
	return _top_bar.position.y + _top_bar.size.y * _bar_k


## Unterkante von Leiste, Aufgabenzeile und Brettzustand (darunter ist Platz, z. B. fürs Livebild).
## Die Zeile des Brettzustands ist immer eingerechnet, auch leer – sonst spränge das Livebild beim Driften.
func info_bottom() -> float:
	return _board.offset_top + _board.get_theme_font_size("font_size") * 1.4


func _process(delta: float) -> void:
	_t += delta
	_layout_bar()
	# Sturz-Panel: groß genug zum Lesen (Handy: größer), aber nie breiter als der Bildschirm
	if _recovery.visible:
		var vs := get_viewport().get_visible_rect().size
		var want := clampf(vs.y / 720.0, 1.0, 3.0) * (1.35 if _mobile_help else 1.0)
		if not _mobile_help:
			want = minf(want, desktop_ui_max())
		# Handy quer: links und rechts sind die Tasten; hochkant liegen sie darunter -> volle Breite
		var fit := (vs.x * (0.72 if _mobile_help and not _portrait else 1.0) - 24.0) / maxf(_recovery.size.x, 1.0)
		var rk := minf(want, fit)
		_recovery.pivot_offset = Vector2(_recovery.size.x * 0.5, _recovery.size.y * (0.5 if _mobile_help else 1.0))
		_recovery.scale = Vector2(rk, rk)
	_trick_time -= delta
	_trick.visible = _trick_time > 0.0
	_ach_time -= delta
	_ach.visible = _ach_time > 0.0
	if _ach.visible:
		_ach.modulate.a = clampf(_ach_time / 0.6, 0.0, 1.0) * clampf((ACH_TIME - _ach_time) / 0.3, 0.0, 1.0)
		_ach.pivot_offset = _ach.size * Vector2(0.5, 0.0)
		_ach.scale = _top_bar.scale
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


## Tempo-Anzeiger: km/h groß, darunter ein Balken bis MAX_KMH mit Marken an den Schwellen, ab denen
## etwas geht (Drift-Press); eine Marke leuchtet, sobald man schnell genug ist.
class SpeedGauge extends Control:
	const MAX_KMH := 50.0
	var font: Font
	var _kmh := 0.0

	func set_value(kmh: float) -> void:
		_kmh = kmh

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var f := font if font else get_theme_default_font()
		draw_string(f, Vector2(2, 18), "TEMPO", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.6))
		draw_string(f, Vector2(0, 22), "%d km/h" % roundi(_kmh), HORIZONTAL_ALIGNMENT_RIGHT, w - 2, 26, Color.WHITE)
		var top := 36.0
		var h := 12.0
		draw_rect(Rect2(0, top, w, h), Color(1, 1, 1, 0.12))
		var fill := clampf(_kmh / MAX_KMH, 0.0, 1.0) * w
		draw_rect(Rect2(0, top, fill, h), ACCENT)
		for m: Array in [["PRESS MAX", Rider.DPRESS_SPEED * 3.6]]:
			var x := clampf(float(m[1]) / MAX_KMH, 0.0, 1.0) * w
			var on := _kmh >= float(m[1])
			var c := Color(1.0, 0.85, 0.2) if on else Color(1, 1, 1, 0.45)
			draw_rect(Rect2(x - 1.5, top - 3.0, 3.0, h + 6.0), c)
			draw_string(f, Vector2(x - 104.0, top + h + 15.0), m[0], HORIZONTAL_ALIGNMENT_RIGHT, 100.0, 12, c)


## Großer Seilzug-Anzeiger: Segmente von grün über gelb nach rot, Spitzenwert-Marke,
## Marke RALEY am Mindest-Seilzug (leuchtet, sobald genug Zug für einen Raley da ist),
## ab 85 % blinkt der Rahmen rot (gleich reißt die Handle aus der Hand).
class TensionGauge extends Control:
	const SEGMENTS := 24
	var font: Font
	var _n := 0.0
	var _ratio := 0.0
	var _limit := Rider.CRASH_TENSION
	var _peak := 0.0
	var _t := 0.0

	func set_value(n: float, ratio: float, limit: float) -> void:
		_n = n
		_ratio = clampf(ratio, 0.0, 1.2)
		_limit = maxf(limit, 1.0)
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
		# Raley-Schwelle: Marke über den Segmenten, Name links daneben in der Kopfzeile
		var rx := clampf(Rider.RALEY_TENSION / _limit, 0.0, 1.0) * w
		var on := _n >= Rider.RALEY_TENSION
		var rc := Color(1.0, 0.85, 0.2) if on else Color(1, 1, 1, 0.45)
		draw_rect(Rect2(rx - 1.5, top - 8.0, 3.0, h + 10.0), rc)
		draw_string(f, Vector2(rx - 104.0, top - 1.0), "RALEY", HORIZONTAL_ALIGNMENT_RIGHT, 100.0, 12, rc)
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
