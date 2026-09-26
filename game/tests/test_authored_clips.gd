extends GdUnitTestSuite
## The Blender-authored clips, and the VICTORY state that exists to play one.
##
## These guard the seam between tools/blender/wrestling_clips.py and the game:
## the clips are authored outside Godot, baked through strike_recipes.gd, and
## reached by FSM state. A break anywhere along that chain is silent -- the
## wrestler just plays the wrong thing -- so it is asserted rather than looked
## at.

const STRIKE_CLIPS := preload("res://resources/animations/strike_clips.tres")
const AUTHORED_GLB := "res://assets/animations/wrestling_clips.glb"

## Clip name -> the length it MUST have, and what fixes that length.
##
## A clip shorter than its state freezes on its last pose for the remainder;
## longer, and it is cut off mid-action. Both have shipped in this project
## before, which is why strike_recipes.gd retimes everything.
const AUTHORED_LENGTHS := {
	"strike_jab": 0.514,          # strike_jab.tres: 10+4+17 = 31 frames
	"strike_cross": 0.667,        # strike_cross.tres: 12+4+24 = 40
	"strike_kick": 0.583,         # strike_kick.tres: 14+5+16 = 35
	"strike_kick_heavy": 0.950,   # strike_kick_heavy.tres: 11+5+41 = 57
	"hit_head": 0.333,            # WrestlerController.HIT_REACT_TICKS = 20
	"hit_torso": 0.333,           # same state
	"stunned": 0.750,             # WrestlerController.STUNNED_TICKS = 45
	"running_clothesline": 1.150, # both running_attack_*.tres: 69 frames
	"win_celebrate": 1.300,       # free: VICTORY is terminal
	"idle_ready": 2.500,          # loops; matches the rig's Idle
	# 0.533s, not the rig's 1.333s Walk. The cycle is generated against
	# MOVE_SPEED (_gait() in tools/blender/wrestling_clips.py): a planted foot
	# has to travel backward at exactly the speed the engine carries the body
	# forward, and the planted rate is travel / (contact_frames / frames *
	# seconds). At 1.333s the cycle delivered 0.42 m/s against MOVE_SPEED 3.5
	# and the mat slid 6.6x under every step. tools/anim/gait_audit.gd is the
	# check; this line and the recipe's `seconds` must move together.
	"walk_stalk": 0.533,          # loops; 16 frames at 30fps
	"run_drive": 0.667,           # loops; matches the rig's Sprint
	"tie_up_collar": 1.000,
	"down_supine": 1.333,
	"finisher_drive": 1.333,
	"submission_work": 1.000,
	"grapple_hold_neutral": 1.000,
	"grapple_hold_attacker": 1.000,
	"grapple_hold_defender": 1.000,
	"move_exec_impact": 0.600,
	"irish_whip_throw": 0.800,
	"getup_rise": 2.100,          # WrestlerController.GETUP_RISE_TICKS = 126
	"pin_cover": 0.600,
}

## The clips a wrestler SITS in have to loop. The bake defaults to
## LOOP_NONE and the rig's own Idle/Walk/Sprint carry LOOP_LINEAR, so a
## generated replacement that forgets this plays once and freezes -- in the
## three states that are on screen for most of a match.
const MUST_LOOP := ["idle_ready", "walk_stalk", "run_drive",
	"tie_up_collar", "down_supine", "submission_work",
	"grapple_hold_neutral", "grapple_hold_attacker", "grapple_hold_defender"]

## Empty: every clip is authored now. Kept as a list rather than deleted so
## that adding a borrowed clip back has somewhere honest to go, and so the
## test below keeps asserting the thing rather than the absence of it.
const STILL_BORROWED: Array[String] = []


func test_the_authored_clips_are_in_the_baked_library() -> void:
	for name: String in AUTHORED_LENGTHS:
		assert_bool(STRIKE_CLIPS.has_animation(name)) \
			.override_failure_message(
				"strike_clips.tres has no '%s': re-run build_strike_clips.gd"
				% name) \
			.is_true()


