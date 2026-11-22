class_name FullCable
extends CableSystem
## Rundanlage (Full-Size-Cable, wie Rixen „Big Bro“): das Stahlseil läuft als geschlossene Schlaufe über 4–7 Masten, immer
## in eine Richtung (Mast-Reihenfolge aus park.json, Hip-Notics L2 gegen den Uhrzeigersinn). Die Masten (13–15 m) stehen an
## Land, ein kranartiger Ausleger reicht weit übers Wasser; an seiner Spitze läuft das Seil über die Umlenkrollen
## (Ecken des Seilwegs = Auslegerspitzen, centered_tips: jede Strecke mittig zwischen Ufer und Insel). Mehrere Carrier
## hängen im gleichen Abstand am Seil; einer davon zieht den Spieler. Keine Wenden – der Fahrer wird um die Ecke gezogen.
##
## Für den Fahrer verhält sich die Anlage wie CableSystem: Aufhängepunkt (get_anchor), Carrier-Geschwindigkeit
## (get_velocity, local_vz) und Zustände IDLE/START/RUN/DONE. Die Fahrphysik bleibt dieselbe. Der feste Rahmen
## (transform: Ursprung am Startmast, -z entlang der ersten Strecke) dient nur als Bezug für Dinge, die starr gerechnet
## werden (Abstände); Bahn-Koordinaten (s entlang des Seils, x seitlich) liefern path_frame / to_lane.

const CORNER_R := 10.0           # m Rundung des Seilwegs an den Auslegerspitzen (Rollen + Ausschwingen des Carriers)
const MAST_OVER := 5.5           # Mastspitze so hoch über dem Ausleger (Foto)
const MAST_LEAN := 7.0           # Mastspitze so weit zum Wasser geneigt (höchstens 40 % des Auslegers)
const PULLEY_R := 1.2            # m Radius der Umlenkrolle an jeder Ecke (eine große je Mast)
const BOOM_MAX := 45.0           # m längster Ausleger (sonst bleibt die Ecke näher am Mast)
const CARRIER_GAP := 100.0       # m Abstand der Carrier am Seil (Anzahl = Länge / Abstand)

var masts_w: Array[Vector3] = []          # Masten (Welt, y = 0) in Fahrtrichtung
var tips_w: Array[Vector3] = []           # Auslegerspitzen = Ecken des Seilwegs (Welt, y = 0)
var length := 0.0                         # Seilweg (Schlaufe) in m
var u := 0.0                              # Spieler-Carrier entlang des Seilwegs (0 = Ende der Rundung am Startmast)
var start_u := 0.0                        # Parkposition des Carriers am Startsteg
var _prev_u := 0.0
var _pts: Array[Vector3] = []             # Seilweg fein (geschlossen, letzter Punkt = erster)
var _cum: Array[float] = []               # Länge bis zu Punkt i
var _carriers: Array[Node3D] = []
var _arc_mid: Array[Vector3] = []         # Mitte des Rollenbogens je Mast (Ausleger)


## Masten setzen (vor add_child). Erster Mast = Startmast.
func setup_path(masts: Array) -> void:
	masts_w.clear()
	for m: Vector3 in masts:
		masts_w.append(Vector3(m.x, 0.0, m.z))
	tips_w = centered_tips(masts_w)
	_build_path()
	# fester Rahmen: Auslegerspitze am Startmast, -z entlang der ersten Strecke
	var d := tips_w[1] - tips_w[0]
	position = tips_w[0]
	rotation.y = atan2(-d.x, -d.z)
	mast_a_z = 0.0
	mast_b_z = -d.length()
	turn_a_z = 1.0e6                       # keine Wenden (Fahrer-Logik für 2-Mast-Anlagen greift nie)
	turn_b_z = -1.0e6
	dir = 1.0


