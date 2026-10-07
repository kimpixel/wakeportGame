class_name Sfx
extends Node
## Einfache Soundeffekte, komplett beim Start synthetisiert (keine Audiodateien nötig):
##  * "Yeah!" / "Wooo!" bei Punkten – das rufen die Leute im T2-Startblock (Steuermann und
##    Gäste), räumlich vom Startsteg aus zu hören (Formant-Synthese, klingt etwas comichaft)
##  * Whoosh beim Absprung, Platschen bei der Landung, großer Platscher beim Sturz
##  * Wasserrauschen abhängig vom Tempo, Grind-Geräusch auf Rails/Boxen
##  * Vögel im Wald
## Taste M schaltet den Ton stumm.

const RATE := 22050

var rider: Rider
var people: Array[Dictionary] = []   # aus Beach: Leute im Startblock

var _yeah: Array[AudioStreamWAV] = []
var _woo: AudioStreamWAV
var _whoosh: AudioStreamWAV
var _splash: AudioStreamWAV
var _thud: AudioStreamWAV
var _crash: AudioStreamWAV
var _chirps: Array[AudioStreamWAV] = []

var _voices: Array[AudioStreamPlayer3D] = []
var _fx: AudioStreamPlayer
var _water: AudioStreamPlayer
var _grind: AudioStreamPlayer
var _bird: AudioStreamPlayer3D

var _prev_mode := Rider.Mode.WATER
var _prev_vy := 0.0
var _bird_t := 3.0
var _muted := false


func _ready() -> void:
	_yeah = [_make_voice("yeah", 1.0), _make_voice("yeah", 1.12), _make_voice("yeah", 0.9)]
	_woo = _make_voice("woo", 1.05)
	_whoosh = _make_whoosh()
	_splash = _make_splash(0.55, 0.5)
	_crash = _make_splash(1.4, 1.0)
	_thud = _make_thud()
	for i in 4:
		_chirps.append(_make_chirp(i))

	# Pro Person im Startblock eine Stimme (laut gerufen, trägt weit übers Wasser)
	for person: Dictionary in people:
		var v := AudioStreamPlayer3D.new()
		v.unit_size = 45.0
		v.volume_db = 4.0
		v.max_db = 6.0
		add_child(v)
		v.global_position = person["pos"]
		_voices.append(v)
	_fx = _player(-4.0)
	_water = _player(-80.0)
	_water.stream = _make_water_loop()
	_water.play()
	_grind = _player(-80.0)
	_grind.stream = _make_grind_loop()
	_grind.play()
	_bird = AudioStreamPlayer3D.new()
	_bird.unit_size = 30.0
	_bird.volume_db = -14.0
	add_child(_bird)

	rider.trick_landed.connect(_on_trick)
	rider.crashed.connect(func(_r: String) -> void: _play(_fx, _crash, 1.0))
	# "Ups" über Boje/Steg: kurzes, helles Plopp
	rider.bumped.connect(func() -> void: _play(_fx, _thud, randf_range(1.6, 1.9)))


