class_name Weather
extends Node
## Wetter, Jahreszeit und Uhrzeit am Wakeport: Sonnenstand aus Datum/Uhrzeit (SunCalc),
## Licht, Himmel (shaders/sky.gdshader), Dunst, Bodennebel, Regen und Schnee. "Jetzt" übernimmt Datum
## und Uhrzeit des Rechners und holt das aktuelle Wetter am See (open-meteo.com, ohne Schlüssel).
##
## Szenarien (SCENARIOS): feste Kombinationen aus Datum, Uhrzeit, Wetter und Extras (Regenbogen,
## Kondensstreifen, Bodennebel). Jeder Start würfelt eins aus (main.gd), wählbar in den Einstellungen.

signal changed

const PRESETS := [
	{"id": "sonnig", "name": "Sonnig", "cloud": 0.05, "rain": 0.0, "haze": 0.0},
	{"id": "heiter", "name": "Heiter", "cloud": 0.35, "rain": 0.0, "haze": 0.0},
	{"id": "bewoelkt", "name": "Bewölkt", "cloud": 0.65, "rain": 0.0, "haze": 0.1},
	{"id": "bedeckt", "name": "Bedeckt", "cloud": 0.95, "rain": 0.0, "haze": 0.25},
	{"id": "schauer", "name": "Schauer", "cloud": 0.6, "rain": 0.35, "haze": 0.15},
	{"id": "regen", "name": "Regen", "cloud": 1.0, "rain": 1.0, "haze": 0.35},
	{"id": "dunst", "name": "Dunst", "cloud": 0.4, "rain": 0.0, "haze": 1.0, "mist": 0.6},
	{"id": "schnee", "name": "Schnee", "cloud": 0.9, "rain": 0.0, "haze": 0.35, "snow": 1.0},
	{"id": "gewitter", "name": "Gewitter", "cloud": 1.0, "rain": 1.0, "haze": 0.3, "storm": 1.0},
]

## Szenarien: day = Tag im Jahr (2026), hour = deutsche Uhrzeit, preset = Wetter-id; Extras überschreiben
## das Wetter (cloud, rain, haze, mist = Bodennebel, rainbow, trails = Kondensstreifen, hot = Hitzetag: viele Badegäste).
## only = "MM-TT": nur an diesem echten Kalendertag im Würfel (dann immer), sonst nicht in der Liste.
## pick = false: nicht gewürfelt (Nacht ist schwerer – unfair für die Rangliste), nur gezielt wählbar.
const SCENARIOS := [
	{"id": "afterhour", "name": "After Hour Raley Session", "day": 230, "hour": 19.75, "preset": "sonnig"},
	{"id": "earlybird", "name": "Early Bird Session", "day": 251, "hour": 8.75, "preset": "dunst", "mist": 1.0,
		"haze": 0.55, "cloud": 0.12},
	{"id": "hochsommer", "name": "Hochsommer. Was für eine Hitze", "day": 187, "hour": 12.0, "preset": "sonnig",
		"haze": 0.25, "hot": 1.0},
	{"id": "regen", "name": "Schöne Regen-Session", "day": 196, "hour": 16.5, "preset": "regen"},
	{"id": "nacht", "name": "Night Session", "day": 222, "hour": 22.75, "preset": "sonnig", "pick": false},
	{"id": "baumschatten", "name": "Sonne hinter den Bäumen", "day": 265, "hour": 18.9, "preset": "sonnig"},
	{"id": "regenbogen", "name": "Nach dem Schauer", "day": 200, "hour": 19.25, "preset": "schauer",
		"rain": 0.15, "rainbow": 1.0},
	{"id": "blauestunde", "name": "Blaue Stunde", "day": 172, "hour": 21.9, "preset": "sonnig"},
	{"id": "oktober", "name": "Goldener Oktober", "day": 285, "hour": 16.25, "preset": "heiter", "haze": 0.15},
	{"id": "kondens", "name": "Chemtrails, oder Kondensstreifen? ;-)", "day": 160, "hour": 15.0, "preset": "sonnig",
		"trails": 1.0},
	{"id": "gewitter", "name": "Gewitter – YOLO", "day": 205, "hour": 18.25, "preset": "gewitter", "pick": false},
	{"id": "nikolaus", "name": "Nikolaus-Session", "day": 340, "hour": 15.0, "preset": "schnee", "only": "12-06"},
]
const NIKOLAUS_DAY := 340         # 6. Dezember: im Schnee fahren = geheimer Erfolg "nikolaus"
const CITY_BEARING := 65.0        # Frankfurt (Stadt + Flughafen) von Raunheim aus: Lichtglocke am Nachthimmel
const MIST_DENSITY := 0.012       # 1/m: Bodennebel direkt über dem Wasser bei mist = 1 (nach oben dünner, shaders/mist.gdshader)
const API := "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=weather_code,cloud_cover"

