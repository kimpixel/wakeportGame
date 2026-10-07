class_name StartScreen
extends CanvasLayer
## Startbildschirm: Terminal und Feature-Setup wählen, oben die Bahn live in der echten
## Szene (isometrisch von der Seeseite) (Features anklickbar, zusammenstehende Teile = Hack, auf beiden Anlagen fährt ein
## Fahrer), unten das gewählte Feature bzw. der Hack in 3D. Dient auch zum Prüfen der Features.
## Tastatur: T Terminal, F Feature-Setup, ←/→ Feature, Enter Spiel starten.

signal terminal_chosen(terminal: String)
signal setup_chosen(idx: int)
signal start_pressed

var features: FeatureSet
var cable_of := {}               # "T1"/"T2" -> CableSystem
var s_offset := {}               # wie FeatureSet.load_setup: s in der Setup-Datei = s_center - Versatz

var _terminal_opt: OptionButton
var _setup_opt: OptionButton
var _map: FeatureMap
var _preview: FeaturePreview
var _title: Label
var _details: Label
var _result: Label
var _terminal := "T2"
var _terminals: Array = []


func _init() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS


## terminals: z. B. ["T2", "T1"] mit Anzeigenamen; setup_names: Namen aus setups/index.json
func build(terminals: Array, terminal_names: Array, setup_names: Array) -> void:
	_terminals = terminals
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.11)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 16
	root.offset_top = 12
	root.offset_right = -16
	root.offset_bottom = -12
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# oben: Titel + Auswahl
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	root.add_child(top)
	var head := Label.new()
	head.text = "Wakeport Raunheim"
	head.add_theme_font_size_override("font_size", 28)
	top.add_child(head)
	_result = Label.new()
	_result.add_theme_font_size_override("font_size", 22)
	_result.add_theme_color_override("font_color", FeatureMap.COL_SEL)
	_result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_result)
	_terminal_opt = _choice(top, "Terminal", terminal_names)
	_terminal_opt.item_selected.connect(func(i: int) -> void: terminal_chosen.emit(_terminals[i]))
	_setup_opt = _choice(top, "Feature-Setup", setup_names)
	_setup_opt.item_selected.connect(func(i: int) -> void: setup_chosen.emit(i))

	# oben: die Bahn live (Start links, Endmast rechts)
	var lt := Label.new()
	lt.text = "Feature oder Hack anklicken (← →)  –  Doppelklick: heranzoomen, ziehen: verschieben, Rad: Zoom, Rechtsklick: ganze Bahn   |   T Terminal   F Feature-Setup   Enter Start"
	lt.add_theme_font_size_override("font_size", 14)
	lt.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root.add_child(lt)
	_map = FeatureMap.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.size_flags_stretch_ratio = 1.15
	_map.hack_selected.connect(_on_hack)
	root.add_child(_map)

	# unten: gewähltes Feature in 3D | Name und Maße
	var low := HBoxContainer.new()
	low.size_flags_vertical = Control.SIZE_EXPAND_FILL
	low.add_theme_constant_override("separation", 16)
	root.add_child(low)
	_preview = FeaturePreview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_stretch_ratio = 1.3
	low.add_child(_preview)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	low.add_child(info)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", FeatureMap.COL_SEL)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_title)
	_details = Label.new()
	_details.add_theme_font_size_override("font_size", 14)
	_details.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_details)

	# unten: Start
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(bottom)
	var go := Button.new()
	go.text = "Spiel starten"
	go.add_theme_font_size_override("font_size", 26)
	go.custom_minimum_size = Vector2(320, 56)
	go.pressed.connect(func() -> void: start_pressed.emit())
	bottom.add_child(go)


func _choice(parent: Control, title: String, names: Array) -> OptionButton:
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 18)
	parent.add_child(l)
	var opt := OptionButton.new()
	opt.add_theme_font_size_override("font_size", 18)
	opt.custom_minimum_size = Vector2(260, 40)
	for n: String in names:
		opt.add_item(n)
	parent.add_child(opt)
	return opt


## Auswahl und Karte auf den aktuellen Stand bringen (nach Öffnen bzw. Wechsel).
## focus: Index des Hacks, der gleich ausgewählt wird (-1: der erste Hack)
func refresh(terminal: String, setup_idx: int, focus := -1) -> void:
	_terminal = terminal
	_terminal_opt.select(_terminals.find(terminal))
	_setup_opt.select(setup_idx)
	var c: CableSystem = cable_of[terminal]
	_map.set_parts(c, features.parts_of(c))
	if _map.hacks.is_empty():
		_title.text = "Keine Features an " + terminal
		_details.text = ""
		_preview.show_parts([], c)
	else:
		_map.select(clampi(focus, 0, _map.hacks.size() - 1))


## Feature/Hack mit diesem Namensanfang auswählen (Test: --screen-select=…).
func select_by_name(prefix: String) -> void:
	for i in _map.hacks.size():
		if FeatureMap.hack_name(_map.hacks[i]).to_lower().contains(prefix.to_lower()):
			_map.select(i)
			_map.zoom_to(i)
			return


func _on_hack(parts: Array) -> void:
	var c: CableSystem = cable_of[_terminal]
	_title.text = FeatureMap.hack_name(parts)
	_preview.show_parts(parts, c)
	var lines: Array[String] = []
	var sorted := parts.duplicate()
	sorted.sort_custom(func(a: FeaturePart, b: FeaturePart) -> bool: return a.s_center < b.s_center)
	for p: FeaturePart in sorted:
		var dir_l := c.transform.affine_inverse().basis * p.forward_world()
		var h := p.height
		if not p.profile.is_empty():
			h = 0.0
			for pt: Array in p.profile:
				h = maxf(h, float(pt[1]))
		lines.append("%s
    s %.1f m, x %.1f m, %s,  %.1f × %.1f m, h %.2f m" % [
			p.display_name, p.s_center - float(s_offset.get(_terminal, 0.0)), p.x_center, "zum Endmast" if dir_l.z < 0.0 else "zum Ufer",
			p.length, p.width, h])
	_details.text = "\n".join(lines)


# ---------------------------------------------------------------- Tastatur

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.is_echo():
		return
	var k := (event as InputEventKey).physical_keycode
	match k:
		KEY_T:
			terminal_chosen.emit(_terminals[(_terminals.find(_terminal) + 1) % _terminals.size()])
		KEY_F:
			setup_chosen.emit((_setup_opt.selected + 1) % _setup_opt.item_count)
		KEY_RIGHT, KEY_D:
			_map.select_step(1)
			_map.zoom_to(_map.selected)
		KEY_LEFT, KEY_A:
			_map.select_step(-1)
			_map.zoom_to(_map.selected)
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			start_pressed.emit()
		_:
			return
	get_viewport().set_input_as_handled()


## Ergebnis der letzten Runde oben in der Leiste.
func set_result(text: String) -> void:
	_result.text = text
