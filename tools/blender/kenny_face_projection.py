#!/usr/bin/env python3
"""Kenny Omega's face, projected from the owner's sheet onto Cody's head UVs.

Kenny is built on Cody's model (KennyModel extends CodyModel; the owner,
27 Oct: "use Cody's body for Kenny"). The face is Kenny's: the front head
shot on the owner's reference sheet (gauntlet/refs/characters/
kenny_omega_sheet.png, HEAD REFERENCES, top left) is projected onto Cody's
head mesh and written into its texture space.

How, without a camera solve:
* Cody's head is rendered straight on (FRONT camera) twice: once with its own
  texture, for landmarking, and once with its UVs as colour (the UV pass), so
  every pixel of the render knows which texel it shows. A third pass gives
  how squarely each pixel faces the camera.
* Matching landmarks -- eyes, brows, nose, mouth, chin, jaw, hairline, ears --
  are marked on the photo and on the textured render (LANDMARKS). The photo is
  warped onto the render, triangle by triangle (a piecewise-affine warp over
  their Delaunay triangulation).
* Each render pixel then writes its warped photo colour into the texel its
  UV names, weighted by how squarely it faced the camera; the gaps between
  splats are filled by pulling colour in from coarser levels (push-pull).

Writes game/assets/characters/kenny_face_projected.png: RGBA in the head
texture's 2048 square, the projected colour in RGB and its weight in alpha.
tools/assets/build_kenny_textures.py composes it with Cody's skin detail.

  python3 tools/blender/kenny_face_projection.py render
      writes the landmarking render to the scratch dir given by KENNY_SCRATCH
  python3 tools/blender/kenny_face_projection.py
      writes the projection

Deterministic: same inputs, byte-identical outputs.
"""
from __future__ import annotations

import os
import pathlib
import sys

import bpy  # noqa: E402  (first: it provides bmesh and mathutils)
import bmesh  # noqa: E402
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import bpy_exit  # noqa: E402

REPO = pathlib.Path(__file__).resolve().parents[2]
SOURCE = REPO / "game/assets/characters/cody_rhodes.glb"
SHEET = REPO / "gauntlet/refs/characters/kenny_omega_sheet.png"
OUT = REPO / "game/assets/characters/kenny_face_projected.png"
HEAD_MATERIAL = "xmaterial_c3d4d9e78b44a79"
## The sheet's front head shot (HEAD REFERENCES, top left), in sheet pixels.
PHOTO_BOX = (1044, 34, 1290, 280)
## The render: square, straight on to his face.
RES = 1024
TEX = 2048
## Camera in front of his face, Blender space (glTF +Z forward is Blender -Y).
CAM_DIST = 1.4
CAM_LENS = 135.0
CAM_Z = 1.705