## Helligkeit für unbeleuchtete Materialien (Leine, Gischt, Regen): 1 am Tag, nachts dunkel – sonst leuchten sie.
static var lum := 1.0
## Stärke der Feature-Spiegelung (Reflection Probes nehmen die Umgebung nur einmal auf): nachts gedämpft,
## sonst leuchten die nassen Features hell.
static var reflect := 1.0
## Dämmerung/Nacht: Features (fast weiß) abdunkeln, Bojen (Signalfarben, extra auffällig) leicht leuchten lassen
static var feature_light := 1.0
static var buoy_glow := 0.0
static var _dim_mats: Array[StandardMaterial3D] = []
static var _glow_mats: Array[StandardMaterial3D] = []


## Material wird wie die Features abgedunkelt (z. B. der blaue Ball).
static func dim_at_night(m: StandardMaterial3D) -> void:
	m.set_meta("base", m.albedo_color)
	_dim_mats.append(m)
	_update_mats()


## Material leuchtet in der Dämmerung und nachts leicht in seiner Farbe (Bojen).
static func glow_at_night(m: StandardMaterial3D) -> void:
	m.emission_enabled = true
	m.emission = m.albedo_color
	_glow_mats.append(m)
	_update_mats()


static func _update_mats() -> void:
	for m in _dim_mats:
		var c: Color = m.get_meta("base")
		m.albedo_color = Color(c.r * feature_light, c.g * feature_light, c.b * feature_light, c.a)
		m.clearcoat = 0.6 * feature_light
	for m in _glow_mats:
		m.emission_energy_multiplier = buoy_glow

var year := 2026
var day := 218                    # Tag im Jahr
var hour := 19.75                 # deutsche Ortszeit
var preset := 0
var scenario := ""                # id des Szenarios ("" = von Hand eingestellt)
var live := false                 # "Jetzt": Uhrzeit läuft mit der Rechneruhr mit

## Jahreszeit und Stimmung für Leben am See (Ambient, Wildlife, Bathers), gesetzt in apply()
var warm := 1.0                   # 0 Mitte Januar … 1 Mitte Juli
var heat := 0.0                   # heißer Badetag (Sommer, Sonne, Nachmittag; Szenario hot): viele SUPs, Badegäste
var daylight := 1.0               # 0 Nacht … 1 Tag
var rain_now := 0.0
var snow_now := 0.0
var storm := 0.0                  # Gewitter (Blitze: Storm)
var autumn := 0.0                 # Herbstfärbung der Laubbäume
var bare := 0.0                   # Laubbäume kahl (Winter)

