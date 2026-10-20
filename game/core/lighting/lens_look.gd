class_name LensLook
extends RefCounted
## How a lit lens in the roof reads (the owner, 20 Oct: the lights near the
## top "look a bit 2 dimensional, unrealistic"). They were flat emissive
## discs: one even white from every angle, so a row of them was a row of
## stickers, and a lamp aimed away from the camera was as hot as one aimed
## straight down its barrel.
##
## A real lens is neither. Seen down the beam it is blinding; turned away it
## falls to the dim glass of its rim, and you see the can it sits in. Close
## enough to resolve, it is a hot core inside a dimmer reflector ring with a
## dark edge where the bezel starts. So:
##
##   * brightness follows how squarely the lens faces the camera (FLOOR off
##     axis, full on it, POWER between);
##   * a lens built round its own origin (the moving head's FixtureLens,
##     `radius` > 0) gets the core / reflector / edge profile across it;
##   * the colour is the gel's at the edge and white in the core.
##
## Unshaded: ALBEDO carries the HDR value, as StarGlints' does, so the core
## still crosses the glow threshold and blooms.

## A lens seen edge-on keeps this much of its light: the glass still glows.
const FLOOR := 0.12
## How quickly it falls off the beam axis: cos^POWER of the angle.
const POWER := 3.0

const SHADER := """
shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled;

uniform vec3 tint : source_color = vec3(1.0);
uniform float level = 3.0;
uniform float whiteness = 0.55;
uniform float radius = 0.0;
uniform float floor_level = 0.12;
uniform float power = 3.0;
varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float facing = floor_level + (1.0 - floor_level) * pow(ndv, power);
	float profile = 1.0;
	float core = whiteness;
	if (radius > 0.0) {
		float r = length(local_pos.xy) / radius;
		// The lamp's hot core, the reflector ring round it, the dark bezel lip.
		float hot = exp(-r * r * 9.0);
		float ring = 0.32 * exp(-pow((r - 0.72) / 0.12, 2.0));
		profile = 0.28 + 1.2 * hot + ring;
		profile *= 1.0 - 0.7 * smoothstep(0.86, 1.0, r);
		core = clamp(whiteness + hot * (1.0 - whiteness), 0.0, 1.0);
	}
	ALBEDO = mix(tint, vec3(1.0), core) * level * profile * facing;
}
"""

static var _shader: Shader


## A lens material in `color`, `level` bright on its axis. `radius` is the
## lens's own radius when the mesh is built round its origin facing -Z (the
## moving head's); 0 for a merged mesh of many lenses, which gets the
## facing falloff only.
static func material(color: Color, level: float, whiteness: float,
		radius := 0.0) -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("tint", Vector3(color.r, color.g, color.b))
	mat.set_shader_parameter("level", level)
	mat.set_shader_parameter("whiteness", whiteness)
	mat.set_shader_parameter("radius", radius)
	mat.set_shader_parameter("floor_level", FLOOR)
	mat.set_shader_parameter("power", POWER)
	return mat
