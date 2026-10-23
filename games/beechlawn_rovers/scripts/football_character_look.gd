extends RefCounted
class_name FootballCharacterLook
## Football-local materials. Skin optics are used only in close-up views;
## distant broadcast players retain cheap ordinary PBR shading.
static var materials: Dictionary = {}
## Native diagnostic fixture may isolate this feature before first draw.
static var scattering_enabled := true
## Shadow transmittance caused a >150s first-draw compile on software Vulkan;
## retain the validated skin diffusion without that optional shader feature.
static var transmittance_enabled := false

static func groom_root_for(source: Material) -> Material:
	if not source is StandardMaterial3D: return source
	var key := "groom:%s" % source.get_instance_id()
	if materials.has(key): return materials[key]
	var result := source.duplicate() as StandardMaterial3D
	result.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	result.alpha_scissor_threshold=.45
	result.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	result.alpha_antialiasing_edge=.45
	result.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key]=result
	return result

static func material_for(source: Material, skin: bool, near_view: bool) -> Material:
	if not source is StandardMaterial3D: return source
	var key := "%s:%s:%s:%s:%s" % [source.get_instance_id(), skin, near_view, scattering_enabled, transmittance_enabled]
	if materials.has(key): return materials[key]
	var result := source.duplicate() as StandardMaterial3D
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if skin:
		result.subsurf_scatter_enabled = near_view and scattering_enabled
		result.subsurf_scatter_skin_mode = true
		result.subsurf_scatter_strength = .12
		result.subsurf_scatter_transmittance_enabled = near_view and scattering_enabled and transmittance_enabled
		result.subsurf_scatter_transmittance_color = Color(.8,.28,.22)
		result.subsurf_scatter_transmittance_depth = .015
		result.subsurf_scatter_transmittance_boost = 0
	else:
		result.clearcoat_enabled = near_view
		result.clearcoat = .65
		result.clearcoat_roughness = .08
	materials[key] = result
	return result
