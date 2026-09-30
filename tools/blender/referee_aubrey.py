#!/usr/bin/env python3
"""Export the referee: Aubrey Edwards, dressed on the base rig's own skeleton.

    python3 tools/blender/referee_aubrey.py \
        [--src "~/.cache/aegis_assets/ubc/Universal Base Characters[Standard]"] \
        [--out game/assets/characters/aubrey_edwards.glb]

The body is Quaternius' Universal Base Characters (CC0, the Standard kit's
Superhero_Female_FullBody), which is rigged on the same 65-bone skeleton as
wrestler_base.glb -- identical bone names and hierarchy -- so every clip in the
project plays on her without a retarget (see core/match/aubrey_model.gd and
the import-wrestler skill, Phase 4, "same rig"). Her hair is the kit's
Hair_Long, weighted to the same skeleton; its own copy of the armature is
dropped and the mesh rebound to the body's.

What this script adds is her referee kit, to the AEW shirt reference
(gauntlet/refs/referee.md): black and white vertical stripes, a black collar
and black cuff bands on short sleeves, a gold-lettered patch on the left
chest; black trousers and black shoes. Each garment is cut from the body
mesh itself -- the faces under it, pushed out along their normals and
smoothed over the hollows a shirt would bridge -- so it carries the body's
own skin weights and deforms with her in every clip. The skin those garments
cover is deleted, bar one ring under each opening, so nothing pokes through.

Stripes: 5 cm black, 5 cm white, nine pairs round the torso, a black one on
the centre line (where the reference's placket is); the sleeves' run round
the arm, as the flat-lay reference draws them. The texture is 16 x 4 pixels
and the UVs repeat it.

Textures are capped at 1024 px (she is seen at ring distance, never in a face
close-up) and the fair skin tone replaces the kit's default. Her hair is
recoloured to a dark brown from the kit's ash texture by luminance.

Deterministic: every derived texture is written by PIL from fixed inputs and
the scene has no randomness, so the same kit writes the same file.
"""

from __future__ import annotations

import argparse
import math
import os
import pathlib
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # before bmesh: the bpy module is what provides it
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/characters/aubrey_edwards.glb"
SRC = pathlib.Path(os.path.expanduser("~/.cache/aegis_assets/ubc/Universal Base Characters[Standard]"))

BODY = "Base Characters/Godot - UE/Superhero_Female_FullBody.gltf"
HAIR = "Hairstyles/Rigged to Head Bone/glTF (Godot -Unreal)/Hair_Long.gltf"
SKIN_LIGHT = "Base Characters/Textures/T_Superhero_Female_Light_BaseColor.png"
TEX_CAP = 1024

# The body's rest pose, measured (T-pose, facing -Y, her left at +X, metres):
# the arms run level at z 1.418 from the shoulder at |x| 0.15; the pelvis is
# at z 0.93; the neck starts at z 1.485; the ankle is at z 0.07.
ARM_X = 0.20          # past this and above ARM_Z, a face is on an arm
ARM_Z = 1.30
SLEEVE_END = 0.335    # short sleeve: about half way to the elbow (0.392)
CUFF = 0.035          # the black band at the end of each sleeve
NECK_Z = 1.472        # the shirt's top edge
COLLAR = 0.03         # the black band at the top of it
SHIRT_HEM_Z = 0.93    # tucked in: below the trousers' waistband
WAIST_Z = 0.995       # the trousers' waistband
ANKLE_Z = 0.105       # trousers down to here; the shoes from here

# How far each garment stands off the skin, and how far the shirt's
# smoothing may pull it back in towards it.
SHIRT_OFF = 0.014
SHIRT_MIN = 0.008
TROUSER_OFF = 0.009
SHOE_OFF = 0.011

STRIPE_PERIOD = 0.10
STRIPE_PAIRS = 9      # round the torso; a whole number, so the back seam meets

# The chest patch, on her left chest (+X).
PATCH_CENTRE = (0.09, 1.33)     # x, z
PATCH_SIZE = (0.10, 0.07)       # w, h

BLACK = (0.018, 0.018, 0.018, 1.0)
HAIR_DARK = (26, 17, 12)
HAIR_LIGHT = (98, 66, 44)


