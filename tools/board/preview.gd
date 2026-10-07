extends SceneTree
## Vorschau von Brett und Bindungen aus mehreren Richtungen:
##   godot --path . --script tools/board/preview.gd -- <ausgabe-präfix>
## Erzeugt <präfix>_top.png, _bottom.png, _side.png, _boots.png, _boot_side.png

const VIEWS := {
	"top": [Vector3(0.0, 1.9, 0.001), Vector3.ZERO],
	"bottom": [Vector3(0.0, -1.9, 0.001), Vector3.ZERO],
	"side": [Vector3(1.8, 0.05, 0.0), Vector3(0, 0.05, 0)],
	"boots": [Vector3(0.75, 0.55, 0.55), Vector3(0, 0.12, 0)],
	"boot_side": [Vector3(0.05, 0.18, -0.85), Vector3(0, 0.14, -0.27)],
}

var _cam: Camera3D


func _initialize() -> void:
	var root3d := Node3D.new()
	root.add_child(root3d)
	var board := Wakeboard.new()
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
	for view_name: String in VIEWS:
		var v: Array = VIEWS[view_name]
		var up := Vector3.FORWARD if absf(v[0].y) > 1.0 else Vector3.UP
		# Bindungen: Brett ist um 90° gedreht -> Blickpunkte mitdrehen
		var eye: Vector3 = Basis(Vector3.UP, PI * 0.5) * v[0]
		var at: Vector3 = Basis(Vector3.UP, PI * 0.5) * v[1]
		_cam.look_at_from_position(eye, at, up)
		for i in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [prefix, view_name])
	quit()
