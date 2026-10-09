class_name TouchPad
extends CanvasLayer
## Virtuelle Tasten fürs Handy (nur sichtbar, wenn MobileInput aktiv ist):
##  * unten links SPRUNG (halten = aufladen, loslassen = abspringen; Tippen auf den Bildschirm springt nicht)
##  * rechts DRIFT (Kante lösen; nach einem Sturz: sofort weiter) und darunter ▲ / ▼
##    (in der Luft Frontroll/Backroll, auf dem Slider Nose-/Tailpress)
##  * oben links ☰        Menü: Weiter, Hilfe, Zurück zum Steg, Startseite, Ton
## Die Finger verteilt MobileInput: wer eine Taste trifft, drückt sie; alle anderen Finger
## springen bzw. starten wie bisher. Stil wie die HUD-Leiste.

signal menu_action(id: String)
signal menu_toggled(open: bool)

const SIZE := 118.0          # Durchmesser der runden Tasten (bei Maßstab 1)

var _buttons: Array[PadButton] = []
var _menu: Control
var _menu_box: VBoxContainer
var _scale := 1.0


class PadButton extends Control:
	var text := ""
	var action := ""              # InputMap-Aktion, die gehalten wird …
	var id := ""                  # … oder ein Menü-Befehl
	var round := true
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
		var font := get_theme_default_font()
		var fs := int(font_size * (size.y / 118.0 if round else size.y / 72.0))
		var ts := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(font, Vector2((size.x - ts.x) * 0.5, (size.y + fs * 0.7) * 0.5), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	func set_down(on: bool) -> void:
		down = on
		queue_redraw()


func _init() -> void:
	layer = 5


func _ready() -> void:
	_add("▲", "pitch_front")
	_add("▼", "pitch_back")
	var drift := _add("DRIFT", "release")
	drift.font_size = 26
	_add("☰", "", "menu")
	var jump := _add("SPRUNG", "jump")
	jump.font_size = 24

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
	for e: Array in [["Weiter", "close"], ["Hilfe ein/aus", "help"], ["Zurück zum Steg  (−2:00)", "reset"],
			["Startseite", "home"], ["Ton aus/an", "mute"], ["Seil-Abreißen an/aus", "rope_rip"]]:
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


func _add(text: String, action: String, id := "") -> PadButton:
	var b := PadButton.new()
	b.text = text
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
	for b: PadButton in [up, down, drift]:
		b.size = Vector2(s, s)
	jump.size = Vector2(s, s) * 1.25
	up.position = Vector2(vp.x - m - s, vp.y - m - s * 2.15)
	down.position = Vector2(vp.x - m - s, vp.y - m - s)
	drift.position = Vector2(vp.x - m - s, vp.y - m - s * 3.3)
	jump.position = Vector2(m, vp.y - m - jump.size.y)
	menu.size = Vector2(s * 0.62, s * 0.62)
	menu.position = Vector2(m, m)
	var w := minf(560.0 * _scale, vp.x - 2.0 * m)
	var h := 72.0 * _scale
	for b: PadButton in _menu_buttons():
		b.custom_minimum_size = Vector2(w, h)
	_menu_box.add_theme_constant_override("separation", int(14.0 * _scale))
	var count := _menu_buttons().size()
	var total := Vector2(w, h * count + (count - 1) * 14.0 * _scale)
	_menu_box.position = (vp - total) * 0.5
	_menu_box.size = total


func _main_buttons() -> Array[PadButton]:
	var out: Array[PadButton] = []
	for b in _buttons:
		if b.get_parent() != _menu_box:
			out.append(b)
	return out


func _menu_buttons() -> Array[PadButton]:
	var out: Array[PadButton] = []
	for c in _menu_box.get_children():
		out.append(c as PadButton)
	return out


func is_menu_open() -> bool:
	return _menu.visible


## Welche Taste liegt unter dem Finger? (Bei offenem Menü nur die Menü-Tasten.)
func button_at(pos: Vector2) -> PadButton:
	if not visible:
		return null
	var list: Array[PadButton] = _menu_buttons() if _menu.visible else _main_buttons()
	for b in list:
		if b.get_global_rect().grow(8.0 * _scale).has_point(pos):
			return b
	return null


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
