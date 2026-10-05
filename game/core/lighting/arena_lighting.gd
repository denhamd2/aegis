extends Node3D
class_name ArenaLighting
## The hall's real light rig: ring key/fill from the truss, house wash on the
## bowl, rim separation, stage wash, and the fog volumes the key cones cut
## shafts through.
##
## Why this replaces four hand-typed SpotLight3Ds in match.tscn
## ------------------------------------------------------------
## Those four were the whole rig, they hung at y 5.5 with `spot_range 10`, and
## the seating bowl starts at 9m -- so nothing outside the ring was lit by a
## light at all. The hall compensated by making every arena surface
## self-emissive (ArenaBuilder._house_lit), which is why the crowd measured
## brighter than the mat: an emissive surface does not care how far it is from
## a fixture. Emission cannot produce a shadow, a falloff, a shaft or a rim,
## so "ring lighting reads as one scene" (VISUAL_BAR.md priority 2) was not
## reachable from it in principle.
##
## Expressed as a script rather than as scene nodes for the same reason
## ArenaBuilder is a script: the rig is ~30 fixtures placed on rings and
## symmetric quads, which is a dozen numbers here and transform soup in a
## .tscn.
##
## Everything in this file is cosmetic. It creates no CollisionObject3D, joins
## no physics layer, and nothing in gameplay reads it -- ARCHITECTURE.md's
## condition for cosmetic systems.
##
## Evidence labelling (ARCHITECTURE.md, reference-driven tuning)
## ------------------------------------------------------------
## Traced to gauntlet/refs/:
##   * the exposure anchor -- the mat must render at 0.43-0.49 relative
##     luminance and a wrestler must sit 0.24-0.31 BELOW it
##     (VISUAL_BAR.md, off frames/wide_standoff_broadcast_angle.jpg);
##   * the crowd's level -- 0.014 relative luminance, dim but ~5x above the
##     void floor (VISUAL_BAR.md, "Background presence");
##   * the direction of the whole design: the wrestler separates from the mat
##     BY VALUE, so the rig has to be top-down dominant. A horizontal mat and
##     a standing torso only read differently under a key that comes from
##     above; under ambient they read the same, which is exactly what the
##     0.094/0.044 measurement was showing.
## Coverage decisions (engineering values, defended as nothing more):
##   * fixture count, truss positions, cone angles, colour temperatures, the
##     house/rim/stage ratios, fog density. gauntlet/refs/ measures nothing
##     about truss layout, and this file does not pretend otherwise.

# --- Geometry this rig hangs on (read from the hall, never written) ---------
## ArenaBuilder.TRUSS_Y. Key fixtures hang just under the grid so the truss
## reads as the thing they are hung from.
const TRUSS_Y := 7.6
const HANG_Y := TRUSS_Y - 0.35
## ArenaBuilder.ROOF_Y. Up from 14.0 with the hall: the building is now built
## around a regulation rink and carries its roof steel where an arena does.
const ROOF_Y := 21.0
## ArenaBuilder.BOWL_FIRST_ROW -- where the seating starts, as an offset from
## the hall's plan rectangle. It is no longer the same number as the
## barricade: there is a rink floor full of seats between the two.
const BOWL_INNER := 10.13
## ArenaBuilder.STAGE_BACK -- the plane the backdrop and the portals stand on.
## Mirrored here rather than imported for the same reason TRUSS_Y is: the rig
## reads the hall's geometry, it never writes it, and a one-way copy makes
## that direction impossible to get wrong.
##
## It moved from -24 to -38 when the entrance set moved to the end of the
## building. Every fixture on the stage is placed relative to this rather than
## in absolute z, so they went with it -- which is the whole reason for the
## mirror being a named constant and not a number typed four times.
const STAGE_BACK_Z := -38.0

# --- Hanging positions ------------------------------------------------------
## Where the fixtures hang, as plain constants because
## `tools/blender/overhead_rig.py` reads them to put steel where the fixtures
## are. A fixture hanging in mid-air is the failure this prevents: the truss
## is built FROM these numbers, so it cannot drift away from them.
##
## Ring keys at (+-KEY_OFFSET, HANG_Y, +-KEY_OFFSET).
const KEY_OFFSET := 3.9
## Top fills at (0, HANG_Y + 0.2, +-TOP_OFFSET_Z).
const TOP_OFFSET_Z := 2.1
## Beams: the plan curve BEAM_INSET inside the bowl's first row, BEAM_DROP
## under the roof.
const BEAM_INSET := 3.5
const BEAM_DROP := 4.0
## House wash: the same, closer to the seats and the roof.
const HOUSE_INSET := 1.5
const HOUSE_DROP := 1.4
## Stage wash, over the front of the entrance set.
const STAGE_WASH_X := 4.2
const STAGE_WASH_Y := 10.0
const STAGE_WASH_DZ := 21.0
## Portal accents, on booms off the deck.
const ACCENT_Y := 6.2
const ACCENT_DZ := 3.4
const ACCENT_NEAR_X := 3.7
const ACCENT_FAR_X := 6.3
## Rim pair, off the upstage line of the ring grid.
const RIM_X := 6.4
const RIM_Y := 6.9
const RIM_Z := -7.2
## Height of a fixture's clamp face above its head's tilt axis -- where the
## steel starts. `tools/blender/overhead_rig.py` builds to the same number.
const FIXTURE_TOP := 0.32
## Backdrop uplights, on floor stands either side of the set.
const UPLIGHT_NEAR_X := 9.4
const UPLIGHT_FAR_X := 12.6
const UPLIGHT_Y := 0.4
const UPLIGHT_DZ := 2.6

# --- Levels -----------------------------------------------------------------
## Ring key. Four fixtures on the truss corners, cross-aimed so each covers
## the far half of the mat; that overlap is what keeps the mat's luminance
## flat enough to be an exposure ANCHOR rather than a hot spot with a number
## attached.
@export var key_energy: float = 9.0
## The key fixture's emitting size, in metres, for PCSS soft shadows. A large
## truss wash or profile has a 0.3-0.4 m front lens. From 7.25 m up that
## makes a penumbra about 9 cm wide under a shoulder 1.5 m off the mat
## (0.35 x 1.5 / 5.75), and
## none at the feet: sharp where a body touches the canvas, soft away from it,
## the way broadcast footage reads.
const KEY_LIGHT_SIZE := 0.35
## The overhead fills' source size: tighter than the keys', so the pool they
## put straight under a body is dark and close, as 2K26's is
## (cody_roman_2k26.md, "In-ring match lighting").
const TOP_LIGHT_SIZE := 0.18
## Straight-down top light, and the lever the exposure anchor is solved on.
## Adds to the mat more than to a standing torso, which opens the
## mat<->wrestler gap without touching either material.
##
## 5.0 -> 24.0, re-solved after the mat took the supplied AEW canvas: that
## artwork's field is 0.636 in sRGB against the near-white it replaced, so the
## same rig rendered a much darker mat. Measured with
## tools/refs/measure_silhouette.py on forward_plus, which is the only
## renderer these numbers mean anything on:
##
##   top    mat      mat<->A   mat<->B
##   5.0    0.252     0.091     0.103
##   12.0   0.330     0.132     0.160
##   18.0   0.387     0.160     0.201
##   24.0   0.437     0.185     0.236   <- mat inside 0.43-0.49
##
## The curve compresses as it climbs the filmic shoulder (+0.078 for the first
## seven units, +0.050 for the last six), so this is solved empirically rather
## than by arithmetic on the old value.
##
## THE COMMENT ABOVE OVERSTATED ITS OWN LEVER, and the sweep is what showed
## it. "A chest's N.L is near 0" is true of a chest and not of a wrestler:
## over that range the mat gained 0.185 and wrestler A gained 0.092, so a
## figure takes about HALF the mat's share of straight-down light -- shoulders,
## heads and forearms are horizontal too. That is why the mat<->wrestler gaps
## improve here but do not reach their 0.24-0.31 band: closing them on this
## lever alone would need the mat near 0.55, outside its own. See README.
##
## 24.0 -> 36.0, re-solved again after the hard camera widened the silhouette
## shot and the key and top were cooled (KEY_COLOR below). Cooling costs
## luminance -- the eye weights green over blue -- so the mat fell to 0.370 at
## the coolest setting tried, and top energy buys it back. Measured on
## forward_plus (Vulkan, llvmpipe), with the key and top at the colours below:
##
##   top    mat      mat<->A   mat<->B
##   24.0   0.406*    0.265     0.132     * at the old warm colours
##   30.0   0.422     0.277     0.146
##   36.0   0.454     0.297     0.172   <- mat inside 0.43-0.49
##
## B's gap is still short of its band and A<->B is still over its own: at the
## hard camera's framing B faces the key bare-chested and reads twice A's
## luminance, and that is his colourway, not the rig. See README.
## 36 -> 22 and the key 9 -> 16 in the 2K26 round (lighting_2k26.md items
## 1/4), with the canvas taken to a light grey: light moved off the floor and
## onto the bodies. Measured on the gameplay and hard cameras (match_look.tscn,
## Vulkan): mat 0.65 -> 0.45, skin p75 0.24 -> 0.29 (2K26 0.31), frame above
## 0.5 from 22% -> 4-8% (2K26 7%), white balance B/G 1.09 -> 1.17 (2K26 1.16).
@export var top_energy: float = 29.0
## Cool back/rim pair.
##
## THE CLAIM BELOW IS WRONG, and it is left standing with its correction
## because it sent a round down the wrong path.
##
## It used to read: "Kept deliberately small: rim light lands on the wrestlers,
## and every unit of it CLOSES the 0.24-0.31 gap the bar wants." That is a
## sound argument and it is not what the renderer does. Measured on
## forward_plus with measure_silhouette.py, holding everything else fixed:
##
##   rim    mat      mat<->A   mat<->B
##   2.2    0.437     0.185     0.236
##   1.2    0.435     0.184     0.235
##   0.6    0.433     0.185     0.234
##
## Cutting rim by 73% moved the gaps by 0.001 -- inside noise. The fixtures are
## aimed across the ring from behind, so at the spawn standoff they rake the
## figures at a grazing angle and contribute almost nothing to a front-facing
## silhouette's mean.
##
## So it STAYS at 2.2. Spending the cool back light that separates a figure
## from a dark crowd, in exchange for 0.001 of a gap, would be paying for
## nothing. The gap was closed on the attire instead -- see match.tscn.
## Raised 2.2 -> 4.0 in the 2K26 round (item 4): the bright edge on heads and
## shoulders against the crowd is what reviewers mean by the ring "popping".
@export var rim_energy: float = 2.0
## House wash on the seating bowl. Sized against VISUAL_BAR.md's 0.014 crowd.
@export var house_energy: float = 0.20
## Entrance stage wash.
@export var stage_energy: float = 2.6
## Beam fixtures over the bowl. What they are for is the SHAFT, not the light
## that lands: see _build_beams(). Solved on art shots on forward_plus, with
## tools/refs/measure_look.py against the four AEW stills (mean saturation
## band 0.487-0.665):
##
##   energy / fog   crowd_bank sat   ring_corner dark   read
##   none           0.438            45.2%              no beams
##   6 / 6          0.438            45.2%              nothing visible
##   200 / 6        0.443            43.7%              nothing visible
##   20 / 40        0.451            42.6%              faint
##   40 / 60        0.468            41.9%              shafts read
##   60 / 120       0.493            41.2%              <- shipped
##
## The first two rows are _spot()'s 1.6 falloff over a 20m throw -- the same
## reason the house wash measures as nothing -- which is why BEAM_ATTENUATION
## exists. Dark fraction falls because the haze the beams light is in frame;
## it stays inside the references' 38-50%.
@export var beam_energy: float = 60.0

