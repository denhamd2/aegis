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
## that copy is driven from his: hung UNDER his Skeleton3D with identity
## transforms, so it shares his skeleton's global transform at every moment,
## and every bone's pose copied across by name on his `skeleton_updated` --
## after the animation, the IK and every modifier have posed him. The same
## as the ula fala (EntranceProps._wear_fala).
##
## It used to be a top-level node pinned to his skeleton's transform and
## copying his bone poses in _process. The owner, on his Mac: the coat
## flashed on and off through the entrance. Read in _process his transform
## is the physics tick's while his body is drawn interpolated between ticks
## (MatchSmoothing), and his bone poses are the ones from before his
## modifiers (Inertializer's between-tick draw among them) -- so the coat sat
## up to a tick of walking (~2 cm) off the body under it, by a different
## amount every frame, and his skin showed through it and was gone again.
##
## And it is bulked as his body is (BodyBulk.CODY, lining pushed the same way
## as the cloth): built on the body before the bulk, it no longer cleared his
## arms and shoulders by the bulk's 1-1.6 cm. Re-pointing the
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
var _w: WrestlerController
## His bone index for each of the coat skeleton's bones, or -1.
var _map: PackedInt32Array = PackedInt32Array()


static func dress(wrestler: WrestlerController) -> EntranceCoat:
	var coat := EntranceCoat.new()
	coat.name = "EntranceCoat"
	coat._w = wrestler
	wrestler.add_child(coat)
	coat._wear(wrestler.skeleton)
	return coat


func _wear(skeleton: Skeleton3D) -> void:
	if skeleton == null or not ResourceLoader.exists(COAT):
		return
	_his = skeleton
	_root = (load(COAT) as PackedScene).instantiate()
	_his.add_child(_root)
	for candidate in _root.find_children("*", "Skeleton3D", true, false):
		_own = candidate
	# Placing him is his skeleton's job: every node from the glb's root down
	# to its skeleton goes to identity.
	var up: Node = _own
	while up != null and up != _his:
		if up is Node3D:
			(up as Node3D).transform = Transform3D.IDENTITY
		up = up.get_parent()
	if _own:
		BodyBulk.apply(_root, _own, BodyBulk.CODY, LINING)
	var mats := _materials()
	for node in _root.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var set: Array = mats.get(String(mi.name), [])
		for i in mini(set.size(), mi.mesh.get_surface_count()):
			mi.set_surface_override_material(i, set[i])
		_meshes.append(mi)
	if _own:
		for i in _own.get_bone_count():
			_map.append(_his.find_bone(_own.get_bone_name(i)))
	_his.skeleton_updated.connect(_follow)
	_follow()


## The inner shell (Solidify) of each part: its normals face his body, so the
## bulk pushes it the other way, outward with the cloth.
const LINING := {"CoatBody": [1], "CoatSkirt": [1], "CoatSleeve": [1]}


func _follow() -> void:
	if _own == null or not is_instance_valid(_his):
		return
	for i in _map.size():
		var j := _map[i]
		if j >= 0:
			_own.set_bone_pose_position(i, _his.get_bone_pose_position(j))
			_own.set_bone_pose_rotation(i, _his.get_bone_pose_rotation(j))
			_own.set_bone_pose_scale(i, _his.get_bone_pose_scale(j))


func set_worn(on: bool) -> void:
	if is_instance_valid(_root):
		_root.visible = on


## It hangs off his skeleton, not off this node, so it does not go with it.
func _exit_tree() -> void:
	if is_instance_valid(_his) and _his.skeleton_updated.is_connected(_follow):
		_his.skeleton_updated.disconnect(_follow)
	if is_instance_valid(_root):
		_root.queue_free()


## The coat, to be carried (PropHandoff): the skinned coat cannot leave his
## body (its rest pose is a T, and it is weighted to his bones), so it is
## hidden and a small folded coat -- the same cloth, lining and trim -- takes
## its place in his right hand. The caller owns the prop from here.
func take_coat() -> Node3D:
	set_worn(false)
	var prop := folded_coat()
	prop.name = "FoldedCoat"
	add_child(prop)
	# It starts in his hand, so taking it is not a jump.
	if _w and is_instance_valid(_his):
		var bone := _his.find_bone(_w._skeleton_bone_name("hand_r"))
		if bone >= 0:
			prop.global_position = (_his.global_transform * _his.get_bone_global_pose(bone)).origin
	return prop


## Size of the folded coat, metres: long, across, thick. Lies flat on a table
## with its long side along the table (PropHandoff._table_holder).
const FOLDED := Vector3(0.30, 0.08, 0.24)


