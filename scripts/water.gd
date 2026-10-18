class_name Water
extends Node3D
## Wasseroberfläche: ruhige Grundwellen + Heckwelle des Fahrers.
## Die Heckwelle entsteht aus Kreiswellen, die entlang der Fahrspur ausgesendet werden
## (überlagert ergibt das den typischen V-förmigen Wake). Die Höhenfunktion existiert
## identisch hier (für die Physik) und in shaders/water.gdshader (für die Grafik).

const FLAT_SHADER := preload("res://shaders/water.gdshader")
const DEPTH_SHADER := preload("res://shaders/water_depth.gdshader")
const WAKE_COUNT := 96   # reicht für zwei Fahrer (Spieler + NPC auf T1)
const WAKE_INTERVAL := 0.1
const WAKE_SPEED := 2.6
const WAKE_WIDTH := 0.9
const WAKE_K := 3.0
const WAKE_AMP := 0.2
const WAKE_DECAY := 0.55
const WAKE_LIFE := 5.6
## Bootswelle: eigene, viel größere Kreiswellen (längere Welle, breiter, lebt länger) – entlang der
## Fahrt ausgesendet ergibt das die große V-Welle hinter dem Boot. Gleiche Werte im Shader (BOAT_*).
const BOAT_COUNT := 32
const BOAT_INTERVAL := 0.25
const BOAT_SPEED := 3.2
const BOAT_WIDTH := 2.5
const BOAT_K := 1.25
const BOAT_AMP := 0.32
const BOAT_DECAY := 0.25
const BOAT_LIFE := 8.0

var sim_time := 0.0

## Wasser-Effekte (Einstellungen -> Wasser), je an/aus. Schlüssel = Shader-Schalter fx_*.
const FX_KEYS := ["detail", "fresnel", "glitter", "crest", "foam", "sharp", "clear"]
## Spitze Wellenkämme: gleiche Formel in Physik (ambient) und Shader (wave)
static var sharp := true
var fx := {}                      # Schlüssel -> an/aus
var sun: DirectionalLight3D       # für Glitzern und Licht durch die Kämme
var env: Environment              # Himmelsfarbe für die Spiegelung
var _tex_a: NoiseTexture2D
var _tex_b: NoiseTexture2D
var _tex_foam: NoiseTexture2D

var _points := PackedVector4Array()
var _next := 0
var _emit_timers := {}   # pro Fahrer ein eigener Takt
var _boat_points := PackedVector4Array()
var _boat_next := 0
var _boat_timer := 0.0
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
	_boat_points.resize(BOAT_COUNT)
	for i in BOAT_COUNT:
		_boat_points[i] = Vector4(0.0, 0.0, -1000.0, 0.0)

	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	for k: String in FX_KEYS:
		fx[k] = true
	_tex_a = _noise_tex(256, 0.012, true, 11)
	_tex_b = _noise_tex(256, 0.02, true, 23)
	_tex_foam = _noise_tex(256, 0.03, false, 37)
	_material = _make_material(compat)
	_coarse_material = _make_material(compat)
	_coarse_material.set_shader_parameter("use_wake", false)
	_coarse_material.set_shader_parameter("hole_half", PATCH_SIZE * 0.5 - 1.0)
	set_color(1)

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
	m.shader = FLAT_SHADER
	m.set_shader_parameter("detail_a", _tex_a)
	m.set_shader_parameter("detail_b", _tex_b)
	m.set_shader_parameter("foam_noise", _tex_foam)
	return m


## Nahtlos kachelnde Rauschtextur (als Normal-Map für die Oberflächenstruktur oder als Graustufen).
func _noise_tex(size: int, freq: float, normal: bool, seed_: int) -> NoiseTexture2D:
	var nz := FastNoiseLite.new()
	nz.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	nz.frequency = freq
	nz.fractal_octaves = 4
	nz.seed = seed_
	var tex := NoiseTexture2D.new()
	tex.width = size
	tex.height = size
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = nz
	if normal:
		tex.as_normal_map = true
		tex.bump_strength = 6.0
	return tex


## Wasserfarbe: 0 Türkis (bisher, wie eine Meeresbucht), 1 Seeblau. Der Browser-Renderer belichtet heller.
func set_color(idx: int) -> void:
	var compat := RenderingServer.get_current_rendering_method() == "gl_compatibility"
	var deep: Color
	var shallow: Color
	if idx == 0:
		deep = Color(0.0, 0.27, 0.29) if compat else Color(0.0, 0.26, 0.29)
		shallow = Color(0.06, 0.46, 0.44) if compat else Color(0.08, 0.52, 0.5)
	else:
		deep = Color(0.02, 0.11, 0.2) if compat else Color(0.03, 0.13, 0.24)
		shallow = Color(0.08, 0.22, 0.34) if compat else Color(0.1, 0.26, 0.4)
	for m: ShaderMaterial in [_material, _coarse_material]:
		m.set_shader_parameter("deep_color", deep)
		m.set_shader_parameter("shallow_color", shallow)


