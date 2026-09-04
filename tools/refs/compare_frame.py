#!/usr/bin/env python3
"""Compare one of our frames against a reference still, whole-frame.

measure_frame.py and measure_silhouette.py both measure *named regions* --
this mat, that wrestler. They are the right tools for VISUAL_BAR.md priority
1, and they say nothing at all about priorities 2 and 3 (lighting
consistency, material believability), which are properties of the whole
image. Nothing in this repo compared a whole frame to a reference frame, so
those two priorities had no measurement behind them and went two rounds
recorded as UNJUDGED.

This does not attempt a pixel diff. Our frame and a broadcast still share no
geometry, no pose and no camera, so per-pixel distance would measure the
framing and nothing else. What it compares is the *statistics a look is made
of*, all of which survive different content:

  tone        Luminance percentiles and histogram distance. A scene lit like
              broadcast puts its pixels in the same places on the curve.
  contrast    RMS contrast, globally and in tiles. Flat lighting shows up
              here as a tile-contrast far below the reference's.
  colour      Mean saturation and the warm/cool balance. Ours reading grey
              against a reference that reads blue is a material or a
              white-balance defect, and this is where it appears.
  detail      Edge density at two scales: how much of the frame carries
              modelled or textured incident. Untextured flat boxes score
              near zero here while a real arena does not.

Every figure is a distribution over the frame, so a difference in what is
*in* the frame moves them far less than a difference in how it is lit and
surfaced -- which is the thing being judged.

Two corrections, both found by a builder challenging this tool's output
rather than by the tool itself, and both worth stating because the first
version of this file reported a gap roughly twice its real size:

**Both frames are resampled to a common resolution first.** `edge_density`
counts pixels whose neighbours differ, so it is a *rate per pixel* and a
render with four times the reference's pixel count spreads the same incident
over four times the area. Measured on one unchanged frame: fine detail
0.147 at our native 1280x720, and 0.315 downscaled to the reference's
640x364. Nothing about the image changed. The larger frame is always
downscaled to the smaller -- upscaling invents no detail but does change
gradient statistics, so it would be the same error with the sign flipped.

**Edges are counted on gamma-encoded luminance, not linear.** The threshold
is an absolute gradient, and a surface can never produce a gradient larger
than its own level: at the 0.014-0.020 linear the house-lit arena renders
at, a 0.010 linear threshold demands 50-70% local contrast just to
register, while the 0.46 mat clears it with 2%. Measured on our own frame,
47% of which is below 0.03 linear: 0.089 of dark pixels registered as edges
against 0.199 of bright ones -- a 2.2x bias against exactly the surfaces the
arena is made of. Gamma-encoding matches the eye's own compression and
measures a dim textured surface and a bright one on the same terms.

The deficit survived both corrections: measured like-for-like the reference
carries about 1.8x our edge density, stable across every threshold tried.
It was the *size* of the gap that was wrong, not its direction.

Letterboxing is detected and cropped before anything is measured.
gauntlet/refs/frames/wide_standoff_broadcast_angle.jpg is letterboxed and
its bars are most of the frame (VISUAL_BAR.md records it reading void 0.251
for that reason alone); measuring through them would compare our render to a
black border.

Usage:
  compare_frame.py <ours.png> [reference.jpg] [--sheet out.png] [--json]

The reference defaults to the wide broadcast standoff, the frame
VISUAL_BAR.md's own silhouette table is read off.
"""
import argparse
import json
import sys
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except ImportError:  # pragma: no cover - tooling, not gameplay
    print("compare_frame.py needs pillow and numpy: pip install pillow numpy",
          file=sys.stderr)
    raise SystemExit(1)

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REFERENCE = (REPO_ROOT / "gauntlet" / "refs" / "frames"
                     / "wide_standoff_broadcast_angle.jpg")

# Rec. 709 luminance weights, applied to linearised sRGB -- the same
# convention measure_frame.py and measure_silhouette.py use, so figures from
# the three tools are comparable.
LUMA_WEIGHTS = np.array([0.2126, 0.7152, 0.0722])

# A row/column whose every pixel sits below this (in 0-255 sRGB) is a
# letterbox bar, not content.
LETTERBOX_LEVEL = 12

# Edge-detection thresholds, applied to gamma-encoded luminance. Calibrated
# so the reference still lands mid-range rather than saturated: at these
# values the wide standoff reads 0.614 fine and 0.343 coarse.
EDGE_FINE = 0.020
EDGE_COARSE = 0.060

