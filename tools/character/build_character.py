# Erzeugt realistische Figuren mit MakeHuman (MPFB) in Blender und exportiert sie als .glb.
# Alle verwendeten MakeHuman-Assets sind CC0.
#
# Aufruf (aus dem Projektordner):
#   blender -b --factory-startup --python tools/character/build_character.py -- <preset> <ausgabe.glb>
#   Presets: rider, operator, guest_f, guest_m
#
# Voraussetzung: Blender-Extension "MPFB" und die CC0-Asset-Packs (system assets, skins01,
# hair01, pants01, shirts01) sind installiert.
import math
import sys
import bmesh
import bpy
import addon_utils

addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)
from bl_ext.user_default.mpfb.services.humanservice import HumanService  # noqa: E402

PRESETS = {
    # Wakeboarder: sportlich, Boardshorts + T-Shirt (Weste und Helm kommen im Spiel dazu)
    "rider": {
        "phenotype": {"gender": 1.0, "age": 0.5, "muscle": 0.72, "weight": 0.42, "proportions": 0.75, "height": 0.58,
                      "race": {"caucasian": 0.85, "asian": 0.1, "african": 0.05}},
        "skin": "young_caucasian_male/young_caucasian_male.mhmat",
        "hair": "short02/short02.mhclo",
        "eyebrows": "eyebrow001/eyebrow001.mhclo",
        "clothes": ["cortu_cargo_pants/cortu_cargo_pants.mhclo", "elvs_crude_t-shirt_male/elvs_crude_t-shirt_male.mhclo"],
        "boardshorts": True,      # Cargohose am Knie abschneiden = knielange Boardshorts
        "vest": "elvs_crude_t-shirt_male",   # T-Shirt -> ärmellose Impact-Weste (Aufdruck per Shader im Spiel)
        "texture": 1024,
    },
    # Steuermann ("Hebler"): etwas älter, Polo-Shirt, Cargohose
    "operator": {
        "phenotype": {"gender": 1.0, "age": 0.62, "muscle": 0.55, "weight": 0.6, "proportions": 0.6, "height": 0.55,
                      "race": {"caucasian": 0.9, "asian": 0.05, "african": 0.05}},
        "skin": "middleage_caucasian_male/middleage_caucasian_male.mhmat",
        "hair": "short04/short04.mhclo",
        "eyebrows": "eyebrow003/eyebrow003.mhclo",
        "clothes": ["namuhekam_male_polo_shirt/namuhekam_male_polo_shirt.mhclo", "cortu_cargo_pants/cortu_cargo_pants.mhclo"],
        "texture": 512,
    },
    "guest_f": {
        "phenotype": {"gender": 0.0, "age": 0.45, "muscle": 0.5, "weight": 0.45, "proportions": 0.7, "height": 0.5,
                      "race": {"caucasian": 0.8, "asian": 0.1, "african": 0.1}},
        "skin": "young_caucasian_female/young_caucasian_female.mhmat",
        "hair": "ponytail01/ponytail01.mhclo",
        "eyebrows": "eyebrow010/eyebrow010.mhclo",
        "clothes": ["toigo_keyhole_tank_top/toigo_keyhole_tank_top.mhclo", "cortu_jeans_shorts/cortu_jeans_shorts.mhclo"],
        "texture": 512,
    },
    "guest_m": {
        "phenotype": {"gender": 1.0, "age": 0.42, "muscle": 0.6, "weight": 0.5, "proportions": 0.6, "height": 0.6,
                      "race": {"caucasian": 0.1, "asian": 0.05, "african": 0.85}},
        "skin": "young_african_male/young_african_male.mhmat",
        "hair": "short01/short01.mhclo",
        "eyebrows": "eyebrow002/eyebrow002.mhclo",
        "clothes": ["toigo_basic_tucked_t-shirt/toigo_basic_tucked_t-shirt.mhclo", "cortu_cargo_pants/cortu_cargo_pants.mhclo"],
        "boardshorts": True,
        "texture": 1024,          # wird auch als NPC-Fahrer auf T1 benutzt
    },
}



def build(preset_name: str, out_path: str) -> None:
    p = PRESETS[preset_name]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    addon_utils.enable("bl_ext.user_default.mpfb", default_set=True)

    info = HumanService._create_default_human_info_dict()
    info["phenotype"].update(p["phenotype"])
    info["rig"] = "game_engine"
    info["eyes"] = "low-poly/low-poly.mhclo"
    info["eyebrows"] = p["eyebrows"]
    info["eyelashes"] = "eyelashes01/eyelashes01.mhclo"
    info["hair"] = p["hair"]
    info["clothes"] = list(p["clothes"])
    info["skin_mhmat"] = p["skin"]
    info["skin_material_type"] = "GAMEENGINE"
    info["eyes_material_type"] = "MAKESKIN"
    info["clothes_material_type"] = "MAKESKIN"
    info["name"] = preset_name

    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    basemesh = HumanService.deserialize_from_dict(info, settings)

    if p.get("boardshorts"):
        _cut_at_knee("cortu_cargo_pants")
    if p.get("vest"):
        _make_vest(p["vest"])

    # Texturen verkleinern (Dateigröße fürs Web)
    max_tex = p.get("texture", 1024)
    for img in bpy.data.images:
        w, h = img.size
        if w > max_tex or h > max_tex:
            f = max_tex / max(w, h)
            img.scale(max(int(w * f), 1), max(int(h * f), 1))

    # Unterteilungs-Modifier entfernen, Rest (Masken für Kleidung/Helfer) wird beim Export angewendet
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            for m in list(obj.modifiers):
                if m.type == "SUBSURF":
                    obj.modifiers.remove(m)

    tris = 0
    for obj in bpy.data.objects:
        if obj.type == "MESH":
            tris += sum(len(poly.vertices) - 2 for poly in obj.data.polygons)
    print("BUILD", preset_name, "objects:", [o.name for o in bpy.data.objects], "approx tris:", tris)

    bpy.ops.export_scene.gltf(
        filepath=out_path,
        export_format="GLB",
        export_apply=True,
        export_animations=False,
        export_skins=True,
        export_yup=True,
        export_image_format="AUTO",
    )
    print("EXPORTED", out_path)


