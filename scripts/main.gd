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
##   --screen[=NAME]   Startbildschirm erzwingen (NAME: Feature/Hack auswählen, z. B. "hack");
##                     normal beginnt das Spiel damit, außer bei --autotest/--shot/--view/--closeup
##   --letgo-at=SEK    Test: Seil zu dieser Zeit verlieren (ohne Sturz)
##   --jump-at=SEK     Test: zu dieser Zeit voll aufgeladen abspringen
##   --pitch=±1        Test: in der Luft ↑ (+1, Frontroll) bzw. ↓ (-1, Backroll) halten
##   --game-time=SEK   Test: Spielzeit (normal 450 s); im Autotest läuft dann eine Runde mit Zeit
##   --weather=ID      Wetter (sonnig, heiter, bewoelkt, bedeckt, regen, dunst)
##   --hour=H --day=T  Uhrzeit (deutsche Zeit) und Tag im Jahr; Tests sonst 21. Juni 14:30
##   --plane=S         Test: sofort ein Jet im Anflug, S m vor dem See (negativ) bzw. danach
##   --passive         Test (mit --autotest): Fahrer ohne Autopilot und ohne Eingaben
##   --no-screen       ohne Startbildschirm direkt ins Spiel
##   --set=NAME=WERT   Test: Einstellung setzen (ohne zu speichern), z. B. --set=goofy=true

const RESET_DELAY := 3.0

# Spielregeln: eine Runde dauert 7:30, es zählen die Punkte in dieser Zeit. Danach wird man
# nur noch zum Start gebracht. Abkürzungen kosten Zeit.
const GAME_TIME := 450.0
const SKIP_PENALTY := 180.0     # Leertaste nach Sturz: Handle sofort da
const RESET_PENALTY := 300.0    # R: zurück zum Startsteg
var _session := false           # Runde läuft (Zeit zählt)
var _game_time := GAME_TIME    # Test: --game-time=SEK
var _time_left := GAME_TIME
var _finishing := false         # Zeit um, Carrier bringt den Fahrer zum Start
var _final_score := 0
var _last_result := ""

var water: Water
var cable: CableSystem
var rider: Rider
var cam: ChaseCamera
var hud: Hud
var mobile: MobileInput
var touch_pad: TouchPad         # nur am Handy
var _setups: Array = []          # aus setups/index.json
var _setup_idx := 0
var _setup_menu: OptionButton
var _setup_arg := ""
const SETTINGS := "user://settings.cfg"
# Einstellungen der Startseite (gespeichert, siehe GameSettings)
var settings := GameSettings.new()
var terrain: Terrain
var _free := false              # Freies Fahren: keine Zeit, keine Strafzeit
var _npc_on := true
var _msaa_default := Viewport.MSAA_DISABLED
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
var weather: Weather
var airplanes: Airplanes
var _plane_arg := NAN
var _load_arg := NAN
var _passive_arg := false       # Test: Fahrer ohne Autopilot, ohne Eingaben
var _weather_arg := ""
var _hour_arg := NAN
var _day_arg := 0
var start_screen: StartScreen
var _screen_arg := false
var _no_screen := false
var _screen_select := ""

var cable_t1: CableSystem
var features: FeatureSet
var npc: Rider
var _npc_crash_t := 0.0
var buoys: TurnBuoys
var beach: Beach

