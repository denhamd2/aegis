#!/usr/bin/env python3
"""Recover photographic UV detail for the existing seeded ringside crowd.

blender --background --python tools/blender/textured_crowd.py -- --out PATH

The original near/far libraries stay intact. This library has the SAME 24
variant indices/poses and seat origins, up to 6000 triangles each. Source UV0
survives into shared 2K atlases; UV1 retains the cosmetic arm weights.
COLOR encodes garment, role, chest and skin masks, not baked illumination.
The runtime shader supplies light and per-instance clothing variation.
"""
from __future__ import annotations

import argparse
import json
import pathlib
import sys

import bpy
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import crowd
import rocketbox_crowd as rb

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT = REPO / "game/assets/environment/floor_crowd_textured.glb"
TEX = REPO / "game/assets/environment/materials/crowd"
CELL, BORDER, SIZE = 512, 8, 2048
INNER = CELL - BORDER * 2
KINDS = ("body", "head", "opacity")
TRIANGLES = 6000


def _graphic(avatar, size: int) -> Image.Image:
    """Rasterize a chest-space print into the source body's UVs.

    Coordinates are measured on the undeformed torso, so the printed logo
    follows the shirt into every baked pose instead of floating over it.
    """
    logo = Image.new("L", (256, 128))
    pen = ImageDraw.Draw(logo)
    font_path = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
    font = ImageFont.truetype(font_path, 72)
    small = ImageFont.truetype(font_path, 21)
    pen.text((128, 40), "AEW", font=font, fill=230, anchor="mm")
    pen.text((128, 91), "WRESTLING", font=small, fill=200, anchor="mm")
    graphic = np.asarray(logo)
    result = np.zeros((size, size), dtype=np.uint8)
    mesh = avatar.mesh_obj.data
    mesh.calc_loop_triangles()
    co = np.array([v.co[:] for v in mesh.vertices])
    world = np.array(avatar.mesh_obj.matrix_world)
    co = co @ world[:3, :3].T + world[:3, 3]
    spine = np.array(avatar._bone_head("Bip01 Spine"))
    top = np.array(avatar._bone_head("Bip01 Spine2"))
    front = avatar._front()
    # Viewer-right on the front of the shirt. Reversing this cross product
    # mirrors readable lettering even when the photographic UVs are correct.
    across = np.cross((0, 0, 1), front)
    side = (co - top) @ across
    height = (co[:, 2] - spine[2]) / max(top[2] - spine[2], 1e-4)
    projected = np.stack([side / 0.24 + 0.5, (1.40 - height) / 0.74], axis=1)
    shirt = np.array([v.color[0] for v in mesh.color_attributes["Info"].data])
    normals = np.array([v.normal[:] for v in mesh.vertices]) @ world[:3, :3].T
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-8)
    facing = normals @ front
    uv_layer = mesh.uv_layers.active.data
    for tri in mesh.loop_triangles:
        ids = np.array(tri.vertices)
        if shirt[ids].mean() < 0.6 or facing[ids].mean() < 0.2:
            continue
        q = projected[ids]
        if q[:, 0].max() < 0 or q[:, 0].min() > 1 or q[:, 1].max() < 0 or q[:, 1].min() > 1:
            continue
        uv = np.array([uv_layer[i].uv[:] for i in tri.loops])
        p = np.stack([uv[:, 0], 1.0 - uv[:, 1]], axis=1) * (size - 1)
        lo = np.maximum(np.floor(p.min(0)).astype(int), 0)
        hi = np.minimum(np.ceil(p.max(0)).astype(int), size - 1)
        if np.any(hi < lo):
            continue
        v0, v1 = p[1] - p[0], p[2] - p[0]
        det = v0[0] * v1[1] - v0[1] * v1[0]
        if abs(det) < 1e-6:
            continue
        xx, yy = np.meshgrid(np.arange(lo[0], hi[0] + 1), np.arange(lo[1], hi[1] + 1))
        dx, dy = xx - p[0, 0], yy - p[0, 1]
        b1 = (dx * v1[1] - dy * v1[0]) / det
        b2 = (v0[0] * dy - v0[1] * dx) / det
        b0 = 1.0 - b1 - b2
        at = b0[..., None] * q[0] + b1[..., None] * q[1] + b2[..., None] * q[2]
        ok = (b0 >= -0.01) & (b1 >= -0.01) & (b2 >= -0.01) \
            & (at[..., 0] >= 0) & (at[..., 0] <= 1) & (at[..., 1] >= 0) & (at[..., 1] <= 1)
        ink = graphic[np.clip((at[..., 1] * 127).astype(int), 0, 127),
                      np.clip((at[..., 0] * 255).astype(int), 0, 255)]
        patch = result[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1]
        np.maximum(patch, np.where(ok, ink, 0), out=patch)
    return Image.fromarray(result)


