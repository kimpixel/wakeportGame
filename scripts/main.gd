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
##   --screen[=NAME]   Startbildschirm erzwingen (NAME: Feature/Hack auswählen, z. B. "hack";
##                     @liste, @einstellungenN, @erfolge, @rangliste, @auswahl[2] = Modus- bzw. Challenge-Liste offen, @editor = Setup-Editor);
##                     normal beginnt das Spiel damit, außer bei --autotest/--shot/--view/--closeup
##   --letgo-at=SEK    Test: Seil zu dieser Zeit verlieren (ohne Sturz)
##   --jump-at=SEK     Test: zu dieser Zeit voll aufgeladen abspringen
##   --hold=AKT@T0-T1,…  Test: Eingabe-Aktion (z. B. release, steer_right) von T0 bis T1 s halten
##   --pitch=±1        Test: in der Luft ↑ (+1, Frontroll; Invert: S-Bend) bzw. ↓ (-1, Backroll) halten
##   --game-time=SEK   Test: Spielzeit (normal 450 s); im Autotest läuft dann eine Runde mit Zeit
##   --scenario=ID     Szenario (Weather.SCENARIOS, z. B. nacht, earlybird, regenbogen, nikolaus); ohne Argumente
##                     würfelt jeder Start eins aus, Tests nehmen sonst "afterhour" (18. August 19:45, sonnig)
##   --weather=ID      Wetter (sonnig, heiter, bewoelkt, bedeckt, schauer, regen, dunst, schnee)
##   --hour=H --day=T  Uhrzeit (deutsche Zeit) und Tag im Jahr
##   --plane=S[,nah|weit[,start|landung]] Test: sofort ein Jet, S m vor dem See (negativ) bzw. danach; nah = tief über dem See
##   --pike-at=SEK     Test: zu dieser Zeit springt der Hecht knapp vor dem Fahrer (Erfolg "fisch")
##   --sup-at=SEK      Test: ein SUP aus der Seemitte kommt herüber, das rote Boot vertreibt ihn
##   --drop-at=S[,x,y,z|,boot]  Test: Fahrer zu dieser Zeit in die Luft setzen (Standard: über den Startsteg, Erfolg "steg";
##                     boot = über das rote Boot am Liegeplatz, Erfolg "boot")
##   --erfolg=ID,…     Test: geheime Erfolge als erreicht zeigen (z. B. --screen=@erfolge --erfolg=fisch)
##   --lb-url=URL      Test: Rangliste über diesen Worker (z. B. lokal http://127.0.0.1:8787), --lb-name=NAME
##   --dpress=W        Test: Drift-Press fest zeigen (-1 Tailpress … +1 Nosepress), auch ohne Drift
##   --passive         Test (mit --autotest): Fahrer ohne Autopilot und ohne Eingaben
##   --no-screen       ohne Startbildschirm direkt ins Spiel
##   --pause-at=SEK    Test: zu dieser Zeit pausieren (mit --shot: Bild der Pause)
##   --settings-at=SEK Test: zu dieser Zeit pausieren und die Einstellungen im Spiel öffnen (mit --shot: Bild davon)
##   --debug-params    Debug-Overlay (Parameter-Regler, im Spiel F4) gleich offen
##   --hitbox          Fangzonen der Slider zeigen (im Spiel: F3)
##   --set=NAME=WERT   Test: Einstellung setzen (ohne zu speichern), z. B. --set=goofy=true
##   --music=DATEI[,…] Test: Musik aus diesen Dateien (nichts kopiert; eigene Titel werden im Test nie gespielt)
##   --mode=ID[:N]     Spielmodus (wende, kicker, slider, raley, sprungstart, drift, transfer) mit Aufgabe N (ab 1) direkt starten;
##                     mit --go=SEK: Aufgaben-Fenster zu dieser Zeit bestätigen; --mode-auto: Autopilot fährt

const RESET_DELAY := 3.0

# Spielregeln: eine Runde dauert 7:30, es zählen die Punkte in dieser Zeit. Danach wird man
# nur noch zum Start gebracht. Abkürzungen kosten Zeit.
const GAME_TIME := 450.0
const SKIP_PENALTY := 60.0      # Strg nach Sturz: Schwimmen abbrechen, Handle sofort da
const RESET_PENALTY := 120.0    # R: zurück zum Startsteg
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
var pause_menu: PauseMenu
var debug_params: DebugParams   # F4, nur lokal (null in der Web-Version)
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
var _grip_on := 1               # Seilzug-Grenze „An“ (GameSettings.GRIP_TENSION), zu der G zurückschaltet
var _swum := false              # seit dem Sturz schon geschwommen (Panel aus)
var _msaa_default := Viewport.MSAA_DISABLED
var _touch_started := false     # dieser Finger hat die Anlage gestartet (kein Sprung)
# Spielmodi (Training): Competition = Runde auf Zeit, sonst Aufgaben mit Medaillen (Challenge)
var game_mode := Training.COMPETITION
var _task_idx := 0
var challenge: Challenge
var task_panel: TaskPanel
var _comp_terminal := ""        # Terminal der Competition (Aufgaben laufen auf Terminal 2)
var _counting := false          # Countdown läuft (Competition)
var _round_over := false        # Runde zu Ende, gleich kommt die Startseite: kein neuer Countdown
var _mode_arg := ""
var _go_at := -1.0
var mode_auto := false           # Test: im Spielmodus fährt der Autopilot (--mode-auto)

