class_name Weather
extends Node
## Wetter, Jahreszeit und Uhrzeit am Wakeport: Sonnenstand aus Datum/Uhrzeit (SunCalc),
## Licht, Himmel (shaders/sky.gdshader), Dunst und Regen. "Jetzt" übernimmt Datum und Uhrzeit
## des Rechners und holt das aktuelle Wetter am See (open-meteo.com, ohne Schlüssel).

signal changed

const PRESETS := [
	{"id": "sonnig", "name": "Sonnig", "cloud": 0.05, "rain": 0.0, "haze": 0.0},
	{"id": "heiter", "name": "Heiter", "cloud": 0.35, "rain": 0.0, "haze": 0.0},
	{"id": "bewoelkt", "name": "Bewölkt", "cloud": 0.65, "rain": 0.0, "haze": 0.1},
	{"id": "bedeckt", "name": "Bedeckt", "cloud": 0.95, "rain": 0.0, "haze": 0.25},
	{"id": "regen", "name": "Regen", "cloud": 1.0, "rain": 1.0, "haze": 0.5},
	{"id": "dunst", "name": "Dunst", "cloud": 0.5, "rain": 0.0, "haze": 1.0},
]
const API := "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=weather_code,cloud_cover"

var year := 2026
var day := 172                    # Tag im Jahr
var hour := 14.5                  # deutsche Ortszeit
var preset := 0
var live := false                 # "Jetzt": Uhrzeit läuft mit der Rechneruhr mit

var sun: DirectionalLight3D
var shadow_distance := 200.0     # Grafikqualität: 0 = keine Schatten
var env: Environment
var _sky_mat: ShaderMaterial
var _rain: CPUParticles3D
var _http: HTTPRequest
var _compat := false
var _live_t := 0.0
var _anim_t := 0.0


func _ready() -> void:
	_compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)

	_rain = CPUParticles3D.new()
	_rain.amount = 900 if _compat else 2500
	_rain.lifetime = 1.1
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(22.0, 1.0, 22.0)
	_rain.direction = Vector3(0.08, -1.0, 0.0)
	_rain.spread = 2.0
	_rain.initial_velocity_min = 11.0
	_rain.initial_velocity_max = 13.0
	_rain.gravity = Vector3.ZERO
	var drop := BoxMesh.new()
	drop.size = Vector3(0.012, 0.45, 0.012)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.75, 0.8, 0.88, 0.45)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	_rain.mesh = drop
	_rain.local_coords = false
	_rain.emitting = false
	add_child(_rain)

	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_weather)
	year = int(Time.get_datetime_dict_from_system()["year"])
	apply()


func preset_names() -> Array:
	return PRESETS.map(func(p: Dictionary) -> String: return p["name"])


func find_preset(id: String) -> int:
	for i in PRESETS.size():
		if PRESETS[i]["id"] == id:
			return i
	return 0


func set_day(d: int) -> void:
	day = clampi(d, 1, 365)
	live = false
	apply()


func set_hour(h: float) -> void:
	hour = clampf(h, 0.0, 24.0)
	live = false
	apply()


func set_preset(i: int) -> void:
	preset = clampi(i, 0, PRESETS.size() - 1)
	apply()


## Heute/jetzt: Datum und Uhrzeit vom Rechner, Wetter live vom See (falls erreichbar).
func set_now() -> void:
	live = true
	_sync_clock()
	apply()
	_http.cancel_request()
	_http.request(API % [SunCalc.LAT, SunCalc.LON])


func _sync_clock() -> void:
	var now := Time.get_datetime_dict_from_system()
	year = int(now["year"])
	day = SunCalc.day_of_year(year, int(now["month"]), int(now["day"]))
	hour = float(now["hour"]) + float(now["minute"]) / 60.0


func _on_weather(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary) or not data.has("current"):
		return
	var cur: Dictionary = data["current"]
	var wc := int(cur.get("weather_code", 0))
	var cover := float(cur.get("cloud_cover", 0.0))
	var id := "sonnig"
	if wc >= 51:
		id = "regen"                       # Niesel, Regen, Schauer, Gewitter
	elif wc == 45 or wc == 48:
		id = "dunst"
	elif cover > 85.0 or wc == 3:
		id = "bedeckt"
	elif cover > 50.0 or wc == 2:
		id = "bewoelkt"
	elif cover > 15.0 or wc == 1:
		id = "heiter"
	preset = find_preset(id)
	apply()


func date_text() -> String:
	return SunCalc.date_text(year, day)