# --- Colour -----------------------------------------------------------------
## Cool key and top, cooler rim.
##
## The key used to be tungsten-ish (1.0, 0.975, 0.93) on the theory that a warm
## key against a cool rim separates a figure from its background. Measured
## against the reference with tools/refs/compare_frame.py on wide_broadcast,
## the frame read WARM: warm/cool -0.109 against the broadcast still's -0.333,
## the largest colour gap on the board, and the lit ring is most of what the
## frame's warmth was. Swept:
##
##   key / top                               warm/cool   saturation
##   (1.0, .975, .93) / (.95, .965, 1.0)      -0.109       0.273
##   (.93, .965, 1.0) / (.90, .945, 1.0)      -0.196       0.342
##   (.88, .945, 1.0) / (.86, .93, 1.0)       -0.237       0.368   <- shipped
##   (.86, .93, 1.0)  / (.84, .92, 1.0)       -0.261       0.392
##
## against a reference saturation of 0.306: cooler still overshoots it, so the
## shipped pair is where the two meet. Top energy was re-solved after this to
## put the mat back on its anchor (see top_energy).
## Cooler since the 2K26 round (lighting_2k26.md item 4): its match frames
## measure white balance B/G 1.16 against our 1.09 -- a crisp 6500 K-ish TV key.
## Neutral since the owner's full 2K26 Cody vs Roman match (cody_roman_2k26.md):
## its match frame measures mean sRGB (0.354, 0.351, 0.359), B/G 1.02 -- a
## white key, not the cool one the storyboard thumbnails suggested.
const KEY_COLOR := Color(0.98, 0.97, 0.95)
const TOP_COLOR := Color(0.97, 0.97, 0.96)
const RIM_COLOR := Color(0.84, 0.89, 1.0)
const HOUSE_COLOR := Color(0.78, 0.84, 1.0)
## The stage wash, pushed violet. Predominantly a hue change, and the figures
## in this comment used to say "only": it claimed Rec.709 luminance of the old
## (0.72, 0.74, 1.0) was 0.7581 against this colour's 0.7574, a difference of
## 0.0007. Re-measured when `test_stage_lighting.gd` was finally written, none
## of those three numbers is right:
##
##   raw sRGB components   old 0.7545   new 0.7489   diff 0.0056
##   linearised            old 0.5363   new 0.5295   diff 0.0068
##
## So the recolour moved the level by about 0.75%, not by 0.09%. It is still a
## small move and it is still dominated by the hue change, but "only the colour
## has changed" was overstated by a factor of eight.
##
## It threatens no anchor, and the reason is worth writing down rather than
## assuming: this fixture cannot reach the mat (see ACCENT_RANGE's table), so
## the level it contributes to VISUAL_BAR.md's 0.43-0.49 window is zero either
## way. `test_stage_lighting.gd` now pins the real figure, so a later recolour
## that moves the level by a lot still fails.
const STAGE_COLOR := Color(0.66, 0.75, 1.0)

## The two accent hues off the reference photographs in
## `gauntlet/refs/stage.md`: magenta on the frame-left portal, amber on the
## frame-right one. Warm and cool at the same time is the whole look -- the
## rings are the source, and these fixtures are what put their colour onto the
## deck, the slats and the backdrop so the rings read as fixtures rather than
## as glowing decals.
##
## Neither is green-dominant, which matters beyond taste: `capture_harness.gd`
## records that a green-dominant element inside the HUD corner probes blinds
## the evidence gate.
const ACCENT_MAGENTA := Color(0.92, 0.22, 0.66)
const ACCENT_AMBER := Color(1.0, 0.62, 0.24)

## RANGE IS THE SAFETY MECHANISM HERE, NOT THE AIMING.
##
## `gauntlet/refs/VISUAL_BAR.md`'s exposure anchor is the mat at 0.43-0.49
## relative luminance, and every fixture that reaches the mat spends that
## budget. The nearest mat corner to an accent fixture at (+-4.6, 6.2, -20.6)
## is 18.7m away, so a range of 12m cannot reach it by more than six metres.
##
## THAT IS TRUE OF THE ACCENTS AND THE UPLIGHTS AND NOT OF THE STAGE WASH, and
## an earlier version of this comment claimed it of "every fixture built for
## the entrance set", which was wrong. Measured over the fixtures this file
## actually builds behind the stage line:
##
##   Accent x4    range 12.0   nearest mat corner 18.68m   safe by RANGE
##   Uplight x4   range 16.0   nearest mat corner 18.97m   safe by RANGE
##   Stage x2     range 28.0   nearest mat corner 17.25m   safe by CONE ONLY
##
## The stage wash out-ranges the mat by eleven metres. What keeps it off the
## canvas is that it is aimed away: the nearest corner sits 77.5 degrees off
## its axis against a 44-degree cone. That is a real guarantee but a weaker
## and more fragile one than range, because re-aiming a fixture is a smaller
## edit than re-ranging it.
##
## `test_stage_lighting.gd` asserts the disjunction -- every stage-side fixture
## is out of range of the mat OR aimed off it -- and prints which one each
## fixture relies on, so a later fixture cannot re-introduce the spill simply
## by being added without the thought.
const ACCENT_RANGE := 12.0
@export var accent_energy: float = 3.2
@export var uplight_energy: float = 2.8

## The beam fixtures' colours, cycled around the grid. Off the four AEW stills
## in gauntlet/refs/lighting/: their saturated pixels fall at hue 210 (cyan-
## blue, 20-81% of each frame), 240 (blue, up to 64%) and 270-300 (violet and
## magenta, 30% of the wide-bowl frame). Blue twice, because it is twice as
## common. None is green-dominant, which capture_harness.gd needs.
##
## Then the owner's AEW arena still (the Dynamite set in WWE 2K): its beams
## are teal and cyan, fanning down through the haze over the stage and the
## ring, with a violet among them. Teal twice; blue still above green in
## every one.
const BEAM_COLORS: Array[Color] = [
	Color(0.16, 0.78, 0.86),
	Color(0.30, 0.62, 1.0),
	Color(0.14, 0.72, 0.80),
	Color(0.55, 0.30, 1.0),
]
## Narrow on purpose. A moving head in beam mode is a few degrees across, and a
## narrow cone puts its whole energy into a visible rod of haze rather than a
## wash nobody can see the edge of -- which is what the house wash is, and why
## it measured as nothing.
const BEAM_ANGLE := 6.0
const BEAM_FIXTURES := 16
## Short of the mat by construction: the nearest fixture on the grid is
## BOWL_INNER - 3.5 out from the ring's centre and aimed further out, so its
## cone points AWAY from the canvas; see test_arena_beams.gd.
const BEAM_RANGE := 40.0
## Distance falloff for the beams, against _spot()'s 1.6. A moving head in
## beam mode is close to collimated; at 1.6 a 20m throw delivered ~1/120 of
## the fixture and no energy that left the pools sane made a visible shaft.
const BEAM_ATTENUATION := 0.8
## How much of each beam goes into the haze rather than onto the seats. High
## because the shaft is the point and the pool is the side effect.
@export var beam_fog_energy: float = 120.0