## Welche Anlage fährt der Spieler? Der NPC fährt immer an der anderen.
const TERMINALS := ["T1", "T2"]
const TERMINAL_NAMES := ["Terminal 1", "Terminal 2"]
var terminal := "T2"
var pc: CableSystem              # Anlage des Spielers
var nc: CableSystem              # Anlage des NPC
var _terminal_menu: OptionButton
var _terminal_arg := ""
var _start := {}                 # "T1"/"T2" -> {pos, yaw, dock, mast_b}
var sfx: Sfx
var ambient: Ambient
var wildlife: Wildlife
var bathers: Bathers
var storm: Storm
var film: FilmCrew                 # Filmteam der Challenges (rotes Boot oder FPV-Drohne)
var weather: Weather
var airplanes: Airplanes
var music: Music
var leaderboard: Leaderboard     # Online-Rangliste (Challenges, Competition)
var _plane_arg := NAN
var _plane_near := -1
var _plane_land := -1
var _load_arg := NAN
var _passive_arg := false       # Test: Fahrer ohne Autopilot, ohne Eingaben
var _weather_arg := ""
var _scenario_arg := ""
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
var _pike_at := -1.0           # Test: Hecht springt zu dieser Zeit knapp vor dem Fahrer
var _sup_at := -1.0            # Test: ein SUP aus der Seemitte kommt zu dieser Zeit herüber
var _drop_at := -1.0           # Test: Fahrer zu dieser Zeit an _drop_pos in die Luft setzen
var _drop_pos := Vector3.INF   # Test: wohin (INF = über den Startsteg)
var _in_boat := false          # Fahrer ist gerade im roten Boot (Erfolg "boot" nur beim Hineinkommen melden)
var _letgo_at := -1.0          # Test: Seil zu dieser Zeit verlieren
var _pause_at := -1.0           # Test: zu dieser Zeit pausieren (und Screenshot)
var _settings_at := -1.0        # Test: zu dieser Zeit die Einstellungen im Spiel öffnen
var _debug_params_arg := false  # Test: Debug-Overlay gleich offen (--debug-params)
var _hitbox_arg := false        # Test: Fangzonen der Slider zeigen
var _set_args: Array[String] = []   # Test: --set=NAME=WERT
var _music_args := PackedStringArray()   # Test: --music=DATEI[,DATEI]
var _hold: Array = []           # Test: [Aktion, von, bis] (--hold)
var _jump_at := -1.0           # Test: zu dieser Zeit abspringen
var _peak_y := 0.0             # Test-Ausgabe: größte Höhe des laufenden Sprungs
var _test_dpress := INF       # Test: Drift-Press fest (--dpress)
var _test_pitch := 0.0         # Test: ↑/↓ in der Luft
var _touch_at: Array[float] = []   # Test: Finger auf den Bildschirm
var _closeup := Vector3.INF     # Testkamera relativ zum Fahrer
var _closeup_look := Vector3(0, 1.1, 0)   # Blickpunkt relativ zum Fahrer (optional 4.-6. Wert)
var _elapsed := 0.0
var _log_t := 0.0


