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
const CREASE := 10.0           # Grad: stärkerer Knick zwischen Nachbarflächen der Oberseite = harte Kante (sonst glatt)
const TR_FLAT := 0.36          # Transition Rail: flacher Abschluss oben, darin das Rail
const TR_RAIL_R := 0.23        # Radius des Rails im Transition Rail: steht je 5 cm über den flachen Abschluss (TR_FLAT) über
const TR_RAIL_UP := 0.345      # so weit ragt es aus dem flachen Abschluss heraus (3/4 des Durchmessers, unteres Viertel im Körper)
const TR_TUCK := 0.015         # Transition Rail: das Rail steht zur Transition hin nur so weit über (außen 5 cm)
const TR_LIP := 0.3            # nur Physik: weiche Auffahrt aufs Rail beginnt so weit vor dem Ende der Transition

var part_id := ""
## Glatte Plastikfläche: dort wird nicht geslidet, man rutscht nur geradeaus weiter (kein Lenken).
## "all" = ganze Oberseite (Pyramid), "transition" = Transition, aber nicht das Rail.
var slick := ""
## Ganze Oberseite fährt man wie einen Kicker (kein Slide, nicht glatt), z. B. Transition Curb.
var kicker := false
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
var top_rail := 0.0             # Block: Oberseite als schwarzes Halbrund-Rail (Radius, z. B. A-Frame Rail); profile = Unterkante der Rundung
var safety_slope := 0.0         # Block: steile, gerade Safety an beiden Enden (Steigung), schneidet oben ins Halbrund
var safety_back_slope := NAN    # Block: Steigung der Safety hinten (NAN = wie vorne, 0 = keine)
var safety_back_h := ENTRY      # Block: Höhe, auf der die Safety hinten beginnt (z. B. auf der Box der Port Plaza)
var safety_h := ENTRY           # Block: Höhe, auf der die Safety vorne beginnt (Ausgänge des Pools: auf dem Beckenrand)
var lip := ENTRY               # Höhe, auf der Auffahrten beginnen (ENTRY = unter Wasser, > 0 = sichtbare Kante)
var side_lip := NAN            # dasselbe für die seitliche Auffahrt (NAN = wie lip)
var side_curve := 2.0          # Form der seitlichen Auffahrt: 1 = gerade Schräge, 2 = konkav
var round_top := false         # Block: Oberkante quer halbrund (Coping, z. B. Plaza Rail)
var black_top: Array = []       # Block: Abschnitt [von, bis] (m ab Anfang), dessen Oberseite schwarz ist (Plaza Rail)
var body_curve := 1.0          # Block: Verlauf height -> height_end (1 = gerade, 2 = konkav wie die Transition Curb)
var floor_h := 0.5             # Pool: Höhe des Beckenbodens (height = Wasserspiegel)
var steps := 6                 # Treppe: Anzahl der Stufen (von height bis zum See)
var water_mesh: MeshInstance3D # Pool: Wasserfläche (im Spiel bekommt sie von Water das Material des Sees)
var inner_v := 1.0             # +1/-1: in welche lokale v-Richtung das Seil liegt (setzt FeatureSet)

## Lage auf der Anlage (wird von FeatureSet gesetzt)
var cable: CableSystem
var s_center := 0.0            # Abstand vom Startmast entlang des Seils
var x_center := 0.0            # seitlicher Abstand zum Seil

var _reach := 1.0              # Radius für die schnelle Vorauswahl
var _inv := Transform3D()      # Welt -> lokal (Teile stehen still)
var _catch_mesh: MeshInstance3D  # Debug: Fangzone
var _slick_mesh: MeshInstance3D  # Debug: glatte Flächen
var _ramp_mesh: MeshInstance3D   # Debug: Safety/Auffahrt/Kicker
var collide := true              # Kollisionskörper bauen (nicht für unsichtbare Katalog-Teile)
const LAYER_COLLIDE := 1 << 11   # Physik-Ebene der Features (Ragdoll prallt daran ab)


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
	side_lip = p.get("side_lip", lip)
	profile = p.get("profile", [])
	top_rail = p.get("top_rail", 0.0)
	safety_slope = p.get("safety_slope", 0.0)
	safety_back_slope = p.get("safety_back_slope", safety_slope)
	safety_back_h = p.get("safety_back_h", ENTRY)
	safety_h = p.get("safety_h", ENTRY)
	round_top = p.get("round_top", false)
	black_top = p.get("black_top", [])
	slick = p.get("slick", "")
	kicker = p.get("kicker", false)
	floor_h = p.get("floor", floor_h)
	steps = int(p.get("steps", steps))
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
const CATCH_SIDE := 0.55         # m seitlich neben der Rail-Achse
const CATCH_DOWN := 0.45         # m unter der Oberkante (an den Seiten nach unten)
const CATCH_UP := 1.3            # m über der Oberkante (hoch: wer darüber ↑/↓ drückt, presst statt zu rollen)
const CATCH_MIN_TOP := 0.15      # an den Enden (Auffahrt im Wasser) wird nicht gefangen


## Hat dieses Teil eine Fangzone (schmaler Slider)?
func can_catch() -> bool:
	return type in ["rail", "pipe", "transition"] or (type == "block" and width <= 1.0)


## Seitliche Lage der Slide-Linie (lokal v).
func catch_v() -> float:
	return -inner_v * (width * 0.5 - TR_FLAT * 0.5) if type == "transition" else 0.0


## Liegt world (nur x/z) über dem Slider oder knapp daneben (margin m)? Höhe egal.
func over_slider(world: Vector3, margin: float) -> bool:
	if not is_slide():
		return false
	var l := _inv * world
	if absf(l.z) > length * 0.5 + margin:
		return false
	return absf(l.x - catch_v()) <= maxf(width * 0.5, CATCH_SIDE) + margin


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


## Debug (F3): glattes Plastik blau (nur rutschen), Safety/Auffahrt und Kicker orange (fährt man
## wie einen Kicker, kein Slide).
func _show_slick(on: bool) -> void:
	if _slick_mesh or _ramp_mesh or not on:
		if _slick_mesh:
			_slick_mesh.visible = on
		if _ramp_mesh:
			_ramp_mesh.visible = on
		return
	if slick != "":
		_slick_mesh = _paint_surface(func(w: Vector3) -> bool: return is_slick_at(w), Color(0.05, 0.35, 1.0, 0.7))
	if type == "ramp" or type == "bump" or ramp_in > 0.0 or ramp_out > 0.0 or safety_slope > 0.0 or kicker:
		_ramp_mesh = _paint_surface(func(w: Vector3) -> bool: return type == "ramp" or on_ramp(w), Color(1.0, 0.45, 0.05, 0.75))


