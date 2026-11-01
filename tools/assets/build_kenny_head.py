#!/usr/bin/env python3
"""Kenny Omega's head shape, photo-fitted from the owner's sheet onto Cody's head.

Kenny is built on Cody's model (KennyModel extends CodyModel). Two judge loops
on his texture took him to 6.9/10 (gauntlet/refs/characters/review/
kenny_face_judge.md) and left the gap in FORM: Cody's square jaw and chin,
his wide mouth, his nose. The owner, 28 Oct, chose the source for Kenny's own
head shape: the character sheet (gauntlet/refs/characters/
kenny_omega_sheet.png). So this is a photo-fit, the way face-builder tools
work:

* Landmarks are marked on the sheet's head photos: the front head shot
  (tools/blender/kenny_face_projection.py's LANDMARKS, marked there for the
  texture projection and read from it here, with FIT_MARKS for the shape)
  and the true profile in HAIR REFERENCES, "SIDE (RIGHT)" (SIDE below).
* The same landmarks on Cody's head: the front ones by casting each marked
  pixel of the projection's front render (its camera is known) onto his head;
  the profile ones off his own centre-line profile (MIDLINE).
* A scaled-orthographic camera is solved for each photo, and Kenny's 3D
  landmarks are solved as Cody's plus a displacement each -- jointly, by
  regularised least squares, alternating with the cameras. The front view
  constrains across and up, the profile depth and up; a profile point that
  is a front landmark seen side on shares its displacement (TWINS). The
  front photo is a close shot, so its marks are first flattened of its
  perspective (PHOTO_DISTANCE). The face is solved symmetric. The eyes are
  anchored: the eyeballs and eye bones stay where Cody's are. The jaw and
  chin marks are taken in off the beard (BEARDED): the photo's outline there
  is beard, not bone. Ears, temples and brows only place the cameras
  (CAMERA_ONLY).
* A thin-plate spline carries the landmark displacements to every vertex of
  the head's skin and the mouth's inside, held at zero over the scalp (under
  the curls, built on Cody's scalp), the back of the head and the neck, and
  damped round the eyeballs so the lids stay on them.

Writes game/resources/characters/kenny_head_shape.tres: each moved vertex's
rest position (Cody's, float32 exact) with its offset and its normal's
change. KennyFaceShape applies it at load, matching vertices by rest
position (the import compresses positions, so within a tolerance).

Run:  python3 tools/assets/build_kenny_head.py
Deterministic: same inputs, byte-identical output. Prints the fit's report:
the residuals per photo and the displacement per landmark.
"""
from __future__ import annotations

import ast
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import build_kenny_textures as tex  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
PROJECTION = REPO / "tools/blender/kenny_face_projection.py"
OUT = REPO / "game/resources/characters/kenny_head_shape.tres"
DATA_SCRIPT = "res://core/match/kenny_head_shape_data.gd"
HEAD = tex.HEAD_MATERIAL
MOUTH = "head_shared_inside_mouth_iw9"
EYE = "xmaterial_7d08cd4d239faf3"