## A coat folded on itself: a thick body of the outer cloth, the red lining
## showing along one edge where it is turned back, and the two sleeves folded
## across the top. Origin at its centre.
static func folded_coat() -> Node3D:
	var mats := _materials()
	var body_m: Material = (mats["CoatBody"] as Array)[0]
	var lining_m: Material = (mats["CoatBody"] as Array)[1]
	var sleeve_m: Material = (mats["CoatSleeve"] as Array)[0]
	var trim_m: Material = (mats["CoatScales"] as Array)[0]
	var root := Node3D.new()
	var box := BoxMesh.new()
	box.size = FOLDED
	root.add_child(_mesh("FoldBody", box, body_m, Vector3.ZERO, Vector3.ZERO))
	# The lining turned back along the front edge.
	var lap := BoxMesh.new()
	lap.size = Vector3(FOLDED.x * 0.98, 0.012, 0.06)
	root.add_child(_mesh("FoldLining", lap, lining_m,
			Vector3(0.0, FOLDED.y * 0.5 + 0.004, -FOLDED.z * 0.5 + 0.045), Vector3.ZERO))
	# A gold edge at the collar end.
	var edge := BoxMesh.new()
	edge.size = Vector3(0.018, FOLDED.y + 0.004, FOLDED.z * 0.94)
	root.add_child(_mesh("FoldTrim", edge, trim_m,
			Vector3(FOLDED.x * 0.5 - 0.008, 0.0, 0.0), Vector3.ZERO))
	# Two sleeves folded over the top, crossing a little.
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var cap := CapsuleMesh.new()
		cap.radius = 0.04
		cap.height = 0.20
		root.add_child(_mesh("FoldSleeve%d" % k, cap, sleeve_m,
				Vector3(-0.03, FOLDED.y * 0.5 + 0.03, side * 0.05),
				Vector3(deg_to_rad(90.0), deg_to_rad(side * 14.0), 0.0)))
	return root


static func _mesh(node_name: String, mesh: Mesh, mat: Material, at: Vector3,
		rot: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _materials() -> Dictionary:
	# The cloth: a satin-backed drill, white with the red panels and the
	# gold trim painted in (cody_coat.py). The ORM makes the trim and studs
	# metal and breaks up the cloth's roughness; the normal map carries the
	# twill and the fine folds; a little rim is the sheen cloth has at a
	# grazing angle. The coat has thickness now (Solidify), so it is drawn
	# one-sided and its inner shell is the lining.
	var body := _cloth("res://assets/characters/cody_coat_body.png",
			"res://assets/characters/cody_coat_orm_body.png",
			"res://assets/characters/cody_coat_nrm_body.png")
	var sleeve := _cloth("res://assets/characters/cody_coat_sleeve.png",
			"res://assets/characters/cody_coat_orm_sleeve.png",
			"res://assets/characters/cody_coat_nrm_sleeve.png")
	var lining := StandardMaterial3D.new()
	lining.albedo_color = Color(0.42, 0.05, 0.07)
	lining.roughness = 0.45
	var lapel := StandardMaterial3D.new()
	lapel.albedo_texture = load("res://assets/characters/cody_coat_lapel.png")
	lapel.roughness = 0.55
	lapel.rim_enabled = true
	lapel.rim = 0.3
	lapel.rim_tint = 0.5
	lapel.cull_mode = BaseMaterial3D.CULL_DISABLED
	# The stand collar: white with the gold lip and seam, both faces drawn --
	# its inside is in shot whenever he throws his head back.
	var collar := _cloth("res://assets/characters/cody_coat_collar.png",
			"res://assets/characters/cody_coat_orm_collar.png",
			"res://assets/characters/cody_coat_nrm_sleeve.png")
	collar.cull_mode = BaseMaterial3D.CULL_DISABLED
	var scales := StandardMaterial3D.new()
	scales.albedo_color = Color(0.93, 0.74, 0.40)
	scales.metallic = 1.0
	scales.roughness = 0.3
	scales.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Per part: [outer, lining]. The glb carries one surface per material
	# slot, in slot order -- slot 1 is Solidify's inner shell.
	return {"CoatBody": [body, lining], "CoatSkirt": [body, lining],
			"CoatSleeve": [sleeve, lining], "CoatLapel": [lapel],
			"CoatCollar": [collar], "CoatScales": [scales]}


static func _cloth(albedo: String, orm: String, normal: String) -> ORMMaterial3D:
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(albedo)
	m.orm_texture = load(orm)
	m.normal_enabled = true
	m.normal_texture = load(normal)
	m.normal_scale = 0.8
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