## How many house fixtures ring the bowl. Twelve had no scallops in it while
## the bowl was a 28 x 18m ring; the plan is 111m round now, so twenty keeps
## the spacing roughly where it was. A coverage decision, not a measurement.
const HOUSE_FIXTURES := 20

## Fixture-energy gain for renderers without volumetric fog -- in practice the
## compatibility renderer, which is what Godot's Web platform falls back to.
##
## Needed because the two renderers do not accumulate this rig's 22 punctual
## lights alike, and the difference is not small. Measured with the project's
## own measure_silhouette.py on the spawn standoff, mat relative luminance
## against VISUAL_BAR.md's 0.43-0.49 anchor:
##
##   forward_plus                        0.456
##   gl_compatibility, as shipped        0.003   <- the web build's real defect
##   gl_compatibility, light limit 32    0.995   <- clipped white
##   gl_compatibility, limit 32 + 0.15   0.465
##
## TWO separate faults, found in this order, and the first one masked the
## second completely.
##
## 1. project.godot's limits/opengl/max_lights_per_object was Godot's default
##    8, and this rig builds 22. The renderer kept 8 per object and did not
##    keep the four truss keys hanging over the mat, so the mat was lit by
##    almost nothing -- 0.003, effectively black. Proved by hiding every
##    fixture except the keys and top fills: with 6 lights, under the limit,
##    the mat rendered 0.995. The fixtures and their energies were never the
##    problem. That setting is now 32, with the evidence recorded beside it.
##
## 2. With all 22 reaching the mat, the compatibility renderer over-shoots
##    instead: 0.995, clipped. Hence this gain, which scales the fixtures
##    this rig creates and nothing else.
##
## Why a gain on the fixtures rather than tonemap_exposure, since exposure was
## tried first: ArenaBuilder._house_lit leaves the bowl, crowd and video wall
## EMISSIVE, and emission crosses renderers intact. Exposure scales emissive
## and lit surfaces together, so fitting it to the mat blew the crowd and
## stage to near-white -- one measured number satisfied and the frame ruined.
## Only the lit surfaces are wrong, so only the lights are touched.
##
## forward_plus never reaches this code (the guard is the same one the fog
## volumes use), and the OpenGL light limit is a key Vulkan ignores. Both
## halves of the fix are therefore invisible to the renderer every gauntlet
## number is measured on; re-measured after the change, forward_plus still
## reports mat 0.456, gaps 0.306/0.296, wrestler<->wrestler 0.010.
##
## KNOWN LIMIT, so nobody reads more into this than it earns. At 0.15 the
## compatibility renderer reports mat<->wrestler 0.412 and 0.353 against the
## bar's 0.24-0.31: the mat's LEVEL is matched, the wrestlers still sit
## further under it than the reference. Its light response differs in kind and
## no single gain closes that. VISUAL_BAR.md:64-86 already rules
## gl_compatibility captures void for judging this bar, and that stands -- the
## web build is for playing, not for measuring.
const COMPAT_LIGHT_GAIN := 0.15

## The same gain, applied to the entrance set, is wrong -- and this is the
## measured version of why.
##
## COMPAT_LIGHT_GAIN exists for one reason: the compatibility renderer
## over-accumulates this rig's punctual lights ON THE MAT, and 0.15 is what
## puts the mat back on VISUAL_BAR.md's 0.43-0.49 anchor. The entrance set's
## fixtures cannot reach the mat at all -- they are range-limited to 12m
## against an 18.5m throw to the nearest corner, which is the guarantee
## `test_stage_lighting.gd` holds. So scaling them buys the anchor nothing and
## costs the whole set: measured on stage_wide against the same frame on
## forward_plus, the backdrop rendered at 0.13x and the crowd beside it 0.28x,
## while the mat sat at 0.99x. The set went dark to protect a number it was
## already incapable of moving.
##
## 1.0, i.e. no scaling behind the stage line. If a later fixture back there
## does start reaching the mat, the range test fails first and loudly, which
## is the order these two want to be in.
const COMPAT_STAGE_GAIN := 1.0

## Fixtures at or behind this depth are entrance-set fixtures. Chosen well in
## front of the stage (-24) and well behind the bowl's inner edge (-9), so it
## separates the two groups without sitting near either.
const STAGE_LINE_Z := -12.0


## The two looks WWE 2K26 runs (gauntlet/refs/lighting_2k26.md): a concert for
## the entrances -- the house near black, the haze full for the beams -- and a
## TV studio for the match -- the crowd lit as people, the ring haze thinned so
## the blacks stay black. MatchSetup switches at the start and at the bell.
enum Look { ENTRANCE, MATCH }
## The ring haze's share during the match (item 3, "clear the veil"): the
## in-scatter in front of the mat was a grey lift over the whole low shot.
const MATCH_RING_HAZE := 0.45
## And on the entrances: enough for the beams and the top light's cone, but the
## full density lit up by the follow spot was a white glare round the ring.
const ENTRANCE_RING_HAZE := 0.6
## The crowd shader's light (`crowd_light` global) in each look (items 2, 7).
const CROWD_LIGHT_MATCH := 3.5
const CROWD_LIGHT_ENTRANCE := 0.3
## The ring keys and top fill in the entrance look (item 7): a concert, the
## ring a pool under the rig, not the studio's even field -- and what bloomed
## Cody's coat white on the in-ring low shots (item 10).
const ENTRANCE_RING_SHARE := 0.4
## Star glints (StarGlints, item 8): full on the entrances, a trace in the
## match, where 2K26's top lights still catch the lens on low shots.
const GLINT_ENTRANCE := 1.0
## glow_hdr_threshold per look: match.tscn's 1.25 for the match; higher on the
## entrances, where the follow spot and walk key put skin and white gear over
## 1.25 and the bloom washed Cody's coat to a white shape (item 10).
const GLOW_THRESHOLD_MATCH := 1.25
const GLOW_THRESHOLD_ENTRANCE := 1.9
const GLINT_MATCH := 0.3
## Moving beams (item 9), entrance look only: each head sweeps its pan and
## tilt about its rest aim over SWEEP_BEATS beats of the music, and every beat
## kicks its level -- a decaying pulse, never a hard strobe.
const SWEEP_PAN := 0.42
const SWEEP_TILT := 0.22
const SWEEP_BEATS := 8.0
## On the crowd cutaways the beams go to work: they sweep this many times
## faster and this much wider across the stands (EntranceDirector.crowd_cut).
const CROWD_SWEEP_SPEED := 3.2
const CROWD_SWEEP_WIDTH := 1.7
## How fast the beams change between their two paces, per second.
const SWEEP_SLEW := 2.5
const PULSE_FLOOR := 0.5
const PULSE_DECAY := 5.0
## The beams' level on the entrances against the match's. They are the show,
## so the walk's house dim does not reach them (it read their pulse at 30-33
## against the match's 60: "shafts faint"); a blackout (house_dim under
## BLACKOUT_DIM) still puts them out.
const ENTRANCE_BEAM_GAIN := 1.6
const BLACKOUT_DIM := 0.2
## The stage set on the entrances (item 7): a concert stage is dark round the
## man in the follow spot. The mid-grey behind him on the stage close-ups (p50
## 0.035-0.07 against 2K26's ~0.015) was the set's house emission
## (ArenaBuilder._house_lit, its "never black" floor), which the house dim does
## not reach; it goes to ENTRANCE_SET_SHARE of itself, and the stage wash to
## ENTRANCE_STAGE_SHARE.
const ENTRANCE_SET_SHARE := 0.25
## The entrance's exposure, as a share of the match's (the tonemap exposure
## the mat's anchor was solved at). The owner: entrances "way too bright".
## Measured against 2K26's entrance storyboard (refs/lighting_2k26.md: p50
## 0.013, p90 0.225, 4% of the frame over 0.5), ours ran p50 0.08-0.26 and
## p90 0.55-0.74 once the man was lit -- the stage's LED faces, the set and
## the follow spot all a stop and more over. The concert look is a dark room
## with a few hot sources, and exposure is the one lever that takes the room
## down while the HDR sources (the wall, the pyro, the glints) still bloom.
const ENTRANCE_EXPOSURE := 0.55
## And the match's, against the same base (refs/lighting_2k26.md: 2K26's
## match frames sit at p90 0.47 with 7% of the frame over 0.5).
const MATCH_EXPOSURE := 1.25
const ENTRANCE_STAGE_SHARE := 0.35
const ENTRANCE_SET_PARTS: Array[String] = ["StageBackdrop", "EntranceStage", "PortalRecess"]
var _set_emission := {}   # StandardMaterial3D -> its own emission multiplier
var look := Look.MATCH
## The Environment's own exposure, read once: the looks scale it.
var _base_exposure := -1.0
var _ring_haze: FogMaterial
var _ring_haze_density := 0.0
var _ring_lights: Array[SpotLight3D] = []
var _stage_wash: Array[SpotLight3D] = []
## The beams' level in the match look, as a share of the entrance's.
const MATCH_BEAM_SHARE := 0.0
var _beams: Array[SpotLight3D] = []
var _beam_rest := {}     # SpotLight3D -> rest Transform3D
var _bodies := {}        # SpotLight3D -> fixture body root
var _glints: StarGlints
var _beat := 0.5
var _beat_clock := 0.0
## The sweep's own phase, integrated so a change of pace never jumps a beam,
## and the pace it is slewing to (1 = the music's, up to CROWD_SWEEP_SPEED).
var _sweep_phase := 0.0
var _sweep_pace := 1.0
var _sweep_pace_target := 1.0
## The entrance director's house dim, which the moving beams' own level
## (rewritten every frame) has to carry.
var house_dim := 1.0


