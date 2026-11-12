class_name WorldMap
extends Control
## World Map: Wakepark wählen. Eigene Seite der Startseite (wie der Setup-Editor), in Einheiten der Startseite.
##
## Karte aus assets/map/world.json (Natural Earth, tools/world_map_data.mjs): Land, große Seen, Landesgrenzen –
## einmal als Mesh in Länge/Breite gebaut, beim Zeichnen nur verschoben/skaliert (flächentreu genug: Länge × cos der
## Kartenmitte). Jeder Park ist ein Knopf (Pin, selbst gezeichnet – Symbole fehlen in der Web-Schrift), daneben die
## Infos zum gewählten Park (Ort, Anlagen) und „Hier fahren“. Mausrad/zwei Finger zoomen, Ziehen verschiebt.

signal closed
signal park_chosen(id: String)

const MAP_FILE := "res://assets/map/world.json"
const SEA := Color(0.05, 0.11, 0.17)
const LAND := Color(0.16, 0.21, 0.18)
const COAST := Color(0.36, 0.48, 0.42)
const BORDER := Color(0.42, 0.5, 0.46, 0.55)
const GRID := Color(1, 1, 1, 0.05)
const PIN_SIZE := 30.0
const MIN_SPAN := 32.0           # Grad Länge, die die Karte mindestens zeigt (Europa bei einem Park)
const ZOOM_MIN := 3.0            # Grad Länge ganz nah
const ZOOM_MAX := 200.0

var host: StartScreen
var current := ""                # Park, der gerade geladen ist

var _parks: Array = []           # [{id, name, place, lat, lon, systems}]
var _sel := -1
var _land: ArrayMesh
var _lines: Array[PackedVector2Array] = []    # Küsten (Land) und Seen, in Kartenkoordinaten
var _borders: Array[PackedVector2Array] = []
var _cos := 1.0                  # cos der Kartenmitte (Länge stauchen)
var _center := Vector2.ZERO      # Kartenmitte (Länge, Breite)
var _span := MIN_SPAN            # sichtbare Länge in Grad
var _map: Control
var _pins: Array[Button] = []
var _side: PanelContainer
var _title: Label
var _place: Label
var _systems: VBoxContainer
var _go: Button
var _back: Button
var _body: BoxContainer
var _root: VBoxContainer
var _drag := false
var _touches := {}               # Finger-Index -> Position (zwei Finger = zoomen)
var _pinch := 0.0


func build() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_load_parks()
	_load_map()

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	_root = root
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	root.add_child(head)
	_back = host._button(tr("Zurück"), 18)
	_back.custom_minimum_size.x = 120
	_back.pressed.connect(close)
	head.add_child(_back)
	var t := host._label(tr("WAKEPARK WÄHLEN"), 28, StartScreen.SEL)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(t)

	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	root.add_child(_body)
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.clip_contents = true
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_map_input)
	_map.resized.connect(_place_pins)
	_body.add_child(_map)
	for i in _parks.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(PIN_SIZE, PIN_SIZE)
		b.size = b.custom_minimum_size
		b.tooltip_text = str(_parks[i]["name"])
		b.draw.connect(_draw_pin.bind(b, i))
		b.pressed.connect(_select.bind(i))
		b.focus_entered.connect(_select.bind(i))
		_map.add_child(b)
		_pins.append(b)

	_side = PanelContainer.new()
	_side.add_theme_stylebox_override("panel", host._box(Color(0.06, 0.08, 0.1, 0.97), 16, 18))
	_body.add_child(_side)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_side.add_child(v)
	_title = host._label("", 30)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_place = host._label("", 18, Color(1, 1, 1, 0.7))
	_place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_place)
	v.add_child(host._small(tr("ANLAGEN")))
	_systems = VBoxContainer.new()
	_systems.add_theme_constant_override("separation", 4)
	v.add_child(_systems)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	_go = host._button(tr("HIER FAHREN"), 26, true)
	_go.custom_minimum_size.y = 64
	_go.pressed.connect(_choose)
	v.add_child(_go)
	MenuNav.add_scope(self, 15, _go)


## Seite zeigen, der geladene Park ist gewählt.
func open() -> void:
	current = Park.id
	visible = true
	_sel = -1
	for i in _parks.size():
		if _parks[i]["id"] == current:
			_sel = i
	if _sel < 0 and not _parks.is_empty():
		_sel = 0
	_fit_view()
	_select(_sel)
	MenuNav.reset_focus(self)


func close() -> void:
	visible = false
	closed.emit()


## Größe in Einheiten (wie der Setup-Editor); hochkant Infos unter der Karte.
func layout(size_units: Vector2, _k: float) -> void:
	position = Vector2.ZERO
	size = size_units
	var m := 16.0
	_root.position = Vector2(m, m)
	_root.size = size_units - Vector2(2 * m, 2 * m)
	var portrait := size_units.x < 900.0
	_body.vertical = portrait
	if portrait:
		_side.custom_minimum_size = Vector2(0, 0)
	else:
		_side.custom_minimum_size = Vector2(minf(400.0, size_units.x * 0.34), 0)
	_place_pins.call_deferred()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("menu_start"):
		_choose()
	else:
		return
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Daten

