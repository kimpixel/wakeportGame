r"""Mocap (Rokoko-FBX) auf das Fahrer-Rig umrechnen und als Pose-Clip fürs Spiel schreiben (WakeTheHack).

Aufruf (Blender im Hintergrund, Vorlage mit unserem Rig als .blend):
  blender -b blender/nosepress.blend --python tools/retarget_mocap.py -- MOCAP.fbx assets/poses/NAME.json START ENDE \
      [goofy|regular] [POP] [ROLL]

START/ENDE = Bildnummern im FBX (= Bildnummern im Video, aus dem Rokoko die Aufnahme gemacht hat). POP = Bild, in
dem das Brett aus dem Wasser gerissen wird (Absprung im Spiel). ROLL (alt, nicht mehr benutzt) = Drehung um die
Brust-Achse je Bild, "BILD:GRAD,…" – zwang den Körper in eine gerade Rolle über Kopf. Ohne ROLL bleibt die Drehung
der Aufnahme: eine volle Drehung um eine schräge Achse (zwischen Brust und Senkrechter), erst zur Seite, dann über
Kopf; das Brett dreht je Bild mit dem ganzen Körper ("board", Quaternion im Modellraum gegenüber Bild START).

Ausgabe im Format von export_pose.py (je Bild Knochen-Drehung gegenüber der Ruhepose im Modellraum, Godot-Achsen),
dazu "stance" (so aufgenommen, das Spiel spiegelt), "pivot" (Schwerpunkt im Modellraum), je Bild "roll" (Drehung
des Bretts um die Brust-Achse durch den Schwerpunkt, rad) und "pop" (Index des Absprung-Bilds).

Umrechnung je Knochen: Drehung des Mocap-Knochens gegenüber seiner Ruhe (Weltraum) mal Ausgleich der
Ruhehaltung (Rokoko steht in T-Pose, unser Rig in A-Pose: Gelenk -> nächstes Gelenk unseres Rigs auf die
Richtung des Mocaps gedreht). Die ganze Aufnahme wird so gedreht, dass zu Beginn die Brust wie bei unserem Rig
schaut (Modell -Y in Blender). Aus einem Video geschätzte Aufnahmen verlieren die Tiefe: die Füße stehen dort
hintereinander statt nebeneinander, und die Drehung des ganzen Körpers fällt viel zu klein aus. Darum steht das
Brett im Spiel nicht an den Füßen, sondern folgt ROLL, und der ganze Körper wird um die Brust-Achse so weit
nachgedreht, dass er dieselbe Drehung macht (Arme, Beine, Haltung bleiben aus der Aufnahme).
"pelvis" = Lage des Beckens im Modellraum: der Schwerpunkt bleibt an der Stelle von Bild START über den Füßen
stehen (Höhe und Flugbahn macht das Spiel).
"""
import bpy, json, sys, math
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
fbx, out, f0, f1 = args[0], args[1], int(args[2]), int(args[3])
stance = args[4] if len(args) > 4 else "goofy"
pop = int(args[5]) if len(args) > 5 else f0
roll_keys = [(int(k), float(v)) for k, v in (p.split(":") for p in args[6].split(","))] if len(args) > 6 else []

MAP = {   # unser Knochen -> Rokoko-Knochen
    "pelvis": "Hips", "spine_01": "Spine2", "spine_02": "Spine3", "spine_03": "Spine4",
    "neck_01": "Neck", "head": "Head",
    "clavicle_l": "LeftShoulder", "upperarm_l": "LeftArm", "lowerarm_l": "LeftForeArm", "hand_l": "LeftHand",
    "clavicle_r": "RightShoulder", "upperarm_r": "RightArm", "lowerarm_r": "RightForeArm", "hand_r": "RightHand",
    "thigh_l": "LeftThigh", "calf_l": "LeftShin", "foot_l": "LeftFoot", "ball_l": "LeftToe",
    "thigh_r": "RightThigh", "calf_r": "RightShin", "foot_r": "RightFoot", "ball_r": "RightToe",
}
C = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))     # Blender (Z oben) -> Godot (Y oben)

ours = next(o for o in bpy.data.objects if o.type == "ARMATURE")
before = set(bpy.data.objects)
bpy.ops.import_scene.fbx(filepath=fbx)
mocap = next(o for o in bpy.data.objects if o.type == "ARMATURE" and o not in before)
sc = bpy.context.scene


def rest_rot(arm, name):
    return (arm.matrix_world @ arm.data.bones[name].matrix_local).to_3x3().normalized()


CHILD = {   # Knochenrichtung = Gelenk -> nächstes Gelenk (die FBX-Knochenspitzen zeigen nicht dorthin)
    "pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "head",
    "clavicle_l": "upperarm_l", "upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l", "hand_l": "middle_01_l",
    "clavicle_r": "upperarm_r", "upperarm_r": "lowerarm_r", "lowerarm_r": "hand_r", "hand_r": "middle_01_r",
    "thigh_l": "calf_l", "calf_l": "foot_l", "foot_l": "ball_l",
    "thigh_r": "calf_r", "calf_r": "foot_r", "foot_r": "ball_r",
    "Hips": "Spine1", "Spine2": "Spine3", "Spine3": "Spine4", "Spine4": "Neck", "Neck": "Head",
    "LeftShoulder": "LeftArm", "LeftArm": "LeftForeArm", "LeftForeArm": "LeftHand", "LeftHand": "LeftFinger3Proximal",
    "RightShoulder": "RightArm", "RightArm": "RightForeArm", "RightForeArm": "RightHand", "RightHand": "RightFinger3Proximal",
    "LeftThigh": "LeftShin", "LeftShin": "LeftFoot", "LeftFoot": "LeftToe",
    "RightThigh": "RightShin", "RightShin": "RightFoot", "RightFoot": "RightToe",
}