## Oberseite dort einfärben, wo pred(Weltpunkt) zutrifft (knapp über der Fläche).
func _paint_surface(pred: Callable, color: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hl := length * 0.5
	var hw := width * 0.5
	var nu := maxi(int(length / 0.2), 2)
	var nv := maxi(int(width / 0.1), 2)
	var pt := func(u: float, v: float) -> Vector3:
		return Vector3(v, height_local(clampf(u, -hl + 0.001, hl - 0.001), clampf(v, -hw + 0.001, hw - 0.001)) + 0.03, -u)
	var any := false
	for i in nu:
		for j in nv:
			var u0 := lerpf(-hl, hl, float(i) / nu)
			var u1 := lerpf(-hl, hl, float(i + 1) / nu)
			var v0 := lerpf(-hw, hw, float(j) / nv)
			var v1 := lerpf(-hw, hw, float(j + 1) / nv)
			var mid: Vector3 = pt.call((u0 + u1) * 0.5, (v0 + v1) * 0.5)
			if mid.y < 0.0 or not pred.call(global_transform * mid):
				continue
			any = true
			var a: Vector3 = pt.call(u0, v0)
			var b: Vector3 = pt.call(u1, v0)
			var c: Vector3 = pt.call(u1, v1)
			var d: Vector3 = pt.call(u0, v1)
			for vtx: Vector3 in [a, b, c, a, c, d]:
				st.add_vertex(vtx)
	if not any:
		return null
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


## Debug: Fangzone als halbdurchsichtiger Körper (an/aus), dazu die glatten Flächen.
func show_catch_zone(on: bool) -> void:
	_show_slick(on)
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
	if on_ramp(world):
		return false                 # Safety/Auffahrt fährt man wie einen Kicker
	match slick:
		"all":
			return true
		"top":
			return _on_bump_top(world)
		"transition":
			var w := -(_inv * world).x * inner_v               # > 0 Richtung Rail
			return absf(w - (width * 0.5 - TR_FLAT * 0.5)) > TR_FLAT * 0.5 + TR_RAIL_R
	return false


## Steht man auf einer Safety bzw. Auffahrt (kurze Schräge vorne/hinten)? Die fährt man wie
## einen Kicker: kein Slide, kein glattes Plastik, kein Einloggen.
func on_ramp(world: Vector3) -> bool:
	if kicker:
		return true                      # ganzes Teil wie ein Kicker (Transition Curb)
	if safety_slope > 0.0:
		var uv := to_uv(world)
		return _on_safety(uv.x, uv.y)    # steile Safety vor dem Halbrund-Rail (A-Frame Rail)
	if type == "bump":
		return not _on_bump_top(world)   # Bump: alle Seiten sind Kicker, nur oben flach
	var u := -(_inv * world).z
	var hl := length * 0.5
	return (ramp_in > 0.0 and u < -hl + ramp_in) or (ramp_out > 0.0 and u > hl - ramp_out)


## Bump: liegt world auf der flachen Spitze (Breite top)?
func _on_bump_top(world: Vector3) -> bool:
	var l := _inv * world
	var r := top * 0.5 + 0.01
	return absf(l.z) <= r and absf(l.x) <= r


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
			if round_top:
				# Coping: quer halbrund, an den Seiten so tief wie der halbe Querschnitt
				var r := width * 0.5
				var drop := r - sqrt(maxf(r * r - v * v, 0.0))
				var hr := _profile_h(u + hl) if not profile.is_empty() else _with_ramps(u, height)
				return hr - drop if hr - drop > ENTRY else hr
			if not profile.is_empty():
				return _with_top_rail(u, v, _with_side_ramp(v, _profile_h(u + hl)))
			# Verlauf über den Körper (ohne Auffahrten): z. B. Transition Curb konkav von 0,35 auf 1,1 m
			var tb := clampf((u + hl - ramp_in) / maxf(length - ramp_in - ramp_out, 0.01), 0.0, 1.0)
			var body := lerpf(height, height_end, pow(tb, body_curve))
			# Auffahrten vorne/hinten und seitlich sind eigenständige Transitions, ineinandergeschoben
			# (Minimum): wo sie sich schneiden, entsteht der Grat (Pyramid)
			return minf(_with_ramps(u, body), _with_side_ramp(v, body))
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
			# Abschluss (TR_FLAT breit), darauf das dicke schwarze Rail (unteres Viertel versenkt); hinten senkrechte
			# Wand. Enden: gerade Auffahrten. Das Rail ragt TR_RAIL_UP heraus.
			var hw := width * 0.5
			if absf(v) > hw:
				return NONE
			var w := -v * inner_v                     # > 0 Richtung Außenkante (weg vom Seil)
			var h := maxf(_tr_env(w), _tr_lip(w))      # Rail rund, von der Transition her weich auffahrbar
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
		"pool":
			# Becken: gefahren wird auf dem Wasser (Water.height_at kennt den Wasserspiegel), kein Hindernis.
			# Nur die Ragdoll stößt auf den Boden.
			if absf(v) > width * 0.5 or not collision:
				return NONE
			return floor_h
		"stairs":
			# Physik: das Brett liegt auf den Stufenkanten auf – Linie von der obersten Kante (Höhe des
			# Beckenwassers) bis zur untersten im See. Die Grafik zeigt die Stufen (_stair_h).
			if absf(v) > width * 0.5:
				return NONE
			var d := length / (steps + 1)
			return lerpf(height, 0.0, clampf((u + hl - d) / (length - d), 0.0, 1.0))
	return NONE


## Treppe: Höhe der Trittfläche (Stufe k von oben, k = 0 auf Höhe des Beckenwassers, k = steps im See).
func _stair_h(u: float) -> float:
	var d := length / (steps + 1)
	var k := clampi(int(floor((u + length * 0.5) / d)), 0, steps)
	return height - k * height / steps


## Liegt (x, z) im Grundriss des Teils?
func contains(x: float, z: float) -> bool:
	var l := _inv * Vector3(x, 0.0, z)
	return absf(l.x) <= width * 0.5 and absf(l.z) <= length * 0.5


## Pool: Wasserspiegel im Becken an (x, z), sonst NONE.
func pool_level_at(x: float, z: float) -> float:
	if type != "pool" or not contains(x, z):
		return NONE
	return height


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


## Halbrund-Rail als Oberseite (A-Frame Rail) und davor/dahinter die steile, gerade Safety:
## die Ebene der Safety schneidet ins Halbrund, von oben gesehen entsteht eine U-förmige Grenze.
func _with_top_rail(u: float, v: float, h: float) -> float:
	if top_rail > 0.0 and absf(v) < top_rail:
		h += sqrt(top_rail * top_rail - v * v)
	if safety_slope > 0.0:
		h = minf(h, _safety_h(u))
	return h


## Höhe der Safety-Ebene (steigt von beiden Enden an, vorne aus dem Wasser).
func _safety_h(u: float) -> float:
	if u > 0.0:
		if safety_back_slope <= 0.0:
			return INF
		return safety_back_h + safety_back_slope * (length * 0.5 - u)
	return safety_h + safety_slope * (length * 0.5 + u)


## Liegt (u, v) auf der Safety statt auf dem Halbrund-Rail?
func _on_safety(u: float, v: float) -> bool:
	if safety_slope <= 0.0:
		return false
	var rail := _profile_h(u + length * 0.5) + (sqrt(top_rail * top_rail - v * v) if absf(v) < top_rail else 0.0)
	return _safety_h(u) < rail


## Ende der vorderen Safety in der Mitte (lokal u): dort beginnt die Oberseite.
func _safety_end() -> float:
	var lo := -length * 0.5
	var hi := 0.0
	for _k in 30:
		var mid := (lo + hi) * 0.5
		if _on_safety(mid, 0.0):
			lo = mid
		else:
			hi = mid
	return hi


## Seitliche Auffahrt auf der Seilseite: von der Innenkante (Wasser) konkav hoch auf h.
func _with_side_ramp(v: float, h: float) -> float:
	if side_ramp <= 0.0:
		return h
	var d := width * 0.5 - v * inner_v         # 0 an der Innenkante
	if d >= side_ramp:
		return h
	return minf(h, lerpf(side_lip, h, pow(clampf(d / side_ramp, 0.0, 1.0), side_curve)))


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
static var _rail_shader: Shader

static func _feature_shader() -> Shader:
	if _shader == null:
		_shader = load("res://shaders/feature.gdshader")
	return _shader


## Zufall je Teil (0..20) aus Lage und Bauteil: jedes Feature hat eigene Kratzer und Flecken.
func _seed() -> float:
	var p := global_position
	return float(absi(hash("%s %d %d" % [part_id, roundi(p.x * 10.0), roundi(p.z * 10.0)])) % 2000) * 0.01


## Schwarzes Rail: matt mit Längskratzern. tube = Rohr aus Util.beam (Achse lokal Y).
func _rail_mat(tube := false, r := 0.05) -> ShaderMaterial:
	if _rail_shader == null:
		_rail_shader = load("res://shaders/feature_rail.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _rail_shader
	m.set_shader_parameter("tube", tube)
	m.set_shader_parameter("tube_r", r)
	m.set_shader_parameter("seed", _seed())
	return m


## Nasser Look des weißen Kunststoffs (im F4-Panel regelbar, Reiter „Features“)
static var WET_DARK := 0.052     # so viel dunkler wird der nasse Kunststoff (0 = weiß wie trocken; mehr = Spiegelung dominiert)
static var WET_FRESNEL := 0.82   # flach geschaut tritt das Weiß so weit zugunsten der Spiegelung zurück
static var WET_ROUGH := 0.151    # Rauheit des Wasserfilms (0 = Spiegel, 0,3 = verschwommen)
static var WET_COAT := 0.396      # Stärke der Klarlack-Schicht (zweiter, glatter Glanz)
static var REFLECT := 0.464       # Helligkeit der Umgebungsspiegelung (Reflection Probes, ab Grafik Mittel)
var _white: ShaderMaterial


func _apply_wet() -> void:
	if _white:
		_white.set_shader_parameter("wet_dark", WET_DARK)
		_white.set_shader_parameter("wet_fresnel", WET_FRESNEL)
		_white.set_shader_parameter("wet_rough", WET_ROUGH)
		_white.set_shader_parameter("wet_coat", WET_COAT)
	for c in get_children():
		if c is ReflectionProbe:
			(c as ReflectionProbe).intensity = REFLECT * Weather.reflect


## F4-Panel: geänderte Werte sofort auf alle Features übertragen
static func debug_changed() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree:
		for p in tree.get_nodes_in_group("feature_parts"):
			(p as FeaturePart)._apply_wet()


func _ready() -> void:
	_inv = global_transform.affine_inverse()
	# Kunststoff mit Gebrauchsspuren (Kratzer, Fahrspur, Algenrand an der Wasserlinie)
	var white := ShaderMaterial.new()
	white.shader = _feature_shader()
	white.set_shader_parameter("half_width", width * 0.5)
	white.set_shader_parameter("seed", _seed())
	_white = white
	_apply_wet()
	add_to_group("feature_parts")
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
			Weather.dim_at_night(rubber)
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
		"pool":
			_build_pool()
		"stairs":
			_build_stairs(white)
		"transition":
			_build_transition_body(white)
			_build_transition_rail(_rail_mat())
		_:
			if top_rail > 0.0:
				# Halbrund-Rail schwarz, Safetys und Wände weiß
				_build_heightfield(white, int(length * 4.0), 2, -INF, INF, func(_u: float, _v: float) -> bool: return false)
				_build_rail_top(white, _rail_mat())
			elif side_ramp > 0.0 and profile.is_empty() and not round_top and body_curve == 1.0 and height_end == height:
				_build_pyramid(white)
			else:
				_build_heightfield(white, 24 if profile.is_empty() else int(length * 8.0), 12 if side_ramp > 0.0 or round_top else 2)
				if black_top.size() == 2:
					_build_black_top(float(black_top[0]), float(black_top[1]))
	if collide:
		_build_collider()


const COLLIDE_BOTTOM := -1.5     # Kollisionskörper reicht so tief: niemand taucht unter einem Feature durch
const COLLIDE_STEP := 0.4        # m: Zellgröße der Kollisionskörper (dazu Linien auf allen Knicken)
static var _collide_mat: PhysicsMaterial


## Kollisionskörper aus height_local() (Form = Physik): massive, konvexe Säulen von der Oberkante
## bis tief unters Wasser. Früher ein hohles Dreiecksnetz – schnelle Kapseln der Ragdoll rutschten
## hindurch und fielen dann innen bzw. unter das Feature, eingeklemmte Knochen rissen die Figur auseinander.
## Konvexe Körper drücken immer zur nächsten Außenseite. Nasses Plastik: glatt, federt etwas.
func _build_collider() -> void:
	if _collide_mat == null:
		_collide_mat = PhysicsMaterial.new()
		_collide_mat.friction = 0.35
		_collide_mat.bounce = 0.3
	var body := StaticBody3D.new()
	body.collision_layer = LAYER_COLLIDE
	body.collision_mask = 0
	body.physics_material_override = _collide_mat
	add_child(body)
	var owner_id := body.create_shape_owner(body)
	if type == "pool" or type == "stairs":
		# Beckenboden bzw. je Stufe ein massiver Block bis tief unters Wasser
		var n := 1 if type == "pool" else steps + 1
		var d := length / n
		for k in n:
			var top := floor_h if type == "pool" else _stair_h(-length * 0.5 + (k + 0.5) * d)
			var box := BoxShape3D.new()
			box.size = Vector3(width, top - COLLIDE_BOTTOM, d)
			var sid := body.create_shape_owner(body)
			body.shape_owner_add_shape(sid, box)
			body.shape_owner_set_transform(sid, Transform3D(Basis.IDENTITY,
				Vector3(0.0, (top + COLLIDE_BOTTOM) * 0.5, -(-length * 0.5 + (k + 0.5) * d))))
		return
	if type == "ball":
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		body.shape_owner_add_shape(owner_id, sphere)
		body.shape_owner_set_transform(owner_id, Transform3D(Basis.IDENTITY, Vector3(0.0, center_y, 0.0)))
		return
	var hl := length * 0.5
	var hw := width * 0.5
	match type:
		"pipe":
			hw = radius * 0.8
		"rail":
			hw = radius + 0.04
	var u_breaks: Array[float] = [-hl + ramp_in, hl - ramp_out]
	if safety_slope > 0.0 and top_rail == 0.0:
		u_breaks.append(_safety_end())          # Kante Safety -> Oberseite scharf
	for pt: Array in profile:
		u_breaks.append(-hl + float(pt[0]))
	var v_breaks: Array[float] = []
	if side_ramp > 0.0:
		v_breaks.append((width * 0.5 - side_ramp) * inner_v)
	if top_rail > 0.0:
		v_breaks.append_array([-top_rail, top_rail])
	var us := _grid_lines(-hl, hl, maxi(ceili(length / COLLIDE_STEP), 1), u_breaks)
	var h_at := func(u: float, v: float) -> float:
		var h := height_local(clampf(u, -hl + 0.001, hl - 0.001), clampf(v, -hw + 0.001, hw - 0.001), true)
		return maxf(h, COLLIDE_BOTTOM)
	# Quer flach (die meisten Boxen, Kicker, Ledges): eine Säule über die ganze Breite
	var flat := true
	for u in us:
		var h0: float = h_at.call(u, 0.0)
		for k in 5:
			if absf(float(h_at.call(u, lerpf(-hw, hw, k / 4.0))) - h0) > 0.02:
				flat = false
	var vs := PackedFloat32Array([-hw, hw]) if flat else _grid_lines(-hw, hw, maxi(ceili(hw * 2.0 / 0.25), 2), v_breaks)
	for i in us.size() - 1:
		for j in vs.size() - 1:
			var corners := [Vector2(us[i], vs[j]), Vector2(us[i + 1], vs[j]), Vector2(us[i], vs[j + 1]), Vector2(us[i + 1], vs[j + 1])]
			var pts := PackedVector3Array()
			var high := false
			for c: Vector2 in corners:
				var h: float = h_at.call(c.x, c.y)
				high = high or h > ENTRY - 0.2
				pts.append(Vector3(c.y, h, -c.x))
				pts.append(Vector3(c.y, COLLIDE_BOTTOM - 0.1, -c.x))
			if not high:
				continue
			var shape := ConvexPolygonShape3D.new()
			shape.points = pts
			body.shape_owner_add_shape(owner_id, shape)


## Allgemeine Form: Oberfläche aus height_local() + senkrechte Wände bis unter Wasser.
## u_from/u_to begrenzen auf einen Abschnitt (z. B. nur die Auffahrrampen).
## top_pred(u, v): nur diese Stücke der Oberseite (z. B. Safety weiß, Rail schwarz); walls: Wände mitbauen.
func _build_heightfield(mat: Material, nu: int, nv: int, u_from := -INF, u_to := INF, top_pred := Callable(), walls := true) -> void:
	var hl := length * 0.5
	var u0 := maxf(-hl, u_from)
	var u1 := minf(hl, u_to)
	var hw := width * 0.5
	if type == "pipe":
		hw = radius * 0.8
	elif type == "rail":
		hw = 0.19
	# Gitterlinien gleichmäßig plus genau auf den Knickstellen (Ende der Auffahrten, Profil-Stützpunkte,
	# Kante der seitlichen Auffahrt, Halbrund-Rail) – sonst liegt ein Knick mitten in einer Masche und
	# die Kante wird über die ganze Masche abgeschrägt (sah rund und verschwommen aus).
	if side_ramp > 0.0 or top_rail > 0.0:
		nv = maxi(nv, int(hw * 2.0 * 6.0))
	var u_breaks: Array[float] = [-hl + ramp_in, hl - ramp_out]
	if safety_slope > 0.0 and top_rail == 0.0:
		u_breaks.append(_safety_end())          # Kante Safety -> Oberseite scharf
	for pt: Array in profile:
		u_breaks.append(-hl + float(pt[0]))
	var v_breaks: Array[float] = []
	if side_ramp > 0.0:
		v_breaks.append((width * 0.5 - side_ramp) * inner_v)
	if top_rail > 0.0:
		v_breaks.append_array([-top_rail, top_rail])
	if type == "bump":
		# flache Spitze: Kante bei d = top_r (gleicher Anteil in u und v, damit die Grate durch die Gitterpunkte laufen)
		var top_r := top / maxf(length, width)
		u_breaks.append_array([-top_r * hl, top_r * hl])
		v_breaks.append_array([-top_r * hw, top_r * hw])
	var us := _grid_lines(u0, u1, nu, u_breaks)
	var vs := _grid_lines(-hw, hw, nv, v_breaks)
	nu = us.size() - 1
	nv = vs.size() - 1
	var p := func(i: int, j: int) -> Vector3:
		var u: float = us[i]
		var v: float = vs[j]
		var h := height_local(clampf(u, -hl + 0.001, hl - 0.001), clampf(v, -hw + 0.001, hw - 0.001))
		return Vector3(v, maxf(h, BOTTOM + 0.05), -u)
	# Oberseite mit eigenen Normalen: Rundungen (Transitions, Kicker, Bump) glatt, echte Knicke
	# (Auffahrt -> flache Oberseite, Seitenkante, Grat) bleiben harte Kanten (CREASE).
	var grid: Array[PackedVector3Array] = []
	for i in nu + 1:
		var row := PackedVector3Array()
		for j in nv + 1:
			row.append(p.call(i, j))
		grid.append(row)
	var up_n := func(x: Vector3, y: Vector3, z: Vector3) -> Vector3:
		var n := (y - x).cross(z - x)
		if n.y < 0.0:
			n = -n
		return n.normalized() if n.length_squared() > 1e-12 else Vector3.UP
	var cos_crease := cos(deg_to_rad(CREASE))
	# Je Masche: entlang der Diagonale teilen, deren Mitte am besten zur echten Höhe passt (so liegen schräge Grate, z. B. am Bump, genau auf
	# der Dreieckskante statt als Treppe). Knickt die Masche selbst (Grat darin), bekommt sie flache
	# Dreiecks-Normalen und zählt beim Glätten der Nachbarn nicht mit (fn = ZERO).
	var fn: Array[PackedVector3Array] = []
	var split_bd: Array[PackedByteArray] = []
	var tri_n: Array[PackedVector3Array] = []
	for i in nu:
		var row := PackedVector3Array()
		var srow := PackedByteArray()
		var trow := PackedVector3Array()
		for j in nv:
			var a := grid[i][j]
			var b := grid[i + 1][j]
			var c := grid[i + 1][j + 1]
			var d := grid[i][j + 1]
			var n1: Vector3 = up_n.call(a, b, c)
			var n2: Vector3 = up_n.call(a, c, d)
			var m1: Vector3 = up_n.call(a, b, d)
			var m2: Vector3 = up_n.call(b, c, d)
			var um := (us[i] + us[i + 1]) * 0.5
			var vm := (vs[j] + vs[j + 1]) * 0.5
			var hm := maxf(height_local(clampf(um, -hl + 0.001, hl - 0.001), clampf(vm, -hw + 0.001, hw - 0.001)), BOTTOM + 0.05)
			var bd := absf((b.y + d.y) * 0.5 - hm) < absf((a.y + c.y) * 0.5 - hm) - 1e-4
			var t1 := m1 if bd else n1
			var t2 := m2 if bd else n2
			srow.append(1 if bd else 0)
			trow.append_array([t1, t2])
			row.append((t1 + t2).normalized() if t1.dot(t2) >= cos_crease else Vector3.ZERO)
		fn.append(row)
		split_bd.append(srow)
		tri_n.append(trow)
	var top_st := SurfaceTool.new()
	top_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_n := 0
	for i in nu:
		for j in nv:
			if top_pred.is_valid():
				if not top_pred.call((us[i] + us[i + 1]) * 0.5, (vs[j] + vs[j + 1]) * 0.5):
					continue
			var a := grid[i][j]
			var b := grid[i + 1][j]
			var c := grid[i + 1][j + 1]
			var d := grid[i][j + 1]
			var tris: Array
			if split_bd[i][j] == 1:
				tris = [[a, b, d, i, j, i + 1, j, i, j + 1], [b, c, d, i + 1, j, i + 1, j + 1, i, j + 1]]
			else:
				tris = [[a, b, c, i, j, i + 1, j, i + 1, j + 1], [a, c, d, i, j, i + 1, j + 1, i, j + 1]]
			for t in 2:
				var tr: Array = tris[t]
				var nf: Vector3 = tri_n[i][j * 2 + t]
				var ns: Array[Vector3] = []
				for k in 3:
					var ci: int = tr[3 + k * 2]
					var cj: int = tr[4 + k * 2]
					var sum := Vector3.ZERO
					if fn[i][j] != Vector3.ZERO:
						for fi in [ci - 1, ci]:
							for fj in [cj - 1, cj]:
								if fi >= 0 and fi < nu and fj >= 0 and fj < nv:
									var n2: Vector3 = fn[fi][fj]
									if n2 != Vector3.ZERO and n2.dot(nf) >= cos_crease:
										sum += n2
					ns.append(sum.normalized() if sum.length_squared() > 1e-8 else nf)
				var order := [0, 1, 2]
				if Plane(tr[0], tr[1], tr[2]).normal.dot(Vector3.UP) < 0.0:
					order = [0, 2, 1]
				for k: int in order:
					top_st.set_normal(ns[k])
					top_st.add_vertex(tr[k])
			top_n += 1
	var mesh: ArrayMesh = top_st.commit() if top_n > 0 else ArrayMesh.new()
	# Wände flach (scharfe Kanten), eigene Fläche im selben Mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	# Seitenwände
	for i in (nu if walls else 0):
		for j: int in [0, nv]:
			var a: Vector3 = p.call(i, j)
			var b: Vector3 = p.call(i + 1, j)
			_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(signf(a.x), 0, 0))
	# Stirnseiten
	for j in (nv if walls else 0):
		for i: int in [0, nu]:
			var a: Vector3 = p.call(i, j)
			var b: Vector3 = p.call(i, j + 1)
			_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(0, 0, signf(a.z)))
	if walls:
		st.generate_normals()
		mesh = st.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	add_child(mi)