# Wende-Wertung: wer die Wende schafft, ohne abzusinken, bekommt Punkte
var _turn_active := false
var _turn_end := 1.0
var _turn_sank := false          # in der Wende abgesoffen -> keine Punkte
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
var _letgo_at := -1.0          # Test: Seil zu dieser Zeit verlieren
var _set_args: Array[String] = []   # Test: --set=NAME=WERT
var _jump_at := -1.0           # Test: zu dieser Zeit abspringen
var _test_pitch := 0.0         # Test: ↑/↓ in der Luft
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
	terrain = Terrain.new()
	add_child(terrain)
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
	var npc_start := Vector3(dc.x + 1.5, Lake.DOCK_T1_Y, dc.y)
	var npc_local_z := (cable_t1.transform.affine_inverse() * npc_start).z
	cable_t1.start_z = npc_local_z - 9.0
	cable_t1.turn_a_z = npc_local_z - 16.0
	add_child(cable_t1)
	rider = Rider.new()
	rider.test_pitch = _test_pitch
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
	npc.helmet_design = 2
	add_child(npc)
	# Startplätze beider Anlagen (Startsteg, Blickrichtung, Steg-Fläche, Endmast)
	_start["T2"] = {"pos": Rider.START_POS, "yaw": 0.0, "dock": Rect2(Lake.DOCK_MIN, Lake.DOCK_MAX - Lake.DOCK_MIN),
		"mast_b": Vector3(0.0, 0.0, Lake.MAST_B_Z)}
	_start["T1"] = {"pos": npc_start, "yaw": cable_t1.rotation.y, "dock": Rect2(dc.x - 3.5, dc.y - 2.2, 7.0, 4.4),
		"mast_b": Geo.masts["t1_end"]}
	npc.grabbed.connect(func() -> void: nc.resume())
	npc.crashed.connect(func(reason: String) -> void:
		if _test_log:
			var l := nc.transform.affine_inverse() * npc.pos
			print("NPC CRASH: ", reason, " local x=%.2f s=%.2f y=%.2f" % [l.x, nc.mast_a_z - l.z, npc.pos.y]))
	npc.trick_landed.connect(func(trick: String, pts: int) -> void:
		if _test_log:
			print("NPC TRICK: ", trick, " +", pts))
	rider.crashed.connect(_on_crashed)
	rider.rope_lost.connect(_on_crashed)
	rider.grabbed.connect(func() -> void:
		pc.resume()
		if _test_log:
			print("HANDLE GEGRIFFEN at ", rider.pos.snapped(Vector3.ONE * 0.1)))
	rider.trick_landed.connect(_on_trick)
	rider.sank.connect(func() -> void:
		if _test_log:
			print("ABGESOFFEN at t=%.1f" % _elapsed)
		if _turn_active:
			_turn_sank = true
		hud.show_trick("Abgesoffen!"))
	rider.skipped.connect(func() -> void: _penalty(SKIP_PENALTY))

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
	_terminal_menu = hud.add_menu_choice("Terminal", ["T2 (Strand, große Hütte)", "T1 (Lounge-Steg)"], 0, _on_terminal_menu)
	var names: Array = []
	for e: Dictionary in _setups:
		names.append(e["name"])
	_setup_menu = hud.add_menu_choice("Feature-Setup", names, _setup_idx, _select_setup)
	# Handy/Tablet: Tippen = Start bzw. Sprung, Neigen = lenken
	mobile = MobileInput.new()
	add_child(mobile)
	mobile.ui_blockers = [_setup_menu.get_parent(), _setup_menu.get_popup(), _terminal_menu.get_popup()]
	if mobile.active:
		hud.set_help(Hud.HELP_MOBILE)
		mobile.touch_down.connect(_on_touch_down)
		mobile.touch_up.connect(_on_touch_up)
		# virtuelle Tasten ▲ ▼ DRIFT und Menü ☰
		touch_pad = TouchPad.new()
		add_child(touch_pad)
		mobile.pad = touch_pad
		touch_pad.menu_action.connect(_on_pad_menu)
	sfx = Sfx.new()
	sfx.rider = rider
	sfx.people = beach.people
	sfx.haptics = mobile.active
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
	# Einflugschneise Frankfurt: Jets im Landeanflug über dem See
	airplanes = Airplanes.new()
	airplanes.jet_sound = sfx.make_jet_loop()
	add_child(airplanes)
	if not is_nan(_plane_arg):
		airplanes.spawn_at(_plane_arg)
	cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
	ambient.pike_hit.connect(func() -> void: hud.show_trick("Hecht erwischt!"))
	if not _test_log:
		settings.load_file(mobile.active)     # Tests laufen immer mit Standardwerten
	_apply_terminal(_initial_terminal())
	_build_start_screen()
	_msaa_default = get_viewport().msaa_3d
	settings.changed.connect(_apply_setting)
	for a: String in _set_args:
		var kv := a.split("=", true, 1)
		if kv.size() == 2 and settings.values.has(kv[0]):
			settings.values[kv[0]] = type_convert(str_to_var(kv[1]), typeof(GameSettings.DEFAULTS[kv[0]]))
	settings.emit_all()
	if _view_arg.size() == 6:
		# Testansicht: feste Kamera (x,y,z -> Blickpunkt x,y,z)
		cam.set_process(false)
		cam.global_position = Vector3(_view_arg[0], _view_arg[1], _view_arg[2])
		cam.look_at(Vector3(_view_arg[3], _view_arg[4], _view_arg[5]), Vector3.UP)
		hud.visible = false
	_reset()

	if _test_log:
		rider.autopilot = not _passive_arg
		rider.auto_lane = _lane_arg
		if _game_time != GAME_TIME:
			_start_run()
		else:
			pc.start()
	# Das Spiel beginnt mit dem Startbildschirm (Testläufe gehen direkt ins Spiel)
	if not _screen_arg and not _no_screen and not _test_log and _shot_path == "" and _view_arg.is_empty() and _closeup == Vector3.INF:
		_screen_arg = true
	if _screen_arg:
		_open_start_screen()
		if _screen_select != "":
			start_screen.select_by_name(_screen_select)
		if _shot_path != "":
			get_tree().create_timer(_shot_time, true).timeout.connect(_take_shot)


