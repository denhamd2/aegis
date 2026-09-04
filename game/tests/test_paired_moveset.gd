extends GdUnitTestSuite
## The full paired moveset: the 17 moves ARCHITECTURE.md scopes (11 grapple
## + 6 reversal), their trajectories, and the seeded pools that let a
## wrestler actually reach more than one move per tier.
##
## Before pools existed each wrestler had exactly one MoveDef slot per tier,
## so authoring 13 more moves would have added 13 unreachable files. These
## tests cover the two halves of that: that every scoped move exists as a
## MoveDef with a trajectory and both role recipes, and that the draw which
## chooses between them is reproducible from the match seed -- a paired move
## feeds damage and momentum, so an unseeded draw would break replays.

const PairedRecipes := preload("res://resources/animations/paired_recipes.gd")
const PAIRED_MOVES := preload("res://resources/animations/paired_moves.tres")
const MOVES_DIR := "res://resources/moves"

## ARCHITECTURE.md's "Scope" section: 11 grapple + 6 reversal paired moves
## (12 grapple until the suplex was cut for looking bad; its slot is held
## for a motion-captured replacement, not backfilled with a procedural one).
const SCOPED_GRAPPLE := 11
const SCOPED_REVERSAL := 6

func _paired_move_names() -> Array[String]:
	var names: Array[String] = []
	for name in PAIRED_MOVES.get_animation_list():
		names.append(String(name))
	names.sort()
	return names

func _move_defs() -> Array[MoveDef]:
	var defs: Array[MoveDef] = []
	for file in DirAccess.get_files_at(MOVES_DIR):
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load("%s/%s" % [MOVES_DIR, file])
		if res is MoveDef:
			defs.append(res)
	return defs

func _make_move(id: StringName) -> MoveDef:
	var move := MoveDef.new()
	move.animation_pair_id = id
	return move

func _make_attacker() -> WrestlerController:
	var attacker: WrestlerController = auto_free(WrestlerController.new())
	var defender: WrestlerController = auto_free(WrestlerController.new())
	defender.weight_class = 1
	attacker.opponent = defender
	return attacker

func test_the_moveset_covers_everything_architecture_scopes() -> void:
	var grapple := 0
	var reversal := 0
	for name in _paired_move_names():
		if name.begins_with("reversal_"):
			reversal += 1
		else:
			grapple += 1
	assert_int(grapple).override_failure_message(
		"Grapple moves in paired_moves.tres: %s" % [_paired_move_names()]
	).is_equal(SCOPED_GRAPPLE)
	assert_int(reversal).is_equal(SCOPED_REVERSAL)

func test_every_paired_move_has_a_move_def() -> void:
	var ids: Array[String] = []
	for def in _move_defs():
		ids.append(String(def.animation_pair_id))
	var orphaned: Array[String] = []
	for name in _paired_move_names():
		if not ids.has(name):
			orphaned.append(name)
	assert_array(orphaned).override_failure_message(
		"Animations with no MoveDef, so nothing can ever play them: %s" % [orphaned]
	).is_empty()

## The inverse: a MoveDef naming an animation nobody generated resolves to a
## grey-box timer at runtime rather than failing, which is exactly the kind
## of silent gap this whole change exists to close.
func test_every_paired_move_def_has_an_animation_and_both_recipes() -> void:
	var broken: Array[String] = []
	for def in _move_defs():
		var id := String(def.animation_pair_id)
		# Strikes and running attacks are single-character moves and don't
		# go through GrappleRig at all -- see ARCHITECTURE.md.
		if not PairedRecipes.RECIPES.has(id):
			continue
		if not PAIRED_MOVES.has_animation(id):
			broken.append("%s: recipe but no trajectory" % id)
		var recipe: Dictionary = PairedRecipes.RECIPES[id]
		for role: String in ["attacker", "defender"]:
			if not recipe.has(role) or (recipe[role] as Array).is_empty():
				broken.append("%s: no %s poses" % [id, role])
	assert_array(broken).is_empty()

func test_generated_trajectories_key_both_roots() -> void:
	var wrong: Array[String] = []
	for move_id in PairedRecipes.TRAJECTORIES:
		var anim := PAIRED_MOVES.get_animation(StringName(move_id))
		if not anim:
			wrong.append("%s: not in the library" % move_id)
			continue
		var seen: Array[String] = []
		for i in anim.get_track_count():
			seen.append("%d:%s" % [anim.track_get_type(i), anim.track_get_path(i)])
		for path: String in ["../WrestlerA", "../WrestlerB"]:
			for type: int in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D]:
				var key := "%d:%s" % [type, path]
				if not seen.has(key):
					wrong.append("%s: missing %s" % [move_id, key])
	assert_array(wrong).is_empty()

## Every generated arc runs the full length of its clip at both ends. A
## trajectory whose last key lands early leaves the wrestler snapping from
## wherever the animation stopped to wherever GrappleRig puts him.
func test_generated_trajectories_span_their_whole_clip() -> void:
	var short: Array[String] = []
	for move_id in PairedRecipes.TRAJECTORIES:
		var anim := PAIRED_MOVES.get_animation(StringName(move_id))
		for i in anim.get_track_count():
			var last := anim.track_get_key_count(i) - 1
			if not is_equal_approx(anim.track_get_key_time(i, 0), 0.0):
				short.append("%s %s starts at %.2f"
						% [move_id, anim.track_get_path(i),
						anim.track_get_key_time(i, 0)])
			if not is_equal_approx(anim.track_get_key_time(i, last), anim.length):
				short.append("%s %s ends at %.2f, clip is %.2f"
						% [move_id, anim.track_get_path(i),
						anim.track_get_key_time(i, last), anim.length])
	assert_array(short).is_empty()

