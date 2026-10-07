extends Node3D
## Baut die Szene auf (einfache Platzhalter-Grafik), richtet die Steuerung ein und
## führt die Simulation in fester Reihenfolge aus: Wasser → Seilbahn → Fahrer.
##
## Testoptionen (nach "--" auf der Kommandozeile):
##   --autotest        Autopilot + Autostart + Telemetrie im Log
##   --quit=SEK        nach SEK Sekunden Simulationszeit beenden
##   --shot=PFAD.png   Screenshot speichern (mit --shot-time=SEK) und beenden
##   --cam=side|orbit  Kameramodus beim Start
##   --setup=ID        Feature-Setup aus setups/index.json (z. B. 2026-09, a, b)
##   --terminal=T1|T2  an welcher Anlage man fährt (der NPC fährt an der anderen)
##   --mobile          Handy-Steuerung erzwingen (mit --tilt=GRAD feste Neigung)
##   --touch-at=SEK,…  Test: Finger zu diesen Zeiten 0.4 s auf den Bildschirm

const RESET_DELAY := 3.0

var water: Water
var cable: CableSystem
var rider: Rider
var cam: ChaseCamera
var hud: Hud
var mobile: MobileInput
var _setups: Array = []          # aus setups/index.json
var _setup_idx := 0
var _setup_menu: OptionButton
var _setup_arg := ""
const SETTINGS := "user://settings.cfg"
var _touch_started := false     # dieser Finger hat die Anlage gestartet (kein Sprung)

## Welche Anlage fährt der Spieler? Der NPC fährt immer an der anderen.
const TERMINALS := ["T2", "T1"]
var terminal := "T2"
var pc: CableSystem              # Anlage des Spielers
var nc: CableSystem              # Anlage des NPC
var _terminal_menu: OptionButton
var _terminal_arg := ""
var _start := {}                 # "T1"/"T2" -> {pos, yaw, dock, mast_b}
var sfx: Sfx
var ambient: Ambient

var cable_t1: CableSystem
var features: FeatureSet
var npc: Rider
var _npc_crash_t := 0.0
var buoys: TurnBuoys
var beach: Beach

# Wende-Wertung: wer die Wende schafft, ohne abzusinken, bekommt Punkte
const SINK_SPEED := 1.5         # m/s – fast Stillstand, das Brett sinkt ein ...
const SINK_TIME := 1.0          # ... und nach so vielen Sekunden ist man abgesoffen
var _turn_active := false
var _turn_end := 1.0
var _turn_slow := 0.0
var _turn_around := false
var _crash_t := 0.0
var _max_tension := 0.0

var _test_log := false
var _quit_after := 0.0
var _shot_path := ""
var _shot_time := 3.0
var _shot_taken := false
var _cam_arg := ""
var _view_arg := PackedFloat32Array()
var _lane_arg := NAN
var _crash_at := -1.0          # Test: Sturz zu dieser Zeit auslösen
var _touch_at: Array[float] = []   # Test: Finger auf den Bildschirm
var _closeup := Vector3.INF     # Testkamera relativ zum Fahrer
var _closeup_look := Vector3(0, 1.1, 0)   # Blickpunkt relativ zum Fahrer (optional 4.-6. Wert)
var _elapsed := 0.0
var _log_t := 0.0


