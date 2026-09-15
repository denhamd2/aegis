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
## The three rope heights, declared one per line as plain numbers rather than
## as literals inside the array. tools/blender/ring.py reads its geometry out
## of this file (see venue.read_constants) and can only parse plain numeric
## constants, so a number that exists only inside an array or a dictionary is
## a number the mesh would have to retype -- which is how a mesh stops
## matching the game it is built for.
const ROPE_HEIGHT_BOTTOM := 0.5
const ROPE_HEIGHT_MIDDLE := 0.85
const ROPE_HEIGHT_TOP := 1.2
const ROPE_HEIGHTS := [ROPE_HEIGHT_BOTTOM, ROPE_HEIGHT_MIDDLE, ROPE_HEIGHT_TOP]
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
const ROPE_SAG_TOP := 0.010
const ROPE_SAG_MIDDLE := 0.014
const ROPE_SAG_BOTTOM := 0.018
const ROPE_SAG := {
	ROPE_HEIGHT_TOP: ROPE_SAG_TOP,
	ROPE_HEIGHT_MIDDLE: ROPE_SAG_MIDDLE,
	ROPE_HEIGHT_BOTTOM: ROPE_SAG_BOTTOM,
}
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
## The connector a rope visibly ends in, sitting ON the rope where it runs into
## the pad -- not inside the post.
##
## Two goes at this were wrong in opposite directions. The sleeve started at
## 0.115 pointing INWARD from the post face, which was right when the corner
## was bare and became a fitting that broke out through the pad's rounded edge
## once there was a pad. Shortening it to 0.055 buried it completely, and the
## reference shows the opposite: a dark clamp is plainly visible at the point
## each white rope meets the cushion.
##
## So the fitting moved onto the rope. The pad is 0.52 wide across the corner
## diagonal, which puts its edge where a rope crosses at
## ROPE_SPAN - PAD_WIDTH/2 * sqrt(2) = 2.732; the clamp straddles that line, so
## it reads as the rope entering a clamp that enters the pad.
const CLAMP_LENGTH := 0.09
const CLAMP_RADIUS := 0.032
## How far inboard of the pad's edge the clamp is centred. Small: the clamp
## should overlap the cushion, not stand off it with daylight between.
const CLAMP_INSET := 0.03

# --- Turnbuckle pads ---------------------------------------------------------
## The pads are BACK, and the note above them is now history rather than
## policy. The comment argued a bare corner "cannot resemble anyone's trade
## dress" -- true, and beside the point: gauntlet/refs/VISUAL_BAR.md settles
## the question the other way, and the AEW references this ring is now matched
## to have three cushions on every corner. They are the single loudest thing
## about a televised corner, and without them the post reads as a bare pole
## with the ropes passing it.
##
## One pad per rope per corner, turned to the DIAGONAL -- which is the one
## respect in which a pad disagrees with the post it is mounted on. The post
## stays axis-aligned (see below); the pad faces the ring centre, because that
## is the face a wrestler is thrown into and the face every camera sees.
const TURNBUCKLE_PAD_WIDTH := 0.52
const TURNBUCKLE_PAD_HEIGHT := 0.24
const TURNBUCKLE_PAD_DEPTH := 0.30
## Diagonal placement, per axis, and the number is set by the POST rather than
## by the ropes.
##
## Work in u, the distance from ring centre along the corner diagonal. The post
## is axis-aligned, so its own corners put it at u = 4.133 (inner) to 4.352
## (outer), and the two rope terminations land at u = 4.329 -- inside that
## span. A pad centred on the ropes therefore sits INSIDE the post, which is
## what the first attempt did: the post's inner corner stood proud of the
## cushion and split each pad into two lobes with a pole up the middle.
##
## So the pad's inner face has to clear u = 4.133, and 3.013 was not enough.
## It put the face at 4.111, clearing the post by 2.2cm -- against a PAD_BEVEL
## of 4.5cm. A bevel pulls the cushion's own face back by up to its width near
## the arris, so across most of the pad's middle the post's corner stood
## through the front of it and read as a faint chevron on every cushion. This
## is the nub-through-the-arris mistake again, one part further along.
##
## 2.979 puts the face at 4.063: 7.0cm of clearance, comfortably more than the
## bevel can eat. The rope ends at 4.329 are still inside the pad's outer face
## at 4.363, which is the other half of the constraint and the reason the
## depth stays at 0.30.
const TURNBUCKLE_PAD_XZ := 2.979
## The rounding on a cushion's arrises. It lives HERE, not in ring.py with the
## other bevel widths, because it is not only a shading choice: it eats into
## the clearance above, and a test can only pin that relationship if both
## numbers are in the same file. `tools/blender/ring.py` reads it out of here
## like every other ring constant.
const TURNBUCKLE_PAD_BEVEL := 0.045

