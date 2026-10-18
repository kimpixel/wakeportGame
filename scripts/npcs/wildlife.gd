class_name Wildlife
extends Node3D
## Tiere am See je nach Jahreszeit (apply_season, aus Weather). Alle aus einfachen Formen, kaum Rechenlast:
##  * Haubentaucher (März–November): treiben herum, tauchen vor dem Fahrer ab und tauchen woanders wieder auf.
##    Taucht einer knapp vor einem ab und auf der anderen Seite hinter einem wieder auf: geheimer Erfolg
##    "Was ein Frechdachs" (grebe_sneaked)
##  * Schwanenpaar, von Mai bis September mit Küken; schwimmt seeseitig neben der T2-Bahn, weicht dem Fahrer aus.
##    Ab und zu formen die beiden mit den Hälsen ein Herz – wer das aus der Nähe sieht: Erfolg "Schwanenliebe"
##  * Graureiher am Ufer, fliegt auf, wenn man ihm zu nahe kommt, und landet ein Stück weiter
##  * Kranichzug (Februar/März nach Nordosten, Oktober/November nach Südwesten): Keilformation hoch am Himmel.
##    Ein Invert, während die Kraniche über einem ziehen: Erfolg "Zugvogel" (cranes_overhead)
##  * Libellen (Juni–August, tags) an den Stegen; Fledermäuse (Mai–September, nachts) über dem Wasser;
##    Glühwürmchen (Juni/Juli, nachts) am Waldrand; Eisschollen am Ufer (Dezember–Februar)

signal grebe_sneaked                # Haubentaucher ist unter einem durchgetaucht
signal swans_love                   # Schwanen-Herz aus der Nähe gesehen

const GREBE_SPEED := 0.35           # m/s an der Oberfläche
const GREBE_DIVE_SPEED := 2.4       # m/s unter Wasser
const GREBE_ALERT := 9.0            # m: so nah lässt er einen kommen, dann taucht er
const SWAN_HOME := Rect2(-34.0, -150.0, 12.0, 80.0)   # seeseitig neben T2 (x -34..-22)
const SWAN_FLEE := 14.0
const HEART_EVERY := Vector2(45.0, 90.0)
const HEART_TIME := 11.0
const HEART_SEE := 20.0             # m: aus der Nähe gesehen
const CRANES := 14
const CRANE_ALT := 95.0
const CRANE_SCALE := 2.2            # größer als echt, sonst nur Punkte am Himmel

var water: Water
var features: FeatureSet
var player: Rider

var _t := 0.0
var _grebes: Array[Dictionary] = []
var _swans: Node3D
var _swan_parts: Array[Dictionary] = []   # {node, neck: Array[Node3D], offset: Vector2, cygnet}
var _swan_at := Vector2(-28.0, -110.0)
var _swan_goal := Vector2(-28.0, -110.0)
var _swan_dir := Vector2(0, -1)
var _heart_t := -1.0
var _heart_next := 60.0
var _heart_seen := false
var _cygnets_on := false
var _heron: Node3D
var _heron_spots: Array[Vector3] = []
var _heron_at := 0
var _heron_fly := -1.0
var _heron_from := Vector3.ZERO
var _heron_to := Vector3.ZERO
var _heron_wings: Array[Node3D] = []
var _cranes: Node3D
var _crane_birds: Array[Node3D] = []
var _crane_season := 0              # 0 keine, 1 Frühjahr (nach NO), -1 Herbst (nach SW)
var _crane_t := -1.0                # < 0: gerade keine am Himmel
var _crane_next := 20.0
var _crane_from := Vector3.ZERO
var _crane_dir := Vector3.ZERO
var _flies: Array[Dictionary] = []  # Libellen {node, home, phase, goal}
var _bats: Array[Dictionary] = []
var _fireflies: Array[CPUParticles3D] = []
var _ice: MultiMeshInstance3D
var _grebes_on := true
var _flies_on := false
var _bats_on := false


