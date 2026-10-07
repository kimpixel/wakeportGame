class_name FeaturePart
extends Node3D
## Ein einzelnes Hindernis-Bauteil (Kicker, Box, Rail, Pipe, Bump …).
##
## Lokales Koordinatensystem: Ursprung = Mitte des Teils auf Wasserhöhe,
## u = entlang der Befahrrichtung (lokal -Z), v = quer (lokal +X).
## Die Form kommt komplett aus den Katalogwerten (setups/parts.json); dieselbe
## Höhenfunktion dient für Physik und Grafik.

const NONE := -100.0
const BOTTOM := -0.45          # Unterkante der Schwimmkörper
const ENTRY := -0.15           # Rampenanfang knapp unter Wasser

var part_id := ""
var display_name := ""
var article := "die"           # für Meldungen: "Gegen die Pipe" / "Gegen den Ball"
var type := "block"
var length := 4.0
var width := 2.0
var height := 1.0
var height_end := NAN
var ramp_in := 0.0
var ramp_out := 0.0
var curve := 1.5
var radius := 0.4
var center_y := 0.1
var top := 1.0
var rail_color := "grey"
var ramp_curve := 1.6          # Form der Auffahrten: 1 = gerade (A-Frame), > 1 = konkav (Transition)
var color := "white"           # Farbe des Körpers: white / grey
var side_ramp := 0.0           # seitliche Transition auf der Seilseite (Breite in m, 0 = senkrechte Wand)
var inner_v := 1.0             # +1/-1: in welche lokale v-Richtung das Seil liegt (setzt FeatureSet)

## Lage auf der Anlage (wird von FeatureSet gesetzt)
var cable: CableSystem
var s_center := 0.0            # Abstand vom Startmast entlang des Seils
var x_center := 0.0            # seitlicher Abstand zum Seil

var _reach := 1.0              # Radius für die schnelle Vorauswahl
var _inv := Transform3D()      # Welt -> lokal (Teile stehen still)


func setup(id: String, p: Dictionary) -> void:
	part_id = id
	display_name = p.get("name", id)
	article = p.get("article", article)
	type = p.get("type", "block")
	length = p.get("length", length)
	width = p.get("width", 0.4 if type == "rail" else (radius * 2.0 if type == "pipe" else width))
	height = p.get("height", height)
	height_end = p.get("height_end", height)
	ramp_in = p.get("ramp_in", 0.0)
	ramp_out = p.get("ramp_out", 0.0)
	curve = p.get("curve", curve)
	radius = p.get("radius", radius)
	center_y = p.get("center_y", center_y)
	top = p.get("top", top)
	rail_color = p.get("color", rail_color)
	color = p.get("color", color)
	ramp_curve = p.get("ramp_curve", ramp_curve)
	side_ramp = p.get("side_ramp", side_ramp)
	if type == "pipe" or type == "ball":
		width = radius * 2.0
	if type == "ball":
		length = radius * 2.0
	_reach = Vector2(length, width).length() * 0.5 + 0.5


## Gleitet man auf diesem Teil (Box, Rail, Pipe) oder ist es eine Absprungrampe?
func is_slide() -> bool:
	return type in ["block", "rail", "pipe", "transition"]


## Bevorzugte Fahrspur über das Teil (seitlicher Abstand zum Seil): Mitte bzw. beim
## Transition Rail direkt am Rail.
func lane_x() -> float:
	if type != "transition":
		return x_center
	var p := global_transform * Vector3(-inner_v * (width * 0.5 - 0.12), 0.0, 0.0)
	return (cable.transform.affine_inverse() * p).x


# ---------------------------------------------------------------- Form

## Oberkante an lokaler Position (u, v) oder NONE.
## collision: bei Rails nur die echte Rohrbreite (zum Draufspringen gilt eine breitere Toleranz).
func height_local(u: float, v: float, collision := false) -> float:
	var hl := length * 0.5
	if u < -hl or u > hl:
		return NONE
	var t := (u + hl) / length                       # 0 = Anfang, 1 = Ende
	match type:
		"ramp":
			if absf(v) > width * 0.5:
				return NONE
			return ENTRY + (height - ENTRY) * pow(t, curve)
		"block":
			if absf(v) > width * 0.5:
				return NONE
			return _with_side_ramp(v, _with_ramps(u, lerpf(height, height_end, t)))
		"rail":
			if absf(v) > (radius + 0.04 if collision else 0.2):   # Toleranz: so breit "trifft" das Brett den Rail
				return NONE
			return _with_ramps(u, height)
		"pipe":
			if absf(v) > radius * 0.8:
				return NONE
			return _with_ramps(u, center_y + sqrt(radius * radius - v * v))
		"transition":
			# Querschnitt: konkave Transition von der Seilseite (-v) hoch zur Kante (+v),
			# dort das schwarze Rail; hinten senkrechte Wand. Enden: schräge Auffahrten.
			var hw := width * 0.5
			if absf(v) > hw:
				return NONE
			var w := -v * inner_v                     # > 0 Richtung Außenkante (weg vom Seil)
			var h: float
			if w > hw - 0.22:
				h = height + 0.05                      # Rail auf der Oberkante
			else:
				h = ENTRY + (height - ENTRY) * pow((w + hw) / width, 2.0)
			var top := height + 0.05
			if ramp_in > 0.0:
				h = minf(h, lerpf(ENTRY, top, clampf((u + hl) / ramp_in, 0.0, 1.0)))
			if ramp_out > 0.0:
				h = minf(h, lerpf(ENTRY, top, clampf((hl - u) / ramp_out, 0.0, 1.0)))
			return h
		"ball":
			# Gummiball (treibt hoch, viel Luft drin): Kugeloberfläche – schon der Rand liegt
			# über dem Wasser, man kommt also nur mit einem Sprung drüber
			var d2 := u * u + v * v
			if d2 > radius * radius:
				return NONE
			return center_y + sqrt(radius * radius - d2)
		"bump":
			var hw := width * 0.5
			if absf(v) > hw:
				return NONE
			var d := maxf(absf(u) / hl, absf(v) / hw)       # 0 Mitte, 1 Rand
			var top_r := top / maxf(length, width)
			return lerpf(ENTRY, height, clampf((1.0 - d) / maxf(1.0 - top_r, 0.01), 0.0, 1.0))
	return NONE


