extends Node3D
class_name ArenaBuilder
## Builds the hall around the ring: the floor and barricades, the floor
## seating, the entrance stage with its ramp and video wall, the overhead
## truss -- and instances the rink, seating bowl and shell, which are a model.
##
## The hall is dimensioned from a REGULATION ICE RINK (see "The rink" below
## and `gauntlet/refs/arena.md`): 60.96 x 25.91m with 8.53m corners, with the
## ring in the middle of it, the boards where a rink's boards are, and the
## seating bowl starting a walkway outside them. Everything that is not the
## ring is measured out from that sheet of ice.
##
## The hall is EMPTY. There is no crowd in it, by decision rather than by
## omission: the seats are the seating now -- ~6,700 in the bowl, modelled one
## at a time, and ~1,490 folding chairs on the rink floor. An empty arena is a thing a wrestling build is
## routinely shot in -- an empty-arena match, a taping-day walkthrough -- and
## it is what `gauntlet/refs/arena.md`'s reference photographs are of.
## Removing the impostors took the only animated geometry in the hall with
## them; see the cosmetic-motion note below.
##
## Why none of this is authored in the .tscn, and why none of it is a
## downloaded arena, are both still deliberate:
##
## - A twenty-row raked bowl with a few thousand seats is not hand-typeable as
##   transforms. Expressed as the dozen numbers below it is reviewable and
##   tunable; expressed as a .tscn it would be transform soup nobody can check.
## - No CC0 wrestling arena exists to download. The ones that do exist are
##   branded (extracted game assets or trademarked trade dress), and none is
##   an arena *bowl* -- they are all rings, which scenes/ring.tscn already
##   has. See assets/environment/CREDITS.md.
##
## What changed, and what it bought
## --------------------------------
## The bowl and the shell are no longer generated here from axis-aligned
## boxes. They are `assets/environment/arena_bowl.glb`, built by
## `tools/blender/arena_bowl.py` -- our own model, from our own numbers, not a
## downloaded one, so the second point above is untouched.
##
## They moved because `gauntlet/refs/arena.md` records what the hall has to be:
## an ice-hockey arena, whose bowl is an OBROUND -- two straight sides joined
## by semicircular ends -- carrying an LED ribbon board that runs unbroken
## through the corners. A stack of boxes can approximate a square annulus and
## cannot be that shape at all; the old bowl was four flat banks, and a ribbon
## that turns square corners is a scoreboard rather than a ribbon.
##
## The split is drawn where the reference draws it. The model is the BUILDING:
## rows, concourse, suite storey, ribbons, stair nosings, wall, roof. This file
## keeps the SHOW: the ring, the ramp, the stage, the video wall, the portals,
## the truss, the floor, the barricades, and everyone in the seats. Nothing of
## the entrance set moved, and none of its numbers changed.
##
## The exporter reads its constants out of THIS FILE (see its `WANTED` list),
## so the mesh and the ringside chairs standing on it cannot be edited apart,
## and `tests/test_arena_bowl.gd` measures the committed .glb against
## `_row_schedule()` to prove they still agree.
##
## Everything here is cosmetic. Nothing in this file creates a
## CollisionObject3D, joins a physics layer, or is read by gameplay: the ring's
## own colliders in ring.tscn remain the only bodies the match touches.
##
## Nothing here moves at all any more. The hall's one piece of cosmetic
## motion was the crowd's idle bob, a vertex shader that ARCHITECTURE.md
## permitted because it ran on the render thread and could not reach
## MatchReferee.compute_end_state_hash(); it left with the crowd. The video
## wall's clip (core/arena/video_wall.gd) is the only thing in the arena that
## changes frame to frame now, and it is a texture, not geometry.
##
## Placement is seeded (PLACEMENT_SEED), so the same build produces the same
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
##
## 6.0m, in from 9.0. The bar is a real one: a state athletic regulation
## requires "the ringside barrier must be a minimum of six feet from the
## outside edge of the ring" (Virginia 18VAC120-40-415.1). The outside edge of
## THIS ring is its apron at APRON_OUT = 3.20, so the minimum legal line is
## 5.03m and 9.0 was 5.8m of empty floor -- nearly nineteen feet, which is not
## a ringside, it is a car park.
##
## 6.0 leaves 2.80m (9ft 2in) between apron and barrier: over the regulation
## minimum, enough for the camera well and a cameraman to work in, and still
## clear of the steel steps, which reach 4.34m from ring centre.
##
## Moving it in does the second half of the job on its own. The floor rows are
## offsets of THIS number (see `_build_floor_seats`), so pulling the barrier
## 3m closer to the ring converts 3m of dead floor into four more rows of the
## best seats in the building.
const BARRICADE_RADIUS := 6.0
## Half-width of the gap the entrance walks through, on the -Z run only.
## The ramp foot lands on this line; without a gap the barrier would run
## straight through it, which is what it did while the ramp ended further in.
const BARRICADE_GAP := 2.40
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
## The black ringside matting. A real ringside floor is not the bare deck --
## it is covered in interlocking rubber mats from the ring out to the barrier,
## and they are the dark ground everything at ringside is read against. The
## entrance ramp comes down to the EDGE of this, at the barrier line, and the
## mat carries the last few metres to the ring; a ramp that runs all the way
## to the apron is a ramp nobody could walk around.
const RINGSIDE_MAT_LIFT := 0.006
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
## Walkway between the two tiers.
const CONCOURSE_DEPTH := 2.6

# --- Floor seating ----------------------------------------------------------
## The chairs set out on the rink floor, between the barricade and the boards.
##
## This is where the bowl's four flat rows went. They existed because the bowl
## started 9m from the ring and there was nowhere else to put ringside seats;
## with the hall on rink scale there are twenty-odd metres of floor out there,
## and a real arena fills it -- floor seating is the best seat in the house and
## there is more of it than there is of anything else at ringside.
##
## Rows are offsets of the BARRICADE's own square, so the first ones wrap the
## ring tightly and they open out as they go; each is clipped to the rink, so
## the floor's shape comes from the boards rather than from a row count.
const FLOOR_ROW_PITCH := 0.85
## First row, as a distance outside the barricade line. Enough for the camera
## pit and for people to get past the front row.
const FLOOR_SEAT_START := 1.20
## Clear walkway kept inside the boards, so the back row is not up against
## them.
const FLOOR_SEAT_MARGIN := 1.2
## Clearance kept either side of the entrance ramp's centreline. The ramp is
## RAMP_HALF_WIDTH wide; this is that plus the aisle a crowd needs to stand in
## while someone walks down it.
const RAMP_CLEARANCE := 3.4
## How many floor rows get the imported folding chair before the rest switch
## to the box proxy. See `_build_floor_chairs()`: the near rows are the ones
## `ringside_low` and `wide_broadcast` actually resolve, and the far ones are
## forty metres of chair backs that cost 1448 triangles each if you let them.
const FLOOR_CHAIR_DETAIL_ROWS := 5

