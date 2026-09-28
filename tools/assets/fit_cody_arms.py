#!/usr/bin/env python3
"""Puts Cody's arm bones INSIDE his arms, and re-weights the arms round them.

The owner: "his arms look messed up". Measured on the committed
`game/assets/characters/cody_rhodes.glb` (the output of
`rig_static_wrestler.py`): that script aims each arm chain as ONE straight
line from the shoulder at the hand, but the supplied statue's arms hang
BENT -- elbows back and in -- so the chain runs through the air beside the
arm. At mid upper-arm the flesh's centre line is 0.19 m from the bone. The
elbow joint therefore bent nothing at the elbow; the mesh bent in a long
smooth curve between two wrongly placed pivots, which rendered as a
rubber arm with no elbow.

The bone LENGTHS were right -- shoulder to the mesh's elbow measures 0.276
against the bone's 0.274 -- so this changes only where the bones point:

  1. Measure the arm's centre line off the mesh itself: bin the arm's
     vertices along the shoulder-to-hand axis and take each bin's centroid.
     The elbow is the centroid of the bins at 0.17-0.23 m along (where the
     line bends furthest out), the wrist the centroid at 0.40-0.44 m (the
     narrowest section before the hand).
  2. Re-aim upperarm at the elbow and lowerarm at the wrist in the REST pose,
     keeping every bone's length, and carry the hand along.
  3. Re-split each arm vertex's upperarm / lowerarm / hand weight by where it
     projects onto the new chain, with a soft blend across each joint. The
     vertex's total arm weight -- and its clavicle, spine and finger weights
     -- are untouched.

Why rest-only is safe: CodyModel plays the base rig's clips by setting each
bone's LOCAL pose directly, so the posed skeleton is the base rig's whatever
the rest is (see cody_model.gd). The rest defines only the bind -- which is
exactly what was wrong. The animation tracks' bone positions, which carry the
base rig's lengths, still agree, because no length changed.

Run:  python3 tools/assets/fit_cody_arms.py
Rewrites game/assets/characters/cody_rhodes.glb in place. Idempotent in
effect: on an already-fitted file the measured elbow and wrist are where the
bones already point, and the re-weighting reproduces itself.
"""

from __future__ import annotations

import pathlib
import sys

import bpy
import numpy as np
from mathutils import Vector

REPO = pathlib.Path(__file__).resolve().parents[2]
GLB = REPO / "game/assets/characters/cody_rhodes.glb"

## Along the shoulder->hand axis, in metres: where the elbow and the wrist
## are read off the centre line (the profile table in the docstring).
ELBOW_BAND = (0.17, 0.23)
WRIST_BAND = (0.40, 0.44)
BIN = 0.02
## A vertex counts as arm when this much of its weight is on the arm chain.
ARM_WEIGHT = 0.6
## Half-widths of the weight blend across each joint. The elbow is wider:
## the biceps and forearm flesh overlap it; the wrist is a narrow joint.
ELBOW_BLEND = 0.045
WRIST_BLEND = 0.02


def smooth(t: float) -> float:
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def arm_points(side: str) -> np.ndarray:
    pts = []
    for o in bpy.data.objects:
        if o.type != "MESH":
            continue
        gi = {g.name: g.index for g in o.vertex_groups}
        idx = [gi.get(f"{k}_{side}") for k in ("upperarm", "lowerarm", "hand")]
        mw = o.matrix_world
        for v in o.data.vertices:
            w = {g.group: g.weight for g in v.groups}
            if sum(w.get(i, 0.0) for i in idx if i is not None) > ARM_WEIGHT:
                pts.append(tuple(mw @ v.co))
    return np.array(pts)


def centre(points: np.ndarray, s: np.ndarray, band: tuple) -> Vector:
    cents = []
    lo = band[0]
    while lo < band[1] - 1e-9:
        m = (s >= lo) & (s < lo + BIN)
        if m.sum() >= 8:
            cents.append(points[m].mean(0))
        lo += BIN
    return Vector(np.mean(cents, axis=0).tolist())


