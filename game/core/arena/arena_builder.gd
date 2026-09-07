extends Node3D
class_name ArenaBuilder
## Builds the hall around the ring: a raked seating bowl, its crowd, the
## entrance stage, the overhead truss, and the shell (walls, roof, floor).
##
## Why this is generated rather than authored in the .tscn, and why it is not
## a downloaded arena model, are both deliberate:
##
## - A twenty-row raked bowl with a few thousand seats is not hand-typeable as
##   transforms. Expressed as the dozen numbers below it is reviewable and
##   tunable; expressed as a .tscn it would be transform soup nobody can check.
## - No CC0 wrestling arena exists to download. The ones that do exist are
##   branded (extracted game assets or trademarked trade dress), and none is
##   an arena *bowl* -- they are all rings, which scenes/ring.tscn already
##   has. See assets/environment/CREDITS.md.
##
## Everything here is cosmetic. Nothing in this file creates a
## CollisionObject3D, joins a physics layer, or is read by gameplay: the ring's
## own colliders in ring.tscn remain the only bodies the match touches. The
## crowd's idle motion is a vertex shader, so it runs on the render thread and
## cannot reach MatchReferee.compute_end_state_hash(). ARCHITECTURE.md permits
## cosmetic motion on exactly that condition.
##
## Placement is seeded (CROWD_SEED), so the same build produces the same
## arena every run and captures stay comparable between rounds.

# --- The ring this hall is built around -------------------------------------
# Read, never written. ring.tscn's mat is 6m square with the ropes at 3.1m,
# and camera.md derives the 41-degree lens from that 3.1m figure -- so these
# are the one set of numbers here that may not be changed to suit the arena.
const RING_HALF_EXTENT := 3.3
## Arena floor level, matching ring.tscn's own ArenaFloor before it moved here.
## The mat sits ~1.1m above it, which is what gives the apron something to be.
const FLOOR_Y := -1.1

# --- Ringside ---------------------------------------------------------------
## Barricade line. Everything between the ring and this is open ringside floor.
const BARRICADE_RADIUS := 9.0
const BARRICADE_HEIGHT := 1.1
## The barricade is a RUN OF PANELS, not one long wall, because that is what
## gauntlet/refs/ring.md shows and because the joins are the only thing giving
## a 36m band of geometry any scale. Each panel is this wide, with a visible
## gap at each join and a leg raking outward behind it.
const BARRICADE_PANEL := 2.4
const BARRICADE_JOIN := 0.05

## Floor panel seams. The reference's ringside floor is a poured slab scored
## into large panels, and those lines are most of what stops it reading as one
## flat grey field from the wide camera -- which is coarse detail, on the
## second-largest surface in the frame after the mat.
const FLOOR_SEAM_PITCH := 4.0
const FLOOR_SEAM_WIDTH := 0.05

# --- Seating bowl -----------------------------------------------------------
## Row geometry. RUN is tread depth, RISE is step height; a real bowl rakes at
## roughly 27 degrees and 0.48/0.95 gives that. Not a reference measurement --
## gauntlet/refs/ measures nothing about seating rake -- so this is an
## engineering value and is not defended as "how it should look".
const ROW_RUN := 0.95
const ROW_RISE := 0.48
const LOWER_ROWS := 12
const UPPER_ROWS := 8
## How many of LOWER_ROWS sit FLAT on the ringside slab rather than raking, and
## carry folding chairs rather than spectators.
##
## This is the ringside of gauntlet/refs/ring.md: rows of empty black folding
## chairs on the flat floor behind the barricade, with the raked bowl starting
## behind them. They are taken off the front of the lower tier rather than
## added in front of it, so the bowl's overall footprint, the concourse and
## the upper tier are all where they were.
const FLAT_CHAIR_ROWS := 4
## Walkway between the two tiers.
const CONCOURSE_DEPTH := 2.6

# --- Entrance stage ---------------------------------------------------------
## The stage occupies the -Z wedge. The default match camera sits off-axis
## on -X/+Z facing it, so the stage reads frame-left in the money shot with
## the crowd at frame center -- both halves of the hall earn their polygons,
## the stage via stage_wide/entrance framings as well as the broadcast edge.
const STAGE_HALF_WIDTH := 6.0
const STAGE_DECK_Y := 0.35
const STAGE_BACK := -24.0
## The ramp runs from the stage lip to the barricade line, descending to floor.
const RAMP_HALF_WIDTH := 1.8

# --- Video wall -------------------------------------------------------------
## Chord width and height of the LED wall, 3:1, off the reference photos in
## `gauntlet/refs/stage.md`. The flat 14 x 5.4 box this replaces was 2.6:1 and
## read as a monitor rather than as a wall.
const SCREEN_WIDTH := 18.0
const SCREEN_HEIGHT := 6.0
## How far the centre of the wall sits behind its ends. 1.6m over 18m is about
## five degrees of toe-in per end -- the reference's wall is gently wrapped,
## not a cylinder, and past roughly 2.5m the ends start to occlude their own
## picture from the broadcast angle.
const SCREEN_SAGITTA := 1.6
## 24 facets is 0.75m each. A facet's chord deviates from the true arc by
## (0.375^2) / (2 * 26.11) = 2.7mm, which is under a pixel at the distance
## CaptureHarness's `stage_wide` shot sees the wall from.
const SCREEN_SEGMENTS := 24
const SCREEN_DEPTH := 0.45
const SCREEN_BEZEL := 0.22
const SCREEN_CENTER_Y := STAGE_DECK_Y + 9.0
const SCREEN_FACE_Z := STAGE_BACK + 1.1
## Linear luminance the wall reaches with nothing playing on it -- the clip
## missing, or a run that must not have a moving picture in it. Dark violet
## rather than the old flat pale blue, because an LED wall between cues is
## dark, and because `_self_emissive` divides by the albedo's linear
## luminance: a near-black panel asks for an absurd energy (this was 7.6 once,
## and blew the screen out).
const SCREEN_BLANK_EMISSION := 0.35

# --- Entrance portals -------------------------------------------------------
## The two lit rings the entrance comes out of. Outer edge lands at
## |x| = PORTAL_OFFSET_X + PORTAL_MAJOR + PORTAL_MINOR = 5.97, just inside
## STAGE_HALF_WIDTH, so the deck still reads as wider than the set dressed on
## it.
const PORTAL_MAJOR := 2.45
const PORTAL_MINOR := 0.22
const PORTAL_OFFSET_X := 3.3
const PORTAL_CENTER_Y := STAGE_DECK_Y + 2.9
const PORTAL_FACE_Z := STAGE_BACK + 1.3
const PORTAL_RING_SEGMENTS := 48
const PORTAL_TUBE_SIDES := 8
## Half-width of the gap at the bottom of the omega, in radians. 0.66 rad is
## 38 degrees either side of straight down, so the tube covers 284 degrees and
## the opening between the two feet is 3.0m -- wide enough to walk a wrestler
## and their entrance through, which is what the gap is for.
const PORTAL_GAP := 0.66
## How far outboard and how far down each foot splays from where the arc ends.
const PORTAL_FOOT_SPREAD := 0.95
const PORTAL_FOOT_Y := STAGE_DECK_Y + 0.18
const PORTAL_SLATS := 13
const PORTAL_RECESS_DEPTH := 3.2
## Linear luminance each ring is asked to reach on its own. Above the
## Environment's glow threshold (1.25) so the rings bloom, which is what makes
## them read as fixtures rather than as coloured decals.
##
## 1.55 was tried first and both rings clipped: the magenta went pink-white and
## the amber went flat yellow, which is the hue being destroyed by the level.
## 1.12 sits just under the threshold at the tube's centre and over it on the
## bloom the fixtures add, so the rings still flare without either of them
## losing the colour that tells the two apart.
const PORTAL_EMISSION := 1.12
## The slat fans inside each portal, well under the ring that frames them.
## Making the two the same level collapses the depth: the reference photos
## read as a lit ring in front of a lit recess, and that only works while the
## ring is clearly the brighter of the two.
##
## 0.34 read as a second light source competing with the ring. 0.26 is the
## version that reads as what it is -- fine strip fixtures picked out inside
## the portal, seen and not looked at.
const PORTAL_FAN_EMISSION := 0.26

