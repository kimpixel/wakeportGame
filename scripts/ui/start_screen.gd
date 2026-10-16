class_name StartScreen
extends CanvasLayer
## Startseite im Stil der HUD-Leiste, für Desktop und Handy (passt sich der Bildschirmgröße an).
## Oben die Wahl des Spielmodus (Competition oder Training: Wenden, Kicker, Slider, Raley); bei
## Competition darunter Terminal und Feature-Setup, sonst die Aufgaben mit ihren Medaillen.
## Im Hintergrund läuft die echte Szene: die Kamera schwenkt langsam um den See, auf beiden
## Anlagen fährt ein Fahrer. Darüber das Menü: Terminal, Feature-Setup, Einstellungen (Wetter,
## Datum, Uhrzeit, Seillänge, Anlagen-Tempo), Setup-Editor (eigene Seite, SetupEditor) und
## "Spiel starten". Tastatur: Leertaste Spiel starten, Esc schließt ein Popup.
## Features & Hacks (alle aus allen Setups, Detail in 3D) ist gebaut, steht aber nicht im Menü
## (Test: --screen=@liste); der Setup-Editor hat eine eigene Hack-Liste.

signal terminal_chosen(terminal: String)
signal setup_chosen(idx: int)
signal start_pressed
signal mode_chosen(id: String)
signal task_chosen(idx: int)
signal setups_changed(id: String, play: bool)   # Setup-Editor hat gespeichert bzw. gelöscht

const BASE_SHORT := 740.0        # so viele Einheiten hat die kurze Bildschirmseite mindestens
const BASE_LONG := 1200.0        # … und die lange
const ORBIT_SPEED := 0.09        # Tempo des Kameraschwenks (Phase rad/s)
const SEL := Color(1.0, 0.82, 0.2)
const ROPE_MIN := 12.0           # m Seillänge (Griff bis Carrier)
const ROPE_MAX := 22.0
const SPEED_MIN := 16.0          # km/h Anlagen-Tempo
const SPEED_MAX := 40.0
## Namen in der Auswahl (Reihenfolge wie Helmet.DESIGNS bzw. GameSettings.VESTS; fehlt einer: Nummer)
const HELMET_NAMES := ["Gelb / Grün", "Weiß / Schwarz", "Blau", "Orange", "Schwarz glänzend", "Pink / Türkis", "Oliv"]
const VEST_NAMES := ["Orange", "Rot", "Blau", "Grün", "Gelb", "Lila", "Schwarz", "Weiß"]

var features: FeatureSet
var weather: Weather
var cable_of := {}               # "T1"/"T2" -> CableSystem
var s_offset := {}               # wie FeatureSet.load_setup (für die Setups im Katalog)
var settings: GameSettings      # Einstellungen (von main.gd gesetzt, vor build)
var music: Music                 # eigene Musik des Spielers (von main.gd gesetzt, vor build)
var mobile := false              # Handy: keine Tastenhinweise

var _terminals: Array = []
var _terminal := "T2"
var _setup_names: Array = []
var _ui: Control
var _menu: PanelContainer
var _title_box: Control
var _result: Label
var _term_select: SelectBox
var _setup_select: SelectBox
var _setup_idx := 0
var _editor: SetupEditor
var _start_btn: Button
var _mode_select: SelectBox
var _mode_ids: Array = []         # je Zeile der Modus-Auswahl die Modus-id ("" = Überschrift)
var _split: BoxContainer          # Querformat: links Spielmodi, rechts Terminal/Setup bzw. Aufgaben
var _left: VBoxContainer          # linke Spalte (Querformat am Handy: auch Einstellungen + Start)
var _menu_v: VBoxContainer
var _bottom_row: HBoxContainer
var _comp_box: VBoxContainer     # Competition: Terminal + Feature-Setup
var _train_box: VBoxContainer    # Spielmodi: Aufgaben
var _task_select: SelectBox
var _task_info: Label
var _dim: ColorRect
var _settings: PanelContainer
var _browser: PanelContainer
var _browser_grid: VBoxContainer
var _detail: PanelContainer
var _achieve: PanelContainer      # geheime Erfolge (Liste mit Achievements.SLOTS Einträgen)
var _achieve_list: VBoxContainer
var _achieve_count: Label
var _detail_title: Label
var _detail_text: Label
var _preview: FeaturePreview
var _syncers: Array[Callable] = []
var _tab_buttons: Array[Button] = []
var _font: Font
var _k := 1.0

# Kamera im Hintergrund
var _cam: Camera3D
var _orbit := 0.0
var _focus := Vector3.ZERO
var _focus_goal := Vector3.ZERO
var _radius := 170.0
var _radius_goal := 170.0
var _basis := Basis.IDENTITY     # Ausrichtung der gewählten Anlage (für die Seeseite)

# Katalog aller Features/Hacks (beim ersten Öffnen aufgebaut)
var _catalog: Array = []         # [{name, hack: Array[FeaturePart], cable, where: Array[String], standard}]
var _catalog_sets: Array[FeatureSet] = []


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


