#!/usr/bin/env python3
"""Family 1, chairs (gauntlet/refs/weapons_nhb.md): the steel folding chair
and the barbed-wire chair.

Run:  python3 tools/blender/weapons/chairs.py

  game/assets/weapons/steel_chair.glb
      SteelChair_Folded  flat, as swung; origin at the top rail's centre, the
                         chair hanging down -Y from it; held and swung by
                         the two front legs (grip_r, grip_l)
      SteelChair_Open    set up on the floor, seat at 0.45 m; origin at
                         floor centre
      SteelChair_Bent    folded, after the shots: seat panel caved in on a
                         buckle line, rails bowed -- in the mesh, not a texture
  game/assets/weapons/barbed_wire_chair.glb
      BarbedWireChair_Folded / BarbedWireChair_Open, the same chair with
      two-strand barbed wire wound round seat and back.

The chair is the arena kind: one tube (front legs and back posts) in an
inverted U, a second U (rear legs) crossing it in an X under the seat, a
pressed-steel seat and back panel with rolled edges, rubber feet. Enamel
paint, chipped through to bare steel, scuffed, with a stencilled number.

Markers (empties, named <Root>__<marker>): grip_r, grip_l, strike (folded),
seat (open).
"""

from __future__ import annotations

import math
import sys
import pathlib

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import weapon_kit as kit  # noqa: E402
from weapon_kit import Vector  # noqa: E402

import numpy as np  # noqa: E402

TUBE_R = 0.0125          # 25 mm steel tube
FRAME_HALF = 0.205       # outer U half width
REAR_HALF = 0.180        # rear U half width, inside the outer
SEAT_W, SEAT_D = 0.40, 0.38
BACK_W, BACK_H = 0.39, 0.16
PANEL_T = 0.004
RIM_R = 0.006
FOLDED_LEN = 0.86
SIDES = 12


# --- textures --------------------------------------------------------------

def paint_textures(weapon_id: str, paint_rgb: tuple, chip_amount: float) -> tuple:
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_paint"))
    n = kit.TEX_SIZE
    big = kit.fbm(rng, n, 6, 5)
    fine = kit.fbm(rng, n, 48, 3)
    chips = np.clip((big * 0.75 + fine * 0.25 - (1.0 - chip_amount)) * 9.0, 0.0, 1.0)
    # scuffs run mostly one way (a chair is dragged and swung along its
    # length), soft, and in clusters where it was hit -- not a cobweb
    cluster = np.clip((kit.fbm(rng, n, 3, 3) - 0.45) * 4.0, 0, 1)
    scuff = kit.scratches(rng, n, 90, 0.10, 1, spread=0.35) * 0.45
    scuff = np.maximum(scuff, kit.scratches(rng, n, 18, 0.22, 3, spread=0.35) * 0.30)
    scuff = scuff * (0.25 + 0.75 * cluster)
    grime = kit.fbm(rng, n, 10, 4)
    paint = np.array(paint_rgb, np.float32)
    steel = np.array([0.56, 0.56, 0.55], np.float32)
    rust = np.array([0.30, 0.17, 0.09], np.float32)
    base = paint[None, None, :] * (0.88 + 0.24 * grime[..., None])
    # scuffs burnish the enamel lighter before they go through it
    base = base + (np.array([0.20, 0.20, 0.20]) - base) * (scuff[..., None] * 0.55)
    bare = steel[None, None, :] * (0.85 + 0.3 * fine[..., None])
    rim = np.clip((big - (1.0 - chip_amount) + 0.03) * 25.0, 0, 1) * (1 - chips)
    bare = bare + (rust - bare) * (np.clip(fine - 0.6, 0, 1)[..., None] * 0.9)
    base = base * (1 - chips[..., None]) + bare * chips[..., None]
    base = base * (1.0 - 0.35 * rim[..., None])  # the dark lip of a chip
    rough = 0.42 + 0.18 * grime + 0.2 * scuff
    rough = rough * (1 - chips) + (0.32 + 0.25 * fine) * chips
    metal = chips * 1.0
    orm = np.stack([np.ones_like(rough), np.clip(rough, 0, 1), metal], -1)
    height = -chips * 0.6 - scuff * 0.15 + grime * 0.05
    nrm = kit.normal_from_height(height, 6.0)
    d = kit.TEX_DIR
    kit.save_rgb(np.clip(base, 0, 0.85), d / f"{weapon_id}_paint_base.png")
    kit.save_rgb(orm, d / f"{weapon_id}_paint_orm.png")
    kit.save_rgb(nrm, d / f"{weapon_id}_paint_normal.png")
    return (d / f"{weapon_id}_paint_base.png", d / f"{weapon_id}_paint_orm.png",
            d / f"{weapon_id}_paint_normal.png")


