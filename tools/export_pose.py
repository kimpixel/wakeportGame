r"""Pose aus Blender fürs Spiel exportieren (WakeTheHack).

Bequem alle Posen auf einmal (PowerShell im Projektordner):  .\tools\export_poses.ps1

Einzeln (Blender im Hintergrund):
  blender -b blender/nosepress.blend --python tools/export_pose.py -- assets/poses/NAME.json

Schreibt für jedes Bild (Animation des Skeletts, sonst nur das aktuelle Bild) je Knochen die
Drehung gegenüber der Ruhepose (Weltraum, in Godot-Achsen: x, z, -y) und die Lage des Beckens
im Raum des Bretts ("Brett"). IK-Hilfsknochen (IK_*) werden ausgelassen; die Pose wird so
ausgewertet, wie Blender sie anzeigt (inkl. IK).
"""
import bpy, json, sys
from mathutils import Matrix

out = sys.argv[sys.argv.index("--") + 1]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
board = bpy.data.objects.get("Brett")
sc = bpy.context.scene
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))     # Blender (Z oben) -> Godot (Y oben)

def to_godot_rot(m3):
    return C @ m3 @ C.transposed()

def quat(m3):
    q = m3.to_quaternion()
    return [q.x, q.y, q.z, q.w]

ad = arm.animation_data
if ad and ad.action:
    f0, f1 = (int(v) for v in ad.action.frame_range)
else:
    f0 = f1 = sc.frame_current
frames = []
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    bpy.context.view_layer.update()
    bones = {}
    for pb in arm.pose.bones:
        if pb.name.startswith("IK_"):
            continue
        rest = (arm.matrix_world @ pb.bone.matrix_local).to_3x3().normalized()
        posed = (arm.matrix_world @ pb.matrix).to_3x3().normalized()
        bones[pb.name] = quat(to_godot_rot(posed @ rest.inverted()))
    pel = arm.matrix_world @ arm.pose.bones["pelvis"].head
    if board:
        local = board.matrix_world.inverted() @ pel
        pelvis = [local.x, local.z, -local.y]
    else:
        pelvis = [pel.x, pel.z, -pel.y]
    frames.append({"bones": bones, "pelvis": pelvis})
with open(out, "w") as fh:
    json.dump({"fps": sc.render.fps, "frames": frames}, fh)
print("POSE EXPORT", out, len(frames), "Bilder,", len(frames[0]["bones"]), "Knochen")
