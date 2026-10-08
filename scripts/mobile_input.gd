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
var ui_blockers: Array = []     # Bedienelemente (z. B. Setup-Menü): Finger darauf starten/springen nicht
var _pressed := ""            # Lenk-Aktion, die dieses Modul gerade hält
var pad: TouchPad             # virtuelle Tasten (▲ ▼ DRIFT ☰)
## Startseite offen: Finger bedienen nur die Oberfläche (als Maus), kein Start/Sprung.
var ui_mode := false:
	set(on):
		ui_mode = on
		if active:
			Input.emulate_mouse_from_touch = on
			if on:
				_touches = 0
var _on_pad := {}             # Finger-Index -> gedrückte PadButton

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
	if t == null or ui_mode:
		return
	if _pad_touch(t):
		get_viewport().set_input_as_handled()
		return
	if t.pressed and _over_ui(t.position):
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


## Finger auf einer virtuellen Taste: Aktion halten bzw. Menü-Befehl beim Loslassen.
## Bei offenem Menü schluckt das Pad alle Finger (kein Sprung). Liefert true, wenn behandelt.
func _pad_touch(t: InputEventScreenTouch) -> bool:
	if pad == null:
		return false
	if not t.pressed:
		if not _on_pad.has(t.index):
			return false
		var b: TouchPad.PadButton = _on_pad[t.index]
		_on_pad.erase(t.index)
		b.set_down(false)
		if b.action != "":
			Input.action_release(b.action)
		else:
			pad.trigger(b.id)
		return true
	var hit := pad.button_at(t.position)
	if hit == null:
		return pad.is_menu_open()
	_on_pad[t.index] = hit
	hit.set_down(true)
	if hit.action != "":
		Input.action_press(hit.action)
	return true


## Alle vom Pad gehaltenen Aktionen loslassen (z. B. beim Öffnen der Startseite).
func release_pad() -> void:
	for b: TouchPad.PadButton in _on_pad.values():
		b.set_down(false)
		if b.action != "":
			Input.action_release(b.action)
	_on_pad.clear()


## Liegt der Finger auf einem sichtbaren Bedienelement (oder ist dessen Popup offen)?
func _over_ui(pos: Vector2) -> bool:
	for c: Variant in ui_blockers:
		if c is Window and (c as Window).visible:
			return true
		if c is Control and (c as Control).is_visible_in_tree() and (c as Control).get_global_rect().has_point(pos):
			return true
	return false


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
	if not tilt_available:
		return          # ohne Sensor nichts anfassen (Tastatur/Gamepad bleiben unberührt)
	var mag := clampf((absf(roll) - DEADZONE) / (MAX_TILT - DEADZONE), 0.0, 1.0)
	var want := ""
	if mag > 0.0:
		want = "steer_right" if roll > 0.0 else "steer_left"
	# nur Aktionen loslassen, die wir selbst gedrückt haben – sonst würde jeder Frame
	# die Tastatur-Lenkung wieder aufheben
	if _pressed != "" and _pressed != want:
		Input.action_release(_pressed)
	if want != "":
		Input.action_press(want, mag)
	_pressed = want
