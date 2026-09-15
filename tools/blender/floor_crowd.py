#!/usr/bin/env python3
"""Export the ringside fans: six seated people, each its own mesh.

    tools/blender/build_arena.sh          # builds this and the bowl
    python floor_crowd.py --out /tmp/x.glb

Why these are separate from the bowl's crowd
--------------------------------------------
`crowd.py` bakes the bowl's people into the hall's mesh, because they sit on
twenty rows of a curve and every one of them is posed differently. The
ringside floor is the opposite problem: `arena_builder.gd` already computes a
transform for every folding chair on the rink (`_floor_seat_row`), so those
figures want to be INSTANCED against the transforms that already exist -- and
a MultiMesh instances one mesh.

So the variety moves. Instead of one mesh per person it is six people and a
thousand instances, with size, yaw and shirt colour varying per instance in
Godot on top of the six poses here. At the distance `ringside_low` frames the
floor from, six is enough that a bank of chairs does not read as a repeat.

These are also the closest crowd to any camera in the game -- they are between
the barricade and the ring -- so they get the full nine-box figure, never the
distant four-box one.

Frame
-----
Each figure is built at the origin facing **+Z**, which is the frame the
folding chair prop is modelled in: `_floor_seat_row` orients a chair with
`Basis(Vector3.UP, atan2(inward.x, inward.z))`, which maps local +Z onto the
inward direction. A figure built in the same frame drops onto a chair's
transform unchanged.

The mesh carries no HUE. Colour arrives per instance from the MultiMesh and
multiplies against what is here, so a shirt colour in the mesh would tint every
fan twice. What the mesh does carry is VALUE -- white for cloth, a darker grey
for skin -- which is what gives a fan a face rather than one flat silhouette.

That colour has to leave Blender as COLOR_0, and glTF only writes it there when
a material demonstrably reads the layer. Hence the ShaderNodeVertexColor and
`export_vertex_color="ACTIVE"` below, both copied from `arena_bowl.py`. Without
them the layer goes out as COLOR_1, which Godot's importer ignores in silence.
"""

from __future__ import annotations

import argparse
import pathlib
import sys

import bpy  # noqa: I001  -- registers the rest
import bmesh  # noqa: F401  -- imported for parity with arena_bowl's Part

import arena_bowl
import crowd as crowd_module
import bpy_exit

REPO = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_OUT = REPO / "game" / "assets" / "environment" / "floor_crowd.glb"


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    args = parser.parse_args(argv)

    arena_bowl.reset_scene()
    parts: dict[str, arena_bowl.Part] = {}

    def make_part(name: str) -> arena_bowl.Part:
        part = arena_bowl.Part(name)
        parts[name] = part
        return part

    names = crowd_module.build_floor_variants(make_part)

    for name, part in parts.items():
        mesh = bpy.data.meshes.new(name)
        # Not welded, for the same reason the bowl's crowd is not: a figure's
        # boxes interpenetrate and merging their shared corners fuses an arm
        # into a torso.
        part.bm.to_mesh(mesh)
        part.bm.free()
        # Smooth, again as the bowl's crowd is: it costs a third of the
        # vertices a flat-shaded box needs, and a softly shaded person reads
        # better than a faceted one at any distance these are seen from.
        for polygon in mesh.polygons:
            polygon.use_smooth = True
        material = bpy.data.materials.new("M_" + name)
        material.use_nodes = True
        bsdf = material.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (1.0, 1.0, 1.0, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
        # Drive base colour from the colour attribute, exactly as arena_bowl.py
        # does for the bowl's crowd, and for the same reason: without a node
        # that demonstrably reads the layer, glTF's default export mode writes
        # it as a SECONDARY attribute. It did -- the figures' white/grey came
        # out as COLOR_1, Godot's importer only reads COLOR_0, and every fan
        # rendered one flat value with no skin at all.
        attribute = material.node_tree.nodes.new("ShaderNodeVertexColor")
        attribute.layer_name = "Col"
        material.node_tree.links.new(attribute.outputs["Color"],
                                     bsdf.inputs["Base Color"])
        mesh.materials.append(material)
        bpy.context.collection.objects.link(bpy.data.objects.new(name, mesh))

    out = pathlib.Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=False,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
        # ACTIVE, not the "MATERIAL" default: see the colour attribute above.
        export_vertex_color="ACTIVE",
    )
    print("floor_crowd: %d variants, %d triangles, %s"
          % (len(names), arena_bowl.triangle_count(), out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
