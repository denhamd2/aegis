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

# --- Levels -----------------------------------------------------------------
## Ring key. Four fixtures on the truss corners, cross-aimed so each covers
## the far half of the mat; that overlap is what keeps the mat's luminance
## flat enough to be an exposure ANCHOR rather than a hot spot with a number
## attached.
@export var key_energy: float = 9.0
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
@export var top_energy: float = 24.0
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
@export var rim_energy: float = 2.2
## House wash on the seating bowl. Sized against VISUAL_BAR.md's 0.014 crowd.
@export var house_energy: float = 0.20
## Entrance stage wash.
@export var stage_energy: float = 2.6

# --- Colour -----------------------------------------------------------------
## Tungsten-ish key, cool fill and rim. A warm key against a cool rim is the
## oldest trick there is for separating a figure from its background, and it
## costs nothing in luminance -- which matters here, because luminance is the
## budget the bar spends.
const KEY_COLOR := Color(1.0, 0.975, 0.93)
const TOP_COLOR := Color(0.95, 0.965, 1.0)
const RIM_COLOR := Color(0.66, 0.78, 1.0)
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

## How many house fixtures ring the bowl. Twelve had no scallops in it while
## the bowl was a 28 x 18m ring; the plan is 111m round now, so twenty keeps
## the spacing roughly where it was. A coverage decision, not a measurement.
const HOUSE_FIXTURES := 20

# --- The beams --------------------------------------------------------------
## The effect `gauntlet/refs/lighting/` is carried by, and the one thing in
## those four photographs this rig had no answer to at all.
##
## What is being built: hard, narrow, saturated cyan-blue shafts thrown from
## the overhead grid out across the seating bowl, crossing each other over the
## crowd. They are moving-head beam fixtures cutting hall haze. They are not a
## wash, they are not the ring key, and -- this is the part that makes them
## safe -- they never touch the mat.
##
## Every other fixture in this file is defined by where its light LANDS. A beam
## is defined by the air it crosses on the way, which is why `beam_energy` and
## `beam_fog_energy` are separate exports: the first is what it does to the
## seats at the far end, the second is the shaft itself, and tuning wants to
## move them in opposite directions.