func _ready() -> void:
	_setup_input()
	_parse_args()
	Analytics.init()                         # Nutzungsstatistik (nur Web-Hauptversion)
	_build_environment()
	Geo.ensure_loaded()
	terrain = Terrain.new()
	add_child(terrain)
	beach = Beach.new()
	add_child(beach)

	water = Water.new()
	add_child(water)
	water.sun = weather.sun
	water.env = weather.env
	cable = CableSystem.new()
	add_child(cable)
	cable.turn_a_z = -28.0          # Ufer-Wende T2: 6 m weiter draußen (mehr Abstand zum Ufer)
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
	rider.test_dpress = _test_dpress
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
	features.reflections = int(settings.values["quality"]) >= 1
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
	rider.jumped.connect(func(info: Dictionary) -> void:
		_peak_y = rider.pos.y
		if _test_log:
			print("ABSPRUNG %s: Seilzug %d N, %.1f km/h, Ladung %.2f, vy %.2f m/s" % [
				"RALEY" if info["raley"] else "Ollie", roundi(info["tension"]), info["speed"] * 3.6, info["load"], info["vy"]]))
	rider.jump_landed.connect(func(info: Dictionary) -> void:
		if _test_log:
			print("FLUG %s: %.2f s, Höhe %.2f m" % [info["name"], info["air_time"], _peak_y]))
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
	_terminal_menu = hud.add_menu_choice("Terminal", TERMINAL_NAMES, 0, _on_terminal_menu)
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
		touch_pad.process_mode = Node.PROCESS_MODE_ALWAYS     # Menü bedienbar, auch während der Pause
		mobile.process_mode = Node.PROCESS_MODE_ALWAYS
		touch_pad.hud = hud
		add_child(touch_pad)
		mobile.pad = touch_pad
		touch_pad.menu_action.connect(_on_pad_menu)
		touch_pad.menu_toggled.connect(func(open: bool) -> void: get_tree().paused = open)
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
	# Tiere je nach Jahreszeit und Badegäste an heißen Tagen (folgen dem Wetter/Szenario)
	wildlife = Wildlife.new()
	wildlife.water = water
	wildlife.features = features
	wildlife.player = rider
	add_child(wildlife)
	wildlife.build()
	bathers = Bathers.new()
	bathers.water = water
	bathers.features = features
	bathers.player = rider
	add_child(bathers)
	storm = Storm.new()                       # Szenario Gewitter: Blitze (ganz selten ein Volltreffer)
	storm.weather = weather
	storm.sfx = sfx
	storm.water = water
	storm.player = rider
	add_child(storm)
	var season := func() -> void:
		ambient.apply_season(weather)
		wildlife.apply_season(weather)
		bathers.apply_season(weather)
		storm.apply_season(weather)
	weather.changed.connect(season)
	season.call()
	wildlife.grebe_sneaked.connect(func() -> void:
		hud.show_trick("Was ein Frechdachs!")
		_unlock_achievement("frechdachs"))
	wildlife.swans_love.connect(func() -> void:
		hud.show_trick("Schwanenliebe")
		_unlock_achievement("schwanenliebe"))
	storm.struck.connect(func() -> void:
		_unlock_achievement("blitz"))
	bathers.splashed.connect(func() -> void:
		hud.show_trick("Badegast nass gespritzt!")
		_unlock_achievement("badegast"))
	rider.jumped.connect(func(info: Dictionary) -> void:
		if info.get("raley", false) and wildlife.cranes_overhead():
			hud.show_trick("Zugvogel!")
			_unlock_achievement("zugvogel"))
	film = FilmCrew.new()
	film.game = self
	add_child(film)
	film.build()
	film.cam.mobile = mobile.active      # Handy: kein Livebild links
	# Einflugschneise Frankfurt: Jets im Landeanflug über dem See
	airplanes = Airplanes.new()
	airplanes.jet_sound = sfx.make_jet_loop()
	add_child(airplanes)
	if not is_nan(_plane_arg):
		airplanes.spawn_at(_plane_arg, _plane_near, _plane_land)
	cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_IDLE_STEP
	ambient.pike_hit.connect(func() -> void:
		hud.show_trick("Hecht erwischt!")
		_unlock_achievement("fisch"))
	# SUP aus der Seemitte zu nah an der Bahn: rotes Boot fährt raus und schickt ihn zurück
	ambient.sup_intruding.connect(film.chase)
	film.sup_chased.connect(ambient.send_back)
	ambient.sup_splashed.connect(func() -> void:
		hud.show_trick("SUP nass gespritzt!")
		_unlock_achievement("sup"))
	ambient.insect_eaten.connect(func() -> void:
		hud.show_trick("Igitt – Insekt verschluckt!")
		_unlock_achievement("insekt"))
	rider.landed_on_dock.connect(func() -> void:
		hud.show_trick("Steg-Landung!")
		_unlock_achievement("steg"))
	if not _test_log:
		settings.load_file(mobile.active)     # Tests laufen immer mit Standardwerten
	if OS.get_cmdline_user_args().is_empty() and str(settings.get_v("scenario")) != "":
		weather.set_scenario(str(settings.get_v("scenario")))   # fest gewähltes Szenario
	# eigene Musik des Spielers (an/aus kommt mit den Einstellungen)
	music = Music.new()
	music.enabled = false
	music.no_save = not OS.get_cmdline_user_args().is_empty()   # Tests: keine eigenen Titel, nichts kopieren
	add_child(music)
	if not _music_args.is_empty():
		music.add_paths(_music_args)
	leaderboard = Leaderboard.new()
	add_child(leaderboard)
	_apply_terminal(_initial_terminal())
	_build_start_screen()
	# Pause (Esc): Spiel anhalten, Fenster mit Weiter / Hilfe / Startseite
	pause_menu = PauseMenu.new()
	pause_menu.music = music
	pause_menu.can_pause = func() -> bool: return not start_screen.visible and hud.visible 		and not task_panel.is_open() and not hud._count.visible
	pause_menu.help_pressed.connect(hud.toggle_help)
	pause_menu.settings_pressed.connect(_open_settings_ingame.bind("pause"))
	start_screen.ingame_closed.connect(_close_settings_ingame)
	pause_menu.home_pressed.connect(_open_start_screen)
	add_child(pause_menu)
	# Debug-Overlay (F4, nur lokal): Parameter live mit Schiebereglern justieren
	if DebugParams.available():
		debug_params = DebugParams.new()
		debug_params.rider = rider
		add_child(debug_params)
		if _debug_params_arg:
			debug_params.toggle()
	# unten rechts: Build-Version (Web) bzw. Git-Branch (lokal) – welche Version/welcher Checkout läuft
	var branch_label: GDScript = preload("res://scripts/ui/branch_label.gd")
	if branch_label.available():
		add_child(branch_label.new())
		hud._debug.offset_bottom -= branch_label.HEIGHT
	# Spielmodi: Aufgaben-Fenster und Ablauf
	task_panel = TaskPanel.new()
	task_panel.mobile = mobile.active
	task_panel.open_changed = func(open: bool) -> void:
		mobile.ui_mode = open or start_screen.visible
		if touch_pad:
			mobile.release_pad()
			touch_pad.visible = not open and not start_screen.visible
	add_child(task_panel)
	challenge = Challenge.new()
	challenge.game = self
	challenge.panel = task_panel
	challenge.home_requested.connect(_open_start_screen)
	add_child(challenge)
	# Menüs mit Tastatur/Gamepad bedienen (Fokus wandern, Knopf drücken)
	var nav := MenuNav.new()
	nav.touch = mobile.active
	add_child(nav)
	# Gamepad: Vibration und Lichtleiste (Farbe des Seilzugs)
	var pad_fx := PadFx.new()
	pad_fx.rider = rider
	pad_fx.active = func() -> bool: return not start_screen.visible and not get_tree().paused
	add_child(pad_fx)
	if _quit_after > 0.0 and _mode_arg != "":   # Spielmodi stehen im Ergebnis-Fenster: Zeit inkl. Pause
		get_tree().create_timer(_quit_after + 3.0, true).timeout.connect(get_tree().quit)
	if _shot_path != "" and _mode_arg != "" and not _screen_arg:   # Spielmodus steht im Fenster: Zeit inkl. Pause
		get_tree().create_timer(_shot_time, true).timeout.connect(_take_shot)
	if _go_at > 0.0:                         # Test: Aufgaben-Fenster bestätigen (läuft auch in der Pause)
		get_tree().create_timer(_go_at, true).timeout.connect(func() -> void:
			if task_panel.is_open():
				task_panel.go_pressed.emit())
	_msaa_default = get_viewport().msaa_3d
	settings.changed.connect(_apply_setting)
	if _hitbox_arg:
		features.show_hitboxes = true
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
	if not _screen_arg and not _no_screen and not _test_log and _shot_path == "" and _view_arg.is_empty() and _closeup == Vector3.INF and _mode_arg == "":
		_screen_arg = true
	if _mode_arg == "":
		_recall_game()                     # zuletzt gespieltes Spiel auf der Startseite vorauswählen
	if _mode_arg != "":
		var mi := _mode_arg.split(":")
		game_mode = mi[0]
		_task_idx = (mi[1].to_int() - 1) if mi.size() > 1 else 0
		if not _screen_arg:
			_enter_training()
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
	start_screen.music = music
	start_screen.leaderboard = leaderboard
	var names: Array = []
	for e: Dictionary in _setups:
		names.append(e["name"])
	start_screen.build(TERMINALS, TERMINAL_NAMES, names)
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
	start_screen.start_pressed.connect(_on_start_pressed)
	start_screen.mode_chosen.connect(func(id: String) -> void:
		game_mode = id
		_task_idx = 0
		start_screen.refresh_mode(game_mode, _task_idx))
	start_screen.task_chosen.connect(func(i: int) -> void:
		_task_idx = i
		start_screen.refresh_mode(game_mode, _task_idx))
	start_screen.setups_changed.connect(_on_setups_changed)


## Setup-Editor hat ein eigenes Setup gespeichert (bzw. gelöscht): Listen neu laden, das
## gespeicherte Setup aufbauen; "Speichern & Fahren" startet gleich das Spiel.
func _on_setups_changed(id: String, play: bool) -> void:
	var cur: String = _setups[_setup_idx]["id"]
	_setups = FeatureSet.list_setups()
	var names: Array = []
	_setup_menu.clear()
	for e: Dictionary in _setups:
		names.append(e["name"])
		_setup_menu.add_item(e["name"])
	start_screen.set_setup_names(names)
	var idx := -1
	for want: String in [id, cur]:
		for i in _setups.size():
			if idx < 0 and _setups[i]["id"] == want:
				idx = i
	_reset()
	_select_setup(maxi(idx, 0), true)
	if play:
		_close_start_screen()
	else:
		pc.start()
		start_screen.refresh(terminal, _setup_idx)


## Startbildschirm zeigen. Die Bahn läuft live weiter: auf der eigenen Anlage fährt der
## Autopilot (wie der NPC auf der anderen), die Spielkamera wird so lange nicht gerendert.
var _autopilot_before := false

func _open_start_screen() -> void:
	get_tree().paused = false
	_round_over = false
	_leave_training()
	_session = false
	_finishing = false
	_reset()
	start_screen.set_result(_last_result)
	_roll_scenario()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.visible = false
	start_screen.activate()
	mobile.ui_mode = true        # Finger bedienen die Startseite (Tippen = Maus)
	_autopilot_before = rider.autopilot
	rider.autopilot = true
	pc.start()
	start_screen.visible = true
	start_screen.refresh(terminal, _setup_idx)
	start_screen.refresh_mode(game_mode, _task_idx)
	if touch_pad:
		mobile.release_pad()
		touch_pad.close_menu()
		touch_pad.visible = false


