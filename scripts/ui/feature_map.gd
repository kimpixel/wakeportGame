class_name FeatureMap
extends Control
## Draufsicht auf alle Features einer Anlage wie die Feature-Pläne: Seil senkrecht,
## unten der Startsteg, oben der Endmast, rechts = rechts in Fahrtrichtung zum Endmast.
## Teile, die (fast) aneinanderstoßen, bilden einen "Hack" und werden zusammen ausgewählt.
## Maus: Klick wählt aus, Doppelklick zoomt auf den Hack, Ziehen verschiebt, Rad zoomt.

signal hack_selected(parts: Array)

const HACK_GAP := 0.8            # so nah (m) beieinander gilt als Hack
const COL_WATER := Color(0.1, 0.42, 0.5)
const COL_GRID := Color(1, 1, 1, 0.07)
const COL_CABLE := Color(0.08, 0.08, 0.1)
const COL_SEL := Color(1.0, 0.82, 0.2)

var cable: CableSystem
var hacks: Array = []            # Array von Arrays mit FeatureParts (nach s sortiert)
var selected := -1
var _hover := -1
var _polys: Dictionary = {}      # FeaturePart -> PackedVector2Array in (s, x)
var _zoom := 5.0                 # Pixel pro Meter
var _pan := Vector2.ZERO         # Bildschirmposition von (s=0, x=0); s zeigt nach oben
var _press := Vector2.INF
var _dragged := false
var _whole := false
var _zoomed := -1                # auf diesen Hack gezoomt (bleibt beim Ändern der Fenstergröße)
var s_offset := 0.0              # Beschriftung in Setup-Metern (T1: Teile sind um diesen Versatz verschoben)


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(func() -> void:
		if _zoomed >= 0:
			zoom_to(_zoomed)
		else:
			fit(_whole))


## Neue Anlage bzw. neues Setup anzeigen.
func set_parts(c: CableSystem, parts: Array[FeaturePart]) -> void:
	cable = c
	_polys.clear()
	for p in parts:
		_polys[p] = _footprint(p, 0.0)
	hacks = _group(parts)
	hacks.sort_custom(func(a: Array, b: Array) -> bool: return _center(a).x < _center(b).x)
	selected = -1
	_hover = -1
	_zoomed = -1
	fit()


## Alle Features (und den Startplatz) ins Bild; whole: die ganze Anlage von Mast zu Mast.
func fit(whole := false) -> void:
	if cable == null or size.x < 10.0:
		return
	var length := cable.mast_a_z - cable.mast_b_z
	var r := Rect2(Vector2(cable.mast_a_z - cable.start_z, 0.0), Vector2.ZERO)
	if whole or _polys.is_empty():
		r = Rect2(0.0, -20.0, length, 40.0)
	else:
		for poly: PackedVector2Array in _polys.values():
			for q in poly:
				r = r.expand(q)
		r = r.grow(6.0)
	_view(r)


## Ausschnitt r (in s, x) einpassen.
func _view(r: Rect2) -> void:
	_zoom = minf((size.x - 30.0) / r.size.y, (size.y - 30.0) / r.size.x)
	var c := r.get_center()
	_pan = Vector2(size.x * 0.5 - c.y * _zoom, size.y * 0.5 + c.x * _zoom)
	queue_redraw()


## Auf einen Hack zoomen.
func zoom_to(idx: int) -> void:
	_zoomed = idx
	var r := Rect2()
	var first := true
	for p: FeaturePart in hacks[idx]:
		for q in _polys[p]:
			r = Rect2(q, Vector2.ZERO) if first else r.expand(q)
			first = false
	_view(r.grow(4.0))


func select(idx: int) -> void:
	selected = idx
	queue_redraw()
	if idx >= 0:
		hack_selected.emit(hacks[idx])


static func hack_name(hack: Array) -> String:
	if hack.size() == 1:
		return (hack[0] as FeaturePart).display_name
	var counts := {}
	for p: FeaturePart in hack:
		counts[p.display_name] = counts.get(p.display_name, 0) + 1
	var names: Array[String] = []
	for n: String in counts:
		names.append(("%d× %s" % [counts[n], n]) if counts[n] > 1 else n)
	return "Hack: " + " + ".join(names)


# ---------------------------------------------------------------- Geometrie

