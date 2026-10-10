class_name Challenge
extends Node
## Ablauf einer Aufgabe der Spielmodi (siehe Training): Setup laden, Aufgabe vorstellen, Fahrer in
## voller Fahrt vor die Stelle setzen, Countdown 3 – 2 – 1 – GO (Spiel steht so lange), Wert messen,
## Medaille vergeben, Ergebnis zeigen. Jeder Versuch beginnt wieder an derselben Stelle.
## Läuft immer auf Terminal 2 mit 30 km/h und 16 m Seil (vergleichbare Werte).

signal home_requested

const SETTLE := 0.7             # s nach Landung/Slide ohne Sturz, bis der Versuch zählt
const FAIL_DELAY := 1.4         # s nach Sturz, bis das Ergebnis kommt
const TIMEOUT := 75.0
const DRIFT_SINK := 0.15        # Wende im Drift: ab diesem Sinkpegel gleitet man nicht mehr (zählt nicht)
const SPIN_EACH := 5            # 360er im Drift: so viele je Richtung zählen
const OUTRO := 1.4              # s nach dem Ende weiterfahren (ausrollen), dann erst das Ergebnis

var game: Node                  # main.gd (rider, pc, features, hud, cam, water, …)
var panel: TaskPanel
var mode_id := ""
var task_idx := 0
var task: Dictionary = {}
var active := false             # eine Aufgabe ist gewählt (Spielmodus läuft)
var running := false            # ein Versuch läuft (wird gemessen)
var attempt := 0

var _t := 0.0
var _value := 0.0               # Messwert des laufenden Versuchs
var _max_y := 0.0
var _laps0 := 0
var _around := false
var _ground_part: FeaturePart
var _launch: FeaturePart        # vom Ziel-Feature abgehoben
var _was_air := false
var _done_t := -1.0             # wartet nach Landung/Slide auf "kein Sturz"
var _fail_t := -1.0
var _fail_text := ""
var _hit := false               # Ziel erreicht (Wert gültig)
var _count := 0
var _s_turn := 0.0              # Wendepunkt (Spiel-s) bei Wende/Raley
var _off := 0.0                 # Verschiebung Setup -> Spiel (s)
var _via := false               # Transfer: gerade über das Start-Feature gekommen (noch nicht im Wasser)
var _via_ok := false            # Transfer: beim Draufkommen aufs Ziel kam man vom Start-Feature
var _target_started := false
var _via_air := false           # Transfer: seit dem Start-Feature in der Luft gewesen (Absprung)
# special (Kombinationen auf der Slider-Kette)
var _stations: Array = []       # Slider der Kette in Fahrtrichtung (je Station die Teile, z. B. Full Pipe = 2)
var _st_next := 0               # nächste noch offene Station
var _cur := {}                  # laufende Station: idx, on_air, on_turns, slide, phase
var _since_air := 99.0          # s seit der letzten Landung
var _air_turns := 0             # halbe Drehungen des letzten Sprungs
var _status: Array[String] = [] # je Station "", "OK", "X"
var _best_station := 0.0        # bester Messwert einer geschafften Station (metric != count)
# Driften
var _spin := 0.0                # drift_spin: Brettdrehung im laufenden Drift (rad, mit Vorzeichen)
var _prev_yaw := 0.0
var _spins := [0, 0]            # drift_spin: volle 360er im Drift [links, rechts]
var _seg := false               # drift_turn: Wende läuft (Carrier bremst / steht / fährt wieder an)
var _seg_t := 0.0
var _drift_t := 0.0
var _from_feat := false         # drift_after: kommt gerade von einem Feature (oder aus dem Sprung davon)
var _water_t := 0.0             # s auf dem Wasser ohne Drift seit dem Feature
var _drift_from := Vector3.INF  # Beginn des laufenden Drifts nach einem Feature


func _ready() -> void:
	var r: Rider = game.rider
	r.jump_landed.connect(_on_landed)
	r.slide_ended.connect(_on_slide)
	r.sank.connect(func() -> void:
		if running and task["kind"] in ["turn", "drift_turn"]:
			_fail("Abgesoffen – kein Wert"))
	panel.go_pressed.connect(func() -> void: start_attempt())
	panel.next_pressed.connect(func() -> void: begin(mode_id, task_idx + 1))
	panel.home_pressed.connect(func() -> void:
		panel.close()
		home_requested.emit())