func _load_parks() -> void:
	for p: Dictionary in Park.list():
		var d := Park.info(p["id"])
		if d.is_empty():
			continue
		var loc: Dictionary = d.get("location", {})
		_parks.append({"id": p["id"], "name": str(d.get("name", p["id"])), "place": str(d.get("place", "")),
			"lat": float(loc.get("lat", 0.0)), "lon": float(loc.get("lon", 0.0)), "systems": d.get("systems", [])})


func _load_map() -> void:
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(MAP_FILE)) if FileAccess.file_exists(MAP_FILE) else null
	if not (d is Dictionary):
		return
	# Land als ein Mesh (Dreiecke je Ring), Seen darüber in Meeresfarbe
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	for key: String in ["land", "lakes"]:
		var c := LAND if key == "land" else SEA
		for ring: Array in d.get(key, []):
			var pts := _ring(ring)
			_lines.append(pts)
			var tri := Geometry2D.triangulate_polygon(pts)
			for idx in tri:
				verts.append(pts[idx])
				cols.append(c)
	for line: Array in d.get("borders", []):
		_borders.append(_ring(line))
	if verts.is_empty():
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	_land = ArrayMesh.new()
	_land.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


## Ganzzahl-Liste (Länge/Breite × 100) -> Punkte in Grad (x = Länge, y = −Breite).
func _ring(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(flat.size() / 2)
	for i in out.size():
		out[i] = Vector2(float(flat[2 * i]) * 0.01, -float(flat[2 * i + 1]) * 0.01)
	return out


# ---------------------------------------------------------------- Ansicht

## Alle Parks im Bild, mindestens MIN_SPAN Grad breit.
func _fit_view() -> void:
	if _parks.is_empty():
		_center = Vector2(10.0, 48.0)
		return
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p: Dictionary in _parks:
		var g := Vector2(p["lon"], p["lat"])
		mn = mn.min(g)
		mx = mx.max(g)
	_center = (mn + mx) * 0.5
	_cos = cos(deg_to_rad(clampf(_center.y, -70.0, 70.0)))
	var asp := _aspect()
	_span = clampf(maxf(maxf((mx.x - mn.x) * 1.8, (mx.y - mn.y) * 1.8 / _cos * asp), MIN_SPAN), ZOOM_MIN, ZOOM_MAX)
	_map.queue_redraw()
	_place_pins()


func _aspect() -> float:
	var s := _map.size if _map else Vector2.ONE
	return s.x / maxf(s.y, 1.0)


## Pixel (Einheiten) je Grad Länge im gestauchten Kartenraum.
func _scale() -> float:
	return _map.size.x / maxf(_span * _cos, 0.001)


## Länge/Breite -> Position in der Karte.
func _to_map(lon: float, lat: float) -> Vector2:
	var k := _scale()
	return _map.size * 0.5 + Vector2((lon - _center.x) * _cos, -(lat - _center.y)) * k


func _from_map(p: Vector2) -> Vector2:
	var k := _scale()
	var d := (p - _map.size * 0.5) / k
	return Vector2(_center.x + d.x / _cos, _center.y - d.y)


func _draw_map() -> void:
	var s := _map.size
	_map.draw_rect(Rect2(Vector2.ZERO, s), SEA)
	var k := _scale()
	var xf := Transform2D(0.0, Vector2(k * _cos, k), 0.0,
		s * 0.5 - Vector2(_center.x * _cos, -_center.y) * k)
	# Gradnetz alle 10°
	for lon in range(-180, 181, 10):
		var x := _to_map(lon, 0.0).x
		if x > 0.0 and x < s.x:
			_map.draw_line(Vector2(x, 0), Vector2(x, s.y), GRID, 1.0)
	for lat in range(-80, 81, 10):
		var y := _to_map(0.0, lat).y
		if y > 0.0 and y < s.y:
			_map.draw_line(Vector2(0, y), Vector2(s.x, y), GRID, 1.0)
	if _land:
		_map.draw_mesh(_land, null, xf)
	var view := Rect2(_from_map(Vector2.ZERO), Vector2.ZERO).expand(_from_map(s))
	view = Rect2(Vector2(view.position.x, -view.end.y), Vector2(view.size.x, view.size.y)).grow(2.0)
	for line: PackedVector2Array in _borders:
		_polyline(line, xf, view, BORDER, 1.0)
	for line: PackedVector2Array in _lines:
		_polyline(line, xf, view, COAST, 1.2)


## Linie zeichnen, wenn sie ins Bild ragt (grob über den ersten Punkt und die Länge – Ringe sind klein genug).
func _polyline(line: PackedVector2Array, xf: Transform2D, view: Rect2, c: Color, w: float) -> void:
	if line.size() < 2:
		return
	var b := Rect2(line[0], Vector2.ZERO)
	for i in range(0, line.size(), 8):
		b = b.expand(line[i])
	if not view.intersects(b.grow(1.0)):
		return
	_map.draw_polyline(xf * line, c, w, true)


func _place_pins() -> void:
	if _map == null:
		return
	for i in _pins.size():
		var p: Dictionary = _parks[i]
		var at := _to_map(p["lon"], p["lat"])
		_pins[i].position = at - Vector2(PIN_SIZE * 0.5, PIN_SIZE)
		_pins[i].visible = Rect2(Vector2.ZERO, _map.size).grow(PIN_SIZE).has_point(at)
	_map.queue_redraw()


## Pin: Tropfen mit Spitze unten am Ort, gewählt grün und größer; Name daneben.
func _draw_pin(b: Button, i: int) -> void:
	var sel := i == _sel
	var c := Hud.ACCENT if sel else Color(1, 1, 1, 0.9)
	var r := PIN_SIZE * (0.36 if sel else 0.3)
	var tip := Vector2(PIN_SIZE * 0.5, PIN_SIZE)
	var mid := tip - Vector2(0, PIN_SIZE * 0.62)
	b.draw_colored_polygon(PackedVector2Array([tip, mid + Vector2(-r * 0.8, r * 0.55), mid + Vector2(r * 0.8, r * 0.55)]), c)
	b.draw_circle(mid, r, c)
	b.draw_circle(mid, r * 0.42, SEA)
	if b.has_focus():
		b.draw_arc(mid, r + 4.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
	var f := host._font
	var fs := 17 if sel else 15
	var name: String = _parks[i]["name"]
	var pos := Vector2(PIN_SIZE + 2.0, mid.y + fs * 0.35)
	b.draw_string_outline(f, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.85))
	b.draw_string(f, pos, name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)


func _select(i: int) -> void:
	if i < 0 or i >= _parks.size():
		_title.text = ""
		_go.disabled = true
		return
	_sel = i
	var p: Dictionary = _parks[i]
	_title.text = p["name"]
	_place.text = tr(p["place"]) if p["place"] != "" else ""
	for c in _systems.get_children():
		c.queue_free()
	for s: Dictionary in p["systems"]:
		var type := str(s.get("type", ""))
		var kind := tr(Park.type_name(type))
		if not Park.playable(type):
			kind = tr("%s (kommt bald)") % kind
		var l := host._label("%s   ·   %s" % [tr(str(s.get("name", s.get("id", "")))), kind], 18,
			Color.WHITE if Park.playable(type) else Color(1, 1, 1, 0.55))
		_systems.add_child(l)
	_go.disabled = false
	_go.text = tr("HIER FAHREN")
	for b in _pins:
		b.queue_redraw()


func _choose() -> void:
	if _sel < 0:
		return
	var id: String = _parks[_sel]["id"]
	close()
	if id != current:
		park_chosen.emit(id)


# ---------------------------------------------------------------- Bedienung

func _map_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_zoom_at(mb.position, 0.85 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.85)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			_drag = mb.pressed
	elif event is InputEventMouseMotion and _drag:
		_pan((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch = 0.0
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var pts: Array = _touches.values()
			var d := (pts[0] as Vector2).distance_to(pts[1])
			if _pinch > 0.0 and d > 0.0:
				_zoom_at(((pts[0] as Vector2) + (pts[1] as Vector2)) * 0.5, _pinch / d)
			_pinch = d
		elif not _drag:
			_pan(sd.relative)


func _pan(rel: Vector2) -> void:
	var k := _scale()
	_center += Vector2(-rel.x / k / _cos, rel.y / k)
	_center.y = clampf(_center.y, -80.0, 80.0)
	_place_pins()


func _zoom_at(at: Vector2, f: float) -> void:
	var before := _from_map(at)
	_span = clampf(_span * f, ZOOM_MIN, ZOOM_MAX)
	var after := _from_map(at)
	_center += before - after
	_place_pins()


## Test (--screen=@weltkarte[:zoom=F][:park=ID][:waehlen]); waehlen = „Hier fahren“ drücken.
func run_test(opts: String) -> void:
	await get_tree().process_frame
	for o: String in opts.split(":", false):
		var kv := o.split("=")
		match kv[0]:
			"zoom":
				_span = clampf(_span / float(kv[1]), ZOOM_MIN, ZOOM_MAX)
				_place_pins()
			"park":
				for i in _parks.size():
					if _parks[i]["id"] == kv[1]:
						_select(i)
	print("WELTKARTE: %d Parks, gewählt %s, Mitte %.1f/%.1f, %.0f Grad" % [_parks.size(),
		_parks[_sel]["id"] if _sel >= 0 else "-", _center.x, _center.y, _span])
	if "waehlen" in opts.split(":", false):
		_choose()
