extends GdUnitTestSuite
## The gate `move_def.gd` and `strike_recipes.gd` both promise.
##
## Three separate comments in those two files say a test fails on a bad
## `sell_frames` -- and the file they name did not exist. This is it.
##
## What it is protecting
## ---------------------
## HIT_REACT runs for exactly the landing move's `sell_frames` ticks and
## plays one clip for that whole stretch. The clip is not stretched to fit:
## if it is shorter than the state, it ends and the defender FREEZES on its
## last pose for the remainder; if it is longer, it is cut off mid-sell. So
## `sell_frames` is not a tuning knob. It has to be one of the lengths a
## reaction clip was actually authored at, and the clip that gets picked for
## a move has to be exactly that long.
##
## Neither of those is visible in code review -- the .tres carries a plain
## integer, and the clip it implies is chosen three files away by
## `StrikeRecipes.reaction_for()`. Both are trivially checkable here.

const StrikeRecipes := preload("res://resources/animations/strike_recipes.gd")
const STRIKE_CLIPS := preload("res://resources/animations/strike_clips.tres")
const MOVES_DIR := "res://resources/moves"


## Every MoveDef on disk, the way `test_paired_moveset.gd` gathers them.
func _move_files() -> Array:
	var out: Array = []
	for file in DirAccess.get_files_at(MOVES_DIR):
		if not file.ends_with(".tres"):
			continue
		var res: Resource = load("%s/%s" % [MOVES_DIR, file])
		if res is MoveDef:
			out.append({"name": file.get_basename(), "move": res})
	return out


## `reaction_for()` returns a library-qualified name ("strikes/hit_torso");
## the AnimationLibrary itself is keyed on the bare name.
func _reaction_clip(move: MoveDef) -> Animation:
	var qualified := StrikeRecipes.reaction_for(move)
	var bare := qualified.get_slice("/", 1)
	if bare.is_empty() or not STRIKE_CLIPS.has_animation(StringName(bare)):
		return null
	return STRIKE_CLIPS.get_animation(StringName(bare))


## A sell length that no clip was authored at freezes the defender.
##
## This is the assertion all three of those comments describe. It is a
## whitelist and not a range on purpose: 22 ticks is a perfectly reasonable
## number and there is no 22-tick clip, so it would fail here rather than
## ship a reaction that stops four ticks early.
func test_every_move_sells_at_a_length_a_clip_exists_for() -> void:
	for entry: Dictionary in _move_files():
		var move: MoveDef = entry["move"]
		assert_bool(StrikeRecipes.SELL_FRAMES.has(move.sell_frames)) \
			.override_failure_message(
				"%s.tres sells for %d ticks and no reaction clip is that "
				% [entry["name"], move.sell_frames]
				+ "long. Authored lengths are %s -- a clip that is shorter "
				% [StrikeRecipes.SELL_FRAMES]
				+ "than the state leaves the defender frozen on its last "
				+ "pose for the rest of it.") \
			.is_true()


## There is deliberately no `hit_head_heavy`, and `reaction_for()` says so:
## a head move asking for a heavy sell silently falls back to the med clip,
## which is 24 ticks against a 34-tick state. That is the freeze this suite
## exists to catch, arriving through the fallback rather than through a bad
## number, so it is checked separately.
func test_no_head_move_asks_for_a_heavy_sell() -> void:
	for entry: Dictionary in _move_files():
		var move: MoveDef = entry["move"]
		if move.damage_head <= move.damage_torso:
			continue
		assert_int(move.sell_frames) \
			.override_failure_message(
				"%s.tres does head damage and sells for %d ticks, but there "
				% [entry["name"], move.sell_frames]
				+ "is no hit_head_heavy clip -- reaction_for() falls back to "
				+ "hit_head_med and the defender freezes for the difference.") \
			.is_less(StrikeRecipes.SELL_HEAVY)


## The clip that actually gets picked is exactly as long as the state that
## plays it.
##
## The two tests above check the NUMBER; this one closes the loop by asking
## the picker what it would really play and measuring it. A clip could be
## re-baked at a new length without its SELL_* constant moving, and nothing
## else in the suite would notice.
func test_every_reaction_clip_is_exactly_as_long_as_the_sell() -> void:
	var ticks := float(Engine.physics_ticks_per_second)
	for entry: Dictionary in _move_files():
		var move: MoveDef = entry["move"]
		var clip := _reaction_clip(move)
		assert_object(clip) \
			.override_failure_message(
				"%s.tres resolves to reaction clip '%s', which is not in "
				% [entry["name"], StrikeRecipes.reaction_for(move)]
				+ "strike_clips.tres at all") \
			.is_not_null()
		if clip == null:
			continue
		var want := move.sell_frames / ticks
		assert_float(clip.length) \
			.override_failure_message(
				"%s.tres sells for %d ticks (%.3fs) but plays '%s', which "
				% [entry["name"], move.sell_frames, want,
					StrikeRecipes.reaction_for(move)]
				+ "is %.3fs" % clip.length) \
			.is_equal_approx(want, 0.02)


## Hitstop is counted in ticks and held, so a negative one would hold
## forever. Zero is the default and the right value for a light exchange.
func test_no_move_asks_for_negative_hitstop() -> void:
	for entry: Dictionary in _move_files():
		var move: MoveDef = entry["move"]
		assert_int(move.hitstop_frames) \
			.override_failure_message(
				"%s.tres asks for %d ticks of hitstop"
				% [entry["name"], move.hitstop_frames]) \
			.is_greater_equal(0)
