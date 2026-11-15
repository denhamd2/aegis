shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

// Match the Blender cell's five diamond periods per UV tile. Integrate each
// strand over its pixel footprint instead of thresholding minified alpha to
// either a disappearing fence or an opaque sheet. This also works without MSAA.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_map : filter_linear_mipmap_anisotropic, repeat_enable;

float stripe_integral(float x) {
	float f = fract(x);
	const float radius = 0.045;
	return floor(x) * (2.0 * radius) + min(f, radius) + max(f - (1.0 - radius), 0.0);
}

float stripe_coverage(float phase, float footprint) {
	float w = max(footprint, 0.00001);
	return clamp((stripe_integral(phase + w * 0.5) - stripe_integral(phase - w * 0.5)) / w, 0.0, 1.0);
}

void fragment() {
	float u = (UV.x + UV.y) * 5.0;
	float v = (UV.x - UV.y) * 5.0;
	float a = stripe_coverage(u, fwidth(u));
	float b = stripe_coverage(v, fwidth(v));
	ALBEDO = texture(albedo_map, UV).rgb;
	vec3 orm = texture(orm_map, UV).rgb;
	METALLIC = orm.b;
	ROUGHNESS = orm.g;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	NORMAL_MAP_DEPTH = 0.7;
	ALPHA = 1.0 - (1.0 - a) * (1.0 - b);
}
