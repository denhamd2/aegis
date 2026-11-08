// Kenny's hair cards: the curl atlas times the groom's vertex colour, cut
// out with alpha to coverage, with HairLook's stretched highlight -- what the
// StandardMaterial3D drew -- and a sway. The owner, 8 Nov: "his hair should be
// able to move as it's long".
//
// The cards' v runs root (1) to tip (0) (kenny_curls.py), so a vertex's share
// of the sway rises from nothing at the root to all of it at the tip, on a
// curve: the lengths swing, the roots stay put. `sway` is a model-space
// offset KennyModel drives from a damped spring on his head's motion.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, alpha_to_coverage_and_one;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float roughness = 0.7;
uniform float specular = 0.12;
uniform float anisotropy_ratio = 0.5;
uniform float alpha_scissor = 0.2;
uniform vec3 sway = vec3(0.0);
uniform float sway_amount = 1.0;

void vertex() {
	float rel = clamp(1.0 - UV.y, 0.0, 1.0);
	VERTEX += sway * (rel * rel * sway_amount);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ALPHA_ANTIALIASING_EDGE = alpha_scissor;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	ANISOTROPY = anisotropy_ratio;
	ANISOTROPY_FLOW = vec2(1.0, 0.0);
}
