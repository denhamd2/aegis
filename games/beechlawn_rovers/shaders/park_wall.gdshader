shader_type spatial;
varying vec3 p;
void vertex() { p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
float hash(vec2 v) { return fract(sin(dot(v,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
	vec2 q=vec2(abs(NORMAL.x)>0.6?p.z:p.x,p.y);
	float row=floor(q.y/0.225);
	vec2 block=vec2(fract(q.x/0.45+mod(row,2.0)*0.5),fract(q.y/0.225));
	float mortar=1.0-smoothstep(0.015,0.045,min(min(block.x,1.0-block.x),min(block.y,1.0-block.y)));
	float grain=hash(floor(q*220.0));
	float damp=(1.0-smoothstep(0.0,0.65,p.y))*(0.7+0.3*sin(p.x*1.6+p.z));
	ALBEDO=mix(vec3(0.43,0.44,0.39),vec3(0.31,0.33,0.29),mortar*0.55+damp*0.35)*(0.9+grain*0.18);
	ROUGHNESS=0.97;
}
