class_name Rider
extends Node3D
## Fahrer-Physik – komplett eigene Steuerung auf Basis des Zugseils.
##
## Kräfte auf den Fahrer:
##  * Zugseil: einseitige Feder (zieht nur, wenn gespannt) vom Griff zum Carrier
##  * Wasserwiderstand längs zum Brett (gering, solange das Brett gleitet)
##  * Kanten-Grip quer zum Brett (hoch) – lenkt den Seilzug in Fahrt entlang des Bretts um.
##    Dadurch kann man nach außen schwingen und schneller werden als der Carrier.
##  * In der Luft: Schwerkraft + Seilzug (zieht nach oben/vorne)

signal crashed(reason: String)
signal trick_landed(trick_name: String, points: int)

enum Mode { WATER, AIR, CRASHED }

const MASS := 80.0
const GRAVITY := 9.81
const ROPE_LENGTH := 16.0       # Zugseil Griff bis Carrier
const ROPE_STIFFNESS := 2600.0
const ROPE_DAMPING := 250.0
const HANDLE_HEIGHT := 1.0
const CRASH_TENSION := 5400.0
const AIR_MAX_TENSION := 1400.0      # in der Luft federn die Arme den Seilzug ab

const DRAG_QUAD := 2.4          # Längswiderstand (gleitend) – klein, damit man in der Wende durchgleitet
const DRAG_LIN := 6.0
const PLOW_DRAG := 260.0        # Zusatzwiderstand, solange das Brett noch nicht gleitet
const PLANE_SPEED := 2.3
const GRIP_QUAD := 160.0        # Querwiderstand der Kante
const GRIP_LIN := 180.0
const TURN_RATE := 1.7
const SPIN_RATE := 7.5
const AIR_ASSIST := 5.0         # Brett dreht in der Luft langsam zur Flugrichtung
const POP_BASE := 2.2
const SLIDE_FRICTION := 0.1     # Reibung Brett auf Feature-Oberfläche
const POP_LOAD := 2.8
const POP_ROPE := 1.8
const BOARD_Y := 0.012          # Unterkante Brettmitte über der Fahrerposition
const ARM_REACH := 0.88         # Griff höchstens so weit weg (Anteil der Armlänge) – Arme leicht gebeugt
const BOARD_HALF := 0.35

const START_POS := Vector3(1.7, Lake.DOCK_Y, -10.0)   # auf dem Startsteg vor der T2-Hütte

var water: Water
var features: FeatureSet
var cable: CableSystem

var mode := Mode.WATER
var pos := START_POS
var vel := Vector3.ZERO
var yaw := 0.0
var attached := true
var tension := 0.0
var tension_smooth := 0.0
var rope_dir := Vector3.FORWARD
var autopilot := false

## Pro Fahrer einstellbar (der NPC auf T1 bekommt eigene Werte, vor add_child setzen)
var start_pos := START_POS
var start_yaw := 0.0
var dock_rect := Rect2(Lake.DOCK_MIN, Lake.DOCK_MAX - Lake.DOCK_MIN)
var mast_b := Vector3(0.0, 0.0, Lake.MAST_B_Z)
var vest_color := Color(1.0, 0.45, 0.05)
## Realistisches Modell (MakeHuman, siehe tools/character). Leer = einfache Klötzchen-Figur.
var model_path := "res://assets/characters/rider.glb"
var shirt_color := Color(0.22, 0.24, 0.28)
var shorts_color := Color(0.15, 0.35, 0.7)
var board_design := 0             # Brett aus der BoardLibrary
var is_npc := false
## Test/Demo: Autopilot hält diese seitliche Spur (Meter neben dem Seil) und fährt Features direkt an
var auto_lane := NAN
var score := 0
var crash_reason := ""
var air_time := 0.0

var _steer := 0.0
var slip := 0.0                 # Quergeschwindigkeit des Bretts (m/s) – > 0 = rutscht nach rechts

var _edge := 0.0
var _release := 0.0
var _edge_vis := 0.0
var _release_vis := 0.0
var _jump_held := false
var _load := 0.0
var _spin_accum := 0.0
var _auto_t := 0.0
var _prev_pos := START_POS
var _prev_yaw := 0.0
var _lean_roll := 0.0
var _lean_pitch := 0.0
var _crouch := 0.0
var _free_handle := Vector3.ZERO
var _rope_dist := 0.0
var _slide_time := 0.0
var _slide_part: FeaturePart
var _line: FeaturePart          # Feature, das der Autopilot gerade anfährt
var _line_popped := false
var _line_skip: FeaturePart     # abgebrochenes Feature (nicht sofort wieder anfahren)
var _turn_end := 0.0            # Autopilot-Wende: +1 = am Endmast, -1 = am Ufer, 0 = keine
var _turn_side := 1.0
var _npc_jump_t := 6.0
var _npc_charge := 0.0
var _npc_spin := false

var _board_pivot: Node3D
var _body_pivot: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _human: Node3D
var _ragdoll: Ragdoll
var _rig: HumanRig
var _handle: MeshInstance3D
var _rope_mesh: ImmediateMesh
var _rope_mat: StandardMaterial3D
var _spray: CPUParticles3D


# ---------------------------------------------------------------- Aufbau