## Übergangsrampen an Anfang/Ende (geschwungen, wie die "Transitions" der echten Features).
func _with_ramps(u: float, h: float) -> float:
	var hl := length * 0.5
	if ramp_in > 0.0 and u < -hl + ramp_in:
		h = minf(h, lerpf(ENTRY, h, pow((u + hl) / ramp_in, ramp_curve)))
	if ramp_out > 0.0 and u > hl - ramp_out:
		h = minf(h, lerpf(ENTRY, h, pow((hl - u) / ramp_out, ramp_curve)))
	return h


## Seitliche Auffahrt auf der Seilseite: von der Innenkante (Wasser) konkav hoch auf h.
func _with_side_ramp(v: float, h: float) -> float:
	if side_ramp <= 0.0:
		return h
	var d := width * 0.5 - v * inner_v         # 0 an der Innenkante
	if d >= side_ramp:
		return h
	return minf(h, lerpf(ENTRY, h, pow(clampf(d / side_ramp, 0.0, 1.0), 2.0)))


## Vorwärtsrichtung des Teils (Befahrrichtung) in Weltkoordinaten.
func forward_world() -> Vector3:
	return -global_basis.z


## Wie fährt man dieses Teil in Fahrtrichtung travel an?
## entry_h: Höhe direkt am Einstieg (<= 0.15 heißt: aus dem Wasser befahrbar, sonst Ollie nötig).
func ride_info(travel: Vector3) -> Dictionary:
	var d := 1.0 if forward_world().dot(travel) >= 0.0 else -1.0
	var hl := length * 0.5
	var entry_h := height_local(-d * (hl - 0.05), 0.0)
	var top_h := maxf(height_local(0.0, 0.0), entry_h)
	var needs_ollie := entry_h > 0.15
	# Kicker/Wedge nur von der flachen Seite – von hinten ist es eine Wand
	var rideable := top_h < 1.4 and entry_h > NONE + 1.0 and not (type in ["ramp", "bump"] and needs_ollie) and type != "ball"
	if needs_ollie and (entry_h > 1.0 or width < 0.8):
		rideable = false          # zu hoch bzw. zu schmal, um sicher draufzuspringen
	return {"entry_h": entry_h, "needs_ollie": needs_ollie, "rideable": rideable}


## Welt -> (u, v)
func to_uv(world: Vector3) -> Vector2:
	var l := _inv * world
	return Vector2(-l.z, l.x)


## Oberkante in Weltkoordinaten oder NONE.
func height_at(x: float, z: float, collision := false) -> float:
	var gp := global_position
	if absf(x - gp.x) > _reach or absf(z - gp.z) > _reach:
		return NONE
	var uv := to_uv(Vector3(x, 0.0, z))
	return height_local(uv.x, uv.y, collision)


# ---------------------------------------------------------------- Grafik

