class_name Ragdoll
extends RefCounted
## Ragdoll für die MakeHuman-Figuren beim Sturz.
## Kapseln (PhysicalBone3D) an den Hauptknochen, Ellbogen und Knie als Scharnier, der Rest
## als Kugelgelenk mit Grenzen. Das Wasser ist **keine Fläche** (früher eine harte Ebene: sah aus
## wie ein Sturz auf eine Steinplatte), sondern wirkt je Knochen nach Eintauchtiefe: Auftrieb
## (die Weste trägt den Oberkörper) und starker Wasserwiderstand – der Körper klatscht hinein,
## taucht kurz unter und kommt wieder hoch, ohne abzuprallen. Beim Eintauchen meldet `splashed`
## den Platscher (Gischt, Welle, Ton), `hit_feature` einen harten Treffer an einem Feature.
## Die Knochen kollidieren mit den Features (abprallen, darauf liegen bleiben),
## nicht untereinander (stabil, keine Explosionen).

signal splashed(at: Vector3, strength: float, vh: Vector3)   # Körperteil klatscht ins Wasser (Stärke 0..1)
signal hit_feature(at: Vector3, strength: float)            # Körper prallt hart an ein Feature (0..1)

const LAYER_BONES := 1 << 9

# Wasser (je Knochen, mal eingetauchter Anteil 0..1)
const BUOY_TORSO := 3.2      # Auftrieb Becken/Oberkörper in Vielfachen des Gewichts (Prallweste: zieht schnell wieder hoch)
const BUOY_LIMB := 1.0       # Arme, Beine, Kopf: schweben
const WATER_DRAG := 2.0      # 1/s: linearer Wasserwiderstand
const WATER_DRAG_Q := 2.2    # 1/m: quadratischer Anteil – schnelle Körper bremsen beim Eintauchen hart
const WATER_SPIN := 5.0      # 1/s: Drehung bremst im Wasser
const SPLASH_MIN := 1.0      # m/s: ab diesem Aufprall spritzt es
const HIT_DV := 4.0          # m/s Geschwindigkeitssprung in einem Schritt (außerhalb des Wassers) = Treffer am Feature

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
var water: Water                # Wasserhöhe je Knochen
var _sim: PhysicalBoneSimulator3D
var _bones: Array[PhysicalBone3D] = []
var _half := PackedFloat32Array()     # je Knochen: halbe Länge der Kapsel ohne Kappen
var _radius := PackedFloat32Array()
var _buoy := PackedFloat32Array()
var _wet := PackedByteArray()          # Knochen ist im Wasser (zum Erkennen des Eintauchens)
var _prev_v := PackedVector3Array()    # Geschwindigkeit nach dem letzten Schritt (Treffer am Feature)
var _splash_cool := 0.0
var _splash_last := 0.0
var _hit_cool := 0.0
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
		pb.friction = 0.4
		pb.bounce = 0.3
		# Luft bremst kaum; das Wasser bremst in step() nach Eintauchtiefe
		pb.linear_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		pb.linear_damp = 0.02
		pb.angular_damp_mode = PhysicalBone3D.DAMP_MODE_REPLACE
		pb.angular_damp = 0.6
		pb.collision_layer = LAYER_BONES
		pb.collision_mask = FeaturePart.LAYER_COLLIDE   # Features (und Boot): abprallen statt durchfallen
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
		_half.append(maxf(shape.height * 0.5 - radius, 0.0))
		_radius.append(radius)
		_buoy.append(BUOY_TORSO if bone_name in ["pelvis", "spine_02"] else BUOY_LIMB)
	_wet.resize(_bones.size())
	_prev_v.resize(_bones.size())
	var sp := skel.find_bone("spine_02")
	if sp >= 0:
		# Figur schaut im Skelettraum nach +Z
		_chest_local = (skel.get_bone_global_rest(sp).basis.inverse() * Vector3(0, 0, 1)).normalized()


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
func start(vel: Vector3) -> void:
	if active:
		return
	active = true
	_sim.physical_bones_start_simulation()
	_splash_cool = 0.0
	_splash_last = 0.0
	_hit_cool = 0.0
	for k in _bones.size():
		var pb := _bones[k]
		pb.linear_velocity = vel
		pb.angular_velocity = Vector3.ZERO
		_prev_v[k] = vel
		_wet[k] = 1 if _submerged(k) > 0.35 else 0
	# Sturz direkt auf dem Wasser (Kante verschnitten …): der Oberkörper ist schon drin – gleich platschen
	var pelvis := _bone("pelvis")
	if pelvis and _wet[_bones.find(pelvis)]:
		var p := pelvis.global_position
		var s := maxf(-vel.y, 0.0) + 0.35 * Vector2(vel.x, vel.z).length()
		splashed.emit(Vector3(p.x, water.height_at(p.x, p.z), p.z), clampf((s - SPLASH_MIN) / 8.0, 0.15, 1.0), Vector3(vel.x, 0.0, vel.z))
		_splash_cool = 0.3
	var cl := _bone("calf_l")
	var cr := _bone("calf_r")
	if cl and cr:
		# Alle Achsen gesperrt (Standard) = starre Verbindung in der aktuellen Lage
		_binding = Generic6DOFJoint3D.new()
		_owner.add_child(_binding)
		_binding.global_position = (cl.global_position + cr.global_position) * 0.5
		_binding.node_a = _binding.get_path_to(cl)
		_binding.node_b = _binding.get_path_to(cr)


