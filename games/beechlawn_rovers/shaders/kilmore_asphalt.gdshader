shader_type spatial;
render_mode cull_back;

uniform sampler2D asphalt_albedo : source_color, repeat_enable;

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
	vec2 uv = world.xz / 4.0;
	vec3 asphalt = texture(asphalt_albedo, uv).rgb;
	float damp = smoothstep(0.52, 0.78, noise(world.xz * 0.08 + vec2(21.8, 4.3)));
	ALBEDO = asphalt * mix(vec3(0.78), vec3(0.60), damp);
	ROUGHNESS = 0.92;
	SPECULAR = 0.16;
}
