class_name PadFx
extends Node
## Gamepad-Rückmeldung: Vibration (Landung je nach Fallhöhe, Sturz, Rumpeln, Sprung-Start, leichtes
## Brummen auf dem Slider, Warnung kurz vor dem Seilabriss) und Lichtleiste (DS4/DualSense) in der
## Farbe der Seilzug-Anzeige: grün – gelb – rot. Ohne Gamepad passiert nichts.

const WARN_FROM := 0.8           # Anteil der Seilzug-Grenze: ab hier brummt es (stärker zum Abriss hin)
const TICK := 0.1                # s: Dauer-Vibration in kurzen Stücken neu setzen

var rider: Rider
var active := Callable()         # main.gd: läuft gerade das Spiel (nicht Startseite/Pause)?
var _t := 0.0
var _flash := 0.0                # s: Lichtleiste rot nach einem Sturz
var _light := Color(-1, -1, -1)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS      # Pause: Lichtleiste wieder grün


func _ready() -> void:
	rider.touched_down.connect(func(fall: float) -> void:
		var k := clampf(fall / 9.0, 0.0, 1.0)
		_rumble(0.25 + 0.5 * k, k * k, 0.1 + 0.15 * k))
	rider.crashed.connect(func(_r: String) -> void:
		_rumble(1.0, 1.0, 0.45)
		_flash = 0.8)
	rider.bumped.connect(func() -> void: _rumble(0.5, 0.2, 0.12))
	rider.dock_yanked.connect(func() -> void: _rumble(0.6, 0.9, 0.3))


func _rumble(weak: float, strong: float, sec: float) -> void:
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), sec)


func _process(delta: float) -> void:
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return
	var playing: bool = active.call() if active.is_valid() else true
	var limit := maxf(minf(rider.crash_tension, Rider.CRASH_TENSION), 1.0)
	var ratio := rider.tension_smooth / limit if rider.attached else 0.0
	# Dauer-Vibration in kurzen Stücken: hört von selbst auf (Pause, Startseite)
	_t -= delta
	if playing and _t <= 0.0:
		_t = TICK
		if rider.mode == Rider.Mode.WATER and rider.attached and ratio > WARN_FROM:
			var k := clampf((ratio - WARN_FROM) / (1.0 - WARN_FROM), 0.0, 1.0)
			_rumble(0.2 + 0.6 * k, k * k * 0.7, TICK * 1.3)
		elif rider.is_sliding():
			_rumble(0.12, 0.0, TICK * 1.3)
	# Lichtleiste
	_flash = maxf(_flash - delta, 0.0)
	var c: Color = Hud.ACCENT
	if _flash > 0.0:
		c = Hud.DANGER
	elif playing:
		c = Hud.TensionGauge._color(clampf(ratio, 0.0, 1.0))
	if not _light.is_equal_approx(c):
		_light = c
		for d in pads:
			if Input.has_joy_light(d):
				Input.set_joy_light(d, c)