func build() -> void:
	_build_grebes()
	_build_swans()
	_build_heron()
	_build_cranes()
	_build_flies()
	_build_bats()
	_build_fireflies()
	_build_ice()


## Weather.changed: wer ist gerade da?
func apply_season(w: Weather) -> void:
	var m := w.month()
	var night := w.daylight < 0.3
	_grebes_on = m >= 3 and m <= 11
	for g in _grebes:
		(g["node"] as Node3D).visible = _grebes_on and g["state"] != "dive"
	_cygnets_on = m >= 5 and m <= 9
	for s in _swan_parts:
		if s["cygnet"]:
			(s["node"] as Node3D).visible = _cygnets_on
	_crane_season = 1 if m in [2, 3] else (-1 if m in [10, 11] else 0)
	if _crane_season == 0 or night:
		_crane_t = -1.0
		_cranes.visible = false
	_flies_on = m >= 6 and m <= 8 and not night and w.rain_now < 0.2
	for f in _flies:
		(f["node"] as Node3D).visible = _flies_on
	_bats_on = m >= 5 and m <= 9 and night
	for b in _bats:
		(b["node"] as Node3D).visible = _bats_on
	var glow := m in [6, 7] and w.daylight < 0.25 and w.rain_now < 0.2
	for ff in _fireflies:
		ff.emitting = glow
		ff.visible = glow
	_ice.visible = w.day >= 335 or w.day <= 59


## Kraniche gerade über dem See (für den Erfolg "Zugvogel").
func cranes_overhead() -> bool:
	if _crane_t < 0.0 or player == null:
		return false
	var c := _cranes.global_position
	return Vector2(c.x - player.pos.x, c.z - player.pos.z).length() < 260.0


# ---------------------------------------------------------------- Haubentaucher

func _build_grebes() -> void:
	var dark := Util.mat(Color(0.28, 0.24, 0.2), 0.6)
	var white := Util.mat(Color(0.92, 0.9, 0.86), 0.6)
	var rufous := Util.mat(Color(0.55, 0.25, 0.1), 0.6)
	var black := Util.mat(Color(0.05, 0.05, 0.05), 0.6)
	var beak := Util.mat(Color(0.75, 0.45, 0.4), 0.5)
	# einer nahe an der T2-Spur (für den Erfolg), zwei seeseitig
	var homes := [Rect2(-7.0, -190.0, 14.0, 120.0), Rect2(-60.0, -200.0, 30.0, 100.0), Rect2(-55.0, -110.0, 25.0, 60.0)]
	for h: Rect2 in homes:
		var n := Node3D.new()
		n.top_level = true
		add_child(n)
		var body := _ellipsoid(n, Vector3(0.17, 0.11, 0.42), Vector3(0, 0.03, 0), dark)
		_ellipsoid(n, Vector3(0.13, 0.08, 0.3), Vector3(0, 0.05, 0.08), white)          # helle Brust/Flanken vorne
		_ellipsoid(n, Vector3(0.05, 0.2, 0.05), Vector3(0, 0.16, 0.16), white)          # schlanker weißer Hals
		_ellipsoid(n, Vector3(0.07, 0.07, 0.09), Vector3(0, 0.27, 0.19), white)         # Kopf
		_ellipsoid(n, Vector3(0.08, 0.06, 0.06), Vector3(0, 0.25, 0.17), rufous)        # rotbraune Halskrause
		_ellipsoid(n, Vector3(0.06, 0.07, 0.05), Vector3(0, 0.31, 0.16), black)         # schwarze Haube
		var bk := _ellipsoid(n, Vector3(0.015, 0.015, 0.07), Vector3(0, 0.27, 0.26), beak)
		bk.rotation.x = 0.1
		body.name = "body"
		var at := h.get_center()
		_grebes.append({"node": n, "home": h, "at": at, "goal": at, "state": "swim", "dive_t": 0.0,
			"dive_to": at, "side": 0.0, "cool": 0.0, "sneak": false})