func _ready() -> void:
	var pants := Util.mat(Color(0.15, 0.18, 0.3))
	var vest := Util.mat(vest_color, 0.6)
	var skin := Util.mat(Color(0.9, 0.7, 0.55))
	var black := Util.mat(Color(0.05, 0.05, 0.05))

	_board_pivot = Node3D.new()
	_board_pivot.position = Vector3(0.0, BOARD_Y, 0.0)
	add_child(_board_pivot)
	# Twin-Tip-Board mit Bindungsschuhen (scripts/wakeboard.gd)
	_board_pivot.add_child(BoardLibrary.make(board_design))

	# Fahrer steht seitlich auf dem Brett: Schultern entlang der Brettachse, Brust zeigt nach +X
	_body_pivot = Node3D.new()
	_body_pivot.position = Vector3(0.0, 0.06, 0.0)
	add_child(_body_pivot)
	Util.beam(_body_pivot, Vector3(0.0, 0.05, 0.26), Vector3(0.0, 0.86, 0.09), 0.075, pants)
	Util.beam(_body_pivot, Vector3(0.0, 0.05, -0.26), Vector3(0.0, 0.86, -0.09), 0.075, pants)
	Util.box(_body_pivot, Vector3(0.24, 0.62, 0.38), Vector3(0.0, 1.14, 0.0), vest)
	Util.sphere(_body_pivot, 0.13, Vector3(0.0, 1.6, 0.0), skin)

	_arm_l = Util.beam(self, Vector3.ZERO, Vector3.UP, 0.045, skin)
	_arm_r = Util.beam(self, Vector3.ZERO, Vector3.UP, 0.045, skin)
	_handle = Util.beam(self, Vector3.ZERO, Vector3.UP, 0.017, black)
	_load_model()
	for n: Node3D in [_arm_l, _arm_r, _handle]:
		n.top_level = true

	_rope_mesh = ImmediateMesh.new()
	_rope_mat = Util.mat(Color(1.0, 0.85, 0.1), 1.0, true)
	var rope_mi := MeshInstance3D.new()
	rope_mi.mesh = _rope_mesh
	rope_mi.top_level = true
	rope_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope_mi)

	# Gischt an der Kante, auf der gefahren wird (Lage/Richtung jedes Frame in _update_spray)
	_spray = CPUParticles3D.new()
	_spray.amount = 120
	_spray.lifetime = 0.7
	_spray.local_coords = false
	_spray.top_level = true
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spray.emission_box_extents = Vector3(0.03, 0.02, 0.35)   # entlang der Kante
	_spray.direction = Vector3(1.0, 0.9, 0.0)
	_spray.spread = 18.0
	_spray.initial_velocity_min = 1.5
	_spray.initial_velocity_max = 3.5
	_spray.gravity = Vector3(0.0, -9.8, 0.0)
	_spray.scale_amount_min = 0.6
	_spray.scale_amount_max = 1.5
	var drop := SphereMesh.new()
	drop.radius = 0.05
	drop.height = 0.1
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Util.mat(Color(0.95, 0.97, 1.0), 0.3)
	_spray.mesh = drop
	_spray.emitting = false
	add_child(_spray)



func reset() -> void:
	mode = Mode.WATER
	pos = start_pos
	_prev_pos = pos
	vel = Vector3.ZERO
	yaw = start_yaw
	_prev_yaw = start_yaw
	attached = true
	tension = 0.0
	tension_smooth = 0.0
	_load = 0.0
	_spin_accum = 0.0
	crash_reason = ""
	air_time = 0.0
	_rope_dist = 0.0
	if _ragdoll:
		_ragdoll.stop()


# ---------------------------------------------------------------- Helfer

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func rope_slack() -> float:
	return maxf(ROPE_LENGTH - _rope_dist, 0.0) if attached else 0.0


## Fährt parallel zum Seil auf einer seitlichen Spur (lokales x der Anlage).
## outward_only: Testspur gilt nur Richtung Endmast, zurück wird ausgewichen.
func _lane_input(lane: float, outward_only: bool) -> void:
	if mode == Mode.AIR:
		_steer = 1.0 if _npc_spin and absf(_spin_accum) < PI * 0.92 else 0.0
		return
	var local := cable.transform.affine_inverse() * pos
	var dir := -signf(cable.local_vz(vel)) if horizontal_speed() > 1.0 else 1.0
	if outward_only and dir < 0.0:
		lane = 0.0   # Rückweg: Richtung Seillinie, an den Features vorbei
	var target := cable.transform * Vector3(lane, 0.0, local.z - dir * 14.0)
	var want := atan2(-(target.x - pos.x), -(target.z - pos.z))
	var diff: float
	if tension_smooth < 30.0 and mode == Mode.WATER and pos.y < 0.15:
		diff = wrapf(atan2(-rope_dir.x, -rope_dir.z) - yaw, -PI, PI)   # Wende: zum Carrier drehen
	else:
		diff = wrapf(_aligned_yaw(want) - yaw, -PI, PI)
	_steer = clampf(-diff * 2.5, -1.0, 1.0)
	_edge = 0.5
	_release = 1.0 if tension_smooth < 30.0 and horizontal_speed() > 3.0 and pos.y < 0.15 else 0.0


## Wende wie ein guter Fahrer: sobald das Seil locker wird, außen um die weiße Boje
## carven (Tempo halten), dann driftend in die neue Richtung drehen. Gibt true zurück,
## solange die Wende läuft.
func _turn_input(speed: float) -> bool:
	if mode != Mode.WATER or pos.y > 0.15:
		return false
	var local := cable.transform.affine_inverse() * pos
	var s_now := cable.mast_a_z - local.z
	if _turn_end == 0.0:
		# Wende beginnt an der roten Boje: dort rauskanten, solange das Seil noch zieht
		var end := -signf(cable.local_vz(vel))
		var s_red := (cable.mast_a_z - (cable.turn_b_z if end > 0.0 else cable.turn_a_z)) - end * TurnBuoys.RED_BEFORE
		var at_red := (s_now - s_red) * end > -2.0 and (s_now - s_red) * end < 4.0 and cable.dir * -1.0 == end
		if not (at_red or cable.state == CableSystem.State.BRAKE) or speed < 3.0:
			return false
		_turn_end = end
		_turn_side = signf(local.x) if absf(local.x) > 0.5 else 1.0
	elif tension_smooth > 250.0 and cable.state == CableSystem.State.RUN:
		_turn_end = 0.0                                    # Seil zieht wieder: Wende vorbei
		return false
	var turn_z := cable.turn_b_z if _turn_end > 0.0 else cable.turn_a_z
	var s_white := (cable.mast_a_z - turn_z) - _turn_end * TurnBuoys.WHITE_BEFORE
	var target_local: Vector3
	if (s_now - s_white) * _turn_end < 0.0:
		# noch vor der Boje: kräftig nach außen rauskanten (Tempo aufbauen), weit an ihr vorbei
		target_local = Vector3(_turn_side * (TurnBuoys.WHITE_SIDE + 4.0), 0.0, cable.mast_a_z - s_white)
		if features and _feature_ahead():
			target_local.x = 0.0    # Feature im Weg (z. B. T1 nahe der Wende): nicht rauskanten
	else:
		# hinter der Boje: zurück in die neue Fahrtrichtung, Richtung Seillinie
		target_local = Vector3(_turn_side * 2.0, 0.0, cable.mast_a_z - (s_now - _turn_end * 15.0))
	var target := cable.transform * target_local
	var want := atan2(-(target.x - pos.x), -(target.z - pos.z))
	# Solange der Carrier noch nicht zurückzieht: quer zum Seil um ihn herum schwingen
	# (Pendel) statt gegen den Zug zu fahren – so bleibt das Tempo erhalten.
	var carrier_back := cable.v * _turn_end < -1.0
	if (s_now - s_white) * _turn_end >= 0.0 and not carrier_back and tension_smooth > 30.0:
		var rope_yaw := atan2(-rope_dir.x, -rope_dir.z)
		var vel_yaw := atan2(-vel.x, -vel.z)
		var t1 := rope_yaw + PI * 0.5
		var t2 := rope_yaw - PI * 0.5
		want = t1 if absf(wrapf(t1 - vel_yaw, -PI, PI)) < absf(wrapf(t2 - vel_yaw, -PI, PI)) else t2
	var diff := wrapf(want - yaw, -PI, PI)
	_steer = clampf(-diff * 2.5, -1.0, 1.0)
	_edge = 0.8 if absf(diff) < 0.6 else 0.3
	_release = 1.0 if absf(diff) > 1.2 else 0.0          # zum Herumdrehen kurz driften
	return true