func test_an_empty_pool_always_gives_the_tier_its_own_move() -> void:
	var attacker := _make_attacker()
	var primary := _make_move(&"primary")
	assert_object(attacker._pick_tier_move(primary, [])).is_same(primary)

func test_the_tier_draw_is_reproducible_from_the_match_seed() -> void:
	var pool: Array[MoveDef] = [_make_move(&"a"), _make_move(&"b"), _make_move(&"c")]
	var primary := _make_move(&"primary")
	var first: Array[StringName] = []
	var second: Array[StringName] = []
	for run: Array[StringName] in [first, second]:
		var attacker := _make_attacker()
		attacker.match_seed = 7
		attacker.player_index = 1
		for _i in 8:
			run.append(attacker._pick_tier_move(primary, pool).animation_pair_id)
	assert_array(second).is_equal(first)

## Draws must not be one move repeated -- a pool that always resolves to the
## same entry is the single-slot moveset with extra files.
func test_the_tier_draw_reaches_more_than_one_move() -> void:
	var pool: Array[MoveDef] = [_make_move(&"a"), _make_move(&"b"), _make_move(&"c")]
	var primary := _make_move(&"primary")
	var attacker := _make_attacker()
	attacker.match_seed = 3
	var drawn := {}
	for _i in 24:
		drawn[attacker._pick_tier_move(primary, pool).animation_pair_id] = true
	assert_int(drawn.size()).override_failure_message(
		"Only drew %s across 24 picks" % [drawn.keys()]
	).is_greater(1)

func test_the_tier_draw_skips_moves_this_opponent_is_too_heavy_for() -> void:
	var forbidden := _make_move(&"forbidden")
	forbidden.weight_class_max = 0
	var attacker := _make_attacker()
	attacker.match_seed = 11
	var primary := _make_move(&"primary")
	for _i in 16:
		assert_str(attacker._pick_tier_move(primary, [forbidden]).animation_pair_id) \
			.is_equal(&"primary")

func test_the_counter_draw_is_reproducible_from_the_match_seed() -> void:
	var pool: Array[MoveDef] = [_make_move(&"x"), _make_move(&"y")]
	var first: Array[StringName] = []
	var second: Array[StringName] = []
	for run: Array[StringName] in [first, second]:
		var referee: MatchReferee = auto_free(MatchReferee.new())
		referee.match_seed = 5
		referee.reversal_counter_move = _make_move(&"counter")
		referee.reversal_move_pool = pool
		for _i in 8:
			run.append(referee._pick_counter().animation_pair_id)
	assert_array(second).is_equal(first)

func test_the_counter_draw_falls_back_to_the_single_move() -> void:
	var referee: MatchReferee = auto_free(MatchReferee.new())
	var counter := _make_move(&"counter")
	referee.reversal_counter_move = counter
	assert_object(referee._pick_counter()).is_same(counter)

## The moves only matter if the shipped match actually hands them out.
func test_the_match_scene_gives_both_wrestlers_the_whole_moveset() -> void:
	var match_scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	var reachable := {}
	for name: String in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = match_scene.get_node(name)
		for tier: Array in [
			[w.grapple_move, w.grapple_move_pool],
			[w.power_move, w.power_move_pool],
			[w.signature_move, w.signature_move_pool],
			[w.finisher_move, w.finisher_move_pool],
		]:
			reachable[String((tier[0] as MoveDef).animation_pair_id)] = true
			for extra: MoveDef in tier[1]:
				reachable[String(extra.animation_pair_id)] = true
	var referee: MatchReferee = match_scene.get_node("MatchReferee")
	reachable[String(referee.reversal_counter_move.animation_pair_id)] = true
	for extra: MoveDef in referee.reversal_move_pool:
		reachable[String(extra.animation_pair_id)] = true
	var unreachable: Array[String] = []
	for name in _paired_move_names():
		if not reachable.has(name):
			unreachable.append(name)
	assert_array(unreachable).override_failure_message(
		"Authored but unreachable in match.tscn: %s" % [unreachable]
	).is_empty()

## No root track may put a wrestler below mat level. The model's origin is
## at its feet, so a negative y is his feet through the canvas, not a
## crouch. Authoring crouches and kneeling finishes as root dips instead of
## bone poses took the match's minimum body height from -0.03m to -0.26m
## the first time these trajectories were generated -- the whole match, not
## just the move, because a body left low stays low until the next getup.
func test_no_trajectory_puts_a_wrestler_under_the_mat() -> void:
	var sunk: Array[String] = []
	for name in PAIRED_MOVES.get_animation_list():
		var anim := PAIRED_MOVES.get_animation(name)
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_POSITION_3D:
				continue
			for k in anim.track_get_key_count(i):
				var pos: Vector3 = anim.track_get_key_value(i, k)
				if pos.y < 0.0:
					sunk.append("%s %s at %.2f: y=%.3f"
							% [name, anim.track_get_path(i),
							anim.track_get_key_time(i, k), pos.y])
	assert_array(sunk).override_failure_message(
		"Root keys below the mat: %s" % [sunk]
	).is_empty()
