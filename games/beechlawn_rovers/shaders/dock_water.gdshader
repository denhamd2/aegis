shader_type spatial;
render_mode cull_back;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 cell=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(cell),hash(cell+vec2(1,0)),f.x),mix(hash(cell+vec2(0,1)),hash(cell+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world.xz;
 float warping=noise(p*.23+vec2(TIME*.04,TIME*.027));
 float a=sin(p.x*1.7+p.y*.73+warping*9.0+TIME*1.05);
 float b=sin(p.y*2.4-p.x*.44+warping*7.0+TIME*.77);
 float footprint=length(fwidth(p));float filtered=1.0/(1.0+footprint*2.0);
 NORMAL_MAP=normalize(vec3(a*.035*filtered,b*.025*filtered,1.0))*.5+.5;
 ALBEDO=mix(vec3(.018,.043,.045),vec3(.026,.058,.057),warping);
 ROUGHNESS=.30+min(.2,footprint*.1);METALLIC=0.0;SPECULAR=.25;
}
