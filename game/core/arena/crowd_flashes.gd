class_name CrowdFlashes
extends Node3D
## The camera flashes in the stands: small points of light at head height, not
## a lit person.
##
## One MultiMesh of additive billboards, an emitter per sampled spectator. Each
## emitter flashes on its own clock -- its own slot grid, offset by its seed --
## so no two ever go off together; a flash lasts one slot (about 3-4 frames) and
## decays through it, with the environment's glow as the bloom. How often is
## the global `crowd_flash_rate` (flashes per second for a fully active
## emitter), and how active an emitter is depends on where it sits: a slow
## noise over the bowl makes some stands dense with phones and others dark.
## It is a vertex/fragment shader reading TIME and the global, so, like the
## crowd's own motion, it cannot touch gameplay or a replay's hash, and it runs
## on gl_compatibility as well as Forward+.

## How many emitters, and how far from them the camera must be to see one.
const EMITTERS := 1400
const NEAR_FADE_FROM := 5.0
const NEAR_FADE_TO := 12.0
## How big a flash reads, in metres at the emitter and as a floor on screen:
## SCREEN_SIZE is metres per metre of distance, so a flash is the same few
## pixels at 10 m and at 40 m.
const MIN_SIZE := 0.10
const SCREEN_SIZE := 0.0065
const SLOT := 0.06
## A phone is held up in front of and above the head.
const HELD_UP := 0.14
const HELD_OUT := 0.22
const SEED := 20261004


## Emitter positions from the crowd's own meshes: a random figure's head (its
## highest vertex), lifted and pushed toward the ring. `meshes` are the Crowd
## and CrowdFar MeshInstance3D nodes.
static func sample_positions(meshes: Array, count: int, seed_value: int) -> PackedVector3Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# One person is every vertex that shares a phase (crowd.py writes one per
	# figure into UV.x), so the head is that group's highest vertex.
	var heads := {}
	for m: MeshInstance3D in meshes:
		if m == null or m.mesh == null or m.mesh.get_surface_count() == 0:
			continue
		var arrays: Array = m.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var xf: Transform3D = m.global_transform if m.is_inside_tree() else m.transform
		if uv.size() != v.size():
			continue
		for i in v.size():
			var key := int(uv[i].x * 1.0e6)
			var world := xf * v[i]
			if not heads.has(key) or world.y > (heads[key] as Vector3).y:
				heads[key] = world
	var out := PackedVector3Array()
	var keys := heads.keys()
	keys.sort()
	if keys.is_empty():
		return out
	for _i in count:
		var world: Vector3 = heads[keys[rng.randi_range(0, keys.size() - 1)]]
		var toward := Vector3(-world.x, 0.0, -world.z)
		if toward.length() > 0.01:
			toward = toward.normalized()
		out.append(world + Vector3.UP * HELD_UP + toward * HELD_OUT)
	return out


## The golden-ratio seed of emitter `i` in [0, 1): every emitter on a clock of
## its own, spread evenly so no two share a slot.
static func emitter_seed(i: int) -> float:
	return fposmod(float(i) * 0.6180339887, 1.0)


## The MultiMesh and its shader, with emitters at `positions`.
func build(positions: PackedVector3Array) -> void:
	for c in get_children():
		c.queue_free()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = positions.size()
	for i in positions.size():
		var p := positions[i]
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_custom_data(i, Color(emitter_seed(i), activity_at(p), 0.0, 0.0))
	# Cull by the bowl, not the sampled points' (tiny) bounds.
	mm.custom_aabb = AABB(Vector3(-80, -2, -80), Vector3(160, 40, 160))
	var node := MultiMeshInstance3D.new()
	node.name = "Flashes"
	node.multimesh = mm
	node.material_override = _material()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## How busy the stand around `p` is, 0.15-1.6: slow noise over the bowl, so
## phones cluster in some sections and others are dark.
static func activity_at(p: Vector3) -> float:
	var n := 0.5 + 0.5 * sin(p.x * 0.19 + 1.3) * cos(p.z * 0.23 - 0.7)
	n = 0.5 * n + 0.5 * (0.5 + 0.5 * sin((p.x + p.z) * 0.11 + p.y * 0.3))
	return lerpf(0.15, 1.6, smoothstep(0.15, 0.85, n))


func _material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

global uniform float crowd_flash_rate;
uniform float slot_len = %f;
uniform float min_size = %f;
uniform float screen_size = %f;
uniform float near_from = %f;
uniform float near_to = %f;
uniform float intensity = 7.0;
varying float glow;

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void vertex() {
	float seed = INSTANCE_CUSTOM.r;
	float act = INSTANCE_CUSTOM.g;
	// This emitter's own clock: its slot grid is shifted by its seed, so no
	// two flash on the same frame, and each slot is an independent roll.
	float t = TIME + seed * 13.37;
	float slot = floor(t / slot_len);
	float within = fract(t / slot_len);
	float roll = hash(seed * 977.0 + slot * 0.7311);
	float p = clamp(crowd_flash_rate * act * slot_len, 0.0, 1.0);
	float on = step(roll, p);
	// Bright at once, gone in a few frames.
	glow = on * pow(1.0 - within, 1.8);
	vec3 centre = MODEL_MATRIX[3].xyz;
	float dist = length((VIEW_MATRIX * vec4(centre, 1.0)).xyz);
	glow *= smoothstep(near_from, near_to, dist);
	float size = max(min_size, dist * screen_size) * (0.7 + 0.5 * hash(seed * 31.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX *= size * step(0.001, glow);
}

void fragment() {
	float d = length(UV * 2.0 - 1.0);
	// A hot core and a soft halo.
	float a = exp(-d * d * 7.0) + 0.25 * exp(-d * d * 1.6);
	ALBEDO = vec3(1.0, 0.97, 0.90) * a * glow * intensity;
	ALPHA = 1.0;
}
""" % [SLOT, MIN_SIZE, SCREEN_SIZE, NEAR_FADE_FROM, NEAR_FADE_TO]
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat
