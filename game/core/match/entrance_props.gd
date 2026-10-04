class_name EntranceProps
extends Node3D
## Roman's entrance props on his body: the ula fala at his neck and the AEW
## title, either worn round his waist or held in his left hand
## (tools/blender/roman_props.py; gauntlet/refs/entrances.md).
##
## The AEW title FOLLOWS a bone rather than being parented to it. The bone
## gives the position; the wrestler's own upright frame gives the orientation.
## A belt parented to hand_l would turn with every twist of the wrist as the
## arm goes up, and the plates would end the raise facing the rafters; held
## this way the plates face the camera the whole way, which is how a man shows
## a title off.
##
## The ula fala is not a follower at all: it is SKINNED to his own rig, the way
## EntranceCoat is. roman_props.py builds it on his body, in his skeleton's own
## coordinates, with the skin weights of the skin under each key, and exports
## the handful of bones those weights name. Here it keeps its own copy of
## that skeleton and copies his pose onto it on his `skeleton_updated` signal,
## which fires after the animation, the IK and every SkeletonModifier3D
## (RomanHeadShape's neck) have finished -- so it is always posed from the
## frame he is drawn in, never from the one before, and it deforms with the
## chest, the clavicles and the neck instead of floating off them. The earlier
## rigid version re-placed itself from one bone in `_process`, which lagged the
## skeleton and could not follow the arms up.
##
## Presentation only: nothing here has collision or touches match state, and
## EntranceDirector frees it at the bell.

const ULA_FALA := "res://assets/props/ula_fala.glb"
const TITLE := "res://assets/props/aew_title.glb"

## Part name -> material. Gold is a metal lit by the follow spot and the
## stage washes; the hall's ambient carries no reflections (material_library's
## note on arena_truss), so a pure conductor renders near-black between the
## lights. A little emission keeps it reading as gold in the dark.
static func _materials() -> Dictionary:
	# AEW_PlateArt: the plate artwork off the owner's atlas, cut to each
	# plate's outline (alpha), with relief, roughness and metal maps made from
	# the same art (tools/assets/build_title_textures.py). ORM so metal and
	# enamel on one plate each get their own response under the follow spot.
	var art := ORMMaterial3D.new()
	art.resource_name = "AEW_PlateArt"
	art.albedo_texture = load("res://assets/props/aew_title_art.png")
	art.normal_enabled = true
	art.normal_texture = load("res://assets/props/aew_title_art_normal.png")
	art.normal_scale = 0.8
	art.orm_texture = load("res://assets/props/aew_title_art_orm.png")
	art.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	art.alpha_scissor_threshold = 0.5
	art.cull_mode = BaseMaterial3D.CULL_DISABLED
	art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# The hall's ambient carries no reflections (material_library's note on
	# arena_truss), so a pure conductor goes near-black between the lights;
	# a trace of the art's own colour as emission keeps the gold reading.
	art.emission_enabled = true
	art.emission_texture = art.albedo_texture
	art.emission_energy_multiplier = 0.06
	# AEW_Gold: the slabs' edges -- the plate depth seen from the side.
	var gold := StandardMaterial3D.new()
	gold.resource_name = "AEW_Gold"
	gold.albedo_color = Color(0.93, 0.74, 0.40)
	gold.metallic = 1.0
	gold.roughness = 0.32
	# AEW_Leather: the tiling grain from the atlas's close-up swatch. The
	# strap's UVs are world metres (cube-projected), so this is tiles/metre.
	var leather := StandardMaterial3D.new()
	leather.resource_name = "AEW_Leather"
	leather.albedo_texture = load("res://assets/props/aew_leather.png")
	leather.albedo_color = Color(0.32, 0.31, 0.30)
	leather.normal_enabled = true
	leather.normal_texture = load("res://assets/props/aew_leather_normal.png")
	leather.normal_scale = 0.35
	leather.roughness = 0.55
	leather.uv1_scale = Vector3.ONE * 11.0
	# AEW_Snaps: brass rings, after the atlas's snap swatch.
	var snap := StandardMaterial3D.new()
	snap.resource_name = "AEW_Snaps"
	snap.albedo_color = Color(0.78, 0.60, 0.32)
	snap.metallic = 1.0
	snap.roughness = 0.4
	# The keys: glossy lacquered red, crimson at the root and a little orange
	# at the tip -- the colour ramp is baked into the glb as vertex colour
	# (roman_props.py FALA_RAMP). A clearcoat gives the hard wet highlight the
	# photograph shows, and a trace of emission keeps them red between the
	# stage lights, as with the title's gold.
	var red := StandardMaterial3D.new()
	red.resource_name = "FalaRed"
	red.vertex_color_use_as_albedo = true
	red.albedo_color = Color.WHITE
	red.roughness = 0.55
	red.metallic_specular = 0.12
	red.emission_enabled = true
	red.emission = Color(0.45, 0.02, 0.02)
	red.emission_energy_multiplier = 0.02
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.10, 0.07, 0.05)
	cord.roughness = 0.9
	return {
		"TitleArt": art, "HeldArt": art, "TitleGold": gold, "HeldGold": gold,
		"TitleStrap": leather, "HeldStrap": leather,
		"TitleSnap": snap, "HeldSnap": snap,
		"FalaRed": red, "FalaCord": cord,
	}


