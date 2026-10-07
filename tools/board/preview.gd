extends SceneTree
## Vorschau von Brett und Bindungen aus mehreren Richtungen:
##   godot --path . --script tools/board/preview.gd -- <ausgabe-präfix> [design | all]
## Erzeugt <präfix>_top.png, _bottom.png, _side.png, _boots.png, _boot_side.png;
## mit "all" stattdessen alle Designs der BoardLibrary nebeneinander (_lib_top/_lib_bottom/_lib_boots).

const VIEWS := {
	"top": [Vector3(0.0, 1.9, 0.001), Vector3.ZERO],
	"bottom": [Vector3(0.0, -1.9, 0.001), Vector3.ZERO],
	"side": [Vector3(1.8, 0.05, 0.0), Vector3(0, 0.05, 0)],
	"boots": [Vector3(0.75, 0.55, 0.55), Vector3(0, 0.12, 0)],
	"boot_side": [Vector3(0.05, 0.18, -0.85), Vector3(0, 0.14, -0.27)],
}

const LIB_VIEWS := {
	"lib_top": [Vector3(0.0, 3.6, 0.001), Vector3.ZERO],
	"lib_bottom": [Vector3(0.0, -3.6, 0.001), Vector3.ZERO],
	"lib_boots": [Vector3(0.0, 1.3, 2.3), Vector3(0, 0.1, 0.0)],
}

var _cam: Camera3D
var _catalog := false


func _initialize() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var args := OS.get_cmdline_user_args()
	var which := args[1] if args.size() > 1 else "0"
	if which == "all":
		_catalog = true
		for i in BoardLibrary.count():
			var b := BoardLibrary.make(i)
			b.position = Vector3((i - (BoardLibrary.count() - 1) * 0.5) * 0.55, 0.0, 0.0)
			root3d.add_child(b)
	else:
		var board := BoardLibrary.make(which.to_int())
		board.rotation.y = PI * 0.5           # Länge quer im Bild
		root3d.add_child(board)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.87, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	root3d.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(50, -140, 0)
	fill.light_energy = 0.5
	root3d.add_child(fill)
	_cam = Camera3D.new()
	_cam.fov = 40
	root3d.add_child(_cam)
	_cam.current = true
	_shots.call_deferred(OS.get_cmdline_user_args()[0])


func _shots(prefix: String) -> void:
	var views := LIB_VIEWS if _catalog else VIEWS
	for view_name: String in views:
		var v: Array = views[view_name]
		var up := Vector3.FORWARD if absf(v[0].y) > 1.0 else Vector3.UP
		# Einzelbrett ist um 90° gedreht -> Blickpunkte mitdrehen
		var turn := Basis.IDENTITY if _catalog else Basis(Vector3.UP, PI * 0.5)
		var eye: Vector3 = turn * v[0]
		var at: Vector3 = turn * v[1]
		_cam.look_at_from_position(eye, at, up)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, view_name])
	quit()
