extends GdUnitTestSuite

const ROMAN_MODEL := preload("res://scenes/roman_model.tscn")
const MATCH_SCENE := preload("res://scenes/match.tscn")
const PAIRED_POSES := preload("res://resources/animations/paired_poses.tres")

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

func test_bone_map_covers_the_spine_chain() -> void:
    assert_str(RomanModel.BONE_MAP.get("spine_01", "")).override_failure_message(
        "BONE_MAP drops spine_01: every base animation driving it is silently "
        + "discarded and the torso animates without a joint."
    ).is_equal("J_Spine1")
    var model := _make_model()
    await await_millis(20)
    var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
    assert_object(player).is_not_null()
    var idle := player.get_animation("Idle")
    # The mapping is the contract; per-clip presence is NOT asserted for
    # spine_01 itself: the importer strips immutable tracks (raw .glb Idle
    # carries 195 channels incl. spine_01, the imported player keeps 56
    # tracks with none), so no adapted clip can carry J_Spine1 today. What
    # IS asserted is that the spine remap path works end to end, via the
    # neighbouring joint the importer kept.
    var spine_tracks := 0
    for track in idle.get_track_count():
        if String(idle.track_get_path(track)).contains(":J_Spine2"):
            spine_tracks += 1
    assert_int(spine_tracks).override_failure_message(
        "Adapted Idle carries no J_Spine2 tracks -- the spine remap path "
        + "itself is broken, and spine_01 would not survive it either."
    ).is_greater(0)

func test_eyes_carry_iris_and_pupil_attachments() -> void:
    var model := _make_model()
    await await_millis(20)
    var skeleton := model.get_game_skeleton() as Skeleton3D
    assert_object(skeleton).is_not_null()
    for bone in ["J_Eye_L", "J_Eye_R"]:
        assert_int(skeleton.find_bone(bone)).override_failure_message(
            "Roman skeleton lost eye bone '%s'" % bone
        ).is_greater_equal(0)
    var targets: Dictionary = RomanModel.EYE_TARGETS
    for bone in targets:
        for slot_i in [0, 1]:
            var want: Vector3 = (targets[bone] as Array)[slot_i]
            var kind := "Iris" if slot_i == 0 else "Pupil"
            var found: BoneAttachment3D = null
            for child in skeleton.get_children():
                if String(child.name) == "Roman" + kind + bone.right(6):
                    found = child as BoneAttachment3D
            assert_object(found).override_failure_message(
                "%s has no %s attachment -- the untextured eyeball renders "
                % [bone, kind] + "with no iris."
            ).is_not_null()
            # The measured offset lives on the attachment's lens child (the
            # standard BoneAttachment3D pattern: attachment at the bone
            # origin, mesh offset beneath it).
            var lens := found.get_child(0) as MeshInstance3D
            assert_object(lens).override_failure_message(
                "%s %s attachment holds no lens mesh." % [bone, kind]
            ).is_not_null()
            assert_vector(lens.position).override_failure_message(
                "%s %s lens sits at %v, not the measured %v -- re-measure "
                % [bone, kind, lens.position, want]
                + "from the .glb bind pose, do not hand-tune."
            ).is_equal_approx(want, Vector3.ONE * 0.001)

func test_normal_maps_import_as_normal_maps() -> void:
    var files := ["bottoms_nrm", "l_wrist_nrm", "r_a_acce_nrm", "r_wrist_nrm",
        "shoes_nrm", "tops_nrm", "wrinkles_normal"]
    for stem in files:
        var path := "res://assets/characters/roman_reigns_%s.png.import" % stem
        assert_bool(FileAccess.file_exists(path)).override_failure_message(
            "Import sidecar missing: %s" % path
        ).is_true()
        var text := FileAccess.get_file_as_string(path)
        assert_bool(text.contains("compress/normal_map=1")).override_failure_message(
            "%s is not flagged as a normal map -- its vectors decode as "
            % path + "sRGB colour and every light on it is wrong."
        ).is_true()

