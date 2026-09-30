class_name AubreyModel
extends Node3D
## The referee, Aubrey Edwards (assets/characters/aubrey_edwards.glb, built by
## tools/blender/referee_aubrey.py from Quaternius' CC0 base characters).
##
## She is rigged on the base rig's own skeleton -- the same 65 bone names in
## the same hierarchy -- so, like CodyModel, there is no bone map and no
## retarget: the keys are copied and only the track paths are rebased.
##
## One thing differs from Cody, and it is why the position tracks go. The
## base rig's clips key a POSITION on every bone, not only on the pelvis, and
## those positions are the base rig's proportions: its shoulder sits 4 cm
## further out than hers, its hip 2 cm further. Played as they are, every clip
## would stretch her onto a man's frame -- shoulders pulled wide of the
## shirt, legs spread. So only the rotations are kept, and the pelvis position
## (the one that carries crouches, kneels and the walk's bob), shifted by the
## difference between the two rigs' pelvis rests so her feet stay on the mat.
##
## Presentation only: nothing in a match reads her. RefereeActor drives her.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"
const STRIKES := "res://resources/animations/strike_clips.tres"
## The base rig's pelvis rest, local to its parent `root` bone, which is
## Z-up (wrestler_base.glb, measured): what the pelvis tracks are keyed in.
const BASE_PELVIS_REST := Vector3(0.0, 0.0501, 0.9167)
## She is 1.70 m; the kit's body is 1.767 m.
const HEIGHT := 1.70
const KIT_HEIGHT := 1.767


func _ready() -> void:
	var source := get_node_or_null("Source") as Node3D
	if source:
		source.scale = Vector3.ONE * (HEIGHT / KIT_HEIGHT)
	_install_animations()
	_dress_fabric()


## Cloth, not plastic: woven fabric catches light at grazing angles (the fuzz
## of its fibres), which glTF has no slot for. A rim term stands in for that
## sheen on her shirt, trim and trousers, tinted by the cloth's own colour.
const FABRIC := {"M_RefStripes": 0.35, "M_RefTrim": 0.3, "M_Trousers": 0.4}
const FABRIC_RIM_TINT := 0.7


func _dress_fabric() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not FABRIC.has(source.resource_name):
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.rim_enabled = true
			material.rim = FABRIC[source.resource_name]
			material.rim_tint = FABRIC_RIM_TINT
			mi.set_surface_override_material(surface, material)


func _install_animations() -> void:
	var player := $AnimationPlayer as AnimationPlayer
	if player == null or get_game_skeleton() == null:
		push_error("AubreyModel: expected an AnimationPlayer and a Skeleton3D")
		return
	var root: Node = (load(BASE_RIG) as PackedScene).instantiate()
	var rig_player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if rig_player:
		player.add_animation_library("", adapt_animation_library(rig_player.get_animation_library("")))
	root.free()
	if ResourceLoader.exists(STRIKES):
		player.add_animation_library(StrikeRecipes.LIBRARY,
				adapt_animation_library(load(STRIKES) as AnimationLibrary))


## The library rebased onto this model's skeleton, rotations only bar the
## pelvis (see the class note).
func adapt_animation_library(source: AnimationLibrary) -> AnimationLibrary:
	var skeleton := get_game_skeleton()
	var skeleton_path := get_path_to(skeleton)
	var pelvis := skeleton.find_bone("pelvis")
	var shift := Vector3.ZERO
	if pelvis >= 0:
		shift = skeleton.get_bone_rest(pelvis).origin - BASE_PELVIS_REST
	var target := AnimationLibrary.new()
	for name in source.get_animation_list():
		var animation: Animation = source.get_animation(name).duplicate(true)
		for track in range(animation.get_track_count() - 1, -1, -1):
			var bone := String(animation.track_get_path(track).get_concatenated_subnames())
			if bone == "":
				continue
			var kind := animation.track_get_type(track)
			if kind == Animation.TYPE_SCALE_3D or (kind == Animation.TYPE_POSITION_3D and bone != "pelvis"):
				animation.remove_track(track)
				continue
			animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone]))
			if kind == Animation.TYPE_POSITION_3D:
				for k in animation.track_get_key_count(track):
					animation.track_set_key_value(track, k, animation.track_get_key_value(track, k) + shift)
		target.add_animation(name, animation)
	return target


func get_game_skeleton() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D
