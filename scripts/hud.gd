class_name Hud
extends CanvasLayer

const HELP := """A / D   Kante: lenken   (in der Luft: drehen)
W   Kante belasten: mehr Grip, weite Bögen, mehr Zug
S   Kante lösen = Driften: Brett rutscht quer, dreht schneller (gut für die Wende)
Leertaste halten + loslassen   Absprung
Enter  Start     R  Neustart     + / -  Anlagentempo
C  Kamera     Maus: umsehen (Klick fängt Maus, Esc gibt frei), Rad: Zoom
P  Autopilot     M  Ton aus/an     H  Hilfe ein/aus
Vor dem Start:   T  Terminal (T1/T2)     F  Feature-Setup     Tab  Feature-Übersicht"""

const HELP_MOBILE := """Handy neigen   lenken
Finger halten + loslassen   Absprung
Tippen   Start"""

var _info: Label
var _center: Label
var _trick: Label
var _help: Label
var _bar: ProgressBar
var _board: Label
var _trick_time := 0.0
var _setup_box: Control


func _ready() -> void:
	_info = _label(20)
	_info.position = Vector2(16, 12)

	_bar = ProgressBar.new()
	_bar.position = Vector2(16, 150)
	_bar.size = Vector2(280, 14)
	_bar.max_value = 1.0
	_bar.show_percentage = false
	add_child(_bar)

	_board = _label(22)
	_board.position = Vector2(16, 170)
	_board.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))

	_center = _label(36)
	_center.anchor_right = 1.0
	_center.anchor_top = 0.3
	_center.anchor_bottom = 0.3
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_trick = _label(44)
	_trick.anchor_right = 1.0
	_trick.anchor_top = 0.15
	_trick.anchor_bottom = 0.15
	_trick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_trick.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

	_help = _label(17)
	_help.text = HELP
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_left = 16
	_help.offset_top = -175
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN


func _label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func set_info(text: String, tension_ratio: float) -> void:
	_info.text = text
	_bar.value = clampf(tension_ratio, 0.0, 1.0)
	_bar.modulate = Color(0.3, 1.0, 0.3).lerp(Color(1.0, 0.2, 0.1), clampf(tension_ratio, 0.0, 1.0))


func set_center(text: String) -> void:
	_center.text = text


func show_trick(text: String) -> void:
	_trick.text = text
	_trick_time = 2.0


## Auswahl vor dem Start (Terminal, Feature-Setup), oben rechts. Liefert die Auswahlbox.
func add_menu_choice(title_text: String, names: Array, current: int, on_select: Callable) -> OptionButton:
	if _setup_box == null:
		var vb := VBoxContainer.new()
		vb.anchor_left = 1.0
		vb.anchor_right = 1.0
		vb.offset_left = -330
		vb.offset_right = -16
		vb.offset_top = 12
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


func _process(delta: float) -> void:
	_trick_time -= delta
	_trick.visible = _trick_time > 0.0


func set_board(text: String) -> void:
	_board.text = text
