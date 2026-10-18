class_name TouchPad
extends CanvasLayer
## Virtuelle Tasten fürs Handy (nur sichtbar, wenn MobileInput aktiv ist):
##  * unten links SPRUNG (halten = aufladen, loslassen = abspringen; Tippen auf den Bildschirm springt nicht)
##    und darüber DRIFT (Kante lösen; nach einem Sturz: sofort weiter) – links, damit rechts
##    gleichzeitig ▲ / ▼ geht (Drift-Press)
##  * rechts Pfeil hoch / runter (in der Luft Frontroll/Backroll bzw. beim Invert S-Bend/Backroll, auf dem Slider Nose-/Tailpress, im Drift Drift-Press);
##    mit Einstellung „Lenkung: Tasten“ dazu links / rechts = Steuerkreuz (statt Handy neigen)
##  * im Wasser nach einem Sturz heißen die Tasten SCHWIMMEN (SPRUNG) und SKIP (DRIFT)
##  * rechts unter der HUD-Leiste ☰ (nicht in der Leiste)   Menü: Weiter, Einstellungen, Hilfe, Zurück zum Steg, Startseite, Ton
## Die Finger verteilt MobileInput: wer eine Taste trifft, drückt sie; alle anderen Finger
## springen bzw. starten wie bisher. Stil wie die HUD-Leiste.

signal menu_action(id: String)
signal menu_toggled(open: bool)

const SIZE := 118.0          # Durchmesser der runden Tasten (bei Maßstab 1)

var _buttons: Array[PadButton] = []
var _menu: Control
var _menu_box: VBoxContainer
var _scale := 1.0
var _steer_buttons := false   # Lenkung über das Steuerkreuz statt Neigung
var hud: Hud                  # ☰ sitzt unter dessen Leiste


class PadButton extends Control:
	var text := ""
	var action := ""              # InputMap-Aktion, die gehalten wird …
	var id := ""                  # … oder ein Menü-Befehl
	var round := true
	var icon := Vector2.ZERO      # Pfeil in diese Richtung statt Text (Bildschirm: y nach unten)
	var font_size := 34
	var down := false

	func _draw() -> void:
		var fill := Color(Hud.ACCENT, 0.55) if down else Hud.PANEL
		if round:
			var r := size.x * 0.5
			draw_circle(size * 0.5, r, fill)
			draw_arc(size * 0.5, r - 2.0, 0.0, TAU, 48, Color(Hud.ACCENT, 0.9), 3.0, true)
		else:
			var sb := StyleBoxFlat.new()
			sb.bg_color = fill
			sb.set_corner_radius_all(14)
			sb.border_width_bottom = 3
			sb.border_color = Hud.ACCENT
			draw_style_box(sb, Rect2(Vector2.ZERO, size))
		if icon != Vector2.ZERO:
			_draw_arrow()
			return
		var font := get_theme_default_font()
		var fs := int(font_size * (size.y / 118.0 if round else size.y / 72.0))
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, (size.y + fs * 0.7) * 0.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	## Pfeil aus Schaft und Spitze, mittig in der Taste.
	func _draw_arrow() -> void:
		var c := size * 0.5
		var d := icon.normalized()
		var n := Vector2(-d.y, d.x)
		var r := size.x * 0.3
		var tip := c + d * r
		var base := c + d * r * 0.05
		draw_line(c - d * r, base, Color.WHITE, size.x * 0.1)
		draw_colored_polygon(PackedVector2Array([tip, base + n * r * 0.6, base - n * r * 0.6]), Color.WHITE)

	func set_down(on: bool) -> void:
		down = on
		queue_redraw()


func _init() -> void:
	layer = 5


func _ready() -> void:
	_add("", "pitch_front", "", Vector2.UP)
	_add("", "pitch_back", "", Vector2.DOWN)
	var drift := _add("DRIFT", "release")
	drift.font_size = 26
	_add("☰", "", "menu")
	var jump := _add("SPRUNG", "jump")
	jump.font_size = 22
	_add("", "steer_left", "", Vector2.LEFT)
	_add("", "steer_right", "", Vector2.RIGHT)
	set_steer_buttons(false)

	# Menü: abgedunkelter Hintergrund, Tasten untereinander
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0, 0, 0, 0.55)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu_box.add_theme_constant_override("separation", 14)
	_menu.add_child(_menu_box)
	for e: Array in [["Weiter", "close"], ["Einstellungen", "settings"], ["Hilfe ein/aus", "help"], ["Zurück zum Steg  (−2:00)", "reset"],
			["Startseite", "home"], ["Ton aus/an", "mute"], ["Seil-Abreißen an/aus  (aus: keine Rangliste)", "rope_rip"]]:
		var b := PadButton.new()
		b.text = e[0]
		b.id = e[1]
		b.round = false
		b.font_size = 26
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_menu_box.add_child(b)
		_buttons.append(b)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _add(text: String, action: String, id := "", icon := Vector2.ZERO) -> PadButton:
	var b := PadButton.new()
	b.text = text
	b.icon = icon
	b.action = action
	b.id = id
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(b)
	_buttons.append(b)
	return b


