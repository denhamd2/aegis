#!/usr/bin/env python3
"""Hell in a Cell's way out (gauntlet/refs/hell_in_a_cell.md): a pair of
long-handled bolt cutters, found under the ring, that snap the chain the
referee padlocked the cell door with. An original design: two tubular steel
handles in red dipped grips, a compound pivot block, and short hardened jaws.

Run:  /tmp/claude-0/bpyenv/bin/python tools/blender/weapons/wire_cutters.py

  game/assets/weapons/wire_cutters.glb
      WireCutters_Clean   closed, as carried

Origin at the right-hand grip (grip_r), as it is held one-handed by the end
of a handle; grip_l on the other handle; strike at the jaws.
"""

from __future__ import annotations

import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

LENGTH = 0.76           # grip end to jaw tip, along +Y
SPREAD = 0.045          # half the gap between the handles at their ends
TUBE_R = 0.011
GRIP_R = 0.016
GRIP_LEN = 0.20


def build(root, prefix, steel, grip_mat, jaw_mat) -> None:
    handles = kit.WeaponPart(prefix + "_handles")
    grips = kit.WeaponPart(prefix + "_grips")
    jaws = kit.WeaponPart(prefix + "_jaws")
    pivot_y = LENGTH - 0.16
    for side in (-1.0, 1.0):
        # Each handle: from its end out at SPREAD in to the pivot block.
        path = [Vector((side * SPREAD * (1.0 - f) + side * 0.012 * f, pivot_y * f, 0.0))
                for f in (0.0, 0.25, 0.5, 0.75, 1.0)]
        kit.sweep(handles, path, lambda t, th: TUBE_R, sides=14)
        gpath = [Vector((side * SPREAD * (1.0 - f * GRIP_LEN / pivot_y), GRIP_LEN * f, 0.0))
                 for f in (0.0, 0.5, 1.0)]
        kit.sweep(grips, gpath, lambda t, th: GRIP_R * (0.92 + 0.08 * (1.0 - abs(2.0 * t - 1.0))), sides=16)
        # A short arm from the pivot to the jaw.
        jaws.grid_panel(Vector((side * 0.006 - 0.012, pivot_y, -0.009)), Vector((0.024, 0, 0)),
                        Vector((0, 0.07, 0)), 1, 3, 0.018)
    # The pivot block: two cheek plates round the handle ends.
    for z in (-0.014, 0.014):
        jaws.grid_panel(Vector((-0.032, pivot_y - 0.03, z)), Vector((0.064, 0, 0)),
                        Vector((0, 0.07, 0)), 2, 2, 0.006)
    # The jaws: two wedges meeting on the centre line, the blades' bevel.
    for side in (-1.0, 1.0):
        jaws.grid_panel(Vector((0.0, pivot_y + 0.07, -0.012)), Vector((side * 0.022, 0, 0)),
                        Vector((0, 0.09, 0)), 1, 3, 0.024,
                        bulge=lambda s, t: -0.006 * t)
    kit.add_mesh(root, handles, steel, uv_scale=4.0, auto_smooth_deg=50.0)
    kit.add_mesh(root, grips, grip_mat, uv_scale=6.0, auto_smooth_deg=60.0)
    kit.add_mesh(root, jaws, jaw_mat, uv_scale=6.0, auto_smooth_deg=30.0)
    kit.marker(root, "grip_r", Vector((SPREAD, 0.07, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((-SPREAD, 0.07, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, LENGTH, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))


def main() -> None:
    kit.reset()
    wid = "wire_cutters"
    steel = kit.pbr_material(wid + "_steel", *kit.metal_textures(wid, (0.30, 0.31, 0.33), 0.12, 0.42), 0.6)
    grip_mat = kit.pbr_material(wid + "_grip", *kit.polymer_textures(wid + "_grip", (0.62, 0.05, 0.04)), 0.9)
    jaw_mat = kit.pbr_material(wid + "_jaw", *kit.metal_textures(wid + "_jaw", (0.12, 0.12, 0.13), 0.05, 0.3), 0.6)
    root = kit.state_root("WireCutters_Clean")
    build(root, root.name, steel, grip_mat, jaw_mat)
    print("wire_cutters: %d triangles" % kit.triangles_under(root))
    print("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
