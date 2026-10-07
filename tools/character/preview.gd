extends SceneTree
## Vorschau einer Figur: godot --path . --script tools/character/preview.gd -- <glb> <png>

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var scene: PackedScene = load(args[0])
	var root3d := Node3D.new()
	root.add_child(root3d)
	var inst := scene.instantiate()
	root3d.add_child(inst)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.65, 0.75)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_energy = 0.6
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root3d.add_child(sun)
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.look_at_from_position(Vector3(0.6, 1.2, 2.6), Vector3(0, 0.95, 0))
	cam.current = true
	var skel := _find_skeleton(inst)
	if skel:
		var names := []
		for i in skel.get_bone_count():
			names.append(skel.get_bone_name(i))
		print("BONES ", names)
	_shot.call_deferred(args[1])

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := _find_skeleton(c)
		if s:
			return s
	return null

func _shot(path: String) -> void:
	for i in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(path)
	quit()
