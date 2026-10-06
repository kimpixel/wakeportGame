extends Node3D
## Baut die Szene auf (einfache Platzhalter-Grafik), richtet die Steuerung ein und
## führt die Simulation in fester Reihenfolge aus: Wasser → Seilbahn → Fahrer.
##
## Testoptionen (nach "--" auf der Kommandozeile):
##   --autotest        Autopilot + Autostart + Telemetrie im Log
##   --quit=SEK        nach SEK Sekunden Simulationszeit beenden
##   --shot=PFAD.png   Screenshot speichern (mit --shot-time=SEK) und beenden
##   --cam=side|orbit  Kameramodus beim Start

const RESET_DELAY := 3.0

var water: Water
var cable: CableSystem
var rider: Rider
var cam: ChaseCamera
var hud: Hud

var _buoys: Array[Node3D] = []
var _crash_t := 0.0
var _max_tension := 0.0

var _test_log := false
var _quit_after := 0.0
var _shot_path := ""
var _shot_time := 3.0
var _shot_taken := false
var _cam_arg := ""
var _elapsed := 0.0
var _log_t := 0.0


func _ready() -> void:
	_setup_input()
	_parse_args()
	_build_environment()
	_build_shore()
	_build_kickers()

	water = Water.new()
	add_child(water)
	cable = CableSystem.new()
	add_child(cable)
	rider = Rider.new()
	rider.water = water
	rider.cable = cable
	add_child(rider)
	rider.crashed.connect(_on_crashed)
	rider.trick_landed.connect(_on_trick)

	cam = ChaseCamera.new()
	cam.rider = rider
	cam.water = water
	add_child(cam)
	cam.current = true
	if _cam_arg == "side":
		cam.cycle_mode()
		cam.cycle_mode()
	elif _cam_arg == "orbit":
		cam.cycle_mode()

	hud = Hud.new()
	add_child(hud)
	_build_buoys()
	_reset()

	if _test_log:
		rider.autopilot = true
		cable.start()


# ---------------------------------------------------------------- Ablauf

func _physics_process(delta: float) -> void:
	water.step(delta)
	cable.step(delta, rider.vel.z if rider.attached else 0.0, rider.rope_slack())
	rider.step(delta)

	if rider.mode == Rider.Mode.CRASHED:
		_crash_t += delta
		if _crash_t > RESET_DELAY:
			_reset()
			if _test_log:
				cable.start()

	_elapsed += delta
	_max_tension = maxf(_max_tension, rider.tension_smooth)
	if _test_log:
		_log_t += delta
		if _log_t >= 1.0:
			_log_t = 0.0
			print("t=%5.1f carrier=%-17s s=%7.1f v=%5.2f | rider %-7s pos=(%6.1f,%5.2f,%7.1f) %5.1f km/h T=%5.0f N Tmax=%5.0f laps=%d score=%d" % [
				_elapsed, cable.state_text(), cable.s, cable.v, Rider.Mode.keys()[rider.mode],
				rider.pos.x, rider.pos.y, rider.pos.z, rider.horizontal_speed() * 3.6,
				rider.tension_smooth, _max_tension, cable.laps, rider.score])
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		get_tree().quit()


func _process(_delta: float) -> void:
	for b in _buoys:
		b.position.y = water.height_at(b.position.x, b.position.z) + 0.1

	var info := "Fahrer: %d km/h\nAnlage: %s  (Tempo %d km/h)\nWenden: %d     Punkte: %d\nKamera: %s%s\nSeilzug: %d N" % [
		roundi(rider.horizontal_speed() * 3.6), cable.state_text(), roundi(cable.max_speed * 3.6),
		cable.laps, rider.score, cam.mode_name(), "   [AUTOPILOT]" if rider.autopilot else "",
		roundi(rider.tension_smooth)]
	hud.set_info(info, rider.tension_smooth / Rider.CRASH_TENSION)
	hud.set_board(rider.board_state_text())
	if rider.mode != Rider.Mode.CRASHED:
		hud.set_center("ENTER drücken zum Starten" if cable.state == CableSystem.State.IDLE else "")

	if _shot_path != "" and not _shot_taken and _elapsed >= _shot_time:
		_shot_taken = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("screenshot saved: ", _shot_path)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		if cable.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED:
			cable.start()
	elif event.is_action_pressed("reset"):
		_reset()
	elif event.is_action_pressed("speed_up"):
		cable.change_speed(2.0)
	elif event.is_action_pressed("speed_down"):
		cable.change_speed(-2.0)
	elif event.is_action_pressed("camera"):
		cam.cycle_mode()
	elif event.is_action_pressed("autopilot"):
		rider.autopilot = not rider.autopilot
	elif event.is_action_pressed("help"):
		hud.toggle_help()