def rest_dir(arm, name):
    if name not in CHILD:
        return None                      # Kopf, Zehen: Ruhehaltung gleich (nach oben bzw. vorne)
    a = arm.matrix_world @ arm.data.bones[name].head_local
    b = arm.matrix_world @ arm.data.bones[CHILD[name]].head_local
    return (b - a).normalized()


def rest_fix(o, r):
    do, dr = rest_dir(ours, o), rest_dir(mocap, r)
    return Matrix.Identity(3) if do is None or dr is None else do.rotation_difference(dr).to_matrix()


def pos(name):
    return mocap.matrix_world @ mocap.pose.bones[name].head


def delta(name):
    pb = mocap.pose.bones[name]
    return (mocap.matrix_world @ pb.matrix).to_3x3().normalized() @ rest_rot(mocap, name).inverted()


def body_basis():
    # Lage des ganzen Körpers: Achse Becken -> Hals, quer die Hüfte (die Füße der Aufnahme sind zu ungenau)
    up = (pos("Neck") - pos("Hips")).normalized()
    fwd = (pos("LeftThigh") - pos("RightThigh")).cross(up).normalized()
    return Matrix((up.cross(fwd), fwd, up)).transposed()


def center():
    # Körperschwerpunkt grob: Becken, Brust, Knie
    return (pos("Hips") + pos("Spine4") + pos("LeftShin") + pos("RightShin")) * 0.25


def roll_at(f):
    # Catmull-Rom durch die Stützpunkte (Grad), außerhalb gehalten
    ks = roll_keys
    if f <= ks[0][0]:
        return ks[0][1]
    if f >= ks[-1][0]:
        return ks[-1][1]
    i = max(j for j in range(len(ks) - 1) if ks[j][0] <= f)
    (xa, a), (xb, b) = ks[i], ks[i + 1]
    pa = ks[i - 1] if i > 0 else (xa - (xb - xa), a - (b - a))
    pb_ = ks[i + 2] if i + 2 < len(ks) else (xb + (xb - xa), b + (b - a))
    t = (f - xa) / (xb - xa)
    ma = (b - pa[1]) / (xb - pa[0]) * (xb - xa)
    mb = (pb_[1] - a) / (pb_[0] - xa) * (xb - xa)
    t2, t3 = t * t, t * t * t
    return (2 * t3 - 3 * t2 + 1) * a + (t3 - 2 * t2 + t) * ma + (-2 * t3 + 3 * t2) * b + (t3 - t2) * mb


fix = {o: rest_fix(o, r) for o, r in MAP.items()}
side = 1.0 if stance == "goofy" else -1.0    # Kopf kippt zum hinteren Fuß: goofy linker Fuß hinten = Modell +X

# Ausrichtung zu Beginn: Brust schaut nach Modell -Y (wie unser Rig in der Ruhe)
sc.frame_set(f0)
fwd = delta("Spine4") @ Vector((0.0, -1.0, 0.0))
fwd.z = 0.0
Y = fwd.normalized().rotation_difference(Vector((0.0, -1.0, 0.0))).to_matrix()
feet0 = (pos("LeftFoot") + pos("RightFoot")) * 0.5
feet0.z = min(pos("LeftFoot").z, pos("RightFoot").z) - 0.08     # Fußknöchel ca. 8 cm über der Sohle
c0 = Vector((0.0, 0.0, (center() - feet0).z))                     # Schwerpunkt über der Brettmitte
B0 = body_basis()

frames = []
prev = None
for f in range(f0, f1 + 1):
    sc.frame_set(f)
    bpy.context.view_layer.update()
    ax = Y @ (pos("Head") - pos("Hips"))
    ang = math.atan2(side * ax.x, ax.z)
    if prev is not None:                       # stetig über ±180°
        ang = prev + (ang - prev + math.pi) % (2 * math.pi) - math.pi
    prev = ang
    roll = math.radians(roll_at(f)) if roll_keys else ang
    R = Matrix.Rotation(side * (roll - ang), 3, "Y") if roll_keys else Matrix.Identity(3)   # Körper nachdrehen
    bones = {}
    for o, r in MAP.items():
        g = C @ (R @ Y @ delta(r) @ fix[o]) @ C.transposed()
        q = g.to_quaternion()
        bones[o] = [q.x, q.y, q.z, q.w]
    p = c0 + R @ Y @ (pos("Hips") - center())
    # Brett dreht mit dem ganzen Körper (gegenüber Bild START, Modellraum Godot)
    q = (C @ (R @ Y @ body_basis() @ B0.inverted() @ Y.transposed()) @ C.transposed()).to_quaternion()
    frames.append({"bones": bones, "pelvis": [p.x, p.z, -p.y], "roll": side * roll, "board": [q.x, q.y, q.z, q.w]})
with open(out, "w") as fh:
    json.dump({"fps": sc.render.fps / sc.render.fps_base, "stance": stance, "pivot": [c0.x, c0.z, -c0.y],
               "pop": pop - f0, "frames": frames}, fh)
print("FBX RETARGET", out, len(frames), "Bilder, Absprung bei Index", pop - f0, ", Schwerpunkt %.2f m über den Füßen" % c0.z)
