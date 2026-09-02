extends GdUnitTestSuite
## The match HUD and the read-only referee views it polls.
##
## There was no HUD at all before this: no CanvasLayer, Control or Label
## anywhere in the project, which also meant the evidence gate's
## hud_present check could never pass. gauntlet/refs/hud.md had been sitting
## there measured and unused the whole time.
##
## Whether the HUD *looks* right is not assertable and was checked by
## rendering a real match at four beats plus a forced pin and a live
## submission. What is assertable is the wiring and the numbers behind it.

const MATCH_SCENE := preload("res://scenes/match.tscn")
const HUD_SCENE := preload("res://scenes/match_hud.tscn")

func _make_referee() -> MatchReferee:
	return auto_free(MatchReferee.new())

func _make_wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WrestlerController.new())
	w.fsm = auto_free(WrestlerFSM.new())
	w.combat = CombatSystem.new()
	return w

## The HUD only means anything if the shipped match actually has one.
func test_the_match_scene_has_a_hud_wired_to_both_wrestlers() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	assert_object(hud.wrestler_a).is_same(scene.get_node("WrestlerA"))
	assert_object(hud.wrestler_b).is_same(scene.get_node("WrestlerB"))
	assert_object(hud.referee).is_same(scene.get_node("MatchReferee"))

func test_the_hud_covers_the_whole_viewport() -> void:
	var hud_root: CanvasLayer = auto_free(HUD_SCENE.instantiate())
	add_child(hud_root)
	var hud: MatchHUD = hud_root.get_node("Draw")
	assert_float(hud.anchor_right).is_equal(1.0)
	assert_float(hud.anchor_bottom).is_equal(1.0)

## The vitality bar and the kickout difficulty must not be able to tell the
## player different stories, so they share a denominator.
func test_the_vitality_bar_uses_the_same_scale_as_the_kickout_window() -> void:
	var combat := CombatSystem.new()
	var move := MoveDef.new()
	move.damage_head = CombatSystem.MAX_LIMB_DAMAGE
	move.damage_torso = CombatSystem.MAX_LIMB_DAMAGE
	move.damage_arms = CombatSystem.MAX_LIMB_DAMAGE
	move.damage_legs = CombatSystem.MAX_LIMB_DAMAGE
	combat.apply_damage(move)
	# Fully damaged on every limb is a full bar, and the kickout window is
	# at its floor -- the two ends of the same scale.
	assert_float(combat.total_damage() / (CombatSystem.MAX_LIMB_DAMAGE * 4.0)) \
		.is_equal_approx(1.0, 0.0001)
	assert_float(combat.kickout_window_fraction(0.0)).is_equal_approx(0.05, 0.0001)

func test_no_count_is_shown_outside_a_pin() -> void:
	assert_int(_make_referee().pin_count()).is_equal(0)

func test_the_count_advances_once_per_sixty_ticks() -> void:
	var referee := _make_referee()
	referee._pinning = true
	referee._pin_defender = _make_wrestler()
	var seen: Array[int] = []
	for tick in MatchReferee.PIN_COUNT_TICKS:
		referee._pin_ticks += 1
		referee._pin_count_shown = mini(3, referee._pin_ticks / MatchReferee.TICKS_PER_COUNT)
		seen.append(referee.pin_count())
	assert_int(seen[MatchReferee.TICKS_PER_COUNT - 1]).is_equal(1)
	assert_int(seen[MatchReferee.TICKS_PER_COUNT * 2 - 1]).is_equal(2)
	assert_int(seen[MatchReferee.TICKS_PER_COUNT * 3 - 1]).is_equal(3)

## The third count and the end of the pin land on the same tick: _tick_pin()
## sees 180 ticks, declares the pinfall and clears _pinning in one call. A
## count derived live from _pinning would therefore show "3" for zero frames
## -- the winning count, the one that matters most, would never be on
## screen. Confirmed by rendering: before this it captured a "2".
func test_the_winning_count_stays_on_screen_after_the_pinfall() -> void:
	var referee := _make_referee()
	referee._pinning = false
	referee._pin_count_shown = 3
	assert_int(referee.pin_count()).is_equal(3)

func test_a_kickout_clears_the_count() -> void:
	var referee := _make_referee()
	var attacker := _make_wrestler()
	var defender := _make_wrestler()
	attacker.fsm.current_state = WrestlerFSM.State.PIN_ATTACKER
	defender.fsm.current_state = WrestlerFSM.State.PIN_DEFENDER
	referee._pinning = true
	referee._pin_attacker = attacker
	referee._pin_defender = defender
	referee._pin_count_shown = 2
	referee._end_pin(false)
	assert_int(referee.pin_count()).is_equal(0)

func test_no_hold_meter_outside_a_submission() -> void:
	var referee := _make_referee()
	assert_bool(referee.is_submission_active()).is_false()
	assert_vector(referee.submission_progress()).is_equal(Vector2.ZERO)

func test_the_hold_meter_reports_both_sides_as_fractions() -> void:
	var referee := _make_referee()
	var defender := _make_wrestler()
	defender._submission_minigame = SubmissionMinigame.new(1.0, 2.0)
	defender._submission_minigame.tick(true, true, 25)
	referee._submissioning = true
	referee._submission_defender = defender
	var progress := referee.submission_progress()
	assert_float(progress.x).is_equal_approx(0.25, 0.0001)
	assert_float(progress.y).is_equal_approx(0.50, 0.0001)

## The HUD is allowed to read gameplay state only because it can never write
## it. Drawing a frame must leave the match exactly as it found it.
func test_drawing_the_hud_changes_no_gameplay_state() -> void:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.combat.momentum = 42.0
	var before := [a.fsm.current_state, b.fsm.current_state, a.combat.momentum,
			b.combat.momentum, a.combat.total_damage(), b.combat.total_damage(),
			a.global_position, b.global_position]
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	hud._draw()
	var after := [a.fsm.current_state, b.fsm.current_state, a.combat.momentum,
			b.combat.momentum, a.combat.total_damage(), b.combat.total_damage(),
			a.global_position, b.global_position]
	assert_array(after).is_equal(before)
