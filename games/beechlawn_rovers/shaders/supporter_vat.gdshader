shader_type spatial;
render_mode cull_disabled;
global uniform float football_crowd_clock;
uniform sampler2D positions : filter_nearest, repeat_disable;
uniform sampler2D normals : filter_nearest, repeat_disable;
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 team_primary : source_color = vec4(.025,.12,.64,1.0);
uniform vec4 team_secondary : source_color = vec4(.035,.04,.055,1.0);
uniform int vertex_count=1;
uniform int texture_width=256;
uniform vec4 clip_from=vec4(0,46,3,0);
uniform vec4 clip_to=vec4(0,46,3,0);
uniform float from_time=0.0;
uniform float to_time=0.0;
uniform float transition_time=-10.0;
uniform bool photographic=false;
varying flat float enabled;
varying vec3 garment;
varying float shirt;
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
vec3 sample_vat(sampler2D tex,vec4 clip,float seconds,int id){
 float phase=clip.w>.5?clamp(seconds/clip.z,0.0,1.0):fract(max(0.0,seconds)/clip.z);
 float frame=phase*(clip.y-1.0);
 int a=(int(clip.x)+int(floor(frame)))*vertex_count+id;
 int b=(int(clip.x)+min(int(ceil(frame)),int(clip.y)-1))*vertex_count+id;
 return mix(texelFetch(tex,ivec2(a%texture_width,textureSize(tex,0).y-1-a/texture_width),0).xyz,texelFetch(tex,ivec2(b%texture_width,textureSize(tex,0).y-1-b/texture_width),0).xyz,fract(frame));
}
void vertex(){
 float delay=INSTANCE_CUSTOM.g*.65;
 float phase=INSTANCE_CUSTOM.r*2.6;
 float blend=smoothstep(0.0,.55,football_crowd_clock-transition_time-delay);
 vec3 a=sample_vat(positions,clip_from,football_crowd_clock-from_time-delay+(clip_from.w<.5?phase:0.0),int(UV2.x+.5));
 vec3 b=sample_vat(positions,clip_to,football_crowd_clock-to_time-delay+phase*float(clip_to.w<.5),int(UV2.x+.5));
 VERTEX=mix(a,b,blend);
 NORMAL=normalize(mix(sample_vat(normals,clip_from,football_crowd_clock-from_time-delay+(clip_from.w<.5?phase:0.0),int(UV2.x+.5)),sample_vat(normals,clip_to,football_crowd_clock-to_time-delay+phase*float(clip_to.w<.5),int(UV2.x+.5)),blend));
 enabled=INSTANCE_CUSTOM.a;
 garment=clothing_colour(INSTANCE_CUSTOM.b);shirt=UV2.y;
}
void fragment(){
 if(enabled<.5)discard;
 vec3 base=photographic?texture(photo,UV).rgb:COLOR.rgb;
 // Preserve photographic fabric variation while leaving skin and hair untouched.
 float detail=clamp(dot(base,vec3(.2126,.7152,.0722))*1.4,.55,1.3);
 ALBEDO=mix(base,garment*detail,clamp(shirt,0.0,1.0));
 ROUGHNESS=.86;
}
