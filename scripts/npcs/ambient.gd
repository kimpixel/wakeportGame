class_name Ambient
extends Node3D
## Leben am See:
##  * Steuermänner an T1 und T2 laufen zwischen Hütte und Steg umher, Blick auf "ihren" Fahrer
##  * wartende Fahrer mit Helm und Brett auf den Stegen
##  * SUP-Paddler: zwei im Badebereich (nördlich der gelben Bojenkette), drei auf Touren durch den See
##    (zwei zwischen T2 und T1, einer seeseitig neben T2) – wer schnell dicht vorbeifährt, spritzt sie
##    nass (geheimer Erfolg "Nass gespritzt")
##  * Mückenschwärme am Waldrand neben T1 – wer durchfährt, verschluckt ein Insekt (Erfolg "Insekten fressen")
##  * ab und zu springt ein Hecht in einem Halbbogen aus dem Wasser – wer ihn trifft, macht "Ups"
##    (geheimer Erfolg "Fischkontakt", siehe Achievements)

signal pike_hit
signal sup_splashed                 # Spieler hat einen SUP-Paddler nass gespritzt
signal insect_eaten                 # Spieler ist durch einen Mückenschwarm gefahren

const PIKE_LEN := 0.9
const PIKE_JUMP := 1.6              # Weite des Bogens
const PIKE_HEIGHT := 0.75           # Höhe des Bogens
const PIKE_TIME := 0.8
const PIKE_CLOSE := 0.15            # Anteil der Sprünge knapp vor dem Fahrer (sonst ist er immer schon weg)
## SUP-Touren (Spielkoordinaten): Mitte (x, z), Halbachsen (x, z), Startphase 0..1, Tempo m/s, Figur
const SUP_TOURS := [
	[Vector2(16.5, -125.0), Vector2(1.6, 58.0), 0.1, 0.8, 0],
	[Vector2(16.5, -125.0), Vector2(1.6, 58.0), 0.6, 0.7, 1],
	[Vector2(-20.0, -135.0), Vector2(1.5, 50.0), 0.35, 0.75, 1],
]
const SPRAY_SPEED := 6.0            # m/s: so schnell muss man sein, damit es spritzt
const SPRAY_DIST := 3.0             # m: so dicht am SUP vorbei
const SUP_WOBBLE := 1.6             # s wackelt der Paddler danach
## Mückenschwärme: Abstand entlang T1 vom Startmast (m); je Stelle ein Schwarm INSECT_SHORE vor dem Ufer
const INSECT_S := [32.0, 36.0, 41.0, 48.0, 58.0]
const INSECT_SHORE := 3.0
const INSECT_Y := 1.6               # Höhe der Wolke über dem Wasser (Kopfhöhe)
const INSECT_R := 1.1               # Radius der Wolke

var beach: Beach
var water: Water
var features: FeatureSet
var sfx: Sfx
var player: Rider                   # Spieler (für den Hecht)

var _operators := {}                # "T1"/"T2" -> Person
var _sups: Array[Dictionary] = []   # {person, path: Array[Vector3], s, speed}
var _pike: Node3D
var _pike_t := -1.0                 # < 0: unter Wasser
var _pike_next := 12.0
var _pike_from := Vector3.ZERO
var _pike_dir := Vector3.FORWARD
var _pike_hit := false
var _splash: CPUParticles3D
var _insects: Array[Dictionary] = []   # {node, home, phase, cool}
var _t := 0.0


func build() -> void:
	for t: String in beach.operator_paths:
		var op := Person.new()
		op.kind = "operator"
		op.path = beach.operator_paths[t]
		add_child(op)
		if op.setup("res://assets/characters/operator.glb"):
			_operators[t] = op
		else:
			op.queue_free()
	var models := ["res://assets/characters/guest_m.glb", "res://assets/characters/guest_f.glb"]
	var i := 0
	for spot: Dictionary in beach.waiting_spots:
		var w := Person.new()
		w.kind = spot["kind"]
		w.board_design = 1 + i % (BoardLibrary.count() - 1)
		w.helmet_design = [3, 1, 5, 4, 6][i % 5]
		add_child(w)
		w.global_position = spot["pos"]
		var f: Vector3 = spot["face"]
		w.rotation.y = atan2(f.x, f.z)
		if not w.setup(models[i % models.size()]):
			w.queue_free()
		i += 1
	_build_sups()
	_build_pike()
	_build_insects()


## Steuermann einer Anlage ("T1"/"T2") oder null.
func operator(t: String) -> Node3D:
	return _operators.get(t, null)


