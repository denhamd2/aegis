// The bowl's plain house-lit surfaces with their baked occlusion on
// (MaterialLibrary.with_occlusion; tools/blender/arena_bowl.py bake_occlusion).
// A StandardMaterial3D puts vertex colour on albedo at most, and the bowl's
// look is its house emission, so the darkening has to reach both. Mirrors the
// parameters MaterialLibrary sets on an untextured spec.
shader_type spatial;
render_mode cull_back;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;

void fragment() {
	vec3 occlusion = COLOR.rgb;
	ALBEDO = albedo.rgb * occlusion;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
	EMISSION = emission.rgb * emission_energy * occlusion;
}