## The profile: HAIR REFERENCES, "SIDE (RIGHT)" -- his right side, facing
## right -- in the pixels of the crop SIDE_BOX of the sheet, placed by eye on
## 5x and 7x gridded enlargements. Profile points are the face's outline
## against the dark ground.
SIDE_BOX = (1033, 558, 1183, 733)
SIDE = [
    ("eye_r_outer", 120.5, 74.5),
    ("ear_r_top", 75.0, 67.5),
    ("ear_r_bottom", 81.0, 100.0),
    ("glabella", 131.5, 61.0),
    ("nasion", 130.0, 66.5),
    ("pronasale", 143.6, 88.5),
    ("subnasale", 130.0, 95.0),
    ("labrale_sup", 137.1, 105.0),
    ("stomion", 132.4, 112.0),
    ("labrale_inf", 136.4, 115.7),
    ("labiomental", 134.3, 123.0),
    ("pogonion", 137.6, 130.7),
]
## The same profile points on Cody: on his OUTER profile -- the centre line's
## most forward point at each height -- the most forward (max) or deepest
## (min) point in a band of heights (m). Taken over all the centre line's
## vertices, "deepest" found the inside of a nostril and of the mouth. The
## centre line is x 0.004: his eyes sit at x 0.0359 and -0.0281.
MIDLINE_X = 0.004
MIDLINE = {
    "glabella": (1.725, 1.745, "max"),
    "nasion": (1.700, 1.728, "min"),
    "pronasale": (1.660, 1.690, "max"),
    "subnasale": (1.648, 1.668, "min"),
    "labrale_sup": (1.640, 1.652, "max"),
    "stomion": (1.636, 1.648, "min"),
    "labrale_inf": (1.622, 1.640, "max"),
    "labiomental": (1.608, 1.630, "min"),
    "pogonion": (1.595, 1.620, "max"),
}
## Front marks for the shape alone, added to or replacing the projection's
## (name, photo x, photo y, render x, render y). The nose's wings at their
## widest -- on the photo the outside of each ala against its crease, on Cody
## where the ala overhangs the cheek (the depth steps there along a row of
## rays through the projection's camera). And the nostrils re-marked at the
## middle of each dark nostril: the projection's marks sit wider, which is
## right for placing its paint but would pull them out past the alae.
FIT_MARKS = [
    ("alar_r", 110.5, 172.0, 466, 600),
    ("alar_l", 145.5, 172.0, 574, 600),
    ("nostril_r", 116.0, 176.0, 490, 605),
    ("nostril_l", 137.5, 176.0, 549, 605),
]
## Front landmarks that are hair, not head: left out of the shape.
EXCLUDED = {"hairline_mid", "hairline_r", "hairline_l"}
## Held where Cody's are: the eyes.
ANCHORED = {"eye_r_centre", "eye_r_inner", "eye_r_outer", "eye_l_centre", "eye_l_inner", "eye_l_outer"}
## Marked on the beard's outline: the skin is this far inside it (m), in off
## the outline the way it faces (x across him, y up, z forward), as that
## photo sees it -- so the front's chin comes up off the beard's lower edge
## and the profile's chin back off its front. (Taken off along Cody's 3D
## normal at the mark instead, the front's chin went back 8 mm, which the
## front cannot see, and kept the beard's length as chin: run 10.) The beard
## is short; it is longest at the chin, and under the lip it fills the dip.
BEARDED = {"jaw_r_mouth": (0.004, (-1.0, 0.0, 0.0)), "jaw_l_mouth": (0.004, (1.0, 0.0, 0.0)),
           "jaw_r_chin": (0.004, (-0.7, -0.7, 0.0)), "jaw_l_chin": (0.004, (0.7, -0.7, 0.0)),
           "chin": (0.006, (0.0, -1.0, 0.0)), "pogonion": (0.006, (0.0, 0.0, 1.0)),
           "labiomental": (0.005, (0.0, 0.0, 1.0))}
## Profile points that are a front landmark seen side on, a few mm apart on
## Cody: one displacement serves both, solved from both photos, each view on
## its own point. (Solved apart, each took only its own photo's word and the
## pair pulled up to 5 mm apart over 2-3 mm of lip and chin.)
TWINS = {"pronasale": "nose_tip", "labrale_sup": "lip_upper", "labrale_inf": "lip_lower",
         "pogonion": "chin"}
## Front landmarks on the centre line: held there, as the profile's are.
FRONT_MIDLINE = {"nose_bridge", "nose_tip", "lip_upper", "lip_lower", "chin"}
## Used to solve the cameras, not to shape the head: in his photos the ears
## and temples are under his curls, and their outline is hair (free, they
## drew his ears 1 cm in, into the curls). And the brows: on the photo they
## are marked at the top of the brow hair, on Cody mid-brow, so free they
## raised his brow 6 mm, a surprised look against his hooded lids (run 9).
CAMERA_ONLY = {"ear_r_top", "ear_r_bottom", "ear_l_top", "ear_l_bottom", "side_r_eye", "side_l_eye",
               "brow_r_outer", "brow_r_inner", "brow_l_inner", "brow_l_outer"}
