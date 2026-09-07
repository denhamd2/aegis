extends Node3D
class_name RingBuilder
## Generates every cosmetic surface of the ring: the canvas, the ropes, the
## turnbuckle fittings, the posts, the apron frame and the steel steps.
##
## Why generated rather than authored in scenes/ring.tscn, following the same
## reasoning as core/arena/arena_builder.gd: a rope is 28 segments of swept
## tube per span and there are twelve spans, a corner carries six rope
## terminations, and a canvas is a texture. None of that is hand-typeable as
## transforms, and expressed as a .tscn it would be exactly the transform soup
## nobody can review. Expressed as the constants below it is reviewable.
##
## THE RING THIS IS MATCHED TO is gauntlet/refs/ring.md -- a plain, unbranded
## ring: white canvas with wear only, thin dark ropes, square black posts, bare
## turnbuckle fittings, a flat dark skirt, bright bare-metal steps. That
## reference governs the ring's LOOK. gauntlet/refs/VISUAL_BAR.md, measured off
## the WWE 2K stills, still governs the measured RELATIONSHIPS (the mat's
## exposure anchor, silhouette separation, void_fraction). Where the two touch
## -- rope colour, most obviously -- the call sites below say which won and
## why.
##
## EVERYTHING HERE IS COSMETIC. This file creates no CollisionObject3D, joins
## no physics layer, and is read by no gameplay system. The ring's colliders --
## Floor/CollisionShape3D and the four RopeCollision* bodies in the group
## "ring_ropes" -- stay in scenes/ring.tscn untouched, at their original
## extents, which is why rope *sag* is a displacement of the rendered mesh only
## and the bodies wrestler_controller.gd bounces off have not moved.
##
## DIMENSIONS THAT MAY NOT CHANGE (the measurement chain hangs off them):
##   * the mat is 6m square and its surface is y = 0. refs/camera.md's 41-deg
##     lens, test_camera_framing.gd's MAX_SEPARATION 8.49 and
##     grapple_rig.gd's RING_HALF_EXTENT 2.0 are all derived from it.
##   * the ropes' span sits at +/-3.1 on the perpendicular axis, at heights
##     0.5 / 0.85 / 1.2. camera.md derives the lens from the 3.1m figure.
## Both are asserted below rather than merely commented, so a later edit that
## drifts them fails loudly instead of silently invalidating the camera.

# --- The frozen numbers ------------------------------------------------------
const MAT_HALF := 3.0
const MAT_TOP_LOCAL := 0.1  ## Floor box is 0.2 thick, Ring sits at y = -0.1.
const ROPE_SPAN := 3.1
const ROPE_HEIGHTS := [0.5, 0.85, 1.2]
const POST_XZ := 3.0

# --- Ropes -------------------------------------------------------------------
## Rope radius. The ring reference (refs/ring.md) shows thin dark cable, and
## thinner than what stood here: these are the finest lines in the frame, not
## a structural element. COVERAGE DECISION -- neither reference measures a
## rope diameter.
const ROPE_RADIUS := 0.018
const ROPE_RINGS := 8
const ROPE_SEGMENTS := 28
## Sag at midspan, per rope, top to bottom. The lower ropes are slacker, but
## all three are far tauter than they were: the ring reference's ropes read as
## near-straight lines between the posts, where the outgoing 3-4.8cm was a
## visible curve. COVERAGE DECISION -- the reference shows tension, it does not
## measure a depth.
const ROPE_SAG := {1.2: 0.010, 0.85: 0.014, 0.5: 0.018}
## How far past the post centre a rope runs before its turnbuckle nub swallows
## the end. The nub is small now that the branded pad is gone, so this is small
## too -- overrun the pad used to hide would now hang in open air.
const ROPE_OVERRUN := 0.022

# --- Turnbuckles -------------------------------------------------------------
## No pads. The ring reference (refs/ring.md) has bare corners: each rope ends
## in a short dark sleeve clamped to the post, with a small clevis behind it,
## and nothing else. What was here -- a 0.37 x 1.13m padded vinyl slab per
## corner carrying a stacked-bar mark -- is gone entirely, and with it
## _pad_vinyl() and the PAD_* palette.
##
## Worth saying plainly, because it inverts an earlier round's reasoning: that
## mark was added under the IP guardrail (a chevron group read as a
## letterform, so it became stacked bars). Deleting the pad deletes the
## guardrail problem rather than managing it. A bare corner cannot resemble
## anyone's trade dress.
const NUB_LENGTH := 0.115
const NUB_RADIUS := 0.038
const CLEVIS := Vector3(0.05, 0.055, 0.07)

# --- Posts -------------------------------------------------------------------
## SQUARE, not round. The reference's posts are flat-faced dark slabs, and they
## are axis-aligned to the ring sides rather than turned to the diagonal -- the
## flat face reads straight down the camera's line on a side-on shot, which is
## most of the shotlist. The outgoing cylinder, its steel cap and the lace
## collar under the pad all go with the pad they were dressed for.
const POST_SECTION := 0.155
const POST_BOTTOM := -0.10
## Taller than the outgoing 1.60: in the reference the post stands well clear
## of the top rope, which is what gives the corner its vertical line.
const POST_TOP := 1.78

