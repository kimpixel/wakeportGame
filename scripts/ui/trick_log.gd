class_name TrickLog
extends CanvasLayer
## Debug (F3, mit den Hitboxen): Liveprotokoll links in der Mitte am Rand – was der Fahrer gerade tut
## (Absprung, Hop, Fangzone, Landung, Slide-Beginn/-Ende mit Transfer und Kette, Tricks, Challenge-Wertung).
## Hilft nachzuvollziehen, warum etwas (nicht) gezählt hat. Geschrieben wird immer (nur Spieler), gezeigt nur mit F3.
## Debug-Text, nicht übersetzt.

const MAX_LINES := 18
const WIDTH := 380.0             # px

static var _lines: Array[String] = []
static var _t0 := -1

var _label: Label
var _panel: PanelContainer


## Zeile anhängen (mit Zeit seit dem ersten Eintrag).
static func add(text: String) -> void:
	var ms := Time.get_ticks_msec()
	if _t0 < 0:
		_t0 = ms
	_lines.append("%6.2f  %s" % [(ms - _t0) / 1000.0, text])
	while _lines.size() > MAX_LINES:
		_lines.pop_front()


static func clear() -> void:
	_lines.clear()
	_t0 = -1


func _ready() -> void:
	layer = 6
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.custom_minimum_size.x = WIDTH
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = WIDTH - 12.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func _process(_delta: float) -> void:
	if not visible:
		return
	_label.text = "Trick-Protokoll (F3)\n" + "\n".join(_lines)
	var vp := get_viewport().get_visible_rect().size
	_panel.size = Vector2(WIDTH, 0.0)                  # Höhe nach Inhalt
	_panel.position = Vector2(0.0, (vp.y - _panel.get_combined_minimum_size().y) * 0.5)