## Szenario "Zufällig" (Standard): nach jedem Spiel ein neues würfeln, sobald die Startseite aufgeht – so zeigt
## sie schon das nächste, und jeder Start (Competition/Challenge) sieht anders aus. R/Neustart würfelt nicht.
## Von Hand eingestelltes Wetter (weather.scenario leer) bleibt; Tests würfeln nie.
func _roll_scenario() -> void:
	if not OS.get_cmdline_user_args().is_empty() or weather.scenario == "":
		return
	var fixed := str(settings.get_v("scenario"))
	if fixed == "":
		weather.set_scenario(Weather.random_scenario(weather.scenario))
	elif fixed != weather.scenario:
		weather.set_scenario(fixed)


## Im Spiel neues Szenario würfeln (Z, Touchpad, ☰-Menü): stellt auf Zufällig und zeigt den Namen.
func _shuffle_scenario() -> void:
	settings.set_v("scenario", "")
	weather.set_scenario(Weather.random_scenario(weather.scenario))
	start_screen.sync_settings()
	hud.show_trick(weather.scenario_name())


## "Spiel starten": Competition beginnt direkt mit Countdown, die Spielmodi mit ihrer Aufgabe.
func _on_start_pressed() -> void:
	_remember_game()
	_count_start()
	_close_start_screen()
	if game_mode == Training.COMPETITION:
		_countdown_start()
	else:
		_enter_training()


## Competition: 3 – 2 – 1 – GO, dann fährt die Anlage los (Runde beginnt).
func _countdown_start() -> void:
	if _counting:
		return
	_counting = true
	await Challenge.countdown(hud, get_tree(), false, sfx)
	_counting = false
	if not start_screen.visible and not challenge.active and pc.state == CableSystem.State.IDLE 			and rider.mode != Rider.Mode.CRASHED:
		_start_run()
		rider.block_jump()


## R / ☰ „Zurück zum Steg“ (Competition): Strafzeit, zurück auf den Steg, dann wieder Countdown.
func _reset_to_dock() -> void:
	if _finishing:
		_end_session()
		_reset()
		return
	_penalty(RESET_PENALTY)
	_reset()
	if not _finishing:
		_countdown_start()


## Spielmodus mit Aufgabe starten (immer Terminal 2).
func _enter_training() -> void:
	_session = false
	_finishing = false
	challenge.begin(game_mode, _task_idx)


## Spielmodus: Aufgabe läuft auf dieser Anlage (meist Terminal 2); die Wahl der Competition merken.
func _training_terminal(t: String) -> void:
	if t == terminal:
		return
	if _comp_terminal == "":
		_comp_terminal = terminal
	_apply_terminal(t)


## Zurück aus dem Spielmodus: Setup, Terminal, Seil und Tempo der Competition wiederherstellen.
func _leave_training() -> void:
	if not challenge.active:
		return
	_task_idx = challenge.task_idx
	_remember_game()                         # „Nächste Challenge“ zählt auch
	challenge.stop()
	if _comp_terminal != "":
		if _comp_terminal != terminal:
			_apply_terminal(_comp_terminal)
		_comp_terminal = ""
	features.load_setup(_setups[_setup_idx]["file"], {"T1": cable_t1, "T2": cable}, _s_offset())
	rider.forget_features()
	npc.forget_features()
	_apply_anlage()


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


## Nutzungsstatistik: welches Spiel gestartet wurde (Competition mit Terminal/Setup/Rundenlänge, sonst die Challenge).
func _count_start() -> void:
	if game_mode == Training.COMPETITION:
		var st: Dictionary = _setups[_setup_idx]
		var setup: String = "eigenes" if st.get("user", false) else str(st.get("id", "?"))
		Analytics.count("start/competition/%s/%s/%s" % [terminal, setup, "frei" if _free else "runde"])
	else:
		var list := Training.tasks(game_mode)
		var id: String = list[clampi(_task_idx, 0, list.size() - 1)]["id"] if not list.is_empty() else "?"
		Analytics.count("start/challenge/%s/%s" % [game_mode, id])


# ---------------------------------------------------------------- Letztes Spiel

## Zuletzt gespieltes Spiel (Modus + Challenge) merken – in user://settings.cfg [game]. Tests speichern nichts.
func _remember_game() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		return
	var list := Training.tasks(game_mode)
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("game", "mode", game_mode)
	cfg.set_value("game", "task", list[clampi(_task_idx, 0, list.size() - 1)]["id"] if not list.is_empty() else "")
	cfg.save(SETTINGS)


## Beim Start: zuletzt gespieltes Spiel wieder auswählen (Challenge nach id, falls sich die Liste ändert).
func _recall_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) != OK:
		return
	var mode: String = cfg.get_value("game", "mode", Training.COMPETITION)
	if Training.MODES[Training.mode_index(mode)]["id"] != mode:
		return
	game_mode = mode
	_task_idx = 0
	var id: String = cfg.get_value("game", "task", "")
	var list := Training.tasks(mode)
	for i in list.size():
		if list[i]["id"] == id:
			_task_idx = i


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
			rider.crash_tension = GameSettings.GRIP_TENSION[clampi(int(v), 0, 3)]
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
		"vol_music":
			Sfx.set_volume(Sfx.BUS_MUSIC, float(v))
		"music_src":
			music.set_source(int(v))
		"music":
			music.set_enabled(bool(v))
		"quality":
			_apply_quality(int(v))
		"tilt":
			mobile.max_tilt = GameSettings.TILT_DEG[clampi(int(v), 0, 2)]
		"tilt_invert":
			mobile.invert = bool(v)
		"steer":
			mobile.use_tilt = int(v) == 0
			if touch_pad:
				touch_pad.set_steer_buttons(int(v) == 1)
		"cam_mode":
			cam.set_mode(int(v))
		"cam_dist":
			cam.distance = float(v)
		"w_color":
			water.set_color(int(v))
		"w_ssr":
			# echte Spiegelbilder (Screen-Space Reflections): nur Desktop-Renderer, nur undurchsichtiges Wasser
			weather.env.ssr_enabled = bool(v)
			weather.env.ssr_max_steps = 48
			weather.env.ssr_fade_in = 0.15
			weather.env.ssr_fade_out = 2.0
		"w_detail", "w_fresnel", "w_glitter", "w_crest", "w_foam", "w_sharp", "w_clear":
			water.set_fx(key.substr(2), bool(v))


