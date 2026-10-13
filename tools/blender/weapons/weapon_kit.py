"""Shared kit for the No Holds Barred weapons (gauntlet/refs/weapons_nhb.md).

Every family script (chairs.py, swung.py, ...) builds its weapons with this:

* `WeaponPart` -- venue.Part in the game's frame (+Y up, forward -Z, metres),
  with an optional `deform` applied to every vertex as it is made. That is how
  a `_Bent` / `_Dented` state is the same build as `_Clean` with real damage
  in the mesh, not a different texture.
* procedural PBR textures -- numpy value noise seeded from the weapon's name,
  written as PNGs by PIL (byte-identical run to run) and loaded into
  Principled BSDF materials the glTF exporter maps straight to base colour,
  metallic-roughness and normal.
* `state_root` / `marker` / `add_mesh` -- the node layout the game reads:
  one root per state named <WeaponId>_<State>, marker empties (grip_r,
  strike, seat ...) under it.
* `export` -- the .glb, one per weapon.

Deterministic: no clock, no unseeded randomness, fixed insertion order.
"""

from __future__ import annotations

import hashlib
import math
import pathlib
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
import venue  # noqa: E402
from venue import Part, to_blender  # noqa: E402

import bpy  # noqa: E402
import bmesh  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[3]
OUT_DIR = ROOT / "game" / "assets" / "weapons"
TEX_DIR = OUT_DIR / "textures"
TEX_SIZE = 1024


# --- geometry ------------------------------------------------------------

class WeaponPart(Part):
    """A Part whose every vertex goes through `deform` (game frame) first."""

    def __init__(self, name: str, deform=None) -> None:
        super().__init__(name)
        self.deform = deform

    def vert(self, position: Vector) -> bmesh.types.BMVert:
        p = Vector(position)
        if self.deform is not None:
            p = self.deform(p)
        return self.bm.verts.new(to_blender(p))

    def grid_panel(self, corner: Vector, u: Vector, v: Vector, nu: int, nv: int,
                   thickness: float, bulge=None) -> None:
        """A sheet `u` x `v` from `corner`, nu x nv quads a side, `thickness`
        thick along u x v, with closed edges. `bulge(s, t)` (0..1 each) moves a
        point along the sheet normal: a seat's dish, a can's dent."""
        n = u.cross(v).normalized()
        rows_top: list[list] = []
        rows_bot: list[list] = []
        for j in range(nv + 1):
            top, bot = [], []
            for i in range(nu + 1):
                s, t = i / nu, j / nv
                b = bulge(s, t) if bulge else 0.0
                p = corner + u * s + v * t + n * b
                top.append(self.vert(p + n * (thickness * 0.5)))
                bot.append(self.vert(p - n * (thickness * 0.5)))
            rows_top.append(top)
            rows_bot.append(bot)
        for j in range(nv):
            for i in range(nu):
                self.quad(rows_top[j][i], rows_top[j][i + 1],
                          rows_top[j + 1][i + 1], rows_top[j + 1][i])
                self.quad(rows_bot[j][i], rows_bot[j + 1][i],
                          rows_bot[j + 1][i + 1], rows_bot[j][i + 1])
        ring_t = [rows_top[0][i] for i in range(nu + 1)] \
            + [rows_top[j][nu] for j in range(1, nv + 1)] \
            + [rows_top[nv][i] for i in range(nu - 1, -1, -1)] \
            + [rows_top[j][0] for j in range(nv - 1, 0, -1)]
        ring_b = [rows_bot[0][i] for i in range(nu + 1)] \
            + [rows_bot[j][nu] for j in range(1, nv + 1)] \
            + [rows_bot[nv][i] for i in range(nu - 1, -1, -1)] \
            + [rows_bot[j][0] for j in range(nv - 1, 0, -1)]
        for k in range(len(ring_t)):
            m = (k + 1) % len(ring_t)
            self.quad(ring_t[k], ring_t[m], ring_b[m], ring_b[k])


def rounded_rect(center: Vector, a: Vector, b: Vector, ha: float, hb: float,
                 r: float, per_corner: int = 4) -> list[Vector]:
    """A closed loop (first point repeated last) round a rectangle in the
    plane of unit axes a, b: half sizes ha, hb, corner radius r."""
    pts: list[Vector] = []
    corners = ((1, 1, 0.0), (-1, 1, 0.5 * math.pi), (-1, -1, math.pi), (1, -1, 1.5 * math.pi))
    for sa, sb, start in corners:
        c = center + a * (sa * (ha - r)) + b * (sb * (hb - r))
        for k in range(per_corner + 1):
            ang = start + 0.5 * math.pi * k / per_corner
            pts.append(c + a * (math.cos(ang) * r) + b * (math.sin(ang) * r))
    pts.append(pts[0])
    return pts