## Auslegerspitzen: jede Strecke Mast i → Mast i+1 seitlich so verschoben, dass sie mittig über dem Wasser liegt
## (zwischen Ufer und Insel: quer zur Strecke vom äußeren Ufer her die erste durchgehende Wasserfläche, deren Mitte,
## gemittelt über die mittleren Punkte der Strecke); Ecken = Schnittpunkte der verschobenen Strecken.
static func centered_tips(masts: Array[Vector3]) -> Array[Vector3]:
	var n := masts.size()
	var off: Array[float] = []
	for i in n:
		var a := masts[i]
		var b := masts[(i + 1) % n]
		var f := (b - a).normalized()
		var left := -f.cross(Vector3.UP).normalized()
		var sum := 0.0
		var cnt := 0
		for k in 7:
			var p := a.lerp(b, 0.25 + 0.5 * k / 6.0)
			var start := NAN
			var x := -40.0
			while x <= 80.0:
				var q := p + left * x
				var wet := Lake.in_lake(q.x, q.z, 0.3)
				if wet and is_nan(start):
					start = x
				elif not wet and not is_nan(start):
					if x - start > 8.0:
						sum += (start + x) * 0.5
						cnt += 1
						break
					start = NAN
				x += 0.5
		off.append(sum / cnt if cnt > 0 else 0.0)
	var tips: Array[Vector3] = []
	for i in n:
		# Ecke an Mast i: Schnitt der verschobenen Strecken i-1 (davor) und i (danach)
		var j := (i - 1 + n) % n
		var a0 := masts[j]
		var f0 := (masts[i] - a0).normalized()
		var p0 := a0 - f0.cross(Vector3.UP).normalized() * off[j]
		var f1 := (masts[(i + 1) % n] - masts[i]).normalized()
		var p1 := masts[i] - f1.cross(Vector3.UP).normalized() * off[i]
		var hit: Variant = Geometry2D.line_intersects_line(Vector2(p0.x, p0.z), Vector2(f0.x, f0.z), Vector2(p1.x, p1.z), Vector2(f1.x, f1.z))
		var t := masts[i]
		if hit != null:
			t = Vector3((hit as Vector2).x, 0.0, (hit as Vector2).y)
		if t.distance_to(masts[i]) > BOOM_MAX:
			t = masts[i] + (t - masts[i]).normalized() * BOOM_MAX
		tips.append(t)
	return tips


func _build_path() -> void:
	_pts.clear()
	var n := tips_w.size()
	# Ecke i: gerundet zwischen den Nachbarstrecken (quadratische Bézier von a über den Mast nach b)
	var corners: Array = []
	for i in n:
		var p := tips_w[i]
		var prev := tips_w[(i - 1 + n) % n]
		var next := tips_w[(i + 1) % n]
		var r := minf(CORNER_R, minf(p.distance_to(prev), p.distance_to(next)) * 0.3)
		corners.append([p + (prev - p).normalized() * r, p, p + (next - p).normalized() * r])
	_arc_mid.clear()
	for c: Array in corners:
		var a: Vector3 = c[0]
		var b: Vector3 = c[1]
		var e: Vector3 = c[2]
		_arc_mid.append(a.lerp(b, 0.5).lerp(b.lerp(e, 0.5), 0.5))
	# Start: Ende der Rundung am Startmast, dann Strecke -> Rundung -> Strecke …, zurück zum Start
	_pts.append(corners[0][2])
	for k in n:
		var c: Array = corners[(k + 1) % n]
		for j in 9:
			var t := float(j) / 8.0
			var a: Vector3 = c[0]
			var b: Vector3 = c[1]
			var e: Vector3 = c[2]
			_pts.append(a.lerp(b, t).lerp(b.lerp(e, t), t))
	_cum.clear()
	var acc := 0.0
	for i in _pts.size():
		if i > 0:
			acc += _pts[i].distance_to(_pts[i - 1])
		_cum.append(acc)
	length = acc