# ---------------------------------------------------------------- Startbildschirm

func _build_start_screen() -> void:
	start_screen = StartScreen.new()
	start_screen.features = features
	start_screen.weather = weather
	start_screen.cable_of = {"T1": cable_t1, "T2": cable}
	start_screen.s_offset = _s_offset()
	start_screen.mobile = mobile.active
	start_screen.settings = settings
	var names: Array = []
	for e: Dictionary in _setups:
		names.append(e["name"])
	start_screen.build(TERMINALS, ["T2 (Strand, große Hütte)", "T1 (Lounge-Steg)"], names)
	start_screen.visible = false
	add_child(start_screen)
	start_screen.terminal_chosen.connect(func(t: String) -> void:
		_reset()
		_select_terminal(t)
		pc.start()
		start_screen.refresh(terminal, _setup_idx))
	start_screen.setup_chosen.connect(func(i: int) -> void:
		_reset()
		_select_setup(i)
		pc.start()
		start_screen.refresh(terminal, _setup_idx))
	start_screen.start_pressed.connect(_close_start_screen)


## Startbildschirm zeigen. Die Bahn läuft live weiter: auf der eigenen Anlage fährt der
## Autopilot (wie der NPC auf der anderen), die Spielkamera wird so lange nicht gerendert.
var _autopilot_before := false

func _open_start_screen() -> void:
	_session = false
	_finishing = false
	_reset()
	start_screen.set_result(_last_result)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	start_screen.activate()
	mobile.ui_mode = true        # Finger bedienen die Startseite (Tippen = Maus)
	_autopilot_before = rider.autopilot
	rider.autopilot = true
	pc.start()
	start_screen.visible = true
	start_screen.refresh(terminal, _setup_idx)
	if touch_pad:
		mobile.release_pad()
		touch_pad.close_menu()
		touch_pad.visible = false


func _close_start_screen() -> void:
	start_screen.visible = false
	hud.visible = true
	if touch_pad:
		touch_pad.visible = true
	mobile.ui_mode = false
	cam.current = true
	rider.autopilot = _autopilot_before
	_reset()
	cam.snap()


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


## Seillänge und Tempo gelten für die eigene Anlage; der NPC fährt mit Standardwerten.
func _apply_anlage() -> void:
	rider.rope_length = float(settings.get_v("rope"))
	pc.max_speed = float(settings.get_v("speed")) / 3.6
	npc.rope_length = Rider.ROPE_LENGTH
	nc.max_speed = 30.0 / 3.6