# --- The turnbuckle connector ------------------------------------------------
## The metal plate joining a rope to the post, sat on the pad's inner face.
##
## In the reference this is the most legible piece of hardware at a corner: a
## flat bracket with a row of bolt holes, noticeably LIGHTER than the cushion
## it is bolted through, catching the ring lights where everything around it
## is matte black. Without it a corner is three featureless cushions, which is
## what the build showed.
##
## It is centred ON the pad's inner face rather than in front of it, so half
## its depth is buried in the cushion and half stands proud -- a plate bolted
## through a pad, not a box parked against one.
const CONNECTOR_WIDTH := 0.10
const CONNECTOR_HEIGHT := 0.085
const CONNECTOR_DEPTH := 0.07
## How far along the pad, from its centre, each connector sits.
##
## They were centred on the pad's face, which was a fair reading of the
## reference until the pad got its AEW artwork -- a steel plate parked over the
## middle of the logo. The reference puts the bracket at the ROPE END anyway,
## where the rope enters the cushion, not on the front of it. Two per pad, one
## per rope, right out at the cushion's ends.
##
## 0.20 wide at +/-0.15 was the first try and swallowed the artwork: the plates
## reached from 0.05 to 0.25 either side of centre, against a face only 0.43
## wide, so all that showed of the logo was a sliver through the middle. At
## 0.10 wide and +/-0.205 they sit on the pad's ends where the ropes enter and
## leave the face clear.
const CONNECTOR_TANGENT := 0.205

# --- The pad's artwork -------------------------------------------------------
## The AEW pad face, supplied by the project owner, on a flat quad sat just
## proud of each cushion's front.
##
## A DECAL rather than a mapping of the cushion itself. The pads are bevelled
## boxes built through `_beveled`, and `venue.py` gives anything that goes
## through it a planar world projection -- fine for tiling cloth, useless for
## landing one logo the right way up, once, on one face of twelve boxes. A quad
## with explicit UVs is the smaller and more controllable piece of work, and it
## leaves the cushion's rounded silhouette untouched.
const PAD_FACE_TEXTURE := "res://assets/environment/materials/turnbuckle_pad.png"
## Inset from the pad's full size by the bevel on each side, so the quad lands
## on the FLAT part of the front and not on the rounding, where it would float
## off the surface.
##
## Written as literals rather than as `TURNBUCKLE_PAD_WIDTH - 2 * BEVEL`,
## which is what they are: `tools/blender/venue.py` parses its constants out of
## this file and takes plain numbers only, so an expression here stops the ring
## exporting at all. `test_the_pad_face_is_inset_by_the_bevel` holds the two
## ends together instead.
const PAD_FACE_WIDTH := 0.43
const PAD_FACE_HEIGHT := 0.15
## Clear of the cushion's face, to keep the two out of a depth fight.
const PAD_FACE_LIFT := 0.004
## The artwork is 1774x887 -- exactly 2:1 -- and the flat face is 2.867:1, so
## mapping the whole image onto it would stretch the mark sideways by 43%.
## Sampling the middle 0.6977 of the HEIGHT gives a region of the same aspect
## as the quad, and what it crops is the black margin above and below the
## letters rather than any of the mark.
const PAD_FACE_V_SPAN := 0.6977

# --- Posts -------------------------------------------------------------------
## SQUARE, not round. The reference's posts are flat-faced dark slabs, and they
## are axis-aligned to the ring sides rather than turned to the diagonal -- the
## flat face reads straight down the camera's line on a side-on shot, which is
## most of the shotlist. The outgoing cylinder, its steel cap and the lace
## collar under the pad all go with the pad they were dressed for.
const POST_SECTION := 0.155
const POST_BOTTOM := -0.10
## 1.78 in the training-hall reference, where a bare post stands well clear of
## the top rope and that vertical line is the whole of the corner. A padded
## corner is the other way round: in the AEW references the CUSHION crowns the
## post, and the cap plate shows just above the top pad rather than towering
## over it. 1.42 puts the plate 0.10 above the top pad's top edge (top rope
## 1.20 + half a 0.24 pad), which is what the photographs show.
const POST_TOP := 1.58