def main() -> int:
	args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
	ap = argparse.ArgumentParser()
	ap.add_argument("--src", default=str(SRC))
	ap.add_argument("--out", default=str(OUT))
	opts = ap.parse_args(args)
	src = pathlib.Path(opts.src)
	if not (src / BODY).exists():
		print("referee_aubrey: the Universal Base Characters kit is not at %s" % src)
		return 1
	tmp = pathlib.Path(tempfile.mkdtemp(prefix="aubrey_"))

	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.ops.import_scene.gltf(filepath=str(src / BODY))
	arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
	arm.name = "Armature"
	body = bpy.data.objects["Superhero_Female"]
	body.name = "Aubrey_Body"
	for o in list(bpy.data.objects):
		if o.type == "MESH" and o.parent is None:
			bpy.data.objects.remove(o)   # the kit's stray Icosphere
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=str(src / HAIR))
	for o in set(bpy.data.objects) - before:
		if o.type == "MESH" and o.parent is not None:
			o.name = "Aubrey_Hair"
			mat = o.matrix_world.copy()
			o.parent = arm
			o.matrix_world = mat
			for md in o.modifiers:
				if md.type == "ARMATURE":
					md.object = arm
	for o in set(bpy.data.objects) - before:
		if o.name != "Aubrey_Hair":
			bpy.data.objects.remove(o)

	_retexture(src, tmp)
	faces = _classify(body)
	shirt = _garment(body, "Aubrey_Shirt", faces["shirt"], SHIRT_OFF, smooth=True)
	_stripe_uvs(shirt)
	_shirt_materials(shirt, tmp)
	_patch(shirt, arm, tmp)
	trousers = _garment(body, "Aubrey_Trousers", faces["trousers"], TROUSER_OFF)
	trousers.data.materials.clear()
	trousers.data.materials.append(_flat("M_Trousers", BLACK, 0.78))
	shoes = _garment(body, "Aubrey_Shoes", faces["shoes"], SHOE_OFF)
	shoes.data.materials.clear()
	shoes.data.materials.append(_flat("M_Shoes", (0.01, 0.01, 0.01, 1.0), 0.32))
	_cover_skin(body, faces["shirt"] | faces["trousers"] | faces["shoes"])

	bpy.ops.object.select_all(action="DESELECT")
	arm.select_set(True)
	for o in arm.children:
		o.select_set(True)
	out = pathlib.Path(opts.out)
	out.parent.mkdir(parents=True, exist_ok=True)
	bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True,
			export_yup=True, export_animations=False, export_skins=True,
			export_apply=False, export_image_format="AUTO")
	tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in arm.children if o.type == "MESH")
	print("referee_aubrey: %s, %d meshes, %d triangles -> %s" % (
			", ".join(sorted(o.name for o in arm.children)), len(arm.children), tris, out))
	return 0


# --- textures ---------------------------------------------------------------

def _retexture(src: pathlib.Path, tmp: pathlib.Path) -> None:
	"""Every image capped at TEX_CAP; the fair skin tone; dark brown hair."""
	for img in list(bpy.data.images):
		path = pathlib.Path(bpy.path.abspath(img.filepath))
		if not path.exists():
			continue
		name = path.name
		if name.startswith("T_Superhero_Female_Dark_BaseColor"):
			path = src / SKIN_LIGHT
			name = "T_Aubrey_Skin.png"
		im = Image.open(path)
		if name.startswith("T_Hair_2_BaseColor"):
			im = _brown(im)
			name = "T_Aubrey_Hair.png"
		# Detail maps at a quarter of that: at ring distance they are shading
		# texture, and at 2048 px they were 12 of the file's 16 MB.
		cap = TEX_CAP // 2 if "Normal" in name else TEX_CAP // 4 if "Roughness" in name else TEX_CAP
		if im.mode not in ("RGB", "L") and "Eye" not in name:
			im = im.convert("RGB")
		if max(im.size) > cap:
			im = im.resize((cap, cap), Image.LANCZOS)
		out = tmp / name
		im.save(out, optimize=False)
		# The importer PACKS the kit's images, so repointing the filepath
		# would re-export the packed original; swap in a fresh image instead.
		fresh = bpy.data.images.load(str(out))
		img.user_remap(fresh)
		bpy.data.images.remove(img)
		fresh.name = out.stem


def _brown(im: Image.Image) -> Image.Image:
	"""The kit's ash hair re-toned by its own luminance, so the strand detail
	stays and only the colour moves."""
	grey = im.convert("L")
	lo, hi = grey.getextrema()
	span = max(hi - lo, 1)
	lut = []
	for c in range(3):
		for v in range(256):
			t = min(max((v - lo) / span, 0.0), 1.0)
			lut.append(int(round(HAIR_DARK[c] + (HAIR_LIGHT[c] - HAIR_DARK[c]) * t)))
	return Image.merge("RGB", (grey, grey, grey)).point(lut)


def _stripe_png(tmp: pathlib.Path) -> pathlib.Path:
	im = Image.new("RGB", (16, 4), (26, 26, 26))
	ImageDraw.Draw(im).rectangle((8, 0, 15, 3), fill=(236, 236, 232))
	out = tmp / "T_Aubrey_Stripes.png"
	im.save(out, optimize=False)
	return out