## Einen Wasser-Effekt an/aus. Die Durchsicht braucht die Szenentiefe: dann
## läuft das feine Gitter mit dem (transparenten) Tiefen-Shader, sonst mit dem schnellen.
func set_fx(key: String, on: bool) -> void:
	fx[key] = on
	if key == "sharp":
		sharp = on
	var depth: bool = fx["clear"]
	var sh: Shader = DEPTH_SHADER if depth else FLAT_SHADER
	for m: ShaderMaterial in [_material, _coarse_material]:
		if m.shader != sh:
			m.shader = sh
		for k: String in FX_KEYS:
			m.set_shader_parameter("fx_" + k, fx[k])


func step(delta: float) -> void:
	sim_time += delta


## Wird vom Fahrer jeden Physikschritt aufgerufen, solange das Brett im Wasser ist.
## Aufprall (Landung): eine einzelne, starke Kreiswelle an dieser Stelle.
func impact(pos: Vector3, strength: float) -> void:
	_points[_next] = Vector4(pos.x, pos.z, sim_time, strength)
	_next = (_next + 1) % WAKE_COUNT


func emit_wake(pos: Vector3, strength: float, delta: float, emitter := 0) -> void:
	var t: float = _emit_timers.get(emitter, 0.0) - delta
	_emit_timers[emitter] = t
	if t > 0.0:
		return
	_emit_timers[emitter] = WAKE_INTERVAL
	_points[_next] = Vector4(pos.x, pos.z, sim_time, strength)
	_next = (_next + 1) % WAKE_COUNT


## Bootswelle: jeden Physikschritt vom fahrenden Boot (Heck). Stärke aus dem Bootstempo: langsam klein,
## ab ca. 7 m/s richtig groß (Kamm bis ca. 0,6 m über dem See).
func emit_boat_wake(pos: Vector3, speed: float, delta: float) -> void:
	_boat_timer -= delta
	if _boat_timer > 0.0:
		return
	_boat_timer = BOAT_INTERVAL
	if speed < 1.5:
		return
	var s := 1.4 * smoothstep(1.5, 9.0, speed)
	_boat_points[_boat_next] = Vector4(pos.x, pos.z, sim_time, s)
	_boat_next = (_boat_next + 1) % BOAT_COUNT


func clear_wake() -> void:
	for i in WAKE_COUNT:
		_points[i] = Vector4(0.0, 0.0, -1000.0, 0.0)
	for i in BOAT_COUNT:
		_boat_points[i] = Vector4(0.0, 0.0, -1000.0, 0.0)


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
	for p: Vector4 in _boat_points:
		var age := sim_time - p.z
		if age < 0.0 or age > BOAT_LIFE:
			continue
		var dx := x - p.x
		var dz := z - p.y
		h += boat_ring(sqrt(dx * dx + dz * dz), age, p.w)
	return h


static func ambient(x: float, z: float, t: float) -> float:
	return 0.045 * _wave(x * 0.31 + z * 0.17 + t * 1.15) \
		+ 0.03 * _wave(-x * 0.23 + z * 0.47 + t * 1.6) \
		+ 0.018 * _wave(x * 0.71 - z * 0.53 + t * 2.3)


## Grundwelle wie im Shader: Sinus oder spitz (exp(sin): spitze Kämme, flache Täler).
static func _wave(a: float) -> float:
	return (exp(sin(a)) - 1.2661) * 0.69 if sharp else sin(a)


static func ring(r: float, age: float, strength: float) -> float:
	var front := WAKE_SPEED * age + 0.3
	var d := r - front
	var env := exp(-d * d / (WAKE_WIDTH * WAKE_WIDTH))
	var decay := (1.0 - exp(-age * 3.0)) * exp(-age * WAKE_DECAY) / sqrt(1.0 + 0.35 * front)
	return strength * WAKE_AMP * env * decay * cos(d * WAKE_K)


static func boat_ring(r: float, age: float, strength: float) -> float:
	var front := BOAT_SPEED * age + 0.5
	var d := r - front
	var env := exp(-d * d / (BOAT_WIDTH * BOAT_WIDTH))
	var decay := (1.0 - exp(-age * 2.0)) * exp(-age * BOAT_DECAY) / sqrt(1.0 + 0.15 * front)
	return strength * BOAT_AMP * env * decay * cos(d * BOAT_K)


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
	_material.set_shader_parameter("boat_points", _boat_points)
	if sun:
		var to_sun := sun.global_transform.basis.z.normalized()
		for m: ShaderMaterial in [_material, _coarse_material]:
			m.set_shader_parameter("sun_dir", to_sun)
			m.set_shader_parameter("sun_color", sun.light_color)
			m.set_shader_parameter("sun_energy", sun.light_energy if sun.visible else 0.0)
			if env:
				m.set_shader_parameter("sky_color", env.fog_light_color)