# --- Apron -------------------------------------------------------------------
const APRON_OUT := 3.20
const APRON_TOP := -0.10
const APRON_BOTTOM := -1.00

# --- Steel steps -------------------------------------------------------------
const STEP_TREADS := 3
const STEP_WIDTH := 1.45
const STEP_RUN := 0.36
const STEP_TOP_Y := -0.14
const STEP_FLOOR_Y := -1.00

# --- Texture generation ------------------------------------------------------
const CANVAS_SIZE := 1024
## Canvas panels are sewn in strips. Five seams across 6m is a 1.2m panel,
## which is the width canvas is milled at. COVERAGE DECISION.
const CANVAS_PANEL := 1.2
const CANVAS_SEED := 20260903
## The mat's palette, as effective albedo (albedo_color is CANVAS_WHITE, so a
## texel is very nearly the surface's albedo outright).
##
## Near-neutral and near-white, because the ring reference (refs/ring.md) is a
## plain unbranded canvas: no blue field, no centre mark, no painted border.
## Two consequences worth stating rather than discovering later:
##
##  * The mat gets BRIGHTER, and that is wanted. VISUAL_BAR.md's mat figure is
##    an exposure anchor at 0.43-0.49 and the build measured 0.359 before this
##    change -- below its own anchor, which also capped how far a wrestler
##    could sit below it (0.208/0.199 against a 0.24-0.31 band). A white
##    canvas raises the ceiling those deltas live under.
##  * It is deliberately NOT warmed toward cream. compare_frame.py reads
##    warm/cool -0.311 against the reference still's -0.333, so ours is
##    already the warmer of the two, and the mat is 212k of 921k pixels in
##    that frame. A warm mat would widen a gap that is already open.
const CANVAS_WHITE := Color(0.975, 0.975, 0.972)
## The canvas body, multiplied into CANVAS_WHITE.
##
## SOLVED, not picked. The first pass at this put the field at 0.93 and the mat
## rendered at 0.590 -- overshooting the 0.43-0.49 anchor as badly as the blue
## mat undershot it at 0.359, and dragging mat<->wrestler to 0.438/0.429
## against a 0.24-0.31 band. Two measured points are enough to fit the curve
## between linear albedo and rendered luminance through this tonemap
## (rendered ~= 0.692 * L**0.719, from L 0.402 -> 0.359 and L 0.801 -> 0.590),
## and 0.46 comes back as L 0.567, i.e. effective albedo ~0.78 sRGB. That is
## what these are, net of the mean the wear below subtracts.
##
## The slight cool cast is the one concession to a second measurement:
## compare_frame.py reads saturation 0.306 and warm/cool -0.333 on the
## reference still, and a large neutral-white mat pulls both toward zero
## (0.195 / -0.077 on the first pass). This is far too weak to read as a
## coloured mat -- it is white canvas under cool light, which is what it is --
## but it is not nothing.
const CANVAS_FIELD := Color(0.770, 0.792, 0.830)

## Generated once per process. match.tscn is instantiated by several test
## suites and by every capture; regenerating a 512-square canvas each time is
## pure waste.
static var _canvas_texture: ImageTexture
static var _canvas_normal_texture: ImageTexture
## The canvas height field, kept so the normal map is derived from the same
## weave the albedo was drawn from rather than from a second, disagreeing one.
static var _canvas_height: PackedFloat32Array

var _ring: Node3D


func _ready() -> void:
	_ring = get_parent() as Node3D
	if _ring == null:
		push_error("RingBuilder must be a child of the Ring node.")
		return
	_assert_frozen_dimensions()
	_build_canvas()
	_build_ropes()
	_build_turnbuckles_and_posts()
	_build_apron_detail()
	_build_steps()


## The measurement chain in camera.md / test_camera_framing.gd / grapple_rig.gd
## is derived from these two numbers. If a later edit moves them, this says so
## instead of letting every downstream number quietly become wrong.
func _assert_frozen_dimensions() -> void:
	var shape: CollisionShape3D = _ring.get_node_or_null("Floor/CollisionShape3D")
	if shape and shape.shape is BoxShape3D:
		var size: Vector3 = (shape.shape as BoxShape3D).size
		assert(is_equal_approx(size.x, 6.0) and is_equal_approx(size.z, 6.0),
			"The mat must stay 6m square -- camera.md and test_camera_framing.gd derive from it.")
	assert(is_equal_approx(_ring.position.y + MAT_TOP_LOCAL, 0.0),
		"The mat surface must stay at y = 0.")
	assert(is_equal_approx(ROPE_SPAN, 3.1), "camera.md derives the 41-degree lens from ropes at 3.1m.")