## Spur des Features, das gerade angefahren wird (oder auf dem man fährt), sonst NAN.
func _line_lane() -> float:
	var inv := cable.transform.affine_inverse()
	var local := inv * pos
	var s_now := cable.mast_a_z - local.z
	var travel := -signf(cable.local_vz(vel))          # +1 = Richtung Endmast
	# Auf einem Feature (auch einem nicht geplanten, z. B. Pipe hinter dem Wedge): Spur halten
	var under := features.part_at(pos.x, pos.z)
	if under and pos.y > 0.12:
		return under.lane_x()
	if _line:
		var exit_s := _line.s_center + travel * _line.length * 0.5
		var entry_now := (_line.s_center - travel * _line.length * 0.5 - s_now) * travel
		if (s_now - exit_s) * travel > 1.0:
			_line = null
		elif entry_now > 0.0 and (entry_now < 10.0 and absf(local.x - _line.lane_x()) > maxf(_line.width * 0.3, 0.15) or _feature_ahead(_line)):
			# nicht rechtzeitig auf Linie: abbrechen und ausweichen statt seitlich hineinzufahren
			_line_skip = _line
			_line = null
			return NAN
	if _line == null:
		var travel_world := cable.transform.basis * Vector3(0.0, 0.0, -travel)
		var best_d := INF
		for part in features.parts_of(cable):
			var info := part.ride_info(travel_world)
			if not info["rideable"] or absf(part.x_center) > 11.0:
				continue
			var entry_s := part.s_center - travel * part.length * 0.5
			var d := (entry_s - s_now) * travel
			# genug Anlauf zum Einschwenken; Teile hinter einem anderen (Combo) zählen nicht extra
			# genug Anlauf, um seitlich einzuschwenken (ca. 1 m quer auf 3 m Strecke)
			var lateral_ok := absf(part.lane_x() - local.x) < (d - 12.0) * 0.3
			var free := features.height_at_entry_free(part, travel_world) and features.inner_side_clear(part)
			if part != _line_skip and lateral_ok and d < 75.0 and d < best_d and free and _path_clear(part, s_now, travel):
				best_d = d
				_line = part
		_line_popped = false
		_npc_spin = is_npc and randf() < 0.3   # manchmal ein 180 vom Kicker
	return _line.lane_x() if _line else NAN


## Für Features ohne Auffahrt (Box, Ledge): rechtzeitig vor der Kante abspringen.
func _line_pop(delta: float, speed: float) -> void:
	if _npc_charge > 0.0:
		_npc_charge -= delta
		return
	if _line == null or _line_popped or mode != Mode.WATER or pos.y > 0.12:
		return
	var local := cable.transform.affine_inverse() * pos
	var travel := -signf(cable.local_vz(vel))
	var info := _line.ride_info(cable.transform.basis * Vector3(0.0, 0.0, -travel))
	var entry_s := _line.s_center - travel * _line.length * 0.5
	var d := (entry_s - (cable.mast_a_z - local.z)) * travel
	if info["needs_ollie"]:
		if d < speed * 1.0 and d > 0.0:
			_npc_charge = 0.5          # halten ... dann loslassen = Absprung kurz vor der Kante
			_line_popped = true
	else:
		_line_popped = d < 0.0
		if info["needs_ollie"]:
			_npc_spin = false


## Ist die Spur bis zum Einstieg des Teils frei von anderen Features?
func _path_clear(part: FeaturePart, s_now: float, travel: float) -> bool:
	var entry_s := part.s_center - travel * part.length * 0.5
	var lane := part.lane_x()
	var s := s_now + travel * 2.0
	while (entry_s - s) * travel > 1.0:
		for dx: float in [-1.6, 0.0, 1.6]:
			var p := cable.transform * Vector3(lane + dx, 0.0, cable.mast_a_z - s)
			var other := features.part_at(p.x, p.z)
			if other and other != part:
				return false
		s += travel * 2.0
	return true


func _feature_ahead(ignore: FeaturePart = null) -> bool:
	var vh := Vector3(vel.x, 0.0, vel.z)
	var side := Vector3(-vh.z, 0.0, vh.x).normalized() * 1.0   # auch etwas links/rechts der Spur prüfen
	for t: float in [0.3, 0.7, 1.1, 1.5, 1.9]:
		var p := pos + vh * t
		for q: Vector3 in [p, p + side, p - side]:
			var hit := features.part_at(q.x, q.z)
			if hit and hit != ignore:
				return true
	return false


func _in_dock(x: float, z: float) -> bool:
	return dock_rect.has_point(Vector2(x, z))


func horizontal_speed() -> float:
	return Vector2(vel.x, vel.z).length()


func visual_position() -> Vector3:
	return _prev_pos.lerp(pos, Engine.get_physics_interpolation_fraction())


## Brett ist ein Twin-Tip: liefert target oder target+180°, je nachdem was näher liegt.
func _aligned_yaw(target: float) -> float:
	if absf(wrapf(target - yaw, -PI, PI)) > PI * 0.5:
		target += PI
	return target


func _obstacle_height(x: float, z: float, collision := false) -> float:
	var h := features.height_at(x, z, collision) if features else FeaturePart.NONE
	if _in_dock(x, z):
		h = maxf(h, Lake.DOCK_Y)
	return h


func _surface_at(x: float, z: float) -> float:
	return maxf(water.height_at(x, z, 1.0), _obstacle_height(x, z))


## Mittelt die Höhe unter Nose und Tail – das Brett glättet kurze Wellen.
func _board_surface() -> float:
	var f := forward() * BOARD_HALF
	var h1 := _surface_at(pos.x + f.x, pos.z + f.z)
	var h2 := _surface_at(pos.x - f.x, pos.z - f.z)
	return maxf((h1 + h2) * 0.5, _obstacle_height(pos.x, pos.z))


# ---------------------------------------------------------------- Physik

func step(delta: float) -> void:
	_prev_pos = pos
	_prev_yaw = yaw
	_read_input(delta)
	if mode == Mode.CRASHED:
		_step_crashed(delta)
		return
	var rope_force := _rope_force(delta)
	if mode == Mode.WATER and tension_smooth > CRASH_TENSION:
		crash("Seil aus der Hand gerissen!")
		return
	if mode == Mode.WATER:
		_step_water(delta, rope_force)
	else:
		_step_air(delta, rope_force)
	if mode != Mode.CRASHED:
		_check_bounds()


