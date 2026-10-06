class_name CableSystem
extends Node3D
## 2-Mast-Anlage: Das Stahlseil ist als geschlossene Schlaufe um zwei Rollen (Ø 30 cm)
## gespannt – eine oben auf dem Ufermast, eine oben auf dem Mast in der Seemitte.
## Der Schlitten (Carrier) sitzt fest auf EINEM Strang. Der Motor kehrt die Laufrichtung
## an jedem Ende um, dadurch pendelt der Carrier hin und her. Am Carrier hängt das Zugseil.

enum State { IDLE, START, RUN, BRAKE, PAUSE, STOPPING }

const CARRIER_HANG := 0.45                # Zugseil hängt so weit unter dem Stahlseil
const MARKER_COUNT := 12

## Geometrie im lokalen Raum der Anlage (Seil entlang -z). Vor add_child() setzen.
var mast_a_z := Lake.MAST_A_Z
var mast_b_z := Lake.MAST_B_Z
var start_z := -22.0                      # Parkposition des Carriers beim Start
var turn_a_z := -30.0                     # Wendepunkt vor dem Ufer (Platz zum Ausschwingen)
var turn_b_z := Lake.MAST_B_Z + 22.0      # Wendepunkt vor dem Endmast

var max_speed := 30.0 / 3.6     # m/s (Standard 30 km/h)
var start_speed := 2.5         # Anfahren vom Steg
var turn_speed := 4.5          # Zug nach der Wende (ca. 16 km/h)
var turn_accel := 3.0
var accel := 1.4
var decel := 3.5               # spät und kräftig bremsen, damit das Seil lange zieht
var pause_time := 0.15

var s := 0.0             # Carrier-Position entlang z
var v := 0.0             # Geschwindigkeit (mit Vorzeichen) entlang z
var dir := -1.0          # -1 = Richtung Endmast, +1 = Richtung Ufer
var state := State.IDLE
var laps := 0
var cable_travel := 0.0

var _prev_s := 0.0
var _prev_travel := 0.0
var _pause_t := 0.0
var _after_turn := false
var _carrier: Node3D
var _pulleys: Array[Node3D] = []
var _markers_a: Array[Node3D] = []
var _markers_b: Array[Node3D] = []


## Platziert die Anlage zwischen zwei Mastpunkten (Spielkoordinaten).
func place_between(a: Vector3, b: Vector3) -> void:
	var d := b - a
	position = a
	rotation.y = atan2(-d.x, -d.z)
	mast_a_z = 0.0
	mast_b_z = -Vector2(d.x, d.z).length()
	turn_b_z = mast_b_z + 22.0


func _ready() -> void:
	s = start_z
	_prev_s = s
	var steel := Util.mat(Color(0.6, 0.62, 0.66), 0.35)
	steel.metallic = 0.8
	var galv := Util.mat(Color(0.72, 0.74, 0.76), 0.45)   # verzinkter Gittermast
	galv.metallic = 0.6

	var ga := global_position
	var ground_a := Geo.height(ga.x, ga.z) if Geo.in_area(ga.x, ga.z) else 0.5
	_build_mast(mast_a_z, maxf(ground_a, 0.0), galv, steel, false)
	_build_mast(mast_b_z, -1.0, galv, steel, true)

	# Die zwei Stränge der Stahlseil-Schlaufe (tangential an den Rollen)
	for side: float in [-1.0, 1.0]:
		var x := side * Lake.PULLEY_RADIUS
		Util.beam(self, Vector3(x, Lake.CABLE_Y, mast_a_z), Vector3(x, Lake.CABLE_Y, mast_b_z), 0.03, steel)

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