var sun: DirectionalLight3D
var shadow_distance := 200.0     # Grafikqualität: 0 = keine Schatten
var shadow_splits := 4           # Grafikqualität: Schatten-Kaskaden (2 = jeder Schattenwerfer halb so oft gezeichnet)
var env: Environment
var _sky_mat: ShaderMaterial
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _fluff: CPUParticles3D        # Pappelflug im Mai (weiße Samenflocken)
var _drop_mat: StandardMaterial3D
var _flake_mat: StandardMaterial3D
var _mist: MeshInstance3D
var _mist_mat: ShaderMaterial
var _sky_energy := 1.0
var _amb_energy := 1.0
var _sun_energy := 1.0
var _flash := 0.0                 # Blitz: hellt Himmel und Szene kurz auf (flash)
var _flash_t := 0.0
var _extra := {}                  # Extras des Szenarios (überschreiben das Wetter)
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
	_drop_mat = StandardMaterial3D.new()
	_drop_mat.albedo_color = Color(0.75, 0.8, 0.88, 0.45)
	_drop_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_drop_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = _drop_mat
	_rain.mesh = drop
	_rain.local_coords = false
	_rain.emitting = false
	add_child(_rain)

	# Schneeflocken: langsam, taumelnd, weite Sicht nach oben
	_snow = CPUParticles3D.new()
	_snow.amount = 700 if _compat else 1800
	_snow.lifetime = 7.0
	_snow.preprocess = 7.0
	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(24.0, 1.0, 24.0)
	_snow.direction = Vector3(0.15, -1.0, 0.05)
	_snow.spread = 25.0
	_snow.initial_velocity_min = 0.9
	_snow.initial_velocity_max = 1.6
	_snow.gravity = Vector3.ZERO
	_snow.angular_velocity_min = -90.0
	_snow.angular_velocity_max = 90.0
	_snow.scale_amount_min = 0.6
	_snow.scale_amount_max = 1.4
	var flake := QuadMesh.new()
	flake.size = Vector2(0.045, 0.045)
	_flake_mat = StandardMaterial3D.new()
	_flake_mat.albedo_color = Color(0.95, 0.96, 1.0, 0.9)
	_flake_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flake_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flake_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	flake.material = _flake_mat
	_snow.mesh = flake
	_snow.local_coords = false
	_snow.emitting = false
	add_child(_snow)

	# Pappelflug (Mai): wenige große, langsam treibende Flocken
	_fluff = _snow.duplicate() as CPUParticles3D
	_fluff.amount = 120 if _compat else 260
	_fluff.direction = Vector3(1.0, -0.15, 0.4)
	_fluff.spread = 60.0
	_fluff.initial_velocity_min = 0.3
	_fluff.initial_velocity_max = 0.9
	_fluff.scale_amount_min = 1.0
	_fluff.scale_amount_max = 2.0
	_fluff.lifetime = 9.0
	_fluff.preprocess = 9.0
	_fluff.emission_box_extents = Vector3(22.0, 4.0, 22.0)
	_fluff.emitting = false
	add_child(_fluff)

	_build_mist()

	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_weather)
	apply()


## Bodennebel: ein Quad über das ganze Bild (der Shader setzt es vor die Kamera und rechnet je Blickstrahl).
func _build_mist() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_mist_mat = ShaderMaterial.new()
	_mist_mat.shader = load("res://shaders/mist.gdshader")
	_mist_mat.render_priority = 9                  # nach dem (transparenten) Wasser zeichnen
	_mist = MeshInstance3D.new()
	_mist.mesh = quad
	_mist.material_override = _mist_mat
	_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mist.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))   # nie wegsortiert
	_mist.visible = false
	add_child(_mist)


func preset_names() -> Array:
	return PRESETS.map(func(p: Dictionary) -> String: return p["name"])


func find_preset(id: String) -> int:
	for i in PRESETS.size():
		if PRESETS[i]["id"] == id:
			return i
	return 0


# ---------------------------------------------------------------- Szenarien

## Szenarien, die in der Liste stehen und gewürfelt werden (ohne die an einen Kalendertag gebundenen,
## außer heute ist dieser Tag).
static func scenario_list() -> Array:
	var today := Time.get_datetime_string_from_system().substr(5, 5)    # "MM-TT"
	return SCENARIOS.filter(func(s: Dictionary) -> bool: return not s.has("only") or s["only"] == today)


static func find_scenario(id: String) -> Dictionary:
	for s: Dictionary in SCENARIOS:
		if s["id"] == id:
			return s
	return {}


## Zufälliges Szenario (nicht wieder avoid); an seinem Kalendertag gewinnt das gebundene (Nikolaus) immer.
static func random_scenario(avoid := "") -> String:
	var list := scenario_list()
	for s: Dictionary in list:
		if s.has("only"):
			return s["id"]
	list = list.filter(func(s: Dictionary) -> bool: return s.get("pick", true) and s["id"] != avoid)
	return list[randi() % list.size()]["id"]


func scenario_name() -> String:
	return str(find_scenario(scenario).get("name", ""))


