shader_type spatial;
render_mode cull_back;

uniform float field_length = 105.0;
uniform float field_width = 68.0;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
varying vec3 world_point;
uniform sampler2D surface_masks : filter_linear, repeat_disable;
uniform sampler2D mud_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D mud_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float wear_strength : hint_range(0.0, 1.0) = 0.0;
uniform bool stadium_mowing = false;
uniform float arena_wetness = 0.0;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;

#include "res://shaders/grass_surface_common.gdshaderinc"

void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }

void fragment() {
	vec2 p = UV * vec2(field_length, field_width);
	float close = 1.0-smoothstep(1.8,5.0,distance(world_point,CAMERA_POSITION_WORLD));
	vec2 rotated=mat2(vec2(.8,.6),vec2(-.6,.8))*p;
	vec3 turf = mix(texture(grass_albedo,rotated/2.8).rgb,texture(grass_albedo,p/.85).rgb,.38+close*.27);
	ALBEDO = br_pitch_colour(p,vec2(field_length,field_width),turf);
	if (stadium_mowing) {
		ALBEDO = br_arena_colour(p,turf,CAMERA_POSITION_WORLD.xz);
	}
	vec2 surface = texture(surface_masks, UV).rg * wear_strength;
	float mud = surface.r;
	float water = surface.g * wetness;
	float grain = br_noise(p * 15.0);
	vec3 soil = texture(mud_albedo,p/1.3).rgb * mix(0.9,0.55,wetness);
	ALBEDO = mix(ALBEDO, soil * (0.88 + grain * 0.18), mud * 0.94);
	ALBEDO = mix(ALBEDO, vec3(0.045,0.052,0.036), water * 0.75);
	float turf_roughness = clamp(texture(grass_roughness,p/1.4).r,.72,.98);
	// Damp leaves remain a rough, fibrous canopy. Treating the whole arena
	// as a smooth wet sheet washed out the cuts in sunlight. Standing water
	// retains its separate localized reflection and roughness response.
	if (stadium_mowing) {
		turf_roughness = max(.88,turf_roughness)-arena_wetness*.06;
	}
	ROUGHNESS = mix(mix(turf_roughness,texture(mud_roughness,p/1.3).r*0.65+0.22,mud*wetness),0.13,water);
	SPECULAR = mix(stadium_mowing ? .12+arena_wetness*.02 : .24,.5,water);
	// Small capillary ripples; wet mud stays rougher than standing water.
	vec3 ripples = normalize(vec3(0.025*sin(p.x*27.0+p.y*13.0+TIME*1.8),
		0.025*cos(p.y*31.0-p.x*9.0+TIME*1.4),1.0))*0.5+0.5;
	vec3 turf_normal = mix(vec3(.5,.5,1.0),texture(grass_normal,p/.85).rgb,.22+close*.40);
	// Rolled bands change the aggregate leaf response, not the slope of the
	// whole pitch. Broad normal waves opposed the colour bands rather than
	// describing the fine grass texture.
	NORMAL_MAP = mix(mix(turf_normal,texture(mud_normal,p/1.3).rgb,mud*0.7),ripples,water);
	METALLIC = 0.0;
	BACKLIGHT=ALBEDO*.12*(1.0-water);
}
