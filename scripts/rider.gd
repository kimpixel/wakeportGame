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
const ROPE_LENGTH := 18.0
const ROPE_STIFFNESS := 2600.0
const ROPE_DAMPING := 250.0
const HANDLE_HEIGHT := 1.0
const CRASH_TENSION := 5400.0

const DRAG_QUAD := 2.4          # Längswiderstand (gleitend) – klein, damit man in der Wende durchgleitet
const DRAG_LIN := 6.0
const PLOW_DRAG := 260.0        # Zusatzwiderstand, solange das Brett noch nicht gleitet
const PLANE_SPEED := 3.0
const GRIP_QUAD := 160.0        # Querwiderstand der Kante
const GRIP_LIN := 180.0
const TURN_RATE := 1.7
const SPIN_RATE := 7.5
const AIR_ASSIST := 3.5         # Brett dreht in der Luft langsam zur Flugrichtung
const POP_BASE := 2.2
const POP_LOAD := 2.8
const POP_ROPE := 1.8
const BOARD_HALF := 0.35

const START_POS := Vector3(1.7, Lake.DOCK_Y, -10.0)   # auf dem Startsteg vor der T2-Hütte

var water: Water
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

var _board_pivot: Node3D
var _body_pivot: Node3D
var _arm_l: MeshInstance3D
var _arm_r: MeshInstance3D
var _handle: MeshInstance3D
var _rope_mesh: ImmediateMesh
var _rope_mat: StandardMaterial3D
var _spray: CPUParticles3D
var _slide_spray: CPUParticles3D


# ---------------------------------------------------------------- Aufbau

func _ready() -> void:
	var board_mat := Util.mat(Color(0.08, 0.08, 0.1), 0.4)
	var bind_mat := Util.mat(Color(0.85, 0.1, 0.1), 0.6)
	var pants := Util.mat(Color(0.15, 0.18, 0.3))
	var vest := Util.mat(Color(1.0, 0.45, 0.05), 0.6)
	var skin := Util.mat(Color(0.9, 0.7, 0.55))
	var black := Util.mat(Color(0.05, 0.05, 0.05))

	_board_pivot = Node3D.new()
	_board_pivot.position = Vector3(0.0, 0.03, 0.0)
	add_child(_board_pivot)
	Util.box(_board_pivot, Vector3(0.43, 0.04, 1.35), Vector3.ZERO, board_mat)
	Util.box(_board_pivot, Vector3(0.26, 0.1, 0.15), Vector3(0.0, 0.06, 0.26), bind_mat)
	Util.box(_board_pivot, Vector3(0.26, 0.1, 0.15), Vector3(0.0, 0.06, -0.26), bind_mat)

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
	_handle = Util.beam(self, Vector3.ZERO, Vector3.UP, 0.025, black)
	for n: Node3D in [_arm_l, _arm_r, _handle]:
		n.top_level = true

	_rope_mesh = ImmediateMesh.new()
	_rope_mat = Util.mat(Color(1.0, 0.85, 0.1), 1.0, true)
	var rope_mi := MeshInstance3D.new()
	rope_mi.mesh = _rope_mesh
	rope_mi.top_level = true
	rope_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rope_mi)

	_spray = CPUParticles3D.new()
	_spray.amount = 90
	_spray.lifetime = 0.7
	_spray.local_coords = false
	_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_spray.emission_box_extents = Vector3(0.2, 0.02, 0.15)
	_spray.direction = Vector3(0.0, 1.0, 0.5)
	_spray.spread = 35.0
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
	_spray.position = Vector3(0.0, 0.05, 0.5)
	_spray.emitting = false
	add_child(_spray)

	_slide_spray = CPUParticles3D.new()
	_slide_spray.amount = 160
	_slide_spray.lifetime = 0.6
	_slide_spray.local_coords = false
	_slide_spray.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_slide_spray.emission_box_extents = Vector3(0.05, 0.02, 0.6)
	_slide_spray.spread = 25.0
	_slide_spray.initial_velocity_min = 2.0
	_slide_spray.initial_velocity_max = 5.0
	_slide_spray.gravity = Vector3(0.0, -9.8, 0.0)
	_slide_spray.scale_amount_min = 0.8
	_slide_spray.scale_amount_max = 2.0
	_slide_spray.mesh = drop
	_slide_spray.position = Vector3(0.0, 0.05, 0.0)
	_slide_spray.emitting = false
	add_child(_slide_spray)


func reset() -> void:
	mode = Mode.WATER
	pos = START_POS
	_prev_pos = pos
	vel = Vector3.ZERO
	yaw = 0.0
	_prev_yaw = 0.0
	attached = true
	tension = 0.0
	tension_smooth = 0.0
	_load = 0.0
	_spin_accum = 0.0
	crash_reason = ""
	air_time = 0.0
	_rope_dist = 0.0


# ---------------------------------------------------------------- Helfer

func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


func right() -> Vector3:
	return Vector3(cos(yaw), 0.0, -sin(yaw))


func rope_slack() -> float:
	return maxf(ROPE_LENGTH - _rope_dist, 0.0) if attached else 0.0


func horizontal_speed() -> float:
	return Vector2(vel.x, vel.z).length()


func visual_position() -> Vector3:
	return _prev_pos.lerp(pos, Engine.get_physics_interpolation_fraction())


## Brett ist ein Twin-Tip: liefert target oder target+180°, je nachdem was näher liegt.
func _aligned_yaw(target: float) -> float:
	if absf(wrapf(target - yaw, -PI, PI)) > PI * 0.5:
		target += PI
	return target


func _obstacle_height(x: float, z: float) -> float:
	var h := Lake.kicker_height(x, z)
	if Lake.in_dock(x, z):
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
	if tension_smooth > CRASH_TENSION:
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

	var held := Input.is_action_pressed("jump") and not autopilot
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
	var diff := wrapf(rope_yaw + offset - yaw, -PI, PI)
	_steer = clampf(-diff * 2.0, -1.0, 1.0)
	_edge = 0.6 if carving else 0.0
	# in der Wende (Seil locker) driften, um schneller herumzukommen
	_release = 1.0 if tension_smooth < 30.0 and speed > 3.0 else 0.0


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
	tension_smooth = lerpf(tension_smooth, tension, 1.0 - exp(-delta * 12.0))
	return rope_dir * tension


func _step_water(delta: float, rope: Vector3) -> void:
	var f := forward()
	var r := right()
	var vh := Vector3(vel.x, 0.0, vel.z)
	var speed := vh.length()
	var vl := vh.dot(f)
	var vs := vh.dot(r)
	var on_dock := Lake.in_dock(pos.x, pos.z) and pos.y > Lake.DOCK_Y - 0.05

	var f_long: float
	var f_lat: float
	if on_dock:
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
	yaw -= _steer * turn * delta
	# Wasserstart: solange das Brett nicht gleitet, dreht es sich in Zugrichtung
	if speed < 2.5 and tension > 30.0:
		var target := _aligned_yaw(atan2(-rope_dir.x, -rope_dir.z))
		yaw = lerp_angle(yaw, target, (1.0 - speed / 2.5) * 2.0 * delta)

	var old_y := pos.y
	pos.x += vel.x * delta
	pos.z += vel.z * delta
	if _obstacle_height(pos.x, pos.z) > old_y + 0.15:
		crash("Gegen den Steg!" if Lake.in_dock(pos.x, pos.z) else "Kicker gerammt!")
		return

	# Höhe folgt der Oberfläche – fällt sie schneller weg als die Schwerkraft zieht
	# (Kicker-Kante, Wellenkamm), hebt der Fahrer ab.
	var surf := _board_surface()
	var ay := -GRAVITY + rope.y / MASS
	var y_ball := old_y + vel.y * delta + 0.5 * ay * delta * delta
	if y_ball > surf + 0.03 and vel.y > 0.8:
		pos.y = y_ball
		vel.y += ay * delta
		_enter_air()
	else:
		# begrenzt, damit Kanten in der Oberfläche keine Katapult-Sprünge erzeugen
		vel.y = lerpf(vel.y, clampf((surf - old_y) / delta, -4.0, 4.0), 0.5)
		pos.y = surf

	if not on_dock:
		water.emit_wake(pos, clampf(speed / 8.0, 0.0, 1.2), delta)


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

	if _obstacle_height(pos.x, pos.z) > pos.y + 0.35:
		crash("Kicker gerammt!")
		return
	var surf := _board_surface()
	if pos.y <= surf and vel.y <= 0.0:
		_land(surf)