# --- Entrance stage ---------------------------------------------------------
## The stage occupies the -Z wedge. The default match camera sits off-axis
## on -X/+Z facing it, so the stage reads frame-left in the money shot with
## the bowl at frame center -- both halves of the hall earn their polygons,
## the stage via stage_wide/entrance framings as well as the broadcast edge.
const STAGE_HALF_WIDTH := 6.0
const STAGE_DECK_Y := 0.35
## The back wall of the set, which the video wall and the portals stand on.
##
## It moved from -24 to -38 with the rink. The set now stands in the gap the
## bowl leaves at the -Z END of the building, BEHIND the boards (-30.48)
## rather than a third of the way across the floor, which is where an entrance
## set actually stands. Everything else on the stage is measured off this, so
## the wall, the portals and the backdrop moved with it and none of their own
## numbers changed.
const STAGE_BACK := -38.0
## The front lip of the deck. The deck is the 8m between it and STAGE_BACK.
const STAGE_FRONT := -30.0
## The ramp runs from the stage lip to the ring, descending to floor level.
##
## It is 25.7m long now, against 4.7m before -- because there is a rink to
## cross. That is the length an entrance ramp is, and it is what the stage
## moving back to the end of the building buys: the walk is a walk.
const RAMP_HALF_WIDTH := 1.8
## Ramp step length. The fall is only STAGE_DECK_Y - FLOOR_Y = 1.45m over the
## whole run, a 6% grade, so the staircase `_add_box` forces is a shallow one:
## ~18 steps of 8cm. Stepped rather than wedged for the reason it always was
## -- axis-aligned boxes are all this file builds -- but at this length the
## steps are under a pixel of rise at any camera in the shotlist and the ramp
## reads as the slope it is standing in for.
const RAMP_STEP_LENGTH := 1.45

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
## Height of the wall's centre above the deck, and how far its face stands
## clear of the back wall. Declared as plain numbers so
## tools/blender/entrance_set.py can read them: that exporter reproduces the
## two sums below, but it must not re-type either measurement.
const SCREEN_CENTER_RISE := 9.0
const SCREEN_FACE_OFFSET := 1.1
const SCREEN_CENTER_Y := STAGE_DECK_Y + SCREEN_CENTER_RISE
const SCREEN_FACE_Z := STAGE_BACK + SCREEN_FACE_OFFSET
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
## How far the circle's lowest point sits BELOW the deck.
##
## This is the whole shape: the portal is a circle, and the deck cuts the
## bottom off it. Nothing else defines where the tube stops -- the two ends
## are wherever the circle crosses the deck, which is why this is the constant
## and the cut angle is derived rather than typed.
##
## 0.25 leaves a 2.2m opening at deck level. Larger cuts a wider doorway and
## less circle; at about 0.9 it stops reading as a circle at all and starts
## reading as an arch, which is a different piece of set.
const PORTAL_CUT_DEPTH := 0.25
const PORTAL_CENTER_Y := STAGE_DECK_Y + PORTAL_MAJOR - PORTAL_CUT_DEPTH
const PORTAL_FACE_OFFSET := 1.3
const PORTAL_FACE_Z := STAGE_BACK + PORTAL_FACE_OFFSET
const PORTAL_RING_SEGMENTS := 48
const PORTAL_TUBE_SIDES := 8
## The angle, measured from +X counter-clockwise, at which the portal circle
## crosses the deck on its right-hand side. Negative: it is below the
## horizontal. The left-hand crossing is its mirror, PI minus this.
##
## Derived from PORTAL_CUT_DEPTH rather than typed, so the tube always stops
## exactly where the deck is and moving one number cannot leave the ends
## floating above the floor or buried under it.
static func _portal_cut_angle() -> float:
	return asin(clampf((STAGE_DECK_Y - PORTAL_CENTER_Y) / PORTAL_MAJOR,
			-1.0, 1.0))
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

# --- The rink ---------------------------------------------------------------
## The hall is built around a REGULATION ICE RINK, in metres, because the
## reference arena is one: 200 x 85 feet with 28-foot corners, which is
## 60.96 x 25.91m with an 8.53m radius. `gauntlet/refs/arena.md` records why
## the building's proportions come from here rather than from the ring.
##
## This is the change that put the hall on scale. Before it, the bowl's first
## row sat 9m from the ring on a 28 x 18m plan -- about a third of a rink --
## and the whole arena was the size of a sports hall. The ring is unmoved at
## the centre of it; everything else is now measured out from the boards.
const RINK_HALF_LENGTH := 30.48
const RINK_HALF_WIDTH := 12.955
const RINK_CORNER_RADIUS := 8.53
## Dasher boards: 42 inches. The glass above them is not built -- it is
## transparent, and at the distances every camera in the shotlist sees the
## boards from it would cost a pane of geometry to show nothing.
const RINK_BOARD_HEIGHT := 1.07
## The board cap rail, a hand's width of yellow along the top of the white.
const RINK_CAP_HEIGHT := 0.12