## Block mit Transitions vorne, hinten und seitlich (Pyramid): aus genau seinen Flächen gebaut.
## Jede Transition ist eine eigene, über die Ecke hinaus verlängerte Fläche; ineinandergeschoben endet jede
## exakt auf der Schnittlinie (gleiche Höhe). So ist der Grat eine scharfe Kante – geschwungen, wenn die
## Kurven verschieden sind (ramp_curve vs. side_curve). Flächen: vorne, hinten, seitlich, Top, Wände.
func _build_pyramid(mat: Material) -> void:
	var hl := length * 0.5
	var hw := width * 0.5
	var top_h := height
	var n := 32
	# Höhe der Transition (Abstand d von ihrer Wasserkante) und Umkehrung (Höhe -> Abstand)
	var trans_h := func(d: float, L: float, from: float, c: float) -> float:
		return lerpf(from, top_h, pow(clampf(d / L, 0.0, 1.0), c))
	var trans_d := func(h: float, L: float, from: float, c: float) -> float:
		return L * pow(clampf((h - from) / (top_h - from), 0.0, 1.0), 1.0 / c)
	# lokale Punkte: du = Abstand vom Anfang (back: vom Ende), dv = Abstand von der Seite mit der Auffahrt
	var pt := func(u: float, dv: float, h: float) -> Vector3:
		return Vector3((hw - dv) * inner_v, maxf(h, BOTTOM + 0.05), -u)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Höhenstufen gleichmäßig entlang der Transition vorne/hinten; dazu der Abstand der Seite auf derselben Höhe
	var levels: Array[float] = []
	for k in n + 1:
		levels.append(float(k) / n)
	var ends: Array = []      # [Vorzeichen, Länge] je Ende mit Transition
	if ramp_in > 0.0:
		ends.append([-1.0, ramp_in])
	if ramp_out > 0.0:
		ends.append([1.0, ramp_out])
	var group := 1
	for e: Array in ends:
		var sgn: float = e[0]
		var L: float = e[1]
		var u_of := func(du: float) -> float: return sgn * (hl - du)
		st.set_smooth_group(group)
		group += 1
		for k in n:
			var du0: float = L * levels[k]
			var du1: float = L * levels[k + 1]
			var h0: float = trans_h.call(du0, L, lip, ramp_curve)
			var h1: float = trans_h.call(du1, L, lip, ramp_curve)
			var dv0: float = trans_d.call(h0, side_ramp, side_lip, side_curve)
			var dv1: float = trans_d.call(h1, side_ramp, side_lip, side_curve)
			_quad(st, pt.call(u_of.call(du0), dv0, h0), pt.call(u_of.call(du1), dv1, h1),
				pt.call(u_of.call(du1), width, h1), pt.call(u_of.call(du0), width, h0), Vector3.UP)
	# Seite: auf denselben Höhenstufen, von Grat vorne bis Grat hinten
	st.set_smooth_group(group)
	group += 1
	var L_ref := ramp_in if ramp_in > 0.0 else ramp_out
	for k in n:
		var h0: float = trans_h.call(L_ref * levels[k], L_ref, lip, ramp_curve)
		var h1: float = trans_h.call(L_ref * levels[k + 1], L_ref, lip, ramp_curve)
		h0 = maxf(h0, side_lip)
		h1 = maxf(h1, side_lip)
		var dv0: float = trans_d.call(h0, side_ramp, side_lip, side_curve)
		var dv1: float = trans_d.call(h1, side_ramp, side_lip, side_curve)
		if dv1 - dv0 < 0.0005:
			continue
		var a0: float = -hl + (trans_d.call(h0, ramp_in, lip, ramp_curve) if ramp_in > 0.0 else 0.0)
		var a1: float = -hl + (trans_d.call(h1, ramp_in, lip, ramp_curve) if ramp_in > 0.0 else 0.0)
		var b0: float = hl - (trans_d.call(h0, ramp_out, lip, ramp_curve) if ramp_out > 0.0 else 0.0)
		var b1: float = hl - (trans_d.call(h1, ramp_out, lip, ramp_curve) if ramp_out > 0.0 else 0.0)
		_quad(st, pt.call(a0, dv0, h0), pt.call(a1, dv1, h1), pt.call(b1, dv1, h1), pt.call(b0, dv0, h0), Vector3.UP)
	# Top
	st.set_smooth_group(group)
	group += 1
	var ta := -hl + ramp_in
	var tb := hl - ramp_out
	_quad(st, pt.call(ta, side_ramp, top_h), pt.call(tb, side_ramp, top_h), pt.call(tb, width, top_h), pt.call(ta, width, top_h), Vector3.UP)
	# Wände flach: hinten (gegenüber der Auffahrt) entlang der Oberkante, Stirnseiten und Unterkante der Seite
	st.set_smooth_group(0xFFFFFFFF)
	var back := PackedVector3Array()
	if ramp_in > 0.0:
		for k in n + 1:
			var du: float = ramp_in * levels[k]
			back.append(pt.call(-hl + du, width, trans_h.call(du, ramp_in, lip, ramp_curve)))
	else:
		back.append(pt.call(-hl, width, top_h))
	if ramp_out > 0.0:
		for k in range(n, -1, -1):
			var du: float = ramp_out * levels[k]
			back.append(pt.call(hl - du, width, trans_h.call(du, ramp_out, lip, ramp_curve)))
	else:
		back.append(pt.call(hl, width, top_h))
	var out_back := Vector3(-inner_v, 0.0, 0.0)
	for k in back.size() - 1:
		var a := back[k]
		var b := back[k + 1]
		_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), out_back)
	# Stirnseiten (Höhe = Anfang der Transition) und Seite an der Wasserkante der seitlichen Auffahrt
	for sgn: float in [-1.0, 1.0]:
		var L := ramp_in if sgn < 0.0 else ramp_out
		var h_end := lip if L > 0.0 else top_h
		var dv_end: float = trans_d.call(h_end, side_ramp, side_lip, side_curve)
		var a: Vector3 = pt.call(sgn * hl, dv_end, h_end)
		var b: Vector3 = pt.call(sgn * hl, width, h_end)
		_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(0, 0, -sgn))
	var s0: Vector3 = pt.call(-hl + (trans_d.call(side_lip, ramp_in, lip, ramp_curve) if ramp_in > 0.0 else 0.0), 0.0, side_lip)
	var s1: Vector3 = pt.call(hl - (trans_d.call(side_lip, ramp_out, lip, ramp_curve) if ramp_out > 0.0 else 0.0), 0.0, side_lip)
	_quad(st, s0, s1, Vector3(s1.x, BOTTOM, s1.z), Vector3(s0.x, BOTTOM, s0.z), Vector3(inner_v, 0.0, 0.0))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## Transition Rail, gemeinsame Maße des Querschnitts (w > 0 weg vom Seil): Rail-Mitte, Mitte des Rohrs (Höhe),
