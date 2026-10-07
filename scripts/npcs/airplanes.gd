class_name Airplanes
extends Node3D
## Flugzeuge im Landeanflug auf Frankfurt (Betriebsrichtung 07): Der Wakeport liegt in der
## Einflugschneise – alle ein, zwei Minuten kommt ein Jet aus Westsüdwest, überfliegt den See
## im 3°-Gleitpfad in etwa 260 m Höhe (Fahrwerk draußen, Lichter an) und ist laut.

const HEADING := 69.0             # Anflugkurs (Grad, rechtweisend)
const GLIDE := 3.0                # Gleitwinkel (Grad)
const ALT_OVER_LAKE := 260.0      # Höhe über dem See
const SIDE_OFFSET := 120.0        # Anfluglinie so weit seitlich der Seemitte (m)
const T_FROM := -5500.0           # Strecke vor / nach dem See (m)
const T_TO := 4300.0

const TYPES := [
	# Länge, Spannweite, Triebwerke, Häufigkeit
	{"len": 37.6, "span": 34.0, "engines": 2, "w": 0.6},     # Mittelstrecke
	{"len": 66.8, "span": 64.8, "engines": 2, "w": 0.3},     # Langstrecke, zweistrahlig
	{"len": 70.7, "span": 64.4, "engines": 4, "w": 0.1},     # Jumbo
]
const TAIL_COLORS := [Color(0.05, 0.14, 0.38), Color(0.78, 0.1, 0.1), Color(0.95, 0.72, 0.1),
	Color(0.1, 0.42, 0.3), Color(0.18, 0.18, 0.2), Color(0.35, 0.55, 0.85)]

var jet_sound: AudioStream
var _dir := Vector3.FORWARD       # Flugrichtung (waagerecht)
var _origin := Vector3.ZERO       # Punkt der Anfluglinie über dem See (Höhe 0)
var _planes: Array[Dictionary] = []
var _next := 25.0
var _t := 0.0


func _ready() -> void:
	var a := deg_to_rad(HEADING)
	var d := Geo.rel_to_game(sin(a), cos(a))
	_dir = Vector3(d.x, 0.0, d.y).normalized()
	var north := Geo.rel_to_game(0.0, 1.0)
	var side := Vector3(_dir.z, 0.0, -_dir.x)
	if side.dot(Vector3(north.x, 0.0, north.y)) < 0.0:
		side = -side
	var lake := Vector3(0.0, 0.0, Lake.MAST_B_Z * 0.5)       # Mitte der T2-Bahn
	_origin = lake + side * SIDE_OFFSET


func _process(delta: float) -> void:
	_t += delta
	_next -= delta
	if _next <= 0.0:
		_next = randf_range(65.0, 140.0)
		_spawn()
	var slope := tan(deg_to_rad(GLIDE))
	for i in range(_planes.size() - 1, -1, -1):
		var p: Dictionary = _planes[i]
		p["s"] = float(p["s"]) + float(p["speed"]) * delta
		var s: float = p["s"]
		var node: Node3D = p["node"]
		if s > T_TO:
			node.queue_free()
			_planes.remove_at(i)
			continue
		var pos := _origin + _dir * s + Vector3.UP * (ALT_OVER_LAKE - s * slope)
		# Anflughaltung: Nase leicht hoch, sanftes Schaukeln
		var b := Basis.looking_at(_dir, Vector3.UP)
		b = b * Basis(Vector3.RIGHT, deg_to_rad(2.5)) * Basis(Vector3.FORWARD, 0.03 * sin(_t * 0.5 + float(p["phase"])))
		node.global_transform = Transform3D(b, pos)
		# Lichter: Blitzer und rotes Drehlicht blinken
		var strobe := fmod(_t + float(p["phase"]), 1.2) < 0.06
		for l: Node3D in p["strobes"]:
			l.visible = strobe
		var beacon := fmod(_t * 1.1 + float(p["phase"]), 1.0) < 0.12
		for l: Node3D in p["beacons"]:
			l.visible = beacon


## Test: sofort ein Flugzeug an Stelle s der Anfluglinie (0 = über dem See).
func spawn_at(s: float) -> void:
	_spawn()
	_planes[-1]["s"] = s
	print("Jet bei ", _origin + _dir * s + Vector3.UP * (ALT_OVER_LAKE - s * tan(deg_to_rad(GLIDE))), " Richtung ", _dir)


func _spawn() -> void:
	var r := randf()
	var type: Dictionary = TYPES[0]
	var acc := 0.0
	for t: Dictionary in TYPES:
		acc += float(t["w"])
		if r <= acc:
			type = t
			break
	var info := _build(type, TAIL_COLORS.pick_random())
	var node: Node3D = info["node"]
	add_child(node)
	if jet_sound:
		var snd := AudioStreamPlayer3D.new()
		snd.stream = jet_sound
		snd.unit_size = 90.0 * (1.3 if int(type["engines"]) == 4 else 1.0) * (1.0 if float(type["len"]) < 50.0 else 1.25)
		snd.max_distance = 8000.0
		snd.volume_db = 2.0
		snd.pitch_scale = randf_range(0.92, 1.06)
		snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		snd.attenuation_filter_cutoff_hz = 2500.0
		snd.attenuation_filter_db = -18.0
		node.add_child(snd)
		snd.play(randf() * 2.5)
	_planes.append({"node": node, "s": T_FROM, "speed": randf_range(68.0, 78.0), "phase": randf() * 10.0,
		"strobes": info["strobes"], "beacons": info["beacons"]})


