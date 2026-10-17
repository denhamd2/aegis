extends SceneTree

const CLIP_SCENE := "res://assets/characters/mixamo/y_bot_football_kick.glb"
const CLIP_NAME := "AN_Beechlawn_PassRight"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CLIP_SCENE) as PackedScene
	if packed == null:
		_fail("Could not load the exported Y-Bot pass clip")
		return
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	var player := instance.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var skeleton := instance.find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null:
		_fail("GLB import did not create an AnimationPlayer")
		return
	if skeleton == null or skeleton.get_bone_count() != 65:
		_fail("Kick clip skeleton differs from Y-Bot")
		return
	if not player.has_animation(CLIP_NAME):
		_fail("Missing exported clip: %s; got %s" % [CLIP_NAME, player.get_animation_list()])
		return
	var animation := player.get_animation(CLIP_NAME)
	if animation.get_track_count() < 40:
		_fail("Expected baked body/limb tracks, got %d" % animation.get_track_count())
		return
	if absf(animation.length - 53.0 / 60.0) >= 0.02:
		_fail("Unexpected 60 fps clip duration: %f" % animation.length)
		return
	var bone_track_count := 0
	for track_index in animation.get_track_count():
		if str(animation.track_get_path(track_index)).contains("Skeleton3D"):
			bone_track_count += 1
	if bone_track_count < 40:
		_fail("Expected baked Skeleton3D tracks, got %d" % bone_track_count)
		return
	var kicking_leg := skeleton.find_bone("mixamorig_RightUpLeg")
	if kicking_leg < 0:
		_fail("Could not find the Mixamo right-thigh bone")
		return
	var rest_rotation := skeleton.get_bone_pose_rotation(kicking_leg)
	player.play(CLIP_NAME)
	player.seek(24.0 / 60.0, true)
	skeleton.force_update_all_bone_transforms()
	var contact_rotation := skeleton.get_bone_pose_rotation(kicking_leg)
	if rest_rotation.angle_to(contact_rotation) < 0.10:
		_fail("The imported clip did not pose the kicking leg at its contact sample")
		return
	print("Beechlawn kick GLB: Y-Bot 65-bone skeleton, %d baked bone tracks, duration %.3fs" % [bone_track_count, animation.length])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
