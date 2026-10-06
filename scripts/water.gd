class_name Water
extends Node3D
## Wasseroberfläche: ruhige Grundwellen + Heckwelle des Fahrers.
## Die Heckwelle entsteht aus Kreiswellen, die entlang der Fahrspur ausgesendet werden
## (überlagert ergibt das den typischen V-förmigen Wake). Die Höhenfunktion existiert
## identisch hier (für die Physik) und in shaders/water.gdshader (für die Grafik).

const WAKE_COUNT := 96   # reicht für zwei Fahrer (Spieler + NPC auf T1)
const WAKE_INTERVAL := 0.1
const WAKE_SPEED := 2.6
const WAKE_WIDTH := 0.9
const WAKE_K := 3.0
const WAKE_AMP := 0.2
const WAKE_DECAY := 0.55
const WAKE_LIFE := 5.6

var sim_time := 0.0

var _points := PackedVector4Array()
var _next := 0
var _emit_timers := {}   # pro Fahrer ein eigener Takt
const PATCH_SIZE := 160.0          # feines Gitter rund um den Fahrer
const LAKE_RECT := Rect2(-490.0, -635.0, 595.0, 720.0)   # ganzer See in Spielkoordinaten

## Dem folgt das feine Wassergitter (normalerweise der Fahrer).
var follow: Node3D

var _material: ShaderMaterial
var _coarse_material: ShaderMaterial
var _patch: MeshInstance3D
var _cell := 0.5


func _ready() -> void:
	_points.resize(WAKE_COUNT)
	for i in WAKE_COUNT:
		_points[i] = Vector4(0.0, 0.0, -1000.0, 0.0)

	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_material = _make_material(compat)
	_coarse_material = _make_material(compat)
	_coarse_material.set_shader_parameter("use_wake", false)
	_coarse_material.set_shader_parameter("hole_half", PATCH_SIZE * 0.5 - 1.0)

	# Feines Gitter (Wellen + Heckwelle), folgt dem Fahrer in ganzen Gitterschritten.
	# Im Browser gröber, damit es auch auf schwächeren Rechnern flüssig läuft.
	_cell = 1.0 if OS.has_feature("web") else 0.5
	var fine := PlaneMesh.new()
	fine.size = Vector2(PATCH_SIZE, PATCH_SIZE)
	fine.subdivide_width = int(PATCH_SIZE / _cell) - 1
	fine.subdivide_depth = int(PATCH_SIZE / _cell) - 1
	fine.material = _material
	_patch = MeshInstance3D.new()
	_patch.mesh = fine
	_patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_patch.extra_cull_margin = 2.0
	add_child(_patch)

	# Grobes Gitter für den restlichen See; unter dem feinen Gitter abgesenkt.
	var coarse := PlaneMesh.new()
	coarse.size = LAKE_RECT.size
	coarse.subdivide_width = int(LAKE_RECT.size.x / 4.0)
	coarse.subdivide_depth = int(LAKE_RECT.size.y / 4.0)
	coarse.material = _coarse_material
	var cm := MeshInstance3D.new()
	cm.mesh = coarse
	cm.position = Vector3(LAKE_RECT.get_center().x, 0.0, LAKE_RECT.get_center().y)
	cm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cm.extra_cull_margin = 2.0
	add_child(cm)


func _make_material(compat: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	# Türkis wie auf den Fotos vom Waldsee; der Browser-Renderer belichtet heller.
	if compat:
		m.set_shader_parameter("deep_color", Color(0.0, 0.27, 0.29))
		m.set_shader_parameter("shallow_color", Color(0.06, 0.46, 0.44))
	else:
		m.set_shader_parameter("deep_color", Color(0.0, 0.26, 0.29))
		m.set_shader_parameter("shallow_color", Color(0.08, 0.52, 0.5))
	return m


func step(delta: float) -> void:
	sim_time += delta


## Wird vom Fahrer jeden Physikschritt aufgerufen, solange das Brett im Wasser ist.
func emit_wake(pos: Vector3, strength: float, delta: float, emitter := 0) -> void:
	var t: float = _emit_timers.get(emitter, 0.0) - delta
	_emit_timers[emitter] = t
	if t > 0.0:
		return
	_emit_timers[emitter] = WAKE_INTERVAL
	_points[_next] = Vector4(pos.x, pos.z, sim_time, strength)
	_next = (_next + 1) % WAKE_COUNT


func clear_wake() -> void:
	for i in WAKE_COUNT:
		_points[i] = Vector4(0.0, 0.0, -1000.0, 0.0)


## Wasserhöhe an (x, z). min_age blendet ganz frische Wellen aus
## (damit der Fahrer nicht von seiner eigenen Bugwelle geschoben wird).
func height_at(x: float, z: float, min_age := 0.0) -> float:
	var h := ambient(x, z, sim_time)
	for p: Vector4 in _points:
		var age := sim_time - p.z
		if age < min_age or age > WAKE_LIFE:
			continue
		var dx := x - p.x
		var dz := z - p.y
		h += ring(sqrt(dx * dx + dz * dz), age, p.w)
	return h


static func ambient(x: float, z: float, t: float) -> float:
	return 0.045 * sin(x * 0.31 + z * 0.17 + t * 1.15) \
		+ 0.03 * sin(-x * 0.23 + z * 0.47 + t * 1.6) \
		+ 0.018 * sin(x * 0.71 - z * 0.53 + t * 2.3)


static func ring(r: float, age: float, strength: float) -> float:
	var front := WAKE_SPEED * age + 0.3
	var d := r - front
	var env := exp(-d * d / (WAKE_WIDTH * WAKE_WIDTH))
	var decay := (1.0 - exp(-age * 3.0)) * exp(-age * WAKE_DECAY) / sqrt(1.0 + 0.35 * front)
	return strength * WAKE_AMP * env * decay * cos(d * WAKE_K)


func _process(_delta: float) -> void:
	if follow:
		var c := follow.global_position
		var step := _cell * 2.0
		_patch.position = Vector3(roundf(c.x / step) * step, 0.0, roundf(c.z / step) * step)
	var hole := Vector2(_patch.position.x, _patch.position.z)
	for m: ShaderMaterial in [_material, _coarse_material]:
		m.set_shader_parameter("sim_time", sim_time)
		m.set_shader_parameter("hole_center", hole)
	_material.set_shader_parameter("wake_points", _points)
