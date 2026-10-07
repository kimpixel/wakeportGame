class_name FeaturePreview
extends SubViewportContainer
## Detailansicht eines Features bzw. Hacks in einer eigenen kleinen 3D-Welt:
## Wasserfläche mit 1-m-Raster, das Teil dreht sich langsam um die eigene Achse.
## Maus ziehen = drehen (dann hält die Drehung kurz an), Rad = Zoom.

const AUTO_SPEED := 0.35         # rad/s
const AUTO_PAUSE := 2.5          # s nach dem Loslassen, bis es wieder selbst dreht

var _vp: SubViewport
var _holder: Node3D
var _cam: Camera3D
var _yaw := 0.6
var _pitch := 0.45
var _dist := 12.0
var _target := Vector3.ZERO
var _dragging := false
var _idle := AUTO_PAUSE


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	add_child(_vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.74, 0.8)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	_vp.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50.0), deg_to_rad(35.0), 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	_vp.add_child(sun)

	# Wasser (leicht durchsichtig, damit man die Schwimmkörper ahnt) und 1-m-Raster
	var water := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	water.mesh = pm
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.1, 0.45, 0.55, 0.78)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.15
	water.material_override = wm
	_vp.add_child(water)
	var grid := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for k in range(-30, 31):
		im.surface_add_vertex(Vector3(k, 0.005, -30))
		im.surface_add_vertex(Vector3(k, 0.005, 30))
		im.surface_add_vertex(Vector3(-30, 0.005, k))
		im.surface_add_vertex(Vector3(30, 0.005, k))
	im.surface_end()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1, 1, 1, 0.12)
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grid.material_override = gm
	_vp.add_child(grid)

	_holder = Node3D.new()
	_vp.add_child(_holder)
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.far = 500.0
	_vp.add_child(_cam)
	_cam.current = true
	_update_cam()


## Teile anzeigen: ihre Meshes werden in die Vorschau-Welt kopiert. Ausrichtung relativ zum Seil
## (Fahrtrichtung zum Endmast zeigt in der Startansicht nach links hinten), Mitte im Ursprung.
func show_parts(parts: Array, cable: CableSystem) -> void:
	for c in _holder.get_children():
		c.queue_free()
	if parts.is_empty():
		return
	var aabb := AABB()
	var first := true
	for p: FeaturePart in parts:
		var c := p.global_position
		if first:
			aabb = AABB(c, Vector3.ZERO)
			first = false
		aabb = aabb.expand(c)
	var center := aabb.get_center()
	center.y = 0.0
	var to_local := Transform3D(cable.global_basis, center).affine_inverse()
	var bounds := AABB()
	first = true
	for p: FeaturePart in parts:
		for mi in _meshes(p):
			var copy := MeshInstance3D.new()
			copy.mesh = mi.mesh
			copy.material_override = mi.material_override
			copy.transform = to_local * mi.global_transform
			_holder.add_child(copy)
			var b := copy.transform * mi.mesh.get_aabb()
			bounds = b if first else bounds.merge(b)
			first = false
	_target = Vector3(bounds.get_center().x, maxf(bounds.get_center().y, 0.3), bounds.get_center().z)
	var r := Vector2(bounds.size.x, bounds.size.z).length() * 0.5
	_dist = clampf(r * 2.7 + 2.0, 4.0, 80.0)
	_idle = AUTO_PAUSE
	_update_cam()


func _meshes(n: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for c in n.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).mesh != null:
			out.append(c)
		out.append_array(_meshes(c))
	return out


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
			_idle = 0.0
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(_dist / 1.12, 2.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(_dist * 1.12, 80.0)
		_update_cam()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_yaw -= mm.relative.x * 0.008
		_pitch = clampf(_pitch + mm.relative.y * 0.006, -0.05, 1.45)
		_update_cam()
		accept_event()


func _process(delta: float) -> void:
	if _vp == null:
		return
	if not _dragging:
		_idle += delta
		if _idle >= AUTO_PAUSE:
			_yaw += AUTO_SPEED * delta
			_update_cam()


func _update_cam() -> void:
	if _cam == null:
		return
	var off := Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * _dist
	_cam.look_at_from_position(_target + off, _target, Vector3.UP)