## Grundriss eines Teils in Anlagenkoordinaten (s, x), um margin vergrößert.
func _footprint(p: FeaturePart, margin: float) -> PackedVector2Array:
	var hw := p.width * 0.5 + margin
	var hl := p.length * 0.5 + margin
	var out := PackedVector2Array()
	var inv := cable.transform.affine_inverse()
	for c: Vector2 in [Vector2(-hw, -hl), Vector2(hw, -hl), Vector2(hw, hl), Vector2(-hw, hl)]:
		var l := inv * (p.global_transform * Vector3(c.x, 0.0, c.y))
		out.append(Vector2(cable.mast_a_z - l.z, l.x))
	return out


## Teile, die sich (mit HACK_GAP Abstand) berühren, zu Hacks zusammenfassen.
func _group(parts: Array[FeaturePart]) -> Array:
	var n := parts.size()
	var root: Array[int] = []
	for i in n:
		root.append(i)
	var find := func(i: int) -> int:
		while root[i] != i:
			i = root[i]
		return i
	var grown: Array[PackedVector2Array] = []
	for p in parts:
		grown.append(_footprint(p, HACK_GAP * 0.5))
	for i in n:
		for j in range(i + 1, n):
			if _overlap(grown[i], grown[j]):
				root[find.call(i)] = find.call(j)
	var by_root := {}
	for i in n:
		var r: int = find.call(i)
		if not by_root.has(r):
			by_root[r] = []
		by_root[r].append(parts[i])
	return by_root.values()


## Trennende Achse: überlappen zwei konvexe Vierecke?
static func _overlap(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly: PackedVector2Array in [a, b]:
		for k in poly.size():
			var e := poly[(k + 1) % poly.size()] - poly[k]
			var axis := Vector2(-e.y, e.x)
			var amin := INF
			var amax := -INF
			var bmin := INF
			var bmax := -INF
			for q in a:
				amin = minf(amin, q.dot(axis))
				amax = maxf(amax, q.dot(axis))
			for q in b:
				bmin = minf(bmin, q.dot(axis))
				bmax = maxf(bmax, q.dot(axis))
			if amax < bmin or bmax < amin:
				return false
	return true


func _center(hack: Array) -> Vector2:
	var c := Vector2.ZERO
	for p: FeaturePart in hack:
		for q in _polys[p]:
			c += q
	return c / (hack.size() * 4.0)


func _to_screen(sx: Vector2) -> Vector2:
	return _pan + Vector2(sx.y, -sx.x) * _zoom


func _hack_at(pos: Vector2) -> int:
	for i in hacks.size():
		for p: FeaturePart in hacks[i]:
			var pts := PackedVector2Array()
			for q in _footprint(p, maxf(0.3, 4.0 / _zoom)):       # kleine Teile gut treffbar
				pts.append(_to_screen(q))
			if Geometry2D.is_point_in_polygon(pos, pts):
				return i
	return -1


# ---------------------------------------------------------------- Eingabe

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				var f := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				var new_zoom := clampf(_zoom * f, 1.0, 80.0)
				_pan = mb.position - (mb.position - _pan) * (new_zoom / _zoom)
				_zoom = new_zoom
				queue_redraw()
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click:
				var hi := _hack_at(mb.position)
				if hi >= 0:
					zoom_to(hi)
			elif mb.pressed:
				_press = mb.position
				_dragged = false
			else:
				if not _dragged:
					var i := _hack_at(mb.position)
					if i >= 0:
						select(i)
				_press = Vector2.INF
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_whole = not _whole if _zoomed < 0 else false
			_zoomed = -1
			fit(_whole)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _press != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if _dragged or mm.position.distance_to(_press) > 4.0:
				_dragged = true
				_pan += mm.relative
				queue_redraw()
		else:
			var h := _hack_at(mm.position)
			if h != _hover:
				_hover = h
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
				queue_redraw()


# ---------------------------------------------------------------- Zeichnen

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COL_WATER)
	if cable == null:
		return
	var font := get_theme_default_font()
	var length := cable.mast_a_z - cable.mast_b_z
	# Raster alle 10 m mit Beschriftung entlang des Seils
	var step := 10.0 if _zoom > 2.5 else 20.0
	var s := fposmod(s_offset, step)
	while s <= length + 0.1:
		var a := _to_screen(Vector2(s, -40.0))
		var b := _to_screen(Vector2(s, 40.0))
		draw_line(a, b, COL_GRID, 1.0)
		draw_string(font, _to_screen(Vector2(s, 0.0)) + Vector2(4, -3), "%d m" % roundi(s - s_offset), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1, 1, 1, 0.45))
		s += step
	var xs := [-30.0, -20.0, -10.0, 10.0, 20.0, 30.0]
	if _zoom > 12.0:
		xs = range(-30, 31).filter(func(v: int) -> bool: return v != 0)
	for x in xs:
		draw_line(_to_screen(Vector2(0.0, float(x))), _to_screen(Vector2(length, float(x))), COL_GRID, 1.0)
	# Seil, Masten, Wendepunkte, Startplatz
	draw_line(_to_screen(Vector2(0, 0)), _to_screen(Vector2(length, 0)), COL_CABLE, 2.0)
	for m in [0.0, length]:
		draw_circle(_to_screen(Vector2(m, 0)), 6.0, Color(0.85, 0.85, 0.8))
	for tz in [cable.turn_a_z, cable.turn_b_z]:
		draw_circle(_to_screen(Vector2(cable.mast_a_z - tz, 0)), 3.5, Color(1.0, 0.4, 0.3))
	var start := _to_screen(Vector2(cable.mast_a_z - cable.start_z, 0))
	draw_rect(Rect2(start - Vector2(5, 5), Vector2(10, 10)), Color(0.95, 0.95, 0.95))
	draw_string(font, start + Vector2(10, 5), "Start", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	# Features
	for i in hacks.size():
		var hi := i == selected
		var ho := i == _hover
		for p: FeaturePart in hacks[i]:
			_draw_part(p, hi, ho)
	for i in hacks.size():
		if i == selected or i == _hover or _zoom >= 7.0:
			var txt := hack_name(hacks[i])
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			var c := _to_screen(_center(hacks[i])) + Vector2(-w * 0.5, 26)
			c.x = clampf(c.x, 4.0, size.x - w - 4.0)
			var col := COL_SEL if i == selected else Color(1, 1, 1, 0.9 if i == _hover else 0.6)
			draw_string_outline(font, c, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.7))
			draw_string(font, c, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)


