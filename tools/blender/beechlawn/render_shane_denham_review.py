"""Render a fixed three-quarter review view of the authored Shane prototype."""
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Vector, Matrix
import math

ROOT = Path(__file__).resolve().parents[3]
SCENE = ROOT / "tools/blender/beechlawn/shane_denham_08.blend"
shared_preview = "--shared" in sys.argv
if shared_preview:
    SCENE = SCENE.with_name("footballer_shared.blend")
scene_override = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--scene=")), None)
if scene_override:
    SCENE = Path(scene_override).resolve()
OUT = ROOT / "games/beechlawn_rovers/docs/art_briefs/shane_denham_08_first_pass.png"
output_override = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--out-dir=")), None)
if output_override:
    OUT = Path(output_override).resolve() / OUT.name
bpy.ops.wm.open_mainfile(filepath=str(SCENE))
variant_path = next((a.split("=", 1)[1] for a in sys.argv if a.startswith("--variant=")), None)
if variant_path:
    # Append head meshes only into this disposable shared-body review session.
    names = ["Skin_Head", "Eye_l", "Eye_r", "Hair_Shane_ShortCropRoots", "Hair_Shane_ShortCropCards"]
    originals = {name: bpy.data.objects[name] for name in names}
    with bpy.data.libraries.load(str(Path(variant_path).resolve()), link=False) as (source, target):
        target.objects = list(names)
    for name, obj in zip(names, target.objects):
        originals[name].data = obj.data
        bpy.data.objects.remove(obj, do_unlink=True)
scene = bpy.context.scene
if shared_preview:
    short = bpy.data.objects.get("Kit_Shirt_ShortSleeve")
    if short:
        short.hide_render = True
armature = bpy.data.objects.get("YBot_Armature")
idle_preview = "--idle" in sys.argv
clip = next((arg.split("=", 1)[1] for arg in sys.argv if arg.startswith("--clip=")), None)
frame = int(next((arg.split("=", 1)[1] for arg in sys.argv if arg.startswith("--frame=")), "2"))
neutral_preview = "--neutral" in sys.argv
clay_preview = "--clay" in sys.argv
albedo_preview = "--albedo" in sys.argv
hide_hair = "--no-hair" in sys.argv
if "--smile" in sys.argv:
    head = bpy.data.objects.get("Skin_Head")
    if head and head.data.shape_keys:
        head.data.shape_keys.key_blocks["Shane_Smile"].value = 1.0
if armature:
    armature.animation_data_create()
    if idle_preview or clip:
        action_name = clip or "AN_Beechlawn_Idle"
        action = bpy.data.actions.get(action_name)
        if action is None:
            raise RuntimeError("Missing review animation: " + action_name)
        armature.animation_data.action = action
        # Show the player in a neutral gameplay pose in addition to the bind
        # pose used for likeness and UV comparison.
        # The action's first authored pose is the planted idle baseline;
        # frame 44 is a later weight shift and makes the review sheet look as
        # if the rig/shorts are broken when it is shown without context.
        scene.frame_set(frame)
    else:
        armature.animation_data.action = None
        for pose_bone in armature.pose.bones:
            pose_bone.location = (0.0, 0.0, 0.0)
            pose_bone.rotation_mode = "QUATERNION"
            pose_bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
            pose_bone.scale = (1.0, 1.0, 1.0)
        scene.frame_set(1)
        if neutral_preview:
            bpy.context.view_layer.update()
            for side, angle in (("Left", -75.0), ("Right", 75.0)):
                bone = armature.pose.bones["mixamorig:" + side + "Arm"]
                rest = bone.bone.matrix_local
                centre = rest.translation
                bone.matrix = (Matrix.Translation(centre)
                               @ Matrix.Rotation(math.radians(angle), 4, "Z")
                               @ Matrix.Translation(-centre) @ rest)
            bpy.context.view_layer.update()
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 600
scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
scene.eevee.taa_render_samples = 8
scene.world = bpy.data.worlds.new("ShaneReviewWorld")
scene.world.use_nodes = True
scene.world.node_tree.nodes["Background"].inputs["Color"].default_value = (.32, .36, .42, 1)
scene.world.node_tree.nodes["Background"].inputs["Strength"].default_value = .55

def area(name, location, energy, size, color):
    light_data = bpy.data.lights.new(name, "AREA")
    light_data.energy = energy
    light_data.shape = "DISK"
    light_data.size = size
    light_data.color = color
    light = bpy.data.objects.new(name, light_data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0, 0, .95)) - light.location).to_track_quat("-Z", "Y").to_euler()

area("Key_Softbox", (2.2, -3.3, 3.6), 450, 3.0, (1.0, .88, .76))
area("Fill_Softbox", (-2.8, -2.2, 2.2), 260, 3.5, (.73, .83, 1.0))
area("Rim_Softbox", (0.5, 2.5, 3.1), 380, 2.6, (1.0, 1.0, 1.0))

ground_mat = bpy.data.materials.new("ReviewGround")
ground_mat.diffuse_color = (.12, .14, .16, 1)
ground_mat.use_nodes = True
ground_mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.12, .14, .16, 1)
ground_mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .92
bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.015))
bpy.context.object.name = "ReviewGround"
bpy.context.object.data.materials.append(ground_mat)