def _cell_image(image: Image.Image) -> Image.Image:
    """Eight-pixel dilation limits atlas bleed in the mip chain."""
    core = image.resize((INNER, INNER), Image.Resampling.LANCZOS)
    out = Image.new(image.mode, (CELL, CELL))
    out.paste(core, (BORDER, BORDER))
    out.paste(core.crop((0, 0, 1, INNER)).resize((BORDER, INNER)), (0, BORDER))
    out.paste(core.crop((INNER - 1, 0, INNER, INNER)).resize((BORDER, INNER)), (CELL - BORDER, BORDER))
    out.paste(out.crop((0, BORDER, CELL, BORDER + 1)).resize((CELL, BORDER)), (0, 0))
    out.paste(out.crop((0, CELL - BORDER - 1, CELL, CELL - BORDER)).resize((CELL, BORDER)), (0, CELL - BORDER))
    return out


def _variant(avatar, fig, index: int, cell_base: int, material) -> tuple:
    evaluated = avatar.mesh_obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
    source = evaluated.to_mesh()
    source.calc_loop_triangles()
    count = len(source.vertices)
    raw = np.array([v.co[:] for v in source.vertices])
    # The shared extractor owns orientation, scale and seating height. Fit its
    # affine transform so UV extraction never introduces a second axis guess.
    design = np.column_stack([raw, np.ones(count)])
    affine = np.linalg.lstsq(design, fig["co"][:count], rcond=None)[0]
    normal_matrix = np.linalg.inv(affine[:3]).T
    nrm = np.array([v.normal[:] for v in source.vertices]) @ normal_matrix
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-8)
    colour = np.array([v.color[:] for v in source.color_attributes["Col"].data])[:, :3]
    chroma = colour / np.maximum(colour.sum(1, keepdims=True), 1e-6)
    skin_chroma = avatar.skin / max(avatar.skin.sum(), 1e-6)
    skin = (np.abs(chroma - skin_chroma).sum(1) < 0.11) & ~fig["shirt"][:count]
    metadata = np.stack([fig["shirt"][:count], np.full(count, fig["role"]),
                         fig["chest"][:count], skin], axis=1).astype(float)
    uv_layer = source.uv_layers.active.data
    kinds = [m.name.split("_")[-1] if m else "body" for m in source.materials]
    verts, normals, uv, motion, masks = [], [], [], [], []
    seen = set()
    for triangle in source.loop_triangles:
        ids = tuple(triangle.vertices)
        key = tuple(sorted(ids))
        if key in seen:
            continue
        seen.add(key)
        p = fig["co"][list(ids)]
        if np.linalg.norm(np.cross(p[1] - p[0], p[2] - p[0])) < 1e-9:
            continue
        kind = kinds[triangle.material_index]
        cell = cell_base + (KINDS.index(kind) if kind in KINDS else 0)
        cx, cy = cell % 4, cell // 4
        for loop_id, vertex_id in zip(triangle.loops, ids):
            u, v = uv_layer[loop_id].uv
            # Source UV and Blender's exported image UV both point up.
            u = u if 0.0 <= u <= 1.0 else u % 1.0
            v = v if 0.0 <= v <= 1.0 else v % 1.0
            uv.append(((cx * CELL + BORDER + u * INNER) / SIZE,
                       1.0 - (cy * CELL + BORDER + (1.0 - v) * INNER) / SIZE))
            point, normal = fig["co"][vertex_id], nrm[vertex_id]
            verts.append((point[0], -point[2], point[1]))
            normals.append((normal[0], -normal[2], normal[1]))
            motion.append((fig["arm"][vertex_id], fig["side"][vertex_id]))
            masks.append(metadata[vertex_id])
    # Phone bodies/screens added by the shared pose extractor keep their real
    # locations. Reserved atlas cells avoid a second material/draw call.
    for triangle in fig["tris"]:
        if triangle.min() < count:
            continue
        p = fig["co"][triangle]
        normal = np.cross(p[1] - p[0], p[2] - p[0])
        normal /= max(np.linalg.norm(normal), 1e-9)
        cell = 13 if fig["colour"][triangle].mean() > 0.1 else 12
        for vertex_id in triangle:
            point = fig["co"][vertex_id]
            verts.append((point[0], -point[2], point[1]))
            normals.append((normal[0], -normal[2], normal[1]))
            uv.append(((cell % 4 + 0.5) / 4.0, 1.0 - (cell // 4 + 0.5) / 4.0))
            motion.append((0.0, 0.5))
            masks.append((0.0, fig["role"], 0.0, 0.0))
    evaluated.to_mesh_clear()
    name = f"Fan{index:02d}"
    # Weld only identical complete vertices. Sharing positions alone would
    # destroy UV seams or masks; leaving every triangle corner separate costs
    # about four times the vertex bandwidth without adding visible detail.
    attributes = np.column_stack([verts, normals, uv, motion, masks]).astype(np.float32)
    unique, _first, inverse = np.unique(attributes, axis=0, return_index=True, return_inverse=True)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(unique[:, :3].tolist(), [], inverse.reshape(-1, 3).tolist())
    mesh.polygons.foreach_set("use_smooth", np.ones(len(mesh.polygons), dtype=bool))
    mesh.normals_split_custom_set(normals)
    for label, values in (("UVMap", uv), ("Arm", motion)):
        layer = mesh.uv_layers.new(name=label)
        layer.data.foreach_set("uv", np.asarray(values, dtype=np.float32).ravel())
    attr = mesh.color_attributes.new("Masks", "FLOAT_COLOR", "POINT")
    attr.data.foreach_set("color", unique[:, 10:14].ravel())
    mesh.color_attributes.active_color = attr
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj, len(mesh.polygons)


def main() -> None:
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=pathlib.Path, default=OUT)
    config = parser.parse_args(args)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    TEX.mkdir(parents=True, exist_ok=True)
    specs = crowd.FLOOR_SEATED + crowd.FLOOR_STANDING
    avatars = list(dict.fromkeys(name for name, _pose in specs))
    atlases = [Image.new("RGBA", (SIZE, SIZE), (40, 40, 42, 255)) for _ in range((len(avatars) + 3) // 4)]
    prints = [Image.new("L", (SIZE, SIZE)) for _ in atlases]
    for atlas in atlases:
        atlas.paste((8, 8, 10, 255), (0, CELL * 3, CELL, CELL * 4))
        atlas.paste((190, 205, 224, 255), (CELL, CELL * 3, CELL * 2, CELL * 4))
    materials = []
    for group in range(len(atlases)):
        mat = bpy.data.materials.new(f"CrowdAtlas{group:02d}")
        mat.diffuse_color = (1, 1, 1, 1)
        materials.append(mat)
    exported, variants = [], {}
    for avatar_index, name in enumerate(avatars):
        avatar = rb.Avatar(name)
        group, local = divmod(avatar_index, 4)
        source_dir = rb.rocketbox_root() / "Assets/Avatars/Adults" / name / "Textures"
        paths = {p.stem.split("_")[1]: p for p in source_dir.glob("*_color.tga")}
        for kind_index, kind in enumerate(KINDS):
            cell = local * 3 + kind_index
            image = Image.open(paths.get(kind, paths["body"])).convert("RGBA")
            atlases[group].paste(_cell_image(image), ((cell % 4) * CELL, (cell // 4) * CELL))
        cell = local * 3
        prints[group].paste(_cell_image(_graphic(avatar, INNER)), ((cell % 4) * CELL, (cell // 4) * CELL))
        for index, (who, pose) in enumerate(specs):
            if who != name:
                continue
            avatar.pose(pose)
            fig = avatar.extract(TRIANGLES, True)
            obj, triangles = _variant(avatar, fig, index, local * 3, materials[group])
            exported.append(obj)
            variants[obj.name] = {"atlas": group, "avatar": name, "pose": pose,
                                  "triangles": triangles, "role": float(fig["role"])}
            cloth = fig["colour"][fig["shirt"]]
            if len(cloth):
                variants[obj.name]["garment_luminance"] = float(np.median(
                    cloth @ np.array([0.2126, 0.7152, 0.0722])) / rb.TEXTURE_LEVEL)
            print(f"textured crowd: {obj.name} {name} {pose} {triangles} triangles", flush=True)
        bpy.data.objects.remove(avatar.mesh_obj, do_unlink=True)
        bpy.data.objects.remove(avatar.arm, do_unlink=True)
    for group, (albedo, graphic) in enumerate(zip(atlases, prints)):
        if graphic.getbbox() is None:
            raise RuntimeError(f"Atlas {group} lost all chest graphics")
        albedo.save(TEX / f"crowd_{group:02d}_color.png", optimize=False)
        graphic.save(TEX / f"crowd_{group:02d}_print.png", optimize=False)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in exported:
        obj.select_set(True)
    config.out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(config.out), export_format="GLB",
                             use_selection=True, export_yup=True, export_apply=True,
                             export_materials="EXPORT", export_vertex_color="ACTIVE",
                             export_animations=False, export_skins=False, export_normals=True)
    manifest = {"source": rb.ROCKETBOX_URL, "source_commit": rb.ROCKETBOX_COMMIT,
                "atlas_size": SIZE, "atlas_count": len(atlases),
                "variant_budget": TRIANGLES + 48, "body_triangle_budget": TRIANGLES,
                "variants": variants}
    config.out.with_suffix(".json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"wrote {config.out}: {len(variants)} variants, {len(atlases)} shared atlases", flush=True)


if __name__ == "__main__":
    main()