## A-förmiger Gittermast wie am Wakeport: zwei Leiter-Beine, oben die Rolle.
## Endmast im See steht auf einer kleinen Plattform über Pfählen.
func _build_mast(z: float, base_y: float, galv: Material, steel: Material, in_lake: bool) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 1
	var top_y := Lake.CABLE_Y - 0.25
	var foot_y := 0.45 if in_lake else base_y
	for side: float in [-1.0, 1.0]:
		var foot := Vector3(side * 2.3, foot_y, z)
		var top := Vector3(side * 0.28, top_y, z)
		for o: float in [-0.3, 0.3]:
			var off := Vector3(0.0, 0.0, o)
			st.append_from(tube, 0, Util.beam_transform(foot + off, top + off * 0.6, 0.05))
		# Sprossen und Diagonalen
		var n := 12
		for i in n:
			var t0 := float(i) / n
			var t1 := float(i + 1) / n
			var p0 := foot.lerp(top, t0)
			var p1 := foot.lerp(top, t1)
			var w0 := lerpf(0.3, 0.18, t0)
			var w1 := lerpf(0.3, 0.18, t1)
			st.append_from(tube, 0, Util.beam_transform(p0 + Vector3(0, 0, -w0), p0 + Vector3(0, 0, w0), 0.025))
			st.append_from(tube, 0, Util.beam_transform(p0 + Vector3(0, 0, -w0), p1 + Vector3(0, 0, w1), 0.02))
	# Querstreben zwischen den Beinen
	for t: float in [0.35, 0.7]:
		var y := lerpf(foot_y, top_y, t)
		var half := lerpf(2.3, 0.28, t)
		st.append_from(tube, 0, Util.beam_transform(Vector3(-half, y, z), Vector3(half, y, z), 0.04))
	# Kopfplatte
	st.append_from(tube, 0, Util.beam_transform(Vector3(-0.45, top_y, z), Vector3(0.45, top_y, z), 0.09))
	if in_lake:
		# Plattform + Pfähle
		for px: float in [-2.5, 2.5]:
			for pz: float in [-1.2, 1.2]:
				st.append_from(tube, 0, Util.beam_transform(Vector3(px, -3.0, z + pz), Vector3(px, 0.4, z + pz), 0.18))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = galv
	add_child(mi)
	if in_lake:
		Util.box(self, Vector3(5.8, 0.15, 3.2), Vector3(0.0, 0.45, z), Util.mat(Color(0.5, 0.42, 0.32)))

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
	Util.box(self, Vector3(0.45, 0.06, 0.45), Vector3(0.0, Lake.CABLE_Y + 0.12, z), galv)
	# Signallampe oben (orange, wie auf den Fotos)
	Util.box(self, Vector3(0.25, 0.3, 0.25), Vector3(0.0, Lake.CABLE_Y + 0.3, z), Util.mat(Color(1.0, 0.45, 0.1), 0.5))


func start() -> void:
	if state == State.IDLE:
		dir = -1.0
		_after_turn = false
		state = State.START


func emergency_stop() -> void:
	if state != State.IDLE:
		state = State.STOPPING


func reset() -> void:
	s = start_z
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
	return turn_b_z if dir < 0.0 else turn_a_z


func _remaining() -> float:
	return (_target() - s) * dir


## Aufhängepunkt des Zugseils (Physik), in Weltkoordinaten.
func get_anchor() -> Vector3:
	return transform * Vector3(Lake.PULLEY_RADIUS, Lake.CABLE_Y - CARRIER_HANG, s)


## Interpolierter Aufhängepunkt für die Grafik.
func get_anchor_visual() -> Vector3:
	var vs := lerpf(_prev_s, s, Engine.get_physics_interpolation_fraction())
	return transform * Vector3(Lake.PULLEY_RADIUS, Lake.CABLE_Y - CARRIER_HANG, vs)


func get_velocity() -> Vector3:
	return transform.basis * Vector3(0.0, 0.0, v)


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
	var length := mast_a_z - mast_b_z
	for i in MARKER_COUNT:
		var base := i * length / MARKER_COUNT
		_markers_a[i].position = Vector3(Lake.PULLEY_RADIUS, Lake.CABLE_Y, mast_b_z + fposmod(travel + base, length))
		_markers_b[i].position = Vector3(-Lake.PULLEY_RADIUS, Lake.CABLE_Y, mast_b_z + fposmod(-travel + base, length))
	for p in _pulleys:
		p.rotation.y = travel / Lake.PULLEY_RADIUS
