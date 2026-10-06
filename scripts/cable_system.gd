class_name CableSystem
extends Node3D
## 2-Mast-Anlage: Das Stahlseil ist als geschlossene Schlaufe um zwei Rollen (Ø 30 cm)
## gespannt – eine oben auf dem Ufermast, eine oben auf dem Mast in der Seemitte.
## Der Schlitten (Carrier) sitzt fest auf EINEM Strang. Der Motor kehrt die Laufrichtung
## an jedem Ende um, dadurch pendelt der Carrier hin und her. Am Carrier hängt das Zugseil.

enum State { IDLE, START, RUN, BRAKE, PAUSE, STOPPING }

const START_Z := -15.0                    # Parkposition des Carriers beim Start
const TURN_A_Z := -45.0                   # Wendepunkt vor dem Ufer (Platz zum Ausschwingen)
const TURN_B_Z := Lake.MAST_B_Z + 25.0    # Wendepunkt vor Mast 2 (Platz zum Ausschwingen)
const CARRIER_HANG := 0.45                # Zugseil hängt so weit unter dem Stahlseil
const MARKER_COUNT := 12

var max_speed := 30.0 / 3.6     # m/s (Standard 30 km/h)
var start_speed := 2.5         # Anfahren vom Steg
var turn_speed := 4.5          # Zug nach der Wende (ca. 16 km/h)
var turn_accel := 3.0
var accel := 1.4
var decel := 3.5               # spät und kräftig bremsen, damit das Seil lange zieht
var pause_time := 0.15

var s := START_Z         # Carrier-Position entlang z
var v := 0.0             # Geschwindigkeit (mit Vorzeichen) entlang z
var dir := -1.0          # -1 = Richtung Mast 2, +1 = Richtung Ufer
var state := State.IDLE
var laps := 0
var cable_travel := 0.0

var _prev_s := START_Z
var _prev_travel := 0.0
var _pause_t := 0.0
var _after_turn := false
var _carrier: Node3D
var _pulleys: Array[Node3D] = []
var _markers_a: Array[Node3D] = []
var _markers_b: Array[Node3D] = []


func _ready() -> void:
	var steel := Util.mat(Color(0.6, 0.62, 0.66), 0.35)
	steel.metallic = 0.8
	var mast_mat := Util.mat(Color(0.88, 0.88, 0.85), 0.6)

	_build_mast(Lake.MAST_A_Z, Lake.SHORE_Y, mast_mat, steel)
	_build_mast(Lake.MAST_B_Z, -1.5, mast_mat, steel)

	# Dreibein für den Mast im See
	for i in 3:
		var ang := TAU * i / 3.0 + 0.5
		var foot := Vector3(cos(ang) * 3.2, -1.5, Lake.MAST_B_Z + sin(ang) * 3.2)
		Util.beam(self, foot, Vector3(0.0, 5.0, Lake.MAST_B_Z), 0.09, mast_mat)
	# Abspannung des Ufermasts nach hinten
	Util.beam(self, Vector3(0.0, Lake.CABLE_Y, Lake.MAST_A_Z), Vector3(0.0, Lake.SHORE_Y, Lake.MAST_A_Z + 14.0), 0.02, steel)

	# Die zwei Stränge der Stahlseil-Schlaufe (tangential an den Rollen)
	for side: float in [-1.0, 1.0]:
		var x := side * Lake.PULLEY_RADIUS
		Util.beam(self, Vector3(x, Lake.CABLE_Y, Lake.MAST_A_Z), Vector3(x, Lake.CABLE_Y, Lake.MAST_B_Z), 0.03, steel)

	# Carrier
	_carrier = Node3D.new()
	add_child(_carrier)
	Util.box(_carrier, Vector3(0.2, 0.24, 0.7), Vector3(0.0, -0.05, 0.0), Util.mat(Color(0.95, 0.75, 0.1), 0.5))
	Util.beam(_carrier, Vector3(0.0, -0.15, 0.0), Vector3(0.0, -CARRIER_HANG, 0.0), 0.025, steel)

	# Markierungen auf beiden Strängen machen die Laufrichtung der Schlaufe sichtbar
	var mk := Util.mat(Color(0.9, 0.15, 0.1), 0.5)
	for i in MARKER_COUNT:
		_markers_a.append(Util.box(self, Vector3(0.09, 0.09, 0.35), Vector3.ZERO, mk))
		_markers_b.append(Util.box(self, Vector3(0.09, 0.09, 0.35), Vector3.ZERO, mk))


func _build_mast(z: float, base_y: float, mast_mat: Material, steel: Material) -> void:
	Util.beam(self, Vector3(0.0, base_y, z), Vector3(0.0, Lake.CABLE_Y - 0.1, z), 0.2, mast_mat)
	# Rolle mit senkrechter Achse – das Seil läuft außen herum
	var pulley := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = Lake.PULLEY_RADIUS + 0.02
	c.bottom_radius = Lake.PULLEY_RADIUS + 0.02
	c.height = 0.08
	c.radial_segments = 16
	pulley.mesh = c
	pulley.material_override = steel
	pulley.position = Vector3(0.0, Lake.CABLE_Y, z)
	add_child(pulley)
	_pulleys.append(pulley)
	# Speiche, damit man das Drehen der Rolle sieht
	Util.box(pulley, Vector3(0.3, 0.1, 0.04), Vector3.ZERO, Util.mat(Color(0.9, 0.15, 0.1)))
	Util.box(self, Vector3(0.45, 0.06, 0.45), Vector3(0.0, Lake.CABLE_Y + 0.12, z), mast_mat)