func set_look(p_look: Look) -> void:
	look = p_look
	var entrance := look == Look.ENTRANCE
	if _ring_haze:
		_ring_haze.density = _ring_haze_density * (ENTRANCE_RING_HAZE if entrance else MATCH_RING_HAZE)
	RenderingServer.global_shader_parameter_set("crowd_light",
			(CROWD_LIGHT_ENTRANCE if entrance else CROWD_LIGHT_MATCH)
			* (1.0 if _supports_volumetric_fog() else COMPAT_CROWD_GAIN))
	RenderingServer.global_shader_parameter_set("glint_strength",
			GLINT_ENTRANCE if entrance else GLINT_MATCH)
	var env := _environment()
	if env:
		env.glow_hdr_threshold = GLOW_THRESHOLD_ENTRANCE if entrance else GLOW_THRESHOLD_MATCH
		if _base_exposure < 0.0:
			_base_exposure = env.tonemap_exposure
		env.tonemap_exposure = _base_exposure * (ENTRANCE_EXPOSURE if entrance else MATCH_EXPOSURE)
	for light in _ring_lights:
		var base := key_energy if String(light.name).begins_with("Key") else top_energy
		light.light_energy = base * (ENTRANCE_RING_SHARE if entrance else 1.0) * renderer_gain(light)
	for light in _stage_wash:
		light.light_energy = stage_energy * (ENTRANCE_STAGE_SHARE if entrance else 1.0) \
				* renderer_gain(light)
	_dim_set(ENTRANCE_SET_SHARE if entrance else 1.0)
	if not entrance:
		# Dark in the match. The owner's 2K26 Cody vs Roman match has no
		# coloured beam anywhere once the bell goes: the crowd is lit evenly,
		# warm-neutral, falling off toward the back rows
		# (gauntlet/refs/cody_roman_2k26.md). Left on, the teal beams parked
		# over the stage threw a blue pool across the stand behind it.
		for beam in _beams:
			beam.transform = _beam_rest[beam]
			beam.light_energy = beam_energy * MATCH_BEAM_SHARE * renderer_gain(beam)
			_pose_body(beam)


## The entrance set's house emission at `share` of its own.
func _dim_set(share: float) -> void:
	if not is_inside_tree():
		return
	if _set_emission.is_empty():
		var root := get_tree().root
		for part in ENTRANCE_SET_PARTS:
			var node := root.find_child(part, true, false) as MeshInstance3D
			var mat := node.material_override as StandardMaterial3D if node else null
			if mat and mat.emission_enabled:
				_set_emission[mat] = mat.emission_energy_multiplier
	for mat: StandardMaterial3D in _set_emission:
		mat.emission_energy_multiplier = _set_emission[mat] * share


func _environment() -> Environment:
	if not is_inside_tree():
		return null
	var we := get_tree().root.find_child("WorldEnvironment", true, false) as WorldEnvironment
	return we.environment if we else null


## The music's beat for the moving beams, and its downbeat now
## (EntranceDirector calls it on each entrance's music hit).
func sync_beat(seconds: float) -> void:
	_beat = maxf(seconds, 0.1)
	_beat_clock = 0.0
	_sweep_phase = 0.0


## The beams go fast and wide across the crowd while the camera is on it.
func crowd_sweep(on: bool) -> void:
	_sweep_pace_target = CROWD_SWEEP_SPEED if on else 1.0


## How wide the beams are sweeping, 1 at the music's pace up to
## CROWD_SWEEP_WIDTH on a crowd cutaway.
func sweep_width() -> float:
	return lerpf(1.0, CROWD_SWEEP_WIDTH,
			clampf((_sweep_pace - 1.0) / (CROWD_SWEEP_SPEED - 1.0), 0.0, 1.0))


func _move_beams(delta: float) -> void:
	_beat_clock += delta
	_sweep_pace = move_toward(_sweep_pace, _sweep_pace_target, SWEEP_SLEW * delta)
	var pulse := PULSE_FLOOR + (1.0 - PULSE_FLOOR) * exp(-PULSE_DECAY * fmod(_beat_clock, _beat) / _beat)
	var w := TAU / (_beat * SWEEP_BEATS)
	_sweep_phase += delta * w * _sweep_pace
	var width := sweep_width()
	for i in _beams.size():
		var beam := _beams[i]
		var rest: Transform3D = _beam_rest[beam]
		var pan := SWEEP_PAN * width * sin(_sweep_phase + i * 0.9)
		var tilt := SWEEP_TILT * width * sin(_sweep_phase * 0.5 + i * 1.7)
		beam.transform = Transform3D(Basis(Vector3.UP, pan) * rest.basis
				* Basis(Vector3.RIGHT, tilt), rest.origin)
		var dim := house_dim if house_dim < BLACKOUT_DIM else 1.0
		beam.light_energy = beam_energy * ENTRANCE_BEAM_GAIN * pulse * dim * renderer_gain(beam)
		_pose_body(beam)
		if _glints:
			_glints.aim(beam)


func _pose_body(light: SpotLight3D) -> void:
	var root: Node3D = _bodies.get(light)
	if root == null:
		return
	var forward := -light.transform.basis.z.normalized()
	var bases := _fixture_bases(root.basis, forward)
	for part: String in bases:
		var mi := root.get_node_or_null(part) as Node3D
		if mi:
			mi.basis = bases[part]


func _ready() -> void:
	add_to_group("arena_lighting")
	_build_ring_key()
	_build_top_fill()
	_build_rim()
	_build_house()
	_build_beams()
	_build_stage_wash()
	_build_stage_accents()
	_build_backdrop_uplights()
	_build_roof_wash()
	_build_ribbon_spill()
	_build_barricade_leds()
	_build_fog_volumes()
	_hang_fixtures()
	_apply_compat_environment()
	_compensate_for_renderer()
	for child in get_children():
		if child is SpotLight3D:
			var n := String(child.name)
			if n.begins_with("Key") or n.begins_with("Top"):
				_ring_lights.append(child)
			elif n == "StageE" or n == "StageW":
				_stage_wash.append(child)
			elif n.begins_with("Beam"):
				_beams.append(child)
				_beam_rest[child] = (child as SpotLight3D).transform
	_glints = StarGlints.new()
	_glints.name = "StarGlints"
	add_child(_glints)
	for child in get_children():
		if child is SpotLight3D:
			_glints.add_for(child)
	set_look(look)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## One spot, aimed. `look_at_from_position` needs a non-degenerate up vector,
## and a fixture pointing straight down is exactly the degenerate case, so
## the up vector is chosen off the aim direction.
func _spot(fixture_name: String, at: Vector3, aim: Vector3, color: Color,
		energy: float, angle: float, cone_falloff: float, range_m: float,
		shadows: bool) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.name = fixture_name
	var dir := (aim - at).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.999 else Vector3.BACK
	light.look_at_from_position(at, aim, up)
	light.light_color = color
	light.light_energy = energy
	light.spot_angle = angle
	light.spot_angle_attenuation = cone_falloff
	light.spot_range = range_m
	# Inverse-square-ish. Godot's default 1.0 is a 1/d falloff, which over a
	# 20m throw makes the near stands four times the far ones; 1.6 is closer
	# to how a real fixture at this distance behaves without going so steep
	# that the bowl's back rows fall off the void floor.
	light.spot_attenuation = 1.6
	light.shadow_enabled = shadows
	if shadows:
		light.shadow_bias = 0.03
		light.shadow_normal_bias = 1.5
		light.shadow_blur = 1.4
	add_child(light)
	return light


## The four truss-corner keys. Cross-aimed: the +X/+Z fixture lights the
## -X/-Z half of the mat. Straight-in aiming puts each fixture's hot spot
## directly under itself and leaves the middle of the mat as the darkest part
## of the brightest surface in frame.
func _build_ring_key() -> void:
	for sx: float in [1.0, -1.0]:
		for sz: float in [1.0, -1.0]:
			var at := Vector3(sx * KEY_OFFSET, HANG_Y, sz * KEY_OFFSET)
			var aim := Vector3(-sx * 1.35, 0.0, -sz * 1.35)
			var light := _spot("Key%s%s" % [
					"E" if sx > 0.0 else "W", "N" if sz > 0.0 else "S"],
					at, aim, KEY_COLOR, key_energy, 40.0, 0.5, 24.0, true)
			# These are the fixtures the shafts come out of.
			light.light_volumetric_fog_energy = 1.6
			# Contact-hardening shadows (refs/aaa_gap.md item 8): a truss
			# fixture's lens is a wide source, so a shadow is sharp where a
			# boot meets the mat and opens up with distance from the body.
			light.light_size = KEY_LIGHT_SIZE


## Two wide fixtures pointing straight down the ring's long axis. Their job is
## the mat's flatness. They had no shadows ("a second set of shadow maps buys
## nothing a critic can see"), and that was wrong: see below.
func _build_top_fill() -> void:
	for sz: float in [1.0, -1.0]:
		var at := Vector3(0.0, HANG_Y + 0.2, sz * TOP_OFFSET_Z)
		var light := _spot("Top%s" % ("N" if sz > 0.0 else "S"), at,
				at + Vector3(0.0, -1.0, 0.0), TOP_COLOR, top_energy,
				52.0, 0.7, 20.0, true)
		light.light_volumetric_fog_energy = 0.8
		# Soft shadows (refs/aaa_gap.md item 8). These two are the strongest
		# light on the mat, and without shadows they filled in every shadow
		# the keys cast: giving the keys PCSS alone changed nothing visible
		# (tools/probe/shadow_shot.tscn). Straight down, they give the
		# contact shadow under a body, the pool that grounds a wrestler on
		# the canvas in broadcast footage.
		light.light_size = TOP_LIGHT_SIZE
		light.shadow_blur = 1.0


