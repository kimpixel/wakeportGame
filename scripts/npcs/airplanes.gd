class_name Airplanes
extends Node3D
## Flugzeuge über dem See: Der Wakeport liegt in der Einflugschneise von Frankfurt. Meist landen sie
## (Betriebsrichtung 07, Jet aus Westsüdwest, Fahrwerk draußen, sinkt bis zum Flughafen), ein Teil
## startet in Gegenrichtung und steigt (`DEPART_SHARE`). Jeder Jet hat eigene Linie: Kurs, Seitenversatz
## und Höhe streuen. Ein Teil kommt tief fast direkt über den See (`NEAR_SHARE`) – dann wirkt er riesig.
## Die Höhe ist an den Flughafen gebunden (`AIRPORT_H` bei `AIRPORT_S`), so taucht kein Jet in den Wald.

const HEADING := 69.0             # Kurs Richtung Flughafen (Grad, rechtweisend)
const HEADING_SPREAD := 6.0       # Kurs je Jet ± so viel Grad (Linie dreht um den Punkt über dem See)
const GLIDE := 3.0                # Steigwinkel vom See weg vom Flughafen (Grad): Landung
const CLIMB := 6.0                # dasselbe beim Start
const AIRPORT_S := 4300.0         # Flughafen so weit vom See entlang der Linie (m)
const AIRPORT_H := 40.0           # Höhe dort (über dem See, über den Bäumen)
const FAR_S := 5500.0             # Strecke auf der anderen Seite des Sees (m)
const ALT_OVER_LAKE := Vector2(200.0, 300.0)   # normale Jets: Höhe über dem See (von, bis)
const SIDE_LANES := [-260.0, 120.0, 650.0]     # normale Jets: Linien seitlich der Seemitte (m, + Norden)
const SIDE_SPREAD := 90.0                      # ± um die Linie
const NEAR_SHARE := 0.35          # Anteil der Jets, die tief und nah über den See kommen
const NEAR_ALT := Vector2(65.0, 100.0)      # Höhe über dem See (von, bis)
const NEAR_SIDE := Vector2(-40.0, 40.0)     # seitlich der Seemitte (von, bis)
const DEPART_SHARE := 0.3         # Anteil Starts (fliegen vom Flughafen weg, also entgegen)
const RUSH_GAP := Vector2(7.0, 13.0)       # Rush Hour: Sekunden bis zum nächsten Jet (von, bis)
const NORMAL_GAP := Vector2(65.0, 140.0)

const TYPES := [
	# Länge, Spannweite, Triebwerke, Häufigkeit
	{"len": 37.6, "span": 34.0, "engines": 2, "w": 0.6},     # Mittelstrecke
	{"len": 66.8, "span": 64.8, "engines": 2, "w": 0.3},     # Langstrecke, zweistrahlig
	{"len": 70.7, "span": 64.4, "engines": 4, "w": 0.1},     # Jumbo
]
const TAIL_COLORS := [Color(0.05, 0.14, 0.38), Color(0.78, 0.1, 0.1), Color(0.95, 0.72, 0.1),
	Color(0.1, 0.42, 0.3), Color(0.18, 0.18, 0.2), Color(0.35, 0.55, 0.85)]

var jet_sound: AudioStream
var _heading := 0.0               # Kurs zum Flughafen im Spiel (rad um +Y, 0 = -Z)
var _north := Vector3.RIGHT       # waagerecht Richtung Norden
var _lake := Vector3.ZERO         # Mitte der T2-Bahn
var _planes: Array[Dictionary] = []
var _next := 25.0
var rate := 1:                    # Einstellungen: 0 aus, 1 normal, 2 Rush Hour
	set(v):
		var was := rate
		rate = v
		if v == 2 and was != 2 and is_inside_tree():
			_fill_rush()
var _t := 0.0


func _ready() -> void:
	var a := deg_to_rad(HEADING)
	var d := Geo.rel_to_game(sin(a), cos(a))
	_heading = atan2(-d.x, -d.y)
	var n := Geo.rel_to_game(0.0, 1.0)
	_north = Vector3(n.x, 0.0, n.y).normalized()
	_lake = Vector3(0.0, 0.0, Lake.MAST_B_Z * 0.5)
	if rate == 2:
		_fill_rush()


func _process(delta: float) -> void:
	_t += delta
	_next -= delta
	if _next <= 0.0:
		var gap := RUSH_GAP if rate == 2 else NORMAL_GAP
		_next = randf_range(gap.x, gap.y)
		if rate > 0:
			_spawn()
	for i in range(_planes.size() - 1, -1, -1):
		var p: Dictionary = _planes[i]
		p["s"] = float(p["s"]) + float(p["speed"]) * delta
		var node: Node3D = p["node"]
		if float(p["s"]) > float(p["s_end"]):
			node.queue_free()
			_planes.remove_at(i)
			continue
		node.global_transform = Transform3D(_attitude(p), _pos(p))
		# Lichter: Blitzer und rotes Drehlicht blinken
		var strobe := fmod(_t + float(p["phase"]), 1.2) < 0.06
		for l: Node3D in p["strobes"]:
			l.visible = strobe
		var beacon := fmod(_t * 1.1 + float(p["phase"]), 1.0) < 0.12
		for l: Node3D in p["beacons"]:
			l.visible = beacon


## Abstand zum Flughafen-Ende der Linie: s läuft in Flugrichtung, 0 = über dem See.
func _to_airport(p: Dictionary) -> float:
	return float(p["s"]) if p["land"] else -float(p["s"])


