class_name DebugParams
extends CanvasLayer
## Debug-Overlay (F4, nur lokal – nicht in der Web-Version): Spielparameter live mit Schiebereglern
## justieren. Die Werte sind `static var` in den Skripten (z. B. Rider.DPRESS_DRAG) und gelten sofort
## für alle Fahrer. Nichts wird gespeichert: „Geänderte kopieren“ legt die Zeilen in die Zwischenablage,
## damit man sie in den Code übernehmen kann. Tasten bleiben beim Spiel (Regler nehmen keinen Fokus).

## Gruppen: [Name, [[Skript, Parameter, min, max], …]]. min/max weglassen = automatisch (0 … 3 × Standard).
const GROUPS := [
	["Drift-Press", [
		["rider", "DPRESS_SPEED", 0.0, 12.0], ["rider", "DPRESS_SIDE", -1.0, 1.0], ["rider", "DPRESS_WRONG", 0.0, 0.8], ["rider", "DPRESS_DRAG", 0.0, 4.0], ["rider", "DPRESS_FALL_ANG", 0.2, 1.57], ["rider", "DPRESS_TURN", 0.05, 2.0],
		["rider", "DPRESS_RISE", 0.2, 10.0], ["rider", "DPRESS_ANG", 0.0, 1.6], ["rider", "DPRESS_END"],
		["challenge", "DPRESS_FULL", 0.0, 1.0]]],
	["Drift", [["rider", "DRIFT_DRAG", 0.0, 2.0], ["rider", "DRIFT_SPIN", 0.0, 4.0], ["rider", "DRIFT_ROPE_GIVE", 0.5, 30.0], ["rider", "DRIFT_ROPE_SETTLE", 0.0, 10.0]]],
	["Fahren", [
		["rider", "DRAG_QUAD"], ["rider", "DRAG_LIN"], ["rider", "PLOW_DRAG"], ["rider", "PLANE_SPEED"],
		["rider", "GRIP_QUAD"], ["rider", "GRIP_LIN"], ["rider", "TURN_RATE"]]],
	["Einsinken", [
		["rider", "SINK_SPEED"], ["rider", "SINK_HOLD_SPEED"], ["rider", "SINK_HOLD_PULL"], ["rider", "SINK_RATE"],
		["rider", "SINK_RECOVER"], ["rider", "SINK_DEPTH"], ["rider", "SWIM_SPEED"]]],
	["Seil", [["rider", "ROPE_STIFFNESS"], ["rider", "ROPE_DAMPING"], ["rider", "CRASH_TENSION", 500.0, 15000.0],
		["rider", "AIR_MAX_TENSION"]]],
	["Sprung", [
		["rider", "POP_BASE"], ["rider", "POP_LOAD"], ["rider", "POP_ROPE"], ["rider", "POP_SCALE", 0.0, 2.0],
		["rider", "POP_ON_RAMP", 0.0, 1.0], ["rider", "KICK_REF"], ["rider", "POP_ON_KICK", 0.0, 2.0],
		["rider", "KICK_MAX_VY"], ["rider", "RAMP_LAUNCH", 0.0, 2.0], ["rider", "AIR_KNEES"], ["rider", "LAND_TIME"]]],
	["Luft", [
		["rider", "SPIN_RATE"], ["rider", "AIR_ASSIST"], ["rider", "FLIP_RATE"], ["rider", "FLIP_LAND_TOL", 0.0, 1.6],
		["rider", "RALEY_SPEED", 0.0, 20.0], ["rider", "RALEY_LOAD", 0.0, 1.0], ["rider", "RALEY_MAX", 0.0, 3.2]]],
	["Slider", [
		["rider", "SLIDE_FRICTION", 0.0, 1.0], ["rider", "PRESS_ANG", 0.0, 1.2], ["rider", "SNAP_RATE"],
		["rider", "SLIDE_TURN"], ["rider", "LOCK_RATE"], ["rider", "LOCK_PULL"], ["rider", "CATCH_GLIDE"],
		["rider", "CATCH_RISE"]]],
	["Sprung-Start", [["rider", "DOCK_BRACE_MAX", 0.1, 1.0], ["rider", "DOCK_YANK_LIFT"], ["rider", "NOLLI_ANG", 0.0, 1.6]]],
	["Punkte", [
		["rider", "SLIDE_BASE"], ["rider", "SLIDE_PER_S"], ["rider", "BOARDSLIDE_BONUS"], ["rider", "PRESS_BONUS"],
		["rider", "SWITCH_BONUS"], ["rider", "AIR_PER_S"], ["rider", "RALEY_POINTS"], ["rider", "FLIP_POINTS"],
		["rider", "COMBO_WINDOW"]]],
]
const SCRIPTS := {"rider": "res://scripts/rider.gd", "challenge": "res://scripts/challenge.gd"}

var rider: Rider                 # Live-Werte oben im Fenster
var _dim: Control
var _live: Label
var _rows: Array[Dictionary] = []   # je Regler: script, name, default, slider, value, label


## Nur lokal: in der Web-Version gibt es das Overlay nicht.
static func available() -> bool:
	return not OS.has_feature("web")


