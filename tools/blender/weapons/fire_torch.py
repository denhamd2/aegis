#!/usr/bin/env python3
"""The fire breather's torch (the owner, 19 Oct: "fire breathing"): what he
holds up to his mouth before he spits the fireball (WeaponCatalog
"fire_torch", Swing.SPRAY; the fire itself is the game's, WrestlerController
_breathe_fire).

Run:  python3 tools/blender/weapons/fire_torch.py

  game/assets/weapons/fire_torch.glb
      FireTorch_Clean  a turned hardwood handle, 0.42 m, with a rag wrapped
                       and wired round its head, charred black from use.
                       Origin at the grip; the handle runs up +Y.

Markers: grip_r (the grip), strike (the head, for a swing), muzzle (the top
of the head, +Z out of it, where the game's flame sits).
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import numpy as np  # noqa: E402

HANDLE_LEN, HANDLE_R = 0.42, 0.015
HEAD_LEN, HEAD_R = 0.10, 0.032
GRIP_FROM = 0.12          # the grip sits this far up from the handle's foot


def build(root, prefix, wood, rag, wire) -> None:
    rng = np.random.RandomState(kit.seed_of("fire_torch"))
    y0 = -GRIP_FROM
    handle = kit.WeaponPart(prefix + "_handle")
    kit.sweep(handle, [Vector((0, y0, 0)), Vector((0, y0 + HANDLE_LEN, 0))],
              lambda t, th: HANDLE_R * (1.08 if t < 0.04 else 1.0 - 0.12 * t), sides=16, caps=True)
    kit.add_mesh(root, handle, wood, uv_scale=3.0)
    head = kit.WeaponPart(prefix + "_rag")
    hy0 = y0 + HANDLE_LEN - HEAD_LEN * 0.8
    lumps = [rng.uniform(0.0, 1.0) for _ in range(7)]
    kit.sweep(head, [Vector((0, hy0, 0)), Vector((0, hy0 + HEAD_LEN, 0))],
              lambda t, th: HEAD_R * (0.75 + 0.25 * math.sin(math.pi * min(t * 1.4, 1.0)))
              * (1.0 + 0.07 * math.sin(th * 5 + lumps[int(t * 6.99)] * 6.0)), sides=18, caps=True)
    kit.add_mesh(root, head, rag, uv_scale=2.0)
    binds = kit.WeaponPart(prefix + "_wire")
    for k, t in enumerate((0.25, 0.6)):
        y = hy0 + HEAD_LEN * t
        r = HEAD_R * (0.75 + 0.25 * math.sin(math.pi * min(t * 1.4, 1.0))) + 0.002
        ring = [Vector((math.cos(a) * r, y + 0.003 * math.sin(a * 3 + k), math.sin(a) * r))
                for a in np.linspace(0, 2 * math.pi, 25)]
        binds.tube(ring, 0.0012, 5)
    kit.add_mesh(root, binds, wire, uv_scale=8.0)
    top = hy0 + HEAD_LEN
    kit.marker(root, "grip_r", Vector((0, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "strike", Vector((0, top - HEAD_LEN * 0.5, 0)), Vector((0, 1, 0)), Vector((0, 0, -1)))
    kit.marker(root, "muzzle", Vector((0, top, 0)), Vector((0, 0, 1)), Vector((0, 1, 0)))


def main() -> None:
    kit.reset()
    wid = "fire_torch"
    wood = kit.pbr_material(wid + "_wood", *kit.wood_textures(wid, (0.46, 0.30, 0.17), (0.28, 0.16, 0.08),
                                                             0.6, 0.3, size=512), 0.6)
    rag = kit.flat_material(wid + "_rag", (0.07, 0.06, 0.05), 0.95)
    wire = kit.flat_material(wid + "_wire", (0.35, 0.34, 0.32), 0.45, 1.0)
    root = kit.state_root("FireTorch_Clean")
    build(root, root.name, wood, rag, wire)
    print("fire_torch: %d triangles" % kit.triangles_under(root))
    print("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