# =============================================================== materials ===
## EVERY material this file uses is resolved here and nowhere else, so the
## swap between the two sources below is a single edit.
##
## The source of record is core/materials/material_library.gd (A2's), reached
## through MATERIAL_LIBRARY by path rather than by class_name. That indirection
## is deliberate and not cargo cult: the library is authored on a sibling
## branch and is merged in underneath this one, so a direct
## `MaterialLibrary.resolve(...)` call would be a parse error in this worktree
## and the ring would not build at all. Resolved by path, this file runs
## correctly on its own and picks the library up the moment the merge lands,
## with no edit at integration.
##
## The fallbacks below are what this file uses until then. They are plain
## StandardMaterial3D with no PBR maps behind them, which is exactly what the
## library exists to fix -- it sizes texel density in world metres, so a 1K map
## over a 6m mat carries detail instead of stretching into nothing.
const MATERIAL_LIBRARY := "res://core/materials/material_library.gd"

static var _library: Object
static var _library_checked := false


## Resolves `key` from the material library, falling back to `fallback`.
## `overrides` is passed through: the library takes a spec-field dictionary, so
## the per-corner turnbuckle tint is an override rather than a new key.
func _resolve(key: String, fallback: StandardMaterial3D,
		overrides: Dictionary = {}) -> StandardMaterial3D:
	if not _library_checked:
		_library_checked = true
		if ResourceLoader.exists(MATERIAL_LIBRARY):
			_library = load(MATERIAL_LIBRARY)
	if _library == null:
		return fallback
	var resolved: Variant = _library.call("resolve", key, overrides)
	if resolved is StandardMaterial3D:
		# Duplicated because the library may hand back a shared instance and
		# two call sites here go on to set albedo on what they get. Mutating a
		# shared material would reach every other consumer of the key.
		return (resolved as StandardMaterial3D).duplicate() as StandardMaterial3D
	push_warning("RingBuilder: material key '%s' did not resolve; using the "
		% key + "local fallback.")
	return fallback


