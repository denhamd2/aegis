"""One-click Unreal test scene: our arena, ring and Roman, lit for TV.

Run inside the Unreal Editor (5.x), not from a shell:
    Tools > Execute Python Script...  ->  pick this file
(needs Edit > Plugins > "Python Editor Script Plugin" enabled; restart after).

What it does, all under /Game/AegisTest:
  1. makes a new empty level, RingTest
  2. imports ringside.glb, arena_bowl.glb, ring.glb and roman_reigns.glb
     *into the level* (same as File > Import Into Level), at their own
     coordinates -- the four files already share one world frame, so the
     ring lands inside the bowl and Roman stands at centre ring
  3. rebuilds the canvas and the apron, which the game draws in ring.tscn
     rather than in ring.glb (6 m square canvas, top at floor zero; black
     apron skirt carrying our banner)
  4. four TV spots on the ring, dim house lights over the crowd, a fixed
     exposure, and four cine cameras round the ring (HardCam_1..4 -- pilot
     whichever one sees Roman's face)

This is an experiment rig, not a port: nothing in the game reads it.
Unreal converts glTF's Y-up metres to Z-up centimetres on import.
"""
import os

import unreal

# Where the aegis checkout lives. Found from this file when run via
# Execute Python Script; set by hand if that fails.
try:
    REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
except NameError:
    REPO = r"C:\path\to\aegis"

ASSETS = os.path.join(REPO, "game", "assets")
GLBS = [
    ("Ringside", os.path.join(ASSETS, "environment", "ringside.glb")),
    ("Arena", os.path.join(ASSETS, "environment", "arena_bowl.glb")),
    ("Ring", os.path.join(ASSETS, "environment", "ring.glb")),
    ("Roman", os.path.join(ASSETS, "characters", "roman_reigns.glb")),
]
BANNER = os.path.join(ASSETS, "environment", "materials", "ring_apron_banner.png")

ROOT = "/Game/AegisTest"
LEVEL = ROOT + "/RingTest"

actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
tools = unreal.AssetToolsHelpers.get_asset_tools()
mel = unreal.MaterialEditingLibrary


def log(msg):
    unreal.log("[aegis] " + msg)


def V(x, y, z):
    return unreal.Vector(x, y, z)


# ------------------------------------------------------------------ level
if unreal.EditorAssetLibrary.does_asset_exist(LEVEL):
    levels.load_level(LEVEL)
    for a in actors.get_all_level_actors():
        if a.get_actor_label().startswith("Aegis_"):
            actors.destroy_actor(a)
else:
    levels.new_level(LEVEL)


def tag(actor, label):
    actor.set_actor_label("Aegis_" + label)
    actor.set_folder_path("Aegis")
    return actor


# ------------------------------------------------------------ the GLBs
def import_into_level(name, path):
    if not os.path.exists(path):
        unreal.log_error("[aegis] missing " + path)
        return
    dest = "%s/%s" % (ROOT, name)
    try:
        mgr = unreal.InterchangeManager.get_interchange_manager_scripted()
        src = unreal.InterchangeManager.create_source_data(path)
        params = unreal.ImportAssetParameters()
        params.is_automated = True
        mgr.import_scene(dest, src, params)
        log("imported into level: " + name)
    except Exception as e:  # older Interchange API: assets, then place them
        log("scene import unavailable (%s); importing assets instead" % e)
        task = unreal.AssetImportTask()
        task.filename = path
        task.destination_path = dest
        task.automated = True
        task.replace_existing = True
        task.save = True
        tools.import_asset_tasks([task])
        for p in task.imported_object_paths:
            obj = unreal.load_asset(p)
            if isinstance(obj, (unreal.StaticMesh, unreal.SkeletalMesh)):
                actors.spawn_actor_from_object(obj, V(0, 0, 0))


for name, path in GLBS:
    import_into_level(name, path)


# ------------------------------------------------ canvas and apron
def flat_material(name, rgb, rough, texture=None):
    path = "%s/Materials/%s" % (ROOT, name)
    if unreal.EditorAssetLibrary.does_asset_exist(path):
        unreal.EditorAssetLibrary.delete_asset(path)
    mat = tools.create_asset(name, ROOT + "/Materials", unreal.Material,
                             unreal.MaterialFactoryNew())
    if texture:
        node = mel.create_material_expression(
            mat, unreal.MaterialExpressionTextureSample, -400, 0)
        node.set_editor_property("texture", texture)
        mel.connect_material_property(node, "RGB", unreal.MaterialProperty.MP_BASE_COLOR)
    else:
        node = mel.create_material_expression(
            mat, unreal.MaterialExpressionConstant3Vector, -400, 0)
        node.set_editor_property("constant", unreal.LinearColor(rgb[0], rgb[1], rgb[2], 1))
        mel.connect_material_property(node, "", unreal.MaterialProperty.MP_BASE_COLOR)
    r = mel.create_material_expression(
        mat, unreal.MaterialExpressionConstant, -400, 200)
    r.set_editor_property("r", rough)
    mel.connect_material_property(r, "", unreal.MaterialProperty.MP_ROUGHNESS)
    mel.recompile_material(mat)
    unreal.EditorAssetLibrary.save_loaded_asset(mat)
    return mat