func _ready() -> void:
	_setup_input()
	_parse_args()
	_build_environment()
	Geo.ensure_loaded()
	add_child(Terrain.new())
	beach = Beach.new()
	add_child(beach)

	water = Water.new()
	add_child(water)
	cable = CableSystem.new()
	add_child(cable)
	# Nachbaranlage T1 mit einem NPC-Fahrer (startet vom T1-Schwimmsteg)
	cable_t1 = CableSystem.new()
	cable_t1.place_between(Geo.masts["t1_start"], Geo.masts["t1_end"])
	var dc := Geo.rel_to_game(21.9, -29.5)
	var npc_start := Vector3(dc.x + 1.5, Lake.DOCK_Y, dc.y)
	var npc_local_z := (cable_t1.transform.affine_inverse() * npc_start).z
	cable_t1.start_z = npc_local_z - 9.0
	cable_t1.turn_a_z = npc_local_z - 16.0
	add_child(cable_t1)
	rider = Rider.new()
	rider.water = water
	rider.cable = cable
	add_child(rider)
	water.follow = rider

	# Hindernisse beider Terminals aus den Setup-Dateien (modular, siehe setups/)
	buoys = TurnBuoys.new()
	buoys.water = water
	add_child(buoys)
	buoys.add_cable(cable)
	buoys.add_cable(cable_t1)

	features = FeatureSet.new()
	add_child(features)
	_setups = FeatureSet.list_setups()
	_setup_idx = _initial_setup()
	features.load_setup(_setups[_setup_idx]["file"], {"T1": cable_t1, "T2": cable}, _s_offset())
	rider.features = features

	npc = Rider.new()
	npc.water = water
	npc.features = features
	npc.cable = cable_t1
	npc.is_npc = true
	npc.autopilot = true
	npc.vest_color = Color(0.15, 0.45, 0.95)
	npc.model_path = "res://assets/characters/guest_m.glb"
	npc.shirt_color = Color(0.85, 0.85, 0.82)
	npc.shorts_color = Color(0.1, 0.1, 0.12)
	npc.board_design = 4               # "Dots" aus der Brett-Bibliothek
	add_child(npc)
	# Startplätze beider Anlagen (Startsteg, Blickrichtung, Steg-Fläche, Endmast)
	_start["T2"] = {"pos": Rider.START_POS, "yaw": 0.0, "dock": Rect2(Lake.DOCK_MIN, Lake.DOCK_MAX - Lake.DOCK_MIN),
		"mast_b": Vector3(0.0, 0.0, Lake.MAST_B_Z)}
	_start["T1"] = {"pos": npc_start, "yaw": cable_t1.rotation.y, "dock": Rect2(dc.x - 3.5, dc.y - 2.2, 7.0, 4.4),
		"mast_b": Geo.masts["t1_end"]}
	npc.crashed.connect(func(reason: String) -> void:
		nc.emergency_stop()
		if _test_log:
			var l := nc.transform.affine_inverse() * npc.pos
			print("NPC CRASH: ", reason, " local x=%.2f s=%.2f y=%.2f" % [l.x, nc.mast_a_z - l.z, npc.pos.y]))
	npc.trick_landed.connect(func(trick: String, pts: int) -> void:
		if _test_log:
			print("NPC TRICK: ", trick, " +", pts))
	rider.crashed.connect(_on_crashed)
	rider.trick_landed.connect(_on_trick)

	cam = ChaseCamera.new()
	cam.far = 6000.0
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
	_terminal_menu = hud.add_menu_choice("Terminal  (T wechseln)", ["T2 (Strand, große Hütte)", "T1 (Lounge-Steg)"], 0, _on_terminal_menu)
	var names: Array = []
	for e: Dictionary in _setups:
		names.append(e["name"])
	_setup_menu = hud.add_menu_choice("Feature-Setup  (F wechseln)", names, _setup_idx, _select_setup)
	# Handy/Tablet: Tippen = Start bzw. Sprung, Neigen = lenken
	mobile = MobileInput.new()
	add_child(mobile)
	mobile.ui_blockers = [_setup_menu.get_parent(), _setup_menu.get_popup(), _terminal_menu.get_popup()]
	if mobile.active:
		hud.set_help(Hud.HELP_MOBILE)
		mobile.touch_down.connect(_on_touch_down)
		mobile.touch_up.connect(_on_touch_up)
	sfx = Sfx.new()
	sfx.rider = rider
	sfx.people = beach.people
	add_child(sfx)
	# Leben am See: laufende Steuermänner, wartende Fahrer, SUPs, Hecht
	ambient = Ambient.new()
	ambient.beach = beach
	ambient.water = water
	ambient.features = features
	ambient.sfx = sfx
	ambient.player = rider
	add_child(ambient)
	ambient.build()
	ambient.pike_hit.connect(func() -> void: hud.show_trick("Hecht erwischt!"))
	_apply_terminal(_initial_terminal())
	if _view_arg.size() == 6:
		# Testansicht: feste Kamera (x,y,z -> Blickpunkt x,y,z)
		cam.set_process(false)
		cam.global_position = Vector3(_view_arg[0], _view_arg[1], _view_arg[2])
		cam.look_at(Vector3(_view_arg[3], _view_arg[4], _view_arg[5]), Vector3.UP)
		hud.visible = false
	_reset()

	if _test_log:
		rider.autopilot = true
		rider.auto_lane = _lane_arg
		pc.start()


# ---------------------------------------------------------------- Terminal

func _initial_terminal() -> String:
	var want := _terminal_arg
	if want == "":
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK:
			want = cfg.get_value("game", "terminal", "T2")
	return want if want in TERMINALS else "T2"