func _mat(albedo: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	# metallic is 0 or 1, never between: a surface is a conductor or it is not.
	# The outgoing post material sat at 0.3, which describes no real material.
	m.metallic = metallic
	return m


## Steel, as a DIELECTRIC, and this is a coverage decision with a reason rather
## than a slip. metallic is 0 or 1 and never between -- which is why the
## outgoing post material's 0.3 was wrong by construction -- but a conductor
## renders as nothing except what it reflects, and the hall around this ring
## has no reflection probe and no sky. Set metallic 1.0 and the posts, caps and
## steps come out black. The library agrees: its `ring_post` is metallic 0.0
## painted steel, and it flags `ring_post_chrome` as unusable for this exact
## reason. Revisit the day the arena gets a radiance map.
func _steel() -> StandardMaterial3D:
	return _resolve("ring_steel", _mat(Color(0.60, 0.61, 0.65), 0.28))


## Bare, unpainted steel: the ring steps and nothing else. Bright, because in
## the ring reference the steps are the second-lightest surface in the frame
## after the canvas -- diamond plate catching the house rig. Still a dielectric
## for exactly the reason _steel()'s note above gives: with no radiance map in
## this scene a conductor renders black, and a bright black step is worse than
## a slightly wrong one.
func _bare_steel() -> StandardMaterial3D:
	return _resolve("ring_steps", _mat(Color(0.62, 0.62, 0.63), 0.42))


## The canvas. Takes the library's `ring_canvas` fabric for its normal and
## roughness maps at their world-metre texel density, and overrides albedo
## only, because the generated weave/seam/scuff texture above and a library
## albedo cannot both occupy StandardMaterial3D's single albedo slot.
##
## albedo_color is near-white and the texture is near-white too, which is a
## simplification over what stood here before. The old arrangement had a blue
## field in the texture and a white albedo_color, because a texture cannot
## brighten past albedo_color and the mark had to be the lightest thing on the
## mat. With no mark, there is nothing to hold headroom for: the mat is one
## near-white surface with wear multiplied into it.
##
## test_wrestler_colorway.gd reads this albedo and asserts the mat sits far
## above either wrestler's skin. Near-white is further above, not less.
##
## The mat's RENDERED value is VISUAL_BAR.md's exposure anchor and measured
## 0.359 against a 0.43-0.49 band before this change. Brightening the canvas is
## the one lever the ring owns there; the rest is lighting's, and lighting is
## deliberately untouched in this round.
func _canvas_material() -> StandardMaterial3D:
	var m := _resolve("ring_canvas", _mat(CANVAS_WHITE, 0.86))
	m.albedo_color = CANVAS_WHITE
	m.albedo_texture = _canvas()
	if m.roughness_texture == null:
		# The weave drives roughness as well as albedo. A canvas is not
		# uniformly glossy -- the thread crowns catch the ring rig and the
		# valleys do not -- and that specular breakup is detail the albedo
		# alone cannot produce, because it survives at grazing angles where
		# the albedo variation is already washed out by the light. The library
		# brings its own roughness map when it is present; this stands in.
		m.roughness = 0.86
		m.roughness_texture = _canvas()
	if m.normal_texture == null:
		m.normal_enabled = true
		m.normal_texture = _canvas_normal()
		# 0.75 rather than the 1.0 this shipped at: enough relief to keep the
		# weave re-lit (fine detail is 0.31 against the reference's 0.61 and
		# needs everything it can get) without returning to the corduroy that
		# CANVAS_RELIEF's note describes.
		m.normal_scale = 0.75
	m.uv1_scale = Vector3.ONE
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## Rope. WHITE, thin and semi-gloss.
##
## Back to white, by direct instruction from the project owner.
##
## This has now been both colours, and the note is kept because the reasoning
## still matters. The value was traced white off the WWE 2K stills; a later
## round took it to near-black to match gauntlet/refs/ring.md, whose ring is
## strung with black cable. The owner wants white, so white governs the look.
## refs/ring.md still governs the rest of the ring, and the measured
## relationships in VISUAL_BAR.md are untouched -- a rope is under 4cm across
## and is not what sets the mat exposure anchor or the silhouette separation.
##
## Roughness rises with the colour, 0.30 -> 0.45. The low value existed only
## because a dark rope could not separate from a dark hall by value and the
## specular return had to draw the line for it; a white rope separates by
## value on its own, and left at 0.30 it reads as wet plastic under the spots.
func _rope_material() -> StandardMaterial3D:
	var m := _resolve("ring_rope", _mat(Color(0.88, 0.88, 0.87), 0.45))
	m.albedo_color = Color(0.88, 0.88, 0.87)
	m.roughness = 0.45
	m.albedo_texture = null
	m.uv1_scale = Vector3.ONE
	return m


# =================================================================== canvas ===

func _build_canvas() -> void:
	var floor_mesh: MeshInstance3D = _ring.get_node_or_null("Floor/MeshInstance3D")
	if floor_mesh == null:
		push_error("RingBuilder: Ring/Floor/MeshInstance3D is missing -- "
			+ "capture_harness.gd keys the silhouette mask off that exact path.")
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Surface 0 is the mat's top face alone, with a full 0..1 UV over the 6m
	# square, so the canvas texture's seams and wear land in world space where
	# they are drawn rather than tiling arbitrarily. BoxMesh atlases its six
	# faces into one UV square and cannot do this.
	_quad(st,
		Vector3(-MAT_HALF, MAT_TOP_LOCAL, MAT_HALF),
		Vector3(MAT_HALF, MAT_TOP_LOCAL, MAT_HALF),
		Vector3(MAT_HALF, MAT_TOP_LOCAL, -MAT_HALF),
		Vector3(-MAT_HALF, MAT_TOP_LOCAL, -MAT_HALF),
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0))
	st.generate_tangents()
	var mesh := st.commit()

	# Surface 1: the canvas rolling over the edge onto the ring frame.
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var basis_dir: Vector3 = [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)][side]
		var tangent := Vector3(basis_dir.z, 0, -basis_dir.x)
		var a: Vector3 = basis_dir * MAT_HALF + tangent * MAT_HALF + Vector3(0, MAT_TOP_LOCAL, 0)
		var b: Vector3 = basis_dir * MAT_HALF - tangent * MAT_HALF + Vector3(0, MAT_TOP_LOCAL, 0)
		_quad(edge, a, b, b - Vector3(0, 0.2, 0), a - Vector3(0, 0.2, 0),
			Vector2(0, 0), Vector2(4, 0), Vector2(4, 1), Vector2(0, 1))
	edge.generate_tangents()
	edge.commit(mesh)

	floor_mesh.mesh = mesh
	floor_mesh.set_surface_override_material(0, _canvas_material())
	# The canvas rolling over the mat edge onto the frame. Dark neutral grey:
	# in the reference this band is the shadowed lip between a white mat and a
	# dark skirt, and it is what stops the two reading as one surface.
	floor_mesh.set_surface_override_material(1, _resolve("ring_apron",
		_mat(Color(0.17, 0.17, 0.175), 0.85), {"tint": Color(0.17, 0.17, 0.175)}))