## Every bone a remapped paired-pose track names must exist on the Roman
## skeleton. The poses are baked against CC0 bone names and remapped through
## BONE_MAP at load; a bone the map drops (spine_01 did exactly this)
## leaves that track pointing at nothing -- no error, just a body part that
## quietly stops performing mid-throw on Roman while the mannequin dances.
func test_adapted_poses_reference_real_roman_bones() -> void:
    var model := _make_model()
    await await_millis(20)
    var skeleton := model.get_game_skeleton() as Skeleton3D
    assert_object(skeleton).is_not_null()
    var lib: AnimationLibrary = model.adapt_animation_library(PAIRED_POSES)
    var dangling: Array[String] = []
    for anim_name in lib.get_animation_list():
        var anim: Animation = lib.get_animation(anim_name)
        for track in anim.get_track_count():
            var bone := String(
                anim.track_get_path(track).get_concatenated_subnames())
            if skeleton.find_bone(bone) < 0:
                dangling.append("%s: %s" % [anim_name, bone])
    assert_array(dangling).override_failure_message(
        "Remapped pose tracks pointing at bones Roman does not have: %s"
        % [dangling]
    ).is_empty()

## --- The position retarget --------------------------------------------------

## Roman floated. Every clip with real root motion put him two metres above
## the mat -- lying flat in mid-air through his own knockdowns, and through
## the three-count that pinned him -- while the upright clips looked fine.
##
## The cause was in _retarget_key's position branch: it rotated the key's
## offset by the two bones' OWN rest bases, which is the local-space mistake
## the rotation branch above it documents at length. Between these two rigs
## that product is a 180-degree flip (the base rig's pelvis rests at euler
## (104.5, 0, 0), Roman's J_Hips at (-90, 0, 0)), so it inverted the vertical
## component of every root translation.
##
## Asserted on the maths rather than on a posed model: instantiating
## roman_reigns.glb costs 52MB per test, which is the whole reason play.tscn
## exists. The rest transforms below are the two rigs' real ones, read off
## the skeletons with tools/probe/retarget_diag.tscn.
const _SOURCE_HIP_REST := Vector3(0.0, 0.0501, 0.9167)
const _TARGET_HIP_REST := Vector3(0.0, 0.0, 0.97754)

func _hip_rest_pair() -> Dictionary:
    return {
        "source": Transform3D(Basis.from_euler(Vector3(deg_to_rad(104.4586),
                0.0, 0.0)), _SOURCE_HIP_REST),
        "target": Transform3D(Basis.from_euler(Vector3(deg_to_rad(-90.0),
                0.0, 0.0)), _TARGET_HIP_REST),
        # Both rigs' hip parents rest unrotated; the flip came entirely from
        # the bones' own bases, which is the point.
        "source_parent": Quaternion.IDENTITY,
        "target_parent": Quaternion.IDENTITY,
    }

## Death01's pelvis key at 1.2s, the frame the floating was measured on. The
## rig is Z-up in rest space, so the height lives in z.
func test_a_down_pose_retargets_onto_the_mat_not_into_the_air() -> void:
    var model: RomanModel = auto_free(RomanModel.new())
    var key := Vector3(0.007216, 0.548235, 0.07876)
    var out: Vector3 = model._retarget_key(Animation.TYPE_POSITION_3D, key,
            _hip_rest_pair())
    # The un-retargeted rig puts this key's hips at 0.079 above the mat; the
    # broken branch put them at 1.974, which rendered as a man lying flat two
    # metres up. Anything near the source value is on the mat.
    assert_float(out.z).override_failure_message(
            "Death01's hips retargeted to %.3f; the base rig puts them at 0.079"
            % out.z).is_between(0.0, 0.30)

## The failing signature, stated as its own case so a regression names itself
## rather than reading as "some number moved".
func test_the_root_translation_is_not_vertically_inverted() -> void:
    var model: RomanModel = auto_free(RomanModel.new())
    var rest := _hip_rest_pair()
    var source_rest: Transform3D = rest["source"]
    # A key half a metre BELOW the source's rest hip height must stay below
    # the target's. Flipping the offset is what sent a falling man upward.
    var key := source_rest.origin - Vector3(0.0, 0.0, 0.5)
    var out: Vector3 = model._retarget_key(Animation.TYPE_POSITION_3D, key,
            rest)
    assert_bool(out.z < _TARGET_HIP_REST.z).override_failure_message(
            "a key below the source rest retargeted to %.3f, above the target's rest %.3f -- the offset is inverted"
            % [out.z, _TARGET_HIP_REST.z]).is_true()

## An upright clip barely moves the root, which is why the fault hid: Idle and
## the strikes looked correct throughout.
func test_a_key_at_the_source_rest_lands_on_the_target_rest() -> void:
    var model: RomanModel = auto_free(RomanModel.new())
    var rest := _hip_rest_pair()
    var out: Vector3 = model._retarget_key(Animation.TYPE_POSITION_3D,
            (rest["source"] as Transform3D).origin, rest)
    assert_vector(out).is_equal_approx(_TARGET_HIP_REST, Vector3.ONE * 0.001)
