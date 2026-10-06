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

var _reach := 1.0              # Radius für die schnelle Vorauswahl
var _inv := Transform3D()      # Welt -> lokal (Teile stehen still)


func setup(id: String, p: Dictionary) -> void:
	part_id = id
	display_name = p.get("name", id)
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
	if type == "pipe":
		width = radius * 2.0
	_reach = Vector2(length, width).length() * 0.5 + 0.5


## Gleitet man auf diesem Teil (Box, Rail, Pipe) oder ist es eine Absprungrampe?
func is_slide() -> bool:
	return type in ["block", "rail", "pipe"]


# ---------------------------------------------------------------- Form

## Oberkante an lokaler Position (u, v) oder NONE.
func height_local(u: float, v: float) -> float:
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
			return _with_ramps(u, lerpf(height, height_end, t))
		"rail":
			if absf(v) > 0.2:                        # Toleranz: so breit "trifft" das Brett den Rail
				return NONE
			return _with_ramps(u, height)
		"pipe":
			if absf(v) > radius * 0.8:
				return NONE
			return _with_ramps(u, center_y + sqrt(radius * radius - v * v))
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
		var t := (u + hl) / ramp_in
		h = minf(h, lerpf(ENTRY, h, 1.0 - pow(1.0 - t, 2.0)))
	if ramp_out > 0.0 and u > hl - ramp_out:
		var t := (hl - u) / ramp_out
		h = minf(h, lerpf(ENTRY, h, 1.0 - pow(1.0 - t, 2.0)))
	return h


## Welt -> (u, v)
func to_uv(world: Vector3) -> Vector2:
	var l := _inv * world
	return Vector2(-l.z, l.x)


## Oberkante in Weltkoordinaten oder NONE.
func height_at(x: float, z: float) -> float:
	var gp := global_position
	if absf(x - gp.x) > _reach or absf(z - gp.z) > _reach:
		return NONE
	var uv := to_uv(Vector3(x, 0.0, z))
	return height_local(uv.x, uv.y)


# ---------------------------------------------------------------- Grafik

func _ready() -> void:
	_inv = global_transform.affine_inverse()
	var white := Util.mat(Color(0.93, 0.94, 0.93), 0.55)
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
		"bump":
			_build_heightfield(white, 12, 12)
		"ramp":
			_build_heightfield(white, 14, 2)
		_:
			_build_heightfield(white, 24, 2)


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