# --- Shell ------------------------------------------------------------------
const WALL_EXTENT := 32.0
const WALL_TOP := 17.0
const ROOF_Y := 14.0
const TRUSS_Y := 7.6

# --- Crowd ------------------------------------------------------------------
## Distance between seats along a row.
@export var seat_pitch: float = 0.62
## Fraction of seats that are actually occupied. A sold-out bowl reads as a
## solid block; leaving gaps is what makes it read as people.
@export var crowd_fill: float = 0.86
## Fixed so the arena is identical every run.
const CROWD_SEED := 20260902

## Crowd shirt palette. Deliberately desaturated and dark: the reference
## frames' crowd sits at relative luminance 0.014 (VISUAL_BAR.md), so a bright
## crowd would not be closer to the reference, it would be further from it.
## What the crowd is for here is *variance*, not brightness.
const CROWD_COLORS: Array[Color] = [
	Color(0.20, 0.21, 0.26),
	Color(0.28, 0.24, 0.24),
	Color(0.17, 0.20, 0.24),
	Color(0.31, 0.29, 0.27),
	Color(0.22, 0.26, 0.28),
	Color(0.26, 0.22, 0.29),
	Color(0.15, 0.16, 0.19),
	Color(0.33, 0.31, 0.33),
]


var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = CROWD_SEED
	_build_floor()
	_build_barricades()
	_build_bowl()
	_build_stage()
	_build_truss()
	_build_shell()


# ---------------------------------------------------------------------------
# Materials
# ---------------------------------------------------------------------------

## Named materials come from core/materials/material_library.gd, which owns
## the full map set (albedo/normal/roughness/AO/metalness), the sRGB-vs-linear
## slotting, the PBR-correctness rules, and the texel density. This is the one
## line of adapter that keeps the hall's call sites reading as art direction.
##
## Every hall material is `house_lit` in the library, meaning it carries its
## albedo map as a multiplied emission map -- emission is unlit, so without
## that the maps below would be invisible no matter how good they are. The
## multiply darkens the mean, which is why each call site wraps `_house_lit()`
## in `MaterialLibrary.house_compensate()`: that divides the map's own mean
## back out of the emission energy, so the house *level* this file solves for
## is preserved and only its *variance* changes.
func _textured(key: String) -> StandardMaterial3D:
	return MaterialLibrary.resolve(key)


## Residual bounce, NOT the hall's lighting any more.
##
## This function used to make every arena surface self-emissive at a computed
## level, because the whole rig was four SpotLight3Ds with `spot_range 10` and
## the seating bowl starts at 9m -- nothing out in the hall was within reach of
## a light, so the hall lit itself. That worked on `gl_compatibility`, which is
## the renderer every number in this repo was measured on until yesterday. On
## `forward_plus`, which the game ships, the same compensation over-returned
## badly enough that the crowd was the brightest thing in the frame, against a
## reference whose crowd sits at relative luminance 0.014 (VISUAL_BAR.md).
##
## It also could not have satisfied VISUAL_BAR.md priority 2 in principle:
## emission has no falloff, casts no shadow, cuts no shaft and puts no rim on
## anything, so a hall lit by it reads as independently-lit props -- the exact
## failure the priority names.
##
## core/lighting/arena_lighting.gd now hangs real fixtures: ring key and top
## fill on the truss, a twelve-fixture house wash aimed outward onto the bowl,
## a cool rim pair, and a stage wash. What survives here is a floor, for the
## faces no fixture reaches (the backs of upper risers, the underside of the
## truss, the roof) -- so they stay dark rather than becoming void.
##
## The level is the one number here that is measured. measure_frame.py counts a
## pixel as void below 0.0025 relative luminance, and VISUAL_BAR.md requires
## void_fraction to stay in 0.010-0.066: an unreached face must sit ABOVE that
## floor, and comfortably, because a surface sitting exactly on it dithers
## across it and shows up as a speckled void mask. It must also sit far enough
## BELOW the reference crowd's 0.014 that a lit surface and an unreached one
## are visibly different, or the fixtures are decoration.
const HOUSE_TARGET := 0.006

## What the Environment's ambient is assumed to return off a diffuse surface,
## as a fraction of its linear albedo. Ambient is down from 0.35 to 0.06 (see
## match.tscn), so what it returns is now genuinely small and this stays
## conservative for the same reason it always did: ambient measures far lower
## on vertical faces than on up-facing treads, and over-crediting it puts the
## risers under the void floor while the treads sit on target.
const AMBIENT_RETURN := 0.05

## `reach` scales the floor for surfaces that should sit under or over it.
##
## The arithmetic is done in LINEAR light. Emission resolves as
## srgb_to_linear(albedo) * energy, so compensating with the *sRGB* luminance
## leaves dark albedos far short: at albedo 0.12 the stage backdrop rendered at
## 0.0026 linear against a 0.014 target while the bowl's 0.30 albedo landed on
## 0.017 -- same formula, six-fold different result, purely from the gamma
## curve.
func _house_lit(mat: StandardMaterial3D, reach: float = 1.0) -> StandardMaterial3D:
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	var albedo_linear := maxf(mat.albedo_color.srgb_to_linear().get_luminance(),
			0.0001)
	var wanted := HOUSE_TARGET * reach
	mat.emission_energy_multiplier = maxf(
			wanted / albedo_linear - AMBIENT_RETURN, 0.0)
	return mat


## For the things that genuinely emit. The video wall is the only one in the
## hall: it is a screen, so it is a light source whether or not a fixture is
## pointed at it, and retiring the house-emission mechanism must not retire it.
##
## `level` is the linear luminance the panel is asked to reach on its own,
## before any fixture reaches it -- above 1.0 so it crosses the Environment's
## glow threshold (1.05) and blooms, which is what a video wall does.
func _self_emissive(mat: StandardMaterial3D, level: float) -> StandardMaterial3D:
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	var albedo_linear := maxf(mat.albedo_color.srgb_to_linear().get_luminance(),
			0.0001)
	mat.emission_energy_multiplier = level / albedo_linear
	return mat


# ---------------------------------------------------------------------------
# Geometry helpers
# ---------------------------------------------------------------------------