## Seil-Abreißen an/aus (Taste G, Handy-Menü): "Aus" bzw. zurück zur zuletzt gewählten Grenze.
func _toggle_rope_rip() -> void:
	var off := int(settings.get_v("grip")) == 3
	settings.set_v("grip", _grip_on if off else 3)
	start_screen.sync_settings()
	hud.show_trick("Seil reißt ab: " + ("an" if off else "aus – keine Rangliste"))


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


## Grafikqualität: Auflösung der 3D-Szene, Schatten, Baumdichte, Kantenglättung, Gischt.
## Die Wasser-Effekte setzt GameSettings.set_quality mit (eigene Schlüssel w_*).
func _apply_quality(q: int) -> void:
	q = clampi(q, 0, 2)
	Spray.set_quality(q)
	SpraySheet.set_quality(q)
	var vp := get_viewport()
	vp.scaling_3d_scale = [0.6, 0.8, 1.0][q]
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, _msaa_default][q]
	weather.shadow_distance = [0.0, 110.0, 200.0][q]
	if ambient:
		ambient.quality = q                   # Zusatz-Paddler und Badegäste an Hitzetagen
		bathers.quality = q
		ambient.apply_season(weather)
		bathers.apply_season(weather)
	weather.apply()
	if terrain:
		terrain.set_tree_density([0.35, 0.7, 1.0][q])
	if features and features.reflections != (q >= 1):
		features.reflections = q >= 1       # nasse Features spiegeln die Umgebung (Reflection Probes) ab Mittel
		features.update_reflections()


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
## Zusätzlich je Anlage in die Mitte gerückt: im Schnitt aller Setups gleich viel Platz zwischen
## roter Boje und erstem bzw. letztem Feature (vorher vorne ~19 m, hinten ~42 m).
const CENTER_SHIFT := {"T1": 10.5, "T2": 12.5}

## Die Setups sind ab dem T2-Startsteg gemessen. Der T1-Steg liegt weiter draußen am Seil –
## dort rücken die Teile um den Unterschied nach hinten (gleicher Anlauf auf beiden Anlagen).
func _s_offset() -> Dictionary:
	return {"T2": FEATURE_SHIFT + float(CENTER_SHIFT["T2"]),
		"T1": FEATURE_SHIFT + float(CENTER_SHIFT["T1"]) + (cable.start_z - cable_t1.start_z) - (cable.mast_a_z - cable_t1.mast_a_z)}


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
func _select_setup(idx: int, force := false) -> void:
	if pc.state != CableSystem.State.IDLE or (idx == _setup_idx and not force):
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

## Finger auf den Bildschirm: steht die Anlage, startet sie; nach einem Sturz heißt
## Halten schwimmen. Gesprungen wird am Handy nur mit der SPRUNG-Taste.
func _on_touch_down() -> void:
	if start_screen.visible:
		return
	if challenge.active or _counting:
		return
	if pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED:
		_start_run()
		_touch_started = true
	elif not rider.attached:
		Input.action_press("swim")


## Menü der virtuellen Tasten (Handy).
## Einstellungen im laufenden Spiel (aus dem Pause-Fenster bzw. dem ☰-Menü): Spiel bleibt pausiert,
## nur das Einstellungs-Fenster der Startseite erscheint. Danach zurück, woher man kam.
var _settings_from := ""

func _open_settings_ingame(from: String) -> void:
	_settings_from = from
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mobile.ui_mode = true        # Finger bedienen das Fenster
	if touch_pad:
		mobile.release_pad()
		touch_pad.visible = false
	pause_menu.hide_window()
	start_screen.open_settings_ingame()


func _close_settings_ingame() -> void:
	mobile.ui_mode = false
	if touch_pad:
		touch_pad.visible = true
	if _settings_from == "pad" and touch_pad:
		touch_pad.trigger("menu")             # ☰-Menü wieder auf (pausiert weiter)
	elif _settings_from == "direct":
		pause_menu.set_paused(false)          # Taste O / Options im Spiel: danach gleich weiter
	else:
		pause_menu.show_again()


func _on_pad_menu(id: String) -> void:
	match id:
		"settings":
			_open_settings_ingame("pad")
		"help":
			hud.toggle_help()
		"reset":
			if challenge.active:
				challenge.start_attempt()
				return
			_reset_to_dock()
		"home":
			_open_start_screen()
		"mute":
			AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))
		"rope_rip":
			_toggle_rope_rip()
		"shuffle":
			_shuffle_scenario()


## Finger weg: nicht mehr schwimmen.
func _on_touch_up() -> void:
	if start_screen.visible:
		return
	_touch_started = false
	Input.action_release("swim")


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
	_check_boat()
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
	for h: Array in _hold:
		if _elapsed >= h[1] and _elapsed < h[2]:
			if h[0] in ["reset", "start"] and _elapsed - delta < h[1]:
				# Tasten, die als Ereignis wirken (R, Start): einmal als Tastendruck schicken
				var ev := InputEventAction.new()
				ev.action = h[0]
				ev.pressed = true
				Input.parse_input_event(ev)
			Input.action_press(h[0])
		elif _elapsed >= h[2] and _elapsed - delta < h[2]:
			Input.action_release(h[0])
	if _crash_at > 0.0 and _elapsed >= _crash_at:
		_crash_at = -1.0
		rider.crash("Teststurz")
	if _pike_at > 0.0 and _elapsed >= _pike_at:
		_pike_at = -1.0
		ambient.pike_now()
	if _sup_at > 0.0 and _elapsed >= _sup_at:
		_sup_at = -1.0
		ambient.sup_come_now()
	if _drop_at > 0.0 and _elapsed >= _drop_at:
		_drop_at = -1.0
		_test_drop()
	if _letgo_at > 0.0 and _elapsed >= _letgo_at:
		_letgo_at = -1.0
		rider.let_go("Test: Seil verloren")
	if _jump_at > 0.0 and _elapsed >= _jump_at and rider.mode == Rider.Mode.WATER:
		_jump_at = -1.0
		rider.test_jump()
	_max_tension = maxf(_max_tension, rider.tension_smooth)
	if rider.mode == Rider.Mode.AIR:
		_peak_y = maxf(_peak_y, rider.pos.y)
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
		pass                             # Freies Fahren: keine Uhr
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
	_round_over = true
	if _test_log:
		print("RUNDE ENDE at t=%.1f" % _elapsed)
	_session = false
	_finishing = false
	_last_result = "Letzte Runde: %d Punkte" % _final_score
	hud.show_trick("Ende!  %d Punkte" % _final_score)
	Analytics.count("runde/ende/" + Analytics.score_bucket(_final_score))
	_submit_round(_final_score)
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		if not start_screen.visible:
			_open_start_screen())