func _read_input(delta: float) -> void:
	if autopilot:
		_autopilot_input(delta)
	else:
		_steer = Input.get_axis("steer_left", "steer_right")
		_edge = Input.get_action_strength("edge")
		_release = Input.get_action_strength("release")

	var held := (Input.is_action_pressed("jump") and not autopilot) or _npc_charge > 0.0
	if held:
		if mode == Mode.WATER:
			_load = minf(_load + delta / 0.5, 1.0)
	else:
		if _jump_held and mode == Mode.WATER and _load > 0.0:
			_pop()
		_load = 0.0
	_jump_held = held


func _autopilot_input(delta: float) -> void:
	_auto_t += delta
	var speed := horizontal_speed()
	var rope_yaw := atan2(-rope_dir.x, -rope_dir.z)
	var side := 1.0 if fmod(_auto_t, 9.0) < 4.5 else -1.0
	var carving := speed > 5.0 and tension_smooth > 50.0
	var offset := 0.35 * side if carving else 0.0
	if not is_nan(auto_lane):
		_lane_input(auto_lane, true)
		return
	if _turn_input(speed):
		return
	# Features fahren: passendes Feature voraus suchen und auf dessen Spur einschwenken
	if features and (tension_smooth > 50.0 or mode == Mode.AIR):
		var lane := _line_lane()
		if not is_nan(lane):
			_lane_input(lane, false)
			_line_pop(delta, speed)
			return
	else:
		_line = null
	# Hindernisse voraus: nicht seitlich hineincarven, sondern Richtung Seillinie (Carrier) halten
	if features and _feature_ahead():
		offset = 0.0
	var target := rope_yaw + offset
	if carving:
		# Twin-Tip: während der Fahrt ist auch Switch (rückwärts) in Ordnung – nicht
		# mitten in der Fahrt das Brett quer drehen. In der Wende dagegen herumcarven.
		target = _aligned_yaw(target)
	var diff := wrapf(target - yaw, -PI, PI)
	_steer = clampf(-diff * 2.0, -1.0, 1.0)
	_edge = 0.6 if carving else 0.0
	# in der Wende (Seil locker) driften, um schneller herumzukommen
	_release = 1.0 if tension_smooth < 30.0 and speed > 3.0 else 0.0
	if is_npc:
		_npc_tricks(delta, speed)


## NPC: springt ab und zu ab (Leertaste "halten" und loslassen), manchmal mit 180.
func _npc_tricks(delta: float, speed: float) -> void:
	if mode == Mode.AIR:
		_steer = 1.0 if _npc_spin and absf(_spin_accum) < PI * 0.92 else 0.0
		return
	if _npc_charge > 0.0:
		_npc_charge -= delta
		return
	_npc_jump_t -= delta
	if _npc_jump_t <= 0.0 and mode == Mode.WATER and speed > 7.0 and tension_smooth > 150.0:
		_npc_charge = randf_range(0.3, 0.55)
		_npc_spin = randf() < 0.4
		_npc_jump_t = randf_range(5.0, 11.0)


func _rope_force(delta: float) -> Vector3:
	tension = 0.0
	if not attached:
		tension_smooth = 0.0
		return Vector3.ZERO
	var anchor := cable.get_anchor()
	var d := anchor - (pos + Vector3(0.0, HANDLE_HEIGHT, 0.0))
	var dist := d.length()
	if dist < 0.001:
		return Vector3.ZERO
	rope_dir = d / dist
	_rope_dist = dist
	var stretch := dist - ROPE_LENGTH
	if stretch > 0.0:
		var ext_rate := (cable.get_velocity() - vel).dot(rope_dir)
		tension = maxf(ROPE_STIFFNESS * stretch + ROPE_DAMPING * ext_rate, 0.0)
		if mode == Mode.AIR and tension > AIR_MAX_TENSION:
			# In der Luft federn die Arme den Zug ab (Fahrer hängt am Seil). Damit das Seil
			# dabei nicht beliebig weit gedehnt wird und bei der Landung zurückschnalzt,
			# hält es den Fahrer auf maximaler Dehnung fest.
			tension = AIR_MAX_TENSION
			var max_stretch := AIR_MAX_TENSION / ROPE_STIFFNESS
			if stretch > max_stretch:
				pos += rope_dir * (stretch - max_stretch)
			if ext_rate > 0.0:
				vel += rope_dir * ext_rate
	tension_smooth = lerpf(tension_smooth, tension, 1.0 - exp(-delta * 12.0))
	return rope_dir * tension


