class_name FullCable
extends CableSystem
## Rundanlage (Full-Size-Cable): das Stahlseil läuft als geschlossene Schlaufe über 4–7 Masten, immer in eine Richtung
## (Mast-Reihenfolge aus park.json, Hip-Notics L2 gegen den Uhrzeigersinn). Mehrere Carrier hängen im gleichen Abstand am
## Seil; einer davon zieht den Spieler. Es gibt keine Wenden – an den Masten führt das Seil um eine Rolle (Ecken des
## Pfads gerundet), der Fahrer wird um die Ecke gezogen.
##
## Für den Fahrer verhält sich die Anlage wie CableSystem: Aufhängepunkt (get_anchor), Carrier-Geschwindigkeit
## (get_velocity, local_vz) und Zustände IDLE/START/RUN/DONE. Die Fahrphysik bleibt dieselbe. Der feste Rahmen
## (transform: Ursprung am Startmast, -z entlang der ersten Strecke) dient nur als Bezug für Dinge, die starr gerechnet
## werden (Abstände); Bahn-Koordinaten (s entlang des Seils, x seitlich) liefern path_frame / to_lane.

const CORNER_R := 14.0           # m: an den Masten läuft das Seil über einen Bogen aus Umlenkrollen am Ausleger
                                 # (die Kurve beginnt so weit vor dem Mast; mit 5 m schoss man in den Mast)
const CARRIER_GAP := 100.0       # m Abstand der Carrier am Seil (Anzahl = Länge / Abstand)
const POLE_R := 0.28

var masts_w: Array[Vector3] = []          # Masten (Welt, y = 0) in Fahrtrichtung
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
	_build_path()
	# fester Rahmen: Startmast, -z entlang der ersten Strecke
	var d := masts_w[1] - masts_w[0]
	position = masts_w[0]
	rotation.y = atan2(-d.x, -d.z)
	mast_a_z = 0.0
	mast_b_z = -d.length()
	turn_a_z = 1.0e6                       # keine Wenden (Fahrer-Logik für 2-Mast-Anlagen greift nie)
	turn_b_z = -1.0e6
	dir = 1.0


func _build_path() -> void:
	_pts.clear()
	var n := masts_w.size()
	# Ecke i: gerundet zwischen den Nachbarstrecken (quadratische Bézier von a über den Mast nach b)
	var corners: Array = []
	for i in n:
		var p := masts_w[i]
		var prev := masts_w[(i - 1 + n) % n]
		var next := masts_w[(i + 1) % n]
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
	# Masten: Rohrmast mit Ausleger zur Innenseite, oben die große Umlenkrolle
	var n := masts_w.size()
	for i in n:
		var m := masts_w[i]
		var g := maxf(Geo.height(m.x, m.z) if Geo.in_area(m.x, m.z) else 0.3, 0.0)
		var top := Lake.CABLE_Y + 0.6
		Util.beam(vis, Vector3(m.x, g - 0.5, m.z), Vector3(m.x, top, m.z), POLE_R, galv)
		# Ausleger vom Mast zum Rollenbogen, abgespannt; am Bogen drei Umlenkrollen
		var mid := _arc_mid[i]
		Util.beam(vis, Vector3(m.x, top - 0.3, m.z), mid + Vector3(0, Lake.CABLE_Y + 0.35, 0), 0.14, galv)
		Util.beam(vis, Vector3(m.x, top + 1.6, m.z), mid + Vector3(0, Lake.CABLE_Y + 0.45, 0), 0.03, steel)
		Util.beam(vis, Vector3(m.x, top + 1.6, m.z), Vector3(m.x, top - 0.3, m.z), POLE_R * 0.7, galv)
		for k in 3:
			var cu := nearest_u(mid) + (k - 1) * 4.0
			var wheel := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.45
			c.bottom_radius = 0.45
			c.height = 0.12
			c.radial_segments = 16
			wheel.mesh = c
			wheel.material_override = steel
			wheel.position = point_at(cu) + Vector3(0, Lake.CABLE_Y + 0.15, 0)
			vis.add_child(wheel)
			_pulleys.append(wheel)
		Util.beam(vis, point_at(nearest_u(mid) - 5.0) + Vector3(0, Lake.CABLE_Y + 0.35, 0),
			point_at(nearest_u(mid) + 5.0) + Vector3(0, Lake.CABLE_Y + 0.35, 0), 0.1, galv)
		Util.box(vis, Vector3(0.3, 0.35, 0.3), Vector3(m.x, top + 0.2, m.z), Util.mat(Color(1.0, 0.45, 0.1), 0.5))
	# Stahlseil entlang des Seilwegs
	for i in _pts.size() - 1:
		Util.beam(vis, _pts[i] + Vector3(0, Lake.CABLE_Y, 0), _pts[i + 1] + Vector3(0, Lake.CABLE_Y, 0), 0.03, steel)
	# Carrier im gleichen Abstand; der erste zieht den Spieler
	var count := maxi(1, roundi(length / CARRIER_GAP))
	for k in count:
		var car := Node3D.new()
		vis.add_child(car)
		Util.box(car, Vector3(0.24, 0.28, 0.8), Vector3(0.0, -0.05, 0.0), Util.mat(Color(0.95, 0.75, 0.1), 0.5))
		Util.beam(car, Vector3(0.0, -0.15, 0.0), Vector3(0.0, -CARRIER_HANG, 0.0), 0.025, steel)
		_carriers.append(car)
	_carrier = _carriers[0]


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
		p.rotation.y = -cable_travel / 0.45