func _on_terminal_menu(idx: int) -> void:
	_select_terminal(TERMINALS[idx])


## Spieler an die andere Anlage (nur solange seine Anlage steht); der NPC wechselt mit.
func _select_terminal(t: String) -> void:
	if t == terminal or pc.state != CableSystem.State.IDLE or rider.mode == Rider.Mode.CRASHED:
		_terminal_menu.select(TERMINALS.find(terminal))
		return
	_apply_terminal(t)
	hud.show_trick("Terminal " + t)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("game", "terminal", t)
	cfg.save(SETTINGS)


func _apply_terminal(t: String) -> void:
	terminal = t
	var other := "T1" if t == "T2" else "T2"
	pc = cable if t == "T2" else cable_t1
	nc = cable_t1 if t == "T2" else cable
	_place_rider(rider, pc, _start[t])
	_place_rider(npc, nc, _start[other])
	_terminal_menu.select(TERMINALS.find(t))
	# Jubel kommt aus dem Startblock der eigenen Anlage
	sfx.set_people(beach.people if t == "T2" else beach.people_t1)
	ambient.set_watch(rider if t == "T2" else npc, rider if t == "T1" else npc)
	pc.reset()
	nc.reset()
	nc.start()
	_npc_crash_t = 0.0
	_reset()
	cam.snap()


func _place_rider(r: Rider, c: CableSystem, s: Dictionary) -> void:
	r.cable = c
	r.start_pos = s["pos"]
	r.start_yaw = s["yaw"]
	r.dock_rect = s["dock"]
	r.mast_b = s["mast_b"]
	r.forget_features()
	r.reset()


# ---------------------------------------------------------------- Feature-Setups

## Die Setups sind ab dem T2-Startsteg gemessen. Der T1-Steg liegt weiter draußen am Seil –
## dort rücken die Teile um den Unterschied nach hinten (gleicher Anlauf auf beiden Anlagen).
func _s_offset() -> Dictionary:
	return {"T1": (cable.start_z - cable_t1.start_z) - (cable.mast_a_z - cable_t1.mast_a_z)}


## Start-Setup: --setup=ID, sonst das zuletzt gewählte, sonst das erste (aktuellste).
func _initial_setup() -> int:
	var want := _setup_arg
	if want == "":
		var cfg := ConfigFile.new()
		if cfg.load(SETTINGS) == OK:
			want = cfg.get_value("game", "setup", "")
	for i in _setups.size():
		if _setups[i]["id"] == want:
			return i
	return 0


## Anderes Feature-Setup aufbauen (nur solange die Anlage steht).
func _select_setup(idx: int) -> void:
	if pc.state != CableSystem.State.IDLE or idx == _setup_idx:
		_setup_menu.select(_setup_idx)
		return
	_setup_idx = idx
	features.load_setup(_setups[idx]["file"], {"T1": cable_t1, "T2": cable}, _s_offset())
	rider.forget_features()
	npc.forget_features()
	npc.reset()
	nc.reset()
	nc.start()
	_npc_crash_t = 0.0
	_setup_menu.select(idx)
	hud.show_trick("Setup: " + str(_setups[idx]["name"]))
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("game", "setup", _setups[idx]["id"])
	cfg.save(SETTINGS)


# ---------------------------------------------------------------- Ablauf

## Finger auf den Bildschirm: steht die Anlage, startet sie (ohne Sprung);
## sonst wird wie mit der Leertaste der Sprung aufgeladen.
func _on_touch_down() -> void:
	if pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED:
		pc.start()
		_touch_started = true
	else:
		Input.action_press("jump")


## Finger weg: Absprung (falls geladen).
func _on_touch_up() -> void:
	_touch_started = false
	Input.action_release("jump")


## Über Bojen und Stege fährt man einfach drüber: die Boje wird unter Wasser gedrückt,
## der Fahrer macht ein kleines "Ups" (kein Sturz).
var _on_steg := {}

func _check_buoy(r: Rider) -> void:
	if r.mode == Rider.Mode.CRASHED:
		return
	var id := r.get_instance_id()
	if buoys.run_over(r.pos, 0.25, id):
		r.ups()
	var on := beach.obstacle_hit(r.pos, 0.25) and not r.in_dock(r.pos.x, r.pos.z)
	if on and not _on_steg.get(id, false):
		r.ups()
	_on_steg[id] = on


