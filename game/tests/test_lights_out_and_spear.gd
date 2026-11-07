extends GdUnitTestSuite
## The owner, 2 Nov.
## - Lights Out: "more time battling outside the ring and using the full
##   selection of weapons. Ensure there is at least one ladder climb and jump.
##   Also ensure they don't overuse one weapon ... when wrestlers are healthy
##   ... a little more defense against being hit by a weapon, either blocking
##   or grabbing the weapon ... less so when their health depleted".
## - "roman didn't land his spear. find out why, and fix" -- the story's loser
##   was locked off his finisher all match.
## A whole seeded match of each is tools/probe/nhb_weapon_probe and flow_probe.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _pair(nhb: bool) -> Array[WrestlerController]:
	var out: Array[WrestlerController] = []
	for i in 2:
		var w: WrestlerController = WRESTLER_SCENE.instantiate()
		w.player_index = i
		w.display_name = "ROMAN REIGNS" if i == 0 else "CODY RHODES"
		if nhb:
			MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
		auto_free(w)
		add_child(w)
		out.append(w)
	out[0].opponent = out[1]
	out[1].opponent = out[0]
	for w in out:
		w.is_ai = true
		w.ai.target = w.opponent
		w.ai.setup_jitter(5, w.player_index)
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	return out


func _flow(pair: Array[WrestlerController], at_seconds: float) -> MatchFlow:
	var flow: MatchFlow = auto_free(MatchFlow.new())
	flow.watch(pair)
	flow.tick = int(at_seconds * 60.0)
	return flow


func after_test() -> void:
	var stock := get_node_or_null("WeaponStock")
	if stock:
		stock.free()


# --- Weapon defence ---------------------------------------------------------

func test_a_healthy_man_defends_some_swings_and_a_hurt_one_none() -> void:
	var full := WrestlerController.weapon_defense_chance(1.0)
	assert_float(full).is_equal_approx(WrestlerController.WEAPON_DEFENSE_MAX, 0.001)
	# "Not all the time though."
	assert_float(full).is_less(0.5)
	assert_float(WrestlerController.weapon_defense_chance(WrestlerController.WEAPON_DEFENSE_FROM)) \
			.is_equal(0.0)
	assert_float(WrestlerController.weapon_defense_chance(0.1)).is_equal(0.0)
	var last := -1.0
	for i in 11:
		var c := WrestlerController.weapon_defense_chance(float(i) / 10.0)
		assert_float(c).is_greater_equal(last)
		last = c


func test_he_defends_a_chair_but_never_a_gun_a_spray_or_a_set_piece() -> void:
	assert_bool(WrestlerController.weapon_defensible(WeaponCatalog.by_id(&"steel_chair"))).is_true()
	for id: StringName in [&"handgun", &"rpg", &"fire_extinguisher", &"fire_torch"]:
		assert_bool(WrestlerController.weapon_defensible(WeaponCatalog.by_id(id))) \
				.override_failure_message(String(id)).is_false()
	for def: WeaponDef in WeaponCatalog.all():
		if def.set_piece:
			assert_bool(WrestlerController.weapon_defensible(def)) \
					.override_failure_message(String(def.id)).is_false()
	assert_bool(WrestlerController.weapon_defensible(null)).is_false()


# --- Weapon variety and the ladder ------------------------------------------

func test_a_weapon_he_has_used_twice_is_left_lying() -> void:
	var pair := _pair(true)
	var ai: WrestlerAI = pair[0].ai
	ai.used_weapons[&"steel_chair"] = 1
	assert_bool(ai._spent_weapons().has(&"steel_chair")).is_false()
	ai.used_weapons[&"steel_chair"] = WrestlerAI.REUSE_MAX
	assert_bool(ai._spent_weapons().has(&"steel_chair")).is_true()


func test_a_used_weapon_is_picked_far_less_often_again() -> void:
	var pair := _pair(true)
	var ai: WrestlerAI = pair[0].ai
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var before := 0
	for i in 400:
		if ai.choose_weapon(rng) == &"kendo_stick":
			before += 1
	ai.used_weapons[&"kendo_stick"] = 2
	rng.seed = 3
	var after := 0
	for i in 400:
		if ai.choose_weapon(rng) == &"kendo_stick":
			after += 1
	assert_int(after).is_less_equal(maxi(1, before / 4))


func test_the_ladder_comes_out_once_the_match_is_under_way() -> void:
	var pair := _pair(true)
	var ai: WrestlerAI = pair[0].ai
	_flow(pair, WrestlerAI.LADDER_DUE_AT - 10.0)
	assert_bool(ai.ladder_due()).is_false()
	pair[0].flow.tick = int((WrestlerAI.LADDER_DUE_AT + 5.0) * 60.0)
	assert_bool(ai.ladder_due()).is_true()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_str(String(ai.choose_weapon(rng))).is_equal("ladder")
	# Had and left lying, it is still due: the spot is the climb.
	pair[1].ai.used_weapons[&"ladder"] = 1
	assert_bool(ai.ladder_due()).is_true()
	# Once either man has been up one, it is a weapon like any other.
	pair[1].ai.ladder_climbs = 1
	assert_bool(ai.ladder_due()).is_false()


func test_no_ladder_is_due_in_a_singles_match() -> void:
	var pair := _pair(false)
	_flow(pair, WrestlerAI.LADDER_DUE_AT + 60.0)
	assert_bool(pair[0].ai.ladder_due()).is_false()


func test_more_of_the_fight_stays_on_the_floor() -> void:
	# 20-30 s on the floor before one takes it back in (it was 10-18), and
	# most weapons used where they were found.
	assert_int(WrestlerAI.OUTSIDE_SPELL.x).is_greater_equal(20 * 60)
	assert_float(WrestlerAI.IN_RING_USE).is_less(0.5)
	assert_float(WrestlerAI.IN_RING_USE_FROM_STAGE).is_less(WrestlerAI.IN_RING_USE)