func _move_grebes(delta: float) -> void:
	if not _grebes_on:
		return
	for g in _grebes:
		var at: Vector2 = g["at"]
		g["cool"] = maxf(float(g["cool"]) - delta, 0.0)
		match g["state"]:
			"swim":
				if at.distance_to(g["goal"]) < 0.5:
					g["goal"] = _grebe_spot(g["home"])
				var step := (Vector2(g["goal"]) - at).limit_length(GREBE_SPEED * delta)
				at += step
				if step.length() > 0.0001:
					(g["node"] as Node3D).rotation.y = lerp_angle((g["node"] as Node3D).rotation.y, atan2(step.x, step.y), delta * 2.0)
				if float(g["cool"]) <= 0.0:
					_grebe_check_dive(g, at)
			"dive":
				var to: Vector2 = g["dive_to"]
				at += (to - at).limit_length(GREBE_DIVE_SPEED * delta)
				g["dive_t"] = float(g["dive_t"]) - delta
				if g["dive_t"] <= 0.0 and at.distance_to(to) < 0.3:
					_grebe_surface(g, at)
		g["at"] = at
		var n: Node3D = g["node"]
		var y := water.height_at(at.x, at.y) if water else 0.0
		n.global_position = Vector3(at.x, y - 0.04, at.y)


## Fahrer kommt auf ihn zu: abtauchen. Liegt er genau in der Fahrspur, schwimmt er unter dem Fahrer durch
## auf die andere Seite (frech!), sonst einfach weg.
func _grebe_check_dive(g: Dictionary, at: Vector2) -> void:
	if player == null or player.mode == Rider.Mode.CRASHED:
		return
	var pp := Vector2(player.pos.x, player.pos.z)
	var v := Vector2(player.vel.x, player.vel.z)
	var d := at - pp
	if d.length() > GREBE_ALERT or v.length() < 2.0 or d.dot(v) <= 0.0:
		return
	var fwd := v.normalized()
	var side := fwd.x * d.y - fwd.y * d.x                    # seitlicher Abstand zur Fahrspur (mit Vorzeichen)
	var to: Vector2
	var sneak := absf(side) < 2.5
	if sneak:
		# unter dem Fahrer durch: auf der anderen Seite, ein Stück hinter der Stelle, an der er vorbeikommt
		var cross := Vector2(-fwd.y, fwd.x) * (-signf(side) if side != 0.0 else 1.0)
		to = at + cross * randf_range(3.0, 4.5) - fwd * randf_range(1.0, 3.0)
	else:
		to = at + (d.normalized() if d.length() > 0.1 else fwd) * randf_range(6.0, 10.0)
	if not _grebe_water(to):
		to = at - fwd * 5.0
	g["state"] = "dive"
	g["dive_to"] = to
	g["dive_t"] = maxf(at.distance_to(to) / GREBE_DIVE_SPEED, 1.6)
	g["side"] = side
	g["sneak"] = sneak
	(g["node"] as Node3D).visible = false
	_ring(at)


func _grebe_surface(g: Dictionary, at: Vector2) -> void:
	g["state"] = "swim"
	g["cool"] = 4.0
	g["goal"] = _grebe_spot(g["home"])
	var n: Node3D = g["node"]
	n.visible = _grebes_on
	_ring(at)
	# Frechdachs: auf der anderen Seite der Fahrspur wieder aufgetaucht, der Fahrer ist schon vorbei
	if g["sneak"] and player and player.mode != Rider.Mode.CRASHED:
		var pp := Vector2(player.pos.x, player.pos.z)
		var v := Vector2(player.vel.x, player.vel.z)
		if v.length() > 1.0 and pp.distance_to(at) < 18.0 and (at - pp).dot(v) < 0.0:
			grebe_sneaked.emit()


func _grebe_spot(h: Rect2) -> Vector2:
	for _k in 12:
		var p := h.position + Vector2(randf() * h.size.x, randf() * h.size.y)
		if _grebe_water(p):
			return p
	return h.get_center()