func _draw_part(p: FeaturePart, sel: bool, hover: bool) -> void:
	var pts := PackedVector2Array()
	for q in _polys[p]:
		pts.append(_to_screen(q))
	var fill := Color(0.95, 0.95, 0.93)
	match p.type:
		"rail":
			fill = Color(0.2, 0.2, 0.22) if p.rail_color != "grey" else Color(0.6, 0.62, 0.65)
		"ball":
			fill = Color(0.1, 0.2, 0.75)
		"transition":
			fill = Color(0.85, 0.87, 0.9)
		_:
			if p.color == "grey":
				fill = Color(0.65, 0.67, 0.7)
	if hover and not sel:
		fill = fill.lerp(COL_SEL, 0.3)
	if p.type == "ball":
		draw_circle(_to_screen(_center([p])), maxf(p.radius * _zoom, 3.0), fill)
	else:
		draw_colored_polygon(pts, fill)
		var outline := pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, COL_SEL if sel else Color(0, 0, 0, 0.6), 2.0 if sel else 1.0)
	# Pfeil in Fahrtrichtung (wie in den Plänen: von der Auffahrt zum Ende)
	if p.type != "ball" and p.type != "bump" and p.length * _zoom > 14.0:
		var a := _to_screen((_polys[p][0] + _polys[p][1]) * 0.25 + (_polys[p][2] + _polys[p][3]) * 0.25)
		var dir_l := cable.transform.affine_inverse().basis * (p.global_basis * Vector3(0, 0, -1))
		var d := Vector2(dir_l.x, dir_l.z).normalized()
		var half := minf(p.length * _zoom * 0.3, 14.0)
		var col := Color(0.1, 0.1, 0.1, 0.8) if p.type != "rail" else Color(1, 1, 1, 0.8)
		draw_line(a - d * half, a + d * half, col, 2.0)
		draw_line(a + d * half, a + d * half - d.rotated(0.5) * 6.0, col, 2.0)
		draw_line(a + d * half, a + d * half - d.rotated(-0.5) * 6.0, col, 2.0)