var _w: WrestlerController
var _fala: Node3D
## The ula fala's own copy of the skeleton it was exported with, and his
## skeleton it is driven from. `_fala_map[i]` is his bone index for the copy's
## bone i, or -1.
var _fala_skeleton: Skeleton3D
var _his: Skeleton3D
var _fala_map := PackedInt32Array()
var _title: Node3D
## Where the title is: "worn" (round his waist), "held", or "" (put down).
var _title_state := "worn"
## Once taken, the necklace is no longer posed from his skeleton.
var _fala_taken := false
var _with_title := true


## `with_title` false dresses the ula fala alone -- the OTC era carries no
## title (gauntlet/refs/entrances.md).
static func dress(wrestler: WrestlerController, with_title := true) -> EntranceProps:
	var props := EntranceProps.new()
	props.name = "EntranceProps"
	props._w = wrestler
	props._with_title = with_title
	props.top_level = true
	wrestler.add_child(props)
	return props


func _ready() -> void:
	var mats := _materials()
	_fala = _load(ULA_FALA, mats)
	if _with_title:
		_title = _load(TITLE, mats)
	_wear_fala()
	set_title("worn")
	_follow()


## Hang the necklace on his skeleton and drive its copy of the bones from his.
##
## The glb root goes UNDER his Skeleton3D with identity transforms, so the
## necklace's skeleton shares his global transform at every moment -- through
## the wrestler's moves, turns and physique scale -- with nothing to lag. Only
## the bone poses need copying, and those are copied on his `skeleton_updated`,
## after the animation, the IK and every modifier have posed him.
func _wear_fala() -> void:
	_his = _w.skeleton if _w else null
	if _fala == null or _his == null:
		return
	var found := _fala.find_children("*", "Skeleton3D", true, false)
	if found.is_empty():
		push_error("EntranceProps: the ula fala has no skeleton")
		return
	_fala_skeleton = found[0]
	_fala.reparent(_his, false)
	# Every node from the glb's root down to its skeleton is the Blender
	# armature's own placement (it carries his model's 1.035 scale); placing
	# him is his skeleton's job here, so all of them go to identity.
	var up: Node = _fala_skeleton
	while up != null and up != _his:
		if up is Node3D:
			(up as Node3D).transform = Transform3D.IDENTITY
		up = up.get_parent()
	_fala_map.clear()
	for i in _fala_skeleton.get_bone_count():
		_fala_map.append(_his.find_bone(_fala_skeleton.get_bone_name(i)))
	_his.skeleton_updated.connect(_sync_fala)
	_sync_fala()


func _sync_fala() -> void:
	if _fala_skeleton == null or _fala_taken:
		return
	for i in _fala_map.size():
		var j := _fala_map[i]
		if j >= 0:
			_fala_skeleton.set_bone_pose_position(i, _his.get_bone_pose_position(j))
			_fala_skeleton.set_bone_pose_rotation(i, _his.get_bone_pose_rotation(j))
			_fala_skeleton.set_bone_pose_scale(i, _his.get_bone_pose_scale(j))