# --- The Spear ----------------------------------------------------------------

func test_the_storys_loser_keeps_his_finisher_for_one_near_fall() -> void:
	var pair := _pair(false)
	var flow := _flow(pair, MatchFlow.FINISH_FROM + 10.0)
	var win: WrestlerController = flow.winner
	var lose: WrestlerController = pair[1] if win == pair[0] else pair[0]
	assert_str(flow.rung(win)).is_equal("finisher")
	assert_str(flow.rung(lose)).is_equal("finisher")
	flow.note_finisher(lose)
	assert_str(flow.rung(lose)).is_equal("none")


func test_both_men_have_the_finisher_in_the_comeback() -> void:
	var p := MatchFlow.phase_at(350.0)
	assert_str(String(p["name"])).is_equal("comeback")
	for kind: int in [Persona.Kind.HEEL, Persona.Kind.FACE]:
		assert_str(String(MatchFlow.row(p, kind)["rung"])).is_equal("finisher")


func _spear_ready(pair: Array[WrestlerController], at_seconds: float) -> WrestlerAI:
	_flow(pair, at_seconds)
	var roman := pair[0]
	roman.finisher_run_move = MoveDef.new()
	roman.combat.finisher_blocked = false
	roman.combat.momentum = 100.0
	roman.combat.tier_reached = CombatSystem.Tier.SIGNATURE
	return roman.ai


func test_the_spear_comes_out_of_nowhere_in_the_comeback() -> void:
	var pair := _pair(false)
	var ai := _spear_ready(pair, 330.0)
	assert_bool(ai._wants_spear_from_nowhere(4.0)).is_true()


func test_the_spear_out_of_nowhere_has_its_terms() -> void:
	var pair := _pair(false)
	var ai := _spear_ready(pair, 330.0)
	# Close range is a legal opportunity too; across ringside is not.
	assert_bool(ai._wants_spear_from_nowhere(1.0)).is_true()
	assert_bool(ai._wants_spear_from_nowhere(9.0)).is_false()
	# Not with the other man out on the floor.
	pair[1].outside_ring = true
	assert_bool(ai._wants_spear_from_nowhere(4.0)).is_false()
	pair[1].outside_ring = false
	# Once, then a long wait.
	ai._nowhere_cooldown = WrestlerAI.SPEAR_NOWHERE_COOLDOWN
	assert_bool(ai._wants_spear_from_nowhere(4.0)).is_false()
	ai._nowhere_cooldown = 0
	# Not in the early going.
	pair[0].flow.tick = 60 * 60
	assert_bool(ai._wants_spear_from_nowhere(4.0)).is_false()


func test_a_ladder_stood_up_in_the_ring_is_kept_where_its_dive_is_made() -> void:
	# Stood up against the ropes over a man lying there, it was never climbed.
	var at := WrestlerController.upright_ladder_spot(Vector3(0.3, 0.0, -2.4), false)
	var keep := WrestlerController.RING_KEEP_IN - 0.75
	assert_float(absf(at.z)).is_less_equal(keep)
	assert_float(at.x).is_equal_approx(0.3, 0.001)
	# Within reach of the man it was stood up over.
	assert_float(Vector2(at.x - 0.3, at.z + 2.4).length()).is_less(WrestlerController.LADDER_AERIAL_REACH)
	# Outside, it goes where he puts it (the ladder bridge, the floor).
	var floor_at := Vector3(4.2, -1.1, 0.0)
	assert_vector(WrestlerController.upright_ladder_spot(floor_at, true)).is_equal(floor_at)


func test_with_a_ladder_stood_up_by_the_downed_man_he_goes_up_it() -> void:
	var pair := _pair(true)
	var roman := pair[0]
	var cody := pair[1]
	cody.is_ai = false
	var ladder := WeaponStock.of(roman).pull(WeaponCatalog.by_id(&"ladder"))
	ladder.set_up_at(Vector3(0.5, 0.0, -0.6), 0.0, "Ladder_Open")
	cody.global_position = Vector3(0.5, 0.0, -1.7)
	cody.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	cody.fsm.transition_to(WrestlerFSM.State.DOWN)
	roman.global_position = Vector3(-0.8, 0.0, 1.6)
	assert_object(roman.ai._ladder_to_climb()).is_same(ladder)
	var climbed := false
	for i in 300:
		await get_tree().physics_frame
		if cody.fsm.current_state != WrestlerFSM.State.DOWN:
			cody.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
			cody.fsm.transition_to(WrestlerFSM.State.DOWN)
		if roman.fsm.current_state == WrestlerFSM.State.LADDER_CLIMB:
			climbed = true
			break
	assert_bool(climbed).override_failure_message("never went up the ladder; at %s in %s" % [
			roman.global_position, WrestlerFSM.State.keys()[roman.fsm.current_state]]).is_true()


func test_a_ladder_in_the_ring_is_climbed_from_the_middle_of_the_ring() -> void:
	var spot := Vector3(-1.8, 0.0, 0.9)
	var yaw := WrestlerController.upright_ladder_yaw(spot, 0.0, false)
	var basis := Basis(Vector3.UP, yaw)
	var mount := spot + basis * Vector3(0.0, 0.0, -WrestlerController.LADDER_FRONT_OFFSET)
	assert_float(Vector2(mount.x, mount.z).length()).is_less(Vector2(spot.x, spot.z).length())
	# Outside it faces the way he set it.
	assert_float(WrestlerController.upright_ladder_yaw(spot, 1.2, true)).is_equal(1.2)
