shader_type spatial;
render_mode cull_disabled;
global uniform float football_crowd_clock;
uniform vec4 home_primary : source_color = vec4(.025,.12,.64,1.0);
uniform vec4 home_secondary : source_color = vec4(.035,.04,.055,1.0);
uniform vec4 away_primary : source_color = vec4(.30,.61,.82,1.0);
uniform vec4 away_secondary : source_color = vec4(.035,.04,.055,1.0);
varying vec2 cloth_uv;
varying flat float away_flag;
void vertex(){
 cloth_uv=UV;
 away_flag=INSTANCE_CUSTOM.b;
 float speed=1.0+INSTANCE_CUSTOM.g*.22;
 VERTEX.z+=sin(UV.x*6.0-football_crowd_clock*4.3*speed+INSTANCE_CUSTOM.r*6.28)*UV.x*.09;
 VERTEX.y+=sin(UV.x*8.0-football_crowd_clock*3.2*speed+INSTANCE_CUSTOM.r*6.28)*UV.x*.035;
}
void fragment(){
 float stripe=step(.5,fract(cloth_uv.x*4.0));
 vec3 primary=mix(home_primary.rgb,away_primary.rgb,away_flag);
 vec3 secondary=mix(home_secondary.rgb,away_secondary.rgb,away_flag);
 ALBEDO=mix(secondary,primary,stripe);
 ROUGHNESS=.92;
}
