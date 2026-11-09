shader_type spatial;
// A flame tongue on a particle billboard (ManFire.tongue_pass): the owner,
// 9 Nov, "Make fire look more realistic". It was one static white-on-clear
// sprite, additive, piled into a blown-out ball. Here each tongue moves:
// scrolling noise breaks its edges and lifts licks off its tip, and it is
// coloured by its own heat -- a pale core, orange body, deep red edges --
// rather than flat by the particle's colour. Soft where it meets a body or
// the floor (the scene's depth), so no hard card edges.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_linear;
uniform vec4 tint : source_color = vec4(1.0);
uniform float intensity = 0.24;
uniform float soft_distance = 0.2;
uniform float speed = 2.2;

varying float v_seed;

void vertex() {
	// Billboard, as BaseMaterial3D's BILLBOARD_PARTICLES.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_seed = fract(float(INSTANCE_ID) * 0.618034) * 31.0;
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
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float up = 1.0 - UV.y;  // 0 at the root, 1 at the tip
	float t = TIME * speed + v_seed;
	float n = fbm(vec2(UV.x * 2.6 + v_seed, up * 2.2 - t));
	float n2 = fbm(vec2(UV.x * 5.0 - v_seed, up * 4.5 - t * 1.6));
	// The tongue leans and wavers more toward its tip.
	float x = UV.x - 0.5 + (n - 0.5) * 0.24 * up;
	float half_w = 0.42 * pow(1.0 - up, 0.5) + 0.015;
	float body = 1.0 - smoothstep(half_w * 0.35, half_w, abs(x));
	// Licks breaking off the top, eaten by the second noise.
	float top = 1.0 - smoothstep(0.3, 0.95, up + (n2 - 0.5) * 0.7);
	float heat = body * smoothstep(0.0, 0.1, up) * top * (0.55 + 0.8 * n);
	// Never to the card's edge: no rectangle round a tongue.
	heat *= smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x) * smoothstep(0.0, 0.08, UV.y);
	heat = clamp(heat * COLOR.a * 1.25, 0.0, 1.0);
	vec3 c = mix(vec3(0.28, 0.03, 0.0), vec3(1.0, 0.30, 0.02), smoothstep(0.05, 0.38, heat));
	c = mix(c, vec3(1.0, 0.66, 0.18), smoothstep(0.38, 0.72, heat));
	c = mix(c, vec3(1.0, 0.92, 0.72), smoothstep(0.82, 1.0, heat));
	// Soft against the scene.
	float depth = texture(depth_tex, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	float soft = clamp((VERTEX.z - view.z) / soft_distance, 0.0, 1.0);
	ALBEDO = c * tint.rgb * intensity;
	ALPHA = smoothstep(0.02, 0.35, heat) * soft;
}
