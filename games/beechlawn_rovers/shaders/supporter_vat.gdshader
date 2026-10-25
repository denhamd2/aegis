shader_type spatial;
render_mode cull_disabled;
global uniform float football_crowd_clock;
uniform sampler2D positions : filter_nearest, repeat_disable;
uniform sampler2D normals : filter_nearest, repeat_disable;
uniform sampler2D photo : source_color, filter_linear_mipmap, repeat_disable;
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
 garment=INSTANCE_CUSTOM.b<.25?vec3(.04,.12,.4):INSTANCE_CUSTOM.b<.5?vec3(.09,.1,.12):INSTANCE_CUSTOM.b<.75?vec3(.65,.67,.7):vec3(.32,.34,.38);shirt=UV2.y;
}
void fragment(){
 if(enabled<.5)discard;
 vec3 base=photographic?texture(photo,UV).rgb:COLOR.rgb;
 // Only the garment mask changes colour; faces retain their photographic skin.
 ALBEDO=base;
 ROUGHNESS=.86;
}
