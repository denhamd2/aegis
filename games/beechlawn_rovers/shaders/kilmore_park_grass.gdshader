shader_type spatial;
render_mode cull_back;
uniform sampler2D grass_albedo : source_color, repeat_enable;

// Low-cost, world-space park turf. Two broad noise scales produce the uneven
// public-park ground and localized worn/muddy traffic patches in the saved refs.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz;
	float broad = noise(p * 0.032);
	float patch = noise(p * 0.13 + vec2(8.1, 19.4));
	float fine = noise(p * 1.15);
	float blade = noise(vec2(p.x * 5.6 + p.y * 0.8, p.y * 22.0));
	vec3 turf = texture(grass_albedo, p / 8.0).rgb;
	vec3 tint = mix(vec3(0.69, 0.78, 0.57), vec3(0.94, 0.97, 0.80),
		clamp(broad * 0.48 + patch * 0.32 + fine * 0.12 + blade * 0.08, 0.0, 1.0));
	vec3 grass = turf * tint * 0.50;
	vec3 dry_soil = vec3(0.30, 0.25, 0.16);
	vec3 damp_soil = vec3(0.13, 0.15, 0.095);
	float worn = smoothstep(0.52, 0.76,
		noise(p * vec2(0.085, 0.17) + vec2(36.7, 5.8)));
	float traffic = smoothstep(0.48, 0.78,
		noise(p * vec2(0.19, 0.07) + vec2(17.4, 43.2)));
	float damp = smoothstep(0.51, 0.79, patch) * worn;
	vec3 soil = mix(dry_soil, damp_soil, damp);
	float wear_amount = clamp(worn * 0.42 + traffic * 0.22, 0.0, 0.58);
	ALBEDO = mix(grass, soil, wear_amount);
	ROUGHNESS = 0.98;
	SPECULAR = 0.08;
}
