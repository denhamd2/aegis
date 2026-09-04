extends GdUnitTestSuite
## The bone-level halves of the paired grapple moves -- the recipes in
## resources/animations/paired_recipes.gd and the clips
## tools/anim/build_paired_poses.gd bakes out of them.
##
## paired_moves.tres animates only the two CharacterBody3D roots, so before
## these existed a throw was two rigid capsules on an arc with an unrelated
## borrowed gesture playing inside each of them. These clips are the bodies.
##
## Whether a pose *looks* right is not assertable and was checked by
## rendering each move at six beats. What is assertable, and what actually
## broke during development, is the wiring: a recipe naming a clip the rig
## doesn't have, a sample time past the end of its source, a generated clip
## whose length no longer matches the trajectory it has to stay in step
## with, and track paths that don't resolve against a real wrestler.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
const PairedRecipes := preload("res://resources/animations/paired_recipes.gd")
const PAIRED_POSES := preload("res://resources/animations/paired_poses.tres")
const PAIRED_MOVES := preload("res://resources/animations/paired_moves.tres")

func _make_wrestler() -> WrestlerController:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	return wrestler

func test_every_recipe_samples_a_clip_the_rig_actually_has() -> void:
	var player := _make_wrestler().anim_player
	var missing: Array[String] = []
	for move_id in PairedRecipes.RECIPES:
		for role in ["attacker", "defender"]:
			for sample: Dictionary in PairedRecipes.RECIPES[move_id][role]:
				if not player.has_animation(sample["clip"]):
					missing.append("%s/%s -> %s" % [move_id, role, sample["clip"]])
	assert_array(missing).override_failure_message(
		"Recipes sample clips the rig doesn't have: %s" % [missing]
	).is_empty()

## A sample time past the end of its source clip silently clamps to the last
## frame, so several beats collapse onto one pose and the move stops moving.
func test_every_sample_time_is_inside_its_source_clip() -> void:
	var player := _make_wrestler().anim_player
	var bad: Array[String] = []
	for move_id in PairedRecipes.RECIPES:
		for role in ["attacker", "defender"]:
			for sample: Dictionary in PairedRecipes.RECIPES[move_id][role]:
				var length: float = player.get_animation(sample["clip"]).length
				if sample["at"] < 0.0 or sample["at"] > length:
					bad.append("%s/%s: %s at %.3f (0..%.3f)"
						% [move_id, role, sample["clip"], sample["at"], length])
	assert_array(bad).override_failure_message(
		"Samples outside their source clip: %s" % [bad]
	).is_empty()

func test_every_recipe_has_a_matching_trajectory() -> void:
	var missing: Array[String] = []
	for move_id in PairedRecipes.RECIPES:
		if not PAIRED_MOVES.has_animation(move_id):
			missing.append(move_id)
	assert_array(missing).override_failure_message(
		"Recipes with no root-transform animation in paired_moves.tres: %s" % [missing]
	).is_empty()

## The two halves are started on the same physics tick and kept in step by
## nothing else, so a length mismatch is a drift that grows for the whole
## move and leaves the attacker still lifting after the victim has landed.
func test_role_clips_are_exactly_as_long_as_the_trajectory() -> void:
	for move_id in PairedRecipes.RECIPES:
		var expected: float = PAIRED_MOVES.get_animation(move_id).length
		for is_attacker in [true, false]:
			var clip := PairedRecipes.role_clip(move_id, is_attacker)
			var bare := clip.substr(clip.find("/") + 1)
			assert_float(PAIRED_POSES.get_animation(bare).length) \
				.override_failure_message("%s is not %.3fs" % [clip, expected]) \
				.is_equal_approx(expected, 0.001)

func test_generated_library_has_both_roles_for_every_recipe() -> void:
	var missing: Array[String] = []
	for move_id in PairedRecipes.RECIPES:
		for suffix in [PairedRecipes.ATTACKER_SUFFIX, PairedRecipes.DEFENDER_SUFFIX]:
			if not PAIRED_POSES.has_animation(move_id + suffix):
				missing.append(move_id + suffix)
	assert_array(missing).override_failure_message(
		"paired_poses.tres is missing: %s -- re-run tools/anim/build_paired_poses.gd"
		% [missing]
	).is_empty()

## A generated clip must pose the *whole* body. Keying a handful of bones and
## leaving the rest to fall back to rest pose is what a hand-authored sparse
## clip would have produced, and it reads as a mannequin with a moving arm.
func test_generated_clips_pose_every_bone_the_rig_animates() -> void:
	var player := _make_wrestler().anim_player
	var expected := player.get_animation("PickUp_Table").get_track_count()
	for name in PAIRED_POSES.get_animation_list():
		assert_int(PAIRED_POSES.get_animation(name).get_track_count()) \
			.override_failure_message("%s poses fewer bones than the rig animates" % name) \
			.is_equal(expected)

