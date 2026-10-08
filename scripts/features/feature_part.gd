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
const TR_FLAT := 0.26          # Transition Rail: flacher Abschluss oben, darin das Rail
const TR_RAIL_R := 0.14        # Radius des Rails im Transition Rail
const TR_RAIL_UP := 0.07       # so weit schaut es aus dem flachen Abschluss heraus

var part_id := ""
## Glatte Plastikfläche: dort wird nicht geslidet, man rutscht nur geradeaus weiter (kein Lenken).
## "all" = ganze Oberseite (Pyramid), "transition" = Transition, aber nicht das Rail.
var slick := ""
var display_name := ""
var row_index := -1           # Nummer der Zeile im Setup (Gruppen: alle Teile dieselbe)
var group_name := ""          # gehört zu einem Modul aus mehreren Teilen (z. B. Pyramid Series)
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
var profile: Array = []         # Block: Längsprofil [[Abstand vom Anfang (m), Höhe], …] statt height/height_end
var lip := ENTRY               # Höhe, auf der Auffahrten beginnen (ENTRY = unter Wasser, > 0 = sichtbare Kante)
var side_curve := 2.0          # Form der seitlichen Auffahrt: 1 = gerade Schräge, 2 = konkav
var body_curve := 1.0          # Block: Verlauf height -> height_end (1 = gerade, 2 = konkav wie die Transition Curb)
var inner_v := 1.0             # +1/-1: in welche lokale v-Richtung das Seil liegt (setzt FeatureSet)

## Lage auf der Anlage (wird von FeatureSet gesetzt)
var cable: CableSystem
var s_center := 0.0            # Abstand vom Startmast entlang des Seils
var x_center := 0.0            # seitlicher Abstand zum Seil

var _reach := 1.0              # Radius für die schnelle Vorauswahl
var _inv := Transform3D()      # Welt -> lokal (Teile stehen still)
var _catch_mesh: MeshInstance3D  # Debug: Fangzone
var collide := true              # Kollisionskörper bauen (nicht für unsichtbare Katalog-Teile)
const LAYER_COLLIDE := 1 << 11   # Physik-Ebene der Features (Ragdoll prallt daran ab)
var _mesh_only := false        # beim Bau des Körpers: Rail-Wölbung weglassen


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
	body_curve = p.get("body_curve", body_curve)
	side_curve = p.get("side_curve", side_curve)
	lip = p.get("lip", lip)
	profile = p.get("profile", [])
	slick = p.get("slick", "")
	if type == "pipe" or type == "ball":
		width = radius * 2.0
	if type == "ball":
		length = radius * 2.0
	_reach = Vector2(length, width).length() * 0.5 + 0.5


## Gleitet man auf diesem Teil (Box, Rail, Pipe) oder ist es eine Absprungrampe?
func is_slide() -> bool:
	return type in ["block", "rail", "pipe", "transition"]


# Fangzone der Slider (Rail, Pipe, schmale Ledge, Rail im Transition Rail): wer im Sprung hier
# hineinfällt, gleitet aufs Rail statt daneben zu landen oder dagegen zu fliegen.
const CATCH_SIDE := 0.75         # m seitlich neben der Rail-Achse
const CATCH_DOWN := 0.6          # m unter der Oberkante (an den Seiten nach unten)
const CATCH_UP := 0.5            # m über der Oberkante
const CATCH_MIN_TOP := 0.15      # an den Enden (Auffahrt im Wasser) wird nicht gefangen


## Hat dieses Teil eine Fangzone (schmaler Slider)?
func can_catch() -> bool:
	return type in ["rail", "pipe", "transition"] or (type == "block" and width <= 1.0)


## Seitliche Lage der Slide-Linie (lokal v).
func catch_v() -> float:
	return -inner_v * (width * 0.5 - TR_FLAT * 0.5) if type == "transition" else 0.0


## Liegt world in der Fangzone? Dann Zielpunkt auf der Slide-Linie (Welt, auf der Oberkante),
## sonst Vector3.INF.
func catch_target(world: Vector3) -> Vector3:
	if not can_catch():
		return Vector3.INF
	var l := _inv * world
	var u := -l.z
	if absf(u) > length * 0.5:
		return Vector3.INF
	var v0 := catch_v()
	if absf(l.x - v0) > CATCH_SIDE:
		return Vector3.INF
	var top := height_local(u, v0)
	if top < CATCH_MIN_TOP:
		return Vector3.INF
	if world.y < top - CATCH_DOWN or world.y > top + CATCH_UP:
		return Vector3.INF
	return global_transform * Vector3(v0, top, -u)


