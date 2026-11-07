// Owner's AEW stills: refs/crowd_lighting_2026_11_07/. Shape only the
// audience's indirect fill; ring exposure and direct fixtures stay independent.
// World-space distance keeps the result stable across broadcast camera cuts.
uniform float crowd_depth_from = 14.0;
uniform float crowd_depth_to = 34.0;
uniform float crowd_back_fill = 0.18;
uniform float crowd_upper_from = 3.0;
uniform float crowd_upper_to = 10.0;
uniform float crowd_upper_fill = 0.3;

float crowd_seating_fill(vec3 world) {
	float depth = smoothstep(crowd_depth_from, crowd_depth_to, length(world.xz));
	float height = smoothstep(crowd_upper_from, crowd_upper_to, world.y);
	return mix(1.0, crowd_back_fill, depth) * mix(1.0, crowd_upper_fill, height);
}
