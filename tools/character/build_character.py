# Erzeugt realistische Figuren mit MakeHuman (MPFB) in Blender und exportiert sie als .glb.
# Alle verwendeten MakeHuman-Assets sind CC0.
#
# Aufruf (aus dem Projektordner):
#   blender -b --factory-startup --python tools/character/build_character.py -- <preset> <ausgabe.glb>
#   Presets: rider, operator, guest_f, guest_m
#
# Voraussetzung: Blender-Extension "MPFB" und die CC0-Asset-Packs (system assets, skins01,
# hair01, pants01, shirts01) sind installiert.
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


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    build(argv[0], argv[1])