## The canvas texture: weave, panel seams, wear and scuff. Multiplies into
## _canvas_material()'s albedo_color.
##
## What is NOT here any more, and why. This drew an original centre mark (a
## ringed triple chevron), two secondary marks on the near and far thirds, and
## a painted border inside the mat edge. All three are gone, because the ring
## reference (refs/ring.md) is an unbranded canvas carrying nothing but wear.
##
## That has a measured cost and it is booked rather than hidden: the marks were
## put here to move coarse detail, which is the lever the mat owns by being the
## largest surface in the frame. The replacement is the streak and traffic
## fields above plus deeper panel seams -- large-scale incident of the kind the
## reference actually has. Whether that holds the number is a measurement, not
## a claim; see the round write-up.
##
## The one thing this change makes strictly easier is the IP guardrail: a mat
## logo is the single most trade-dress-shaped object on a wrestling ring, and
## there now isn't one.
static func _canvas() -> ImageTexture:
	if _canvas_texture != null:
		return _canvas_texture
	var noise := FastNoiseLite.new()
	noise.seed = CANVAS_SEED
	noise.frequency = 0.45
	var fine := FastNoiseLite.new()
	fine.seed = CANVAS_SEED + 7
	fine.frequency = 3.2
	## Scuff streaks. Sampled with the x axis squashed and the z axis stretched,
	## which turns isotropic noise into long smears running across the mat --
	## which is what the reference's canvas actually carries, and what has to
	## hold the coarse-detail end of the frame now the centre mark is gone.
	var streak := FastNoiseLite.new()
	streak.seed = CANVAS_SEED + 13
	streak.frequency = 0.40
	var streak_b := FastNoiseLite.new()
	streak_b.seed = CANVAS_SEED + 29
	streak_b.frequency = 0.32

	var n := CANVAS_SIZE
	var data := PackedByteArray()
	data.resize(n * n * 3)
	_canvas_height = PackedFloat32Array()
	_canvas_height.resize(n * n)
	var metres := 6.0 / float(n)
	for py: int in range(n):
		var z := (float(py) + 0.5) * metres - MAT_HALF
		for px: int in range(n):
			var x := (float(px) + 0.5) * metres - MAT_HALF
			var v := 1.0

			# Weave. Two interleaved thread directions, at the resolution floor
			# on purpose -- at match distance this is grain, not pattern.
			#
			# The amplitude is a third of what it was, and that is a fix rather
			# than a preference. A 4-texel period sampled through a mip chain
			# beats against the pixel grid, and the two directions together
			# resolve into a diagonal herringbone; at 0.050 on a white mat that
			# read as corduroy across the whole canvas. The blue field used to
			# hide it. Nothing hides it now, so it comes down to where it is
			# grain again.
			# The 0.35 term is a per-thread irregularity, and it is load
			# bearing rather than garnish: a perfectly periodic 4-texel
			# pattern is what beats with the pixel grid in the first place.
			# Jittering each thread's own weight breaks the beat while
			# leaving the weave a weave.
			var thread := 0.016 * (1.0 + 0.35 * fine.get_noise_2d(
				float(px) * 0.37, float(py) * 0.37))
			v += thread * float((px % 4) - 1.5) * 0.667 \
				+ thread * float((py % 4) - 1.5) * 0.667
			# Wear: a low octave for the trodden centre, a higher one for scuff.
			v += 0.045 * noise.get_noise_2d(x * 4.0, z * 4.0)
			v += 0.026 * fine.get_noise_2d(x * 4.0, z * 4.0)
			v += 0.030 * fine.get_noise_2d(x * 19.0, z * 19.0)

			# Scuff streaks, in two directions so the mat does not read as
			# combed. Biased dark -- a scuff is dirt, it never brightens
			# canvas -- via the -absf(), which is also what keeps the clean
			# parts of the mat genuinely clean instead of grey overall.
			#
			# Deliberately LOW frequency and long. This is the mat's whole
			# contribution to coarse detail now that the centre mark is gone,
			# and coarse detail is measured on a heavily downscaled frame:
			# anything with a period under about a third of a metre is averaged
			# out of that measurement before it is taken. The first pass ran
			# these at z * 7.0, which is fine grain, and coarse detail fell to
			# 0.202 from the marked mat's 0.276.
			v -= 0.110 * absf(streak.get_noise_2d(x * 0.45, z * 2.6))
			v -= 0.085 * absf(streak_b.get_noise_2d(x * 2.4, z * 0.40))

			# Traffic. The middle of a mat is where the match happens and it
			# is visibly greyer for it; the corners stay near-clean.
			var traffic := 1.0 - clampf(sqrt(x * x + z * z) / 2.7, 0.0, 1.0)
			v -= 0.075 * traffic * traffic

			# Panel seams. A sewn seam is a dark valley with a raised lip, and
			# with the mark gone these are the largest deliberate feature left
			# on the mat, so they run deeper than they did.
			var seam := absf(fposmod(z + CANVAS_PANEL * 0.5, CANVAS_PANEL) - CANVAS_PANEL * 0.5)
			# WIDE, and this is the one number here set by the measurement
			# rather than by the thing being modelled. From the wide camera the
			# 6m mat spans about 700px, so a centimetre is roughly a pixel --
			# and coarse detail is read off a frame downscaled far below that.
			# A 1.4cm seam is invisible to it no matter how deep it goes. A
			# 4cm lap is both what a sewn canvas seam actually measures once
			# the doubled-over lip is counted, and wide enough to survive the
			# downscale, which is what makes it worth having.
			if seam < 0.040:
				v -= 0.26
			elif seam < 0.075:
				v += 0.060
				if fposmod(x, 0.05) < 0.022:   # the stitch itself
					v -= 0.10

			var col := CANVAS_FIELD * v

			_canvas_height[py * n + px] = v
			var i := (py * n + px) * 3
			data[i] = _byte(col.r)
			data[i + 1] = _byte(col.g)
			data[i + 2] = _byte(col.b)

	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_canvas_texture = ImageTexture.create_from_image(img)
	return _canvas_texture