func _step_water(delta: float, rope: Vector3) -> void:
	var f := forward()
	var r := right()
	var vh := Vector3(vel.x, 0.0, vel.z)
	var speed := vh.length()
	var vl := vh.dot(f)
	var vs := vh.dot(r)
	var on_dock := _in_dock(pos.x, pos.z) and pos.y > Lake.DOCK_Y - 0.05
	var feat_h := features.height_at(pos.x, pos.z) if features else FeaturePart.NONE
	var on_feature := feat_h > 0.05 and pos.y > feat_h - 0.1

	var f_long: float
	var f_lat: float
	if on_feature:
		# Auf Box, Rail oder Pipe: das Brett rutscht in jede Richtung gleich leicht
		# (Boardslide quer zur Fahrtrichtung ist also möglich).
		# Mit belasteter Kante (W) hält das Brett quer besser – gegen den seitlichen Seilzug.
		var fr := SLIDE_FRICTION * MASS * GRAVITY
		f_long = -fr * vl / maxf(speed, 0.5)
		f_lat = -fr * (1.0 + 3.0 * _edge) * vs / maxf(absf(vs), 0.3)
	elif on_dock:
		# nasse Startrampe: rutschig längs, fest quer
		f_long = -40.0 * vl
		f_lat = -500.0 * vs
	else:
		var plow := (1.0 - clampf(speed / PLANE_SPEED, 0.0, 1.0)) * PLOW_DRAG
		f_long = -(DRAG_QUAD * vl * absf(vl) + (DRAG_LIN + plow) * vl)
		# Kante belasten (W): Brett hält quer fester. Kante lösen (S): Brett liegt flach
		# und rutscht quer weg = Driften.
		var grip_mult := 1.0 + 0.9 * _edge - 0.75 * _release
		f_lat = -(GRIP_QUAD * grip_mult * vs * absf(vs) + (GRIP_LIN * grip_mult + plow) * vs)
	slip = vs

	var force := Vector3(rope.x, 0.0, rope.z) + f * f_long + r * f_lat
	vel.x += force.x / MASS * delta
	vel.z += force.z / MASS * delta

	# Lenken über die Kante
	# flaches (driftendes) Brett lässt sich schneller herumdrehen, belastete Kante zieht weite Bögen
	var turn := TURN_RATE * clampf(0.6 + speed / 7.0, 0.6, 1.4) * (1.0 + 0.8 * _release - 0.3 * _edge)
	if on_feature:
		turn = 2.5   # auf dem Feature dreht man das Brett frei (z. B. in den Boardslide)
	yaw -= _steer * turn * delta
	# Wasserstart: solange das Brett nicht gleitet, dreht es sich in Zugrichtung
	if speed < 2.5 and tension > 30.0 and not on_feature:
		var target := _aligned_yaw(atan2(-rope_dir.x, -rope_dir.z))
		yaw = lerp_angle(yaw, target, (1.0 - speed / 2.5) * 2.0 * delta)

	var old_y := pos.y
	pos.x += vel.x * delta
	pos.z += vel.z * delta
	if _obstacle_height(pos.x, pos.z, true) > old_y + 0.15:
		crash("Gegen den Steg!" if _in_dock(pos.x, pos.z) else "Gegen %s gefahren!" % _part_name(pos.x, pos.z))
		return

	# Höhe folgt der Oberfläche – fällt sie schneller weg als die Schwerkraft zieht
	# (Kicker-Kante, Wellenkamm), hebt der Fahrer ab.
	var surf := _board_surface()
	var ay := -GRAVITY + rope.y / MASS
	var y_ball := old_y + vel.y * delta + 0.5 * ay * delta * delta
	# Abheben: Kante/Kamm wirft hoch, oder man rutscht über das Ende eines Features hinaus
	if y_ball > surf + 0.03 and (vel.y > 0.8 or surf < old_y - 0.2):
		pos.y = y_ball
		vel.y += ay * delta
		_enter_air()
	else:
		# begrenzt, damit Kanten in der Oberfläche keine Katapult-Sprünge erzeugen
		vel.y = lerpf(vel.y, clampf((surf - old_y) / delta, -4.0, 4.0), 0.5)
		pos.y = surf

	if not on_dock and not on_feature:
		water.emit_wake(pos, clampf(speed / 8.0, 0.0, 1.2), delta, get_instance_id())
	_track_slide(delta, on_feature)


## Punkte für Slides: wer eine Weile auf Box/Rail/Pipe rutscht, bekommt sie beim Verlassen.
func _track_slide(delta: float, on_feature: bool) -> void:
	var part := features.part_at(pos.x, pos.z) if (features and on_feature) else null
	if part and part.is_slide():
		_slide_time += delta
		_slide_part = part
		return
	if _slide_part and _slide_time > 0.3:
		var vh := Vector3(vel.x, 0.0, vel.z)
		var across := vh.length() > 1.0 and absf(vh.normalized().dot(forward())) < 0.6
		var trick := ("Boardslide" if across else "50-50") + " – " + _slide_part.display_name
		var pts := int(_slide_time * 120.0) + (60 if across else 0)
		score += pts
		trick_landed.emit(trick, pts)
	_slide_time = 0.0
	_slide_part = null


## Punkte von außen vergeben (z. B. für eine saubere Wende) – löst auch den Jubel aus.
func award(trick_name: String, points: int) -> void:
	score += points
	trick_landed.emit(trick_name, points)


## Rutscht der Fahrer gerade auf einem Feature (für den Grind-Sound)?
func is_sliding() -> bool:
	return _slide_part != null and mode == Mode.WATER


func _part_name(x: float, z: float) -> String:
	var p := features.part_at(x, z) if features else null
	return "die " + p.display_name if p else "das Hindernis"


func _pop() -> void:
	var lift := POP_BASE + POP_LOAD * _load + POP_ROPE * clampf((tension_smooth - 150.0) / 600.0, 0.0, 1.0)
	lift *= clampf(horizontal_speed() / 6.0, 0.3, 1.0)
	vel.y = maxf(vel.y, 0.0) + lift
	_enter_air()


func _enter_air() -> void:
	mode = Mode.AIR
	air_time = 0.0
	_spin_accum = 0.0


func _step_air(delta: float, rope: Vector3) -> void:
	var drag := -vel * vel.length() * 0.3
	vel += (rope + drag) / MASS * delta
	vel.y -= GRAVITY * delta
	var old_obstacle := _obstacle_height(pos.x, pos.z, true)
	pos += vel * delta
	air_time += delta

	var old_yaw := yaw
	if absf(_steer) > 0.1:
		yaw -= _steer * SPIN_RATE * delta
	else:
		var vh := Vector3(vel.x, 0.0, vel.z)
		if vh.length() > 1.0:
			yaw = rotate_toward(yaw, _aligned_yaw(atan2(-vh.x, -vh.z)), AIR_ASSIST * delta)
	_spin_accum += wrapf(yaw - old_yaw, -PI, PI)

	# Seitlich gegen ein Feature geflogen? Nur wenn man von außen hineinfliegt –
	# wer schon darüber ist (z. B. seitlich vom Rail fällt), landet stattdessen.
	var obstacle := _obstacle_height(pos.x, pos.z, true)
	if obstacle > pos.y + 0.35 and old_obstacle < obstacle - 0.3:
		crash("Gegen %s gefahren!" % _part_name(pos.x, pos.z))
		return
	var surf := _board_surface()
	if pos.y <= surf and vel.y <= 0.0:
		_land(surf)


func _land(surf: float) -> void:
	var vh := Vector3(vel.x, 0.0, vel.z)
	# Auf einem Feature darf man quer landen (Boardslide), im Wasser nicht
	var on_feature := _obstacle_height(pos.x, pos.z) > 0.05 and _obstacle_height(pos.x, pos.z) >= surf - 0.02
	if not on_feature and vh.length() > 2.0 and absf(vh.normalized().dot(forward())) < cos(deg_to_rad(50.0)):
		crash("Verkantet gelandet!")
		return
	if vel.y < -11.0:
		crash("Zu harte Landung!")
		return
	pos.y = surf
	vel.y = 0.0
	vel.x *= 0.97
	vel.z *= 0.97
	mode = Mode.WATER
	var half_turns := int(round(absf(_spin_accum) / PI))
	if air_time > 0.5 or half_turns > 0:
		var trick_name := "Air" if half_turns == 0 else str(half_turns * 180)
		var pts := int(air_time * 100.0) + half_turns * 150
		score += pts
		trick_landed.emit(trick_name, pts)


