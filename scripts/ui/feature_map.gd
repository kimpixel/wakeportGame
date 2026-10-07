class_name FeatureMap
extends Control
## Draufsicht auf die echte 3D-Szene einer Anlage (Kamera senkrecht von oben, wie die
## Feature-Pläne ausgerichtet: unten der Startsteg, oben der Endmast). Darüber nur die
## Markierung des gewählten bzw. überfahrenen Features/Hacks und sein Name.
## Teile, die (fast) aneinanderstoßen, bilden einen "Hack" und werden zusammen ausgewählt.
## Maus: Klick wählt aus, Doppelklick zoomt auf den Hack, Ziehen verschiebt, Rad zoomt.

signal hack_selected(parts: Array)

const HACK_GAP := 0.8            # so nah (m) beieinander gilt als Hack
const COL_SEL := Color(1.0, 0.82, 0.2)
const CAM_HEIGHT := 120.0

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
var _vp: SubViewport
var _cam: Camera3D
var _overlay: Control


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	# echte Szene: eigene Kamera in derselben 3D-Welt wie das Spiel
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_vp = SubViewport.new()
	_vp.world_3d = get_tree().root.find_world_3d()
	_vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.near = 1.0
	_cam.far = CAM_HEIGHT + 60.0
	_vp.add_child(_cam)
	_cam.current = true
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
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
	# Kamera auf den aktuellen Ausschnitt; die Markierungen zeichnet das Overlay darüber
	if cable == null or _cam == null:
		return
	var sx := Vector2((_pan.y - size.y * 0.5) / _zoom, (size.x * 0.5 - _pan.x) / _zoom)   # Bildmitte in (s, x)
	_cam.size = size.y / _zoom
	var b := cable.global_basis.orthonormalized()
	_cam.global_transform = Transform3D(Basis(b.x, -b.z, Vector3.UP),
		cable.global_transform * Vector3(sx.y, 0.0, cable.mast_a_z - sx.x) + Vector3.UP * CAM_HEIGHT)
	_overlay.queue_redraw()


func _draw_overlay() -> void:
	if cable == null:
		return
	var font := get_theme_default_font()
	for i in hacks.size():
		if i != selected and i != _hover:
			continue
		var col := COL_SEL if i == selected else Color(1, 1, 1, 0.85)
		for p: FeaturePart in hacks[i]:
			var pts := PackedVector2Array()
			for q in _footprint(p, 0.25):
				pts.append(_to_screen(q))
			pts.append(pts[0])
			_overlay.draw_polyline(pts, col, 2.5 if i == selected else 1.5, true)
		var txt := hack_name(hacks[i])
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var r := Rect2()
		var first := true
		for p: FeaturePart in hacks[i]:
			for q in _polys[p]:
				var sp := _to_screen(q)
				r = Rect2(sp, Vector2.ZERO) if first else r.expand(sp)
				first = false
		var c := Vector2(r.get_center().x - w * 0.5, r.end.y + 22.0)
		c.x = clampf(c.x, 4.0, size.x - w - 4.0)
		c.y = clampf(c.y, 18.0, size.y - 6.0)
		_overlay.draw_string_outline(font, c, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
		_overlay.draw_string(font, c, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