## A normal map derived from the canvas's own weave.
##
## This is the fine-detail lever the albedo alone cannot pull. An albedo weave
## is flattened by the light: at the wide camera's grazing angle the mat is lit
## almost uniformly, so a 4% albedo ripple survives as a 4% pixel ripple and
## then gets averaged away by the mip chain. A normal ripple is re-lit every
## frame -- the thread crowns face the ring rig and the valleys do not -- so it
## produces a much larger pixel difference from the same surface, and it is the
## same mechanism A2 leans on with normal_scale in the library keys.
##
## Derived by central difference from the same height field _canvas() drew the
## albedo from, so the two cannot disagree about where a thread is.
##
## RELIEF IS DOWN FROM 4.0, and the reason is the same mechanism this docstring
## spends its length praising, turned against the mat. The weave has a 4-texel
## period; a normal ripple at that period is re-lit every frame, which is
## exactly why it survives where an albedo ripple does not -- and also why, on
## a white mat, the two thread directions resolved into a diagonal herringbone
## across the whole canvas. It was there under the blue field too and the blue
## hid it.
##
## So the lever is kept and turned down rather than removed: 1.5 leaves the
## weave re-lit and legible up close in `mat_close`, without it beating against
## the pixel grid into corduroy at match distance. The reference's canvas is a
## smooth surface with soft broad wear on it, not a corded one.
const CANVAS_RELIEF := 1.5

static func _canvas_normal() -> ImageTexture:
	if _canvas_normal_texture != null:
		return _canvas_normal_texture
	_canvas()  # populates _canvas_height
	var n := CANVAS_SIZE
	var data := PackedByteArray()
	data.resize(n * n * 3)
	for py: int in range(n):
		for px: int in range(n):
			var left := _canvas_height[py * n + posmod(px - 1, n)]
			var right := _canvas_height[py * n + posmod(px + 1, n)]
			var up := _canvas_height[posmod(py - 1, n) * n + px]
			var down := _canvas_height[posmod(py + 1, n) * n + px]
			var normal := Vector3((left - right) * CANVAS_RELIEF,
				(up - down) * CANVAS_RELIEF, 1.0).normalized()
			var i := (py * n + px) * 3
			data[i] = _byte(normal.x * 0.5 + 0.5)
			data[i + 1] = _byte(normal.y * 0.5 + 0.5)
			data[i + 2] = _byte(normal.z * 0.5 + 0.5)
	var img := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, data)
	img.generate_mipmaps()
	_canvas_normal_texture = ImageTexture.create_from_image(img)
	return _canvas_normal_texture


static func _byte(f: float) -> int:
	return clampi(int(round(clampf(f, 0.0, 1.0) * 255.0)), 0, 255)


# ==================================================================== ropes ===

func _build_ropes() -> void:
	var holder := _replace("Ropes")
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for height: float in ROPE_HEIGHTS:
		for side: int in range(4):
			var along := Vector3(1, 0, 0) if side < 2 else Vector3(0, 0, 1)
			var out := Vector3(0, 0, 1) if side < 2 else Vector3(1, 0, 0)
			var sign_out := 1.0 if side % 2 == 0 else -1.0
			var base: Vector3 = out * (ROPE_SPAN * sign_out) + Vector3(0, height, 0)
			_sweep_rope(st, base, along, height)
	st.generate_tangents()
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "RopeMesh"
	mesh_instance.mesh = st.commit()
	mesh_instance.set_surface_override_material(0, _rope_material())
	holder.add_child(mesh_instance)


## One span, swept as a tube along a parabola. A catenary and a parabola differ
## by less than a millimetre over 6m at this sag, and the parabola is the one
## that can be written down.
func _sweep_rope(st: SurfaceTool, base: Vector3, along: Vector3, height: float) -> void:
	var half := POST_XZ + ROPE_OVERRUN
	var sag: float = ROPE_SAG[height]
	var up := Vector3(0, 1, 0)
	var side_dir := along.cross(up).normalized()
	var previous: Array = []
	for seg: int in range(ROPE_SEGMENTS + 1):
		var t := float(seg) / float(ROPE_SEGMENTS)
		var s := lerpf(-half, half, t)
		var drop := sag * 4.0 * t * (1.0 - t)
		var centre: Vector3 = base + along * s - up * drop
		var ring: Array = []
		for r: int in range(ROPE_RINGS + 1):
			var a := TAU * float(r) / float(ROPE_RINGS)
			var normal: Vector3 = (side_dir * cos(a) + up * sin(a)).normalized()
			ring.append([centre + normal * ROPE_RADIUS, normal,
				Vector2(float(r) / float(ROPE_RINGS), s / 0.11)])
		if seg > 0:
			for r: int in range(ROPE_RINGS):
				_tri(st, previous[r], previous[r + 1], ring[r + 1])
				_tri(st, previous[r], ring[r + 1], ring[r])
		previous = ring


