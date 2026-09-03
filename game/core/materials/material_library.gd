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
##     house_lit       bool    emission carries the albedo map (see below).
##     emission_tint   Color   emission colour when house_lit; defaults to tint.
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
	"emission_tint": null,    # null = use tint
	"cull_back": true,
}

## The named materials. Each is `SPEC_DEFAULTS` plus what it changes.
##
## Values traced to `gauntlet/refs/VISUAL_BAR.md` are marked TRACED; the rest
## are coverage decisions -- an engineering value, chosen and named as such.
const SPECS := {
	# --- Ring (consumed by scenes/ring.tscn's owner) ---------------------
	## TRACED: VISUAL_BAR.md reads the mat at relative luminance 0.46 on
	## frames/wide_standoff_broadcast_angle.jpg, with both wrestlers 0.24-0.31
	## below it. The tint holds that value; the map supplies the weave.
	"ring_mat": {
		"asset": "Fabric063", "tint": Color(0.60, 0.70, 0.82),
		"tile_metres": 1.2, "roughness": 0.95,
	},
	## Coverage decision: the apron is the same vinyl-over-canvas as the mat,
	## darker because it hangs out of the ring lights.
	"ring_apron": {
		"asset": "Fabric063", "tint": Color(0.20, 0.23, 0.30),
		"tile_metres": 0.9, "roughness": 0.95,
	},
	## TRACED: every rope in every reference frame is white (clearest in the
	## near-rope foreground of wide_standoff_broadcast_angle.jpg).
	## Coverage decision: roughness 0.45 -- a taped rope is a semi-gloss
	## dielectric, and it is one of the few ring surfaces inside the spot
	## rig's reach that can return a highlight at all.
	"ring_rope": {
		"tint": Color(0.93, 0.93, 0.91), "roughness": 0.45,
	},
	## Coverage decision, and a correction: this shipped at metallic 0.3,
	## which is not a material. A chromed ring post is a conductor: 1.0.
	"ring_post": {
		"asset": "Metal032", "tint": Color(0.55, 0.56, 0.60),
		"tile_metres": 0.35, "roughness": 1.0, "metallic": 1.0,
	},
	## Coverage decision: padded vinyl turnbuckle cover.
	"ring_turnbuckle_pad": {
		"asset": "Fabric063", "tint": Color(0.10, 0.15, 0.70),
		"tile_metres": 0.5, "roughness": 0.9,
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
	## Coverage decision: ringside is a dark rubber event floor laid over the
	## venue slab, not bare concrete. Rubber004 is dark by scan (mean 0.176
	## sRGB), so the tint barely has to darken it and the map survives.
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
	return SPECS.has(key)


## A read-only copy of a named spec, merged over the defaults. Useful to a
## caller that wants to know a material's tint without building it.
static func spec(key: String) -> Dictionary:
	assert(SPECS.has(key), "MaterialLibrary: unknown material %s" % key)
	return _merged(key, {})


## Build the named material. Returns a fresh `StandardMaterial3D` each call.
static func resolve(key: String, overrides: Dictionary = {}) -> StandardMaterial3D:
	assert(SPECS.has(key), "MaterialLibrary: unknown material %s" % key)
	return _build(_merged(key, overrides))


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

	var color_tex := _load_map(asset, suffix, "color")
	if color_tex != null:
		mat.albedo_texture = color_tex

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
