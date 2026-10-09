class_name ChaseCamera
extends Camera3D
## 3rd-Person-Kamera.
##  * Verfolger: schwenkt weich hinter die Fahrtrichtung; Maus/rechter Stick drehen frei,
##    nach kurzer Pause kehrt die Kamera automatisch hinter den Fahrer zurück.
##  * Orbit: Kamera bleibt, wo man sie hindreht.
##  * Ufer: Zuschauerperspektive von der Seite (zeigt Seil und Carrier gut).
## Auf dem Slider zoomt die Verfolger-Kamera etwas heran, beim Nose-/Tailpress noch näher und
## schwenkt zur Seite (Brustseite des Fahrers); danach weich zurück.

enum CamMode { CHASE, ORBIT, SIDE }

const MODE_NAMES := ["Verfolger", "Orbit", "Ufer"]
const BASE_PITCH := -0.3
const SLIDE_ZOOM := 0.7          # Abstand auf dem Slider (Anteil)
const PRESS_ZOOM := 0.5          # Abstand beim Press (Anteil)
const PRESS_SIDE := 1.0          # beim Press so weit zur Seite schwenken (1 = ganz in die Press-Ansicht)
const PRESS_BEHIND := 0.55       # Press-Ansicht: von der Brustseite so weit nach hinten (Blick in Fahrtrichtung; 1 = genau von hinten)
const PRESS_FOCUS := 1.0         # beim Press so weit den Blick vom Fahrer auf den Press-Blickpunkt
const PRESS_TIP := 0.4           # Press-Blickpunkt: zwischen Becken (0) und gedrücktem Brett-Ende (1)
const PRESS_PORTRAIT := 1.35     # Handy hochkant: beim Press weiter weg (schmales Bild)
const PRESS_LIFT := 0.3          # m über dem Brett-Ende

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
var _slide_k := 0.0              # 0..1 weich: Fahrer auf dem Slider
var _press_k := 0.0              # 0..1 weich: Nose-/Tailpress
var _press_focus := Vector3.ZERO # Press: Blickpunkt am gedrückten Brett-Ende (weich nachgeführt)


func cycle_mode() -> void:
	cam_mode = ((cam_mode + 1) % 3) as CamMode
	if cam_mode == CamMode.ORBIT:
		_off_yaw += _yaw
		_yaw = 0.0
	elif cam_mode == CamMode.CHASE:
		_yaw = _off_yaw
		_off_yaw = 0.0


## Kameramodus direkt setzen (Einstellungen: Standard-Kamera).
func set_mode(m: int) -> void:
	while int(cam_mode) != clampi(m, 0, 2):
		cycle_mode()


## Beim nächsten Bild direkt hinter den Fahrer springen (z. B. nach Terminalwechsel).
func snap() -> void:
	_initialized = false


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
		_yaw = rider.yaw - (1.2 if rider.in_dock(rider.pos.x, rider.pos.z) else 0.0)
	# erst mit dem Fahrer mitziehen, dann glätten: sonst hängt der Blick bei 8 m/s ca. 0,7 m hinterher
	# (von hinten unsichtbar, von der Seite beim Press deutlich)
	var move := Vector3(rider.vel.x, 0.0, rider.vel.z) * delta
	_focus = (_focus + move).lerp(target, 1.0 - exp(-delta * 12.0))

	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if look.length() > 0.1:
		_off_yaw -= look.x * 2.5 * delta
		_off_pitch -= look.y * 1.5 * delta
		_idle = 0.0
	_idle += delta

	var speed := rider.horizontal_speed()
	var sliding := rider.is_sliding()
	var pressing := sliding and absf(rider._press_vis) > 0.3
	_slide_k = lerpf(_slide_k, 1.0 if sliding else 0.0, 1.0 - exp(-delta * (3.0 if sliding else 1.5)))
	_press_k = lerpf(_press_k, 1.0 if pressing else 0.0, 1.0 - exp(-delta * (2.5 if pressing else 1.5)))
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
		# Auf dem Startsteg steht hinter dem Fahrer die T2-Hütte – von der Seite (Norden) schauen
		if rider.in_dock(rider.pos.x, rider.pos.z) and speed < 2.0:
			desired = rider.yaw - 1.2
		# Press: von der Seite (Brustseite des Fahrers) zuschauen
		if _press_k > 0.01:
			# schräg von hinten auf der Brustseite: Blick in Fahrtrichtung, Brett und gedrücktes Ende im Bild
			var side_yaw := rider.yaw + rider._facing() * PI * 0.5
			var vh := Vector3(rider.vel.x, 0.0, rider.vel.z)
			if vh.length() > 1.0:
				side_yaw = lerp_angle(side_yaw, atan2(-vh.x, -vh.z), PRESS_BEHIND)
			desired = lerp_angle(desired, side_yaw, _press_k * PRESS_SIDE)
		_yaw = lerp_angle(_yaw, desired, 1.0 - exp(-delta * 2.5))
		if _idle > 1.5:
			var back := 1.0 - exp(-delta * 1.5)
			_off_yaw = lerpf(wrapf(_off_yaw, -PI, PI), 0.0, back)
			_off_pitch = lerpf(_off_pitch, 0.0, back)

	_off_pitch = clampf(BASE_PITCH + _off_pitch, -1.35, 0.3) - BASE_PITCH

	if cam_mode == CamMode.SIDE:
		var side_pos := Vector3(_focus.x - 32.0, 6.0, _focus.z + 14.0)   # Nordseite (offener See, T1 liegt im Süden)
		global_position = global_position.lerp(side_pos, 1.0 - exp(-delta * 1.5))
		look_at(_focus, Vector3.UP)
	else:
		var pitch := BASE_PITCH + _off_pitch
		var zoom := 1.0
		# Press: Blick zwischen Körper (Becken) und dem Brett-Ende, mit dem geslidet wird
		if cam_mode == CamMode.CHASE and _press_k > 0.01:
			var want := _focus                   # Press vorbei: weich zurück auf den Fahrer
			if rider.press_body != Vector3.ZERO:
				want = (rider.press_body + Vector3(0.0, 0.5, 0.0)).lerp(rider.press_tip + Vector3(0.0, PRESS_LIFT, 0.0), PRESS_TIP)
			_press_focus = (_press_focus + move).lerp(want, 1.0 - exp(-delta * 8.0)) if _press_focus != Vector3.ZERO else want
		else:
			_press_focus = Vector3.ZERO
		var focus := _focus.lerp(_press_focus, _press_k * PRESS_FOCUS) if _press_focus != Vector3.ZERO else _focus
		if cam_mode == CamMode.CHASE:
			var vp := get_viewport().get_visible_rect().size
			var press_zoom := PRESS_ZOOM * (PRESS_PORTRAIT if vp.y > vp.x else 1.0)
			zoom = lerpf(lerpf(1.0, SLIDE_ZOOM, _slide_k), press_zoom, _press_k)
		var offset := Basis(Vector3.UP, _yaw + _off_yaw) * Basis(Vector3.RIGHT, pitch) * Vector3(0.0, 0.0, distance * zoom)
		var cam_pos := focus + offset
		var ground := maxf(water.height_at(cam_pos.x, cam_pos.z), Geo.height(cam_pos.x, cam_pos.z))
		cam_pos.y = maxf(cam_pos.y, ground + 0.6)
		global_position = cam_pos
		look_at(focus + Vector3(0.0, 0.3, 0.0), Vector3.UP)

	fov = lerpf(fov, 68.0 + clampf(speed * 1.2, 0.0, 14.0), 1.0 - exp(-delta * 3.0))
