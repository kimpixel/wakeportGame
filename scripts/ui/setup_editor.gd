class_name SetupEditor
extends Control
## Setup-Editor (eigene Seite, von der Startseite aus): Feature-Setups für T1 und T2 bauen.
## Links die Bahn in der Draufsicht (technische Darstellung: echte Teile von oben, Raster,
## Seil, Masten, Bojen; umschaltbar auf 3D), rechts Bauteile, Hacks aus allen Setups,
## Eigenschaften der Auswahl mit 3D-Vorschau und das Setup selbst (Vorlage, Speichern, JSON).
## Eigene Setups landen in user://setups (FeatureSet.save_user_setup) und erscheinen danach
## auf der Startseite unter FEATURE-SETUP.
##
## Bedienung: Teil antippen = auswählen (Umschalt = mehrere), ziehen = verschieben,
## leere Fläche ziehen = Karte schieben, Rad = Zoom. Tasten: Pfeile 0,1 m (Umschalt 1 m),
## Q/E drehen 5° (Umschalt 15°), F Richtung, M spiegeln, Strg+D duplizieren, Entf löschen,
## Strg+Z / Strg+Y rückgängig / wiederholen, Esc Auswahl aufheben bzw. zurück.

signal closed
signal saved(id: String, play: bool)
signal plants_saved                # Bepflanzung gespeichert: im Spiel neu aufbauen

const SNAP := 0.1                # m Raster beim Verschieben
const HISTORY := 80
const PICK_MARGIN := 0.3         # m um den Grundriss, der noch als Treffer zählt
const HACK_COLOR := Color(1.0, 0.55, 0.15)
const CATEGORIES := [
	["KICKER & WEDGES", ["ramp"]],
	["BOXEN, LEDGES & CURBS", ["block"]],
	["RAILS & PIPES", ["rail", "pipe", "transition"]],
	["MODULE (MEHRERE TEILE)", ["group"]],
	["SONSTIGES", ["bump", "ball"]],
]

var host: StartScreen            # Stil (Tasten, Schrift) und die echten Seilbahnen
var ui_scale := 1.0              # Skalierung der Startseite (für die Auflösung der Karte)

var _catalog: Dictionary = {}    # parts.json
var _data: Dictionary = {}       # Setup in Arbeit {"name", "T2": [...], "T1": [...]}
var _terminal := "T2"
var _user_id := ""               # eigenes Setup, das gerade bearbeitet wird ("" = noch nicht gespeichert)
var _sel: Array[int] = []        # ausgewählte Zeilen (des aktuellen Terminals)
var _undo: Array[String] = []
var _redo: Array[String] = []
var _last_tag := ""
var _last_tag_t := 0.0
var _dirty := false
var _leave_armed := false
var _hacks: Array = []           # Hacks.group des aktuellen Terminals
var _hack_templates: Array = []  # [{label, where, rows}] aus allen Setups

# Karte
var _vp: SubViewport
var _world: Node3D
var _fs: FeatureSet
var _cables := {}                # "T1"/"T2" -> CableSystem nur für die Koordinaten (nicht im Baum)
var _lane := {}                  # Bahn-Marken des aktuellen Terminals (in Setup-Koordinaten)
var _lane_root: Node3D
var _cam: Camera3D
var _map: Control
var _view: TextureRect
var _overlay: Control
var _status: Label
var _center := Vector2(120.0, 0.0)   # (s, x) in der Bildmitte
var _span := 70.0                # sichtbare Breite quer zum Seil (m)
var _3d := false
var _need_fit := false

# Ziehen
var _press := false
var _drag_mode := ""             # "", "pan", "move"
var _press_px := Vector2.ZERO
var _press_sx := Vector2.ZERO
var _press_row := -1
var _press_shift := false
var _drag_nodes: Array = []      # [[FeaturePart, Ursprungsposition]]
var _drag_delta := Vector2.ZERO

# Seitenleiste
var _body: BoxContainer
var _side: PanelContainer
var _pages: Array[Control] = []
var _tabs: Array[Button] = []
var _name_edit: LineEdit
var _term_buttons: Array[Button] = []
var _btn_3d: Button
var _btn_undo: Button
var _btn_redo: Button
var _sel_box: VBoxContainer      # Inhalt der Seite "Auswahl"
var _preview: FeaturePreview
var _preview_frame: Control
var _hack_list: VBoxContainer
var _setup_info: Label
var _json_edit: TextEdit
var _btn_delete_setup: Button
var _toast: Label
var _toast_t := 0.0

# Pflanzen (Reiter „Pflanzen“, siehe Plants): auf dem Luftbild malen, radieren, Automatik zurückholen
const PLANT_PAGE := 4
const PLANT_HISTORY := 30
const BRUSHES := [0.5, 1.0, 2.0, 3.0, 5.0, 8.0, 12.0]
const DENSITIES := [["locker", 0.6], ["normal", 1.0], ["dicht", 1.6]]
const TOOLS := [["malen", "Malen"], ["radieren", "Radieren"], ["auto", "Automatik"], ["schieben", "Schieben"]]
const LAYER_FILL := {"boden": Color(0.3, 0.85, 1.0, 0.25), "gehoelz": Color(1.0, 0.6, 0.2, 0.25)}
var _plant_mode := false
var _plant_id := "ufergras"
var _plant_tool := "malen"
var _brush := 3.0                # m Radius
var _density := 1.0              # Faktor: größer = dichter
var _plant_undo: Array[String] = []
var _plant_redo: Array[String] = []
var _plants_dirty := false
var _painting := false
var _paint_last := Vector2.INF   # letzter Pinselpunkt (s, x) beim Ziehen
var _brush_px := Vector2(-1.0, -1.0)
var _ground: Node3D              # Luftbild unter der Karte (nur im Reiter „Pflanzen“)
var _plant_buttons := {}
var _tool_buttons := {}
var _density_buttons: Array[Button] = []
var _brush_label: Label
var _plant_info: Label
var _btn_plant_reset: Button


# ---------------------------------------------------------------- Aufbau

func build() -> void:
	_catalog = FeatureSet.read_catalog()
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for t: String in ["T2", "T1"]:
		var c := CableSystem.new()       # nur Koordinaten: Startmast im Ursprung, Seil entlang -z
		c.mast_a_z = 0.0
		_cables[t] = c
	_build_world()
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)
	root.add_child(_build_top_bar())
	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 0)
	root.add_child(_body)
	_body.add_child(_build_map())
	_side = _build_side()
	_body.add_child(_side)
	_toast = host._label("", 22, StartScreen.SEL)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.visible = false
	add_child(_toast)
	tree_exiting.connect(func() -> void:
		if _preview_frame.get_parent() == null:
			_preview_frame.free()
		for c: CableSystem in _cables.values():
			c.free())


func _build_world() -> void:
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_vp.size = Vector2i(800, 600)
	add_child(_vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.07, 0.25, 0.32)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(-60.0), 0.0)
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 250.0
	_vp.add_child(sun)
	_world = Node3D.new()
	_vp.add_child(_world)
	_lane_root = Node3D.new()
	_world.add_child(_lane_root)
	_fs = FeatureSet.new()
	_world.add_child(_fs)
	_cam = Camera3D.new()
	_cam.far = 2000.0
	_vp.add_child(_cam)
	_cam.current = true


func _build_top_bar() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", host._box(Color(0.06, 0.08, 0.1), 0, 8))
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	p.add_child(row)
	var back := host._button("Zurück", 16)
	back.pressed.connect(_on_back)
	row.add_child(back)
	var title := host._label("SETUP-EDITOR", 22, StartScreen.SEL)
	title.custom_minimum_size.y = 48
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Name des Setups"
	_name_edit.custom_minimum_size = Vector2(240, 48)
	_name_edit.add_theme_font_size_override("font_size", 16)
	_name_edit.text_changed.connect(func(t: String) -> void:
		_data["name"] = t
		_dirty = true)
	row.add_child(_name_edit)
	var tg := ButtonGroup.new()
	for t: String in ["T2", "T1"]:
		var b := host._button(t, 16)
		b.toggle_mode = true
		b.button_group = tg
		b.custom_minimum_size.x = 56
		b.tooltip_text = "Terminal 2 (Strand)" if t == "T2" else "Terminal 1 (Lounge-Steg)"
		b.pressed.connect(func() -> void: _set_terminal(t))
		row.add_child(b)
		_term_buttons.append(b)
	_btn_undo = host._button("Rückgängig", 16)
	_btn_undo.tooltip_text = "Strg+Z"
	_btn_undo.pressed.connect(_undo_step)
	row.add_child(_btn_undo)
	_btn_redo = host._button("Wiederholen", 16)
	_btn_redo.tooltip_text = "Strg+Y"
	for b: Button in [_btn_undo, _btn_redo]:
		var dis := host._box(Color(0.1, 0.12, 0.14, 0.6), 12)
		dis.border_color = Color(1, 1, 1, 0.15)
		b.add_theme_stylebox_override("disabled", dis)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))
	_btn_redo.pressed.connect(_redo_step)
	row.add_child(_btn_redo)
	_btn_3d = host._button("3D", 16)
	_btn_3d.toggle_mode = true
	_btn_3d.custom_minimum_size.x = 56
	_btn_3d.toggled.connect(func(on: bool) -> void:
		_3d = on
		_update_cam())
	row.add_child(_btn_3d)
	var save := host._button("SPEICHERN", 16, true)
	save.pressed.connect(func() -> void: _save(false))
	row.add_child(save)
	var play := host._button("SPEICHERN & FAHREN", 16, true)
	play.pressed.connect(func() -> void: _save(true))
	row.add_child(play)
	return p


