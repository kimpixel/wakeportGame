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


## Zwei-Knochen-IK: upper -> lower -> end, Endpunkt auf target, Knie/Ellbogen Richtung pole.
func two_bone(upper: String, lower: String, end: String, target: Vector3, pole: Vector3) -> void:
	var a := global_pose(upper).origin
	var b := global_pose(lower).origin
	var c := global_pose(end).origin
	var l1 := a.distance_to(b)
	var l2 := b.distance_to(c)
	var to_t := target - a
	var d := clampf(to_t.length(), 0.01, (l1 + l2) * 0.999)
	var dir := to_t.normalized()
	# Winkel am oberen Gelenk (Kosinussatz)
	var cos_a := clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0)
	var bend_dir := (pole - a) - dir * (pole - a).dot(dir)
	if bend_dir.length() < 0.001:
		bend_dir = dir.cross(Vector3.RIGHT)
	bend_dir = bend_dir.normalized()
	var b_new := a + (dir * cos_a + bend_dir * sqrt(1.0 - cos_a * cos_a)) * l1
	rotate_global(upper, _arc(b - a, b_new - a))
	# unteres Glied auf das Ziel richten
	var b2 := global_pose(lower).origin
	var c2 := global_pose(end).origin
	rotate_global(lower, _arc(c2 - b2, (a + dir * d) - b2))


## Endknochen (Fuß/Hand) auf eine globale Ausrichtung setzen (Basis im Skelettraum).
func set_end_basis(end: String, basis: Basis) -> void:
	var g := global_pose(end)
	set_global(end, Transform3D(basis, g.origin))


func leg(side: String, foot_target: Vector3, knee_pole: Vector3) -> void:
	two_bone("thigh_" + side, "calf_" + side, "foot_" + side, foot_target, knee_pole)


func arm(side: String, hand_target: Vector3, elbow_pole: Vector3) -> void:
	two_bone("upperarm_" + side, "lowerarm_" + side, "hand_" + side, hand_target, elbow_pole)


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
