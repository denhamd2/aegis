shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass_albedo : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform bool stadium_mowing = false;
instance uniform vec4 exposed_edges=vec4(0.0);
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
 float near_blend=smoothstep(.65,1.4,distance_to_camera);
 float pixels=.022*VIEWPORT_SIZE.y*PROJECTION_MATRIX[1][1]/(2.0*max(.1,-VERTEX.z));
 float far_blend=smoothstep(.70,1.15,pixels);
 // Fade only exposed residency boundaries; internal neighbours stay dense.
 // Projected-size selection still works for high cameras and long lenses.
 vec2 within=fract(crown/4.0);
 float edge=min(min(mix(1.0,smoothstep(0.0,.22,within.x),exposed_edges.x),mix(1.0,smoothstep(0.0,.22,1.0-within.x),exposed_edges.y)),
  min(mix(1.0,smoothstep(0.0,.22,within.y),exposed_edges.z),mix(1.0,smoothstep(0.0,.22,1.0-within.y),exposed_edges.w)));
 ALPHA=cover*near_blend*far_blend*edge;
 ALPHA_HASH_SCALE=1.0;
 vec2 p=world_point.xz+vec2(52.5,34.0);
 vec2 rotated=mat2(vec2(.8,.6),vec2(-.6,.8))*p;
 vec3 turf=mix(texture(grass_albedo,rotated/2.8).rgb,texture(grass_albedo,p/.85).rgb,.65);
 ALBEDO=(stadium_mowing ? br_arena_colour(p,turf,CAMERA_POSITION_WORLD.xz) : br_pitch_colour(p,vec2(105.0,68.0),turf))*COLOR.rgb*mix(.90,1.01,UV.y);
 float wear=smoothstep(.22,.6,br_noise(world_point.xz*29.0));
 ALBEDO=mix(ALBEDO,stadium_mowing ? vec3(.68,.70,.64) : vec3(.43,.44,.35),paint*wear*.86);
 ROUGHNESS=.85; SPECULAR=.20; BACKLIGHT=ALBEDO*.25;
 if (!FRONT_FACING) NORMAL=-NORMAL;
 NORMAL=normalize(mix(NORMAL,(VIEW_MATRIX*vec4(0.0,1.0,0.0,0.0)).xyz,.85));
}