func _index(uu: float) -> int:
	uu = fposmod(uu, length)
	var lo := 0
	var hi := _cum.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if _cum[mid] <= uu:
			lo = mid
		else:
			hi = mid
	return lo


## Punkt auf dem Seilweg (y = 0).
func point_at(uu: float) -> Vector3:
	uu = fposmod(uu, length)
	var i := _index(uu)
	var seg := _cum[i + 1] - _cum[i]
	return _pts[i].lerp(_pts[i + 1], (uu - _cum[i]) / seg if seg > 0.0 else 0.0)


## Fahrtrichtung (waagrecht, Länge 1).
func tangent_at(uu: float) -> Vector3:
	var i := _index(uu)
	var d := _pts[i + 1] - _pts[i]
	while d.length_squared() < 1e-8 and i + 2 < _pts.size():
		i += 1
		d = _pts[i + 1] - _pts[i]
	return d.normalized()


## Bahn-Rahmen bei s (entlang des Seils ab dem Startmast): Ursprung auf dem Seilweg, -z in Fahrtrichtung, +x rechts.
func path_frame(sv: float) -> Transform3D:
	var f := tangent_at(sv)
	var right := f.cross(Vector3.UP).normalized()
	return Transform3D(Basis(right, Vector3.UP, -f), point_at(sv))