## Where they hang. `tools/blender/entrance_set.py:build_truss()` lays
## four-chord lattices on x and z in {-7.5, -2.5, 2.5, 7.5}, each running to
## +-11.0, so every point on the square |x| = 7.5 or |z| = 7.5 sits on a real
## outer chord. A fixture anywhere else on that square would be hanging from
## nothing, which is the defect the truss was modelled to avoid.
const BEAM_HANG_XZ := 7.5
## The chords' half-length, so the test can say a beam is ON one rather than
## merely on the square its corners describe.
const TRUSS_REACH := 11.0
## Bearings walked on the plan loop. Twelve, of which the two aimed into the
## entrance-set gap are dropped -- see the builder.
const BEAM_PICKS := 12
## How far round the loop a beam lands from the bearing it hangs on: 8 indices
## of 96, i.e. 30 degrees. This is the cross-aim, and it is the same idea as
## `_build_ring_key()`'s for the same reason -- aimed straight out, twelve
## beams are twelve radii and nothing crosses anything. Crossing is most of
## what the reference frames show.
const BEAM_CROSS := 8
## Where they land: the plan curve this far outside the bowl's first row, i.e.
## the mid-upper rake. Nearer and the shafts are too short to read; further and
## they leave the haze.
const BEAM_TARGET_OFFSET := 16.0
## Height of the aim point. The rake is deliberately shallow -- about 7 degrees
## below horizontal over a 35m throw -- because a beam that dives at the crowd
## is a follow spot. The reference shafts cross the upper third of the frame
## nearly flat, which is what a fixture hung at 7.25m and aimed at the far side
## of a 111m bowl does.
const BEAM_TARGET_Y := 2.5
## Godot's `spot_angle` is the HALF-angle, so this is a 7-degree cone.
##
## THE REFERENCE IS NARROWER THAN THIS AND CANNOT BE BUILT. Measured off
## `aew_grand_slam_broadcast.png` the shafts read 0.3-0.5m wide over a 30m
## throw -- 2 to 4 degrees total, which is a beam mover. Godot's volumetric fog
## is a froxel grid: `match.tscn` runs `volumetric_fog_length 64.0` over the
## default 64-deep volume, which is roughly 0.54m of world per froxel at 30m.
## A reference-accurate shaft is narrower than one froxel and renders as a grey
## smudge or as nothing.
##
## 3.5 is the narrowest half-angle that still spans several froxels at the
## median throw. THE LEVER FOR GETTING CLOSER IS NOT A SMALLER ANGLE -- it is
## `rendering/environment/volumetric_fog/volume_size` and `volume_depth` in
## project.godot, and that is a frame-cost decision no measurement taken in
## this container may be used to defend (ARCHITECTURE.md's renderer rule).
const BEAM_ANGLE := 3.5
## Angular falloff. LOW IS HARD HERE, and that is the opposite of the reading
## the parameter's name invites.
##
## Godot's forward shader computes
##
##     spot_rim = (1.0 - cos_angle) / (1.0 - spot_cutoff)
##     attenuation *= 1.0 - pow(spot_rim, light_data.inv_spot_attenuation)
##
## and `inv_spot_attenuation` is 1.0 / spot_angle_attenuation. So a SMALL
## parameter is a LARGE exponent, which holds the cone flat to its edge and
## then drops -- a hard edge. The washes in this file sit at 0.4-0.7 because a
## wash wants the feather. A beam is the opposite object: its edge is the whole
## read.
##
## This was checked on rendered frames rather than trusted, because getting it
## backwards fails silently -- every test still passes and the beams simply
## come out as soft cones.
##
## THE A/B WAS INCONCLUSIVE AND THAT IS WORTH RECORDING. Rendered at 0.25 and
## at 3.0 with everything else held, crowd_bank measured p50 0.0204 both times
## and mean saturation 0.301 against 0.298 -- a difference inside noise,
## because at the energies in force at the time NEITHER produced a visible
## shaft. The 0.003 of saturation leans the way the shader formula predicts
## and that is all it does. 0.25 is kept on the formula's authority, not on a
## measurement, and a later round with the energies now in this file could
## settle it properly.
const BEAM_CONE_FALLOFF := 0.25
## Distance falloff, against `_spot()`'s 1.6 default. That default is defended
## there for fixtures whose job is a wash over a 20m throw. A beam fixture is
## collimated and has to still be hot 40m out: at 0.45 a 35m hit keeps about
## half the near intensity, at 1.6 it keeps a ninth, and a shaft that dies
## before it crosses anything is not a shaft.
const BEAM_ATTENUATION := 0.45
## The longest throw this layout produces is 41.0m (the two beams aimed down
## the length of the hall), so the range has to clear it or the shaft stops in
## mid-air short of its target.
const BEAM_RANGE := 44.0
## Measured off `gauntlet/refs/lighting/`, not chosen.
##
## Blue-dominant saturated pixels in the top third of the two frames whose
## beams are actually cyan (`aew_elevated_blue_beams.jpg`,
## `aew_grand_slam_broadcast.png`), averaged and normalised so B = 1.0:
##
##   elevated, blue beams   (0.312, 0.484, 1.0)   hue 225   sat 0.69
##   Grand Slam broadcast   (0.245, 0.542, 1.0)   hue 216   sat 0.76
##
## The mean of those two. The other two references are the magenta shows and
## are what a later colourway would sample; they are not mixed in here.
##
## This is the HUE, not the level. The shaft's core clips toward white through
## energy x fog energy and the Environment's `glow_hdr_threshold` of 1.25,
## which is what makes it read as hot -- so the colour is NOT pre-whitened to
## get there. Doing that produces a pale shaft that never clips.
const BEAM_COLOR := Color(0.28, 0.51, 1.0)
## What a beam does to the seats it lands on.
##
## SOLVED ON FRAMES, and the first guess was wrong by most of an order of
## magnitude. 5.0 x 4.0 was reasoned from the stage accents, which read well at
## 3.2 x 2.0 through the global density alone -- but those shafts are three
## metres long and a few metres from the lens, and these are forty metres long
## and thirty metres away. Rendered, 5.0/4.0 produced no visible shaft at all:
## crowd_bank's p99 went DOWN 0.4434 to 0.4420 and mean saturation moved 0.005.
## A reader looking at that frame would have concluded the rig was broken.
##
##   energy  fog   crowd_bank p50   mean sat   what the frame shows
##   5.0     4.0   0.0204          0.301      nothing
##   40.0    40.0  0.0243          0.368      shafts, and hot ovals where they land
##   14.0    80.0  0.0235          0.359      shafts, pools reading as lit crowd
##
## The middle row is why these are two exports and not one number. At 40/40 the
## far-end pools were the brightest thing in the bowl -- blue discs on the
## seating with a shaft arriving at them. Dropping the fixture's own energy to
## 14 and putting the difference into scatter keeps the shaft and lets the pool
## fall back to what the reference photographs actually show, which is a patch
## of crowd lit by a beam rather than a lamp pointed at some seats.
@export var beam_energy: float = 14.0
## The shaft itself. Separate from the above on purpose: if the far-end pools
## read as hot ovals on the stands, this is the one to raise and `beam_energy`
## is the one to drop. That is not hypothetical -- it is the 40/40 to 14/80
## move in the table above.
##
## A coverage decision with no reference behind it. `gauntlet/refs/` measures
## haze nowhere, and this number is meaningless on its own: what it multiplies
## is `HallHaze`'s density, so the two move together and neither can be read
## without the other.
@export var beam_fog_energy: float = 200.0

