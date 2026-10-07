class_name Person
extends Node3D
## Lebende Nebenfigur (MakeHuman-Modell), Pose jedes Bild per IK aus dem HumanRig.
## Der Knoten steht auf dem Boden, das Modell schaut nach lokal +Z.
## Arten (kind):
##  * "operator"  – Steuermann mit Fernsteuerung (quer, beide Hände an den Enden); läuft
##                   zwischen Wegpunkten (Hütte, Treppe, Steg) hin und her, steht dazwischen,
##                   hat aber immer ein Auge auf den Fahrer (Kopf und Oberkörper drehen mit)
##  * "wait_stand" – wartender Fahrer mit Helm, hält sein Brett aufrecht neben sich
##  * "wait_sit"   – wartender Fahrer mit Helm, sitzt an der Stegkante, Beine baumeln
##  * "sup"        – Stand-up-Paddler auf einem Board, paddelt (Zieh-Zyklus, Seitenwechsel)

const WALK_SPEED := 0.9
const STRIDE := 0.32                 # halbe Schrittlänge

var kind := "operator"
var watch: Node3D                    # wen die Figur im Blick hat (der Fahrer)
var path: Array[Vector3] = []        # operator: Wegpunkte (Welt), als Kette begehbar
var board_design := 1
var helmet_design := 1

var _rig: HumanRig
var _fig: Node3D
var _t := 0.0
var _phase := 0.0
var _seed := 0.0

# operator
var _remote: Node3D
var _at := 0                         # aktueller Wegpunkt
var _goal := 0                       # Ziel-Wegpunkt
var _wait := 2.0
var _walking := false

# sup
var _paddle: MeshInstance3D
var _paddle_side := 1.0


func setup(model: String) -> bool:
	if not ResourceLoader.exists(model):
		return false
	_fig = (load(model) as PackedScene).instantiate()
	add_child(_fig)
	var skel := HumanRig.find_skeleton(_fig)
	if skel == null:
		return false
	_rig = HumanRig.new(skel)
	_seed = randf() * 100.0
	match kind:
		"operator":
			_build_remote()
			if not path.is_empty():
				global_position = path[0]
				_wait = randf_range(2.0, 6.0)
		"wait_stand":
			_attach_helmet()
			var b := BoardLibrary.make(board_design)
			# hochkant neben der rechten Hand (rechts = lokal -X), Bindungen nach vorne
			b.transform = Transform3D(Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, -PI * 0.5),
				Vector3(-0.5, Wakeboard.LENGTH * 0.5 + 0.01, 0.1))
			add_child(b)
		"wait_sit":
			_attach_helmet()
			var b := BoardLibrary.make(board_design)
			b.transform = Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.9, 0.0, -0.25))
			add_child(b)
		"sup":
			_build_sup()
	return true


func _process(delta: float) -> void:
	if _rig == null:
		return
	_t += delta
	match kind:
		"operator":
			_move_operator(delta)
		"sup":
			_phase += delta * 1.6
	_rig.begin()
	match kind:
		"operator":
			_pose_operator()
		"wait_stand":
			_pose_stand()
		"wait_sit":
			_pose_sit()
		"sup":
			_pose_sup()
	if watch and kind != "sup":
		_rig.look_at(_rig.to_skel(watch.global_position + Vector3(0, 1.0, 0)), 1.2)
	elif kind == "sup":
		_rig.look_at(_rig.to_skel(global_transform * Vector3(0, 1.4, 10)), 0.5)


# ---------------------------------------------------------------- Steuermann

func _build_remote() -> void:
	_remote = Node3D.new()
	_remote.position = Vector3(0.0, 1.08, 0.3)
	add_child(_remote)
	Util.box(_remote, Vector3(0.3, 0.07, 0.1), Vector3.ZERO, Util.mat(Color(1.0, 0.82, 0.05), 0.5))
	Util.box(_remote, Vector3(0.05, 0.03, 0.05), Vector3(0, 0.05, 0), Util.mat(Color(0.85, 0.1, 0.1)))
	var black := Util.mat(Color(0.08, 0.08, 0.09), 0.6)
	Util.box(_remote, Vector3(0.03, 0.02, 0.03), Vector3(-0.07, 0.045, 0), black)
	Util.box(_remote, Vector3(0.03, 0.02, 0.03), Vector3(0.07, 0.045, 0), black)