func _grebe_water(p: Vector2) -> bool:
	if not Lake.in_lake(p.x, p.y, 2.0):
		return false
	return features == null or features.height_at(p.x, p.y) <= FeaturePart.NONE + 0.5


## Kleiner Wasserring beim Ab- und Auftauchen.
func _ring(at: Vector2) -> void:
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.2
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	var mat := Util.mat(Color(0.85, 0.9, 0.95, 0.6), 0.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	mi.top_level = true
	add_child(mi)
	var y := water.height_at(at.x, at.y) if water else 0.0
	mi.global_position = Vector3(at.x, y + 0.01, at.y)
	mi.scale = Vector3(1, 0.15, 1)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(5, 0.15, 5), 1.4)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.4)
	tw.tween_callback(mi.queue_free)


# ---------------------------------------------------------------- Schwäne

func _build_swans() -> void:
	_swans = Node3D.new()
	_swans.top_level = true
	add_child(_swans)
	var white := Util.mat(Color(0.96, 0.96, 0.94), 0.55)
	var grey := Util.mat(Color(0.55, 0.5, 0.45), 0.7)
	var orange := Util.mat(Color(0.95, 0.45, 0.1), 0.4)
	var black := Util.mat(Color(0.05, 0.05, 0.05), 0.5)
	# zwei Altvögel nebeneinander, vier Küken in einer Reihe dahinter
	for k in 2:
		var n := Node3D.new()
		_swans.add_child(n)
		_ellipsoid(n, Vector3(0.36, 0.28, 0.75), Vector3(0, 0.12, 0), white)
		_ellipsoid(n, Vector3(0.3, 0.22, 0.32), Vector3(0, 0.26, -0.22), white)      # hochgestellte Flügel hinten
		var neck: Array[Node3D] = []
		var prev: Node3D = n
		var pos := Vector3(0, 0.2, 0.28)
		for j in 3:
			var seg := Node3D.new()
			seg.position = pos
			prev.add_child(seg)
			_ellipsoid(seg, Vector3(0.09, 0.09, 0.26), Vector3(0, 0, 0.11), white)
			neck.append(seg)
			prev = seg
			pos = Vector3(0, 0, 0.22)
		var head := Node3D.new()
		head.position = Vector3(0, 0, 0.24)
		prev.add_child(head)
		_ellipsoid(head, Vector3(0.1, 0.09, 0.15), Vector3(0, 0, 0.02), white)
		_ellipsoid(head, Vector3(0.05, 0.035, 0.12), Vector3(0, -0.01, 0.12), orange)
		_ellipsoid(head, Vector3(0.04, 0.04, 0.04), Vector3(0, 0.02, 0.07), black)    # Höcker
		neck.append(head)
		_swan_parts.append({"node": n, "neck": neck, "offset": Vector2(0.6 if k == 0 else -0.6, 0.0), "cygnet": false})
	for k in 4:
		var c := Node3D.new()
		_swans.add_child(c)
		_ellipsoid(c, Vector3(0.16, 0.12, 0.3), Vector3(0, 0.05, 0), grey)
		_ellipsoid(c, Vector3(0.08, 0.08, 0.09), Vector3(0, 0.15, 0.13), grey)
		_ellipsoid(c, Vector3(0.025, 0.02, 0.05), Vector3(0, 0.15, 0.2), black)
		_swan_parts.append({"node": c, "neck": [], "offset": Vector2(0.0, -1.2 - 0.55 * k), "cygnet": true})