func crash(reason: String) -> void:
	if mode == Mode.CRASHED:
		return
	mode = Mode.CRASHED
	attached = false
	crash_reason = reason
	_free_handle = pos + Vector3(0.0, HANDLE_HEIGHT, 0.0)
	if _ragdoll:
		# Körper fliegt mit dem bisherigen Schwung weiter (begrenzt), dann bremst das Wasser
		_ragdoll.start(vel.limit_length(12.0), water.height_at(pos.x, pos.z), pos)
	vel.y = 0.0
	crashed.emit(reason)


func _step_crashed(delta: float) -> void:
	var k := exp(-1.5 * delta)
	vel.x *= k
	vel.z *= k
	vel.y = 0.0
	pos.x += vel.x * delta
	pos.z += vel.z * delta
	if _ragdoll and _ragdoll.active:
		_ragdoll.step(delta)
		# Fahrerposition (Kamera, Brett) folgt dem treibenden Körper
		var c := _ragdoll.center()
		pos.x = c.x
		pos.z = c.z
	pos.y = water.height_at(pos.x, pos.z) - 0.25


func _check_bounds() -> void:
	if _in_dock(pos.x, pos.z):
		return
	if not Lake.in_lake(pos.x, pos.z, 0.5):
		crash("Ab ans Ufer!")
		return
	if Vector2(pos.x - mast_b.x, pos.z - mast_b.z).length() < Lake.MAST_B_RADIUS and pos.y < 6.0:
		crash("Gegen den Mast!")


# ---------------------------------------------------------------- Grafik

func _process(delta: float) -> void:
	var frac := Engine.get_physics_interpolation_fraction()
	var vpos := _prev_pos.lerp(pos, frac)
	position = vpos
	basis = Basis(Vector3.UP, lerp_angle(_prev_yaw, yaw, frac))

	var speed := horizontal_speed()
	var target_roll := 0.0
	var target_pitch := 0.0
	var target_crouch := 0.0
	match mode:
		Mode.CRASHED:
			target_roll = 1.45
		Mode.AIR:
			target_crouch = 0.3
		Mode.WATER:
			# Körper lehnt sich gegen den Seilzug, beim Carven zusätzlich in die Kurve
			# Kante belastet: tiefer in die Knie, stärker gegen das Seil gelehnt.
			# Drift: aufrechter Körper, Brett liegt flach.
			var pull := rope_dir * tension_smooth
			target_roll = atan2(pull.dot(right()), MASS * GRAVITY) * (1.1 + 0.5 * _edge_vis) * (1.0 - 0.6 * _release_vis) \
				- _steer * clampf(speed / 8.0, 0.0, 1.0) * 0.35
			target_pitch = atan2(pull.dot(forward()), MASS * GRAVITY) * 0.5
			target_crouch = _load * 0.25 + _edge_vis * 0.12
			if speed < 2.5 and not _in_dock(pos.x, pos.z):
				target_crouch = maxf(target_crouch, 0.3)
	var k := 1.0 - exp(-delta * 8.0)
	_edge_vis = lerpf(_edge_vis, _edge, k)
	_release_vis = lerpf(_release_vis, _release, k)
	_lean_roll = lerpf(_lean_roll, clampf(target_roll, -0.85, 1.5), k)
	_lean_pitch = lerpf(_lean_pitch, clampf(target_pitch, -0.6, 0.6), k)
	_crouch = lerpf(_crouch, target_crouch, k)

	if _rig:
		_pose_human()
	_body_pivot.rotation = Vector3(_lean_pitch, 0.0, _lean_roll)
	_body_pivot.scale = Vector3(1.0, 1.0 - _crouch, 1.0)
	_body_pivot.position.y = -0.3 if mode == Mode.CRASHED else 0.06
	if _ragdoll and _ragdoll.active:
		_board_on_feet()
	else:
		_board_pivot.position = Vector3(0.0, BOARD_Y, 0.0)
		_board_pivot.rotation = Vector3(0.0, 0.0, 1.2 if mode == Mode.CRASHED \
			else _lean_roll * (0.35 + 0.45 * _edge_vis) * (1.0 - 0.85 * _release_vis))

	# Griff, Arme, Seil
	var anchor := cable.get_anchor_visual()
	var handle_pos: Vector3
	var to_anchor := Vector3.FORWARD
	if attached:
		var hand := vpos + Vector3(0.0, HANDLE_HEIGHT * (1.0 - _crouch * 0.5), 0.0)
		to_anchor = (anchor - hand).normalized()
		handle_pos = hand + to_anchor * 0.35
		if _rig:
			# Realistischer Griff: vor der vorderen Hüfte, Arme fast gestreckt
			var rb := global_transform.basis.orthonormalized()
			handle_pos = vpos + rb * Vector3(0.2, 0.86 - 0.3 * _crouch, -0.2) + to_anchor * 0.5
	else:
		var off := _free_handle - anchor
		off.y = 0.0
		if off.length() > ROPE_LENGTH * 0.85:
			_free_handle = anchor + off.normalized() * ROPE_LENGTH * 0.85
		_free_handle.y = water.height_at(_free_handle.x, _free_handle.z) + 0.05
		handle_pos = _free_handle
		to_anchor = (anchor - handle_pos).normalized()
	var bar_axis := to_anchor.cross(Vector3.UP)
	bar_axis = bar_axis.normalized() if bar_axis.length() > 0.01 else Vector3.RIGHT
	_arm_l.visible = attached and _rig == null
	_arm_r.visible = attached and _rig == null
	if _rig and attached and mode != Mode.CRASHED:
		# Die Hände bestimmen, wo der Griff ist: nie weiter weg, als die Arme reichen
		handle_pos = _pose_arms(handle_pos, bar_axis)
	Util.place_beam(_handle, handle_pos - bar_axis * 0.2, handle_pos + bar_axis * 0.2)
	if attached and _rig == null:     # Ersatzarme nur ohne Figur (place_beam macht sichtbar!)
		var body := _body_pivot.global_transform
		Util.place_beam(_arm_l, body * Vector3(0.0, 1.38, 0.17), handle_pos - bar_axis * 0.08)
		Util.place_beam(_arm_r, body * Vector3(0.0, 1.38, -0.17), handle_pos + bar_axis * 0.08)
	_draw_rope(handle_pos, anchor)

	_update_spray(speed)


## Kurzer Zustandstext für das HUD.
## Gischt kommt aus der Kante, auf der gefahren wird: wer quer zum Seilzug nach links schneidet,
## fährt auf der rechten Kante – die Gischt spritzt nach rechts weg (und umgekehrt).
## Je schneller man seitlich schneidet, desto höher und weiter. Beim Driften (Kante gelöst)
## greift keine Kante – dann gibt es keine Gischt.
func _update_spray(speed: float) -> void:
	var on_water := mode == Mode.WATER and speed > 3.0 and not _in_dock(pos.x, pos.z) and pos.y < 0.2
	if not on_water or _release > 0.3:
		_spray.emitting = false
		return
	var v := Vector3(vel.x, 0.0, vel.z)
	var travel := v.normalized()
	# seitliche Geschwindigkeit quer zur Achse der Seilbahn (Linie des Carriers)
	var axis := cable.global_transform.basis.z
	axis = Vector3(axis.x, 0.0, axis.z).normalized()
	var lat := v - axis * v.dot(axis)
	var cut := lat.length()
	var side := -lat / cut if cut > 0.3 else travel.cross(Vector3.UP)
	var w := clampf((cut - 0.3) / 1.5, 0.0, 1.0)        # 0 = geradeaus, 1 = kräftig geschnitten
	# Lage: an der Kante auf der Gischtseite, etwas hinter der Brettmitte, knapp über dem Wasser
	var board := _board_pivot.global_position
	var at := board + side * 0.2 - travel * 0.25
	at.y = water.height_at(at.x, at.z) + 0.03
	# Ausrichtung: lokales X = zur Gischtseite, Z = entlang der Kante
	var bx := side
	var bz := bx.cross(Vector3.UP).normalized()
	_spray.global_transform = Transform3D(Basis(bx, Vector3.UP, bz), at)
	var dir := side * (0.2 + 1.3 * w) + Vector3.UP * (0.7 + 0.3 * w) - travel * (0.6 - 0.4 * w)
	_spray.direction = Basis(bx, Vector3.UP, bz).inverse() * dir.normalized()
	_spray.initial_velocity_min = 0.8 + w * 1.5 + cut * 0.3
	_spray.initial_velocity_max = 1.6 + w * 2.5 + cut * 0.6 + speed * 0.08
	_spray.scale_amount_min = 0.5 + 0.3 * w
	_spray.scale_amount_max = 1.0 + 1.0 * w
	_spray.emitting = true


## Nach einem Setup-Wechsel: gemerkte Features vergessen (die alten Teile gibt es nicht mehr).
func forget_features() -> void:
	_slide_part = null
	_line = null
	_line_skip = null


func board_state_text() -> String:
	if mode != Mode.WATER:
		return ""
	if _release > 0.3:
		return "DRIFT – Kante gelöst, Brett rutscht quer (%.1f m/s)" % absf(slip)
	if _edge > 0.3:
		return "KANTE belastet – maximaler Grip"
	return ""


# ---------------------------------------------------------------- Realistisches Modell

func _load_model() -> void:
	if model_path == "" or not ResourceLoader.exists(model_path):
		return
	var scene: PackedScene = load(model_path)
	_human = scene.instantiate()
	# Modell schaut nach +Z; der Fahrer steht seitlich: Brust zeigt nach +X (lokal)
	_human.rotation.y = PI * 0.5
	_human.position.y = 0.06
	add_child(_human)
	var skel := HumanRig.find_skeleton(_human)
	if skel == null:
		_human.queue_free()
		_human = null
		return
	_rig = HumanRig.new(skel)
	_ragdoll = Ragdoll.new(skel, self)
	_body_pivot.visible = false
	_tint_clothes(_human)
	# Helm am Kopf-Knochen (die Impact-Weste ist das eng anliegende Oberteil, siehe _tint_clothes)
	_attach_node("head", Helmet.new())