## Fixture-energy gain for renderers without volumetric fog -- in practice the
## compatibility renderer, which is what Godot's Web platform falls back to.
##
## Needed because the two renderers do not accumulate this rig's punctual
## lights alike, and the difference is not small.
##
## THE COUNT IN THIS COMMENT WAS 22 AND WAS STALE, which matters because 22 is
## what the limit below was raised to 32 against. The rig builds 38 on
## gl_compatibility -- 4 key, 2 top, 2 rim, 20 house, 2 stage, 4 accent, 4
## uplight -- and 48 on forward_plus, where the ten truss beams are added. It
## was 22 when HOUSE_FIXTURES was 12 and the accents and uplights did not
## exist. 32 is still the right OpenGL value, and it is right for a reason the
## old number could not have given: the beams, which are what would have burst
## it, are not built on that renderer at all. Measured with the project's
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


func _ready() -> void:
	_build_ring_key()
	_build_top_fill()
	_build_rim()
	_build_house()
	_build_truss_beams()
	_build_stage_wash()
	_build_stage_accents()
	_build_backdrop_uplights()
	_build_fog_volumes()
	_apply_compat_environment()
	_compensate_for_renderer()


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
			var at := Vector3(sx * 3.9, HANG_Y, sz * 3.9)
			var aim := Vector3(-sx * 1.35, 0.0, -sz * 1.35)
			var light := _spot("Key%s%s" % [
					"E" if sx > 0.0 else "W", "N" if sz > 0.0 else "S"],
					at, aim, KEY_COLOR, key_energy, 40.0, 0.5, 24.0, true)
			# These are the fixtures the shafts come out of.
			light.light_volumetric_fog_energy = 1.6


## Two wide fixtures pointing straight down the ring's long axis. No shadows:
## their job is the mat's flatness, and a second set of shadow maps buys
## nothing a critic can see.
func _build_top_fill() -> void:
	for sz: float in [1.0, -1.0]:
		var at := Vector3(0.0, HANG_Y + 0.2, sz * 2.1)
		_spot("Top%s" % ("N" if sz > 0.0 else "S"), at,
				at + Vector3(0.0, -1.0, 0.0), TOP_COLOR, top_energy,
				52.0, 0.7, 20.0, false).light_volumetric_fog_energy = 0.8


## Back pair, above and behind the entrance side, raking across the ring
## toward the broadcast cam. This is the separation light: it puts a cool
## edge on the side of a wrestler the warm key cannot reach.
func _build_rim() -> void:
	for sx: float in [1.0, -1.0]:
		var at := Vector3(sx * 6.4, 6.9, -7.2)
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
	var loop := ArenaBuilder._plan_loop(BOWL_INNER - 1.5)
	for i: int in HOUSE_FIXTURES:
		var entry: Array = loop[(i * loop.size()) / HOUSE_FIXTURES]
		var at: Vector3 = entry[0] + Vector3(0.0, ROOF_Y - 1.4, 0.0)
		var dir: Vector3 = entry[1]
		var aim: Vector3 = entry[0] + dir * 10.0 + Vector3(0.0, 2.6, 0.0)
		# 0.25 -> 0.08. Twenty fixtures aimed outward into HallHaze, whose
		# density nearly doubled for the beams: at the new figure the old fog
		# energy turns the whole bowl into a general blue glow, which is the
		# opposite of what a beam needs behind it. It costs nothing visible --
		# `gauntlet/refs/lighting.md`'s ablation shows this wash does not reach
		# the stands at all -- and it buys back the contrast the shafts read
		# against.
		_spot("House%02d" % i, at, aim, HOUSE_COLOR, house_energy,
				46.0, 0.55, 34.0, false).light_volumetric_fog_energy = 0.08