# --- Bowl plan --------------------------------------------------------------
## The bowl is an OBROUND -- two straight sides joined by semicircular ends --
## because that is the plan of the ice-hockey arenas this promotion plays in,
## which `gauntlet/refs/arena.md` records off the reference photographs. Every
## row, the concourse, the suite fascia, the shell, the rink deck and the
## boards are the same curve at a different offset from one rectangle of
## half-extents (BOWL_STRAIGHT_X, BOWL_STRAIGHT_Z), so the rows stay parallel
## and the tread depth is constant through the corners.
##
## That rectangle IS THE RINK'S: a rink is its own corner radius offset from
## it, so `_plan_loop(RINK_CORNER_RADIUS)` is the boards and every row is the
## same curve further out. One rectangle, one curve, one building -- which is
## why these two are derived numbers written out longhand rather than an
## expression: `arena_bowl.py` parses plain constants, and
## `test_arena_bowl.gd` asserts the derivation instead.
##
##     BOWL_STRAIGHT_X = RINK_HALF_WIDTH  - RINK_CORNER_RADIUS = 4.425
##     BOWL_STRAIGHT_Z = RINK_HALF_LENGTH - RINK_CORNER_RADIUS = 21.95
##
## The long axis is Z, so the +-X sides are the building's long sides -- the
## hard-camera sides -- and the -Z end is an END. That is where the entrance
## set goes, and it is why the ramp can now be a ramp: it has the length of a
## rink end to cross.
##
## These are the numbers `tools/blender/arena_bowl.py` reads to build the mesh.
## It parses them out of THIS FILE; they are not duplicated there, and adding
## one to its WANTED list is how it gets a new one.
const BOWL_STRAIGHT_X := 4.425
const BOWL_STRAIGHT_Z := 21.95
## Where the first row of the bowl sits, as an offset from the plan rectangle.
## The boards are at RINK_CORNER_RADIUS (8.53) and this is 1.6m outside them:
## the walkway that runs round every rink between the boards and the seats.
##
## Distinct from BARRICADE_RADIUS, which is measured from the RING. The two
## used to be the same number because the bowl started where ringside ended;
## now there is a rink floor between them, and it is full of seats.
const BOWL_FIRST_ROW := 10.13
## Sampling of the plan curve. Both loops -- Blender's and this file's -- must
## produce the same vertex count in the same order, which they do by using
## these two numbers and nothing else.
const BOWL_CORNER_SEGMENTS := 16
const BOWL_STRAIGHT_SEGMENTS := 8
## Aisles cut up the rake. `arena_bowl.py` lays a lit stair nosing on every
## tread there and leaves the seat rail broken for them, and the ringside
## chairs leave the same gaps.
const BOWL_AISLES := 12
## The storey between the two tiers: suite glass with an LED ribbon board
## above and below it. The upper tier starts on top of it, which is what gives
## the hall two decks rather than one thirty-row rake.
const SUITE_HEIGHT := 3.6
const RIBBON_HEIGHT := 0.55
## Height of a seat back standing on its tread.
const SEAT_BACK_HEIGHT := 0.42
## How wide a seat back is as a fraction of SEAT_PITCH. Under 1.0 so there is
## a visible dark gap between one seat and the next: with the hall empty that
## gap is the whole read. Built as one continuous rail -- which is what this
## was while a crowd sat in front of it -- a bank of seats renders as a flat
## navy slope with nothing in it to count.
const SEAT_WIDTH_FRACTION := 0.84
## How wide an aisle is kept clear of seating, in metres either side.
const AISLE_CLEARANCE := 0.85

# --- Shell ------------------------------------------------------------------
## The hall is longer than it is wide, like the rink inside it. WALL_EXTENT is
## the +-Z half-extent and WALL_EXTENT_X the +-X one; the difference is exactly
## BOWL_STRAIGHT_Z - BOWL_STRAIGHT_X, so the shell clears the last row by the
## same margin all the way round.
##
##     last row  = BOWL_FIRST_ROW + 12*ROW_RUN + CONCOURSE_DEPTH + 8*ROW_RUN
##               = 10.13 + 11.4 + 2.6 + 7.6 = 31.73
##     +-X       = BOWL_STRAIGHT_X + 31.73 + 1.8 = 37.96
##     +-Z       = BOWL_STRAIGHT_Z + 31.73 + 1.8 = 55.48
##
## which is a building 76 x 111m on plan. A real arena of this rink's era is
## 100-120m long, so this is the right order of magnitude for the first time.
const WALL_EXTENT := 55.5
const WALL_EXTENT_X := 38.0
## Roof and wall height went up with the plan. A 14m roof over a 111m hall is
## a warehouse; a rink arena carries its roof steel at 20-25m, and the upper
## tier's back row now tops out at 12.1m, which the old 14m roof would have
## been sitting on.
const WALL_TOP := 25.0
const ROOF_Y := 21.0
const TRUSS_Y := 7.6

# --- The Blender model ------------------------------------------------------
## The bowl and shell mesh, built by `tools/blender/arena_bowl.py` from the
## constants above and exported as glTF. See that file's header for why this
## one piece of the hall is modelled rather than assembled from boxes: an
## obround bowl with swept ribbon boards is not expressible as axis-aligned
## primitives, and the reference arena is an obround.
##
## Everything else in the hall -- ring, ramp, stage, video wall, portals,
## truss, floor, barricades, ringside chairs -- is still built here and is
## unchanged by the model.
const BOWL_MODEL := "res://assets/environment/arena_bowl.glb"
## Which MaterialLibrary key dresses each object in the model. Every surface
## the model ships is overridden: the .glb carries placeholder colours so it
## can be opened on its own, and the hall's real tints are solved against
## measured luminance targets that a colour picked in Blender cannot know
## about. `reach` scales the house-emission floor per part exactly as the
## generated surfaces do.
const BOWL_MODEL_MATERIALS := {
	"BowlSteps": ["arena_bowl", 1.0],
	"BowlSeats": ["arena_seat", 1.17],
	"SuiteFascia": ["arena_shell", 0.9],
	"SuiteGlass": ["arena_suite_glass", 0.5],
	"Shell": ["arena_shell", 0.85],
	"RinkDeck": ["arena_rink", 0.7],
	# The boards are the brightest large surface in the hall on purpose: they
	# are white, they ring the floor, and in the reference photographs they
	# are the line that tells floor from seating.
	#
	# 8.0 is an order of magnitude above any other reach here, and it is not a
	# fudge: `_house_lit()` solves for a target LUMINANCE, so a reach is only
	# comparable between surfaces of similar albedo, and this one's albedo is
	# five times the bowl's. What it buys is 0.048 linear against the seats'
	# 0.0070 -- boards that read white with the house down, which is what every
	# reference photograph shows and what a fixture-lit white wall at floor
	# level does not get on its own down here.
	"RinkBoards": ["arena_boards", 8.0],
	"RinkCap": ["arena_board_cap", 3.0],
}
## The two parts that are lit rather than house-lit: the ribbon boards ring
## the whole bowl and the stair nosings run up every aisle, and both are
## fixtures in the reference frames -- they emit, they are not surfaces
## catching a wash. Values are the linear luminance each reaches on its own.
const BOWL_MODEL_EMISSIVE := {
	"RibbonBoards": ["arena_ribbon", 0.40],
	"StairNosing": ["arena_nosing", 0.28],
}

# --- Seating ----------------------------------------------------------------
## Distance between seats along a row.
##
## A constant as well as an export, because it is the pitch
## `tools/blender/arena_bowl.py` divides each row's seats at and the exporter
## reads constants, not exports. Retuning the export alone moves the ringside
## chairs and leaves the bowl's seats where they were; move the constant and
## rebuild the model.
const SEAT_PITCH := 0.62
@export var seat_pitch: float = SEAT_PITCH
## Fixed so the arena is identical every run.
const PLACEMENT_SEED := 20260902