# --- Apron -------------------------------------------------------------------
const APRON_OUT := 3.20
## The padded roll along the apron's outer edge.
##
## The edge used to be a flat 0.2m band in dark neutral grey, described as "the
## shadowed lip between a white mat and a dark skirt". The reference has no
## such lip: the apron edge is a fat padded bolster, the skirt's own vinyl
## wraps over it, and the corner chevron runs up the skirt and across it.
## Flat and dark, it read as a hard black line drawn round the ring.
##
## The axis sits one radius inboard of APRON_OUT so the roll's widest point is
## flush with the skirt plane and its crown stands above the skirt's top edge.
const APRON_ROLL_RADIUS := 0.10
const APRON_ROLL_AXIS := APRON_OUT - APRON_ROLL_RADIUS
## Arc segments over the half-round. Six is where the crown highlight stops
## reading as facets at `ring_corner`, the closest shot in the list.
const APRON_ROLL_STEPS := 6
## How much of the banner's height the roll takes. The skirt below starts from
## the top of the graphic too, so this is a small overlap rather than a split:
## the top of the artwork is near-uniform field either side of the chevrons, so
## what carries across the seam is the COLOUR, which is the thing the eye
## follows round a corner.
const APRON_ROLL_V := 0.15
const APRON_BANNER := "res://assets/environment/materials/ring_apron_banner.png"
const APRON_TOP := -0.10
const APRON_BOTTOM := -1.00

# --- Steel steps -------------------------------------------------------------
## The steps stand at a CORNER, hard against a ring post, not halfway down a
## side. That is where they go: the regulation that governs them asks for
## "suitable steps for use of the contestants in their corners" (Virginia
## 18VAC120-40-415.1), and on television the two sets sit tight against a post
## with their top tread level with the apron, so a wrestler climbing them
## steps straight over the top rope beside the turnbuckle.
##
## Two sets, on DIAGONALLY opposite corners: +X beside the post at (+3, +3),
## -X beside the post at (-3, -3). Diagonal rather than both on one side so
## each half of the ring has a way in, and neither set stands in the entrance
## walkway down the middle of -Z.
##
## This is the gap left between the near edge of the steps and the post.
const STEP_POST_GAP := 0.10
const STEP_TREADS := 3
const STEP_WIDTH := 1.45
const STEP_RUN := 0.36
const STEP_TOP_Y := -0.14
const STEP_FLOOR_Y := -1.00

