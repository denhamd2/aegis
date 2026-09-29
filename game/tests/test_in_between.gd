extends GdUnitTestSuite
## Phase 4, the AI's in-between behaviour (gauntlet/refs/animation_gap.md):
## a man plays to the crowd with his own taunt, sells the part that has
## taken the most, and paces himself as he wears down.


func test_a_taunt_starts_standing_and_can_be_cut_off() -> void:
	var legal := WrestlerFSM.LEGAL_TRANSITIONS
	assert_bool(legal[WrestlerFSM.State.IDLE].has(WrestlerFSM.State.TAUNT)).is_true()
	assert_bool(legal[WrestlerFSM.State.LOCOMOTION].has(WrestlerFSM.State.TAUNT)).is_true()
	for out: WrestlerFSM.State in [WrestlerFSM.State.IDLE, WrestlerFSM.State.HIT_REACT,
			WrestlerFSM.State.DOWN]:
		assert_bool(legal[WrestlerFSM.State.TAUNT].has(out)).is_true()


func test_each_mans_taunt_is_a_real_clip_held_no_longer_than_it_runs() -> void:
	for style: String in WrestlerController.TAUNTS:
		var t: Array = WrestlerController.TAUNTS[style]
		var key := String(t[0]).trim_prefix("strikes/")
		assert_bool(WrestlerController.StrikeRecipes.RECIPES.has(key)) \
				.override_failure_message("no clip for %s's taunt: %s" % [style, t[0]]).is_true()
		var seconds: float = WrestlerController.StrikeRecipes.RECIPES[key]["seconds"]
		assert_float(seconds * 60.0).is_greater_equal(float(t[1]))


func test_he_sells_what_has_taken_the_most() -> void:
	var d := {CombatSystem.Limb.HEAD: 10.0, CombatSystem.Limb.TORSO: 30.0,
			CombatSystem.Limb.ARMS: 5.0, CombatSystem.Limb.LEGS: 55.0}
	assert_str(WrestlerController.most_hurt(d, 20.0)).is_equal("legs")
	d[CombatSystem.Limb.HEAD] = 70.0
	assert_str(WrestlerController.most_hurt(d, 20.0)).is_equal("head")
	# Nothing past the bar: nothing to sell.
	assert_str(WrestlerController.most_hurt(d, 80.0)).is_equal("")


func test_every_part_he_can_sell_has_a_clutch() -> void:
	for part: String in ["head", "torso", "legs", "arms"]:
		assert_bool(SellClutch.LEAN_DEG.has(part)).is_true()


func test_a_worn_man_walks_slower_and_waits_longer() -> void:
	assert_float(WrestlerAI.fatigue_walk_scale(0.0)).is_equal(1.0)
	assert_float(WrestlerAI.fatigue_cooldown_scale(0.0)).is_equal(1.0)
	var spent := BodyLife.DAMAGE_FULL * 2.0
	assert_float(WrestlerAI.fatigue_walk_scale(spent)).is_equal_approx(WrestlerAI.FATIGUE_WALK_MIN, 1e-6)
	assert_float(WrestlerAI.fatigue_cooldown_scale(spent)).is_equal_approx(WrestlerAI.FATIGUE_COOLDOWN_MAX, 1e-6)
	var last_walk := 2.0
	var last_wait := 0.0
	for d in range(0, 200, 10):
		var walk := WrestlerAI.fatigue_walk_scale(float(d))
		var wait := WrestlerAI.fatigue_cooldown_scale(float(d))
		assert_float(walk).is_less_equal(last_walk)
		assert_float(wait).is_greater_equal(last_wait)
		last_walk = walk
		last_wait = wait