## Kleidung einfärben: T-Shirt als Rashguard, Hose als Boardshorts.
func _tint_clothes(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var lname := String(mi.name).to_lower()
		var tint := Color.WHITE
		if "shirt" in lname or "top" in lname:
			tint = vest_color.lerp(Color.BLACK, 0.25)     # Oberteil = Impact-Weste
		elif "pants" in lname or "shorts" in lname:
			tint = shorts_color
		# Impact-Weste (aus dem Charakter-Skript): Aufdruck als Sticker-Collage per Shader
		for si in mi.mesh.get_surface_count():
			var sm := mi.mesh.surface_get_material(si)
			if sm and sm.resource_name.begins_with("vest_print"):
				var vm := ShaderMaterial.new()
				vm.shader = load("res://shaders/vest.gdshader")
				mi.set_surface_override_material(si, vm)
		if tint != Color.WHITE:
			for si in mi.mesh.get_surface_count():
				var m := mi.get_active_material(si)
				if m is StandardMaterial3D:
					var d := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
					d.albedo_color = tint
					mi.set_surface_override_material(si, d)
	for c in n.get_children():
		_tint_clothes(c)


## Hängt einen Knoten an einen Knochen; der Knoten ist in Skelett-Achsen der Ruhepose gebaut
## (Ursprung = Knochen, +Y oben, +Z vorne).
func _attach_node(bone: String, node: Node3D) -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	_rig.skeleton.add_child(att)
	var rest := _rig.rest_global(bone).basis.orthonormalized()
	node.transform = Transform3D(rest.inverse(), Vector3.ZERO)
	att.add_child(node)


## Pose aus der Physik: Füße in den Bindungen, Becken/Oberkörper gegen den Seilzug,
## Knie federn je nach Belastung, Kopf schaut in Fahrtrichtung.
func _pose_human() -> void:
	if _ragdoll.active:
		var c := _ragdoll.center()
		_ragdoll.follow_water(water.height_at(c.x, c.z), c)
		return
	_human.rotation = Vector3(0.0, PI * 0.5, 0.0)
	_human.position = Vector3(0.0, 0.06, 0.0)
	_rig.begin()
	if mode == Mode.CRASHED:
		_human.rotation = Vector3(0.0, PI * 0.5, 1.45)        # liegt im Wasser
		_human.position = Vector3(0.6, -0.25, 0.0)
		return
	var skel_inv := _rig.skeleton.global_transform.affine_inverse()
	var rb := global_transform.basis.orthonormalized()
	var board := _board_pivot.global_transform
	var foot_front := board * Wakeboard.ankle_local(true)    # linker Fuß Richtung Nose
	var foot_back := board * Wakeboard.ankle_local(false)
	var mid := (foot_front + foot_back) * 0.5
	var hip_h := 0.84 - 0.32 * _crouch
	var lean_local := Vector3(-sin(_lean_roll) * 0.55, hip_h * cos(_lean_roll) * cos(_lean_pitch), sin(_lean_pitch) * 0.4)
	var pelvis_world := mid + rb * lean_local
	# Becken- und Oberkörperneigung (Welt -> Skelettraum)
	var skel_b := _rig.skeleton.global_transform.basis.orthonormalized()
	var lean_w := rb * Basis.from_euler(Vector3(_lean_pitch * 0.5, 0.0, _lean_roll * 0.6)) * rb.inverse()
	var to_skel := func(bw: Basis) -> Basis: return skel_b.inverse() * bw * skel_b
	_rig.set_pelvis(skel_inv * pelvis_world, to_skel.call(lean_w))
	# Oberkörper zum Seil drehen und etwas weiter zurücklehnen
	var rope_h := Vector3(rope_dir.x, 0.0, rope_dir.z)
	var chest := rb * Vector3.RIGHT
	var twist := 0.0
	if rope_h.length() > 0.1 and attached:
		twist = clampf(chest.signed_angle_to(rope_h.normalized(), Vector3.UP), -1.4, 1.4) * 0.75
	var spine_w := Basis(Vector3.UP, twist) * (rb * Basis.from_euler(Vector3(_lean_pitch * 0.4, 0.0, _lean_roll * 0.4)) * rb.inverse())
	_rig.bend_spine(to_skel.call(spine_w).get_rotation_quaternion())
	# Beine: Knie Richtung Brust/Zehen, leicht nach außen
	var knee_dir := chest * 1.0 + Vector3.UP * 0.3
	_rig.leg("l", skel_inv * foot_front, skel_inv * (pelvis_world + knee_dir + rb * Vector3(0, 0, -Wakeboard.STANCE)))
	_rig.leg("r", skel_inv * foot_back, skel_inv * (pelvis_world + knee_dir + rb * Vector3(0, 0, Wakeboard.STANCE)))
	# Füße flach in den Bindungen (Ruhe-Ausrichtung relativ zum Fahrer)
	# Füße in den Bindungen: kippen mit dem Brett, Duck-Stance wie die Schuhe
	var board_rel := board.basis.orthonormalized() * rb.inverse()
	for front: bool in [true, false]:
		var fb := "foot_l" if front else "foot_r"
		var w := board_rel * Basis(rb * Vector3.UP, Wakeboard.foot_yaw(front))
		_rig.set_end_basis(fb, skel_b.inverse() * w * skel_b * _rig.rest_global(fb).basis)
	# Kopf: in Fahrtrichtung bzw. zum Seil
	var look_dir := Vector3(vel.x, 0.0, vel.z)
	if look_dir.length() < 1.0:
		look_dir = rope_h if rope_h.length() > 0.1 else forward()
	_rig.look_at(skel_inv * (pelvis_world + Vector3.UP * 0.8 + look_dir.normalized() * 10.0))


## Beim Sturz bleibt das Brett an den Füßen (Bindungen): Lage aus den Fuß-Knochen der Ragdoll.
func _board_on_feet() -> void:
	var skel_b := _rig.skeleton.global_transform.basis
	var gl := _ragdoll.child_world("calf_l", "foot_l")
	var gr := _ragdoll.child_world("calf_r", "foot_r")
	var front := gl.origin
	var back := gr.origin
	# Sohlen-Normale: in der Ruhepose zeigt sie nach oben
	var up_l := gl.basis * (_rig.rest_global("foot_l").basis.inverse() * (skel_b.inverse() * Vector3.UP))
	var up_r := gr.basis * (_rig.rest_global("foot_r").basis.inverse() * (skel_b.inverse() * Vector3.UP))
	var z := back - front
	z = z.normalized() if z.length() > 0.01 else global_basis.z
	var y := (up_l + up_r)
	y = (y - z * y.dot(z)).normalized() if (y - z * y.dot(z)).length() > 0.01 else Vector3.UP
	var b := Basis(y.cross(z), y, z)
	var ank := (Wakeboard.ankle_local(true) + Wakeboard.ankle_local(false)) * 0.5
	_board_pivot.global_transform = Transform3D(b, (front + back) * 0.5 - b * ank)


## Arme an den Griff. Die Armlänge ist die Grenze: Liegt der Wunsch-Griffpunkt weiter weg,
## wird der Griff näher an den Körper geholt (Arme bleiben leicht gebeugt, nie überstreckt).
## Gibt die tatsächliche Griffposition zurück.
func _pose_arms(handle_pos: Vector3, bar_axis: Vector3) -> Vector3:
	var skel_inv := _rig.skeleton.global_transform.affine_inverse()
	var skel := _rig.skeleton.global_transform
	var sh_l := skel * _rig.global_pose("upperarm_l").origin
	var sh_r := skel * _rig.global_pose("upperarm_r").origin
	var reach := (_rig.rest_global("upperarm_l").origin.distance_to(_rig.rest_global("lowerarm_l").origin)
		+ _rig.rest_global("lowerarm_l").origin.distance_to(_rig.rest_global("hand_l").origin)) * ARM_REACH + HumanRig.GRIP_ALONG * 0.8
	for i in 4:
		var over := 0.0
		var pull := Vector3.ZERO
		for sh: Vector3 in [sh_l, sh_r]:
			var end := handle_pos - bar_axis * 0.1 if sh.distance_to(handle_pos - bar_axis * 0.1) < sh.distance_to(handle_pos + bar_axis * 0.1) else handle_pos + bar_axis * 0.1
			var d := sh.distance_to(end)
			if d - reach > over:
				over = d - reach
				pull = (sh - end).normalized()
		if over <= 0.0:
			break
		handle_pos += pull * over
	var a := handle_pos - bar_axis * 0.1
	var b := handle_pos + bar_axis * 0.1
	# Ellbogen nach unten und leicht nach außen (vom Körper weg)
	var mid_sh := (sh_l + sh_r) * 0.5
	# jede Hand an das Griffende, das näher an ihrer Schulter liegt (sonst überkreuzen die Arme)
	var front := a if sh_l.distance_to(a) + sh_r.distance_to(b) < sh_l.distance_to(b) + sh_r.distance_to(a) else b
	var back := b if front == a else a
	# Hände umschließen den Griff (Faust), Daumen zur Griffmitte
	_rig.grip("l", skel_inv * front, skel_inv.basis * (handle_pos - front),
		skel_inv * (sh_l + Vector3.DOWN * 0.6 + (sh_l - mid_sh).normalized() * 0.25))
	_rig.grip("r", skel_inv * back, skel_inv.basis * (handle_pos - back),
		skel_inv * (sh_r + Vector3.DOWN * 0.6 + (sh_r - mid_sh).normalized() * 0.25))
	return handle_pos


func _draw_rope(a: Vector3, b: Vector3) -> void:
	_rope_mesh.clear_surfaces()
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _rope_mat)
	var chord := a.distance_to(b)
	# Durchhang einer Parabel mit gleicher Bogenlänge wie das (lose) Seil
	var slack := maxf(ROPE_LENGTH - chord, 0.0)
	var sag := sqrt(3.0 * chord * slack / 8.0)
	for i in 21:
		var t := i / 20.0
		var p := a.lerp(b, t)
		p.y = maxf(p.y - 4.0 * sag * t * (1.0 - t), 0.05)
		_rope_mesh.surface_add_vertex(p)
	_rope_mesh.surface_end()