## The truss beams: hard cyan shafts thrown out across the bowl.
##
## NOT BUILT ON gl_compatibility, and the guard is doing more work here than
## the one in `_build_fog_volumes()` does.
##
## 1. A beam fixture with no FogVolume to scatter through is not a beam. It is
##    a seven-degree pool of blue on some seats forty metres away -- an effect
##    that only ever existed in the air, rendered as the one part of itself
##    that was never the point.
## 2. `project.godot`'s `limits/opengl/max_lights_per_object` is 32, and it was
##    raised to that against a measured failure (see COMPAT_LIGHT_GAIN) where
##    the renderer dropped the truss keys and rendered the mat at 0.003. The
##    house wash already puts this rig near that ceiling on the ring. Ten more
##    fixtures originating eight metres from the mat would re-trigger exactly
##    that fault, and the fix is not a bigger limit -- it is not building
##    fixtures that renderer cannot show.
## 3. It means `_compensate_for_renderer()` never sees a beam. That is true by
##    construction rather than by assertion, which is why it is written down.
##
## forward_plus is unaffected and every measured number is taken there.
##
## PLACEMENT. The origins come off the truss and the targets come off the
## bowl, and they are two different curves -- which is the whole reason this
## function is longer than the other builders.
##
##   * targets walk `ArenaBuilder._plan_loop()`, the hall's own obround, 16m
##     outside the bowl's first row. Copying the function rather than a number
##     is the rule `_build_house()` sets out: a number can be mirrored, a curve
##     has to be called.
##   * origins are where the target's BEARING crosses the truss square, so
##     every fixture lands on a modelled outer chord and hangs 0.35m under the
##     lattice exactly as the keys do.
##
## Two of the twelve are dropped: their targets fall in the entrance-set gap,
## where `ArenaBuilder._in_stage_gap()` says there is no seating to light and
## the reference photographs show the stage instead of a crowd. Ten survive,
## and they are mirror-symmetric about x = 0 -- which is not arranged, it falls
## out of dropping a symmetric pair from a symmetric walk.
func _build_truss_beams() -> void:
	if not _supports_volumetric_fog():
		return
	var loop := ArenaBuilder._plan_loop(BOWL_INNER + BEAM_TARGET_OFFSET)
	for i: int in BEAM_PICKS:
		var hang_index := (i * loop.size()) / BEAM_PICKS
		var aim_index := (hang_index + BEAM_CROSS) % loop.size()
		var target: Vector3 = loop[aim_index][0]
		if ArenaBuilder._in_stage_gap(target):
			continue
		var hang: Vector3 = loop[hang_index][0]
		var bearing := Vector3(hang.x, 0.0, hang.z).normalized()
		# Scale the bearing until it meets the truss square, i.e. until whichever
		# of |x| and |z| is larger reaches BEAM_HANG_XZ. That is the chord.
		var to_chord := BEAM_HANG_XZ / maxf(absf(bearing.x), absf(bearing.z))
		var at := bearing * to_chord + Vector3(0.0, HANG_Y, 0.0)
		var aim := Vector3(target.x, BEAM_TARGET_Y, target.z)
		var light := _spot("Beam%02d" % i, at, aim, BEAM_COLOR, beam_energy,
				BEAM_ANGLE, BEAM_CONE_FALLOFF, BEAM_RANGE, false)
		# `_spot()` hardcodes 1.6 and six other fixture families are tuned
		# against it, so it is overridden here rather than parameterised.
		light.spot_attenuation = BEAM_ATTENUATION
		# A specular hit from a beam on a wrestler's shoulder is the one way a
		# cone that never touches the mat could still move
		# `measure_silhouette.py`, which is the measurement this whole rig is
		# range- and cone-limited to protect.
		light.light_specular = 0.0
		light.light_volumetric_fog_energy = beam_fog_energy