## Einfaches Verkehrsflugzeug aus Grundkörpern: Rumpf, gepfeilte Flügel, Leitwerk,
## Triebwerke, ausgefahrenes Fahrwerk, Lichter. Lokal: Nase nach -Z, oben +Y.
func _build(type: Dictionary, tail: Color) -> Dictionary:
	var root := Node3D.new()
	var L: float = type["len"]
	var span: float = type["span"]
	var r := L * 0.05                       # Rumpfradius
	var white := Util.mat(Color(0.93, 0.94, 0.95), 0.35)
	var grey := Util.mat(Color(0.72, 0.74, 0.77), 0.45)
	var dark := Util.mat(Color(0.12, 0.12, 0.13), 0.6)
	var tail_mat := Util.mat(tail, 0.4)
	# Rumpf mit Nase und Heckkonus
	var body := _mesh(root, _cyl(r, r, L * 0.72), white, Vector3(0, 0, 0.02 * L))
	body.rotation.x = PI * 0.5
	var nose := _mesh(root, _sphere(r), white, Vector3(0, -r * 0.05, -L * 0.34))
	nose.scale = Vector3(1.0, 0.95, 2.2)
	var cone := _mesh(root, _cyl(r * 0.25, r, L * 0.2), white, Vector3(0, r * 0.25, L * 0.48))
	cone.rotation.x = PI * 0.5
	_mesh(root, _box(Vector3(r * 1.6, r * 0.2, L * 0.03)), dark, Vector3(0, r * 0.45, -L * 0.37))   # Cockpitfenster
	# Flügel (gepfeilt, leicht V-Form)
	var chord := L * 0.16
	for sd: float in [-1.0, 1.0]:
		var w := _mesh(root, _box(Vector3(span * 0.5, r * 0.14, chord)), grey,
			Vector3(sd * span * 0.25, -r * 0.45, -L * 0.02 + span * 0.25 * 0.42))
		w.rotation = Vector3(0.0, -sd * deg_to_rad(25.0), sd * deg_to_rad(5.0))
		# Höhenleitwerk
		var hs := _mesh(root, _box(Vector3(span * 0.17, r * 0.1, chord * 0.45)), grey,
			Vector3(sd * span * 0.085, r * 0.35, L * 0.45))
		hs.rotation = Vector3(0.0, -sd * deg_to_rad(30.0), sd * deg_to_rad(6.0))
	# Seitenleitwerk in der Farbe der Airline
	var fin := _mesh(root, _box(Vector3(r * 0.16, L * 0.17, chord * 0.75)), tail_mat, Vector3(0, r + L * 0.07, L * 0.42))
	fin.rotation.x = deg_to_rad(35.0)
	# Triebwerke unter den Flügeln
	var n: int = type["engines"]
	var spots: Array = [0.33] if n == 2 else [0.27, 0.55]
	for sd: float in [-1.0, 1.0]:
		for f: float in spots:
			var x := sd * span * 0.5 * f
			var z := -L * 0.02 + absf(x) * 0.42 - chord * 0.55
			var eng := _mesh(root, _cyl(r * 0.42, r * 0.38, L * 0.11), grey, Vector3(x, -r * 0.95, z))
			eng.rotation.x = PI * 0.5
			_mesh(root, _cyl(r * 0.3, r * 0.3, 0.05), dark, Vector3(x, -r * 0.95, z - L * 0.056)).rotation.x = PI * 0.5
	# Fahrwerk ausgefahren
	for g: Vector3 in [Vector3(0, 0, -L * 0.3), Vector3(-r * 0.9, 0, L * 0.03), Vector3(r * 0.9, 0, L * 0.03)]:
		_mesh(root, _cyl(r * 0.06, r * 0.06, r * 0.9), grey, g + Vector3(0, -r * 1.35, 0))
		var wheel := _mesh(root, _cyl(r * 0.22, r * 0.22, r * 0.3), dark, g + Vector3(0, -r * 1.8, 0))
		wheel.rotation.z = PI * 0.5
	# Lichter: Landescheinwerfer, Positionslichter rot/grün, Blitzer, Drehlicht
	var lights := {"strobes": [], "beacons": []}
	_light(root, Vector3(0, -r * 0.8, -L * 0.15), Color(1.0, 0.98, 0.9), r * 0.18)
	_light(root, Vector3(-span * 0.12, -r * 0.5, -L * 0.04), Color(1.0, 0.98, 0.9), r * 0.15)
	_light(root, Vector3(span * 0.12, -r * 0.5, -L * 0.04), Color(1.0, 0.98, 0.9), r * 0.15)
	_light(root, Vector3(-span * 0.5, -r * 0.25, span * 0.21), Color(1.0, 0.1, 0.1), r * 0.1)
	_light(root, Vector3(span * 0.5, -r * 0.25, span * 0.21), Color(0.1, 1.0, 0.25), r * 0.1)
	for sd: float in [-1.0, 1.0]:
		lights["strobes"].append(_light(root, Vector3(sd * span * 0.5, -r * 0.2, span * 0.23), Color.WHITE, r * 0.16))
	lights["beacons"].append(_light(root, Vector3(0, r * 1.02, 0), Color(1.0, 0.15, 0.1), r * 0.12))
	lights["beacons"].append(_light(root, Vector3(0, -r * 1.02, L * 0.05), Color(1.0, 0.15, 0.1), r * 0.12))
	return {"node": root, "strobes": lights["strobes"], "beacons": lights["beacons"]}


func _mesh(parent: Node3D, m: Mesh, mat: Material, at: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = at
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _light(parent: Node3D, at: Vector3, c: Color, size: float) -> MeshInstance3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 4.0
	return _mesh(parent, _sphere(maxf(size, 0.25)), m, at)


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 16
	c.rings = 1
	return c


static func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 16
	s.rings = 8
	return s


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