scene.render.image_settings.file_format = "PNG"
if hide_hair:
    for obj in list(scene.objects):
        if obj.type!="MESH":continue
        if obj.name.startswith("Hair_"):
            obj.hide_render = True
            continue
        slots={i for i,m in enumerate(obj.data.materials) if m and m.name.startswith("MAT_Hair_")}
        if slots:
            bm=bmesh.new();bm.from_mesh(obj.data)
            bmesh.ops.delete(bm,geom=[f for f in bm.faces if f.material_index in slots],context="FACES")
            bm.to_mesh(obj.data);bm.free();obj.data.update()
if albedo_preview:
    # Diagnostic only: isolate image registration from normal/shadow faults.
    for material in list(bpy.data.materials):
        if not material.use_nodes:
            continue
        nodes, links = material.node_tree.nodes, material.node_tree.links
        bsdf = nodes.get("Principled BSDF")
        output = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None)
        if not bsdf or not output:
            continue
        emission = nodes.new("ShaderNodeEmission")
        source = bsdf.inputs["Base Color"]
        if source.links:
            links.new(source.links[0].from_socket, emission.inputs["Color"])
        else:
            emission.inputs["Color"].default_value = source.default_value
        links.new(emission.outputs[0], output.inputs["Surface"])
if clay_preview:
    clay = bpy.data.materials.new("REVIEW_Clay_NoTextures")
    clay.use_nodes = True
    clay.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.28, .28, .28, 1)
    clay.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .76
    # Eevee does not honor the Cycles view-layer material override here.
    # Replace slots in this disposable render session; never save the source.
    for obj in scene.objects:
        if obj.type == "MESH":
            for slot in obj.material_slots:
                slot.material = clay
OUT.parent.mkdir(parents=True, exist_ok=True)
views = [
    ("threequarter", (3.3, -3.3, .92), 68),
    ("front", (0.0, -4.7, .92), 68),
    ("profile", (4.7, 0.0, .92), 68),
    ("profile_portrait", (1.25, 0.0, 1.69), 95),
    ("back", (0.0, 4.7, .92), 68),
    ("portrait", (0.0, -1.25, 1.69), 95),
]
if "--face-views" in sys.argv:
    views.append(("threequarter_portrait", (.75, -1.10, 1.69), 95))
motion_review = "--motion-check" in sys.argv
if motion_review:
    views = [("idle_f44_front", (0, -4.7, .92), 68),
             ("sprint_f10_front", (0, -4.7, .92), 68),
             ("shotright_f18_profile", (4.7, 0, .92), 68)]
elif "--face-views" in sys.argv:
    views = sorted((view for view in views if "portrait" in view[0]),
                   key=lambda view: view[0] != "portrait")
elif "--portrait-only" in sys.argv:
    views = [view for view in views if view[0] == "portrait"]
elif "--kit-detail" in sys.argv:
    views = [("kit_detail", (0.0, -2.1, 1.45), 82)]
elif "--front-only" in sys.argv:
    views = [view for view in views if view[0] == "front"]
elif "--back-only" in sys.argv:
    views = [view for view in views if view[0] == "back"]
elif "--jersey-views" in sys.argv:
    views = [view for view in views if view[0] in ("front", "back")]
elif "--profile-only" in sys.argv:
    views = [view for view in views if view[0] == "profile"]
elif "--profile-portrait-only" in sys.argv:
    views = [view for view in views if view[0] == "profile_portrait"]
elif "--body-views" in sys.argv:
    views = [view for view in views if "portrait" not in view[0]]
for view_name, position, lens in views:
    if motion_review:
        action_name, probe = {"idle_f44_front": ("AN_Beechlawn_Idle", 44),
                              "sprint_f10_front": ("AN_Beechlawn_Sprint", 10),
                              "shotright_f18_profile": ("AN_Beechlawn_ShotRight", 18)}[view_name]
        armature.animation_data.action = bpy.data.actions[action_name]
        scene.frame_set(probe)
    camera_data = bpy.data.cameras.new("CAM_Shane_" + view_name)
    camera = bpy.data.objects.new("CAM_Shane_" + view_name, camera_data)
    scene.collection.objects.link(camera)
    camera.location = position
    target = Vector((0, 0, 1.69)) if "portrait" in view_name else Vector((0, 0, .92))
    if view_name == "kit_detail":
        target = Vector((0, 0, 1.45))
    camera.rotation_euler = (target - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera_data.lens = lens
    if "portrait" not in view_name and view_name != "kit_detail":
        # Matched-height orthographic body views isolate shape from lens tilt.
        camera_data.type = "ORTHO"
        camera_data.ortho_scale = 2.1
    scene.camera = camera
    suffix = "idle_" if idle_preview else "neutral_" if neutral_preview else ""
    if clip:
        suffix = clip.removeprefix("AN_Beechlawn_").lower() + "_f%d_" % frame
    if hide_hair:
        suffix = "nohair_" + suffix
    if clay_preview:
        suffix = "clay_" + suffix
    if albedo_preview:
        suffix = "albedo_" + suffix
    prefix = "footballer_shared_" if shared_preview else "shane_denham_08_"
    output = OUT.with_name(prefix + "%s%s.png" % (suffix, view_name))
    scene.render.filepath = str(output)
    bpy.ops.render.render(write_still=True)
    print("SHANE_REVIEW_RENDER", output)