func set_scenario(id: String) -> void:
	var s := find_scenario(id)
	if s.is_empty():
		return
	scenario = id
	live = false
	day = s["day"]
	hour = s["hour"]
	preset = find_preset(s["preset"])
	_extra = {}
	for k: String in ["cloud", "rain", "haze", "mist", "rainbow", "trails", "hot"]:
		if s.has(k):
			_extra[k] = s[k]
	apply()


## Gerade im Nikolaus-Schnee (geheimer Erfolg "nikolaus").
func is_nikolaus() -> bool:
	return day == NIKOLAUS_DAY and PRESETS[preset]["id"] == "schnee"


# ---------------------------------------------------------------- von Hand

func set_day(d: int) -> void:
	day = clampi(d, 1, 365)
	live = false
	scenario = ""
	apply()


func set_hour(h: float) -> void:
	hour = clampf(h, 0.0, 24.0)
	live = false
	scenario = ""
	apply()


func set_preset(i: int) -> void:
	preset = clampi(i, 0, PRESETS.size() - 1)
	scenario = ""
	_extra = {}
	apply()


## Heute/jetzt: Datum und Uhrzeit vom Rechner, Wetter live vom See (falls erreichbar).
func set_now() -> void:
	live = true
	scenario = ""
	_extra = {}
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
	if (wc >= 71 and wc <= 77) or wc == 85 or wc == 86:
		id = "schnee"
	elif wc >= 80 and wc <= 82:
		id = "schauer"
	elif wc >= 51:
		id = "regen"                       # Niesel, Regen, Gewitter
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


func _val(p: Dictionary, key: String) -> float:
	return float(_extra.get(key, p.get(key, 0.0)))