## Wer schaut auf wen: die Steuermänner auf den Fahrer ihrer Anlage, die Wartenden auf den Spieler.
func set_watch(t2_rider: Node3D, t1_rider: Node3D) -> void:
	if _operators.has("T2"):
		_operators["T2"].watch = t2_rider
	if _operators.has("T1"):
		_operators["T1"].watch = t1_rider
	for c in get_children():
		if c is Person and (c as Person).kind.begins_with("wait"):
			(c as Person).watch = player


# ---------------------------------------------------------------- SUP

func _build_sups() -> void:
	var models := ["res://assets/characters/guest_f.glb", "res://assets/characters/guest_m.glb"]
	# zwei Paddler auf einer großen Runde im Badebereich (Wasser nördlich der Bojenkette)
	var loops := [[Vector2(30.0, 58.0), Vector2(16.0, 7.0), 0.0, 0.75], [Vector2(46.0, 66.0), Vector2(12.0, 6.0), PI, 0.6]]
	for k in loops.size():
		var l: Array = loops[k]
		var pts: Array[Vector3] = []
		for j in 32:
			var a := TAU * j / 32.0
			var rel: Vector2 = l[0] + Vector2(cos(a) * l[1].x, sin(a) * l[1].y)
			var g := Geo.rel_to_game(rel.x, rel.y)
			if Geo.height(g.x, g.y) < -0.8:
				pts.append(Vector3(g.x, 0.0, g.y))
		_add_sup(pts, float(l[2]) / TAU, l[3], models[k])
	# Touren durch den See (Spielkoordinaten, lange schmale Runden): zwei zwischen T2 und T1, einer
	# seeseitig neben T2 (außerhalb der Features, x bis ±11,3 m) – dort kommen sie in Reichweite
	for t: Array in SUP_TOURS:
		var c: Vector2 = t[0]
		var r: Vector2 = t[1]
		var pts: Array[Vector3] = []
		for j in 48:
			var a := TAU * j / 48.0
			pts.append(Vector3(c.x + cos(a) * r.x, 0.0, c.y + sin(a) * r.y))
		_add_sup(pts, t[2], t[3], models[int(t[4])])


func _add_sup(pts: Array[Vector3], phase: float, speed: float, model: String) -> void:
	if pts.size() < 8:
		return
	var p := Person.new()
	p.kind = "sup"
	add_child(p)
	if not p.setup(model):
		p.queue_free()
		return
	_sups.append({"person": p, "path": pts, "s": phase * pts.size(), "speed": speed, "wet": 0.0, "cool": 0.0})


func _move_sups(delta: float) -> void:
	for sup: Dictionary in _sups:
		var pts: Array[Vector3] = sup["path"]
		var n := pts.size()
		var i := int(sup["s"])
		var seg_len := pts[i % n].distance_to(pts[(i + 1) % n])
		sup["s"] = fmod(float(sup["s"]) + float(sup["speed"]) * delta / maxf(seg_len, 0.5), float(n))
		var s: float = sup["s"]
		i = int(s)
		var a := pts[i % n]
		var b := pts[(i + 1) % n]
		var pos := a.lerp(b, s - i)
		var p: Person = sup["person"]
		pos.y = water.height_at(pos.x, pos.z)
		p.global_position = pos
		var d := b - a
		p.rotation.y = lerp_angle(p.rotation.y, atan2(d.x, d.z), clampf(delta * 1.5, 0.0, 1.0))
		# nass gespritzt: Paddler wackelt kurz auf dem Board
		sup["wet"] = maxf(float(sup["wet"]) - delta / SUP_WOBBLE, 0.0)
		sup["cool"] = maxf(float(sup["cool"]) - delta, 0.0)
		p.rotation.z = 0.14 * float(sup["wet"]) * sin(float(sup["wet"]) * 30.0)
		_check_spray(sup, pos)


## Spieler fährt schnell dicht am SUP vorbei (oder landet daneben): Gischt trifft den Paddler.
func _check_spray(sup: Dictionary, pos: Vector3) -> void:
	if player == null or player.mode != Rider.Mode.WATER or float(sup["cool"]) > 0.0:
		return
	if player.horizontal_speed() < SPRAY_SPEED or player.pos.y > 0.3:
		return
	if Vector2(player.pos.x - pos.x, player.pos.z - pos.z).length() > SPRAY_DIST:
		return
	sup["wet"] = 1.0
	sup["cool"] = 6.0
	_splash_at(pos.lerp(player.pos, 0.4))
	sup_splashed.emit()


# ---------------------------------------------------------------- Insekten