## Tasten passend zur Bildschirmgröße (Handy hoch- oder querformatig) anordnen.
func _layout() -> void:
	var vp := get_viewport().get_visible_rect().size
	_scale = clampf(minf(vp.x, vp.y) / 700.0, 0.6, 3.0)
	var s := SIZE * _scale
	var m := 24.0 * _scale
	var up: PadButton = _buttons[0]
	var down: PadButton = _buttons[1]
	var drift: PadButton = _buttons[2]
	var menu: PadButton = _buttons[3]
	var jump: PadButton = _buttons[4]
	var left: PadButton = _buttons[5]
	var right: PadButton = _buttons[6]
	for b: PadButton in [up, down, drift, left, right]:
		b.size = Vector2(s, s)
	jump.size = Vector2(s, s) * 1.25
	if _steer_buttons:
		# Steuerkreuz unten rechts: oben / unten / links / rechts um eine freie Mitte
		var g := s * 0.76     # Abstand Mitte -> Taste (Kreise berühren sich diagonal fast)
		var cx := vp.x - m - s * 0.5 - g
		var cy := vp.y - m - s * 0.5 - g
		up.position = Vector2(cx, cy - g) - Vector2(s, s) * 0.5
		down.position = Vector2(cx, cy + g) - Vector2(s, s) * 0.5
		left.position = Vector2(cx - g, cy) - Vector2(s, s) * 0.5
		right.position = Vector2(cx + g, cy) - Vector2(s, s) * 0.5
	else:
		up.position = Vector2(vp.x - m - s, vp.y - m - s * 2.15)
		down.position = Vector2(vp.x - m - s, vp.y - m - s)
	jump.position = Vector2(m, vp.y - m - jump.size.y)
	drift.position = Vector2(m + (jump.size.x - s) * 0.5, jump.position.y - s * 1.15)   # über SPRUNG
	menu.size = Vector2(s * 0.62, s * 0.62)
	_place_menu_button()
	var w := minf(560.0 * _scale, vp.x - 2.0 * m)
	var h := 72.0 * _scale
	for b: PadButton in _menu_buttons():
		b.custom_minimum_size = Vector2(w, h)
	_menu_box.add_theme_constant_override("separation", int(14.0 * _scale))
	var count := _menu_buttons().size()
	var total := Vector2(w, h * count + (count - 1) * 14.0 * _scale)
	_menu_box.position = (vp - total) * 0.5
	_menu_box.size = total


## ☰ rechts oben, aber unter der HUD-Leiste (die Leiste wächst mit dem Bildschirm, darum jedes Bild).
func _place_menu_button() -> void:
	var menu: PadButton = _buttons[3]
	var vp := get_viewport().get_visible_rect().size
	var m := 24.0 * _scale
	var top := m
	if hud:     # hochkant auch unter Aufgabenzeile und Brettzustand (die gehen über die ganze Breite)
		top = (hud.info_bottom() if vp.x < vp.y else hud.bar_bottom()) + m * 0.5
	menu.position = Vector2(vp.x - m - menu.size.x, top)


func _process(_delta: float) -> void:
	if visible and hud:
		_place_menu_button()


func _main_buttons() -> Array[PadButton]:
	var out: Array[PadButton] = []
	for b in _buttons:
		if b.get_parent() != _menu_box and b.visible:
			out.append(b)
	return out


func _menu_buttons() -> Array[PadButton]:
	var out: Array[PadButton] = []
	for c in _menu_box.get_children():
		out.append(c as PadButton)
	return out


## Lenkung über Tasten (Steuerkreuz rechts) statt Neigung.
func set_steer_buttons(on: bool) -> void:
	_steer_buttons = on
	_buttons[5].visible = on
	_buttons[6].visible = on
	if _menu_box:
		_layout()


## Im Wasser nach einem Sturz: SPRUNG heißt SCHWIMMEN, DRIFT heißt SKIP (sofort weiter).
func set_swim(on: bool) -> void:
	var jump: PadButton = _buttons[4]
	var drift: PadButton = _buttons[2]
	var jt := "SCHWIMMEN" if on else "SPRUNG"
	if jump.text == jt:
		return
	jump.text = jt
	jump.font_size = 17 if on else 22
	drift.text = "SKIP" if on else "DRIFT"
	jump.queue_redraw()
	drift.queue_redraw()


func is_menu_open() -> bool:
	return _menu.visible


## Welche Taste liegt unter dem Finger? (Bei offenem Menü nur die Menü-Tasten.)
func button_at(pos: Vector2) -> PadButton:
	if not visible:
		return null
	var list: Array[PadButton] = _menu_buttons() if _menu.visible else _main_buttons()
	# runde Tasten als Kreis prüfen (das Steuerkreuz liegt eng), bei Überlappung die nächste
	var best: PadButton = null
	var best_d := INF
	for b in list:
		var r := b.get_global_rect()
		var d := pos.distance_to(r.get_center())
		var hit := d <= r.size.x * 0.5 + 8.0 * _scale if b.round else r.grow(8.0 * _scale).has_point(pos)
		if hit and d < best_d:
			best = b
			best_d = d
	return best


## Ein Menü-Befehl (Taste losgelassen).
func trigger(id: String) -> void:
	match id:
		"menu":
			_set_menu(true)
		"close":
			_set_menu(false)
		_:
			_set_menu(false)
			menu_action.emit(id)


func close_menu() -> void:
	_set_menu(false)


## Menü auf/zu – solange es offen ist, ist das Spiel pausiert.
func _set_menu(on: bool) -> void:
	_menu.visible = on
	menu_toggled.emit(on)