func _build_map() -> Control:
	_map = Control.new()
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.clip_contents = true
	_map.resized.connect(_resize_view)
	_view = TextureRect.new()
	_view.texture = _vp.get_texture()
	_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_view.stretch_mode = TextureRect.STRETCH_SCALE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_view.gui_input.connect(_map_input)
	_map.add_child(_view)
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	_map.add_child(_overlay)
	# Zoom-Tasten rechts oben (Handy: kein Mausrad)
	var zoom := VBoxContainer.new()
	zoom.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	zoom.offset_left = -70.0
	zoom.offset_right = -10.0
	zoom.offset_top = 10.0
	zoom.add_theme_constant_override("separation", 6)
	_map.add_child(zoom)
	for z: Array in [["+", 1.0 / 1.4], ["−", 1.4]]:
		var b := host._button(z[0], 24)
		b.custom_minimum_size = Vector2(56, 52)
		var f: float = z[1]
		b.pressed.connect(func() -> void: _zoom_at(_map.size * 0.5, f))
		zoom.add_child(b)
	var fit := host._button("[ ]", 18)
	fit.tooltip_text = "Ganze Bahn zeigen"
	fit.custom_minimum_size = Vector2(56, 52)
	fit.pressed.connect(_fit)
	zoom.add_child(fit)
	_status = host._label("", 15, Color(1, 1, 1, 0.75))
	_status.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_status.offset_left = 12.0
	_status.offset_top = -30.0
	_status.offset_bottom = -6.0
	_status.clip_text = true
	_map.add_child(_status)
	return _map


func _build_side() -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", host._box(Color(0.06, 0.08, 0.1), 0, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	# Reiter umbrechen, wenn die Leiste zu schmal ist (fünf Reiter)
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", 6)
	tabs.add_theme_constant_override("v_separation", 6)
	v.add_child(tabs)
	var tg := ButtonGroup.new()
	for title: String in ["Teile", "Hacks", "Auswahl", "Setup", "Pflanzen"]:
		var b := host._button(title, 16)
		b.toggle_mode = true
		b.button_group = tg
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := _tabs.size()
		b.pressed.connect(func() -> void: _show_page(idx))
		tabs.add_child(b)
		_tabs.append(b)
		var scroll := ScrollContainer.new()
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(scroll)
		var page := VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 8)
		scroll.add_child(page)
		_pages.append(scroll)
	_fill_parts(_pages[0].get_child(0))
	_hack_list = _pages[1].get_child(0)
	_hack_list.add_child(host._small("Hacks werden beim Öffnen gesammelt …"))
	_sel_box = _pages[2].get_child(0)
	_build_setup_page(_pages[3].get_child(0))
	_build_plant_page(_pages[PLANT_PAGE].get_child(0))
	# 3D-Vorschau der Auswahl (bleibt bestehen, wird beim Füllen der Seite neu eingehängt)
	_preview_frame = Control.new()
	_preview_frame.custom_minimum_size = Vector2(0, 220)
	_preview_frame.clip_contents = true
	_preview = FeaturePreview.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview_frame.add_child(_preview)
	_show_page(0)
	return p


func _show_page(idx: int) -> void:
	for i in _pages.size():
		_pages[i].visible = i == idx
	for i in _tabs.size():
		_tabs[i].set_pressed_no_signal(i == idx)
	if idx == 1 and _hack_templates.is_empty():
		_collect_hacks()
	var plants := idx == PLANT_PAGE
	if plants != _plant_mode:
		_plant_mode = plants
		if _ground:
			_ground.visible = plants
		if plants:
			_update_plant_ui()
		_clamp_center()
		_update_cam()
		_update_info()


## Bauteile aus parts.json, nach Art sortiert. Antippen = in die Bildmitte stellen.
func _fill_parts(page: VBoxContainer) -> void:
	page.add_child(_hint("Antippen stellt das Teil in die Mitte der Karte. Danach ziehen, drehen, Richtung wählen."))
	for cat: Array in CATEGORIES:
		var ids: Array = []
		for id: String in _catalog:
			if id.begins_with("_") or not (_catalog[id] is Dictionary):
				continue
			if str(_catalog[id].get("type", "block")) in cat[1]:
				ids.append(id)
		if ids.is_empty():
			continue
		ids.sort_custom(func(a: String, b: String) -> bool: return _part_name(a).naturalnocasecmp_to(_part_name(b)) < 0)
		page.add_child(host._small(cat[0]))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		page.add_child(grid)
		for id: String in ids:
			var b := host._button(_part_name(id), 16)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.clip_text = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = _part_info(id)
			b.pressed.connect(func() -> void: _add_part(id))
			grid.add_child(b)