## The profile points are on the centre line, Kenny's as Cody's: they do not
## move across. (Free to, the side view's slight turn let them slide 12-15 mm
## sideways to take up its error.) And the face is solved symmetric: each
## left/right pair moves as mirror images, so the front photo's slight turn
## goes to its camera, not into a nose 2 mm off centre (run 10).
ACROSS_HELD = 100.0
## How far each photo's camera stood from his face (m); a view not listed is
## taken as far off. The front head shot is a close one: on Cody's rigid
## landmarks a pinhole camera fits it best at 0.65-0.8 m (2.9 px rms, against
## 4.4 px for a distant camera), and solved as distant its perspective -- the
## nose large against the sides of the face -- came out as a jaw and cheeks
## 5 mm too narrow a side (run 10). The profile shows no preference.
PHOTO_DISTANCE = {"front": 0.75}
## How hard a landmark's displacement is held toward none, against the
## photos (a 1 m displacement costs REGULARISE x the camera's px per m).
REGULARISE = 0.35
FIT_ROUNDS = 40
## The dense field: zero over the scalp (above his hairline, round the front
## of the head), the back of the head and the neck; damped inside this far of
## each eyeball's centre; no vertex moved more than MAX_MOVE.
SCALP_CLEAR = 0.006
BACK_ANGLE = 110.0
NECK_BELOW = 1.585
ANCHOR_STEP = 0.02
EYE_DAMP = (0.014, 0.024)
MAX_MOVE = 0.012
TPS_SMOOTH = 1e-6


def projection_constants() -> dict:
    """The face projection's landmarks and camera, read from its source (it
    imports bpy, which this does not need)."""
    out = {}
    for node in ast.parse(PROJECTION.read_text()).body:
        target = node.targets[0] if isinstance(node, ast.Assign) else getattr(node, "target", None)
        name = getattr(target, "id", "")
        if name in ("LANDMARKS", "PHOTO_BOX", "RES", "CAM_DIST", "CAM_LENS", "CAM_Z"):
            out[name] = ast.literal_eval(node.value)
    return out


def front_marks(proj) -> list:
    """The front landmarks the fit uses: the projection's, with FIT_MARKS."""
    extra = {m[0]: m for m in FIT_MARKS}
    marks = [extra.pop(m[0], m) for m in proj["LANDMARKS"] if m[0] not in EXCLUDED]
    return marks + list(extra.values())


def ray_hit(origin, direction, pts, tris):
    """The first hit of a ray on a triangle mesh (point, triangle), or the
    mesh vertex nearest the ray if it misses (a silhouette landmark)."""
    a, b, c = pts[tris[:, 0]], pts[tris[:, 1]], pts[tris[:, 2]]
    e1, e2 = b - a, c - a
    p = np.cross(direction, e2)
    det = np.einsum("ij,ij->i", e1, p)
    ok = np.abs(det) > 1e-12
    inv = np.where(ok, 1.0 / np.where(ok, det, 1.0), 0.0)
    s = origin - a
    u = np.einsum("ij,ij->i", s, p) * inv
    q = np.cross(s, e1)
    v = (q @ direction) * inv
    t = np.einsum("ij,ij->i", e2, q) * inv
    hit = ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0)
    if hit.any():
        i = int(np.flatnonzero(hit)[np.argmin(t[hit])])
        return origin + direction * t[i], i
    rel = pts - origin
    along = rel @ direction
    dist = np.linalg.norm(rel - np.outer(along, direction), axis=1)
    j = int(np.argmin(np.where(along > 0, dist, np.inf)))
    tri = int(np.flatnonzero((tris == j).any(axis=1))[0])
    return pts[j], tri


def tri_normal(pts, tri):
    a, b, c = pts[tri]
    n = np.cross(b - a, c - a)
    return n / np.linalg.norm(n)


