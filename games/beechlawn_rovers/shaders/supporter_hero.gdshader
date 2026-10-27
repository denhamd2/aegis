shader_type spatial;
render_mode cull_disabled;
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 team_primary : source_color = vec4(.025,.12,.64,1.0);
uniform vec4 team_secondary : source_color = vec4(.035,.04,.055,1.0);
uniform float garment_variant=0.0;

vec3 clothing_colour(float code){
 int v=int(floor(code*12.0));
 vec3 p=team_primary.rgb;vec3 s=team_secondary.rgb;
 if(v==0)return p;
 if(v==1)return s;
 if(v==2)return mix(p,s,.25);
 if(v==3)return mix(p,s,.5);
 if(v==4)return p*.78;
 if(v==5)return s*1.35;
 if(v==6)return p*1.22;
 if(v==7)return mix(p,s,.72);
 if(v==8)return vec3(.37,.13,.12);
 if(v==9)return vec3(.24,.30,.18);
 if(v==10)return vec3(.49,.40,.29);
 return vec3(.30,.33,.37);
}

void fragment(){
 vec3 base=texture(photo,UV).rgb;
 float detail=clamp(dot(base,vec3(.2126,.7152,.0722))*1.4,.55,1.3);
 // UV2.y is the exported Info garment mask on every close-up supporter.
 ALBEDO=mix(base,clothing_colour(garment_variant)*detail,clamp(UV2.y,0.0,1.0));
 ROUGHNESS=.86;
}