func _move_swans(delta: float) -> void:
	# langsam umherziehen, vor dem Fahrer ausweichen, ab und zu Herz
	if player and player.mode != Rider.Mode.CRASHED:
		var pp := Vector2(player.pos.x, player.pos.z)
		if pp.distance_to(_swan_at) < SWAN_FLEE:
			var away := (_swan_at - pp).normalized()
			_swan_goal = _clamp_home(_swan_at + away * 10.0)
			_heart_t = -1.0
	if _heart_t < 0.0:
		_heart_next -= delta
		if _heart_next <= 0.0:
			_heart_t = 0.0
			_heart_seen = false
		if _swan_at.distance_to(_swan_goal) < 0.5:
			_swan_goal = _clamp_home(_swan_at + Vector2(randf_range(-8.0, 8.0), randf_range(-14.0, 14.0)))
		var step := (_swan_goal - _swan_at).limit_length(0.3 * delta)
		_swan_at += step
		if step.length() > 0.0001:
			_swan_dir = _swan_dir.lerp(step.normalized(), clampf(delta * 0.8, 0.0, 1.0)).normalized()
	else:
		_heart_t += delta
		if _heart_t > HEART_TIME:
			_heart_t = -1.0
			_heart_next = randf_range(HEART_EVERY.x, HEART_EVERY.y)
		elif not _heart_seen and player and player.mode != Rider.Mode.CRASHED and _heart_t > 2.0:
			if Vector2(player.pos.x, player.pos.z).distance_to(_swan_at) < HEART_SEE:
				_heart_seen = true
				swans_love.emit()
	var heart := 0.0
	if _heart_t >= 0.0:
		heart = smoothstep(0.0, 2.0, _heart_t) * (1.0 - smoothstep(HEART_TIME - 2.0, HEART_TIME, _heart_t))
	var yaw := atan2(_swan_dir.x, _swan_dir.y)
	var basis := Basis(Vector3.UP, yaw)
	var side := basis * Vector3(1, 0, 0)
	var fwd := basis * Vector3(0, 0, 1)
	for s in _swan_parts:
		var n: Node3D = s["node"]
		var off: Vector2 = s["offset"]
		var bob := sin(_t * 1.1 + off.y * 2.0) * 0.08
		var p := Vector3(_swan_at.x, 0.0, _swan_at.y) + side * off.x * lerpf(1.0, 1.2, heart) + fwd * (off.y + bob)
		p.y = water.height_at(p.x, p.z) - 0.05 if water else 0.0
		n.global_position = p
		var y := yaw
		if not s["cygnet"]:
			# Herz: beide drehen sich ganz zueinander und biegen die Hälse vor und nach unten, die Köpfe berühren sich
			y -= signf(off.x) * PI * 0.5 * heart
			var neck: Array = s["neck"]
			var bends := [lerpf(-1.3, -1.35, heart), lerpf(0.25, 0.75, heart), lerpf(0.35, 1.05, heart), lerpf(0.6, 0.85, heart)]
			for j in neck.size():
				(neck[j] as Node3D).rotation.x = bends[j]
		n.rotation.y = y


func _clamp_home(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, SWAN_HOME.position.x, SWAN_HOME.end.x), clampf(p.y, SWAN_HOME.position.y, SWAN_HOME.end.y))


# ---------------------------------------------------------------- Graureiher