## Aufgabe wählen: Setup aufbauen, Aufgabe vorstellen (Spiel steht).
func begin(mode: String, idx: int) -> void:
	var list := Training.tasks(mode)
	if list.is_empty():
		return
	mode_id = mode
	task_idx = clampi(idx, 0, list.size() - 1)
	task = list[task_idx]
	active = true
	running = false
	attempt = 0
	var term: String = task.get("terminal", "T2")
	game._training_terminal(term)
	game.features.load_setup(task["setup"], {"T1": game.cable_t1, "T2": game.cable}, game._s_offset())
	game.rider.forget_features()
	game.npc.forget_features()
	_off = float(game._s_offset()[term])
	game.rider.rope_length = Training.ROPE
	game.pc.max_speed = Training.SPEED / 3.6
	game.hud.time_title = "VERSUCH"
	game.film.start(int(game.settings.get_v("film")))
	await _place_and_freeze()
	if not active:
		get_tree().paused = false
		return
	panel.show_intro(_mode_name(), task_idx, list.size(), task, _best(), task_idx + 1 < list.size())
	_update_hud()


## Spielmodus verlassen (Startseite / Competition).
func stop() -> void:
	active = false
	running = false
	panel.close()
	game.film.stop()
	game.hud.show_count("")
	game.hud.set_task("")
	game.hud.time_title = "ZEIT"


## Neuer Versuch: Fahrer an den Start der Aufgabe, Countdown, los.
func start_attempt() -> void:
	panel.close()
	attempt += 1
	running = false
	await _place_and_freeze()
	if not active:
		get_tree().paused = false
		return
	_reset_measure()
	_update_hud()
	await countdown(game.hud, get_tree(), true, game.sfx)
	if not active:
		return
	game.rider.block_jump()
	if task.get("start", {}).has("dock"):
		game.pc.start()                    # Start vom Steg: die Anlage fährt bei GO los
	running = true


## Countdown 3 – 2 – 1 – GO. freeze: Spiel steht bis GO (Spielmodi); sonst läuft die Szene weiter.
## sfx: spricht die Zahlen (englisch: three, two, one, go).
static func countdown(hud: Hud, tree: SceneTree, freeze: bool, sfx: Sfx = null) -> void:
	if freeze:
		tree.paused = true
	for n: String in ["3", "2", "1"]:
		hud.show_count(n)
		if sfx:
			sfx.say_count(n)
		await tree.create_timer(0.8, true).timeout
	hud.show_count("GO")
	if sfx:
		sfx.say_count("GO")
	if freeze:
		tree.paused = false
	tree.create_timer(0.7, true).timeout.connect(func() -> void:
		if hud._count.text == "GO":
			hud.show_count(""))


## Fahrer und Carrier in Fahrt an den Start der Aufgabe; ein Bild laufen lassen (Figur und
## Kamera folgen), dann anhalten.
func _place_and_freeze() -> void:
	var tree := get_tree()
	tree.paused = false
	game.pause_menu.set_paused(false)
	_place()
	game.water.clear_wake()
	game.cam.snap()
	await tree.physics_frame
	await tree.process_frame
	game.cam.snap()
	await tree.process_frame
	await tree.process_frame
	tree.paused = true


