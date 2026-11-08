// Kenny's hair cards: the curl atlas times the groom's vertex colour, cut
// out with alpha to coverage, with an anisotropic highlight along the
// strands -- and a sway. The owner, 8 Nov: "his hair should be able to move
// as it's long".
//
// The groom writes each vertex's share of its length into COLOR.a (0 root,
// 1 tip; kenny_curls.py), so the sway rises from nothing at the root to all
// of it at the tip, on a curve: the lengths swing, the roots stay put.
// `sway` is a model-space offset KennyModel drives from a damped spring on
// his head's motion.
//
// Loop 7 (art director, review 6): the highlight's flow runs along v, the
// strands' direction; a little back-light for the rim through the hair.
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, alpha_to_coverage_and_one;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
// Loop 8: the sheen rides the strands -- specular and the back-light scale
// with the atlas's tone (a strand's lit side), roughness runs from matte in
// the gaps to glossy on the crests: untinted specular everywhere read as a
// white plastic sheet.
uniform float rough_dark = 0.7;
uniform float rough_bright = 0.4;
uniform float specular = 0.2;
uniform float anisotropy_ratio = 0.8;
uniform float alpha_scissor = 0.25;
uniform float backlight = 0.35;
uniform vec3 sway = vec3(0.0);
uniform float sway_amount = 1.0;

void vertex() {
	float rel = clamp(COLOR.a, 0.0, 1.0);
	VERTEX += sway * (rel * rel * sway_amount);
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	ALBEDO = t.rgb * COLOR.rgb;
	ALPHA = t.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ALPHA_ANTIALIASING_EDGE = alpha_scissor;
	ROUGHNESS = mix(rough_dark, rough_bright, t.r);
	SPECULAR = specular * t.r;
	ANISOTROPY = anisotropy_ratio;
	ANISOTROPY_FLOW = vec2(0.0, 1.0);
	BACKLIGHT = COLOR.rgb * backlight * t.r;
}
