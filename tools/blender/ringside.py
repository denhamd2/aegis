#!/usr/bin/env python3
"""Build the ringside floor, its panel joints and the barricades in Blender.

Run:  tools/blender/build_venue.sh ringside

What this builds
----------------
The event floor slab, the joints between the decking panels laid over the ice,
and the four runs of barricade around the ring.

What moving it buys
-------------------
Only one of the three gains anything from Blender, and it is said plainly
because the other two are here for completeness rather than for craft:

* **The barricades.** They were flat boxes: a panel, a cap rail and a leg,
  each a sharp-edged slab. A real barricade is a steel frame -- a panel with a
  chamfered edge, a ROUND capping rail, and a raking leg that is a tube. The
  cap rail is the part that matters: it is the only horizontal at ringside
  catching the house rig, it runs right across the wide shot at chest height,
  and a box cannot take a highlight along its length the way a tube does.
* **The floor slab** is one box and stays one box. It is here so the whole
  ringside is one model rather than half a model.
* **The panel joints** keep their analytic clip to the rink's own plan: at a
  given x the decking reaches `BOWL_STRAIGHT_Z + sqrt(r^2 - dx^2)`, so a joint
  stops where the decking does instead of running out over the seating. They
  are flat strips a hair above the floor rather than grooves cut into it -- a
  joint is 5 cm wide and a groove would need three faces where one strip is
  identical from every camera in the shotlist.

Dimensions are READ OUT OF `game/core/arena/arena_builder.gd`, never retyped.
"""

from __future__ import annotations

import argparse
import math
import pathlib
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))

import venue  # noqa: E402 -- venue imports bpy, which registers mathutils
from venue import Part  # noqa: E402
from mathutils import Vector  # noqa: E402

import bpy_exit  # noqa: E402

WANTED = [
    "FLOOR_Y", "WALL_EXTENT", "WALL_EXTENT_X",
    "FLOOR_SEAM_PITCH", "FLOOR_SEAM_WIDTH",
    "RINK_HALF_LENGTH", "RINK_HALF_WIDTH", "RINK_CORNER_RADIUS",
    "BOWL_STRAIGHT_X", "BOWL_STRAIGHT_Z",
    "BARRICADE_RADIUS", "BARRICADE_HEIGHT", "BARRICADE_PANEL", "BARRICADE_JOIN",
    "BARRICADE_GAP", "RINGSIDE_MAT_LIFT", "RAMP_HALF_WIDTH",
    "DESK_BAY_X0", "DESK_BAY_Z", "DESK_X",
    "DESK_Z", "DESK_LENGTH", "DESK_HEIGHT", "DESK_DEPTH",
    "DESK_TOP_THICKNESS", "DESK_TOP_OVERHANG", "DESK_LED_HEIGHT", "DESK_RISER",
    "DESK_MONITORS", "DESK_MONITOR_WIDTH", "DESK_MONITOR_HEIGHT",
    "DESK_MONITOR_DEPTH", "DESK_MONITOR_TILT",
]

# Placeholder colours only; arena_builder.gd overrides every part by name.
PART_COLORS = {
    "Floor": (0.14, 0.14, 0.16, 1.0),
    "RingsideMat": (0.035, 0.035, 0.040, 1.0),
    "FloorSeams": (0.09, 0.09, 0.10, 1.0),
    "Barricades": (0.30, 0.31, 0.34, 1.0),
    "CommentaryDesk": (0.10, 0.10, 0.12, 1.0),
    "CommentaryDeskTop": (0.38, 0.39, 0.42, 1.0),
    "CommentaryDeskLed": (0.20, 0.25, 0.80, 1.0),
    "CommentaryRiser": (0.05, 0.05, 0.06, 1.0),
    "CommentaryKit": (0.04, 0.04, 0.045, 1.0),
    "CommentaryScreens": (0.30, 0.40, 0.60, 1.0),
}
SMOOTH = frozenset({"CommentaryKit"})
## The LED face carries its own UVs (one tile of the ribbon art across the
## desk); everything else is cube-projected.
PROJECTED = frozenset(PART_COLORS) - {"CommentaryDeskLed", "CommentaryScreens"}
FACE_TOWARD = {"CommentaryDeskLed": (0.0, 0.0, -1.0)}


