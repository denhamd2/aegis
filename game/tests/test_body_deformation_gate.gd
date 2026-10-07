extends GdUnitTestSuite
## Pins the two body-deformation findings that are fixed at the clip level.
##
## 1. The shoulder girdle follows the arm. Before, the clavicle was never driven
##    outside the strikes, so an arm swung overhead folded the deltoid into the
##    neck. Win_Celebrate (both arms overhead) must lift both clavicles.
## 2. Limb flips. A solved limb that swings more than 100 degrees between two
##    consecutive keys is an IK branch flip (the rope step-through calf turns
##    179 degrees in 33 ms). 40 remain: kicks that snap straight (Drive-By,
##    Springboard DK contact), the Tope launch and the arms in the rope duck,
##    where the hand is within a hand of the shoulder. This is a ratchet:
##    fixing a clip lowers the number and the constant should follow it down;
##    making one worse fails.

## 3. The hip helpers' share of the thigh. HipHelpers bakes a bone that turns
##    SWING of the thigh's turn out of rest, and a SHARE of a turn has two
##    readings 180 degrees apart once the turn passes the antipode -- which is
##    exactly where a man flat on his back with his legs over him sits. Read a
##    frame at a time it took whichever was shorter for that frame alone, so
##    the helper whipped 179.2 degrees in 33 ms while the thigh it follows
##    moved 4.1 (Rope_Rebound; 41 of them). It carries HipHelpers.SHARE of the
##    skin from the hip down the thigh, so on screen that was Cody's leg
##    folding through itself, in both get-ups and every clip where he takes a
##    move. Same ratchet.
const CLIPS_GLB := "res://assets/animations/wrestling_clips.glb"
const FLIP_DEGREES := 100.0
const KNOWN_FLIPS := 40
const CLAVICLE_LIFT_DEGREES := 10.0
## A helper taking a SHARE of the thigh's turn cannot out-turn the thigh, give
## or take this much rounding.
const HELPER_SLACK_DEGREES := 5.0
## ...and nothing that follows a limb at half speed moves this far in a frame.
const HELPER_JUMP_DEGREES := 60.0
## 41 before the reading was carried across frames. All three that are left
## are in Springboard_DK_Attacker, whose thigh genuinely swings 96 degrees in
## one frame -- the clip that also carries six of the arm flips above, and
## which wants re-authoring rather than a better bake.
const KNOWN_HELPER_JUMPS := 3

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


## The helper never out-turns the thigh whose share it is taking -- which is
## the one thing a half-swing owes, and what the antipode broke.
func test_the_hip_helpers_never_out_turn_the_thigh() -> void:
    var root: Node = auto_free((load(CLIPS_GLB) as PackedScene).instantiate())
    add_child(root)
    var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
    var skeleton := root.find_child("Skeleton3D", true, false) as Skeleton3D
    assert_object(skeleton).override_failure_message(
        "no Skeleton3D in %s" % CLIPS_GLB).is_not_null()
    var jumps := 0
    var worst := "none"
    var worst_deg := 0.0
    for clip_name in player.get_animation_list():
        var clip := player.get_animation(clip_name)
        for side: String in HipHelpers.SIDES:
            var bone := "thigh_%s" % side
            var at := skeleton.find_bone(bone)
            if at < 0:
                continue
            var track := -1
            for t in clip.get_track_count():
                if clip.track_get_type(t) == Animation.TYPE_ROTATION_3D \
                        and String(clip.track_get_path(t).get_concatenated_subnames()) == bone:
                    track = t
            if track < 0:
                continue
            var rest := skeleton.get_bone_rest(at).basis.get_rotation_quaternion()
            # Exactly what HipHelpers.add_tracks() bakes, key for key.
            var swing := Quaternion.IDENTITY
            var last_helper := Quaternion.IDENTITY
            var last_thigh := Quaternion.IDENTITY
            for k in clip.track_get_key_count(track):
                var posed: Quaternion = clip.track_get_key_value(track, k)
                swing = HipHelpers.scaled_turn(posed * rest.inverse(), HipHelpers.SWING, swing)
                var helper := swing * rest
                if k > 0:
                    var moved := rad_to_deg(last_helper.angle_to(helper))
                    var thigh := rad_to_deg(last_thigh.angle_to(posed))
                    if moved > thigh + HELPER_SLACK_DEGREES or moved > HELPER_JUMP_DEGREES:
                        jumps += 1
                        if moved > worst_deg:
                            worst_deg = moved
                            worst = "%s %s key %d (thigh %.1f, helper %.1f)" % [
                                clip_name, bone, k, thigh, moved]
                last_helper = helper
                last_thigh = posed
    assert_int(jumps).override_failure_message(
        "%d hip-helper jumps past the thigh they follow, worst %s" % [jumps, worst]
    ).is_less_equal(KNOWN_HELPER_JUMPS)


## Roman's entrance walk (roman_entrance_aaa_plan.md step 2) is smooth: no
## joint's per-frame turn changes by more than WALK_JERK_DEG from one frame to
## the next. The old gait jumped 5.9 deg (the thigh at toe-off) and the head
## snapped home 28 degrees in 6 frames at the loop seam (3.1 deg).
## 4.5: the knee's load response at heel strike is a real, quick flex (~4).
const WALK_JERK_DEG := 4.5

func test_romans_walk_has_no_jerks() -> void:
    _assert_smooth_walk("Walk_Slow_Look", WALK_JERK_DEG)


## Cody's walk and its gesture variants (cody_entrance_aaa_plan.md step 2).
## His cycle is 26 frames to Roman's 48: the same smooth curve played 1.85x
## as fast changes its per-frame turn 3.4x as much, so his bar is set on his
## own tempo. The old gait jerked his knees 17-18 and a gesture's upper arm
## 24-33 (a clavicle that jumped by the chest's turn as the arm came down);
## now 6 and 7.5.
const CODY_WALK_JERK_DEG := 8.0

func test_codys_walk_has_no_jerks() -> void:
    for clip_name in ["Walk_Crowd", "Walk_Crowd_Shout_L", "Walk_Crowd_Shout_R",
            "Walk_Crowd_Point"]:
        _assert_smooth_walk(clip_name, CODY_WALK_JERK_DEG)


func _assert_smooth_walk(clip_name: String, limit: float) -> void:
    var player := _library()
    var clip := player.get_animation(clip_name)
    var dt := 1.0 / 30.0
    var worst := {}
    for t in clip.get_track_count():
        if clip.track_get_type(t) != Animation.TYPE_ROTATION_3D:
            continue
        var bone := String(clip.track_get_path(t).get_concatenated_subnames())
        if not (bone in ["thigh_l", "thigh_r", "calf_l", "calf_r", "Head", "neck_01",
                "spine_03", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r",
                "pelvis"]):
            continue
        var last_v := -1.0
        var prev: Quaternion = clip.rotation_track_interpolate(t, 0.0)
        var time := dt
        while time <= clip.length + 0.0001:
            var q: Quaternion = clip.rotation_track_interpolate(t, minf(time, clip.length))
            var v := rad_to_deg(prev.angle_to(q))
            if last_v >= 0.0:
                worst[bone] = maxf(worst.get(bone, 0.0), absf(v - last_v))
            last_v = v
            prev = q
            time += dt
    for bone in worst:
        assert_float(worst[bone]).override_failure_message(
                "%s jerks %.2f deg/frame^2 in %s" % [bone, worst[bone], clip_name]
        ).is_less(limit)
