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


func _ready() -> void:
	var r: Rider = game.rider
	r.jump_landed.connect(_on_landed)
	r.slide_ended.connect(_on_slide)
	r.sank.connect(func() -> void:
		if running and task["kind"] == "turn":
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
	game.features.load_setup(task["setup"], {"T1": game.cable_t1, "T2": game.cable}, game._s_offset())
	game.rider.forget_features()
	game.npc.forget_features()
	_off = float(game._s_offset()["T2"])
	game.rider.rope_length = Training.ROPE
	game.pc.max_speed = Training.SPEED / 3.6
	game.hud.time_title = "VERSUCH"
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
		if task["kind"] == "chain" and _count > 0:
			_value = _count
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
			if _past(s_now, float(task["end_s"]) + _off) and _done_t < 0.0:
				if task["kind"] == "chain" and _count > 0:
					_value = _count
					_hit = true
					_finish(true)
				else:
					_fail("Slider verpasst – kein Wert")
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
	var tg: Dictionary = task.get("target", {})
	if tg.is_empty():
		return true
	if p.s_center < float(tg["s0"]) + _off or p.s_center > float(tg["s1"]) + _off:
		return false
	if signf(p.x_center) != signf(float(tg["side"])):
		return false
	return not tg.has("x") or absf(p.x_center - float(tg["x"])) < 1.5


func _on_landed(info: Dictionary) -> void:
	if not running or _fail_t >= 0.0:
		return
	match task["kind"]:
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


func _on_slide(info: Dictionary) -> void:
	if not running or _fail_t >= 0.0:
		return
	var p: FeaturePart = info["part"]
	if not _in_target(p):
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


## Versuch auswerten, Bestwert speichern, Ergebnis zeigen (Spiel steht).
func _finish(ok: bool) -> void:
	running = false
	var list := Training.tasks(mode_id)
	var medal := 0
	var text := _fail_text
	var new_best := false
	if ok and _hit:
		medal = Training.medal_for(task, _value)
		text = Training.format_value(task, _value)
		new_best = Training.record(mode_id, task, _value) if not game._test_log else false   # Tests speichern nichts
		if medal == 0:
			text += "   –   noch keine Medaille"
		if game._test_log:
			print("CHALLENGE %s/%s Versuch %d: %s Medaille %d" % [mode_id, task["id"], attempt, text, medal])
	elif game._test_log:
		print("CHALLENGE %s/%s Versuch %d: %s" % [mode_id, task["id"], attempt, text])
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
			"kick", "raley":
				if task["metric"] == "height" and (game.rider.mode == Rider.Mode.AIR or _hit):
					live = "Höhe " + Training.format_value(task, _max_y)
			"chain":
				live = Training.format_value(task, _count)
		if live != "":
			line += "     " + live
	var b := _best()
	if not is_nan(float(b[1])):
		line += "     Bestwert " + Training.format_value(task, b[1])
	game.hud.set_task(line)