## Eingetauchter Anteil eines Knochens 0..1 (senkrechte Ausdehnung der Kapsel gegen die Wellenhöhe).
func _submerged(k: int) -> float:
	var pb := _bones[k]
	var p := pb.global_position
	var ext := absf(pb.global_basis.y.normalized().y) * _half[k] + _radius[k]
	return clampf((water.height_at(p.x, p.z) - (p.y - ext)) / (2.0 * ext), 0.0, 1.0)


## Pro Physikschritt: Wasser (Auftrieb, Widerstand, Platscher), Treffer an Features und die Weste.
func step(delta: float) -> void:
	if not active:
		return
	_splash_cool -= delta
	_hit_cool -= delta
	if _splash_cool <= 0.0:
		_splash_last = 0.0
	var g := Vector3(0.0, -float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)), 0.0)
	for k in _bones.size():
		var pb := _bones[k]
		var f := _submerged(k)
		var v := pb.linear_velocity
		var p := pb.global_position
		# Harter Treffer: die Geschwindigkeit springt, ohne dass Schwerkraft oder Wasser es erklären
		# (nur schwere Teile – an Armen/Beinen reißen auch die Gelenke)
		if f < 0.05 and pb.mass >= 9.0 and _hit_cool <= 0.0:
			var dv := (v - (_prev_v[k] + g * delta)).length()
			if dv > HIT_DV:
				hit_feature.emit(p, clampf((dv - HIT_DV) / 8.0 + 0.2, 0.0, 1.0))
				_hit_cool = 0.35
		# Eintauchen: Platscher je nach Aufprall (senkrecht zählt voll, waagrecht – Bauchklatscher im Rutschen – etwas)
		var wet := f > 0.35
		if wet and not _wet[k]:
			var s := maxf(-v.y, 0.0) + 0.35 * Vector2(v.x, v.z).length()
			var strength := clampf((s - SPLASH_MIN) / 8.0, 0.0, 1.0) * clampf(pb.mass / 12.0, 0.3, 1.0)
			if strength > 0.04 and (_splash_cool <= 0.0 or strength > _splash_last * 1.4):
				splashed.emit(Vector3(p.x, water.height_at(p.x, p.z), p.z), strength, Vector3(v.x, 0.0, v.z))
				_splash_cool = 0.15
				_splash_last = strength
		_wet[k] = 1 if wet else (0 if f < 0.1 else _wet[k])
		if f > 0.0:
			# Auftrieb gegen die Schwerkraft, Widerstand linear + quadratisch: schnell eintauchen bremst hart,
			# federt aber nicht zurück (kein Abprallen wie von einer Fläche)
			v += -g * _buoy[k] * f * delta
			v -= v * minf((WATER_DRAG + WATER_DRAG_Q * v.length()) * f * delta, 0.9)
			pb.linear_velocity = v
			pb.angular_velocity *= exp(-WATER_SPIN * f * delta)
		_prev_v[k] = v
	_vest(delta)


