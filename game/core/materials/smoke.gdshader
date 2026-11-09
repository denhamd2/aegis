shader_type spatial;
// Smoke off a fire (ManFire._flame_particles' sub-emitter): a soft, dark,
// churning puff on a particle billboard, blended over the scene (not added),
// fading as it rises and spreads. Soft against the scene's depth.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 smoke_color : source_color = vec4(0.09, 0.08, 0.075, 1.0);
uniform float density = 0.45;
uniform float soft_distance = 0.4;

varying float v_seed;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_seed = fract(float(INSTANCE_ID) * 0.618034) * 23.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(5.3, 1.9);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 d = UV - 0.5;
	float n = fbm(UV * 3.0 + vec2(v_seed, -TIME * 0.35 + v_seed));
	float r = length(d) * 2.0 + (n - 0.5) * 0.6;
	float puff = 1.0 - smoothstep(0.35, 1.0, r);
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / soft_distance, 0.0, 1.0);
	ALBEDO = smoke_color.rgb * (0.7 + 0.6 * n);
	ALPHA = puff * density * COLOR.a * soft;
}