## Ende der Transition, Höhe der Transition bzw. des flachen Abschlusses (ohne Rail) und Oberkante des Rohrs.
func _tr_c() -> float:
	return width * 0.5 - TR_FLAT * 0.5

func _tr_cy() -> float:
	return height + TR_RAIL_UP - TR_RAIL_R

## Ende der Transition: TR_TUCK unter dem Rail (das Rail steht zur Transition nur so weit über)
func _tr_wt() -> float:
	return _tr_c() - TR_RAIL_R + TR_TUCK

func _tr_base(w: float) -> float:
	var hw := width * 0.5
	return ENTRY + (height - ENTRY) * pow(clampf((w + hw) / (_tr_wt() + hw), 0.0, 1.0), 2.0)


## Nur Fahrphysik: weiche Auffahrt von der Transition aufs Rail. Das Rohr ragt weit heraus, seitlich wäre es
## eine Stufe (= Sturz); das Brett überbrückt die Kerbe unter dem Rail und rollt auf einer stetigen Kurve
## (Hermite: Steigung der Transition -> waagrecht auf der Rail-Oberkante) hoch. Seilseitig, ab TR_LIP vor dem Transitions-Ende.
func _tr_lip(w: float) -> float:
	var c := _tr_c()
	var w0 := _tr_wt() - TR_LIP
	if w < w0 or w > c:
		return NONE
	var hw := width * 0.5
	var h0 := _tr_base(w0)
	var m0 := 2.0 * (height - ENTRY) * (w0 + hw) / pow(_tr_wt() + hw, 2.0)
	var h1 := height + TR_RAIL_UP
	var span := c - w0
	var t := (w - w0) / span
	return h0 * (2.0 * t * t * t - 3.0 * t * t + 1.0) + m0 * span * (t * t * t - 2.0 * t * t + t) + h1 * (-2.0 * t * t * t + 3.0 * t * t)

