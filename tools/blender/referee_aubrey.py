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

Stripes: 5 cm black, 5 cm white, vertical, a black one on the centre line
(where the reference's placket is); the sleeves' run round the arm, as the
flat-lay reference draws them. The texture is 16 x 4 pixels
and the UVs repeat it.

Textures are capped at 1024 px (she is seen at ring distance, never in a face
close-up) and the fair skin tone replaces the kit's default. Her hair is
recoloured to a dark brown from the kit's ash texture by luminance.

Fit and cloth: the garments are cut loose and draped (see CHEST_LO and
LEG_AXIS below), and every fabric carries a woven texture -- a tileable twill
height field, as shaded albedo and as a normal map -- so it reads as cloth
under the arena lights rather than as paint on skin.

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
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT = ROOT / "game/assets/characters/aubrey_edwards.glb"
SRC = pathlib.Path(os.path.expanduser("~/.cache/aegis_assets/ubc/Universal Base Characters[Standard]"))

BODY = "Base Characters/Godot - UE/Superhero_Female_FullBody.gltf"
SKIN_LIGHT = "Base Characters/Textures/T_Superhero_Female_Light_BaseColor.png"
TEX_CAP = 1024

# The body's rest pose, measured (T-pose, facing -Y, her left at +X, metres):
# the arms run level at z 1.418 from the shoulder at |x| 0.15; the pelvis is
# at z 0.93; the neck starts at z 1.485; the ankle is at z 0.07.
ARM_X = 0.20          # past this and above ARM_Z, a face is on an arm
ARM_Z = 1.30
SLEEVE_END = 0.335    # short sleeve: about half way to the elbow (0.392)
NECK_Z = 1.472        # the shirt's top edge
TRIM_RINGS = 2        # the collar and cuffs: this many rings of faces deep
SHIRT_HEM_Z = 0.975   # tucked in: inside the waistband (WAISTBAND)
WAIST_Z = 1.02        # the trousers' waistband (the belt's top edge)
ANKLE_Z = 0.105       # trousers down to here; the shoes from here

# How far each garment stands off the skin, and how far the shirt's
# smoothing may pull it back in towards it. The shirt's minimum clears the
# trousers everywhere they overlap (the tuck, 0.93-0.995), so the two never
# fight for the same surface.
SHIRT_OFF = 0.022
SHIRT_MIN = 0.019
TROUSER_OFF = 0.012
SHOE_OFF = 0.011

# The drape. A shirt is not a second skin: it hangs off the widest part of
# the chest and shoulder blades and falls from there, nearly straight, to
# where it is tucked in, bridging the waist and the small of the back instead
# of following them in. So below the chest band every point is pushed out to
# the chest's own girth at that bearing (less a slight taper), and eased back
# to the body over the tuck; the fabric blouses a little over the waistband,
# as a tucked shirt does, and a few soft vertical folds run down from the
# bust. The sleeves are cut loose and flare towards the cuff.
CHEST_LO, CHEST_HI = 1.17, 1.34
DRAPE_TAPER = 0.10            # m of radius lost per m below the chest
TUCK_LO, TUCK_HI = 1.02, 1.10
FOLDS, FOLD_DEPTH = 11, 0.0035
SLEEVE_EASE = (0.008, 0.024)  # extra stand-off at the shoulder, at the cuff
# Straight-leg trousers: below the knee the leg falls at the knee's own
# girth rather than hugging the calf, easing half back in at the hem. The leg
# axis is the rest pose's thigh and calf bones.
LEG_AXIS = ((0.944, 0.111, 0.052), (0.535, 0.111, 0.032), (0.071, 0.111, 0.077))
KNEE_LO, KNEE_HI = 0.49, 0.58
# The waistband stands proud of the tucked-in shirt tail, so the tail is
# inside the trousers rather than poking out through them.
WAISTBAND = (0.95, 0.032)     # from this height up, this far off the skin
BELT = 0.035                  # the black belt: this deep below the waistband's top
TAIL_MAX = 0.024              # the shirt tail's stand-off below the waistband
FABRIC_TILE = 0.10            # the weave textures repeat every 10 cm

STRIPE_PERIOD = 0.10

# The chest patch, on her left chest (+X).
PATCH_CENTRE = (0.09, 1.33)     # x, z
PATCH_SIZE = (0.10, 0.07)       # w, h

BLACK = (0.018, 0.018, 0.018, 1.0)
SKIN_SATURATION = 0.74
SKIN_VALUE = 1.12
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
	_retexture(src, tmp)
	_hair(body, arm, tmp)
	faces = _classify(body)
	shirt = _garment(body, "Aubrey_Shirt", faces["shirt"], SHIRT_OFF, smooth=True, drape=_drape_shirt)
	_stripe_uvs(shirt)
	_shirt_materials(shirt, tmp)
	_patch(shirt, arm, tmp)
	trousers = _garment(body, "Aubrey_Trousers", faces["trousers"], TROUSER_OFF, drape=_drape_trousers)
	_fabric_uvs(trousers)
	trousers.data.materials.clear()
	trousers.data.materials.append(_textured("M_Trousers", _cloth_png(tmp, "T_Aubrey_Trousers", (22, 22, 24), (22, 22, 24), 0.12),
			0.85, _weave_normal_png(tmp, "T_Aubrey_Twill_N", 1.2)))
	trousers.data.materials.append(_flat("M_Belt", (0.008, 0.008, 0.008, 1.0), 0.3))
	for p in trousers.data.polygons:
		if min(trousers.data.vertices[i].co.z for i in p.vertices) > WAIST_Z - BELT:
			p.material_index = 1
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
		if name == "T_Aubrey_Skin.png":
			im = _paler(im)
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


def _paler(im: Image.Image) -> Image.Image:
	"""Her fair skin: the kit's lightest tone is still a tan against her
	(measured median (171, 120, 83)). Less saturation, a little lighter, so
	it lands near (200, 158, 128) -- fair, still warm, not grey."""
	hsv = np.asarray(im.convert("RGB").convert("HSV"), dtype=np.float32)
	hsv[..., 1] *= SKIN_SATURATION
	hsv[..., 2] = np.minimum(255.0, hsv[..., 2] * SKIN_VALUE)
	return Image.fromarray(hsv.round().astype(np.uint8), "HSV").convert("RGB")


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


def _weave(size: int = 128) -> "np.ndarray":
	"""A tileable twill height field in 0..1: diagonal ribs (a 2/1 twill's
	wale, exaggerated to about 3 mm so it survives ring distance), crossed by
	a fainter plain-weave grid, with a little seeded slub noise."""
	i, j = np.meshgrid(np.arange(size), np.arange(size), indexing="xy")
	ribs = 0.5 + 0.5 * np.sin(2 * np.pi * (i + j) * 32 / size)
	grid = 0.5 + 0.25 * (np.sin(2 * np.pi * i * 64 / size) + np.sin(2 * np.pi * j * 64 / size))
	rng = np.random.default_rng(20240613)
	slub = rng.random((size, size))
	for _ in range(3):   # a wrap-around blur, so the noise tiles too
		slub = (slub + np.roll(slub, 1, 0) + np.roll(slub, -1, 0) + np.roll(slub, 1, 1) + np.roll(slub, -1, 1)) / 5
	slub = (slub - slub.min()) / max(slub.max() - slub.min(), 1e-6)
	return 0.62 * ribs + 0.18 * grid + 0.20 * slub


def _cloth_png(tmp: pathlib.Path, name: str, left, right, depth: float) -> pathlib.Path:
	"""One tile of cloth: the left half `left`, the right half `right` (the
	stripes: black and white; the trousers: one colour twice), shaded by the
	weave so the fabric reads as woven rather than printed."""
	size = 128
	h = _weave(size)
	base = np.zeros((size, size, 3))
	base[:, : size // 2] = left
	base[:, size // 2:] = right
	shade = (1.0 - depth) + depth * h
	out = tmp / (name + ".png")
	Image.fromarray(np.clip(base * shade[..., None], 0, 255).astype(np.uint8), "RGB").save(out, optimize=False)
	return out


def _stripe_png(tmp: pathlib.Path) -> pathlib.Path:
	return _cloth_png(tmp, "T_Aubrey_Stripes", (24, 24, 25), (238, 237, 232), 0.10)


def _weave_normal_png(tmp: pathlib.Path, name: str, strength: float) -> pathlib.Path:
	"""The weave's normal map (OpenGL convention, as glTF wants), from the
	same height field by wrap-around central differences."""
	h = _weave(128)
	dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
	dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
	n = np.stack([-dx, dy, np.ones_like(h)], -1)
	n /= np.linalg.norm(n, axis=-1, keepdims=True)
	out = tmp / (name + ".png")
	Image.fromarray(((n * 0.5 + 0.5) * 255).round().astype(np.uint8), "RGB").save(out, optimize=False)
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


def _textured(name: str, png: pathlib.Path, roughness: float, normal: pathlib.Path | None = None) -> bpy.types.Material:
	m = _flat(name, (1, 1, 1, 1), roughness)
	nodes, links = m.node_tree.nodes, m.node_tree.links
	bsdf = nodes["Principled BSDF"]
	tex = nodes.new("ShaderNodeTexImage")
	tex.image = bpy.data.images.load(str(png))
	tex.image.name = png.stem
	links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	if normal is not None:
		ntex = nodes.new("ShaderNodeTexImage")
		ntex.image = bpy.data.images.load(str(normal))
		ntex.image.name = normal.stem
		ntex.image.colorspace_settings.name = "Non-Color"
		nmap = nodes.new("ShaderNodeNormalMap")
		links.new(ntex.outputs["Color"], nmap.inputs["Color"])
		links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
	return m


def _shirt_materials(shirt: bpy.types.Object, tmp: pathlib.Path) -> None:
	"""The stripes, and the black trim: the collar and the cuffs are the two
	rings of faces at each opening, so the band follows the edge exactly
	rather than stepping across the stripes where the neckline dips."""
	shirt.data.materials.clear()
	weave = _weave_normal_png(tmp, "T_Aubrey_Weave_N", 1.0)
	shirt.data.materials.append(_textured("M_RefStripes", _stripe_png(tmp), 0.8, weave))
	# The trim is ribbed knit: the same weave, black, and a touch shinier.
	shirt.data.materials.append(_textured("M_RefTrim",
			_cloth_png(tmp, "T_Aubrey_Trim", (20, 20, 21), (20, 20, 21), 0.18), 0.7, weave))
	bm = bmesh.new()
	bm.from_mesh(shirt.data)
	edge = {v for v in bm.verts if v.is_boundary and v.co.z > ARM_Z - 0.1}
	trim = set()
	for _ring in range(TRIM_RINGS):
		ring = {f for v in edge for f in v.link_faces}
		trim |= ring
		edge = {v for f in ring for v in f.verts}
	for f in bm.faces:
		f.material_index = 1 if f in trim else 0
	bm.to_mesh(shirt.data)
	bm.free()


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


def _garment(body, name: str, keep: set, offset: float, smooth: bool = False, drape=None):
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
	if drape:
		drape(bm)
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
			elif co.z < WAIST_Z and out > TAIL_MAX:
				# The tail stays inside the waistband.
				v.co -= n * (out - TAIL_MAX)
		_folds(bm)
	bm.to_mesh(ob.data)
	bm.free()
	while len(ob.data.uv_layers) > 1:
		ob.data.uv_layers.remove(ob.data.uv_layers[-1])
	for p in ob.data.polygons:
		p.use_smooth = True
	return ob


def _smoothstep(t: float) -> float:
	t = min(max(t, 0.0), 1.0)
	return t * t * (3.0 - 2.0 * t)


def _bins(values, count: int) -> list:
	"""A circular max-filter over angle bins, so one sparse bin does not
	leave a dent in the drape."""
	return [max(values[(i - 1) % count], values[i], values[(i + 1) % count]) for i in range(count)]


def _drape_shirt(bm) -> None:
	"""See CHEST_LO. Radii are about the torso's own front-back centre."""
	sleeve = lambda v: abs(v.co.x) > ARM_X and v.co.z > ARM_Z
	for v in bm.verts:
		if sleeve(v):
			t = _smoothstep((abs(v.co.x) - ARM_X) / (SLEEVE_END - ARM_X))
			v.co += v.normal * (SLEEVE_EASE[0] + (SLEEVE_EASE[1] - SLEEVE_EASE[0]) * t)
	torso = [v for v in bm.verts if not sleeve(v)]
	cy = sum(v.co.y for v in torso) / len(torso)
	count = 48
	top = [0.0] * count
	def polar(v):
		a = math.atan2(v.co.x, v.co.y - cy)
		return a, math.hypot(v.co.x, v.co.y - cy), int((a + math.pi) / (2 * math.pi) * count) % count
	for v in torso:
		if CHEST_LO < v.co.z < CHEST_HI:
			_, r, b = polar(v)
			top[b] = max(top[b], r)
	top = _bins(top, count)
	for v in torso:
		z = v.co.z
		if z >= CHEST_LO:
			continue
		a, r, b = polar(v)
		target = top[b] - DRAPE_TAPER * (CHEST_LO - z)
		w = _smoothstep((z - TUCK_LO) / (TUCK_HI - TUCK_LO))
		if target > r and r > 1e-4:
			k = (r + (target - r) * w) / r
			v.co.x *= k
			v.co.y = cy + (v.co.y - cy) * k


def _folds(bm) -> None:
	"""Soft vertical folds from under the bust to the tuck: a small radial
	ripple, after the smoothing so it is not smoothed away."""
	torso = [v for v in bm.verts if not (abs(v.co.x) > ARM_X and v.co.z > ARM_Z)]
	cy = sum(v.co.y for v in torso) / len(torso)
	for v in torso:
		z = v.co.z
		amount = _smoothstep((CHEST_HI - 0.06 - z) / 0.08) * _smoothstep((z - TUCK_LO) / 0.05)
		if amount <= 0.0:
			continue
		a = math.atan2(v.co.x, v.co.y - cy)
		out = Vector((v.co.x, v.co.y - cy, 0.0))
		if out.length > 1e-4:
			v.co += out.normalized() * FOLD_DEPTH * amount * math.sin(a * FOLDS + z * 9.0)


def _leg_axis(z: float):
	(z0, x0, y0), (z1, x1, y1), (z2, x2, y2) = LEG_AXIS
	if z >= z1:
		t = (z0 - z) / (z0 - z1)
		return x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
	t = min((z1 - z) / (z1 - z2), 1.0)
	return x1 + (x2 - x1) * t, y1 + (y2 - y1) * t


def _drape_trousers(bm) -> None:
	"""See LEG_AXIS and WAISTBAND. The waistband's top edge is levelled to
	one height (cut along the body's faces it was ragged), and the belt is
	the band under it."""
	for v in bm.verts:
		if v.is_boundary and v.co.z > 0.9:
			v.co.z = WAIST_Z + 0.008
	for v in bm.verts:
		k = _smoothstep((v.co.z - WAISTBAND[0]) / 0.02)
		if k > 0.0:
			v.co += v.normal * (WAISTBAND[1] - TROUSER_OFF) * k
	count = 32
	for side in (-1.0, 1.0):
		leg = [v for v in bm.verts if v.co.x * side > 0.02 and v.co.z < KNEE_HI + 0.05]
		def polar(v):
			ax, ay = _leg_axis(v.co.z)
			dx, dy = v.co.x - ax * side, v.co.y - ay
			a = math.atan2(dx, dy)
			return dx, dy, math.hypot(dx, dy), int((a + math.pi) / (2 * math.pi) * count) % count
		knee = [0.0] * count
		for v in leg:
			if KNEE_LO < v.co.z < KNEE_HI:
				_, _, r, b = polar(v)
				knee[b] = max(knee[b], r)
		knee = _bins(knee, count)
		for v in leg:
			z = v.co.z
			if z >= KNEE_LO + 0.03:
				continue
			dx, dy, r, b = polar(v)
			# Full straight fall to mid-shin, easing half back in at the hem.
			w = 0.5 + 0.5 * _smoothstep((z - ANKLE_Z) / 0.18)
			w *= _smoothstep((KNEE_LO + 0.03 - z) / 0.06)
			if knee[b] > r > 1e-4:
				k = (r + (knee[b] - r) * w) / r
				ax, ay = _leg_axis(z)
				v.co.x = ax * side + dx * k
				v.co.y = ay + dy * k


def _fabric_uvs(ob) -> None:
	"""Tile coordinates for the weave: projected front and back like the
	shirt's stripes, one tile every FABRIC_TILE."""
	me = ob.data
	uv = me.uv_layers[0].data
	for p in me.polygons:
		back = p.normal.y > 0.0
		for li in p.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			uv[li].uv = ((-co.x if back else co.x) / FABRIC_TILE, co.z / FABRIC_TILE)


def _stripe_uvs(shirt: bpy.types.Object) -> None:
	"""u in stripe periods. Round the torso it is ARC LENGTH from the front
	centre-line, measured along the cross-section at each height, so a
	stripe is the same 5 cm wherever it is -- front, flank or back -- and
	hangs vertical down a straight drape. (By angle, the stripes fanned out
	from the neck like rays; projected flat, they smeared down the sides.)
	The seam is at the centre back. The sleeves run round the arm, by
	distance out along it."""
	me = shirt.data
	uv = me.uv_layers[0].data
	sleeve = lambda co: abs(co.x) > ARM_X and co.z > ARM_Z
	torso = [v.co for v in me.vertices if not sleeve(v.co)]
	cy = sum(c.y for c in torso) / len(torso)
	# The girth profile: mean radius per (height slab, bearing bin), smoothed
	# over both, and integrated round from the front centre-line. Measuring
	# vertex to vertex instead zigzags between rows and stripes the back like
	# a zebra.
	slab, count = 0.02, 72
	z0 = min(c.z for c in torso)
	rows = int((max(c.z for c in torso) - z0) / slab) + 1
	total = [[0.0] * count for _ in range(rows)]
	seen = [[0] * count for _ in range(rows)]
	bearing = lambda co: math.atan2(co.x, -(co.y - cy))
	for c in torso:
		k = min(int((c.z - z0) / slab), rows - 1)
		b = int((bearing(c) + math.pi) / (2 * math.pi) * count) % count
		total[k][b] += math.hypot(c.x, c.y - cy)
		seen[k][b] += 1
	radius = []
	for k in range(rows):
		known = [(b, total[k][b] / seen[k][b]) for b in range(count) if seen[k][b]]
		row = []
		for b in range(count):
			if seen[k][b]:
				row.append(total[k][b] / seen[k][b])
			else:   # an empty bin: the nearest filled one round the ring
				row.append(min(known, key=lambda e: min(abs(e[0] - b), count - abs(e[0] - b)))[1]
						if known else 0.15)
		radius.append(row)
	for _ in range(4):
		radius = [[(radius[k][(b - 1) % count] + 2 * radius[k][b] + radius[k][(b + 1) % count]) / 4
				for b in range(count)] for k in range(rows)]
		radius = [[(radius[max(k - 1, 0)][b] + 2 * radius[k][b] + radius[min(k + 1, rows - 1)][b]) / 4
				for b in range(count)] for k in range(rows)]
	step = 2 * math.pi / count
	arcs = []
	for k in range(rows):
		# cum[b]: arc from bearing -pi to bin b's lower edge; re-zeroed on the
		# front (bearing 0, the lower edge of bin count/2).
		cum = [0.0]
		for b in range(count):
			cum.append(cum[-1] + radius[k][b] * step)
		# Front and back are separate panels, joined at side seams (as a real
		# shirt is cut): each is measured from its OWN centre-line, so both
		# centre stripes hang true and any mismatch lands in the seams.
		front, back = cum[count // 2], cum[count]
		arcs.append([c - front if abs(i - count // 2) <= count // 4 else
				(c - back if i > count // 2 else c) for i, c in enumerate(cum)])
	def arc(co) -> float:
		f = (bearing(co) + math.pi) / step
		b = min(int(f), count - 1)
		t = f - b
		zf = min(max((co.z - z0) / slab - 0.5, 0.0), rows - 1.0)
		k = min(int(zf), rows - 2) if rows > 1 else 0
		s_ = zf - k
		at = lambda kk: arcs[kk][b] + (arcs[kk][b + 1] - arcs[kk][b]) * t
		return at(k) if rows == 1 else at(k) * (1 - s_) + at(k + 1) * s_
	for p in me.polygons:
		c = p.center
		us = []
		for li in p.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			if sleeve(c):
				us.append((abs(co.x) - ARM_X) / STRIPE_PERIOD)
			else:
				us.append(arc(co) / STRIPE_PERIOD + 0.25)   # black on the centre-line
		if not sleeve(c) and max(us) - min(us) > 1.5:
			# A face across a seam: all of it on the side of its first corner,
			# measured on that panel.
			us = [us[0]] * len(us)
		for li, u in zip(p.loop_indices, us):
			uv[li].uv = (u, me.vertices[me.loops[li].vertex_index].co.z / STRIPE_PERIOD)


def _interp(xs, ys, x) -> float:
	"""ys at x, linearly, clamped to the ends."""
	if x <= xs[0]:
		return ys[0]
	if x >= xs[-1]:
		return ys[-1]
	lo, hi = 0, len(xs) - 1
	while hi - lo > 1:
		mid = (lo + hi) // 2
		if xs[mid] <= x:
			lo = mid
		else:
			hi = mid
	span = xs[hi] - xs[lo]
	t = 0.0 if span <= 0 else (x - xs[lo]) / span
	return ys[lo] + (ys[hi] - ys[lo]) * t


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


# --- hair: tied back, a curled ponytail ----------------------------------------
#
# How she wears it to referee: pulled back off the face and tied in a
# ponytail, which she curls (her own description of her match-night routine;
# the AEW toy figure of her is sculpted the same way). The kit has no such
# hairstyle, so it is built here:
#
#   * the CAP is her own scalp -- the head's faces above her hairline, stood
#     off a few millimetres -- because hair pulled back tight follows the
#     skull exactly; it carries the head's weights, so it cannot slip;
#   * the PONYTAIL is a tube swept from the tie at the back of her crown down
#     to between her shoulder blades, full just under the tie and tapering to
#     the tip, its cross-section lobed and twisted along its length so it
#     reads as curls rather than a rope;
#   * a black HAIR TIE rings the root;
#   * the ponytail rides five new bones, ponytail_1..5, chained off Head, so
#     the game can swing it on springs (AubreyModel, SpringBoneSimulator3D).
#
# Head measurements (rest pose, metres, facing -Y): brows top 1.687, crown
# 1.767, skull centre about (0, 0.01, 1.67), back of the skull y 0.112.
## The hairline, by bearing round the skull from the front: the forehead's
## (5 cm above the brows), receding a little at the temples, over the ears,
## and the nape. Hair pulled back shows the whole forehead.
HAIRLINE = ((0.0, 1.738), (0.75, 1.728), (1.45, 1.672), (math.pi, 1.548))
CAP_OFF = 0.0035
CAP_CROWN = 0.004                  # a little more over the crown
SKULL = Vector((0.0, 0.01, 1.67))
TAIL_PATH = ((0.0, 0.122, 1.712), (0.0, 0.158, 1.700), (0.0, 0.180, 1.645),
		(0.0, 0.172, 1.560), (0.0, 0.158, 1.480), (0.0, 0.150, 1.405))
TAIL_RADIUS = ((0.0, 0.015), (0.12, 0.028), (0.45, 0.025), (0.80, 0.015), (1.0, 0.004))
TAIL_RINGS, TAIL_SIDES = 28, 16
CURL_LOBES, CURL_DEPTH, CURL_TWIST = 7, 0.20, 2.5
TAIL_BONES = 5
HAIR_COLOUR = ((34, 23, 16), (92, 62, 42))   # root, highlight


def _hairline(co) -> float:
	"""Hairline height at this bearing round the skull (HAIRLINE); smooth
	between the keys."""
	a = abs(math.atan2(co.x - SKULL.x, -(co.y - SKULL.y)))
	for (a0, z0), (a1, z1) in zip(HAIRLINE, HAIRLINE[1:]):
		if a <= a1:
			return z0 + (z1 - z0) * _smoothstep((a - a0) / (a1 - a0))
	return HAIRLINE[-1][1]


def _hair(body, arm, tmp: pathlib.Path) -> None:
	names = {g.index: g.name for g in body.vertex_groups}
	head_faces = set()
	for p in body.data.polygons:
		vs = [body.data.vertices[i] for i in p.vertices]
		# Every head face that reaches above the hairline; the exact edge is
		# drawn by the texture's alpha (CAP_V), not by where the faces stop,
		# which cut it in steps.
		if all(v.groups and names[max(v.groups, key=lambda g: g.weight).group] == "Head" for v in vs) \
				and max(v.co.z - _hairline(v.co) for v in vs) > -0.004:
			head_faces.add(p.index)
	cap = _garment(body, "Aubrey_HairCap", head_faces, CAP_OFF)
	bm = bmesh.new()
	bm.from_mesh(cap.data)
	for v in bm.verts:
		v.co += v.normal * CAP_CROWN * _smoothstep((v.co.z - 1.70) / 0.06)
	bm.to_mesh(cap.data)
	bm.free()
	# UVs: u round the skull, v up from the hairline, so the strand texture
	# runs from the hairline back over the crown.
	me = cap.data
	uv = me.uv_layers[0].data
	for p in me.polygons:
		us = []
		for li in p.loop_indices:
			co = me.vertices[me.loops[li].vertex_index].co
			us.append((math.atan2(co.x - SKULL.x, -(co.y - SKULL.y)) / (2 * math.pi) * 6.0,
					_cap_v(co.z - _hairline(co))))
		if max(u for u, _ in us) - min(u for u, _ in us) > 3.0:
			us = [(u + 6.0 if u < 0 else u, v) for u, v in us]
		for li, (u, v) in zip(p.loop_indices, us):
			uv[li].uv = (u, v)
	hair_png = _strands_png(tmp)
	mat = _textured("M_AubreyHair", hair_png, 0.45)
	mat.blend_method = "CLIP"
	mat.alpha_threshold = 0.35
	nodes = mat.node_tree.nodes
	tex = next(n for n in nodes if n.type == "TEX_IMAGE")
	mat.node_tree.links.new(tex.outputs["Alpha"], nodes["Principled BSDF"].inputs["Alpha"])
	cap.data.materials.clear()
	cap.data.materials.append(mat)
	_ponytail(arm, mat)


## v on the cap: the hairline at CAP_V[0], the crown and back up to CAP_V[1],
## all inside one tile so nothing wraps (a wrapped tile drew the transparent
## hairline row as a stripe across her crown). Below the line, v runs down
## to 0, where the texture is clear.
CAP_V = (0.12, 0.98)
CAP_SPAN = 0.24   # metres of scalp above the hairline the tile covers


def _cap_v(above: float) -> float:
	if above < 0.0:
		return max(CAP_V[0] + above * (CAP_V[0] / 0.02), 0.0)
	return CAP_V[0] + (CAP_V[1] - CAP_V[0]) * min(above / CAP_SPAN, 1.0)


def _strands_png(tmp: pathlib.Path) -> pathlib.Path:
	"""Strands along v, dark at the root; alpha ragged at the hairline (v 0)
	so the edge reads as hair growing, not a painted line."""
	w, h = 128, 256
	rng = np.random.default_rng(19870309)
	cols = rng.random(w)
	for _ in range(2):
		cols = (cols + np.roll(cols, 1) + np.roll(cols, -1)) / 3
	cols = (cols - cols.min()) / max(cols.max() - cols.min(), 1e-6)
	v = np.linspace(0.0, 1.0, h)[:, None]
	shade = 0.55 + 0.45 * cols[None, :] * (0.6 + 0.4 * np.clip(v * 3, 0, 1))
	lo, hi = np.array(HAIR_COLOUR[0], float), np.array(HAIR_COLOUR[1], float)
	rgb = lo + (hi - lo) * shade[..., None]
	# Clear below the hairline (CAP_V[0]), a ragged few millimetres of edge,
	# solid above.
	edge = CAP_V[0] - 0.01 + rng.random(w) * 0.03
	alpha = np.clip((v - edge[None, :]) / 0.03, 0.0, 1.0)
	img = np.concatenate([rgb, alpha[..., None] * 255.0], -1)
	out = tmp / "T_Aubrey_Strands.png"
	# v runs up the image (row 0 at the top is v = 1 in glTF's flipped V).
	Image.fromarray(np.flipud(img).round().astype(np.uint8), "RGBA").save(out, optimize=False)
	return out


def _catmull(points, t: float) -> Vector:
	n = len(points) - 1
	f = min(max(t, 0.0), 1.0) * n
	i = min(int(f), n - 1)
	u = f - i
	p0 = Vector(points[max(i - 1, 0)])
	p1, p2 = Vector(points[i]), Vector(points[i + 1])
	p3 = Vector(points[min(i + 2, n)])
	return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u
			+ (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)


def _tail_radius(t: float) -> float:
	for (t0, r0), (t1, r1) in zip(TAIL_RADIUS, TAIL_RADIUS[1:]):
		if t <= t1:
			k = _smoothstep((t - t0) / max(t1 - t0, 1e-6))
			return r0 + (r1 - r0) * k
	return TAIL_RADIUS[-1][1]


def _ponytail(arm, mat) -> None:
	# The bones first: a chain from the tie to the tip, parented to Head.
	bpy.context.view_layer.objects.active = arm
	bpy.ops.object.mode_set(mode="EDIT")
	eb = arm.data.edit_bones
	parent = eb["Head"]
	joints = [_catmull(TAIL_PATH, 0.06 + 0.94 * k / TAIL_BONES) for k in range(TAIL_BONES + 1)]
	for k in range(TAIL_BONES):
		b = eb.new("ponytail_%d" % (k + 1))
		b.head, b.tail = joints[k], joints[k + 1]
		b.parent = parent
		b.use_connect = k > 0
		parent = b
	bpy.ops.object.mode_set(mode="OBJECT")
	# The tube.
	bm = bmesh.new()
	uvl = bm.loops.layers.uv.new("UVMap")
	rings = []
	up = Vector((1.0, 0.0, 0.0))
	for r in range(TAIL_RINGS + 1):
		t = r / TAIL_RINGS
		c = _catmull(TAIL_PATH, t)
		tangent = (_catmull(TAIL_PATH, min(t + 0.01, 1.0)) - _catmull(TAIL_PATH, max(t - 0.01, 0.0))).normalized()
		side = up.cross(tangent).normalized()
		norm = tangent.cross(side).normalized()
		base = _tail_radius(t)
		ring = []
		for k in range(TAIL_SIDES):
			a = 2 * math.pi * k / TAIL_SIDES
			curl = 1.0 + CURL_DEPTH * math.sin(CURL_LOBES * a + CURL_TWIST * 2 * math.pi * t) \
					* _smoothstep(t / 0.2)
			ring.append(bm.verts.new(c + (side * math.cos(a) + norm * math.sin(a)) * base * curl))
		rings.append((ring, t))
	for (ra, ta), (rb, tb) in zip(rings, rings[1:]):
		for k in range(TAIL_SIDES):
			k2 = (k + 1) % TAIL_SIDES
			f = bm.faces.new((ra[k], ra[k2], rb[k2], rb[k]))
			for loop, (kk, tt) in zip(f.loops, ((k, ta), (k + 1, ta), (k + 1, tb), (k, tb))):
				# Strands along the tail: v down its length, u round it.
				loop[uvl].uv = (kk / TAIL_SIDES * 2.0, 0.3 + tt * 0.65)
	tip = bm.verts.new(_catmull(TAIL_PATH, 1.0) + (_catmull(TAIL_PATH, 1.0) - _catmull(TAIL_PATH, 0.97)).normalized() * 0.01)
	last = rings[-1][0]
	for k in range(TAIL_SIDES):
		bm.faces.new((last[k], last[(k + 1) % TAIL_SIDES], tip))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new("Aubrey_Ponytail")
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	me.materials.append(mat)
	ob = bpy.data.objects.new("Aubrey_Ponytail", me)
	bpy.context.collection.objects.link(ob)
	ob.parent = arm
	# Weights: Head at the tie, then a blend along the chain.
	groups = {n: ob.vertex_groups.new(name=n) for n in ["Head"] + ["ponytail_%d" % (k + 1) for k in range(TAIL_BONES)]}
	for v in me.vertices:
		# Nearest point on the chain, as a bone coordinate.
		best, best_d = 0.0, 1e9
		for k in range(TAIL_BONES):
			a, b = joints[k], joints[k + 1]
			ab = b - a
			t = min(max((v.co - a).dot(ab) / ab.length_squared, 0.0), 1.0)
			d = (a + ab * t - v.co).length
			if d < best_d:
				best, best_d = k + t, d
		if v.co.z > joints[0].z - 0.005 and best < 0.05:
			groups["Head"].add([v.index], 1.0, "REPLACE")
			continue
		k = min(int(best), TAIL_BONES - 1)
		f = best - k
		groups["ponytail_%d" % (k + 1)].add([v.index], 1.0 - f * 0.5, "REPLACE")
		nxt = "ponytail_%d" % (k + 2) if k + 1 < TAIL_BONES else "Head" if k == 0 else None
		if nxt and k + 1 < TAIL_BONES:
			groups[nxt].add([v.index], f * 0.5, "REPLACE")
	md = ob.modifiers.new("Armature", "ARMATURE")
	md.object = arm
	# The hair tie.
	bm = bmesh.new()
	c = _catmull(TAIL_PATH, 0.05)
	tangent = (_catmull(TAIL_PATH, 0.07) - _catmull(TAIL_PATH, 0.03)).normalized()
	side = up.cross(tangent).normalized()
	norm = tangent.cross(side).normalized()
	R, rr = 0.0175, 0.0045
	grid = []
	for i in range(16):
		a = 2 * math.pi * i / 16
		row = []
		for j in range(8):
			b = 2 * math.pi * j / 8
			d = side * math.cos(a) + norm * math.sin(a)
			row.append(bm.verts.new(c + d * (R + rr * math.cos(b)) + tangent * rr * math.sin(b)))
		grid.append(row)
	for i in range(16):
		for j in range(8):
			bm.faces.new((grid[i][j], grid[(i + 1) % 16][j], grid[(i + 1) % 16][(j + 1) % 8], grid[i][(j + 1) % 8]))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	me = bpy.data.meshes.new("Aubrey_HairTie")
	bm.to_mesh(me)
	bm.free()
	for p in me.polygons:
		p.use_smooth = True
	me.materials.append(_flat("M_HairTie", (0.01, 0.01, 0.01, 1.0), 0.4))
	tie = bpy.data.objects.new("Aubrey_HairTie", me)
	bpy.context.collection.objects.link(tie)
	tie.parent = arm
	tie.vertex_groups.new(name="Head").add(list(range(len(me.vertices))), 1.0, "REPLACE")
	tie.modifiers.new("Armature", "ARMATURE").object = arm


if __name__ == "__main__":
	import bpy_exit
	bpy_exit.finish(main())
