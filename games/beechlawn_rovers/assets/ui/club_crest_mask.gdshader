shader_type canvas_item;
// Preserve the supplied JPEG pixels. Mask only the white exterior around its
// tall oval; interior white lettering/fields remain opaque. UV is atlas UV.
void fragment() {
	vec2 source_pixel = UV * vec2(1280.0);
	vec2 oval = (source_pixel - vec2(640.0, 620.0)) / vec2(345.0, 486.0);
	vec4 ink = texture(TEXTURE, UV);
	ink.a *= 1.0 - smoothstep(0.995, 1.003, length(oval));
	COLOR = ink;
}