func _init() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_dim = Control.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.9)
	sb.set_corner_radius_all(12)
	sb.border_width_bottom = 3
	sb.border_color = Hud.ACCENT
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -40.0
	panel.offset_right = -16.0
	panel.offset_top = 16.0
	panel.offset_bottom = -16.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var head := HBoxContainer.new()
	var title := Label.new()
	title.text = "DEBUG  ·  Parameter (F4)"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Hud.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("Geänderte kopieren", _copy))
	head.add_child(_button("Alle zurücksetzen", _reset_all))
	head.add_child(_button("Schließen", func() -> void: toggle()))
	box.add_child(head)
	_live = Label.new()
	_live.add_theme_font_size_override("font_size", 15)
	_live.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	box.add_child(_live)

	var notes := _read_comments()
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.focus_mode = Control.FOCUS_NONE
	box.add_child(tabs)
	for g: Array in GROUPS:
		var scroll := ScrollContainer.new()
		scroll.name = g[0]
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 10)
		scroll.add_child(list)
		for e: Array in g[1]:
			_add_row(list, e, notes)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b


## Eine Zeile: Name + Kommentar aus dem Quelltext, Regler, Wert, Standard-Taste.
func _add_row(list: VBoxContainer, e: Array, notes: Dictionary) -> void:
	var script: Script = load(SCRIPTS[e[0]])
	var pname: String = e[1]
	var v: Variant = script.get(pname)
	if v == null:
		push_warning("DebugParams: %s.%s ist keine static var" % [e[0], pname])
		return
	var is_int := v is int
	var def := float(v)
	var lo: float = e[2] if e.size() > 2 else (minf(0.0, def * 3.0))
	var hi: float = e[3] if e.size() > 3 else (maxf(absf(def) * 3.0, 1.0))
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	var line := HBoxContainer.new()
	var name_l := Label.new()
	name_l.text = pname
	name_l.custom_minimum_size.x = 200
	name_l.add_theme_font_size_override("font_size", 16)
	line.add_child(name_l)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 1.0 if is_int else (hi - lo) / 500.0
	slider.value = def
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	line.add_child(slider)
	var val := LineEdit.new()
	val.custom_minimum_size.x = 90
	val.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(val)
	var reset := _button("Std.", Callable())
	reset.tooltip_text = "Standard: %s" % _fmt(def, is_int)
	line.add_child(reset)
	row.add_child(line)
	if notes.has(pname):
		var note := Label.new()
		note.text = "%s   (Standard %s)" % [notes[pname], _fmt(def, is_int)]
		note.add_theme_font_size_override("font_size", 12)
		note.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(note)
	list.add_child(row)
	var r := {"script": script, "file": e[0], "name": pname, "default": def, "int": is_int,
		"slider": slider, "value": val, "label": name_l}
	_rows.append(r)
	slider.value_changed.connect(func(x: float) -> void: _apply(r, x))
	val.text_submitted.connect(func(t: String) -> void:
		var x := t.replace(",", ".").to_float()
		slider.max_value = maxf(slider.max_value, x)
		slider.min_value = minf(slider.min_value, x)
		slider.value = x
		_apply(r, x)
		val.release_focus())
	reset.pressed.connect(func() -> void:
		slider.value = def
		_apply(r, def))
	_show(r)


func _apply(r: Dictionary, x: float) -> void:
	r["script"].set(r["name"], roundi(x) if r["int"] else x)
	_show(r)


func _show(r: Dictionary) -> void:
	var cur := float(r["script"].get(r["name"]))
	r["value"].text = _fmt(cur, r["int"])
	var changed := not is_equal_approx(cur, r["default"])
	r["label"].add_theme_color_override("font_color", Hud.ACCENT if changed else Color.WHITE)


func _fmt(x: float, is_int: bool) -> String:
	if is_int:
		return str(roundi(x))
	return String.num(x, 3)


func _reset_all() -> void:
	for r: Dictionary in _rows:
		r["slider"].value = r["default"]
		_apply(r, r["default"])


## Geänderte Werte als Code-Zeilen in die Zwischenablage (zum Übernehmen in die Skripte).
func _copy() -> void:
	var lines: PackedStringArray = []
	for r: Dictionary in _rows:
		var cur := float(r["script"].get(r["name"]))
		if not is_equal_approx(cur, r["default"]):
			lines.append("%s.gd: static var %s := %s   # war %s" % [r["file"], r["name"],
				_fmt(cur, r["int"]) if r["int"] else str(snappedf(cur, 0.001)), _fmt(r["default"], r["int"])])
	DisplayServer.clipboard_set("\n".join(lines) if not lines.is_empty() else "(nichts geändert)")
	_live.text = "%d geänderte Werte kopiert" % lines.size()


## Kommentare hinter den Parametern aus dem Quelltext (nur lokal lesbar).
func _read_comments() -> Dictionary:
	var out := {}
	for key: String in SCRIPTS:
		var f := FileAccess.open(SCRIPTS[key], FileAccess.READ)
		if f == null:
			continue
		for line in f.get_as_text().split("\n"):
			if not line.begins_with("static var ") or not line.contains("#"):
				continue
			var n := line.substr(11).get_slice(" ", 0).get_slice(":", 0)
			out[n] = line.get_slice("#", 1).strip_edges()
	return out


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.keycode == KEY_F4:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_dim.visible = not _dim.visible


func is_open() -> bool:
	return _dim.visible


func _process(_delta: float) -> void:
	if not _dim.visible or rider == null:
		return
	if _live.text.ends_with("kopiert") and Engine.get_process_frames() % 180 != 0:
		return
	_live.text = "Tempo %.1f km/h   Seilzug %d N   %s   Drift-Press %+.2f   Sinkpegel %.2f" % [
		rider.horizontal_speed() * 3.6, roundi(rider.tension_smooth),
		"DRIFT" if rider.drifting else "kein Drift", rider.drift_press(), rider.sink_level]