func _physics_process(delta: float) -> void:
	water.step(delta)
	pc.step(delta, pc.local_vz(rider.vel) if rider.attached else 0.0, rider.rope_slack())
	nc.step(delta, nc.local_vz(npc.vel) if npc.attached else 0.0, npc.rope_slack())
	npc.step(delta)
	_check_buoy(npc)
	if npc.mode == Rider.Mode.CRASHED:
		_npc_crash_t += delta
		if _npc_crash_t > 4.0:
			_npc_crash_t = 0.0
			npc.reset()
			nc.reset()
			nc.start()
	rider.step(delta)
	_check_buoy(rider)
	_track_turn()

	if rider.mode == Rider.Mode.CRASHED:
		_crash_t += delta
		if _crash_t > RESET_DELAY:
			_reset()
			if _test_log:
				pc.start()

	_elapsed += delta
	for i in _touch_at.size():
		var t := _touch_at[i]
		if t > 0.0 and _elapsed >= t:
			_touch_at[i] = -(t + 0.4)
			_fake_touch(true)
		elif t < 0.0 and _elapsed >= -t:
			_touch_at[i] = 0.0
			_fake_touch(false)
	if _crash_at > 0.0 and _elapsed >= _crash_at:
		_crash_at = -1.0
		rider.crash("Teststurz")
	_max_tension = maxf(_max_tension, rider.tension_smooth)
	if _test_log:
		_log_t += delta
		if _log_t >= 1.0:
			_log_t = 0.0
			print("t=%5.1f carrier=%-17s s=%7.1f v=%5.2f | rider %-7s pos=(%6.1f,%5.2f,%7.1f) %5.1f km/h T=%5.0f N Tmax=%5.0f laps=%d score=%d | NPC %s %4.1f km/h NPC-Wenden %d" % [
				_elapsed, pc.state_text(), pc.s, pc.v, Rider.Mode.keys()[rider.mode],
				rider.pos.x, rider.pos.y, rider.pos.z, rider.horizontal_speed() * 3.6,
				rider.tension_smooth, _max_tension, pc.laps, rider.score,
				Rider.Mode.keys()[npc.mode], npc.horizontal_speed() * 3.6, nc.laps])
	if _quit_after > 0.0 and _elapsed >= _quit_after:
		get_tree().quit()


func _fake_touch(pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.pressed = pressed
	e.position = Vector2(400, 300)
	Input.parse_input_event(e)
	print("TOUCH ", "down" if pressed else "up", " t=%.1f carrier=%s rider=%s pos=%s steer=%.2f" % [
		_elapsed, pc.state_text(), Rider.Mode.keys()[rider.mode], rider.pos.snapped(Vector3.ONE * 0.1),
		Input.get_axis("steer_left", "steer_right")])


func _process(_delta: float) -> void:
	if _closeup != Vector3.INF:
		cam.set_process(false)
		hud.visible = false
		var rp := rider.visual_position()
		cam.look_at_from_position(rp + rider.global_basis * _closeup, rp + rider.global_basis * _closeup_look)
	var info := "Fahrer: %d km/h\nAnlage %s: %s  (Tempo %d km/h)\nWenden: %d     Punkte: %d\nKamera: %s%s\nSeilzug: %d N" % [
		roundi(rider.horizontal_speed() * 3.6), terminal, pc.state_text(), roundi(pc.max_speed * 3.6),
		pc.laps, rider.score, cam.mode_name(), "   [AUTOPILOT]" if rider.autopilot else "",
		roundi(rider.tension_smooth)]
	hud.set_info(info, rider.tension_smooth / Rider.CRASH_TENSION)
	hud.set_board(rider.board_state_text())
	hud.show_setup_menu(pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED)
	if rider.mode != Rider.Mode.CRASHED:
		if pc.state == CableSystem.State.IDLE:
			hud.set_center("Tippen zum Starten" if mobile.active else "ENTER drücken zum Starten")
		elif mobile.active and not mobile.tilt_available:
			hud.set_center("Neigungssensor nicht verfügbar –\nBewegungssensoren im Browser erlauben")
		else:
			hud.set_center("")

	if _shot_path != "" and not _shot_taken and _elapsed >= _shot_time:
		_shot_taken = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot_path)
		print("screenshot saved: ", _shot_path)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		if pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED:
			pc.start()
	elif event.is_action_pressed("reset"):
		_reset()
	elif event.is_action_pressed("speed_up"):
		pc.change_speed(2.0)
	elif event.is_action_pressed("speed_down"):
		pc.change_speed(-2.0)
	elif event.is_action_pressed("camera"):
		cam.cycle_mode()
	elif event.is_action_pressed("autopilot"):
		rider.autopilot = not rider.autopilot
	elif event.is_action_pressed("next_terminal"):
		_select_terminal("T1" if terminal == "T2" else "T2")
	elif event.is_action_pressed("next_setup"):
		_select_setup((_setup_idx + 1) % _setups.size())
	elif event.is_action_pressed("help"):
		hud.toggle_help()


