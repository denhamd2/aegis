class_name StarGlints
extends Node3D
## The star filter WWE 2K26's entrances are shot through
## (gauntlet/refs/lighting_2k26.md item 8): every fixture whose lens looks
## back down the camera throws a star (six long points, six short). One
## camera-facing additive quad per fixture lens; the shader brightens it by how squarely the beam
## points at the lens of the camera, so a fixture aimed away throws nothing
## and one sweeping through the camera flares as it passes.
##
## Presentation only, no collision, nothing reads it. `strength` is the
## global `glint_strength`, set per look by ArenaLighting.set_look.

## Screen size of a star, as a fraction of the camera's distance to it.
const SIZE := 0.09
## How tightly a glint follows the beam: cos^POWER of the angle between the
## beam and the line to the camera. 10 keeps it to roughly a 30-degree cone.
const POWER := 10.0

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

global uniform float glint_strength;
instance uniform vec3 beam_dir = vec3(0.0, -1.0, 0.0);
instance uniform vec3 tint = vec3(1.0);
uniform float size = 0.09;
uniform float power = 10.0;
varying float facing;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float dist = length(cam - centre);
	facing = pow(max(dot(normalize(beam_dir), normalize(cam - centre)), 0.0), power);
	// Billboard, scaled with distance so the star holds its size on screen.
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * dist * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	// A star filter's look, not a drawing of one. The first version read as
	// "a hub with spokes" (the owner's words): its spokes were cut in ANGLE,
	// so each widened with distance into a bar; they were still ~10% bright
	// where the quad's square edge chopped them; and a x6 gain clipped all six
	// to flat white round a pin-dot core. Now: each spoke is a line of fixed
	// width that tapers to a point and is gone before the edge, alternate
	// spokes shorter (the 6+6 of a real filter), and most of the light is a
	// soft core and halo -- the lens -- that the streaks come out of.
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float spokes = 0.0;
	for (int i = 0; i < 6; i++) {
		float ang = float(i) * 3.14159265 / 6.0;
		vec2 dir = vec2(cos(ang), sin(ang));
		float len = (i % 2 == 0) ? 1.0 : 0.6;
		float t = clamp(r / len, 0.0, 1.0);
		float d = abs(dot(p, vec2(-dir.y, dir.x)));
		float w = 0.012 * (1.0 - t) + 0.0025;
		spokes += exp(-(d * d) / (w * w)) * pow(1.0 - t, 2.2) * (i % 2 == 0 ? 1.0 : 0.55);
	}
	float core = exp(-r * r * 220.0) * 3.0;
	float halo = exp(-r * 9.0) * 0.6 + exp(-r * r * 30.0) * 0.3;
	float v = (spokes * 1.6 + core + halo) * facing * glint_strength;
	// Fixture colour in the halo, white in the core and streaks, a faint
	// warm-to-cool fringe out along the spokes.
	vec3 fringe = mix(vec3(1.0, 0.97, 0.92), vec3(0.88, 0.94, 1.0), smoothstep(0.1, 0.6, r));
	vec3 col = mix(tint, vec3(1.0), clamp(core + spokes, 0.0, 1.0)) * fringe;
	// Unshaded draws ALBEDO only -- EMISSION is ignored -- so the over-bright
	// HDR value goes there; only the core crosses the glow threshold.
	ALBEDO = col * v * 3.0;
}
"""

var _material: ShaderMaterial
var _glints := {}   # SpotLight3D -> MeshInstance3D


func _ready() -> void:
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("size", SIZE)
	_material.set_shader_parameter("power", POWER)


## One star on `light`'s lens. Re-aim with `aim()` when the beam moves.
func add_for(light: SpotLight3D) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mi := MeshInstance3D.new()
	mi.name = "Glint" + String(light.name)
	mi.mesh = quad
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The billboard is built in the vertex shader, so the culling box must
	# hold it at any size it can take.
	mi.extra_cull_margin = 16.0
	add_child(mi)
	mi.global_position = light.global_position
	mi.set_instance_shader_parameter("tint", Vector3(light.light_color.r,
			light.light_color.g, light.light_color.b))
	_glints[light] = mi
	aim(light)


func aim(light: SpotLight3D) -> void:
	var mi: MeshInstance3D = _glints.get(light)
	if mi:
		mi.set_instance_shader_parameter("beam_dir", -light.global_transform.basis.z)