func _tr_env(w: float) -> float:
	var h := _tr_base(w)
	var d := w - _tr_c()
	if absf(d) <= TR_RAIL_R:
		h = maxf(h, _tr_cy() + sqrt(maxf(TR_RAIL_R * TR_RAIL_R - d * d, 0.0)))
	return h


## Ebene der Rampe vorne/hinten: Höhe h liegt bei u (ohne Rampe: das Ende selbst).
func _tr_cut(h: float, sgn: float) -> float:
	var L := ramp_in if sgn < 0.0 else ramp_out
	var hl := length * 0.5
	if L <= 0.0:
		return sgn * hl
	return sgn * (hl - L * clampf((h - ENTRY) / (height + TR_RAIL_UP - ENTRY), 0.0, 1.0))


## Weißer Körper des Transition Rails aus genau seinen Flächen: Transition von der Seilseite (läuft unter dem
## Überstand des Rails bis zum flachen Abschluss), flacher Abschluss (unter dem Rail), Rampen vorne/hinten als
## Ebenen bis exakt auf die Schnittkante mit dem Querschnitt (von vorne gesehen = Querschnitt samt Rail-Wölbung),
## Wände. Ohne Rampe (1/2 Transition Rail hinten) ist das Ende eine senkrechte Wand mit dem Querschnitt.
## Das schwarze Rohr baut _build_transition_rail.
func _build_transition_body(mat: Material) -> void:
	var hl := length * 0.5
	var hw := width * 0.5
	var c := _tr_c()
	var w_t := _tr_wt()
	var pt := func(u: float, w: float, h: float) -> Vector3:
		return Vector3(-w * inner_v, maxf(h, BOTTOM + 0.05), -u)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Transition (in sich glatt), bis unter den Überstand des Rails
	st.set_smooth_group(1)
	var n := 24
	for k in n:
		var w0 := lerpf(-hw, w_t, float(k) / n)
		var w1 := lerpf(-hw, w_t, float(k + 1) / n)
		var h0 := _tr_base(w0)
		var h1 := _tr_base(w1)
		_quad(st, pt.call(_tr_cut(h0, -1.0), w0, h0), pt.call(_tr_cut(h0, 1.0), w0, h0),
			pt.call(_tr_cut(h1, 1.0), w1, h1), pt.call(_tr_cut(h1, -1.0), w1, h1), Vector3.UP)
	# flacher Abschluss (liegt unter dem Rohr)
	st.set_smooth_group(2)
	_quad(st, pt.call(_tr_cut(height, -1.0), w_t, height), pt.call(_tr_cut(height, 1.0), w_t, height),
		pt.call(_tr_cut(height, 1.0), hw, height), pt.call(_tr_cut(height, -1.0), hw, height), Vector3.UP)
	# Querschnitt für Rampen/Stirnwände: Transition bis zum Rohr, dort senkrecht hoch auf die Rohr-Mitte, dann Rohr-Oberkante
	var prof: Array[Vector2] = []
	for k in n + 1:
		var w := lerpf(-hw, c - TR_RAIL_R, float(k) / n)
		prof.append(Vector2(w, _tr_base(w)))
	for k in 21:
		var w := lerpf(c - TR_RAIL_R, hw, float(k) / 20)
		prof.append(Vector2(w, _tr_env(w)))
	for side: Array in [[-1.0, ramp_in, 10], [1.0, ramp_out, 11]]:
		var sgn: float = side[0]
		var L: float = side[1]
		st.set_smooth_group(side[2] if L > 0.0 else 0xFFFFFFFF)
		for j in prof.size() - 1:
			var p0 := prof[j]
			var p1 := prof[j + 1]
			var a: Vector3 = pt.call(sgn * hl, p0.x, ENTRY if L > 0.0 else p0.y)
			var b: Vector3 = pt.call(sgn * hl, p1.x, ENTRY if L > 0.0 else p1.y)
			if absf(p1.x - p0.x) < 0.00001:
				if L <= 0.0:
					continue
				# senkrechter Schritt unter dem Überstand: Dreieck in der Rampenebene
				st.add_vertex(a)
				var lo: Vector3 = pt.call(_tr_cut(p0.y, sgn), p0.x, p0.y)
				var hi: Vector3 = pt.call(_tr_cut(p1.y, sgn), p1.x, p1.y)
				if Plane(a, lo, hi).normal.dot(Vector3(0, 1, -sgn)) < 0.0:
					st.add_vertex(hi)
					st.add_vertex(lo)
				else:
					st.add_vertex(lo)
					st.add_vertex(hi)
				continue
			if L > 0.0:
				_quad(st, a, pt.call(_tr_cut(p0.y, sgn), p0.x, p0.y), pt.call(_tr_cut(p1.y, sgn), p1.x, p1.y), b, Vector3(0, 1, -sgn))
			# Stirnseite unter der Wasserkante bzw. ohne Rampe die ganze Querschnitts-Wand
			_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(0, 0, -sgn))
	# Seitenwände: außen (weg vom Seil) bis zum flachen Abschluss, innen an der Wasserkante der Transition
	st.set_smooth_group(0xFFFFFFFF)
	var outer := PackedVector3Array()
	outer.append(pt.call(-hl, hw, ENTRY if ramp_in > 0.0 else height))
	outer.append(pt.call(_tr_cut(height, -1.0), hw, height))
	outer.append(pt.call(_tr_cut(height, 1.0), hw, height))
	outer.append(pt.call(hl, hw, ENTRY if ramp_out > 0.0 else height))
	for k in 3:
		var a := outer[k]
		var b := outer[k + 1]
		if a.distance_to(b) > 0.0001:
			_quad(st, a, b, Vector3(b.x, BOTTOM, b.z), Vector3(a.x, BOTTOM, a.z), Vector3(-inner_v, 0, 0))
	var i0: Vector3 = pt.call(-hl, -hw, ENTRY)
	var i1: Vector3 = pt.call(hl, -hw, ENTRY)
	_quad(st, i0, i1, Vector3(i1.x, BOTTOM, i1.z), Vector3(i0.x, BOTTOM, i0.z), Vector3(inner_v, 0, 0))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## Gitterlinien von a bis b: n gleichmäßige Schritte plus die Knickstellen (sortiert, ohne Fast-Doppel).