def helix_around_box(center: Vector, along: Vector, a: Vector, b: Vector,
                     ha: float, hb: float, length: float, turns: float,
                     steps_per_turn: int = 24) -> list[Vector]:
    """A wire wound round a box: loops in the a/b plane advancing along
    `along` over `length` -- a coil round a seat panel or a bat barrel."""
    pts = []
    n = max(2, int(turns * steps_per_turn))
    for k in range(n + 1):
        f = k / n
        ang = 2.0 * math.pi * turns * f
        ca, sb = math.cos(ang), math.sin(ang)
        # superellipse: hugs a rectangle's flats rather than an ellipse's
        ea = math.copysign(abs(ca) ** 0.35, ca) * ha
        eb = math.copysign(abs(sb) ** 0.35, sb) * hb
        pts.append(center + along * (length * (f - 0.5)) + a * ea + b * eb)
    return pts


def barbed_wire(part: WeaponPart, path: list[Vector], rng: np.random.RandomState,
                wire_r: float = 0.0016, twist_r: float = 0.0022,
                barb_every: float = 0.10, barb_len: float = 0.016) -> None:
    """Two strands twisted round `path`, a four-point barb every `barb_every`."""
    # resample the path evenly
    seg = [(path[i + 1] - path[i]).length for i in range(len(path) - 1)]
    total = sum(seg)
    # four samples a twist: the least that still reads as two strands wound
    step = 0.0087
    count = max(2, int(total / step))
    even: list[Vector] = []
    acc, i = 0.0, 0
    for k in range(count + 1):
        d = total * k / count
        while i < len(seg) - 1 and acc + seg[i] < d:
            acc += seg[i]
            i += 1
        f = 0.0 if seg[i] < 1e-9 else (d - acc) / seg[i]
        even.append(path[i].lerp(path[i + 1], min(max(f, 0.0), 1.0)))
    frames = venue._frames(even)
    twist_per_m = 2.0 * math.pi / 0.035
    for strand in (0.0, math.pi):
        pts = []
        for k, (p, (_, nrm, bin_)) in enumerate(zip(even, frames)):
            ang = strand + twist_per_m * total * k / count
            pts.append(p + nrm * (math.cos(ang) * twist_r) + bin_ * (math.sin(ang) * twist_r))
        part.tube(pts, wire_r, sides=4, caps=True)
    d = barb_every * 0.5
    while d < total:
        k = min(count, int(d / total * count))
        p = even[k]
        _, nrm, bin_ = frames[k]
        tang = (even[min(k + 1, count)] - even[max(k - 1, 0)]).normalized()
        spin = rng.uniform(0.0, math.pi)
        for arm in (0.0, 0.5 * math.pi):
            dirv = nrm * math.cos(spin + arm) + bin_ * math.sin(spin + arm)
            a = p - dirv * barb_len + tang * 0.002
            b = p + dirv * barb_len - tang * 0.002
            part.tube([a, p, b], wire_r * 0.9, sides=4, caps=True)
        d += barb_every


# --- textures ------------------------------------------------------------

def seed_of(name: str) -> int:
    return int.from_bytes(hashlib.md5(name.encode()).digest()[:4], "little")


def value_noise(rng: np.random.RandomState, size: int, cells: int) -> np.ndarray:
    """Tileable smooth noise 0..1: a random grid, bicubic-upsampled."""
    grid = rng.rand(cells, cells).astype(np.float32)
    tiled = np.tile(grid, (3, 3))
    img = Image.fromarray((tiled * 65535).astype(np.uint16).astype(np.int32), mode="I")
    big = img.resize((size * 3, size * 3), Image.BICUBIC)
    arr = np.asarray(big, dtype=np.float32)[size:2 * size, size:2 * size] / 65535.0
    return np.clip(arr, 0.0, 1.0)


