extends GdUnitTestSuite
## Selling (gauntlet/refs/match_aaa_plan.md): a blow is sold for a second,
## not a third of one. HIT_REACT keeps its 20 ticks -- the frame data -- and
## the sell plays on after it in IDLE while he is left alone; an AI man waits
## it out, and a third blow inside a sell rocks him.

var _scene: Node
var _a: WrestlerController
var _b: WrestlerController


func before_test() -> void:
	_scene = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(_scene, pair[0], pair[1], 3)
	_scene.entrances = false
	add_child(_scene)
	_a = _scene.get_node("WrestlerA")
	_b = _scene.get_node("WrestlerB")
	# The man selling is AI; the other stands still (no live input in a
	# headless test), so nothing but the blows below happens to him.
	_b.is_ai = true
	_a.is_ai = false


func after_test() -> void:
	_scene.queue_free()


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_each_reaction_has_its_sell() -> void:
	var jab: MoveDef = load("res://resources/moves/strike_jab.tres")
	var gut: MoveDef = load("res://resources/moves/strike_gut_punch.tres")
	assert_str(StrikeRecipes.sell_for(StrikeRecipes.reaction_for(jab))) \
			.is_equal(StrikeRecipes.clip("sell_head"))
	assert_str(StrikeRecipes.sell_for(StrikeRecipes.reaction_for(gut))) \
			.is_equal(StrikeRecipes.clip("sell_gut"))
	assert_str(StrikeRecipes.sell_for("strikes/stunned")).is_equal("")


func test_the_sell_clips_are_as_long_as_the_sell() -> void:
	for name in ["sell_head", "sell_gut"]:
		var clip := _b.anim_player.get_animation(StrikeRecipes.clip(name))
		assert_object(clip).is_not_null()
		assert_float(clip.length * 60.0).is_equal_approx(
				WrestlerController.SELL_TICKS, 1.0)


func test_a_man_left_alone_sells_the_blow_and_waits_it_out() -> void:
	await _ticks(2)
	_b._begin_hit_reaction(load("res://resources/moves/strike_cross.tres"))
	assert_int(_b.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)
	await _ticks(WrestlerController.HIT_REACT_TICKS + 1)
	assert_int(_b.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
	assert_int(_b.sell_ticks).is_greater(WrestlerController.SELL_TICKS - 4)
	# An AI man selling does nothing but a reversal.
	var polled := _b._poll_live_input()
	assert_bool(polled.has("strike")).is_false()
	assert_bool(polled.has("move")).is_false()


func test_a_third_blow_inside_the_sell_rocks_him() -> void:
	await _ticks(2)
	var cross: MoveDef = load("res://resources/moves/strike_cross.tres")
	_b._begin_hit_reaction(cross)
	await _ticks(WrestlerController.HIT_REACT_TICKS + 4)
	_b._begin_hit_reaction(cross)
	assert_int(_b.fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)
	await _ticks(WrestlerController.HIT_REACT_TICKS + 4)
	_b._begin_hit_reaction(cross)
	assert_int(_b.fsm.current_state).is_equal(WrestlerFSM.State.STUNNED)


## Strike strings: inside the window the second shot is light and the third
## the heaviest he has; out of it, the ordinary draw.
func test_a_string_ends_on_his_heaviest_shot() -> void:
	await _ticks(2)
	var roman: WrestlerController = _a if _a.strike_move_pool.size() >= 2 else _b
	var heaviest := 0.0
	for m: MoveDef in roman.strike_move_pool + [roman.strike_move]:
		heaviest = maxf(heaviest, StrikeRecipes.total_damage(m))
	roman._count_string_hit()
	roman._count_string_hit()
	var third := roman._pick_string_strike()
	assert_float(StrikeRecipes.total_damage(third)).is_equal(heaviest)
	roman._count_string_hit()
	assert_int(roman._string_hits).is_equal(0)
	# Too long after the last landed: a fresh draw, the string forgotten.
	roman._count_string_hit()
	roman._string_clock += WrestlerController.STRING_WINDOW_TICKS + 1
	roman._pick_string_strike()
	assert_int(roman._string_hits).is_equal(0)