func _player(db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = db
	add_child(p)
	return p


func _play(p: AudioStreamPlayer, stream: AudioStream, pitch: float) -> void:
	p.stream = stream
	p.pitch_scale = pitch
	p.play()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("mute"):
		_muted = not _muted
		AudioServer.set_bus_mute(0, _muted)


# ---------------------------------------------------------------- Ereignisse

## Jubel aus dem Startblock: der Steuermann ruft immer, Gäste manchmal mit.
func _on_trick(trick: String, points: int) -> void:
	if _voices.is_empty():
		return
	var big := points >= 250 or trick.begins_with("360") or trick.begins_with("540")
	for i in _voices.size():
		if i > 0 and randf() > 0.55:
			continue
		var v := _voices[i]
		v.stream = _woo if big else _yeah.pick_random()
		v.pitch_scale = float(people[i]["pitch"]) * randf_range(0.96, 1.04)
		# Gäste setzen einen Tick später ein
		if i == 0:
			v.play()
		else:
			get_tree().create_timer(randf_range(0.05, 0.3)).timeout.connect(v.play)


func _process(delta: float) -> void:
	var mode := rider.mode
	var speed := rider.horizontal_speed()
	if mode == Rider.Mode.AIR and _prev_mode == Rider.Mode.WATER and rider.vel.y > 2.0:
		_play(_fx, _whoosh, randf_range(0.9, 1.15))
	if mode == Rider.Mode.WATER and _prev_mode == Rider.Mode.AIR and _prev_vy < -1.5:
		if rider.pos.y > 0.15:
			_play(_fx, _thud, randf_range(0.9, 1.1))         # Landung auf einem Feature
		else:
			_play(_fx, _splash, randf_range(0.85, 1.1))
	_prev_mode = mode
	_prev_vy = rider.vel.y

	# Wasserrauschen nach Tempo, nur wenn das Brett im Wasser ist
	var on_water := mode == Rider.Mode.WATER and rider.pos.y < 0.2
	var target := clampf(speed / 9.0, 0.0, 1.0) * (1.0 if on_water else 0.0)
	var lin := lerpf(db_to_linear(_water.volume_db), target * 0.6, 1.0 - exp(-delta * 6.0))
	_water.volume_db = linear_to_db(maxf(lin, 0.0001))
	_water.pitch_scale = 0.8 + clampf(speed / 9.0, 0.0, 1.0) * 0.5

	# Grinden auf Rail / Box
	var sliding := rider.is_sliding()
	var g := lerpf(db_to_linear(_grind.volume_db), 0.5 if sliding and speed > 1.0 else 0.0, 1.0 - exp(-delta * 15.0))
	_grind.volume_db = linear_to_db(maxf(g, 0.0001))
	_grind.pitch_scale = 0.75 + clampf(speed / 9.0, 0.0, 1.0) * 0.5

	# Vögel im Wald rundherum
	_bird_t -= delta
	if _bird_t <= 0.0:
		_bird_t = randf_range(2.5, 8.0)
		var cam := get_viewport().get_camera_3d()
		if cam:
			var ang := randf() * TAU
			_bird.global_position = cam.global_position + Vector3(cos(ang), 0.3, sin(ang)) * randf_range(25.0, 60.0)
			_bird.stream = _chirps.pick_random()
			_bird.pitch_scale = randf_range(0.9, 1.2)
			_bird.play()


# ---------------------------------------------------------------- Synthese

func _to_wav(s: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(s.size() * 2)
	for i in s.size():
		data.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _normalize(s: PackedFloat32Array, peak := 0.9) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	for i in s.size():
		s[i] *= peak / m
	return s


## Stimme per Formant-Synthese: Grundton + Obertöne, gewichtet mit Resonanzen des Vokaltrakts.
## "yeah" gleitet von /j/ über /e/ nach /a/, "woo" ist ein /u/ mit hochgezogener Tonhöhe.
func _make_voice(word: String, pitch: float) -> AudioStreamWAV:
	var dur := 0.62 if word == "yeah" else 0.75
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(pitch * 1000.0)
	for i in n:
		var t := float(i) / RATE
		var x := t / dur
		var f0: float
		var f1: float
		var f2: float
		var f3: float
		if word == "yeah":
			f0 = (175.0 + 70.0 * sin(clampf(x * 1.6, 0.0, 1.0) * PI * 0.8) - 25.0 * x) * pitch
			var a := smoothstep(0.08, 0.3, x)
			var b := smoothstep(0.3, 0.6, x)
			f1 = lerpf(lerpf(280.0, 560.0, a), 760.0, b)
			f2 = lerpf(lerpf(2250.0, 1850.0, a), 1250.0, b)
			f3 = 2650.0
		else:
			f0 = (200.0 + 140.0 * smoothstep(0.0, 0.5, x) - 40.0 * smoothstep(0.6, 1.0, x)) * pitch
			f1 = 320.0
			f2 = lerpf(900.0, 800.0, x)
			f3 = 2300.0
		f0 *= 1.0 + 0.02 * sin(t * 2.0 * PI * 5.5)   # Vibrato
		phase += f0 / RATE
		var sample := 0.0
		var k := 1
		while k * f0 < 4500.0:
			var hf := k * f0
			var amp := exp(-pow(hf - f1, 2.0) / (2.0 * 90.0 * 90.0)) * 1.0 \
				+ exp(-pow(hf - f2, 2.0) / (2.0 * 120.0 * 120.0)) * 0.6 \
				+ exp(-pow(hf - f3, 2.0) / (2.0 * 160.0 * 160.0)) * 0.3 \
				+ 0.02 / k
			sample += amp * sin(TAU * phase * k)
			k += 1
		sample += rng.randf_range(-0.04, 0.04)                     # Atemgeräusch
		var env := smoothstep(0.0, 0.06, x) * (1.0 - smoothstep(0.75, 1.0, x))
		out[i] = sample * env
	return _to_wav(_normalize(out, 0.8))


func _noise(n: int, seed_value: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = rng.randf_range(-1.0, 1.0)
	return s


## Einfacher Tiefpass (k klein = dumpf).
func _lowpass(s: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var y := 0.0
	for i in s.size():
		y += (s[i] - y) * k
		s[i] = y
	return s


func _make_whoosh() -> AudioStreamWAV:
	var n := int(0.45 * RATE)
	var s := _noise(n, 3)
	var y := 0.0
	for i in n:
		var x := float(i) / n
		var k := lerpf(0.05, 0.35, sin(x * PI))       # Filter öffnet und schließt
		y += (s[i] - y) * k
		s[i] = y * sin(x * PI)
	return _to_wav(_normalize(s, 0.6))


func _make_splash(dur: float, size: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var s := _noise(n, 7 + int(size * 10.0))
	var y := 0.0
	for i in n:
		var x := float(i) / n
		y += (s[i] - y) * lerpf(0.6, 0.08, x)
		var env := exp(-x * 5.0) * smoothstep(0.0, 0.01, x)
		# ein paar Tropfen-Plopps
		var drops := 0.0
		if size > 0.7:
			drops = sin(TAU * 80.0 * x * dur) * exp(-x * 12.0) * 0.6
		s[i] = y * env + drops
	return _to_wav(_normalize(s, 0.75 if size > 0.7 else 0.5))


func _make_thud() -> AudioStreamWAV:
	var n := int(0.3 * RATE)
	var s := _noise(n, 11)
	for i in n:
		var t := float(i) / RATE
		s[i] = sin(TAU * 85.0 * t) * exp(-t * 18.0) + s[i] * exp(-t * 60.0) * 0.4
	return _to_wav(_normalize(s, 0.7))


func _make_water_loop() -> AudioStreamWAV:
	var n := RATE * 2
	var s := _lowpass(_noise(n, 21), 0.12)
	for i in n:
		var x := float(i) / n
		s[i] *= 0.75 + 0.25 * sin(TAU * x * 3.0) * sin(TAU * x * 7.0)
	# weiches Überblenden des Loop-Endes in den Anfang
	var fade := RATE / 10
	for i in fade:
		var a := float(i) / fade
		s[n - fade + i] = lerpf(s[n - fade + i], s[i], a)
	return _to_wav(_normalize(s, 0.7), true)


func _make_grind_loop() -> AudioStreamWAV:
	var n := RATE
	var s := _noise(n, 33)
	var hp := 0.0
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		hp = 0.92 * (hp + s[i] - prev)                   # Hochpass: zischend-metallisch
		prev = s[i]
		var ring := sin(TAU * 1180.0 * t) * 0.25 + sin(TAU * 1873.0 * t) * 0.18 + sin(TAU * 2650.0 * t) * 0.12
		s[i] = hp * 0.5 + ring * (0.6 + 0.4 * sin(TAU * 13.0 * t))
	return _to_wav(_normalize(s, 0.6), true)


func _make_chirp(variant: int) -> AudioStreamWAV:
	var n := int(0.5 * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var phase := 0.0
	var notes := 2 + variant % 3
	for i in n:
		var x := float(i) / n
		var seg := fmod(x * notes, 1.0)
		var f := lerpf(3200.0 + variant * 300.0, 4800.0 - variant * 200.0, seg) if variant % 2 == 0 \
			else lerpf(5200.0, 3400.0, seg)
		phase += f / RATE
		var env := sin(clampf(seg / 0.7, 0.0, 1.0) * PI) * (1.0 - x * 0.5)
		s[i] = sin(TAU * phase) * env
	return _to_wav(_normalize(s, 0.5))