func _land(surf: float) -> void:
	var vh := Vector3(vel.x, 0.0, vel.z)
	if vh.length() > 2.0 and absf(vh.normalized().dot(forward())) < cos(deg_to_rad(50.0)):
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
	vel.y = 0.0
	crashed.emit(reason)


func _step_crashed(delta: float) -> void:
	var k := exp(-1.5 * delta)
	vel.x *= k
	vel.z *= k
	vel.y = 0.0
	pos.x += vel.x * delta
	pos.z += vel.z * delta
	pos.y = water.height_at(pos.x, pos.z) - 0.25


func _check_bounds() -> void:
	if Lake.in_dock(pos.x, pos.z):
		return
	if not Lake.in_lake(pos.x, pos.z, 0.5):
		crash("Ab ans Ufer!")
		return
	var dz := pos.z - Lake.MAST_B_Z
	if pos.x * pos.x + dz * dz < Lake.MAST_B_RADIUS * Lake.MAST_B_RADIUS and pos.y < 6.0:
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
			if speed < 2.5 and not Lake.in_dock(pos.x, pos.z):
				target_crouch = maxf(target_crouch, 0.3)
	var k := 1.0 - exp(-delta * 8.0)
	_edge_vis = lerpf(_edge_vis, _edge, k)
	_release_vis = lerpf(_release_vis, _release, k)
	_lean_roll = lerpf(_lean_roll, clampf(target_roll, -0.85, 1.5), k)
	_lean_pitch = lerpf(_lean_pitch, clampf(target_pitch, -0.6, 0.6), k)
	_crouch = lerpf(_crouch, target_crouch, k)

	_body_pivot.rotation = Vector3(_lean_pitch, 0.0, _lean_roll)
	_body_pivot.scale = Vector3(1.0, 1.0 - _crouch, 1.0)
	_body_pivot.position.y = -0.3 if mode == Mode.CRASHED else 0.06
	_board_pivot.rotation.z = 1.2 if mode == Mode.CRASHED \
		else _lean_roll * (0.35 + 0.45 * _edge_vis) * (1.0 - 0.85 * _release_vis)

	# Griff, Arme, Seil
	var anchor := cable.get_anchor_visual()
	var handle_pos: Vector3
	var to_anchor := Vector3.FORWARD
	if attached:
		var hand := vpos + Vector3(0.0, HANDLE_HEIGHT * (1.0 - _crouch * 0.5), 0.0)
		to_anchor = (anchor - hand).normalized()
		handle_pos = hand + to_anchor * 0.35
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
	Util.place_beam(_handle, handle_pos - bar_axis * 0.22, handle_pos + bar_axis * 0.22)

	_arm_l.visible = attached
	_arm_r.visible = attached
	if attached:
		var body := _body_pivot.global_transform
		Util.place_beam(_arm_l, body * Vector3(0.0, 1.38, 0.17), handle_pos - bar_axis * 0.08)
		Util.place_beam(_arm_r, body * Vector3(0.0, 1.38, -0.17), handle_pos + bar_axis * 0.08)
	_draw_rope(handle_pos, anchor)

	_spray.emitting = mode == Mode.WATER and speed > 3.0 and not Lake.in_dock(pos.x, pos.z)
	_spray.initial_velocity_max = 1.5 + speed * 0.35
	_spray.direction = Vector3(-signf(_lean_roll) * 0.8, 1.0, 0.5)

	# Drift: das quer rutschende Brett schiebt eine Gischtwand zur Seite
	var drifting := mode == Mode.WATER and speed > 3.0 and _release_vis > 0.3 and absf(slip) > 0.6
	_slide_spray.emitting = drifting
	_slide_spray.direction = Vector3(signf(slip), 0.8, 0.0)
	_slide_spray.initial_velocity_max = 2.0 + absf(slip) * 2.0


## Kurzer Zustandstext für das HUD.
func board_state_text() -> String:
	if mode != Mode.WATER:
		return ""
	if _release > 0.3:
		return "DRIFT – Kante gelöst, Brett rutscht quer (%.1f m/s)" % absf(slip)
	if _edge > 0.3:
		return "KANTE belastet – maximaler Grip"
	return ""


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
