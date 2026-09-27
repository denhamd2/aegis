"""Render an authored clip's keyframes as a contact sheet, on the rig's own mesh.

Usage (headless, no Blender application needed):

    python3 game/tools/blender/clip_sheet.py Getup_Rise /tmp/getup.png
    python3 game/tools/blender/clip_sheet.py Getup_Rise /tmp/getup.png --side

Why this exists: every in-game probe renders under the arena's lights, which
light a pair from above and behind, and at the distance the match camera sits
a man lying on the mat is a few dark pixels. That is the right test of what
ships, and the wrong tool for asking "which way up is he in this pose" --
which is how SUPINE went on laying every downed wrestler face down without
anybody seeing it. This poses the mannequin from wrestling_clips.CLIPS
through the same RigPoser the clips are keyed with, frames it square-on under
a flat sun in Cycles, and renders one panel per authored key.

It writes nothing into the repo. It is a look, not an asset.
"""

import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "..", "tools", "blender"))

import wrestling_clips  # noqa: E402
from rig_pose import RigPoser  # noqa: E402
from bpy_exit import finish  # noqa: E402

PANEL = 360


def setup(side):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=wrestling_clips.RIG)
    arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)

    scene = bpy.context.scene
    # Cycles on the CPU: Workbench and EEVEE both need an EGL context, and a
    # headless container has none. A handful of samples is plenty to read a
    # pose.
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 8
    scene.cycles.use_denoising = False
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.7, 0.2, 0.6)
    scene.collection.objects.link(sun)
    scene.render.resolution_x = PANEL
    scene.render.resolution_y = PANEL
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.55, 1.0)
    scene.world = world

    # A mat to lie on, so "on the mat" and "under it" are visible.
    bpy.ops.mesh.primitive_plane_add(size=6.0, location=(0.0, 0.0, 0.0))

    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = 2.6
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    # The character faces -Y. Three-quarter from his front-left by default,
    # square on his left side with --side.
    if side:
        cam.location = Vector((6.0, 0.0, 0.9))
    else:
        cam.location = Vector((4.2, -4.2, 2.4))
    direction = Vector((0.0, 0.0, 0.7)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    return arm


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    side = "--side" in sys.argv
    clip, out = args[0], args[1]
    frames = wrestling_clips.CLIPS[clip]
    arm = setup(side)
    poser = RigPoser(arm)

    tmp = out + ".d"
    os.makedirs(tmp, exist_ok=True)
    paths = []
    for frame, spec in frames:
        poser.apply(spec)
        path = os.path.join(tmp, "%s_%03d.png" % (clip, frame))
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append((frame, path))

    # Stitch with bpy's own image API so this needs nothing but bpy.
    cols = min(len(paths), 6)
    rows = (len(paths) + cols - 1) // cols
    sheet = bpy.data.images.new("sheet", cols * PANEL, rows * PANEL)
    pixels = [0.0] * (cols * PANEL * rows * PANEL * 4)
    for i, (_frame, path) in enumerate(paths):
        img = bpy.data.images.load(path)
        src = list(img.pixels)
        col, row = i % cols, rows - 1 - i // cols
        for y in range(PANEL):
            dst = ((row * PANEL + y) * cols * PANEL + col * PANEL) * 4
            pixels[dst:dst + PANEL * 4] = src[y * PANEL * 4:(y + 1) * PANEL * 4]
    sheet.pixels = pixels
    sheet.filepath_raw = out
    sheet.file_format = "PNG"
    sheet.save()
    print("wrote %s: %s at frames %s" % (out, clip, [f for f, _ in paths]))


if __name__ == "__main__":
    main()
    finish(0)