## Eine Einstellung anwenden (beim Start alle, danach bei jeder Änderung).
func _apply_setting(key: String) -> void:
	var v: Variant = settings.get_v(key)
	match key:
		"mode":
			if not _test_log:           # Tests: --game-time bzw. Standard
				_free = int(v) == 0
				_game_time = float(v) if not _free else 0.0
				if not _session:
					_time_left = _game_time
		"board":
			rider.set_board(int(v))
		"goofy":
			rider.goofy = bool(v)
		"helmet":
			rider.set_helmet(int(v))
		"vest":
			rider.set_vest(GameSettings.VESTS[clampi(int(v), 0, GameSettings.VESTS.size() - 1)])
		"assist_lock", "assist_flip":
			rider.assist_lock = bool(settings.get_v("assist_lock"))
			rider.assist_flip = bool(settings.get_v("assist_flip"))
			rider.trick_bonus = settings.trick_bonus()
		"grip":
			rider.crash_tension = GameSettings.GRIP_TENSION[clampi(int(v), 0, 2)]
		"rope", "speed":
			_apply_anlage()
		"planes":
			airplanes.rate = int(v)
		"npc":
			_set_npc(bool(v))
		"vol_fx":
			Sfx.set_volume(Sfx.BUS_FX, float(v))
		"vol_cheer":
			Sfx.set_volume(Sfx.BUS_CHEER, float(v))
		"vol_planes":
			Sfx.set_volume(Sfx.BUS_PLANES, float(v))
		"quality":
			_apply_quality(int(v))
		"tilt":
			mobile.max_tilt = GameSettings.TILT_DEG[clampi(int(v), 0, 2)]
		"tilt_invert":
			mobile.invert = bool(v)
		"cam_mode":
			cam.set_mode(int(v))
		"cam_dist":
			cam.distance = float(v)


## NPC auf der anderen Anlage an/aus.
func _set_npc(on: bool) -> void:
	if on == _npc_on:
		return
	_npc_on = on
	npc.visible = on
	if on:
		npc.reset()
		nc.reset()
		nc.start()
	else:
		nc.reset()


## Grafikqualität: Auflösung der 3D-Szene, Schatten, Baumdichte, Kantenglättung.
func _apply_quality(q: int) -> void:
	q = clampi(q, 0, 2)
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, _msaa_default][q]
	weather.shadow_distance = [0.0, 110.0, 200.0][q]
	weather.apply()
	if terrain:
		terrain.set_tree_density([0.35, 0.7, 1.0][q])


func _apply_terminal(t: String) -> void:
	terminal = t
	var other := "T1" if t == "T2" else "T2"
	pc = cable if t == "T2" else cable_t1
	nc = cable_t1 if t == "T2" else cable
	_place_rider(rider, pc, _start[t])
	_place_rider(npc, nc, _start[other])
	_apply_anlage()
	_terminal_menu.select(TERMINALS.find(t))
	# Jubel kommt aus dem Startblock der eigenen Anlage
	sfx.set_people(beach.people if t == "T2" else beach.people_t1)
	sfx.operator = ambient.operator(t)
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

## Alle Features stehen so viel weiter draußen als in den Setup-Dateien (mehr Platz zur Ufer-Wende).
const FEATURE_SHIFT := 10.0

## Die Setups sind ab dem T2-Startsteg gemessen. Der T1-Steg liegt weiter draußen am Seil –
## dort rücken die Teile um den Unterschied nach hinten (gleicher Anlauf auf beiden Anlagen).
func _s_offset() -> Dictionary:
	return {"T2": FEATURE_SHIFT,
		"T1": FEATURE_SHIFT + (cable.start_z - cable_t1.start_z) - (cable.mast_a_z - cable_t1.mast_a_z)}


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
	if start_screen.visible:
		return
	if pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED:
		_start_run()
		_touch_started = true
	else:
		Input.action_press("jump")


## Menü der virtuellen Tasten (Handy).
func _on_pad_menu(id: String) -> void:
	match id:
		"help":
			hud.toggle_help()
		"reset":
			if _finishing:
				_end_session()
			else:
				_penalty(RESET_PENALTY)
			_reset()
		"home":
			_open_start_screen()
		"mute":
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


