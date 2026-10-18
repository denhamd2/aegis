shader_type spatial;
render_mode cull_disabled;
varying vec3 field_position;
void vertex() { field_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	float grit=hash(floor(field_position.xz*100.0));
	float fade=0.5+0.5*sin(field_position.x*0.83+field_position.z*1.16);
	if (grit < 0.12+fade*0.20) { discard; }
	ALBEDO=mix(vec3(0.57,0.58,0.48),vec3(0.88,0.87,0.76),grit);
	ROUGHNESS=1.0;
}
