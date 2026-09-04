extends RefCounted
class_name MaterialLibrary
## One place that turns a stable name into a fully-configured
## `StandardMaterial3D`.
##
## Every builder in the project -- the arena, the ring, props -- asks for a
## material by name here instead of newing a `StandardMaterial3D` and typing
## an albedo colour into it. That is what makes "material believability"
## (`gauntlet/refs/VISUAL_BAR.md` priority 3) a property one file owns rather
## than a property scattered across every scene.
##
## ## Public API
##
##     MaterialLibrary.resolve(key)                  -> StandardMaterial3D
##     MaterialLibrary.resolve(key, overrides)       -> StandardMaterial3D
##     MaterialLibrary.house_compensate(mat)         -> StandardMaterial3D
##     MaterialLibrary.keys()                        -> PackedStringArray
##     MaterialLibrary.has(key)                      -> bool
##     MaterialLibrary.spec(key)                     -> Dictionary (read-only copy)
##
## `resolve()` returns a **fresh material every call** -- callers may mutate
## what they get back without poisoning anyone else's copy. Loaded textures
## *are* shared, because `load()` caches, so asking for twenty materials off
## one asset costs one set of textures.
##
## `overrides` is an optional Dictionary; any key in `SPEC_DEFAULTS` may be
## overridden per call. The common ones:
##
##     tint            Color   multiplies the albedo map. This is where a
##                             measured luminance relationship lives.
##     tile_metres     float   real-world size the texture tile represents.
##                             uv1_scale is derived from it, so texel density
##                             is consistent between materials by construction.
##                             ASSUMES UVs IN WORLD METRES -- see the ring
##                             block in SPECS if the mesh is a primitive.
##     roughness       float   scalar multiplying the roughness map.
##     metallic        float   0.0 or 1.0. Asserted, not clamped.
##     albedo_map      bool    false = take the asset's normal/roughness/AO
##                             but not its colour, so the tint is the value.
##     preserve_albedo_mean
##                     bool    hold the rendered mean at the tint, for a
##                             surface whose value something else measures.
##     house_lit       bool    emission carries the albedo map (see below).
##     normal_scale    float
##
## ## The named materials
##
## Ring (call these from `core/ring/ring_builder.gd`):
##
##     ring_canvas  ring_apron  ring_rope  ring_post  ring_post_chrome
##     ring_turnbuckle_pad  ring_steel
##
## Arena hall (called from `core/arena/arena_builder.gd`):
##
##     arena_floor  arena_barricade  arena_bowl  arena_stage_deck
##     arena_stage_backdrop  arena_shell  arena_truss  arena_tunnel
##     arena_screen
##
## `ALIASES` keeps older names (`ring_mat`, `ring_pad`) working.
##
## ### Names are a contract
##
## The keys below are consumed by other scenes and other agents' builders.
## Add keys freely; do not rename or repurpose one without updating every
## caller, because a missing key is a hard error (`resolve` asserts) rather
## than a silent flat-grey fallback -- a silent fallback is exactly how a
## scene ends up looking untextured and nobody notices.
##
## ## PBR correctness, enforced here rather than remembered per scene
##
## - `metallic` is **0.0 or 1.0**, never in between. A mid-range metalness is
##   not a material, it is two materials averaged: it has neither a
##   dielectric's white specular nor a conductor's tinted one. `_build()`
##   asserts it. (The ring posts shipped at 0.3, which is what prompted the
##   assert rather than a comment.)
## - `roughness` stays inside **0.30-0.90**. Below 0.3 a surface mirrors, and
##   with no radiance map in this scene a mirror renders black; above 0.9
##   there is no specular lobe left to catch a highlight. Two of the scanned
##   roughness maps ran outside that window, so they were linearly rebanded
##   at import (`*_RoughnessBand.png` -- see the CREDITS.md beside them).
## - `specular` is 0.5 for every dielectric, i.e. F0 = 4%, which is what
##   Godot's 0.5 default means. Conductors ignore it.
## - A colour map is the only map imported as sRGB; normal, roughness, AO and
##   metalness are linear data. `fetch_cc0.py` writes a `.import.hint.json`
##   next to each file recording which, and this file plugs each map into the
##   slot that samples it correctly.
## - Mipmaps are **on** for every map (`.import`: `mipmaps/generate=true`) and
##   filtering is anisotropic. Without mipmaps a tiled floor at a grazing
##   angle aliases into shimmer, which is not detail even though an edge
##   detector counts it as some.
##
## ## House lighting
##
## `ArenaBuilder` lights the hall from its materials rather than from lights
## aimed at the stands (see `_house_lit()` there -- that function, and the
## `HOUSE_TARGET`/`AMBIENT_RETURN` constants behind it, are a lighting
## concern and this file does not own them).
##
## What this file owns is that the house light is not *flat*. Emission is
## unlit by definition, so a hall surface whose emission is a single colour
## renders as a single colour and its albedo map is invisible -- which is the
## mechanism behind the arena reading as untextured boxes no matter how good
## the textures on it were. Materials marked `house_lit` therefore carry
## `emission_texture = albedo map` with `EMISSION_OPERATOR_MULTIPLY`, so the
## house light picks up the surface's own variance.
##
## Multiplying by a map whose mean is not 1.0 would also drag the house
## *level* down, and that level is the exposure anchor a different slice is
## solving. `house_compensate()` divides it back out: call it on a material
## after the emission energy has been set, and the mean rendered level is
## preserved to within the map's own mean. Composition, not entanglement --
## `ArenaBuilder._house_lit()` is untouched.

