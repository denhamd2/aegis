class_name FoldingCoatProp
extends Node3D
## A compact, animated cloth stand-in for Cody's skinned entrance coat once
## he has pulled it clear of his shoulders. The two sleeves tuck in one at a
## time, then the body folds over itself while the handoff eases it to his
## waiting hand. Every visible part uses the entrance coat's cloth textures.

const FOLD_SECONDS := 1.55
const FOLDED_SIZE := Vector3(0.28, 0.18, 0.24)
const BODY_TEX := "res://assets/characters/cody_coat_body.png"
const SLEEVE_TEX := "res://assets/characters/cody_coat_sleeve.png"
const LINING_TEX := "res://assets/characters/cody_coat_lapel.png"

var _elapsed := 0.0
var _body: MeshInstance3D
var _left: MeshInstance3D
var _right: MeshInstance3D
var _left_home := Vector3(-0.28, 0.03, 0.0)
var _right_home := Vector3(0.28, 0.03, 0.0)
var _left_rot := Vector3(0.0, 0.0, -PI * 0.5)
var _right_rot := Vector3(0.0, 0.0, PI * 0.5)


func _ready() -> void:
	_build()


func advance_fold(delta: float) -> void:
	_elapsed = minf(_elapsed + delta, FOLD_SECONDS)
	var t := _elapsed / FOLD_SECONDS
	# Cody draws the left sleeve in first, then folds the right over it.
	var left_t := _ease(clampf(t / 0.42, 0.0, 1.0))
	var right_t := _ease(clampf((t - 0.32) / 0.43, 0.0, 1.0))
	_left.position = _left_home.lerp(Vector3(0.0, 0.12, 0.0), left_t)
	_left.rotation = _left_rot.lerp(Vector3(0.0, 0.0, 0.0), left_t)
	_left.scale = Vector3.ONE.lerp(Vector3(0.58, 0.68, 0.8), left_t)
	_right.position = _right_home.lerp(Vector3(0.0, 0.20, -0.015), right_t)
	_right.rotation = _right_rot.lerp(Vector3(0.0, 0.0, 0.0), right_t)
	_right.scale = Vector3.ONE.lerp(Vector3(0.56, 0.64, 0.78), right_t)
	var body_t := _ease(clampf((t - 0.55) / 0.45, 0.0, 1.0))
	_body.rotation.x = lerpf(0.0, -0.14, body_t)
	_body.scale = Vector3(1.0, 1.0, 1.0).lerp(Vector3(0.58, 0.23, 0.48), body_t)


func is_folded() -> bool:
	return _elapsed >= FOLD_SECONDS


func _build() -> void:
	var body_mat := _cloth(BODY_TEX, 0.58)
	var sleeve_mat := _cloth(SLEEVE_TEX, 0.62)
	var lining_mat := _cloth(LINING_TEX, 0.52)
	# Rounded, slightly flared body panels and separate sleeves read as cloth;
	# the coat is never represented by a cuboid that pops into his hand.
	var torso := CapsuleMesh.new()
	torso.radius = 0.22
	torso.height = 0.78
	_body = _part("CoatBodyCloth", torso, body_mat, Vector3(0.0, 0.0, 0.0))
	_body.scale = Vector3(1.0, 1.0, 0.72)
	var sleeve := CapsuleMesh.new()
	sleeve.radius = 0.075
	sleeve.height = 0.56
	_left = _part("LeftSleeveCloth", sleeve, sleeve_mat, _left_home, _left_rot)
	_right = _part("RightSleeveCloth", sleeve, sleeve_mat, _right_home, _right_rot)
	# Open cloth lapels give the collar and lining a clear silhouette while the
	# sleeves are folded inward.
	var lapel_mesh := _curved_panel_mesh(0.16, 0.38, 0.025)
	_part("LeftLiningLapel", lapel_mesh, lining_mat, Vector3(-0.09, 0.10, -0.155),
		Vector3(0.0, 0.0, -0.18))
	_part("RightLiningLapel", lapel_mesh, lining_mat, Vector3(0.09, 0.10, -0.155),
		Vector3(0.0, 0.0, 0.18))


func _part(node_name: String, mesh: Mesh, material: Material, at: Vector3,
		rot := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation = rot
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(part)
	return part


func _cloth(path: String, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(path) as Texture2D
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _curved_panel_mesh(width: float, height: float, bow: float) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for row in 3:
		var v := float(row) / 2.0
		for col in 3:
			var u := float(col) / 2.0
			vertices.append(Vector3((u - 0.5) * width, (0.5 - v) * height,
					bow * sin(u * PI)))
			uvs.append(Vector2(u, v))
	for row in 2:
		for col in 2:
			var a := row * 3 + col
			indices.append_array(PackedInt32Array([a, a + 3, a + 1, a + 1, a + 3, a + 4]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