func _build_heron() -> void:
	# Plätze am Ufer: flaches Land direkt am Wasser, weg von Stegen und Strand
	var spots: Array[Vector3] = []
	for k in 400:
		if spots.size() >= 5:
			break
		var x := randf_range(-90.0, 60.0)
		var z := randf_range(-260.0, -60.0)
		var h := Geo.height(x, z)
		if h < 0.05 or h > 0.8 or Lake.in_lake(x, z, 0.0):
			continue
		if not (Lake.in_lake(x + 2.0, z, 0.0) or Lake.in_lake(x - 2.0, z, 0.0) or Lake.in_lake(x, z + 2.0, 0.0) or Lake.in_lake(x, z - 2.0, 0.0)):
			continue
		spots.append(Vector3(x, h, z))
	_heron_spots = spots
	_heron = Node3D.new()
	_heron.top_level = true
	add_child(_heron)
	if spots.is_empty():
		_heron.visible = false
		return
	var grey := Util.mat(Color(0.55, 0.57, 0.6), 0.7)
	var white := Util.mat(Color(0.85, 0.86, 0.86), 0.7)
	var dark := Util.mat(Color(0.12, 0.12, 0.14), 0.7)
	var yellow := Util.mat(Color(0.85, 0.7, 0.25), 0.5)
	for sx: float in [-0.06, 0.06]:
		Util.beam(_heron, Vector3(sx, 0, 0), Vector3(sx, 0.55, 0), 0.012, yellow)
	_ellipsoid(_heron, Vector3(0.22, 0.22, 0.5), Vector3(0, 0.75, -0.02), grey)
	_ellipsoid(_heron, Vector3(0.06, 0.32, 0.06), Vector3(0, 0.98, 0.14), white)
	_ellipsoid(_heron, Vector3(0.08, 0.08, 0.13), Vector3(0, 1.15, 0.18), white)
	_ellipsoid(_heron, Vector3(0.03, 0.02, 0.14), Vector3(0, 1.15, 0.3), yellow)
	_ellipsoid(_heron, Vector3(0.03, 0.03, 0.12), Vector3(0, 1.17, 0.1), dark)     # schwarzer Schopf
	for sx: float in [-1.0, 1.0]:
		var w := Node3D.new()
		w.position = Vector3(sx * 0.1, 0.82, 0)
		_heron.add_child(w)
		var wm := Util.box(w, Vector3(0.8, 0.02, 0.4), Vector3(sx * 0.4, 0, 0), grey)
		wm.name = "wing"
		w.visible = false
		_heron_wings.append(w)
	_heron_at = randi() % spots.size()
	_heron.global_position = spots[_heron_at]
	_heron.rotation.y = randf() * TAU


func _move_heron(delta: float) -> void:
	if _heron_spots.is_empty():
		return
	if _heron_fly < 0.0:
		if player and Vector2(player.pos.x - _heron.global_position.x, player.pos.z - _heron.global_position.z).length() < 18.0:
			_heron_from = _heron.global_position
			var nxt := (_heron_at + 1 + randi() % maxi(_heron_spots.size() - 1, 1)) % _heron_spots.size()
			_heron_at = nxt
			_heron_to = _heron_spots[nxt]
			_heron_fly = 0.0
			for w in _heron_wings:
				w.visible = true
		return
	var dur := maxf(_heron_from.distance_to(_heron_to) / 7.0, 2.0)
	_heron_fly += delta / dur
	var t := minf(_heron_fly, 1.0)
	var p := _heron_from.lerp(_heron_to, t)
	p.y += sin(t * PI) * 12.0
	var d := _heron_to - _heron_from
	_heron.rotation.y = atan2(d.x, d.z)
	_heron.global_position = p
	for i in _heron_wings.size():
		_heron_wings[i].rotation.z = (1.0 if i == 0 else -1.0) * sin(_t * 6.0) * 0.6
	if _heron_fly >= 1.0:
		_heron_fly = -1.0
		for w in _heron_wings:
			w.visible = false


# ---------------------------------------------------------------- Kraniche

func _build_cranes() -> void:
	_cranes = Node3D.new()
	_cranes.top_level = true
	_cranes.visible = false
	add_child(_cranes)
	var dark := Util.mat(Color(0.22, 0.22, 0.24), 0.8)
	for i in CRANES:
		var b := Node3D.new()
		var row := (i + 1) / 2
		var s := 1.0 if i % 2 == 0 else -1.0
		b.position = Vector3(s * row * 3.2, randf_range(-0.6, 0.6), -row * 4.0) * CRANE_SCALE   # Keil, Spitze vorne (+Z)
		b.scale = Vector3.ONE * CRANE_SCALE
		_cranes.add_child(b)
		Util.box(b, Vector3(0.18, 0.15, 1.5), Vector3.ZERO, dark)               # langer Hals bis Beine
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			b.add_child(w)
			Util.box(w, Vector3(1.1, 0.03, 0.35), Vector3(sx * 0.6, 0, 0), dark)
			w.set_meta("side", sx)
		_crane_birds.append(b)