const MAT_DIR := "res://assets/environment/materials/"

## Ceiling on `preserve_albedo_mean`'s compensation. Albedo above 1.0 is
## deliberate there -- the tint is a multiplier on a map, not a colour anyone
## sees on its own -- but an unbounded gain against a dark map produces a
## surface that clips wherever the map is light, which is how a ring skirt
## became a white band across the bottom of the frame.
const MAX_ALBEDO_GAIN := 2.2

## Defaults every spec is merged over. Keeping the whole shape in one place
## is what lets `resolve(key, overrides)` accept any of these per call.
const SPEC_DEFAULTS := {
	"asset": "",              # ambientCG asset id; "" = untextured
	"suffix": "_1K-PNG_",     # between asset id and map role in the filename
	"tint": Color(1, 1, 1),
	"tile_metres": 1.0,       # real-world metres one texture tile covers
	"roughness": 1.0,         # scalar; multiplies the roughness map
	"metallic": 0.0,          # 0.0 or 1.0. Asserted.
	"specular": 0.5,          # dielectric F0 = 4%. Conductors ignore it.
	"normal_scale": 1.0,
	"ao_light_affect": 1.0,
	"house_lit": false,
	"cull_back": true,
	## Hold the *rendered* mean at the tint rather than at tint x map.
	##
	## An albedo map multiplies the tint, so a map whose mean linear value is
	## 0.49 renders a surface at 49% of the luminance its tint names. That is
	## fine for a hall wall and not fine for the ring canvas: VISUAL_BAR.md's
	## whole silhouette table is anchored on the mat's measured luminance, and
	## `measure_silhouette.py` reads it off rendered pixels. With this set the
	## tint is divided by the map's mean, so adding a weave changes the mat's
	## texture and not its value. The tint can end up above 1.0 -- that is
	## deliberate and safe, because it is only ever seen multiplied by a map
	## whose mean brings the product back down.
	##
	## The gain is capped (see `MAX_ALBEDO_GAIN`), which a blown-out preview
	## forced: the apron's map has a linear mean of 0.11, so dividing by it
	## asked for an albedo of 4.9-7.2 and the apron rendered as a white band
	## along the bottom of the frame (p95 0.629 against a reference 0.427).
	## A dark map encodes darkness that belongs to the material -- use
	## `albedo_map: false` there instead. Only turn this on where the map is
	## light *and* the tint's value is an anchor something else measures --
	## in practice, the mat.
	"preserve_albedo_mean": false,
	## Take the asset's normal/roughness/AO but *not* its colour map.
	##
	## For a surface whose tint is the point -- a blue turnbuckle pad, a ring
	## skirt carrying the ring's colour -- an albedo map is a liability: it
	## multiplies, so a map with a linear mean of 0.27 costs the surface
	## three-quarters of its colour, and `preserve_albedo_mean` cannot buy
	## that back once a channel clamps at 1.0. Structure without colour is the
	## right trade there: the normal and roughness maps still break the
	## surface up under direct light, and the value survives untouched.
	"albedo_map": true,
}