func _place() -> void:
	var c: CableSystem = game.pc
	var r: Rider = game.rider
	var st: Dictionary = task["start"]
	if st.has("dock"):
		# Sprung-Start: auf dem Startsteg, Anlage steht bis GO
		r.autopilot = game.mode_auto
		r.reset()
		c.reset()
		game.film.snap()
		_laps0 = c.laps
		return
	var out: bool
	var s_r: float
	if st.has("turn"):
		var tz: float = c.turn_b_z if st["turn"] == "b" else c.turn_a_z
		_s_turn = c.mast_a_z - tz
		out = st["turn"] == "b"
		s_r = _s_turn - float(st["before"]) if out else _s_turn + float(st["before"])
	else:
		out = float(st["dir"]) > 0.0
		s_r = float(st["s"]) + _off
	var x: float = st.get("x", 0.0)
	var speed := Training.SPEED / 3.6
	var z_r := c.mast_a_z - s_r
	var dy := Lake.CABLE_Y - CableSystem.CARRIER_HANG - Rider.HANDLE_HEIGHT
	var horiz := sqrt(maxf(r.rope_length * r.rope_length - dy * dy, 4.0)) - 0.3
	var dx := x - Lake.PULLEY_RADIUS
	var dz := sqrt(maxf(horiz * horiz - dx * dx, 1.0))
	c.place_running(z_r - dz if out else z_r + dz, -1.0 if out else 1.0, speed)
	var travel := c.transform.basis * Vector3(0.0, 0.0, -1.0 if out else 1.0)
	var p := c.transform * Vector3(x, 0.0, z_r)
	r.autopilot = game.mode_auto
	r.place(Vector3(p.x, 0.0, p.z), atan2(-travel.x, -travel.z), travel * speed)
	game.film.snap()
	_laps0 = c.laps


func _reset_measure() -> void:
	_t = 0.0
	_value = 0.0
	_max_y = 0.0
	_around = false
	_ground_part = null
	_launch = null
	_was_air = false
	_done_t = -1.0
	_fail_t = -1.0
	_hit = false
	_count = 0
	_via = false
	_via_ok = false
	_via_air = false
	_target_started = false
	_cur = {}
	_st_next = 0
	_since_air = 99.0
	_air_turns = 0
	_status.clear()
	_stations.clear()
	_best_station = 0.0
	_spin = 0.0
	_spins = [0, 0]
	_prev_yaw = game.rider.yaw
	_seg = false
	_seg_t = 0.0
	_drift_t = 0.0
	_from_feat = false
	_water_t = 0.0
	_drift_from = Vector3.INF
	if task["kind"] == "special":
		var groups := {}
		for p: FeaturePart in game.features.parts:
			if p.is_slide() and _in_target(p) and p.cable == game.pc:
				var key: Variant = p.group_name if p.group_name != "" else p
				if not groups.has(key):
					groups[key] = []
					_stations.append(groups[key])
				groups[key].append(p)
		var out := float(task["start"].get("dir", 1.0)) > 0.0
		var s_of := func(st: Array) -> float:
			var s := INF if out else -INF
			for p: FeaturePart in st:
				s = minf(s, p.s_center) if out else maxf(s, p.s_center)
			return s
		_stations.sort_custom(func(a: Array, b: Array) -> bool:
			return s_of.call(a) < s_of.call(b) if out else s_of.call(a) > s_of.call(b))
		for i in _stations.size():
			_status.append("")
	if task["kind"] == "turn":
		_value = 0.0


# ---------------------------------------------------------------- Messen

