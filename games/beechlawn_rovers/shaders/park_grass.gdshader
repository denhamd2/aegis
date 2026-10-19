shader_type spatial;
render_mode cull_back;

uniform float field_length = 105.0;
uniform float field_width = 68.0;
uniform sampler2D grass_albedo : source_color, repeat_enable;

#include "res://shaders/grass_surface_common.gdshaderinc"

void fragment() {
	vec2 p = UV * vec2(field_length, field_width);
	vec3 turf = texture(grass_albedo, p / 8.0).rgb;
	ALBEDO = br_pitch_colour(p,vec2(field_length,field_width),turf);
	ROUGHNESS = 0.96;
	METALLIC = 0.0;
}
