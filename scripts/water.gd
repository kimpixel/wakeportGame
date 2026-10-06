class_name Water
extends Node3D
## Wasseroberfläche: ruhige Grundwellen + Heckwelle des Fahrers.
## Die Heckwelle entsteht aus Kreiswellen, die entlang der Fahrspur ausgesendet werden
## (überlagert ergibt das den typischen V-förmigen Wake). Die Höhenfunktion existiert
## identisch hier (für die Physik) und in shaders/water.gdshader (für die Grafik).

const WAKE_COUNT := 56
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
var _emit_timer := 0.0
var _material: ShaderMaterial


func _ready() -> void:
	_points.resize(WAKE_COUNT)
	for i in WAKE_COUNT:
		_points[i] = Vector4(0.0, 0.0, -1000.0, 0.0)

	var w := Lake.MAX_X - Lake.MIN_X + 8.0
	var d := Lake.MAX_Z - Lake.MIN_Z + 8.0
	var plane := PlaneMesh.new()
	plane.size = Vector2(w, d)
	plane.subdivide_width = int(w / 0.6)
	plane.subdivide_depth = int(d / 0.6)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/water.gdshader")
	plane.material = _material

	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3((Lake.MIN_X + Lake.MAX_X) * 0.5, 0.0, (Lake.MIN_Z + Lake.MAX_Z) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 2.0
	add_child(mi)


func step(delta: float) -> void:
	sim_time += delta


## Wird vom Fahrer jeden Physikschritt aufgerufen, solange das Brett im Wasser ist.
func emit_wake(pos: Vector3, strength: float, delta: float) -> void:
	_emit_timer -= delta
	if _emit_timer > 0.0:
		return
	_emit_timer = WAKE_INTERVAL
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
	_material.set_shader_parameter("sim_time", sim_time)
	_material.set_shader_parameter("wake_points", _points)