func _reset() -> void:
	rider.reset()
	cable.reset()
	water.clear_wake()
	_crash_t = 0.0


func _on_crashed(reason: String) -> void:
	cable.emergency_stop()
	hud.set_center("%s\nNeustart in %d s  (oder R)" % [reason, int(RESET_DELAY)])
	if _test_log:
		print("CRASH: ", reason, " at ", rider.pos)


func _on_trick(trick_name: String, points: int) -> void:
	hud.show_trick("%s   +%d" % [trick_name, points])
	if _test_log:
		print("TRICK: ", trick_name, " +", points)


# ---------------------------------------------------------------- Eingabe

func _setup_input() -> void:
	_bind("steer_left", [KEY_A, KEY_LEFT], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("steer_right", [KEY_D, KEY_RIGHT], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_bind("edge", [KEY_W, KEY_UP], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_bind("release", [KEY_S, KEY_DOWN], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_bind("start", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_START], [])
	_bind("reset", [KEY_R], [JOY_BUTTON_BACK], [])
	_bind("speed_up", [KEY_PAGEUP], [JOY_BUTTON_DPAD_UP], [], [KEY_PLUS, KEY_KP_ADD])
	_bind("speed_down", [KEY_PAGEDOWN], [JOY_BUTTON_DPAD_DOWN], [], [KEY_MINUS, KEY_KP_SUBTRACT])
	_bind("camera", [KEY_C], [JOY_BUTTON_Y], [])
	_bind("autopilot", [KEY_P], [], [])
	_bind("help", [KEY_H, KEY_F1], [], [])
	_bind("cam_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("cam_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("cam_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("cam_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])


## physical_keys: Tastenposition (WASD auf jedem Layout gleich), logical_keys: Zeichen (+/-).
func _bind(action: String, physical_keys: Array, buttons: Array, axes: Array, logical_keys: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	for k: Key in physical_keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for k: Key in logical_keys:
		var e := InputEventKey.new()
		e.keycode = k
		InputMap.action_add_event(action, e)
	for b: JoyButton in buttons:
		var e := InputEventJoypadButton.new()
		e.button_index = b
		InputMap.action_add_event(action, e)
	for a: Array in axes:
		var e := InputEventJoypadMotion.new()
		e.axis = a[0]
		e.axis_value = a[1]
		InputMap.action_add_event(action, e)


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autotest":
			_test_log = true
		elif arg.begins_with("--quit="):
			_quit_after = arg.substr(7).to_float()
		elif arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--shot-time="):
			_shot_time = arg.substr(12).to_float()
		elif arg.begins_with("--cam="):
			_cam_arg = arg.substr(6)


# ---------------------------------------------------------------- Welt

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.22, 0.42, 0.78)
	sky_mat.sky_horizon_color = Color(0.68, 0.78, 0.9)
	sky_mat.ground_horizon_color = Color(0.6, 0.7, 0.75)
	sky_mat.ground_bottom_color = Color(0.25, 0.32, 0.25)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.88)
	env.fog_density = 0.0015
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)

	# Browser (Compatibility-Renderer) belichtet deutlich heller – eigene Werte, damit es
	# ungefähr so aussieht wie die Desktop-Version.
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		sky_mat.sky_top_color = Color(0.08, 0.22, 0.6)
		sky_mat.sky_horizon_color = Color(0.42, 0.55, 0.76)
		env.fog_light_color = Color(0.5, 0.6, 0.75)
		sky_mat.energy_multiplier = 0.8
		env.ambient_light_energy = 0.3
		env.tonemap_exposure = 0.8
		sun.light_energy = 0.65


func _build_shore() -> void:
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var grass := Util.mat(Color(0.14, 0.3, 0.08) if compat else Color(0.32, 0.55, 0.25))
	var sand := Util.mat(Color(0.82, 0.74, 0.55))
	var wood := Util.mat(Color(0.55, 0.38, 0.22))
	var far := 500.0
	var y := Lake.SHORE_Y - 1.5
	var lake_len := Lake.MAX_Z - Lake.MIN_Z
	var zc := (Lake.MIN_Z + Lake.MAX_Z) * 0.5
	# Vier Uferblöcke um das See-Rechteck herum
	Util.box(self, Vector3(2.0 * far, 3.0, far), Vector3(0.0, y, Lake.MAX_Z + far * 0.5), grass)
	Util.box(self, Vector3(2.0 * far, 3.0, far), Vector3(0.0, y, Lake.MIN_Z - far * 0.5), grass)
	Util.box(self, Vector3(far, 3.0, lake_len), Vector3(Lake.MIN_X - far * 0.5, y, zc), grass)
	Util.box(self, Vector3(far, 3.0, lake_len), Vector3(Lake.MAX_X + far * 0.5, y, zc), grass)
	# Strand + Startsteg + Motorhaus am Ufermast
	Util.box(self, Vector3(40.0, 0.1, 12.0), Vector3(0.0, Lake.SHORE_Y, 6.0), sand)
	var dmin := Lake.DOCK_MIN
	var dmax := Lake.DOCK_MAX
	Util.box(self, Vector3(dmax.x - dmin.x, 0.6, dmax.y - dmin.y),
		Vector3((dmin.x + dmax.x) * 0.5, Lake.DOCK_Y - 0.3, (dmin.y + dmax.y) * 0.5), wood)
	Util.box(self, Vector3(3.0, 2.5, 3.0), Vector3(4.5, Lake.SHORE_Y + 1.25, Lake.MAST_A_Z + 1.0), Util.mat(Color(0.3, 0.33, 0.38)))

	# Bäume
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var trunk := Util.mat(Color(0.4, 0.28, 0.18))
	var leaf := Util.mat(Color(0.17, 0.38, 0.2))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 2.2
	cone.height = 6.0
	var placed := 0
	while placed < 90:
		var x := rng.randf_range(-170.0, 170.0)
		var z := rng.randf_range(-430.0, 90.0)
		if x > Lake.MIN_X - 6.0 and x < Lake.MAX_X + 6.0 and z > Lake.MIN_Z - 6.0 and z < Lake.MAX_Z + 16.0:
			continue
		var sc := rng.randf_range(0.7, 1.4)
		var base := Vector3(x, Lake.SHORE_Y, z)
		Util.beam(self, base, base + Vector3(0.0, 2.0 * sc, 0.0), 0.25 * sc, trunk)
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = leaf
		mi.position = base + Vector3(0.0, 5.0 * sc, 0.0)
		mi.scale = Vector3.ONE * sc
		add_child(mi)
		placed += 1


func _build_buoys() -> void:
	var orange := Util.mat(Color(1.0, 0.45, 0.05), 0.5)
	for side: float in [-1.0, 1.0]:
		for i in 8:
			_buoys.append(Util.sphere(self, 0.35, Vector3(side * 28.0, 0.0, -30.0 - i * 40.0), orange))


func _build_kickers() -> void:
	var mat := Util.mat(Color(0.92, 0.92, 0.88), 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k: Dictionary in Lake.KICKERS:
		var kx: float = k["x"]
		var kz: float = k["z"]
		var kdir: float = k["dir"]
		var klen: float = k["len"]
		var kw: float = k["width"]
		var kh: float = k["height"]
		var x0 := kx - kw * 0.5
		var x1 := kx + kw * 0.5
		var bottom := -0.6
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var n := 12
		for i in n:
			var u0 := float(i) / n
			var u1 := float(i + 1) / n
			var z0 := kz + kdir * (u0 * klen - klen * 0.5)
			var z1 := kz + kdir * (u1 * klen - klen * 0.5)
			var h0 := Lake.kicker_profile(u0, kh)
			var h1 := Lake.kicker_profile(u1, kh)
			_quad(st, Vector3(x0, h0, z0), Vector3(x1, h0, z0), Vector3(x1, h1, z1), Vector3(x0, h1, z1), Vector3.UP)
			_quad(st, Vector3(x0, bottom, z0), Vector3(x0, h0, z0), Vector3(x0, h1, z1), Vector3(x0, bottom, z1), Vector3.LEFT)
			_quad(st, Vector3(x1, bottom, z0), Vector3(x1, h0, z0), Vector3(x1, h1, z1), Vector3(x1, bottom, z1), Vector3.RIGHT)
		var zl := kz + kdir * klen * 0.5
		_quad(st, Vector3(x0, bottom, zl), Vector3(x1, bottom, zl), Vector3(x1, kh, zl), Vector3(x0, kh, zl), Vector3(0.0, 0.0, kdir))
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		add_child(mi)


## Zwei Dreiecke; Reihenfolge wird so gedreht, dass die Normale nach "outward" zeigt.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, outward: Vector3) -> void:
	if Plane(a, b, c).normal.dot(outward) < 0.0:
		var t := b
		b = d
		d = t
	for v in [a, b, c, a, c, d]:
		st.add_vertex(v)