# ============================================= turnbuckles, posts and caps ===

func _build_turnbuckles_and_posts() -> void:
	var holder := _replace("Posts")
	var dark := SurfaceTool.new(); dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fitting := SurfaceTool.new(); fitting.begin(Mesh.PRIMITIVE_TRIANGLES)

	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post := Vector3(POST_XZ * sx, 0.0, POST_XZ * sz)
			# Axis-aligned: local X runs along +X, local Z along +Z, so the
			# post's faces are parallel to the ring's sides.
			_oriented_box(dark,
				post + Vector3(0, (POST_BOTTOM + POST_TOP) * 0.5, 0),
				Vector3(1, 0, 0), Vector3(0, 0, 1),
				Vector3(POST_SECTION, POST_TOP - POST_BOTTOM, POST_SECTION))

			# Each rope terminates in its own sleeve, and each sleeve is on the
			# face its rope runs off. A corner carries two ropes per height --
			# one down X, one down Z -- so it carries two sleeves per height,
			# which is what the reference's corners show.
			for height: float in ROPE_HEIGHTS:
				var centre: Vector3 = post + Vector3(0, height, 0)
				for out: Vector3 in [Vector3(-sx, 0, 0), Vector3(0, 0, -sz)]:
					var tangent := Vector3(out.z, 0, -out.x)
					# The sleeve, lying along the rope, drawn as a box rather
					# than a cylinder: at this size the silhouette is four
					# pixels and a box costs a third of the triangles.
					_oriented_box(fitting,
						centre + out * (POST_SECTION * 0.5 + NUB_LENGTH * 0.5),
						tangent, out,
						Vector3(NUB_RADIUS * 2.0, NUB_RADIUS * 2.0, NUB_LENGTH))
					# The clevis clamping the sleeve back to the post.
					_oriented_box(fitting,
						centre + out * (POST_SECTION * 0.5 + 0.012),
						tangent, out, CLEVIS)

	# Matte, not satin. At roughness 0.55 the posts carried a hard vertical
	# specular streak down each face and read as moulded plastic; the
	# reference's posts are flat black padding and return almost nothing.
	_emit(holder, "PostMesh", dark,
		_resolve("ring_post", _mat(Color(0.075, 0.075, 0.080), 0.94)))
	_emit(holder, "TurnbuckleFittings", fitting,
		_resolve("ring_post", _mat(Color(0.11, 0.11, 0.115), 0.42)))


# ==================================================================== apron ===
## The skirt boxes stay in ring.tscn (they carry the CC0 fabric this file must
## not re-license). What is added here is the frame the skirt hangs from.
##
## What is NOT added any more: the printed chevron band, and the nine vertical
## folds per side. The ring reference (refs/ring.md) has a flat, unbranded,
## near-featureless skirt -- a dark grey sheet from the mat edge to the floor
## with a lip at the top and a hem at the bottom. The band went with the rest
## of the branding; the folds went because the reference's skirt is drum-tight,
## not draped.
##
## The round note that used to sit on the band is kept, because it is about
## this strip of frame rather than about the band, and it still binds: a bright
## surface hung here lit the one strip of the wide frame that was still pure
## black and took void_fraction from 0.023 to 0.002, outside VISUAL_BAR.md's
## 0.010-0.066 floor. A real arena is dark under the ring apron. Everything
## added below is therefore dark, which is also what the reference shows -- the
## two agree, which is the comfortable case.

func _build_apron_detail() -> void:
	var holder := _replace("ApronDetail")
	var rail := SurfaceTool.new(); rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var out: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
		var tangent := Vector3(out.z, 0, -out.x)
		var mid: Vector3 = out * APRON_OUT
		# The lip the skirt hangs off, under the mat edge.
		_oriented_box(rail, mid + Vector3(0, APRON_TOP + 0.04, 0), tangent, out,
			Vector3(6.62, 0.13, 0.17))
		# The hem, weighted so the skirt hangs straight.
		_oriented_box(rail, mid + Vector3(0, APRON_BOTTOM + 0.03, 0), tangent, out,
			Vector3(6.58, 0.07, 0.13))
	_emit(holder, "ApronRail", rail,
		_resolve("ring_apron", _mat(Color(0.105, 0.105, 0.112), 0.85),
			{"tint": Color(0.105, 0.105, 0.112)}))


# ============================================================== steel steps ===
## Geometry unchanged -- three treads at +/-X, offset along Z, which is already
## where the reference puts them. What changes is the material: in the
## reference the steps are BARE metal and the second-brightest thing in the
## frame after the canvas, where here they shared the ring's dark painted
## `ring_steel` with the apron rail. They get their own key for that reason;
## brightening `ring_steel` itself would have brightened the apron rail with
## them, into the strip of frame the note above says to leave dark.