## Debug: Fangzone als halbdurchsichtiger Körper (an/aus).
func show_catch_zone(on: bool) -> void:
	if _catch_mesh:
		_catch_mesh.visible = on
		return
	if not on or not can_catch():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v0 := catch_v()
	var hl := length * 0.5
	var n := maxi(int(length / 0.25), 2)
	var prev: Array = []
	for i in n + 1:
		var u := lerpf(-hl, hl, float(i) / n)
		var top := height_local(u, v0)
		var ring: Array = []
		if top >= CATCH_MIN_TOP:
			for c: Vector2 in [Vector2(-CATCH_SIDE, -CATCH_DOWN), Vector2(CATCH_SIDE, -CATCH_DOWN),
					Vector2(CATCH_SIDE, CATCH_UP), Vector2(-CATCH_SIDE, CATCH_UP)]:
				ring.append(Vector3(v0 + c.x, top + c.y, -u))
		if not prev.is_empty() and not ring.is_empty():
			for k in 4:
				var a: Vector3 = prev[k]
				var b: Vector3 = prev[(k + 1) % 4]
				var c2: Vector3 = ring[(k + 1) % 4]
				var d: Vector3 = ring[k]
				for vtx: Vector3 in [a, b, c2, a, c2, d]:
					st.add_vertex(vtx)
		prev = ring
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.1, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	_catch_mesh = MeshInstance3D.new()
	_catch_mesh.mesh = st.commit()
	_catch_mesh.material_override = mat
	_catch_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_catch_mesh)


## Steht man an dieser Stelle auf glattem Plastik (kein Slide, nur Rutschen, kein Lenken)?
func is_slick_at(world: Vector3) -> bool:
	match slick:
		"all":
			return true
		"transition":
			var w := -(_inv * world).x * inner_v               # > 0 Richtung Rail
			return absf(w - (width * 0.5 - TR_FLAT * 0.5)) > TR_FLAT * 0.5 + TR_RAIL_R
	return false


## Einloggen beim Slide: Längsachse des Teils (Welt, waagerecht).
func lock_axis() -> Vector3:
	var a := global_basis.z
	a.y = 0.0
	return a.normalized()


## Einloggen beim Slide: seitliche Korrektur (Welt) zur Slide-Spur – Rail/Pipe mittig, beim
## Transition Rail aufs Rail (nur wenn man in dessen Nähe ist), auf breiten Boxen nur weg vom Rand.
func lock_offset(world: Vector3) -> Vector3:
	var v := (_inv * world).x
	var target := v
	match type:
		"rail", "pipe":
			target = 0.0
		"transition":
			var rail := -inner_v * (width * 0.5 - TR_FLAT * 0.5)
			if absf(v - rail) < 0.6:
				target = rail
		_:
			var m := maxf(width * 0.5 - 0.3, 0.0)
			target = clampf(v, -m, m)
	var side := global_basis.x
	side.y = 0.0
	return side.normalized() * (target - v)


## Bevorzugte Fahrspur über das Teil (seitlicher Abstand zum Seil): Mitte bzw. beim
## Transition Rail direkt am Rail.
func lane_x() -> float:
	if type != "transition":
		return x_center
	var p := global_transform * Vector3(-inner_v * (width * 0.5 - TR_FLAT * 0.5), 0.0, 0.0)
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
			if not profile.is_empty():
				return _with_side_ramp(v, _profile_h(u + hl))
			# Verlauf über den Körper (ohne Auffahrten): z. B. Transition Curb konkav von 0,35 auf 1,1 m
			var tb := clampf((u + hl - ramp_in) / maxf(length - ramp_in - ramp_out, 0.01), 0.0, 1.0)
			return _with_side_ramp(v, _with_ramps(u, lerpf(height, height_end, pow(tb, body_curve))))
		"rail":
			if absf(v) > (radius + 0.04 if collision else 0.2):   # Toleranz: so breit "trifft" das Brett den Rail
				return NONE
			return _with_ramps(u, height)
		"pipe":
			if absf(v) > radius * 0.8:
				return NONE
			return _with_ramps(u, center_y + sqrt(radius * radius - v * v))
		"transition":
			# Querschnitt: konkave Transition von der Seilseite (-v) hoch zu einem flachen
			# Abschluss (TR_FLAT breit), darin das schwarze Rail halb versenkt; hinten senkrechte
			# Wand. Enden: schräge Auffahrten. Das Rail ragt nur TR_RAIL_UP heraus – keine Kante.
			var hw := width * 0.5
			if absf(v) > hw:
				return NONE
			var w := -v * inner_v                     # > 0 Richtung Außenkante (weg vom Seil)
			var h := ENTRY + (height - ENTRY) * pow(clampf((w + hw) / (width - TR_FLAT), 0.0, 1.0), 2.0)
			var d := w - (hw - TR_FLAT * 0.5)          # Abstand zur Rail-Mitte
			if absf(d) < TR_RAIL_R and not _mesh_only:
				h = maxf(h, height + TR_RAIL_UP - TR_RAIL_R + sqrt(TR_RAIL_R * TR_RAIL_R - d * d))
			var top := height + TR_RAIL_UP
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


