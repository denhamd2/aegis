#!/usr/bin/env python3
"""The ladder bridge after a man has come down on it (the owner, 19 Oct:
"ladder bridge ... folds when a man lands on it"): the closed ladder from
set_pieces.py, laid flat the way Ladder_Laid_Out lies, and folded in the
middle into a V -- its two halves FOLD_DEG down from the bridge's line, the
fold at the bottom.

Run:  python3 tools/blender/weapons/ladder_bent.py

  game/assets/weapons/ladder_bent.glb
      Ladder_Bent  origin where the bridge's middle was, at its rails' height;
                   the length along Z, the fold hanging FOLD_DEG down, so the
                   ends stay at the bridge's height and the fold drops toward
                   the floor between the apron and the barricade

A file of its own rather than a state in ladder.glb, so the ladder's
committed file is not rebuilt (WeaponActor shows it in place of the bridge,
WeaponActor.fold_bridge()).
"""

from __future__ import annotations

import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402
import set_pieces as sp  # noqa: E402

FOLD_DEG = 40.0


def fold(p: Vector) -> Vector:
    """A closed-ladder vertex (length up +Y from its feet, thickness along Z)
    to the folded bridge: the length along Z about the middle, the rails'
    thickness up, each half turned FOLD_DEG down about the fold."""
    a = math.radians(FOLD_DEG)
    s = p.y - sp.LAD_LEN / 2.0
    h = p.z
    z = s * math.cos(a)
    y = -(sp.LAD_LEN / 2.0 - abs(s)) * math.sin(a) + h * math.cos(a)
    return Vector((p.x, y, z))


class _Folded(kit.WeaponPart):
    def __init__(self, name: str, deform=None) -> None:
        super().__init__(name, deform=fold)


def main() -> None:
    kit.reset()
    wid = "ladder_bent"
    # the same materials, by the same names, as the ladder's own
    alu = kit.pbr_material("ladder_alu", *kit.metal_textures("ladder", (0.70, 0.70, 0.68), 0.08, 0.35), 0.5)
    steps = kit.pbr_material("ladder_steps", *kit.metal_textures("ladder_steps", (0.60, 0.60, 0.58), 0.15, 0.45),
                             0.6)
    cap = kit.pbr_material("ladder_cap", *kit.polymer_textures("ladder_cap", (0.65, 0.50, 0.04)), 0.5)
    real = kit.WeaponPart
    kit.WeaponPart = _Folded
    try:
        root = kit.state_root("Ladder_Bent")
        sp.build_ladder(root, root.name, alu, steps, cap, False)
    finally:
        kit.WeaponPart = real
    # its markers stay where build_ladder put them on a standing ladder;
    # nothing reads a bent ladder's markers
    print("ladder_bent: %d triangles" % kit.triangles_under(root))
    print("wrote " + str(kit.export(wid).relative_to(kit.ROOT)))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
