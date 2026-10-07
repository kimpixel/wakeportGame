# Erzeugt den Wakeboard-Bindungsschuh als .glb (Blender, per Skript, keine fremden Assets).
#
# Aufruf (aus dem Projektordner):
#   blender -b --factory-startup --python tools/board/build_boot.py -- assets/board/boot.glb
#
# Koordinaten (Blender): Z oben, +Y = Zehen, Ursprung = Unterkante Platte, genau unter dem Knöchel.
# Aufbau: Montageplatte, weiße Sohle mit orangem Streifen, Schaft als Loft aus Querschnitten
# (unten schwarz, oben oliv, Camo-Feld an der Seite), drei schwarze Riemen, schwarzer Kragen,
# orange Fersenschlaufe. Das Material "camo" bekommt im Spiel einen Shader.
import math
import sys

import bmesh
import bpy
from mathutils import Vector

PLATE = 0.008          # Montageplatte (schwarz) auf dem Brett
SOLE = 0.036           # Sohle
SOLE_TOP = PLATE + SOLE


def lin(c):
    """sRGB -> linear (Blender-Farben sind linear)."""
    return tuple(pow(v, 2.2) for v in c) + (1.0,)


def material(name, srgb, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = lin(srgb)
    bsdf.inputs["Roughness"].default_value = rough
    m.use_backface_culling = False
    return m


MAT = {}


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_obj(name, bm, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(MAT[m])
    return link(bpy.data.objects.new(name, me))


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def ring(z, back, front, half_w, n=40, power=3.2):
    """Abgerundetes Rechteck (Superellipse) als Querschnitt auf Höhe z."""
    mid = (front + back) * 0.5
    half_l = (front - back) * 0.5
    pts = []
    for i in range(n):
        t = 2.0 * math.pi * i / n
        c, s = math.cos(t), math.sin(t)
        x = half_w * math.copysign(abs(c) ** (2.0 / power), c)
        y = mid + half_l * math.copysign(abs(s) ** (2.0 / power), s)
        pts.append(Vector((x, y, z)))
    return pts


def footprint_box(name, z0, z1, grow, mat):
    """Sohlenschicht: Fußumriss von z0 bis z1, um grow vergrößert."""
    bm = bmesh.new()
    lo = [bm.verts.new(p) for p in ring(z0, -0.112 - grow, 0.238 + grow, 0.060 + grow)]
    hi = [bm.verts.new(p) for p in ring(z1, -0.112 - grow, 0.238 + grow, 0.060 + grow)]
    n = len(lo)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))
    bm.faces.new(list(reversed(lo)))
    bm.faces.new(hi)
    obj = mesh_obj(name, bm, [mat])
    bev = obj.modifiers.new("bevel", "BEVEL")
    bev.width = min(0.006, (z1 - z0) * 0.3)
    bev.segments = 2
    bev.limit_method = "ANGLE"
    apply_modifiers(obj)
    return obj


# Schaft-Querschnitte: (Höhe über Sohle, hinten, vorne, halbe Breite).
# Flache Zehenkappe, langer Spann, Schaft leicht nach vorne geneigt, oben etwas ausgestellt.
LEAN = 0.16            # Vorlage des Schafts (m nach vorne pro m Höhe)
_SECTIONS = [
    (-0.004, -0.104, 0.231, 0.057),
    (0.016, -0.104, 0.230, 0.057),
    (0.034, -0.102, 0.219, 0.056),
    (0.050, -0.100, 0.192, 0.055),
    (0.066, -0.098, 0.150, 0.053),
    (0.088, -0.096, 0.102, 0.051),
    (0.118, -0.094, 0.064, 0.050),
    (0.155, -0.092, 0.046, 0.050),
    (0.195, -0.091, 0.042, 0.052),
    (0.235, -0.092, 0.045, 0.055),
    (0.262, -0.094, 0.050, 0.057),
]
SECTIONS = [(SOLE_TOP + h, b + LEAN * max(h - 0.05, 0.0), f + LEAN * max(h - 0.05, 0.0), w) for h, b, f, w in _SECTIONS]
TOP_Z = SECTIONS[-1][0]


def heel_line_y(z):
    """Diagonale Grenze des schwarzen Fersenkeils (vorne davon farbig)."""
    return -0.035 + (LEAN - 0.42) * (z - SOLE_TOP - 0.03)


def bisect(bm, co, no, clear_inner=False, clear_outer=False):
    geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    bmesh.ops.bisect_plane(bm, geom=geom, plane_co=Vector(co), plane_no=Vector(no).normalized(),
                           clear_inner=clear_inner, clear_outer=clear_outer)


def build_upper():
    bm = bmesh.new()
    rings = [[bm.verts.new(p) for p in ring(*s)] for s in SECTIONS]
    n = len(rings[0])
    for a, b in zip(rings, rings[1:]):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(list(reversed(rings[0])))       # Boden (liegt auf der Sohle)
    obj = mesh_obj("upper", bm, ["black", "olive", "camo"])
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    apply_modifiers(obj)
    # Farbzonen: erst entlang der Grenzen schneiden (saubere Kanten), dann zuordnen
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bisect(bm, (0, 0, SOLE_TOP + 0.034), (0, 0, 1))
    bisect(bm, (0, 0, TOP_Z - 0.03), (0, 0, 1))
    bisect(bm, (0, heel_line_y(SOLE_TOP + 0.03), SOLE_TOP + 0.03), (0, 1, 0.42 - LEAN))
    bisect(bm, (0, 0, SOLE_TOP + 0.16), (0, 0, 1))
    bisect(bm, (0, -0.045, 0), (0, 1, 0))
    bisect(bm, (0, 0.105, 0), (0, 1, 0))
    for side in (-1, 1):
        bisect(bm, (side * 0.024, 0, 0), (1, 0, 0))
    for f in bm.faces:
        c = f.calc_center_median()
        h = c.z - SOLE_TOP
        idx = 1                                   # oliv
        if h < 0.034 or c.z > TOP_Z - 0.03:
            idx = 0                               # schwarzer Rand unten, Kragen oben
        elif c.y < heel_line_y(c.z):
            idx = 0                               # schwarzer Fersenkeil (diagonal)
        elif h < 0.16 and -0.045 < c.y < 0.105 and abs(c.x) > 0.024:
            idx = 2                               # Camo-Feld an den Seiten
        f.material_index = idx
    bm.to_mesh(obj.data)
    bm.free()
    return obj


def band_from_surface(src, name, point, normal, half, mat, offset, thick, front_only=-1.0):
    """Riemen/Kragen: Flächen des Schafts in einer Scheibe (Ebene ± half) kopieren,
    nach außen versetzen und aufdicken – liegt so genau auf der Schuhform."""
    normal = Vector(normal).normalized()
    point = Vector(point)
    bm = bmesh.new()
    bm.from_mesh(src.data)
    # sauber zuschneiden: Scheibe zwischen zwei parallelen Ebenen, nur vorne/seitlich
    bisect(bm, point + normal * half, normal, clear_outer=True)
    bisect(bm, point - normal * half, normal, clear_inner=True)
    bisect(bm, (0, front_only, 0), (0, 1, 0), clear_inner=True)
    # Riemen enden seitlich über dem schwarzen Rand (dort sind sie verankert)
    bisect(bm, (0, 0, SOLE_TOP + 0.045), (0, 0, 1), clear_inner=True)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset
    for f in bm.faces:
        f.material_index = 0
    obj = mesh_obj(name, bm, [mat])
    sol = obj.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = thick
    sol.offset = 1.0
    apply_modifiers(obj)
    return obj


def heel_loop():
    """Orange Zuglasche hinten am Kragen."""
    bm = bmesh.new()
    w, t = 0.016, 0.003
    path = [(-0.094, TOP_Z - 0.07), (-0.099, TOP_Z - 0.01), (-0.104, TOP_Z + 0.035),
            (-0.096, TOP_Z + 0.05), (-0.088, TOP_Z + 0.03)]
    prev = None
    for y, z in path:
        quad = [bm.verts.new((sx * w, y + sy * t, z)) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
        if prev:
            for i in range(4):
                j = (i + 1) % 4
                bm.faces.new((prev[i], prev[j], quad[j], quad[i]))
        prev = quad
    return mesh_obj("heel_loop", bm, ["orange"])


def plate():
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * 0.07, v.co.y * 0.26 + 0.06, (v.co.z + 0.5) * PLATE))
    return mesh_obj("plate", bm, ["plate"])


def build(out_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    MAT["white"] = material("white", (0.92, 0.91, 0.88), 0.7)
    MAT["orange"] = material("orange", (1.0, 0.36, 0.08), 0.55)
    MAT["black"] = material("black", (0.07, 0.07, 0.075), 0.75)
    MAT["olive"] = material("olive", (0.36, 0.38, 0.25), 0.7)
    MAT["camo"] = material("camo", (0.45, 0.45, 0.32), 0.7)
    MAT["strap"] = material("strap", (0.05, 0.05, 0.055), 0.6)
    MAT["plate"] = material("plate", (0.1, 0.1, 0.1), 0.5)

    plate()
    footprint_box("sole_low", PLATE, PLATE + 0.020, 0.0, "white")
    footprint_box("sole_stripe", PLATE + 0.020, PLATE + 0.025, 0.0015, "orange")
    footprint_box("sole_top", PLATE + 0.025, SOLE_TOP, 0.0, "white")
    upper = build_upper()
    # Riemen: Knöchel (waagerecht), Spann (diagonal), Zehen (flach geneigt) – nur vorne/seitlich
    band_from_surface(upper, "strap_ankle", (0, 0, SOLE_TOP + 0.205), (0, 0.18, 1), 0.018, "strap", 0.002, 0.005, -0.06)
    band_from_surface(upper, "strap_instep", (0, 0.06, SOLE_TOP + 0.11), (0, 0.72, 0.69), 0.019, "strap", 0.002, 0.005, -0.05)
    band_from_surface(upper, "strap_toe", (0, 0.135, SOLE_TOP + 0.06), (0, 0.85, 0.52), 0.016, "strap", 0.002, 0.005, 0.0)
    band_from_surface(upper, "collar", (0, 0, TOP_Z - 0.012), (0, 0, 1), 0.012, "black", 0.003, 0.006)
    heel_loop()

    # alles zu einem Objekt (ein Mesh, mehrere Materialien)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = upper
    bpy.ops.object.join()
    upper.name = "boot"
    bpy.ops.object.shade_smooth()
    tris = sum(len(p.vertices) - 2 for p in upper.data.polygons)
    print("BOOT tris:", tris)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_yup=True, export_apply=True)
    print("EXPORTED", out_path)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    build(argv[0])