def stencil_texture(weapon_id: str, text: str) -> pathlib.Path:
    """White stencilled arena number, worn, on transparent."""
    from PIL import Image, ImageDraw
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_stencil"))
    size = 512
    img = Image.new("L", (size, size // 2), 0)
    draw = ImageDraw.Draw(img)
    f = kit.font(170)
    box = draw.textbbox((0, 0), text, font=f)
    x = (size - (box[2] - box[0])) // 2 - box[0]
    y = (size // 2 - (box[3] - box[1])) // 2 - box[1]
    draw.text((x, y), text, font=f, fill=255)
    # stencil bridges: two vertical gaps through every glyph
    for gx in (size * 0.5 - 4,):
        draw.rectangle([gx, 0, gx + 7, size], fill=0)
    a = np.asarray(img, np.float32) / 255.0
    wear = kit.fbm(rng, size, 8, 4)[: size // 2, :]
    a = a * np.clip((wear - 0.28) * 4.0, 0, 1) * 0.92
    rgb = np.ones((size // 2, size, 3), np.float32) * 0.80
    path = kit.TEX_DIR / f"{weapon_id}_stencil.png"
    kit.save_rgba(np.concatenate([rgb, a[..., None]], -1), path)
    return path


def wire_textures(weapon_id: str) -> tuple:
    rng = np.random.RandomState(kit.seed_of(weapon_id + "_wire"))
    n = 256
    rust = kit.fbm(rng, n, 8, 4)
    r = np.clip((rust - 0.5) * 3.0, 0, 1)
    galv = np.array([0.62, 0.63, 0.62])
    brown = np.array([0.33, 0.19, 0.10])
    base = galv[None, None] * (1 - r[..., None]) + brown[None, None] * r[..., None]
    orm = np.stack([np.ones_like(r), 0.38 + 0.45 * r, 1.0 - 0.8 * r], -1)
    d = kit.TEX_DIR
    kit.save_rgb(base, d / f"{weapon_id}_wire_base.png")
    kit.save_rgb(orm, d / f"{weapon_id}_wire_orm.png")
    return d / f"{weapon_id}_wire_base.png", d / f"{weapon_id}_wire_orm.png"


# --- the chair -------------------------------------------------------------

def _side_path(points_yz: list[tuple[float, float]], x: float) -> list[Vector]:
    return [Vector((x, y, z)) for y, z in points_yz]


def _u_frame(part: kit.WeaponPart, side_yz: list[tuple[float, float]], half: float,
             top_r: float = 0.05) -> None:
    """An inverted U: both sides along side_yz (bottom to top), joined over
    the top by a bend of radius top_r."""
    left = _side_path(side_yz, -half)
    right = _side_path(side_yz, half)
    y_top, z_top = side_yz[-1]
    y_prev, z_prev = side_yz[-2]
    up = Vector((0.0, y_top - y_prev, z_top - z_prev)).normalized()
    # left side up, a rounded corner, across, a rounded corner, right side down
    path = list(left)
    end = left[-1]
    for k in range(1, 5):
        ang = 0.5 * math.pi * k / 4
        path.append(end + up * (math.sin(ang) * top_r) + Vector((1, 0, 0)) * ((1 - math.cos(ang)) * top_r))
    rend = right[-1]
    corner_r = []
    for k in range(4, 0, -1):
        ang = 0.5 * math.pi * k / 4
        corner_r.append(rend + up * (math.sin(ang) * top_r) - Vector((1, 0, 0)) * ((1 - math.cos(ang)) * top_r))
    path += corner_r
    path += list(reversed(right))
    part.tube(path, TUBE_R, SIDES, caps=True)


def _feet(part: kit.WeaponPart, feet: list[tuple[Vector, Vector]]) -> None:
    for base, axis in feet:
        part.tube([base - axis * 0.004, base + axis * 0.035], TUBE_R + 0.0025, SIDES, caps=True)


def _rivet(part: kit.WeaponPart, at: Vector, axis: Vector) -> None:
    part.tube([at - axis * 0.004, at + axis * 0.004], 0.0055, 8, caps=True)


def _dish(depth: float):
    return lambda s, t: -depth * math.sin(math.pi * s) * math.sin(math.pi * t)


def build_open(root, prefix: str, paint, rubber, deform=None) -> dict:
    frame = kit.WeaponPart(prefix + "_frame", deform)
    panels = kit.WeaponPart(prefix + "_panels", deform)
    feet = kit.WeaponPart(prefix + "_feet", deform)
    # outer U: front feet forward (-Z), rising back to the top of the back
    outer = [(0.0, -0.215), (0.24, -0.11), (0.45, -0.02), (0.62, 0.055), (0.80, 0.105), (0.83, 0.11)]
    _u_frame(frame, outer, FRAME_HALF)
    # rear U: rear feet back (+Z), rising forward to under the seat front
    rear = [(0.0, 0.215), (0.20, 0.12), (0.40, -0.02), (0.435, -0.06)]
    _u_frame(frame, rear, REAR_HALF, top_r=0.03)
    # front cross brace near the floor, seat cross rails
    for x0, x1, y, z in ((-FRAME_HALF, FRAME_HALF, 0.13, -0.155),
                         (-REAR_HALF, REAR_HALF, 0.12, 0.165)):
        frame.tube([Vector((x0, y, z)), Vector((x1, y, z))], TUBE_R * 0.8, SIDES)
    # seat: pressed panel on two side rails pivoting on the outer frame
    seat_y = 0.45
    for x in (-REAR_HALF + 0.01, REAR_HALF - 0.01):
        frame.tube([Vector((x, seat_y - 0.02, -0.19)), Vector((x, seat_y - 0.02, 0.17))], 0.009, 8)
    corner = Vector((-SEAT_W / 2, seat_y, -0.20))
    panels.grid_panel(corner, Vector((SEAT_W, 0, 0)), Vector((0, 0.015, SEAT_D)), 14, 14,
                      PANEL_T, _dish(0.012))
    panels.tube(kit.rounded_rect(Vector((0, seat_y + 0.008, -0.20 + SEAT_D / 2)), Vector((1, 0, 0)),
                                 Vector((0, 0.04, 1)).normalized(), SEAT_W / 2, SEAT_D / 2, 0.035),
                RIM_R, 8, caps=False)
    # back panel between the posts, curved to the back
    by0 = 0.60
    bz0 = 0.06
    back_corner = Vector((-BACK_W / 2, by0, bz0))
    back_v = Vector((0, BACK_H, BACK_H * 0.28))
    panels.grid_panel(back_corner, Vector((BACK_W, 0, 0)), back_v, 12, 6, PANEL_T,
                      lambda s, t: 0.018 * math.sin(math.pi * s))
    # rivets at the X pivots and seat hinge
    for x in (-FRAME_HALF - TUBE_R, FRAME_HALF + TUBE_R):
        sx = math.copysign(1, x)
        _rivet(frame, Vector((x, 0.39, -0.045)), Vector((sx, 0, 0)))
        _rivet(frame, Vector((x, 0.45, -0.02)), Vector((sx, 0, 0)))
    _feet(feet, [(Vector((s * FRAME_HALF, 0.0, -0.215)), Vector((0, 1, 0.45)).normalized()) for s in (-1, 1)]
          + [(Vector((s * REAR_HALF, 0.0, 0.215)), Vector((0, 1, -0.45)).normalized()) for s in (-1, 1)])
    objs = {
        "frame": kit.add_mesh(root, frame, paint),
        "panels": kit.add_mesh(root, panels, paint),
        "feet": kit.add_mesh(root, feet, rubber),
    }
    kit.marker(root, "seat", Vector((0, seat_y + 0.01, -0.01)))
    kit.marker(root, "grip_r", Vector((FRAME_HALF * 0.6, 0.85, 0.11)), Vector((0, -1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((-FRAME_HALF * 0.6, 0.85, 0.11)), Vector((0, -1, 0)), Vector((0, 0, 1)))
    return objs


def build_folded(root, prefix: str, paint, rubber, deform=None) -> dict:
    """Flat: every tube in two planes a tube apart, the seat folded up flat
    against the front. Origin at the top rail's centre; the chair hangs down
    -Y; front of the seat faces -Z. Held by the two front legs."""
    frame = kit.WeaponPart(prefix + "_frame", deform)
    panels = kit.WeaponPart(prefix + "_panels", deform)
    feet = kit.WeaponPart(prefix + "_feet", deform)
    top = 0.0
    bottom = -FOLDED_LEN
    outer = [(bottom, 0.0), (bottom + 0.3, 0.0), (top - 0.32, 0.0), (top - 0.05, 0.0)]
    _u_frame(frame, outer, FRAME_HALF)
    rz = TUBE_R * 2.05
    rear = [(bottom - 0.01, rz), (bottom + 0.2, rz), (bottom + 0.42, rz), (bottom + 0.47, rz)]
    _u_frame(frame, rear, REAR_HALF, top_r=0.03)
    frame.tube([Vector((-FRAME_HALF, bottom + 0.13, 0)), Vector((FRAME_HALF, bottom + 0.13, 0))], TUBE_R * 0.8, SIDES)
    frame.tube([Vector((-REAR_HALF, bottom + 0.12, rz)), Vector((REAR_HALF, bottom + 0.12, rz))], TUBE_R * 0.8, SIDES)
    # seat folded flat on the front, hinge at its top
    sz = -TUBE_R - 0.012
    seat_top = -0.33
    for x in (-REAR_HALF + 0.01, REAR_HALF - 0.01):
        frame.tube([Vector((x, seat_top, sz + 0.008)), Vector((x, seat_top - SEAT_D + 0.02, sz + 0.008))], 0.009, 8)
    corner = Vector((-SEAT_W / 2, seat_top - SEAT_D, sz))
    panels.grid_panel(corner, Vector((SEAT_W, 0, 0)), Vector((0, SEAT_D, 0)), 16, 16, PANEL_T,
                      lambda s, t: 0.010 * math.sin(math.pi * s) * math.sin(math.pi * t))
    panels.tube(kit.rounded_rect(Vector((0, seat_top - SEAT_D / 2, sz)), Vector((1, 0, 0)), Vector((0, 1, 0)),
                                 SEAT_W / 2, SEAT_D / 2, 0.035), RIM_R, 8, caps=False)
    back_corner = Vector((-BACK_W / 2, -0.21, 0.0))
    panels.grid_panel(back_corner, Vector((BACK_W, 0, 0)), Vector((0, BACK_H, 0)), 12, 6, PANEL_T,
                      lambda s, t: 0.012 * math.sin(math.pi * s))
    for x in (-FRAME_HALF - TUBE_R, FRAME_HALF + TUBE_R):
        sx = math.copysign(1, x)
        _rivet(frame, Vector((x, seat_top, 0.0)), Vector((sx, 0, 0)))
        _rivet(frame, Vector((x, bottom + 0.46, rz * 0.5)), Vector((sx, 0, 0)))
    _feet(feet, [(Vector((s * FRAME_HALF, bottom - 0.004, 0)), Vector((0, 1, 0))) for s in (-1, 1)]
          + [(Vector((s * REAR_HALF, bottom - 0.014, rz)), Vector((0, 1, 0))) for s in (-1, 1)])
    objs = {
        "frame": kit.add_mesh(root, frame, paint),
        "panels": kit.add_mesh(root, panels, paint),
        "feet": kit.add_mesh(root, feet, rubber),
    }
    # Swung by the legs, as it is at ringside: a hand round each front leg
    # just above the rubber feet, so the flat of the seat and back comes down
    # on him. +Y up the chair toward the striking end, +Z out of the back of
    # the hand (the chair's back, +Z).
    grip_y = bottom + 0.07
    kit.marker(root, "grip_r", Vector((FRAME_HALF, grip_y, 0.0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    kit.marker(root, "grip_l", Vector((-FRAME_HALF, grip_y, 0.0)), Vector((0, 1, 0)), Vector((0, 0, 1)))
    # the middle of the flat it lands with: the upper seat, on its front face
    kit.marker(root, "strike", Vector((0, seat_top - 0.08, sz - 0.01)), Vector((0, 1, 0)), Vector((0, 0, -1)))
    return objs


def bent(p: Vector) -> Vector:
    """The damage of a run of chair shots on a folded chair: the rails bowed
    back, the seat caved in round a buckle line across it, a twist."""
    t = min(max(-p.y / FOLDED_LEN, 0.0), 1.0)
    q = Vector(p)
    q.z += 0.045 * math.sin(math.pi * t)                       # bow
    q.x += 0.012 * math.sin(math.pi * t) * (p.y + 0.4) * 2.0    # twist
    # the seat panel (in front, z < -0.015): a deep cave and a crease
    if p.z < -0.012 and -0.73 < p.y < -0.32:
        cx, cy = 0.04, -0.54
        r2 = ((p.x - cx) / 0.16) ** 2 + ((p.y - cy) / 0.13) ** 2
        q.z += 0.055 * math.exp(-r2 * 1.6)
        crease = abs((p.y + 0.50) - 0.25 * p.x)
        q.z += 0.018 * math.exp(-(crease / 0.02) ** 2)
        q.y += 0.01 * math.exp(-r2)
    # the back panel dinged at one corner
    if -0.22 < p.y < -0.04:
        q.z += 0.02 * math.exp(-(((p.x + 0.12) / 0.07) ** 2 + ((p.y + 0.08) / 0.06) ** 2))
    return q


def stencil_decal(root, prefix: str, mat, at: Vector, size: tuple, normal_z: float, deform=None):
    part = kit.WeaponPart(prefix + "_stencil", deform)
    w, h = size
    v = [part.vert(at + Vector((sx * w / 2, sy * h / 2, 0))) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    if normal_z > 0:
        part.bm.faces.new(v)
    else:
        part.bm.faces.new(list(reversed(v)))
    mesh = kit.bpy.data.meshes.new(part.name)
    part.bm.to_mesh(mesh)
    part.bm.free()
    uv = mesh.uv_layers.new(name="UVMap")
    for li, loop in enumerate(mesh.loops):
        u, vv = ((0, 0), (1, 0), (1, 1), (0, 1))[loop.vertex_index]
        uv.data[li].uv = (1 - u if normal_z < 0 else u, vv)
    mesh.materials.append(mat)
    obj = kit.bpy.data.objects.new(part.name, mesh)
    kit.bpy.context.collection.objects.link(obj)
    obj.parent = root
    return obj


def wrap_wire(root, prefix: str, wire_mat, folded: bool, rng) -> None:
    part = kit.WeaponPart(prefix + "_wire")
    if folded:
        # coils round the folded chair over the seat, and two round the back
        seat_c = Vector((0, -0.52, -0.004))
        part_paths = [
            kit.helix_around_box(seat_c, Vector((0, 1, 0)), Vector((1, 0, 0)), Vector((0, 0, 1)),
                                 FRAME_HALF + 0.022, 0.034, 0.30, 3.5),
            kit.helix_around_box(Vector((0, -0.13, 0.0)), Vector((0, 1, 0)), Vector((1, 0, 0)),
                                 Vector((0, 0, 1)), FRAME_HALF + 0.02, 0.022, 0.08, 1.5),
        ]
    else:
        seat_c = Vector((0, 0.452, -0.01))
        part_paths = [
            kit.helix_around_box(seat_c, Vector((0, 0, 1)), Vector((1, 0, 0)), Vector((0, 1, 0)),
                                 SEAT_W / 2 + 0.012, 0.022, 0.30, 3.5),
            kit.helix_around_box(Vector((0, 0.68, 0.083)), Vector((0, 1, 0.28)).normalized(), Vector((1, 0, 0)),
                                 Vector((0, -0.28, 1)).normalized(), FRAME_HALF + 0.02, 0.026, 0.10, 1.5),
        ]
    for path in part_paths:
        # a loose end trailing off each coil
        end = path[-1]
        tail = [end, end + Vector((0.03, -0.02, -0.04)), end + Vector((0.07, -0.07, -0.06)),
                end + Vector((0.09, -0.13, -0.05))]
        kit.barbed_wire(part, path + tail[1:], rng)
    kit.add_mesh(root, part, wire_mat, smooth=True, uv_scale=4.0, auto_smooth_deg=180.0)


def main() -> None:
    report = []
    for weapon_id, roots in (("steel_chair", ("SteelChair_Folded", "SteelChair_Open", "SteelChair_Bent")),
                             ("barbed_wire_chair", ("BarbedWireChair_Folded", "BarbedWireChair_Open"))):
        kit.reset()
        # charcoal enamel on the arena chair, a lighter grey on the wire one
        base, orm, nrm = paint_textures(weapon_id, (0.15, 0.155, 0.16) if weapon_id == "steel_chair"
                                        else (0.24, 0.25, 0.26), 0.34 if weapon_id == "steel_chair" else 0.29)
        paint = kit.pbr_material(weapon_id + "_paint", base, orm, nrm, 0.8)
        rubber = kit.flat_material(weapon_id + "_rubber", (0.025, 0.025, 0.025), 0.85)
        stencil = kit.pbr_material(weapon_id + "_stencil", stencil_texture(weapon_id, "17"), None, None,
                                   roughness=0.6, alpha=True)
        wire = None
        if weapon_id == "barbed_wire_chair":
            wb, wo = wire_textures(weapon_id)
            wire = kit.pbr_material(weapon_id + "_wire", wb, wo, None)
        rng = np.random.RandomState(kit.seed_of(weapon_id + "_barbs"))
        for root_name in roots:
            root = kit.state_root(root_name)
            state = root_name.split("_")[-1]
            if state == "Open":
                build_open(root, root_name, paint, rubber)
                stencil_decal(root, root_name, stencil, Vector((0, 0.69, 0.115)), (0.16, 0.08), 1.0,
                              deform=lambda p: Vector((p.x, p.y, p.z + (p.y - 0.69) * 0.28 + 0.003)))
            else:
                deform = bent if state == "Bent" else None
                build_folded(root, root_name, paint, rubber, deform)
                stencil_decal(root, root_name, stencil, Vector((0, -0.13, 0.0035 + 0.012)), (0.16, 0.08), 1.0,
                              deform)
            if wire is not None:
                wrap_wire(root, root_name, wire, state == "Folded", rng)
            report.append("%s %s: %d triangles" % (weapon_id, root_name, kit.triangles_under(root)))
        out = kit.export(weapon_id)
        report.append("wrote " + str(out.relative_to(kit.ROOT)))
    print("\n".join(report))


if __name__ == "__main__":
    main()
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]))
    import bpy_exit  # noqa: E402 -- skip bpy's teardown segfault (see there)
    bpy_exit.finish(0)
