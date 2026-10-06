extends GdUnitTestSuite
## Pins the two body-deformation findings that are fixed at the clip level.
##
## 1. The shoulder girdle follows the arm. Before, the clavicle was never driven
##    outside the strikes, so an arm swung overhead folded the deltoid into the
##    neck. Win_Celebrate (both arms overhead) must lift both clavicles.
## 2. Limb flips. A solved limb that swings more than 100 degrees between two
##    consecutive keys is an IK branch flip (the rope step-through calf turns
##    179 degrees in 33 ms). 73 remain (the leg snaps in Rope_Step_Through and its apron version were fixed by lowering the lead foot and picking knee poles that are not parallel to the leg; arms in the duck and the Springboard DK are what is left), nearly all in Rope_Step_Through,
##    Roll_Out_Ropes and Springboard_DK, where the authored foot passes within
##    a hand of the hip. This is a ratchet: fixing a clip lowers the number
##    and the constant should follow it down; making one worse fails.

const CLIPS_GLB := "res://assets/animations/wrestling_clips.glb"
const FLIP_DEGREES := 100.0
const KNOWN_FLIPS := 73
const CLAVICLE_LIFT_DEGREES := 10.0

func _library() -> AnimationPlayer:
    var root: Node = auto_free((load(CLIPS_GLB) as PackedScene).instantiate())
    add_child(root)
    return root.find_child("AnimationPlayer", true, false) as AnimationPlayer

func test_raised_arms_lift_the_clavicles() -> void:
    var player := _library()
    var clip := player.get_animation("Win_Celebrate")
    for bone in ["clavicle_l", "clavicle_r"]:
        var track := -1
        for t in clip.get_track_count():
            if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D \
                    and String(clip.track_get_path(t).get_concatenated_subnames()) == bone:
                track = t
        assert_int(track).override_failure_message("%s is not keyed" % bone).is_greater_equal(0)
        var rest: Quaternion = clip.track_get_key_value(track, 0)
        var most := 0.0
        for k in clip.track_get_key_count(track):
            var q: Quaternion = clip.track_get_key_value(track, k)
            most = maxf(most, rad_to_deg(rest.angle_to(q)))
        assert_float(most).override_failure_message(
            "%s only moves %.1f deg in Win_Celebrate" % [bone, most]
        ).is_greater(CLAVICLE_LIFT_DEGREES)

func test_limb_flips_do_not_grow() -> void:
    var player := _library()
    var flips := 0
    for clip_name in player.get_animation_list():
        var clip := player.get_animation(clip_name)
        for t in clip.get_track_count():
            if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
                continue
            var bone := String(clip.track_get_path(t).get_concatenated_subnames())
            if not (bone.begins_with("thigh") or bone.begins_with("calf")
                    or bone.begins_with("upperarm") or bone.begins_with("lowerarm")):
                continue
            for k in range(1, clip.track_get_key_count(t)):
                var a: Quaternion = clip.track_get_key_value(t, k - 1)
                var b: Quaternion = clip.track_get_key_value(t, k)
                if rad_to_deg(a.angle_to(b)) > FLIP_DEGREES:
                    flips += 1
    assert_int(flips).override_failure_message(
        "%d single-key limb flips over %d degrees (was %d)" % [flips, FLIP_DEGREES, KNOWN_FLIPS]
    ).is_less_equal(KNOWN_FLIPS)
