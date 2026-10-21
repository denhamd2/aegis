shader_type canvas_item;
// Sample the supplied sheet's head panel without changing its source pixels.
uniform vec4 source_region = vec4(0.864, 0.0, 0.136, 0.205);
void fragment() {
	vec4 portrait = texture(TEXTURE, source_region.xy + UV * source_region.zw);
	portrait.a *= COLOR.a;
	portrait.a *= 1.0 - smoothstep(0.965, 1.0, length(UV * 2.0 - 1.0));
	COLOR = portrait;
}
