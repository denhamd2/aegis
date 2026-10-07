"""Fits the 2K26 in-match hard cam in THIS ring's units (gauntlet/refs/match_engine_2k26.md, section 4).

A square-on pinhole camera (no yaw or roll) is solved for focal length, height above the mat,
distance from the ring centre and downward tilt, against the image rows of the far and near ropes
(bottom, middle, top) and, optionally, the pixel span of the far top rope's ends -- measured on
1280x720 frames of raw/video/cody_roman_2k26.mp4 -- using this ring's rope heights and rope line
(core/ring/ring_builder.gd: ropes 0.50 / 0.85 / 1.20 m, rope line 3.1 m, rope ends 2.80 m).
Fitting in our units is the point: it is the camera that reproduces 2K26's picture in our ring.

    python3 tools/refs/fit_hard_cam.py        # ~6 min per frame, brute-force grid, numpy only

Measured inputs (rows found as runs of near-white low-saturation pixels down a clear column):
  340 s  far 359.5/280/199.5  near -/443/253.5
  360 s  far 349.5/281/213    near -/391/255.5
  600 s  far 403.5/324.5/245  near -/548.5/361.5
(The near bottom rope is left out: at these angles its row is confused with its shadow on the
apron, and including it was what pushed the residual from ~1 px to 11-14 px.)
"""
import numpy as np
ROPE = np.array([0.5, 0.85, 1.2]); Z = 3.1; END = 2.80


def fit_frame(far_rows, near_rows, ends=None, cy=360, cx=640):
    """Square-on camera (no yaw/roll) in OUR ring's units. far/near_rows: image
    rows of the bottom, middle, top rope (None where unseen). ends: (u_left,
    u_right) of the far top rope's ends."""
    h = np.arange(0.8, 6.0, 0.02)[:, None, None]
    D = np.arange(3.6, 20.0, 0.05)[None, :, None]
    th = np.radians(np.arange(-5, 35, 0.25))[None, None, :]
    best = None
    for F in np.arange(400, 3000, 10.0):
        err = np.zeros((h.shape[0], D.shape[1], th.shape[2])); n = 0
        for rows, dz in ((far_rows, Z), (near_rows, -Z)):
            for Y, row in zip(ROPE, rows):
                if row is None:
                    continue
                a = np.arctan2(h - Y, D + dz)
                err = err + (F * np.tan(a - th) - (row - cy)) ** 2; n += 1
        if ends is not None:
            depth = (D + Z) * np.cos(th) + (h - 1.2) * np.sin(th)
            err = err + (F * 2 * END / depth - (ends[1] - ends[0])) ** 2; n += 1
        i = np.unravel_index(np.argmin(err), err.shape)
        if best is None or err[i] < best[0]:
            best = (err[i], F, h.flat[i[0]], D.flat[i[1]], th.flat[i[2]], n)
    e, F, hv, Dv, tv, n = best
    res = {"rms": float(np.sqrt(e / n)), "F": F, "vfov": 2 * np.degrees(np.arctan(cy / F)),
           "h": hv, "D": Dv, "tilt": np.degrees(tv)}
    if ends is not None:
        depth = (Dv + Z) * np.cos(tv) + (hv - 1.2) * np.sin(tv)
        res["lateral"] = ((ends[0] + ends[1]) / 2 - cx) * depth / F
    return res


def show(name, r):
    s = (f"{name}: rms {r['rms']:.1f}px | vFOV {r['vfov']:.1f} deg | height {r['h']:.2f} m | "
         f"{r['D']:.2f} m from ring centre ({r['D'] - 3.1:.2f} m outside the near ropes) | "
         f"tilt down {r['tilt']:.1f} deg")
    if 'lateral' in r:
        s += f" | lateral {r['lateral']:+.2f} m"
    print(s)


if __name__ == "__main__":
    show("340 s", fit_frame([359.5, 280, 199.5], [None, 443, 253.5]))
    show("360 s", fit_frame([349.5, 281, 213], [None, 391, 255.5]))
    show("600 s", fit_frame([403.5, 324.5, 245], [None, 548.5, 361.5]))