func start() -> void:
	if state == State.IDLE:
		dir = -1.0
		_after_turn = false
		state = State.START


func emergency_stop() -> void:
	if state != State.IDLE:
		state = State.STOPPING


func reset() -> void:
	s = START_Z
	_prev_s = s
	v = 0.0
	dir = -1.0
	laps = 0
	state = State.IDLE


func change_speed(kmh: float) -> void:
	max_speed = clampf(max_speed + kmh / 3.6, 16.0 / 3.6, 40.0 / 3.6)


## rider_vz: Geschwindigkeit des Fahrers entlang z (Vorzeichen wie v).
## rope_slack: wie viele Meter das Zugseil gerade durchhängt (0 = gespannt).
func step(delta: float, rider_vz: float, rope_slack: float) -> void:
	_prev_s = s
	_prev_travel = cable_travel
	match state:
		State.IDLE:
			v = 0.0
		State.STOPPING:
			v = move_toward(v, 0.0, decel * 1.5 * delta)
		State.START, State.RUN:
			var target_speed := max_speed
			var a := accel
			if state == State.START:
				# Anfahren: solange das Seil durchhängt zügig fahren, aber so bremsen,
				# dass das Seil nur mit der Zug-Geschwindigkeit strammgezogen wird.
				# Nach einer Wende zieht die Anlage kräftiger, damit man durch die Kurve kommt.
				var pickup := turn_speed if _after_turn else start_speed
				if _after_turn:
					a = turn_accel
				target_speed = minf(max_speed, sqrt(pickup * pickup + 2.0 * a * 0.8 * maxf(rope_slack, 0.0)))
			var spd := move_toward(absf(v), target_speed, a * delta)
			v = spd * dir
			# Erst wenn der Fahrer in die neue Richtung gleitet, fährt die Anlage auf Tempo hoch
			# (sonst würde das Seil nach der Wende mit vollem Tempo anreißen).
			if state == State.START and rider_vz * dir > (4.0 if _after_turn else 2.2):
				state = State.RUN
			if _remaining() <= v * v / (2.0 * decel):
				state = State.BRAKE
		State.BRAKE:
			var remaining := _remaining()
			var spd := absf(v)
			if remaining < 0.02 or spd < 0.06:
				s = _target()
				v = 0.0
				state = State.PAUSE
				_pause_t = pause_time
			else:
				spd = maxf(spd - spd * spd / (2.0 * remaining) * delta, 0.05)
				v = spd * dir
		State.PAUSE:
			v = 0.0
			_pause_t -= delta
			if _pause_t <= 0.0:
				dir = -dir
				laps += 1
				_after_turn = true
				state = State.START
	s += v * delta
	if state == State.BRAKE and _remaining() < 0.0:
		s = _target()
	cable_travel += v * delta


func _target() -> float:
	return TURN_B_Z if dir < 0.0 else TURN_A_Z


func _remaining() -> float:
	return (_target() - s) * dir


## Aufhängepunkt des Zugseils (Physik).
func get_anchor() -> Vector3:
	return Vector3(Lake.PULLEY_RADIUS, Lake.CABLE_Y - CARRIER_HANG, s)


## Interpolierter Aufhängepunkt für die Grafik.
func get_anchor_visual() -> Vector3:
	var a := get_anchor()
	a.z = lerpf(_prev_s, s, Engine.get_physics_interpolation_fraction())
	return a


func get_velocity() -> Vector3:
	return Vector3(0.0, 0.0, v)


func state_text() -> String:
	match state:
		State.IDLE: return "Bereit"
		State.START: return "Anfahren"
		State.RUN: return "Fahrt → Mast 2" if dir < 0.0 else "Fahrt → Ufer"
		State.BRAKE: return "Bremst zur Wende"
		State.PAUSE: return "Wende"
		State.STOPPING: return "Not-Stopp"
	return ""


func _process(_delta: float) -> void:
	var frac := Engine.get_physics_interpolation_fraction()
	var cs := lerpf(_prev_s, s, frac)
	var travel := lerpf(_prev_travel, cable_travel, frac)
	_carrier.position = Vector3(Lake.PULLEY_RADIUS, Lake.CABLE_Y, cs)
	var length := Lake.MAST_A_Z - Lake.MAST_B_Z
	for i in MARKER_COUNT:
		var base := i * length / MARKER_COUNT
		_markers_a[i].position = Vector3(Lake.PULLEY_RADIUS, Lake.CABLE_Y, Lake.MAST_B_Z + fposmod(travel + base, length))
		_markers_b[i].position = Vector3(-Lake.PULLEY_RADIUS, Lake.CABLE_Y, Lake.MAST_B_Z + fposmod(-travel + base, length))
	for p in _pulleys:
		p.rotation.y = travel / Lake.PULLEY_RADIUS
