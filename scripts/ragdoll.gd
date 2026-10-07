class_name Ragdoll
extends RefCounted
## Ragdoll für die MakeHuman-Figuren beim Sturz.
## Kapseln (PhysicalBone3D) an den Hauptknochen, Ellbogen und Knie als Scharnier, der Rest
## als Kugelgelenk mit Grenzen. Starke Dämpfung wie im Wasser; eine unsichtbare Ebene auf
## Wasserhöhe hält den Körper an der Oberfläche (grober Auftrieb).
## Die Knochen kollidieren nur mit dieser Ebene, nicht untereinander (stabil, keine Explosionen).

const LAYER_BONES := 1 << 9
const LAYER_WATER := 1 << 10

# Knochen: [Kindknochen fürs Längenmaß, Radius, Masse, Gelenk ("cone"/"hinge"/""), Schwenkgrenze °]
const BONES := {
	"pelvis":     ["spine_01", 0.13, 12.0, "", 0.0],
	"spine_02":   ["neck_01", 0.14, 16.0, "cone", 25.0],
	"head":       ["", 0.11, 5.0, "cone", 40.0],
	"upperarm_l": ["lowerarm_l", 0.05, 2.5, "cone", 80.0],
	"lowerarm_l": ["hand_l", 0.04, 2.0, "hinge", 0.0],
	"upperarm_r": ["lowerarm_r", 0.05, 2.5, "cone", 80.0],
	"lowerarm_r": ["hand_r", 0.04, 2.0, "hinge", 0.0],
	"thigh_l":    ["calf_l", 0.07, 9.0, "cone", 60.0],
	"calf_l":     ["foot_l", 0.05, 4.5, "hinge", 0.0],
	"thigh_r":    ["calf_r", 0.07, 9.0, "cone", 60.0],
	"calf_r":     ["foot_r", 0.05, 4.5, "hinge", 0.0],
}
# Scharnier: Kindknochen des unteren Glieds, um die Beugeachse aus der Ruhepose zu bestimmen
const HINGE_PARENT := {"lowerarm_l": "upperarm_l", "lowerarm_r": "upperarm_r", "calf_l": "thigh_l", "calf_r": "thigh_r"}

var active := false
var _sim: PhysicalBoneSimulator3D
var _bones: Array[PhysicalBone3D] = []
var _water: StaticBody3D
var _skel: Skeleton3D
var _owner: Node3D
var _binding: Generic6DOFJoint3D   # Brett: beide Unterschenkel fest miteinander verbunden
var _chest_local := Vector3.FORWARD     # Brustrichtung im Knochenraum von spine_02

const VEST_TORQUE := 140.0   # Auftrieb der Prallweste vorne: dreht auf den Rücken (N·m bei Bauchlage)


func _init(skel: Skeleton3D, owner_node: Node3D) -> void:
	_skel = skel
	_owner = owner_node
	_sim = PhysicalBoneSimulator3D.new()
	skel.add_child(_sim)
	for bone_name: String in BONES:
		var cfg: Array = BONES[bone_name]
		var i := skel.find_bone(bone_name)
		if i < 0:
			continue
		var rest := skel.get_bone_global_rest(i)
		var length := 0.22
		if cfg[0] != "":
			length = rest.origin.distance_to(skel.get_bone_global_rest(skel.find_bone(cfg[0])).origin)
		var radius: float = cfg[1]
		var pb := PhysicalBone3D.new()
		pb.name = "rd_" + bone_name
		pb.bone_name = bone_name
		pb.mass = cfg[2]
		pb.friction = 0.2
		pb.linear_damp = 1.6           # Wasser bremst
		pb.angular_damp = 3.0
		pb.collision_layer = LAYER_BONES
		pb.collision_mask = LAYER_WATER
		# Körper mittig auf dem Knochen (Knochen-Y zeigt zum Kindknochen)
		pb.body_offset = Transform3D(Basis.IDENTITY, Vector3(0.0, length * 0.5, 0.0))
		var shape := CapsuleShape3D.new()
		shape.radius = radius
		shape.height = maxf(length + radius * 0.5, radius * 2.0 + 0.01)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		pb.add_child(cs)
		# Gelenk am Knochenanfang
		var joint_basis := Basis.IDENTITY
		match cfg[3]:
			"cone":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			"hinge":
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_HINGE
				joint_basis = _hinge_basis(skel, bone_name, rest)
			_:
				pb.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
		pb.joint_offset = Transform3D(joint_basis, Vector3(0.0, -length * 0.5, 0.0))
		_sim.add_child(pb)
		if cfg[3] == "cone":
			pb.set("joint_constraints/swing_span", cfg[4])
			pb.set("joint_constraints/twist_span", 30.0)
		elif cfg[3] == "hinge":
			pb.set("joint_constraints/angular_limit_enabled", true)
			pb.set("joint_constraints/angular_limit_upper", 140.0)
			pb.set("joint_constraints/angular_limit_lower", 0.0)
		_bones.append(pb)
	var sp := skel.find_bone("spine_02")
	if sp >= 0:
		# Figur schaut im Skelettraum nach +Z
		_chest_local = (skel.get_bone_global_rest(sp).basis.inverse() * Vector3(0, 0, 1)).normalized()
	# Wasserfläche, nur für die Ragdoll
	_water = StaticBody3D.new()
	_water.top_level = true
	_water.collision_layer = LAYER_WATER
	_water.collision_mask = 0
	var plane := CollisionShape3D.new()
	plane.shape = WorldBoundaryShape3D.new()
	_water.add_child(plane)
	_water.process_mode = Node.PROCESS_MODE_DISABLED
	owner_node.add_child(_water)


