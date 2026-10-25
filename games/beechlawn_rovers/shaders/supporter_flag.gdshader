shader_type spatial;
render_mode cull_disabled;
global uniform float football_crowd_clock;
varying vec2 cloth_uv;
void vertex(){
 cloth_uv=UV;
 VERTEX.z+=sin(UV.x*6.0-football_crowd_clock*4.3+INSTANCE_CUSTOM.r*6.28)*UV.x*.09;
 VERTEX.y+=sin(UV.x*8.0-football_crowd_clock*3.2+INSTANCE_CUSTOM.r*6.28)*UV.x*.035;
}
void fragment(){
 float stripe=step(.5,fract(cloth_uv.x*4.0));
 ALBEDO=mix(vec3(.02,.045,.085),vec3(.035,.22,.72),stripe);
 ROUGHNESS=.92;
}
