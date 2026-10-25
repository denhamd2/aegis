shader_type spatial;
render_mode cull_disabled;
uniform sampler2D print_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float reveal : hint_range(0.0,1.0)=0.0;
uniform float cloth_time=0.0;
uniform float cloth_height=28.0;
varying vec3 world_position;
void vertex(){
 float down=1.0-clamp(VERTEX.y/cloth_height,0.0,1.0);
 // Fabric is stored as a concertina at the top. The deployed part retains
 // its print/UV length while the remaining folds gather around a rolled hem.
 float deployed=min(down,reveal);
 float folded=max(0.0,down-reveal);
 float pleat=sin(folded*95.0)*min(.20,folded*3.0);
 VERTEX.y=cloth_height-deployed*cloth_height-folded*.25;
 float pin=sin(clamp(down/max(.01,reveal),0.0,1.0)*1.5708);
 VERTEX.z+=pleat+sin(VERTEX.x*.52+cloth_time*1.4)*.10*pin+sin(down*18.0-cloth_time*1.8)*.045*pin;
 VERTEX.x+=sin(cloth_time*.9+down*7.0)*.035*pin;
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 vec4 ink=texture(print_texture,UV);
 ALPHA=ink.a;ALPHA_SCISSOR_THRESHOLD=.5;
 vec3 colour=ink.rgb;
 float weave=sin(UV.x*1700.0)*sin(UV.y*2100.0);
 ALBEDO=colour*(.985+weave*.015);
 ROUGHNESS=.94;
 // Derivatives include the animated folds instead of frozen flat normals.
 vec3 n=normalize(cross(dFdx(world_position),dFdy(world_position)));
 NORMAL=normalize((VIEW_MATRIX*vec4(n,0.0)).xyz);
}