# Tile grid for local contrast. 12x8 over a 16:9 frame gives roughly square
# tiles big enough to hold a lighting gradient and small enough that a flat
# region cannot hide inside one.
TILE_COLS = 12
TILE_ROWS = 8


def srgb_to_linear(a: np.ndarray) -> np.ndarray:
    return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)


def load(path: Path) -> np.ndarray:
    """RGB float 0-1 in sRGB space, letterbox cropped."""
    img = Image.open(path).convert("RGB")
    a = np.asarray(img, dtype=np.float64) / 255.0
    return crop_letterbox(a)


def crop_letterbox(a: np.ndarray) -> np.ndarray:
    level = LETTERBOX_LEVEL / 255.0
    lit = a.max(axis=2) > level
    rows = np.flatnonzero(lit.any(axis=1))
    cols = np.flatnonzero(lit.any(axis=0))
    if rows.size == 0 or cols.size == 0:
        return a
    return a[rows[0]:rows[-1] + 1, cols[0]:cols[-1] + 1]


def luminance(a: np.ndarray) -> np.ndarray:
    return srgb_to_linear(a) @ LUMA_WEIGHTS


def saturation(a: np.ndarray) -> np.ndarray:
    """HSV saturation. Reads how colourful the frame is, independent of how
    bright it is -- a desaturated grey-blue mat and a broadcast blue one
    differ here even when their luminance matches."""
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    return np.where(mx > 1e-6, (mx - mn) / np.maximum(mx, 1e-6), 0.0)


def warm_cool(a: np.ndarray) -> float:
    """Positive is warm (red over blue), negative cool. Mean over the frame,
    normalised by mean level so exposure does not leak into it."""
    mean = a.reshape(-1, 3).mean(axis=0)
    level = max(mean.mean(), 1e-6)
    return float((mean[0] - mean[2]) / level)


def edge_density(lum: np.ndarray, threshold: float) -> float:
    """Fraction of pixels sitting on a luminance edge, counted on
    gamma-encoded luminance so a dim surface and a bright one are measured on
    the same terms -- see the module docstring on why linear was wrong."""
    lum = np.clip(lum, 0.0, 1.0) ** (1.0 / 2.2)
    gx = np.zeros_like(lum)
    gy = np.zeros_like(lum)
    gx[:, 1:-1] = lum[:, 2:] - lum[:, :-2]
    gy[1:-1, :] = lum[2:, :] - lum[:-2, :]
    mag = np.hypot(gx, gy)
    return float((mag > threshold).mean())


def tile_contrast(lum: np.ndarray) -> float:
    """Mean over tiles of each tile's RMS contrast (sd / mean). Global RMS
    contrast cannot tell a scene with real light falloff from one that is
    uniformly lit but has a bright object in it; per-tile can."""
    h, w = lum.shape
    ys = np.linspace(0, h, TILE_ROWS + 1).astype(int)
    xs = np.linspace(0, w, TILE_COLS + 1).astype(int)
    out = []
    for y0, y1 in zip(ys[:-1], ys[1:]):
        for x0, x1 in zip(xs[:-1], xs[1:]):
            tile = lum[y0:y1, x0:x1]
            if tile.size == 0:
                continue
            m = tile.mean()
            if m <= 1e-6:
                out.append(0.0)
            else:
                out.append(float(tile.std() / m))
    return float(np.mean(out)) if out else 0.0


def histogram_distance(a: np.ndarray, b: np.ndarray, bins: int = 64) -> float:
    """Earth-mover distance between two luminance histograms, on a log-ish
    scale so shadow detail is not swamped by the highlights. 0 is identical,
    1 is maximally far apart."""
    edges = np.linspace(0.0, 1.0, bins + 1)
    ha, _ = np.histogram(np.clip(a, 0, 1) ** (1 / 2.2), bins=edges)
    hb, _ = np.histogram(np.clip(b, 0, 1) ** (1 / 2.2), bins=edges)
    ha = ha / max(ha.sum(), 1)
    hb = hb / max(hb.sum(), 1)
    return float(np.abs(np.cumsum(ha) - np.cumsum(hb)).sum() / bins)


def common_size(a: Path, b: Path) -> tuple[int, int]:
    """The smaller of the two frames, post-letterbox-crop. Every metric is
    read at this size so neither frame's pixel count flatters it."""
    ra, rb = load(a), load(b)
    if ra.shape[0] * ra.shape[1] <= rb.shape[0] * rb.shape[1]:
        return ra.shape[1], ra.shape[0]
    return rb.shape[1], rb.shape[0]