## One axis-aligned box, with UVs taken from in-plane world coordinates so
## texel density stays constant no matter how big the box is. Boxes are solid
## and allowed to abut; interior faces are never seen.
static func _add_box(st: SurfaceTool, center: Vector3, size: Vector3) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3.UP, Vector3.RIGHT, Vector3.BACK],
		[Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.BACK, Vector3.RIGHT, Vector3.UP],
		[Vector3.FORWARD, Vector3.LEFT, Vector3.UP],
		[Vector3.RIGHT, Vector3.FORWARD, Vector3.UP],
		[Vector3.LEFT, Vector3.BACK, Vector3.UP],
	]
	for face: Array in faces:
		var normal: Vector3 = face[0]
		var u: Vector3 = face[1]
		var v: Vector3 = face[2]
		var origin := center + normal * (normal.abs() * h).length()
		var eu := u * (u.abs() * h).length()
		var ev := v * (v.abs() * h).length()
		var corners := [
			origin - eu - ev, origin + eu - ev,
			origin + eu + ev, origin - eu + ev,
		]
		var uvs: Array[Vector2] = []
		for c: Vector3 in corners:
			uvs.append(Vector2((c * u.abs()).length() * signf(c.dot(u)),
					(c * v.abs()).length() * signf(c.dot(v))))
		for tri: Array in [[0, 1, 2], [0, 2, 3]]:
			for i: int in tri:
				st.set_normal(normal)
				st.set_uv(uvs[i])
				st.add_vertex(corners[i])


## `_add_box` in the local frame of one side of the hall: `along` runs down the
## side, `out` points away from the ring, and `size` is (width, height, depth)
## in that frame. Both vectors are axis-aligned everywhere this is used, so it
## resolves to a permutation of `_add_box`'s size rather than a rotation --
## which is what keeps the world-metre UVs `_add_box` generates.
## One quad, given its four corners listed COUNTER-CLOCKWISE as seen from the
## side the normals point at, with a per-corner normal and UV.
##
## Every curved emitter below goes through this, because face winding is the
## way a correct-looking mesh renders as a hole onto whatever is behind it and
## the failure gives you nothing to look at. Godot's front faces are
## **clockwise** from the front -- `_add_box` already obeys that, though it
## does not say so: its UP face lists (-x,-z), (+x,-z), (+x,+z), which viewed
## from above (where -Z is screen-up) runs top-left, top-right, bottom-right.
##
## Listing corners counter-clockwise here and reversing once, in one place, is
## the version that stays correct: the caller writes the loop in the order the
## maths produces it, and nothing has to remember the convention twice.
##
## The video wall was invisible in the first render of this set for exactly
## this reason -- the geometry, the UVs and the material were all right, and
## the panel was being culled.
static func _add_quad(st: SurfaceTool, corners: Array) -> void:
	for tri: Array in [[0, 2, 1], [0, 3, 2]]:
		for k: int in tri:
			var vert: Array = corners[k]
			st.set_normal(vert[1])
			st.set_uv(vert[2])
			st.add_vertex(vert[0])


## Radius of the circle through a chord of half-width `half_chord` bowed by
## `sagitta` at its midpoint: R = (c^2 + s^2) / 2s.
##
## The video wall is specified by the two numbers anyone can read off a
## photograph -- how wide it is and how far its centre sits behind its ends --
## rather than by a radius, which is a number nobody can measure from a seat.
static func _arc_radius(half_chord: float, sagitta: float) -> float:
	return (half_chord * half_chord + sagitta * sagitta) / maxf(2.0 * sagitta, 0.0001)


## How far forward the arc has come at parameter angle `phi`, measured from
## the panel's centre. 0 at phi = 0, exactly `sagitta` at each end.
static func _arc_offset(phi: float, radius: float) -> float:
	return radius - radius * cos(phi)


## The sagitta a chord of half-width `half_chord` has on a circle of `radius`
## -- the inverse of `_arc_radius`.
##
## This is what makes the bezel CONCENTRIC with the picture it frames. Building
## both from the same sagitta looks right and is not: a wider chord bowed by
## the same amount is a *different circle*, the two arcs cross somewhere in the
## middle of the panel, and the frame surfaces through the picture. That showed
## up as two dark chevrons across the top of the wall in the first render of
## it. Same circle, different chord, and the frame stays behind the picture
## everywhere.
static func _sagitta_for(radius: float, half_chord: float) -> float:
	return radius - sqrt(maxf(radius * radius - half_chord * half_chord, 0.0))


## One concave panel bowed toward the audience, with NORMALISED UVs.
##
## This exists because `_add_box` cannot be used for it. That function lays
## UVs out in world metres so `tile_metres` keeps texel density constant, which
## is exactly right for a tiled hall surface and exactly wrong for anything
## carrying a picture: a video frame mapped in metres tiles eighteen times
## across an eighteen-metre wall. Here u runs 0..1 left to right *as the
## audience sees it* -- a viewer at +Z looking down -Z has +X on their right,
## so u = 0 is the -X end -- and v runs 0..1 top to bottom, which is image
## space, so a texture lands on the wall the way it looks in a file browser.
##
## Vertices sit at equal ANGLE rather than equal x, so u is proportional to
## arc length and a pixel of video is the same size at the ends as it is in
## the middle. The circle's centre is placed on the audience side of the
## panel, which is what makes the surface concave and not a barrel:
##
##     phi_i = -phi_max + 2 * phi_max * i / segments,  phi_max = asin(c / R)
##     p_i   = center + (R sin phi_i, +-height/2, R - R cos phi_i)
##     n_i   = (-sin phi_i, 0, cos phi_i)
##
## Only the front face is emitted. `_add_curved_shell` supplies the box behind
## it, so the two can wear different materials -- a picture and a bezel.
static func _add_curved_face(st: SurfaceTool, center: Vector3, width: float,
		height: float, sagitta: float, segments: int) -> void:
	var half_chord := width * 0.5
	var radius := _arc_radius(half_chord, sagitta)
	var phi_max := asin(clampf(half_chord / radius, -1.0, 1.0))
	var top := center.y + height * 0.5
	var bottom := center.y - height * 0.5
	for i: int in segments:
		var t0 := float(i) / float(segments)
		var t1 := float(i + 1) / float(segments)
		var phi0 := lerpf(-phi_max, phi_max, t0)
		var phi1 := lerpf(-phi_max, phi_max, t1)
		var x0 := center.x + radius * sin(phi0)
		var x1 := center.x + radius * sin(phi1)
		var z0 := center.z + _arc_offset(phi0, radius)
		var z1 := center.z + _arc_offset(phi1, radius)
		var n0 := Vector3(-sin(phi0), 0.0, cos(phi0))
		var n1 := Vector3(-sin(phi1), 0.0, cos(phi1))
		# Corners counter-clockwise as the audience sees them; `_add_quad`
		# owns the winding. Never fix an inside-out surface by flipping
		# cull_mode -- `cull_back` is a MaterialLibrary spec field, and
		# flipping it there flips it for every other caller of that key.
		_add_quad(st, [
			[Vector3(x0, bottom, z0), n0, Vector2(t0, 1.0)],
			[Vector3(x1, bottom, z1), n1, Vector2(t1, 1.0)],
			[Vector3(x1, top, z1), n1, Vector2(t1, 0.0)],
			[Vector3(x0, top, z0), n0, Vector2(t0, 0.0)],
		])


## The bezel that frames `_add_curved_face`: the same arc, `bezel` larger in
## both axes and pushed `depth` away from the audience, plus the four rim
## strips joining the two.
##
## Its UVs stay in world metres (u = arc length, v = height) because unlike
## the face it frames it wears an ordinary tiled library material.
static func _add_curved_shell(st: SurfaceTool, center: Vector3, width: float,
		height: float, sagitta: float, segments: int, depth: float,
		bezel: float) -> void:
	# The picture's circle, then this panel's chord on that same circle.
	var radius := _arc_radius(width * 0.5, sagitta)
	var half_chord := width * 0.5 + bezel
	var phi_max := asin(clampf(half_chord / radius, -1.0, 1.0))
	var top := center.y + height * 0.5 + bezel
	var bottom := center.y - height * 0.5 - bezel
	for i: int in segments:
		var phi0 := lerpf(-phi_max, phi_max, float(i) / float(segments))
		var phi1 := lerpf(-phi_max, phi_max, float(i + 1) / float(segments))
		# Front ring (the visible bezel, which the picture is inset into),
		# then the back panel, then the rims that join them.
		_arc_quad(st, center, radius, phi0, phi1, bottom, top, 0.0, true)
		_arc_quad(st, center, radius, phi0, phi1, bottom, top, -depth, false)
		_arc_rim(st, center, radius, phi0, phi1, top, depth, Vector3.UP)
		_arc_rim(st, center, radius, phi0, phi1, bottom, depth, Vector3.DOWN)