# --- Texture generation ------------------------------------------------------
const CANVAS_SIZE := 1024
## Canvas panels are sewn in strips. Five seams across 6m is a 1.2m panel,
## which is the width canvas is milled at. COVERAGE DECISION.
## Kept as the documented panel width even though nothing reads it any more:
## the canvas is milled at 1.2m and the next thing to model panels (a normal
## map, a subtle albedo shift, anything that is not a line) will want it. The
## SEAM_* profile constants that used to live here are gone with the seams.
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
## The supplied AEW canvas artwork, mapped 1:1 over the 6m mat.
##
## Surface 0 of the floor mesh already carries a full 0..1 UV across the square
## precisely so a canvas lands in world space rather than tiling, which is what
## lets this drop straight on with no scaling.
##
## It is DARKER than what it replaces and that is the point: the field reads
## 0.636 in sRGB against CANVAS_WHITE's 0.975. The mat is an exposure anchor
## (VISUAL_BAR.md, and the round that solved ring exposure to a reference
## 0.46), so this moves a measured number -- see the round note in README.
const CANVAS_ART := "res://assets/environment/materials/ring_canvas.png"
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
	_build_model()


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
	# The supplied canvas artwork if it is there, the generated weave if not.
	#
	# The generated texture does not go away: it still drives ROUGHNESS and the
	# NORMAL below, which is where most of its value was. What it stops doing
	# is standing in for a canvas nobody had -- the mark it used to draw was
	# removed entirely when refs/ring.md called for an unbranded mat, leaving
	# albedo carrying weave and wear on a blank field.
	var art: Texture2D = load(CANVAS_ART) if ResourceLoader.exists(CANVAS_ART) else null
	m.albedo_texture = art if art != null else _canvas()
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

	# Surface 1: the flat apron strip between the mat edge and the roll.
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var basis_dir: Vector3 = _SIDE_DIRS[side]
		var tangent := Vector3(basis_dir.z, 0, -basis_dir.x)
		var inner: float = MAT_HALF
		var outer: float = APRON_ROLL_AXIS
		# Wound from -tangent to +tangent: the other way round the normals
		# come out pointing at the floor and the strip renders as nothing at
		# all, which is exactly what the first attempt did.
		_quad(walk,
			basis_dir * inner - tangent * APRON_OUT + Vector3(0, MAT_TOP_LOCAL, 0),
			basis_dir * outer - tangent * APRON_OUT + Vector3(0, MAT_TOP_LOCAL, 0),
			basis_dir * outer + tangent * APRON_OUT + Vector3(0, MAT_TOP_LOCAL, 0),
			basis_dir * inner + tangent * APRON_OUT + Vector3(0, MAT_TOP_LOCAL, 0),
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 4), Vector2(0, 4))
	walk.generate_tangents()
	walk.commit(mesh)

	# Surface 2: the padded roll the apron edge actually is.
	var roll := SurfaceTool.new()
	roll.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var basis_dir: Vector3 = _SIDE_DIRS[side]
		var tangent := Vector3(basis_dir.z, 0, -basis_dir.x)
		for step: int in range(APRON_ROLL_STEPS):
			var t0 := float(step) / float(APRON_ROLL_STEPS)
			var t1 := float(step + 1) / float(APRON_ROLL_STEPS)
			var p0 := _roll_point(basis_dir, t0)
			var p1 := _roll_point(basis_dir, t1)
			# u runs 0..1 along the side so the banner's chevrons land on the
			# corners, exactly as they do on the skirt below.
			_quad(roll,
				p0 - tangent * APRON_OUT, p1 - tangent * APRON_OUT,
				p1 + tangent * APRON_OUT, p0 + tangent * APRON_OUT,
				Vector2(0, t0 * APRON_ROLL_V), Vector2(0, t1 * APRON_ROLL_V),
				Vector2(1, t1 * APRON_ROLL_V), Vector2(1, t0 * APRON_ROLL_V))
	roll.generate_tangents()
	roll.commit(mesh)

	floor_mesh.mesh = mesh
	floor_mesh.set_surface_override_material(0, _canvas_material())
	# The apron a wrestler stands on outside the ropes: the same light cloth as
	# the mat, not the dark lip that used to stand in for it.
	floor_mesh.set_surface_override_material(1, _resolve("ring_apron",
		_mat(Color(0.52, 0.52, 0.53), 0.9), {"tint": Color(0.52, 0.52, 0.53)}))
	floor_mesh.set_surface_override_material(2, _apron_banner_material())


## The four side directions, outward. Shared by the apron strip and the roll so
## the two cannot disagree about which way a side faces.
const _SIDE_DIRS := [Vector3(0, 0, 1), Vector3(1, 0, 0),
	Vector3(0, 0, -1), Vector3(-1, 0, 0)]


## A point on the apron roll's arc, `t` running 0 (inboard, level with the mat)
## to 1 (underneath, where the skirt takes over).
##
## The arc is a half-round of radius APRON_ROLL_RADIUS about an axis set back
## from the skirt plane by exactly that radius, so the roll's widest point
## lands flush on APRON_OUT. That is what makes it read: the bulge stands proud
## of the skirt's top edge and catches the light along its crown, which is the
## single thing that tells a padded apron edge from a folded one.
func _roll_point(basis_dir: Vector3, t: float) -> Vector3:
	var angle := t * PI
	return basis_dir * (APRON_ROLL_AXIS + APRON_ROLL_RADIUS * sin(angle)) \
		+ Vector3(0, MAT_TOP_LOCAL - APRON_ROLL_RADIUS
			+ APRON_ROLL_RADIUS * cos(angle), 0)


## The AEW artwork on the front of each turnbuckle pad.
##
## Unshaded it is not -- a pad is vinyl and takes the ring light like the
## cushion behind it -- but it is NOT the library's `ring_turnbuckle_pad`
## either: that key carries a fabric normal map at a 0.30m tile, which at this
## size would crawl a weave across the letterforms.
func _pad_face_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = load(PAD_FACE_TEXTURE)
	if tex != null:
		mat.albedo_texture = tex
	mat.texture_repeat = false
	mat.roughness = 0.68
	mat.metallic = 0.0
	# Two-sided, and this is the fix for a failure venue.py's own `finish`
	# warns about: `recalc_face_normals` finds the outside of a closed solid,
	# but an OPEN SHEET has no outside, so it picks an arbitrary direction and
	# a sheet facing the wrong way renders as nothing at all. Its `face_toward`
	# escape hatch takes one direction per part and these twelve quads face
	# four different diagonals, whose normals sum to nothing. Culling off makes
	# the winding irrelevant, which for a flat decal costs nothing.
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


