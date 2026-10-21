class_name TaskPanel
extends CanvasLayer
## Fenster der Spielmodi im HUD-Stil: vor dem ersten Versuch die Aufgabe (Ziel, Steuerung, Tipp,
## Schwellen für Bronze/Silber/Gold), nach jedem Versuch das Ergebnis. Tasten: Enter/PS = Los bzw.
## Nochmal (Leertaste/Kreuz drückt den Knopf mit Fokus, anfangs Los), N = nächste Aufgabe,
## Esc/Kreis = Startseite. Läuft auch während der Pause.

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
var _rank: Label                 # Rangliste: Platz (Ergebnis)
var leaderboard: Leaderboard     # main.gd: für das Namensfeld (vor add_child setzen)
var _name: NameField             # Ergebnis ohne gespeicherten Namen: Name gleich hier eintragen
var _name_tip: Label
var _photos: HBoxContainer       # Fotos des Filmteams vom Versuch (Ergebnis)
var _medals: Array[Medal] = []
var _medal_labels: Array[Label] = []
var _go: Button
var _mgrid: GridContainer        # Medaillen-Schwellen (hochkant untereinander)
var _next: Button
var _home: Button
var _font: Font


## Pokal (Bild aus Trophy – Sonderzeichen fehlen in der Web-Schrift).
class Medal extends Control:
	var level := 0                 # 0 keiner, 1 Bronze, 2 Silber, 3 Gold

	func _draw() -> void:
		var n := minf(size.x, size.y)
		draw_texture_rect(Trophy.texture(level, 96), Rect2((size - Vector2(n, n)) * 0.5, Vector2(n, n)), false)

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
	_photos = HBoxContainer.new()
	_photos.add_theme_constant_override("separation", 8)
	_photos.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(_photos)
	_text = _label(19, Color(1, 1, 1, 0.9))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_text)
	_rank = _label(18, Hud.ACCENT)
	_rank.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rank.visible = false
	v.add_child(_rank)
	# noch kein Name: gleich hier eintragen (Ergebnis zählt sonst als „Anonym #…“)
	_name = NameField.new()
	_name.mobile = mobile
	_name.font = _font
	_name.visible = false
	v.add_child(_name)
	var nb := _button("Speichern", false)
	nb.size_flags_horizontal = Control.SIZE_SHRINK_END
	nb.custom_minimum_size = Vector2(130, 48)
	_name.build(20, "DEIN NAME", nb)
	_name.saved.connect(func(n: String) -> void:
		_name.visible = false
		var re := RegEx.create_from_string("Anonym #\\w+")
		_rank.text = re.sub(_rank.text, n, true)
		_name_tip.text = "Gespeichert – du stehst jetzt als „%s“ in der Rangliste." % n
		_name_tip.visible = true
		_layout())
	_name_tip = _label(15, Color(1, 1, 1, 0.7))
	_name_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_tip.visible = false
	v.add_child(_name_tip)
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
	_go = _button(tr("LOS"), true)
	_go.pressed.connect(func() -> void: go_pressed.emit())
	brow.add_child(_go)
	_next = _button(tr("Nächste Challenge"), false)
	_next.pressed.connect(func() -> void: next_pressed.emit())
	brow.add_child(_next)
	_home = _button(tr("Startseite"), false)
	_home.pressed.connect(func() -> void: home_pressed.emit())
	brow.add_child(_home)
	get_viewport().size_changed.connect(_layout)
	MenuNav.add_scope(_dim, 20, _go)


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
	var sb := StyleBoxFlat.new()
	sb.bg_color = Hud.ACCENT if primary else Color(0.14, 0.17, 0.2)
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	for st: String in ["normal", "hover", "pressed"]:
		var s2 := sb.duplicate() as StyleBoxFlat
		if st == "hover":
			s2.bg_color = s2.bg_color.lightened(0.12)
		elif st == "pressed":
			s2.bg_color = s2.bg_color.darkened(0.2)
		b.add_theme_stylebox_override(st, s2)
	b.add_theme_stylebox_override("focus", MenuNav.focus_box())
	var fc := Color(0.04, 0.07, 0.03) if primary else Color.WHITE
	for k: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, fc)
	return b


## Aufgabe vorstellen (vor dem ersten Versuch). best: [Medaille, Bestwert].
func show_intro(mode_name: String, idx: int, count: int, task: Dictionary, best: Array, has_next: bool) -> void:
	_fill(mode_name, idx, count, task, best, has_next)
	_result_row.visible = false
	_rank.visible = false
	_name.visible = false
	_name_tip.visible = false
	_set_photos([])
	var keys: String = tr(task.get("keys_mobile", task["keys"]) if mobile else task["keys"])
	var goal: String = tr(task["goal"])
	var combo: Array = task.get("combo", [])
	for i in combo.size():       # Slider Special: die Kombination je Slider
		goal += "\n%d. %s:  %s" % [i + 1, tr(combo[i].get("name", "")), Challenge.combo_text(combo[i])]
	_text.text = "%s\n\n%s  %s\n%s  %s" % [goal, tr("Steuerung:"), keys, tr("Tipp:"), tr(task["tip"])]
	_go.text = tr("LOS") + ("" if mobile else "  (%s)" % tr("Leertaste"))
	_open()