## One quad of the curved shell's face ring, at `z_shift` from the arc.
static func _arc_quad(st: SurfaceTool, center: Vector3, radius: float,
		phi0: float, phi1: float, lo: float, hi: float, z_shift: float,
		front: bool) -> void:
	var p := func(phi: float, y: float) -> Vector3:
		return Vector3(center.x + radius * sin(phi), y,
				center.z + _arc_offset(phi, radius) + z_shift)
	var n0 := Vector3(-sin(phi0), 0.0, cos(phi0)) * (1.0 if front else -1.0)
	var n1 := Vector3(-sin(phi1), 0.0, cos(phi1)) * (1.0 if front else -1.0)
	var arc0 := radius * phi0
	var arc1 := radius * phi1
	var corners := [
		[p.call(phi0, lo), n0, Vector2(arc0, lo)],
		[p.call(phi1, lo), n1, Vector2(arc1, lo)],
		[p.call(phi1, hi), n1, Vector2(arc1, hi)],
		[p.call(phi0, hi), n0, Vector2(arc0, hi)],
	]
	if not front:
		corners.reverse()
	_add_quad(st, corners)


## One quad of the horizontal rim joining the shell's front arc to its back.
static func _arc_rim(st: SurfaceTool, center: Vector3, radius: float,
		phi0: float, phi1: float, y: float, depth: float,
		normal: Vector3) -> void:
	var p := func(phi: float, z_shift: float) -> Vector3:
		return Vector3(center.x + radius * sin(phi), y,
				center.z + _arc_offset(phi, radius) + z_shift)
	var arc0 := radius * phi0
	var arc1 := radius * phi1
	var corners := [
		[p.call(phi0, 0.0), normal, Vector2(arc0, 0.0)],
		[p.call(phi1, 0.0), normal, Vector2(arc1, 0.0)],
		[p.call(phi1, -depth), normal, Vector2(arc1, -depth)],
		[p.call(phi0, -depth), normal, Vector2(arc0, -depth)],
	]
	if normal.y > 0.0:
		corners.reverse()
	_add_quad(st, corners)


## An arc of tube lying in the XY plane, facing +Z -- the body of an entrance
## portal.
##
## Swept between two angles rather than closed, because the reference portals
## are an OMEGA, not a ring: the tube arches over the top, comes down both
## sides, and stops short of the bottom, leaving the gap the entrance actually
## walks out of. A closed circle reads as a neon hoop hung on a wall, which is
## a different piece of set entirely.
##
##     p(theta, phi) = C + (major + minor cos phi) (cos theta, sin theta, 0)
##                       + (0, 0, minor sin phi)
##     n(theta, phi) = cos phi (cos theta, sin theta, 0) + (0, 0, sin phi)
##
## UVs are (theta / TAU, phi / TAU) so a tiled material would wrap the tube
## rather than smear along it. Nothing tiled wears one today; the next
## material might.
##
## `ring_segments` counts the whole circle, so a partial sweep uses its share
## and the facet size stays the same however much of the circle is drawn. 48
## over the full turn is roughly two pixels of facet at the distance
## CaptureHarness's `stage_wide` shot sees the portals from.
static func _add_arc_tube(st: SurfaceTool, center: Vector3, major: float,
		minor: float, from_angle: float, to_angle: float, ring_segments: int,
		tube_sides: int) -> void:
	var span := to_angle - from_angle
	var steps := maxi(int(ceil(absf(span) / TAU * float(ring_segments))), 1)
	var point := func(ti: int, pi: int) -> Array:
		var theta := from_angle + span * float(ti) / float(steps)
		var phi := TAU * float(pi) / float(tube_sides)
		var radial := Vector3(cos(theta), sin(theta), 0.0)
		var normal := radial * cos(phi) + Vector3(0.0, 0.0, sin(phi))
		var pos := center + radial * (major + minor * cos(phi)) \
				+ Vector3(0.0, 0.0, minor * sin(phi))
		return [pos, normal, Vector2(theta / TAU, float(pi) / float(tube_sides))]
	for ti: int in steps:
		for pi: int in tube_sides:
			_add_quad(st, [
				point.call(ti, pi + 1), point.call(ti + 1, pi + 1),
				point.call(ti + 1, pi), point.call(ti, pi),
			])


## A straight length of tube between two points -- the splayed foot each end
## of an omega drops to the deck on.
##
## Deliberately not tangential to the arc it continues. The tangent at the
## arc's end points down and *inward*, and the reference set's feet turn
## outward and plant wider than the arc: that flare is what stops the portal
## reading as a hoop someone cut a piece out of.
static func _add_tube_along(st: SurfaceTool, from: Vector3, to: Vector3,
		minor: float, sides: int) -> void:
	var axis := to - from
	if axis.length() < 0.0001:
		return
	var forward := axis.normalized()
	var up := Vector3.BACK if absf(forward.dot(Vector3.BACK)) < 0.9 else Vector3.UP
	var u := forward.cross(up).normalized()
	var v := forward.cross(u).normalized()
	var rim := func(base: Vector3, pi: int) -> Array:
		var phi := TAU * float(pi) / float(sides)
		var normal := u * cos(phi) + v * sin(phi)
		return [base + normal * minor, normal,
				Vector2(float(pi) / float(sides), base.distance_to(from))]
	for pi: int in sides:
		_add_quad(st, [
			rim.call(from, pi + 1), rim.call(to, pi + 1),
			rim.call(to, pi), rim.call(from, pi),
		])


## The radial slat fan inside a portal: `count` tapered planks swept between
## `from_angle` and `to_angle`.
##
## Each slat is a single two-sided quad rather than a solid plank. At the
## distance any shot in the list sees the stage from, the 5cm edge of a plank
## is under a pixel, so the eight triangles a box would cost buy nothing --
## and a fan is the one place in the hall where the count of things matters
## more than the thickness of each.
static func _add_fan(st: SurfaceTool, center: Vector3, inner: float,
		outer: float, count: int, half_inner: float, half_outer: float,
		from_angle: float, to_angle: float) -> void:
	for i: int in count:
		var t := (float(i) + 0.5) / float(count)
		var angle := lerpf(from_angle, to_angle, t)
		var dir := Vector3(cos(angle), sin(angle), 0.0)
		var side := Vector3(-sin(angle), cos(angle), 0.0)
		var a := center + dir * inner - side * half_inner
		var b := center + dir * inner + side * half_inner
		var c := center + dir * outer + side * half_outer
		var d := center + dir * outer - side * half_outer
		for normal: Vector3 in [Vector3.BACK, Vector3.FORWARD]:
			var corners := [
				[a, normal, Vector2(0.0, 0.0)], [b, normal, Vector2(1.0, 0.0)],
				[c, normal, Vector2(1.0, 1.0)], [d, normal, Vector2(0.0, 1.0)],
			]
			if normal.z < 0.0:
				corners.reverse()
			_add_quad(st, corners)


