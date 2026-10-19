// Shared field-edge pigment and wear: keeps the playing area and park apron continuous.
float br_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float br_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(br_hash(i), br_hash(i + vec2(1.0, 0.0)), f.x),
		mix(br_hash(i + vec2(0.0, 1.0)), br_hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 br_pitch_colour(vec2 p, vec2 field_size, vec3 turf) {
	float broad = br_noise(p * 0.12);
	float fine = br_noise(p * 2.8);
	float mowing = 0.5 + 0.5 * sin((p.x + field_size.x * 0.5) * 0.72);
	vec3 tint = mix(vec3(0.73, 0.82, 0.62), vec3(0.96, 1.0, 0.84),
		clamp(broad * 0.5 + fine * 0.5, 0.0, 1.0));
	vec3 base = turf * tint * (0.63 + mowing * 0.018);
	vec2 centre=p-field_size*0.5;
	float goal_wear=exp(-pow((abs(centre.x)-field_size.x*0.5+2.0)/6.0,2.0)-pow(centre.y/5.0,2.0));
	float central_wear=exp(-dot(centre/vec2(12.0,9.0),centre/vec2(12.0,9.0)))*0.25;
	float traffic=exp(-pow((centre.y-8.0)/2.3,2.0))*br_noise(p*0.17)*0.22;
	float worn = smoothstep(0.50, 0.76, br_noise(p * vec2(0.56, 0.82) + vec2(11.3, 4.7)));
	float muddy = smoothstep(0.52, 0.78, br_noise(p * vec2(0.17, 0.29) + vec2(37.1, 12.2))) * worn;
	base = mix(base, vec3(0.29, 0.24, 0.15), worn * 0.17);
	base = mix(base, vec3(0.15, 0.16, 0.11), muddy * 0.20);
	base = mix(base,vec3(0.24,0.205,0.12),clamp(goal_wear*(0.36+fine*0.26)+central_wear+traffic,0.0,0.72));
	return base;
}
