class_name SkinLook
## What makes a wrestler's skin read as flesh rather than painted plastic
## (gauntlet/refs/aaa_gap.md, item 2): light going INTO the skin and
## scattering before it comes back out.
##
## Without it a skin material is a hard Lambert surface: the terminator where
## the key light falls off is a sharp line, and a backlit ear is as dark as a
## shoulder. Real skin softens that line with a warm bleed -- the light that
## went in under the lit side and came out a few millimetres into the shadow --
## and glows red where it is thin enough to light through. Both are what 2K's
## faces do under a truss key, and both are one BaseMaterial3D feature,
## screen-space subsurface scattering in skin mode.
##
## Applied by each character model to the materials it already identifies as
## skin (RomanModel.SKIN_ROUGHNESS, CodyModel.SKIN_MATERIALS), on the
## duplicates it already makes -- never to gear, hair or eyes. Not to Kenny:
## his scan is ONE material over skin and gear alike, and scattering light
## through his vest would read as wet cloth.

## How far light spreads under the surface, as the renderer's 0-1 strength.
## 0.45: enough that the terminator on a bicep softens by a finger's width at
## the match camera, not so much that a face goes waxy in a close-up.
const STRENGTH := 0.45
## Thin parts lit from behind -- ears, fingers, the rim of a nose -- pass a
## little red light: blood under skin. Depth is how thick a part can be and
## still pass it; boost stays 0 so a whole torso never glows.
const TRANSMITTANCE_COLOR := Color(0.85, 0.30, 0.20)
const TRANSMITTANCE_DEPTH := 0.06


static func apply(material: BaseMaterial3D) -> void:
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_skin_mode = true
	material.subsurf_scatter_strength = STRENGTH
	material.subsurf_scatter_transmittance_enabled = true
	material.subsurf_scatter_transmittance_color = TRANSMITTANCE_COLOR
	material.subsurf_scatter_transmittance_depth = TRANSMITTANCE_DEPTH
	material.subsurf_scatter_transmittance_boost = 0.0


# --- Pores (gauntlet/refs/aaa_gap.md, item 6) ---------------------------------
## The tiling pore-and-crease normal tile (tools/assets/build_skin_detail.py).
const DETAIL_NORMAL := "res://assets/characters/skin_detail_normal.png"
## How much of the final normal is the pore tile, 0-1. Godot mixes the detail
## normal INTO the base normal map by the detail albedo's alpha, so this also
## takes as much away from the model's own muscle and face relief: 0.3 breaks
## the highlight without flattening the anatomy under it.
const DETAIL_MIX := 0.3


## Adds the pore layer to `material`, tiled `tiles` times across its UV space
## (the atlas's own layout, copied into UV2 by with_detail_uv()).
##
## The detail albedo is a white pixel at DETAIL_MIX alpha, in MULTIPLY: white
## times the albedo is the albedo, so the colour is untouched and the alpha is
## there only to set how much pore normal is mixed in.
static func add_pores(material: BaseMaterial3D, tiles: float) -> void:
	var tex := load(DETAIL_NORMAL) as Texture2D
	if tex == null:
		return
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(1, 1, 1, DETAIL_MIX))
	material.detail_enabled = true
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.detail_uv_layer = BaseMaterial3D.DETAIL_UV_2
	material.detail_albedo = ImageTexture.create_from_image(img)
	material.detail_normal = tex
	material.uv2_scale = Vector3(tiles, tiles, 1.0)


## `mi`'s mesh rebuilt with UV2 = UV on the listed surfaces, so a detail layer
## can tile independently of the base textures: BaseMaterial3D's detail can
## only be scaled on UV2, and these models ship without one. Skin, bone
## weights and blend shapes are carried over; the surface override materials
## are put back. A surface that already has UV2 is left alone.
static func with_detail_uv(mi: MeshInstance3D, surfaces: Array) -> void:
	var source := mi.mesh as ArrayMesh
	if source == null or surfaces.is_empty():
		return
	var overrides := []
	for s in source.get_surface_count():
		overrides.append(mi.get_surface_override_material(s))
	var mesh := ArrayMesh.new()
	mesh.blend_shape_mode = source.blend_shape_mode
	for b in source.get_blend_shape_count():
		mesh.add_blend_shape(source.get_blend_shape_name(b))
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		if surfaces.has(s) and arrays[Mesh.ARRAY_TEX_UV2] == null \
				and arrays[Mesh.ARRAY_TEX_UV] != null:
			arrays[Mesh.ARRAY_TEX_UV2] = (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
		var flags := source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
		mesh.add_surface_from_arrays(source.surface_get_primitive_type(s), arrays,
				source.surface_get_blend_shape_arrays(s), {}, flags)
		mesh.surface_set_material(s, source.surface_get_material(s))
		mesh.surface_set_name(s, source.surface_get_name(s))
	mi.mesh = mesh
	for s in overrides.size():
		mi.set_surface_override_material(s, overrides[s])


# --- Sweat (gauntlet/refs/aaa_gap.md, item 5) ---------------------------------
## A man walks out dry and is wet by the end of a long match. Sweat is a film
## of water ON the skin, which is what BaseMaterial3D's clearcoat models: a
## second, glossy specular layer over the skin's own. So a wet wrestler keeps
## his skin's soft sheen underneath and gains a sharp, bright highlight on top
## -- the look of every late-match close-up -- rather than turning into a
## uniformly shiny doll, which is what lowering the skin's own roughness does.
## 0.6 and 0.18, down from a first 0.85 and 0.12: rendered soaked at those
## (tools/probe/skin_shot.tscn) he read as cling-filmed, a continuous mirror
## over every muscle. Sweat is beads and streaks, broken up by the pores --
## bright, but not a lacquer.
const SWEAT_COAT := 0.7
const SWEAT_COAT_ROUGHNESS_DRY := 0.55
const SWEAT_COAT_ROUGHNESS_WET := 0.18


## Sets `material`'s wetness, 0 (dry) to 1 (soaked).
static func set_wetness(material: BaseMaterial3D, wetness: float) -> void:
	var w := clampf(wetness, 0.0, 1.0)
	material.clearcoat_enabled = w > 0.0
	material.clearcoat = SWEAT_COAT * w
	material.clearcoat_roughness = lerpf(SWEAT_COAT_ROUGHNESS_DRY,
			SWEAT_COAT_ROUGHNESS_WET, w)