## The dark recess behind a portal: a drum running away from the audience
## with its normals pointing INWARD, so back-face culling keeps the inside
## visible and the outside -- which is buried in the backdrop -- costs
## nothing. Capped at the far end, because an uncapped tube is a hole onto
## the Environment background, and `measure_frame.py` scores that as void.
static func _add_tube(st: SurfaceTool, center: Vector3, radius: float,
		depth: float, segments: int) -> void:
	for i: int in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var d0 := Vector3(cos(a0), sin(a0), 0.0)
		var d1 := Vector3(cos(a1), sin(a1), 0.0)
		_add_quad(st, [
			[center + d0 * radius - Vector3(0.0, 0.0, depth), -d0,
					Vector2(a0 * radius, depth)],
			[center + d1 * radius - Vector3(0.0, 0.0, depth), -d1,
					Vector2(a1 * radius, depth)],
			[center + d1 * radius, -d1, Vector2(a1 * radius, 0.0)],
			[center + d0 * radius, -d0, Vector2(a0 * radius, 0.0)],
		])
	# The back wall of the recess.
	var cap := center - Vector3(0.0, 0.0, depth)
	for i: int in segments:
		var a0 := TAU * float(i) / float(segments)
		var a1 := TAU * float(i + 1) / float(segments)
		var p0 := cap + Vector3(cos(a0), sin(a0), 0.0) * radius
		var p1 := cap + Vector3(cos(a1), sin(a1), 0.0) * radius
		for vert: Vector3 in [cap, p1, p0]:
			st.set_normal(Vector3.BACK)
			st.set_uv(Vector2(vert.x, vert.y))
			st.add_vertex(vert)


static func _add_oriented(st: SurfaceTool, center: Vector3, along: Vector3,
		out: Vector3, size: Vector3) -> void:
	var world: Vector3 = along.abs() * size.x + Vector3.UP * size.y \
			+ out.abs() * size.z
	_add_box(st, center, world)


