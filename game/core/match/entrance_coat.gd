class_name EntranceCoat
extends Node
## Cody's entrance coat (tools/blender/cody_coat.py), worn for his entrance
## and taken off in the ring.
##
## The coat is SKINNED to his own rig -- built on his body and weighted with
## his own skin weights -- so it is not a prop that follows a bone like the
## ula fala: its meshes are moved onto his Skeleton3D and deform with it,
## sleeves bending at his elbows and the skirt swinging with his thighs.
##
## It keeps its OWN copy of the skeleton, the one it was exported with, and
## that copy is driven from his every frame: pinned to his skeleton's
## transform and every bone's pose copied across by name. Re-pointing the
## coat's skin at his Skeleton3D was the first attempt, and although its
## binds resolved (same names, identical bind poses) the coat stayed in the
## rest pose while he moved -- so the coat does not depend on runtime skin
## registration at all.
##
## Presentation only: EntranceDirector puts it on at his entrance, takes it
## off on his Coat_Off beat, and frees it at the bell.

const COAT := "res://assets/characters/cody_coat.glb"

var _meshes: Array[MeshInstance3D] = []
var _root: Node3D
var _own: Skeleton3D
var _his: Skeleton3D
## His bone index for each of the coat skeleton's bones, or -1.
var _map: PackedInt32Array = PackedInt32Array()


static func dress(wrestler: WrestlerController) -> EntranceCoat:
	var coat := EntranceCoat.new()
	coat.name = "EntranceCoat"
	wrestler.add_child(coat)
	coat._wear(wrestler.skeleton)
	return coat


func _wear(skeleton: Skeleton3D) -> void:
	if skeleton == null or not ResourceLoader.exists(COAT):
		return
	_his = skeleton
	_root = (load(COAT) as PackedScene).instantiate()
	add_child(_root)
	_root.top_level = true
	for candidate in _root.find_children("*", "Skeleton3D", true, false):
		_own = candidate
	var mats := _materials()
	for node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mats.has(String(mi.name)):
			mi.material_override = mats[String(mi.name)]
		_meshes.append(mi)
	if _own:
		for i in _own.get_bone_count():
			_map.append(_his.find_bone(_own.get_bone_name(i)))
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if _own == null or not is_instance_valid(_his):
		return
	# His skeleton's frame, and then every bone's local pose.
	_own.global_transform = _his.global_transform
	for i in _map.size():
		var j := _map[i]
		if j >= 0:
			_own.set_bone_pose_position(i, _his.get_bone_pose_position(j))
			_own.set_bone_pose_rotation(i, _his.get_bone_pose_rotation(j))
			_own.set_bone_pose_scale(i, _his.get_bone_pose_scale(j))


func set_worn(on: bool) -> void:
	if _root:
		_root.visible = on


static func _materials() -> Dictionary:
	# Satin coat fabric: white with the red panels and the gold trim painted
	# in (cody_coat.py); the ORM map makes the trim and studs metal.
	var body := ORMMaterial3D.new()
	body.albedo_texture = load("res://assets/characters/cody_coat_body.png")
	body.orm_texture = load("res://assets/characters/cody_coat_orm_body.png")
	body.cull_mode = BaseMaterial3D.CULL_DISABLED
	var sleeve := ORMMaterial3D.new()
	sleeve.albedo_texture = load("res://assets/characters/cody_coat_sleeve.png")
	sleeve.orm_texture = load("res://assets/characters/cody_coat_orm_sleeve.png")
	sleeve.cull_mode = BaseMaterial3D.CULL_DISABLED
	var collar := StandardMaterial3D.new()
	collar.albedo_color = Color(0.73, 0.10, 0.13)
	collar.roughness = 0.5
	collar.cull_mode = BaseMaterial3D.CULL_DISABLED
	var scales := StandardMaterial3D.new()
	scales.albedo_color = Color(0.93, 0.74, 0.40)
	scales.metallic = 1.0
	scales.roughness = 0.3
	scales.cull_mode = BaseMaterial3D.CULL_DISABLED
	return {"CoatBody": body, "CoatSkirt": body, "CoatSleeve": sleeve,
			"CoatCollar": collar, "CoatScales": scales}