## Old names kept pointing at their replacements, so a rename does not break
## a caller mid-fleet. Resolved before `SPECS` is consulted.
const ALIASES := {
	"ring_mat": "ring_canvas",
	"ring_pad": "ring_turnbuckle_pad",
}

## The named materials. Each is `SPEC_DEFAULTS` plus what it changes.
##
## Values traced to `gauntlet/refs/VISUAL_BAR.md` are marked TRACED; the rest
## are coverage decisions -- an engineering value, chosen and named as such.
const SPECS := {
	# --- Ring -------------------------------------------------------------
	#
	# Consumed by `core/ring/ring_builder.gd`. These are the keys to call:
	#
	#   ring_canvas            the mat
	#   ring_apron             the skirt hanging off the mat edge
	#   ring_rope              all four sides, all three heights
	#   ring_post              the corner posts
	#   ring_turnbuckle_pad    the corner pads
	#   ring_steel             steps, frame, anything painted steel
	#
	# Two things a caller has to know:
	#
	# 1. `uv1_scale` is derived from `tile_metres` on the assumption that the
	#    mesh's UVs are laid out in **world metres** (which is what
	#    `ArenaBuilder._add_box` does). A `BoxMesh`'s default UVs run 0-1 per
	#    face regardless of size, so a 6m mat would get exactly one tile. If
	#    the ring is built from primitives, either generate UVs in metres or
	#    pass `{"tile_metres": <face size in metres> / <tiles wanted>}` per
	#    call. This is the single most likely way these materials land looking
	#    untextured.
	# 2. `resolve()` returns a fresh material, so overriding a tint per corner
	#    (blue corner, red corner) is `resolve("ring_turnbuckle_pad",
	#    {"tint": Color(...)})` and costs nothing shared.

	## TRACED: VISUAL_BAR.md reads the mat at relative luminance 0.46 on
	## frames/wide_standoff_broadcast_angle.jpg, with both wrestlers 0.24-0.31
	## below it, and `test_wrestler_colorway.gd` asserts against that. The tint
	## holds the value; `preserve_albedo_mean` is what keeps it holding it once
	## a map multiplies in.
	##
	## Coverage decision on the map: Fabric036 is a plain linen weave, chosen
	## by measurement rather than by eye. Rescaled to the pixel size its tile
	## occupies, it scores 0.617 edge density in the `wide_broadcast` framing
	## and 0.924 in `mat_close` -- the only candidate fetched that is textured
	## at *both* distances. The mat previously carried no map at all, and
	## Fabric063 (the apron's) scores 0.000 at match distance.
	##
	## 0.5m tile: 12 repeats across the 6m mat. Finer than that and the weave
	## minifies below the pixel in the wide shot, which is the failure mode
	## this whole entry exists to avoid.
	"ring_canvas": {
		"asset": "Fabric036", "tint": Color(0.60, 0.70, 0.82),
		"tile_metres": 0.5, "roughness": 0.95, "preserve_albedo_mean": true,
		"normal_scale": 0.8,
	},
	## Coverage decision: the apron skirt is a darker, tighter weave than the
	## canvas, and hangs out of the ring lights. Fabric030 scores 0.877 close
	## up; at match distance the apron is a 40px band where the map cannot
	## read whatever it is, so the close shot is what chose it.
	"ring_apron": {
		"asset": "Fabric030", "tint": Color(0.13, 0.15, 0.28),
		"tile_metres": 0.45, "roughness": 0.95, "albedo_map": false,
	},
	## TRACED: every rope in every reference frame is white (clearest in the
	## near-rope foreground of wide_standoff_broadcast_angle.jpg).
	## Coverage decision: no map. A rope is 5cm across and never covers enough
	## pixels for a tiled map to be anything but noise. Roughness 0.45 because
	## a taped rope is semi-gloss, and because the ropes are the surface
	## closest to the spot rig -- if anything in this scene returns a specular
	## highlight it is these.
	"ring_rope": {
		"tint": Color(0.93, 0.93, 0.91), "roughness": 0.45,
	},
	## Coverage decision, and a correction: the post shipped at metallic 0.3,
	## which is not a material -- it has neither a dielectric's white specular
	## nor a conductor's tinted one.
	##
	## It is 0.0 here, not 1.0, and the reason is measured rather than
	## aesthetic. A conductor has no diffuse response at all: everything it
	## shows is reflected. This scene's Environment is
	## `ambient_light_source = COLOR` with a flat background, so there is no
	## radiance map, so a conductor reflects only the four spots and renders
	## black -- which is exactly what a `metallic 1.0` preview produced in
	## `ring_corner` (see the round report). A painted steel post is a
	## dielectric anyway, so 0.0 is both correct and visible. Flip it to
	## `ring_post_chrome` the day a sky/HDRI radiance source lands.
	"ring_post": {
		"asset": "Metal032", "tint": Color(0.22, 0.23, 0.26),
		"tile_metres": 0.35, "roughness": 0.9, "metallic": 0.0,
	},
	## The same post as a conductor. Correct PBR for bare chrome and currently
	## unusable: with no radiance map it renders black. Kept named so the
	## switch is one call site, not a rediscovery.
	"ring_post_chrome": {
		"asset": "Metal032", "tint": Color(0.55, 0.56, 0.60),
		"tile_metres": 0.35, "roughness": 1.0, "metallic": 1.0,
	},
	## Coverage decision: padded vinyl turnbuckle cover, Fabric061's dotted
	## weave at a small tile so the pad reads as padded up close in
	## `ring_corner`. Override `tint` per corner.
	"ring_turnbuckle_pad": {
		"asset": "Fabric061", "tint": Color(0.10, 0.15, 0.70),
		"tile_metres": 0.30, "roughness": 0.9, "normal_scale": 1.2,
		"albedo_map": false,
	},
	## Coverage decision: painted steel -- ring steps, frame, apron edge.
	## Painted, so dielectric: the paint is what you see, not the steel.
	"ring_steel": {
		"asset": "DiamondPlate009", "tint": Color(0.30, 0.32, 0.38),
		"tile_metres": 1.0, "roughness": 1.0, "normal_scale": 1.2,
	},

	# --- Arena hall (consumed by core/arena/arena_builder.gd) -------------
	#
	# The hall tints look implausibly dark for the surfaces they name, and
	# they are load-bearing at exactly that value. `ArenaBuilder._house_lit()`
	# solves emission energy as `HOUSE_TARGET / linear(albedo) - AMBIENT_RETURN`
	# and clamps the result at zero, so brightening a tint does not brighten
	# the surface -- past linear albedo ~0.29 it drives the energy to zero and
	# the surface goes out. The first pass here raised these tints so the
	# albedo maps would read, and switched off the truss and the barricades
	# doing it. The maps read through `emission_texture` instead; the tint
	# stays where the lighting slice needs it.
	#
	# Their *hue* is free, though, because `_house_lit()` reads only the
	# tint's luminance. compare_frame.py measures the reference still at
	# saturation 0.306 and warm/cool -0.333 against our 0.239 / -0.181, so
	# every hall tint below is pushed cool and away from neutral grey at
	# constant linear luminance -- red down, blue up, green held. That moves
	# two measured statistics and moves neither the house level nor the
	# silhouette relationships measured off luminance.

	## Coverage decision, scored not guessed. Six candidate colour maps were
	## rescaled to the pixel size their tile actually occupies in
	## `wide_broadcast` and run through the same Sobel edge count
	## `compare_frame.py` uses. Four of them -- Rubber004, Concrete034,
	## Metal032, Fabric063 -- measured 0.000-0.034 at that scale: at match
	## distance they are not textures, they are flat colours with a file
	## behind them. PavingStones150 measured 0.862 and DiamondPlate009 0.872.
	## The venue floor is paved slab; ringside dressing is a later slice's job.
	"arena_floor": {
		"asset": "PavingStones150", "tint": Color(0.070, 0.100, 0.150),
		"tile_metres": 2.0, "roughness": 1.0, "house_lit": true,
	},
	## Coverage decision: painted steel crowd barricade. Painted, so it is a
	## dielectric (metallic 0.0) -- the paint layer is what you see, not the
	## steel under it. DiamondPlate009 carries the highest on-screen edge
	## density of anything imported here, which is why it is on the geometry
	## that rings the whole frame at ringside.
	"arena_barricade": {
		"asset": "DiamondPlate009", "tint": Color(0.120, 0.170, 0.250),
		"tile_metres": 2.0, "roughness": 1.0, "house_lit": true,
		"normal_scale": 1.4,
	},
	## Coverage decision: carpeted bowl treads and risers. The tile is large
	## on purpose -- the bowl sits 12-30m out, so a small tile minifies its
	## weave below the pixel and renders as flat colour. Carpet012 scores
	## 0.176 with a 96px tile and 0.584 with a 160px one; 3.0m puts it in the
	## second regime at this camera.
	"arena_bowl": {
		"asset": "Carpet012", "tint": Color(0.230, 0.305, 0.430),
		"tile_metres": 3.0, "roughness": 1.0, "house_lit": true,
	},
	## Coverage decision: staging deck is steel deck plate, which is both what
	## it would really be and the map that survives the distance.
	"arena_stage_deck": {
		"asset": "DiamondPlate009", "tint": Color(0.105, 0.140, 0.205),
		"tile_metres": 2.5, "roughness": 1.0, "house_lit": true,
	},
	## Coverage decision: poured concrete wall. Concrete033 measures near-zero
	## edge density at this distance and is kept anyway -- the backdrop and
	## the shell are meant to be the flat, quiet part of the frame, and the
	## reference still's own background is flat there too.
	"arena_stage_backdrop": {
		"asset": "Concrete033", "tint": Color(0.090, 0.120, 0.175),
		"tile_metres": 4.0, "roughness": 1.0, "house_lit": true,
	},
	"arena_shell": {
		"asset": "Concrete033", "tint": Color(0.098, 0.130, 0.185),
		"tile_metres": 4.5, "roughness": 1.0, "house_lit": true,
	},
	## Coverage decision: bare aluminium lighting truss. A conductor, so
	## metallic 1.0 -- and worth saying plainly that with this scene's
	## Environment (ambient_light_source = COLOR, no radiance map) a conductor
	## gets no ambient specular and would render black on diffuse alone. What
	## makes the truss read is its house emission, not its metal.
	"arena_truss": {
		"asset": "Metal032", "tint": Color(0.125, 0.145, 0.185),
		"tile_metres": 0.45, "roughness": 1.0, "metallic": 1.0,
		"house_lit": true,
	},
	## Coverage decision: the tunnel mouth is meant to read as a recess, so
	## it is the darkest thing on the stage; its own frame is painted steel.
	"arena_tunnel": {
		"asset": "DiamondPlate009", "tint": Color(0.070, 0.090, 0.130),
		"tile_metres": 1.5, "roughness": 1.0, "house_lit": true,
	},
	## Coverage decision: the video wall is deliberately blank -- a logo there
	## would be branding, which ARCHITECTURE.md's IP guardrail scopes out.
	## Kept off near-black on purpose: the house-light compensation divides
	## by linear albedo, so a very dark panel asks for an absurd energy.
	"arena_screen": {
		"tint": Color(0.28, 0.30, 0.38), "roughness": 0.35,
	},
}

