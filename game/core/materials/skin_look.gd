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
## Moderate diffusion retains the cheek/shoulder planes under the wetter
## October reference finish. Review this together with the entrance keys.
const STRENGTH := 0.28
## Thin parts lit from behind -- ears, fingers, the rim of a nose -- pass a
## little red light: blood under skin. Depth is how thick a part can be and
## still pass it; boost stays 0 so a whole torso never glows.
const TRANSMITTANCE_COLOR := Color(0.85, 0.30, 0.20)
const TRANSMITTANCE_DEPTH := 0.06


static func apply(material: BaseMaterial3D, face := false) -> void:
	material.set_meta("skin_face_film", face)
	material.subsurf_scatter_enabled = true
	material.subsurf_scatter_skin_mode = true
	material.subsurf_scatter_strength = STRENGTH
	material.subsurf_scatter_transmittance_enabled = true
	material.subsurf_scatter_transmittance_color = TRANSMITTANCE_COLOR
	material.subsurf_scatter_transmittance_depth = TRANSMITTANCE_DEPTH
	material.subsurf_scatter_transmittance_boost = 0.0
	material.clearcoat_texture = load(WET_FILM)


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
## October 16 target: a visible, broken wet sheen from the entrance onward.
## R masks the film and G varies its roughness; both are linear data. Reuse
## one small mask across the body materials rather than adding a draw pass.
const WET_FILM := "res://assets/characters/skin_wet_film.png"
## A thin, broad coat: 0.7 at roughness 0.22 read as oil (the owner, 19 Oct).
const SWEAT_COAT := 0.22
const SWEAT_COAT_ROUGHNESS_DRY := 0.5
const SWEAT_COAT_ROUGHNESS_WET := 0.42
## Close portraits exposed broad oily patches on cheeks/forehead. Keep the
## wet layer, with less coverage and a broader lobe than chest/shoulder skin.
const FACE_FILM_SHARE := 0.18
const FACE_FILM_ROUGHNESS_GAIN := 2.2


## Sets `material`'s wetness, 0 (dry) to 1 (soaked).
static func set_wetness(material: BaseMaterial3D, wetness: float) -> void:
	var w := clampf(wetness, 0.0, 1.0)
	if material.clearcoat_texture == null:
		material.clearcoat_texture = load(WET_FILM)
	material.clearcoat_enabled = w > 0.0
	var face: bool = material.get_meta("skin_face_film", false)
	var share: float = material.get_meta("skin_face_film_share", FACE_FILM_SHARE) if face else 1.0
	var roughness_gain: float = material.get_meta("skin_face_film_roughness_gain", FACE_FILM_ROUGHNESS_GAIN) if face else 1.0
	material.clearcoat = SWEAT_COAT * w * share
	material.clearcoat_roughness = lerpf(SWEAT_COAT_ROUGHNESS_DRY,
			SWEAT_COAT_ROUGHNESS_WET, w) * roughness_gain