func time_text() -> String:
	var m := int(round(hour * 60.0)) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]


## Sonnenstand (Höhe, Azimut in Grad) für die eingestellte Zeit.
func sun_position() -> Vector2:
	var utc := hour - SunCalc.utc_offset(year, day)
	var d := day
	if utc < 0.0:
		utc += 24.0
		d -= 1
	return SunCalc.position(maxi(d, 1), utc)


func apply() -> void:
	if env == null:
		return
	var p: Dictionary = PRESETS[preset]
	var cloud: float = p["cloud"]
	var rain: float = p["rain"]
	var haze: float = p["haze"]
	var sp := sun_position()
	var el := sp.x
	var az := deg_to_rad(sp.y)
	var flat := Geo.rel_to_game(sin(az), cos(az))
	var to_sun := Vector3(flat.x * cos(deg_to_rad(el)), sin(deg_to_rad(el)), flat.y * cos(deg_to_rad(el))).normalized()
	var dayf := smoothstep(-8.0, 8.0, el)                 # Dämmerung bis Tag
	var golden := 1.0 - smoothstep(2.0, 22.0, el)         # tiefe Sonne: warmes Licht
	if el < -6.0:
		golden *= smoothstep(-14.0, -6.0, el)
	var sky_energy := 0.8 if _compat else 1.0
	_sky_mat.set_shader_parameter("sun_dir", to_sun)
	_sky_mat.set_shader_parameter("day", dayf)
	_sky_mat.set_shader_parameter("golden", golden)
	_sky_mat.set_shader_parameter("cloud", cloud)
	_sky_mat.set_shader_parameter("rain", rain)
	_sky_mat.set_shader_parameter("energy", sky_energy)

	# Licht: Sonne, nachts schwaches Mondlicht (gegenüber, fest 35° hoch)
	var up := smoothstep(-2.0, 6.0, el)
	var dir := to_sun
	var color := Color(1.0, 0.97, 0.92).lerp(Color(1.0, 0.6, 0.35), golden)
	var energy := up * (1.0 - 0.7 * cloud)
	if up < 0.05:
		dir = Vector3(-to_sun.x, 0.0, -to_sun.z).normalized() * cos(deg_to_rad(35.0)) + Vector3.UP * sin(deg_to_rad(35.0))
		color = Color(0.6, 0.7, 1.0)
		energy = 0.12 * (1.0 - 0.6 * cloud)
	if dir.y < 0.05:
		dir = (dir + Vector3.UP * (0.05 - dir.y)).normalized()     # Schatten nicht endlos lang
	sun.basis = Basis.looking_at(-dir)
	sun.light_color = color
	sun.light_energy = energy * (0.65 if _compat else 1.0)
	sun.shadow_enabled = energy > 0.08 and cloud < 0.85 and shadow_distance > 0.0
	sun.directional_shadow_max_distance = maxf(shadow_distance, 1.0)

	# Umgebungslicht: Himmel + neutrales Grau, nachts dunkel, bei Wolken weicher
	env.ambient_light_color = Color(0.62, 0.6, 0.55).lerp(Color(0.12, 0.14, 0.22), 1.0 - dayf)
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_energy = lerpf(0.25, 1.0, dayf) * (1.0 + 0.3 * cloud) * (0.3 if _compat else 1.0)
	env.tonemap_exposure = (0.8 if _compat else 1.0) * lerpf(1.6, 1.0, dayf)
	# Dunst und Regen: kürzere Sicht
	var hor := Color(0.7, 0.78, 0.88).lerp(Color(0.05, 0.06, 0.1), 1.0 - dayf)
	hor = hor.lerp(Color(0.55, 0.57, 0.6) * maxf(dayf, 0.1), cloud * 0.7)
	if _compat:
		hor = hor * 0.75
	env.fog_light_color = hor
	env.fog_density = 0.00022 + haze * 0.004 + rain * 0.002
	# Himmel nur bei Dunst/Regen eintrüben (sonst sieht man Wolken und Abendrot nicht)
	env.fog_sky_affect = clampf(0.1 + haze * 0.6 + rain * 0.4, 0.0, 1.0)
	_rain.emitting = rain > 0.0
	changed.emit()


func _process(delta: float) -> void:
	_anim_t += delta
	_sky_mat.set_shader_parameter("t", _anim_t)
	if live:
		_live_t += delta
		if _live_t > 30.0:
			_live_t = 0.0
			_sync_clock()
			apply()
	if _rain.emitting:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_rain.global_position = cam.global_position + Vector3(0.0, 9.0, 0.0)