def measure(path: Path, size: tuple[int, int] | None = None) -> dict:
    rgb = load(path)
    if size and (rgb.shape[1], rgb.shape[0]) != size:
        rgb = np.asarray(
            Image.fromarray((rgb * 255).astype(np.uint8)).resize(
                size, Image.LANCZOS), dtype=np.float64) / 255.0
    lum = luminance(rgb)
    sat = saturation(rgb)
    flat = lum.ravel()
    pct = np.percentile(flat, [5, 25, 50, 75, 95])
    return {
        "path": str(path),
        "size": f"{rgb.shape[1]}x{rgb.shape[0]}",
        "_lum": flat,
        "mean_luminance": float(flat.mean()),
        "p05": float(pct[0]), "p25": float(pct[1]), "p50": float(pct[2]),
        "p75": float(pct[3]), "p95": float(pct[4]),
        "tile_contrast": tile_contrast(lum),
        "mean_saturation": float(sat.mean()),
        "warm_cool": warm_cool(rgb),
        "edge_density_fine": edge_density(lum, EDGE_FINE),
        "edge_density_coarse": edge_density(lum, EDGE_COARSE),
    }


# name -> (label, how much of a gap is worth a critic's attention)
METRICS = [
    ("mean_luminance", "mean luminance", 0.030),
    ("p05", "shadows (p05)", 0.020),
    ("p50", "midtone (p50)", 0.040),
    ("p95", "highlights (p95)", 0.060),
    ("tile_contrast", "local contrast", 0.150),
    ("mean_saturation", "saturation", 0.060),
    ("warm_cool", "warm/cool balance", 0.100),
    ("edge_density_fine", "fine detail", 0.060),
    ("edge_density_coarse", "coarse detail", 0.040),
]


def contact_sheet(ours: Path, ref: Path, out: Path) -> None:
    a = Image.fromarray((load(ours) * 255).astype(np.uint8))
    b = Image.fromarray((load(ref) * 255).astype(np.uint8))
    height = 480
    a = a.resize((int(a.width * height / a.height), height), Image.LANCZOS)
    b = b.resize((int(b.width * height / b.height), height), Image.LANCZOS)
    sheet = Image.new("RGB", (a.width + b.width + 12, height), (18, 18, 20))
    sheet.paste(a, (0, 0))
    sheet.paste(b, (a.width + 12, 0))
    sheet.save(out)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("ours")
    ap.add_argument("reference", nargs="?", default=str(DEFAULT_REFERENCE))
    ap.add_argument("--sheet", help="write a side-by-side PNG here")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    args = ap.parse_args()

    size = common_size(Path(args.ours), Path(args.reference))
    ours = measure(Path(args.ours), size)
    ref = measure(Path(args.reference), size)
    hist = histogram_distance(ours.pop("_lum"), ref.pop("_lum"))

    rows = []
    for key, label, tolerance in METRICS:
        delta = ours[key] - ref[key]
        rows.append({
            "metric": key, "label": label,
            "ours": ours[key], "reference": ref[key],
            "delta": delta, "tolerance": tolerance,
            "flagged": abs(delta) > tolerance,
        })

    if args.sheet:
        contact_sheet(Path(args.ours), Path(args.reference), Path(args.sheet))

    if args.json:
        print(json.dumps({"ours": ours, "reference": ref,
                          "histogram_distance": hist, "metrics": rows}, indent=2))
        return 0

    print(f"ours      {ours['path']}  {ours['size']}")
    print(f"reference {ref['path']}  {ref['size']}")
    print(f"          (both measured at {size[0]}x{size[1]})")
    print()
    print(f"  {'':22}{'ours':>9}{'ref':>9}{'delta':>9}")
    for r in rows:
        mark = "  <-- " if r["flagged"] else ""
        print(f"  {r['label']:22}{r['ours']:9.3f}{r['reference']:9.3f}"
              f"{r['delta']:+9.3f}{mark}")
    print()
    print(f"  luminance histogram distance  {hist:.4f}"
          f"   (0 = same tonal distribution)")
    flagged = [r["label"] for r in rows if r["flagged"]]
    if flagged:
        print(f"\n  outside tolerance: {', '.join(flagged)}")
    else:
        print("\n  every metric inside tolerance")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
