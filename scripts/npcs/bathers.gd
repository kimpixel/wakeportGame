class_name Bathers
extends Node3D
## Badegäste an heißen Tagen (Weather.heat): Leute auf Luftmatratzen und in Schwimmringen treiben im Badebereich
## (nördlich der gelben Bojenkette) und seeseitig hinter der Bahn – nie zwischen den Bahnen. Dazu die Liegewiese
## am Badestrand: Handtücher, Sonnenschirme, ein paar Sonnenbadende.
## Die Figuren werden nur einmal posiert (Person "float"/"ring"/"towel"), danach bewegt sich nur noch der Knoten;
## wie viele Figuren, begrenzt die Grafikstufe (quality). Erst bei Bedarf gebaut.
## Ein Matratzen-Schläfer treibt ab und zu bis an die T2-Bahn heran: wer ihn nass spritzt, bekommt den geheimen
## Erfolg "Badegast".

signal splashed                      # Spieler hat einen Badegast nass gespritzt

const FLOATERS := [2, 4, 8]          # Badegäste im Wasser je Grafikstufe (bei voller Hitze)
const SUNBATHERS := [0, 2, 4]        # Sonnenbadende auf der Wiese je Grafikstufe
const TOWELS := 14
const UMBRELLAS := 6
const DRIFT_SPEED := 0.12            # m/s
const DOZER_X := -13.5               # so nah treibt der Schläfer an die T2-Bahn
const SPRAY_SPEED := 6.0
const SPRAY_DIST := 3.0

var water: Water
var features: FeatureSet
var player: Rider
var quality := 2

var _floaters: Array[Dictionary] = []   # {node, at: Vector2, goal: Vector2, area: Rect2, wet, cool, dozer}
var _lawn: Node3D
var _sunbathers: Array[Node3D] = []
var _built := false
var _active := 0
var _t := 0.0

const COLORS := [Color(0.95, 0.35, 0.55), Color(0.98, 0.82, 0.15), Color(0.2, 0.6, 0.95), Color(0.3, 0.85, 0.5),
	Color(0.98, 0.5, 0.15), Color(0.95, 0.95, 0.95)]


## Weather.changed: Anzahl nach Hitze, Tageslicht und Regen.
func apply_season(w: Weather) -> void:
	var on := w.heat > 0.05 and w.rain_now < 0.2 and w.daylight > 0.5
	if on and not _built:
		_build()
	var n := int(round(FLOATERS[clampi(quality, 0, 2)] * w.heat)) if on else 0
	_active = n
	for i in _floaters.size():
		var f: Dictionary = _floaters[i]
		var vis := i < n
		(f["node"] as Node3D).visible = vis
	if _lawn:
		_lawn.visible = on
		var towels := int(round(TOWELS * w.heat)) if on else 0
		var umbrellas := int(round(UMBRELLAS * w.heat)) if on else 0
		for c in _lawn.get_children():
			var k: int = c.get_meta("k")
			c.visible = k < towels if c.get_meta("towel") else k < umbrellas
		var sb := int(round(SUNBATHERS[clampi(quality, 0, 2)] * w.heat)) if on else 0
		for i in _sunbathers.size():
			_sunbathers[i].visible = i < sb and int(_sunbathers[i].get_meta("towel")) < towels


