class_name FeatureMap
extends Control
## Die Bahn in der echten 3D-Szene, live (die Fahrer fahren weiter), isometrisch von der
## Seeseite gesehen (der See liegt links der Bahn): Startsteg rechts, Endmast links. Darüber nur die Markierung des gewählten
## bzw. überfahrenen Features/Hacks und sein Name.
## Teile, die (fast) aneinanderstoßen, bilden einen "Hack" und werden zusammen ausgewählt.
## Maus: Klick wählt aus, Doppelklick zoomt auf den Hack, Ziehen verschiebt, Rad zoomt,
## Rechtsklick zeigt wieder die ganze Bahn.

signal hack_selected(parts: Array)

const HACK_GAP := 0.8            # so nah (m) beieinander gilt als Hack
const COL_SEL := Color(1.0, 0.82, 0.2)
const TILT := deg_to_rad(35.0)   # Blick schräg von oben (90° = senkrecht)
const AZIMUTH := deg_to_rad(30.0) # Blick schräg über die Bahn (0 = genau quer)
const CAM_DIST := 160.0

var cable: CableSystem
var hacks: Array = []            # Array von Arrays mit FeatureParts (nach s sortiert)
var selected := -1
var _hover := -1
var _polys: Dictionary = {}      # FeaturePart -> PackedVector2Array in (s, x)
var _center_sx := Vector2.ZERO   # Bildmitte auf dem Wasser in (s, x)
var _span := 150.0               # sichtbare Breite in m
var _press := Vector2.INF
var _dragged := false
var _zoomed := -1                # auf diesen Hack gezoomt (bleibt beim Ändern der Fenstergröße)
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
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_cam.near = 1.0
	_cam.far = CAM_DIST * 2.0
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
			fit())


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
	fit()


## Ganze Bahn ins Bild: vom Startsteg bis zum Endmast.
func fit() -> void:
	if cable == null:
		return
	var s0 := cable.mast_a_z - cable.start_z - 8.0
	var s1 := cable.mast_a_z - cable.mast_b_z + 4.0
	_view(Rect2(s0, -14.0, s1 - s0, 28.0))


## Ausschnitt r (in s, x) einpassen.
func _view(r: Rect2) -> void:
	_center_sx = r.get_center()
	_zoomed = -1
	if cable == null or _cam == null or size.x < 10.0:
		return
	# Projektion ist linear (orthogonal): einmal messen, dann passend skalieren
	_span = 100.0
	_place_camera()
	var box := Rect2()
	var first := true
	for c: Vector2 in [r.position, r.position + Vector2(r.size.x, 0), r.end, r.position + Vector2(0, r.size.y)]:
		var sp := _to_screen(c)
		box = Rect2(sp, Vector2.ZERO) if first else box.expand(sp)
		first = false
	_span = clampf(100.0 * maxf(box.size.x / (size.x - 30.0), box.size.y / (size.y - 30.0)), 6.0, 400.0)
	queue_redraw()


## Auf einen Hack zoomen.
func zoom_to(idx: int) -> void:
	var r := Rect2()
	var first := true
	for p: FeaturePart in hacks[idx]:
		for q in _polys[p]:
			r = Rect2(q, Vector2.ZERO) if first else r.expand(q)
			first = false
	_view(r.grow(5.0))
	_zoomed = idx


func select(idx: int) -> void:
	selected = idx
	queue_redraw()
	if idx >= 0:
		hack_selected.emit(hacks[idx])


## Nächstes/voriges Feature bzw. Hack (Tastatur).
func select_step(step: int) -> void:
	if hacks.is_empty():
		return
	select(posmod(selected + step, hacks.size()))


## Name eines Features bzw. Hacks. Übliche Kombinationen sind kein Hack: Module aus mehreren
## Teilen (Pyramid Series, Spine Kicker …), Ollie Box mit Ledge und Kicker nebeneinander.
static func hack_name(hack: Array) -> String:
	if hack.size() == 1:
		return (hack[0] as FeaturePart).display_name
	var group := (hack[0] as FeaturePart).group_name
	var ids := {}
	for p: FeaturePart in hack:
		if p.group_name != group:
			group = ""
		ids[p.part_id] = true
	if group != "":
		return group
	var standard := ids.keys().all(func(i: String) -> bool: return i.begins_with("kicker_")) \
		or ids.keys().all(func(i: String) -> bool: return i in ["ollie_box", "ollie_box_half", "ollie_ledge"])
	var counts := {}
	for p: FeaturePart in hack:
		counts[p.display_name] = counts.get(p.display_name, 0) + 1
	var names: Array[String] = []
	for n: String in counts:
		names.append(("%d× %s" % [counts[n], n]) if counts[n] > 1 else n)
	return ("" if standard else "Hack: ") + " + ".join(names)


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




