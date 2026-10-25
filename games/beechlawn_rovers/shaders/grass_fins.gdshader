shader_type spatial;
render_mode cull_disabled, alpha_to_coverage;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
varying vec3 world_point;
varying vec2 crown;
varying float paint;
varying float seed;
#include "res://shaders/grass_surface_common.gdshaderinc"
float blade_hash(float p) { return fract(sin(p*127.1)*43758.5453); }
void vertex() {
 world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 crown=(MODEL_MATRIX*vec4(0.0,0.0,0.0,1.0)).xz;
 paint=INSTANCE_CUSTOM.r; seed=INSTANCE_CUSTOM.g;
 VERTEX.x+=sin(TIME*1.6+crown.x)*VERTEX.y*.08;
}
void fragment() {
 float column=floor(UV.x*18.0);
 float bend=(blade_hash(column+seed*31.0)-.5)*.65;
 float at=fract(UV.x*18.0+UV.y*UV.y*bend);
 float height=.48+.5*blade_hash(column+seed*73.0);
 float width=mix(.34,.055,clamp(UV.y/height,0.0,1.0));
 float cover=(1.0-smoothstep(width-.08,width+.08,abs(at-.5)))*(1.0-smoothstep(height-.10,height,UV.y));
 float distance_to_camera=distance(world_point,CAMERA_POSITION_WORLD);
 float near_blend=smoothstep(1.25,2.4,distance_to_camera);
 float pixels=.022*VIEWPORT_SIZE.y*PROJECTION_MATRIX[1][1]/(2.0*max(.1,-VERTEX.z));
 float far_blend=smoothstep(.70,1.15,pixels);
 ALPHA=cover*near_blend*far_blend;
 ALPHA_SCISSOR_THRESHOLD=.4;
 ALPHA_ANTIALIASING_EDGE=.2;
 ALPHA_TEXTURE_COORDINATE=UV*vec2(512.0,64.0);
 vec2 p=world_point.xz+vec2(52.5,34.0);
 vec3 turf=texture(grass_albedo,p/1.4).rgb;
 ALBEDO=br_pitch_colour(p,vec2(105.0,68.0),turf)*COLOR.rgb*mix(.72,1.02,UV.y);
 float wear=smoothstep(.22,.6,br_noise(world_point.xz*29.0));
 ALBEDO=mix(ALBEDO,vec3(.43,.44,.35),paint*wear*.86);
 ROUGHNESS=.85; SPECULAR=.20; BACKLIGHT=ALBEDO*.25;
 if (!FRONT_FACING) NORMAL=-NORMAL;
}