var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = PLACEMENT_SEED
	_build_ringside()
	_build_bowl()
	_build_floor_seats()
	_build_entrance_set()


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


## What a self-emissive level is multiplied by on a renderer with no HDR
## buffer. See `_emissive_gain()` for the measurement.
##
## Solved, not guessed: at 0.35 the portal band measured 0.76x of the same
## frame on forward_plus -- overshot into too dark -- so 0.46 is 0.35 scaled by
## that miss.
##
## RE-MEASURED before shipping, because this comment first said the rings then
## land "within a few percent". They do not: the portal band reads 0.86x of the
## forward_plus frame, so 0.46 is still 14% dark. That is a large improvement
## on the 2.89x this replaced and it keeps the magenta and amber telling the
## two rings apart instead of clipping both to white, which is the point. It is
## not parity, and the constant is deliberately NOT re-tuned to 0.535 off a
## single region's box: the same frame has an unexplained result on the
## backdrop edges (see README), and chasing one number while another is
## unaccounted for is how the first version of this comment came to overstate
## itself.
const COMPAT_EMISSIVE_GAIN := 0.46

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
	mat.emission_energy_multiplier = level * _emissive_gain() / albedo_linear
	return mat


## Multiplier on every self-emissive level in the hall, by renderer.
##
## The levels above are solved against forward_plus, whose HDR buffer lets the
## Environment's Filmic curve roll a value above 1.0 back down. The
## compatibility renderer has no such buffer: anything over 1.0 clips flat to
## white instead of rolling off, so the same number that blooms on one renderer
## is a white shape on the other. Measured on stage_wide against the same frame
## on forward_plus, before this existed: the portal band rendered at 2.89x and
## the video wall at 1.71x, while everything house-lit around them went darker.
##
## This is the opposite correction to ArenaLighting's COMPAT_LIGHT_GAIN and it
## lives here rather than there because emission is a material property -- no
## amount of scaling a Light3D touches it. Two separate faults, two separate
## fixes.
static func _emissive_gain() -> float:
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		return 1.0
	return COMPAT_EMISSIVE_GAIN


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
## The video wall's curve left with the wall. `tools/blender/entrance_set.py`
## carries `arc_radius` and `sagitta_for` now, and the reason they are a PAIR
## went with them: the bezel has to sit on the SAME circle as the picture, a
## wider chord bowed by its own sagitta, or the two arcs cross mid-panel and
## the frame surfaces through the picture as two dark chevrons.

## The stage's mesh helpers -- the curved wall's face and shell, the portal
## arc tube, the slat fan and the recess tube -- left with the geometry they
## built. tools/blender/entrance_set.py makes those shapes now, out of
## venue.py's swept tubes and arcs. What stays here is what still generates:
## _add_box and _add_oriented, for the floor, its seams and the barricades.




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

## The floor, its panel joints and the barricades are
## `tools/blender/ringside.py`'s model.
##
## Only the barricades gained anything by moving, and it is worth saying which:
## their capping rail is a TUBE now rather than a box. It is the only
## horizontal at ringside at chest height, it runs across the whole width of
## the wide shot, and a box takes a highlight on one facet where a tube takes
## one along its length -- which is what reads as steel. The raking leg behind
## each panel is a tube for the same reason.
##
## The floor slab is one box there as it was one box here. The panel joints
## keep their analytic clip to the rink's own plan -- at a given x the decking
## reaches BOWL_STRAIGHT_Z + sqrt(r^2 - dx^2), so a joint stops where the
## decking does instead of running out over the seating.
const RINGSIDE_MODEL := "res://assets/environment/ringside.glb"

## Part name -> [material key, house reach]. Unchanged from the surfaces these
## replace, including the barricade's 1.5: it is the one ringside surface the
## wide shot reads scale off, and it has to separate from the floor behind it.
const RINGSIDE_MATERIALS := {
	"Floor": ["arena_floor", 1.0],
	# The black matting between the barrier and the ring. Reach 0.45: it is
	# the darkest large surface in the lower frame and it is what the mat's
	# exposure anchor, the steps and the wrestlers working outside are all
	# read against. Lifting it further flattens the ring into the floor.
	"RingsideMat": ["arena_floor", 0.45],
	"FloorSeams": ["arena_floor", 0.35],
	"Barricades": ["arena_barricade", 1.5],
}


func _build_ringside() -> void:
	var packed: PackedScene = load(RINGSIDE_MODEL)
	if packed == null:
		push_error("ArenaBuilder: %s failed to load. Run tools/blender/build_venue.sh ringside."
				% RINGSIDE_MODEL)
		return
	var root: Node3D = packed.instantiate()
	root.name = "Ringside"
	for part: String in RINGSIDE_MATERIALS:
		var spec: Array = RINGSIDE_MATERIALS[part]
		_dress(root, part, MaterialLibrary.house_compensate(
				_house_lit(_textured(spec[0]), spec[1])))
	add_child(root)


# ---------------------------------------------------------------------------
# Seating bowl
# ---------------------------------------------------------------------------

## The bowl itself is `tools/blender/arena_bowl.py`'s model; what is built
## here is who sits on it.
##
## The two halves share `_row_schedule()`, which is the same arithmetic the
## exporter runs, so a ringside chair's tread height and the mesh's tread
## height come from one place. `test_arena_bowl.gd` measures the shipped .glb
## against this schedule, so the pair cannot drift silently.
func _build_bowl() -> void:
	add_child(_build_bowl_model())


# ---------------------------------------------------------------------------
# Floor seating
# ---------------------------------------------------------------------------

