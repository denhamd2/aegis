#!/usr/bin/env python3
"""Shared Blender foundation for every piece of the venue.

`arena_bowl.py` established the pattern this module generalises: the geometry
of the hall is built in Blender from the constants that already live in
GDScript, exported as a committed `.glb`, and then *dressed* in Godot, which
overrides each named object with a `MaterialLibrary` material. Blender owns
shape; Godot keeps owning look, physics and anything that moves.

That split is why these scripts can build things GDScript could not. The
entrance ramp is the clearest case: `arena_builder.gd` says outright that
"axis-aligned boxes are all this file builds", so a 25.7 m ramp with a 6%
grade shipped as **eighteen stacked boxes** pretending to be a slope. A ramp
is a wedge. Here it can simply be one.

What lives here
---------------
* `read_constants` -- the single-source-of-truth parser. Every shared number
  is read out of the GDScript that already declares it, never retyped, so the
  mesh and the game cannot drift apart.
* `to_blender` -- the one place the two coordinate frames disagree.
* `Part` -- one exported object, with the primitives the venue is made of:
  boxes (optionally bevelled), swept tubes, arcs, revolved rings and lattices.
* `finish` / `export_glb` -- deterministic output, so a rebuild with no input
  change produces a byte-identical file that can be diffed and reviewed.

Determinism
-----------
No RNG, no timestamps, no dependence on dict iteration beyond the insertion
order the callers fix. Rebuilding without changing an input must reproduce the
file byte for byte; that is what makes a committed binary reviewable.
"""

from __future__ import annotations

import math
import pathlib
import re

import bpy  # noqa: I001 -- the bpy module registers the rest; it imports first
import bmesh
from mathutils import Vector

# A trailing `## doc comment` is normal in this codebase, and a parser that
# silently fails to see such a constant is a trap: it reports the constant
# missing and invites someone to hard-code the number here instead.
CONST_RE = re.compile(
    r"const\s+([A-Z0-9_]+)\s*:=\s*(-?[0-9.]+)\s*(?:#.*)?$")

REPO = pathlib.Path(__file__).resolve().parents[2]
ARENA_GD = REPO / "game" / "core" / "arena" / "arena_builder.gd"
RING_GD = REPO / "game" / "core" / "ring" / "ring_builder.gd"
ASSET_DIR = REPO / "game" / "assets" / "environment"


def read_constants(path: pathlib.Path, wanted: list[str]) -> dict[str, float]:
    """Parse `const NAME := <number>` out of a GDScript file.

    Only plain numeric literals are read. Anything derived (`SCREEN_CENTER_Y`
    is `STAGE_DECK_Y + 9.0`) is out of scope on purpose: this parser exists to
    share measurements, not to evaluate GDScript.

    A missing constant is a hard failure rather than a default, because a
    default is how a mesh silently stops matching the game it is built for.
    """
    found: dict[str, float] = {}
    for line in path.read_text().splitlines():
        match = CONST_RE.match(line.strip())
        if match and match.group(1) in wanted:
            found[match.group(1)] = float(match.group(2))
    missing = [name for name in wanted if name not in found]
    if missing:
        raise SystemExit(
            "venue.py: %s does not define %s as plain numeric constants. "
            "Add them there rather than hard-coding them here."
            % (path, ", ".join(missing))
        )
    return found


def to_blender(point: Vector) -> Vector:
    """Godot's frame -> Blender's, the one place the two disagree.

    Every calculation in these files is done in the GAME's frame: +Y is up,
    the bowl's straights run down +-X, and the entrance set fills -Z -- so the
    numbers here read the same as the numbers in the GDScript, and a tread
    height in one is a tread height in the other.

    Blender is Z-up, and its glTF exporter (with `export_yup`) rewrites
    (x, y, z) as (x, z, -y). Composing the two, a game-frame point must be
    stored as (x, -z, y) for the export to put it back where it started. That
    map is a rotation, not a mirror, so winding and normals survive it and
    `recalc_face_normals` still means what it says.
    """
    return Vector((point.x, -point.z, point.y))


