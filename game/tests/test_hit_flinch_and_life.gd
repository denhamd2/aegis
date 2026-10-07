extends GdUnitTestSuite
## Phase 3's hit reactions and in-between life (HitFlinch, hit-stop,
## BodyLife) and the Inertializer's facing turn: the numbers they are built
## on.


func test_a_flinch_peaks_fast_rebounds_once_and_settles() -> void:
	assert_float(HitFlinch.envelope(0.0)).is_equal(0.0)
	assert_float(HitFlinch.envelope(HitFlinch.ATTACK_TICKS)).is_equal_approx(1.0, 1e-5)
	# Springs back past rest, softly.
	var lowest := 0.0
	for t in range(3, 40):
		lowest = minf(lowest, HitFlinch.envelope(float(t)))
	assert_float(lowest).is_between(-0.4, -0.02)
	var settle := HitFlinch.ATTACK_TICKS + HitFlinch.SETTLE_TICKS * 6.0
	assert_float(absf(HitFlinch.envelope(settle))).is_less(0.01)


func test_a_blow_lands_where_its_damage_does() -> void:
	var head := MoveDef.new()
	head.damage_head = 7.0
	head.damage_torso = 2.0
	var body := MoveDef.new()
	body.damage_torso = 6.0
	body.damage_legs = 3.0
	var legs := MoveDef.new()
	legs.damage_legs = 6.0
	legs.damage_torso = 1.0
	assert_str(HitFlinch.zone_of(head)).is_equal("head")
	assert_str(HitFlinch.zone_of(body)).is_equal("body")
	assert_str(HitFlinch.zone_of(legs)).is_equal("legs")


## Only the biggest blows stop the picture: an ordinary punch or kick never
## freezes it (the stutter the owner saw), a signature does, briefly.
func test_only_the_biggest_blows_stop_the_clips() -> void:
	for path in ["strike_jab", "strike_cross", "strike_kick"]:
		var move: MoveDef = load("res://resources/moves/%s.tres" % path)
		assert_int(WrestlerController.hit_stop_ticks_for(HitFlinch.strength_of(move))) \
				.override_failure_message("%s freezes the picture" % path).is_equal(0)
	var superman: MoveDef = load("res://resources/moves/signature_superman_punch.tres")
	assert_int(WrestlerController.hit_stop_ticks_for(HitFlinch.strength_of(superman))) \
			.is_equal(WrestlerController.HIT_STOP_HEAVY)
	assert_int(WrestlerController.HIT_STOP_HEAVY).is_less_equal(2)


func test_fatigue_runs_from_fresh_to_spent_on_sweats_scale() -> void:
	assert_float(BodyLife.fatigue_of(0.0)).is_equal(0.0)
	assert_float(BodyLife.fatigue_of(80.0)).is_equal_approx(0.5, 1e-5)
	assert_float(BodyLife.fatigue_of(1000.0)).is_equal(1.0)
	assert_float(BodyLife.DAMAGE_FULL).is_equal(Sweat.DAMAGE_FULL)


func test_a_bigger_snap_takes_longer_to_turn_out() -> void:
	assert_float(Inertializer.turn_ticks(PI)).is_equal_approx(14.0, 1e-4)
	assert_float(Inertializer.turn_ticks(0.3)).is_less(Inertializer.turn_ticks(PI))


func test_a_fidget_eases_in_and_out_and_starts_and_ends_at_rest() -> void:
	assert_float(BodyLife.fidget_curve(0.0)).is_equal_approx(0.0, 1e-6)
	assert_float(BodyLife.fidget_curve(0.5)).is_equal_approx(1.0, 1e-6)
	assert_float(BodyLife.fidget_curve(1.0)).is_equal_approx(0.0, 1e-6)
	# No slope at either end: it does not jolt in or out.
	assert_float(BodyLife.fidget_curve(0.01)).is_less(0.002)