## Rangliste: Punkte der Runde eintragen (nur mit Standard-Anlage, siehe Leaderboard.competition_blocked).
## Platz erscheint unter dem Titel der Startseite.
func _submit_round(score: int) -> void:
	var sec := roundi(_game_time)
	var st: Dictionary = _setups[_setup_idx]
	if not leaderboard.enabled() or (_test_log and not leaderboard.has_name()):
		return
	var why := Leaderboard.competition_blocked(settings, sec, st)
	if why != "" or not leaderboard.has_name():
		_last_result += "   ·   " + (why if why != "" else "Rangliste: Namen eintragen")
		return
	var b := leaderboard.competition_board(sec, terminal, st, TERMINAL_NAMES[TERMINALS.find(terminal)])
	var r := await leaderboard.submit(b, score)
	if r.get("ok", false):
		_last_result = "Letzte Runde: %d Punkte   ·   %s Platz %d von %d" % [score,
			"Rangliste" if r.get("improved", false) else "Dein Bestwert:", int(r["rank"]), int(r["total"])]
	elif str(r.get("error", "")) != "":
		_last_result += "   ·   Rangliste: " + str(r["error"])
	if start_screen.visible:
		start_screen.set_result(_last_result)


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
	Analytics.tick(_delta)
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
	var time_text := _clock(_time_left if _session else _game_time)
	if challenge.active:
		time_text = str(maxi(challenge.attempt, 1))
		state = Hud.TimeState.RUNNING
	elif _free_ride():
		time_text = "FREI"                  # Freies Fahren: keine Uhr
		state = Hud.TimeState.RUNNING
	hud.time_title = "VERSUCH" if challenge.active else ("MODUS" if _free_ride() else "ZEIT")
	hud.set_stats(time_text, state,
		_final_score if _finishing else rider.score, rider.tension_smooth, minf(rider.crash_tension, Rider.CRASH_TENSION))
	hud.set_speed(rider.horizontal_speed() * 3.6)
	hud.set_debug("Fahrer %d km/h   ·   Anlage %s: %s (Tempo %d km/h)\nWenden %d   ·   Kamera: %s%s" % [
		roundi(rider.horizontal_speed() * 3.6), terminal, pc.state_text(), roundi(pc.max_speed * 3.6),
		pc.laps, cam.mode_name(), "   ·   AUTOPILOT" if rider.autopilot else ""])
	hud.set_board(rider.board_state_text())
	if touch_pad:
		touch_pad.set_swim(rider.mode == Rider.Mode.CRASHED)     # im Wasser: SCHWIMMEN / SKIP
	# Terminal/Setup wählt man am Handy nur auf der Startseite
	hud.show_setup_menu(pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED and not mobile.active)
	if challenge.active or _counting:
		hud.show_recovery("", [])
		hud.set_center("")
	elif rider.attached:
		_swum = false
	elif rider.swimming:
		_swum = true                # wer losschwimmt, braucht das Panel nicht mehr
	if challenge.active or _counting:
		pass                        # Spielmodi/Countdown: kein Sturz-Panel, kein Starttext
	elif not rider.attached:
		hud.set_center("")
		if _swum:
			hud.show_recovery("", [])
		elif pc.state == CableSystem.State.HOLD or pc.state == CableSystem.State.FETCH:
			var title := "STURZ  –  der Operator bringt dir die Handle" if pc.state == CableSystem.State.FETCH 				else "STURZ  –  die Handle liegt bereit"
			var free := _free_ride() or not _session
			var swim := "ca. %d s" % roundi(rider.swim_time())
			if mobile.active:
				hud.show_recovery(title, [["SCHWIMMEN halten", "Zur Handle schwimmen", swim, false],
					["SKIP", "Sofort weiterfahren", "keine Strafzeit" if free else "−1:00", not free],
					["☰", "Zurück zum Steg", "keine Strafzeit" if free else "−2:00", not free]])
			else:
				hud.show_recovery(title, [["LEERTASTE halten", "Zur Handle schwimmen", swim, false],
					["STRG", "Sofort weiterfahren", "keine Strafzeit" if free else "−1:00", not free],
					["R", "Zurück zum Steg", "keine Strafzeit" if free else "−2:00", not free]])
		else:
			hud.show_recovery("", [])
	elif rider.mode != Rider.Mode.CRASHED:
		hud.show_recovery("", [])
		if pc.state == CableSystem.State.IDLE:
			hud.set_center("")
			# Competition: steht man auf dem Steg (z. B. nach Bergung), startet der Countdown von selbst
			if not _round_over and not start_screen.visible and hud.visible and not get_tree().paused:
				_countdown_start()
		elif mobile.active and mobile.use_tilt and not mobile.tilt_available:
			hud.set_center("Neigungssensor nicht verfügbar –\nBewegungssensoren im Browser erlauben")
		else:
			hud.set_center("")

	if rider.dock_charge > 0.0:
		hud.set_center("SPRUNG-START  %d %%" % roundi(rider.dock_charge * 100.0))   # auch in den Challenges

	if _pause_at > 0.0 and _elapsed >= _pause_at:
		_pause_at = -1.0
		pause_menu.set_paused(true)
		if _shot_path != "":
			_take_shot()
	if _settings_at > 0.0 and _elapsed >= _settings_at:
		_settings_at = -1.0
		pause_menu.set_paused(true)
		_open_settings_ingame("pause")
		print("EINSTELLUNGEN im Spiel offen, pausiert: %s" % get_tree().paused)
		if _shot_path != "":
			_take_shot()
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
	if event.is_action_pressed("shuffle") and not start_screen.visible:
		_shuffle_scenario()
	elif event.is_action_pressed("settings"):
		if pause_menu.can_pause.call():          # O / Options: Einstellungen direkt über dem pausierten Spiel
			pause_menu.set_paused(true)
			_open_settings_ingame("direct")
	elif event.is_action_pressed("start"):
		if start_screen.visible:
			return
		if pc.state == CableSystem.State.IDLE and rider.mode != Rider.Mode.CRASHED and not _counting and not challenge.active:
			_start_run()
			rider.block_jump()
	elif event.is_action_pressed("reset") and challenge.active:
		challenge.start_attempt()            # Spielmodus: neuer Versuch
	elif (event.is_action_pressed("speed_up") or event.is_action_pressed("speed_down")) and challenge.active:
		pass                                 # Spielmodus: festes Tempo
	elif (event.is_action_pressed("speed_up") or event.is_action_pressed("speed_down")) and event is InputEventJoypadButton \
			and rider.mode == Rider.Mode.AIR:
		pass                                 # L1/R1 in der Luft: schnelle Drehung, nicht Tempo
	elif event.is_action_pressed("reset"):
		_reset_to_dock()
	elif event.is_action_pressed("speed_up") or event.is_action_pressed("speed_down"):
		pc.change_speed(2.0 if event.is_action_pressed("speed_up") else -2.0)
		settings.set_v("speed", float(roundi(pc.max_speed * 3.6)))
		start_screen.sync_settings()
	elif event.is_action_pressed("camera"):
		cam.cycle_mode()
	elif event.is_action_pressed("autopilot"):
		rider.autopilot = not rider.autopilot
	elif event.is_action_pressed("rope_rip"):
		_toggle_rope_rip()
	elif event.is_action_pressed("hitbox"):
		features.show_hitboxes = not features.show_hitboxes
		hud.show_trick("Hitboxen " + ("an" if features.show_hitboxes else "aus"))
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
			if weather.is_nikolaus():
				_unlock_achievement("nikolaus")
		elif _test_log:
			print("WENDE abgesoffen – keine Punkte")