def arc(center: Vector, radius: float, start: float, end: float,
        segments: int, axis: str = "y") -> list[Vector]:
    """Points along a circular arc, in the game frame.

    `axis` names the axis the circle is normal to: "y" for a plan-view arc
    (the bowl's corners, a barricade's bend), "z" for an upright ring facing
    the camera (the entrance portals).
    """
    points: list[Vector] = []
    for i in range(segments + 1):
        theta = start + (end - start) * i / segments
        cos_t, sin_t = math.cos(theta), math.sin(theta)
        if axis == "y":
            points.append(center + Vector((radius * cos_t, 0.0, radius * sin_t)))
        elif axis == "z":
            points.append(center + Vector((radius * cos_t, radius * sin_t, 0.0)))
        else:
            points.append(center + Vector((0.0, radius * sin_t, radius * cos_t)))
    return points


def _frames(points: list[Vector]) -> list[tuple[Vector, Vector, Vector]]:
    """Parallel-transported frames along a polyline.

    A tube swept with a fixed up-vector twists wherever the path turns toward
    it, and degenerates entirely where the path runs vertical -- which a rope
    termination and a truss diagonal both do. Transporting the previous frame
    onto each new tangent keeps the cross-section from spinning along the run.
    """
    out: list[tuple[Vector, Vector, Vector]] = []
    up = Vector((0.0, 1.0, 0.0))
    normal = None
    for i, point in enumerate(points):
        if i == 0:
            tangent = (points[1] - points[0])
        elif i == len(points) - 1:
            tangent = (points[-1] - points[-2])
        else:
            tangent = (points[i + 1] - points[i - 1])
        if tangent.length < 1e-9:
            tangent = Vector((0.0, 0.0, 1.0))
        tangent = tangent.normalized()
        if normal is None:
            seed = up if abs(tangent.dot(up)) < 0.95 else Vector((1.0, 0.0, 0.0))
            normal = (seed - tangent * seed.dot(tangent)).normalized()
        else:
            normal = (normal - tangent * normal.dot(tangent))
            if normal.length < 1e-9:
                seed = up if abs(tangent.dot(up)) < 0.95 else Vector((1.0, 0.0, 0.0))
                normal = (seed - tangent * seed.dot(tangent))
            normal = normal.normalized()
        binormal = tangent.cross(normal).normalized()
        out.append((tangent, normal, binormal))
    return out