## Finger weg: Absprung (falls geladen).
func _on_touch_up() -> void:
	if start_screen.visible:
		return
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
	if _npc_on:
		nc.step(delta, nc.local_vz(npc.vel) if npc.attached else 0.0, npc.rope_slack())
		npc.step(delta)
		_check_buoy(npc)
		_recover(npc, nc, delta)
	rider.step(delta)
	if not is_nan(_load_arg):
		rider._load = _load_arg            # Test: Sprung so weit aufgeladen (nur Haltung)
	_check_buoy(rider)
	_track_turn()
	_recover(rider, pc, delta)

	_step_session(delta)
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
	if _letgo_at > 0.0 and _elapsed >= _letgo_at:
		_letgo_at = -1.0
		rider.let_go("Test: Seil verloren")
	if _jump_at > 0.0 and _elapsed >= _jump_at and rider.mode == Rider.Mode.WATER:
		_jump_at = -1.0
		rider.test_jump()
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


# ---------------------------------------------------------------- Spielzeit

## Start vom Steg: eine neue Runde beginnt (Punkte auf 0, volle Zeit).
func _start_run() -> void:
	if not _session:
		_session = true
		_finishing = false
		_time_left = _game_time
		rider.score = 0
	pc.start()


## Freies Fahren: die Uhr zählt hoch, es gibt kein Zeitende und keine Strafzeit.
func _free_ride() -> bool:
	return _free and not _test_log


func _step_session(delta: float) -> void:
	if not _session or start_screen.visible:
		return
	if _free_ride():
		_time_left += delta
	elif not _finishing:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_up()
	elif pc.state == CableSystem.State.DONE or pc.state == CableSystem.State.IDLE:
		_end_session()


func _penalty(sec: float) -> void:
	if not _session or _finishing or _free_ride():
		return
	_time_left -= sec
	hud.show_trick("Strafzeit −%d:%02d" % [int(sec) / 60, int(sec) % 60])
	if _time_left <= 0.0:
		_time_up()


## Zeit um: die Punkte stehen fest, der Operator bringt den Fahrer zum Start.
func _time_up() -> void:
	if _test_log:
		print("ZEIT UM at t=%.1f score=%d" % [_elapsed, rider.score])
	_time_left = 0.0
	_finishing = true
	_final_score = rider.score
	pc.finish()
	hud.show_trick("Zeit um!  %d Punkte" % _final_score)


func _end_session() -> void:
	if _test_log:
		print("RUNDE ENDE at t=%.1f" % _elapsed)
	_session = false
	_finishing = false
	_last_result = "Letzte Runde: %d Punkte" % _final_score
	hud.show_trick("Ende!  %d Punkte" % _final_score)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not start_screen.visible:
			_open_start_screen())


static func _clock(sec: float) -> String:
	var s := maxi(ceili(sec), 0)
	return "%d:%02d" % [s / 60, s % 60]


## Bergung (2-Mast-Prinzip, niemand muss zurück zum Start): Wer die Handle verloren hat,
## bekommt sie vom Operator auf seine Höhe gebracht und schwimmt hin (siehe Rider._swim).
## Nur wer an Land oder im Steg gelandet ist (oder ewig nicht hinkommt), startet neu am Steg.
var _lost_t := {}