def _cut_at_knee(name_part: str) -> None:
    """Schneidet ein Kleidungsstück knapp unter dem Knie ab (lange Hose -> Boardshorts)."""
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    knee_z = (arm.matrix_world @ arm.data.bones["calf_l"].head_local).z
    cut = knee_z - 0.04
    obj = next(o for o in bpy.data.objects if name_part in o.name and o.type == "MESH")
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    mw = obj.matrix_world
    doomed = [v for v in bm.verts if (mw @ v.co).z < cut]
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()


VEST_PITCH = 0.075      # Höhe der gesteppten Kammern
VEST_THICK = 0.010      # Dicke Neopren + Schaum (nach innen)
VEST_BULGE = 0.011      # so weit wölben sich die Kammern nach außen


def _new_mat(name, srgb, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = tuple(pow(c, 2.2) for c in srgb) + (1.0,)
    bsdf.inputs["Roughness"].default_value = rough
    m.use_backface_culling = False
    return m


def _apply_first(obj, mod):
    """Modifier ganz nach vorne (vor die Armatur) schieben und anwenden."""
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.scene.objects:
        o.select_set(o == obj)
    bpy.ops.object.modifier_move_to_index(modifier=mod.name, index=0)
    bpy.ops.object.modifier_apply(modifier=mod.name)


def _make_vest(name_part: str) -> None:
    """T-Shirt -> ärmellose Impact-Weste: Ärmel weg (nach Gewicht der Arm-Knochen), Saum gerade
    an der Hüfte, waagerechte gesteppte Kammern, aufgedickt mit neongelbem Futter und schwarzer
    Einfassung, schwarzer Reißverschluss vorne. Materialien: vest_print (Aufdruck, im Spiel per
    Shader), vest_lining, vest_trim, vest_zip."""
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    obj = next(o for o in bpy.data.objects if name_part in o.name and o.type == "MESH")
    obj.name = "vest"
    # Haut unter den Ärmeln wieder einblenden (MakeHuman blendet sie unter Kleidung aus)
    for o in bpy.data.objects:
        if o.type == "MESH":
            for m in list(o.modifiers):
                if m.type == "MASK" and name_part in (m.vertex_group or "") + m.name:
                    o.modifiers.remove(m)
    mw = obj.matrix_world
    scale = mw.to_scale().x
    hem_z = (arm.matrix_world @ arm.data.bones["spine_01"].head_local).z - 0.035

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    deform = bm.verts.layers.deform.verify()
    arm_groups = {obj.vertex_groups[n].index for n in ("upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r")
                  if n in obj.vertex_groups}
    doomed = []
    for v in bm.verts:
        w_arm = sum(w for g, w in v[deform].items() if g in arm_groups)
        if w_arm > 0.35 or (mw @ v.co).z < hem_z:
            doomed.append(v)
    bmesh.ops.delete(bm, geom=doomed, context="VERTS")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    for m in (_new_mat("vest_print", (0.6, 0.5, 0.4), 0.7), _new_mat("vest_lining", (0.86, 0.92, 0.42), 0.8),
              _new_mat("vest_trim", (0.05, 0.05, 0.05), 0.7), _new_mat("vest_zip", (0.03, 0.03, 0.03), 0.4)):
        obj.data.materials.append(m)
    for f in obj.data.polygons:
        f.material_index = 0

    # feiner unterteilen, damit die Kammern rund werden (Gewichte werden mit interpoliert)
    sub = obj.modifiers.new("vest_sub", "SUBSURF")
    sub.levels = 1
    sub.subdivision_type = "SIMPLE"
    _apply_first(obj, sub)

    # Kammern: nach außen wölben, an den Nähten (alle VEST_PITCH) eingezogen
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    for v in bm.verts:
        z = (mw @ v.co).z - hem_z
        bulge = pow(abs(math.sin(math.pi * z / VEST_PITCH)), 0.6)
        v.co += v.normal * (0.003 + VEST_BULGE * bulge) / scale
    bm.to_mesh(obj.data)
    bm.free()

    sol = obj.modifiers.new("vest_solid", "SOLIDIFY")
    sol.thickness = VEST_THICK / scale
    sol.offset = -1.0
    sol.use_rim = True
    sol.material_offset = 1
    sol.material_offset_rim = 2
    _apply_first(obj, sol)

    # Reißverschluss: schmaler Streifen vorne in der Mitte (MakeHuman: vorne = -Y)
    for f in obj.data.polygons:
        c = mw @ f.center
        if f.material_index == 0 and abs(c.x) < 0.008 and c.y < 0.0:
            f.material_index = 3
    print("VEST faces:", len(obj.data.polygons))


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    build(argv[0], argv[1])