static var _pool_paint: StandardMaterial3D
static var _pool_water: ShaderMaterial


## Pool: blau gestrichenes Becken (Boden, Innenseiten von Rand, Rampe und Treppe knapp davor) und die
## Wasserfläche. Die weißen Wände selbst gehören zu Rand, Rampe und Treppe.
func _build_pool() -> void:
	if _pool_paint == null:
		_pool_paint = Util.mat(Color(0.16, 0.42, 0.62), 0.55)
		Weather.dim_at_night(_pool_paint)
		_pool_water = ShaderMaterial.new()
		_pool_water.shader = load("res://shaders/pool_water.gdshader")
	var hl := length * 0.5
	var hw := width * 0.5
	var inset := 0.006
	var top := height + 0.18                         # Anstrich bis knapp unter die Oberkante des Rands
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	_quad(st, Vector3(-hw, floor_h, hl), Vector3(hw, floor_h, hl), Vector3(hw, floor_h, -hl), Vector3(-hw, floor_h, -hl), Vector3.UP)
	for s: float in [-1.0, 1.0]:
		var x := s * (hw - inset)
		_quad(st, Vector3(x, floor_h, hl), Vector3(x, top, hl), Vector3(x, top, -hl), Vector3(x, floor_h, -hl), Vector3(-s, 0, 0))
	# vorne (Rampe, lokal +z) bis zur Oberkante, hinten (Treppe) bis zum Wasserspiegel
	var zf := hl - inset
	_quad(st, Vector3(-hw, floor_h, zf), Vector3(hw, floor_h, zf), Vector3(hw, top, zf), Vector3(-hw, top, zf), Vector3(0, 0, -1))
	var zb := -hl + inset
	_quad(st, Vector3(-hw, floor_h, zb), Vector3(hw, floor_h, zb), Vector3(hw, height, zb), Vector3(-hw, height, zb), Vector3(0, 0, 1))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _pool_paint
	add_child(mi)
	# Gitter fein genug für Heckwelle und Aufprallwellen (der See-Shader verschiebt die Punkte)
	var plane := PlaneMesh.new()
	plane.size = Vector2(width, length)
	plane.subdivide_width = int(width / 0.25)
	plane.subdivide_depth = int(length / 0.25)
	water_mesh = MeshInstance3D.new()
	water_mesh.mesh = plane
	water_mesh.material_override = _pool_water    # Ersatz (Vorschau/Editor ohne See)
	water_mesh.position.y = height
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water_mesh.extra_cull_margin = 1.0
	add_child(water_mesh)