## Die Weste trägt vorne – ein Drehmoment rollt den Oberkörper im Wasser auf den Rücken
## (Gesicht nach oben), wie bei einem echten Sturz mit Impact-Weste.
func _vest(delta: float) -> void:
	var sp := _bone("spine_02")
	if sp == null:
		return
	var wet := _submerged(_bones.find(sp))
	var chest := (sp.global_basis * _chest_local).normalized()
	var face_down := 1.0 - chest.dot(Vector3.UP)          # 0 = Rücken, 2 = Bauch
	if face_down < 0.05 or wet <= 0.0:
		return
	var axis := chest.cross(Vector3.UP)
	if axis.length() < 0.15:
		# genau in Bauchlage: über die Körperlängsachse seitlich wegrollen
		axis = sp.global_basis.y.normalized()
	axis = axis.normalized()
	# Kräftepaar statt Drehmoment (PhysicalBone3D hat nur Impulse): oben/unten an der Brust
	var torque := VEST_TORQUE * minf(face_down, 1.0) * minf(wet * 2.0, 1.0)
	# Hebel u senkrecht zur Achse, Kraft axis × u  ->  u × (axis × u) = axis
	var u := Vector3.UP - axis * Vector3.UP.dot(axis)
	u = u.normalized() if u.length() > 0.1 else sp.global_basis.z.normalized()
	var push := axis.cross(u).normalized()
	sp.apply_impulse(push * torque / 0.3 * delta, u * 0.15)
	sp.apply_impulse(-push * torque / 0.3 * delta, -u * 0.15)


## Schwimmen: der treibende Körper bewegt sich (in Rückenlage) mit Geschwindigkeit v übers Wasser.
func swim(v: Vector3, delta: float) -> void:
	if not active:
		return
	var k := 1.0 - exp(-delta * 12.0)
	for pb in _bones:
		var lv := pb.linear_velocity
		var h := Vector3(lv.x, 0.0, lv.z).lerp(Vector3(v.x, 0.0, v.z), k)
		pb.linear_velocity = Vector3(h.x, lv.y, h.z)


func stop() -> void:
	if not active:
		return
	active = false
	if _binding:
		_binding.queue_free()
		_binding = null
	_sim.physical_bones_stop_simulation()


## Momentaufnahme der Haltung, wie die Ragdoll sie gerade zeigt (Format wie HumanRig.snapshot):
## simulierte Knochen aus den Kapseln, die übrigen mit ihrer Haltung zum Elternknochen.
## Zum weichen Übergang aus dem Sturz ins Schwimmen (das Skelett selbst kennt die Ragdoll-Lage nicht).
func pose_snapshot() -> Array:
	var skel_inv := _skel.global_transform.affine_inverse()
	var sim := {}
	for pb in _bones:
		var w := skel_inv * (pb.global_transform * pb.body_offset.affine_inverse())
		sim[_skel.find_bone(pb.bone_name)] = Transform3D(w.basis.orthonormalized(), w.origin)
	var n := _skel.get_bone_count()
	var glob: Array[Transform3D] = []
	glob.resize(n)
	var done := PackedByteArray()
	done.resize(n)
	var ps := PackedVector3Array()
	var rs: Array[Quaternion] = []
	ps.resize(n)
	rs.resize(n)
	for i in n:
		_snap_bone(i, sim, glob, done, ps, rs)
	return [ps, rs, _skel.global_transform]


func _snap_bone(i: int, sim: Dictionary, glob: Array[Transform3D], done: PackedByteArray,
		ps: PackedVector3Array, rs: Array[Quaternion]) -> void:
	if done[i]:
		return
	var parent := _skel.get_bone_parent(i)
	var parent_g := Transform3D.IDENTITY
	if parent >= 0:
		_snap_bone(parent, sim, glob, done, ps, rs)
		parent_g = glob[parent]
	var local := Transform3D(Basis(_skel.get_bone_pose_rotation(i)), _skel.get_bone_pose_position(i))
	if sim.has(i):
		local = parent_g.affine_inverse() * (sim[i] as Transform3D)
	glob[i] = parent_g * local
	ps[i] = local.origin
	rs[i] = local.basis.orthonormalized().get_rotation_quaternion()
	done[i] = 1


## Test: größter Abstand eines Knochens vom Becken (> ca. 1,2 m = Figur reißt auseinander) und tiefster Punkt.
func diag() -> Vector2:
	var c := center()
	var far := 0.0
	var low := INF
	for pb in _bones:
		far = maxf(far, pb.global_position.distance_to(c))
		low = minf(low, pb.global_position.y)
	return Vector2(far, low)


## Wo der Körper gerade ist (für Kamera/Fahrerposition).
func center() -> Vector3:
	var pb := _bone("pelvis")
	return pb.global_position if pb else _skel.global_position


## Geschwindigkeit des Körpers (Becken).
func velocity() -> Vector3:
	var pb := _bone("pelvis")
	return pb.linear_velocity if pb else Vector3.ZERO


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
