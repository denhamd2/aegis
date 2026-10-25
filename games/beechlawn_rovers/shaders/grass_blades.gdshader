shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool stadium_mowing = false;
varying vec3 world_point;
varying float paint;
#include "res://shaders/grass_surface_common.gdshaderinc"
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float distance_to_camera=distance(world_point,CAMERA_POSITION_WORLD);
 VERTEX.y*=1.0-smoothstep(.95,1.55,distance_to_camera);
 VERTEX.x+=sin(TIME*1.8+world_point.x*.7+world_point.z*.5)*VERTEX.y*.10;
 paint=INSTANCE_CUSTOM.r;
}
void fragment() {
 vec2 p=world_point.xz+vec2(52.5,34.0);
 float close=1.0-smoothstep(1.8,5.0,distance(world_point,CAMERA_POSITION_WORLD));
 vec2 rotated=mat2(vec2(.8,.6),vec2(-.6,.8))*p;
 vec3 turf=mix(texture(grass_albedo,rotated/2.8).rgb,texture(grass_albedo,p/.85).rgb,.38+close*.27);
 ALBEDO=(stadium_mowing ? br_arena_colour(p,turf,CAMERA_POSITION_WORLD.xz) : br_pitch_colour(p,vec2(105.0,68.0),turf))*COLOR.rgb*mix(.90,1.01,UV.y);
 float wear=smoothstep(.22,.6,br_noise(world_point.xz*29.0));
 ALBEDO=mix(ALBEDO,stadium_mowing ? vec3(.68,.70,.64) : vec3(.43,.44,.35),paint*wear*.86);
 ROUGHNESS=.85;SPECULAR=.20;
 BACKLIGHT=ALBEDO*.3;
 if (!FRONT_FACING) NORMAL=-NORMAL;
 // Hemispherical turf normals keep the near crown's average light response
 // continuous with the ground, rather than turning each resident cell dark.
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,.85));
}
