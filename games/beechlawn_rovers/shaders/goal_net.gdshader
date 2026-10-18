shader_type spatial;
render_mode cull_disabled;
uniform sampler2D net_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform float impact_age=2.0;
uniform vec3 impact_point=vec3(0.0);
void vertex() {
	float d=distance(VERTEX,impact_point);
	float ripple=sin(impact_age*25.0-d*8.0)*exp(-impact_age*5.0-d*0.8)*0.055;
	VERTEX+=NORMAL*ripple;
}
void fragment() {
	vec4 sample_color=texture(net_texture,UV);
	if(sample_color.a<0.4){discard;}
	ALBEDO=sample_color.rgb;
	ROUGHNESS=0.96;
}
