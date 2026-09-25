extends GdUnitTestSuite
## The comeback: the beaten man fires up and turns the match round (see
## CombatSystem's comeback section and gauntlet/anchor/MATCH_FLOW.md).
##
## What these pin down is the contract of the story beat rather than its
## tuning: who can earn one, that it is once a match, what it does to the man
## who has it and to the man who faces it, and that a knockdown ends it.

func _make_wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	w.fsm = auto_free(WrestlerFSM.new())
	w.combat = CombatSystem.new()
	# In the tree, because a hit reaction shoves him away from the other man
	# and reads both global positions to do it.
	add_child(w)
	return w

func _pair() -> Array[WrestlerController]:
	var a := _make_wrestler()
	var b := _make_wrestler()
	a.opponent = b
	b.opponent = a
	return [a, b]

func _hit_for(damage: float) -> MoveDef:
	var move := MoveDef.new()
	var per_limb := damage / 4.0
	move.damage_head = per_limb
	move.damage_torso = per_limb
	move.damage_arms = per_limb
	move.damage_legs = per_limb
	return move

## Behind by the heat gap, and just hit twice without answering.
func _beaten_down(w: WrestlerController) -> void:
	w.combat.apply_damage(_hit_for(CombatSystem.HEAT_DAMAGE_GAP))
	w.combat.unanswered_hits = CombatSystem.HEAT_UNANSWERED_HITS


# --- earning one ----------------------------------------------------------

func test_two_fresh_men_have_not_earned_a_comeback() -> void:
	var a := CombatSystem.new()
	var b := CombatSystem.new()
	assert_bool(a.earned_comeback(b)).is_false()

func test_a_beating_earns_one() -> void:
	var pair := _pair()
	_beaten_down(pair[0])
	assert_bool(pair[0].combat.earned_comeback(pair[1].combat)).is_true()

## Hits alone are not a beating: two fresh men trading does not qualify.
func test_unanswered_hits_without_a_deficit_do_not_earn_one() -> void:
	var a := CombatSystem.new()
	var b := CombatSystem.new()
	a.unanswered_hits = 10
	assert_bool(a.earned_comeback(b)).is_false()

## And a deficit alone is not the moment: he has to have just been hit.
func test_a_deficit_he_has_answered_does_not_earn_one() -> void:
	var a := CombatSystem.new()
	var b := CombatSystem.new()
	a.apply_damage(_hit_for(CombatSystem.HEAT_DAMAGE_GAP * 2.0))
	a.unanswered_hits = 0
	assert_bool(a.earned_comeback(b)).is_false()

func test_once_a_match() -> void:
	var pair := _pair()
	_beaten_down(pair[0])
	pair[0].fire_up()
	pair[0].combat.comeback_ticks = 0
	_beaten_down(pair[0])
	assert_bool(pair[0].combat.earned_comeback(pair[1].combat)).is_false()
	assert_bool(pair[0].combat.earned_kickout_comeback(pair[1].combat)).is_false()

## The kickout comeback needs the deficit too: a man barely behind who
## survives a cover has not been beaten down.
func test_a_kickout_only_fires_him_up_if_he_is_well_behind() -> void:
	var a := CombatSystem.new()
	var b := CombatSystem.new()
	a.apply_damage(_hit_for(CombatSystem.HEAT_DAMAGE_GAP - 1.0))
	assert_bool(a.earned_kickout_comeback(b)).is_false()
	a.apply_damage(_hit_for(1.0))
	assert_bool(a.earned_kickout_comeback(b)).is_true()


# --- the heat count -------------------------------------------------------

func test_taking_moves_counts_and_answers_the_other_man() -> void:
	var pair := _pair()
	pair[1].combat.unanswered_hits = 3
	pair[0]._took_moves(2)
	assert_int(pair[0].combat.unanswered_hits).is_equal(2)
	assert_int(pair[1].combat.unanswered_hits).is_equal(0)


# --- what it does ---------------------------------------------------------

func test_firing_up_puts_a_signature_within_reach() -> void:
	var pair := _pair()
	pair[0].fire_up()
	assert_bool(pair[0].combat.is_fired_up()).is_true()
	assert_bool(pair[0].combat.can_signature()).is_true()