## Map role -> filename part, in the order `_build` plugs them in.
const MAP_FILES := {
	"color": "Color",
	"normal": "NormalGL",
	"roughness": "Roughness",
	"roughness_band": "RoughnessBand",
	"ao": "AmbientOcclusion",
	"metalness": "Metalness",
}

## Cached mean linear luminance per colour map, keyed by resource path. See
## `_mean_linear()`.
static var _mean_cache := {}


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for k: String in SPECS:
		out.append(k)
	out.sort()
	return out


static func has(key: String) -> bool:
	return SPECS.has(_canonical(key))


## Follow `ALIASES` to the name `SPECS` actually stores.
static func _canonical(key: String) -> String:
	return ALIASES.get(key, key)


## A read-only copy of a named spec, merged over the defaults. Useful to a
## caller that wants to know a material's tint without building it.
static func spec(key: String) -> Dictionary:
	var k := _canonical(key)
	assert(SPECS.has(k), "MaterialLibrary: unknown material %s" % key)
	return _merged(k, {})


## Build the named material. Returns a fresh `StandardMaterial3D` each call.
static func resolve(key: String, overrides: Dictionary = {}) -> StandardMaterial3D:
	var k := _canonical(key)
	assert(SPECS.has(k), "MaterialLibrary: unknown material %s" % key)
	return _build(_merged(k, overrides))