func test_each_authored_clip_is_exactly_as_long_as_what_plays_it() -> void:
	for name: String in AUTHORED_LENGTHS:
		var anim: Animation = STRIKE_CLIPS.get_animation(name)
		assert_float(anim.length).is_equal_approx(AUTHORED_LENGTHS[name], 0.002)


func test_the_authored_clips_actually_animate_bones() -> void:
	# A retime of a missing source silently bakes an empty clip of the right
	# length, which would pass the length test above and animate nothing.
	for name: String in AUTHORED_LENGTHS:
		var anim: Animation = STRIKE_CLIPS.get_animation(name)
		var rotation_tracks := 0
		for t in anim.get_track_count():
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rotation_tracks += 1
		assert_int(rotation_tracks).is_greater(0)


func test_the_authored_source_glb_ships_every_clip_the_recipes_ask_for() -> void:
	var packed: PackedScene = load(AUTHORED_GLB)
	assert_object(packed).is_not_null()
	var node: Node = packed.instantiate()
	var player: AnimationPlayer = node.find_child("AnimationPlayer", true, false)
	assert_object(player).is_not_null()
	var present := PackedStringArray()
	for lib_name in player.get_animation_library_list():
		for a in player.get_animation_library(lib_name).get_animation_list():
			present.append(String(a))
	for recipe_name: String in AUTHORED_LENGTHS:
		var recipe: Dictionary = StrikeRecipes.RECIPES[recipe_name]
		assert_str(recipe.get("file", "")).is_equal(AUTHORED_GLB)
		assert_array(present).contains([recipe["source"]])
	node.free()


func test_every_authored_clip_poses_the_whole_body() -> void:
	# The first authored pass keyframed only arms and head: 14 rotation
	# tracks against the sampled clips' 55, so hips and legs held whatever
	# the AnimationTree was blending from and a strike never stepped into
	# anything. 20 is above the arms-and-head count and below the 55 that
	# includes every finger, which these deliberately leave at rest.
	for name: String in AUTHORED_LENGTHS:
		var anim: Animation = STRIKE_CLIPS.get_animation(name)
		var rotation_tracks := 0
		for t in anim.get_track_count():
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
				rotation_tracks += 1
		assert_int(rotation_tracks) \
			.override_failure_message(
				"%s poses only %d bones: legs and hips are not authored"
				% [name, rotation_tracks]) \
			.is_greater(20)


func test_every_recipe_is_authored() -> void:
	# The migration is finished, and this is what keeps it finished: a new
	# recipe that samples the CC0 rig instead of naming an authored clip
	# fails here rather than quietly reintroducing borrowed motion.
	for name: String in StrikeRecipes.RECIPES:
		if STILL_BORROWED.has(name):
			continue
		assert_bool(StrikeRecipes.RECIPES[name].has("file")) \
			.override_failure_message(
				"%s is sampled off the rig, not authored" % name) \
			.is_true()


func test_nothing_is_borrowed_any_more() -> void:
	assert_array(STILL_BORROWED).is_empty()


func test_the_running_attack_no_longer_throws_a_punch() -> void:
	# Neither running_attack_*.tres sets animation_pair_id, so both fall
	# through to STATE_ANIMATIONS -- which meant both sprinted the width of
	# the ring and threw Punch_Cross.
	assert_str(WrestlerController.clip_for_state(
			WrestlerFSM.State.RUNNING_ATTACK, true)) \
		.is_equal("strikes/running_clothesline")


func test_the_clips_a_wrestler_sits_in_loop() -> void:
	for name: String in MUST_LOOP:
		assert_int(STRIKE_CLIPS.get_animation(name).loop_mode) \
			.override_failure_message(
				"%s does not loop: it will freeze on its last frame" % name) \
			.is_equal(Animation.LOOP_LINEAR)