def build_floor(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The slab.

    WALL_EXTENT_X on the long axis: the bowl reaches further down +-X than it
    does down +-Z, and a square slab under an obround hall leaves the back
    rows standing over nothing.
    """
    parts["Floor"].box(
        Vector((0.0, cfg["FLOOR_Y"] - 0.1, 0.0)),
        Vector((cfg["WALL_EXTENT_X"] * 2.0, 0.2, cfg["WALL_EXTENT"] * 2.0)),
    )


def build_seams(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The joints between the decking panels, clipped to the rink's plan."""
    seams = parts["FloorSeams"]
    r = cfg["RINK_CORNER_RADIUS"]

    def reach_z(x: float) -> float:
        dx = max(abs(x) - cfg["BOWL_STRAIGHT_X"], 0.0)
        return cfg["BOWL_STRAIGHT_Z"] + math.sqrt(max(r * r - dx * dx, 0.0))

    def reach_x(z: float) -> float:
        dz = max(abs(z) - cfg["BOWL_STRAIGHT_Z"], 0.0)
        return cfg["BOWL_STRAIGHT_X"] + math.sqrt(max(r * r - dz * dz, 0.0))

    pitch = cfg["FLOOR_SEAM_PITCH"]
    width = cfg["FLOOR_SEAM_WIDTH"]
    y = cfg["FLOOR_Y"] + 0.004
    steps = int(cfg["RINK_HALF_WIDTH"] / pitch)
    for i in range(-steps, steps + 1):
        at = i * pitch
        seams.box(Vector((at, y, 0.0)),
                  Vector((width, 0.008, reach_z(at) * 2.0)))
    steps = int(cfg["RINK_HALF_LENGTH"] / pitch)
    for i in range(-steps, steps + 1):
        at = i * pitch
        seams.box(Vector((0.0, y, at)),
                  Vector((reach_x(at) * 2.0, 0.008, width)))


def build_ringside_mat(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The black matting from the barrier in to the ring.

    A real ringside floor is not the bare deck: it is covered in interlocking
    rubber mats, and they are the dark ground the ring, the steps and the
    wrestlers working outside are all read against. It is also what the
    entrance ramp comes down ONTO -- the ramp stops at this mat's outer edge,
    and the mat carries the last few metres to the apron.

    Laid as one slab a few millimetres above the floor rather than as tiles.
    At every camera in the shotlist the joins between mats are below a pixel,
    and the ring, the steps and the barricade all stand on top of it.
    """
    reach = cfg["BARRICADE_RADIUS"]
    y = cfg["FLOOR_Y"] + cfg["RINGSIDE_MAT_LIFT"] * 0.5
    parts["RingsideMat"].box(
        Vector((0.0, y, 0.0)),
        Vector((reach * 2.0, cfg["RINGSIDE_MAT_LIFT"], reach * 2.0)),
    )
    # And on into the desk's bay (arena_builder.gd DESK_BAY_*).
    x0, bay_z = cfg["DESK_BAY_X0"], cfg["DESK_BAY_Z"]
    parts["RingsideMat"].box(
        Vector(((x0 + reach) * 0.5, y, (reach + bay_z) * 0.5)),
        Vector((reach - x0, cfg["RINGSIDE_MAT_LIFT"], bay_z - reach)),
    )


def _box(part: Part, centre: Vector, axes: tuple[Vector, Vector, Vector],
         size: Vector, bevel: float = 0.0, segments: int = 1) -> None:
    """A box in any frame -- `axes` are its width, height and depth
    directions -- for the tilted pieces oriented_box (always upright) cannot
    make: a monitor leaning back, a laptop lid, a chair back."""
    ea, eu, eo = (axes[0].normalized() * (size.x * 0.5),
                  axes[1].normalized() * (size.y * 0.5),
                  axes[2].normalized() * (size.z * 0.5))
    corners = [
        centre + ea * sa + eu * su + eo * so
        for sa, su, so in (
            (-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
            (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1),
        )
    ]
    faces = ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
             (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
    if bevel > 0.0:
        part._beveled(corners, faces, bevel, segments)
        return
    v = [part.vert(c) for c in corners]
    for face in faces:
        part.quad(*[v[i] for i in face])


def build_commentary_desk(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """The commentary desk, in its own bay on +Z (arena_builder.gd DESK_*).

    Built to read at broadcast range the way WWE 2K's announce table does:

    * a low carpeted RISER under the desk and chairs -- the team's own area;
    * the desk body with a kick plate and proud end panels, and on its ring
      side an LED FACE showing the ribbon boards' art (2K26's announce-table
      cover; the face is its own part so Godot can light it);
    * a thick WORKTOP with a padded, rounded front edge, overhanging the body
      -- the shadow line under it is what makes a desk read as a desk;
    * per commentator, a MONITOR on a short stand tilted back at the seat, a
      HEADSET on the desk and a high-backed CHAIR behind it; two laptops
      between them.

    The team sits on the far (+Z) side facing the ring, as in
    `aew_low_angle_led_wall.jpg`, so the LED face is toward the ring and the
    hard camera, and the monitors face away from it.
    """
    body = parts["CommentaryDesk"]
    top = parts["CommentaryDeskTop"]
    led = parts["CommentaryDeskLed"]
    riser = parts["CommentaryRiser"]
    kit = parts["CommentaryKit"]
    screens = parts["CommentaryScreens"]
    x0, z = cfg["DESK_X"], cfg["DESK_Z"]
    depth = cfg["DESK_DEPTH"]
    length = cfg["DESK_LENGTH"]
    floor_y = cfg["FLOOR_Y"]
    base_y = floor_y + cfg["DESK_RISER"]
    top_y = floor_y + cfg["DESK_HEIGHT"]
    thickness = cfg["DESK_TOP_THICKNESS"]
    overhang = cfg["DESK_TOP_OVERHANG"]
    front_z = z - depth * 0.5
    back_z = z + depth * 0.5
    X = Vector((1.0, 0.0, 0.0))
    Y = Vector((0.0, 1.0, 0.0))
    Z = Vector((0.0, 0.0, 1.0))

    # The riser: from in front of the desk back to the bay's barricade, short
    # of the bay's ends.
    r_front = front_z - 0.35
    r_back = cfg["DESK_BAY_Z"] - 0.12
    r_x0 = cfg["DESK_BAY_X0"] + 0.25
    r_x1 = cfg["BARRICADE_RADIUS"] - 0.15
    riser.box(Vector(((r_x0 + r_x1) * 0.5, floor_y + cfg["DESK_RISER"] * 0.5,
                      (r_front + r_back) * 0.5)),
              Vector((r_x1 - r_x0, cfg["DESK_RISER"], r_back - r_front)), bevel=0.012)

    # Body: riser to just under the worktop, the ends standing proud of it.
    body_h = top_y - thickness - base_y
    body.box(Vector((x0, base_y + body_h * 0.5, z)),
             Vector((length - 0.08, body_h, depth)), bevel=0.01)
    for sx in (-1.0, 1.0):
        body.box(Vector((x0 + sx * (length * 0.5 - 0.03), base_y + body_h * 0.5, z)),
                 Vector((0.06, body_h, depth + 0.04)), bevel=0.012, bevel_segments=2)
    # Kick plate along the ring side.
    kick = 0.09
    body.box(Vector((x0, base_y + kick * 0.5, front_z - 0.012)),
             Vector((length - 0.08, kick, 0.03)), bevel=0.006)
    # The LED face: one quad, one tile of the ribbon art across it, u running
    # left to right as the ring sees it (screen-right from +Z looking in is -X).
    led_y0 = base_y + kick + 0.03
    led_y1 = led_y0 + cfg["DESK_LED_HEIGHT"]
    fz = front_z - 0.004
    lx0, lx1 = x0 - (length * 0.5 - 0.07), x0 + (length * 0.5 - 0.07)
    a = led.vert(Vector((lx1, led_y0, fz)))
    b = led.vert(Vector((lx0, led_y0, fz)))
    c = led.vert(Vector((lx0, led_y1, fz)))
    d = led.vert(Vector((lx1, led_y1, fz)))
    led.quad(a, b, c, d, uvs=[(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)])

    # Worktop, proud of the body on every side, its edges rounded.
    top.box(Vector((x0, top_y - thickness * 0.5, z)),
            Vector((length + overhang * 2.0, thickness, depth + overhang * 2.0)),
            bevel=0.02, bevel_segments=3)
    # The padded bumper along its ring-side edge.
    kit.tube([Vector((x0 - length * 0.5 - overhang + 0.03, top_y - thickness * 0.5,
                      front_z - overhang)),
              Vector((x0 + length * 0.5 + overhang - 0.03, top_y - thickness * 0.5,
                      front_z - overhang))], thickness * 0.62, sides=10)

    # Seats: one per monitor, evenly along the desk.
    count = int(cfg["DESK_MONITORS"])
    pitch = length / float(count)
    m_w, m_h, m_d = (cfg["DESK_MONITOR_WIDTH"], cfg["DESK_MONITOR_HEIGHT"],
                     cfg["DESK_MONITOR_DEPTH"])
    tilt = math.radians(cfg["DESK_MONITOR_TILT"])
    seat_xs = [x0 + (i + 0.5) * pitch - length * 0.5 for i in range(count)]
    for i, sx in enumerate(seat_xs):
        # Monitor: a foot, a short neck, and the housing leaning back toward
        # the seat with its screen on the seat side.
        mz = z - depth * 0.18
        kit.box(Vector((sx, top_y + 0.008, mz)), Vector((0.22, 0.016, 0.16)), bevel=0.004)
        kit.cylinder(Vector((sx, top_y, mz)), Y, 0.018, 0.16, sides=8)
        up = Vector((0.0, math.cos(tilt), -math.sin(tilt)))
        out = Vector((0.0, math.sin(tilt), math.cos(tilt)))
        centre = Vector((sx, top_y + 0.13 + m_h * 0.5 * math.cos(tilt), mz))
        _box(kit, centre, (X, up, out), Vector((m_w, m_h, m_d)), bevel=0.006)
        # Screen face, a few millimetres proud of the housing toward the seat.
        sc = centre + out * (m_d * 0.5 + 0.002)
        ew, eh = X * (m_w * 0.46), up * (m_h * 0.44)
        q = [screens.vert(sc - ew - eh), screens.vert(sc + ew - eh),
             screens.vert(sc + ew + eh), screens.vert(sc - ew + eh)]
        screens.quad(*q)
        # Headset, on the desk in front of the seat: a band and two cups.
        hz = back_z - 0.2
        hx = sx + 0.32
        band = [Vector((hx + 0.09 * math.cos(t), top_y + 0.03 + 0.07 * math.sin(t), hz))
                for t in [math.pi * k / 8.0 for k in range(9)]]
        kit.tube(band, 0.008, sides=6, caps=True)
        for side in (-1.0, 1.0):
            kit.cylinder(Vector((hx + side * 0.09, top_y, hz)), Y, 0.04, 0.045, sides=10)
        # Chair: five-star base, gas column, seat, tilted high back.
        cz = back_z + 0.42
        for k in range(5):
            ang = 2.0 * math.pi * k / 5.0
            leg = Vector((math.cos(ang), 0.0, math.sin(ang)))
            kit.oriented_box(Vector((sx, base_y + 0.04, cz)) + leg * 0.15, leg,
                             Vector((-leg.z, 0.0, leg.x)), Vector((0.3, 0.03, 0.04)))
        kit.cylinder(Vector((sx, base_y + 0.05, cz)), Y, 0.025, 0.36, sides=8)
        seat_y = base_y + 0.48
        kit.box(Vector((sx, seat_y, cz)), Vector((0.5, 0.08, 0.48)), bevel=0.025, bevel_segments=2)
        back_tilt = math.radians(12.0)
        bup = Vector((0.0, math.cos(back_tilt), math.sin(back_tilt)))
        bout = Vector((0.0, -math.sin(back_tilt), math.cos(back_tilt)))
        _box(kit, Vector((sx, seat_y + 0.38, cz + 0.24 + 0.36 * math.sin(back_tilt))),
             (X, bup, bout), Vector((0.48, 0.68, 0.08)), bevel=0.025, segments=2)
        # A laptop between this seat and the next.
        if i < count - 1:
            lx = (sx + seat_xs[i + 1]) * 0.5
            lz = back_z - 0.22
            kit.box(Vector((lx, top_y + 0.009, lz)), Vector((0.33, 0.018, 0.23)), bevel=0.003)
            lid = math.radians(105.0)
            lup = Vector((0.0, math.sin(lid), math.cos(lid)))
            lout = Vector((0.0, -math.cos(lid), math.sin(lid)))
            lc = Vector((lx, top_y + 0.018, lz - 0.115)) + lup * 0.11
            _box(kit, lc, (X, lup, lout), Vector((0.33, 0.22, 0.01)))
            ls = lc + lout * 0.006
            ew, eh = X * 0.15, lup * 0.095
            q = [screens.vert(ls - ew - eh), screens.vert(ls + ew - eh),
                 screens.vert(ls + ew + eh), screens.vert(ls - ew + eh)]
            screens.quad(*q)


def build_barricades(cfg: dict[str, float], parts: dict[str, Part]) -> None:
    """Runs of discrete panels, each with a round cap rail and a leg.

    The runs are `ArenaBuilder.barricade_panels()`'s, mirrored here: the four
    sides of the ring with the entrance GAP on -Z, and on +Z the desk's bay --
    the barricade steps back to DESK_BAY_Z from the panel joint at
    DESK_BAY_X0 to the +X corner, the +X run carries on to meet it, and a
    return closes it. A run of length L takes int(L / PANEL) panels at an
    even pitch.

    The -Z run's GAP: the ramp's foot lands on this line, and a panel whose
    centre clears the gap by less than its own half-width still puts its end
    through the opening -- the first attempt left two of them standing in
    the entrance.
    """
    barricade = parts["Barricades"]
    height = cfg["BARRICADE_HEIGHT"]
    y = cfg["FLOOR_Y"] + height * 0.5
    top = cfg["FLOOR_Y"] + height
    r = cfg["BARRICADE_RADIUS"]
    x0, bay_z = cfg["DESK_BAY_X0"], cfg["DESK_BAY_Z"]
    runs = [
        (Vector((-r, 0, -r)), Vector((r, 0, -r)), Vector((0.0, 0.0, -1.0))),
        (Vector((-r, 0, -r)), Vector((-r, 0, r)), Vector((-1.0, 0.0, 0.0))),
        (Vector((r, 0, -r)), Vector((r, 0, bay_z)), Vector((1.0, 0.0, 0.0))),
        (Vector((-r, 0, r)), Vector((x0, 0, r)), Vector((0.0, 0.0, 1.0))),
        (Vector((x0, 0, r)), Vector((x0, 0, bay_z)), Vector((-1.0, 0.0, 0.0))),
        (Vector((x0, 0, bay_z)), Vector((r, 0, bay_z)), Vector((0.0, 0.0, 1.0))),
    ]
    for a, b, out in runs:
        length = (b - a).length
        count = max(1, int(length / cfg["BARRICADE_PANEL"]))
        pitch = length / count
        width = pitch - cfg["BARRICADE_JOIN"]
        along = Vector((out.z, 0.0, -out.x))
        step = (b - a).normalized()
        for i in range(count):
            at = a + step * (pitch * (i + 0.5))
            if out.z < -0.5 and abs(at.x) - width * 0.5 < cfg["BARRICADE_GAP"]:
                continue
            barricade.oriented_box(at + Vector((0.0, y, 0.0)), along, out,
                                   Vector((width, height, 0.14)))
            # The cap rail: a TUBE, because it is the only horizontal at
            # ringside at chest height and it runs across the whole wide
            # shot. A box takes a highlight on one facet; a tube takes one
            # along its length, which is what reads as steel.
            rail_y = top - 0.035
            half = along * (width * 0.5)
            barricade.tube(
                [at + Vector((0.0, rail_y, 0.0)) - half,
                 at + Vector((0.0, rail_y, 0.0)) + half],
                0.048, sides=8,
            )
            # One leg per panel, behind it, raking out to the floor. A tube
            # again: at ringside distance its silhouette is the whole of what
            # it contributes, and a round one is never seen edge-on as a line.
            barricade.tube(
                [at + Vector((0.0, top - 0.18, 0.0)),
                 at + out * 0.42 + Vector((0.0, cfg["FLOOR_Y"] + 0.02, 0.0))],
                0.028, sides=6,
            )


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(venue.ASSET_DIR / "ringside.glb"))
    args = parser.parse_args(argv)

    cfg = venue.read_constants(venue.ARENA_GD, WANTED)
    venue.reset_scene()
    parts = {name: Part(name) for name in PART_COLORS}
    build_floor(cfg, parts)
    build_seams(cfg, parts)
    build_ringside_mat(cfg, parts)
    build_barricades(cfg, parts)
    build_commentary_desk(cfg, parts)
    venue.finish(parts, PART_COLORS, smooth=SMOOTH, projected=PROJECTED,
                 face_toward=FACE_TOWARD)

    out = pathlib.Path(args.out)
    venue.export_glb(out)
    print("ringside: %d triangles, %s" % (venue.triangle_count(), out))
    return 0


if __name__ == "__main__":
    bpy_exit.finish(main(sys.argv[1:]))
