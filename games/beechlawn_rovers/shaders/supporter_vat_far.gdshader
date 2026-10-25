shader_type spatial;
render_mode cull_disabled;
global uniform float football_crowd_clock;
uniform sampler2D positions : filter_nearest, repeat_disable;
uniform int vertex_count=1;
uniform int texture_width=256;
uniform int texture_height=1;
uniform vec4 clip_from=vec4(0,46,3,0);
uniform vec4 clip_to=vec4(0,46,3,0);
uniform float from_time=0.0;
uniform float to_time=0.0;
uniform float transition_time=-10.0;
varying flat float enabled;
varying vec3 tint;
varying float shirt;
vec3 animated_position(vec4 clip,float seconds,int id){
 float phase=clip.w>.5?clamp(seconds/clip.z,0.0,1.0):fract(max(0.0,seconds)/clip.z);
 float frame=phase*(clip.y-1.0);
 int a=(int(clip.x)+int(frame))*vertex_count+id;
 int b=(int(clip.x)+min(int(frame)+1,int(clip.y)-1))*vertex_count+id;
 vec3 p=texelFetch(positions,ivec2(a%texture_width,texture_height-1-a/texture_width),0).xyz;
 vec3 q=texelFetch(positions,ivec2(b%texture_width,texture_height-1-b/texture_width),0).xyz;
 return mix(p,q,fract(frame));
}
void vertex(){
 float delay=INSTANCE_CUSTOM.g*.65;float phase=INSTANCE_CUSTOM.r*2.6;
 float blend=smoothstep(0.0,.55,football_crowd_clock-transition_time-delay);
 VERTEX=animated_position(clip_to,football_crowd_clock-to_time-delay+(clip_to.w<.5?phase:0.0),int(UV2.x+.5));
 if(blend<.999)VERTEX=mix(animated_position(clip_from,football_crowd_clock-from_time-delay+(clip_from.w<.5?phase:0.0),int(UV2.x+.5)),VERTEX,blend);
 // Distant bodies retain baked colour and rest normals; only the near tier
 // needs the extra animated-normal texture bandwidth.
 enabled=INSTANCE_CUSTOM.a;
 tint=INSTANCE_CUSTOM.b<.25?vec3(.04,.12,.4):INSTANCE_CUSTOM.b<.5?vec3(.09,.1,.12):INSTANCE_CUSTOM.b<.75?vec3(.65,.67,.7):vec3(.32,.34,.38);
 shirt=UV2.y;
}
void fragment(){
 if(enabled<.5)discard;
 ALBEDO=COLOR.rgb;
 ROUGHNESS=.86;
}
