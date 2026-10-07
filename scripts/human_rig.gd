class_name HumanRig
extends RefCounted
## Prozedurale Posen für die MakeHuman-Figuren (Skelett "game_engine", Unreal-Namen).
## Kein Animationsmaterial nötig: Becken, Wirbelsäule und Kopf werden direkt gesetzt,
## Arme und Beine per Zwei-Knochen-IK an Zielpunkte (Griff, Bindungen, Bank …) gelegt.
##
## Ablauf pro Frame:  begin() -> set_pelvis() -> bend_spine() -> leg()/arm() -> look_at()

var skeleton: Skeleton3D
var _bones := {}
var _rest_global := {}       # Knochenname -> Ruhepose im Skelettraum


func _init(skel: Skeleton3D) -> void:
	skeleton = skel
	for i in skel.get_bone_count():
		_bones[skel.get_bone_name(i)] = i
	skel.reset_bone_poses()
	for bone_name: String in _bones:
		_rest_global[bone_name] = skel.get_bone_global_pose(_bones[bone_name])


static func find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var s := find_skeleton(c)
		if s:
			return s
	return null


func idx(bone_name: String) -> int:
	return _bones.get(bone_name, -1)


func rest_global(bone_name: String) -> Transform3D:
	return _rest_global[bone_name]


func begin() -> void:
	skeleton.reset_bone_poses()


## Weltpunkt -> Skelettraum
func to_skel(world: Vector3) -> Vector3:
	return skeleton.global_transform.affine_inverse() * world


func global_pose(bone_name: String) -> Transform3D:
	return skeleton.get_bone_global_pose(_bones[bone_name])


## Setzt die globale (Skelettraum-)Transformation eines Knochens.
func set_global(bone_name: String, t: Transform3D) -> void:
	var i: int = _bones[bone_name]
	var parent := skeleton.get_bone_parent(i)
	var parent_t := skeleton.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := parent_t.affine_inverse() * t
	skeleton.set_bone_pose_position(i, local.origin)
	skeleton.set_bone_pose_rotation(i, local.basis.get_rotation_quaternion())


## Dreht einen Knochen zusätzlich um q (Skelettraum, um seinen eigenen Ursprung).
func rotate_global(bone_name: String, q: Quaternion) -> void:
	var g := global_pose(bone_name)
	set_global(bone_name, Transform3D(Basis(q) * g.basis, g.origin))


## Becken an Position (Skelettraum) mit Drehung relativ zur Ruhepose.
func set_pelvis(pos: Vector3, rot: Basis) -> void:
	var rest := rest_global("pelvis")
	set_global("pelvis", Transform3D(rot * rest.basis, pos))


## Wirbelsäule biegen: Drehung q gleichmäßig auf spine_01..03 verteilt.
func bend_spine(q: Quaternion) -> void:
	var part := Quaternion.IDENTITY.slerp(q, 1.0 / 3.0)
	for b: String in ["spine_01", "spine_02", "spine_03"]:
		rotate_global(b, part)


## Kopf (und etwas der Hals) Richtung Zielpunkt drehen, begrenzt.
func look_at(target: Vector3, max_angle := 1.1) -> void:
	for b: String in ["neck_01", "head"]:
		var g := global_pose(b)
		var fwd := (g.basis * _local_forward(b)).normalized()
		var want := (target - g.origin).normalized()
		var q := _limited_arc(fwd, want, max_angle * 0.5)
		rotate_global(b, q)


## Zwei-Knochen-IK: upper -> lower -> end, Endpunkt auf target, Gelenk (Knie/Ellbogen)
## zeigt Richtung pole. rest_joint_dir: wohin das Gelenk in der Ruhepose zeigt (Skelettraum,
## Figur schaut nach +Z): Ellbogen nach hinten (-Z), Knie nach vorne (+Z).
## Die Knochen werden als ganzes Koordinatensystem gedreht (Richtung + Gelenkachse) –
## so knicken Ellbogen und Knie nur in ihre natürliche Richtung und nichts verdreht sich.
func two_bone(upper: String, lower: String, end: String, target: Vector3, pole: Vector3, rest_joint_dir: Vector3) -> void:
	var a := global_pose(upper).origin
	var l1 := rest_global(upper).origin.distance_to(rest_global(lower).origin)
	var l2 := rest_global(lower).origin.distance_to(rest_global(end).origin)
	var to_t := target - a
	var d := clampf(to_t.length(), 0.01, (l1 + l2) * 0.999)
	var dir := to_t.normalized()
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var joint_dir := (pole - a) - dir * (pole - a).dot(dir)
	if joint_dir.length() < 0.001:
		joint_dir = dir.cross(Vector3.RIGHT)
	joint_dir = joint_dir.normalized()
	var b_new := a + (dir * cos_a + joint_dir * sqrt(1.0 - cos_a * cos_a)) * l1
	var c_new := a + dir * d
	# Ruhe-Koordinatensysteme der beiden Glieder
	var ra := rest_global(upper)
	var rb := rest_global(lower)
	var rc := rest_global(end)
	var up_rest := (rb.origin - ra.origin).normalized()
	var lo_rest := (rc.origin - rb.origin).normalized()
	var up_new := (b_new - a).normalized()
	var lo_new := (c_new - b_new).normalized()
	# Gelenkachse: Gliedrichtung x Gelenk-Zeigerichtung (in Ruhe und im Ziel gleich definiert)
	var axis_rest := up_rest.cross(rest_joint_dir).normalized()
	var axis_new := up_new.cross(joint_dir).normalized()
	var q_up := _frame_rot(up_rest, axis_rest, up_new, axis_new)
	var q_lo := _frame_rot(lo_rest, axis_rest, lo_new, axis_new)
	set_global(upper, Transform3D(q_up * ra.basis, a))
	set_global(lower, Transform3D(q_lo * rb.basis, b_new))
	set_global(end, Transform3D(q_lo * rc.basis, c_new))