## Ergebnis eines Versuchs. medal 0 = keine; text z. B. "2,4 m" oder "Gestürzt".
func show_result(mode_name: String, idx: int, count: int, task: Dictionary, best: Array, has_next: bool,
		medal: int, text: String, new_best: bool, photos: Array[Texture2D] = []) -> void:
	_fill(mode_name, idx, count, task, best, has_next)
	_result_row.visible = true
	_set_photos(photos)
	_result_medal.set_level(medal)
	_result.text = ("%s!   %s" % [tr(Training.MEDALS[medal]).to_upper(), text]) if medal > 0 else text
	_result.add_theme_color_override("font_color", Training.MEDAL_COLORS[medal] if medal > 0 else Color(1, 1, 1, 0.9))
	var b := tr("Bestwert: %s") % (Training.format_value(task, best[1]) if not is_nan(float(best[1])) else "–")
	if new_best:
		b = tr("Neue Bestleistung!") + "   " + b
	_text.text = b
	_go.text = tr("NOCHMAL") + ("" if mobile else "  (%s)" % tr("Leertaste"))
	_open()


## Competition: Ende der Runde (eigene Instanz in main.gd). Punkte groß, darunter groß der Platz in der
## Rangliste (kommt per set_rank nach); Knöpfe „Erneut spielen“ (Standard) und „Zurück“ (Startseite).
func show_round(head: String, score: int, rank: String) -> void:
	_head.text = head
	_title.text = tr("RUNDE BEENDET")
	_result_row.visible = true
	_result_medal.visible = false
	_result.text = tr_n("%d Punkt", "%d Punkte", score) % score
	_result.add_theme_font_size_override("font_size", 72)
	_result.add_theme_color_override("font_color", Color.WHITE)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank.add_theme_font_size_override("font_size", 34)
	_rank.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text.visible = false
	_mgrid.visible = false
	_next.visible = false
	_set_photos([])
	_go.text = tr("ERNEUT SPIELEN") + ("" if mobile else "  (%s)" % tr("Leertaste"))
	_home.text = tr("Zurück")
	set_rank(rank)
	_open()


## Zeile mit dem Platz in der Rangliste ("" = ausblenden); kommt nach, sobald der Server antwortet.
func set_rank(text: String) -> void:
	_rank.text = text
	_rank.visible = text != ""
	_update_name(text)
	if is_open():
		_layout()


## Namensfeld nur, wenn das Ergebnis in die Rangliste kam (Platz steht da) und noch kein Name gespeichert ist.
func _update_name(rank_text: String) -> void:
	_name_tip.visible = false
	var show := leaderboard != null and leaderboard.participating() and not leaderboard.has_name() \
		and (rank_text.contains("Platz") or rank_text.contains("PLATZ"))
	_name.leaderboard = leaderboard
	_name.visible = show
	if show:
		_name.edit.text = ""
		_name.set_msg("Trag deinen Namen ein – sonst stehst du als „Anonym“ in der Rangliste.")


## Fotos als Abzüge (weißer Rand) nebeneinander; eins allein etwas größer.
func _set_photos(photos: Array[Texture2D]) -> void:
	for c in _photos.get_children():
		c.queue_free()
	_photos.visible = not photos.is_empty()
	if photos.is_empty():
		return
	var vs := get_viewport().get_visible_rect().size
	var inner := (500.0 if vs.x < vs.y else 720.0) - 52.0
	var w := minf(300.0, (inner - 8.0 * (photos.size() - 1)) / photos.size()) - 8.0
	for tex in photos:
		var frame := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.97, 0.97, 0.95)
		sb.set_corner_radius_all(4)
		sb.set_content_margin_all(4)
		frame.add_theme_stylebox_override("panel", sb)
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.custom_minimum_size = Vector2(w, w * 9.0 / 16.0)
		frame.add_child(r)
		_photos.add_child(frame)


func _fill(mode_name: String, idx: int, count: int, task: Dictionary, best: Array, has_next: bool) -> void:
	_head.text = "%s   ·   CHALLENGE %d / %d" % [tr(mode_name).to_upper(), idx + 1, count]
	_title.text = tr(task["title"])
	for i in 3:
		_medal_labels[i].text = "%s  %s" % [tr(Training.MEDALS[i + 1]), Training.format_threshold(task, i)]
		_medals[i].modulate.a = 1.0 if int(best[0]) > i else 0.45
	_next.visible = has_next
	_next.text = tr("Nächste Challenge") + ("" if mobile else "  (N)")


func _open() -> void:
	MenuNav.reset_focus(_dim)                # Fokus auf LOS / NOCHMAL
	if not _dim.visible:
		Hud.fade_in(_dim)                     # weich einblenden
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
	if not mobile:
		k = minf(k, Hud.desktop_ui_max())
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
	if not event.is_pressed() or event.is_echo():
		return
	var k := event as InputEventKey
	if get_viewport().gui_get_focus_owner() == _name.edit and k != null:
		if event.is_action_pressed("ui_cancel"):     # Esc: nur das Tippen beenden
			_name.edit.release_focus()
			get_viewport().set_input_as_handled()
		return                                       # Enter speichert (text_submitted), Buchstaben ins Feld
	if event.is_action_pressed("menu_start"):        # Enter / PS: Los bzw. Nochmal (Leertaste/Kreuz drückt den Knopf mit Fokus)
		go_pressed.emit()
	elif event.is_action_pressed("ui_cancel"):       # Esc / Kreis: Startseite
		home_pressed.emit()
	elif k and k.physical_keycode == KEY_N:
		if _next.visible:
			next_pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
