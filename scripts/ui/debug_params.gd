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
	["Wasserwand", [["sheet", "WALL_BASE", 0.0, 3.0], ["sheet", "WALL_SPEED_MIN", 0.0, 10.0], ["sheet", "WALL_SPEED_MAX", 0.0, 14.0],
		["sheet", "WALL_ANG_LOW", 0.0, 1.5], ["sheet", "WALL_ANG_HIGH", 0.3, 2.4], ["sheet", "WALL_ROPE_MIN", 0.0, 1500.0], ["sheet", "WALL_ROPE_FULL", 200.0, 4000.0],
		["sheet", "WALL_TEMPO_FULL", 1.0, 20.0], ["sheet", "WALL_W_ROPE", 0.0, 2.0], ["sheet", "WALL_W_TEMPO", 0.0, 2.0], ["sheet", "WALL_W_ANGLE", 0.0, 2.0], ["sheet", "WALL_W_JUMP", 0.0, 2.0]]],
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
		["rider", "RALEY_TENSION", 0.0, 5400.0], ["rider", "RALEY_LOAD", 0.0, 1.0], ["rider", "RALEY_ROPE", 0.0, 3.0], ["rider", "RALEY_PER_SPEED", 0.0, 0.5], ["rider", "RALEY_MAX_VY", 4.0, 14.0], ["rider", "RALEY_MAX", 0.0, 3.2], ["rider", "INVERT_SPIN_RALEY", 0.3, 0.95], ["rider", "RALEY_STRETCH", 0.1, 0.8], ["rider", "SBEND_CUT", 0.22, 0.72], ["rider", "RALEY_CUT_RATE", 2.0, 30.0], ["rider", "RALEY_SPIN_ANG", 0.0, 2.8]]],
	["Slider", [
		["rider", "SLIDE_FRICTION", 0.0, 1.0], ["rider", "PRESS_ANG", 0.0, 1.2], ["rider", "SNAP_RATE"],
		["rider", "SLIDE_TURN"], ["rider", "LOCK_RATE"], ["rider", "LOCK_PULL"], ["rider", "CATCH_GLIDE"],
		["rider", "CATCH_RISE"]]],
	["Sprung-Start", [["rider", "DOCK_BRACE_MAX", 0.1, 1.0], ["rider", "DOCK_YANK_LIFT"], ["rider", "NOLLI_ANG", 0.0, 1.6]]],
	["Punkte", [
		["rider", "SLIDE_BASE"], ["rider", "SLIDE_PER_S"], ["rider", "BOARDSLIDE_BONUS"], ["rider", "PRESS_BONUS"],
		["rider", "SWITCH_BONUS"], ["rider", "AIR_PER_S"], ["rider", "RALEY_POINTS"], ["rider", "INVERT_POINTS"], ["rider", "FLIP_POINTS"],
		["rider", "COMBO_WINDOW"]]],
	["Features", [["feature", "WET_DARK", 0.0, 1.0], ["feature", "WET_FRESNEL", 0.0, 1.0], ["feature", "WET_ROUGH", 0.0, 0.5],
		["feature", "WET_COAT", 0.0, 1.0], ["feature", "REFLECT", 0.0, 2.0]]],
]
const SCRIPTS := {"rider": "res://scripts/rider.gd", "challenge": "res://scripts/challenge.gd", "sheet": "res://scripts/spray_sheet.gd",
	"feature": "res://scripts/features/feature_part.gd"}

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


## Kompaktes Panel oben rechts am Rand, feste Pixelgröße (wächst nicht mit dem Fenster): Bereich per
## Auswahlfeld, je Parameter eine Zeile (Name, Regler, Wert, ↺); die Erklärung steht im Tooltip.
const W := 360                    # px Breite
const FONT := 12

var _panel: PanelContainer
var _pages: Array[Control] = []


func _ready() -> void:
	_dim = Control.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.88)
	sb.set_corner_radius_all(6)
	sb.border_width_bottom = 2
	sb.border_color = Hud.ACCENT
	sb.set_content_margin_all(6)
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -W - 4
	_panel.offset_right = -4
	_panel.offset_top = 4
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_dim.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	_panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 3)
	var pick := OptionButton.new()
	pick.focus_mode = Control.FOCUS_NONE
	pick.add_theme_font_size_override("font_size", FONT)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick.tooltip_text = "Debug-Parameter (F4)"
	head.add_child(pick)
	var copy := _button("Kopieren", _copy)
	copy.tooltip_text = "Geänderte Werte als Code-Zeilen in die Zwischenablage"
	head.add_child(copy)
	var reset := _button("Reset", _reset_all)
	reset.tooltip_text = "Alle zurücksetzen"
	head.add_child(reset)
	head.add_child(_button("×", func() -> void: toggle()))
	box.add_child(head)
	_live = Label.new()
	_live.add_theme_font_size_override("font_size", FONT - 1)
	_live.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_live.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_live.custom_minimum_size.x = W - 12
	box.add_child(_live)

	var notes := _read_comments()
	for g: Array in GROUPS:
		pick.add_item(g[0])
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 1)
		list.visible = _pages.is_empty()
		box.add_child(list)
		_pages.append(list)
		for e: Array in g[1]:
			_add_row(list, e, notes)
	pick.item_selected.connect(func(i: int) -> void:
		for k in _pages.size():
			_pages[k].visible = k == i
		_panel.reset_size())


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", FONT)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## Eine Zeile: Name (Tooltip = Kommentar aus dem Quelltext + Standard), Regler, Wert, ↺ (Standard).
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
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 3)
	var name_l := Label.new()
	name_l.text = pname
	name_l.custom_minimum_size.x = 130
	name_l.clip_text = true
	name_l.add_theme_font_size_override("font_size", FONT)
	name_l.mouse_filter = Control.MOUSE_FILTER_PASS
	name_l.tooltip_text = "%s\n%s   (Standard %s)" % [pname, notes.get(pname, ""), _fmt(def, is_int)]
	line.add_child(name_l)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = 1.0 if is_int else (hi - lo) / 500.0
	slider.value = def
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_NONE
	slider.tooltip_text = name_l.tooltip_text
	line.add_child(slider)
	var val := LineEdit.new()
	val.custom_minimum_size.x = 58
	val.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", FONT)
	line.add_child(val)
	var reset := _button("↺", Callable())
	reset.tooltip_text = "Standard: %s" % _fmt(def, is_int)
	line.add_child(reset)
	list.add_child(line)
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
	if r["script"].has_method("debug_changed"):
		r["script"].call("debug_changed")      # z. B. Features: neue Werte in die Materialien übertragen
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
	var mb := event as InputEventMouseButton
	if mb and _dim.visible and _panel.get_global_rect().has_point(mb.position) 			and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		get_viewport().set_input_as_handled()      # über dem Panel zoomt das Mausrad nicht die Kamera
		return
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
	_live.text = "%.1f km/h   Seilzug %d N   %s   D-Press %+.2f   Sink %.2f   Gischt %.2f" % [
		rider.horizontal_speed() * 3.6, roundi(rider.tension_smooth),
		"DRIFT" if rider.drifting else "–", rider.drift_press(), rider.sink_level, rider.spray_strength]