func test_no_clip_carries_a_duplicate_track() -> void:
	# Authored clips baked TWO pelvis rotation tracks -- the real one plus a
	# single-key bind pose, 104 deg about X. Both remap onto the same
	# runtime path and Godot applies whichever it reaches last, so a
	# wrestler in IDLE rendered lying flat on his back in the middle of the
	# ring. _dedupe_tracks() in build_strike_clips.gd keeps the longer one.
	for name: String in AUTHORED_LENGTHS:
		var anim: Animation = STRIKE_CLIPS.get_animation(name)
		var seen := {}
		for t in anim.get_track_count():
			var key := "%s|%d" % [anim.track_get_path(t), anim.track_get_type(t)]
			assert_bool(seen.has(key)) \
				.override_failure_message(
					"%s has two %s tracks" % [name, anim.track_get_path(t)]) \
				.is_false()
			seen[key] = true


func test_no_state_still_plays_a_raw_rig_clip() -> void:
	# Every entry should name a generated library ("strikes/" or "paired/").
	# A bare name is a clip borrowed straight off wrestler_base.glb, which
	# is what the migration set out to remove.
	for state: int in WrestlerController.STATE_ANIMATIONS:
		var clip: String = WrestlerController.STATE_ANIMATIONS[state]
		assert_bool(clip.contains("/")) \
			.override_failure_message(
				"state %d still plays the rig clip '%s'" % [state, clip]) \
			.is_true()
	for table in [WrestlerController.ATTACKER_STATE_ANIMATIONS,
			WrestlerController.DEFENDER_STATE_ANIMATIONS]:
		for state: int in table:
			assert_bool(String(table[state]).contains("/")) \
				.override_failure_message(
					"role override for state %d still plays '%s'"
					% [state, table[state]]) \
				.is_true()


func test_both_halves_of_every_paired_move_are_authored() -> void:
	# A move with one half authored and one still stitched would drift: the
	# two are timed against each other beat for beat.
	var lib: AnimationLibrary = load(
			"res://resources/animations/paired_poses.tres")
	for move_id: String in PairedRecipes.RECIPES:
		var recipe: Dictionary = PairedRecipes.RECIPES[move_id]
		assert_bool(recipe.has("authored")) \
			.override_failure_message("%s is still pose-stitched" % move_id) \
			.is_true()
		for role: String in ["attacker", "defender"]:
			assert_str(recipe["authored"][role]).is_not_empty()
		for suffix: String in [PairedRecipes.ATTACKER_SUFFIX,
				PairedRecipes.DEFENDER_SUFFIX]:
			assert_bool(lib.has_animation(move_id + suffix)).is_true()


func test_victory_is_terminal() -> void:
	# The match is over. Anything leading out of VICTORY would let a frozen
	# wrestler act again, and the celebration holding its last pose is the
	# intended end state rather than an oversight.
	assert_array(WrestlerFSM.LEGAL_TRANSITIONS[WrestlerFSM.State.VICTORY]) \
		.is_empty()


func test_a_winner_can_celebrate_from_wherever_the_bell_catches_him() -> void:
	# A pinfall winner is in PIN_ATTACKER and a submission winner in
	# SUBMISSION_ATTACKER, but the referee can also declare one from a
	# tie-up resolution, so every state the bell can catch him in has to reach
	# VICTORY.
	#
	# VICTORY itself is terminal, and ENTRANCE is the other exemption: the bell
	# cannot catch a man on the ramp. The entrance runs before the referee's
	# first tick -- MatchSetup awaits it and only then starts the recording, and
	# EntranceDirector freezes the referee for the duration -- so there is no
	# match to win while anybody is in it. Adding VICTORY to its transition list
	# would be a path that says a wrestler can be declared the winner of a match
	# that has not begun.
	const OFF_THE_CLOCK := [WrestlerFSM.State.VICTORY,
			WrestlerFSM.State.ENTRANCE]
	for state: int in WrestlerFSM.State.values():
		if OFF_THE_CLOCK.has(state):
			continue
		assert_array(WrestlerFSM.LEGAL_TRANSITIONS[state]) \
			.override_failure_message(
				"%s cannot reach VICTORY"
				% WrestlerFSM.State.keys()[state]) \
			.contains([WrestlerFSM.State.VICTORY])


func test_the_victory_state_plays_the_authored_celebration() -> void:
	assert_str(WrestlerController.clip_for_state(
			WrestlerFSM.State.VICTORY, true)).is_equal("strikes/win_celebrate")