func _build() -> void:
	_built = true
	var models := ["res://assets/characters/guest_f.glb", "res://assets/characters/guest_m.glb"]
	# Bereiche (Spielkoordinaten x, z): Badebereich nördlich der Bojenkette und seeseitig hinter der T2-Bahn
	var areas := [_rel_rect(Vector2(18.0, 48.0), Vector2(60.0, 75.0)), Rect2(-70.0, -200.0, 45.0, 120.0)]
	for i in FLOATERS[2]:
		var area: Rect2 = areas[i % 2]
		var at := _free_spot(area)
		if at == Vector2.INF:
			continue
		var node := Node3D.new()
		add_child(node)
		var ring := i % 3 == 2
		_build_float(node, ring, COLORS[i % COLORS.size()])
		var p := Person.new()
		p.kind = "ring" if ring else "float"
		node.add_child(p)
		if not p.setup(models[i % 2]):
			p.queue_free()
		node.visible = false
		node.rotation.y = randf() * TAU
		var dozer := i == 1                  # liegt seeseitig und treibt ab und zu bis an die Bahn
		_floaters.append({"node": node, "at": at, "goal": at, "area": area, "wet": 0.0, "cool": 0.0, "dozer": dozer,
			"timer": randf_range(30.0, 90.0)})
	_build_lawn(models)


## Rechteck im Spiel aus zwei Ecken in (dE, dN) relativ zum T2-Startmast.
func _rel_rect(a: Vector2, b: Vector2) -> Rect2:
	var ga := Geo.rel_to_game(a.x, a.y)
	var gb := Geo.rel_to_game(b.x, b.y)
	return Rect2(Vector2(minf(ga.x, gb.x), minf(ga.y, gb.y)), (ga - gb).abs())


## Freier Wasserplatz im Bereich: tief genug, kein Feature, nicht zwischen den Bahnen.
func _free_spot(area: Rect2) -> Vector2:
	for _k in 30:
		var p := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		if _water_ok(p):
			return p
	return Vector2.INF


func _water_ok(p: Vector2) -> bool:
	if Geo.height(p.x, p.y) > -0.8 or not Lake.in_lake(p.x, p.y, 3.0):
		return false
	if p.x > -18.0 and p.x < 52.0 and p.y < 0.0:
		return false                       # Bahnen und alles dazwischen
	return features == null or features.height_at(p.x, p.y) <= FeaturePart.NONE + 0.5


## Luftmatratze (gestreift, mit Kopfkissen-Wulst) bzw. Schwimmring.
func _build_float(node: Node3D, ring: bool, col: Color) -> void:
	var mat := Util.mat(col, 0.35)
	if ring:
		var tm := TorusMesh.new()
		tm.inner_radius = 0.38
		tm.outer_radius = 0.62
		var mi := MeshInstance3D.new()
		mi.mesh = tm
		mi.material_override = mat
		mi.position.y = 0.02
		node.add_child(mi)
		return
	var stripe := Util.mat(col.lerp(Color.WHITE, 0.6), 0.35)
	for k in 5:
		var b := Util.box(node, Vector3(0.75, 0.14, 0.38), Vector3(0.0, 0.03, -0.9 + k * 0.4), mat if k % 2 == 0 else stripe)
		b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var pillow := Util.box(node, Vector3(0.75, 0.2, 0.3), Vector3(0.0, 0.06, -1.15), mat)
	pillow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Liegewiese am Badestrand (Nordufer): Land nahe am Wasser, ohne Bäume, flach.