func _recover(r: Rider, c: CableSystem, delta: float) -> void:
	var id := r.get_instance_id()
	if r.attached:
		_lost_t[id] = 0.0
		return
	var t: float = _lost_t.get(id, 0.0) + delta
	_lost_t[id] = t
	var stranded := not Lake.in_lake(r.pos.x, r.pos.z, 0.0) or r.in_dock(r.pos.x, r.pos.z)
	if (stranded and t > RESET_DELAY) or t > 120.0:
		_lost_t[id] = 0.0
		if r == rider:
			_reset()
			if _test_log or start_screen.visible:
				pc.start()
		else:
			r.reset()
			c.reset()
			c.start()
		return
	if not stranded:
		c.fetch((c.transform.affine_inverse() * r.pos).z)


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
	var state := Hud.TimeState.IDLE
	if _finishing:
		state = Hud.TimeState.OVER
	elif _session:
		state = Hud.TimeState.LOW if _time_left < 60.0 and not _free_ride() else Hud.TimeState.RUNNING
	hud.set_stats(_clock(_time_left if _session else _game_time), state,
		_final_score if _finishing else rider.score, rider.tension_smooth, rider.tension_smooth / rider.crash_tension)
	hud.set_debug("Fahrer %d km/h   ·   Anlage %s: %s (Tempo %d km/h)\nWenden %d   ·   Kamera: %s%s" % [
		roundi(rider.horizontal_speed() * 3.6), terminal, pc.state_text(), roundi(pc.max_speed * 3.6),
		pc.laps, cam.mode_name(), "   ·   AUTOPILOT" if rider.autopilot else ""])
	hud.set_board(rider.board_state_text())
	# Terminal/Setup wählt man am Handy nur auf der Startseite
	hud.show_setup_menu(pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED and not mobile.active)
	if not rider.attached:
		var skip := "Tippen: sofort weiterfahren" if mobile.active \
			else "↑ halten: zur Handle schwimmen     Leertaste: sofort weiterfahren\n(R = zurück zum Steg)"
		if pc.state == CableSystem.State.HOLD:
			hud.set_center(skip)
		elif pc.state == CableSystem.State.FETCH:
			hud.set_center("Der Operator bringt dir die Handle …\n" + skip)
		else:
			hud.set_center("")
	elif rider.mode != Rider.Mode.CRASHED:
		if pc.state == CableSystem.State.IDLE:
			hud.set_center("Tippen zum Starten" if mobile.active else "LEERTASTE drücken zum Starten")
		elif mobile.active and not mobile.tilt_available:
			hud.set_center("Neigungssensor nicht verfügbar –\nBewegungssensoren im Browser erlauben")
		else:
			hud.set_center("")

	if _shot_path != "" and not _shot_taken and _elapsed >= _shot_time:
		_take_shot()


func _take_shot() -> void:
	if _shot_taken:
		return
	_shot_taken = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	print("screenshot saved: ", _shot_path)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start"):
		if pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED:
			_start_run()
			rider.block_jump()
	elif event.is_action_pressed("reset"):
		if _finishing:
			_end_session()
		else:
			_penalty(RESET_PENALTY)
		_reset()
	elif event.is_action_pressed("speed_up") or event.is_action_pressed("speed_down"):
		pc.change_speed(2.0 if event.is_action_pressed("speed_up") else -2.0)
		settings.set_v("speed", float(roundi(pc.max_speed * 3.6)))
		start_screen.sync_settings()
	elif event.is_action_pressed("camera"):
		cam.cycle_mode()
	elif event.is_action_pressed("autopilot"):
		rider.autopilot = not rider.autopilot
	elif event.is_action_pressed("help"):
		hud.toggle_help()
	elif event.is_action_pressed("overview"):
		_open_start_screen()


## Wertet eine Wende aus: beginnt, wenn der Carrier zur Wende bremst, endet, wenn er
## wieder auf Tempo geht. Punkte nur, wenn man nicht abgesoffen ist (Rider.sank);
## Bonus, wenn man außen um eine der weißen Bojen herumgefahren ist.
func _track_turn() -> void:
	if pc.state == CableSystem.State.BRAKE and not _turn_active and rider.attached and rider.mode != Rider.Mode.CRASHED:
		_turn_active = true
		_turn_end = 1.0 if pc.dir < 0.0 else -1.0
		_turn_sank = false
		_turn_around = false
	if not _turn_active:
		return
	if rider.mode == Rider.Mode.CRASHED or not rider.attached:
		_turn_active = false
		return
	var local := pc.transform.affine_inverse() * rider.pos
	var s := pc.mast_a_z - local.z
	var s_turn := pc.mast_a_z - (pc.turn_b_z if _turn_end > 0.0 else pc.turn_a_z)
	var s_white := s_turn - _turn_end * TurnBuoys.WHITE_BEFORE
	if (s - s_white) * _turn_end > 0.0 and absf(local.x) > TurnBuoys.WHITE_SIDE - 0.5:
		_turn_around = true
	if pc.state == CableSystem.State.RUN:
		_turn_active = false
		if not _turn_sank:
			rider.award("Wende um die Boje" if _turn_around else "Saubere Wende", 30 if _turn_around else 15)
		elif _test_log:
			print("WENDE abgesoffen – keine Punkte")