func _physics_process(delta: float) -> void:
	if not running:
		return
	var r: Rider = game.rider
	var c: CableSystem = game.pc
	_t += delta
	if _fail_t >= 0.0:
		_fail_t -= delta
		if _fail_t < 0.0:
			_finish(false)
		return
	if r.mode == Rider.Mode.CRASHED or not r.attached:
		if task["kind"] in ["chain", "special", "drift_spin"] and _count > 0:
			_value = _special_value() if task["kind"] == "special" else _count
			_hit = true
			_finish(true)
			return
		_fail("Gestürzt – kein Wert" if r.mode == Rider.Mode.CRASHED else "Seil verloren – kein Wert")
		return
	var local := c.transform.affine_inverse() * r.pos
	var s_now := c.mast_a_z - local.z
	match task["kind"]:
		"turn":
			_value = maxf(_value, r.sink_level)
			var s_white := _s_turn - (1.0 if task["start"]["turn"] == "b" else -1.0) * TurnBuoys.WHITE_BEFORE
			var end := 1.0 if task["start"]["turn"] == "b" else -1.0
			if (s_now - s_white) * end > 0.0 and absf(local.x) > TurnBuoys.WHITE_SIDE - 0.5:
				_around = true
			if c.laps > _laps0 and c.state == CableSystem.State.RUN and r.tension_smooth > 200.0:
				if task.get("buoy", false) and not _around:
					_fail("Nicht um die weiße Boje – kein Wert")
				else:
					_hit = true
					_finish(true)
				return
		"kick":
			if r.mode == Rider.Mode.AIR:
				if not _was_air:
					_was_air = true
					_max_y = r.pos.y
					if _launch == null and _ground_part and _in_target(_ground_part):
						_launch = _ground_part          # vom Ziel-Kicker abgehoben
				_max_y = maxf(_max_y, r.pos.y)
			else:
				if _was_air:
					_was_air = false
					if _launch and not _hit:
						if task.get("no_pop", false) and r._popped:
							_fail("Ohne Absprung fahren – kein Wert")
							return
						_value = _max_y
						_hit = true
						_done_t = SETTLE
				_ground_part = game.features.part_at(r.pos.x, r.pos.z) if r.pos.y > 0.05 else null
			if _launch == null and _past(s_now, float(task["end_s"]) + _off):
				_fail("Kicker verpasst – kein Wert")
				return
		"slide", "chain":
			if task.has("via"):
				_track_via(r)
			if _past(s_now, float(task["end_s"]) + _off) and _done_t < 0.0:
				if task["kind"] == "chain" and _count > 0:
					_value = _count
					_hit = true
					_finish(true)
				else:
					_fail("Slider verpasst – kein Wert")
				return
		"special":
			_track_special(r)
			var all_done := _cur.is_empty() and not _stations.is_empty() and _st_next >= _stations.size()
			if (_past(s_now, float(task["end_s"]) + _off) and _cur.is_empty()) or all_done:
				if _count > 0:
					_value = _special_value()
					_hit = true
					_finish(true)
				else:
					_fail("Keine Kombination geschafft – kein Wert")
				return
		"drift_spin":
			if _track_drift_spin(r, s_now):
				return
		"drift_turn":
			if _track_drift_turn(r, delta):
				return
		"drift_after":
			_track_drift_after(r)
			if _past(s_now, float(task["end_s"]) + _off) and _drift_from == Vector3.INF:
				if _value > 0.0:
					_hit = true
					_finish(true)
				else:
					_fail("Kein Drift nach einem Feature – kein Wert")
				return
		"dock":
			if r.mode == Rider.Mode.AIR:
				_max_y = maxf(_max_y, r.pos.y)
			elif _done_t < 0.0 and r.pos.y < 0.2 and not r.in_dock(r.pos.x, r.pos.z):
				_fail("Kein Sprung-Start – auf dem Steg ↓ halten, bis das Seil losreißt")
				return
		"raley":
			if r.mode == Rider.Mode.AIR:
				if not _was_air:
					_was_air = true
					_max_y = r.pos.y
				_max_y = maxf(_max_y, r.pos.y)
			else:
				_was_air = false
			if c.laps > _laps0 and absf(s_now - _s_turn) > float(task["end_after"]) and _done_t < 0.0:
				_fail("Kein Raley – mehr Tempo: weit raus, dann hart zur Mitte kanten")
				return
	if _done_t >= 0.0:
		if r.mode == Rider.Mode.WATER and r.pos.y < 0.15:
			_done_t -= delta
		if _done_t < 0.0:
			_finish(true)
			return
	if _t > TIMEOUT:
		_fail("Zeit abgelaufen – kein Wert")
	_update_hud()


## Liegt s schon hinter der Grenze (in Fahrtrichtung der Aufgabe)?
func _past(s_now: float, s_end: float) -> bool:
	var st: Dictionary = task["start"]
	var out := float(st.get("dir", 1.0)) > 0.0
	return s_now > s_end if out else s_now < s_end


func _in_target(p: FeaturePart) -> bool:
	return _matches(p, task.get("target", {}))