class Part:
    """One exported object: a bmesh plus the name Godot dresses it by.

    Parts are separate objects rather than one merged mesh because the
    GDScript applies a `MaterialLibrary` material per part by node name -- a
    ring's canvas, its ropes and its steel steps are three different surfaces
    and the hall's house-lighting compensation is solved per material.
    """

    def __init__(self, name: str) -> None:
        self.name = name
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.verify()

    # --- primitives ------------------------------------------------------

    def vert(self, position: Vector) -> bmesh.types.BMVert:
        return self.bm.verts.new(to_blender(position))

    def quad(self, a, b, c, d, uvs: list[tuple[float, float]] | None = None) -> None:
        try:
            face = self.bm.faces.new((a, b, c, d))
        except ValueError:
            return  # Duplicate face where two solids share a wall; harmless.
        if uvs:
            for loop, coord in zip(face.loops, uvs):
                loop[self.uv].uv = coord

    def tri(self, a, b, c) -> None:
        try:
            self.bm.faces.new((a, b, c))
        except ValueError:
            pass

    def quad_at(self, a: Vector, b: Vector, c: Vector, d: Vector,
                uvs: list[tuple[float, float]] | None = None) -> None:
        """A quad from four positions, with optional explicit UVs.

        Explicit UVs matter for exactly the surfaces carrying a drawn texture
        -- the ring canvas's seams and wear are painted in world space and
        must land where they are drawn, not tile arbitrarily.
        """
        self.quad(self.vert(a), self.vert(b), self.vert(c), self.vert(d), uvs)

    def prism(self, inner: list[Vector], outer: list[Vector],
              base_y: float, top_y: float, closed: bool) -> None:
        """A closed solid swept along two polylines, from `base_y` to `top_y`.

        Solid rather than a surface because pieces STACK and bury each other's
        walls; a solid guarantees there is no gap to see the floor through at
        the join. Winding is fixed up once at export by `recalc_face_normals`,
        which is reliable precisely because every piece is closed.
        """
        if top_y <= base_y:
            return
        lo_in = [self.vert(Vector((p.x, base_y, p.z))) for p in inner]
        hi_in = [self.vert(Vector((p.x, top_y, p.z))) for p in inner]
        lo_out = [self.vert(Vector((p.x, base_y, p.z))) for p in outer]
        hi_out = [self.vert(Vector((p.x, top_y, p.z))) for p in outer]
        count = len(inner) - (0 if closed else 1)
        for i in range(count):
            j = (i + 1) % len(inner)
            self.quad(lo_in[i], hi_in[i], hi_in[j], lo_in[j])      # riser
            self.quad(lo_out[i], hi_out[i], hi_out[j], lo_out[j])  # back
            self.quad(hi_in[i], hi_out[i], hi_out[j], hi_in[j])    # tread
            self.quad(lo_in[i], lo_out[i], lo_out[j], lo_in[j])    # underside
        if not closed:
            for k in (0, len(inner) - 1):
                self.quad(lo_in[k], hi_in[k], hi_out[k], lo_out[k])

    def oriented_box(self, center: Vector, along: Vector, out: Vector,
                     size: Vector) -> None:
        """A box in its own frame: `size` is (width along, height, depth out).

        Anything standing on a curved run -- a seat, a barricade panel -- faces
        its own bearing, and an axis-aligned box would sit skewed to the run
        and read as a jumble exactly where the plan is most visible.
        """
        up = Vector((0.0, 1.0, 0.0))
        ea = along.normalized() * (size.x * 0.5)
        eu = up * (size.y * 0.5)
        eo = out.normalized() * (size.z * 0.5)
        corners = [
            center + ea * sa + eu * su + eo * so
            for sa, su, so in (
                (-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1),
            )
        ]
        v = [self.vert(c) for c in corners]
        for face in ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
                     (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            self.quad(*[v[i] for i in face])

    def box(self, center: Vector, size: Vector, bevel: float = 0.0,
            bevel_segments: int = 1) -> None:
        """An axis-aligned box, optionally bevelled.

        The bevel is why this is worth having in Blender at all. A ring post,
        a stage lip and a steel step all catch the house lights on their
        arrises, and a perfectly sharp 90-degree edge takes no highlight at
        all -- it is the single clearest tell of geometry that was typed as
        eight corners rather than built.
        """
        h = size * 0.5
        corners = [
            Vector((center.x + sx * h.x, center.y + sy * h.y, center.z + sz * h.z))
            for sx, sy, sz in (
                (-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1),
                (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1),
            )
        ]
        faces = ((0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
                 (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7))
        if bevel <= 0.0:
            v = [self.vert(c) for c in corners]
            for face in faces:
                self.quad(*[v[i] for i in face])
            return
        self._beveled(corners, faces, bevel, bevel_segments)

    def wedge(self, near: Vector, far: Vector, half_width: float,
              near_y: float, far_y: float, thickness: float,
              bevel: float = 0.0) -> None:
        """A sloped deck: a real ramp, not a staircase.

        `near`/`far` give the run in plan; `near_y`/`far_y` the deck height at
        each end. The solid carries its own underside and side fascias, so it
        reads from the broadcast angle the way a ramp does -- a continuous
        edge line falling toward the ring -- rather than as a flight of
        sub-pixel steps.
        """
        direction = (far - near)
        direction.y = 0.0
        if direction.length < 1e-9:
            return
        side = Vector((-direction.z, 0.0, direction.x)).normalized() * half_width
        top = [
            Vector((near.x, near_y, near.z)) - side,
            Vector((near.x, near_y, near.z)) + side,
            Vector((far.x, far_y, far.z)) + side,
            Vector((far.x, far_y, far.z)) - side,
        ]
        bottom = [Vector((p.x, p.y - thickness, p.z)) for p in top]
        corners = top + bottom
        faces = ((0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1),
                 (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0))
        if bevel <= 0.0:
            v = [self.vert(c) for c in corners]
            for face in faces:
                self.quad(*[v[i] for i in face])
            return
        self._beveled(corners, faces, bevel, 1)

    def tube(self, path: list[Vector], radius: float, sides: int = 8,
             caps: bool = True) -> None:
        """A circular section swept along a polyline.

        Ropes, truss chords, barricade rails and portal rings are all this.
        Frames are parallel-transported (see `_frames`) so the section does not
        spin along the run.
        """
        if len(path) < 2:
            return
        rings: list[list[bmesh.types.BMVert]] = []
        for point, (_, normal, binormal) in zip(path, _frames(path)):
            ring = []
            for s in range(sides):
                theta = 2.0 * math.pi * s / sides
                offset = normal * (math.cos(theta) * radius) \
                    + binormal * (math.sin(theta) * radius)
                ring.append(self.vert(point + offset))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for s in range(sides):
                t = (s + 1) % sides
                self.quad(rings[i][s], rings[i][t], rings[i + 1][t], rings[i + 1][s])
        if caps:
            self.bm.faces.new(list(reversed(rings[0])))
            self.bm.faces.new(rings[-1])

    def cylinder(self, base: Vector, axis: Vector, radius: float,
                 height: float, sides: int = 12) -> None:
        """An upright-ish cylinder: posts, bolts, truss uprights, rope nubs."""
        direction = axis.normalized()
        self.tube([base, base + direction * height], radius, sides, caps=True)

    def lattice(self, start: Vector, end: Vector, size: float,
                bay: float, chord_radius: float, diagonal_radius: float,
                sides: int = 6) -> None:
        """A four-chord truss: the real thing, not a box painted grey.

        Overhead truss is the one piece of an arena that is unmistakably a
        lattice from every angle, and it is also the piece a box-builder has
        no way to make. Four chords on the corners of a square section, with
        alternating diagonals in each bay and a vertical at every node.
        """
        run = end - start
        length = run.length
        if length < 1e-6 or bay <= 0.0:
            return
        direction = run.normalized()
        up = Vector((0.0, 1.0, 0.0))
        if abs(direction.dot(up)) > 0.95:
            up = Vector((1.0, 0.0, 0.0))
        side = direction.cross(up).normalized() * (size * 0.5)
        vert_axis = side.cross(direction).normalized() * (size * 0.5)
        offsets = [side + vert_axis, side - vert_axis,
                   -side - vert_axis, -side + vert_axis]
        for offset in offsets:
            self.tube([start + offset, end + offset], chord_radius, sides)
        bays = max(int(round(length / bay)), 1)
        for b in range(bays):
            t0 = start + run * (b / bays)
            t1 = start + run * ((b + 1) / bays)
            for k in range(4):
                a, c = offsets[k], offsets[(k + 1) % 4]
                # Alternating diagonal, so consecutive bays form the zigzag a
                # truss actually carries rather than a row of parallel struts.
                if (b + k) % 2 == 0:
                    self.tube([t0 + a, t1 + c], diagonal_radius, sides)
                else:
                    self.tube([t0 + c, t1 + a], diagonal_radius, sides)
                self.tube([t1 + a, t1 + c], diagonal_radius, sides)

    # --- internals -------------------------------------------------------

    def _beveled(self, corners: list[Vector], faces, width: float,
                 segments: int) -> None:
        """Build one solid in a scratch bmesh, bevel it, merge it in.

        Beveling the part's own bmesh would round every edge of every solid
        already in it, so each bevelled piece gets its own scratch mesh. The
        scratch is built in the GAME frame and converted on merge -- legal
        because `to_blender` is a rotation, so a bevel is the same width
        before and after it.
        """
        scratch = bmesh.new()
        verts = [scratch.verts.new((c.x, c.y, c.z)) for c in corners]
        for face in faces:
            try:
                scratch.faces.new([verts[i] for i in face])
            except ValueError:
                pass
        bmesh.ops.recalc_face_normals(scratch, faces=scratch.faces[:])
        bmesh.ops.bevel(
            scratch,
            geom=scratch.verts[:] + scratch.edges[:] + scratch.faces[:],
            offset=width, segments=segments, profile=0.5, affect="EDGES",
            clamp_overlap=True,
        )
        mapping: dict[int, bmesh.types.BMVert] = {}
        scratch.verts.index_update()
        for v in scratch.verts:
            mapping[v.index] = self.vert(Vector((v.co.x, v.co.y, v.co.z)))
        for face in scratch.faces:
            try:
                self.bm.faces.new([mapping[v.index] for v in face.verts])
            except ValueError:
                pass
        scratch.free()


# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)


def cube_project(mesh: bpy.types.Mesh, scale: float = 1.0) -> None:
    """World-metre planar UVs, projected per face off its dominant axis.

    The MaterialLibrary's surfaces are authored "at their world-metre texel
    density", so a UV unit here is a metre of the model. Projecting per face
    rather than unwrapping is right for this geometry: every piece of the
    venue is boxes, tubes and swept prisms, so each face is near-planar and a
    dominant-axis projection is what an unwrap would converge to anyway --
    without leaving a seam layout to drift between rebuilds.
    """
    uv_layer = mesh.uv_layers.active or mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        nx, ny, nz = (abs(c) for c in polygon.normal)
        for loop_index in polygon.loop_indices:
            co = mesh.vertices[mesh.loops[loop_index].vertex_index].co
            if nz >= nx and nz >= ny:
                uv = (co.x, co.y)
            elif nx >= ny:
                uv = (co.y, co.z)
            else:
                uv = (co.x, co.z)
            uv_layer.data[loop_index].uv = (uv[0] * scale, uv[1] * scale)


def finish(parts: dict[str, Part], colors: dict[str, tuple],
           emissive: frozenset[str] = frozenset(),
           smooth: frozenset[str] = frozenset(),
           projected: frozenset[str] = frozenset()) -> None:
    """Turn every Part into a scene object with a placeholder material.

    The colours are NOT the shipped look: the GDScript overrides every part
    with a `MaterialLibrary` material, because the hall's tints are solved
    against measured luminance targets in `gauntlet/refs/VISUAL_BAR.md` and a
    colour picked in Blender cannot know about them. What they are for is the
    `.glb` being openable on its own and reading as the venue.
    """
    for name, part in parts.items():
        if not part.bm.faces:
            raise SystemExit("venue.py: part '%s' is empty." % name)
        mesh = bpy.data.meshes.new(name)
        bmesh.ops.remove_doubles(part.bm, verts=part.bm.verts[:], dist=0.0005)
        bmesh.ops.recalc_face_normals(part.bm, faces=part.bm.faces[:])
        part.bm.to_mesh(mesh)
        part.bm.free()
        material = bpy.data.materials.new("M_" + name)
        material.use_nodes = True
        bsdf = material.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = colors[name]
        bsdf.inputs["Roughness"].default_value = 0.85
        if name in emissive:
            bsdf.inputs["Emission Color"].default_value = colors[name]
            bsdf.inputs["Emission Strength"].default_value = 1.0
        mesh.materials.append(material)
        # Smooth shading is opt-in per part: a swept rope and a portal ring
        # are round and must read that way, while a bowl's risers and a steel
        # step are faceted geometry and smoothing them only muddies the edge.
        if name in smooth:
            for polygon in mesh.polygons:
                polygon.use_smooth = True
        if name in projected:
            cube_project(mesh)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)


def triangle_count() -> int:
    total = 0
    for obj in bpy.data.objects:
        total += sum(max(len(p.vertices) - 2, 0) for p in obj.data.polygons)
    return total


def export_glb(out: pathlib.Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(out),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=False,
        export_cameras=False,
        export_lights=False,
        export_materials="EXPORT",
    )
