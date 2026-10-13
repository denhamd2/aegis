extends GdUnitTestSuite
## A hit is sold to its size and to what the man has left
## (WrestlerController.sell_tier): a jab is a flinch, a chair to the head a
## stagger, the same chair on a beaten man takes him to a knee, and the
## biggest shots put him down on their own.


const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func test_a_jab_is_a_flinch_and_a_big_boot_is_not() -> void:
	assert_int(WrestlerController.sell_tier(4.0, 1.0, false)).is_equal(WrestlerController.Sell.LIGHT)
	assert_int(WrestlerController.sell_tier(8.0, 1.0, false)).is_equal(WrestlerController.Sell.MEDIUM)
	assert_int(WrestlerController.sell_tier(14.0, 1.0, false)).is_equal(WrestlerController.Sell.HEAVY)


func test_the_same_hit_sells_bigger_on_a_beaten_man() -> void:
	assert_int(WrestlerController.sell_tier(4.0, 0.1, false)).is_equal(WrestlerController.Sell.MEDIUM)
	assert_int(WrestlerController.sell_tier(8.0, 0.1, false)).is_equal(WrestlerController.Sell.KNEE)
	assert_int(WrestlerController.sell_tier(14.0, 0.1, false)).is_equal(WrestlerController.Sell.DOWN)


func test_a_chair_shot_staggers_a_fresh_man_and_floors_a_beaten_one() -> void:
	var chair := WeaponCatalog.swing_move(WeaponCatalog.by_id(&"steel_chair"))
	var dealt := chair.damage_head + chair.damage_torso + chair.damage_arms + chair.damage_legs
	assert_int(WrestlerController.sell_tier(dealt, 1.0, true)).is_equal(WrestlerController.Sell.HEAVY)
	assert_int(WrestlerController.sell_tier(dealt, 0.2, true)).is_equal(WrestlerController.Sell.DOWN)


func test_the_steps_put_anyone_down() -> void:
	var steps := WeaponCatalog.swing_move(WeaponCatalog.by_id(&"steel_steps"))
	var dealt := steps.damage_head + steps.damage_torso + steps.damage_arms + steps.damage_legs
	assert_int(WrestlerController.sell_tier(dealt, 1.0, true)).is_equal(WrestlerController.Sell.DOWN)


func test_every_tier_has_a_reaction_clip() -> void:
	for name: String in ["hit_head", "hit_torso", "hit_heavy_head", "hit_heavy_gut", "hit_knee", "bump_back"]:
		assert_bool(StrikeRecipes.RECIPES.has(name)).override_failure_message("no " + name).is_true()
	assert_str(StrikeRecipes.sell_for(StrikeRecipes.clip("hit_heavy_head"))).is_equal(StrikeRecipes.clip("sell_head"))
	assert_str(StrikeRecipes.sell_for(StrikeRecipes.clip("hit_heavy_gut"))).is_equal(StrikeRecipes.clip("sell_gut"))


func test_a_beaten_man_lies_there_longer() -> void:
	var w: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(w)
	await get_tree().physics_frame
	w._go_down(-1)
	var fresh := w._move_ticks_remaining
	w.combat.limb_damage[CombatSystem.Limb.HEAD] = 100.0
	w.combat.limb_damage[CombatSystem.Limb.TORSO] = 100.0
	w.fsm.transition_to(WrestlerFSM.State.GETUP)
	w.fsm.transition_to(WrestlerFSM.State.IDLE)
	w._go_down(-1)
	assert_int(w._move_ticks_remaining).is_greater(fresh)