def cody_landmarks(proj, head, eye):
    """{name: (point, normal)} on Cody's head, front and profile."""
    pts, _, tris = head
    epts, _, etris = eye
    res = proj["RES"]
    f = proj["CAM_LENS"] / 36.0 * res
    cam = np.array([0.0, proj["CAM_Z"], proj["CAM_DIST"]])
    out = {}
    for name, _, _, rx, ry in front_marks(proj):
        d = np.array([(rx - res / 2) / f, -(ry - res / 2) / f, -1.0])
        d /= np.linalg.norm(d)
        mesh_pts, mesh_tris = (epts, etris) if name in ANCHORED else (pts, tris)
        p, i = ray_hit(cam, d, mesh_pts, mesh_tris)
        out[name] = (p, tri_normal(mesh_pts, mesh_tris[i]))
    profile = outer_profile(pts, tris)
    for name, (lo, hi, kind) in MIDLINE.items():
        band = profile[(profile[:, 1] >= lo) & (profile[:, 1] <= hi)]
        p = band[np.argmax(band[:, 2])] if kind == "max" else band[np.argmin(band[:, 2])]
        out[name] = (p, np.array([0.0, 0.0, 1.0]))
    return out


def outer_profile(pts, tris, step=0.0005):
    """His profile: the head cut by the centre plane x = MIDLINE_X, and at each
    height the cut's most forward point on the face. (Picking among vertices
    near the plane found the insides of the nostrils and the mouth wherever a
    height had no front vertex close enough.)"""
    x = pts[:, 0] - MIDLINE_X
    # Each triangle the plane crosses gives a segment between the two edges it
    # cuts; sampled along its length, so every height band sees the outline
    # (edge crossings alone left bands holding only a stray deep point).
    ends = []
    for i, j in ((0, 1), (1, 2), (2, 0)):
        a, b = tris[:, i], tris[:, j]
        t = np.clip(x[a] / np.where(x[a] == x[b], 1.0, x[a] - x[b]), 0.0, 1.0)[:, None]
        point = pts[a] + (pts[b] - pts[a]) * t
        ends.append((point, (x[a] < 0) != (x[b] < 0)))
    crosses = np.stack([e[1] for e in ends], 1)
    two = crosses.sum(1) == 2
    first = np.argmax(crosses, axis=1)
    last = 2 - np.argmax(crosses[:, ::-1], axis=1)
    pick = np.stack([e[0] for e in ends], 1)
    p0 = pick[np.arange(len(tris)), first][two]
    p1 = pick[np.arange(len(tris)), last][two]
    cut = np.concatenate([p0 + (p1 - p0) * f for f in np.linspace(0.0, 1.0, 6)])
    cut = cut[cut[:, 2] > -0.03]
    bins = np.floor(cut[:, 1] / step).astype(np.int64)
    out = []
    for b in np.unique(bins):
        row = cut[bins == b]
        out.append(row[np.argmax(row[:, 2])])
    return np.array(out)


def solve_camera(X, x):
    """Scaled orthographic camera M (2x3, orthogonal rows of equal norm) and t
    with x ~ X M^T + t, by least squares."""
    A = np.c_[X, np.ones(len(X))]
    sol, *_ = np.linalg.lstsq(A, x, rcond=None)
    M = sol[:3].T
    u, s, vt = np.linalg.svd(M, full_matrices=False)
    M = s.mean() * (u @ vt)
    t = (x - X @ M.T).mean(0)
    return M, t


def skin_marks(cam, P, x, outward, depths, distance):
    """Photo marks `x` of points `P` as a distant camera would place them on
    his skin: drawn toward the image of the points' centre by their depth
    when the camera stood `distance` away (its perspective undone), then in
    off the beard's outline by `depths`, against `outward` as the photo sees
    it."""
    M, t = cam
    if distance:
        forward = np.cross(M[0], M[1])
        forward /= np.linalg.norm(forward)
        c = P.mean(0)
        centre = M @ c + t
        x = centre + (x - centre) * ((distance + (P - c) @ forward) / distance)[:, None]
    seen = outward @ M.T
    seen /= np.maximum(np.linalg.norm(seen, axis=1, keepdims=True), 1e-12)
    return x - seen * (depths * np.linalg.norm(M[0]))[:, None]


def mirror(name: str) -> str:
    """The landmark across the face: eye_r_outer <-> eye_l_outer."""
    return "_".join({"r": "l", "l": "r"}.get(p, p) for p in name.split("_"))