## Passt das Teil zur Beschreibung? {name} (Anzeigename, nur eigene Anlage) oder {s0, s1, side, x}.
func _matches(p: FeaturePart, tg: Dictionary) -> bool:
	if tg.is_empty():
		return true
	if tg.has("name"):
		return p.display_name == tg["name"] and p.cable == game.pc
	if p.s_center < float(tg["s0"]) + _off or p.s_center > float(tg["s1"]) + _off:
		return false
	if signf(p.x_center) != signf(float(tg["side"])):
		return false
	return not tg.has("x") or absf(p.x_center - float(tg["x"])) < 1.5


func _on_landed(info: Dictionary) -> void:
	if not running or _fail_t >= 0.0:
		return
	match task["kind"]:
		"dock":
			if info.get("start", "") != task["jump"]:
				_fail("Das war kein Raley Start – Brett quer zum Seil stellen" if task["jump"] == "raley" \
					else "Das war kein Nolli – Brett längs zum Seil lassen")
				return
			match task["metric"]:
				"height":
					_value = _max_y
				"spin":
					_value = int(info["half_turns"]) * 180.0
				"points":
					_value = float(info["points"])
			_hit = true
			_done_t = SETTLE
		"raley":
			if not info["raley"]:
				return
			match task["metric"]:
				"height":
					_value = _max_y
				"spin":
					_value = int(info["half_turns"]) * 180.0
				"points":
					_value = float(info["points"])
			_hit = true
			_done_t = SETTLE


## Transfer: über das Start-Feature gekommen? Wer dazwischen ins Wasser kommt, muss neu ansetzen.
## Beim ersten Kontakt mit dem Ziel wird festgehalten, ob man vom Start-Feature kam.
## Gilt nur: auf dem Start-Feature fahren (Brett auf seiner Oberfläche, nicht darüber fliegen),
## von dort abspringen und aus der Luft aufs Ziel kommen. Wer das Ziel von vorne anfährt, von der
## Seite aus dem Wasser drauf springt oder dazwischen Wasser/ein anderes Feature berührt, zählt nicht.
func _track_via(r: Rider) -> void:
	var under: FeaturePart = game.features.part_at(r.pos.x, r.pos.z) if r.pos.y > 0.05 else null
	if r.mode == Rider.Mode.AIR:
		if _via:
			_via_air = true                     # vom Start-Feature abgehoben
		return
	if under and _matches(under, task["via"]):
		_via = true
		_via_air = false
	elif under and _in_target(under):
		if not _target_started:
			_target_started = true
			_via_ok = _via and _via_air       # direkt aus dem Sprung vom Start-Feature aufs Ziel
	else:
		_via = false                           # Wasser oder anderes Feature: neu ansetzen
		_via_air = false


## Driften: ist der Fahrer gerade im Drift auf dem Wasser?
func _drifting(r: Rider) -> bool:
	return r.drifting and r.mode == Rider.Mode.WATER and r.pos.y < 0.2


## 360er im Drift zwischen den roten Bojen: Brettdrehung im Drift mitzählen, je volle Umdrehung
## eine, links und rechts getrennt; gewertet werden bis SPIN_EACH je Richtung (Ziel: 5 + 5).
## Drift lösen setzt die angefangene Drehung zurück. true = Versuch zu Ende.
func _track_drift_spin(r: Rider, s_now: float) -> bool:
	var c: CableSystem = game.pc
	var s_a := c.mast_a_z - c.turn_a_z + TurnBuoys.RED_BEFORE
	var s_b := c.mast_a_z - c.turn_b_z - TurnBuoys.RED_BEFORE
	if s_now > s_a and s_now < s_b and _drifting(r):
		_spin += wrapf(r.yaw - _prev_yaw, -PI, PI)
		if absf(_spin) >= TAU:
			var side := 0 if _spin > 0.0 else 1          # Yaw wächst nach links
			_spin -= signf(_spin) * TAU
			_spins[side] += 1
			_count = mini(_spins[0], SPIN_EACH) + mini(_spins[1], SPIN_EACH)
			game.hud.show_trick("360 %s im Drift!  (%d / %d)" % [["links", "rechts"][side], mini(_spins[side], SPIN_EACH), SPIN_EACH])
	else:
		_spin = 0.0
	_prev_yaw = r.yaw
	if s_now >= s_b or _count >= SPIN_EACH * 2:
		if _count > 0:
			_value = _count
			_hit = true
			_finish(true)
		else:
			_fail("Kein 360 im Drift – kein Wert")
		return true
	return false


