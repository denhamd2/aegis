extends GdUnitTestSuite
## Knockdown used to be `combat.total_damage() >= KNOCKDOWN_DAMAGE` -- a test
## on a number that only ever rises, so the first crossing latched it true
## for the rest of the match and every later hit, a 4-damage jab included,
## put the man back on the mat.
##
## Measured across five AI-vs-AI seeds before the fix: both wrestlers entered
## GRAPPLE_HOLD exactly three times in every single seed, and the whole late
## match was strike -> knockdown -> cover -> kickout -> getup -> strike. That
## is why the grapple chain this slice is about barely ran -- a match played
## two or three of the eighteen authored paired moves and then stopped
## producing tie-ups at all, because the AI's "opponent is down, walk in"
## branch owns every tick a wrestler spends on the mat.
##
## These are the invariants that make that class of bug -- an event
## expressed as a threshold on a monotone quantity -- fail loudly.

func _make_wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	w.fsm = auto_free(WrestlerFSM.new())
	w.combat = CombatSystem.new()
	return w

## Spread over all four limbs because CombatSystem.apply_damage() clamps each
## limb at MAX_LIMB_DAMAGE -- a single-limb hit cannot express the multiples
## of KNOCKDOWN_DAMAGE these cases need.
func _hit_for(damage: float) -> MoveDef:
	var move := MoveDef.new()
	var per_limb := damage / 4.0
	move.damage_head = per_limb
	move.damage_torso = per_limb
	move.damage_arms = per_limb
	move.damage_legs = per_limb
	return move

func test_a_fresh_wrestler_is_not_knocked_down() -> void:
	var w := _make_wrestler()
	assert_bool(w._would_be_knocked_down()).is_false()

func test_crossing_the_threshold_knocks_him_down() -> void:
	var w := _make_wrestler()
	w.combat.apply_damage(_hit_for(WrestlerController.KNOCKDOWN_DAMAGE))
	assert_bool(w._would_be_knocked_down()).is_true()

## The bug in one line: after one knockdown the next jab must not be another
## one. The wrestler is far past KNOCKDOWN_DAMAGE in absolute damage here --
## that is exactly the state the old test latched on.
func test_the_next_jab_after_a_knockdown_is_not_another_knockdown() -> void:
	var w := _make_wrestler()
	w.combat.apply_damage(_hit_for(WrestlerController.KNOCKDOWN_DAMAGE))
	w._go_down()
	w.combat.apply_damage(_hit_for(4.0))
	assert_float(w.combat.total_damage()).is_greater(WrestlerController.KNOCKDOWN_DAMAGE)
	assert_bool(w._would_be_knocked_down()).override_failure_message(
		"A jab after a knockdown knocked him down again, so a match never "
		+ "returns to its feet and the grapple chain stops."
	).is_false()

## He does go down again -- once he has taken another KNOCKDOWN_DAMAGE
## *since* the last one, which is what makes this an event rather than a
## latch.
func test_he_goes_down_again_after_another_full_threshold() -> void:
	var w := _make_wrestler()
	w.combat.apply_damage(_hit_for(WrestlerController.KNOCKDOWN_DAMAGE))
	w._go_down()
	w.combat.apply_damage(_hit_for(WrestlerController.KNOCKDOWN_DAMAGE - 1.0))
	assert_bool(w._would_be_knocked_down()).is_false()
	w.combat.apply_damage(_hit_for(1.0))
	assert_bool(w._would_be_knocked_down()).is_true()

## Damage keeps accumulating across knockdowns -- the reset is on the
## knockdown bookkeeping, not on the damage the pin and submission gates
## read (CombatSystem.KICKOUT_DAMAGE_REFERENCE, SUBMISSION_ESCAPE_LIMB).
func test_a_knockdown_does_not_heal_him() -> void:
	var w := _make_wrestler()
	w.combat.apply_damage(_hit_for(WrestlerController.KNOCKDOWN_DAMAGE))
	w._go_down()
	assert_float(w.combat.total_damage()).is_equal(WrestlerController.KNOCKDOWN_DAMAGE)