## Landmarks: (name, photo x, photo y, render x, render y). Photo coordinates
## are in the 246-pixel crop of PHOTO_BOX; render coordinates in the RES
## square, placed by eye on 4x-enlarged, gridded copies of each.
LANDMARKS: list[tuple[str, float, float, float, float]] = [
    ("eye_r_centre", 93.0, 132.0, 440, 490),
    ("eye_r_inner", 107.5, 133.0, 478, 492),
    ("eye_r_outer", 80.5, 131.0, 400, 488),
    ("eye_l_centre", 157.0, 130.0, 605, 490),
    ("eye_l_inner", 143.75, 131.25, 565, 492),
    ("eye_l_outer", 170.0, 129.5, 643, 488),
    ("brow_r_outer", 75.0, 117.5, 385, 455),
    ("brow_r_inner", 110.0, 116.25, 485, 462),
    ("brow_l_inner", 140.0, 115.5, 558, 462),
    ("brow_l_outer", 175.0, 113.75, 665, 452),
    ("nose_bridge", 126.25, 132.5, 520, 495),
    ("nose_tip", 126.25, 170.0, 520, 590),
    ("nostril_r", 113.75, 175.0, 490, 603),
    ("nostril_l", 140.0, 175.0, 550, 603),
    ("mouth_r", 105.0, 203.75, 452, 683),
    ("mouth_l", 147.5, 203.75, 590, 683),
    ("lip_upper", 126.25, 198.75, 520, 668),
    ("lip_lower", 126.25, 210.0, 520, 700),
    ("chin", 126.0, 238.0, 520, 762),
    ("hairline_mid", 125.0, 56.25, 520, 330),
    ("hairline_r", 82.5, 75.0, 365, 330),
    ("hairline_l", 180.0, 62.5, 690, 330),
    ("side_r_eye", 63.75, 130.0, 330, 490),
    ("side_l_eye", 193.75, 128.75, 712, 490),
    ("ear_r_top", 46.25, 117.5, 285, 455),
    ("ear_r_bottom", 52.5, 167.5, 300, 600),
    ("ear_l_top", 208.75, 112.5, 752, 460),
    ("ear_l_bottom", 202.5, 165.0, 735, 600),
    ("jaw_r_mouth", 72.5, 200.0, 370, 690),
    ("jaw_l_mouth", 185.0, 197.5, 680, 690),
    ("jaw_r_chin", 95.0, 230.0, 430, 745),
    ("jaw_l_chin", 160.0, 228.75, 612, 745),
    ("cheek_r", 62.5, 165.0, 345, 590),
    ("cheek_l", 193.75, 162.5, 700, 590),
]


def load_head():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    body = bpy.data.objects["Body"]
    head_mat = [i for i, m in enumerate(body.data.materials) if m.name == HEAD_MATERIAL][0]
    bm = bmesh.new()
    bm.from_mesh(body.data)
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.material_index != head_mat],
                     context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(body.data)
    bm.free()
    # The pose the model was supplied in: drop the armature so nothing deforms.
    for o in list(bpy.data.objects):
        if o != body:
            bpy.data.objects.remove(o, do_unlink=True)
    body.modifiers.clear()
    return body


def camera():
    cam = bpy.data.cameras.new("Front")
    cam.lens = CAM_LENS
    cam.sensor_width = 36.0
    obj = bpy.data.objects.new("Front", cam)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = (0.0, -CAM_DIST, CAM_Z)
    obj.rotation_euler = (np.pi / 2, 0.0, 0.0)
    bpy.context.scene.camera = obj


def emission_material(name, build):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    nt.links.new(em.outputs[0], out.inputs[0])
    build(nt, em)
    return mat


def render(body, mat, path, exr=False):
    body.data.materials.clear()
    body.data.materials.append(mat)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 1
    scene.cycles.use_denoising = False
    scene.cycles.pixel_filter_type = "BOX"
    scene.cycles.filter_width = 0.01
    scene.cycles.seed = 0
    scene.render.resolution_x = RES
    scene.render.resolution_y = RES
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.dither_intensity = 0.0
    if exr:
        scene.render.image_settings.file_format = "OPEN_EXR"
        scene.render.image_settings.color_depth = "32"
        scene.render.image_settings.color_mode = "RGBA"
    else:
        scene.render.image_settings.file_format = "PNG"
        scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def textured(nt, em):
    img = bpy.data.images.load(str(REPO / "game/assets/characters/cody_rhodes_ximage_d17c32323759dea.png"))
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs[0], em.inputs[0])


def uv_pass(nt, em):
    uv = nt.nodes.new("ShaderNodeUVMap")
    nt.links.new(uv.outputs[0], em.inputs[0])


def facing_pass(nt, em):
    lw = nt.nodes.new("ShaderNodeLayerWeight")
    inv = nt.nodes.new("ShaderNodeMath")
    inv.operation = "SUBTRACT"
    inv.inputs[0].default_value = 1.0
    nt.links.new(lw.outputs["Facing"], inv.inputs[1])
    nt.links.new(inv.outputs[0], em.inputs[0])


def read_exr(path):
    img = bpy.data.images.load(str(path))
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    bpy.data.images.remove(img)
    return px


