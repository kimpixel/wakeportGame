class_name Hud
extends CanvasLayer

const HELP := """A / D   Kante: lenken   (in der Luft: drehen)
W   Kante belasten: mehr Grip, weite Bögen, mehr Zug
S   Kante lösen = Driften: Brett rutscht quer, dreht schneller (gut für die Wende)
Leertaste halten + loslassen   Absprung
Enter  Start     R  Neustart     + / -  Anlagentempo
C  Kamera     Maus: umsehen (Klick fängt Maus, Esc gibt frei), Rad: Zoom
P  Autopilot     H  Hilfe ein/aus"""

var _info: Label
var _center: Label
var _trick: Label
var _help: Label
var _bar: ProgressBar
var _board: Label
var _trick_time := 0.0


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


func toggle_help() -> void:
	_help.visible = not _help.visible


func _process(delta: float) -> void:
	_trick_time -= delta
	_trick.visible = _trick_time > 0.0


func set_board(text: String) -> void:
	_board.text = text