func _reset() -> void:
	_turn_active = false
	rider.reset()
	pc.reset()
	water.clear_wake()
	cam.snap()                       # Kamera gleich am Steg, nicht vom letzten Ort herüberschwenken
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
	# Gamepad (Namen wie PS4): Kreuz = A, Kreis = B, Dreieck = Y, Options = START, Share = BACK, PS = GUIDE
	_bind("steer_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], [[JOY_AXIS_LEFT_X, -1.0]])
	_bind("steer_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], [[JOY_AXIS_LEFT_X, 1.0]])
	# ↑/↓: in der Luft Frontroll/Backroll, auf dem Slider Nose-/Tailpress, nach Sturz ↑ = schwimmen
	_bind("pitch_front", [KEY_UP, KEY_W], [JOY_BUTTON_DPAD_UP], [[JOY_AXIS_LEFT_Y, -1.0]])
	_bind("pitch_back", [KEY_DOWN, KEY_S], [JOY_BUTTON_DPAD_DOWN], [[JOY_AXIS_LEFT_Y, 1.0]])
	# Strg (zur Not Alt): Kante lösen = Driften (Gamepad: Kreis oder L2)
	_bind("release", [KEY_CTRL, KEY_ALT], [JOY_BUTTON_B], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_bind("jump", [KEY_SPACE], [JOY_BUTTON_A], [])
	_bind("swim", [], [], [])          # Handy: Bildschirm halten nach einem Sturz
	_bind("hitbox", [KEY_F3], [], [])  # Debug: Fangzonen der Slider zeigen
	_bind("rope_rip", [KEY_G], [], [])  # Seil-Abreißen an/aus
	_bind("start", [KEY_SPACE], [JOY_BUTTON_A], [])
	_bind("reset", [KEY_R], [JOY_BUTTON_TOUCHPAD], [])   # Touchpad im Spiel = Neustart (Share würfelt das Szenario)
	_bind("speed_up", [KEY_PAGEUP], [JOY_BUTTON_RIGHT_SHOULDER], [], [KEY_PLUS, KEY_KP_ADD])
	_bind("speed_down", [KEY_PAGEDOWN], [JOY_BUTTON_LEFT_SHOULDER], [], [KEY_MINUS, KEY_KP_SUBTRACT])
	_bind("jump_analog", [], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])   # R2: Sprung analog aufladen
	# L1/R1 in der Luft: schnelle halbe Drehung (auf dem Wasser Tempo), im Menü Reiter wechseln
	_bind("spin_left", [], [JOY_BUTTON_LEFT_SHOULDER], [])
	_bind("spin_right", [], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_bind("tab_prev", [], [JOY_BUTTON_LEFT_SHOULDER], [])
	_bind("tab_next", [], [JOY_BUTTON_RIGHT_SHOULDER], [])
	_bind("cam_zoom", [], [JOY_BUTTON_RIGHT_STICK], [])   # R3 halten: rechter Stick ↕ zoomt
	# Menüs (MenuNav): Enter / PS / Touchpad = Start, O / Options = Einstellungen, Esc / PS = Pause
	_bind("menu_start", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_GUIDE, JOY_BUTTON_TOUCHPAD], [])
	_bind("settings", [KEY_O], [JOY_BUTTON_START], [])
	_bind("shuffle", [], [JOY_BUTTON_BACK], [], [KEY_Z])   # Szenario würfeln (Z wie Zufall, Share): Startseite und im Spiel
	_bind("pause", [KEY_ESCAPE], [JOY_BUTTON_GUIDE], [])
	# Godot-Menüaktionen: Leertaste / Kreuz drückt den Knopf mit Fokus (Enter startet, s. menu_start),
	# Esc / Kreis zurück, Steuerkreuz und linker Stick bewegen den Fokus
	for e: InputEvent in InputMap.action_get_events("ui_accept"):
		var ek := e as InputEventKey
		if ek and (ek.keycode in [KEY_ENTER, KEY_KP_ENTER] or ek.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
			InputMap.action_erase_event("ui_accept", e)
	_ui_joy("ui_accept", JOY_BUTTON_A)
	_ui_joy("ui_cancel", JOY_BUTTON_B)
	_ui_joy("ui_left", JOY_BUTTON_DPAD_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_ui_joy("ui_right", JOY_BUTTON_DPAD_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_ui_joy("ui_up", JOY_BUTTON_DPAD_UP, JOY_AXIS_LEFT_Y, -1.0)
	_ui_joy("ui_down", JOY_BUTTON_DPAD_DOWN, JOY_AXIS_LEFT_Y, 1.0)
	_bind("camera", [KEY_C], [], [])          # nur Tastatur (Dreieck bleibt frei)
	_bind("autopilot", [KEY_P], [], [])
	_bind("help", [KEY_H, KEY_F1], [], [])
	_bind("mute", [KEY_M], [], [])
	_bind("overview", [KEY_TAB], [], [])
	_bind("cam_left", [], [], [[JOY_AXIS_RIGHT_X, -1.0]])
	_bind("cam_right", [], [], [[JOY_AXIS_RIGHT_X, 1.0]])
	_bind("cam_up", [], [], [[JOY_AXIS_RIGHT_Y, -1.0]])
	_bind("cam_down", [], [], [[JOY_AXIS_RIGHT_Y, 1.0]])


## Gamepad-Taste (und Stick-Richtung) zu einer Godot-Menüaktion, falls noch nicht drin.
func _ui_joy(action: String, button: JoyButton, axis := JOY_AXIS_INVALID, value := 0.0) -> void:
	var has_b := false
	var has_a := axis == JOY_AXIS_INVALID
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton and (e as InputEventJoypadButton).button_index == button:
			has_b = true
		elif e is InputEventJoypadMotion and (e as InputEventJoypadMotion).axis == axis \
				and signf((e as InputEventJoypadMotion).axis_value) == signf(value):
			has_a = true
	if not has_b:
		var b := InputEventJoypadButton.new()
		b.button_index = button
		InputMap.action_add_event(action, b)
	if not has_a:
		var m := InputEventJoypadMotion.new()
		m.axis = axis
		m.axis_value = value
		InputMap.action_add_event(action, m)


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


## Geheimen Erfolg freischalten (nur im Spiel, nicht hinter der Startseite) und melden.
func _unlock_achievement(id: String) -> void:
	if start_screen and start_screen.visible:
		return
	if Achievements.unlock(id):
		hud.show_achievement(Achievements.get_def(id)["name"])
		Analytics.count("erfolg/" + id)
		print("ERFOLG ", id)


## Geheimer Erfolg "boot": ins rote Boot gefahren (Sturz) oder beim Sturz hineingefallen.
func _check_boat() -> void:
	if start_screen and start_screen.visible:
		return
	var crashed := rider.mode == Rider.Mode.CRASHED
	if crashed and not (rider._ragdoll and rider._ragdoll.active):
		return                                      # schwimmend zählt nicht
	var hit := false
	for b: Node3D in [film.boat, beach.boat]:
		if b and b.is_visible_in_tree() and FilmCrew.in_boat(b, rider.pos, 0.0 if crashed else 0.25):
			hit = true
	if hit and not _in_boat:
		if not crashed:
			rider.crash("Ins Boot gefahren!")
		hud.show_trick("Boot crash!")
		_unlock_achievement("boot")
	_in_boat = hit


## Test --drop-at: Fahrer mit etwas Tempo in die Luft setzen (z. B. über den Steg oder in einen Mückenschwarm).
func _test_drop() -> void:
	var p := _drop_pos
	if p == Vector3.ZERO and beach.boat:
		p = beach.boat.global_position + Vector3(0.0, 1.0, 0.0)
	elif p == Vector3.INF:
		var d := rider.dock_rect.get_center()
		p = Vector3(d.x, rider.start_pos.y + 1.2, d.y)
	rider.pos = p
	rider.vel = Vector3(0.0, 1.0, -3.0)
	if _drop_pos == Vector3.ZERO:
		rider.let_go("Test: ins Boot")          # sonst zieht das Seil ihn vom Boot weg
		rider.vel = Vector3(0.0, 0.5, 0.0)
	rider.mode = Rider.Mode.AIR
	rider.air_time = 0.0
	print("DROP ", p)


func _parse_args() -> void:
	Achievements.no_save = not OS.get_cmdline_user_args().is_empty()   # Tests speichern keine Erfolge
	for arg in OS.get_cmdline_user_args():
		if arg == "--autotest":
			_test_log = true
		elif arg.begins_with("--quit="):
			_quit_after = arg.substr(7).to_float()
		elif arg.begins_with("--shot="):
			_shot_path = arg.substr(7)
		elif arg.begins_with("--shot-time="):
			_shot_time = arg.substr(12).to_float()
		elif arg.begins_with("--hold="):
			for h in arg.substr(7).split(","):
				var a := h.split("@")
				var tt := a[1].split("-")
				_hold.append([a[0], tt[0].to_float(), tt[1].to_float()])
		elif arg.begins_with("--dpress="):
			_test_dpress = arg.substr(9).to_float()
		elif arg.begins_with("--pitch="):
			_test_pitch = arg.substr(8).to_float()
		elif arg.begins_with("--pause-at="):
			_pause_at = arg.substr(11).to_float()
		elif arg.begins_with("--settings-at="):
			_settings_at = arg.substr(14).to_float()
		elif arg.begins_with("--mode="):
			_mode_arg = arg.substr(7)
		elif arg == "--mode-auto":
			mode_auto = true
		elif arg.begins_with("--go="):
			_go_at = arg.substr(5).to_float()
		elif arg == "--debug-params":
			_debug_params_arg = true
		elif arg == "--hitbox":
			_hitbox_arg = true
		elif arg.begins_with("--set="):
			_set_args.append(arg.substr(6))
		elif arg.begins_with("--music="):
			_music_args = arg.substr(8).split(",")
		elif arg.begins_with("--jump-at="):
			_jump_at = arg.substr(10).to_float()
		elif arg.begins_with("--letgo-at="):
			_letgo_at = arg.substr(11).to_float()
		elif arg.begins_with("--crash-at="):
			_crash_at = arg.substr(11).to_float()
		elif arg.begins_with("--sup-at="):
			_sup_at = arg.substr(9).to_float()
		elif arg.begins_with("--drop-at="):
			var v := arg.substr(10).split_floats(",")
			_drop_at = v[0]
			if arg.ends_with(",boot"):
				_drop_pos = Vector3.ZERO
			elif v.size() >= 4:
				_drop_pos = Vector3(v[1], v[2], v[3])
		elif arg.begins_with("--pike-at="):
			_pike_at = arg.substr(10).to_float()
		elif arg.begins_with("--erfolg="):
			for id in arg.substr(9).split(","):
				Achievements.unlock(id)
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
		elif arg.begins_with("--scenario="):
			_scenario_arg = arg.substr(11)
		elif arg.begins_with("--weather="):
			_weather_arg = arg.substr(10)
		elif arg.begins_with("--hour="):
			_hour_arg = arg.substr(7).to_float()
		elif arg.begins_with("--day="):
			_day_arg = arg.substr(6).to_int()
		elif arg.begins_with("--plane="):
			var pa := arg.substr(8).split(",")
			_plane_arg = pa[0].to_float()
			if pa.size() > 1:
				_plane_near = 1 if pa[1] == "nah" else 0
			if pa.size() > 2:
				_plane_land = 0 if pa[2] == "start" else 1
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
	# Jeder Start würfelt ein Szenario (Datum, Uhrzeit, Wetter, Extras; Weather.SCENARIOS), am 6. Dezember immer
	# Nikolaus. Tests nehmen fest "afterhour". Änderungen in den Einstellungen gelten nur für diese Sitzung;
	# "Jetzt" holt bei Bedarf die echte Uhrzeit und das Wetter.
	var sc := _scenario_arg
	if sc == "":
		sc = Weather.random_scenario() if OS.get_cmdline_user_args().is_empty() else "afterhour"
	weather.set_scenario(sc)
	if _weather_arg != "" or not is_nan(_hour_arg) or _day_arg > 0:
		weather.scenario = ""
	if _weather_arg != "":
		weather.preset = weather.find_preset(_weather_arg)
	if not is_nan(_hour_arg):
		weather.hour = _hour_arg
		weather.live = false
	if _day_arg > 0:
		weather.day = _day_arg
		weather.live = false
	weather.apply()