def _patch_png(tmp: pathlib.Path) -> pathlib.Path:
	"""The chest patch: a black badge with a grey keyline, ALL ELITE over a
	large AEW with a gold E, WRESTLING under it."""
	w, h = 280, 200
	im = Image.new("RGB", (w, h), (20, 20, 20))
	d = ImageDraw.Draw(im)
	d.rectangle((6, 6, w - 7, h - 7), outline=(120, 120, 120), width=5)
	gold = (197, 171, 87)
	white = (240, 240, 236)
	bold = _font(84)
	small = _font(26)
	d.text((w / 2 - 4, 40), "ALL", font=small, fill=white, anchor="rm")
	d.text((w / 2 + 4, 40), "ELITE", font=small, fill=gold, anchor="lm")
	x = w / 2
	parts = [("A", white), ("E", gold), ("W", white)]
	widths = [d.textlength(t, font=bold) for t, _ in parts]
	x -= sum(widths) / 2
	for (t, col), tw in zip(parts, widths):
		d.text((x, 108), t, font=bold, fill=col, anchor="lm")
		x += tw
	d.text((w / 2, 166), "WRESTLING", font=small, fill=white, anchor="mm")
	out = tmp / "T_Aubrey_Patch.png"
	im.save(out, optimize=False)
	return out


def _font(size: int) -> ImageFont.FreeTypeFont:
	for path in ("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
			"/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"):
		if os.path.exists(path):
			return ImageFont.truetype(path, size)
	return ImageFont.load_default()


# --- materials --------------------------------------------------------------

def _flat(name: str, colour, roughness: float) -> bpy.types.Material:
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = colour
	bsdf.inputs["Roughness"].default_value = roughness
	m.use_backface_culling = False
	return m


def _textured(name: str, png: pathlib.Path, roughness: float) -> bpy.types.Material:
	m = _flat(name, (1, 1, 1, 1), roughness)
	tex = m.node_tree.nodes.new("ShaderNodeTexImage")
	tex.image = bpy.data.images.load(str(png))
	tex.image.name = png.stem
	m.node_tree.links.new(tex.outputs["Color"], m.node_tree.nodes["Principled BSDF"].inputs["Base Color"])
	return m


def _shirt_materials(shirt: bpy.types.Object, tmp: pathlib.Path) -> None:
	shirt.data.materials.clear()
	shirt.data.materials.append(_textured("M_RefStripes", _stripe_png(tmp), 0.72))
	shirt.data.materials.append(_flat("M_RefTrim", BLACK, 0.7))
	for p in shirt.data.polygons:
		c = p.center
		sleeve = abs(c.x) > ARM_X and c.z > ARM_Z
		trim = (sleeve and abs(c.x) > SLEEVE_END - CUFF) or (not sleeve and c.z > NECK_Z - COLLAR)
		p.material_index = 1 if trim else 0


# --- geometry ---------------------------------------------------------------

def _classify(body: bpy.types.Object) -> dict:
	"""Which of the body's faces each garment covers, by where they sit in
	the rest pose."""
	mw = body.matrix_world
	shirt, trousers, shoes = set(), set(), set()
	for p in body.data.polygons:
		c = mw @ p.center
		on_arm = abs(c.x) > ARM_X and c.z > ARM_Z
		if on_arm:
			if abs(c.x) < SLEEVE_END:
				shirt.add(p.index)
		elif SHIRT_HEM_Z < c.z < NECK_Z and abs(c.x) < 0.26:
			shirt.add(p.index)
		if not on_arm and c.z < WAIST_Z:
			(trousers if c.z > ANKLE_Z else shoes).add(p.index)
	return {"shirt": shirt, "trousers": trousers, "shoes": shoes}


def _garment(body, name: str, keep: set, offset: float, smooth: bool = False):
	"""A copy of the body cut down to `keep` and stood off the skin: it keeps
	the body's vertex groups and armature modifier, so it is skinned as she
	is. `smooth` bridges the hollows a garment does not follow (between the
	breasts, the small of the back), never closer to the skin than
	SHIRT_MIN."""
	ob = body.copy()
	ob.data = body.data.copy()
	ob.name = name
	ob.data.name = name
	bpy.context.collection.objects.link(ob)
	bm = bmesh.new()
	bm.from_mesh(ob.data)
	bm.faces.ensure_lookup_table()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in keep], context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.normal_update()
	skin = {v: (v.co.copy(), v.normal.copy()) for v in bm.verts}
	for v in bm.verts:
		v.co += v.normal * offset
	if smooth:
		inner = [v for v in bm.verts if not v.is_boundary]
		for _ in range(6):
			bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5,
					use_axis_x=True, use_axis_y=True, use_axis_z=True)
		for v in bm.verts:
			co, n = skin[v]
			out = (v.co - co).dot(n)
			if out < SHIRT_MIN:
				v.co += n * (SHIRT_MIN - out)
	bm.to_mesh(ob.data)
	bm.free()
	while len(ob.data.uv_layers) > 1:
		ob.data.uv_layers.remove(ob.data.uv_layers[-1])
	for p in ob.data.polygons:
		p.use_smooth = True
	return ob


