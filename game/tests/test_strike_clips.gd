extends GdUnitTestSuite
## Strikes: the generated clips, the reach that decides whether one
## connects, and the reaction the wrestler taking it plays.
##
## What was wrong, all of it measured rather than guessed:
##   - strike_jab.tres ran 20 ticks against an 0.87s Punch_Jab, so 38% of
##     the punch played and the arm cross-faded away mid-travel
##   - STRIKE_HIT_RANGE was 1.8m against a fist that reaches 0.76m; an
##     instrumented match recorded strikes landing at 1.60m, more than half
##     a metre of clear air
##   - every hit played Hit_Chest, so a jab to the jaw and a slam to the
##     ribs produced the same flinch
##   - there was no kick at all
##   - the AI could only strike between 1.4m and 1.6m, a shell it crosses in
##     two ticks, so one match contained exactly one strike exchange

const StrikeRecipes := preload("res://resources/animations/strike_recipes.gd")
const STRIKE_CLIPS := preload("res://resources/animations/strike_clips.tres")
const RIG := preload("res://assets/characters/wrestler_base.glb")

func _rig_player() -> AnimationPlayer:
	var model: Node = auto_free(RIG.instantiate())
	add_child(model)
	return model.find_child("AnimationPlayer", true, false)

func _make_move(head: float, torso: float) -> MoveDef:
	var move := MoveDef.new()
	move.damage_head = head
	move.damage_torso = torso
	return move

func test_every_recipe_produces_a_clip() -> void:
	for name in StrikeRecipes.RECIPES:
		assert_bool(STRIKE_CLIPS.has_animation(StringName(name))) \
			.override_failure_message("No generated clip for '%s'" % name).is_true()

func test_every_source_clip_is_on_the_rig() -> void:
	var player := _rig_player()
	var missing: Array[String] = []
	for name in StrikeRecipes.RECIPES:
		var recipe: Dictionary = StrikeRecipes.RECIPES[name]
		var source_player := player
		var source_model: Node
		if recipe.has("file"):
			var packed: PackedScene = load(recipe["file"])
			if packed:
				source_model = auto_free(packed.instantiate())
				source_player = source_model.find_child("AnimationPlayer", true, false)
		if recipe.has("source") and (not source_player \
				or not source_player.has_animation(String(recipe["source"]))):
			missing.append("%s -> %s" % [name, recipe["source"]])
		for sample: Dictionary in recipe.get("samples", []):
			if not source_player.has_animation(String(sample["clip"])):
				missing.append("%s -> %s" % [name, sample["clip"]])
	assert_array(missing).is_empty()

func test_every_sample_time_is_inside_its_source() -> void:
	var player := _rig_player()
	var bad: Array[String] = []
	for name in StrikeRecipes.RECIPES:
		for sample: Dictionary in StrikeRecipes.RECIPES[name].get("samples", []):
			var source: Animation = player.get_animation(String(sample["clip"]))
			if float(sample["at"]) < 0.0 or float(sample["at"]) > source.length:
				bad.append("%s: %s@%.3f (0..%.3f)"
						% [name, sample["clip"], sample["at"], source.length])
	assert_array(bad).is_empty()

func test_generated_clips_are_the_length_the_recipe_asks_for() -> void:
	for name in StrikeRecipes.RECIPES:
		var want: float = StrikeRecipes.RECIPES[name]["seconds"]
		assert_float(STRIKE_CLIPS.get_animation(StringName(name)).length) \
			.override_failure_message("%s is not %.3fs" % [name, want]) \
			.is_equal_approx(want, 0.001)

func test_generated_tracks_resolve_on_the_runtime_rig() -> void:
	var player := _rig_player()
	var runtime_tracks := {}
	var template: Animation = player.get_animation("Punch_Cross")
	for track in template.get_track_count():
		runtime_tracks["%d:%s" % [template.track_get_type(track),
				String(template.track_get_path(track).get_concatenated_subnames())]] = true
	var unresolved: Array[String] = []
	for name in StrikeRecipes.RECIPES:
		var clip: Animation = STRIKE_CLIPS.get_animation(StringName(name))
		for track in clip.get_track_count():
			var key := "%d:%s" % [clip.track_get_type(track),
					String(clip.track_get_path(track).get_concatenated_subnames())]
			if not runtime_tracks.has(key):
				unresolved.append("%s -> %s" % [name, key])
	assert_array(unresolved).is_empty()