## Höhe aus dem Längsprofil (lineare Abschnitte zwischen den Stützpunkten).
func _profile_h(d: float) -> float:
	var prev: Array = profile[0]
	for k in range(1, profile.size()):
		var pt: Array = profile[k]
		if d <= float(pt[0]):
			var span := maxf(float(pt[0]) - float(prev[0]), 0.001)
			return lerpf(float(prev[1]), float(pt[1]), clampf((d - float(prev[0])) / span, 0.0, 1.0))
		prev = pt
	return float(prev[1])


## Übergangsrampen an Anfang/Ende (geschwungen, wie die "Transitions" der echten Features).
func _with_ramps(u: float, h: float) -> float:
	var hl := length * 0.5
	if ramp_in > 0.0 and u < -hl + ramp_in:
		h = minf(h, lerpf(lip, h, pow((u + hl) / ramp_in, ramp_curve)))
	if ramp_out > 0.0 and u > hl - ramp_out:
		h = minf(h, lerpf(lip, h, pow((hl - u) / ramp_out, ramp_curve)))
	return h


## Seitliche Auffahrt auf der Seilseite: von der Innenkante (Wasser) konkav hoch auf h.
func _with_side_ramp(v: float, h: float) -> float:
	if side_ramp <= 0.0:
		return h
	var d := width * 0.5 - v * inner_v         # 0 an der Innenkante
	if d >= side_ramp:
		return h
	return minf(h, lerpf(lip, h, pow(clampf(d / side_ramp, 0.0, 1.0), side_curve)))


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

static var _shader: Shader

static func _feature_shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/feature.gdshader")
	return _shader


func _ready() -> void:
	_inv = global_transform.affine_inverse()
	# Kunststoff mit Gebrauchsspuren (Kratzer, Fahrspur, Algenrand an der Wasserlinie)
	var white := ShaderMaterial.new()
	white.shader = _feature_shader()
	white.set_shader_parameter("half_width", width * 0.5)
	if color == "grey":
		white.set_shader_parameter("base_color", Color(0.62, 0.64, 0.66))
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
			_mesh_only = true      # weißer Körper ohne Rail-Wölbung, das Rail ist ein eigenes Rohr
			_build_heightfield(white, 30, 24)
			_mesh_only = false
			var black := Util.mat(Color(0.06, 0.06, 0.07), 0.35)
			var hl := length * 0.5
			var rx := -inner_v * (width * 0.5 - TR_FLAT * 0.5)
			# Rail im flachen Abschluss versenkt (nur der obere Teil schaut heraus); beginnt und
			# endet dort, wo die schrägen Auffahrten oben ankommen
			var ry := height + TR_RAIL_UP - TR_RAIL_R
			var tube := Util.beam(self, Vector3(rx, ry, hl - ramp_in), Vector3(rx, ry, -hl + ramp_out), TR_RAIL_R, black)
			tube.mesh.set("radial_segments", 16)
		_:
			_build_heightfield(white, 24 if profile.is_empty() else int(length * 8.0), 12 if side_ramp > 0.0 else 2)
	if collide:
		_build_collider()


## Kollisionskörper aus der sichtbaren Form (alle Dreiecke): daran prallt die Ragdoll beim
## Sturz ab bzw. bleibt darauf liegen. Die Fahrphysik nutzt weiter height_local().
func _build_collider() -> void:
	var faces := PackedVector3Array()
	for c in get_children():
		if c is MeshInstance3D and c != _catch_mesh and (c as MeshInstance3D).mesh:
			var mi := c as MeshInstance3D
			for v in mi.mesh.get_faces():
				faces.append(mi.transform * v)
	if faces.is_empty():
		return
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_COLLIDE
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)


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
	# Harte Kanten: jede Fläche bekommt eine eigene Glättungsgruppe, sonst rundet
	# generate_normals() die Kanten zwischen Oberseite und Wänden ab (Ledges sähen rund aus).
	# Nur geschwungene Oberseiten (Transitions, Kicker, Bump) werden in sich geglättet.
	var curved := type in ["ramp", "transition", "bump", "pipe"] or (side_ramp > 0.0 and side_curve > 1.0) or body_curve > 1.0 \
		or (ramp_curve > 1.0 and (ramp_in > 0.0 or ramp_out > 0.0))
	st.set_smooth_group(1 if curved else 0xFFFFFFFF)
	# Oberseite
	for i in nu:
		for j in nv:
			_quad(st, p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), Vector3.UP)
	# Wände immer flach (scharfe Kanten)
	st.set_smooth_group(0xFFFFFFFF)
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
