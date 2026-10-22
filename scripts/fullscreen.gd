class_name Fullscreen
extends Node
## Vollbild am Desktop: F11 oder Alt+Enter schaltet zwischen Fenster und Vollbild um
## (überall: Spiel, Startseite, Pause, Editor). Nicht im Web – dort braucht der Browser einen Klick.


static func available() -> bool:
	return not OS.has_feature("web")


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k or not k.pressed or k.echo:
		return
	var enter := k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER
	if k.keycode == KEY_F11 or (enter and k.alt_pressed):
		toggle()
		get_viewport().set_input_as_handled()   # Alt+Enter startet sonst auch das Spiel (menu_start)


static func toggle() -> void:
	var full := DisplayServer.window_get_mode() in [DisplayServer.WINDOW_MODE_FULLSCREEN,
			DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN]
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
