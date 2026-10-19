shader_type spatial;
// Blood on a wrestler's skin (Blood): drawn over the skin as its material's
// next pass, so it skins with him -- no decal sliding over a moving body.
//
// `reveal` is the surface's baked map (tools/blood/bake_blood_masks.gd): red
// is the bleed level at which the head wound reaches each texel, green the
// back's. Blood shows where the wrestler's bleed has passed it, thicker and
// darker the longer it has been there (the further past), wet and glossy
// while it is fresh and duller as it dries.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D reveal : hint_default_white, filter_linear_mipmap, repeat_disable;
uniform float bleed_head : hint_range(0.0, 1.5) = 0.0;
uniform float bleed_back : hint_range(0.0, 1.5) = 0.0;
// 1 fresh and running, 0 dried: the time since he last bled more.
uniform float wet : hint_range(0.0, 1.0) = 1.0;

// Linear albedo. Blood is dark: whole blood reflects little but red, and
// under arena light even a fresh run reads deep crimson, not paint red (the
// first pass used 0.36 here and every render looked like red paint).
//
// The 19 Oct review (gauntlet/refs/nhb/weapon_review.md): at a full bleed the
// face read as a coat of red gloss -- opaque, one colour, mirror-shiny, runs
// of even width. Fresh blood under the hard light is a translucent film the
// skin shows through, dark only where it pools, sheened rather than glassy,
// and its runs wander and thin out. So a little darker again, the thin film
// thinner, the gloss satin, and the edges broken up at two scales.
const vec3 FRESH = vec3(0.120, 0.007, 0.007);
const vec3 THICK = vec3(0.045, 0.002, 0.003);
const vec3 DRIED = vec3(0.045, 0.010, 0.007);
// how far past its threshold a texel takes to go from the first trace to
// fully covered, and to fully thick
const float EDGE = 0.035;
const float BODY = 0.25;

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

float coverage(float threshold, float bleed) {
	if (threshold > 0.995) {
		return 0.0;
	}
	return clamp((bleed - threshold) / EDGE, 0.0, 1.0);
}

// Puncture marks: a scatter of small dots, each with a short run below it.
float punctures(vec2 uv) {
	vec2 g = uv * 140.0;
	vec2 c = floor(g);
	float best = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 cell = c + vec2(float(x), float(y));
			if (hash(cell * 1.31) > 0.45) {
				continue;
			}
			vec2 at = cell + vec2(hash(cell), hash(cell + 7.0));
			vec2 d = g - at;
			// the run trails one way along v (UV down is roughly body down)
			d.y = d.y > 0.0 ? d.y * 0.35 : d.y;
			best = max(best, 1.0 - smoothstep(0.10, 0.22, length(d)));
		}
	}
	return best;
}

void vertex() {
	// a hair off the skin, so the pass never loses the depth test to it
	VERTEX += NORMAL * 0.0008;
}

void fragment() {
	vec2 t = texture(reveal, UV).rg;
	// ragged edges: the threshold wanders a little texel to texel
	float n = noise(UV * 220.0);
	// and wanders at a coarser scale too, so a run narrows and widens
	float w = noise(UV * 48.0 + 11.0);
	float h = coverage(t.r + (n - 0.5) * 0.03 + (w - 0.5) * 0.06, bleed_head);
	float b = coverage(t.g + (n - 0.5) * 0.05, bleed_back);
	// the back starts as punctures and only joins up as it bleeds more
	float joined = smoothstep(0.12, 0.35, bleed_back - t.g);
	b *= mix(punctures(UV), 1.0, joined);
	float c = max(h, b);
	if (c <= 0.001) {
		discard;
	}
	float past = max((bleed_head - t.r) * step(0.001, h), (bleed_back - t.g) * step(0.001, b));
	// thick where it has been running longest, clotted unevenly
	float thick = clamp(past / BODY, 0.0, 1.0) * mix(0.65, 1.0, noise(UV * 90.0 + 3.0));
	vec3 col = mix(FRESH, THICK, thick);
	col = mix(DRIED, col, wet);
	ALBEDO = col;
	ROUGHNESS = mix(0.6, mix(0.4, 0.22, thick), wet);
	SPECULAR = 0.35;
	METALLIC = 0.0;
	// a thin first film tints the skin; a run of it hides it
	// mottled, so the skin's own pores and tone come through the film
	float film = mix(0.7, 1.0, noise(UV * 140.0 + 5.0));
	ALPHA = c * mix(0.35 * film, 0.92, thick);
}