## Wende im Drift: von dem Moment, in dem der Carrier zur Wende bremst, bis das Seil in der neuen
## Richtung wieder zieht – welcher Anteil davon im Drift gleitend (nicht schon einsinkend)? Absaufen = kein Wert.
## true = zu Ende.
func _track_drift_turn(r: Rider, delta: float) -> bool:
	var c: CableSystem = game.pc
	if not _seg and c.laps == _laps0 and c.state != CableSystem.State.RUN:
		_seg = true
	if not _seg:
		return false
	_seg_t += delta
	if _drifting(r) and r.sink_level < DRIFT_SINK:
		_drift_t += delta
	_value = _drift_t / maxf(_seg_t, 0.01)
	if c.laps > _laps0 and c.state == CableSystem.State.RUN and r.tension_smooth > 200.0:
		_hit = true
		_finish(true)
		return true
	return false


## Drift nach einem Feature: wer vom Feature (auch aus dem Sprung davon) aufs Wasser kommt und
## gleich (bis 0,3 s) driftet, dessen Drift-Strecke zählt; die längste gilt.
func _track_drift_after(r: Rider) -> void:
	var on_feat := r.pos.y > 0.05 and game.features.part_at(r.pos.x, r.pos.z) != null
	var drifting := _drifting(r)
	if on_feat:
		_from_feat = true
		_water_t = 0.0
	elif r.mode == Rider.Mode.WATER and not drifting:
		_water_t += get_physics_process_delta_time()
		if _water_t > 0.3:
			_from_feat = false
	if drifting and _from_feat and _drift_from == Vector3.INF:
		_drift_from = r.pos
	if _drift_from == Vector3.INF:
		return
	var d := Vector2(r.pos.x - _drift_from.x, r.pos.z - _drift_from.z).length()
	if drifting:
		_value = maxf(_value, d)
		return
	_drift_from = Vector3.INF            # Drift gelöst: diese Strecke ist fertig
	_from_feat = false
	if d >= 1.0:
		game.hud.show_trick("%s Drift" % Training.format_value(task, d))


## Slider Special: je Slider der Kette Aufspringen (aus der Luft, Drehung), Stellung, Press und
## Abgang (Drehung bis zum Wasser) prüfen. Ausgelassene Slider zählen als verpasst.
func _track_special(r: Rider) -> void:
	if r.mode == Rider.Mode.AIR:
		_since_air = 0.0
		_air_turns = int(round(absf(r._spin_accum) / PI))
		return
	_since_air += get_physics_process_delta_time()
	if _cur.is_empty():
		if r.is_sliding():
			var i := _station_of(r._slide_part)
			if i >= _st_next:
				for k in range(_st_next, i):
					_station_done(k, false, "ausgelassen")
				_st_next = i + 1
				var on_air := _since_air < 0.2
				_cur = {"idx": i, "on_air": on_air, "on_turns": _air_turns if on_air else 0, "phase": "slide"}
		return
	if _cur["phase"] == "slide":
		if not r.is_sliding():
			_station_done(_cur["idx"], false, "zu kurz auf dem Slider")    # (unter 0,3 s: kein Slide)
			_cur = {}
		return
	# Abgang: die Slide-Wertung kommt erst nach der Landung bzw. auf der Abfahrt – dann im Wasser werten
	# (Drehung aus dem Sprung vom Slider, sonst gerade)
	var on_feat := r.pos.y > 0.05 and game.features.part_at(r.pos.x, r.pos.z) != null
	if r.pos.y < 0.15 and not on_feat:
		_judge_station(_air_turns if _cur["out_air"] else 0)
	elif r.is_sliding() and _station_of(r._slide_part) != _cur["idx"]:
		_judge_station(_air_turns if _cur["out_air"] else 0)     # direkt auf den nächsten Slider


