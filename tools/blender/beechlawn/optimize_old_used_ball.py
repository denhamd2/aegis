"""Prepare the owner-supplied worn football for Beechlawn's Godot runtime.

Run from the repository root:
    blender --disable-autoexec -b --python tools/blender/beechlawn/optimize_old_used_ball.py

The original Blender file and its included license are preserved under
tools/blender/beechlawn/source/. This script creates an optimized authoring
file and a GLB; it does not overwrite the source or the existing ball.
"""

from pathlib import Path
import bpy


ROOT = Path(__file__).resolve().parents[3]
SOURCE_BLEND = ROOT / "tools/blender/beechlawn/source/old_used_ball_original.blend"
AUTHORING_OUT = ROOT / "tools/blender/beechlawn/old_used_ball_game_asset.blend"
GLB_OUT = ROOT / "games/beechlawn_rovers/assets/environment/old_used_ball.glb"
BALL_DIAMETER_M = 0.22
DECIMATE_RATIO = 0.035
TEXTURE_SIZE = 2048


def main():
    if not SOURCE_BLEND.is_file():
        raise FileNotFoundError(f"Source ball blend not found: {SOURCE_BLEND}")

    bpy.ops.wm.open_mainfile(filepath=str(SOURCE_BLEND))
    scene = bpy.context.scene
    balls = [obj for obj in scene.objects if obj.type == "MESH"]
    if len(balls) != 1:
        raise RuntimeError(f"Expected one ball mesh, found {len(balls)}")
    ball = balls[0]
    if ball.name != "usedoldball":
        raise RuntimeError(f"Unexpected source mesh: {ball.name}")

    # Remove render-scene helpers. The game supplies its own lighting/camera.
    for obj in list(scene.objects):
        if obj != ball:
            bpy.data.objects.remove(obj, do_unlink=True)

    # Normalize to a regulation-size 22 cm football and apply object scale.
    bpy.context.view_layer.objects.active = ball
    ball.select_set(True)
    largest_axis = max(ball.dimensions)
    if largest_axis <= 0:
        raise RuntimeError("Source ball has invalid dimensions")
    ball.scale *= BALL_DIAMETER_M / largest_axis
    # Bake the source's non-axis-aligned object rotation. Keeping it on the
    # exported node makes the runtime AABB appear oversized despite the mesh's
    # 22 cm authoring dimensions.
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    ball.location = (0.0, 0.0, 0.0)
    ball.name = "SM_OldUsedFootball"
    ball.data.name = "MESH_OldUsedFootball"

    # Reduce the source's 124k triangles while retaining the packed UV texture.
    before_triangles = sum(max(1, len(poly.vertices) - 2) for poly in ball.data.polygons)
    decimate = ball.modifiers.new("RuntimeTriangleBudget", "DECIMATE")
    decimate.ratio = DECIMATE_RATIO
    decimate.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=decimate.name)
    after_triangles = sum(max(1, len(poly.vertices) - 2) for poly in ball.data.polygons)
    if after_triangles > 6000:
        raise RuntimeError(f"Decimation exceeded 6000 triangles: {after_triangles}")
    for poly in ball.data.polygons:
        poly.use_smooth = True

    # The original source and packed 4K image remain untouched in source/.
    source_image = next((image for image in bpy.data.images
                         if image.size[0] >= 2048 and image.size[1] >= 2048
                         and image.source == "FILE"), None)
    if source_image is None:
        raise RuntimeError("Could not find the packed 4K ball albedo")
    source_image.name = "TX_OldUsedFootball_Albedo"
    source_image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
    source_image.pack()

    material = bpy.data.materials.new("M_OldUsedFootball")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    nodes.clear()
    output = nodes.new("ShaderNodeOutputMaterial")
    shader = nodes.new("ShaderNodeBsdfPrincipled")
    shader.inputs["Roughness"].default_value = 0.92
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = source_image
    texture.interpolation = "Linear"
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(shader.outputs["BSDF"], output.inputs["Surface"])
    ball.data.materials.clear()
    ball.data.materials.append(material)

    # Preserve an editable, clean Blender scene alongside the runtime asset.
    scene.render.fps = 30
    AUTHORING_OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(AUTHORING_OUT))

    ball.select_set(True)
    bpy.context.view_layer.objects.active = ball
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
        export_image_format="JPEG",
        export_image_quality=90,
        export_draco_mesh_compression_enable=False,
    )
    print(f"Ball source triangles: {before_triangles:,}")
    print(f"Ball runtime triangles: {after_triangles:,}")
    print(f"Ball dimensions: {[round(axis, 5) for axis in ball.dimensions]} m")
    print(f"Ball GLB: {GLB_OUT} ({GLB_OUT.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