func apply() -> void:
	if env == null:
		return
	var p: Dictionary = PRESETS[preset]
	var cloud := _val(p, "cloud")
	var rain := _val(p, "rain")
	var haze := _val(p, "haze")
	var mist := _val(p, "mist")
	var snow := _val(p, "snow")
	var sp := sun_position()
	var el := sp.x
	var az := deg_to_rad(sp.y)
	var flat := Geo.rel_to_game(sin(az), cos(az))
	var to_sun := Vector3(flat.x * cos(deg_to_rad(el)), sin(deg_to_rad(el)), flat.y * cos(deg_to_rad(el))).normalized()
	var dayf := smoothstep(-8.0, 8.0, el)                 # Dämmerung bis Tag
	var golden := 1.0 - smoothstep(2.0, 22.0, el)         # tiefe Sonne: warmes Licht
	if el < -6.0:
		golden *= smoothstep(-14.0, -6.0, el)
	elif el > 0.0:
		golden = maxf(golden, mist * 0.7)                 # Morgennebel: goldenes Gegenlicht
	# Mond (Vollmond gegenüber der Sonne, fest 35° hoch) und Lichtglocke von Frankfurt
	var moon := (Vector3(-to_sun.x, 0.0, -to_sun.z).normalized() * cos(deg_to_rad(35.0))
		+ Vector3.UP * sin(deg_to_rad(35.0)))
	var cb := deg_to_rad(CITY_BEARING)
	var city := Geo.rel_to_game(sin(cb), cos(cb)).normalized()
	_sky_mat.set_shader_parameter("sun_dir", to_sun)
	_sky_mat.set_shader_parameter("moon_dir", moon)
	_sky_mat.set_shader_parameter("city_dir", Vector3(city.x, 0.0, city.y))
	_sky_mat.set_shader_parameter("day", dayf)
	_sky_mat.set_shader_parameter("golden", golden)
	_sky_mat.set_shader_parameter("cloud", cloud)
	_sky_mat.set_shader_parameter("rain", rain)
	_sky_mat.set_shader_parameter("snow", snow)
	_sky_mat.set_shader_parameter("rainbow", _val(p, "rainbow"))
	_sky_mat.set_shader_parameter("trails", _val(p, "trails"))
	storm = _val(p, "storm")
	_sky_energy = 1.0 - 0.45 * storm                      # Gewitter: düster
	_sky_mat.set_shader_parameter("energy", _sky_energy)
	var dusk := smoothstep(0.3, 1.0, dayf)                # 0 ab Blauer Stunde bis Nacht, 1 am Tag
	_sky_mat.set_shader_parameter("radiance", lerpf(0.25, 1.0, dusk))

	# Licht: Sonne, nachts schwaches Mondlicht
	var up := smoothstep(-2.0, 6.0, el)
	var dir := to_sun
	var color := Color(1.0, 0.97, 0.92).lerp(Color(1.0, 0.6, 0.35), golden)
	var energy := up * (1.0 - 0.7 * cloud)
	if up < 0.05:
		dir = moon
		color = Color(0.55, 0.65, 1.0)
		energy = 0.035 * (1.0 - 0.7 * cloud)    # schwach: helle Flächen (Features, Sand) wirken sonst wie beleuchtet
	if dir.y < 0.05:
		dir = (dir + Vector3.UP * (0.05 - dir.y)).normalized()     # Schatten nicht endlos lang
	sun.basis = Basis.looking_at(-dir)
	sun.light_color = color
	sun.light_specular = 0.05 if up < 0.05 else 0.5          # Mond: kaum Glanzflecken auf den nassen Features
	sun.light_energy = energy * (0.8 if _compat else 1.0)   # Web-Renderer (Compatibility): Wasser sonst grell
	_sun_energy = sun.light_energy
	sun.shadow_enabled = energy > 0.08 and cloud < 0.85 and shadow_distance > 0.0
	sun.directional_shadow_max_distance = maxf(shadow_distance, 1.0)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if shadow_splits == 2 else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS

	# Umgebungslicht: Himmel + neutrales Grau, nachts dunkel, bei Wolken weicher; Schnee hellt auf
	env.ambient_light_color = Color(0.62, 0.6, 0.55).lerp(Color(0.09, 0.11, 0.2), 1.0 - dayf)
	env.ambient_light_sky_contribution = 0.45
	env.ambient_light_energy = (lerpf(0.12, 1.0, dayf) * (1.0 + 0.3 * cloud + 0.25 * snow)
		* (0.7 if _compat else 1.0) * (1.0 - 0.4 * storm))
	_amb_energy = env.ambient_light_energy
	env.tonemap_exposure = (0.9 if _compat else 1.0) * lerpf(0.9, 1.0, dayf)
	# Dunst, Regen und Schnee: kürzere Sicht
	var hor := Color(0.7, 0.78, 0.88).lerp(Color(0.03, 0.04, 0.07), 1.0 - dayf)
	hor = hor.lerp(Color(0.55, 0.57, 0.6) * maxf(dayf, 0.06), cloud * 0.7)
	hor = hor.lerp(Color(0.92, 0.83, 0.66) * maxf(dayf, 0.06), mist * 0.6)   # Morgennebel: hell, warm
	if _compat:
		hor = hor * 0.75
	env.fog_light_color = hor
	env.fog_density = 0.00022 + haze * 0.0045 + rain * 0.002 + snow * 0.002
	env.fog_sun_scatter = (haze * 0.08 + mist * 0.12) * up
	# Bodennebel über dem Wasser (_build_mist)
	_mist.visible = mist > 0.0
	_mist_mat.set_shader_parameter("density", MIST_DENSITY * mist)
	_mist_mat.set_shader_parameter("mist_color", Color(0.86, 0.8, 0.7) * lerpf(0.15, 1.0, dayf))
	_mist_mat.set_shader_parameter("sun_color", color * up)
	_mist_mat.set_shader_parameter("sun_dir", to_sun)
	# Himmel nur bei Dunst eintrüben (sonst sieht man Wolken, Regenwolken und Abendrot nicht)
	env.fog_sky_affect = clampf(0.1 + haze * 0.45 + rain * 0.1, 0.0, 1.0)
	_rain.emitting = rain > 0.0
	var drops := int((900 if _compat else 2500) * clampf(rain * 1.5, 0.3, 1.0))   # Schauer: weniger Tropfen
	if rain > 0.0 and _rain.amount != drops:
		_rain.amount = drops
	_snow.emitting = snow > 0.0
	# Jahreszeit: Wärme (Kurve über das Jahr), Badetag, Laub
	daylight = dayf
	rain_now = rain
	snow_now = snow
	warm = 0.5 - 0.5 * cos(TAU * (day - 20) / 365.0)
	var afternoon := smoothstep(10.0, 13.0, hour) * (1.0 - smoothstep(19.0, 21.0, hour))
	heat = clampf(smoothstep(0.75, 0.97, warm) * afternoon * (1.0 - cloud) * (1.0 - rain) * 1.3, 0.0, 1.0)
	heat = maxf(heat, _val(p, "hot"))
	_leaves()
	RenderingServer.global_shader_parameter_set("autumn", autumn)
	RenderingServer.global_shader_parameter_set("bare", bare)
	_fluff.emitting = day >= 125 and day <= 160 and rain == 0.0 and dayf > 0.5
	RenderingServer.global_shader_parameter_set("snow", snow)
	# Features (fast weiß) stechen in der Dämmerung und nachts neben dunklem Wald und Wasser grell heraus
	feature_light = lerpf(0.12, 1.0, dusk)
	buoy_glow = (1.0 - dusk) * 0.15
	RenderingServer.global_shader_parameter_set("feature_light", feature_light)
	_update_mats()

	# unbeleuchtete Materialien mit dem Licht abdunkeln
	lum = clampf(lerpf(0.13, 1.0, dayf) * (1.0 - 0.25 * cloud), 0.0, 1.0)
	_drop_mat.albedo_color = Color(0.75 * lum, 0.8 * lum, 0.88 * lum, 0.45)
	_flake_mat.albedo_color = Color(0.95 * lum, 0.96 * lum, lum, 0.9)
	SpraySheet.set_light(lum)
	reflect = lerpf(0.12, 1.0, dusk) * (1.0 - 0.3 * cloud)
	if is_inside_tree():
		for pr in get_tree().get_nodes_in_group("feature_probe"):
			if (pr as ReflectionProbe).reflection_mask != 0:    # noch in der Aufnahme: blendet selbst ein
				(pr as ReflectionProbe).intensity = FeaturePart.REFLECT * reflect
	Spray.set_light(lum)
	changed.emit()