## The whole point of generating them: the clip a state plays must be as
## long as the state, or the FSM cuts it off mid-motion.
func test_the_jab_clip_matches_the_move_that_plays_it() -> void:
	var move: MoveDef = load("res://resources/moves/strike_jab.tres")
	var clip := STRIKE_CLIPS.get_animation(&"strike_jab")
	var move_seconds := move.total_frames() / float(Engine.physics_ticks_per_second)
	assert_float(clip.length).override_failure_message(
		"strike_jab.tres runs %.3fs but its clip is %.3fs, so the punch is "
		% [move_seconds, clip.length] + "cut off or frozen"
	).is_equal_approx(move_seconds, 0.02)

func test_the_kick_clip_matches_the_move_that_plays_it() -> void:
	var move: MoveDef = load("res://resources/moves/strike_kick.tres")
	var clip := STRIKE_CLIPS.get_animation(&"strike_kick")
	assert_float(clip.length).is_equal_approx(
		move.total_frames() / float(Engine.physics_ticks_per_second), 0.02)

func test_the_reactions_are_as_long_as_the_hit_reaction_state() -> void:
	var seconds := WrestlerController.HIT_REACT_TICKS / float(Engine.physics_ticks_per_second)
	for name: StringName in [&"hit_head", &"hit_torso"]:
		assert_float(STRIKE_CLIPS.get_animation(name).length) \
			.override_failure_message("%s outlives or undershoots HIT_REACT" % name) \
			.is_equal_approx(seconds, 0.02)

func test_the_stunned_clip_is_as_long_as_the_stunned_state() -> void:
	assert_float(STRIKE_CLIPS.get_animation(&"stunned").length).is_equal_approx(
		WrestlerController.STUNNED_TICKS / float(Engine.physics_ticks_per_second), 0.02)

func test_a_head_shot_and_a_body_shot_pick_different_reactions() -> void:
	var head := StrikeRecipes.reaction_for(_make_move(4.0, 1.0))
	var body := StrikeRecipes.reaction_for(_make_move(1.0, 6.0))
	assert_str(head).is_equal("strikes/hit_head")
	assert_str(body).is_equal("strikes/hit_torso")
	assert_str(head).is_not_equal(body)

func test_a_move_with_no_damage_still_gets_a_reaction() -> void:
	assert_str(StrikeRecipes.reaction_for(null)).is_equal("strikes/hit_torso")

## A strike must not be able to land from further than the fist can reach.
## Measured by running FK over the generated jab: the fist peaks 0.76m
## ahead of the wrestler's own origin, and the opponent's capsule radius is
## 0.4m, so the furthest a punch can honestly connect is ~1.16m.
const MEASURED_FIST_REACH := 0.76
const CAPSULE_RADIUS := 0.4

func test_strikes_cannot_land_from_further_than_a_fist_reaches() -> void:
	assert_float(WrestlerController.STRIKE_HIT_RANGE).override_failure_message(
		"Strikes land from %.2fm but a fist reaches %.2fm"
		% [WrestlerController.STRIKE_HIT_RANGE, MEASURED_FIST_REACH + CAPSULE_RADIUS]
	).is_less_equal(MEASURED_FIST_REACH + CAPSULE_RADIUS)

## The AI must not throw a strike it cannot land. Its close-range decision
## happens inside tie_up_range (1.3m), which reaches further than a fist
## does (1.15m), so the decision is additionally gated on the reach -- this
## is the assertion that caught that gap.
func test_the_ai_never_strikes_from_beyond_a_fists_reach() -> void:
	var ai: WrestlerAI = auto_free(WrestlerAI.new())
	assert_bool(ai.tie_up_range > WrestlerController.STRIKE_HIT_RANGE) \
		.override_failure_message(
			"This test guards a gap that no longer exists; if tie-up range "
			+ "is now within a fist's reach the gate below is redundant."
		).is_true()
	# The source of truth is the gate itself: poll_input() may only return a
	# strike when the opponent is inside STRIKE_HIT_RANGE.
	var source := FileAccess.get_file_as_string("res://core/ai/wrestler_ai.gd")
	assert_str(source).contains("distance <= WrestlerController.STRIKE_HIT_RANGE")
