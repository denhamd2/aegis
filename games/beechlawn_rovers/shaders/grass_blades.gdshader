shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap;
varying vec3 world_point;
varying float paint;
#include "res://shaders/grass_surface_common.gdshaderinc"
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float distance_to_camera=distance(world_point.xz,CAMERA_POSITION_WORLD.xz);
 VERTEX.y*=1.0-smoothstep(3.4,4.7,distance_to_camera);
 VERTEX.x+=sin(TIME*1.8+world_point.x*.7+world_point.z*.5)*VERTEX.y*.10;
 paint=INSTANCE_CUSTOM.r;
}
void fragment() {
 vec2 p=world_point.xz+vec2(52.5,34.0);
 vec3 turf=texture(grass_albedo,p/8.0).rgb;
 ALBEDO=br_pitch_colour(p,vec2(105.0,68.0),turf)*COLOR.rgb*mix(.75,1.15,UV.y);
 float wear=smoothstep(.22,.6,br_noise(world_point.xz*29.0));
 ALBEDO=mix(ALBEDO,vec3(.56,.56,.48),paint*wear*.86);
 ROUGHNESS=.95;SPECULAR=.15;
 BACKLIGHT=ALBEDO*.3;
 if (!FRONT_FACING) NORMAL=-NORMAL;
}
