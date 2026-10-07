class_name MobileInput
extends Node
## Steuerung auf Handy/Tablet im Browser:
##  * Finger auf den Bildschirm: touch_down / touch_up (main.gd: Start bzw. Sprung laden/abspringen)
##  * Handy nach links/rechts neigen = lenken (Neigungssensor über deviceorientation)
## Aktiv, wenn im Browser ein Touchscreen mit Finger-Zeiger erkannt wird, oder mit --mobile (Test).
## Die Neigung wird in Bildschirmkoordinaten gerechnet: funktioniert hoch- und querformatig.

signal touch_down
signal touch_up

const MAX_TILT := 25.0        # Grad Neigung für vollen Lenkausschlag
const DEADZONE := 3.0         # Grad um die Mitte ohne Wirkung

var active := false
var tilt_available := false   # liefert der Sensor Werte (bzw. Erlaubnis erteilt)?
var debug_roll := NAN         # Test: feste Neigung in Grad (--tilt=…)
var _touches := 0

# Läuft im Browser: hört auf deviceorientation (auf iOS erst nach Erlaubnis, die beim ersten
# Antippen erfragt wird – das muss direkt im Touch-Ereignis passieren) und liefert die Neigung
# um die Bildschirm-Normale in Grad (rechts herunter = positiv).
const JS := """
(function () {
	if (window.wpRoll) return;
	var o = {beta: 0, gamma: 0, ok: false};
	function onOri(e) {
		if (e.beta === null || e.gamma === null) return;
		o.beta = e.beta; o.gamma = e.gamma; o.ok = true;
	}
	function listen() { window.addEventListener('deviceorientation', onOri); }
	var needsPermission = typeof DeviceOrientationEvent !== 'undefined'
		&& typeof DeviceOrientationEvent.requestPermission === 'function';
	if (needsPermission) {
		var ask = function () {
			window.removeEventListener('touchend', ask, true);
			DeviceOrientationEvent.requestPermission()
				.then(function (r) { if (r === 'granted') listen(); })
				.catch(function () {});
		};
		window.addEventListener('touchend', ask, true);
	} else {
		listen();
	}
	window.wpRoll = function () {
		if (!o.ok) return null;
		var d = Math.PI / 180, b = o.beta * d, g = o.gamma * d;
		// Richtung "oben" (gegen die Schwerkraft) in Gerätekoordinaten
		var ux = -Math.cos(b) * Math.sin(g), uy = Math.sin(b);
		// auf die x-Achse des Bildschirms projizieren (Bildschirmdrehung beachten)
		var ang = ((screen.orientation && screen.orientation.angle) || window.orientation || 0) * d;
		var sx = ux * Math.cos(ang) - uy * Math.sin(ang);
		return -Math.asin(Math.max(-1, Math.min(1, sx))) / d;
	};
})();
"""


static func detect() -> bool:
	if "--mobile" in OS.get_cmdline_user_args():
		return true
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		var r: Variant = JavaScriptBridge.eval(
			"(navigator.maxTouchPoints > 0) && window.matchMedia('(pointer: coarse)').matches", true)
		return r == true
	return false


func _ready() -> void:
	active = detect()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tilt="):
			debug_roll = arg.substr(7).to_float()
	if not active:
		set_process(false)
		set_process_input(false)
		return
	# Finger sollen nicht als Maus gelten (sonst fängt die Kamera den Zeiger ein)
	Input.emulate_mouse_from_touch = false
	if OS.has_feature("web"):
		JavaScriptBridge.eval(JS, true)


func _input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t == null:
		return
	if t.pressed:
		_touches += 1
		if _touches == 1:
			touch_down.emit()
	else:
		_touches = maxi(_touches - 1, 0)
		if _touches == 0:
			touch_up.emit()
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	var roll := 0.0
	if not is_nan(debug_roll):
		roll = debug_roll
		tilt_available = true
	elif OS.has_feature("web"):
		var v: Variant = JavaScriptBridge.eval("window.wpRoll ? window.wpRoll() : null", true)
		if v != null:
			tilt_available = true
			roll = float(v)
	var mag := clampf((absf(roll) - DEADZONE) / (MAX_TILT - DEADZONE), 0.0, 1.0)
	if roll > 0.0 and mag > 0.0:
		Input.action_press("steer_right", mag)
		Input.action_release("steer_left")
	elif roll < 0.0 and mag > 0.0:
		Input.action_press("steer_left", mag)
		Input.action_release("steer_right")
	else:
		Input.action_release("steer_left")
		Input.action_release("steer_right")