## Back pair, above and behind the entrance side, raking across the ring
## toward the broadcast cam. This is the separation light: it puts a cool
## edge on the side of a wrestler the warm key cannot reach.
## On a close-up the cool back rim comes up, so the wrestler's shoulders and
## head separate from the soft crowd behind him, as in every 2K26 close-up
## (cody_roman_2k26.md). Eased, so the cut is not a light switching on.
const CLOSE_UP_RIM_GAIN := 3.5
const CLOSE_UP_RIM_RATE := 4.0
var _rim_gain := 1.0


func _light_close_ups(delta: float) -> void:
	if look != Look.MATCH or not is_inside_tree():
		return
	var cam := get_viewport().get_camera_3d() as MatchCamera
	var want := CLOSE_UP_RIM_GAIN if cam != null and cam.is_close_up() else 1.0
	if is_equal_approx(want, _rim_gain):
		return
	_rim_gain = move_toward(_rim_gain, want, CLOSE_UP_RIM_RATE * delta)
	for child in get_children():
		if child is SpotLight3D and String(child.name).begins_with("Rim"):
			(child as SpotLight3D).light_energy = rim_energy * _rim_gain


func _build_rim() -> void:
	for sx: float in [1.0, -1.0]:
		var at := Vector3(sx * RIM_X, RIM_Y, RIM_Z)
		_spot("Rim%s" % ("E" if sx > 0.0 else "W"), at,
				Vector3(-sx * 0.6, 1.15, 1.4), RIM_COLOR, rim_energy,
				30.0, 0.4, 26.0, false).light_volumetric_fog_energy = 2.2


## House wash. Fixtures at roof height around the rink, aimed outward and down
## onto the seating bowl -- which is where the hall's light has to come from
## if the stands are to stop being self-illuminated.
##
## Aimed OUTWARD on purpose: aimed inward they would spill onto the mat, and
## the mat's exposure is the one number in this file that is anchored to a
## reference measurement rather than chosen.
##
## They used to sit on a CIRCLE of radius 7.8 in the middle of the floor,
## which worked while the bowl was a 28 x 18m ring around the ring itself. The
## hall is now a rink arena: the seating on the long sides is 14m out and the
## seating at the ends is 32m out, and no circle of fixtures is the same
## distance from both. So the ring follows the hall's own plan curve, one
## fixture per equal step around it, each aimed out and down at the rows in
## front of it.
##
## This is the one place the rig calls into ArenaBuilder rather than mirroring
## a constant, and the reason is that the thing being read is a CURVE. Copying
## a number keeps a one-way dependency honest; copying a curve means copying
## the function that generates it, and two copies of that is exactly the drift
## the mirror rule exists to prevent.
func _build_house() -> void:
	var loop := ArenaBuilder._plan_loop(BOWL_INNER - HOUSE_INSET)
	for i: int in HOUSE_FIXTURES:
		var entry: Array = loop[(i * loop.size()) / HOUSE_FIXTURES]
		var at: Vector3 = entry[0] + Vector3(0.0, ROOF_Y - HOUSE_DROP, 0.0)
		var dir: Vector3 = entry[1]
		var aim: Vector3 = entry[0] + dir * 10.0 + Vector3(0.0, 2.6, 0.0)
		_spot("House%02d" % i, at, aim, HOUSE_COLOR, house_energy,
				46.0, 0.55, 34.0, false).light_volumetric_fog_energy = 0.25


## Moving heads in beam mode on the roof grid, fanned out over the bowl.
##
## This is the element of a televised AEW hall the rig did not have at all.
## Every reference still in gauntlet/refs/lighting/ carries visible shafts of
## blue, violet and magenta standing in the haze over the crowd, and they are
## most of why those frames read as lit-for-TV rather than as a sports hall
## with the lights down: 38-50% of each frame is black, and the beams are what
## cut through it.
##
## Hung on the same plan curve the house wash follows (ArenaBuilder._plan_loop)
## so the fan stays even around an obround bowl, and aimed OUT and DOWN into the
## seats, which is what keeps the canvas out of every cone.
##
## Static, not sweeping. A real moving head moves, and a sweep here would be
## cosmetic in ARCHITECTURE.md's sense -- but it would also make every capture
## frame depend on wall-clock time, and the gauntlet's measurements are only
## comparable across rounds because the frames are not.
##
## Not built on the compatibility renderer. A beam is for its shaft, and the
## shaft is volumetric fog, which that renderer does not have (see
## _build_fog_volumes). What would be left is sixteen coloured pools on the
## crowd -- and split by STAGE_LINE_Z, so half would take COMPAT_LIGHT_GAIN and
## half would not, lighting one end of the bowl seven times the other.
##
## No shadows: sixteen more shadow maps for a cone six degrees wide buys
## nothing a critic can see, and the renderer's shadow atlas is already spent
## on the ring key.
func _build_beams() -> void:
	if not _supports_volumetric_fog():
		return
	var loop := ArenaBuilder._plan_loop(BOWL_INNER - BEAM_INSET)
	for i: int in BEAM_FIXTURES:
		# Offset half a step from the house fixtures so the two sets interleave
		# rather than stacking on the same hanging points.
		var entry: Array = loop[((2 * i + 1) * loop.size()) / (2 * BEAM_FIXTURES)]
		var at: Vector3 = entry[0] + Vector3(0.0, ROOF_Y - BEAM_DROP, 0.0)
		var dir: Vector3 = entry[1]
		# Alternate a near and a far throw, so the fan crosses the bowl rather
		# than drawing sixteen parallel lines at one angle.
		var reach := 9.0 if i % 2 == 0 else 16.0
		var aim: Vector3 = entry[0] + dir * reach + Vector3(0.0, 3.0, 0.0)
		var light := _spot("Beam%02d" % i, at, aim,
				BEAM_COLORS[i % BEAM_COLORS.size()], beam_energy,
				BEAM_ANGLE, 0.2, BEAM_RANGE, false)
		light.spot_attenuation = BEAM_ATTENUATION
		light.light_volumetric_fog_energy = beam_fog_energy


## Uplights standing on the beam ring's top chord, washing the roof steel.
##
## Every AEW still shows the roof: steel lit magenta and violet from below,
## so the overhead volume reads as a coloured space the rig hangs in, not as a
## black lid. Ours was a black lid. These put colour onto
## overhead_rig.py's roof joists.
##
## Aimed UP: nothing on the floor is in any of their cones, the mat least of
## all. Same falloff as the beams, for the same reason -- a 3.5m throw at
## _spot()'s 1.6 is fine, but the far joists are 8m off.
const ROOF_WASH_FIXTURES := 12
## (The owner's AEW still: a dark, neutral roof over the rig, not a magenta
## one -- so a cool steel blue, and half the level it had.)
const ROOF_WASH_COLORS: Array[Color] = [
	Color(0.55, 0.62, 0.85),
	Color(0.45, 0.50, 0.80),
]
@export var roof_wash_energy: float = 3.0


func _build_roof_wash() -> void:
	var loop := ArenaBuilder._plan_loop(BOWL_INNER - BEAM_INSET)
	# Beam ring: hanging height + clamp + the 0.52 section, then stood on top.
	var chord_top := ROOF_Y - BEAM_DROP + FIXTURE_TOP + 0.52
	for i: int in ROOF_WASH_FIXTURES:
		var entry: Array = loop[(i * loop.size()) / ROOF_WASH_FIXTURES]
		var at: Vector3 = entry[0] + Vector3(0.0, chord_top + FIXTURE_TOP, 0.0)
		var aim: Vector3 = entry[0] - (entry[1] as Vector3) * 3.0 \
				+ Vector3(0.0, ROOF_Y, 0.0)
		var light := _spot("RoofWash%02d" % i, at, aim,
				ROOF_WASH_COLORS[i % ROOF_WASH_COLORS.size()], roof_wash_energy,
				55.0, 0.5, 14.0, false)
		light.spot_attenuation = BEAM_ATTENUATION
		light.light_volumetric_fog_energy = 0.4


# ---------------------------------------------------------------------------
# Fixture bodies
# ---------------------------------------------------------------------------

## The moving-head body `tools/blender/overhead_rig.py` builds, in four parts
## whose origin is the head's tilt axis.
const FIXTURE_MODEL := "res://assets/environment/moving_head.glb"
## The lens's emission. A lit fixture seen from in front is the hottest thing
## in a televised frame -- the references put p99 at 0.64-0.94 on a handful
## of such points -- so this is over the glow threshold on purpose. It is a
## disc 0.22m across; at any distance a camera sees it from it is a few pixels.
const LENS_LEVEL := 3.0
## How far toward white a lens reads. A lit lens is nearly white at its core
## and takes its colour at the edge; a lens emitting the pure gel colour reads
## as a painted disc.
const LENS_WHITENESS := 0.55


