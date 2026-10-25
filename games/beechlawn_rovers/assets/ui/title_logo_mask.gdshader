shader_type canvas_item;
// Reveal the uploaded wordmark's original white and red pixels. The dark
// photographic backdrop is transparent; the logo's colour and aspect survive.
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float white_ink = smoothstep(0.24, 0.64, min(source.r, min(source.g, source.b)));
	float red_ink = smoothstep(0.40, 0.76, source.r)
		* smoothstep(0.18, 0.45, source.r - max(source.g, source.b));
	COLOR = vec4(source.rgb, source.a * max(white_ink, red_ink));
}
