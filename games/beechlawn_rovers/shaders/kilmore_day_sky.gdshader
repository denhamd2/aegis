shader_type sky;
render_mode use_debanding;

// Photographed clouds provide structure; these controls balance the sky only.
// Bilinear sampling matches Godot's PanoramaSkyMaterial. Implicit mip
// derivatives across the longitude wrap otherwise make a grey vertical seam.
uniform sampler2D cloud_panorama : source_color, filter_linear, repeat_enable;
uniform float sky_energy : hint_range(0.1, 3.0) = 1.0;
uniform float sky_saturation : hint_range(0.0, 1.2) = 0.68;
uniform float horizon_haze : hint_range(0.0, 0.4) = 0.18;
uniform vec3 horizon_tint : source_color = vec3(0.76, 0.82, 0.88);

void sky() {
	vec3 photograph = texture(cloud_panorama, SKY_COORDS).rgb;
	float luminance = dot(photograph, vec3(0.2126, 0.7152, 0.0722));
	vec3 balanced = mix(vec3(luminance), photograph, sky_saturation) * sky_energy;
	float low_horizon = pow(1.0 - clamp(EYEDIR.y * 8.0, 0.0, 1.0), 3.0);
	COLOR = mix(balanced, horizon_tint, low_horizon * horizon_haze);
}