## Scharnierachse (Joint-Z) = Beugeachse des Gelenks aus der Ruhepose, im Knochenraum.
## Die Ruhepose ist leicht gebeugt; Beugen = Drehung in diese Richtung (positiver Winkel).
static func _hinge_basis(skel: Skeleton3D, bone_name: String, rest: Transform3D) -> Basis:
	var parent_rest := skel.get_bone_global_rest(skel.find_bone(HINGE_PARENT[bone_name]))
	var up_dir := (rest.origin - parent_rest.origin).normalized()
	var lo_dir := rest.basis.y.normalized()
	var axis := up_dir.cross(lo_dir)
	if axis.length() < 0.01:
		axis = rest.basis.x
	var z_local := (rest.basis.inverse() * axis).normalized()
	var x_local := Vector3.UP.cross(z_local)
	if x_local.length() < 0.01:
		x_local = Vector3.RIGHT
	x_local = x_local.normalized()
	return Basis(x_local, z_local.cross(x_local), z_local)


## Startet die Simulation aus der aktuellen Pose, alle Teile mit Geschwindigkeit vel.
func start(vel: Vector3, water_y: float, at: Vector3) -> void:
	if active:
		return
	active = true
	_water.global_position = Vector3(at.x, water_y - 0.12, at.z)
	_water.process_mode = Node.PROCESS_MODE_INHERIT
	_sim.physical_bones_start_simulation()
	for pb in _bones:
		pb.linear_velocity = vel
		pb.angular_velocity = Vector3.ZERO
	var cl := _bone("calf_l")
	var cr := _bone("calf_r")
	if cl and cr:
		# Alle Achsen gesperrt (Standard) = starre Verbindung in der aktuellen Lage
		_binding = Generic6DOFJoint3D.new()
		_owner.add_child(_binding)
		_binding.global_position = (cl.global_position + cr.global_position) * 0.5
		_binding.node_a = _binding.get_path_to(cl)
		_binding.node_b = _binding.get_path_to(cr)


## Pro Physikschritt: Die Weste trägt vorne – ein Drehmoment rollt den Oberkörper
## auf den Rücken (Gesicht nach oben), wie bei einem echten Sturz mit Impact-Weste.
func step(delta: float) -> void:
	if not active:
		return
	var sp := _bone("spine_02")
	if sp == null:
		return
	var chest := (sp.global_basis * _chest_local).normalized()
	var face_down := 1.0 - chest.dot(Vector3.UP)          # 0 = Rücken, 2 = Bauch
	if face_down < 0.05:
		return
	var axis := chest.cross(Vector3.UP)
	if axis.length() < 0.15:
		# genau in Bauchlage: über die Körperlängsachse seitlich wegrollen
		axis = sp.global_basis.y.normalized()
	axis = axis.normalized()
	# Kräftepaar statt Drehmoment (PhysicalBone3D hat nur Impulse): oben/unten an der Brust
	var torque := VEST_TORQUE * minf(face_down, 1.0)
	# Hebel u senkrecht zur Achse, Kraft axis × u  ->  u × (axis × u) = axis
	var u := Vector3.UP - axis * Vector3.UP.dot(axis)
	u = u.normalized() if u.length() > 0.1 else sp.global_basis.z.normalized()
	var push := axis.cross(u).normalized()
	sp.apply_impulse(push * torque / 0.3 * delta, u * 0.15)
	sp.apply_impulse(-push * torque / 0.3 * delta, -u * 0.15)


## Wasserebene folgt der Welle an der aktuellen Stelle.
func follow_water(water_y: float, at: Vector3) -> void:
	if active:
		_water.global_position = Vector3(at.x, water_y - 0.12, at.z)


func stop() -> void:
	if not active:
		return
	active = false
	if _binding:
		_binding.queue_free()
		_binding = null
	_sim.physical_bones_stop_simulation()
	_water.process_mode = Node.PROCESS_MODE_DISABLED


## Wo der Körper gerade ist (für Kamera/Fahrerposition).
func center() -> Vector3:
	var pb := _bone("pelvis")
	return pb.global_position if pb else _skel.global_position


## Welt-Transformation eines nicht simulierten Kindknochens (z. B. Fuß an der Wade):
## simulierter Elternknochen + die Haltung zum Zeitpunkt des Sturzes.
func child_world(parent_bone: String, child_bone: String) -> Transform3D:
	var pb := _bone(parent_bone)
	var parent_w := pb.global_transform * pb.body_offset.affine_inverse()
	var rel := _skel.get_bone_global_pose(_skel.find_bone(parent_bone)).affine_inverse() 		* _skel.get_bone_global_pose(_skel.find_bone(child_bone))
	return parent_w * rel


func _bone(bone_name: String) -> PhysicalBone3D:
	for pb in _bones:
		if pb.bone_name == bone_name:
			return pb
	return null