## Station bewerten (nach dem Abgang).
func _judge_station(out_turns: int) -> void:
	var req: Dictionary = task["combo"][_cur["idx"]] if _cur["idx"] < task["combo"].size() else {}
	var info: Dictionary = _cur.get("slide", {})
	var why := ""
	var want_on := int(req.get("on", 0))
	var stance := "bs" if float(info.get("bs_share", 0.0)) > 0.5 else "5050"
	var t := float(info.get("time", 0.0))
	var press := "nose" if float(info.get("press_nose", 0.0)) > t * 0.5 else ("tail" if float(info.get("press_tail", 0.0)) > t * 0.5 else "")
	if not _cur["on_air"]:
		why = "kein Ollie on (über die Auffahrt)"
	elif int(_cur["on_turns"]) != want_on:
		why = "Aufspringen: %s statt %s" % [_turn_name(int(_cur["on_turns"])), _turn_name(want_on)]
	elif req.has("stance") and stance != req["stance"]:
		why = "Boardslide statt 50-50" if stance == "bs" else "50-50 statt Boardslide"
	elif req.has("press") and press != req["press"]:
		why = ("kein Press" if press == "" else ("Nosepress" if press == "nose" else "Tailpress") + " statt " + ("Nosepress" if req["press"] == "nose" else "Tailpress"))
	elif req.has("out") and out_turns != int(req["out"]):
		why = "Abgang: %s statt %s" % [_turn_name(out_turns), _turn_name(int(req["out"]))]
	if why == "" and task["metric"] != "count":
		_best_station = maxf(_best_station, float(info.get(task["metric"], 0.0)))   # z. B. Meter im Slide
	_station_done(_cur["idx"], why == "", why)
	_cur = {}


## Wert der Kombinations-Challenge: Anzahl geschaffter Slider oder bester Messwert einer geschafften Station.
func _special_value() -> float:
	return float(_count) if task["metric"] == "count" else _best_station


## Station (Index in _stations) eines Slider-Teils, -1 = keins.
func _station_of(p: FeaturePart) -> int:
	for i in _stations.size():
		if p in _stations[i]:
			return i
	return -1


func _station_name(i: int) -> String:
	var combo: Array = task.get("combo", [])
	if i < combo.size() and combo[i].has("name"):
		return combo[i]["name"]
	return (_stations[i][0] as FeaturePart).display_name


func _turn_name(half_turns: int) -> String:
	return "gerade" if half_turns == 0 else str(half_turns * 180)


func _station_done(i: int, ok: bool, why: String) -> void:
	if i >= _status.size() or _status[i] != "":
		return
	_status[i] = "OK" if ok else "X"
	if ok:
		_count += 1
	var name := "%d. %s" % [i + 1, _station_name(i)]
	game.hud.show_trick(("%s geschafft!" % name) if ok else ("%s: %s" % [name, why]))
	if game._test_log:
		print("SPECIAL %s %s %s" % [name, "OK" if ok else "X", why])


## Kombination einer Station als Text, z. B. "Ollie on – Boardslide Nosepress – 180 out".
static func combo_text(req: Dictionary) -> String:
	var on := int(req.get("on", 0))
	var parts: Array[String] = ["Ollie on" if on == 0 else "Ollie %d on" % (on * 180)]
	var s := "Boardslide" if req.get("stance", "") == "bs" else "50-50"
	if req.has("press"):
		s += " Nosepress" if req["press"] == "nose" else " Tailpress"
	parts.append(s)
	if req.has("out"):
		parts.append("%d out" % (int(req["out"]) * 180))
	return " – ".join(parts)


func _on_slide(info: Dictionary) -> void:
	if not running or _fail_t >= 0.0:
		return
	var p: FeaturePart = info["part"]
	if task["kind"] == "special":
		if not _cur.is_empty() and _cur["phase"] == "slide" and _station_of(p) == _cur["idx"]:
			_cur["slide"] = info
			_cur["phase"] = "out"
			_cur["out_air"] = _since_air < 0.3 and game.rider.mode != Rider.Mode.AIR    # vom Slider abgesprungen, eben gelandet
		return
	if not _in_target(p):
		return
	if task.has("via") and not _via_ok:
		_fail(str(task.get("via_fail", "Transfer verpasst")) + " – kein Wert")
		return
	if task["kind"] == "chain":
		if float(info["dist"]) >= 1.5:
			_count += 1
		return
	if task["kind"] != "slide":
		return
	_value = maxf(_value, float(info[task["metric"]]) if info.has(task["metric"]) else 0.0)
	_hit = true
	_done_t = SETTLE