banner = None
if os.path.exists(BANNER):
    t = unreal.AssetImportTask()
    t.filename = BANNER
    t.destination_path = ROOT + "/Materials"
    t.automated = True
    t.replace_existing = True
    t.save = True
    tools.import_asset_tasks([t])
    if t.imported_object_paths:
        banner = unreal.load_asset(t.imported_object_paths[0])

canvas_mat = flat_material("M_Canvas", (0.95, 0.95, 0.94), 0.85)
apron_mat = flat_material("M_Apron", (0.02, 0.02, 0.02), 0.9, banner)
cube = unreal.load_asset("/Engine/BasicShapes/Cube.Cube")  # 100 cm cube


def box(label, centre, size_cm, mat, yaw=0.0):
    a = actors.spawn_actor_from_object(cube, centre, unreal.Rotator(0, 0, yaw))
    a.set_actor_scale3d(V(size_cm[0] / 100.0, size_cm[1] / 100.0, size_cm[2] / 100.0))
    a.get_component_by_class(unreal.StaticMeshComponent).set_material(0, mat)
    return tag(a, label)


# ring.tscn: 6 x 0.2 x 6 m box, top at y = 0 (the mat surface).
box("Canvas", V(0, 0, -10), (600, 600, 20), canvas_mat)
# Apron skirt: 6.6 m x 0.9 m at 3.15 m out, spanning 0.2 m to 1.1 m below.
for i, (x, y, yaw) in enumerate([(315, 0, 0), (-315, 0, 180), (0, 315, 90), (0, -315, 270)]):
    box("Apron%d" % i, V(x, y, -65), (2, 660, 90), apron_mat, yaw)


# ------------------------------------------------------------ lighting
def look(frm, to):
    return unreal.MathLibrary.find_look_at_rotation(frm, to)


def light(cls, label, pos, target, intensity, color, radius, cone=None):
    a = actors.spawn_actor_from_class(cls, pos, look(pos, target))
    comp = a.get_component_by_class(unreal.LocalLightComponent)
    try:
        comp.set_editor_property("intensity_units", unreal.LightUnits.CANDELAS)
    except Exception:
        pass
    comp.set_intensity(intensity)
    comp.set_light_color(color)
    comp.set_attenuation_radius(radius)
    if cone:
        comp.set_outer_cone_angle(cone)
        comp.set_inner_cone_angle(cone * 0.6)
    return tag(a, label)


chest = V(0, 0, 120)
warm = unreal.LinearColor(1.0, 0.94, 0.86, 1)
# Four truss spots, 9 m up on the corner diagonals: ~1,000 lux on the canvas,
# which is where a TV-lit ring sits.
for i, (x, y) in enumerate([(700, 700), (-700, 700), (700, -700), (-700, -700)]):
    light(unreal.SpotLight, "Spot%d" % i, V(x, y, 900), chest, 25000, warm, 3000, 30)
# House lights: dim and cool over the stands, so the bowl reads but falls off.
cool = unreal.LinearColor(0.75, 0.82, 1.0, 1)
for i, (x, y) in enumerate([(2500, 0), (-2500, 0), (0, 3500), (0, -3500)]):
    light(unreal.PointLight, "House%d" % i, V(x, y, 1500), V(x, y, 0), 3000, cool, 4000)

# Fixed exposure so the ring doesn't pump as cameras cut (EV100 8.5 ~ TV ring).
pp = tag(actors.spawn_actor_from_class(unreal.PostProcessVolume, V(0, 0, 0)), "Exposure")
pp.set_editor_property("unbound", True)
try:
    s = pp.get_editor_property("settings")
    for k, v in [("override_auto_exposure_min_brightness", True),
                 ("auto_exposure_min_brightness", 8.5),
                 ("override_auto_exposure_max_brightness", True),
                 ("auto_exposure_max_brightness", 8.5)]:
        s.set_editor_property(k, v)
    pp.set_editor_property("settings", s)
except Exception as e:
    log("exposure left on auto (%s)" % e)

# ------------------------------------------------------------ cameras
for i, (x, y) in enumerate([(900, 0), (0, 900), (-900, 0), (0, -900)]):
    pos = V(x, y, 260)
    cam = actors.spawn_actor_from_class(unreal.CineCameraActor, pos, look(pos, chest))
    cam.get_cine_camera_component().set_editor_property("current_focal_length", 35.0)
    tag(cam, "HardCam_%d" % (i + 1))

levels.save_current_level()
log("done -- open the Aegis folder in the Outliner; pilot a HardCam to frame Roman")