func _move_operator(delta: float) -> void:
	if path.size() < 2:
		return
	if not _walking:
		_wait -= delta
		_face(_watch_dir(), delta * 2.0)
		if _wait <= 0.0:
			_goal = randi() % path.size()
			_walking = _goal != _at
			_wait = randf_range(3.0, 9.0)
		return
	var next := _at + signi(_goal - _at)
	var to := path[next] - global_position
	var step := WALK_SPEED * delta
	if to.length() <= step:
		global_position = path[next]
		_at = next
		if _at == _goal:
			_walking = false
		return
	global_position += to.normalized() * step
	_face(Vector3(to.x, 0.0, to.z), delta * 6.0)
	_phase += PI * WALK_SPEED / (2.0 * STRIDE) * delta


func _watch_dir() -> Vector3:
	if watch == null:
		return global_basis.z
	var d := watch.global_position - global_position
	return Vector3(d.x, 0.0, d.z)


## Körper (lokal +Z) langsam in Richtung dir drehen.
func _face(dir: Vector3, rate: float) -> void:
	if dir.length() < 0.01:
		return
	var want := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, want, clampf(rate, 0.0, 1.0))


func _pose_operator() -> void:
	var walk := 1.0 if _walking else 0.0
	_pose_legs(walk, 0.02)
	# Oberkörper zum Fahrer drehen (beim Gehen behält er ihn so im Blick)
	var d := _watch_dir()
	if d.length() > 0.1:
		var local_d := global_basis.inverse() * d
		var yaw := clampf(atan2(local_d.x, local_d.z), -0.9, 0.9)
		_rig.bend_spine(Quaternion(Vector3.UP, yaw * 0.7))
	_hold_remote()


func _hold_remote() -> void:
	for side: String in ["l", "r"]:
		var sx := 1.0 if side == "l" else -1.0          # links = lokal +X
		var grip_at := _remote.position + Vector3(sx * 0.12, 0.0, 0.0)
		var pole := Vector3(sx * 0.6, 0.9, -0.2)
		_rig.grip(side, _rig.to_skel(global_transform * grip_at),
			_rig.skeleton.global_transform.basis.inverse() * (global_basis * Vector3(-sx, 0, 0)),
			_rig.to_skel(global_transform * pole))


## Beine: stehen (walk = 0) oder gehen (walk = 1, Schrittzyklus aus _phase).
func _pose_legs(walk: float, dip: float) -> void:
	var pelvis := _rig.rest_global("pelvis").origin
	pelvis.y -= dip + walk * 0.03 * absf(cos(_phase))
	var sway := sin(_t * 0.7 + _seed) * 0.01 * (1.0 - walk)
	pelvis.x += sway
	_rig.set_pelvis(pelvis, Basis.IDENTITY)
	for side: String in ["l", "r"]:
		var foot := _rig.rest_global("foot_" + side).origin
		var ph := _phase + (0.0 if side == "l" else PI)
		foot.z += walk * -STRIDE * cos(ph)
		foot.y += walk * 0.09 * maxf(0.0, sin(ph))
		_rig.leg(side, foot, foot + Vector3(0.0, 0.5, 1.0))


# ---------------------------------------------------------------- Wartende Fahrer

func _pose_stand() -> void:
	_pose_legs(0.0, 0.03)
	# rechte Hand am Brett (oben an der Kante), linke Hand locker an der Hüfte
	_rig.arm("r", _rig.to_skel(global_transform * Vector3(-0.42, 1.25, 0.1)),
		_rig.to_skel(global_transform * Vector3(-0.9, 1.0, -0.4)))
	_rig.arm("l", _rig.to_skel(global_transform * Vector3(0.22, 0.95, -0.02)),
		_rig.to_skel(global_transform * Vector3(0.7, 1.0, -0.4)))


func _pose_sit() -> void:
	# sitzt an der Stegkante (Knotenursprung = Kante, Beine baumeln nach +Z über dem Wasser)
	var pelvis := Vector3(0.0, 0.12, -0.12)
	_rig.set_pelvis(_rig.to_skel(global_transform * pelvis), Basis.IDENTITY)
	var swing := sin(_t * 1.3 + _seed) * 0.06
	for side: String in ["l", "r"]:
		var sx := 1.0 if side == "l" else -1.0
		var foot := Vector3(sx * 0.13, -0.42, 0.3 + swing * sx)
		_rig.leg(side, _rig.to_skel(global_transform * foot), _rig.to_skel(global_transform * Vector3(sx * 0.15, 0.6, 1.2)))
		_rig.arm(side, _rig.to_skel(global_transform * Vector3(sx * 0.27, 0.03, -0.18)),
			_rig.to_skel(global_transform * Vector3(sx * 0.8, 0.6, -0.6)))