## Drehung, die (Richtung d0, Achse h0) auf (d1, h1) abbildet.
static func _frame_rot(d0: Vector3, h0: Vector3, d1: Vector3, h1: Vector3) -> Basis:
	var h0o := (h0 - d0 * h0.dot(d0)).normalized()
	var h1o := (h1 - d1 * h1.dot(d1)).normalized()
	var b0 := Basis(d0, h0o, d0.cross(h0o))
	var b1 := Basis(d1, h1o, d1.cross(h1o))
	return b1 * b0.inverse()


## Endknochen (Fuß/Hand) auf eine globale Ausrichtung setzen (Basis im Skelettraum).
func set_end_basis(end: String, basis: Basis) -> void:
	var g := global_pose(end)
	set_global(end, Transform3D(basis, g.origin))


func leg(side: String, foot_target: Vector3, knee_pole: Vector3) -> void:
	two_bone("thigh_" + side, "calf_" + side, "foot_" + side, foot_target, knee_pole, Vector3(0, 0, 1))


func arm(side: String, hand_target: Vector3, elbow_pole: Vector3) -> void:
	two_bone("upperarm_" + side, "lowerarm_" + side, "hand_" + side, hand_target, elbow_pole, Vector3(0, 0, -1))


## Hand umschließt eine Stange (Ristgriff): Arm per IK so, dass die Stange in der Handfläche
## liegt, Handrücken nach oben/vorne, Daumen zur Mitte, Finger zur Faust um die Stange gebogen.
## grip_point: Stelle auf der Stange, toward_center: Stangenrichtung zur anderen Hand (beides Skelettraum).
const GRIP_ALONG := 0.10      # Stange so weit vom Handgelenk Richtung Fingerknöchel ...
const GRIP_PALM := 0.026      # ... und so weit vor der Handfläche (≈ Stangenradius + Polster)
const FINGER_CURL := [1.3, 1.45, 0.8]    # Beugung Grund-, Mittel-, Endgelenk (rad)
const THUMB_CURL := [0.0, 0.3, 0.45]    # Daumen-Mittel-/Endglied zur Stange
const THUMB_UNDER := 0.03              # Daumen so weit unter der Stangenmitte (Handflächenseite)

func grip(side: String, grip_point: Vector3, toward_center: Vector3, elbow_pole: Vector3) -> void:
	var s := 1.0 if side == "l" else -1.0     # Spiegelung: linke und rechte Hand sind Spiegelbilder
	var hand := "hand_" + side
	var rh := rest_global(hand)
	var f_rest := (rest_global("middle_01_" + side).origin - rh.origin).normalized()
	var a_rest := rest_global("index_01_" + side).origin - rest_global("pinky_01_" + side).origin
	a_rest = (a_rest - f_rest * a_rest.dot(f_rest)).normalized()
	var bar := toward_center.normalized()
	var shoulder := global_pose("upperarm_" + side).origin
	# Fingerrichtung: quer zur Stange, etwa von der Schulter weg, aber flacher (Handgelenk leicht gebeugt)
	var d := grip_point - shoulder
	d.y *= 0.4
	var f_new := (d - bar * d.dot(bar)).normalized()
	var palm := f_new.cross(bar) * s
	arm(side, grip_point - f_new * GRIP_ALONG - palm * GRIP_PALM, elbow_pole)
	set_end_basis(hand, _frame_rot(f_rest, a_rest, f_new, bar) * rh.basis)
	# Finger zur Faust: jedes Glied dreht seine Spitze Richtung Handfläche
	var curl_axis := f_new.cross(palm).normalized()
	for finger: String in ["index", "middle", "ring", "pinky"]:
		for k in 3:
			rotate_global("%s_0%d_%s" % [finger, k + 1, side], Quaternion(curl_axis, FINGER_CURL[k]))
	# Daumen: unter der Stange entlang Richtung andere Hand, Spitze leicht um die Stange gebogen
	var t1 := global_pose("thumb_01_" + side).origin
	var t3 := global_pose("thumb_03_" + side).origin
	var thumb_target := grip_point + palm * THUMB_UNDER + bar * 0.035
	rotate_global("thumb_01_" + side, _arc(t3 - t1, thumb_target - t1))
	for k in [1, 2]:
		var tb := "thumb_0%d_%s" % [k + 1, side]
		var g := global_pose(tb)
		var tdir := g.basis.y.normalized()
		var to_bar := grip_point - g.origin
		to_bar -= bar * to_bar.dot(bar)
		var ax := tdir.cross(to_bar)
		if ax.length() > 0.001:
			rotate_global(tb, Quaternion(ax.normalized(), THUMB_CURL[k]))


## Vorwärtsrichtung des Kopfes in Knochen-Koordinaten (aus der Ruhepose: Figur schaut nach +Z).
func _local_forward(bone_name: String) -> Vector3:
	return rest_global(bone_name).basis.inverse() * Vector3(0, 0, 1)


static func _arc(from: Vector3, to: Vector3) -> Quaternion:
	if from.length() < 1e-6 or to.length() < 1e-6:
		return Quaternion.IDENTITY
	return Quaternion(from.normalized(), to.normalized())


static func _limited_arc(from: Vector3, to: Vector3, max_angle: float) -> Quaternion:
	var q := _arc(from, to)
	var angle := q.get_angle()
	if angle > max_angle:
		q = Quaternion.IDENTITY.slerp(q, max_angle / angle)
	return q