func _build_steps() -> void:
	var holder := _replace("Steps")
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 1.0]:
		var out := Vector3(sx, 0, 0)
		var tangent := Vector3(0, 0, 1)
		var rise := (STEP_TOP_Y - STEP_FLOOR_Y) / float(STEP_TREADS)
		for i: int in range(STEP_TREADS):
			var top := STEP_FLOOR_Y + rise * float(i + 1)
			var depth := STEP_RUN * float(STEP_TREADS - i)
			var centre: Vector3 = out * (APRON_OUT + 0.06 + depth * 0.5) \
				+ Vector3(0, (STEP_FLOOR_Y + top) * 0.5, 0) + tangent * 0.35
			_oriented_box(st, centre, tangent, out,
				Vector3(STEP_WIDTH, top - STEP_FLOOR_Y, depth))
	_emit(holder, "StepsMesh", st, _bare_steel())


# ================================================================== helpers ===

## Creates a container for one group of generated meshes.
##
## The meshes hang under RingBuilder itself, not under Ring. That is not a
## style choice: Ring is mid-instantiation while this node's _ready runs, and
## add_child() on a node that is still setting up its own children fails
## outright -- which is how the first wired build produced an empty ring and a
## row of "Parent node is busy setting up children" errors. RingBuilder sits at
## Ring's own origin with no transform of its own, so the local space the
## constants above are written in is unchanged.
func _replace(container: String) -> Node3D:
	var existing := get_node_or_null(container)
	if existing:
		remove_child(existing)
		existing.queue_free()
	var node := Node3D.new()
	node.name = container
	add_child(node)
	return node


func _emit(holder: Node3D, node_name: String, st: SurfaceTool, material: Material) -> void:
	st.generate_normals()
	st.generate_tangents()
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.set_surface_override_material(0, material)
	holder.add_child(instance)


func _tri(st: SurfaceTool, a: Array, b: Array, c: Array) -> void:
	for vertex: Array in [a, b, c]:
		st.set_normal(vertex[1])
		st.set_uv(vertex[2])
		st.add_vertex(vertex[0])


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	var normal := (b - a).cross(d - a).normalized()
	# Godot's front faces wind CLOCKWISE. The first wired build emitted a-b-c
	# / a-c-d, which is counter-clockwise seen from the side the normal points
	# at, so every generated face was back-facing: the mat rendered as a black
	# hole and every box was seen from the inside.
	for pair: Array in [[a, ua], [c, uc], [b, ub], [a, ua], [d, ud], [c, uc]]:
		st.set_normal(normal)
		st.set_uv(pair[1])
		st.add_vertex(pair[0])


## A box whose local X follows `tangent` and local Z follows `forward`, so a
## turnbuckle pad can face ring centre at 45 degrees without a transform node.
func _oriented_box(st: SurfaceTool, centre: Vector3, tangent: Vector3,
		forward: Vector3, size: Vector3) -> void:
	var x: Vector3 = tangent.normalized() * size.x * 0.5
	var y := Vector3(0, size.y * 0.5, 0)
	var z: Vector3 = forward.normalized() * size.z * 0.5
	var corner := func(i: int, j: int, k: int) -> Vector3:
		return centre + x * float(i) + y * float(j) + z * float(k)
	var faces := [
		[corner.call(-1, 1, 1), corner.call(1, 1, 1), corner.call(1, 1, -1), corner.call(-1, 1, -1)],
		[corner.call(-1, -1, -1), corner.call(1, -1, -1), corner.call(1, -1, 1), corner.call(-1, -1, 1)],
		[corner.call(-1, -1, 1), corner.call(1, -1, 1), corner.call(1, 1, 1), corner.call(-1, 1, 1)],
		[corner.call(1, -1, -1), corner.call(-1, -1, -1), corner.call(-1, 1, -1), corner.call(1, 1, -1)],
		[corner.call(1, -1, 1), corner.call(1, -1, -1), corner.call(1, 1, -1), corner.call(1, 1, 1)],
		[corner.call(-1, -1, -1), corner.call(-1, -1, 1), corner.call(-1, 1, 1), corner.call(-1, 1, -1)],
	]
	for face: Array in faces:
		_quad(st, face[0], face[1], face[2], face[3],
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))


func _cylinder(st: SurfaceTool, base: Vector3, height: float, radius: float,
		sides: int) -> void:
	var top := base + Vector3(0, height, 0)
	for i: int in range(sides):
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		_quad(st, base + d0 * radius, base + d1 * radius,
			top + d1 * radius, top + d0 * radius,
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
		st.set_normal(Vector3.UP)
		for point: Vector3 in [top, top + d0 * radius, top + d1 * radius]:
			st.set_uv(Vector2(point.x, point.z))
			st.add_vertex(point)