func _exit_tree() -> void:
	if is_instance_valid(_his) and _his.skeleton_updated.is_connected(_sync_fala):
		_his.skeleton_updated.disconnect(_sync_fala)
	# It hangs off his skeleton, not off this node, so it does not go with it.
	# (Unless it was taken: whoever carries it owns it then.)
	if is_instance_valid(_fala) and _fala.get_parent() != self and not _fala_taken:
		_fala.queue_free()


func _load(path: String, mats: Dictionary) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("EntranceProps: %s failed to load" % path)
		return Node3D.new()
	var root: Node3D = packed.instantiate()
	add_child(root)
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := String(mi.name)
		if mats.has(key):
			mi.material_override = mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## The belt, to be carried (PropHandoff): it shows as held and stops following
## his hand. The caller owns it from here.
func take_title() -> Node3D:
	if _title == null:
		return null
	set_title("held")
	_title_state = "carried"
	return _title


## The ula fala, to be carried: it stops being posed from his bones and goes
## back to its own rest shape (a loop). The caller owns it from here.
func take_fala() -> Node3D:
	if _fala == null:
		return null
	if is_instance_valid(_his) and _his.skeleton_updated.is_connected(_sync_fala):
		_his.skeleton_updated.disconnect(_sync_fala)
	if _fala_skeleton:
		_fala_skeleton.reset_bone_poses()
	_fala_taken = true
	return _fala


## Where the neck sits in the ula fala's rest shape, in the skeleton's frame:
## the point a carrier holds it by.
func fala_neck_rest() -> Vector3:
	if _fala_skeleton == null:
		return Vector3.ZERO
	# The necklace carries Roman's own rig's bone names.
	for bone: String in ["J_Neck", "neck_01"]:
		var i := _fala_skeleton.find_bone(bone)
		if i >= 0:
			return _fala_skeleton.get_bone_global_rest(i).origin
	return Vector3.ZERO


func set_title(state: String) -> void:
	_title_state = state if _title else ""
	if _title == null:
		return
	for node in _title.find_children("", "MeshInstance3D", true, false):
		var n := String(node.name)
		(node as Node3D).visible = (state == "worn" and n.begins_with("Title")) \
				or (state == "held" and n.begins_with("Held"))


func set_fala_visible(on: bool) -> void:
	if _fala:
		_fala.visible = on


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if _w == null or _title_state == "carried":
		return
	var turn := Basis(Vector3.UP, _w.global_rotation.y)
	if _title == null:
		return
	if _title_state == "held":
		var hand := _bone("hand_l")
		if hand != Vector3.INF:
			# Real size: the belt is authored in metres off the atlas.
			_title.global_transform = Transform3D(turn, hand)
	else:
		# Worn: authored at Roman's own measured waist, so 1:1 on his hips --
		# and turned with them. Held level (turn alone) it stayed upright
		# while his pelvis tipped and his torso leaned into the walk and the
		# climb, and his stomach came out through the plates by up to 17 cm
		# (tools/probe/wear_clearance.tscn). Here it takes the pelvis's
		# rotation away from its rest, so at rest it is exactly as authored.
		var hips := _bone("pelvis")
		if hips != Vector3.INF:
			_title.global_transform = Transform3D(_pelvis_turn() * turn, hips)


## The pelvis's rotation away from its rest pose, in world space.
func _pelvis_turn() -> Basis:
	return _bone_turn("pelvis")


## A bone's rotation away from its rest pose, in world space.
func _bone_turn(canonical: String) -> Basis:
	var sk := _w.skeleton
	var i := sk.find_bone(_w._skeleton_bone_name(canonical)) if sk else -1
	if i < 0:
		return Basis.IDENTITY
	var s := sk.global_basis.orthonormalized()
	var local := sk.get_bone_global_pose(i).basis.orthonormalized() \
			* sk.get_bone_global_rest(i).basis.orthonormalized().inverse()
	return s * local * s.inverse()


func _bone(canonical: String) -> Vector3:
	var sk := _w.skeleton
	if sk == null:
		return Vector3.INF
	var i := sk.find_bone(_w._skeleton_bone_name(canonical))
	if i < 0:
		return Vector3.INF
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin
