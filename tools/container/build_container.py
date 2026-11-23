# Erzeugt den Wohncontainer (umgebauter Container zum Übernachten am See) als .glb.
# Blender per Skript, keine fremden Assets. Vorlage: Fotos vom Gelände (weiße Seitenwände, schwarze
# Fensterrahmen und Blenden, große Glasfront zum See, flaches dunkles Dach mit heller Attika,
# innen Birkensperrholz, dunkler Boden, Bett mit gepolstertem Kopfteil, dunkle Vorhänge).
#
# Aufruf (aus dem Projektordner):
#   blender -b --factory-startup --python tools/container/build_container.py -- assets/buildings/wohncontainer.glb [vorschau.png]
#
# Koordinaten (Blender): Z oben, X = Breite, Y = Länge. Ursprung = Mitte der Grundfläche auf dem Boden.
# Seiten (so benennt sie der Nutzer, von vorne gesehen): Vorne = Längsseite −X (große Glasflächen, Schiebetür),
# Hinten = Längsseite +X, Links = Stirnseite +Y, Rechts = Stirnseite −Y.
# Im Spiel (glTF, Y oben): Vorne zeigt nach −X, Links nach −Z.
# Alles wird zu EINEM Objekt verbunden, je Material eine Fläche (wenige Draw Calls).
import math
import sys

import bmesh
import bpy
from mathutils import Vector

L = 12.0          # Länge (Y)
W = 3.0           # Breite (X)
BASE = 0.25       # Sockel (weiß, etwas eingerückt)
H = 2.75          # Wandhöhe über dem Sockel
T = 0.10          # Wanddicke gesamt
T_OUT = 0.07      # davon Außenhaut, Rest Sperrholz innen
TOP = BASE + H    # Oberkante Wände
FRAME = 0.06      # Rahmenprofil (Alu schwarz)


def lin(c):
    """sRGB -> linear (Blender-Farben sind linear)."""
    return tuple(pow(v, 2.2) for v in c)


MAT = {}
NUMBER_POS = []
BM = {}


def material(name, srgb, rough=0.6, metal=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = lin(srgb) + (1.0,)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    m.use_backface_culling = False
    MAT[name] = m
    BM[name] = bmesh.new()
    return m


def box(mat, corners):
    """Quader aus 8 Ecken (Reihenfolge: u0v0d0, u1v0d0, u1v1d0, u0v1d0, dann dasselbe mit d1)."""
    bm = BM[mat]
    v = [bm.verts.new(c) for c in corners]
    for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([v[i] for i in f])


def aabb(mat, x0, y0, z0, x1, y1, z1):
    box(mat, [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
              (x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)])


def cyl(mat, center, radius, depth, axis, segs=16):
    """Zylinder (z. B. Lüfter), axis = 'x'/'y'/'z'."""
    bm = BM[mat]
    ring0, ring1 = [], []
    for i in range(segs):
        a = math.tau * i / segs
        c, s = math.cos(a) * radius, math.sin(a) * radius
        for ring, off in ((ring0, -depth / 2), (ring1, depth / 2)):
            p = {"x": (off, c, s), "y": (c, off, s), "z": (c, s, off)}[axis]
            ring.append(bm.verts.new(Vector(center) + Vector(p)))
    bm.faces.new(ring0)
    bm.faces.new(list(reversed(ring1)))
    for i in range(segs):
        j = (i + 1) % segs
        bm.faces.new([ring0[i], ring0[j], ring1[j], ring1[i]])


class Wall:
    """Wand in eigenen Koordinaten: u entlang der Wand, v Höhe ab Sockel, d Tiefe von der Außenseite nach innen."""

    def __init__(self, origin, along, normal):
        self.o = Vector(origin)
        self.a = Vector(along)
        self.n = Vector(normal)

    def p(self, u, v, d):
        return self.o + self.a * u + Vector((0, 0, BASE + v)) - self.n * d

    def box(self, mat, u0, v0, d0, u1, v1, d1):
        box(mat, [self.p(u0, v0, d0), self.p(u1, v0, d0), self.p(u1, v1, d0), self.p(u0, v1, d0),
                  self.p(u0, v0, d1), self.p(u1, v0, d1), self.p(u1, v1, d1), self.p(u0, v1, d1)])

    def solid(self, u0, u1, v0, v1, mat):
        self.box(mat, u0, v0, 0.0, u1, v1, T_OUT)
        self.box("sperrholz", u0, v0, T_OUT, u1, v1, T)

    def build(self, segments):
        u = 0.0
        for seg in segments:
            kind, w = seg[0], seg[1]
            u0, u1 = u, u + w
            if kind == "wand":
                self.solid(u0, u1, 0.0, H, seg[2])
            elif kind == "fenster":
                sill, head, panes, top_mat, low_mat = seg[2], seg[3], seg[4], seg[5], seg[6]
                if sill > 0.0:
                    self.solid(u0, u1, 0.0, sill, low_mat)
                if head < H:
                    self.solid(u0, u1, head, H, top_mat)
                self._window(u0, u1, sill, head, panes, seg[7] if len(seg) > 7 else None)
            elif kind == "tuer":
                head, mat = seg[2], seg[3]
                self.solid(u0, u1, head, H, mat)
                self._door(u0, u1, head, mat)
            u = u1
        return u

    def _window(self, u0, u1, v0, v1, panes, blind=None):
        f, d0, d1 = FRAME, 0.0, T
        # Rahmen: Leibung ganz durch die Wand, schwarz
        self.box("rahmen", u0, v0, d0, u0 + f, v1, d1)
        self.box("rahmen", u1 - f, v0, d0, u1, v1, d1)
        self.box("rahmen", u0 + f, v0, d0, u1 - f, v0 + f * (1.5 if v0 > 0 else 1.0), d1)
        self.box("rahmen", u0 + f, v1 - f, d0, u1 - f, v1, d1)
        # panes: Anzahl gleich breiter Flügel oder Liste der Anteile (z. B. (0.75, 0.25))
        parts = [1.0 / panes] * panes if isinstance(panes, int) else list(panes)
        acc = 0.0
        for frac in parts[:-1]:
            acc += frac
            m = u0 + f + (u1 - u0 - 2 * f) * acc
            # Schiebetür: die beiden Flügel überlappen sich mit einem breiten Mittelstoß
            self.box("rahmen", m - f * 0.9, v0, 0.015, m + f * 0.9, v1, 0.075)
        # Glas in der Mitte der Leibung, leicht zurückgesetzt
        self.box("glas", u0 + f, v0 + f, 0.04, u1 - f, v1 - f, 0.05)
        if blind:
            # Rollo im Raum vor der Innenwand, etwas breiter als die Öffnung, ganz heruntergelassen;
            # oben der Kasten auf der Wand
            self.box(blind, u0 - 0.04, v0 + 0.02, T + 0.03, u1 + 0.04, v1 + 0.02, T + 0.04)
            self.box(blind, u0 - 0.06, v1, T + 0.005, u1 + 0.06, v1 + 0.12, T + 0.10)

    def _door(self, u0, u1, head, mat):
        f = 0.04
        self.box("rahmen", u0, 0.0, 0.0, u0 + f, head, T)
        self.box("rahmen", u1 - f, 0.0, 0.0, u1, head, T)
        self.box("rahmen", u0 + f, head - f, 0.0, u1 - f, head, T)
        self.box(mat, u0 + f, 0.0, 0.025, u1 - f, head - f, 0.065)
        # Drücker und Schloss (schwarz) auf der Seite zum Ende der Wand
        hu = u1 - f - 0.12
        self.box("rahmen", hu - 0.02, 1.0, -0.06, hu + 0.02, 1.2, 0.025)
        self.box("rahmen", hu - 0.16, 1.02, -0.07, hu + 0.02, 1.05, -0.04)


def curtain(x, y0, y1, side):
    """Dunkler Vorhang, zusammengeschoben neben einem Fenster (Falten als versetzte Streifen)."""
    n = max(6, int(abs(y1 - y0) / 0.075))
    w = (y1 - y0) / n
    for i in range(n):
        off = 0.035 if i % 2 else 0.0
        a, b = y0 + w * i, y0 + w * (i + 1)
        aabb("vorhang", x - side * (0.05 + off), min(a, b), BASE + 0.08,
             x - side * (0.13 + off), max(a, b), TOP - 0.06)


def build(out_path, preview=None):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material("weiss", (0.93, 0.93, 0.92), rough=0.45)
    material("schwarz", (0.06, 0.06, 0.065), rough=0.4)
    material("rahmen", (0.05, 0.05, 0.055), rough=0.35, metal=0.4)
    material("glas", (0.08, 0.10, 0.11), rough=0.04, alpha=0.35)
    material("dach", (0.16, 0.16, 0.17), rough=0.9)
    material("attika", (0.82, 0.83, 0.84), rough=0.35, metal=0.3)
    material("sperrholz", (0.86, 0.74, 0.56), rough=0.65)
    material("boden", (0.27, 0.26, 0.25), rough=0.6)
    material("polster", (0.22, 0.22, 0.23), rough=0.9)
    material("bettwaesche", (0.95, 0.95, 0.94), rough=0.85)
    material("vorhang", (0.17, 0.17, 0.18), rough=0.95)
    material("rollo_schwarz", (0.07, 0.07, 0.075), rough=0.9)
    material("rollo_grau", (0.45, 0.45, 0.46), rough=0.9)
    material("geraet", (0.80, 0.80, 0.78), rough=0.5)

    hx, hy = W / 2, L / 2
    # Sockel (leicht eingerückt) und Boden
    aabb("weiss", -hx + 0.04, -hy + 0.04, 0.0, hx - 0.04, hy - 0.04, BASE)
    aabb("boden", -hx + T, -hy + T, BASE, hx - T, hy - T, BASE + 0.05)
    # Decke (Sperrholz) mit schwarzer Schattenfuge, Dach mit dunkler Bahn und heller Attika
    aabb("sperrholz", -hx + T, -hy + T, TOP - 0.22, hx - T, hy - T, TOP - 0.20)
    for sx in (-1, 1):
        aabb("schwarz", sx * (hx - T), -hy + T, TOP - 0.25, sx * (hx - T - 0.03), hy - T, TOP - 0.20)
    aabb("dach", -hx + T, -hy + T, TOP - 0.08, hx - T, hy - T, TOP - 0.03)
    # Attika nur als Rand auf den Wänden (Abdeckblech), innen liegt die dunkle Dachbahn tiefer
    a0, a1 = TOP, TOP + 0.04
    aabb("attika", -hx - 0.01, -hy - 0.01, a0, hx + 0.01, -hy + T, a1)
    aabb("attika", -hx - 0.01, hy - T, a0, hx + 0.01, hy + 0.01, a1)
    aabb("attika", -hx - 0.01, -hy + T, a0, -hx + T, hy - T, a1)
    aabb("attika", hx - T, -hy + T, a0, hx + 0.01, hy - T, a1)

    # Vorne (Längsseite −X), von links (+Y) nach rechts: Glas 1/3 mit integrierter Schiebetür, weiß 1/3,
    # dann Glas / weiß / Glas und ein schmaler weißer Abschluss. Schwarze Blende über dem Glas.
    third = L / 3.0
    front = Wall((-hx, hy, 0), (0, -1, 0), (-1, 0, 0))
    front.build([
        ("fenster", third, 0.0, 2.20, (0.75, 0.25), "schwarz", "weiss"),   # Schiebetür 3/4 : 1/4
        ("wand", third, "weiss"),
        ("fenster", 1.40, 0.0, 2.20, 1, "schwarz", "weiss", "rollo_schwarz"),
        ("wand", 0.80, "weiss"),
        ("fenster", 1.40, 0.0, 2.20, 1, "schwarz", "weiss", "rollo_grau"),
        ("wand", third - 3.60, "weiss"),
    ])
    # Hinten (Längsseite +X): geschlossen, nur ein kleines Fenster (Bad)
    back = Wall((hx, -hy, 0), (0, 1, 0), (1, 0, 0))
    back.build([
        ("wand", 1.20, "weiss"),
        ("fenster", 0.60, 1.60, 2.20, 1, "weiss", "weiss"),
        ("wand", L - 1.80, "weiss"),
    ])
    # Stirnseiten zwischen den Längswänden
    inner = W - 2 * T
    # Links (+Y): 1/3 schwarz, 1/3 Glas, 1/3 schwarz
    left = Wall((-hx + T, hy, 0), (1, 0, 0), (0, 1, 0))
    left.build([
        ("wand", inner / 3, "schwarz"),
        ("fenster", inner / 3, 0.0, H, 1, "schwarz", "schwarz"),
        ("wand", inner / 3, "schwarz"),
    ])
    # Rechts (−Y): nur ein kleines Fenster oben links (von außen gesehen)
    right = Wall((hx - T, -hy, 0), (-1, 0, 0), (0, -1, 0))
    right.build([
        ("wand", inner - 0.90, "schwarz"),
        ("fenster", 0.60, 1.60, 2.20, 1, "schwarz", "schwarz"),
        ("wand", 0.30, "schwarz"),
    ])

    # Vorne rechts neben der Schiebetür: kleine quadratische Wandleuchte (schwarz), darüber die Hausnummer.
    # Die Nummer ist nicht im Modell: das Empty "Hausnummer" markiert ihre Mitte, das Spiel setzt sie
    # je Container ein (scripts/wohn_container.gd).
    ly = hy - third - 0.55
    aabb("rahmen", -hx - 0.12, ly - 0.06, BASE + 1.92, -hx, ly + 0.06, BASE + 2.04)
    aabb("weiss", -hx - 0.125, ly - 0.05, BASE + 1.915, -hx - 0.02, ly + 0.05, BASE + 1.92)   # Lichtaustritt unten
    # Nummer knapp über der Leuchte, mittig über ihr
    NUMBER_POS[:] = [-hx - 0.003, ly, BASE + 2.22]

    # Klimagerät (Außeneinheit) vor der rechten Stirnseite
    aabb("geraet", -0.45, -hy - 0.40, 0.05, 0.45, -hy - 0.08, 0.70)
    cyl("schwarz", (0.12, -hy - 0.41, 0.375), 0.22, 0.02, "y")
    aabb("schwarz", -0.40, -hy - 0.12, 0.10, 0.40, -hy - 0.06, 0.14)

    # Innen: Bett quer, Kopfteil (gepolstert, dunkel) an der hinteren Wand, Nachttisch, Sofa
    fy = BASE + 0.05
    bx0, bx1, by0, by1 = hx - T - 2.05, hx - T - 0.10, 2.9, 4.5
    aabb("sperrholz", bx0, by0, fy, bx1, by1, fy + 0.30)
    aabb("bettwaesche", bx0 - 0.01, by0 - 0.01, fy + 0.30, bx1, by1 + 0.01, fy + 0.52)
    aabb("polster", bx0 - 0.02, by0 - 0.02, fy + 0.44, bx0 + 0.55, by1 + 0.02, fy + 0.55)
    aabb("polster", hx - T - 0.10, by0 - 0.20, fy + 0.30, hx - T - 0.02, by1 + 0.20, fy + 1.25)
    for i, y in enumerate((by0 + 0.4, by1 - 0.4)):
        aabb("bettwaesche", bx1 - 0.45, y - 0.32, fy + 0.52, bx1 - 0.10, y + 0.32, fy + 0.70)
        aabb("polster", bx1 - 0.60, y - 0.25, fy + 0.52, bx1 - 0.42, y + 0.25, fy + 0.72)
    aabb("sperrholz", hx - T - 0.45, by1 + 0.30, fy, hx - T - 0.02, by1 + 0.75, fy + 0.55)
    # Sofa an der hinteren Wand
    sy0, sy1 = -2.6, -0.8
    aabb("polster", hx - T - 0.80, sy0, fy, hx - T - 0.02, sy1, fy + 0.42)
    aabb("polster", hx - T - 0.25, sy0, fy + 0.42, hx - T - 0.02, sy1, fy + 0.85)
    # Vorhänge innen neben der großen Schiebetür
    curtain(-hx + T, hy - T - 0.05, hy - T - 1.60, -1)        # weit vor die Glasfläche gezogen
    curtain(-hx + T, hy - third - 0.05, hy - third - 0.50, -1)

    # Je Material ein Objekt, dann verbinden
    objs = []
    for name, bm in BM.items():
        if len(bm.faces) == 0:
            continue
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(MAT[name])
        ob = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in objs:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = "Wohncontainer"
    obj.data.name = "Wohncontainer"
    for p in obj.data.polygons:
        p.use_smooth = False

    mark = bpy.data.objects.new("Hausnummer", None)
    mark.location = NUMBER_POS
    bpy.context.scene.collection.objects.link(mark)
    mark.select_set(True)
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out_path, export_format="GLB", export_yup=True, export_apply=True,
                              use_selection=True)
    print("CONTAINER", out_path, "dreiecke", sum(len(p.vertices) - 2 for p in obj.data.polygons))
    if preview:
        render_previews(preview)


def render_previews(prefix):
    """Nur zur Selbstkontrolle: ein paar Ansichten mit Eevee."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 1200, 800
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.7, 0.9, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    scene.collection.objects.link(sun)
    ground = bpy.data.meshes.new("g")
    gbm = bmesh.new()
    bmesh.ops.create_grid(gbm, x_segments=1, y_segments=1, size=30)
    gbm.to_mesh(ground)
    gm = bpy.data.materials.new("gras")
    gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = lin((0.25, 0.5, 0.2)) + (1,)
    ground.materials.append(gm)
    scene.collection.objects.link(bpy.data.objects.new("g", ground))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 28
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {
        "vorne_oben": ((9.0, 13.0, 9.0), (0, 1.0, 1.0)),
        "rechts": ((10.0, 4.0, 2.0), (0, 1.5, 1.5)),
        "links": ((-10.0, 2.0, 2.5), (0, 0.5, 1.5)),
        "hinten": ((-6.0, -13.0, 5.0), (0, -3.0, 1.2)),
        "innen": ((0.6, -1.2, 1.7), (0.6, 6.0, 0.9)),
    }
    for name, (pos, look) in views.items():
        cam.location = pos
        cam.rotation_euler = (Vector(look) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = f"{prefix}_{name}.png"
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    build(argv[0], argv[1] if len(argv) > 1 else None)
