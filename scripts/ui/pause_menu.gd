class_name PauseMenu
extends CanvasLayer
## Pause (Esc): hält das Spiel an (SceneTree.paused) und zeigt ein Fenster im HUD-Stil mit
## Weiter, Hilfe und Startseite. Läuft selbst auch während der Pause (PROCESS_MODE_ALWAYS).

signal help_pressed
signal home_pressed

var can_pause: Callable          # main.gd: darf jetzt pausiert werden? (nicht auf der Startseite)
var _dim: ColorRect
var _box: VBoxContainer


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
	title.text = "PAUSE"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Hud.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(title)
	_button("Weiter  (Esc)", func() -> void: set_paused(false))
	_button("Hilfe ein/aus", func() -> void: help_pressed.emit())
	_button("Startseite", func() -> void:
		set_paused(false)
		home_pressed.emit())


func _button(text: String, on_press: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 56)
	b.add_theme_font_size_override("font_size", 24)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(on_press)
	_box.add_child(b)


func set_paused(on: bool) -> void:
	if on and can_pause.is_valid() and not can_pause.call():
		return
	get_tree().paused = on
	_dim.visible = on
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func is_paused() -> bool:
	return _dim.visible


func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k and k.pressed and not k.echo and k.physical_keycode == KEY_ESCAPE:
		set_paused(not is_paused())
		get_viewport().set_input_as_handled()