## Treppe: Trittflächen (_stair_h, dunkelgrau wie auf dem Foto), weiße Stirnseiten der Stufen, Seitenwände
## und Rückwand bis unters Wasser.
func _build_stairs(mat: ShaderMaterial) -> void:
	var hl := length * 0.5
	var hw := width * 0.5
	var d := length / (steps + 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0xFFFFFFFF)
	var tread := SurfaceTool.new()
	tread.begin(Mesh.PRIMITIVE_TRIANGLES)
	tread.set_smooth_group(0xFFFFFFFF)
	for k in steps + 1:
		var u0 := -hl + k * d
		var u1 := u0 + d
		var h := _stair_h(u0 + d * 0.5)
		var h_next := _stair_h(u1 + d * 0.5) if k < steps else BOTTOM
		# Trittfläche und Stirnseite nach unten (zur nächsten Stufe bzw. ins Wasser)
		_quad(tread, Vector3(-hw, h, -u0), Vector3(hw, h, -u0), Vector3(hw, h, -u1), Vector3(-hw, h, -u1), Vector3.UP)
		_quad(st, Vector3(-hw, h, -u1), Vector3(hw, h, -u1), Vector3(hw, h_next, -u1), Vector3(-hw, h_next, -u1), Vector3(0, 0, -1))
		for s: float in [-1.0, 1.0]:
			_quad(st, Vector3(s * hw, h, -u0), Vector3(s * hw, h, -u1), Vector3(s * hw, BOTTOM, -u1), Vector3(s * hw, BOTTOM, -u0), Vector3(s, 0, 0))
	_quad(st, Vector3(-hw, height, hl), Vector3(hw, height, hl), Vector3(hw, BOTTOM, hl), Vector3(-hw, BOTTOM, hl), Vector3(0, 0, 1))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)
	var grey := mat.duplicate() as ShaderMaterial
	grey.set_shader_parameter("base_color", Color(0.3, 0.32, 0.34))
	tread.generate_normals()
	var mt := MeshInstance3D.new()
	mt.mesh = tread.commit()
	mt.material_override = grey
	add_child(mt)


func _grid_lines(a: float, b: float, n: int, breaks: Array[float]) -> PackedFloat32Array:
	var vals: Array[float] = []
	for i in n + 1:
		vals.append(lerpf(a, b, float(i) / n))
	for x in breaks:
		if x > a + 0.01 and x < b - 0.01:
			vals.append(x)
	vals.sort()
	var out := PackedFloat32Array()
	for x in vals:
		if out.is_empty() or x - out[out.size() - 1] > 0.004:
			out.append(x)
		elif absf(x - b) < 0.0001:
			out[out.size() - 1] = x
	return out


## Schwarze Oberseite (nur Optik, knapp über der weißen): z. B. die runde Gleitfläche der Plaza Rail.
## from/to in m ab dem Anfang des Teils.
func _build_black_top(from: float, to: float) -> void:
	var hl := length * 0.5
	var u0 := clampf(from - hl, -hl, hl)
	var u1 := clampf(to - hl, -hl, hl)
	var nu := maxi(int((u1 - u0) * 4.0), 1)
	var nv := 12
	var hw := width * 0.5 + 0.004
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var p := func(i: int, j: int) -> Vector3:
		var u := lerpf(u0, u1, float(i) / nu)
		var v := lerpf(-hw, hw, float(j) / nv)
		var h := height_local(u, clampf(v, -width * 0.5 + 0.001, width * 0.5 - 0.001))
		return Vector3(v, h + 0.006, -u)
	for i in nu:
		for j in nv:
			_quad(st, p.call(i, j), p.call(i + 1, j), p.call(i + 1, j + 1), p.call(i, j + 1), Vector3.UP)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _rail_mat()
	add_child(mi)