## Mückenschwärme am Waldrand rechts neben T1 (vom Start aus gesehen): über dem Wasser ein paar
## Meter vor dem Ufer. Wer ganz weit rausfährt und durchfährt, verschluckt ein Insekt.
func _build_insects() -> void:
	if not Geo.masts.has("t1_start"):
		return
	var a: Vector3 = Geo.masts["t1_start"]
	var b: Vector3 = Geo.masts["t1_end"]
	var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
	var right := dir.cross(Vector3.UP)
	var dot := BoxMesh.new()
	dot.size = Vector3.ONE * 0.035
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.06, 0.05, 0.04)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dot.material = mat
	for s: float in INSECT_S:
		var base := a + dir * s
		var off := 0.0
		while off < 40.0 and Lake.in_lake(base.x + right.x * off, base.z + right.z * off, 0.0):
			off += 0.5
		if off >= 40.0 or off < INSECT_SHORE + 4.0:
			continue
		var c := base + right * (off - INSECT_SHORE)
		var swarm := CPUParticles3D.new()
		swarm.amount = 70
		swarm.lifetime = 1.6
		swarm.preprocess = 2.0
		swarm.mesh = dot
		swarm.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		swarm.emission_sphere_radius = INSECT_R * 0.7
		swarm.direction = Vector3.UP
		swarm.spread = 180.0
		swarm.gravity = Vector3.ZERO
		swarm.initial_velocity_min = 0.2
		swarm.initial_velocity_max = 0.7
		swarm.radial_accel_min = -1.2          # zieht zur Mitte zurück: bleibt eine Wolke
		swarm.radial_accel_max = -0.6
		swarm.tangential_accel_min = -1.5
		swarm.tangential_accel_max = 1.5
		swarm.top_level = true
		add_child(swarm)
		var home := Vector3(c.x, INSECT_Y, c.z)
		swarm.global_position = home
		_insects.append({"node": swarm, "home": home, "phase": randf() * TAU, "cool": 0.0})


func _move_insects(delta: float) -> void:
	for sw: Dictionary in _insects:
		var ph: float = sw["phase"] + _t * 0.7
		var node: CPUParticles3D = sw["node"]
		node.global_position = sw["home"] + Vector3(sin(ph) * 0.6, sin(ph * 1.7) * 0.25, cos(ph * 0.8) * 0.6)
		sw["cool"] = maxf(float(sw["cool"]) - delta, 0.0)
		if player == null or player.mode == Rider.Mode.CRASHED or float(sw["cool"]) > 0.0:
			continue
		var head := player.pos + Vector3(0.0, 1.55, 0.0)
		var d := head - node.global_position
		if Vector2(d.x, d.z).length() < INSECT_R and absf(d.y) < INSECT_R:
			sw["cool"] = 8.0
			insect_eaten.emit()


# ---------------------------------------------------------------- Hecht

func _build_pike() -> void:
	_pike = Node3D.new()
	_pike.visible = false
	_pike.top_level = true
	add_child(_pike)
	var body := SphereMesh.new()
	body.radius = 0.5
	body.height = 1.0
	var olive := Util.mat(Color(0.3, 0.36, 0.18), 0.35)
	var mi := MeshInstance3D.new()
	mi.mesh = body
	mi.material_override = olive
	mi.scale = Vector3(0.11, 0.13, PIKE_LEN)          # lang und schlank, Kopf nach +Z
	_pike.add_child(mi)
	var belly := MeshInstance3D.new()
	belly.mesh = body
	belly.material_override = Util.mat(Color(0.82, 0.8, 0.62), 0.4)
	belly.scale = Vector3(0.095, 0.08, PIKE_LEN * 0.85)
	belly.position = Vector3(0, -0.03, 0.02)
	_pike.add_child(belly)
	# Schwanzflosse und Rückenflosse
	var fin := PrismMesh.new()
	fin.size = Vector3(0.02, 0.22, 0.2)
	for f: Array in [[Vector3(0, 0, -PIKE_LEN * 0.55), Vector3(PI * 0.5, 0, 0)], [Vector3(0, 0.07, -PIKE_LEN * 0.3), Vector3.ZERO]]:
		var fm := MeshInstance3D.new()
		fm.mesh = fin
		fm.material_override = olive
		fm.position = f[0]
		fm.rotation = f[1]
		fm.scale = Vector3(1, 1, 1) if f[1] == Vector3.ZERO else Vector3(1, 1.2, 1)
		_pike.add_child(fm)
	Util.sphere(_pike, 0.018, Vector3(0.05, 0.03, PIKE_LEN * 0.4), Util.mat(Color(0.9, 0.85, 0.3), 0.3))
	Util.sphere(_pike, 0.018, Vector3(-0.05, 0.03, PIKE_LEN * 0.4), Util.mat(Color(0.9, 0.85, 0.3), 0.3))
	_splash = CPUParticles3D.new()
	_splash.emitting = false
	_splash.one_shot = true
	_splash.amount = 40
	_splash.lifetime = 0.6
	_splash.explosiveness = 0.9
	_splash.direction = Vector3.UP
	_splash.spread = 40.0
	_splash.initial_velocity_min = 1.0
	_splash.initial_velocity_max = 2.6
	_splash.gravity = Vector3(0, -9.8, 0)
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Util.mat(Color(0.95, 0.97, 1.0), 0.3)
	_splash.mesh = drop
	_splash.top_level = true
	add_child(_splash)


