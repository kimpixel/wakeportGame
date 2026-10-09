class_name Ambient
extends Node3D
## Leben am See:
##  * Steuermänner an T1 und T2 laufen zwischen Hütte und Steg umher, Blick auf "ihren" Fahrer
##  * wartende Fahrer mit Helm und Brett auf den Stegen
##  * SUP-Paddler ganz links (nördlich der gelben Bojenkette, im Badebereich)
##  * ab und zu springt ein Hecht in einem Halbbogen aus dem Wasser – wer ihn trifft, macht "Ups"
##    (geheimer Erfolg "Fischkontakt", siehe Achievements)

signal pike_hit

const PIKE_LEN := 0.9
const PIKE_JUMP := 1.6              # Weite des Bogens
const PIKE_HEIGHT := 0.75           # Höhe des Bogens
const PIKE_TIME := 0.8
const PIKE_CLOSE := 0.15            # Anteil der Sprünge knapp vor dem Fahrer (sonst ist er immer schon weg)

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
	# zwei Paddler auf einer großen Runde im Badebereich (Wasser nördlich der Bojenkette)
	var loops := [[Vector2(30.0, 58.0), Vector2(16.0, 7.0), 0.0, 0.75], [Vector2(46.0, 66.0), Vector2(12.0, 6.0), PI, 0.6]]
	var models := ["res://assets/characters/guest_f.glb", "res://assets/characters/guest_m.glb"]
	for k in loops.size():
		var l: Array = loops[k]
		var pts: Array[Vector3] = []
		for j in 32:
			var a := TAU * j / 32.0
			var rel: Vector2 = l[0] + Vector2(cos(a) * l[1].x, sin(a) * l[1].y)
			var g := Geo.rel_to_game(rel.x, rel.y)
			if Geo.height(g.x, g.y) < -0.8:
				pts.append(Vector3(g.x, 0.0, g.y))
		if pts.size() < 8:
			continue
		var p := Person.new()
		p.kind = "sup"
		add_child(p)
		if not p.setup(models[k]):
			p.queue_free()
			continue
		_sups.append({"person": p, "path": pts, "s": float(l[2]) / TAU * pts.size(), "speed": l[3]})


func _move_sups(delta: float) -> void:
	for sup: Dictionary in _sups:
		var pts: Array[Vector3] = sup["path"]
		var n := pts.size()
		var seg_len := pts[0].distance_to(pts[1 % n])
		sup["s"] = fmod(float(sup["s"]) + float(sup["speed"]) * delta / maxf(seg_len, 0.5), float(n))
		var s: float = sup["s"]
		var i := int(s)
		var a := pts[i % n]
		var b := pts[(i + 1) % n]
		var pos := a.lerp(b, s - i)
		var p: Person = sup["person"]
		pos.y = water.height_at(pos.x, pos.z)
		p.global_position = pos
		var d := b - a
		p.rotation.y = lerp_angle(p.rotation.y, atan2(d.x, d.z), clampf(delta * 1.5, 0.0, 1.0))


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
	_move_sups(delta)
	_move_pike(delta)
