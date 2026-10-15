class_name SelectBox
extends Button
## Auswahlbox für Startseite und Einstellungen (statt OptionButton – dessen Liste ist am Handy winzig).
## Zeigt die gewählte Zeile mit Pfeil; Antippen öffnet die Liste mit großen Zeilen direkt an der Box
## (nach unten oder oben, je nachdem wo mehr Platz ist; passt sie nicht, scrollt sie per Finger),
## Tippen daneben oder Esc schließt. Zeilen können ein Bild haben (Pokal, Farbe), Überschriften
## (nicht wählbar) trennen Gruppen.

signal item_selected(idx: int)

const ROW_H := 50.0
const ARROW_W := 30.0

var host: Control                 # hier hängt die offene Liste (skalierte Oberfläche der Startseite)
var font_size := 18
var selected := -1
var _items: Array = []            # {text, icon, header}
var _overlay: Control
var _scroll: ScrollContainer
var _press_scroll := 0


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	expand_icon = false
	custom_minimum_size = Vector2(0, 48)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pressed.connect(_open)


func _ready() -> void:
	add_theme_font_size_override("font_size", font_size)
	add_theme_constant_override("icon_max_width", 30)
	# Platz rechts für den Pfeil
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var sb := get_theme_stylebox(st)
		if sb:
			sb = sb.duplicate()
			sb.content_margin_right += ARROW_W
			add_theme_stylebox_override(st, sb)


func clear() -> void:
	_items.clear()
	selected = -1
	text = ""
	icon = null


## Wählbare Zeile; liefert ihren Index.
func add_item(label: String, img: Texture2D = null) -> int:
	_items.append({"text": label, "icon": img, "header": false})
	return _items.size() - 1


## Nicht wählbare Zwischenüberschrift in der Liste (zählt beim Index mit).
func add_header(label: String) -> void:
	_items.append({"text": label, "icon": null, "header": true})


func item_count() -> int:
	return _items.size()


func set_item_icon(idx: int, img: Texture2D) -> void:
	_items[idx]["icon"] = img
	if idx == selected:
		icon = img


func select(idx: int) -> void:
	if idx < 0 or idx >= _items.size() or _items[idx]["header"]:
		return
	selected = idx
	text = _items[idx]["text"]
	icon = _items[idx]["icon"]


func is_open() -> bool:
	return _overlay != null


func close() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null


func _draw() -> void:
	# Pfeil nach unten (gezeichnet, Sonderzeichen fehlen in der Web-Schrift)
	var c := Vector2(size.x - ARROW_W * 0.5 - 8.0, size.y * 0.5)
	var w := 7.0
	draw_polyline(PackedVector2Array([c + Vector2(-w, -w * 0.5), c + Vector2(0, w * 0.5), c + Vector2(w, -w * 0.5)]),
		Hud.ACCENT if not is_open() else Color.WHITE, 3.0, true)


func _open() -> void:
	if _overlay or _items.is_empty():
		return
	var parent: Control = host if host else get_parent_control()
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.size = parent.size
	_overlay.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			close()
			queue_redraw())
	parent.add_child(_overlay)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.11, 0.98)
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)
	sb.border_color = Hud.ACCENT
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	_overlay.add_child(panel)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	_scroll.add_child(list)
	var h := 0.0
	for i in _items.size():
		var it: Dictionary = _items[i]
		if it["header"]:
			var l := Label.new()
			l.text = it["text"]
			l.add_theme_font_size_override("font_size", 14)
			l.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
			l.custom_minimum_size = Vector2(0, 30)
			l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			l.mouse_filter = Control.MOUSE_FILTER_PASS
			list.add_child(l)
			h += 34.0
			continue
		var b := Button.new()
		b.text = it["text"]
		b.icon = it["icon"]
		b.add_theme_constant_override("icon_max_width", 30)
		b.add_theme_font_size_override("font_size", font_size)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.focus_mode = Control.FOCUS_NONE
		b.toggle_mode = true
		b.button_pressed = i == selected
		b.custom_minimum_size = Vector2(0, ROW_H)
		b.mouse_filter = Control.MOUSE_FILTER_PASS       # Wischen scrollt die Liste
		b.button_down.connect(func() -> void: _press_scroll = _scroll.scroll_vertical)
		b.pressed.connect(func() -> void:
			b.set_pressed_no_signal(i == selected)
			if absi(_scroll.scroll_vertical - _press_scroll) > 6:
				return                                    # war ein Wischen, keine Wahl
			_pick(i))
		list.add_child(b)
		h += ROW_H + 4.0
	h += 12.0
	# an der Box ausrichten (in Einheiten der Oberfläche)
	var inv := _overlay.get_global_transform().affine_inverse()
	var r := get_global_rect()
	var top := inv * r.position
	var bottom := inv * r.end
	var m := 8.0
	var w := clampf(bottom.x - top.x, 220.0, parent.size.x - 2.0 * m)
	var x := clampf(top.x, m, parent.size.x - m - w)
	var below := parent.size.y - m - bottom.y
	var above := top.y - m
	var y: float
	if h <= below:
		y = bottom.y + 2.0
	elif h <= above:
		y = top.y - 2.0 - h
	else:
		# passt weder darunter noch darüber: so viel wie möglich zeigen, notfalls über der Box
		h = minf(h, parent.size.y - 2.0 * m)
		y = clampf(bottom.y + 2.0, m, parent.size.y - m - h)
	panel.position = Vector2(x, y)
	panel.size = Vector2(w, h)
	panel.custom_minimum_size = Vector2(w, h)
	_scroll.custom_minimum_size = Vector2(0, h - 12.0)
	queue_redraw()
	# gewählte Zeile sichtbar
	await get_tree().process_frame
	if _overlay and selected >= 0:
		var c := list.get_child(selected) as Control
		if c:
			_scroll.scroll_vertical = int(maxf(0.0, c.position.y - (h - ROW_H) * 0.5))


func _pick(i: int) -> void:
	close()
	queue_redraw()
	if i != selected:
		select(i)
		item_selected.emit(i)


func _input(event: InputEvent) -> void:
	if _overlay and event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_ESCAPE:
		close()
		queue_redraw()
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	close()