## Build a material straight from a spec dictionary, with no named entry.
## For one-offs; anything reused should get a name in `SPECS` instead.
static func build(overrides: Dictionary) -> StandardMaterial3D:
	var s := SPEC_DEFAULTS.duplicate()
	s.merge(overrides, true)
	return _build(s)


## Undo the mean darkening a multiplied emission map causes.
##
## Call this **after** whatever set `emission_energy_multiplier` (in this
## project, `ArenaBuilder._house_lit()`). `EMISSION` resolves to
## `emission * energy * emission_map`, so a map whose mean linear value is
## `m` renders the surface at `m` times the level the energy was solved for.
## Dividing the energy by `m` puts the mean back where the lighting slice put
## it while keeping every bit of the map's variance.
##
## No-op on a material with no emission texture, so it is safe to call
## unconditionally.
static func house_compensate(mat: StandardMaterial3D) -> StandardMaterial3D:
	var tex := mat.emission_texture
	if tex == null or not mat.emission_enabled:
		return mat
	var mean := _mean_linear(tex)
	if mean > 0.0001:
		mat.emission_energy_multiplier /= mean
	return mat


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------

static func _merged(key: String, overrides: Dictionary) -> Dictionary:
	var s := SPEC_DEFAULTS.duplicate()
	s.merge(SPECS[key], true)
	s.merge(overrides, true)
	return s


