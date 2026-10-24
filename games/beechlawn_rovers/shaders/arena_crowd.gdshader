shader_type spatial;
render_mode cull_disabled;
varying vec4 fan;
void vertex() {
 fan = INSTANCE_CUSTOM;
 // Cylindrical billboards: upright seated spectators, grouped for culling.
 vec3 right = normalize(vec3(INV_VIEW_MATRIX[0].x,0.0,INV_VIEW_MATRIX[0].z));
 vec3 forward = normalize(cross(right,vec3(0.0,1.0,0.0)));
 MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right,0.0),vec4(0.0,1.0,0.0,0.0),vec4(forward,0.0),MODEL_MATRIX[3]);
 VERTEX.y += sin(TIME*2.1+fan.a*37.0)*0.012*UV.y;
}
void fragment() {
 vec2 head=(UV-vec2(.5,.17))/vec2(.19,.17);
 float face=1.0-step(1.0,dot(head,head));
 float torso=step(.32,UV.y)*step(UV.y,.94)*step(abs(UV.x-.5),mix(.42,.28,UV.y));
 ALPHA=max(face,torso);
 ALPHA_SCISSOR_THRESHOLD=.5;
 ALBEDO=mix(fan.rgb,vec3(.76,.60,.52),face);
 float hair=face*step(UV.y,.095);
 ALBEDO=mix(ALBEDO,vec3(.13,.10,.085),hair);
 ROUGHNESS=.95;
 SPECULAR=.12;
}