func _fail(text: String) -> void:
	if _fail_t >= 0.0:
		return
	_fail_text = text
	_fail_t = FAIL_DELAY


## Versuch auswerten, Bestwert speichern, Ergebnis zeigen (Spiel steht). Ohne Wert (Sturz usw.)
## kein Fenster: sofort neuer Versuch.
func _finish(ok: bool) -> void:
	running = false
	var list := Training.tasks(mode_id)
	var medal := 0
	var text := _fail_text
	var new_best := false
	if ok and _hit and task.get("drift_exit", false) and not game.rider.last_exit_drift:
		_fail_text = "Gerade abgefahren – hier quer mit Drift abgehen"
		ok = false
		text = _fail_text
	if ok and _hit:
		medal = Training.medal_for(task, _value)
		text = Training.format_value(task, _value)
		new_best = Training.record(mode_id, task, _value) if not game._test_log else false   # Tests speichern nichts
		if medal == 0:
			text += "   –   noch keine Medaille"
		if game._test_log:
			print("CHALLENGE %s/%s Versuch %d: %s Medaille %d" % [mode_id, task["id"], attempt, text, medal])
	else:
		# Sturz, Seil verloren, verpasst …: kein Fenster, gleich der nächste Versuch (mit Countdown)
		if game._test_log:
			print("CHALLENGE %s/%s Versuch %d: %s" % [mode_id, task["id"], attempt, text])
		game.hud.show_trick(text.replace(" – kein Wert", ""))
		start_attempt()
		return
	# erst noch ein Stück ausfahren lassen, dann anhalten und das Ergebnis zeigen
	game.hud.show_trick(("%s!  " % Training.MEDALS[medal].to_upper() if medal > 0 else "") + text)
	var n := attempt
	await get_tree().create_timer(OUTRO).timeout
	if not active or running or attempt != n:
		return
	get_tree().paused = true
	panel.show_result(_mode_name(), task_idx, list.size(), task, _best(), task_idx + 1 < list.size(),
		medal, text, new_best)
	_update_hud()


func _best() -> Array:
	return Training.best(mode_id, task["id"])


func _mode_name() -> String:
	return Training.MODES[Training.mode_index(mode_id)]["name"]


## Zeile unter der HUD-Leiste: Aufgabe, laufender Messwert, Bestwert.
func _update_hud() -> void:
	if not active:
		return
	var line := "%s %d: %s" % [_mode_name().to_upper(), task_idx + 1, task["title"]]
	if running:
		var live := ""
		match task["kind"]:
			"turn":
				live = Training.format_value(task, _value)
			"kick", "raley", "dock":
				if task["metric"] == "height" and (game.rider.mode == Rider.Mode.AIR or _hit):
					live = "Höhe " + Training.format_value(task, _max_y)
			"chain":
				live = Training.format_value(task, _count)
			"drift_spin":
				live = "links %d / %d   rechts %d / %d" % [mini(_spins[0], SPIN_EACH), SPIN_EACH, mini(_spins[1], SPIN_EACH), SPIN_EACH]
			"drift_turn":
				if _seg:
					live = Training.format_value(task, _value)
			"drift_after":
				live = "Bester Drift " + Training.format_value(task, _value)
			"special":
				var n := _st_next - 1 if not _cur.is_empty() else _st_next
				if n < task["combo"].size():
					live = "%d. %s: %s" % [n + 1, task["combo"][n].get("name", ""), combo_text(task["combo"][n])]
				live += "     %d geschafft" % _count
		if live != "":
			line += "     " + live
	var b := _best()
	if not is_nan(float(b[1])):
		line += "     Bestwert " + Training.format_value(task, b[1])
	game.hud.set_task(line)