## Nächste Stelle auf dem Seilweg (s).
func nearest_u(world: Vector3) -> float:
	var p := Vector2(world.x, world.z)
	var best := INF
	var bu := 0.0
	for i in _pts.size() - 1:
		var a := Vector2(_pts[i].x, _pts[i].z)
		var b := Vector2(_pts[i + 1].x, _pts[i + 1].z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d := p.distance_squared_to(a + ab * t)
		if d < best:
			best = d
			bu = _cum[i] + t * ab.length()
	return bu


# ---------------------------------------------------------------- CableSystem-Schnittstelle

func place_xf(local: Transform3D) -> Transform3D:
	var sv := -local.origin.z
	return path_frame(sv) * Transform3D(local.basis, Vector3(local.origin.x, local.origin.y, 0.0))


func to_lane(world: Vector3) -> Vector2:
	var sv := nearest_u(world)
	var f := path_frame(sv)
	return Vector2(sv, (world - f.origin).dot(f.basis.x))


func get_anchor() -> Vector3:
	return point_at(u) + Vector3(0.0, Lake.CABLE_Y - CARRIER_HANG, 0.0)


func get_anchor_visual() -> Vector3:
	var frac := Engine.get_physics_interpolation_fraction()
	var vu := _prev_u + wrapf(u - _prev_u, -length * 0.5, length * 0.5) * frac
	return point_at(vu) + Vector3(0.0, Lake.CABLE_Y - CARRIER_HANG, 0.0)


func get_velocity() -> Vector3:
	return tangent_at(u) * v


## Anteil der Geschwindigkeit in Fahrtrichtung des Carriers (positiv = mit dem Seil).
func local_vz(world_vel: Vector3) -> float:
	return world_vel.dot(tangent_at(u))


func start() -> void:
	if state == State.IDLE:
		dir = 1.0
		_after_turn = false
		state = State.START


func reset() -> void:
	u = start_u
	_prev_u = u
	s = u
	v = 0.0
	dir = 1.0
	laps = 0
	state = State.IDLE
	finishing = false


## Keine Bergung durch den Operator: nach einem Sturz geht es zurück zum Startsteg (main.gd).
func fetch(_z: float) -> void:
	pass


func hold_at(_z: float) -> void:
	pass


func hold_ahead(_z: float, _ahead: float) -> void:
	pass


func resume() -> void:
	if state == State.IDLE or state == State.HOLD:
		state = State.START


## Spielzeit vorbei: die Anlage hält (am Spielende geht es zurück zum Steg).
func finish() -> void:
	finishing = true
	state = State.DONE


func step(delta: float, rider_vz: float, rope_slack: float) -> void:
	_prev_u = u
	_prev_s = s
	_prev_travel = cable_travel
	match state:
		State.START, State.RUN:
			var target_speed := max_speed
			if state == State.START:
				# Anfahren wie an der 2-Mast-Anlage: zügig, solange das Seil durchhängt, dann mit Zug-Tempo
				target_speed = minf(max_speed, sqrt(start_speed * start_speed + 2.0 * accel * 0.8 * maxf(rope_slack, 0.0)))
				if rider_vz > 2.2:
					state = State.RUN
			v = move_toward(v, target_speed, accel * delta)
		_:
			v = 0.0
	var before := u
	u = fposmod(u + v * delta, length)
	if u < before - length * 0.5:
		laps += 1
	s = u
	cable_travel += v * delta


func state_text() -> String:
	match state:
		State.IDLE: return "Bereit"  # i18n
		State.START: return "Anfahren"  # i18n
		State.RUN: return "Rundfahrt"  # i18n
		State.DONE: return "Ende – zurück am Start"  # i18n
	return ""


# ---------------------------------------------------------------- Grafik

func _ready() -> void:
	u = start_u
	_prev_u = u
	s = u
	var steel := Util.mat(Color(0.6, 0.62, 0.66), 0.35)
	steel.metallic = 0.8
	var galv := Util.mat(Color(0.72, 0.74, 0.76), 0.45)
	galv.metallic = 0.6
	var vis := Node3D.new()
	vis.top_level = true                   # Grafik in Weltkoordinaten (der Rahmen der Anlage ist nur ein Bezug)
	add_child(vis)
	# Masten nach dem Foto des Motormasts (L2-Start): Dreigurt-Gittermast am Ufer, schräg zum Wasser geneigt;
	# auf Seilhöhe ein waagrechter Fachwerk-Ausleger bis zur Spitze (Rollenbogen), von der Mastspitze zur
	# Auslegerspitze und nach hinten zum Boden abgespannt. Am Startmast hängt der Antrieb an der Auslegerspitze.
	# Alle Stahlteile in zwei zusammengefassten Meshes (Gitter, Seile) – wenige Draw-Calls am Handy.
	var truss := SurfaceTool.new()
	truss.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wires := SurfaceTool.new()
	wires.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 1
	var n := masts_w.size()
	for i in n:
		var m := masts_w[i]
		var g := maxf(Geo.height(m.x, m.z) if Geo.in_area(m.x, m.z) else 0.3, 0.0)
		var mid := _arc_mid[i]
		var out := Vector3(mid.x - m.x, 0.0, mid.z - m.z)
		var reach := out.length()
		var od := out / maxf(reach, 0.01)
		var arm_y := Lake.CABLE_Y + 0.6
		var apex_y := arm_y + MAST_OVER
		var lean := minf(MAST_LEAN, reach * 0.4)       # Neigung zum Wasser (Foto: kräftig)
		var foot := Vector3(m.x, g - 0.3, m.z)
		var apex := Vector3(m.x, apex_y, m.z) + od * lean
		var root := foot.lerp(apex, (arm_y - foot.y) / (apex_y - foot.y))
		var tip := Vector3(mid.x, arm_y, mid.z)
		_truss(truss, tube, foot, apex, 0.95, 0.6, od)
		_truss(truss, tube, root, tip, 0.85, 0.6, Vector3.UP)
		# Abspannung: Mastspitze → Auslegerspitze (zwei), → Auslegermitte; nach hinten zwei zum Boden
		var side := od.cross(Vector3.UP)
		for sd: float in [-1.0, 1.0]:
			wires.append_from(tube, 0, Util.beam_transform(apex, tip + side * sd * 0.35, 0.025))
			var anchor := Vector3(m.x, 0.0, m.z) - od * 12.0 + side * sd * 7.0
			anchor.y = Geo.height(anchor.x, anchor.z) if Geo.in_area(anchor.x, anchor.z) else g
			wires.append_from(tube, 0, Util.beam_transform(apex, anchor, 0.03))
		wires.append_from(tube, 0, Util.beam_transform(apex, root.lerp(tip, 0.5), 0.02))
		# Eine große Umlenkrolle unter der Auslegerspitze (Nutzer: nur eine, groß, in der Mitte); ihr Rand
		# berührt das Seil in der Mitte des Bogens, die Achse hängt am Ausleger
		var cu := nearest_u(mid)
		var inner := tangent_at(cu + 2.0) - tangent_at(cu - 2.0)
		inner = inner.normalized() if inner.length() > 0.001 else -od
		var hub := point_at(cu) + inner * PULLEY_R + Vector3(0, Lake.CABLE_Y, 0)
		var wheel := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = PULLEY_R
		c.bottom_radius = PULLEY_R
		c.height = 0.16
		c.radial_segments = 28
		wheel.mesh = c
		wheel.material_override = steel
		wheel.position = hub
		vis.add_child(wheel)
		_pulleys.append(wheel)
		truss.append_from(tube, 0, Util.beam_transform(hub - Vector3(0, 0.15, 0), Vector3(hub.x, arm_y, hub.z), 0.09))
		truss.append_from(tube, 0, Util.beam_transform(Vector3(hub.x, arm_y, hub.z), tip, 0.08))
		Util.box(vis, Vector3(0.3, 0.35, 0.3), apex + Vector3(0, 0.25, 0), Util.mat(Color(1.0, 0.45, 0.1), 0.5))
		if i == 0:
			_build_drive(vis, truss, tube, tip, od)
	var mi := MeshInstance3D.new()
	mi.mesh = truss.commit()
	mi.material_override = galv
	vis.add_child(mi)
	# Stahlseil entlang des Seilwegs (im selben Mesh wie die Abspannungen)
	for i in _pts.size() - 1:
		wires.append_from(tube, 0, Util.beam_transform(_pts[i] + Vector3(0, Lake.CABLE_Y, 0),
			_pts[i + 1] + Vector3(0, Lake.CABLE_Y, 0), 0.03))
	var mw := MeshInstance3D.new()
	mw.mesh = wires.commit()
	mw.material_override = steel
	vis.add_child(mw)
	# Carrier im gleichen Abstand; der erste zieht den Spieler
	var count := maxi(1, roundi(length / CARRIER_GAP))
	for k in count:
		var car := Node3D.new()
		vis.add_child(car)
		Util.box(car, Vector3(0.24, 0.28, 0.8), Vector3(0.0, -0.05, 0.0), Util.mat(Color(0.95, 0.75, 0.1), 0.5))
		Util.beam(car, Vector3(0.0, -0.15, 0.0), Vector3(0.0, -CARRIER_HANG, 0.0), 0.025, steel)
		_carriers.append(car)
	_carrier = _carriers[0]


## Dreigurt-Fachwerk von a nach b (Breite w0 am Anfang, × taper am Ende), eine Spitze des Dreiecks zeigt nach `up_hint`.
func _truss(st: SurfaceTool, tube: Mesh, a: Vector3, b: Vector3, w0: float, taper: float, up_hint: Vector3) -> void:
	var axis := (b - a).normalized()
	var u := (up_hint - axis * up_hint.dot(axis)).normalized()
	if u.length() < 0.5:
		u = axis.cross(Vector3.RIGHT).normalized()
	var v := axis.cross(u)
	var offs: Array[Vector3] = []
	for k in 3:                                    # gleichseitiges Dreieck um die Achse
		var ang := TAU * k / 3.0
		offs.append((u * cos(ang) + v * sin(ang)) * w0 * 0.577)
	var bays := maxi(2, int(a.distance_to(b) / 1.4))
	for j in bays:
		var t0 := float(j) / bays
		var t1 := float(j + 1) / bays
		var s0 := lerpf(1.0, taper, t0)
		var s1 := lerpf(1.0, taper, t1)
		var p0 := a.lerp(b, t0)
		var p1 := a.lerp(b, t1)
		for k in 3:
			var o0 := offs[k] * s0
			var o1 := offs[k] * s1
			var on := offs[(k + 1) % 3]
			st.append_from(tube, 0, Util.beam_transform(p0 + o0, p1 + o1, 0.045))           # Gurt
			st.append_from(tube, 0, Util.beam_transform(p0 + o0, p0 + on * s0, 0.02))       # Ring
			var d0 := p0 + (o0 if j % 2 == 0 else on * s0)
			var d1 := p1 + (on * s1 if j % 2 == 0 else o1)
			st.append_from(tube, 0, Util.beam_transform(d0, d1, 0.018))                     # Diagonale


## Antrieb an der Auslegerspitze des Startmasts (Foto): dunkler Maschinenblock mit Motor unter dem
## Ausleger, darüber eine Plattform mit Geländer und ein kleiner weißer Schaltkasten.
func _build_drive(vis: Node3D, st: SurfaceTool, tube: Mesh, tip: Vector3, od: Vector3) -> void:
	var dark := Util.mat(Color(0.26, 0.27, 0.28), 0.5)
	dark.metallic = 0.5
	var yaw := atan2(od.x, od.z)
	var block := Util.box(vis, Vector3(1.2, 0.8, 2.2), tip + od * -0.6 + Vector3(0, -0.75, 0), dark)
	block.rotation.y = yaw
	var motor := Util.box(vis, Vector3(0.7, 0.7, 1.0), tip + od * -1.9 + Vector3(0, -0.7, 0), Util.mat(Color(0.25, 0.3, 0.36), 0.5))
	motor.rotation.y = yaw
	var side := od.cross(Vector3.UP)
	# Plattform (Gitterrost) mit Geländer über der Spitze
	var plat_c := tip + od * -0.8 + Vector3(0, 0.55, 0)
	var plat := Util.box(vis, Vector3(2.4, 0.06, 3.4), plat_c, Util.mat(Color(0.55, 0.57, 0.58), 0.7))
	plat.rotation.y = yaw
	var cx := [-1.2, 1.2]
	var cz := [-1.7, 1.7]
	var corners: Array[Vector3] = []
	for zz: float in cz:
		for xx: float in cx:
			corners.append(plat_c + side * xx + od * zz)
	var order := [0, 1, 3, 2, 0]
	for k in 4:
		var a: Vector3 = corners[order[k]]
		var b: Vector3 = corners[order[k + 1]]
		st.append_from(tube, 0, Util.beam_transform(a + Vector3(0, 1.05, 0), b + Vector3(0, 1.05, 0), 0.03))
		st.append_from(tube, 0, Util.beam_transform(a + Vector3(0, 0.5, 0), b + Vector3(0, 0.5, 0), 0.02))
		st.append_from(tube, 0, Util.beam_transform(a, a + Vector3(0, 1.05, 0), 0.03))
	var cab := Util.box(vis, Vector3(0.6, 0.7, 0.4), plat_c + od * -1.0 + side * 0.5 + Vector3(0, 0.4, 0), Util.mat(Color(0.93, 0.93, 0.9), 0.6))
	cab.rotation.y = yaw

func _process(_delta: float) -> void:
	if _carriers.is_empty():
		return
	var frac := Engine.get_physics_interpolation_fraction()
	var vu := _prev_u + wrapf(u - _prev_u, -length * 0.5, length * 0.5) * frac
	for k in _carriers.size():
		var cu := vu + k * length / _carriers.size()
		var car := _carriers[k]
		car.position = point_at(cu) + Vector3(0.0, Lake.CABLE_Y, 0.0)
		var f := tangent_at(cu)
		car.rotation.y = atan2(-f.x, -f.z)
	for p in _pulleys:
		p.rotation.y = -cable_travel / PULLEY_R
