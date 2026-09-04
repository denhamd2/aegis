extends Node3D
## Adapts the user-supplied Roman model to the game's universal wrestler rig.
## The source has no animations, so the base rig's animation library is reused
## after its tracks are remapped to Roman's named body bones.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"

const BONE_MAP := {
	"pelvis": "J_Hips",
	"spine_02": "J_Spine2",
	"spine_03": "J_Chest",
	"neck_01": "J_Neck",
	"Head": "J_Head",
	"clavicle_l": "J_Clavicle_L",
	"upperarm_l": "J_Shoulder_L",
	"lowerarm_l": "J_Elbow_L",
	"hand_l": "J_Wrist_L",
	"index_01_l": "J_IndexF0_L",
	"index_02_l": "J_IndexF1_L",
	"index_03_l": "J_IndexF2_L",
	"middle_01_l": "J_MiddleF0_L",
	"middle_02_l": "J_MiddleF1_L",
	"middle_03_l": "J_MiddleF2_L",
	"pinky_01_l": "J_PinkyF0_L",
	"pinky_02_l": "J_PinkyF1_L",
	"pinky_03_l": "J_PinkyF2_L",
	"ring_01_l": "J_RingF0_L",
	"ring_02_l": "J_RingF1_L",
	"ring_03_l": "J_RingF2_L",
	"thumb_01_l": "J_ThumbF1_L",
	"thumb_02_l": "J_ThumbF2_L",
	"thumb_03_l": "J_ThumbF3_L",
	"clavicle_r": "J_Clavicle_R",
	"upperarm_r": "J_Shoulder_R",
	"lowerarm_r": "J_Elbow_R",
	"hand_r": "J_Wrist_R",
	"index_01_r": "J_IndexF0_R",
	"index_02_r": "J_IndexF1_R",
	"index_03_r": "J_IndexF2_R",
	"index_04_leaf_r": "J_IndexF3_R",
	"middle_01_r": "J_MiddleF0_R",
	"middle_02_r": "J_MiddleF1_R",
	"middle_03_r": "J_MiddleF2_R",
	"middle_04_leaf_r": "J_MiddleF3_R",
	"pinky_01_r": "J_PinkyF0_R",
	"pinky_02_r": "J_PinkyF1_R",
	"pinky_03_r": "J_PinkyF2_R",
	"pinky_04_leaf_r": "J_PinkyF3_R",
	"ring_01_r": "J_RingF0_R",
	"ring_02_r": "J_RingF1_R",
	"ring_03_r": "J_RingF2_R",
	"ring_04_leaf_r": "J_RingF3_R",
	"thumb_01_r": "J_ThumbF1_R",
	"thumb_02_r": "J_ThumbF2_R",
	"thumb_03_r": "J_ThumbF3_R",
	"thigh_l": "J_Leg_L",
	"calf_l": "J_Knee_L",
	"foot_l": "J_Foot_L",
	"ball_l": "J_Toe_L",
	"thigh_r": "J_Leg_R",
	"calf_r": "J_Knee_R",
	"foot_r": "J_Foot_R",
	"ball_r": "J_Toe_R",
}

func _ready() -> void:
	var body: Skeleton3D = _find_body_skeleton()
	if not body:
		push_error("Roman model has no body Skeleton3D")
		return
	_copy_base_animation_library()

func get_game_skeleton() -> Skeleton3D:
	return _find_body_skeleton()

func game_bone_name(game_bone: String) -> String:
	return BONE_MAP.get(game_bone, game_bone)

func uses_universal_attire() -> bool:
	return false

func _find_body_skeleton() -> Skeleton3D:
	for candidate in find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.get_bone_count() < 200 \
				and skeleton.find_bone("J_Hips") >= 0:
			return skeleton
	return null

func _animation_skeletons() -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	for candidate in find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.find_bone("J_Hips") >= 0:
			out.append(skeleton)
	return out

func _copy_base_animation_library() -> void:
	var packed: PackedScene = load(BASE_RIG)
	var source_root: Node = packed.instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var target_player := $AnimationPlayer as AnimationPlayer
	if not source_player or not target_player:
		push_error("Roman model could not load the base animation library")
		source_root.free()
		return
	target_player.add_animation_library("", adapt_animation_library(
			source_player.get_animation_library("")))
	source_root.free()

func adapt_animation_library(source: AnimationLibrary) -> AnimationLibrary:
	var target := AnimationLibrary.new()
	var skeletons := _animation_skeletons()
	for name in source.get_animation_list():
		var source_animation: Animation = source.get_animation(name)
		var animation := Animation.new()
		animation.length = source_animation.length
		animation.loop_mode = source_animation.loop_mode
		animation.step = source_animation.step
		for track in source_animation.get_track_count():
			var path := source_animation.track_get_path(track)
			var bone := String(path.get_concatenated_subnames())
			if not BONE_MAP.has(bone):
				continue
			for skeleton in skeletons:
				var output_track := animation.add_track(
						source_animation.track_get_type(track))
				animation.track_set_path(output_track, NodePath("%s:%s" % [
						get_path_to(skeleton), BONE_MAP[bone]]))
				animation.track_set_interpolation_type(output_track,
						source_animation.track_get_interpolation_type(track))
				for key in source_animation.track_get_key_count(track):
					animation.track_insert_key(output_track,
							source_animation.track_get_key_time(track, key),
							source_animation.track_get_key_value(track, key),
							source_animation.track_get_key_transition(track, key))
		target.add_animation(name, animation)
	return target