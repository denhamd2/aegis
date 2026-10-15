shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

// UV0 is the photographic atlas; UV2 is cosmetic arm weight / side.
// COLOR: garment mask, reaction role, chest mask, skin mask.
uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D print_atlas : filter_linear_mipmap, repeat_disable;
uniform sampler2D cloth_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float garment_luminance = 0.18;
uniform float albedo_gain = 0.85;
global uniform float crowd_excitement;
global uniform float crowd_light;

varying vec4 masks;
varying vec4 clothing;

float fan_hash(float value) {
	return fract(sin(value * 12.9898) * 43758.5453);
}

void vertex() {
	masks = COLOR;
	clothing = INSTANCE_CUSTOM;
	float figure = float(INSTANCE_ID) * 0.6180339887;
	float phase = fract(figure) * 6.2831853;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ring_dist = length(world.xz);
	float band = 0.5 + 0.5 * sin(atan(world.z, world.x) * 3.0 - TIME * 0.9 + ring_dist * 0.04);
	float excitement = clamp(crowd_excitement * (0.4 + 0.8 * band), 0.0, 1.0);
	float lift = clamp(VERTEX.y * 1.4, 0.0, 1.0);
	VERTEX.y += sin(TIME * 1.7 + phase) * 0.018 * lift;
	VERTEX.x += sin(TIME * 1.071 + phase * 1.7) * 0.012 * lift;
	float jumper = step(0.65, masks.g);
	float waver = step(0.4, masks.g) * (1.0 - jumper);
	float clapper = step(0.15, masks.g) * (1.0 - step(0.4, masks.g));
	float bounce = abs(sin(TIME * 15.0 * (0.85 + 0.3 * fan_hash(figure)) + phase));
	VERTEX.y += bounce * 0.055 * (0.45 + 1.7 * jumper) * excitement * lift;
	VERTEX.x += sin(TIME * 3.4 + phase) * 0.04 * waver * excitement * lift;
	float activity = 0.3 + 0.7 * excitement;
	float side = (1.0 - UV2.y) * 2.0 - 1.0;
	float clap = 0.5 + 0.5 * sin(TIME * 13.0 * (0.85 + 0.3 * fan_hash(figure * 7.1)) + phase * 2.0);
	VERTEX.x += side * clap * 0.045 * UV2.x * clapper * activity;
	float pump = max(0.0, sin(TIME * 6.5 * (0.8 + 0.4 * fan_hash(figure * 3.3)) + phase * 3.0));
	VERTEX.y += pump * 0.08 * UV2.x * (waver + jumper) * activity;
}

void fragment() {
	vec4 source = texture(albedo_atlas, UV);
	float garment = smoothstep(0.25, 0.75, masks.r);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float folds = clamp(luminance / max(garment_luminance, 0.02), 0.4, 1.65);
	vec3 tee = mix(source.rgb, clothing.rgb * folds, 0.82);
	vec3 base = mix(source.rgb, tee, garment);
	float ink = texture(print_atlas, UV).r * garment * step(0.004, clothing.a);
	base = mix(base, vec3(0.68, 0.67, 0.63) * clamp(folds, 0.7, 1.2), ink * 0.88);
	ALBEDO = base * albedo_gain;
	ROUGHNESS = mix(0.83, 0.53, smoothstep(0.3, 0.7, masks.a));
	METALLIC = 0.0;
	SPECULAR = 0.35;
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), texture(cloth_normal, UV * 32.0).rgb, garment * 0.16);
	// A tiny residual floor holds silhouettes during a blackout; the fixtures
	// and their shadows provide the visible match lighting and surface shape.
	EMISSION = base * 0.0015 * clamp(crowd_light / 3.5, 0.0, 1.0);
	ALPHA = source.a;
	ALPHA_SCISSOR_THRESHOLD = 0.45;
}
