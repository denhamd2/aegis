shader_type spatial;
render_mode cull_back;

uniform float field_length = 105.0;
uniform float field_width = 68.0;

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
	vec2 p = UV * vec2(field_length, field_width);
	float broad = noise(p * 0.12);
	float fine = noise(p * 2.8);
	float mowing = 0.5 + 0.5 * sin((p.x + field_length * 0.5) * 0.72);
	vec3 dark_grass = vec3(0.075, 0.155, 0.048);
	vec3 light_grass = vec3(0.15, 0.235, 0.075);
	vec3 base = mix(dark_grass, light_grass, mowing * 0.10 + broad * 0.37 + fine * 0.16);
	float worn = smoothstep(0.50, 0.76, noise(p * vec2(0.56, 0.82) + vec2(11.3, 4.7)));
	base = mix(base, vec3(0.23,0.21,0.13), worn * 0.22);
	ALBEDO = base;
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
}
