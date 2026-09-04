extends GdUnitTestSuite

const ROMAN_MODEL := preload("res://scenes/roman_model.tscn")
const MATCH_SCENE := preload("res://scenes/match.tscn")

func _make_model() -> Node3D:
    var model: Node3D = auto_free(ROMAN_MODEL.instantiate())
    add_child(model)
    return model

func test_body_skeleton_keeps_named_skin_bones() -> void:
    var model := _make_model()
    await await_millis(20)
    var skeleton := model.get_game_skeleton() as Skeleton3D
    assert_object(skeleton).is_not_null()
    for bone in ["J_Hips", "J_Spine2", "J_Chest", "J_Head",
            "J_Shoulder_L", "J_Elbow_L", "J_Wrist_L",
            "J_Leg_L", "J_Knee_L", "J_Foot_L"]:
        assert_int(skeleton.find_bone(bone)).override_failure_message(
            "Roman body lost skin bone '%s'" % bone
        ).is_greater_equal(0)

func test_base_animations_are_remapped_to_roman_bones() -> void:
    var model := _make_model()
    await await_millis(20)
    var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
    assert_object(player).is_not_null()
    for clip in ["Idle", "Walk", "Sprint", "Push", "Interact", "Hit_Head"]:
        assert_bool(player.has_animation(clip)).override_failure_message(
            "Roman model is missing base animation '%s'" % clip
        ).is_true()
    var idle := player.get_animation("Idle")
    var bad_tracks: Array[String] = []
    for track in idle.get_track_count():
        var path := String(idle.track_get_path(track))
        if path.contains(":pelvis") or path.contains(":spine_03"):
            bad_tracks.append(path)
        if path.contains(":J_") == false and track > 0:
            bad_tracks.append(path)
    assert_array(bad_tracks).is_empty()

func test_match_wires_roman_to_generated_move_libraries() -> void:
    var match: Node = auto_free(MATCH_SCENE.instantiate())
    add_child(match)
    await await_millis(40)
    var wrestler := match.get_node("WrestlerA") as WrestlerController
    assert_object(wrestler.anim_player).is_not_null()
    for clip in ["strikes/strike_jab", "strikes/strike_kick",
            "strikes/running_double_leg", "paired/grapple_hiptoss__attacker"]:
        assert_bool(wrestler.anim_player.has_animation(clip)) \
            .override_failure_message(
                "Roman match model is missing generated animation '%s'" % clip
            ).is_true()