## terminals: z. B. ["T2", "T1"] mit Anzeigenamen; setup_names: Namen aus setups/index.json
func build(terminals: Array, terminal_names: Array, setup_names: Array) -> void:
	_terminals = terminals
	_setup_names = setup_names
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Segoe UI", "Roboto", "Helvetica Neue", "Arial"])
	sf.font_weight = 700
	_font = sf

	_cam = Camera3D.new()
	_cam.fov = 50.0
	_cam.far = 3000.0
	add_child(_cam)

	_ui = Control.new()
	_ui.theme = _make_theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ui)

	# links oben: Titel und Ergebnis der letzten Runde
	var tb := VBoxContainer.new()
	tb.add_theme_constant_override("separation", 0)
	tb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(tb)
	_title_box = tb
	var t := _label("WAKE THE HACK", 44)
	t.add_theme_constant_override("outline_size", 10)
	tb.add_child(t)
	var place := _label("Wakeport Raunheim", 20, Color(1, 1, 1, 0.85))
	tb.add_child(place)
	_result = _label("", 24, SEL)
	tb.add_child(_result)

	# Menü
	_menu = _panel()
	_ui.add_child(_menu)
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 10)
	_menu.add_child(mv)
	# Querformat zwei Spalten (links Spielmodus, rechts Auswahl), hochkant untereinander
	_split = BoxContainer.new()
	_split.add_theme_constant_override("separation", 18)
	mv.add_child(_split)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.8
	_split.add_child(left)
	_left = left
	_menu_v = mv
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.add_child(right)
	# Spielmodus: Competition, darunter die Community Challenges (Wenden, Kicker, Slider …)
	left.add_child(_small("SPIELMODUS"))
	_mode_select = _select(20)
	for m: Dictionary in Training.MODES:
		_mode_ids.append(m["id"])
		_mode_select.add_item(m["name"])
		if m["id"] == Training.COMPETITION:
			_mode_ids.append("")
			_mode_select.add_header("COMMUNITY CHALLENGE")
	_mode_select.item_selected.connect(func(i: int) -> void: mode_chosen.emit(_mode_ids[i]))
	left.add_child(_mode_select)
	_comp_box = VBoxContainer.new()
	_comp_box.add_theme_constant_override("separation", 6)
	right.add_child(_comp_box)
	_train_box = VBoxContainer.new()
	_train_box.add_theme_constant_override("separation", 6)
	_train_box.visible = false
	right.add_child(_train_box)
	_train_box.add_child(_small("CHALLENGE"))
	_task_select = _select(18)
	_task_select.item_selected.connect(func(i: int) -> void: task_chosen.emit(i))
	_train_box.add_child(_task_select)
	_task_info = _label("", 16, Color(1, 1, 1, 0.85))
	_task_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_task_info.custom_minimum_size = Vector2(100, 0)
	_train_box.add_child(_task_info)
	_comp_box.add_child(_small("TERMINAL"))
	_term_select = _select(20)
	for n: String in terminal_names:
		_term_select.add_item(n)
	_term_select.item_selected.connect(func(i: int) -> void: terminal_chosen.emit(_terminals[i]))
	_comp_box.add_child(_term_select)
	_comp_box.add_child(_small("FEATURE-SETUP"))
	_setup_select = _select(18)
	_setup_select.item_selected.connect(func(i: int) -> void: setup_chosen.emit(i))
	_comp_box.add_child(_setup_select)
	set_setup_names(setup_names)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	mv.add_child(row)
	_bottom_row = row
	var eb := _button("Einstellungen", 20)
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eb.pressed.connect(func() -> void: _show_popup(_settings))
	row.add_child(eb)
	var ed := _button("Setup-Editor", 20)
	ed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ed.pressed.connect(open_editor)
	row.add_child(ed)
	var ab := _button("Erfolge", 20)
	ab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ab.pressed.connect(_open_achievements)
	row.add_child(ab)
	_start_btn = _button("SPIEL STARTEN", 30, true)
	_start_btn.custom_minimum_size.y = 72
	_start_btn.pressed.connect(func() -> void: start_pressed.emit())
	mv.add_child(_start_btn)

	# Popups über abgedunkeltem Hintergrund
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.visible = false
	_dim.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_close_popups())
	_ui.add_child(_dim)
	_build_settings()
	_build_browser()
	_build_detail()
	_build_achievements()
	_editor = SetupEditor.new()
	_editor.host = self
	_editor.visible = false
	_ui.add_child(_editor)
	_editor.build()
	_editor.saved.connect(func(id: String, play: bool) -> void: setups_changed.emit(id, play))
	_editor.closed.connect(func() -> void: get_viewport().disable_3d = false)


## Spielmodus und Challenge anzeigen (Auswahl mit Pokalen, kurzes Ziel).
func refresh_mode(mode_id: String, task_idx: int) -> void:
	_mode_select.select(_mode_ids.find(mode_id))
	var comp := mode_id == Training.COMPETITION
	_comp_box.visible = comp
	_train_box.visible = not comp
	_start_btn.text = "SPIEL STARTEN" if comp else "CHALLENGE STARTEN"
	if not comp:
		var list := Training.tasks(mode_id)
		_task_select.clear()
		for i in list.size():
			var t: Dictionary = list[i]
			_task_select.add_item("%d  %s" % [i + 1, t["name"]],
				Trophy.texture(clampi(int(Training.best(mode_id, t["id"])[0]), 0, 3)))
		_task_select.select(clampi(task_idx, 0, list.size() - 1))
		var t: Dictionary = list[clampi(task_idx, 0, list.size() - 1)]
		var best := Training.best(mode_id, t["id"])
		var line: String = t["goal"]
		if not is_nan(float(best[1])):
			line += "\nBestwert: " + Training.format_value(t, best[1])
		_task_info.text = line
	_layout()


