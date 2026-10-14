shader_type spatial;
// Blood on the ring canvas (CanvasBlood): drawn over the mat as its
// material's next pass, from a stain map painted in the mat's own UV space.
//
// `stains` red is how much blood is on each texel (a speck, a drip, a pool,
// a smear dragged through it), green is when it was last added to, as a
// fraction of TIME_SPAN seconds of match. Fresh blood is bright, wet and
// glossy and sits ON the canvas; it soaks in and dries dark and matte over
// DRY seconds -- the brown-red patches a ring carries at the end of a
// hardcore match. A thin film tints the canvas rather than covering it.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D stains : hint_default_black, filter_linear, repeat_disable;
// match seconds, the same clock the green channel was written with
uniform float now = 0.0;
uniform float time_span = 1200.0;
uniform float dry = 180.0;

// Linear albedo, as on the skin (blood_overlay.gdshader). On a white mat
// even a thin film reads deep red, never pink: the first pass here used
// 0.42 and a light "soaked" pink, and the canvas looked painted.
const vec3 FRESH = vec3(0.100, 0.004, 0.005);
const vec3 THICK = vec3(0.032, 0.001, 0.002);
const vec3 DRIED = vec3(0.060, 0.014, 0.010);
const vec3 SOAKED = vec3(0.160, 0.030, 0.025);

void vertex() {
	// a hair above the mat, so the pass never loses the depth test to it
	VERTEX += NORMAL * 0.0015;
}

void fragment() {
	vec2 s = texture(stains, UV).rg;
	float amount = s.r;
	if (amount < 0.04) {
		discard;
	}
	float age = max(now - s.g * time_span, 0.0);
	float wet = 1.0 - clamp(age / dry, 0.0, 1.0);
	// thin film soaks in pink-brown; a run or a pool stands on the cloth
	float thick = smoothstep(0.06, 0.45, amount);
	vec3 wet_col = mix(FRESH, THICK, thick);
	vec3 dry_col = mix(SOAKED, DRIED, thick);
	ALBEDO = mix(dry_col, wet_col, wet);
	ROUGHNESS = mix(0.85, mix(0.5, 0.32, thick), wet);
	SPECULAR = 0.25;
	// crisp edges from a bilinear amount: the shape is the 0.1-0.25 contour
	float edge = smoothstep(0.05, 0.11, amount);
	ALPHA = edge * mix(0.88, 0.97, thick);
}