func _build_rail(white: Material) -> void:
	# Grau = Stahl (Pro Rail), sonst schwarzer matter Kunststoff mit Längskratzern
	var steel: Material
	var post: Material
	if rail_color == "grey":
		var m := Util.mat(Color(0.55, 0.57, 0.6), 0.35)
		m.metallic = 0.6
		steel = m
		post = m
	else:
		steel = _rail_mat(true, radius)
		post = _rail_mat(true, 0.05)
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
		Util.beam(self, Vector3(0, BOTTOM, -u), Vector3(0, height - radius, -u), 0.05, post)
		Util.box(self, Vector3(0.7, 0.35, 0.7), Vector3(0, -0.1, -u), white)


## Oberseite des A-Frame Rails: Safetys weiß, Halbrund-Rail schwarz. Die Grenze (Safety-Ebene
## schneidet die Rundung) wird je Spalte exakt berechnet, damit sie nicht treppig aussieht.
func _build_rail_top(white: Material, black: Material) -> void:
	var hl := length * 0.5
	var hw := width * 0.5
	var nv := 16
	var vs: Array[float] = []
	var ub: Array[float] = []          # Grenze vorne (u < 0)
	var ubb: Array[float] = []         # Grenze hinten (u > 0; hl = keine Safety hinten)
	for j in nv + 1:
		var v := lerpf(-hw + 0.001, hw - 0.001, float(j) / nv)
		vs.append(v)
		var lo := -hl
		var hi := 0.0
		for _k in 30:
			var mid := (lo + hi) * 0.5
			if _on_safety(mid, v):
				lo = mid
			else:
				hi = mid
		ub.append(hi)
		lo = 0.0
		hi = hl
		for _k in 30:
			var mid := (lo + hi) * 0.5
			if _on_safety(mid, v):
				hi = mid
			else:
				lo = mid
		ubb.append(hi)
	var pt := func(u: float, v: float) -> Vector3:
		return Vector3(v, maxf(height_local(clampf(u, -hl + 0.001, hl - 0.001), v), BOTTOM + 0.05), -u)
	var strip := func(st: SurfaceTool, u_a: Callable, u_b: Callable, n: int) -> void:
		for j in nv:
			for i in n:
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				var a: Vector3 = pt.call(lerpf(u_a.call(j), u_b.call(j), t0), vs[j])
				var b: Vector3 = pt.call(lerpf(u_a.call(j), u_b.call(j), t1), vs[j])
				var c: Vector3 = pt.call(lerpf(u_a.call(j + 1), u_b.call(j + 1), t1), vs[j + 1])
				var d: Vector3 = pt.call(lerpf(u_a.call(j + 1), u_b.call(j + 1), t0), vs[j + 1])
				_quad(st, a, b, c, d, Vector3.UP)
	var front := func(_j: int) -> float: return -hl
	var back := func(_j: int) -> float: return hl
	var b_in := func(j: int) -> float: return ub[j]
	var b_out := func(j: int) -> float: return ubb[j]
	# black_top [von, bis]: hinter "bis" ist die Oberseite wieder weiß (z. B. runde Safety hinten an der Plaza Rail)
	var black_end := hl
	if black_top.size() == 2:
		black_end = clampf(float(black_top[1]) - hl, -hl, hl)
	var b_black := func(j: int) -> float: return minf(b_out.call(j), black_end)
	for part: Array in [[white, true], [black, false]]:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_smooth_group(1)
		if part[1]:
			strip.call(st, front, b_in, 4)
			strip.call(st, b_black, back, int((hl - black_end) * 8.0) + 4)
		else:
			strip.call(st, b_in, b_black, int(length * 4.0))
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = part[0]
		add_child(mi)


## Rail im Transition Rail: dickes schwarzes Rohr (TR_RAIL_R), nur das untere Viertel steckt im Körper, seitlich
## steht es ca. 5 cm über den flachen Abschluss über (zur Transition hin setzt es sich mit der Rundung ab). Vorne/
## hinten schneidet die Rampenebene das Rohr ab (es verschmilzt mit der Rampe); der Überstand außen bekommt dort
## eine Abschlussfläche in der Rampenebene.
func _build_transition_rail(black: Material) -> void:
	var hw := width * 0.5
	var c := _tr_c()
	var cy := _tr_cy()
	var R := TR_RAIL_R
	var w_t := _tr_wt()
	var pt := func(u: float, w: float, h: float) -> Vector3:
		return Vector3(-w * inner_v, h, -u)
	var on_circle := func(th: float) -> Vector2:     # th = 0 oben, > 0 weg vom Seil
		return Vector2(c + R * sin(th), cy + R * cos(th))
	var inside := func(p: Vector2) -> bool:          # im weißen Körper?
		if p.x > hw:
			return false
		return p.y <= (_tr_base(p.x) if p.x < w_t else height)
	# sichtbarer Bogen: von oben in beide Richtungen bis in den Körper
	var lim := func(dir: float) -> float:
		var lo := 0.0
		var hi := dir * PI
		for _k in 40:
			var mid := (lo + hi) * 0.5
			if inside.call(on_circle.call(mid)):
				hi = mid
			else:
				lo = mid
		return lo
	var th_l: float = lim.call(-1.0)
	var th_r: float = lim.call(1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(1)
	var n := 40
	for k in n:
		var t0 := lerpf(th_l, th_r, float(k) / n)
		var t1 := lerpf(th_l, th_r, float(k + 1) / n)
		var p0: Vector2 = on_circle.call(t0)
		var p1: Vector2 = on_circle.call(t1)
		var out := Vector3(-sin((t0 + t1) * 0.5) * inner_v, cos((t0 + t1) * 0.5), 0.0)
		_quad(st, pt.call(_tr_cut(p0.y, -1.0), p0.x, p0.y), pt.call(_tr_cut(p0.y, 1.0), p0.x, p0.y),
			pt.call(_tr_cut(p1.y, 1.0), p1.x, p1.y), pt.call(_tr_cut(p1.y, -1.0), p1.x, p1.y), out)
	# Abschluss des Überstands außen (w > hw) in der Rampenebene bzw. am Ende ohne Rampe
	st.set_smooth_group(0xFFFFFFFF)
	var m := 8
	for sgn: float in [-1.0, 1.0]:
		for k in m:
			var w0 := lerpf(hw, c + R, float(k) / m)
			var w1 := lerpf(hw, c + R, float(k + 1) / m)
			var s0 := sqrt(maxf(R * R - pow(w0 - c, 2.0), 0.0))
			var s1 := sqrt(maxf(R * R - pow(w1 - c, 2.0), 0.0))
			var a: Vector3 = pt.call(_tr_cut(cy - s0, sgn), w0, cy - s0)
			var b: Vector3 = pt.call(_tr_cut(cy + s0, sgn), w0, cy + s0)
			var cc: Vector3 = pt.call(_tr_cut(cy + s1, sgn), w1, cy + s1)
			var d: Vector3 = pt.call(_tr_cut(cy - s1, sgn), w1, cy - s1)
			var ramp := ramp_in if sgn < 0.0 else ramp_out
			_quad(st, a, b, cc, d, Vector3(0, 1, -sgn) if ramp > 0.0 else Vector3(0, 0, -sgn))
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = black
	add_child(mi)


## Zwei Dreiecke, Reihenfolge so gedreht, dass die Normale nach "outward" zeigt.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	if Plane(a, b, c).normal.dot(outward) < 0.0:
		var t := b
		b = d
		d = t
	for vtx: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(vtx)