## The chairs on the rink floor, from the barricade out to the boards.
##
## This is the biggest block of seating in the hall and, in a real building,
## the most expensive: twenty-odd metres of floor either side of the ring and
## a rink end behind it. It replaced the four flat rows the bowl used to carry
## at ringside, which existed only because the bowl started 9m from the ring
## and there was nowhere else to put them.
##
## Rows are offsets of the BARRICADE's square rather than of the rink's
## rectangle: floor seating is laid out around the ring, not around the
## building, and a row that wrapped the rink's plan would have its far end
## forty metres from the thing it is pointed at. Each row is then clipped to
## the rink, so the shape of the block comes from the boards.
func _build_floor_seats() -> void:
	var detailed: Array[Transform3D] = []
	var distant: Array[Transform3D] = []
	# The last row is the one whose offset still leaves the walkway inside the
	# boards. Derived, not counted: changing the rink or the margin moves the
	# back row without anyone having to re-count rows.
	var last := RINK_HALF_LENGTH - FLOOR_SEAT_MARGIN - BARRICADE_RADIUS
	var index := 0
	var offset := FLOOR_SEAT_START
	while offset <= last:
		_floor_seat_row(offset,
				detailed if index < FLOOR_CHAIR_DETAIL_ROWS else distant)
		offset += FLOOR_ROW_PITCH
		index += 1
	add_child(_build_chairs("FloorChairs", _chair_mesh(), detailed))
	add_child(_build_chairs("FloorChairsFar", _chair_proxy_mesh(), distant))
	_build_floor_crowd(detailed + distant)


## Ringside model: six seated people, built by tools/blender/floor_crowd.py.
const FLOOR_CROWD_MODEL := "res://assets/environment/floor_crowd.glb"
## How many of the ringside chairs have somebody in them.
##
## Higher than the bowl's 0.86 because these are the seats a camera is nearest
## to and the ones gauntlet/refs/lighting/ shows packed -- ringside is where a
## show puts the people it wants on television. The empty ones still read:
## the chair is modelled underneath every figure either way.
const FLOOR_CROWD_FILL := 0.92
## Seeded separately from PLACEMENT_SEED so re-rolling who is sitting where
## does not move the chairs themselves.
const FLOOR_CROWD_SEED := 20260916


## Put people in the ringside chairs.
##
## One MultiMesh per variant rather than one for the lot, because a MultiMesh
## draws a single mesh: six meshes is six draw calls and six poses, against
## one draw call and a thousand identical twins.
##
## The figures reuse the chairs' own transforms -- same curve, same yaw, same
## exclusions for the rink edge, the ramp and the aisles -- so a fan cannot
## end up in a spot a chair was not. The Blender figure is built with its
## backside at a folding chair's seat height, so it needs no vertical offset
## here (crowd.CHAIR_SEAT_HEIGHT).
func _build_floor_crowd(seats: Array[Transform3D]) -> void:
	var packed: PackedScene = load(FLOOR_CROWD_MODEL)
	if packed == null:
		push_error("ArenaBuilder: %s failed to load. Run tools/blender/build_arena.sh."
				% FLOOR_CROWD_MODEL)
		return
	var source: Node3D = packed.instantiate()
	var meshes: Array[Mesh] = []
	for child in source.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh != null:
			meshes.append(instance.mesh)
	if meshes.is_empty():
		push_error("ArenaBuilder: %s carries no fan meshes." % FLOOR_CROWD_MODEL)
		source.free()
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = FLOOR_CROWD_SEED
	# Which variant each occupied seat gets, and how it is dressed.
	var buckets: Array[Array] = []
	var colours: Array[Array] = []
	for _i in meshes.size():
		buckets.append([] as Array[Transform3D])
		colours.append([] as Array[Color])

	for seat in seats:
		if rng.randf() > FLOOR_CROWD_FILL:
			continue
		var pick := rng.randi_range(0, meshes.size() - 1)
		# Size and a little extra yaw on top of the chair's own, so two
		# neighbours on the same variant are still not the same person.
		var scale := rng.randf_range(0.93, 1.07)
		var turned := seat.rotated_local(Vector3.UP, rng.randf_range(-0.18, 0.18))
		buckets[pick].append(Transform3D(turned.basis.scaled(Vector3.ONE * scale),
				turned.origin))
		colours[pick].append(_crowd_shirt(rng))
	source.free()

	var material := _crowd_material("float(INSTANCE_ID) * 0.6180339887")
	for i in meshes.size():
		if buckets[i].is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# Per-instance colour is why the six meshes carry no hue of their
		# own: the shirt is dressed here, so six poses clothe a thousand
		# people. The meshes are not flat white though -- they carry white
		# for cloth and a darker grey for skin, and this multiplies against
		# it, which is what gives a fan a face.
		mm.use_colors = true
		mm.mesh = meshes[i]
		mm.instance_count = buckets[i].size()
		for j in buckets[i].size():
			mm.set_instance_transform(j, buckets[i][j])
			mm.set_instance_color(j, colours[i][j])
		var node := MultiMeshInstance3D.new()
		node.name = "FloorCrowd%02d" % i
		node.multimesh = mm
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)


## A shirt, from the same palette tools/blender/crowd.py dresses the bowl in --
## restated here rather than shared because the bowl's is baked into a .glb by
## a Blender script this file cannot import, and a crowd whose two halves wear
## different palettes is worse than one number written twice.
const CROWD_SHIRTS: Array[Color] = [
	Color(0.20, 0.21, 0.26), Color(0.28, 0.24, 0.24), Color(0.17, 0.20, 0.24),
	Color(0.31, 0.29, 0.27), Color(0.22, 0.26, 0.28), Color(0.26, 0.22, 0.29),
	Color(0.15, 0.16, 0.19), Color(0.33, 0.31, 0.33), Color(0.19, 0.23, 0.21),
	Color(0.30, 0.26, 0.22), Color(0.24, 0.20, 0.22), Color(0.18, 0.19, 0.27),
	Color(0.29, 0.30, 0.31), Color(0.21, 0.18, 0.18),
]


func _crowd_shirt(rng: RandomNumberGenerator) -> Color:
	var base: Color = CROWD_SHIRTS[rng.randi_range(0, CROWD_SHIRTS.size() - 1)]
	var k := rng.randf_range(0.82, 1.18)
	# sRGB in, linear out, and this conversion is the whole reason the two
	# halves of the crowd can share one palette.
	#
	# crowd.py writes these same numbers into a colour attribute, where the
	# glTF importer decodes them -- 0.72 arrives in the mesh as 0.479. A
	# MultiMesh instance colour gets no such decode: it reaches COLOR in the
	# shader exactly as written. Handing the shader 0.21 raw is handing it a
	# LINEAR 0.21, which displays around 0.5 -- so the ringside fans came out
	# pale grey blocks against a bowl wearing the identical palette, in the
	# seats nearest the camera.
	return Color(base.r * k, base.g * k, base.b * k).srgb_to_linear()


