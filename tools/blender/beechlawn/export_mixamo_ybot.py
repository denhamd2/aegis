"""Import the supplied Mixamo Y-Bot FBX and create a clean Godot GLB.

Run from the repository root:
    blender -b --python tools/blender/beechlawn/export_mixamo_ybot.py

The FBX remains the source of truth. The Blender file is editable source and
the GLB is the runtime asset. Mixamo bone names are deliberately preserved.
"""

from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot_source.fbx"
BLEND_OUT = ROOT / "tools/blender/beechlawn/y_bot_source.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/characters/mixamo/y_bot.glb"


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.armatures, bpy.data.cameras,
                       bpy.data.lights, bpy.data.curves):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)


def main():
    if not SOURCE.is_file():
        raise FileNotFoundError(f"Mixamo FBX not found: {SOURCE}")

    reset_scene()
    bpy.ops.import_scene.fbx(filepath=str(SOURCE), automatic_bone_orientation=False)

    # Mixamo's FBX includes default scene helpers. Keep only the skinned actor.
    for obj in list(bpy.context.scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
        elif obj.type == "MESH" and len(obj.data.vertices) < 100:
            bpy.data.objects.remove(obj, do_unlink=True)

    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(armatures) != 1 or len(meshes) != 2:
        raise RuntimeError(
            f"Expected one armature and two skinned meshes; found {len(armatures)} and {len(meshes)}"
        )
    armature = armatures[0]
    if len(armature.data.bones) != 65:
        raise RuntimeError(f"Unexpected Mixamo skeleton size: {len(armature.data.bones)} bones")
    if any(not any(mod.type == "ARMATURE" and mod.object == armature for mod in mesh.modifiers)
           for mesh in meshes):
        raise RuntimeError("Both character meshes must be bound to the Mixamo armature")

    armature.name = "YBot_Armature"
    armature.data.name = "YBot_Skeleton"
    for mesh in meshes:
        mesh.name = "YBot_Surface" if "Surface" in mesh.name else "YBot_Joints"

    # Save a clean authoring file while preserving the untouched source FBX.
    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_set(1)
    BLEND_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_OUT))

    # Export only the rig and skinned meshes. Do not ship the FBX's one-frame
    # pose action as gameplay animation; meaningful clips will be added later.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [armature, *meshes]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = armature
    GLB_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_OUT),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_skins=True,
        export_influence_nb=4,
        export_draco_mesh_compression_enable=False,
        export_leaf_bone=False,
        export_rest_position_armature=True,
    )
    print(f"Exported {GLB_OUT} ({GLB_OUT.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
