class_name PauseMenu
extends CanvasLayer
## Pause (Esc): hält das Spiel an (SceneTree.paused) und zeigt ein Fenster im HUD-Stil mit
## Weiter, Einstellungen, Hilfe, Nächster Titel (eigene Musik) und Startseite. Läuft selbst auch während der Pause (PROCESS_MODE_ALWAYS).

signal help_pressed
signal settings_pressed           # Einstellungen öffnen (Spiel bleibt pausiert)
signal home_pressed

var music: Music                 # eigene Musik (Taste „Nächster Titel“ nur, wenn Titel da sind)
var can_pause: Callable          # main.gd: darf jetzt pausiert werden? (nicht auf der Startseite)
var _dim: ColorRect
var _box: VBoxContainer
var _next_btn: Button


func _init() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.visible = false
	add_child(_dim)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.07, 0.09, 0.92)
	sb.set_corner_radius_all(16)
	sb.border_width_bottom = 3
	sb.border_color = Hud.ACCENT
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 18
	sb.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dim.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)
	var title := Label.new()
	title.text = tr("PAUSE")
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Hud.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_button(tr("Weiter  (Esc)"), func() -> void: set_paused(false))
	_button(tr("Einstellungen"), func() -> void: settings_pressed.emit())
	_button(tr("Hilfe ein/aus"), func() -> void: help_pressed.emit())
	_next_btn = _button(tr("Nächster Titel"), func() -> void:
		music.next()
		_update_music())
	_button(tr("Startseite"), func() -> void:
		set_paused(false)
		home_pressed.emit())
	MenuNav.add_scope(_dim, 30)


func _button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_stylebox_override("focus", MenuNav.focus_box(4))
	b.pressed.connect(on_press)
	_box.add_child(b)
	return b


func _update_music() -> void:
	var on := music != null and music.current != ""
	_next_btn.visible = on
	if on:
		_next_btn.text = tr("Nächster Titel") + "   (♪ %s)" % music.current.left(28)


func set_paused(on: bool) -> void:
	if on and can_pause.is_valid() and not can_pause.call():
		return
	get_tree().paused = on
	_dim.visible = on
	if on:
		MenuNav.reset_focus(_dim)            # Fokus auf „Weiter“
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_update_music()


## Einstellungen offen: Fenster weg, Pause bleibt (danach show_again).
func hide_window() -> void:
	_dim.visible = false


## Nach den Einstellungen: wieder das Pause-Fenster zeigen.
func show_again() -> void:
	get_tree().paused = true
	_dim.visible = true
	_update_music()


func is_paused() -> bool:
	return _dim.visible


## Esc / PS: Pause an/aus; in der Pause schließen auch Kreis (ui_cancel) und Enter, O / Options öffnet die Einstellungen.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action_pressed("pause"):
		set_paused(not is_paused())
	elif is_paused() and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_start")):
		set_paused(false)
	elif is_paused() and event.is_action_pressed("settings"):
		settings_pressed.emit()
	else:
		return
	get_viewport().set_input_as_handled()