func _build_lawn(models: Array) -> void:
	_lawn = Node3D.new()
	add_child(_lawn)
	var spots: Array[Vector3] = []
	var area := Rect2(-210.0, -35.0, 95.0, 100.0)        # Sandstrand am Nordufer (Badestrand)
	for _k in 600:
		if spots.size() >= TOWELS + UMBRELLAS + 4:
			break
		var p := area.position + Vector2(randf() * area.size.x, randf() * area.size.y)
		var h := Geo.height(p.x, p.y)
		if h < 0.25 or h > 2.5 or Geo.canopy(p.x, p.y) > 1.0 or not Lake.in_lake(p.x + 6.0, p.y, 0.0) and \
				not Lake.in_lake(p.x - 6.0, p.y, 0.0) and not Lake.in_lake(p.x, p.y + 6.0, 0.0) and not Lake.in_lake(p.x, p.y - 6.0, 0.0):
			continue
		if Geo.height(p.x + 0.8, p.y) - Geo.height(p.x - 0.8, p.y) > 0.3:
			continue                       # zu steil
		var v := Vector3(p.x, h, p.y)
		var close := false
		for s in spots:
			if s.distance_to(v) < 2.5:
				close = true
		if not close:
			spots.append(v)
	var i := 0
	for s in spots:
		var yaw := randf() * TAU
		if i < TOWELS:
			var t := Util.box(_lawn, Vector3(0.9, 0.02, 1.8), s + Vector3(0, 0.02, 0), Util.mat(COLORS[i % COLORS.size()], 0.9))
			t.rotation.y = yaw
			t.set_meta("towel", true)
			t.set_meta("k", i)
			if _sunbathers.size() < SUNBATHERS[2] and i % 3 == 0:
				var p := Person.new()
				p.kind = "towel"
				add_child(p)
				p.global_position = s + Vector3(0, 0.03, 0)
				p.rotation.y = yaw
				p.set_meta("towel", i)
				if p.setup(models[i % 2]):
					_sunbathers.append(p)
				else:
					p.queue_free()
		elif i < TOWELS + UMBRELLAS:
			var u := Node3D.new()
			_lawn.add_child(u)
			u.position = s
			u.set_meta("towel", false)
			u.set_meta("k", i - TOWELS)
			Util.beam(u, Vector3.ZERO, Vector3(0, 2.1, 0), 0.025, Util.mat(Color(0.9, 0.9, 0.9), 0.5))
			var cm := CylinderMesh.new()
			cm.top_radius = 0.02
			cm.bottom_radius = 1.1
			cm.height = 0.45
			cm.radial_segments = 8
			var mi := MeshInstance3D.new()
			mi.mesh = cm
			mi.material_override = Util.mat(COLORS[(i + 2) % COLORS.size()], 0.8)
			mi.position.y = 2.0
			u.add_child(mi)
		i += 1


func _process(delta: float) -> void:
	if water == null or _active == 0:
		return
	_t += delta
	for i in _active:
		var f: Dictionary = _floaters[i]
		var at: Vector2 = f["at"]
		var goal: Vector2 = f["goal"]
		f["timer"] = float(f["timer"]) - delta
		if at.distance_to(goal) < 0.5 or float(f["timer"]) <= 0.0:
			f["timer"] = randf_range(40.0, 120.0)
			if f["dozer"] and goal.x > DOZER_X - 1.0:
				goal = _free_spot(f["area"])                  # vom Bahnrand wieder weg
			elif f["dozer"] and randf() < 0.5:
				goal = Vector2(DOZER_X, randf_range(-90.0, -180.0))   # döst bis an die Bahn heran
			else:
				goal = _free_spot(f["area"])
			if goal == Vector2.INF:
				goal = at
			f["goal"] = goal
		var step := (goal - at).limit_length(DRIFT_SPEED * delta)
		at += step
		f["at"] = at
		var node: Node3D = f["node"]
		var y := water.height_at(at.x, at.y)
		node.global_position = Vector3(at.x, y, at.y)
		node.rotation.y += delta * 0.03 * sin(_t * 0.1 + i)
		# nass gespritzt: Matratze schaukelt
		f["wet"] = maxf(float(f["wet"]) - delta / 1.6, 0.0)
		f["cool"] = maxf(float(f["cool"]) - delta, 0.0)
		node.rotation.z = 0.05 * sin(_t * 1.3 + i) + 0.2 * float(f["wet"]) * sin(float(f["wet"]) * 25.0)
		_check_spray(f, node.global_position)


func _check_spray(f: Dictionary, pos: Vector3) -> void:
	if player == null or player.mode != Rider.Mode.WATER or float(f["cool"]) > 0.0:
		return
	if player.horizontal_speed() < SPRAY_SPEED or player.pos.y > 0.3:
		return
	if Vector2(player.pos.x - pos.x, player.pos.z - pos.z).length() > SPRAY_DIST:
		return
	f["wet"] = 1.0
	f["cool"] = 6.0
	splashed.emit()
