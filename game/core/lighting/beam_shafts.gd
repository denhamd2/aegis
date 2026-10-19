class_name BeamShafts
extends Node3D
## Drawn light shafts for the stage's beam lights: a thin additive cone down
## each beam, soft at its edges and fading along its throw.
##
## The owner's 2026 Dynamite stills (18 Oct) show the stage's moving heads and
## truss spots as tight, crisp pencils of light crossing in the haze. Ours
## were volumetric fog, and the fog grid is far coarser than a 4-degree beam:
## however narrow the cone, it smeared into a broad bright wedge. A drawn
## cone keeps the beam as thin as the lamp, on every renderer.
##
## Each shaft is a child of its light, so it follows every pan and tilt the
## entrance cues give the heads, and goes when the light is hidden. Its glow
## follows the light's own colour and energy each frame, so a cue's tint, a
## blackout or an iris fade carries to the shaft. Presentation only.

## Shaft brightness at the core of the beam with its light at rest energy.
## A cue that boosts or dims the light scales the shaft with it.
@export var strength := 0.35
## The drawn shaft's half-width against the light's own cone: the visible
## pencil is the hot core of the beam, not its full field.
const WIDTH_OF_CONE := 0.3
## The shaft's radius at the lens.
const LENS_RADIUS := 0.09
const SEGMENTS := 16
## How far down its range a shaft is drawn before it has faded out.
const LENGTH_OF_RANGE := 0.85

const SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

instance uniform vec3 glow = vec3(0.0);
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
// Metres over which a shaft fades out into whatever it passes into (the deck,
// a wall, a man): without it the cone's wall cuts a hard ring where it meets
// the floor.
uniform float soft_depth = 1.2;

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 scene = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float behind = (-scene.z / scene.w) - (-VERTEX.z);
	float soft = clamp(behind / soft_depth, 0.0, 1.0);
	// Soft edges: bright where the cone faces the camera, gone where its
	// side turns edge-on -- the look of a round beam in haze.
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float edge = pow(facing, 2.5);
	// Along the throw: a quick fade in off the lens, a long fade out.
	float t = UV.y;
	float along = smoothstep(0.0, 0.04, t) * pow(1.0 - t, 1.6);
	ALBEDO = glow * edge * along * soft;
}
"""

var _material: ShaderMaterial
var _shafts := {}   # SpotLight3D -> MeshInstance3D
var _rest := {}     # SpotLight3D -> its energy when the shaft was added


func _init() -> void:
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader


## One shaft down `light`'s beam.
func add_for(light: SpotLight3D) -> void:
	var mi := MeshInstance3D.new()
	mi.name = "Shaft"
	mi.mesh = cone(light.spot_range * LENGTH_OF_RANGE,
			light.spot_range * LENGTH_OF_RANGE * tan(deg_to_rad(light.spot_angle)) * WIDTH_OF_CONE)
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	light.add_child(mi)
	_shafts[light] = mi
	_rest[light] = maxf(light.light_energy, 0.001)
	_update(light, mi)


func shafts() -> Dictionary:
	return _shafts


## An open cone from the origin down -Z (a light's forward), `length` long and
## `radius` wide at its far end; UV.y runs 0 at the lens to 1 at the end.
static func cone(length: float, radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var slope := (radius - LENS_RADIUS) / length
	for ring: int in 2:
		var r := LENS_RADIUS if ring == 0 else radius
		var z := 0.0 if ring == 0 else -length
		for s: int in SEGMENTS + 1:
			var a := TAU * s / SEGMENTS
			var dir := Vector3(cos(a), sin(a), 0.0)
			verts.append(dir * r + Vector3(0.0, 0.0, z))
			normals.append((dir + Vector3(0.0, 0.0, slope)).normalized())
			uvs.append(Vector2(float(s) / SEGMENTS, float(ring)))
	for s: int in SEGMENTS:
		var a := s
		var b := s + 1
		var c := s + SEGMENTS + 1
		var d := c + 1
		indices.append_array([a, c, b, b, c, d])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _process(_delta: float) -> void:
	for light: SpotLight3D in _shafts:
		if is_instance_valid(light):
			_update(light, _shafts[light])


func _update(light: SpotLight3D, mi: MeshInstance3D) -> void:
	var c: Color = light.light_color * (light.light_energy / float(_rest[light])) * strength
	mi.set_instance_shader_parameter("glow", Vector3(c.r, c.g, c.b))