def delaunay(points):
    """Bowyer-Watson over a few dozen landmarks: triangles as index triples."""
    pts = [tuple(p) for p in points]
    big = 1e5
    sup = [(-big, -big), (big, -big), (0.0, big)]
    allp = pts + sup
    n = len(pts)
    tris = [(n, n + 1, n + 2)]

    def circ(t):
        (ax, ay), (bx, by), (cx, cy) = allp[t[0]], allp[t[1]], allp[t[2]]
        d = 2 * (ax * (by - cy) + bx * (cy - ay) + cx * (ay - by))
        ux = ((ax * ax + ay * ay) * (by - cy) + (bx * bx + by * by) * (cy - ay)
              + (cx * cx + cy * cy) * (ay - by)) / d
        uy = ((ax * ax + ay * ay) * (cx - bx) + (bx * bx + by * by) * (ax - cx)
              + (cx * cx + cy * cy) * (bx - ax)) / d
        return ux, uy, (ax - ux) ** 2 + (ay - uy) ** 2

    for i, (px, py) in enumerate(pts):
        bad = []
        for t in tris:
            ux, uy, r2 = circ(t)
            if (px - ux) ** 2 + (py - uy) ** 2 < r2:
                bad.append(t)
        edges = {}
        for t in bad:
            for e in ((t[0], t[1]), (t[1], t[2]), (t[2], t[0])):
                k = tuple(sorted(e))
                edges[k] = edges.get(k, 0) + 1
        tris = [t for t in tris if t not in bad]
        for (a, b), c in sorted(edges.items()):
            if c == 1:
                tris.append((a, b, i))
    return [t for t in tris if max(t) < n]


def warp_photo(photo, src, dst):
    """The photo moved onto the render frame, triangle by triangle (inverse
    mapping: every render pixel inside a triangle samples the photo through
    that triangle's affine map)."""
    out = np.zeros((RES, RES, 3), np.float32)
    covered = np.zeros((RES, RES), bool)
    ys, xs = np.mgrid[0:RES, 0:RES]
    ph, pw = photo.shape[:2]
    for t in delaunay(dst):
        d = np.array([dst[i] for i in t], np.float64)
        s = np.array([src[i] for i in t], np.float64)
        x0, y0 = np.floor(d.min(0)).astype(int)
        x1, y1 = np.ceil(d.max(0)).astype(int)
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, RES - 1), min(y1, RES - 1)
        if x1 < x0 or y1 < y0:
            continue
        gx = xs[y0:y1 + 1, x0:x1 + 1].astype(np.float64)
        gy = ys[y0:y1 + 1, x0:x1 + 1].astype(np.float64)
        # Barycentrics of each pixel in the destination triangle.
        m = np.array([[d[1, 0] - d[0, 0], d[2, 0] - d[0, 0]],
                      [d[1, 1] - d[0, 1], d[2, 1] - d[0, 1]]])
        if abs(np.linalg.det(m)) < 1e-9:
            continue
        inv = np.linalg.inv(m)
        rx, ry = gx - d[0, 0], gy - d[0, 1]
        b1 = inv[0, 0] * rx + inv[0, 1] * ry
        b2 = inv[1, 0] * rx + inv[1, 1] * ry
        inside = (b1 >= -1e-6) & (b2 >= -1e-6) & (b1 + b2 <= 1 + 1e-6)
        sx = s[0, 0] + b1 * (s[1, 0] - s[0, 0]) + b2 * (s[2, 0] - s[0, 0])
        sy = s[0, 1] + b1 * (s[1, 1] - s[0, 1]) + b2 * (s[2, 1] - s[0, 1])
        # Bilinear sample of the photo.
        sx = np.clip(sx, 0, pw - 1.001)
        sy = np.clip(sy, 0, ph - 1.001)
        ix, iy = np.floor(sx).astype(int), np.floor(sy).astype(int)
        fx, fy = (sx - ix)[..., None], (sy - iy)[..., None]
        c = (photo[iy, ix] * (1 - fx) * (1 - fy) + photo[iy, ix + 1] * fx * (1 - fy)
             + photo[iy + 1, ix] * (1 - fx) * fy + photo[iy + 1, ix + 1] * fx * fy)
        region = out[y0:y1 + 1, x0:x1 + 1]
        region[inside] = c[inside]
        covered[y0:y1 + 1, x0:x1 + 1] |= inside
    return out, covered