func _attach_helmet() -> void:
	var att := BoneAttachment3D.new()
	att.bone_name = "head"
	_rig.skeleton.add_child(att)
	var h := Helmet.new(helmet_design)
	h.transform = Transform3D(_rig.rest_global("head").basis.orthonormalized().inverse(), Vector3.ZERO)
	att.add_child(h)


# ---------------------------------------------------------------- SUP

func _build_sup() -> void:
	var deck := CapsuleMesh.new()
	deck.radius = 0.4
	deck.height = 3.2
	var mi := MeshInstance3D.new()
	mi.mesh = deck
	var colors := [Color(0.95, 0.95, 0.92), Color(0.2, 0.6, 0.85), Color(0.95, 0.55, 0.15)]
	mi.material_override = Util.mat(colors[randi() % colors.size()], 0.4)
	mi.rotation.x = PI * 0.5
	mi.scale = Vector3(1.0, 1.0, 0.16)
	mi.position.y = 0.04
	add_child(mi)
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.016
	shaft.bottom_radius = 0.016
	shaft.height = 1.0
	_paddle = MeshInstance3D.new()
	_paddle.mesh = shaft
	_paddle.material_override = Util.mat(Color(0.1, 0.1, 0.12), 0.5)
	_paddle.top_level = true
	add_child(_paddle)
	var blade := Util.box(_paddle, Vector3(0.2, 0.45, 0.02), Vector3(0, -0.5, 0), Util.mat(Color(0.1, 0.1, 0.12), 0.5))
	blade.name = "blade"


func _pose_sup() -> void:
	# Füße nebeneinander, etwas in die Knie
	var pelvis := _rig.rest_global("pelvis").origin
	pelvis.y -= 0.05 + 0.03 * sin(_phase * 2.0)
	_rig.set_pelvis(pelvis, Basis.IDENTITY)
	for side: String in ["l", "r"]:
		var foot := _rig.rest_global("foot_" + side).origin
		foot.y += 0.08
		_rig.leg(side, foot, foot + Vector3(0.0, 0.5, 1.0))
	# Paddelzug: Blatt vorne einstechen, am Körper vorbei nach hinten ziehen; alle 4 Züge Seite wechseln
	var cyc := fmod(_phase, TAU)
	if cyc < 0.05 and fmod(_phase, TAU * 4.0) < 0.05:
		_paddle_side = -_paddle_side
	var pull := 0.5 - 0.5 * cos(cyc) if cyc < PI else 0.5 + 0.5 * cos(cyc - PI)   # 0 vorne -> 1 hinten -> 0
	var sx := _paddle_side
	var lower := Vector3(sx * 0.32, 0.95, lerpf(0.55, -0.25, pull))
	var top := lower + Vector3(-sx * 0.25, 0.6, 0.15)
	_rig.bend_spine(Quaternion(Vector3.UP, sx * (0.35 - 0.6 * pull)) * Quaternion(Vector3.RIGHT, 0.2))
	var lower_side := "l" if sx > 0.0 else "r"
	var top_side := "r" if sx > 0.0 else "l"
	_rig.arm(lower_side, _rig.to_skel(global_transform * lower), _rig.to_skel(global_transform * Vector3(sx * 0.9, 0.8, -0.3)))
	_rig.arm(top_side, _rig.to_skel(global_transform * top), _rig.to_skel(global_transform * Vector3(-sx * 0.8, 1.4, -0.3)))
	# Paddel: von der oberen Hand durch die untere bis ins Wasser
	var a := global_transform * top
	var b := global_transform * lower
	var dir := (b - a).normalized()
	var tip := a + dir * 1.95
	var mid := (a + tip) * 0.5
	var up := -dir
	var side := up.cross(global_basis.z).normalized()
	if side.length() < 0.1:
		side = global_basis.x
	_paddle.global_transform = Transform3D(Basis(side, up, side.cross(up)).scaled(Vector3(1.0, a.distance_to(tip), 1.0)), mid)
	var blade: Node3D = _paddle.get_node("blade")
	blade.scale = Vector3(1.0, 1.0 / a.distance_to(tip), 1.0)