func _ready() -> void:
	_inv = global_transform.affine_inverse()
	var white := Util.mat(Color(0.93, 0.94, 0.93), 0.55)
	if color == "grey":
		white = Util.mat(Color(0.62, 0.64, 0.66), 0.45)
	match type:
		"rail":
			_build_rail(white)
		"pipe":
			var hl := length * 0.5
			if ramp_in > 0.0:
				_build_heightfield(white, 10, 14, -hl, -hl + ramp_in)
			if ramp_out > 0.0:
				_build_heightfield(white, 10, 14, hl - ramp_out, hl)
			var tube := CylinderMesh.new()
			tube.top_radius = radius
			tube.bottom_radius = radius
			tube.height = length - ramp_in - ramp_out
			tube.radial_segments = 18
			var mi := MeshInstance3D.new()
			mi.mesh = tube
			mi.material_override = white
			mi.rotation.x = PI * 0.5
			mi.position = Vector3(0.0, center_y, (ramp_out - ramp_in) * 0.5)   # lokal -Z = Fahrtrichtung
			add_child(mi)
		"ball":
			var ball := SphereMesh.new()
			ball.radius = radius
			ball.height = radius * 2.0
			ball.radial_segments = 32
			ball.rings = 16
			var rubber := Util.mat(Color(0.05, 0.12, 0.55), 0.3)
			rubber.clearcoat_enabled = true
			rubber.clearcoat = 0.6
			var mi := MeshInstance3D.new()
			mi.mesh = ball
			mi.material_override = rubber
			mi.position.y = center_y
			add_child(mi)
			# Ventil oben und Ankerleine nach unten
			Util.sphere(self, 0.03, Vector3(0.0, center_y + radius, 0.0), Util.mat(Color(0.05, 0.05, 0.05), 0.5))
			Util.beam(self, Vector3(0.0, center_y - radius + 0.05, 0.0), Vector3(0.0, -1.5, 0.0), 0.008, Util.mat(Color(0.2, 0.2, 0.2), 0.8))
		"bump":
			_build_heightfield(white, 12, 12)
		"ramp":
			_build_heightfield(white, 14, 2)
		"transition":
			_build_heightfield(white, 30, 12)
			var black := Util.mat(Color(0.06, 0.06, 0.07), 0.35)
			var hl := length * 0.5
			var rx := -inner_v * (width * 0.5 - 0.1)
			# Rail nur auf dem flachen Oberteil: beginnt und endet dort, wo die schrägen Auffahrten oben ankommen
			Util.beam(self, Vector3(rx, height + 0.02, hl - ramp_in), Vector3(rx, height + 0.02, -hl + ramp_out), 0.07, black)
		_:
			_build_heightfield(white, 24, 12 if side_ramp > 0.0 else 2)


## Allgemeine Form: Oberfläche aus height_local() + senkrechte Wände bis unter Wasser.
## u_from/u_to begrenzen auf einen Abschnitt (z. B. nur die Auffahrrampen).
func _build_heightfield(mat: Material, nu: int, nv: int, u_from := -INF, u_to := INF) -> void:
	var hl := length * 0.5
	var u0 := maxf(-hl, u_from)
	var u1 := minf(hl, u_to)
	var hw := width * 0.5
	if type == "pipe":
		hw = radius * 0.8
	elif type == "rail":
		hw = 0.19
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := func(i: int, j: int) -> Vector3:
		var u := lerpf(u0, u1, float(i) / nu)
		var v := lerpf(-hw, hw, float(j) / nv)
		var h := height_local(clampf(u, -hl + 0.001, hl - 0.001), clampf(v, -hw + 0.001, hw - 0.001))
		return Vector3(v, maxf(h, BOTTOM + 0.05), -u)
	# Oberseite
	for i in nu:
		for j in nv:
			_quad(st, p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), Vector3.UP)
	# Seitenwände
	for i in nu:
		for j: int in [0, nv]:
			var a: Vector3 = p.call(i, j)
			var b: Vector3 = p.call(i + 1, j)
			_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(signf(a.x), 0, 0))
	# Stirnseiten
	for j in nv:
		for i: int in [0, nu]:
			var a: Vector3 = p.call(i, j)
			var b: Vector3 = p.call(i, j + 1)
			_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(0, 0, signf(a.z)))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func _build_rail(white: Material) -> void:
	var steel := Util.mat(Color(0.55, 0.57, 0.6) if rail_color == "grey" else Color(0.08, 0.08, 0.09), 0.35)
	steel.metallic = 0.6
	var hl := length * 0.5
	# Übergangsrampen (weiße, schmale Auffahrten)
	if ramp_in > 0.0:
		_build_heightfield(white, 12, 2, -hl, -hl + ramp_in)
	if ramp_out > 0.0:
		_build_heightfield(white, 12, 2, hl - ramp_out, hl)
	# Rohr
	var a := -hl + ramp_in * 0.8
	var b := hl - ramp_out * 0.8
	var tube := Util.beam(self, Vector3(0, height - radius * 0.5, -a), Vector3(0, height - radius * 0.5, -b), radius, steel)
	tube.mesh.set("radial_segments", 10)
	# Stützen und Schwimmkörper
	var n := maxi(int((b - a) / 3.0), 1)
	for i in n + 1:
		var u := lerpf(a, b, float(i) / n)
		Util.beam(self, Vector3(0, BOTTOM, -u), Vector3(0, height - radius, -u), 0.05, steel)
		Util.box(self, Vector3(0.7, 0.35, 0.7), Vector3(0, -0.1, -u), white)


## Zwei Dreiecke, Reihenfolge so gedreht, dass die Normale nach "outward" zeigt.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	if Plane(a, b, c).normal.dot(outward) < 0.0:
		var t := b
		b = d
		d = t
	for vtx: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(vtx)