## One row of floor chairs, walked along the barricade's offset curve.
##
## Three things take a chair out of the row, and all three are things a real
## floor has: the rink's edge (with its walkway), the entrance ramp's corridor,
## and the four corner aisles that break the floor into blocks.
func _floor_seat_row(offset: float, out_chairs: Array[Transform3D]) -> void:
	const WOBBLE := 0.012
	const YAW_JITTER := 0.035
	var loop := _offset_loop(BARRICADE_RADIUS, BARRICADE_RADIUS, offset)
	var carry := 0.0
	for i: int in loop.size():
		var here: Vector3 = loop[i][0]
		var next: Vector3 = loop[(i + 1) % loop.size()][0]
		var span := here.distance_to(next)
		if span <= 0.0:
			continue
		var at := seat_pitch - carry
		while at < span:
			var point := here.lerp(next, at / span)
			at += seat_pitch
			if not _inside_rink(point, FLOOR_SEAT_MARGIN):
				continue
			if point.z < 0.0 and absf(point.x) < RAMP_CLEARANCE:
				continue
			if _in_floor_aisle(point):
				continue
			var inward: Vector3 = -(loop[i][1] as Vector3)
			var jitter := Vector3(_rng.randf_range(-WOBBLE, WOBBLE), 0.0,
					_rng.randf_range(-WOBBLE, WOBBLE))
			var basis := Basis(Vector3.UP, atan2(inward.x, inward.z)
					+ _rng.randf_range(-YAW_JITTER, YAW_JITTER))
			out_chairs.append(Transform3D(basis,
					Vector3(point.x, FLOOR_Y, point.z) + jitter))
		carry = span - (at - seat_pitch)


## Is a point on the rink, with `margin` of walkway kept inside the boards?
##
## The rink IS the plan rectangle offset by RINK_CORNER_RADIUS, so this is the
## same distance-to-a-rectangle the whole building is built on, tested rather
## than swept.
static func _inside_rink(point: Vector3, margin: float) -> bool:
	var dx := maxf(absf(point.x) - BOWL_STRAIGHT_X, 0.0)
	var dz := maxf(absf(point.z) - BOWL_STRAIGHT_Z, 0.0)
	return sqrt(dx * dx + dz * dz) <= RINK_CORNER_RADIUS - margin


## The two diagonal aisles that cut the floor into four blocks -- sides and
## ends -- as the lines x = z and x = -z. Distance from a point to either is
## |x -+ z| / sqrt(2), which is cheaper than any bearing arithmetic and, unlike
## an angular clearance, stays the same width the whole way out.
static func _in_floor_aisle(point: Vector3) -> bool:
	const HALF_WIDTH := 0.85
	return minf(absf(point.x - point.z), absf(point.x + point.z)) \
			< HALF_WIDTH * sqrt(2.0)


## Instance the exported bowl and dress every part of it.
##
## The model ships placeholder colours so the .glb opens as something
## recognisable on its own; nothing in the frame uses them. Each object is
## overridden with the MaterialLibrary key `BOWL_MODEL_MATERIALS` names, which
## is where the hall's measured tints, its maps and its house-lighting
## compensation live -- and is why swapping generated geometry for a model
## moved no luminance target.
func _build_bowl_model() -> Node3D:
	var packed: PackedScene = load(BOWL_MODEL)
	if packed == null:
		push_error("ArenaBuilder: %s failed to load. Run tools/blender/build_arena.sh."
				% BOWL_MODEL)
		return Node3D.new()
	var root: Node3D = packed.instantiate()
	root.name = "BowlModel"
	for part: String in BOWL_MODEL_MATERIALS:
		var spec: Array = BOWL_MODEL_MATERIALS[part]
		_dress(root, part, MaterialLibrary.house_compensate(
				_house_lit(_textured(spec[0]), spec[1])))
	for part: String in BOWL_MODEL_EMISSIVE:
		var spec: Array = BOWL_MODEL_EMISSIVE[part]
		_dress(root, part, _self_emissive(_textured(spec[0]), spec[1]))
	for part: String in CROWD_PARTS:
		_dress(root, part, _crowd_material())
	return root


## The parts of the bowl model that are people, and the level they sit at.
##
## Not in BOWL_MODEL_MATERIALS because they are not a MaterialLibrary surface:
## every crowd vertex carries its own shirt colour and its own animation phase
## (tools/blender/crowd.py bakes both into COLOR_0), so the material has to be
## a shader that reads them rather than a StandardMaterial3D with one albedo.
const CROWD_PARTS := ["Crowd", "CrowdFar"]

## Idle motion, and the light floor the crowd sits on.
##
## A vertex shader ON PURPOSE, and this is the clause ARCHITECTURE.md's
## cosmetic-motion rule was written for: it runs on the render thread, reads
## only TIME and the mesh's own attributes, and writes nothing back, so it
## cannot feed gameplay state or move a replay's end-state hash. Thousands of
## skinned spectators is not an option that runs; this is how a crowd moves.
##
## The phase comes from UV.x, not from INSTANCE_ID. The crowd used to be a
## MultiMesh, where an instance id told one person from the next; it is baked
## into the bowl's own mesh now, so every figure shares one id and keying off
## it would make the entire bowl bob in perfect unison. crowd.py writes a
## golden-ratio phase per figure into a UV channel instead -- colour alpha was
## tried first and arrives back 1.0 for every vertex, since nothing in either
## the exporter or the importer preserves an alpha no material reads.
func _crowd_material(phase_source: String = "UV.x") -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, shadows_disabled, cull_disabled;

uniform float bob_amplitude = 0.035;
uniform float bob_speed = 1.7;
uniform float sway_amplitude = 0.018;
// The floor that keeps the back rows off measure_frame.py's 0.0025 void
// threshold, in the same spirit as ArenaBuilder.HOUSE_TARGET. The crowd's
// real level is meant to come from a fixture aimed at it; until the house
// wash actually reaches the bowl (see gauntlet/refs/lighting.md's ablation)
// this is most of what lights them, which is why it is not smaller.
uniform float house_light = 0.055;

varying vec3 shirt;

void vertex() {
	shirt = COLOR.rgb;
	float phase = PHASE_SOURCE * 6.2831853;
	// Bob scaled by height above the seat, so feet stay planted and heads
	// move most -- a figure translated bodily reads as a hovering cutout.
	float lift = clamp(VERTEX.y * 1.4, 0.0, 1.0);
	VERTEX.y += sin(TIME * bob_speed + phase) * bob_amplitude * lift;
	// A little lateral sway on a different period, so the bowl does not
	// pulse as one organism.
	VERTEX.x += sin(TIME * bob_speed * 0.63 + phase * 1.7) * sway_amplitude * lift;
}

