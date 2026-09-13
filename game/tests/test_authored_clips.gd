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
	"strike_cross": 0.667,   # strike_cross.tres: 12+4+24 = 40 frames
	"hit_head": 0.333,       # WrestlerController.HIT_REACT_TICKS = 20
	"win_celebrate": 1.300,  # free: VICTORY is terminal, nothing times out
}


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


func test_victory_is_terminal() -> void:
	# The match is over. Anything leading out of VICTORY would let a frozen
	# wrestler act again, and the celebration holding its last pose is the
	# intended end state rather than an oversight.
	assert_array(WrestlerFSM.LEGAL_TRANSITIONS[WrestlerFSM.State.VICTORY]) \
		.is_empty()


func test_a_winner_can_celebrate_from_wherever_the_bell_catches_him() -> void:
	# A pinfall winner is in PIN_ATTACKER and a submission winner in
	# SUBMISSION_ATTACKER, but the referee can also declare one from a
	# tie-up resolution, so every non-terminal state has to reach VICTORY.
	for state: int in WrestlerFSM.State.values():
		if state == WrestlerFSM.State.VICTORY:
			continue
		assert_array(WrestlerFSM.LEGAL_TRANSITIONS[state]) \
			.override_failure_message(
				"state %d cannot reach VICTORY" % state) \
			.contains([WrestlerFSM.State.VICTORY])


func test_the_victory_state_plays_the_authored_celebration() -> void:
	assert_str(WrestlerController.clip_for_state(
			WrestlerFSM.State.VICTORY, true)).is_equal("strikes/win_celebrate")