func _move_cranes(delta: float) -> void:
	if _crane_season == 0:
		return
	if _crane_t < 0.0:
		_crane_next -= delta
		if _crane_next <= 0.0:
			# Zugrichtung: Herbst nach Südwesten, Frühjahr nach Nordosten; quer über den See
			var bearing := deg_to_rad(225.0 if _crane_season < 0 else 45.0) + randf_range(-0.3, 0.3)
			var g := Geo.rel_to_game(sin(bearing), cos(bearing)).normalized()
			_crane_dir = Vector3(g.x, 0.0, g.y)
			var center := Vector3(randf_range(-60.0, 20.0), CRANE_ALT + randf_range(-20.0, 30.0), randf_range(-180.0, -60.0))
			_crane_from = center - _crane_dir * 700.0
			_crane_t = 0.0
			_cranes.visible = true
		return
	_crane_t += delta
	var p := _crane_from + _crane_dir * _crane_t * 16.0
	_cranes.global_position = p
	_cranes.rotation.y = atan2(_crane_dir.x, _crane_dir.z)
	for b in _crane_birds:
		for w in b.get_children():
			if w.has_meta("side"):
				(w as Node3D).rotation.z = float(w.get_meta("side")) * sin(_t * 3.2 + b.position.z * 0.3) * 0.45
	if _crane_t * 16.0 > 1400.0:
		_crane_t = -1.0
		_cranes.visible = false
		_crane_next = randf_range(60.0, 140.0)


# ---------------------------------------------------------------- Libellen, Fledermäuse, Glühwürmchen

func _build_flies() -> void:
	var body_mat := Util.mat(Color(0.1, 0.45, 0.75), 0.3)
	var wing_mat := Util.mat(Color(0.85, 0.9, 1.0, 0.35), 0.1)
	wing_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var homes: Array[Vector3] = []
	for k: String in ["t2_start", "t1_start"]:
		if Geo.masts.has(k):
			var m: Vector3 = Geo.masts[k]
			for j in 4:
				homes.append(m + Vector3(randf_range(-10.0, -2.0), 0.0, randf_range(-14.0, -4.0)))
	for h in homes:
		var n := Node3D.new()
		n.top_level = true
		n.visible = false
		add_child(n)
		Util.box(n, Vector3(0.012, 0.012, 0.09), Vector3.ZERO, body_mat)
		for z: float in [0.012, -0.01]:
			Util.box(n, Vector3(0.13, 0.002, 0.02), Vector3(0, 0.005, z), wing_mat)
		_flies.append({"node": n, "home": h + Vector3(0, 0.8, 0), "phase": randf() * TAU, "goal": h, "t": 0.0})


func _move_flies(delta: float) -> void:
	if not _flies_on:
		return
	for f in _flies:
		var n: Node3D = f["node"]
		f["t"] = float(f["t"]) - delta
		if f["t"] <= 0.0:
			f["t"] = randf_range(0.4, 1.6)       # stehen, dann ruckartig weiter
			f["goal"] = Vector3(f["home"]) + Vector3(randf_range(-3.0, 3.0), randf_range(-0.5, 0.6), randf_range(-3.0, 3.0))
		var to: Vector3 = f["goal"]
		var step := (to - n.global_position).limit_length(4.0 * delta)
		n.global_position += step
		if step.length() > 0.001:
			n.rotation.y = atan2(step.x, step.z)


func _build_bats() -> void:
	var mat := Util.mat(Color(0.06, 0.05, 0.05), 0.9)
	for i in 5:
		var n := Node3D.new()
		n.top_level = true
		n.visible = false
		add_child(n)
		Util.box(n, Vector3(0.05, 0.04, 0.09), Vector3.ZERO, mat)
		for sx: float in [-1.0, 1.0]:
			var w := Node3D.new()
			n.add_child(w)
			Util.box(w, Vector3(0.16, 0.005, 0.1), Vector3(sx * 0.08, 0, 0), mat)
			w.set_meta("side", sx)
		var c := Vector3(randf_range(-30.0, 10.0), randf_range(3.0, 7.0), randf_range(-80.0, -20.0))
		_bats.append({"node": n, "center": c, "phase": randf() * TAU, "r": randf_range(6.0, 14.0)})


