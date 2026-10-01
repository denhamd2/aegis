class_name EyeKit
## The head kit's eyes (character_aaa_plan.md S1), shared by every model:
## the material an eye gets from tools/assets/build_eyes.py's maps --
##   <prefix>_eye_color.png   sclera, iris, pupil (and, for Aubrey, lids)
##   <prefix>_eye_orm.png     R occlusion where the lids meet the eye,
##                            G roughness (the cornea glass-smooth)
##   <prefix>_eye_height.png  the iris behind the cornea, as parallax
## -- plus a wet film (clearcoat) over it all. Each model finds its own eye
## surfaces (they are named differently in every source asset) and calls
## dress().

const TEXTURES := "res://assets/characters/%s_eye_%s.png"
const CLEARCOAT_ROUGHNESS := 0.03
## Lids shade direct light too, not just the ambient.
const AO_LIGHT_AFFECT := 0.7


static func eye_material(prefix: String, parallax: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Eye_" + prefix
	m.albedo_texture = load(TEXTURES % [prefix, "color"]) as Texture2D
	var orm := load(TEXTURES % [prefix, "orm"]) as Texture2D
	m.ao_enabled = true
	m.ao_texture = orm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = AO_LIGHT_AFFECT
	m.roughness = 1.0
	m.roughness_texture = orm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.heightmap_enabled = true
	m.heightmap_texture = load(TEXTURES % [prefix, "height"]) as Texture2D
	m.heightmap_scale = parallax
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = CLEARCOAT_ROUGHNESS
	# Where the texture also paints skin (Aubrey's lids), only the eye is wet.
	var coat := TEXTURES % [prefix, "coat"]
	if ResourceLoader.exists(coat):
		m.clearcoat_texture = load(coat) as Texture2D
	return m


## Lash cards: dark strands, scissored, barely reflective -- at the default
## reflectance thin cards catch a cool key and read as a silver fringe.
static func lash_material(texture: Texture2D, color: Color, scissor: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = "Lashes"
	m.albedo_texture = texture
	m.albedo_color = color
	m.roughness = 0.85
	m.metallic_specular = 0.1
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = scissor
	m.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
	m.alpha_antialiasing_edge = scissor
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Puts `material` on every surface under `root` whose source material is
## named `source_name`. Returns how many.
static func dress(root: Node, source_name: String, material: BaseMaterial3D) -> int:
	var count := 0
	for mi: MeshInstance3D in root.find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(s)
			if source and source.resource_name == source_name:
				mi.set_surface_override_material(s, material)
				count += 1
	return count