func _build_setup_page(page: VBoxContainer) -> void:
	_setup_info = host._label("", 16, Color(1, 1, 1, 0.85))
	_setup_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_setup_info)
	page.add_child(host._small("VORLAGE LADEN   (ersetzt beide Terminals)"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	grid.name = "Vorlagen"
	page.add_child(grid)
	page.add_child(host._small("TERMINAL"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	var clear := host._button("Terminal leeren", 16)
	clear.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear.pressed.connect(func() -> void:
		_begin()
		_data[_terminal] = []
		_sel.clear()
		_rebuild())
	row.add_child(clear)
	var copy := host._button("Vom anderen Terminal", 16)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.tooltip_text = "Teile des anderen Terminals hierher kopieren (ersetzt dieses Terminal)"
	copy.pressed.connect(func() -> void:
		_begin()
		_data[_terminal] = (_data.get(_other(), []) as Array).duplicate(true)
		_sel.clear()
		_rebuild())
	row.add_child(copy)
	page.add_child(host._small("JSON   (zum Weitergeben oder für setups/ im Projekt)"))
	_json_edit = TextEdit.new()
	_json_edit.custom_minimum_size = Vector2(0, 150)
	_json_edit.placeholder_text = "Hier ein Setup-JSON einfügen und „Aus Text laden“ drücken"
	_json_edit.add_theme_font_size_override("font_size", 13)
	_json_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	page.add_child(_json_edit)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 6)
	page.add_child(jrow)
	var exp := host._button("Als JSON kopieren", 16)
	exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp.pressed.connect(func() -> void:
		var txt := _export_json()
		_json_edit.text = txt
		DisplayServer.clipboard_set(txt)
		_show_toast("JSON in die Zwischenablage kopiert"))
	jrow.add_child(exp)
	var imp := host._button("Aus Text laden", 16)
	imp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	imp.pressed.connect(_import_json)
	jrow.add_child(imp)
	_btn_delete_setup = host._button("Eigenes Setup löschen", 16)
	_btn_delete_setup.pressed.connect(_delete_setup)
	page.add_child(_btn_delete_setup)


func _fill_templates() -> void:
	var grid: GridContainer = _pages[3].get_child(0).get_node("Vorlagen")
	for c in grid.get_children():
		c.queue_free()
	var empty := host._button("Leeres Setup", 16)
	empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	empty.pressed.connect(func() -> void:
		_begin()
		_load({"name": "Eigenes Setup", "T2": [], "T1": []}, ""))
	grid.add_child(empty)
	for e: Dictionary in FeatureSet.list_setups():
		var b := host._button(str(e["name"]).get_slice(" (", 0), 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.tooltip_text = str(e["name"])
		var entry := e
		b.pressed.connect(func() -> void:
			_begin()
			_load_entry(entry))
		grid.add_child(b)


# ---------------------------------------------------------------- Öffnen / Schließen

## Editor zeigen. entry: Setup aus FeatureSet.list_setups() als Ausgangspunkt (ungespeicherte
## Arbeit bleibt erhalten).
func open(entry: Dictionary, terminal: String) -> void:
	visible = true
	_leave_armed = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_fill_templates()
	if _data.is_empty() or not _dirty:
		_undo.clear()
		_redo.clear()
		_load_entry(entry)
		_dirty = false
	_set_terminal(terminal if terminal in _cables else "T2", true)
	_need_fit = true
	_resize_view()


func _close() -> void:
	visible = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func _on_back() -> void:
	if (_dirty or _plants_dirty) and not _leave_armed:
		_leave_armed = true
		_show_toast("Nicht gespeichert! Nochmal „Zurück“ = trotzdem verlassen (bleibt bis zum Neuladen erhalten)")
		return
	_close()


func _load_entry(entry: Dictionary) -> void:
	var d := FeatureSet.read_setup(entry.get("file", ""))
	if entry.get("user", false):
		_load(d, str(entry.get("id", "")))
	else:
		d["name"] = "Mein " + str(d.get("name", entry.get("name", "Setup"))).get_slice(" (", 0)
		_load(d, "")


func _load(d: Dictionary, user_id: String) -> void:
	_data = d.duplicate(true)
	for t: String in _cables:
		if not (_data.get(t) is Array):
			_data[t] = []
	_user_id = user_id
	_name_edit.text = str(_data.get("name", ""))
	_sel.clear()
	_dirty = true
	_rebuild()


func _set_terminal(t: String, force := false) -> void:
	if t == _terminal and not force:
		return
	_terminal = t
	_mark_terminal()
	_sel.clear()
	_build_lane()
	_rebuild()
	if not force:
		_fit()


func _mark_terminal() -> void:
	for i in _term_buttons.size():
		_term_buttons[i].set_pressed_no_signal((i == 0) == (_terminal == "T2"))


func _other() -> String:
	return "T1" if _terminal == "T2" else "T2"


func _rows() -> Array:
	return _data.get(_terminal, [])


# ---------------------------------------------------------------- Bahn (Seil, Masten, Bojen, Raster)

## Marken der Bahn in Setup-Koordinaten: die Setups sind gegenüber dem Spiel um s_offset
## verschoben (Startmast liegt bei s = -s_offset).
func _build_lane() -> void:
	for c in _lane_root.get_children():
		c.free()
	var real: CableSystem = host.cable_of[_terminal]
	var off: float = host.s_offset.get(_terminal, 0.0)
	var a := -off
	var b := real.mast_a_z - real.mast_b_z - off
	var ta := real.mast_a_z - real.turn_a_z - off
	var tb := real.mast_a_z - real.turn_b_z - off
	_lane = {"mast_a": a, "mast_b": b, "turn_a": ta, "turn_b": tb,
		"red_a": ta + TurnBuoys.RED_BEFORE, "red_b": tb - TurnBuoys.RED_BEFORE}
	# Raster: 5 m fein, 10 m kräftiger
	var x_max := 50.0
	for major: bool in [false, true]:
		var im := ImmediateMesh.new()
		im.surface_begin(Mesh.PRIMITIVE_LINES)
		var step := 10.0 if major else 5.0
		var s0 := floorf((a - 10.0) / step) * step
		var s := s0
		while s <= b + 10.0:
			if major or fmod(absf(s), 10.0) > 0.1:
				im.surface_add_vertex(Vector3(-x_max, 0.01, -s))
				im.surface_add_vertex(Vector3(x_max, 0.01, -s))
			s += step
		var x := -x_max
		while x <= x_max:
			if (major and fmod(absf(x), 10.0) < 0.1) or (not major and fmod(absf(x), 10.0) > 0.1):
				im.surface_add_vertex(Vector3(x, 0.01, -(a - 10.0)))
				im.surface_add_vertex(Vector3(x, 0.01, -(b + 10.0)))
			x += 5.0
		im.surface_end()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(1, 1, 1, 0.22 if major else 0.09)
		mi.material_override = m
		_lane_root.add_child(mi)
	# Seil (dunkle Linie) und Masten
	var rope := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 0.04, b - a)
	rope.mesh = bm
	rope.position = Vector3(0.0, 0.03, -(a + b) * 0.5)
	rope.material_override = _flat(Color(0.02, 0.03, 0.04))
	_lane_root.add_child(rope)
	for s: float in [a, b]:
		_marker(Vector3(0.0, 0.0, -s), 1.2, Color(0.75, 0.77, 0.8), 3.0)
	# Bojen: rot mittig vor der Wende, weiß links/rechts kurz davor
	for s: float in [_lane["red_a"], _lane["red_b"]]:
		_marker(Vector3(0.0, 0.0, -s), 0.6, Color(0.95, 0.15, 0.1), 0.6)
	for k: Array in [[ta, 1.0], [tb, -1.0]]:
		var ws: float = k[0] + k[1] * TurnBuoys.WHITE_BEFORE
		for side: float in [-1.0, 1.0]:
			_marker(Vector3(side * TurnBuoys.WHITE_SIDE, 0.0, -ws), 0.6, Color(0.96, 0.96, 0.94), 0.6)
	# Luftbild (grob weit, fein um die Anlagen) als Untergrund zum Pflanzen-Malen
	_ground = Node3D.new()
	_ground.visible = _plant_mode
	_lane_root.add_child(_ground)
	for k: Array in [[Geo.area, "dop_wide.jpg", -0.06], [Geo.core, "dop_core.jpg", -0.04]]:
		var r: Rect2 = k[0]
		# Bild oben = Norden: NW, NO, SO, SW (Rechteck relativ zum Ursprung, Position = Südwest-Ecke)
		var corners := [Vector2(r.position.x, r.end.y), r.end, Vector2(r.end.x, r.position.y), r.position]
		var uvs := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in [0, 1, 2, 0, 2, 3]:
			var g := Geo.rel_to_game(corners[i].x, corners[i].y)
			var sx := _world_to_sx(g)
			st.set_uv(uvs[i])
			st.add_vertex(Vector3(sx.y, k[2], -sx.x))
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_texture = load(Geo.DIR + k[1])
		mi.material_override = m
		_ground.add_child(mi)


## Setup-Koordinaten (s, x) des aktuellen Terminals -> Spielkoordinaten (x, z).
func _sx_to_world(sx: Vector2) -> Vector2:
	var real: CableSystem = host.cable_of[_terminal]
	var off: float = host.s_offset.get(_terminal, 0.0)
	var w := real.transform * Vector3(sx.y, 0.0, real.mast_a_z - sx.x - off)
	return Vector2(w.x, w.z)


## Spielkoordinaten (x, z) -> Setup-Koordinaten (s, x) des aktuellen Terminals.
func _world_to_sx(g: Vector2) -> Vector2:
	var real: CableSystem = host.cable_of[_terminal]
	var off: float = host.s_offset.get(_terminal, 0.0)
	var l := real.transform.affine_inverse() * Vector3(g.x, 0.0, g.y)
	return Vector2(real.mast_a_z - l.z - off, l.x)


func _marker(pos: Vector3, r: float, c: Color, h: float) -> void:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r
	cy.height = h
	mi.mesh = cy
	mi.position = pos + Vector3(0.0, h * 0.5 - 0.1, 0.0)
	mi.material_override = _flat(c)
	_lane_root.add_child(mi)


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m


# ---------------------------------------------------------------- Kamera

func _resize_view() -> void:
	if _map == null:
		return
	var px := (_map.size * ui_scale).round()
	_vp.size = Vector2i(maxi(int(px.x), 16), maxi(int(px.y), 16))
	if _need_fit and _map.size.x > 100.0 and visible:
		_need_fit = false
		_fit()
	_update_cam()


## Draufsicht: s nach rechts, +x (rechts mit Blick zum Endmast) nach unten.
## 3D: schräg von der rechten Seite, gleicher Ausschnitt.
func _update_cam() -> void:
	if _cam == null:
		return
	var target := Vector3(_center.y, 0.0, -_center.x)
	if _3d:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		_cam.fov = 45.0
		var dist := _span * 1.25
		var pitch := 0.8
		_cam.look_at_from_position(target + Vector3(cos(pitch), sin(pitch), 0.0) * dist, target, Vector3.UP)
	else:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		_cam.keep_aspect = Camera3D.KEEP_HEIGHT
		_cam.size = _span
		_cam.look_at_from_position(target + Vector3(0.0, 300.0, 0.0), target, Vector3(-1.0, 0.0, 0.0))
	_overlay.queue_redraw()


## Bildschirmpunkt (Einheiten in der Karte) -> (s, x) auf der Wasseroberfläche.
func _screen_to_sx(p: Vector2) -> Vector2:
	var k := Vector2(_vp.size) / _map.size
	var o := _cam.project_ray_origin(p * k)
	var d := _cam.project_ray_normal(p * k)
	if absf(d.y) < 1e-4:
		return _center
	var hit := o + d * (-o.y / d.y)
	return Vector2(-hit.z, hit.x)


func _world_to_screen(w: Vector3) -> Vector2:
	return _cam.unproject_position(w) * (_map.size / Vector2(_vp.size))


func _sx_to_screen(s: float, x: float, y := 0.0) -> Vector2:
	return _world_to_screen(Vector3(x, y, -s))


func _zoom_at(p: Vector2, f: float) -> void:
	var before := _screen_to_sx(p)
	_span = clampf(_span * f, 6.0, 600.0 if _plant_mode else 300.0)
	_update_cam()
	var after := _screen_to_sx(p)
	_center += before - after
	_clamp_center()
	_update_cam()


func _clamp_center() -> void:
	if _lane.is_empty():
		return
	# Pflanzen: auch die Ufer weiter weg (Strand, Seitenufer, hinter dem Endmast)
	var more := 150.0 if _plant_mode else 0.0
	_center.x = clampf(_center.x, _lane["mast_a"] - 20.0 - more, _lane["mast_b"] + 20.0 + more)
	_center.y = clampf(_center.y, -60.0 - more * 1.5, 60.0 + more * 1.5)


## Ganze Bahn bzw. alle Teile zeigen.
func _fit() -> void:
	if _lane.is_empty() or _map.size.x < 10.0:
		return
	var lo: float = _lane["turn_a"]
	var hi: float = _lane["turn_b"]
	var xs := Vector2(-12.0, 12.0)
	for p: FeaturePart in _fs.parts:
		xs.x = minf(xs.x, p.x_center - p.width)
		xs.y = maxf(xs.y, p.x_center + p.width)
	_center = Vector2((lo + hi) * 0.5, (xs.x + xs.y) * 0.5)
	var aspect := _map.size.x / maxf(_map.size.y, 1.0)
	_span = clampf(maxf((hi - lo) * 1.06 / aspect, (xs.y - xs.x) * 1.3), 10.0, 300.0)
	if _3d:
		_span *= 0.7
	_update_cam()


# ---------------------------------------------------------------- Eingabe auf der Karte

func _map_input(event: InputEvent) -> void:
	if _plant_mode and _plant_input(event):
		_view.accept_event()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(mb.position, 1.0 / 1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(mb.position, 1.15)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_press = true
				_press_px = mb.position
				_press_sx = _screen_to_sx(mb.position)
				_press_shift = mb.shift_pressed or mb.ctrl_pressed
				_press_row = _pick(_press_sx) if mb.button_index == MOUSE_BUTTON_LEFT else -1
				_drag_mode = "pan" if mb.button_index != MOUSE_BUTTON_LEFT else ""
				if mb.double_click and _press_row >= 0:
					_select_hack_of(_press_row)
					_press = false
			elif _press:
				_release()
		_view.accept_event()
	elif event is InputEventMouseMotion and _press:
		var mm := event as InputEventMouseMotion
		if _drag_mode == "" and mm.position.distance_to(_press_px) > 6.0:
			_drag_mode = "move" if _press_row >= 0 else "pan"
			if _drag_mode == "move":
				if not (_press_row in _sel):
					if not _press_shift:
						_sel.clear()
					_sel.append(_press_row)
					_sync_selection()
				_drag_nodes.clear()
				for p: FeaturePart in _fs.parts:
					if p.row_index in _sel:
						_drag_nodes.append([p, p.position])
		var now := _screen_to_sx(mm.position)
		if _drag_mode == "pan":
			_center += _press_sx - now
			_clamp_center()
			_update_cam()
		elif _drag_mode == "move":
			var d := now - _press_sx
			_drag_delta = Vector2(snappedf(d.x, SNAP), snappedf(d.y, SNAP))
			for e: Array in _drag_nodes:
				(e[0] as FeaturePart).position = (e[1] as Vector3) + Vector3(_drag_delta.y, 0.0, -_drag_delta.x)
			_status.text = "verschieben   s %+.1f m   x %+.1f m" % [_drag_delta.x, _drag_delta.y]
			_overlay.queue_redraw()
		_view.accept_event()


func _release() -> void:
	_press = false
	if _drag_mode == "move":
		_drag_nodes.clear()
		if _drag_delta != Vector2.ZERO:
			_begin()
			for i in _sel:
				var r: Dictionary = _rows()[i]
				r["s"] = snappedf(float(r.get("s", 0.0)) + _drag_delta.x, 0.01)
				r["x"] = snappedf(float(r.get("x", 0.0)) + _drag_delta.y, 0.01)
			_drag_delta = Vector2.ZERO
		_rebuild()
	elif _drag_mode == "":
		# Tippen: auswählen (Umschalt/Strg: hinzufügen bzw. abwählen)
		if _press_row < 0:
			if not _press_shift:
				_sel.clear()
		elif _press_shift:
			if _press_row in _sel:
				_sel.erase(_press_row)
			else:
				_sel.append(_press_row)
		else:
			_sel = [_press_row]
		_sync_selection()
		if not _sel.is_empty():
			_show_page(2)
	_drag_mode = ""


## Zeile des Teils unter (s, x) oder -1 (kleinstes Teil gewinnt, z. B. Rail neben der Pyramid).
func _pick(sx: Vector2) -> int:
	var best := -1
	var best_a := INF
	for p: FeaturePart in _fs.parts:
		var uv := p.to_uv(Vector3(sx.y, 0.0, -sx.x))
		if absf(uv.x) <= p.length * 0.5 + PICK_MARGIN and absf(uv.y) <= p.width * 0.5 + PICK_MARGIN:
			var a := p.length * p.width
			if a < best_a:
				best_a = a
				best = p.row_index
	return best


func _select_hack_of(row: int) -> void:
	for hack: Array in _hacks:
		for p: FeaturePart in hack:
			if p.row_index == row:
				_sel.clear()
				for q: FeaturePart in hack:
					if not (q.row_index in _sel):
						_sel.append(q.row_index)
				_sync_selection()
				_show_page(2)
				return


# ---------------------------------------------------------------- Tastatur

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			focus.release_focus()
			get_viewport().set_input_as_handled()
		return
	var k := event as InputEventKey
	var big := k.shift_pressed
	match k.keycode:
		KEY_ESCAPE:
			if not _sel.is_empty():
				_sel.clear()
				_sync_selection()
			else:
				_on_back()
		KEY_DELETE, KEY_BACKSPACE:
			_delete_sel()
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN:
			var step := 1.0 if big else SNAP
			var d := {KEY_LEFT: Vector2(-step, 0), KEY_RIGHT: Vector2(step, 0),
				KEY_UP: Vector2(0, -step), KEY_DOWN: Vector2(0, step)}[k.keycode] as Vector2
			_move_sel(d)
		KEY_Q:
			_rotate_sel(15.0 if big else 5.0)
		KEY_E:
			_rotate_sel(-15.0 if big else -5.0)
		KEY_F:
			_flip_sel()
		KEY_M:
			_mirror_sel()
		KEY_D:
			if k.ctrl_pressed:
				_duplicate_sel()
		KEY_Z:
			if k.ctrl_pressed:
				if k.shift_pressed:
					_redo_step()
				else:
					_undo_step()
		KEY_Y:
			if k.ctrl_pressed:
				_redo_step()
		KEY_A:
			if k.ctrl_pressed:
				_sel.clear()
				for i in _rows().size():
					_sel.append(i)
				_sync_selection()
	# alle Tasten abfangen: das Spiel und die Startseite dahinter sollen nicht reagieren
	get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- Bearbeiten

## Vor jeder Änderung: Stand für "Rückgängig" merken. tag fasst schnelle Wiederholungen
## (z. B. Pfeiltasten) zu einem Schritt zusammen.
func _begin(tag := "") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if tag != "" and tag == _last_tag and now - _last_tag_t < 1.5:
		_last_tag_t = now
		return
	_last_tag = tag
	_last_tag_t = now
	_undo.append(JSON.stringify([_data, _terminal, _sel]))
	if _undo.size() > HISTORY:
		_undo.pop_front()
	_redo.clear()
	_dirty = true
	_leave_armed = false


func _undo_step() -> void:
	if _plant_mode:
		_plant_step(true)
		return
	if _undo.is_empty():
		return
	_redo.append(JSON.stringify([_data, _terminal, _sel]))
	_restore(_undo.pop_back())


func _redo_step() -> void:
	if _plant_mode:
		_plant_step(false)
		return
	if _redo.is_empty():
		return
	_undo.append(JSON.stringify([_data, _terminal, _sel]))
	_restore(_redo.pop_back())


func _restore(snap: String) -> void:
	var a: Array = JSON.parse_string(snap)
	_data = a[0]
	_name_edit.text = str(_data.get("name", ""))
	_last_tag = ""
	_dirty = true
	var t: String = a[1]
	_sel.clear()
	if t != _terminal:
		_terminal = t
		_mark_terminal()
		_build_lane()
	for i: Variant in a[2]:
		_sel.append(int(i))
	_rebuild()


## Teile neu aufbauen (nach jeder Änderung) und Hacks erkennen.
func _rebuild() -> void:
	var c: CableSystem = _cables[_terminal]
	_fs.load_data(_data, {_terminal: c}, {}, "Editor")
	_hacks = Hacks.group(_fs.parts_of(c), c)
	var n := _rows().size()
	_sel.assign(_sel.filter(func(i: int) -> bool: return i < n))
	_btn_undo.disabled = _undo.is_empty()
	_btn_redo.disabled = _redo.is_empty()
	_sync_selection()
	_update_info()


func _add_part(id: String) -> void:
	_begin()
	var row := {"part": id, "s": snappedf(_center.x, 0.5), "x": snappedf(_center.y, 0.5)}
	var e: Dictionary = _catalog.get(id, {})
	if e.get("type", "") not in ["ball", "bump"]:
		row["dir"] = "out"
	_rows().append(row)
	_sel = [_rows().size() - 1]
	_rebuild()
	_show_toast(_part_name(id) + " eingefügt")


## Hack aus einem Setup einfügen: gleiche Anordnung, Mitte bei der Bildmitte (s),
## seitlich wie im Original.
func _add_hack(t: Dictionary) -> void:
	_begin()
	var rows: Array = t["rows"]
	var mid := 0.0
	for r: Dictionary in rows:
		mid += float(r.get("s", 0.0))
	mid /= rows.size()
	_sel.clear()
	for r: Dictionary in rows:
		var nr := r.duplicate(true)
		nr["s"] = snappedf(float(r.get("s", 0.0)) - mid + snappedf(_center.x, 0.5), 0.01)
		_rows().append(nr)
		_sel.append(_rows().size() - 1)
	_rebuild()
	_show_page(2)
	_show_toast(str(t["label"]) + " eingefügt")


func _delete_sel() -> void:
	if _sel.is_empty():
		return
	_begin()
	var keep: Array = []
	for i in _rows().size():
		if not (i in _sel):
			keep.append(_rows()[i])
	_data[_terminal] = keep
	_sel.clear()
	_rebuild()


func _move_sel(d: Vector2) -> void:
	if _sel.is_empty():
		return
	_begin("move")
	for i in _sel:
		var r: Dictionary = _rows()[i]
		r["s"] = snappedf(float(r.get("s", 0.0)) + d.x, 0.01)
		r["x"] = snappedf(float(r.get("x", 0.0)) + d.y, 0.01)
	_rebuild()


## Mitte der Auswahl (s, x).
func _sel_center() -> Vector2:
	var c := Vector2.ZERO
	for i in _sel:
		c += Vector2(float(_rows()[i].get("s", 0.0)), float(_rows()[i].get("x", 0.0)))
	return c / maxf(_sel.size(), 1.0)


## Drehen um die Hochachse (Grad, + = gegen den Uhrzeiger von oben). Mehrere Teile drehen
## gemeinsam um ihre Mitte. Ab 90° Abweichung wird daraus die andere Richtung (dir).
func _rotate_sel(deg: float) -> void:
	if _sel.is_empty():
		return
	_begin("rot")
	var c := _sel_center()
	var b := Basis(Vector3.UP, deg_to_rad(deg))
	for i in _sel:
		var r: Dictionary = _rows()[i]
		if _sel.size() > 1:
			var off := b * Vector3(float(r.get("x", 0.0)) - c.y, 0.0, -(float(r.get("s", 0.0)) - c.x))
			r["s"] = snappedf(c.x - off.z, 0.01)
			r["x"] = snappedf(c.y + off.x, 0.01)
		_set_yaw(r, float(r.get("yaw", 0.0)) + deg)
	_rebuild()


func _set_yaw(r: Dictionary, yaw: float) -> void:
	yaw = wrapf(yaw, -180.0, 180.0)
	if absf(yaw) > 90.0 and r.has("dir"):
		r["dir"] = "out" if r["dir"] == "in" else "in"
		yaw -= 180.0 * signf(yaw)
	yaw = snappedf(yaw, 0.1)
	if is_zero_approx(yaw):
		r.erase("yaw")
	else:
		r["yaw"] = yaw


## Richtung umdrehen (Anfahrt von der anderen Seite). Mehrere Teile: um ihre Mitte wenden.
func _flip_sel() -> void:
	if _sel.is_empty():
		return
	if _sel.size() > 1:
		_rotate_sel(180.0)
		return
	_begin()
	var r: Dictionary = _rows()[_sel[0]]
	r["dir"] = "out" if r.get("dir", "out") == "in" else "in"
	_rebuild()


## An der Seillinie spiegeln (auf die andere Seite des Seils).
func _mirror_sel() -> void:
	if _sel.is_empty():
		return
	_begin()
	for i in _sel:
		var r: Dictionary = _rows()[i]
		r["x"] = -float(r.get("x", 0.0))
		if r.has("yaw"):
			_set_yaw(r, -float(r["yaw"]))
		if r.has("inner_v"):
			r["inner_v"] = -float(r["inner_v"])
		var exits: Dictionary = _catalog.get(r.get("part", ""), {}).get("exits", {})
		if not exits.is_empty():
			# Pool: Ausgänge tauschen die Seite
			var l: String = r.get("exit_left", exits.get("left", ""))
			r["exit_left"] = r.get("exit_right", exits.get("right", ""))
			r["exit_right"] = l
	_rebuild()


func _duplicate_sel() -> void:
	if _sel.is_empty():
		return
	_begin()
	var lo := INF
	var hi := -INF
	for p: FeaturePart in _fs.parts:
		if p.row_index in _sel:
			lo = minf(lo, p.s_center - p.length * 0.5)
			hi = maxf(hi, p.s_center + p.length * 0.5)
	var shift := snappedf(hi - lo + 3.0, 0.5)
	var new_sel: Array[int] = []
	for i in _sel:
		var r: Dictionary = (_rows()[i] as Dictionary).duplicate(true)
		r["s"] = snappedf(float(r.get("s", 0.0)) + shift, 0.01)
		_rows().append(r)
		new_sel.append(_rows().size() - 1)
	_sel = new_sel
	_rebuild()


func _set_value(key: String, v: Variant) -> void:
	if _sel.size() != 1:
		return
	_begin("val:" + key)
	var r: Dictionary = _rows()[_sel[0]]
	if key == "yaw":
		_set_yaw(r, float(v))
	else:
		r[key] = v
	_rebuild()


# ---------------------------------------------------------------- Seitenleiste "Auswahl"

func _sync_selection() -> void:
	if _sel_box == null:
		return
	if _preview_frame.get_parent():
		_preview_frame.get_parent().remove_child(_preview_frame)
	for c in _sel_box.get_children():
		c.queue_free()
	_overlay.queue_redraw()
	if _sel.is_empty():
		_sel_box.add_child(_hint("Nichts ausgewählt. Ein Feature in der Karte antippen (doppelt = ganzer Hack), "
			+ "Umschalt/Strg + Klick wählt mehrere.\n\nTasten: Pfeile verschieben (Umschalt 1 m), Q/E drehen, "
			+ "F Richtung, M spiegeln, Strg+D duplizieren, Entf löschen, Strg+Z rückgängig."))
		return
	var parts: Array = []
	for p: FeaturePart in _fs.parts:
		if p.row_index in _sel:
			parts.append(p)
	var title := host._label(_sel_title(parts), 22, StartScreen.SEL)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sel_box.add_child(title)
	_sel_box.add_child(_preview_frame)
	_preview.show_parts(parts, _cables[_terminal])
	if _sel.size() == 1:
		var r: Dictionary = _rows()[_sel[0]]
		var id: String = r.get("part", "")
		_sel_box.add_child(_hint(_part_info(id)))
		_num_row("POSITION ENTLANG DES SEILS  s (m)", float(r.get("s", 0.0)), 0.1, -20.0, 300.0,
			func(v: float) -> void: _set_value("s", snappedf(v, 0.01)))
		_num_row("SEITLICH  x (m)   + rechts, − links (Blick zum Endmast)", float(r.get("x", 0.0)), 0.1, -60.0, 60.0,
			func(v: float) -> void: _set_value("x", snappedf(v, 0.01)))
		_num_row("DREHUNG (Grad)", float(r.get("yaw", 0.0)), 1.0, -90.0, 90.0,
			func(v: float) -> void: _set_value("yaw", v))
		if r.has("dir") or _catalog.get(id, {}).get("type", "") not in ["ball", "bump"]:
			_sel_box.add_child(host._small("RICHTUNG (Anfahrt)"))
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			_sel_box.add_child(row)
			var g := ButtonGroup.new()
			for d: Array in [["out", "Zum Endmast  →"], ["in", "←  Zum Steg"]]:
				var b := host._button(d[1], 16)
				b.toggle_mode = true
				b.button_group = g
				b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				b.button_pressed = r.get("dir", "out") == d[0]
				var val: String = d[0]
				b.pressed.connect(func() -> void: _set_value("dir", val))
				row.add_child(b)
		# Pool: Ausgang links/rechts wählbar (Add-ons mit "pool_exit")
		var exits: Dictionary = _catalog.get(id, {}).get("exits", {})
		if not exits.is_empty():
			var ids: Array[String] = []
			for k: String in _catalog:
				if _catalog[k] is Dictionary and _catalog[k].get("pool_exit", false):
					ids.append(k)
			for side: Array in [["left", "AUSGANG LINKS (Blick von der Rampe)"], ["right", "AUSGANG RECHTS (Blick von der Rampe)"]]:
				var key: String = "exit_" + side[0]
				_choice_row(side[1], ids, str(r.get(key, exits.get(side[0], ""))),
					func(v: String) -> void: _set_value(key, v))
		for k: Array in [["ramp_in", "AUFFAHRT VORNE (m, 0 = ab)"], ["ramp_out", "AUFFAHRT HINTEN (m, 0 = ab)"]]:
			var def := _ramp_default(id, k[0])
			if not is_nan(def):
				var key: String = k[0]
				_num_row(k[1], float(r.get(key, def)), 0.1, 0.0, 10.0,
					func(v: float) -> void: _set_value(key, snappedf(v, 0.01)))
	else:
		_sel_box.add_child(_hint("%d Teile ausgewählt – sie werden gemeinsam verschoben, gedreht und gespiegelt." % _sel.size()))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_sel_box.add_child(grid)
	for a: Array in [["Drehen +15°  (Q)", func() -> void: _rotate_sel(15.0)],
			["Drehen −15°  (E)", func() -> void: _rotate_sel(-15.0)],
			["Umdrehen  (F)", _flip_sel],
			["Spiegeln  (M)", _mirror_sel],
			["Duplizieren", _duplicate_sel],
			["Ganzen Hack wählen", func() -> void: _select_hack_of(_sel[0])],
			["Löschen", _delete_sel]]:
		var b := host._button(a[0], 16)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.pressed.connect(a[1])
		grid.add_child(b)


func _sel_title(parts: Array) -> String:
	for hack: Array in _hacks:
		var rows := {}
		for p: FeaturePart in hack:
			rows[p.row_index] = true
		if rows.size() == _sel.size() and _sel.all(func(i: int) -> bool: return rows.has(i)):
			return Hacks.hack_name(hack)
	if _sel.size() == 1:
		return _part_name(_rows()[_sel[0]].get("part", ""))
	return "%d Teile" % parts.size()


## Zahl mit − / + und Eingabefeld.
func _num_row(title: String, value: float, step: float, lo: float, hi: float, apply: Callable) -> void:
	_sel_box.add_child(host._small(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sel_box.add_child(row)
	var sb := SpinBox.new()
	sb.min_value = lo
	sb.max_value = hi
	sb.step = step * 0.1 if step < 1.0 else step
	sb.custom_arrow_step = step
	sb.value = value
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sb.custom_minimum_size.y = 48
	sb.get_line_edit().add_theme_font_size_override("font_size", 18)
	sb.select_all_on_focus = true
	var minus := host._button("−", 22)
	minus.custom_minimum_size.x = 52
	var plus := host._button("+", 22)
	plus.custom_minimum_size.x = 52
	minus.pressed.connect(func() -> void: apply.call(clampf(sb.value - step, lo, hi)))
	plus.pressed.connect(func() -> void: apply.call(clampf(sb.value + step, lo, hi)))
	sb.value_changed.connect(func(v: float) -> void: apply.call(v))
	row.add_child(minus)
	row.add_child(sb)
	row.add_child(plus)


## Auswahl aus Bauteilen (ids) mit ◀ / ▶, in der Mitte der Name.
func _choice_row(title: String, ids: Array[String], current: String, apply: Callable) -> void:
	_sel_box.add_child(host._small(title))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_sel_box.add_child(row)
	var idx := maxi(ids.find(current), 0)
	var prev := host._button("◀", 22)
	prev.custom_minimum_size.x = 52
	var mid := host._button(_part_name(ids[idx]), 18)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.custom_minimum_size.y = 48
	var next := host._button("▶", 22)
	next.custom_minimum_size.x = 52
	prev.pressed.connect(func() -> void: apply.call(ids[(idx - 1 + ids.size()) % ids.size()]))
	next.pressed.connect(func() -> void: apply.call(ids[(idx + 1) % ids.size()]))
	mid.pressed.connect(func() -> void: apply.call(ids[(idx + 1) % ids.size()]))
	row.add_child(prev)
	row.add_child(mid)
	row.add_child(next)


## Standardwert einer Auffahrt (NAN = Teil hat keine einstellbare Auffahrt).
func _ramp_default(id: String, key: String) -> float:
	var e: Dictionary = _catalog.get(id, {})
	match e.get("type", ""):
		"pipe":
			return float(e.get(key, 0.0))
		"group":
			for c: Dictionary in e.get("parts", []):
				if c.get("edge", "") == ("in" if key == "ramp_in" else "out"):
					return float(_catalog.get(c.get("part", ""), {}).get(key, 0.0))
	return NAN


# ---------------------------------------------------------------- Seitenleiste "Hacks"

## Alle Hacks (mehrere zusammenstehende Features) aus allen Setups beider Terminals, einmal
## aufgebaut und nach Anordnung zusammengefasst.
func _collect_hacks() -> void:
	for c in _hack_list.get_children():
		c.queue_free()
	var by_sig := {}
	for e: Dictionary in FeatureSet.list_setups():
		var d := FeatureSet.read_setup(e["file"])
		for t: String in ["T2", "T1"]:
			var rows: Array = d.get(t, [])
			if rows.size() < 2:
				continue
			var c: CableSystem = _cables[t]
			var fs := FeatureSet.new()
			fs.visible = false
			_world.add_child(fs)
			fs.load_data(d, {t: c}, {}, e["file"])
			for hack: Array in Hacks.group(fs.parts, c):
				var idx := {}
				for p: FeaturePart in hack:
					idx[p.row_index] = true
				if idx.size() < 2:
					continue          # ein Modul (z. B. Pyramid Series) steht schon bei den Bauteilen
				var sig := Hacks.signature(hack, c)
				var where := "%s (%s)" % [str(e["name"]).get_slice(" (", 0), t]
				if by_sig.has(sig):
					by_sig[sig]["where"].append(where)
					continue
				var hrows: Array = []
				var keys := idx.keys()
				keys.sort()
				for i: int in keys:
					hrows.append((rows[i] as Dictionary).duplicate(true))
				by_sig[sig] = {"label": Hacks.hack_name(hack).trim_prefix("Hack: "), "where": [where],
					"rows": hrows, "standard": Hacks.is_standard(hack)}
			fs.free()
	_hack_templates = by_sig.values()
	_hack_templates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["label"].naturalnocasecmp_to(b["label"]) < 0)
	_hack_list.add_child(_hint("Antippen fügt den Hack in die Mitte der Karte ein (gleiche Anordnung, seitlich wie im Original)."))
	for section: Array in [["HACKS", false], ["GÄNGIGE KOMBINATIONEN", true]]:
		_hack_list.add_child(host._small(section[0]))
		for t: Dictionary in _hack_templates:
			if t["standard"] != section[1]:
				continue
			var b := host._button(str(t["label"]), 16)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.clip_text = true
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.tooltip_text = "%s\nIm Setup: %s" % [t["label"], ", ".join(t["where"])]
			var tt := t
			b.pressed.connect(func() -> void: _add_hack(tt))
			_hack_list.add_child(b)
			var w := host._label("   " + ", ".join(t["where"]), 13, Color(1, 1, 1, 0.5))
			w.clip_text = true
			_hack_list.add_child(w)


# ---------------------------------------------------------------- Setup: Speichern, JSON, Infos

func _update_info() -> void:
	var n := _rows().size()
	var hack_count := 0
	for h: Array in _hacks:
		if not Hacks.is_standard(h):
			hack_count += 1
	var lines: Array[String] = ["%s: %d Features/Hacks (%d Zeilen), davon %d Hacks.   %s: %d Zeilen." % [
		_terminal, _hacks.size(), n, hack_count, _other(), (_data.get(_other(), []) as Array).size()]]
	# Warnungen: Teile außerhalb der Fahrstrecke (vor der Ufer-Wende bzw. hinter der roten Boje)
	if not _lane.is_empty():
		for p: FeaturePart in _fs.parts:
			var s := p.s_center
			if s - p.length * 0.5 < _lane["turn_a"] + 8.0 or s + p.length * 0.5 > _lane["red_b"]:
				lines.append("Achtung: %s bei s = %.0f m liegt außerhalb der Fahrstrecke." % [p.display_name, s])
	lines.append("Eigenes Setup (gespeichert)" if _user_id != "" else "Noch nicht gespeichert – „Speichern“ legt ein eigenes Setup an.")
	_setup_info.text = "\n".join(lines)
	_btn_delete_setup.disabled = _user_id == ""
	if _plant_mode:
		_status.text = "Pflanzen   ·   %s: %s   ·   linke Taste = Pinsel, rechte Taste ziehen = Karte bewegen, Rad / + − = Zoom" % [
			{"malen": "Malen", "radieren": "Radieren", "auto": "Automatik", "schieben": "Schieben"}[_plant_tool], Plants.species(_plant_id)["name"]]
	else:
		_status.text = "%s   ·   %d Teile   ·   Ziehen = verschieben, freie Fläche ziehen = Karte bewegen, Rad / + − = Zoom" % [_terminal, n]


func _clean_data() -> Dictionary:
	var out := {"name": _name_edit.text.strip_edges() if _name_edit.text.strip_edges() != "" else "Eigenes Setup",
		"date": _data.get("date", "????-??"), "source": "Setup-Editor"}
	for t: String in ["T2", "T1"]:
		var rows: Array = []
		for r: Dictionary in _data.get(t, []):
			var nr := {}
			for k: String in r:
				var v: Variant = r[k]
				if v is float:
					v = snappedf(v, 0.01)
					if is_equal_approx(v, roundf(v)):
						v = int(roundf(v))
				nr[k] = v
			rows.append(nr)
		out[t] = rows
	return out


func _export_json() -> String:
	return JSON.stringify(_clean_data(), "  ", false)


func _import_json() -> void:
	var d: Variant = JSON.parse_string(_json_edit.text)
	if not (d is Dictionary) or not ((d as Dictionary).has("T2") or (d as Dictionary).has("T1")):
		_show_toast("Kein gültiges Setup-JSON (braucht \"T2\" und/oder \"T1\")")
		return
	_begin()
	_load(d, _user_id)
	_show_toast("Setup aus Text geladen")


func _save(play: bool) -> void:
	var d := _clean_data()
	if _user_id == "":
		_user_id = "eigen-%d" % int(Time.get_unix_time_from_system())
	if FeatureSet.save_user_setup(_user_id, d) == "":
		_show_toast("Speichern fehlgeschlagen")
		return
	_dirty = false
	_leave_armed = false
	_update_info()
	_fill_templates()
	_show_toast("Gespeichert: " + str(d["name"]))
	saved.emit(_user_id, play)
	if play:
		_close()


func _delete_setup() -> void:
	if _user_id == "":
		return
	FeatureSet.delete_user_setup(_user_id)
	var id := _user_id
	_user_id = ""
	_dirty = true
	_update_info()
	_fill_templates()
	_show_toast("Eigenes Setup gelöscht (bleibt hier zum Weiterbearbeiten)")
	saved.emit(id, false)


# ---------------------------------------------------------------- Pflanzen

## Reiter „Pflanzen“: Werkzeug, Art, Pinsel, Dichte, Speichern.
func _build_plant_page(page: VBoxContainer) -> void:
	page.add_child(_hint("Auf dem Luftbild malen. Wo du malst, radierst oder die Automatik zurückholst, " +
		"übernimmst du die Stelle: dort setzt das Spiel nichts Automatisches mehr (Wiesengras, Schilf, " +
		"Ufergras bzw. Sträucher und Bäume aus dem Wald) – getrennt für Bodenpflanzen und Gehölze. " +
		"Rechte Maustaste ziehen = Karte bewegen."))
	page.add_child(host._small("WERKZEUG"))
	var tools := GridContainer.new()
	tools.columns = 2
	tools.add_theme_constant_override("h_separation", 6)
	tools.add_theme_constant_override("v_separation", 6)
	page.add_child(tools)
	var tg := ButtonGroup.new()
	for t: Array in TOOLS:
		var b := host._button(t[1], 16)
		b.toggle_mode = true
		b.button_group = tg
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = t[0]
		b.tooltip_text = {"malen": "Gewählte Pflanze setzen", "radieren": "Pflanzen der Ebene entfernen (auch die automatischen)",
			"auto": "Stellen wieder der Automatik überlassen (entfernt Gemaltes der Ebene)", "schieben": "Karte mit dem Finger bewegen"}[id]
		b.pressed.connect(func() -> void:
			_plant_tool = id
			_update_plant_ui())
		tools.add_child(b)
		_tool_buttons[id] = b
	page.add_child(host._small("PFLANZE   (Radieren/Automatik wirken auf ihre Ebene)"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	page.add_child(grid)
	var pg := ButtonGroup.new()
	for sp: Dictionary in Plants.SPECIES:
		var b := host._button(sp["name"], 16)
		b.toggle_mode = true
		b.button_group = pg
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_color_override("font_color", (sp["color"] as Color).lightened(0.35))
		var hr: Array = sp["h"]
		b.tooltip_text = "%s: %.1f–%.1f m hoch, Abstand %.1f m – %s" % [sp["name"], hr[0], hr[1], sp["spacing"], Plants.LAYER_NAMES[sp["layer"]]]
		var id: String = sp["id"]
		b.pressed.connect(func() -> void:
			_plant_id = id
			if _plant_tool == "schieben":
				_plant_tool = "malen"
			_update_plant_ui())
		grid.add_child(b)
		_plant_buttons[id] = b
	page.add_child(host._small("PINSEL"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	page.add_child(row)
	for d: int in [-1, 1]:
		var b := host._button("−" if d < 0 else "+", 20)
		b.custom_minimum_size = Vector2(56, 48)
		b.pressed.connect(func() -> void:
			var i := clampi(BRUSHES.find(_brush) + d, 0, BRUSHES.size() - 1)
			_brush = BRUSHES[i]
			_update_plant_ui())
		row.add_child(b)
		if d < 0:
			_brush_label = host._label("", 16)
			_brush_label.custom_minimum_size.x = 90
			_brush_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_brush_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(_brush_label)
	page.add_child(host._small("DICHTE BEIM MALEN"))
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 6)
	page.add_child(drow)
	var dg := ButtonGroup.new()
	for d: Array in DENSITIES:
		var b := host._button(d[0], 16)
		b.toggle_mode = true
		b.button_group = dg
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var f: float = d[1]
		b.pressed.connect(func() -> void:
			_density = f
			_update_plant_ui())
		drow.add_child(b)
		_density_buttons.append(b)
	_plant_info = host._label("", 15, Color(1, 1, 1, 0.8))
	_plant_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(_plant_info)
	var save := host._button("PFLANZEN SPEICHERN", 16, true)
	save.pressed.connect(_save_plants)
	page.add_child(save)
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 6)
	page.add_child(jrow)
	var exp := host._button("Als JSON kopieren", 16)
	exp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp.tooltip_text = "Für setups/plants.json im Projekt"
	exp.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(Plants.to_json())
		_show_toast("Bepflanzung als JSON in die Zwischenablage kopiert"))
	jrow.add_child(exp)
	_btn_plant_reset = host._button("Zurücksetzen", 16)
	_btn_plant_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_plant_reset.tooltip_text = "Eigene Bepflanzung löschen, wieder die aus dem Spiel"
	_btn_plant_reset.pressed.connect(func() -> void:
		_plant_begin()
		Plants.reset_user()
		_plants_dirty = false
		plants_saved.emit()
		_update_plant_ui()
		_show_toast("Bepflanzung aus dem Spiel geladen"))
	jrow.add_child(_btn_plant_reset)


func _update_plant_ui() -> void:
	for id: String in _tool_buttons:
		(_tool_buttons[id] as Button).set_pressed_no_signal(id == _plant_tool)
	for id: String in _plant_buttons:
		(_plant_buttons[id] as Button).set_pressed_no_signal(id == _plant_id)
	for i in _density_buttons.size():
		_density_buttons[i].set_pressed_no_signal(is_equal_approx(DENSITIES[i][1], _density))
	_brush_label.text = "Ø %s m" % str(_brush * 2.0).trim_suffix(".0")
	var counts := {}
	for e: Array in Plants.hand_list():
		counts[e[0]] = counts.get(e[0], 0) + 1
	var parts: Array[String] = []
	for sp: Dictionary in Plants.SPECIES:
		if counts.has(sp["id"]):
			parts.append("%s %d" % [sp["name"], counts[sp["id"]]])
	var lines: Array[String] = ["Gemalt: " + (", ".join(parts) if not parts.is_empty() else "noch nichts")]
	lines.append("Von Hand gepflegt: %d m² Boden, %d m² Gehölz" % [
		(Plants.managed["boden"] as Dictionary).size() * int(Plants.CELL * Plants.CELL),
		(Plants.managed["gehoelz"] as Dictionary).size() * int(Plants.CELL * Plants.CELL)])
	lines.append("Ebene der Pflanze: " + Plants.LAYER_NAMES[Plants.layer_of(_plant_id)])
	if _plants_dirty:
		lines.append("Nicht gespeichert.")
	_plant_info.text = "\n".join(lines)
	_btn_plant_reset.visible = Plants.can_reset_user()
	_btn_undo.disabled = _plant_undo.is_empty() if _plant_mode else _undo.is_empty()
	_btn_redo.disabled = _plant_redo.is_empty() if _plant_mode else _redo.is_empty()
	_update_info()
	_overlay.queue_redraw()


## Maus/Finger auf der Karte im Reiter „Pflanzen“. true = verarbeitet.
func _plant_input(event: InputEvent) -> bool:
	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		_brush_px = mm.position
		if _painting:
			var now := _screen_to_sx(mm.position)
			_paint_line(_paint_last, now)
			_paint_last = now
			return true
		_overlay.queue_redraw()
		return false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or _plant_tool == "schieben":
			return false
		if mb.pressed:
			_plant_begin()
			_painting = true
			_paint_last = _screen_to_sx(mb.position)
			_paint_at(_paint_last)
		elif _painting:
			_painting = false
			_update_plant_ui()
		return true
	return false


## Pinsel von a nach b ziehen (Schritte von einem halben Pinsel, damit nichts ausgelassen wird).
func _paint_line(a: Vector2, b: Vector2) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / maxf(_brush * 0.5, 0.25)))
	for i in n:
		_paint_at(a.lerp(b, float(i + 1) / n))


## Einmal den Pinsel bei (s, x) anwenden.
func _paint_at(sx: Vector2) -> void:
	var w := _sx_to_world(sx)
	var sp := Plants.species(_plant_id)
	var layer: String = sp["layer"]
	var r := _brush
	var cells: Dictionary = Plants.managed[layer]
	var c0 := Plants.cell_of(w.x - r, w.y - r)
	var c1 := Plants.cell_of(w.x + r, w.y + r)
	for cx in range(c0.x, c1.x + 1):
		for cz in range(c0.y, c1.y + 1):
			var mid := (Vector2(cx, cz) + Vector2(0.5, 0.5)) * Plants.CELL
			if mid.distance_to(w) > r + Plants.CELL * 0.35:
				continue
			if _plant_tool == "auto":
				cells.erase(Vector2i(cx, cz))
			else:
				cells[Vector2i(cx, cz)] = true
	if _plant_tool != "malen":
		for e: Array in Plants.hand_near(w.x, w.y, r, layer):
			Plants.remove_hand(e)
	else:
		# festes Raster je Art: nochmal über dieselbe Stelle malen setzt nichts doppelt
		var step: float = sp["spacing"] / _density
		var salt := 7000 + Plants.SPECIES.find(sp) * 10
		var hr: Array = sp["h"]
		for gx in range(floori((w.x - r) / step), ceili((w.x + r) / step) + 1):
			for gz in range(floori((w.y - r) / step), ceili((w.y + r) / step) + 1):
				var px := (gx + Plants.rand01(gx, gz, salt) * 0.8 - 0.4) * step
				var pz := (gz + Plants.rand01(gx, gz, salt + 1) * 0.8 - 0.4) * step
				if Vector2(px, pz).distance_to(w) > r or not Plants.allowed(_plant_id, px, pz):
					continue
				if not Plants.hand_near(px, pz, step * 0.75, layer).is_empty():
					continue
				Plants.add_hand([_plant_id, px, pz, lerpf(hr[0], hr[1], Plants.rand01(gx, gz, salt + 2)), Plants.rand01(gx, gz, salt + 3) * TAU])
	_plants_dirty = true
	_overlay.queue_redraw()


func _plant_begin() -> void:
	_plant_undo.append(JSON.stringify(Plants.to_data()))
	if _plant_undo.size() > PLANT_HISTORY:
		_plant_undo.pop_front()
	_plant_redo.clear()
	_leave_armed = false


func _plant_step(back: bool) -> void:
	var from := _plant_undo if back else _plant_redo
	var to := _plant_redo if back else _plant_undo
	if from.is_empty():
		return
	to.append(JSON.stringify(Plants.to_data()))
	Plants.from_data(JSON.parse_string(from.pop_back()))
	_plants_dirty = true
	_update_plant_ui()


func _save_plants() -> void:
	var file := Plants.save()
	if file == "":
		_show_toast("Speichern fehlgeschlagen")
		return
	_plants_dirty = false
	_leave_armed = false
	plants_saved.emit()
	_update_plant_ui()
	_show_toast("Bepflanzung gespeichert (%s), im Spiel neu aufgebaut" % file.get_file())


## Pflanzen in der Karte: gepflegte Stellen getönt, automatische Pflanzen blass, gemalte kräftig, Pinsel.
func _draw_plants(o: Control) -> void:
	var view := Rect2(Vector2.ZERO, o.size).grow(30.0)
	# Draufsicht: lineare Abbildung Spiel (x, z) -> Bildschirm, sonst je Punkt projizieren
	var p0 := _game_to_screen(Vector2.ZERO)
	var ax := _game_to_screen(Vector2(1.0, 0.0)) - p0
	var az := _game_to_screen(Vector2(0.0, 1.0)) - p0
	var proj := func(x: float, z: float) -> Vector2:
		return p0 + ax * x + az * z if not _3d else _game_to_screen(Vector2(x, z))
	var px_per_m := ax.length() if not _3d else 4.0
	for layer: String in Plants.LAYERS:
		var col: Color = LAYER_FILL[layer]
		for c: Vector2i in Plants.managed[layer]:
			var q := Vector2(c) * Plants.CELL
			var a: Vector2 = proj.call(q.x, q.y)
			if not view.has_point(a):
				continue
			o.draw_colored_polygon(PackedVector2Array([a, proj.call(q.x + Plants.CELL, q.y),
				proj.call(q.x + Plants.CELL, q.y + Plants.CELL), proj.call(q.x, q.y + Plants.CELL)]), col)
	for e: Array in Plants.auto_cache():
		if Plants.is_managed(Plants.layer_of(e[0]), e[1], e[2]):
			continue
		var p: Vector2 = proj.call(e[1], e[2])
		if view.has_point(p):
			var sp := Plants.species(e[0])
			var col: Color = sp["color"]
			col.a = 0.45
			o.draw_circle(p, maxf(1.5, float(e[3]) * float(sp["r"]) * px_per_m), col)
	for e: Array in Plants.hand_list():
		var p: Vector2 = proj.call(e[1], e[2])
		if view.has_point(p):
			var sp := Plants.species(e[0])
			var rad := maxf(2.0, float(e[3]) * float(sp["r"]) * px_per_m)
			o.draw_circle(p, rad, sp["color"])
			if rad > 4.0:
				o.draw_arc(p, rad, 0.0, TAU, 16, Color(0, 0, 0, 0.5), 1.0, true)
	if _plant_tool != "schieben" and Rect2(Vector2.ZERO, o.size).has_point(_brush_px):
		var col := {"malen": Color(1, 1, 1, 0.9), "radieren": Color(1, 0.35, 0.3, 0.9), "auto": Color(0.4, 0.8, 1.0, 0.9)}[_plant_tool] as Color
		var c := _screen_to_sx(_brush_px)
		var edge := _sx_to_screen(c.x + _brush, c.y)
		o.draw_arc(_brush_px, _brush_px.distance_to(edge), 0.0, TAU, 48, col, 2.0, true)


func _game_to_screen(g: Vector2) -> Vector2:
	var sx := _world_to_sx(g)
	return _sx_to_screen(sx.x, sx.y)


# ---------------------------------------------------------------- Zeichnen (Überlagerung)

func _draw_overlay() -> void:
	if _lane.is_empty() or _cam == null:
		return
	var o := _overlay
	var font := get_theme_default_font()
	if _plant_mode:
		_draw_plants(o)
	# Maßstab entlang des Seils
	var px_per_m := (_sx_to_screen(_center.x + 1.0, 0.0) - _sx_to_screen(_center.x, 0.0)).length()
	var step := 10.0 if px_per_m > 4.0 else (20.0 if px_per_m > 1.6 else 50.0)
	var s: float = ceilf(float(_lane["mast_a"]) / step) * step
	while s <= _lane["mast_b"]:
		var p := _sx_to_screen(s, 0.0)
		if Rect2(Vector2.ZERO, o.size).grow(20).has_point(p):
			_text(o, font, p + Vector2(3, 16), "%d" % roundi(s), 13, Color(1, 1, 1, 0.55))
		s += step
	for m: Array in [["mast_a", "Startmast"], ["turn_a", "Wende"], ["red_a", "rote Boje"],
			["red_b", "rote Boje"], ["turn_b", "Wende"], ["mast_b", "Endmast"]]:
		var p := _sx_to_screen(_lane[m[0]], -1.5)
		_text(o, font, p + Vector2(4, -6), m[1], 14, Color(1, 1, 1, 0.8))
	# Seiten beschriften (Blick vom Steg zum Endmast)
	var left := _sx_to_screen(_center.x, -_span * 0.5 + 2.0)
	_text(o, font, Vector2(12, clampf(left.y, 20, o.size.y - 40)), "links (−x)", 14, Color(1, 1, 1, 0.5))
	var right := _sx_to_screen(_center.x, _span * 0.5 - 2.0)
	_text(o, font, Vector2(12, clampf(right.y, 40, o.size.y - 40)), "rechts (+x)", 14, Color(1, 1, 1, 0.5))
	# Grundrisse: Auswahl gelb, Hacks orange
	var c: CableSystem = _cables[_terminal]
	for hack: Array in _hacks:
		var is_hack := not Hacks.is_standard(hack)
		var mid := Vector2.ZERO
		var top := -INF
		for p: FeaturePart in hack:
			var sel := p.row_index in _sel
			var col := StartScreen.SEL if sel else (HACK_COLOR if is_hack else Color(1, 1, 1, 0.35))
			var pts := PackedVector2Array()
			for q: Vector2 in Hacks.footprint(p, c, 0.05):
				pts.append(_sx_to_screen(q.x, q.y))
			pts.append(pts[0])
			o.draw_polyline(pts, col, 3.0 if sel else (2.0 if is_hack else 1.0), true)
			if sel:
				# Pfeil in Fahrtrichtung (Anfahrt)
				var f := p.forward_world() * p.length * 0.35
				var a := _world_to_screen(p.global_position)
				var b := _world_to_screen(p.global_position + f)
				o.draw_line(a, b, col, 2.0, true)
				var dir := (b - a).normalized()
				if dir != Vector2.ZERO:
					o.draw_colored_polygon(PackedVector2Array([b + dir * 10.0, b + dir.orthogonal() * 6.0, b - dir.orthogonal() * 6.0]), col)
			mid += Vector2(p.s_center, p.x_center)
			top = maxf(top, p.x_center + p.width * 0.5)
		mid /= hack.size()
		if px_per_m > 2.5:
			var label := Hacks.hack_name(hack)
			var lp := _sx_to_screen(mid.x, top + 0.8)
			var fs := 14
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			_text(o, font, lp + Vector2(-w * 0.5, 14), label, fs, HACK_COLOR if is_hack else Color(1, 1, 1, 0.85))


func _text(o: Control, font: Font, p: Vector2, t: String, fs: int, col: Color) -> void:
	o.draw_string_outline(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.8))
	o.draw_string(font, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ---------------------------------------------------------------- Kleinkram

func _part_name(id: String) -> String:
	return str(_catalog.get(id, {}).get("name", id))


func _part_info(id: String) -> String:
	var e: Dictionary = _catalog.get(id, {})
	if e.get("type", "") == "group":
		var names: Array[String] = []
		for c: Dictionary in e.get("parts", []):
			var nm := _part_name(c.get("part", ""))
			if not str(c.get("part", "")).begins_with("@") and nm not in names:
				names.append(nm)
		if e.has("exits"):
			names.append("2 Ausgänge (wählbar)")
		return "Modul: " + " + ".join(names)
	var h := float(e.get("height", 0.0))
	for pt: Array in e.get("profile", []):
		h = maxf(h, float(pt[1]))
	var w := float(e.get("width", float(e.get("radius", 0.2)) * 2.0))
	return "%s   %.1f × %.1f m, Höhe %.2f m" % [_part_name(id), float(e.get("length", w)), w, h]


func _hint(t: String) -> Label:
	var l := host._label(t, 15, Color(1, 1, 1, 0.65))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _show_toast(t: String) -> void:
	_toast.text = t
	_toast.visible = true
	_toast_t = 3.0
	_place_toast()


func _place_toast() -> void:
	var ts := _toast.get_combined_minimum_size()
	_toast.size = ts
	_toast.position = Vector2((_map.size.x - ts.x) * 0.5, _map.position.y + _body.position.y + 70.0)


## Größe setzen (Einheiten der Startseite). Hochformat: Karte oben, Leiste unten.
func layout(size_units: Vector2, k: float) -> void:
	ui_scale = k
	position = Vector2.ZERO
	size = size_units
	var portrait := size_units.x < 900.0
	_body.vertical = portrait
	if portrait:
		_side.custom_minimum_size = Vector2(0, size_units.y * 0.45)
	else:
		_side.custom_minimum_size = Vector2(minf(420.0, size_units.x * 0.38), 0)
	_resize_view()


## Test (--screen=@editor:OPT:OPT…): t1, t2, 3d, sel=N (Zeile wählen), hack=N (Hack der Zeile),
## seite=N (Reiter 0–4), add=ID (Bauteil einfügen), rot=GRAD, zoom=F, save (eigenes Setup speichern),
## Pflanzen: pflanzen (Reiter), mitte=S,X (Kartenmitte), art=ID, werkzeug=malen|radieren|auto, pinsel=R,
## dichte=F, malen=S,X[,S2,X2] (Pinselstrich), psave (Bepflanzung speichern – schreibt setups/plants.json!).
func run_test(opts: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for o: String in opts.split(":", false):
		var kv := o.split("=")
		match kv[0]:
			"t1", "t2":
				_set_terminal(kv[0].to_upper())
				_fit()
			"3d":
				_btn_3d.button_pressed = true
			"sel":
				_sel = [int(kv[1])]
				_sync_selection()
				_show_page(2)
			"hack":
				_select_hack_of(int(kv[1]))
			"seite":
				_show_page(int(kv[1]))
			"add":
				_add_part(kv[1])
			"rot":
				_rotate_sel(float(kv[1]))
			"save":
				_save(false)
			"zoom":
				_zoom_at(_map.size * 0.5, float(kv[1]))
			"pflanzen":
				_show_page(PLANT_PAGE)
			"mitte":
				var v := kv[1].split_floats(",")
				_center = Vector2(v[0], v[1])
				_clamp_center()
				_update_cam()
			"art":
				_plant_id = kv[1]
			"werkzeug":
				_plant_tool = kv[1]
			"pinsel":
				_brush = float(kv[1])
			"dichte":
				_density = float(kv[1])
			"malen":
				var v := kv[1].split_floats(",")
				_plant_begin()
				var a := Vector2(v[0], v[1])
				_paint_at(a)
				if v.size() >= 4:
					_paint_line(a, Vector2(v[2], v[3]))
				_update_plant_ui()
				print("PFLANZEN gemalt: %d, gepflegt Boden %d / Gehölz %d Zellen" % [Plants.hand_list().size(),
					(Plants.managed["boden"] as Dictionary).size(), (Plants.managed["gehoelz"] as Dictionary).size()])
			"psave":
				_save_plants()


func _process(delta: float) -> void:
	if not visible:
		return
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast.visible = false
