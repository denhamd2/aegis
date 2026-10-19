shader_type spatial;
// Burn marks on a wrestler's skin (ManFire): charred, blistered patches where
// he has burned. They spread while he is alight and stay for the rest of the
// match. A char at the centre of each patch, a red-brown blister ring round
// it, and the edges ragged on two scales of noise, so no two marks match.
// Drawn over the skin as its material's last next pass, like the blood.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

// 0 untouched, 1 burned over the whole body. Only ever raised (ManFire).
uniform float burn : hint_range(0.0, 1.0) = 0.0;
uniform float seed_offset = 0.0;

// Linear albedo: a char is near black, and the blister the colour of scalded skin.
const vec3 CHAR = vec3(0.030, 0.024, 0.022);
const vec3 BLISTER = vec3(0.24, 0.07, 0.04);

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

void fragment() {
	vec2 p = UV * vec2(7.0, 9.0) + vec2(seed_offset, seed_offset * 0.37);
	// a few blobs of noise; the threshold falls as the burn spreads, so the
	// patches grow outward from where they started
	float n = noise(p) * 0.6 + noise(p * 2.9 + 3.1) * 0.4;
	float ragged = (noise(UV * 180.0) - 0.5) * 0.10;
	float level = 1.05 - burn * 0.75;
	float burned = smoothstep(level - 0.03 + ragged, level + 0.01 + ragged, n);
	float charred = smoothstep(level + 0.07, level + 0.13, n + ragged);
	vec3 col = mix(BLISTER, CHAR, charred);
	ALBEDO = col;
	ROUGHNESS = mix(0.9, 0.7, charred);
	SPECULAR = 0.3;
	METALLIC = 0.0;
	ALPHA = burned * 0.92;
}