def push_pull(col, w):
    """Fill the holes between splats: average down to coarse levels, then pull
    each level's colour into the finer level's empty texels."""
    levels = [(col * w[..., None], w)]
    while levels[-1][1].shape[0] > 8:
        c, ww = levels[-1]
        h = c.shape[0] // 2
        c2 = c.reshape(h, 2, h, 2, 3).sum((1, 3))
        w2 = ww.reshape(h, 2, h, 2).sum((1, 3))
        levels.append((c2, w2))
    c, ww = levels[-1]
    filled = c / np.maximum(ww, 1e-6)[..., None]
    for c, ww in reversed(levels[:-1]):
        up = np.repeat(np.repeat(filled, 2, 0), 2, 1)
        k = np.clip(ww, 0, 1)[..., None]
        own = c / np.maximum(ww, 1e-6)[..., None]
        filled = own * k + up * (1 - k)
    return filled


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    scratch = pathlib.Path(os.environ.get("KENNY_SCRATCH", "/tmp/kenny_face"))
    scratch.mkdir(parents=True, exist_ok=True)
    body = load_head()
    camera()
    if args and args[0] == "render":
        render(body, emission_material("Tex", textured), scratch / "front_render.png")
        print("wrote", scratch / "front_render.png")
        return 0
    if len(LANDMARKS) < 12:
        print("LANDMARKS not filled in")
        return 1
    render(body, emission_material("UV", uv_pass), scratch / "uv.exr", exr=True)
    render(body, emission_material("Facing", facing_pass), scratch / "facing.exr", exr=True)
    uvp = read_exr(scratch / "uv.exr")
    fac = read_exr(scratch / "facing.exr")
    sheet = Image.open(SHEET).convert("RGB").crop(PHOTO_BOX)
    photo = np.asarray(sheet, np.float32) / 255.0
    src = [(l[1], l[2]) for l in LANDMARKS]
    dst = [(l[3], l[4]) for l in LANDMARKS]
    warped, covered = warp_photo(photo, src, dst)
    alive = covered & (uvp[..., 3] > 0.5)
    # Weight: how squarely the surface faced the photo's camera, eased so
    # the cheeks' sides, seen edge-on, give way to Cody's own texture.
    weight = np.clip((fac[..., 0] - 0.35) / 0.4, 0, 1) ** 1.5 * alive
    u = np.clip(uvp[..., 0], 0, 1)
    v = np.clip(uvp[..., 1], 0, 1)
    tx = np.minimum((u * TEX).astype(int), TEX - 1)
    ty = np.minimum(((1 - v) * TEX).astype(int), TEX - 1)
    acc = np.zeros((TEX, TEX, 3), np.float64)
    wacc = np.zeros((TEX, TEX), np.float64)
    m = weight > 0
    np.add.at(acc, (ty[m], tx[m]), warped[m] * weight[m][:, None])
    np.add.at(wacc, (ty[m], tx[m]), weight[m])
    col = acc / np.maximum(wacc, 1e-9)[..., None]
    # Colour into the texels the splats missed (push-pull); the weight only
    # across those gaps -- a render pixel lands on about two texels in each
    # direction -- then feathered. (Spread by push-pull like the colour, the
    # weight filled whole coarse blocks round the face with the photo.)
    filled = push_pull(col.astype(np.float32), np.clip(wacc, 0, 1).astype(np.float32))
    w8 = Image.fromarray((np.clip(wacc, 0, 1) * 255 + 0.5).astype(np.uint8), "L")
    w8 = w8.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(3))
    wfill = np.asarray(w8, np.float32) / 255.0
    rgba = np.dstack([np.clip(filled, 0, 1), np.clip(wfill, 0, 1)])
    Image.fromarray((rgba * 255 + 0.5).astype(np.uint8), "RGBA").save(OUT, optimize=False)
    print("wrote", OUT)
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main())