## Neuen Sprung planen: meist ein Stück vor dem Spieler (damit man ihn sieht), manchmal genau in der Spur.
## Ab und zu (PIKE_CLOSE) knapp voraus: dann ist der Fahrer mitten im Bogen dort – mit Lenken zu treffen.
## close (Test --pike-at): knapp voraus, genau in der Spur, springt in Fahrtrichtung.
func _start_pike(close := false) -> void:
	if player == null:
		return
	var v := Vector3(player.vel.x, 0.0, player.vel.z)
	var fwd := v.normalized() if v.length() > 2.0 else -player.global_basis.z
	var side := fwd.cross(Vector3.UP)
	var ahead := randf_range(10.0, 22.0)
	var off := randf_range(-0.4, 0.4) if randf() < 0.35 else randf_range(2.0, 5.0) * (1.0 if randf() < 0.5 else -1.0)
	var near := close or randf() < PIKE_CLOSE
	if near:
		ahead = v.length() * PIKE_TIME * 0.5 + randf_range(0.5, 2.0)
		off = 0.0 if close else randf_range(-2.0, 2.0)
	var at := player.pos + fwd * ahead + side * off
	if not Lake.in_lake(at.x, at.z, 3.0) or (features and features.height_at(at.x, at.z) > FeaturePart.NONE + 1.0):
		_pike_next = 3.0
		return
	var a := randf() * TAU
	_pike_dir = fwd if close else Vector3(cos(a), 0.0, sin(a))
	_pike_from = at - _pike_dir * PIKE_JUMP * 0.5
	_pike_t = 0.0
	_pike_hit = false
	_pike.visible = true
	_splash_at(_pike_from)


## Test: Hecht springt sofort knapp vor dem Fahrer.
func pike_now() -> void:
	_start_pike(true)


func _splash_at(p: Vector3) -> void:
	_splash.global_position = Vector3(p.x, water.height_at(p.x, p.z), p.z)
	_splash.restart()
	if sfx:
		sfx.splash_at(_splash.global_position)


func _move_pike(delta: float) -> void:
	if _pike_t < 0.0:
		_pike_next -= delta
		if _pike_next <= 0.0:
			_pike_next = randf_range(15.0, 35.0)
			_start_pike()
		return
	_pike_t += delta / PIKE_TIME
	if _pike_t >= 1.0:
		_splash_at(_pike_from + _pike_dir * PIKE_JUMP)
		_pike_t = -1.0
		_pike.visible = false
		return
	var t := _pike_t
	# Halbbogen: kommt schräg aus dem Wasser, dreht in der Luft über den Kopf und taucht wieder ein
	var p := _pike_from + _pike_dir * PIKE_JUMP * t
	var wy := water.height_at(p.x, p.z)
	p.y = wy - 0.25 + (PIKE_HEIGHT + 0.25) * 4.0 * t * (1.0 - t)
	var vel := _pike_dir * PIKE_JUMP + Vector3.UP * (PIKE_HEIGHT + 0.25) * 4.0 * (1.0 - 2.0 * t)
	_pike.global_transform = Transform3D(Basis.looking_at(-vel.normalized(), Vector3.UP).orthonormalized(), p)
	# Zusammenstoß mit dem Spieler
	if not _pike_hit and player and player.mode != Rider.Mode.CRASHED:
		var body := player.pos + Vector3(0, 0.5, 0)
		if body.distance_to(p) < 0.75:
			_pike_hit = true
			player.ups()
			pike_hit.emit()


func _process(delta: float) -> void:
	if water == null:
		return
	_t += delta
	_move_sups(delta)
	_move_pike(delta)
	_move_insects(delta)