## A body at every light this rig built.
##
## Placed from the light, not from the steel, so no fixture can hang in the
## air: the steel is built from the same constants the lights are (see the
## "Hanging positions" block). The body is articulated like the real thing --
## base fixed to the steel, yoke panned about the vertical, head tilted inside
## it -- so the lens ends up on the beam axis without the base leaning.
##
## Fixtures aimed upward stand rather than hang (the uplights on their floor
## stands, the roof wash on top of its truss): the assembly is flipped so the
## base is below.
##
## No shadows from any of it. The SpotLight3D sits on the head's tilt axis,
## INSIDE the can, and the four ring keys cast shadows: a shadow-casting body
## would put the key's own fixture in front of it.
func _hang_fixtures() -> void:
	var packed: PackedScene = load(FIXTURE_MODEL)
	if packed == null:
		push_error("ArenaLighting: %s failed to load. Run tools/blender/build_venue.sh rig."
				% FIXTURE_MODEL)
		return
	var model: Node3D = packed.instantiate()
	var meshes := {}
	for part: String in ["FixtureBase", "FixtureYoke", "FixtureHead", "FixtureLens"]:
		var node := model.find_child(part, true, false) as MeshInstance3D
		if node == null:
			push_error("ArenaLighting: %s has no '%s'." % [FIXTURE_MODEL, part])
			model.free()
			return
		meshes[part] = node.mesh
	model.free()

	var body_mat := MaterialLibrary.resolve("arena_chair")
	var lens_mats := {}
	var lights: Array[SpotLight3D] = []
	for child in get_children():
		if child is SpotLight3D:
			lights.append(child)
	for light in lights:
		var key := light.light_color.to_html()
		if not lens_mats.has(key):
			lens_mats[key] = _lens_material(light.light_color)
		var body := _fixture_for(light, meshes, body_mat, lens_mats[key])
		add_child(body)
		_bodies[light] = body


static func _lens_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.02, 0.02, 0.02)
	mat.emission_enabled = true
	mat.emission = color.lerp(Color.WHITE, LENS_WHITENESS)
	mat.emission_energy_multiplier = LENS_LEVEL
	mat.metallic_specular = 0.0
	return mat