def fbm(rng: np.random.RandomState, size: int, base: int = 4, octaves: int = 5) -> np.ndarray:
    out = np.zeros((size, size), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += value_noise(rng, size, base * (2 ** o)) * amp
        total += amp
        amp *= 0.5
    return out / total


def scratches(rng: np.random.RandomState, size: int, count: int, length: float,
              width: int = 1, spread: float = math.pi) -> np.ndarray:
    """Thin straight-ish scuff lines, 0..1, within `spread` radians of one
    direction (pi: any way)."""
    img = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(img)
    for _ in range(count):
        x, y = rng.uniform(0, size, 2)
        ang = rng.uniform(-spread * 0.5, spread * 0.5) + 0.5 * math.pi
        ln = rng.uniform(0.3, 1.0) * length * size
        bend = rng.uniform(-0.15, 0.15)
        pts = []
        for k in range(6):
            f = k / 5
            a = ang + bend * f
            pts.append((x + math.cos(a) * ln * f, y + math.sin(a) * ln * f))
        draw.line(pts, fill=int(rng.uniform(90, 255)), width=width)
    return np.asarray(img, np.float32) / 255.0


def normal_from_height(h: np.ndarray, strength: float) -> np.ndarray:
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(h)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def save_rgb(arr: np.ndarray, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGB")
    img.save(path, optimize=False, compress_level=9)


def save_rgba(arr: np.ndarray, path: pathlib.Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img = Image.fromarray((np.clip(arr, 0, 1) * 255.0 + 0.5).astype(np.uint8), "RGBA")
    img.save(path, optimize=False, compress_level=9)


def font(size: int) -> ImageFont.FreeTypeFont:
    for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                 "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"):
        if pathlib.Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size=size)


# --- materials -----------------------------------------------------------

def _image(path: pathlib.Path, non_color: bool) -> bpy.types.Image:
    img = bpy.data.images.load(str(path), check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    return img


def pbr_material(name: str, base: pathlib.Path, orm: pathlib.Path | None,
                 normal: pathlib.Path | None, normal_strength: float = 1.0,
                 roughness: float = 0.5, metallic: float = 0.0,
                 alpha: bool = False) -> bpy.types.Material:
    """Principled BSDF the glTF exporter maps 1:1: base colour (alpha in A
    when `alpha`), ORM packed (G roughness, B metallic) and a normal map."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = _image(base, False)
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if alpha:
        links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
        mat.blend_method = "CLIP"
    if orm is not None:
        t2 = nodes.new("ShaderNodeTexImage")
        t2.image = _image(orm, True)
        sep = nodes.new("ShaderNodeSeparateColor")
        links.new(t2.outputs["Color"], sep.inputs["Color"])
        links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
        links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
    if normal is not None:
        t3 = nodes.new("ShaderNodeTexImage")
        t3.image = _image(normal, True)
        nm = nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = normal_strength
        links.new(t3.outputs["Color"], nm.inputs["Color"])
        links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def flat_material(name: str, color: tuple, roughness: float, metallic: float = 0.0) -> bpy.types.Material:
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


# --- scene ---------------------------------------------------------------

def state_root(name: str) -> bpy.types.Object:
    root = bpy.data.objects.new(name, None)
    root.empty_display_type = "PLAIN_AXES"
    bpy.context.collection.objects.link(root)
    return root


def marker(root: bpy.types.Object, name: str, position: Vector,
           y_axis: Vector = Vector((0, 1, 0)), z_axis: Vector = Vector((0, 0, 1))) -> None:
    """An empty at `position` (game frame) whose game-frame +Y and +Z are the
    given axes. Named `<name>` under its state root (Godot keeps node names
    unique per parent, so every state carries the same marker names)."""
    obj = bpy.data.objects.new(root.name + "__" + name, None)
    obj.empty_display_type = "ARROWS"
    obj.empty_display_size = 0.05
    y = y_axis.normalized()
    z = (z_axis - y * z_axis.dot(y)).normalized()
    x = y.cross(z)
    basis = Matrix((to_blender(x), to_blender(y), to_blender(z))).transposed()
    obj.matrix_world = Matrix.Translation(to_blender(position)) @ basis.to_4x4()
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    obj["marker"] = name


def add_mesh(root: bpy.types.Object, part: WeaponPart, material: bpy.types.Material,
             smooth: bool = True, uv_scale: float = 2.0, auto_smooth_deg: float = 40.0) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(part.name)
    bmesh.ops.remove_doubles(part.bm, verts=part.bm.verts[:], dist=0.00005)
    bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
    part.bm.to_mesh(mesh)
    part.bm.free()
    mesh.materials.append(material)
    if smooth:
        for poly in mesh.polygons:
            poly.use_smooth = True
    venue.cube_project(mesh, uv_scale)
    obj = bpy.data.objects.new(part.name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = root
    if smooth and auto_smooth_deg < 180.0:
        mod = obj.modifiers.new("edges", "EDGE_SPLIT")
        mod.split_angle = math.radians(auto_smooth_deg)
        mod.use_edge_sharp = False
    return obj


def triangles_under(root: bpy.types.Object) -> int:
    total = 0
    for obj in root.children_recursive:
        if obj.type == "MESH":
            total += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    return total


def export(weapon_id: str) -> pathlib.Path:
    out = OUT_DIR / (weapon_id + ".glb")
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out), export_format="GLB", export_apply=True, export_yup=True,
        use_selection=False, export_cameras=False, export_lights=False,
        export_materials="EXPORT", export_image_format="AUTO", export_extras=True)
    return out


def reset() -> None:
    venue.reset_scene()
