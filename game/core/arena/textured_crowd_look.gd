extends RefCounted
## Material adapter for the near-only photographic crowd library.
## The variant indices and seeded placement are the existing floor-crowd contract.

const MODEL := "res://assets/environment/floor_crowd_textured.glb"
const MANIFEST := "res://assets/environment/floor_crowd_textured.json"
const SHADER := preload("res://core/arena/textured_crowd.gdshader")
const TEXTURES := "res://assets/environment/materials/crowd/"


static func manifest() -> Dictionary:
	if not FileAccess.file_exists(MANIFEST):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed if parsed is Dictionary else {}


static func material(spec: Dictionary) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var atlas := int(spec["atlas"])
	mat.set_shader_parameter("albedo_atlas", load(TEXTURES + "crowd_%02d_color.png" % atlas))
	mat.set_shader_parameter("print_atlas", load(TEXTURES + "crowd_%02d_print.png" % atlas))
	mat.set_shader_parameter("cloth_normal", load("res://assets/environment/materials/Fabric030_1K-PNG_NormalGL.png"))
	mat.set_shader_parameter("garment_luminance", float(spec.get("garment_luminance", 0.18)))
	return mat