func _reset() -> void:
	_turn_active = false
	rider.reset()
	pc.reset()
	water.clear_wake()
	_crash_t = 0.0


func _on_crashed(reason: String) -> void:
	hud.show_trick(reason)
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
	# ↑/↓: in der Luft Frontroll/Backroll, auf dem Slider Nose-/Tailpress, nach Sturz ↑ = schwimmen
	_bind("pitch_front", [KEY_UP, KEY_W], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("pitch_back", [KEY_DOWN, KEY_S], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	# Strg (zur Not Alt): Kante lösen = Driften
	_bind("release", [KEY_CTRL, KEY_ALT], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_bind("start", [KEY_SPACE], [JOY_BUTTON_START], [])
	_bind("reset", [KEY_R], [JOY_BUTTON_BACK], [])
	_bind("speed_up", [KEY_PAGEUP], [JOY_BUTTON_DPAD_UP], [], [KEY_PLUS, KEY_KP_ADD])
	_bind("speed_down", [KEY_PAGEDOWN], [JOY_BUTTON_DPAD_DOWN], [], [KEY_MINUS, KEY_KP_SUBTRACT])
	_bind("camera", [KEY_C], [JOY_BUTTON_Y], [])
	_bind("autopilot", [KEY_P], [], [])
	_bind("help", [KEY_H, KEY_F1], [], [])
	_bind("mute", [KEY_M], [], [])
	_bind("overview", [KEY_TAB], [], [])
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
		elif arg.begins_with("--pitch="):
			_test_pitch = arg.substr(8).to_float()
		elif arg.begins_with("--set="):
			_set_args.append(arg.substr(6))
		elif arg.begins_with("--jump-at="):
			_jump_at = arg.substr(10).to_float()
		elif arg.begins_with("--letgo-at="):
			_letgo_at = arg.substr(11).to_float()
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
		elif arg.begins_with("--game-time="):
			_game_time = arg.substr(12).to_float()
		elif arg.begins_with("--weather="):
			_weather_arg = arg.substr(10)
		elif arg.begins_with("--hour="):
			_hour_arg = arg.substr(7).to_float()
		elif arg.begins_with("--day="):
			_day_arg = arg.substr(6).to_int()
		elif arg.begins_with("--plane="):
			_plane_arg = arg.substr(8).to_float()
		elif arg.begins_with("--load="):
			_load_arg = arg.substr(7).to_float()
		elif arg == "--passive":
			_passive_arg = true
		elif arg == "--no-screen":
			_no_screen = true
		elif arg == "--screen" or arg.begins_with("--screen="):
			_screen_arg = true
			_screen_select = arg.substr(9) if arg.length() > 9 else ""
		elif arg.begins_with("--cam="):
			_cam_arg = arg.substr(6)


# ---------------------------------------------------------------- Welt

func _build_environment() -> void:
	# Wetter, Jahreszeit und Uhrzeit (Sonnenstand aus der echten Lage des Sees, siehe Weather)
	Geo.ensure_loaded()
	weather = Weather.new()
	add_child(weather)
	# Jeder Start: Sommertag 10:30, sonnig (nie Nacht). Änderungen in den Einstellungen gelten
	# nur für diese Sitzung; "Jetzt" holt bei Bedarf die echte Uhrzeit und das Wetter.
	weather.preset = weather.find_preset("sonnig")
	weather.day = 172
	weather.hour = 10.5
	weather.live = false
	if _weather_arg != "":
		weather.preset = weather.find_preset(_weather_arg)
	if not is_nan(_hour_arg):
		weather.hour = _hour_arg
		weather.live = false
	if _day_arg > 0:
		weather.day = _day_arg
		weather.live = false
	weather.apply()