## Auswahl der Feature-Setups (neu füllen, z. B. nach Speichern im Setup-Editor).
func set_setup_names(setup_names: Array) -> void:
	_setup_names = setup_names
	_setup_select.clear()
	for n: String in setup_names:
		_setup_select.add_item(n.get_slice(" (", 0))     # ohne "(Datum ?)"
	_setup_select.select(clampi(_setup_idx, 0, setup_names.size() - 1))
	if is_inside_tree():
		_layout()


## Setup-Editor öffnen (Ausgangspunkt: das gewählte Setup). Die Szene dahinter wird so lange
## nicht gerendert.
func open_editor() -> void:
	_close_popups()
	Analytics.count("editor")
	var list := FeatureSet.list_setups()
	_editor.open(list[clampi(_setup_idx, 0, list.size() - 1)], _terminal)
	get_viewport().disable_3d = true


func editor_open() -> bool:
	return _editor != null and _editor.visible


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


# ---------------------------------------------------------------- Stil

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font = _font
	th.default_font_size = 20
	var normal := _box(Color(0.12, 0.15, 0.18), 12)
	var hover := _box(Color(0.2, 0.24, 0.28), 12)
	var down := _box(Color(Hud.ACCENT, 0.85), 12)
	for st: String in ["normal", "focus"]:
		th.set_stylebox(st, "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", down)
	th.set_stylebox("hover_pressed", "Button", down)
	th.set_color("font_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color(0.05, 0.08, 0.05))
	th.set_color("font_hover_pressed_color", "Button", Color(0.05, 0.08, 0.05))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_stylebox("panel", "PanelContainer", _box(Color(0.05, 0.07, 0.09, 0.82), 16, 18))
	# Schieber: dicke Spur, großer Griff (gut mit dem Finger)
	var track := _box(Color(1, 1, 1, 0.15), 6)
	track.content_margin_top = 6
	track.content_margin_bottom = 6
	th.set_stylebox("slider", "HSlider", track)
	var fill := _box(Color(Hud.ACCENT, 0.8), 6)
	fill.content_margin_top = 6
	fill.content_margin_bottom = 6
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var grab := _knob(Color.WHITE)
	th.set_icon("grabber", "HSlider", grab)
	th.set_icon("grabber_highlight", "HSlider", _knob(Hud.ACCENT.lightened(0.4)))
	th.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	return th


func _box(c: Color, r: int, margin := 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	sb.border_width_bottom = 3
	sb.border_color = Hud.ACCENT
	sb.content_margin_left = margin + 4
	sb.content_margin_right = margin + 4
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _knob(c: Color) -> ImageTexture:
	var n := 36
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length()
			img.set_pixel(x, y, Color(c, clampf(n * 0.5 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	return p


func _button(text: String, size: int, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.custom_minimum_size = Vector2(0, 48)
	b.focus_mode = Control.FOCUS_NONE
	if primary:
		var sb := _box(Hud.ACCENT, 14)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", _box(Hud.ACCENT.lightened(0.15), 14))
		b.add_theme_stylebox_override("pressed", _box(Hud.ACCENT.darkened(0.2), 14))
		b.add_theme_color_override("font_color", Color(0.04, 0.07, 0.03))
		b.add_theme_color_override("font_hover_color", Color(0.04, 0.07, 0.03))
	return b


## Auswahlbox (Liste öffnet über der Oberfläche, am Handy mit großen Zeilen).
func _select(size: int) -> SelectBox:
	var sb := SelectBox.new()
	sb.font_size = size
	sb.host = _ui
	return sb


func _label(text: String, size: int, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _small(text: String) -> Label:
	return _label(text, 15, Color(1, 1, 1, 0.6))


# ---------------------------------------------------------------- Layout

## Alles in "Einheiten" bauen und als Ganzes skalieren: auf dem Handy werden Tasten und
## Schrift so groß wie nötig, im Hochformat steht das Menü unten statt links.
func _layout() -> void:
	if _ui == null or not is_inside_tree():
		return
	var vp := get_viewport().get_visible_rect().size
	# Handy: größer (Fingerbreite), dafür weniger Platz
	var short := BASE_SHORT * (0.7 if mobile else 1.0)
	var long := BASE_LONG * (0.7 if mobile else 1.0)
	_k = clampf(minf(minf(vp.x, vp.y) / short, maxf(vp.x, vp.y) / long), 0.4, 4.0)
	var size := vp / _k
	_ui.scale = Vector2(_k, _k)
	_ui.size = size
	_ui.position = Vector2.ZERO
	var m := 20.0
	var portrait := size.x < 760.0
	_title_box.position = Vector2(m, m)
	_title_box.size = Vector2(size.x - 2.0 * m, 0)
	var w := size.x - 2.0 * m if portrait else clampf(size.x * 0.6, 640.0, 860.0)
	var low := not portrait and size.y < 620.0        # Handy quer: breiteres, flacheres Menü
	if low:
		w = minf(size.x * 0.66, 860.0)
	_menu.custom_minimum_size = Vector2(w, 0)
	_menu.size = Vector2(w, 0)
	_split.vertical = portrait
	# Handy quer (flach): Einstellungen/Editor und Start in die linke Spalte, sonst zu hoch
	var host: VBoxContainer = _left if low else _menu_v
	for c: Control in [_bottom_row, _start_btn]:
		if c.get_parent() != host:
			c.reparent(host)
	_start_btn.custom_minimum_size.y = 56 if low else 72
	await get_tree().process_frame
	var h := _menu.get_combined_minimum_size().y
	_menu.size = Vector2(w, h)
	if portrait:
		_menu.position = Vector2(m, size.y - m - h)
	else:
		_menu.position = Vector2(m, maxf(size.y - m - h, 110.0))
	_dim.position = Vector2.ZERO
	_dim.size = size
	for p: PanelContainer in [_settings, _browser, _detail, _achieve]:
		_fit_popup(p, size)
	_editor.layout(size, _k)


func _fit_popup(p: PanelContainer, size: Vector2) -> void:
	var w := minf(size.x - 32.0, 760.0)
	var h := minf(size.y - 32.0, 640.0)
	p.custom_minimum_size = Vector2(w, 0)
	p.size = Vector2(w, h)
	p.position = (size - Vector2(w, h)) * 0.5


# ---------------------------------------------------------------- Popups

func _popup_frame(title: String) -> Array:
	var p := _panel()
	p.add_theme_stylebox_override("panel", _box(Color(0.06, 0.08, 0.1, 0.97), 16, 18))
	p.visible = false
	_ui.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var l := _label(title, 28, SEL)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	var x := _button("✕", 24)
	x.custom_minimum_size = Vector2(56, 52)
	x.pressed.connect(_close_popups)
	head.add_child(x)
	return [p, v, l]


func _show_popup(p: PanelContainer) -> void:
	for q: PanelContainer in [_settings, _browser, _detail, _achieve]:
		q.visible = q == p
	_dim.visible = true


func _close_popups() -> void:
	if _detail.visible and _detail.get_meta("from_browser", false):
		_show_popup(_browser)
		return
	for q: PanelContainer in [_settings, _browser, _detail, _achieve]:
		q.visible = false
	_dim.visible = false


func _popup_open() -> bool:
	return _dim.visible


## Einstellungen in fünf Reitern: Spiel, Fahrer, Welt, Technik, Musik. Alles außer Wetter/Uhrzeit
## landet in GameSettings (gespeichert); main.gd wendet die Werte an.
func _build_settings() -> void:
	var f := _popup_frame("EINSTELLUNGEN")
	_settings = f[0]
	var v: VBoxContainer = f[1]
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var holder := VBoxContainer.new()
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(holder)
	var tg := ButtonGroup.new()
	var pages: Array[VBoxContainer] = []
	for title: String in ["Spiel", "Fahrer", "Welt", "Technik", "Musik"]:
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 10)
		holder.add_child(page)
		pages.append(page)
		var b := _button(title, 14 if mobile else 19)
		b.toggle_mode = true
		b.button_group = tg
		b.clip_text = true            # fünf Reiter: am Handy hochkant schmaler werden dürfen
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := pages.size() - 1
		b.pressed.connect(func() -> void:
			for i in pages.size():
				pages[i].visible = i == idx
			scroll.scroll_vertical = 0)
		tabs.add_child(b)
		_tab_buttons.append(b)
		if idx == 0:
			b.button_pressed = true
		else:
			page.visible = false
	if settings:
		_page_game(pages[0])
		_page_rider(pages[1])
	_page_world(pages[2])
	if settings:
		_page_tech(pages[3])
	if settings and music:
		_page_music(pages[4])
	var ok := _button("FERTIG", 24, true)
	ok.pressed.connect(_close_popups)
	v.add_child(ok)
	sync_settings()


func _page_game(p: VBoxContainer) -> void:
	var modes: Array = []
	var secs: Array = []
	for m: Array in GameSettings.MODES:
		secs.append(m[0])
		modes.append(m[1])
	_opt_row(p, "COMPETITION: RUNDENLÄNGE", modes, "mode", secs)
	p.add_child(_small("HILFEN   (je ausgeschaltete Hilfe +15 % auf alle Tricks)"))
	_opt_row(p, "Auf dem Slider einloggen", ["An", "Aus"], "assist_lock", [true, false])
	_opt_row(p, "Überschlag dreht von selbst zu Ende", ["An", "Aus"], "assist_flip", [true, false])
	_opt_row(p, "SEILZUG-GRENZE   (ab wann die Handle aus der Hand gerissen wird; im Spiel G)",
		["Locker", "Normal", "Streng", "Aus"], "grip", [0, 1, 2, 3])


func _page_rider(p: VBoxContainer) -> void:
	var boards: Array = []
	for i in BoardLibrary.count():
		boards.append(BoardLibrary.design(i)["name"])
	_opt_row(p, "BRETT", boards, "board")
	_opt_row(p, "STANCE   (Regular: links vorne)", ["Regular", "Goofy"], "goofy", [false, true])
	var helmets: Array = []
	for d: Dictionary in Helmet.DESIGNS:
		helmets.append([d["left"], d["right"]])
	_swatch_row(p, "HELM", helmets, "helmet", HELMET_NAMES)
	var vests: Array = []
	for c: Color in GameSettings.VESTS:
		vests.append([c, c])
	_swatch_row(p, "WESTE", vests, "vest", VEST_NAMES)


func _page_world(p: VBoxContainer) -> void:
	if weather:
		var ws := _select(18)
		for n: String in weather.preset_names():
			ws.add_item(n)
		ws.item_selected.connect(func(i: int) -> void: weather.set_preset(i))
		_row(p, "WETTER   (jeder Start: sonniger Sommertag 10:30)").add_child(ws)
		var date_l := _small("DATUM")
		var day_s := _slider(1.0, 365.0, 1.0)
		_row(p, "", date_l).add_child(day_s)
		day_s.value_changed.connect(func(val: float) -> void:
			if int(val) != weather.day:
				weather.set_day(int(val)))
		var time_l := _small("UHRZEIT")
		var hour_s := _slider(0.0, 24.0, 0.25)
		_row(p, "", time_l).add_child(hour_s)
		hour_s.value_changed.connect(func(val: float) -> void:
			if absf(val - weather.hour) > 0.01:
				weather.set_hour(val))
		var now := _button("Jetzt  (live)", 18)
		now.tooltip_text = "Heute, aktuelle Uhrzeit und Wetter am See"
		now.pressed.connect(weather.set_now)
		p.add_child(now)
		var update := func() -> void:
			ws.select(weather.preset)
			day_s.set_value_no_signal(weather.day)
			hour_s.set_value_no_signal(weather.hour)
			date_l.text = "DATUM   " + weather.date_text()
			time_l.text = "UHRZEIT   " + weather.time_text() + ("   (live)" if weather.live else "")
		weather.changed.connect(update)
		update.call()
	if settings == null:
		return
	p.add_child(_label("", 4))
	_slider_row(p, "SEILLÄNGE", "rope", ROPE_MIN, ROPE_MAX, 0.5, func(x: float) -> String: return "%.1f m" % x)
	_slider_row(p, "ANLAGEN-TEMPO", "speed", SPEED_MIN, SPEED_MAX, 1.0, func(x: float) -> String: return "%d km/h" % roundi(x))
	var std := _button("Seil und Tempo: Standard  (16 m, 30 km/h)", 17)
	std.pressed.connect(func() -> void:
		settings.set_v("rope", Rider.ROPE_LENGTH)
		settings.set_v("speed", 30.0)
		sync_settings())
	p.add_child(std)
	_opt_row(p, "FLUGZEUGE", ["Aus", "Normal", "Rush Hour"], "planes", [0, 1, 2])
	_opt_row(p, "FAHRER AUF DER ANDEREN ANLAGE", ["An", "Aus"], "npc", [true, false])
	_opt_row(p, "CHALLENGE: FILMTEAM", ["Zufall", "Boot", "Drohne", "Aus"], "film", [0, 1, 2, 3])


func _page_tech(p: VBoxContainer) -> void:
	_opt_row(p, "GRAFIK   (niedrig = flüssiger, schont den Akku)", ["Niedrig", "Mittel", "Hoch"], "quality", [0, 1, 2])
	var pct := func(x: float) -> String: return "%d %%" % roundi(x * 100.0)
	_slider_row(p, "LAUTSTÄRKE EFFEKTE", "vol_fx", 0.0, 1.0, 0.05, pct)
	_slider_row(p, "LAUTSTÄRKE JUBEL", "vol_cheer", 0.0, 1.0, 0.05, pct)
	_slider_row(p, "LAUTSTÄRKE FLUGZEUGE", "vol_planes", 0.0, 1.0, 0.05, pct)
	_opt_row(p, "KAMERA", ["Verfolger", "Orbit", "Ufer"], "cam_mode", [0, 1, 2])
	_slider_row(p, "KAMERA-ABSTAND", "cam_dist", 4.0, 14.0, 0.5, func(x: float) -> String: return "%.1f m" % x)
	if mobile:
		_opt_row(p, "LENKUNG", ["Gyro (Handy neigen)", "Tasten (Steuerkreuz)"], "steer", [0, 1])
		_opt_row(p, "NEIGUNG ZUM LENKEN", ["Wenig empfindlich", "Mittel", "Sehr empfindlich"], "tilt", [0, 1, 2])
		_opt_row(p, "NEIGUNG UMKEHREN", ["Nein", "Ja"], "tilt_invert", [false, true])


## Musik: Spiel-Musik (lizenzfrei, Pixabay) und/oder eigene Titel des Spielers.
func _page_music(p: VBoxContainer) -> void:
	var info := _label("Spiel-Musik: lizenzfreie Titel von Pixabay. Dazu kannst du eigene Titel wählen (MP3, OGG, WAV) – sie bleiben "
		+ "auf diesem Gerät bzw. in diesem Browser gespeichert. Alles läuft gemischt im Hintergrund.", 16, Color(1, 1, 1, 0.8))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(info)
	_opt_row(p, "MUSIK", ["An", "Aus"], "music", [true, false])
	_opt_row(p, "QUELLE", ["Spiel-Musik", "Eigene Titel", "Beides"], "music_src", [0, 1, 2])
	var pct := func(x: float) -> String: return "%d %%" % roundi(x * 100.0)
	_slider_row(p, "LAUTSTÄRKE MUSIK", "vol_music", 0.0, 1.0, 0.05, pct)
	var status := _label("", 18)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(status)
	var grid := GridContainer.new()
	grid.columns = 2 if mobile else 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	p.add_child(grid)
	var add := _button("Titel hinzufügen", 18, true)
	add.pressed.connect(music.pick_files)
	var nxt := _button("Nächster Titel", 18)
	nxt.pressed.connect(music.next)
	var clr := _button("Eigene entfernen", 18)
	clr.pressed.connect(music.clear_all)
	for b: Button in [add, nxt, clr]:
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(b)
	var credits := _small("")
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var update := func() -> void:
		var n := music.tracks.size()
		status.text = "%d Spiel-Musik, %d eigene" % [music.game_tracks.size(), n]
		if music.current != "":
			status.text += "   ♪ " + music.current
		elif music.loading != "":
			status.text += "   lädt: " + music.loading
		nxt.disabled = music.playlist().is_empty() or not music.enabled
		clr.disabled = n == 0
		credits.text = "" if music.game_tracks.is_empty() else \
			"Danke für die Spiel-Musik (Pixabay): " + ", ".join(music.game_artists())
	music.changed.connect(update)
	p.add_child(_label("", 4))
	p.add_child(credits)
	update.call()
	var alt := _small("ODER NEBENHER HÖREN, z. B. mit Spotify (dann hier Musik aus)")
	alt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(alt)
	var open := _button("Skate-Punk bei Spotify", 17)
	open.pressed.connect(func() -> void: OS.shell_open(Music.PLAYLIST_URL))
	p.add_child(open)


## Zeile einer Einstellung: links der Titel (bricht um), rechts das Bedienelement (wird angehängt).
## label: eigenes Titel-Label (z. B. mit Wert, den man später ändert), sonst eines aus title.
func _row(p: VBoxContainer, title: String, label: Label = null) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)
	var l := label if label else _small(title)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_stretch_ratio = 0.7
	l.custom_minimum_size = Vector2(80, 0)
	row.add_child(l)
	return row


## Auswahl als Auswahlbox. values: gespeicherte Werte je Zeile (leer = Index), icons: Bild je Zeile.
func _opt_row(p: VBoxContainer, title: String, labels: Array, key: String, values: Array = [], icons: Array = []) -> void:
	var sel := _select(18)
	for i in labels.size():
		sel.add_item(labels[i], icons[i] if i < icons.size() else null)
	sel.item_selected.connect(func(i: int) -> void:
		settings.set_v(key, values[i] if i < values.size() else i))
	_row(p, title).add_child(sel)
	_syncers.append(func() -> void:
		var cur: Variant = settings.get_v(key)
		for i in labels.size():
			if _same(cur, values[i] if i < values.size() else i):
				sel.select(i))


## Gleicher Einstellungswert? (Zahlen aus der Datei können als float zurückkommen)
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


## Farbauswahl als Auswahlbox: je Zeile ein rundes Farbfeld, innen ein zweites (z. B. Helm-Design).
func _swatch_row(p: VBoxContainer, title: String, colors: Array, key: String, names: Array) -> void:
	var labels: Array = []
	var icons: Array = []
	for i in colors.size():
		labels.append(names[i] if i < names.size() else "Nr. %d" % (i + 1))
		icons.append(_swatch(colors[i][0], colors[i][1]))
	_opt_row(p, title, labels, key, [], icons)


func _swatch(outer: Color, inner: Color) -> ImageTexture:
	var n := 30
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5)
			var a := clampf(n * 0.5 - d.length(), 0.0, 1.0)
			var c := inner if absf(d.x) < 5.5 and absf(d.y) < 5.5 else outer
			if d.length() > n * 0.5 - 2.0:
				c = Color(1, 1, 1, 0.6)                 # heller Rand (auch dunkle Farben sichtbar)
			img.set_pixel(x, y, Color(c, a))
	return ImageTexture.create_from_image(img)


func _slider_row(p: VBoxContainer, title: String, key: String, lo: float, hi: float, step: float, fmt: Callable) -> void:
	var l := _small(title)
	var s := _slider(lo, hi, step)
	_row(p, "", l).add_child(s)
	var show := func() -> void: l.text = "%s   %s" % [title, fmt.call(s.value)]
	s.value_changed.connect(func(val: float) -> void:
		show.call()
		settings.set_v(key, val))
	_syncers.append(func() -> void:
		s.set_value_no_signal(float(settings.get_v(key)))
		show.call())


## Anzeige der Einstellungen auf den aktuellen Stand bringen (z. B. nach + / − im Spiel).
func sync_settings() -> void:
	if settings == null:
		return
	for f: Callable in _syncers:
		f.call()


func _slider(lo: float, hi: float, step: float) -> HSlider:
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.custom_minimum_size = Vector2(0, 44)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sl.focus_mode = Control.FOCUS_NONE
	return sl


## Features & Hacks: Liste aller Features und Hacks aus allen Setups.
func _build_browser() -> void:
	var f := _popup_frame("FEATURES & HACKS")
	_browser = f[0]
	var v: VBoxContainer = f[1]
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_browser_grid = VBoxContainer.new()
	_browser_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_grid.add_theme_constant_override("separation", 10)
	scroll.add_child(_browser_grid)


func _build_detail() -> void:
	var f := _popup_frame("")
	_detail = f[0]
	_detail_title = f[2]
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var v: VBoxContainer = f[1]
	# eigener Rahmen: die 3D-Vorschau übernimmt sonst die Größe ihres Bildes und wächst mit
	var frame := Control.new()
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 160)
	frame.clip_contents = true
	v.add_child(frame)
	_preview = FeaturePreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_child(_preview)
	_detail_text = _label("", 16, Color(1, 1, 1, 0.8))
	_detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_detail_text)


## Geheime Erfolge: SLOTS Zeilen, noch nicht erreichte ausgegraut und ohne Text.
func _build_achievements() -> void:
	var f := _popup_frame("GEHEIME ERFOLGE")
	_achieve = f[0]
	var v: VBoxContainer = f[1]
	_achieve_count = _small("")
	v.add_child(_achieve_count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_achieve_list = VBoxContainer.new()
	_achieve_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_achieve_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_achieve_list)


func _open_achievements() -> void:
	for c in _achieve_list.get_children():
		c.queue_free()
	var n := Achievements.count_unlocked()
	_achieve_count.text = "%d von %d entdeckt – was es gibt, siehst du erst, wenn du es geschafft hast." 		% [n, Achievements.SLOTS]
	_achieve_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for i in Achievements.SLOTS:
		var a: Dictionary = Achievements.LIST[i] if i < Achievements.LIST.size() else {}
		var date := Achievements.unlocked_at(a["id"]) if not a.is_empty() else ""
		_achieve_list.add_child(_achievement_row(i + 1, a, date))
	_show_popup(_achieve)


func _achievement_row(nr: int, a: Dictionary, date: String) -> Control:
	var open := date != ""
	var p := PanelContainer.new()
	var sb := _box(Color(0.16, 0.14, 0.06, 0.95) if open else Color(1, 1, 1, 0.05), 10, 8)
	sb.border_color = SEL if open else Color(1, 1, 1, 0.12)
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var badge := _label(str(nr) if open else "?", 26, Color(0.1, 0.08, 0.02) if open else Color(1, 1, 1, 0.3))
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.custom_minimum_size = Vector2(46, 46)
	badge.add_theme_constant_override("outline_size", 0)
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = SEL if open else Color(1, 1, 1, 0.08)
	bsb.set_corner_radius_all(23)
	badge.add_theme_stylebox_override("normal", bsb)
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	if open:
		v.add_child(_label(a["name"], 22, SEL))
		var t := _label(a["text"], 16, Color(1, 1, 1, 0.85))
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		v.add_child(_label("erreicht am " + date, 14, Color(1, 1, 1, 0.5)))
	else:
		v.add_child(_label("Geheim", 22, Color(1, 1, 1, 0.35)))
		v.add_child(_label("Noch nicht entdeckt", 16, Color(1, 1, 1, 0.25)))
	return p


func _open_browser() -> void:
	if _catalog.is_empty():
		_build_catalog()
		_fill_browser()
	_show_popup(_browser)


## Katalog: jedes Setup einmal unsichtbar aufbauen, Teile beider Anlagen zu Hacks gruppieren
## und gleiche Features/Hacks zusammenfassen (mit allen Fundstellen).
func _build_catalog() -> void:
	var by_sig := {}
	for e: Dictionary in FeatureSet.list_setups():
		var fs := FeatureSet.new()
		fs.visible = false
		fs.colliders = false
		add_child(fs)
		fs.load_setup(e["file"], cable_of, s_offset)
		_catalog_sets.append(fs)
		for t: String in _terminals:
			var c: CableSystem = cable_of[t]
			for hack: Array in Hacks.group(fs.parts_of(c), c):
				# gängige Features nach Namen zusammenfassen, Hacks nach Anordnung
				var sig := Hacks.hack_name(hack) if Hacks.is_standard(hack) else Hacks.signature(hack, c)
				var where := "%s (%s)" % [e["name"], t]
				if by_sig.has(sig):
					by_sig[sig]["where"].append(where)
				else:
					by_sig[sig] = {"name": Hacks.hack_name(hack), "hack": hack, "cable": c,
						"where": [where], "standard": Hacks.is_standard(hack)}
	_catalog = by_sig.values()
	# gleichnamige Hacks (andere Anordnung) mit ihrem Setup unterscheiden
	var count := {}
	for e: Dictionary in _catalog:
		count[e["name"]] = count.get(e["name"], 0) + 1
	for e: Dictionary in _catalog:
		e["label"] = (e["name"] as String).trim_prefix("Hack: ")
		if count[e["name"]] > 1:
			e["label"] += "  ·  " + (e["where"][0] as String).replace(" (Datum ?)", "").replace(" (Jahr ?)", "")
	_catalog.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["name"].naturalnocasecmp_to(b["name"]) < 0)


func _fill_browser() -> void:
	for c in _browser_grid.get_children():
		c.queue_free()
	for section: Array in [["FEATURES", true], ["HACKS", false]]:
		_browser_grid.add_child(_small(section[0]))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_browser_grid.add_child(grid)
		for e: Dictionary in _catalog:
			if e["standard"] != section[1]:
				continue
			var name: String = e["label"]
			var b := _button(name, 17)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = name
			b.pressed.connect(func() -> void: _open_detail(e, true))
			grid.add_child(b)


func _open_detail(e: Dictionary, from_browser: bool) -> void:
	var hack: Array = e["hack"]
	_detail_title.text = e["name"]
	_detail.set_meta("from_browser", from_browser)
	_show_popup(_detail)
	_preview.show_parts(hack, e["cable"])
	var lines: Array[String] = []
	for p: FeaturePart in hack:
		var h := p.height
		if not p.profile.is_empty():
			h = 0.0
			for pt: Array in p.profile:
				h = maxf(h, float(pt[1]))
		lines.append("%s   %.1f × %.1f m, Höhe %.2f m" % [p.display_name, p.length, p.width, h])
	var where: Array = e["where"]
	lines.append("Im Setup: " + ", ".join(where))
	_detail_text.text = "\n".join(lines)


# ---------------------------------------------------------------- Ablauf

## Auswahl und Kamera auf den aktuellen Stand bringen (nach Öffnen bzw. Wechsel).
func refresh(terminal: String, setup_idx: int, _focus_idx := -1) -> void:
	_terminal = terminal
	_setup_idx = setup_idx
	var ti := _terminals.find(terminal)
	if ti >= 0:
		_term_select.select(ti)
	_setup_select.select(setup_idx)
	# Kamera schwenkt auf die gewählte Anlage
	var c: CableSystem = cable_of[terminal]
	_focus_goal = c.global_transform * Vector3(0.0, 0.0, (c.mast_a_z + c.mast_b_z) * 0.5)
	_radius_goal = absf(c.mast_b_z - c.mast_a_z) * 0.55 + 30.0
	_basis = c.global_basis.orthonormalized()
	if _focus == Vector3.ZERO:
		_focus = _focus_goal
		_radius = _radius_goal
	_layout()


## Startseite wird sichtbar: Hintergrundkamera übernimmt.
func activate() -> void:
	_cam.current = true
	_close_popups()
	_layout()


## Feature/Hack mit diesem Namensteil im Popup zeigen (Test: --screen=NAME).
func select_by_name(prefix: String) -> void:
	if prefix.begins_with("@editor"):
		open_editor()
		_editor.run_test(prefix.substr(7))
		return
	if prefix == "@liste":
		_open_browser()
		return
	if prefix == "@erfolge":
		_open_achievements()
		return
	if prefix.begins_with("@auswahl"):             # Liste offen: Spielmodi, @auswahl2 Challenges
		await get_tree().process_frame
		await get_tree().process_frame
		(_task_select if prefix == "@auswahl2" else _mode_select).pressed.emit()
		return
	if prefix.begins_with("@einstellungen"):
		_show_popup(_settings)
		var tab := prefix.substr(14).to_int()          # z. B. @einstellungen2 = Reiter "Welt"
		if tab > 0 and tab < _tab_buttons.size():
			_tab_buttons[tab].button_pressed = true
			_tab_buttons[tab].pressed.emit()
		return
	if _catalog.is_empty():
		_build_catalog()
		_fill_browser()
	for e: Dictionary in _catalog:
		if (e["name"] as String).to_lower().contains(prefix.to_lower()):
			_open_detail(e, false)
			return


## Ergebnis der letzten Runde unter dem Titel.
func set_result(text: String) -> void:
	_result.text = text


func _process(delta: float) -> void:
	if not visible or _cam == null:
		return
	# Popups wachsen mit ihrem Inhalt (z. B. Text beim ersten Umbruch), schrumpfen aber nicht
	# von selbst: Größe jedes Bild festhalten
	if _dim.visible:
		for p: PanelContainer in [_settings, _browser, _detail, _achieve]:
			if p.visible:
				_fit_popup(p, _ui.size)
	_orbit += ORBIT_SPEED * delta
	_focus = _focus.lerp(_focus_goal, 1.0 - exp(-delta * 0.8))
	_radius = lerpf(_radius, _radius_goal, 1.0 - exp(-delta * 0.8))
	# langsamer Schwenk um die Anlage, Höhe atmet leicht mit
	# Schwenk von der Seeseite (lokal -x der Anlage) hin und her, nie über Land
	var phi := 1.05 * sin(_orbit)
	var side := _basis * Vector3(-cos(phi), 0.0, sin(phi))
	var h := 34.0 + 12.0 * sin(_orbit * 1.7)
	var pos := _focus + side * _radius + Vector3.UP * h
	_cam.look_at_from_position(pos, _focus + Vector3(0.0, 2.0, 0.0), Vector3.UP)


# ---------------------------------------------------------------- Tastatur

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.is_echo() or editor_open():
		return
	var k := (event as InputEventKey).physical_keycode
	match k:
		KEY_ESCAPE:
			if not _popup_open():
				return
			_close_popups()
		KEY_SPACE, KEY_TAB:
			if _popup_open():
				_close_popups()
			start_pressed.emit()
		_:
			return
	get_viewport().set_input_as_handled()
