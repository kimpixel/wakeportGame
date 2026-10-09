# IK-Steuerung für das Fahrer-Rig (Hände und Füße), damit man Posen in Blender
# bequem verschieben kann. glTF speichert keine IK-Constraints – nach dem Import
# fehlen sie, dieses Skript legt sie an, ohne dass sich die Pose verändert.
#
# Benutzung in Blender:
#   1. Vorlage importieren (Datei > Importieren > glTF 2.0)
#   2. Reiter "Scripting" oben, dieses Skript öffnen (Text > Öffnen), "Run Script" (▶)
#   3. Zurück in "Layout": Armature ist im Pose-Modus. Die Steuerknochen
#      IK_hand_*, IK_foot_* (Hände/Füße) und POLE_* (Ellbogen/Knie) mit G
#      verschieben, R drehen – Arme und Beine folgen.
#
# Headless:
#   blender -b --python tools/character/ik_rig.py -- EINGABE.glb AUSGABE.blend

import math
import sys
import bpy
from mathutils import Vector

# (Unterarm/Unterschenkel, Hand/Fuß, Ziel-Knochen, Pole-Knochen)
CHAINS = [
	("lowerarm_l", "hand_l", "IK_hand_l", "POLE_elbow_l"),
	("lowerarm_r", "hand_r", "IK_hand_r", "POLE_elbow_r"),
	("calf_l", "foot_l", "IK_foot_l", "POLE_knee_l"),
	("calf_r", "foot_r", "IK_foot_r", "POLE_knee_r"),
]
POLE_DIST = 0.5  # Meter vor Ellbogen/Knie


def fit_pole_angle(ik, pb, knee):
	# Pole-Winkel suchen, bei dem Ellbogen/Knie dort bleibt, wo es vorher war
	# (hängt von der Knochen-Rolle ab, darum numerisch statt per Formel)
	def err(a):
		ik.pole_angle = a
		bpy.context.view_layer.update()
		return (pb.parent.tail - knee).length
	best = min((math.radians(d) for d in range(-180, 180, 5)), key=err)
	step = math.radians(2.5)
	while step > 1e-5:
		best = min((best - step, best, best + step), key=err)
		step *= 0.5
	err(best)


def find_armature():
	ob = bpy.context.view_layer.objects.active
	if ob and ob.type == 'ARMATURE':
		return ob
	for ob in bpy.context.scene.objects:
		if ob.type == 'ARMATURE':
			return ob
	raise RuntimeError("Keine Armature in der Szene – erst die .glb importieren.")


def build(arm):
	for ob in bpy.context.selected_objects:
		ob.select_set(False)
	arm.select_set(True)
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode='POSE')
	pbs = arm.pose.bones
	if "IK_hand_l" in pbs:
		print("IK ist schon eingerichtet.")
		return
	bpy.context.view_layer.update()

	# aktuelle (gepostete) Lagen merken, Armature-Raum
	plan = []
	for mid, end, tgt, pole in CHAINS:
		root = pbs[mid].parent.head
		knee = pbs[mid].head
		axis = (pbs[end].head - root).normalized()
		# Pole: von der Linie Schulter/Hüfte–Hand/Fuß weg in Richtung Ellbogen/Knie
		out = knee - (root + axis * (knee - root).dot(axis))
		if out.length < 1e-4:  # ganz gestreckt: nach vorn zeigen
			out = Vector((0, -1, 0))
		pole_loc = knee + out.normalized() * POLE_DIST
		plan.append((mid, end, tgt, pole, pbs[end].matrix.copy(), pole_loc, pbs[end].length))

	# Ellbogen/Knie (Ende des Oberarms/Oberschenkels) vorher, für den Pole-Winkel
	knees = {c[0]: pbs[c[0]].parent.tail.copy() for c in CHAINS}
	# Steuerknochen anlegen (ohne Eltern, damit sie frei verschiebbar sind)
	bpy.ops.object.mode_set(mode='EDIT')
	ebs = arm.data.edit_bones
	for mid, end, tgt, pole, m_end, pole_loc, length in plan:
		t = ebs.new(tgt)
		t.head = (0, 0, 0)
		t.tail = (0, max(length, 0.08), 0)
		t.matrix = m_end
		t.use_deform = False
		p = ebs.new(pole)
		p.head = pole_loc
		p.tail = pole_loc + Vector((0, 0, 0.1))
		p.use_deform = False
	bpy.ops.object.mode_set(mode='POSE')
	bpy.context.view_layer.update()

	col = arm.data.collections.get("IK") or arm.data.collections.new("IK")
	for mid, end, tgt, pole, m_end, pole_loc, length in plan:
		for n in (tgt, pole):
			col.assign(arm.data.bones[n])
			arm.data.bones[n].color.palette = 'THEME03'  # grün
		ik = pbs[mid].constraints.new('IK')
		ik.target = arm
		ik.subtarget = tgt
		ik.pole_target = arm
		ik.pole_subtarget = pole
		ik.chain_count = 2
		# Hand/Fuß dreht sich mit dem Ziel
		cr = pbs[end].constraints.new('COPY_ROTATION')
		cr.target = arm
		cr.subtarget = tgt
		fit_pole_angle(ik, pbs[mid], knees[mid])
	arm.show_in_front = True
	bpy.context.view_layer.update()
	print("IK eingerichtet:", ", ".join(c[2] for c in CHAINS))


def main():
	argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
	if argv:
		bpy.ops.wm.read_factory_settings(use_empty=True)
		bpy.ops.import_scene.gltf(filepath=argv[0])
	arm = find_armature()
	bpy.context.view_layer.update()
	before = {e: (arm.matrix_world @ arm.pose.bones[e].head).copy() for c in CHAINS for e in c[:2]}
	build(arm)
	for e, p in before.items():
		d = (arm.matrix_world @ arm.pose.bones[e].head - p).length
		print("Abweichung %s: %.4f m" % (e, d))
	if len(argv) > 1:
		bpy.ops.wm.save_as_mainfile(filepath=argv[1])


main()