func _move_bats(_delta: float) -> void:
	if not _bats_on:
		return
	for b in _bats:
		var n: Node3D = b["node"]
		var ph: float = float(b["phase"]) + _t * 0.9
		var r: float = b["r"]
		# flatterhafte Schleifen
		var p: Vector3 = Vector3(b["center"]) + Vector3(cos(ph) * r + sin(ph * 3.7) * 1.5, sin(ph * 2.3) * 1.2, sin(ph * 1.3) * r)
		var prev := n.global_position
		n.global_position = p
		if (p - prev).length() > 0.0001:
			n.rotation.y = atan2(p.x - prev.x, p.z - prev.z)
		for w in n.get_children():
			if w.has_meta("side"):
				(w as Node3D).rotation.z = float(w.get_meta("side")) * sin(_t * 18.0 + ph) * 0.8


func _build_fireflies() -> void:
	var dot := SphereMesh.new()
	dot.radius = 0.02
	dot.height = 0.04
	dot.radial_segments = 4
	dot.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material = mat
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 0.45, 0.6, 1.0])
	ramp.colors = PackedColorArray([Color(0.7, 1.0, 0.3, 0.0), Color(0.7, 1.0, 0.3, 0.0), Color(0.85, 1.0, 0.4, 1.0),
		Color(0.7, 1.0, 0.3, 0.0), Color(0.7, 1.0, 0.3, 0.0)])
	var spots: Array[Vector3] = []
	for k: String in ["t1_start", "t2_start"]:
		if Geo.masts.has(k):
			spots.append(Geo.masts[k] + Vector3(6.0, 1.0, -20.0))
			spots.append(Geo.masts[k] + Vector3(10.0, 1.0, -45.0))
	for s in spots:
		var p := CPUParticles3D.new()
		p.amount = 40
		p.lifetime = 3.0
		p.preprocess = 3.0
		p.mesh = dot
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(8.0, 1.0, 8.0)
		p.gravity = Vector3.ZERO
		p.direction = Vector3.UP
		p.spread = 180.0
		p.initial_velocity_min = 0.05
		p.initial_velocity_max = 0.2
		p.color_ramp = ramp
		p.emitting = false
		p.visible = false
		p.top_level = true
		add_child(p)
		p.global_position = Vector3(s.x, maxf(Geo.height(s.x, s.z), 0.0) + 1.0, s.z)
		_fireflies.append(p)


# ---------------------------------------------------------------- Eisschollen

func _build_ice() -> void:
	var pts: Array[Transform3D] = []
	for k in 6000:
		if pts.size() >= 160:
			break
		var x := randf_range(-140.0, 80.0)
		var z := randf_range(-300.0, 40.0)
		if x > -18.0 and x < 52.0 and z < 10.0:
			continue                                   # nicht auf den Bahnen und nicht dazwischen
		if not Lake.in_lake(x, z, 0.5) or Lake.in_lake(x, z, 7.0):
			continue                                   # nur ein Streifen am Ufer
		var r := randf_range(0.4, 1.6)
		pts.append(Transform3D(Basis(Vector3.UP, randf() * TAU).scaled(Vector3(r, 1.0, r * randf_range(0.6, 1.0))),
			Vector3(x, 0.03, z)))
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.05
	cyl.height = 0.06
	cyl.radial_segments = 6
	cyl.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cyl
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	_ice = MultiMeshInstance3D.new()
	_ice.multimesh = mm
	_ice.material_override = Util.mat(Color(0.85, 0.9, 0.95), 0.25)
	_ice.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ice.visible = false
	add_child(_ice)


# ---------------------------------------------------------------- Helfer

func _ellipsoid(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 5
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.scale = size
	mi.position = pos
	parent.add_child(mi)
	return mi


func _process(delta: float) -> void:
	_t += delta
	_move_grebes(delta)
	_move_swans(delta)
	_move_heron(delta)
	_move_cranes(delta)
	_move_flies(delta)
	_move_bats(delta)