## Laub nach Tag im Jahr: ab Ende September gelb/rot, ab November kahl, im April wieder grün.
func _leaves() -> void:
	var d := float(day)
	if d >= 330.0 or d < 95.0:
		autumn = 0.5                 # letzte braune Blätter
		bare = 0.85
	elif d < 130.0:
		autumn = 0.5 * (1.0 - smoothstep(95.0, 110.0, d))
		bare = 0.85 * (1.0 - smoothstep(95.0, 128.0, d))
	else:
		autumn = smoothstep(262.0, 292.0, d)
		bare = 0.85 * smoothstep(295.0, 330.0, d)


## Monat 1..12 des eingestellten Tages.
func month() -> int:
	return int(SunCalc._date(year, day)["month"])


## Blitz: Himmel und Szene flackern kurz hell auf (Stärke 0..1, nah = 1).
func flash(strength: float) -> void:
	_flash = maxf(_flash, strength)
	_flash_t = 0.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash_t += delta
		var f := _flash * exp(-_flash_t * 9.0) * (0.6 + 0.4 * absf(sin(_flash_t * 55.0)))   # flackert
		if _flash_t > 0.6:
			_flash = 0.0
			f = 0.0
		_sky_mat.set_shader_parameter("energy", _sky_energy * (1.0 + f * 3.0))
		env.ambient_light_energy = _amb_energy * (1.0 + f * 6.0)
		sun.light_energy = _sun_energy + f * 1.5
	_anim_t += delta
	_sky_mat.set_shader_parameter("t", _anim_t)
	if _mist.visible:
		_mist_mat.set_shader_parameter("t", _anim_t)
	if live:
		_live_t += delta
		if _live_t > 30.0:
			_live_t = 0.0
			_sync_clock()
			apply()
	if _rain.emitting or _snow.emitting or _fluff.emitting:
		var cam := get_viewport().get_camera_3d()
		if cam:
			_rain.global_position = cam.global_position + Vector3(0.0, 9.0, 0.0)
			_snow.global_position = cam.global_position + Vector3(0.0, 8.0, 0.0)
			_fluff.global_position = cam.global_position + Vector3(0.0, 2.0, 0.0)
