class_name ChaseCamera
extends Camera3D
## 3rd-Person-Kamera.
##  * Verfolger: schwenkt weich hinter die Fahrtrichtung; Maus/rechter Stick drehen frei,
##    nach kurzer Pause kehrt die Kamera automatisch hinter den Fahrer zurück.
##  * Orbit: Kamera bleibt, wo man sie hindreht.
##  * Ufer: Zuschauerperspektive von der Seite (zeigt Seil und Carrier gut).

enum CamMode { CHASE, ORBIT, SIDE }

const MODE_NAMES := ["Verfolger", "Orbit", "Ufer"]
const BASE_PITCH := -0.3

var rider: Rider
var water: Water
var cam_mode := CamMode.CHASE
var distance := 7.5

var _yaw := 0.0
var _off_yaw := 0.0
var _off_pitch := 0.0
var _idle := 10.0
var _focus := Vector3.ZERO
var _initialized := false


func cycle_mode() -> void:
	cam_mode = ((cam_mode + 1) % 3) as CamMode
	if cam_mode == CamMode.ORBIT:
		_off_yaw += _yaw
		_yaw = 0.0
	elif cam_mode == CamMode.CHASE:
		_yaw = _off_yaw
		_off_yaw = 0.0


func mode_name() -> String:
	return MODE_NAMES[cam_mode]


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed:
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(distance - 0.6, 3.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(distance + 0.6, 30.0)
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	var mm := event as InputEventMouseMotion
	if mm and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_off_yaw -= mm.relative.x * 0.004
		_off_pitch -= mm.relative.y * 0.003
		_idle = 0.0
		return
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	var target := rider.visual_position() + Vector3(0.0, 1.4, 0.0)
	if not _initialized:
		_initialized = true
		_focus = target
		_yaw = rider.yaw
	_focus = _focus.lerp(target, 1.0 - exp(-delta * 12.0))

	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if look.length() > 0.1:
		_off_yaw -= look.x * 2.5 * delta
		_off_pitch -= look.y * 1.5 * delta
		_idle = 0.0
	_idle += delta

	var speed := rider.horizontal_speed()
	if cam_mode == CamMode.CHASE:
		# Blickrichtung = Fahrtrichtung, bei wenig Tempo (Wende) zunehmend Richtung Carrier.
		# Dadurch dreht die Kamera in der Wende mit und zeigt schon die neue Fahrtrichtung.
		var desired := _yaw
		var vel_h := Vector3(rider.vel.x, 0.0, rider.vel.z)
		var w := clampf((speed - 2.0) / 5.0, 0.0, 1.0)
		var look_dir := vel_h.normalized() * w
		if rider.attached:
			look_dir += Vector3(rider.rope_dir.x, 0.0, rider.rope_dir.z) * (1.0 - w)
		if look_dir.length() > 0.15:
			desired = atan2(-look_dir.x, -look_dir.z)
		_yaw = lerp_angle(_yaw, desired, 1.0 - exp(-delta * 2.5))
		if _idle > 1.5:
			var back := 1.0 - exp(-delta * 1.5)
			_off_yaw = lerpf(wrapf(_off_yaw, -PI, PI), 0.0, back)
			_off_pitch = lerpf(_off_pitch, 0.0, back)

	_off_pitch = clampf(BASE_PITCH + _off_pitch, -1.35, 0.3) - BASE_PITCH

	if cam_mode == CamMode.SIDE:
		var side_pos := Vector3(_focus.x + 32.0, 6.0, _focus.z + 14.0)
		global_position = global_position.lerp(side_pos, 1.0 - exp(-delta * 1.5))
		look_at(_focus, Vector3.UP)
	else:
		var pitch := BASE_PITCH + _off_pitch
		var offset := Basis(Vector3.UP, _yaw + _off_yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0.0, 0.0, distance)
		var cam_pos := _focus + offset
		var ground := maxf(water.height_at(cam_pos.x, cam_pos.z), Geo.height(cam_pos.x, cam_pos.z))
		cam_pos.y = maxf(cam_pos.y, ground + 0.6)
		global_position = cam_pos
		look_at(_focus + Vector3(0.0, 0.3, 0.0), Vector3.UP)

	fov = lerpf(fov, 68.0 + clampf(speed * 1.2, 0.0, 14.0), 1.0 - exp(-delta * 3.0))