## (s, x) auf dem Wasser -> Welt
func _world(sx: Vector2, y := 0.0) -> Vector3:
	return cable.global_transform * Vector3(sx.y, y, cable.mast_a_z - sx.x)


func _to_screen(sx: Vector2) -> Vector2:
	return _cam.unproject_position(_world(sx))


## Meter pro Pixel (waagerecht)
func _mpp() -> float:
	return _span / maxf(size.x, 1.0)


## Bildpunkt -> Punkt auf dem Wasser in (s, x)
func _ground(pos: Vector2) -> Vector2:
	var o := _cam.project_ray_origin(pos)
	var d := _cam.project_ray_normal(pos)
	var w := o + d * (-o.y / minf(d.y, -0.01))
	var l := cable.global_transform.affine_inverse() * w
	return Vector2(cable.mast_a_z - l.z, l.x)


func _hack_at(pos: Vector2) -> int:
	for i in hacks.size():
		for p: FeaturePart in hacks[i]:
			var pts := PackedVector2Array()
			for q in _footprint(p, maxf(0.3, 6.0 * _mpp())):       # kleine Teile gut treffbar
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
				var f := 1.0 / 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.15
				# der Punkt unter der Maus bleibt stehen
				var before := _ground(mb.position)
				_span = clampf(_span * f, 6.0, 400.0)
				_place_camera()
				_center_sx += before - _ground(mb.position)
				_zoomed = -1
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
			fit()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _press != Vector2.INF and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
			if _dragged or mm.position.distance_to(_press) > 4.0:
				_dragged = true
				_center_sx += _ground(mm.position - mm.relative) - _ground(mm.position)
				_zoomed = -1
				queue_redraw()
		else:
			var h := _hack_at(mm.position)
			if h != _hover:
				_hover = h
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if h >= 0 else Control.CURSOR_ARROW
				queue_redraw()


# ---------------------------------------------------------------- Zeichnen

func _process(_delta: float) -> void:
	# live: die Markierungen jedes Bild nachziehen (die Fenstergröße kann sich ändern)
	if is_visible_in_tree():
		_place_camera()
		_overlay.queue_redraw()


func _draw() -> void:
	_place_camera()
	_overlay.queue_redraw()


## Kamera isometrisch über dem See (links der Bahn), leicht schräg zum Endmast hin.
func _place_camera() -> void:
	if cable == null or _cam == null:
		return
	var target := _world(_center_sx)
	var b := cable.global_basis.orthonormalized()
	var flat := (b * Vector3(cos(AZIMUTH), 0.0, -sin(AZIMUTH))).normalized()   # vom See zur Bahn
	var fwd := (flat * cos(TILT) + Vector3.DOWN * sin(TILT)).normalized()
	_cam.size = _span
	_cam.global_transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), target - fwd * CAM_DIST)


func _draw_overlay() -> void:
	if cable == null:
		return
	var font := get_theme_default_font()
	for i in hacks.size():
		if i != selected and i != _hover:
			continue
		var col := COL_SEL if i == selected else Color(1, 1, 1, 0.85)
		var r := Rect2()
		var first := true
		for p: FeaturePart in hacks[i]:
			var pts := PackedVector2Array()
			for q in _footprint(p, 0.25):
				var sp := _to_screen(q)
				pts.append(sp)
				r = Rect2(sp, Vector2.ZERO) if first else r.expand(sp)
				first = false
			pts.append(pts[0])
			_overlay.draw_polyline(pts, col, 2.5 if i == selected else 1.5, true)
		var txt := hack_name(hacks[i])
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		var c := Vector2(r.get_center().x - w * 0.5, r.end.y + 22.0)
		c.x = clampf(c.x, 4.0, size.x - w - 4.0)
		c.y = clampf(c.y, 18.0, size.y - 6.0)
		_overlay.draw_string_outline(font, c, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.75))
		_overlay.draw_string(font, c, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, col)