def fit(cody, views):
    """Kenny's landmark displacements, and each view's camera and residuals."""
    names = sorted(n for n in cody if n not in TWINS)
    index = {n: i for i, n in enumerate(names)}
    D = np.zeros((len(names), 3))
    pairs = [(index[n], index[mirror(n)]) for n in names if "r" in n.split("_") and mirror(n) in index]
    # Per view, each mark: the displacement it sees, Cody's point under it,
    # the beard's depth there and which way its outline faces, and the mark.
    obs = {}
    for view, marks in views.items():
        ks = [index[TWINS.get(n, n)] for n in marks]
        P0 = np.array([cody[n][0] for n in marks])
        beard = [BEARDED.get(n, (0.0, (0.0, 0.0, 1.0))) for n in marks]
        depth = np.array([b[0] for b in beard])
        N = np.array([b[1] for b in beard], float)
        obs[view] = (ks, P0, N, depth, np.array(list(marks.values()), float))
    skin = {view: o[4] for view, o in obs.items()}
    cams = {}
    for _ in range(FIT_ROUNDS):
        for view, (ks, P0, N, depth, raw) in obs.items():
            P = P0 + D[ks]
            cams[view] = solve_camera(P, skin[view])
            skin[view] = skin_marks(cams[view], P, raw, N, depth, PHOTO_DISTANCE.get(view))
            cams[view] = solve_camera(P, skin[view])
        for i, n in enumerate(names):
            if n in ANCHORED:
                continue
            rows, rhs = [], []
            scale = 0.0
            for view, (ks, P0, _, _, _) in obs.items():
                M, t = cams[view]
                for j in np.flatnonzero(np.array(ks) == i):
                    rows.append(M)
                    rhs.append(skin[view][j] - t - M @ P0[j])
                    scale += np.linalg.norm(M[0])
            if not rows:
                continue
            mu = REGULARISE * scale / len(rows)
            held = n in MIDLINE or n in FRONT_MIDLINE
            A = np.vstack(rows + [mu * np.diag([ACROSS_HELD if held else 1.0, 1.0, 1.0])])
            b = np.concatenate(rhs + [np.zeros(3)])
            D[i] = np.linalg.lstsq(A, b, rcond=None)[0]
        for a, b in pairs:
            across = (D[a, 0] - D[b, 0]) / 2
            rest = (D[a, 1:] + D[b, 1:]) / 2
            D[a] = (across, *rest)
            D[b] = (-across, *rest)
    report = {}
    for view, (ks, P0, _, _, _) in obs.items():
        M, t = cams[view]
        err = np.linalg.norm((P0 + D[ks]) @ M.T + t - skin[view], axis=1)
        report[view] = (np.linalg.norm(M[0]), dict(zip(views[view], err)))
    disp = {n: D[index[n]] for n in names}
    disp.update({twin: disp[n] for twin, n in TWINS.items()})
    return disp, report


def anchors(head):
    """Zero-displacement points: over the scalp, round the back, the neck."""
    pts = np.unique(head[0].round(5), axis=0)
    theta = np.degrees(np.abs(np.arctan2(pts[:, 0] - MIDLINE_X, pts[:, 2] - tex.HEAD_AXIS_Z)))
    keep = ((pts[:, 1] > tex.hairline_at(theta) + SCALP_CLEAR) | (theta > BACK_ANGLE)
            | (pts[:, 1] < NECK_BELOW))
    pts = pts[keep]
    cells = np.floor(pts / ANCHOR_STEP).astype(np.int64)
    _, first = np.unique(cells, axis=0, return_index=True)
    return pts[np.sort(first)]


def thin_plate(centres, values, query):
    """The 3D thin-plate (biharmonic, phi = r) interpolant of `values` at
    `centres`, evaluated at `query`."""
    n = len(centres)
    K = np.linalg.norm(centres[:, None] - centres[None], axis=-1) + TPS_SMOOTH * np.eye(n)
    P = np.c_[np.ones(n), centres]
    A = np.block([[K, P], [P.T, np.zeros((4, 4))]])
    sol = np.linalg.solve(A, np.r_[values, np.zeros((4, 3))])
    out = np.empty((len(query), 3))
    for s in range(0, len(query), 4096):
        q = query[s:s + 4096]
        out[s:s + 4096] = np.linalg.norm(q[:, None] - centres[None], axis=-1) @ sol[:n] \
            + np.c_[np.ones(len(q)), q] @ sol[n:]
    return out