## The clock only runs while he is on his feet and fighting: MatchReferee
## passes false while he is down or getting up after the kickout.
func test_the_clock_waits_while_he_is_down() -> void:
	var c := CombatSystem.new()
	c.start_comeback()
	c.tick_comeback(false)
	assert_int(c.comeback_ticks).is_equal(CombatSystem.COMEBACK_TICKS)
	c.tick_comeback(true)
	assert_int(c.comeback_ticks).is_equal(CombatSystem.COMEBACK_TICKS - 1)

func test_it_runs_out() -> void:
	var c := CombatSystem.new()
	c.start_comeback()
	for i in CombatSystem.COMEBACK_TICKS:
		c.tick_comeback(true)
	assert_bool(c.is_fired_up()).is_false()

## The no-sell: the damage is real, the flinch is not.
func test_he_shrugs_a_strike_off() -> void:
	var pair := _pair()
	pair[0].fire_up()
	pair[0]._pending_hits.append(_hit_for(8.0))
	pair[0]._resolve_pending_hits()
	assert_float(pair[0].combat.total_damage()).is_equal(8.0)
	assert_int(pair[0].fsm.current_state).is_equal(WrestlerFSM.State.IDLE)

func test_his_strikes_hurt_more() -> void:
	var pair := _pair()
	pair[0].fire_up()
	pair[1]._pending_hits.append(_hit_for(8.0))
	pair[1]._resolve_pending_hits()
	assert_float(pair[1].combat.total_damage()).is_equal(
			8.0 * CombatSystem.COMEBACK_DAMAGE_SCALE)

## The man facing a comeback is rocked into the STUNNED stagger, not the
## ordinary flinch -- that is what lets the run string together.
func test_his_strikes_stagger_the_other_man() -> void:
	var pair := _pair()
	pair[0].fire_up()
	pair[1]._pending_hits.append(_hit_for(8.0))
	pair[1]._resolve_pending_hits()
	assert_int(pair[1].fsm.current_state).is_equal(WrestlerFSM.State.STUNNED)

## STUNNED -> STUNNED is not a legal transition; a second shot while he is
## still staggered takes the ordinary reaction instead of asserting.
func test_a_second_shot_on_a_staggered_man_is_legal() -> void:
	var pair := _pair()
	pair[0].fire_up()
	pair[1]._pending_hits.append(_hit_for(8.0))
	pair[1]._resolve_pending_hits()
	pair[1]._pending_hits.append(_hit_for(8.0))
	pair[1]._resolve_pending_hits()
	assert_int(pair[1].fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)

## Without a comeback, nothing changes: an ordinary hit is an ordinary flinch.
func test_an_ordinary_hit_is_an_ordinary_flinch() -> void:
	var pair := _pair()
	pair[1]._pending_hits.append(_hit_for(8.0))
	pair[1]._resolve_pending_hits()
	assert_float(pair[1].combat.total_damage()).is_equal(8.0)
	assert_int(pair[1].fsm.current_state).is_equal(WrestlerFSM.State.HIT_REACT)

func test_a_knockdown_cuts_it_off() -> void:
	var pair := _pair()
	pair[0].fire_up()
	pair[0]._go_down()
	assert_bool(pair[0].combat.is_fired_up()).is_false()


# --- the lock-up ------------------------------------------------------------

## A fired-up man drives through the lock-up: the other man's presses count
## for nothing while he is not fired up himself.
func test_he_drives_through_the_lock_up() -> void:
	var pair := _pair()
	var referee: MatchReferee = auto_free(MatchReferee.new())
	assert_float(referee._tie_up_weight(pair[1], pair[0])).is_equal(1.0)
	pair[0].fire_up()
	assert_float(referee._tie_up_weight(pair[1], pair[0])).is_equal(0.0)
	assert_float(referee._tie_up_weight(pair[0], pair[1])).is_equal(1.0)
	# Both fired up: an even contest again.
	pair[1].fire_up()
	assert_float(referee._tie_up_weight(pair[1], pair[0])).is_equal(1.0)
