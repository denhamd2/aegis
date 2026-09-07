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
## ArenaBuilder.ROOF_Y / BARRICADE_RADIUS.
const ROOF_Y := 14.0
const BOWL_INNER := 9.0

# --- Levels -----------------------------------------------------------------
## Ring key. Four fixtures on the truss corners, cross-aimed so each covers
## the far half of the mat; that overlap is what keeps the mat's luminance
## flat enough to be an exposure ANCHOR rather than a hot spot with a number
## attached.
@export var key_energy: float = 9.0
## Straight-down top light. Adds to the mat far more than to a standing
## torso (a floor's N.L is 1.0 under it, a chest's is near 0), which is the
## lever that opens the mat<->wrestler gap without touching either material.
@export var top_energy: float = 5.0
## Cool back/rim pair. Kept deliberately small: rim light lands on the
## wrestlers, and every unit of it CLOSES the 0.24-0.31 gap the bar wants.
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
const STAGE_COLOR := Color(0.72, 0.74, 1.0)

## How many house fixtures ring the bowl. Twelve is enough that the wash has
## no scallops at bowl distance; a coverage decision, not a measurement.
const HOUSE_FIXTURES := 12

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


func _ready() -> void:
	_build_ring_key()
	_build_top_fill()
	_build_rim()
	_build_house()
	_build_stage_wash()
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


## House wash. Twelve fixtures on a ring at roof height, aimed outward and
## down onto the seating bowl -- which is where the hall's light has to come
## from if the stands are to stop being self-illuminated.
##
## Aimed OUTWARD on purpose: aimed inward they would spill onto the mat, and
## the mat's exposure is the one number in this file that is anchored to a
## reference measurement rather than chosen.
func _build_house() -> void:
	var radius := BOWL_INNER - 1.2
	for i: int in HOUSE_FIXTURES:
		var a := TAU * float(i) / float(HOUSE_FIXTURES)
		var dir := Vector3(sin(a), 0.0, cos(a))
		var at := dir * radius + Vector3(0.0, ROOF_Y - 1.4, 0.0)
		var aim := dir * (BOWL_INNER + 9.0) + Vector3(0.0, 1.6, 0.0)
		_spot("House%02d" % i, at, aim, HOUSE_COLOR, house_energy,
				46.0, 0.55, 34.0, false).light_volumetric_fog_energy = 0.25


## Two fixtures over the entrance stage, cool so the stage reads as a
## different room from the ring rather than as more of the same wash.
func _build_stage_wash() -> void:
	for sx: float in [1.0, -1.0]:
		var at := Vector3(sx * 4.2, 10.0, -17.0)
		_spot("Stage%s" % ("E" if sx > 0.0 else "W"), at,
				Vector3(sx * 2.0, 0.0, -22.0), STAGE_COLOR, stage_energy,
				44.0, 0.5, 28.0, false).light_volumetric_fog_energy = 1.2


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
	_fog_box("HallHaze", Vector3(0.0, 6.0, 2.0), Vector3(58.0, 15.0, 58.0),
			0.0012, Color(0.62, 0.68, 0.86), 0.05)


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
## camera can produce; only the barricades, the chairs and the bowl are
## inside it. That is the difference between depth and a wash.
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
	world.environment = env


## Scale every fixture this rig built, on renderers that over-accumulate them.
## Runs after the _build_* calls so it catches all of them, and so a fixture
## added later is covered without having to remember this exists.
func _compensate_for_renderer() -> void:
	if _supports_volumetric_fog():
		return
	for child in get_children():
		if child is Light3D:
			child.light_energy *= COMPAT_LIGHT_GAIN


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