## Two fixtures over the entrance stage, cool so the stage reads as a
## different room from the ring rather than as more of the same wash.
func _build_stage_wash() -> void:
	for sx: float in [1.0, -1.0]:
		var at := Vector3(sx * 4.2, 10.0, STAGE_BACK_Z + 21.0)
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
			var shoulder := 2.1 if i == 0 else 4.6
			var at := Vector3(sx * shoulder, 6.2, STAGE_BACK_Z + 3.4)
			var aim := Vector3(sx * 3.3, 3.25, STAGE_BACK_Z + 1.1)
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
## Placed OUTBOARD of the portals, at |x| 7.6 and 11.5. The obvious spot --
## either side of the ramp at |x| 5.4 -- is inside the portal rings, whose
## outer edge is at 5.97, so a fixture there lights the inside of a ring and
## the panel behind it gets nothing. That was the first attempt and the
## backdrop stayed black.
func _build_backdrop_uplights() -> void:
	for sx: float in [-1.0, 1.0]:
		var color := ACCENT_MAGENTA if sx < 0.0 else ACCENT_AMBER
		for i: int in 2:
			var x := sx * (7.6 if i == 0 else 11.5)
			var at := Vector3(x, 0.4, STAGE_BACK_Z + 2.6)
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
	_fog_box("RingHaze", Vector3(0.0, 4.0, 0.0), Vector3(20.0, 9.0, 20.0),
			0.005, Color(0.80, 0.84, 0.95), 0.14)
	# HallHaze was a 58 x 15 x 58 box at (0, 6, 2) -- x +-29, z -27..31 -- and
	# that was big enough for its old job of putting air behind the far stands.
	# It is not big enough for the job it has now.
	#
	# `_build_truss_beams()` aims at the plan curve 16m outside the bowl's
	# first row, which reaches z +-48 at the ends of an obround this long. More
	# than half of every end-aimed shaft used to fall OUTSIDE the only volume
	# that can make it visible, and a beam that fades out halfway across the
	# hall is worse than no beam: it reads as a rendering fault rather than as
	# a fixture.
	#
	# 78 x 104 covers the seated rake on both axes (the last row sits at x
	# +-36.2, z +-53.7) and lets the shell edge fall off. The height band is y
	# -1 to 13: the truss at 7.25 down to the floor, and up to the upper tier's
	# back rows at 13.2.
	#
	# Density stays at roughly what it was -- 0.0012 -> 0.0010 -- and that is
	# the opposite of where this went first.
	#
	# The obvious move was to raise it to 0.0022, since a shaft's brightness is
	# density times the fixture's `light_volumetric_fog_energy`. Rendered, it
	# cost more than it bought: density scatters EVERY light in the hall, so
	# the denser haze lit the whole bowl and crowd_bank's fraction below 0.01
	# relative luminance went from 10.8% to 5.1%, away from the references'
	# 38-50%. The haze was undoing the darkening it was committed alongside.
	#
	# Fog energy scatters ONE fixture. So the density comes back down and
	# `beam_fog_energy` carries the shafts instead. Same beams, a darker hall
	# behind them, and the two knobs are no longer fighting.
	#
	# ONE BOX, NOT TWO. Overlapping FogVolumes sum their densities, so a second
	# volume over this one would make a hazy frame un-attributable to any
	# single number. A `RoofHaze` above the truss was considered and declined
	# for the same reason plus a simpler one: every shaft this rig builds lives
	# between y 7.25 and y 2.5, entirely inside the box below. It becomes the
	# right idea only if a later set is aimed UP into the roof steel, which is
	# the other thing `aew_grand_slam_broadcast.png` shows.
	_fog_box("HallHaze", Vector3(0.0, 6.0, -2.0), Vector3(78.0, 14.0, 104.0),
			0.0010, Color(0.62, 0.68, 0.86), 0.05)


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


## The compatibility Environment, kept so the fog's begin distance can follow
## the shot. Null on forward_plus, where none of this path runs.
var _compat_env: Environment


## Keeps the depth fog starting BEYOND the ring whichever camera is on.
##
## Cheap enough to do every frame -- one length and one assignment -- and it
## has to be every frame, because the rig cuts between a camera 3.5m out and
## one 28.5m out with no transition between them.
func _process(_delta: float) -> void:
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
