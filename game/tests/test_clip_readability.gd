extends GdUnitTestSuite
## What the authored clips DO, in centimetres, rather than what they are made of.
##
## test_authored_clips.gd already asserts that every clip exists, is the right
## length, loops when it must and poses the whole body. All of that was true of
## a hit reaction that moved the head 6.4 cm and of a stance that stood a
## wrestler reclining away from his own guard -- the two defects behind "they
## are standing in a weird pose" and "the opponent is hit and nothing
## happens". Neither is visible in a track count.
##
## So these sample the baked pose and assert the motion. The thresholds are
## floors under measured values, not targets: they exist to catch a clip going
## quiet again, which is the failure mode this set has had twice (once from a
## table that keyframed only arms and head, once from a lean authored the wrong
## way round).
##
## Sampling is play -> pause -> seek(update=true) and read on the spot, the
## same as tools/probe/pose_compare.tscn. Awaiting a frame after the seek lets
## the player advance by one delta, which on a half-second strike is 3% of the
## clip -- enough to read a different frame than the one asked for.

const AUTHORED_GLB := "res://assets/animations/wrestling_clips.glb"
const BASE_RIG := "res://assets/characters/wrestler_base.glb"

## Measured on the clips as committed, with the floors set below them:
##
##   Hit_React_Head   head 36.0 cm   Hit_React_Torso  head 22.6 cm
##   Strike_Jab       fist 31.7 cm   Strike_Forearm   fist 43.1 cm
##
## 15 cm is roughly the width of a man's head on this 1.65 m rig: a reaction
## that moves it less than that is not readable at match camera distance, and a
## punch that travels less than that has not left the guard.
const READABLE := 0.15


func _rig() -> Dictionary:
	var model: Node3D = auto_free((load(BASE_RIG) as PackedScene).instantiate())
	add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var clips: Node = (load(AUTHORED_GLB) as PackedScene).instantiate()
	var clip_player: AnimationPlayer = clips.find_child("AnimationPlayer", true, false)
	var library: AnimationLibrary = clip_player.get_animation_library(
			clip_player.get_animation_library_list()[0]).duplicate(true)
	clips.free()
	player.add_animation_library(&"authored", library)
	return {"player": player, "skeleton": skeleton}


## One bone's position, in skeleton space, at a fraction through a clip.
func _at(rig: Dictionary, clip: String, fraction: float, bone: String) -> Vector3:
	var player: AnimationPlayer = rig["player"]
	var skeleton: Skeleton3D = rig["skeleton"]
	var key := "authored/%s" % clip
	var animation := player.get_animation(key)
	player.play(key)
	player.pause()
	player.seek(animation.length * fraction, true)
	return skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin


## The furthest a bone gets from where the clip started.
func _travel(rig: Dictionary, clip: String, bone: String) -> float:
	var start := _at(rig, clip, 0.0, bone)
	var worst := 0.0
	for step in 21:
		var here := _at(rig, clip, step / 20.0, bone)
		worst = maxf(worst, (here - start).length())
	return worst


func test_a_wrestler_at_rest_leans_over_his_front_foot() -> void:
	# Forward is +Z in the rig's own space (the model's PI-Y mount in
	# WrestlerController._install_character_model() is what turns it into
	# Godot's -Z). The stance carried spine lean +12 for the life of the
	# project, which tips the torso BACKWARD -- rig_pose._euler()'s docstring
	# said otherwise and was wrong -- and put the head 4.5 cm behind the hips.
	var rig := _rig()
	var head := _at(rig, "Idle_Ready", 0.0, "Head")
	var pelvis := _at(rig, "Idle_Ready", 0.0, "pelvis")
	assert_float(head.z - pelvis.z) \
		.override_failure_message(
			"the stance reclines: the head is %.3f m behind the hips"
			% (pelvis.z - head.z)) \
		.is_greater(0.04)


func test_the_guard_is_wider_than_it_is_clasped() -> void:
	# At 0.30 m apart the hands sat inside the 0.384 m shoulder width with the
	# elbows pinned to the ribs, and rendered as a man holding something in
	# front of his chest rather than as a guard.
	var rig := _rig()
	var right := _at(rig, "Idle_Ready", 0.0, "hand_r")
	var left := _at(rig, "Idle_Ready", 0.0, "hand_l")
	assert_float(absf(left.x - right.x)) \
		.override_failure_message("the hands are %.3f m apart -- that is a clasp"
				% absf(left.x - right.x)) \
		.is_greater(0.38)


func test_taking_a_shot_moves_the_man_who_takes_it() -> void:
	var rig := _rig()
	for clip: String in ["Hit_React_Head", "Hit_React_Torso"]:
		assert_float(_travel(rig, clip, "Head")) \
			.override_failure_message(
				"%s barely moves the head: nothing reads as a hit landing" % clip) \
			.is_greater(READABLE)


func test_a_head_shot_and_a_body_shot_are_different_things() -> void:
	# Asserted as DIRECTION, not as size. Both clips move the head a long way,
	# and which of them moves it further is an accident of the geometry -- a
	# torso rocking back off a forward-leaning stance sweeps a wider arc than
	# one folding down, so the head shot measures 36.0 cm against the body
	# shot's 22.6 cm even though the body shot is the bigger event. What
	# actually separates them is where the head goes: a head shot whips it
	# BACKWARD off his heels, a body shot folds him DOWN around it. A set where
	# both do the same thing is a set with one reaction in it.
	var rig := _rig()
	var head_start := _at(rig, "Hit_React_Head", 0.0, "Head")
	var head_deep := _at(rig, "Hit_React_Head", 0.33, "Head")
	var body_start := _at(rig, "Hit_React_Torso", 0.0, "Head")
	var body_deep := _at(rig, "Hit_React_Torso", 0.33, "Head")
	assert_float(head_deep.z - head_start.z) \
		.override_failure_message("a head shot is not driving the head backward") \
		.is_less(-0.15)
	assert_float(body_deep.y - body_start.y) \
		.override_failure_message("a body shot is not folding him down") \
		.is_less(-0.08)
	assert_float(body_deep.z - body_start.z) \
		.override_failure_message("a body shot is whipping him back, not folding") \
		.is_greater(0.0)


func test_a_punch_leaves_the_guard() -> void:
	# The striking hand, measured rather than declared: the jab is thrown with
	# the LEFT and the cross with the RIGHT, which is what makes them read as
	# two punches instead of the same arm twice.
	var rig := _rig()
	for pair: Array in [["Strike_Jab", "hand_l"], ["Strike_Forearm", "hand_r"]]:
		assert_float(_travel(rig, pair[0], pair[1])) \
			.override_failure_message("%s never extends %s" % [pair[0], pair[1]]) \
			.is_greater(READABLE)


func test_the_hand_that_is_not_throwing_stays_home() -> void:
	# The other hand holding its guard is half of why a punch reads as a
	# punch. It is allowed to move -- the shoulders rotate under it -- but not
	# as far as the one being thrown.
	var rig := _rig()
	for pair: Array in [["Strike_Jab", "hand_r", "hand_l"],
			["Strike_Forearm", "hand_l", "hand_r"]]:
		assert_float(_travel(rig, pair[0], pair[1])) \
			.override_failure_message("%s throws both hands" % pair[0]) \
			.is_less(_travel(rig, pair[0], pair[2]))