## The apron banner, on the roll, so the graphic runs over the edge instead of
## stopping at it.
##
## In the reference the chevron at the corner comes up the skirt, over the roll
## and dies at the apron floor -- the roll is the same piece of printed vinyl,
## not a separate trim. Mapping u 0..1 per side puts the graphic's chevron ends
## on the corners here for the same reason it does on the skirt.
func _apron_banner_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex: Texture2D = load(APRON_BANNER)
	if tex != null:
		mat.albedo_texture = tex
	mat.texture_repeat = false
	mat.roughness = 0.9
	mat.metallic = 0.0
	return mat


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

			# NO PANEL SEAMS. The mat is unbroken.
			#
			# Three versions of this existed. Round 4 ruled them as two hard
			# steps -- a flat -0.26 trench beside a flat +0.060 lip -- to buy
			# back the coarse detail the deleted centre mark had been
			# carrying. On a near-white canvas that is five black lines ruled
			# across the biggest surface in the frame, and it was reported as
			# exactly that from the deployed build. The next version softened
			# them to a feathered 0.10 dip, which reads as a real sewn seam.
			#
			# They are gone entirely now because the project owner asked for a
			# mat with no lines on it, having seen the softened version. That
			# is a look decision and it overrides the measurement the seams
			# were serving; the cost is booked in README rather than argued
			# with.
			#
			# What still carries the mat: the weave, the wear noise, the
			# streak fields and the centre traffic darkening, all above. Those
			# are the only incident left, and if coarse detail ever has to be
			# recovered it has to come from them -- NOT from putting lines
			# back.

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

## The ring's steel and rope is `tools/blender/ring.py`'s model.
##
## It was four SurfaceTool generators here: the ropes, the posts and their
## terminations, the apron frame and the steps. They are one committed `.glb`
## now, for the reasons that file records -- bevelled arrises that catch the
## house rig, round turnbuckle sleeves instead of boxes, and stringers holding
## the steel steps together as one object. Every dimension still comes from
## the constants above; `tools/blender/ring.py` reads them out of this file
## rather than retyping them, so the two cannot drift.
##
## What did NOT move: the canvas (`_build_canvas`, two quads carrying a
## generated texture at a node path the capture harness keys off), every
## collider in `scenes/ring.tscn`, and every material below.
const RING_MODEL := "res://assets/environment/ring.glb"

## Part name in the .glb -> the material that dresses it. Same split as
## before: the steps get `ring_steps` rather than the apron's `ring_steel`,
## because in the reference they are bare metal and the second-brightest
## surface in the frame, and brightening `ring_steel` would have brightened
## the apron rail into the strip of frame that has to stay dark.
func _model_materials() -> Dictionary:
	return {
		"PostMesh": _resolve("ring_post", _mat(Color(0.075, 0.075, 0.080), 0.94)),
		"TurnbuckleFittings": _resolve("ring_post", _mat(Color(0.11, 0.11, 0.115), 0.42)),
		# Vinyl, not steel: a pad is a soft cover and takes a broad dull
		# sheen, where the fittings behind it take a tight specular one.
		"TurnbucklePads": _resolve("ring_turnbuckle_pad",
			_mat(Color(0.055, 0.055, 0.060), 0.62)),
		# The connector plates take the STEPS' bare steel rather than the
		# post's paint: they are the one bright thing at a corner and the
		# whole reason they are modelled.
		"TurnbuckleConnectors": _bare_steel(),
		"TurnbuckleFaces": _pad_face_material(),
		"RopeMesh": _rope_material(),
		"ApronRail": _resolve("ring_apron", _mat(Color(0.105, 0.105, 0.112), 0.85),
			{"tint": Color(0.105, 0.105, 0.112)}),
		"StepsMesh": _bare_steel(),
	}


func _build_model() -> void:
	var holder := _replace("RingModel")
	var packed: PackedScene = load(RING_MODEL)
	if packed == null:
		push_error("RingBuilder: %s failed to load. Run tools/blender/build_venue.sh ring."
			% RING_MODEL)
		return
	var root: Node3D = packed.instantiate()
	root.name = "RingMeshes"
	holder.add_child(root)
	var materials := _model_materials()
	for part: String in materials:
		var node := root.find_child(part, true, false) as MeshInstance3D
		if node == null:
			push_error("RingBuilder: %s has no '%s' object." % [RING_MODEL, part])
			continue
		node.material_override = materials[part]


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


## _quad survives the move to Blender because `_build_canvas` still uses
## it: the canvas is the one ring surface this file still generates.
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