def nearest_on_segment(p: Vector, a: Vector, b: Vector) -> tuple[float, float]:
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return t, (a + ab * t - p).length


def main() -> int:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(GLB))
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    mw = arm.matrix_world
    inv = mw.inverted()

    targets = {}
    for side in "lr":
        bones = arm.data.bones
        shoulder = mw @ bones[f"upperarm_{side}"].head_local
        hand = mw @ bones[f"hand_{side}"].head_local
        axis = (hand - shoulder).normalized()
        pts = arm_points(side)
        s = (pts - np.array(shoulder)) @ np.array(axis)
        elbow = centre(pts, s, ELBOW_BAND)
        wrist = centre(pts, s, WRIST_BAND)
        targets[side] = (elbow, wrist)
        print(f"{side}: elbow {tuple(round(c, 3) for c in elbow)} "
              f"({(elbow - shoulder).length:.3f} from the shoulder), wrist "
              f"{tuple(round(c, 3) for c in wrist)}")

    # Re-aim in the REST pose, lengths kept.
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    chains = {}
    for side, (elbow, wrist) in targets.items():
        up, low, hand = eb[f"upperarm_{side}"], eb[f"lowerarm_{side}"], eb[f"hand_{side}"]
        l_up, l_low, l_hand = up.length, low.length, hand.length
        hand_dir = (hand.tail - hand.head).normalized()
        # Children of the hand (the fingers) ride along with it.
        finger_offsets = [(c, c.head - hand.head, c.tail - hand.head)
                          for c in hand.children_recursive]
        e_local, w_local = inv @ elbow, inv @ wrist
        up.tail = up.head + (e_local - up.head).normalized() * l_up
        low.head = up.tail
        low.tail = low.head + (w_local - low.head).normalized() * l_low
        old_hand_head = hand.head.copy()
        hand.head = low.tail
        hand.tail = hand.head + hand_dir * l_hand
        shift = hand.head - old_hand_head
        for c, _, _ in finger_offsets:
            c.head += shift
            c.tail += shift
        chains[side] = [mw @ up.head.copy(), mw @ up.tail.copy(),
                        mw @ low.tail.copy(), mw @ hand.tail.copy()]
    bpy.ops.object.mode_set(mode="OBJECT")

    # Re-split the arm weights along the new chain.
    for side, (s0, s1, s2, s3) in chains.items():
        l1 = (s1 - s0).length
        l2 = l1 + (s2 - s1).length
        segs = [(s0, s1, 0.0), (s1, s2, l1), (s2, s3, l2)]
        for o in bpy.data.objects:
            if o.type != "MESH":
                continue
            groups = [o.vertex_groups.get(f"{k}_{side}")
                      for k in ("upperarm", "lowerarm", "hand")]
            if None in groups:
                continue
            gidx = [g.index for g in groups]
            omw = o.matrix_world
            for v in o.data.vertices:
                w = {g.group: g.weight for g in v.groups}
                total = sum(w.get(i, 0.0) for i in gidx)
                if total <= 0.0:
                    continue
                p = omw @ v.co
                along, nearest = 0.0, float("inf")
                for a, b, base in segs:
                    t, d = nearest_on_segment(p, a, b)
                    if d < nearest:
                        along, nearest = base + (b - a).length * t, d
                w_up = 1.0 - smooth((along - (l1 - ELBOW_BLEND)) / (2 * ELBOW_BLEND))
                w_hand = smooth((along - (l2 - WRIST_BLEND)) / (2 * WRIST_BLEND))
                w_low = max(0.0, 1.0 - w_up - w_hand)
                for g, share in zip(groups, (w_up, w_low, w_hand)):
                    if share * total > 1e-4:
                        g.add([v.index], share * total, "REPLACE")
                    else:
                        g.remove([v.index])

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=str(GLB),
        export_format="GLB",
        use_selection=True,
        export_skins=True,
        export_animations=False,
        export_yup=True,
        export_image_format="AUTO",
    )
    print(f"wrote {GLB} ({GLB.stat().st_size / 1e6:.1f} MB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