## Wertet eine Wende aus: beginnt, wenn der Carrier zur Wende bremst, endet, wenn er
## wieder auf Tempo geht. Punkte, wenn man nicht abgesoffen ist (nicht länger als
## SINK_TIME unter SINK_SPEED);
## Bonus, wenn man außen um eine der weißen Bojen herumgefahren ist.
func _track_turn() -> void:
	if pc.state == CableSystem.State.BRAKE and not _turn_active and rider.attached and rider.mode != Rider.Mode.CRASHED:
		_turn_active = true
		_turn_end = 1.0 if pc.dir < 0.0 else -1.0
		_turn_slow = 0.0
		_turn_around = false
	if not _turn_active:
		return
	if rider.mode == Rider.Mode.CRASHED or not rider.attached:
		_turn_active = false
		return
	if rider.mode == Rider.Mode.WATER and rider.horizontal_speed() < SINK_SPEED:
		_turn_slow += get_physics_process_delta_time()
	var local := pc.transform.affine_inverse() * rider.pos
	var s := pc.mast_a_z - local.z
	var s_turn := pc.mast_a_z - (pc.turn_b_z if _turn_end > 0.0 else pc.turn_a_z)
	var s_white := s_turn - _turn_end * TurnBuoys.WHITE_BEFORE
	if (s - s_white) * _turn_end > 0.0 and absf(local.x) > TurnBuoys.WHITE_SIDE - 0.5:
		_turn_around = true
	if pc.state == CableSystem.State.RUN:
		_turn_active = false
		if _turn_slow < SINK_TIME:
			rider.award("Wende um die Boje" if _turn_around else "Saubere Wende", 250 if _turn_around else 120)
		elif _test_log:
			print("WENDE abgesoffen, %.1f s zu langsam" % _turn_slow)


func _reset() -> void:
	_turn_active = false
	rider.reset()
	pc.reset()
	water.clear_wake()
	_crash_t = 0.0


func _on_crashed(reason: String) -> void:
	pc.emergency_stop()
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
	_bind("next_setup", [KEY_F], [], [])
	_bind("next_terminal", [KEY_T], [], [])
	_bind("mute", [KEY_M], [], [])
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
		elif arg.begins_with("--crash-at="):
			_crash_at = arg.substr(11).to_float()
		elif arg.begins_with("--terminal="):
			_terminal_arg = arg.substr(11).to_upper()
		elif arg.begins_with("--setup="):
			_setup_arg = arg.substr(8)
		elif arg.begins_with("--touch-at="):
			for v in arg.substr(11).split(","):
				_touch_at.append(v.to_float())
		elif arg.begins_with("--closeup="):
			var c := arg.substr(10).split(",")
			_closeup = Vector3(c[0].to_float(), c[1].to_float(), c[2].to_float())
			if c.size() >= 6:
				_closeup_look = Vector3(c[3].to_float(), c[4].to_float(), c[5].to_float())
		elif arg.begins_with("--lane="):
			_lane_arg = arg.substr(7).to_float()
		elif arg.begins_with("--view="):
			_view_arg = PackedFloat32Array(Array(arg.substr(7).split(",")).map(func(v: String) -> float: return v.to_float()))
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
	# Schatten nicht zu blau: Himmelslicht nur teilweise, Rest neutrales Grau
	env.ambient_light_color = Color(0.62, 0.6, 0.55)
	env.ambient_light_sky_contribution = 0.45
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.78, 0.88)
	env.fog_density = 0.00022   # maximale Sichtweite, nur leichter Dunst am Horizont
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	# Echte Himmelsrichtung: Nachmittagssonne aus Süd-Südwest (Azimut 200°, 45° hoch)
	var az := deg_to_rad(200.0)
	var el := deg_to_rad(45.0)
	var flat := Geo.rel_to_game(sin(az), cos(az))
	var to_sun := Vector3(flat.x * cos(el), sin(el), flat.y * cos(el))
	sun.basis = Basis.looking_at(-to_sun)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
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





