shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled;
uniform sampler2D net_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float impact_age=2.0;
uniform vec3 impact_point=vec3(0.0);
uniform vec3 impact_vector=vec3(0.0);
void vertex() {
 // Goal mesh local coordinates: x across goal, y height, z negative depth.
 // Both front-post ties, crossbar and ground attachments stay anchored.
 float d=distance(VERTEX,impact_point);
 float side_anchor=smoothstep(0.0,0.34,3.79-abs(VERTEX.x));
 float ground_anchor=smoothstep(0.0,0.22,VERTEX.y);
 float front_anchor=smoothstep(0.0,0.25,-VERTEX.z);
 float envelope=exp(-d*d*1.3)*side_anchor*ground_anchor*front_anchor;
 float response=exp(-impact_age*3.0)*sin(impact_age*16.0);
 VERTEX+=impact_vector*envelope*response;
}
void fragment() {
 vec4 rope=texture(net_texture,UV);
 ALPHA=rope.a;
 ALBEDO=rope.rgb;
 ROUGHNESS=0.96;
}
