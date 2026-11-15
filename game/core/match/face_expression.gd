class_name FaceExpression
extends Node
## Two small blend shapes on each detailed wrestler head: parted mouth for a
## hard hit or hold, and a tightened brow and lips for sustained pain. The
## model's rest sculpt runs first; these shapes leave its source GLB untouched.

const OPEN := &"pain_open"
const CLENCH := &"pain_clench"

var wrestler: WrestlerController
var meshes: Array[MeshInstance3D] = []
var _open := 0.0
var _clench := 0.0


static func fields(mouth: float, z: float, open: bool) -> Array:
	if open:
		return [
			[Vector3(0, mouth - 0.011, z), Vector3(0.048, 0.021, 0.030),
					Vector3(0, -0.008, 0.001), false],
			[Vector3(0, mouth + 0.006, z), Vector3(0.040, 0.014, 0.025),
					Vector3(0, 0.003, 0.001), false],
			[Vector3(0, mouth - 0.038, z - 0.015), Vector3(0.061, 0.029, 0.050),
					Vector3(0, -0.004, 0), false],
		]
	return [
		[Vector3(0.032, mouth + 0.082, z - 0.004), Vector3(0.027, 0.018, 0.039),
				Vector3(-0.001, -0.004, 0.002), true],
		[Vector3(0.032, mouth - 0.001, z), Vector3(0.017, 0.013, 0.025),
				Vector3(-0.002, 0.001, 0.002), true],
		[Vector3(0, mouth - 0.009, z), Vector3(0.038, 0.012, 0.025),
				Vector3(0, 0.002, 0), false],
	]


static func make_profile(materials: Array, mouth: float, z: float) -> Dictionary:
	return {"materials": materials, "open": fields(mouth, z, true), "clench": fields(mouth, z, false),
		"mesh_tokens": ["mouthbag", "teeth", "combinations_ALPHA"]}


func install(model: Node3D) -> void:
	if not model.has_method("expression_profile"): return
	var profile: Dictionary = model.expression_profile()
	if profile.is_empty(): return
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "PortraitRoots":
			continue
		var source := mi.mesh as ArrayMesh
		if source == null or source.get_blend_shape_count() > 0:
			continue
		var surfaces := []
		var shapes := []
		var moved := 0
		for s in source.get_surface_count():
			var mat := source.surface_get_material(s)
			var mat_name := mat.resource_name if mat else ""
			var eligible: bool = profile["materials"].has(mat_name)
			for token: String in profile["mesh_tokens"]:
				eligible = eligible or String(mi.name).contains(token)
			var base := source.surface_get_arrays(s)
			var pair := []
			for is_open in [true, false]:
				var shape := []
				shape.resize(Mesh.ARRAY_MAX)
				for slot in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT]:
					if base[slot] != null:
						shape[slot] = base[slot].duplicate()
				if eligible:
					moved += RomanFaceShape.sculpt(shape, profile["open" if is_open else "clench"])
				# ArrayMesh morph targets store offsets from the base surface,
				# not absolute positions. Feeding the sculpted coordinates here
				# doubles the head and pulls teeth and beard through the face.
				var vertices := shape[Mesh.ARRAY_VERTEX] as PackedVector3Array
				var original := base[Mesh.ARRAY_VERTEX] as PackedVector3Array
				for v in vertices.size():
					vertices[v] -= original[v]
				shape[Mesh.ARRAY_VERTEX] = vertices
				# Normals and tangents are replacement directions in Godot's
				# mesh format; the rest of each surface must retain its base
				# directions when a shape reaches full weight.
				pair.append(shape)
			surfaces.append(base)
			shapes.append(pair)
		if moved == 0:
			continue
		var mesh := ArrayMesh.new()
		mesh.add_blend_shape(OPEN)
		mesh.add_blend_shape(CLENCH)
		for s in source.get_surface_count():
			var flags := source.surface_get_format(s) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			mesh.add_surface_from_arrays(source.surface_get_primitive_type(s), surfaces[s],
					shapes[s], {}, flags)
			mesh.surface_set_material(s, source.surface_get_material(s))
			mesh.surface_set_name(s, source.surface_get_name(s))
		mi.mesh = mesh
		meshes.append(mi)


func _physics_process(_delta: float) -> void:
	if wrestler == null or meshes.is_empty() or wrestler.fsm == null or wrestler.combat == null:
		return
	var state := wrestler.fsm.current_state
	var hurt := clampf(wrestler.combat.wear / 100.0, 0.0, 1.0)
	var acute := state == WrestlerFSM.State.HIT_REACT or state == WrestlerFSM.State.DOWN \
			or state == WrestlerFSM.State.SUBMISSION_DEFENDER
	var target_open := 0.75 if acute and wrestler._hit_sell >= WrestlerController.Sell.HEAVY else 0.0
	var target_clench := maxf(hurt * 0.65, 0.55 if acute else 0.0)
	_open = move_toward(_open, target_open, 0.10)
	_clench = move_toward(_clench, target_clench * (1.0 - _open * 0.4), 0.08)
	for mi in meshes:
		mi.set_blend_shape_value(0, _open)
		mi.set_blend_shape_value(1, _clench)