## Track paths are copied off a source clip by the generator rather than
## hardcoded, so this is the guard that a re-import moving the Skeleton3D
## breaks a test instead of producing tracks that resolve to nothing.
func test_generated_track_paths_resolve_against_a_real_wrestler() -> void:
	var wrestler := _make_wrestler()
	var root := wrestler.anim_player.get_node(wrestler.anim_player.root_node)
	var anim := PAIRED_POSES.get_animation("grapple_hiptoss__attacker")
	var unresolved: Array[String] = []
	for i in anim.get_track_count():
		var path := anim.track_get_path(i)
		var node := root.get_node_or_null(NodePath(path.get_concatenated_names()))
		if not node:
			unresolved.append(String(path))
		elif node is Skeleton3D and (node as Skeleton3D).find_bone(
				path.get_concatenated_subnames()) < 0:
			unresolved.append(String(path))
	assert_array(unresolved).override_failure_message(
		"Tracks that resolve to no bone on a real wrestler: %s" % [unresolved]
	).is_empty()

func test_roles_resolve_to_different_clips() -> void:
	assert_str(PairedRecipes.role_clip(&"grapple_hiptoss", true)) \
		.is_not_equal(PairedRecipes.role_clip(&"grapple_hiptoss", false))

func test_a_move_with_no_recipe_resolves_to_nothing() -> void:
	assert_str(PairedRecipes.role_clip(&"strike_jab", true)).is_empty()
	assert_float(PairedRecipes.defender_grip_until(&"strike_jab")).is_equal_approx(0.0, 0.0001)

## The defender lets go partway through a throw and holds on for the whole of
## a move nobody is lifted in. Both ends of that range have to stay inside
## the clip or the countdown is meaningless.
func test_defender_grip_windows_are_inside_the_move() -> void:
	for move_id in PairedRecipes.RECIPES:
		var fraction: float = PairedRecipes.defender_grip_until(move_id)
		assert_float(fraction).override_failure_message(
			"%s grips for %.2f of the move" % [move_id, fraction]
		).is_between(0.0, 1.0)

## A wrestler must be able to play the clip by name through his own
## AnimationPlayer -- the library has to be registered, under the name the
## recipes hand out.
func test_a_wrestler_can_play_its_half_of_an_authored_move() -> void:
	var wrestler := _make_wrestler()
	var move := MoveDef.new()
	move.animation_pair_id = &"grapple_hiptoss"
	assert_bool(wrestler.play_paired_pose(move, true)).is_true()
	assert_bool(wrestler.play_paired_pose(move, false)).is_true()

## A move with no authored performance must leave the wrestler on the
## borrowed single-character clip rather than erroring or blanking the pose.
func test_a_move_with_no_recipe_falls_back_instead_of_failing() -> void:
	var wrestler := _make_wrestler()
	var move := MoveDef.new()
	move.animation_pair_id = &"not_a_real_move"
	assert_bool(wrestler.play_paired_pose(move, true)).is_false()
	assert_bool(wrestler.play_paired_pose(null, true)).is_false()

## Regression guard for bodies buried in the mat.
##
## The model's origin is at its feet, so a body left pitched far off vertical
## at the end of a throw hangs its length *below* the root -- measured, a
## suplex victim's pelvis ended at y = -0.55, half a metre under the mat, and
## stayed there until GrappleRig._level_bodies() corrected it a tick after
## the clip finished. Lying a thrown wrestler down is the pose clip's job
## now; the trajectory has to hand him back upright.
##
## Checked strictly for a body the trajectory actually throws (one that
## leaves the mat), and loosely for everyone else: a wrestler shoved back on
## his heels is allowed to end leaning, which puts no part of him under the
## mat, but nobody may end on their face.
const AIRBORNE_HEIGHT := 0.30
const MAX_END_TILT_DEGREES := 45.0

func test_thrown_bodies_land_upright() -> void:
	var pitched: Array[String] = []
	for name in PAIRED_MOVES.get_animation_list():
		var anim := PAIRED_MOVES.get_animation(name)
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			if not _goes_airborne(anim, anim.track_get_path(i)):
				continue
			var last := anim.track_get_key_count(i) - 1
			var up := Basis(anim.track_get_key_value(i, last) as Quaternion) * Vector3.UP
			if up.dot(Vector3.UP) < 0.999:
				pitched.append("%s %s (up=%v)" % [name, anim.track_get_path(i), up])
	assert_array(pitched).override_failure_message(
		"Thrown bodies that don't land upright: %s" % [pitched]
	).is_empty()

func test_no_move_ends_with_a_body_on_its_face() -> void:
	var tilted: Array[String] = []
	var limit := cos(deg_to_rad(MAX_END_TILT_DEGREES))
	for name in PAIRED_MOVES.get_animation_list():
		var anim := PAIRED_MOVES.get_animation(name)
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var last := anim.track_get_key_count(i) - 1
			var up := Basis(anim.track_get_key_value(i, last) as Quaternion) * Vector3.UP
			if up.dot(Vector3.UP) < limit:
				tilted.append("%s %s (up=%v)" % [name, anim.track_get_path(i), up])
	assert_array(tilted).override_failure_message(
		"Bodies ending more than %.0f degrees off vertical: %s"
		% [MAX_END_TILT_DEGREES, tilted]
	).is_empty()

## Whether the wrestler this rotation track belongs to is lifted off the mat
## anywhere in the move, read off his own position track.
func _goes_airborne(anim: Animation, path: NodePath) -> bool:
	var pos := anim.find_track(path, Animation.TYPE_POSITION_3D)
	if pos < 0:
		return false
	for k in anim.track_get_key_count(pos):
		if (anim.track_get_key_value(pos, k) as Vector3).y >= AIRBORNE_HEIGHT:
			return true
	return false