static func _mesh_instance(name: String, st: SurfaceTool,
		mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = st.commit()
	node.material_override = mat
	# The hall is a backdrop. Casting shadows from thousands of seats onto
	# nothing would cost fill rate no capture can spend.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _new_surface() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


# ---------------------------------------------------------------------------
# Floor, barricades
# ---------------------------------------------------------------------------

func _build_floor() -> void:
	var st := _new_surface()
	_add_box(st, Vector3(0.0, FLOOR_Y - 0.1, 0.0),
			Vector3(WALL_EXTENT * 2.0, 0.2, WALL_EXTENT * 2.0))
	add_child(_mesh_instance("Floor", st,
			MaterialLibrary.house_compensate(_house_lit(_textured("arena_floor"), 1.0))))
	_build_floor_seams()


## The scored panel lines in the ringside slab. Drawn as their own darker
## surface a hair above the floor rather than cut into it: a seam is 5cm wide
## and modelling it as a groove would need three faces where one flat strip is
## visually identical from every camera in the shotlist.
##
## `reach` is well under the floor's own, so a seam reads as a shadow line
## rather than as a painted marking -- which is the difference between a
## scored slab and a car park.
func _build_floor_seams() -> void:
	var st := _new_surface()
	var reach := BARRICADE_RADIUS + ROW_RUN * float(FLAT_CHAIR_ROWS) + 1.0
	var lines := int(reach / FLOOR_SEAM_PITCH)
	for i: int in range(-lines, lines + 1):
		var at := float(i) * FLOOR_SEAM_PITCH
		_add_box(st, Vector3(at, FLOOR_Y + 0.004, 0.0),
				Vector3(FLOOR_SEAM_WIDTH, 0.008, reach * 2.0))
		_add_box(st, Vector3(0.0, FLOOR_Y + 0.004, at),
				Vector3(reach * 2.0, 0.008, FLOOR_SEAM_WIDTH))
	add_child(_mesh_instance("FloorSeams", st,
			MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_floor"), 0.35))))


## Four runs of discrete panels, each with a capping rail along its top and a
## leg raking outward behind it. It was one continuous box per side, which from
## the wide camera is a featureless band with nothing in it to read scale off.
func _build_barricades() -> void:
	var st := _new_surface()
	var y := FLOOR_Y + BARRICADE_HEIGHT * 0.5
	var top := FLOOR_Y + BARRICADE_HEIGHT
	var span := BARRICADE_RADIUS * 2.0
	var panels := int(span / BARRICADE_PANEL)
	var pitch := span / float(panels)
	var width := pitch - BARRICADE_JOIN
	for side: int in range(4):
		# `out` points away from the ring, `along` runs down the barricade.
		var out: Vector3 = [Vector3(0, 0, 1), Vector3(0, 0, -1),
				Vector3(1, 0, 0), Vector3(-1, 0, 0)][side]
		var along := Vector3(out.z, 0.0, -out.x)
		var line: Vector3 = out * BARRICADE_RADIUS
		for i: int in range(panels):
			var t := (float(i) + 0.5) / float(panels) - 0.5
			var at: Vector3 = line + along * (t * span)
			_add_oriented(st, at + Vector3(0.0, y, 0.0), along, out,
					Vector3(width, BARRICADE_HEIGHT, 0.14))
			# The cap rail, proud of the panel on both faces.
			_add_oriented(st, at + Vector3(0.0, top - 0.035, 0.0), along, out,
					Vector3(width, 0.07, 0.20))
			# One leg per panel, behind it, raking out to the floor. Boxed
			# rather than angled: at ringside distance the leg is three pixels
			# wide and its silhouette is the whole of what it contributes.
			_add_oriented(st, at + out * 0.22
					+ Vector3(0.0, FLOOR_Y + BARRICADE_HEIGHT * 0.28, 0.0),
					along, out,
					Vector3(0.05, BARRICADE_HEIGHT * 0.56, 0.42))
	add_child(_mesh_instance("Barricades", st,
			MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_barricade"), 1.5))))


# ---------------------------------------------------------------------------
# Seating bowl
# ---------------------------------------------------------------------------

## Each row is a solid block spanning from the bowl floor up to its own tread
## height, so the stack reads as a staircase with no gaps to fall through and
## no hidden faces to z-fight. The -Z side is split around the stage opening.
func _build_bowl() -> void:
	var steps := _new_surface()
	var seats: Array[Transform3D] = []
	var colors: Array[Color] = []
	var chairs: Array[Transform3D] = []
	var chair_colors: Array[Color] = []

	var inner := BARRICADE_RADIUS
	var tread_y := FLOOR_Y
	for tier: int in [0, 1]:
		var rows: int = LOWER_ROWS if tier == 0 else UPPER_ROWS
		if tier == 1:
			inner += CONCOURSE_DEPTH
			_add_concourse(steps, inner - CONCOURSE_DEPTH, inner, tread_y)
		for r: int in rows:
			var outer := inner + ROW_RUN
			# The first rows of the lower tier stay on the slab. _add_row is
			# still called and still no-ops on zero height, so the flat rows
			# cost no geometry -- the floor already under them is the tread.
			var flat := tier == 0 and r < FLAT_CHAIR_ROWS
			if not flat:
				tread_y += ROW_RISE
			_add_row(steps, inner, outer, tread_y)
			if flat:
				_seat_row(inner, outer, tread_y, chairs, chair_colors, true)
			else:
				_seat_row(inner, outer, tread_y, seats, colors)
			inner = outer

	add_child(_mesh_instance("SeatingBowl", steps, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_bowl")))))
	add_child(_build_chairs(chairs))
	add_child(_build_crowd(seats, colors))


## Cut around the stage exactly as the seating rows are. Built uncut, the
## concourse closes the gap the rows leave and walls the entrance off -- a
## false-colour pass showed it as a solid block filling the centre of frame
## behind the ring, which is what was reading as void there.
func _add_concourse(st: SurfaceTool, inner: float, outer: float,
		y: float) -> void:
	_ring_band(st, inner, outer, FLOOR_Y, y, true)


func _add_row(st: SurfaceTool, inner: float, outer: float, y: float) -> void:
	_ring_band(st, inner, outer, FLOOR_Y, y, true)


## A square annulus between `inner` and `outer`, solid from `base_y` to
## `top_y`. Split around the stage on -Z when `cut_stage` is set.
func _ring_band(st: SurfaceTool, inner: float, outer: float, base_y: float,
		top_y: float, cut_stage: bool) -> void:
	var height := top_y - base_y
	if height <= 0.0:
		return
	var mid_y := (base_y + top_y) * 0.5
	var depth := outer - inner
	var mid_r := (inner + outer) * 0.5

	# +Z bank, full width.
	_add_box(st, Vector3(0.0, mid_y, mid_r),
			Vector3(outer * 2.0, height, depth))
	# -Z bank, split around the entrance stage.
	if cut_stage:
		var wing := (outer - STAGE_HALF_WIDTH) * 0.5
		if wing > 0.0:
			for sign: float in [1.0, -1.0]:
				_add_box(st,
						Vector3(sign * (STAGE_HALF_WIDTH + wing), mid_y, -mid_r),
						Vector3(wing * 2.0, height, depth))
	else:
		_add_box(st, Vector3(0.0, mid_y, -mid_r),
				Vector3(outer * 2.0, height, depth))
	# +X and -X banks, spanning only the gap the Z banks leave.
	for sign: float in [1.0, -1.0]:
		_add_box(st, Vector3(sign * mid_r, mid_y, 0.0),
				Vector3(depth, height, inner * 2.0))


## Seats along one row's tread, on whichever banks that row actually has.
##
## `neat` switches the run from a crowd to a rank of empty chairs: every
## position filled, near-square, no size variance. An unoccupied row is set
## out in a grid and a crowd never is, and the difference is most of what
## tells the two apart at this distance.
func _seat_row(inner: float, outer: float, y: float,
		out_seats: Array[Transform3D], out_colors: Array[Color],
		neat: bool = false) -> void:
	var seat_r := inner + (outer - inner) * 0.45
	# +Z bank faces -Z, and so on: every seat looks at the ring.
	_seat_run(Vector3(-outer, y, seat_r), Vector3(outer, y, seat_r), PI,
			out_seats, out_colors, 0.0, neat)
	_seat_run(Vector3(-inner, y, -seat_r), Vector3(inner, y, -seat_r), 0.0,
			out_seats, out_colors, STAGE_HALF_WIDTH, neat)
	_seat_run(Vector3(seat_r, y, -inner), Vector3(seat_r, y, inner), -PI * 0.5,
			out_seats, out_colors, 0.0, neat)
	_seat_run(Vector3(-seat_r, y, -inner), Vector3(-seat_r, y, inner), PI * 0.5,
			out_seats, out_colors, 0.0, neat)


func _seat_run(from: Vector3, to: Vector3, facing: float,
		out_seats: Array[Transform3D], out_colors: Array[Color],
		skip_abs_x: float = 0.0, neat: bool = false) -> void:
	var span := from.distance_to(to)
	var count := int(span / seat_pitch)
	if count <= 0:
		return
	var fill := 1.0 if neat else crowd_fill
	var wobble := 0.012 if neat else 0.06
	var yaw := 0.035 if neat else 0.25
	for i: int in count:
		var t := (float(i) + 0.5) / float(count)
		var at := from.lerp(to, t)
		if skip_abs_x > 0.0 and absf(at.x) < skip_abs_x:
			continue
		if _rng.randf() > fill:
			continue
		var jitter := Vector3(_rng.randf_range(-wobble, wobble), 0.0,
				_rng.randf_range(-wobble, wobble))
		var basis := Basis(Vector3.UP, facing + _rng.randf_range(-yaw, yaw))
		if not neat:
			basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.9, 1.08))
		out_seats.append(Transform3D(basis, at + jitter))
		out_colors.append(CROWD_COLORS[_rng.randi() % CROWD_COLORS.size()])


# ---------------------------------------------------------------------------
# Ringside chairs
# ---------------------------------------------------------------------------

## The empty folding chairs on the flat rows behind the barricade.
##
## Its own MultiMesh rather than a second colour on the crowd's, for one
## non-negotiable reason: `_crowd_material()` is a vertex shader that bobs
## every instance it is applied to, and a breathing chair is worse than no
## chair at all. This takes a plain material and does not move.
func _build_chairs(chairs: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _chair_mesh()
	mm.instance_count = chairs.size()
	for i: int in chairs.size():
		mm.set_instance_transform(i, chairs[i])

	var node := MultiMeshInstance3D.new()
	node.name = "RingsideChairs"
	node.multimesh = mm
	# `reach` is high for a hall surface. Ringside is nearly the only part of
	# the frame gauntlet/refs/ring.md shows lit at all -- its chairs read
	# clearly against a grey floor -- and at the 0.55 this started on they were
	# indistinguishable from the black under the ring. The headroom to do it
	# is measured: wide_broadcast reads void_fraction 0.026 against
	# VISUAL_BAR.md's 0.010-0.066, and brightening ringside spends that
	# downward. Re-measure after touching this; the floor is what voids a
	# round, not the ceiling.
	node.material_override = MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_chair"), 2.5))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## The chair, baked once.
##
## The source is an imported FBX, and it arrives with its correction living in
## the node transforms above the mesh -- Blender exports Z-up at 1/100 scale,
## so Godot's importer parents the mesh under a scale-100, rotate-X--90 chain.
## A MultiMesh takes a bare Mesh and no hierarchy, so that chain is folded into
## the vertices here rather than repeated in every instance transform. Baked
## once and cached: `match.tscn` is built by several test suites and by every
## capture.
##
## The armature comes off in the same step. The rig exists so the chair can
## fold; nothing here ever folds one, and a skinned mesh cannot go into a
## MultiMesh regardless.
##
## What comes out is 1448 triangles, 0.50 x 0.90 x 0.60m, feet on y = 0, facing
## +Z -- which is already the facing convention `_seat_run` assumes, so no yaw
## correction is applied and none should be added.
const CHAIR_SCENE := "res://assets/environment/props/MetalFoldingChair.fbx"

static var _chair_cache: ArrayMesh


static func _chair_mesh() -> ArrayMesh:
	if _chair_cache != null:
		return _chair_cache
	var packed: PackedScene = load(CHAIR_SCENE)
	if packed == null:
		push_error("ArenaBuilder: %s failed to load." % CHAIR_SCENE)
		return _new_surface().commit()
	var root := packed.instantiate()
	var source: MeshInstance3D = root.find_child("MetalFoldingChair", true, false)
	if source == null or source.mesh == null:
		push_error("ArenaBuilder: no MetalFoldingChair mesh in %s." % CHAIR_SCENE)
		root.free()
		return _new_surface().commit()

	# Accumulate the transform the importer put above the mesh.
	var bake := Transform3D()
	var node := source as Node3D
	while node != null:
		bake = node.transform * bake
		node = node.get_parent() as Node3D

	var st := _new_surface()
	var normal_basis := bake.basis.inverse().transposed()
	for surface: int in source.mesh.get_surface_count():
		var arrays := source.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))
		for i: int in indices:
			if i < normals.size():
				st.set_normal((normal_basis * normals[i]).normalized())
			st.add_vertex(bake * vertices[i])
	root.free()
	_chair_cache = st.commit()
	return _chair_cache


# ---------------------------------------------------------------------------
# Crowd
# ---------------------------------------------------------------------------

## One MultiMesh for the whole bowl: a few thousand seated impostors in one
## draw call. They are impostors, not characters -- a torso and a head, no
## faces, no limbs. At bowl distance under the match lens what a crowd reads
## as is a broken-up silhouette with colour variance, and that is all this is
## claiming to be.
func _build_crowd(seats: Array[Transform3D],
		colors: Array[Color]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _spectator_mesh()
	mm.instance_count = seats.size()
	for i: int in seats.size():
		mm.set_instance_transform(i, seats[i])
		mm.set_instance_color(i, colors[i])

	var node := MultiMeshInstance3D.new()
	node.name = "Crowd"
	node.multimesh = mm
	node.material_override = _crowd_material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


static func _spectator_mesh() -> ArrayMesh:
	var st := _new_surface()
	_add_box(st, Vector3(0.0, 0.34, 0.0), Vector3(0.42, 0.58, 0.30))
	_add_box(st, Vector3(0.0, 0.74, 0.0), Vector3(0.21, 0.23, 0.21))
	return st.commit()


## The idle bob. This is a vertex shader on purpose: it runs on the render
## thread, reads only TIME and INSTANCE_ID, and writes nothing back, so it
## cannot feed into gameplay state or change a replay's end-state hash --
## which is the condition ARCHITECTURE.md puts on cosmetic motion.
func _crowd_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, shadows_disabled;

uniform float bob_amplitude = 0.045;
uniform float bob_speed = 1.6;
// Residual bounce only, down from 0.55. At 0.55 this term alone put the
// impostors at ~0.117 relative luminance -- brighter than the mat's own
// 0.172 on forward_plus, against a reference crowd of 0.014
// (VISUAL_BAR.md). The bowl is lit by real fixtures now
// (core/lighting/arena_lighting.gd), so the crowd's level comes from a
// light aimed at it; this is only the floor that keeps the back rows off
// measure_frame.py's 0.0025 void threshold.
uniform float house_light = 0.03;

varying vec3 seat_color;

void vertex() {
	seat_color = COLOR.rgb;
	// Golden-ratio phase spread: adjacent seats never bob together, and the
	// pattern never repeats along a row.
	float phase = fract(float(INSTANCE_ID) * 0.6180339887) * 6.2831853;
	VERTEX.y += (sin(TIME * bob_speed + phase) * 0.5 + 0.5) * bob_amplitude;
}

void fragment() {
	ALBEDO = seat_color;
	EMISSION = seat_color * house_light;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


# ---------------------------------------------------------------------------
# Entrance stage
# ---------------------------------------------------------------------------

## Deck, ramp to the ring, tunnel mouth, and a blank screen. The screen is
## deliberately blank: a logo there would be branding, and ARCHITECTURE.md
## scopes branding to original art this project does not have yet.
## The entrance set: deck and ramp, the perforated backdrop, two lit portals,
## and the curved video wall above them.
##
## Split into four because the old single function was already sixty lines of
## boxes and this is four distinct pieces of set, each with its own reference
## photograph and its own reasons.
func _build_stage() -> void:
	_build_stage_deck()
	_build_stage_backdrop()
	_build_entrance_portals()
	_build_stage_screen()


## The deck and the ramp down to floor level.
##
## Geometry unchanged from the grey-box version; what changed is underneath
## it. The deck is now a lacquered gloss (`arena_stage_deck`, roughness 0.14)
## and `match.tscn` turns on SSR, so this surface carries a reflection of the
## video wall and the two rings. That reflection is most of what makes the
## reference photos read as a stage.
##
## The house reach drops from 1.1 to 0.8 with it: house emission is added on
## top of the reflection, and a deck emitting at its old level washes out the
## thing it is now there to show.
func _build_stage_deck() -> void:
	var deck := _new_surface()
	var stage_front := -BARRICADE_RADIUS
	var deck_depth := stage_front - STAGE_BACK
	_add_box(deck, Vector3(0.0, (FLOOR_Y + STAGE_DECK_Y) * 0.5,
			(stage_front + STAGE_BACK) * 0.5),
			Vector3(STAGE_HALF_WIDTH * 2.0, STAGE_DECK_Y - FLOOR_Y, deck_depth))
	# Ramp: a short stack of steps rather than a wedge, because _add_box only
	# makes axis-aligned boxes and a visible staircase is honest grey-box.
	var steps := 6
	for i: int in steps:
		var t := float(i) / float(steps)
		var y := lerpf(STAGE_DECK_Y, FLOOR_Y, t)
		var z0 := lerpf(stage_front, -RING_HALF_EXTENT - 1.0, t)
		var z1 := lerpf(stage_front, -RING_HALF_EXTENT - 1.0,
				float(i + 1) / float(steps))
		_add_box(deck, Vector3(0.0, (FLOOR_Y + y) * 0.5, (z0 + z1) * 0.5),
				Vector3(RAMP_HALF_WIDTH * 2.0, y - FLOOR_Y, absf(z1 - z0)))
	add_child(_mesh_instance("EntranceStage", deck, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_stage_deck"), 0.8))))


## Backdrop behind the stage, at house level. Without it the portals are holes
## onto the Environment's background colour -- which measure_frame.py scores as
## void, and which measured as a quarter of the frame's middle band on the
## first capture. A portal has to be a recess in something, not an opening
## onto nothing.
##
## The material is now `arena_stage_panel` rather than poured concrete: the
## reference set's backdrop is a perforated panel wall, and at stage distance
## what carries that is a fine dark weave rather than a flat slab.
func _build_stage_backdrop() -> void:
	var backdrop := _new_surface()
	_add_box(backdrop, Vector3(0.0, (FLOOR_Y + WALL_TOP) * 0.5, STAGE_BACK - 0.4),
			Vector3(STAGE_HALF_WIDTH * 2.4, WALL_TOP - FLOOR_Y, 0.4))
	add_child(_mesh_instance("StageBackdrop", backdrop, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_stage_panel"), 2.6))))


## The two circular entrance portals: a dark recess, a radial slat fan in the
## lower half of it, and a lit ring standing proud of both.
##
## Depth order, back to front, is what makes a ring read as a fixture rather
## than as a painted circle: the recess is the darkest thing on the stage, the
## fan sits inside it lit only by the ring, and the ring is in front of both
## and is the only part that emits. Flattening any of those three onto the
## same plane collapses the whole effect.
##
## The rings are the magenta/amber pair from the reference photos. They are
## built as separate nodes rather than one surface so a later round can move,
## recolour or animate one without touching the other.
func _build_entrance_portals() -> void:
	var recess := _new_surface()
	for sx: float in [-1.0, 1.0]:
		_add_tube(recess, Vector3(sx * PORTAL_OFFSET_X, PORTAL_CENTER_Y,
				PORTAL_FACE_Z), PORTAL_MAJOR - PORTAL_MINOR * 0.5,
				PORTAL_RECESS_DEPTH, PORTAL_RING_SEGMENTS)
	add_child(_mesh_instance("PortalRecess", recess,
			MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_tunnel"), 0.35))))

	for side: Dictionary in [
		{"name": "West", "x": -1.0, "key": "arena_portal_magenta"},
		{"name": "East", "x": 1.0, "key": "arena_portal_amber"},
	]:
		var sx: float = side["x"]
		var at := Vector3(sx * PORTAL_OFFSET_X, PORTAL_CENTER_Y, PORTAL_FACE_Z)

		# The omega. Bottom of the circle is -PI/2; the sweep runs from just
		# past it, the long way round, to just short of it again.
		var ring := _new_surface()
		var from_angle := -PI * 0.5 + PORTAL_GAP
		var to_angle := from_angle + TAU - PORTAL_GAP * 2.0
		_add_arc_tube(ring, at, PORTAL_MAJOR, PORTAL_MINOR, from_angle,
				to_angle, PORTAL_RING_SEGMENTS, PORTAL_TUBE_SIDES)
		# A foot off each end, splayed outward and planted on the deck.
		for end_angle: float in [from_angle, to_angle]:
			var tip := at + Vector3(cos(end_angle), sin(end_angle), 0.0) * PORTAL_MAJOR
			var outward := signf(tip.x - at.x)
			_add_tube_along(ring, tip, Vector3(
					tip.x + outward * PORTAL_FOOT_SPREAD, PORTAL_FOOT_Y, tip.z),
					PORTAL_MINOR, PORTAL_TUBE_SIDES)
		add_child(_mesh_instance("PortalRing%s" % side["name"], ring,
				_self_emissive(MaterialLibrary.resolve(side["key"]),
				PORTAL_EMISSION)))

		# The slat fan, in that portal's own colour and lit -- these are strip
		# fixtures in the reference photographs, not dark slats catching the
		# ring's spill. They were built house-lit first and vanished: at hall
		# level, inside an unlit recess, there is nothing for them to catch.
		#
		# One wedge per portal, on its OUTBOARD side and clear of the gap the
		# entrance walks through. A full lower half would fill the doorway
		# with slats.
		var fan := _new_surface()
		var wedge_from := PI if sx < 0.0 else TAU - (PI * 0.5 - PORTAL_GAP)
		# Slat half-widths are what make a fan read as separate strips rather
		# than as a filled wedge: 13 slats across 52 degrees are 0.15m apart
		# at the outer radius, so anything over about 0.06 half-width closes
		# the gaps and the whole thing renders as one solid triangle. It did,
		# at 0.09.
		_add_fan(fan, at - Vector3(0.0, 0.0, 0.12), 0.55, 2.2, PORTAL_SLATS,
				0.012, 0.035, wedge_from, wedge_from + PI * 0.5 - PORTAL_GAP)
		add_child(_mesh_instance("PortalFan%s" % side["name"], fan,
				_self_emissive(MaterialLibrary.resolve(side["key"]),
				PORTAL_FAN_EMISSION)))


## The curved video wall, and the clip that plays on it.
##
## The panel is built with its own material first and only then handed to
## `StageVideo`. That ordering is the fallback: if the clip is missing, fails
## to decode, or the run is one that must not have a moving picture in it, the
## wall is already correct and nothing has to be undone.
##
## On the brightness. The flat panel this replaces was capped at a self-
## emissive level of 0.35, and the note on it recorded why: at 1.35 the screen
## owned the frame's top 5% of luminance (p95 0.633 against the reference
## still's 0.427) with 36.5% of the blown pixels inside the one grid cell it
## occupied. That measurement was taken of a *blank* panel whose whole area sat
## at one value. This wall carries a picture whose own mean is far below its
## peak, and the set it is now part of is matched to photographs in which the
## wall is plainly the brightest thing in the building. So the cap is
## deliberately revised upward here and re-measured rather than inherited --
## the numbers it was re-measured against are in README.md.
func _build_stage_screen() -> void:
	var bezel := _new_surface()
	_add_curved_shell(bezel, Vector3(0.0, SCREEN_CENTER_Y, SCREEN_FACE_Z - 0.06),
			SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_SAGITTA, SCREEN_SEGMENTS,
			SCREEN_DEPTH, SCREEN_BEZEL)
	add_child(_mesh_instance("StageScreenBezel", bezel,
			MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_tunnel"), 0.5))))

	var face := _new_surface()
	_add_curved_face(face, Vector3(0.0, SCREEN_CENTER_Y, SCREEN_FACE_Z),
			SCREEN_WIDTH, SCREEN_HEIGHT, SCREEN_SAGITTA, SCREEN_SEGMENTS)
	var screen_mat := MaterialLibrary.resolve("arena_screen")
	# The face carries normalised UVs, not world metres, so the texel-density
	# scale MaterialLibrary derived from `tile_metres` has to go. Miss this and
	# whatever lands on the wall tiles across it.
	screen_mat.uv1_scale = Vector3.ONE
	var screen := _mesh_instance("StageScreen", face,
			_self_emissive(screen_mat, SCREEN_BLANK_EMISSION))
	add_child(screen)
	add_child(StageVideo.attach(screen, screen_mat))


# ---------------------------------------------------------------------------
# Truss and shell
# ---------------------------------------------------------------------------

## A lighting grid above the ring. The roof alone left the camera's upper
## third a single flat emissive plane; this is what puts structure in it.
## It sits above the four SpotLight3Ds in match.tscn (y 5.5, range 10) so it
## neither occludes them nor changes how the mat is lit.
func _build_truss() -> void:
	var st := _new_surface()
	var reach := 11.0
	for offset: float in [-7.5, -2.5, 2.5, 7.5]:
		_add_box(st, Vector3(0.0, TRUSS_Y, offset),
				Vector3(reach * 2.0, 0.24, 0.24))
		_add_box(st, Vector3(offset, TRUSS_Y, 0.0),
				Vector3(0.24, 0.24, reach * 2.0))
	# Chords, so the grid reads as truss rather than as bare pipe.
	for offset: float in [-7.5, -2.5, 2.5, 7.5]:
		_add_box(st, Vector3(0.0, TRUSS_Y + 0.55, offset),
				Vector3(reach * 2.0, 0.14, 0.14))
		_add_box(st, Vector3(offset, TRUSS_Y + 0.55, 0.0),
				Vector3(0.14, 0.14, reach * 2.0))
	# Drops to the roof, so it hangs from something.
	for x: float in [-7.5, 7.5]:
		for z: float in [-7.5, 7.5]:
			_add_box(st, Vector3(x, (TRUSS_Y + ROOF_Y) * 0.5, z),
					Vector3(0.16, ROOF_Y - TRUSS_Y, 0.16))
	add_child(_mesh_instance("Truss", st, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_truss"), 0.9))))


func _build_shell() -> void:
	var st := _new_surface()
	var span := WALL_EXTENT * 2.0
	var mid_y := (FLOOR_Y + WALL_TOP) * 0.5
	var height := WALL_TOP - FLOOR_Y
	for sign: float in [1.0, -1.0]:
		_add_box(st, Vector3(0.0, mid_y, WALL_EXTENT * sign),
				Vector3(span, height, 0.4))
		_add_box(st, Vector3(WALL_EXTENT * sign, mid_y, 0.0),
				Vector3(0.4, height, span))
	_add_box(st, Vector3(0.0, ROOF_Y, 0.0), Vector3(span, 0.4, span))
	add_child(_mesh_instance("Shell", st, MaterialLibrary.house_compensate(
			_house_lit(_textured("arena_shell"), 0.85))))