## Höhe über dem See: zum Flughafen hin linear auf AIRPORT_H, auf der anderen Seite steigend.
func _height(p: Dictionary) -> float:
	var a := _to_airport(p)
	var alt: float = p["alt"]
	if a >= 0.0:
		return lerpf(alt, AIRPORT_H, a / AIRPORT_S)
	return alt - a * tan(deg_to_rad(float(p["slope"])))


func _pos(p: Dictionary) -> Vector3:
	var dir: Vector3 = p["dir"]
	var side := Vector3(-dir.z, 0.0, dir.x)
	if side.dot(_north) < 0.0:
		side = -side
	return _lake + side * float(p["side"]) + dir * float(p["s"]) + Vector3.UP * _height(p)


## Lage: Nase im Flugweg (sinkt bzw. steigt), leicht hoch, sanftes Schaukeln.
func _attitude(p: Dictionary) -> Basis:
	var dir: Vector3 = p["dir"]
	var a := _to_airport(p)
	var alt: float = p["alt"]
	var climb := (alt - AIRPORT_H) / AIRPORT_S if a >= 0.0 else tan(deg_to_rad(float(p["slope"])))
	var path := atan(climb) * (-1.0 if p["land"] else 1.0)
	var b := Basis.looking_at(dir, Vector3.UP)
	return b * Basis(Vector3.RIGHT, path + deg_to_rad(2.5 if p["land"] else 6.0)) \
		* Basis(Vector3.FORWARD, 0.03 * sin(_t * 0.5 + float(p["phase"])))


## Rush Hour sofort voll: Jets schon auf ihren Linien verteilt (sonst erst nach Minuten).
func _fill_rush() -> void:
	var k := randf_range(0.0, 1.0)
	var n := int((AIRPORT_S + FAR_S) / (73.0 * (RUSH_GAP.x + RUSH_GAP.y) * 0.5))
	for i in n:
		_spawn()
		var p: Dictionary = _planes[-1]
		p["s"] = lerpf(float(p["s"]), float(p["s_end"]), fmod(k + float(i) / float(n), 1.0))
	_next = randf_range(RUSH_GAP.x, RUSH_GAP.y)


## Test: sofort ein Jet an Stelle s seiner Linie (0 = über dem See, negativ = davor);
## near: 1 nah, 0 normal, -1 Zufall; land: 1 Landung, 0 Start, -1 Zufall.
func spawn_at(s: float, near := -1, land := -1) -> void:
	_spawn(near, land)
	var p: Dictionary = _planes[-1]
	p["s"] = s
	print("Jet bei ", _pos(p), " Richtung ", p["dir"], " Höhe über See ", p["alt"], " seitlich ", p["side"],
		" ", "Landung" if p["land"] else "Start")


func _spawn(near := -1, land := -1) -> void:
	var r := randf()
	var type: Dictionary = TYPES[0]
	var acc := 0.0
	for t: Dictionary in TYPES:
		acc += float(t["w"])
		if r <= acc:
			type = t
			break
	var landing := randf() >= DEPART_SHARE if land < 0 else land == 1
	var info := _build(type, TAIL_COLORS.pick_random(), landing)
	var node: Node3D = info["node"]
	add_child(node)
	if jet_sound:
		var snd := AudioStreamPlayer3D.new()
		snd.bus = Sfx.BUS_PLANES
		snd.stream = jet_sound
		snd.unit_size = 90.0 * (1.3 if int(type["engines"]) == 4 else 1.0) * (1.0 if float(type["len"]) < 50.0 else 1.25) \
			* (1.0 if landing else 1.4)
		snd.max_distance = 8000.0
		snd.volume_db = 2.0
		snd.pitch_scale = randf_range(0.92, 1.06)
		snd.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
		snd.attenuation_filter_cutoff_hz = 2500.0
		snd.attenuation_filter_db = -18.0
		node.add_child(snd)
		snd.play(Sfx.loop_start(2.5))
	var close := randf() < NEAR_SHARE if near < 0 else near == 1
	var alt := randf_range(NEAR_ALT.x, NEAR_ALT.y) if close else randf_range(ALT_OVER_LAKE.x, ALT_OVER_LAKE.y)
	var side := randf_range(NEAR_SIDE.x, NEAR_SIDE.y) if close \
		else float(SIDE_LANES.pick_random()) + randf_range(-SIDE_SPREAD, SIDE_SPREAD)
	var h := _heading + deg_to_rad(randf_range(-HEADING_SPREAD, HEADING_SPREAD))
	var dir := Vector3(-sin(h), 0.0, -cos(h))
	if not landing:
		dir = -dir
	_planes.append({"node": node, "s": -FAR_S if landing else -AIRPORT_S, "s_end": AIRPORT_S if landing else FAR_S,
		"land": landing, "dir": dir, "slope": GLIDE if landing else CLIMB,
		"speed": randf_range(68.0, 78.0) if landing else randf_range(80.0, 95.0), "phase": randf() * 10.0,
		"alt": alt, "side": side, "strobes": info["strobes"], "beacons": info["beacons"]})


## Einfaches Verkehrsflugzeug aus Grundkörpern: Rumpf, gepfeilte Flügel, Leitwerk,
## Triebwerke, Fahrwerk (nur beim Landen draußen), Lichter. Lokal: Nase nach -Z, oben +Y.
func _build(type: Dictionary, tail: Color, gear := true) -> Dictionary:
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
	# Fahrwerk ausgefahren (Landung)
	var wheels: Array[Vector3] = [Vector3(0, 0, -L * 0.3), Vector3(-r * 0.9, 0, L * 0.03), Vector3(r * 0.9, 0, L * 0.03)]
	for g: Vector3 in (wheels if gear else [] as Array[Vector3]):
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