void fragment() {
	ALBEDO = shirt;
	EMISSION = shirt * house_light;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
"""
	shader.code = shader.code.replace("PHASE_SOURCE", phase_source)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


## Override one named object in the model, and say so loudly if it is missing
## -- a part that silently keeps its Blender colour is the one failure mode of
## dressing a model by node name, and it shows up as a pale surface in the
## middle of a solved frame rather than as an error.
func _dress(root: Node3D, part: String, mat: Material) -> void:
	var node := root.find_child(part, true, false) as MeshInstance3D
	if node == null:
		push_error("ArenaBuilder: %s has no '%s' object." % [BOWL_MODEL, part])
		return
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------------------------------------------------------------------------
# The plan curve
# ---------------------------------------------------------------------------

## Every row of the bowl in build order, as the exporter builds them.
##
## Mirrors `arena_bowl.py`'s `row_schedule()` line for line. The two are
## written twice rather than shared through a data file because what they are
## made of is already shared -- the exporter parses its numbers out of this
## file -- and a twenty-line loop a test pins against the mesh is a smaller
## liability than a third format between them.
static func _row_schedule() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var inner := BOWL_FIRST_ROW
	var tread_y := FLOOR_Y
	for tier: int in [0, 1]:
		var count: int = LOWER_ROWS if tier == 0 else UPPER_ROWS
		if tier == 1:
			var concourse_inner := inner
			inner += CONCOURSE_DEPTH
			rows.append({"kind": "concourse", "inner": concourse_inner,
					"outer": inner, "tread_y": tread_y})
			tread_y += SUITE_HEIGHT
		for r: int in count:
			var outer := inner + ROW_RUN
			tread_y += ROW_RISE
			rows.append({"kind": "seated", "tier": tier, "index": r,
					"inner": inner, "outer": outer, "tread_y": tread_y})
			inner = outer
	rows.append({"kind": "outer", "inner": inner, "outer": inner,
			"tread_y": tread_y})
	return rows


## The obround at `offset`, as [position, outward normal] pairs, counter-
## clockwise from the +X straight. Positions carry y = 0; the caller supplies
## the tread height.
##
## Mirrors `arena_bowl.py`'s `plan_loop()`, vertex order included, so an index
## means the same bearing in both -- which is what lets the aisles the chairs
## leave clear be the aisles the model puts stair nosings up.
static func _plan_loop(offset: float) -> Array:
	return _offset_loop(BOWL_STRAIGHT_X, BOWL_STRAIGHT_Z, offset)


## The general form: the obround at `offset` from ANY rectangle.
##
## Two rectangles are offset in this hall and they are not the same one. The
## building -- rink, boards, bowl, shell -- comes off (BOWL_STRAIGHT_X,
## BOWL_STRAIGHT_Z), which is the rink's. The floor seating comes off the
## BARRICADE's square, because floor seats are laid out around the ring rather
## than around the building. Same curve, same walk, same normals; one function.
static func _offset_loop(ax: float, az: float, offset: float) -> Array:
	var loop: Array = []
	var straight := func(from: Vector3, to: Vector3, normal: Vector3) -> void:
		for i: int in BOWL_STRAIGHT_SEGMENTS:
			loop.append([from.lerp(to, float(i) / float(BOWL_STRAIGHT_SEGMENTS)),
					normal])
	var corner := func(center: Vector3, start_angle: float) -> void:
		for i: int in BOWL_CORNER_SEGMENTS:
			var angle := start_angle \
					+ PI * 0.5 * float(i) / float(BOWL_CORNER_SEGMENTS)
			var dir := Vector3(cos(angle), 0.0, sin(angle))
			loop.append([center + dir * offset, dir])
	straight.call(Vector3(ax + offset, 0.0, -az), Vector3(ax + offset, 0.0, az),
			Vector3.RIGHT)
	corner.call(Vector3(ax, 0.0, az), 0.0)
	straight.call(Vector3(ax, 0.0, az + offset), Vector3(-ax, 0.0, az + offset),
			Vector3.BACK)
	corner.call(Vector3(-ax, 0.0, az), PI * 0.5)
	straight.call(Vector3(-ax - offset, 0.0, az), Vector3(-ax - offset, 0.0, -az),
			Vector3.LEFT)
	corner.call(Vector3(-ax, 0.0, -az), PI)
	straight.call(Vector3(-ax, 0.0, -az - offset), Vector3(ax, 0.0, -az - offset),
			Vector3.FORWARD)
	corner.call(Vector3(ax, 0.0, -az), PI * 1.5)
	return loop


## Where the entrance set stands: the bowl opens instead of walling it off.
static func _in_stage_gap(point: Vector3) -> bool:
	return point.z < 0.0 and absf(point.x) < STAGE_HALF_WIDTH


## Loop indices the aisles land on. Index-based rather than distance-based so
## an aisle keeps the same bearing on every row, which is what makes the
## nosings line up into a staircase instead of wandering across the rake.
static func _aisle_indices() -> PackedInt32Array:
	var per_loop := _plan_loop(BOWL_FIRST_ROW).size()
	var picks := PackedInt32Array()
	for k: int in BOWL_AISLES:
		picks.append(int(round(float(k) * float(per_loop) / float(BOWL_AISLES)))
				% per_loop)
	return picks


# ---------------------------------------------------------------------------
# The chairs themselves
# ---------------------------------------------------------------------------

## One MultiMesh of folding chairs, in one draw call, on a plain material, not
## moving.
##
## Called twice, with two different meshes: the imported chair for the rows
## near the ring and a box proxy for the rest. See `_chair_proxy_mesh()` for
## why that split exists and what it is worth.
func _build_chairs(node_name: String, mesh: Mesh,
		chairs: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = chairs.size()
	for i: int in chairs.size():
		mm.set_instance_transform(i, chairs[i])

	var node := MultiMeshInstance3D.new()
	node.name = node_name
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


## The far-floor chair: four boxes, 48 triangles, standing in for the imported
## chair's 1448.
##
## The floor seats ~2,000 chairs now. At the imported mesh's triangle count
## that is 2.9 MILLION triangles of folding chair -- more than the rest of the
## hall put together by an order of magnitude, and most of it forty metres from
## any camera in the shotlist, where a whole chair covers a few pixels and
## nothing in it is resolvable but its silhouette and the gap under its seat.
##
## So the near rows (FLOOR_CHAIR_DETAIL_ROWS of them, the ones `ringside_low`
## and `wide_broadcast` actually resolve) keep the imported chair and the rest
## get this. The split costs one extra draw call and saves ~2.4M triangles.
##
## Dimensions and origin match `_chair_mesh()` exactly -- 0.50 x 0.90 x 0.60m,
## feet on y = 0, facing +Z -- because the two are placed by the same code and
## a proxy that does not match its own subject is a seam in the middle of the
## floor rather than an LOD.
static var _proxy_cache: ArrayMesh


static func _chair_proxy_mesh() -> ArrayMesh:
	if _proxy_cache != null:
		return _proxy_cache
	var st := _new_surface()
	# Seat pan, back, and the two legs, in that order.
	_add_box(st, Vector3(0.0, 0.44, 0.0), Vector3(0.46, 0.05, 0.46))
	_add_box(st, Vector3(0.0, 0.68, -0.21), Vector3(0.46, 0.44, 0.05))
	for sx: float in [-1.0, 1.0]:
		_add_box(st, Vector3(sx * 0.20, 0.22, 0.0), Vector3(0.05, 0.44, 0.42))
	_proxy_cache = st.commit()
	return _proxy_cache


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
## The entrance set and the truss are `tools/blender/entrance_set.py`'s model.
##
## They were five SurfaceTool builders here -- deck and ramp, backdrop,
## portals, video wall, truss. Two of them are why the move was worth making:
##
## * **The ramp was a staircase.** `_add_box` only makes axis-aligned boxes,
##   so a 25.7m ramp falling 1.45m shipped as eighteen 8cm steps. The note on
##   it argued the steps were under a pixel of rise from any camera in the
##   shotlist, which is true of the treads and false of the EDGE: a stepped
##   ramp has a stepped silhouette against the floor from every angle that
##   sees it side-on. It is one wedge now, with a fascia down each flank and
##   a nose at the bottom instead of a 1.45m cliff.
## * **The truss was sixteen boxes.** Overhead truss is the one piece of an
##   arena that is unmistakably a lattice from every angle. It is now four
##   chords on a square section with alternating diagonals bay by bay.
##
## Everything else is reproduced at its existing measurements, and every
## measurement is still read out of the constants above -- entrance_set.py
## parses them from this file rather than retyping them.
const ENTRANCE_MODEL := "res://assets/environment/entrance_set.glb"

## Part name in the .glb -> [material key, house reach]. The reaches are the
## ones each surface was solved at and the notes that earned them still stand:
## the deck is 0.8 because house emission is added on top of the SSR
## reflection that makes it read as a stage, and the backdrop is 1.1 -- in
## band with the shell -- because its colour comes from the four uplights
## aimed at it rather than from the surface lighting itself.
const ENTRANCE_MATERIALS := {
	"EntranceStage": ["arena_stage_deck", 0.8],
	"StageBackdrop": ["arena_stage_panel", 1.1],
	"PortalRecess": ["arena_tunnel", 0.35],
	"StageScreenBezel": ["arena_tunnel", 0.5],
	"Truss": ["arena_truss", 0.9],
}

## The parts that light themselves: part name -> [material key, level].
const ENTRANCE_EMISSIVE := {
	# The ramp's edge strips, in the portals' magenta. That colour is
	# MEASURED, not chosen: sampling the lit strip along the deck's leading
	# edge in gauntlet/refs/stage/dynamite_stage_low_angle.jpg, 67 of 136
	# sampled columns come back violet-magenta at hue 287-295 degrees against
	# 9 blue and 5 cyan, with the rest blown to white at the strip's core.
	#
	# Level 0.72 rather than the portals' 1.12: the strips run the whole 24m
	# of the ramp and sit far closer to the broadcast camera than the portals
	# do, so the same level puts two hard magenta lines through the middle of
	# every wide shot. This is under the Environment's glow threshold at the
	# tube's centre and over it on the bloom, so they still flare.
	"RampLeds": ["arena_portal_magenta", 0.72],
	"PortalRingWest": ["arena_portal_magenta", PORTAL_EMISSION],
	"PortalRingEast": ["arena_portal_amber", PORTAL_EMISSION],
	"PortalFanWest": ["arena_portal_magenta", PORTAL_FAN_EMISSION],
	"PortalFanEast": ["arena_portal_amber", PORTAL_FAN_EMISSION],
}


func _build_entrance_set() -> void:
	var packed: PackedScene = load(ENTRANCE_MODEL)
	if packed == null:
		push_error("ArenaBuilder: %s failed to load. Run tools/blender/build_venue.sh entrance."
				% ENTRANCE_MODEL)
		return
	var root: Node3D = packed.instantiate()
	root.name = "EntranceSet"
	for part: String in ENTRANCE_MATERIALS:
		var spec: Array = ENTRANCE_MATERIALS[part]
		_dress(root, part, MaterialLibrary.house_compensate(
				_house_lit(_textured(spec[0]), spec[1])))
	for part: String in ENTRANCE_EMISSIVE:
		var spec: Array = ENTRANCE_EMISSIVE[part]
		_dress(root, part, _self_emissive(MaterialLibrary.resolve(spec[0]), spec[1]))
	add_child(root)
	_attach_stage_video(root)


## The video wall, dressed last and separately.
##
## The panel is given its own material FIRST and only then handed to
## `StageVideo`. That ordering is the fallback: if the clip is missing, fails
## to decode, or the run is one that must not have a moving picture in it, the
## wall is already correct and nothing has to be undone.
##
## The face carries NORMALISED UVs (entrance_set.py authors them, unlike every
## other part, which is projected at world-metre density), so the texel-density
## scale MaterialLibrary derived from `tile_metres` has to go. Miss this and
## whatever lands on the wall tiles across it.
func _attach_stage_video(root: Node3D) -> void:
	var screen := root.find_child("StageScreen", true, false) as MeshInstance3D
	if screen == null:
		push_error("ArenaBuilder: %s has no 'StageScreen' object." % ENTRANCE_MODEL)
		return
	var screen_mat := MaterialLibrary.resolve("arena_screen")
	screen_mat.uv1_scale = Vector3.ONE
	screen.material_override = _self_emissive(screen_mat, SCREEN_BLANK_EMISSION)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(StageVideo.attach(screen, screen_mat))


## The shell is part of the Blender model now.
##
## It moved for the same reason the bowl did: the wall follows the bowl's own
## obround plan one metre outside the last row, so the building is the shape of
## the hall in it, and four boxes cannot be that. Its roof is still a slab --
## every camera in the shotlist is under the truss looking at the ring, and the
## roof is only ever the dark thing the truss hangs from.
##
## `_ready()` no longer calls this; it is kept as the place that documents
## where the shell went, and deliberately builds nothing.
func _build_shell() -> void:
	pass