## One articulated body for one light. Split out so a test can build one
## against a known light and check the lens lands on its beam.
static func _fixture_for(light: SpotLight3D, meshes: Dictionary,
		body_mat: Material, lens_mat: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "Body" + String(light.name)
	root.position = light.position
	var forward := -light.transform.basis.z.normalized()
	var standing := forward.y > 0.3
	if standing:
		root.basis = Basis(Vector3.RIGHT, PI)
	var parts := _fixture_bases(root.basis, forward)
	for part: String in parts:
		var mi := MeshInstance3D.new()
		mi.name = part
		mi.mesh = meshes[part]
		mi.basis = parts[part]
		mi.material_override = lens_mat if part == "FixtureLens" else body_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	return root


## The LED ribbon boards as light sources (lighting_2k26.md item 6). In 2K26
## the ribbons throw their purple and blue onto the rows round them; ours were
## emissive art that lit nothing. Low omnis under the lower ribbon on the
## suite fascia, alternating the two hues the art is mostly made of. No
## shadows, short range: they colour the neighbouring rows and stop.
const RIBBON_SPILL_LIGHTS := 24
const RIBBON_SPILL_ENERGY := 1.4
const RIBBON_SPILL_RANGE := 6.5
const RIBBON_SPILL_COLORS: Array[Color] = [Color(0.55, 0.25, 1.0), Color(0.2, 0.45, 1.0)]


func _build_ribbon_spill() -> void:
	var suite := {}
	for row: Dictionary in ArenaBuilder._row_schedule():
		if row["kind"] == "concourse":
			suite = row
			break
	if suite.is_empty():
		return
	var loop := ArenaBuilder._plan_loop(float(suite["inner"]) - 0.6)
	var y := float(suite["tread_y"]) + 0.5
	for i: int in RIBBON_SPILL_LIGHTS:
		var entry: Array = loop[(i * loop.size()) / RIBBON_SPILL_LIGHTS]
		var light := OmniLight3D.new()
		light.name = "RibbonSpill%02d" % i
		light.position = (entry[0] as Vector3) + Vector3(0.0, y, 0.0)
		light.light_color = RIBBON_SPILL_COLORS[i % RIBBON_SPILL_COLORS.size()]
		light.light_energy = RIBBON_SPILL_ENERGY
		light.omni_range = RIBBON_SPILL_RANGE
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.0
		add_child(light)


## The barricade's faces (item 6, second half; and the owner's two AEW arena
## stills of WWE 2K's Dynamite set). As in those stills:
## * every straight run -- the two ends AND the two sides, the hard camera's
##   own among them (it was plain black) -- is LED panels end to end, the
##   owner's AEW / DYNAMITE banner (see assets/environment/CREDITS.md) across
##   each run;
## * the four cut corners carry the AEW logo, on black;
## * every other panel is plain black barrier (ringside.py's own surface).
## One low omni in front of each LED panel, in the banner's purple and blue,
## short enough to fade out at the mat's edge: the mat's exposure is the
## anchored number (VISUAL_BAR.md).
const BARRICADE_SPILL_ENERGY := 0.7
const BARRICADE_SPILL_RANGE := 3.0
## A spill shared by two adjacent long-side panels (see _build_barricade_leds).
const BARRICADE_SPILL_PAIR_GAIN := 1.3
const BARRICADE_SPILL_IN := 0.35     # light in front of the panel face
const BARRICADE_SPILL_DROP := 0.7    # light under the barricade top
const BARRICADE_WALL_ART := "res://assets/environment/materials/barricade_led_dynamite.png"
const BARRICADE_CORNER_ART := "res://assets/environment/materials/barricade_corner_aew.png"
## The corner art's width over its height (1029 x 496).
const BARRICADE_CORNER_ASPECT := 2.075
## The corner logo is printed, not lit: a touch of emission so it reads in
## the dark corners of the hall, as the stills' logos do.
const BARRICADE_CORNER_GLOW := 0.25
const BARRICADE_WALL_FOOT := 0.10    # face above the floor
const BARRICADE_WALL_HEAD := 0.09    # face below the barricade top (the rail)


func _build_barricade_leds() -> void:
	var top := ArenaBuilder.FLOOR_Y + ArenaBuilder.BARRICADE_HEIGHT
	# ringside.py's panel is 0.14 deep, centred on the line; the face sits on
	# its ring-side face.
	var inset := 0.07 + 0.004
	var h := ArenaBuilder.BARRICADE_HEIGHT - BARRICADE_WALL_FOOT - BARRICADE_WALL_HEAD
	var n := 0
	var spills := 0
	var corners := 0
	var side_panels: Array = []
	for panel: Array in ArenaBuilder.barricade_panels():
		var at: Vector3 = panel[0]
		var out: Vector3 = panel[2]
		var width: float = panel[3]
		var kind := barricade_face(panel)
		if kind == "":
			continue
		var face := MeshInstance3D.new()
		face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var quad := QuadMesh.new()
		quad.size = Vector2(width - 0.04, h)
		face.mesh = quad
		# Facing the ring, u across the art as someone in the ring reads it.
		face.transform = Transform3D(Basis(Vector3.UP.cross(-out), Vector3.UP, -out),
				at - out * inset + Vector3.UP * (ArenaBuilder.FLOOR_Y
				+ BARRICADE_WALL_FOOT + h * 0.5))
		if kind == "corner":
			face.name = "BarricadeCorner%d" % corners
			face.material_override = _corner_material((width - 0.04) / h)
			add_child(face)
			corners += 1
			continue
		face.name = "BarricadeLed%02d" % n
		var count := float(panel[6])
		face.material_override = _wall_material(Vector2(float(panel[5]) / count, 1.0 / count))
		add_child(face)
		n += 1
		if absf(out.x) > 0.99:
			# The +-X long sides (the only LED runs now) keep one spill per panel.
			_barricade_spill(n - 1, at, out, inset, top, BARRICADE_SPILL_ENERGY)
		else:
			side_panels.append(panel)
	# The long sides share spills: one omni per PAIR of adjacent panels, at the
	# midpoint, a little hotter than a single panel's. Eight more full-strength
	# omnis would have lit the mat ring (the anchored exposure) and cost eight
	# more lights for the same effect; the LED faces themselves are
	# per-panel and at the same level as the ends.
	var i := 0
	while i < side_panels.size():
		var a: Array = side_panels[i]
		var at: Vector3 = a[0]
		var energy := BARRICADE_SPILL_ENERGY
		if i + 1 < side_panels.size():
			var b: Array = side_panels[i + 1]
			var span := (a[0] as Vector3).distance_to(b[0])
			if (a[2] as Vector3).is_equal_approx(b[2]) \
					and span < ArenaBuilder.BARRICADE_PANEL * 1.5:
				at = ((a[0] as Vector3) + (b[0] as Vector3)) * 0.5
				energy = BARRICADE_SPILL_ENERGY * BARRICADE_SPILL_PAIR_GAIN
				i += 1
		_barricade_spill(n + spills, at, a[2], inset, top, energy)
		spills += 1
		i += 1


func _barricade_spill(index: int, at: Vector3, out: Vector3, inset: float,
		top: float, energy: float) -> void:
	var light := OmniLight3D.new()
	light.name = "BarricadeSpill%02d" % index
	light.position = at - out * (inset + BARRICADE_SPILL_IN) \
			+ Vector3.UP * (top - BARRICADE_SPILL_DROP)
	light.light_color = RIBBON_SPILL_COLORS[index % RIBBON_SPILL_COLORS.size()]
	light.light_energy = energy
	light.omni_range = BARRICADE_SPILL_RANGE
	light.shadow_enabled = false
	light.light_volumetric_fog_energy = 0.0
	add_child(light)


## What a barricade panel shows: "led" on the two long sides only -- the hard
## camera's (-X) and the one opposite it (+X), the panels facing +-X -- "corner"
## (the plain AEW logo) on a cut corner, and "" (plain black barrier) for the
## rest: the stage end and the announce-desk end (+-Z). The owner's call: the
## Dynamite banner repeating all the way round read wrong.
static func barricade_face(panel: Array) -> String:
	var out: Vector3 = panel[2]
	if float(panel[3]) < ArenaBuilder.BARRICADE_PANEL * 0.8 \
			and absf(out.x) > 0.5 and absf(out.z) > 0.5:
		return "corner"
	if absf(out.x) > 0.99:
		return "led"
	return ""


func _corner_material(aspect: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var tex := load(BARRICADE_CORNER_ART) as Texture2D
	mat.albedo_texture = tex
	mat.emission_enabled = true
	mat.emission = Color.BLACK
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	mat.emission_texture = tex
	mat.emission_energy_multiplier = BARRICADE_CORNER_GLOW
	mat.roughness = 0.55
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# Fitted by trimming the art's side margins, never by squashing the logo.
	var span := minf(aspect / BARRICADE_CORNER_ASPECT, 1.0)
	mat.uv1_scale = Vector3(span, 1.0, 1.0)
	mat.uv1_offset = Vector3((1.0 - span) * 0.5, 0.0, 0.0)
	return mat


func _wall_material(span: Vector2) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	# As ArenaBuilder._ribbon_material: a black face whose LEDs are the
	# whole signal, matte, at the ribbon boards' level.
	mat.albedo_color = Color(0.02, 0.02, 0.025)
	mat.emission_enabled = true
	mat.emission = Color.BLACK
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
	mat.emission_texture = load(BARRICADE_WALL_ART)
	mat.emission_energy_multiplier = ArenaBuilder.RIBBON_ART_PEAK * ArenaBuilder._emissive_gain()
	mat.roughness = 1.0
	mat.metallic_specular = 0.0
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.uv1_scale = Vector3(span.y, 1.0, 1.0)
	mat.uv1_offset = Vector3(span.x, 0.0, 0.0)
	return mat


## The yoke and head bases that point a fixture body's lens along `forward`.
## Shared with the moving beams, which re-pose their bodies every frame.
static func _fixture_bases(root_basis: Basis, forward: Vector3) -> Dictionary:
	var local := root_basis.inverse() * forward
	var yaw := 0.0
	if Vector2(local.x, local.z).length() > 0.001:
		yaw = atan2(-local.x, -local.z)
	var in_yoke := Basis(Vector3.UP, -yaw) * local
	var tilt := atan2(in_yoke.y, -in_yoke.z)
	var yoke_basis := Basis(Vector3.UP, yaw)
	return {
		"FixtureBase": Basis.IDENTITY,
		"FixtureYoke": yoke_basis,
		"FixtureHead": yoke_basis * Basis(Vector3.RIGHT, tilt),
		"FixtureLens": yoke_basis * Basis(Vector3.RIGHT, tilt),
	}


## Two fixtures over the entrance stage, cool so the stage reads as a
## different room from the ring rather than as more of the same wash.
func _build_stage_wash() -> void:
	for sx: float in [1.0, -1.0]:
		var at := Vector3(sx * STAGE_WASH_X, STAGE_WASH_Y, STAGE_BACK_Z + STAGE_WASH_DZ)
		_spot("Stage%s" % ("E" if sx > 0.0 else "W"), at,
				Vector3(sx * 2.0, 0.0, STAGE_BACK_Z + 16.0), STAGE_COLOR,
				stage_energy,
				44.0, 0.5, 28.0, false).light_volumetric_fog_energy = 1.2


## Four accents on the entrance portals, two per ring, in that ring's colour.
##
## Two per side rather than one because a single fixture puts one hot spot on
## a two-and-a-half-metre ring and leaves the rest of it flat; a pair from
## either shoulder wraps it.
##
## The fog energy is high on purpose. On forward_plus these cones are drawn
## through `HallHaze`, and the coloured shafts standing in the air around the
## portals are most of what makes the reference photographs read -- it is the
## cheapest part of this whole set and the part that carries it.
func _build_stage_accents() -> void:
	for sx: float in [-1.0, 1.0]:
		var color := ACCENT_MAGENTA if sx < 0.0 else ACCENT_AMBER
		var label := "W" if sx < 0.0 else "E"
		for i: int in 2:
			var shoulder := ACCENT_NEAR_X if i == 0 else ACCENT_FAR_X
			var at := Vector3(sx * shoulder, ACCENT_Y, STAGE_BACK_Z + ACCENT_DZ)
			var aim := Vector3(sx * ArenaBuilder.PORTAL_OFFSET_X, 3.25, STAGE_BACK_Z + 1.1)
			_spot("Accent%s%d" % [label, i], at, aim, color, accent_energy,
					34.0, 0.6, ACCENT_RANGE, false) \
					.light_volumetric_fog_energy = 2.0


## Floor-mounted washes up the perforated backdrop, two either side, each in
## its own half's accent colour.
##
## Without them the backdrop is the one large surface on the stage lit only by
## house emission, and it reads as a flat card behind a lit set -- the
## reference photographs have a wall of colour there and it is what the
## silhouettes of the set read against. Uplighting a perforated panel is also
## what makes the perforation visible at all: the grazing angle is what casts
## the texture.
##
## Placed OUTBOARD of the portals, at |x| 9.4 and 12.6. The obvious spot --
## either side of the ramp -- is inside the portal rings, whose
## outer edge is at 7.67, so a fixture there lights the inside of a ring and
## the panel behind it gets nothing. That was the first attempt and the
## backdrop stayed black.
func _build_backdrop_uplights() -> void:
	for sx: float in [-1.0, 1.0]:
		var color := ACCENT_MAGENTA if sx < 0.0 else ACCENT_AMBER
		for i: int in 2:
			var x := sx * (UPLIGHT_NEAR_X if i == 0 else UPLIGHT_FAR_X)
			var at := Vector3(x, UPLIGHT_Y, STAGE_BACK_Z + UPLIGHT_DZ)
			_spot("Uplight%s%d" % ["W" if sx < 0.0 else "E", i], at,
					Vector3(x, 10.0, STAGE_BACK_Z), color, uplight_energy,
					52.0, 0.4, 16.0, false).light_volumetric_fog_energy = 1.6


# ---------------------------------------------------------------------------
# Fog
# ---------------------------------------------------------------------------

## Two boxes of extra haze: one filling the volume between the truss and the
## mat (where the key cones are, so this is what the shafts are made of), and
## a thinner one out over the bowl so the far stands sit behind some air
## instead of reading as a wall at the same clarity as the ropes.
##
## The Environment carries a low global density as well; these only add the
## local concentration. Density values are a coverage decision -- there is no
## reference measurement of haze in gauntlet/refs/.
##
## FogVolume is forward_plus only. FogMaterial compiles a `shader_type fog`
## shader, which the compatibility renderer has no support for, so on that
## renderer every volume built here raised
##
##   ERROR: shader type fog not supported in OpenGL renderer
##      at: shader_set_code (drivers/gles3/storage/material_storage.cpp:2238)
##
## once per volume and then rendered nothing. The Web export is the case that
## matters: Godot's Web platform falls back to gl_compatibility, so the
## deployed build logged the error on every boot.
##
## Skipping the volumes there is not a downgrade of the shipping look --
## forward_plus is unaffected and every measured number was taken on it. It
## drops an error the renderer was always going to raise, for geometry it was
## always going to ignore. The hall does read flatter without the haze; that
## is a limitation of the compatibility renderer, not something to work
## around here, and README.md says so where it warns off Pages screenshots.
func _build_fog_volumes() -> void:
	if not _supports_volumetric_fog():
		return
	# Neutral and thinner than it was: 2K26's match frame has blacks at
	# p10 0.008 against our 0.019 under a blue haze (cody_roman_2k26.md).
	_fog_box("RingHaze", Vector3(0.0, 4.0, 0.0), Vector3(20.0, 9.0, 20.0),
			0.003, Color(0.85, 0.85, 0.87), 0.14)
	_fog_box("HallHaze", Vector3(0.0, 6.0, 2.0), Vector3(58.0, 15.0, 58.0),
			0.0006, Color(0.75, 0.75, 0.78), 0.05)


## Depth fog for the compatibility renderer, which is what the browser build
## runs and therefore what the Pages build looks like.
##
## The hall reads flat there because _build_fog_volumes() returns early --
## FogVolume is forward_plus only -- so the far stands sit at the same clarity
## as the ropes. Environment fog IS supported on gl_compatibility, so it can
## put air back between the ring and the crowd.
##
## THIS IS THE SECOND ATTEMPT. The first used the default EXPONENTIAL mode,
## which begins at the near plane: it tinted the mat and the wrestlers along
## with everything else, and the result was a grey wash over the whole frame
## rather than depth. It was measured, it moved numbers, and it was reverted
## because the frame was worse. What that attempt lacked is the lever below.
##
## FOG_MODE_DEPTH takes a begin distance, so the fog can be made to start
## BEYOND the ring and never touch the subjects at all:
##
##   the camera sits 3.2-9.0m from the pair's midpoint (MatchCamera's
##   min/max_distance) and the far ropes are at most 3.1m past that midpoint,
##   so no ring geometry is ever more than ~12.1m from the lens.
##
## FOG_BEGIN is 13.0, past that worst case with margin. The mat, the ropes,
## the posts and both wrestlers are outside the fog in every framing the
## HANDHELD can produce; only the barricades, the chairs and the bowl are
## inside it. That is the difference between depth and a wash.
##
## That worst case is no longer the only one. The rig covers a match from a
## hard camera 28.5m out (MatchCamera.hard_cam_position), which puts the far
## side of the ring ~32m from the lens -- nineteen metres INSIDE a fog begin
## that was written to stay outside it. A constant cannot be right for both
## shots, because 13.0 is what gives the handheld its depth and anything that
## clears the master's ring would leave the handheld's barricade unfogged.
##
## So it tracks the shot, the same way the lens does: _process sets
## fog_depth_begin to the camera's own distance plus the ring's reach, floored
## at the measured 13.0. At the handheld's 3.2-9.0m the floor wins and every
## number measured on that shot is untouched; at the master's 28.5 the ring
## falls outside the fog exactly as this note always claimed it did.
##
## fog_sky_affect is 0.0 and that is load-bearing, not tidiness: the
## background is a flat near-black (background_mode = 1) and VISUAL_BAR.md
## bands void_fraction at 0.010-0.066. Letting fog lift the void would eat
## that band directly, and lifting the void was part of what made attempt one
## read as a wash.
##
## forward_plus never reaches this code -- same guard as the fog volumes -- so
## the volumetric rig and every number measured on it are untouched. Note also
## that a headless run reports forward_plus, so THE TEST SUITE NEVER EXERCISES
## THIS PATH. It is covered by rendered frames, not by tests.
const FOG_BEGIN := 13.0
const FOG_END := 52.0
## Above 1.0 so the onset is gentle at the barricade and the density arrives
## in the upper bowl, rather than a hard edge at FOG_BEGIN.
const FOG_CURVE := 1.5
## Coverage decisions, like the volumetric densities above -- gauntlet/refs/
## measures no haze. The tint matches HallHaze's albedo so the two renderers
## disagree about technique rather than about colour.
const FOG_DENSITY := 0.45
## The ring's own reach from its centre, for the fog-begin solve above: the
## far ropes at ROPE_SPAN 3.1 plus a wrestler stood behind them.
const RING_REACH := 4.0
## The fog colour is the value distant geometry fades TOWARD, so in a dark hall
## it has to be dark. At energy 1.0 the tint below is far brighter than the
## arena and the haze ADDED light: the crowd went milky white and the near-black
## background lifted with it -- the same "wash" failure as attempt one, arrived
## at from the other direction. VISUAL_BAR.md puts the crowd at 0.014 relative
## luminance; the tint times this energy lands just under that, so far rows
## dissolve into the dark instead of glowing out of it.
const FOG_ENERGY := 0.12
const FOG_TINT := Color(0.62, 0.68, 0.86)

## Saturation grade, compatibility only.
##
## match.tscn sets adjustment_saturation 1.22, and that lift is correct -- for
## forward_plus, which compare_frame.py measures at mean_saturation 0.201
## against the reference still's 0.306. It is applied on both renderers, and
## the compatibility renderer does not need it: measured on the same fixed-park
## frame it comes out at 0.394, over the reference rather than under. The two
## renderers were being graded identically while erring in opposite directions.
##
## 1.0 is "no grade" rather than a tuned number, and it is what the arithmetic
## points at: 0.394 / 1.22 is about 0.32, within 0.02 of the reference. This
## was reported by eye first -- the browser frames looked over-saturated -- and
## the measurement agreed.
const COMPAT_SATURATION := 0.82
## The web build's fill, measured against the same match frames on Vulkan
## (scratchpad look_vk / look_gl2, the owner's "way too bright" round): once
## the ring keys kept their compatibility gain (renderer_gain), the mat sat
## on its anchor but the crowd was black silhouettes and the low ringside
## shots put the men in shadow -- this renderer has no SSIL and no
## volumetric fog to carry the bounce. More ambient, and the crowd's house
## emission up, close most of that without touching the mat.
const COMPAT_AMBIENT_GAIN := 3.0
## The crowd's share was re-measured when the stands became Rocketbox people
## (darker tees, real skin): at 6.0 the opengl3 gameplay frame's top 200 rows
## measured linear Y 0.016 against Vulkan's 0.037; 9.0 gave 0.026, 12.0 0.035.
const COMPAT_CROWD_GAIN := 12.0


## The compatibility Environment, kept so the fog's begin distance can follow
## the shot. Null on forward_plus, where none of this path runs.
var _compat_env: Environment


## Keeps the depth fog starting BEYOND the ring whichever camera is on.
##
## Cheap enough to do every frame -- one length and one assignment -- and it
## has to be every frame, because the rig cuts between a camera 3.5m out and
## one 28.5m out with no transition between them.
func _process(_delta: float) -> void:
	if look == Look.ENTRANCE and not _beams.is_empty():
		_move_beams(_delta)
	_light_close_ups(_delta)
	if _compat_env == null:
		return
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null:
		return
	var out := Vector2(camera.global_position.x, camera.global_position.z).length()
	_compat_env.fog_depth_begin = maxf(FOG_BEGIN, out + RING_REACH)


func _apply_compat_environment() -> void:
	if _supports_volumetric_fog():
		return
	var world := get_viewport().find_world_3d() if is_inside_tree() else null
	if world == null or world.environment == null:
		return
	# Duplicated rather than mutated in place: the Environment is a sub-resource
	# of match.tscn and is shared between instances of it, so writing to the
	# original would leak this renderer's settings into every other instance
	# in the process.
	var env: Environment = world.environment.duplicate()
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = FOG_BEGIN
	env.fog_depth_end = FOG_END
	env.fog_depth_curve = FOG_CURVE
	env.fog_density = FOG_DENSITY
	env.fog_light_color = FOG_TINT
	env.fog_light_energy = FOG_ENERGY
	env.fog_sun_scatter = 0.0
	env.fog_aerial_perspective = 0.0
	env.fog_sky_affect = 0.0
	env.adjustment_saturation = COMPAT_SATURATION
	env.ambient_light_energy *= COMPAT_AMBIENT_GAIN
	# The compatibility path keeps Filmic at exposure 1.0. match.tscn moved
	# to AgX at 1.7 (refs/aaa_gap.md item 10), measured on forward_plus; this
	# renderer's COMPAT_* gains were solved under Filmic, and AgX's 1.7 on top
	# of them put the mat at 0.536, over its band. Kept as calibrated rather
	# than re-solved on the renderer the game does not ship its look on.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	# gl_compatibility has no screen-space reflections, so the flag match.tscn
	# sets is inert here. Clearing it explicitly is documentation: this
	# duplicated Environment is meant to be an honest description of what that
	# renderer will actually do, and leaving a flag set that does nothing makes
	# it a worse one. The entrance deck is a low-roughness dark floor on this
	# path -- see the note beside `arena_stage_deck` in material_library.gd.
	env.ssr_enabled = false
	world.environment = env
	_compat_env = env


## Scale every fixture this rig built, on renderers that over-accumulate them.
## Runs after the _build_* calls so it catches all of them, and so a fixture
## added later is covered without having to remember this exists.
##
## Two gains, not one: the ring rig is scaled to hold the mat's exposure
## anchor, and the entrance set is left alone because it cannot reach the mat
## to disturb it. See COMPAT_STAGE_GAIN for the measurement behind that.
func _compensate_for_renderer() -> void:
	if _supports_volumetric_fog():
		return
	for child in get_children():
		if child is Light3D:
			var light: Light3D = child
			light.light_energy *= compat_gain_for_z(light.position.z)


## What `_compensate_for_renderer()` scaled `light` by: 1 on forward_plus.
##
## Every place that SETS a fixture's energy from its exported level (the
## looks, the beam chase) has to multiply this back in. They did not, and on
## the compatibility renderer -- the web build -- the first set_look() put
## the ring keys and top fill back to full: the mat rendered pure white and
## the owner played a match "way too bright".
func renderer_gain(light: Node3D) -> float:
	if _supports_volumetric_fog():
		return 1.0
	return compat_gain_for_z(light.position.z)


## Which compatibility gain a fixture at this depth takes.
##
## Split out of `_compensate_for_renderer()` so it can be asserted without a
## renderer: the loop above needs a built rig, this needs a number.
static func compat_gain_for_z(z: float) -> float:
	return COMPAT_STAGE_GAIN if z <= STAGE_LINE_Z else COMPAT_LIGHT_GAIN


## Read from RenderingServer, never from the project setting: project.godot
## reports forward_plus even during a compatibility run, which is the same
## trap ARCHITECTURE.md's capture-pipeline rule exists for.
static func _supports_volumetric_fog() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func _fog_box(fog_name: String, at: Vector3, size: Vector3, density: float,
		albedo: Color, height_falloff: float) -> void:
	var volume := FogVolume.new()
	volume.name = fog_name
	volume.shape = RenderingServer.FOG_VOLUME_SHAPE_BOX
	volume.size = size
	volume.position = at
	var material := FogMaterial.new()
	material.density = density
	material.albedo = albedo
	material.height_falloff = height_falloff
	material.edge_fade = 0.35
	volume.material = material
	add_child(volume)
	if fog_name == "RingHaze":
		_ring_haze = material
		_ring_haze_density = density