def vertex_normals(pts, tris):
    """Area-weighted normals, shared by every vertex at one position (UV-seam
    duplicates shade as one surface)."""
    key, inv = np.unique(pts.round(6), axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    n = np.zeros((len(key), 3))
    face = np.cross(pts[tris[:, 1]] - pts[tris[:, 0]], pts[tris[:, 2]] - pts[tris[:, 0]])
    for k in range(3):
        np.add.at(n, inv[tris[:, k]], face)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    return n[inv]


def fmt(a) -> str:
    return ", ".join("%.9g" % float(v) for v in np.asarray(a, np.float32).reshape(-1))


def main() -> int:
    proj = projection_constants()
    mesh = tex.glb_mesh()
    head, mouth, eye = mesh[HEAD], mesh[MOUTH], mesh[EYE]
    cody = cody_landmarks(proj, head, eye)
    front = {n: (x, y) for n, x, y, _, _ in front_marks(proj)}
    side = {n: (x, y) for n, x, y in SIDE}
    disp, report = fit(cody, {"front": front, "side": side})
    for n in CAMERA_ONLY:
        disp[n] = np.zeros(3)
    for view, (scale, errs) in report.items():
        print(f"{view}: {scale:.0f} px/m, residual mean {np.mean(list(errs.values())):.2f} px, "
              f"worst {max(errs, key=errs.get)} {max(errs.values()):.2f} px")
    for n in sorted(disp, key=lambda n: -np.linalg.norm(disp[n])):
        d = disp[n] * 1000
        print(f"  {n:14s} {np.linalg.norm(d):5.1f} mm  ({d[0]:+5.1f}, {d[1]:+5.1f}, {d[2]:+5.1f})")

    zero = anchors(head)
    names = sorted(disp)
    centres = np.r_[np.array([cody[n][0] for n in names]), zero]
    values = np.r_[np.array([disp[n] for n in names]), np.zeros((len(zero), 3))]
    eye_centres = [eye[0][np.sign(eye[0][:, 0] - MIDLINE_X) == s].mean(0) for s in (1.0, -1.0)]
    print(f"thin plate: {len(names)} landmarks, {len(zero)} zero anchors")

    rest, offset, normal_offset = [], [], []
    for pts, tris in ((head[0], head[2]), (mouth[0], mouth[2])):
        move = thin_plate(centres, values, pts)
        near = np.min([np.linalg.norm(pts - c, axis=1) for c in eye_centres], axis=0)
        move *= tex.smoothstep(EYE_DAMP[0], EYE_DAMP[1], near)[:, None]
        length = np.linalg.norm(move, axis=1, keepdims=True)
        move *= np.minimum(1.0, MAX_MOVE / np.maximum(length, 1e-12))
        dn = vertex_normals(pts + move, tris) - vertex_normals(pts, tris)
        keep = (np.linalg.norm(move, axis=1) > 1e-6) | (np.linalg.norm(dn, axis=1) > 1e-5)
        rest.append(pts[keep]); offset.append(move[keep]); normal_offset.append(dn[keep])
    rest, offset, normal_offset = (np.concatenate(a).astype(np.float32) for a in (rest, offset, normal_offset))
    # One entry per rest position, in a fixed order.
    _, first = np.unique(rest, axis=0, return_index=True)
    first = np.sort(first)
    rest, offset, normal_offset = rest[first], offset[first], normal_offset[first]
    print(f"baked {len(rest)} positions, largest move {np.linalg.norm(offset, axis=1).max() * 1000:.1f} mm")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(
        '[gd_resource type="Resource" script_class="KennyHeadShapeData" load_steps=2 format=3]\n\n'
        f'[ext_resource type="Script" path="{DATA_SCRIPT}" id="1_data"]\n\n'
        "[resource]\n"
        'script = ExtResource("1_data")\n'
        f"rest = PackedVector3Array({fmt(rest)})\n"
        f"offset = PackedVector3Array({fmt(offset)})\n"
        f"normal_offset = PackedVector3Array({fmt(normal_offset)})\n")
    print(f"wrote {OUT.relative_to(REPO)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