def _stripe_uvs(shirt: bpy.types.Object) -> None:
	"""u in stripe periods: round the torso by angle (a whole number of pairs,
	so the seam at the back meets), round each arm by distance out along it."""
	me = shirt.data
	uv = me.uv_layers[0].data
	for p in me.polygons:
		c = p.center
		sleeve = abs(c.x) > ARM_X and c.z > ARM_Z
		us = []
		for li in p.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			if sleeve:
				u = (abs(co.x) - ARM_X) / STRIPE_PERIOD
			else:
				u = math.atan2(co.x, -co.y) / (2 * math.pi) * STRIPE_PAIRS
			us.append(u + 0.25)   # a black stripe centred on the front
		if not sleeve and max(us) - min(us) > STRIPE_PAIRS / 2:
			us = [u + STRIPE_PAIRS if u < 0.25 else u for u in us]
		for li, u in zip(p.loop_indices, us):
			uv[li].uv = (u, me.vertices[me.loops[li].vertex_index].co.z / STRIPE_PERIOD)


def _patch(shirt: bpy.types.Object, arm: bpy.types.Object, tmp: pathlib.Path) -> None:
	"""The chest patch: a small grid laid on the shirt's surface from the
	front, 2 mm proud of it, skinned like the shirt vertex nearest each of its
	points."""
	bm = bmesh.new()
	bm.from_mesh(shirt.data)
	tree = BVHTree.FromBMesh(bm)
	cx, cz = PATCH_CENTRE
	w, h = PATCH_SIZE
	nx, nz = 6, 4
	me = bpy.data.meshes.new("Aubrey_Patch")
	verts, uvs = [], []
	for j in range(nz + 1):
		for i in range(nx + 1):
			x = cx - w / 2 + w * i / nx
			z = cz - h / 2 + h * j / nz
			hit, normal = None, None
			for dx, dz in ((0, 0), (0.001, 0.001), (-0.001, -0.001)):
				hit, normal, _, _ = tree.ray_cast(Vector((x + dx, -1.0, z + dz)), Vector((0, 1, 0)))
				if hit is not None:
					break
			if hit is None:
				print("referee_aubrey: patch ray missed the shirt at x %.3f z %.3f" % (x, z))
				return
			verts.append(hit + normal * 0.002)
			uvs.append((i / nx, j / nz))
	faces = [(j * (nx + 1) + i, j * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i + 1, (j + 1) * (nx + 1) + i)
			for j in range(nz) for i in range(nx)]
	me.from_pydata([tuple(v) for v in verts], [], faces)
	layer = me.uv_layers.new(name="UVMap")
	for p in me.polygons:
		p.use_smooth = True
		for li in p.loop_indices:
			layer.data[li].uv = uvs[me.loops[li].vertex_index]
	me.materials.append(_textured("M_RefPatch", _patch_png(tmp), 0.6))
	ob = bpy.data.objects.new("Aubrey_Patch", me)
	bpy.context.collection.objects.link(ob)
	ob.parent = arm
	# Weights from the nearest shirt vertex.
	kd_src = shirt.data.vertices
	names = {g.index: g.name for g in shirt.vertex_groups}
	for g in shirt.vertex_groups:
		ob.vertex_groups.new(name=g.name)
	for vi, co in enumerate(verts):
		near = min(kd_src, key=lambda v: (v.co - co).length_squared)
		for ge in near.groups:
			ob.vertex_groups[names[ge.group]].add([vi], ge.weight, "REPLACE")
	md = ob.modifiers.new("Armature", "ARMATURE")
	md.object = arm
	bm.free()


def _cover_skin(body: bpy.types.Object, covered: set) -> None:
	"""Delete the skin under the clothes, keeping the ring of faces at each
	opening (cuffs, collar, ankles) so no gap shows under an edge."""
	bm = bmesh.new()
	bm.from_mesh(body.data)
	bm.faces.ensure_lookup_table()
	edge_verts = set()
	for f in bm.faces:
		if f.index not in covered:
			edge_verts.update(f.verts)
	gone = [f for f in bm.faces if f.index in covered and not any(v in edge_verts for v in f.verts)]
	bmesh.ops.delete(bm, geom=gone, context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bm.to_mesh(body.data)
	bm.free()


if __name__ == "__main__":
	import bpy_exit
	bpy_exit.finish(main())