static func _map_path(asset: String, suffix: String, role: String) -> String:
	return MAT_DIR + asset + suffix + MAP_FILES[role] + ".png"


static func _load_map(asset: String, suffix: String, role: String) -> Texture2D:
	if asset.is_empty():
		return null
	var path := _map_path(asset, suffix, role)
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func _build(s: Dictionary) -> StandardMaterial3D:
	var metallic: float = s["metallic"]
	assert(metallic == 0.0 or metallic == 1.0,
			"MaterialLibrary: metallic must be 0.0 or 1.0, got %s. A "
			% metallic + "mid-range metalness is two materials averaged.")

	var mat := StandardMaterial3D.new()
	var asset: String = s["asset"]
	var suffix: String = s["suffix"]

	mat.albedo_color = s["tint"]
	mat.metallic = metallic
	# Godot 4 names the dielectric F0 scalar `metallic_specular`; 0.5 = 4%.
	mat.metallic_specular = s["specular"]
	mat.roughness = clampf(s["roughness"], 0.0, 1.0)
	mat.cull_mode = (BaseMaterial3D.CULL_BACK if s["cull_back"]
			else BaseMaterial3D.CULL_DISABLED)
	# Mipmaps exist; use them, and use anisotropy so a floor seen at a
	# grazing angle keeps its texture instead of smearing to grey.
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	var color_tex: Texture2D = null
	if s["albedo_map"]:
		color_tex = _load_map(asset, suffix, "color")
	if color_tex != null:
		mat.albedo_texture = color_tex
		if s["preserve_albedo_mean"]:
			var mean := _mean_linear(color_tex)
			if mean > 0.0001:
				# Linear divide on a Color: the tint is a multiplier here, not
				# a colour to be displayed, so it is allowed above 1.0.
				# One gain on all three channels, never a per-channel clamp:
				# clamping channels independently is a hue change, and the
				# first version of this did exactly that -- the mat's
				# (0.60, 0.70, 0.82) all clamped to 1.0 and the canvas came
				# out neutral grey with its blue gone. Capped at MAX_ALBEDO_GAIN.
				var t: Color = mat.albedo_color
				var gain := minf(1.0 / mean, MAX_ALBEDO_GAIN)
				mat.albedo_color = Color(t.r * gain, t.g * gain, t.b * gain, t.a)

	var normal_tex := _load_map(asset, suffix, "normal")
	if normal_tex != null:
		mat.normal_enabled = true
		mat.normal_texture = normal_tex
		mat.normal_scale = s["normal_scale"]

	# The rebanded map wins where one exists: it is the same scan pushed
	# inside 0.30-0.90, and the raw one is kept only for auditability.
	var rough_tex := _load_map(asset, suffix, "roughness_band")
	if rough_tex == null:
		rough_tex = _load_map(asset, suffix, "roughness")
	if rough_tex != null:
		mat.roughness_texture = rough_tex

	var ao_tex := _load_map(asset, suffix, "ao")
	if ao_tex != null:
		mat.ao_enabled = true
		mat.ao_texture = ao_tex
		mat.ao_light_affect = s["ao_light_affect"]
		mat.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED

	if metallic == 1.0:
		var metal_tex := _load_map(asset, suffix, "metalness")
		if metal_tex != null:
			mat.metallic_texture = metal_tex

	# Texel density. ArenaBuilder lays UVs out in world metres, so a tile
	# `tile_metres` across is `1 / tile_metres` repeats per metre. Deriving
	# it rather than typing a repeat count per surface is the whole point:
	# two materials with the same physical tile size now have the same texel
	# density whatever size box they land on.
	var tile: float = maxf(s["tile_metres"], 0.001)
	var repeats := 1.0 / tile
	mat.uv1_scale = Vector3(repeats, repeats, 1.0)

	if s["house_lit"] and color_tex != null:
		# Emission is unlit, so without this the map is invisible on every
		# hall surface. MULTIPLY, not ADD: the house light is the surface
		# lit, not a glow added on top of it.
		mat.emission_texture = color_tex
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY

	return mat


## Mean linear luminance of a texture, cached by resource path.
##
## `Image.resize(1, 1)` is the whole trick: a box/Lanczos downscale to a
## single pixel *is* the mean, computed by the engine's own resampler instead
## of by a million-iteration GDScript loop. Colour maps are sRGB-encoded, so
## the result is linearised before it is used as a divisor.
static func _mean_linear(tex: Texture2D) -> float:
	var key := tex.resource_path
	if key.is_empty():
		key = str(tex.get_instance_id())
	if _mean_cache.has(key):
		return _mean_cache[key]
	var img := tex.get_image()
	var mean := 1.0
	if img != null:
		if img.is_compressed():
			img.decompress()
		img.resize(1, 1, Image.INTERPOLATE_LANCZOS)
		mean = img.get_pixel(0, 0).srgb_to_linear().get_luminance()
	_mean_cache[key] = mean
	return mean
