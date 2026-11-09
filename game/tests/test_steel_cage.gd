extends GdUnitTestSuite
## The Steel Cage (gauntlet/refs/steel_cage.md): the cage built round the
## ring, the climb up, over and down, the door, being pulled off, the whip
## into the steel, the rally, and the AI going for it and going after it --
## and none of it in the singles match.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")
const JAB := preload("res://resources/moves/strike_jab.tres")

var _cage: CageBuilder
var _escape: CageEscape


func before_test() -> void:
	_cage = null
	_escape = null


func after_test() -> void:
	for n: Node in [_escape, _cage]:
		if n and is_instance_valid(n):
			n.free()


## A wrestler in a Steel Cage match, standing at `at`, nobody across from him
## (the AI with no target does nothing of its own).
func _wrestler(at: Vector3, caged := true, index := 0) -> WrestlerController:
	var w: WrestlerController = WRESTLER_SCENE.instantiate()
	w.player_index = index
	if caged:
		MatchRules.set_mode(w, MatchRules.Mode.STEEL_CAGE)
	auto_free(w)
	add_child(w)
	w.is_ai = true
	w.global_position = at
	return w


func _build_cage() -> void:
	_cage = CageBuilder.build(self)
	_escape = CageEscape.new()
	_escape.cage = _cage
	add_child(_escape)


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


# --- rules -------------------------------------------------------------------

func test_the_mode_is_a_cage_that_escaping_wins() -> void:
	assert_str(MatchRules.label(MatchRules.Mode.STEEL_CAGE)).is_equal("STEEL CAGE")
	var w := _wrestler(Vector3.ZERO)
	assert_bool(MatchRules.caged(w)).is_true()
	assert_bool(MatchRules.escape_wins(w)).is_true()
	assert_bool(MatchRules.no_holds_barred(w)).is_false()
	var singles := _wrestler(Vector3.ZERO, false, 1)
	assert_bool(MatchRules.caged(singles)).is_false()
	assert_bool(MatchRules.escape_wins(singles)).is_false()
	assert_object(singles.cage_escape()).is_null()


func test_cage_escape_state_leads_only_where_listed() -> void:
	var legal: Array = WrestlerFSM.LEGAL_TRANSITIONS[WrestlerFSM.State.CAGE_ESCAPE]
	assert_array(legal).contains_exactly_in_any_order([WrestlerFSM.State.IDLE,
			WrestlerFSM.State.HIT_REACT, WrestlerFSM.State.LADDER_FALL,
			WrestlerFSM.State.DOWN, WrestlerFSM.State.VICTORY])
	for from: int in [WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
			WrestlerFSM.State.RUN]:
		assert_bool((WrestlerFSM.LEGAL_TRANSITIONS[from] as Array).has(
				WrestlerFSM.State.CAGE_ESCAPE)).is_true()


# --- the cage ----------------------------------------------------------------

func test_the_cage_stands_on_the_apron_edge_with_a_door_and_collision() -> void:
	_build_cage()
	var spec := _cage.spec
	assert_float(spec.half).is_greater(RingBuilder.APRON_OUT)
	assert_float(spec.half).is_less(RingBuilder.APRON_OUT + 0.15)
	# 4.1 m over the apron: about 17 ft over the arena floor.
	assert_float(spec.top_y - WrestlerController.FLOOR_LEVEL).is_between(4.6, 5.6)
	for axis: Vector3 in CageBuilder.axes():
		assert_object(_cage.get_node_or_null("Wall_%s" % _cage._axis_name(axis))).is_not_null()
	var body := _cage.get_node("CageCollision") as StaticBody3D
	assert_int(body.get_child_count()).is_equal(4)
	assert_object(_cage.find_child("DoorPivot", true, false)).is_not_null()
	# The door is in the -X wall, centred, and only there.
	assert_bool(_cage.in_door_lane(Vector3(-2.5, 0, 0.2))).is_true()
	assert_bool(_cage.in_door_lane(Vector3(-2.5, 0, 1.4))).is_false()
	assert_bool(_cage.in_door_lane(Vector3(2.5, 0, 0.2))).is_false()


func test_the_mesh_texture_is_wire_on_clear_and_the_same_every_run() -> void:
	var a := CageBuilder.mesh_texture().get_image()
	var clear := 0
	var wire := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			var alpha := a.get_pixel(x, y).a
			if alpha < 0.05:
				clear += 1
			elif alpha > 0.9:
				wire += 1
	# Mostly open: chain link is wire round holes.
	assert_int(clear).is_greater(wire)
	assert_int(wire).is_greater(0)
	CageBuilder._mesh_texture = null
	var b := CageBuilder.mesh_texture().get_image()
	assert_bool(a.get_data() == b.get_data()).is_true()


func test_the_door_swings_out_of_the_cage() -> void:
	_build_cage()
	var pivot := _cage.find_child("DoorPivot", true, false) as Node3D
	var leaf := pivot.get_child(pivot.get_child_count() - 1) as Node3D
	var shut := leaf.global_position
	_cage.set_door_open(1.0)
	var open := leaf.global_position
	# The free side moves out of the cage (-X), not into the ring.
	assert_float(open.x).is_less(shut.x - 0.3)


# --- climbing out -----------------------------------------------------------

func test_pushing_into_the_cage_climbs_it_instead_of_crossing_the_ropes() -> void:
	_build_cage()
	var w := _wrestler(Vector3(2.5, 0.0, 0.3))
	await _ticks(2)
	assert_bool(w.can_cross_ropes()).is_false()
	assert_bool(_escape.at_wall(w)).is_true()
	assert_bool(_escape.at_door(w)).is_false()
	assert_bool(w._pushing_into_cage({"cage_climb": true})).is_true()
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.CAGE_ESCAPE)
	assert_int(_escape.climb_of(w).route).is_equal(CageEscape.Route.CLIMB)


func test_a_climb_goes_up_over_and_down_and_wins_without_a_jump() -> void:
	_build_cage()
	var w := _wrestler(Vector3(2.5, 0.0, 0.3))
	await _ticks(2)
	var won: Array = []
	_escape.escaped.connect(func(who: WrestlerController) -> void: won.append(who))
	assert_bool(_escape.begin(w)).is_true()
	var last := w.global_position
	var biggest := 0.0
	var biggest_drop := 0.0
	var highest := 0.0
	var phases := {}
	var total := CageEscape.CLIMB_TICKS + CageEscape.OVER_TICKS + CageEscape.DESCEND_TICKS \
			+ CageEscape.DROP_TICKS + 10
	for i in total:
		var c := _escape.climb_of(w)
		var dropping := c != null and c.phase == CageEscape.Phase.DROP
		await _ticks(1)
		var step := w.global_position.distance_to(last)
		if dropping:
			biggest_drop = maxf(biggest_drop, step)
		else:
			biggest = maxf(biggest, step)
		last = w.global_position
		highest = maxf(highest, w.global_position.y)
		c = _escape.climb_of(w)
		if c:
			phases[c.phase] = true
	assert_array(won).contains_exactly([w])
	for p: int in [CageEscape.Phase.CLIMB, CageEscape.Phase.OVER, CageEscape.Phase.DESCEND,
			CageEscape.Phase.DROP]:
		assert_bool(phases.has(p)).override_failure_message("never in phase %d" % p).is_true()
	# Up to straddle the top rail, and down on the floor outside.
	assert_float(highest).is_greater(_cage.spec.top_y - CageEscape.PEAK_BELOW_TOP - 0.05)
	assert_bool(w.outside_ring).is_true()
	assert_float(w.global_position.y).is_equal_approx(WrestlerController.FLOOR_LEVEL, 0.02)
	assert_float(w.global_position.x).is_greater(_cage.spec.half)
	# Never a teleport: on the wall no tick moves his root more than 4 cm, and
	# the drop is no faster than falling from where he lets go.
	assert_float(biggest).is_less(0.04)
	var fall := _cage.spec.base_y + CageEscape.LOW_ABOVE_BASE - WrestlerController.FLOOR_LEVEL
	assert_float(biggest_drop).is_less(sqrt(2.0 * 9.8 * fall) / 60.0 * 1.15)


func test_he_climbs_back_down_when_he_pushes_away() -> void:
	_build_cage()
	var w := _wrestler(Vector3(2.5, 0.0, 0.3))
	w.is_ai = false
	await _ticks(2)
	assert_bool(_escape.begin(w)).is_true()
	for i in 60:
		_escape.tick(w, {})
	assert_float(w.global_position.y).is_greater(0.3)
	for i in 40:
		_escape.tick(w, {"move": Vector2(-1.0, 0.0)})
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
	assert_float(w.global_position.y).is_equal_approx(0.0, 0.01)
	assert_object(_escape.climb_of(w)).is_null()


func test_a_man_climbing_after_him_pulls_him_off_into_the_ring() -> void:
	_build_cage()
	var climber := _wrestler(Vector3(2.5, 0.0, 0.3), true, 0)
	var chaser := _wrestler(Vector3(2.5, 0.0, 1.1), true, 1)
	await _ticks(2)
	assert_bool(_escape.begin(climber)).is_true()
	await _ticks(150)
	var health := climber.combat.health()
	var pulled: Array = []
	_escape.pulled_off.connect(func(c: WrestlerController, by: WrestlerController) -> void:
		pulled.append([c, by]))
	assert_bool(_escape.begin(chaser)).is_true()
	assert_int(_escape.climb_of(chaser).route).is_equal(CageEscape.Route.CHASE)
	# He falls back into the ring and is down on the canvas, inside the ropes.
	var went_down := false
	for i in CageEscape.CHASE_TICKS + 90:
		await _ticks(1)
		if climber.fsm.current_state == WrestlerFSM.State.DOWN:
			went_down = true
			break
	assert_int(pulled.size()).is_equal(1)
	assert_object(pulled[0][1]).is_equal(chaser)
	assert_float(climber.combat.health()).is_less(health)
	assert_bool(went_down).is_true()
	assert_float(climber.global_position.y).is_equal_approx(0.0, 0.05)
	assert_float(climber.global_position.x).is_less_equal(WrestlerController.RING_KEEP_IN + 0.01)
	assert_bool(climber.outside_ring).is_false()
	# And the man who pulled him off climbs back down.
	await _ticks(CageEscape.BACK_DOWN_TICKS + 5)
	assert_int(chaser.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
	assert_float(chaser.global_position.y).is_equal_approx(0.0, 0.02)


func test_past_the_top_he_cannot_be_stopped() -> void:
	_build_cage()
	var climber := _wrestler(Vector3(2.5, 0.0, 0.3), true, 0)
	var chaser := _wrestler(Vector3(2.5, 0.0, 1.1), true, 1)
	await _ticks(2)
	assert_bool(_escape.begin(climber)).is_true()
	await _ticks(CageEscape.CLIMB_TICKS + int(CageEscape.OVER_TICKS * CageEscape.OVER_SAFE) + 4)
	assert_bool(_escape.is_stoppable(climber)).is_false()
	# Pushing into the wall now is a climb of his own, not a chase.
	assert_bool(_escape.begin(chaser)).is_true()
	assert_int(_escape.climb_of(chaser).route).is_not_equal(CageEscape.Route.CHASE)


func test_a_blow_on_a_low_climber_knocks_him_off() -> void:
	_build_cage()
	var w := _wrestler(Vector3(2.5, 0.0, 0.3))
	await _ticks(2)
	assert_bool(_escape.begin(w)).is_true()
	await _ticks(20)
	w._pending_hits.append(JAB)
	w._resolve_pending_hits()
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.LADDER_FALL)
	assert_object(_escape.climb_of(w)).is_null()
	var went_down := false
	for i in 60:
		await _ticks(1)
		went_down = went_down or w.fsm.current_state == WrestlerFSM.State.DOWN
	assert_bool(went_down).is_true()


func test_pulled_off_the_top_he_stays_down_like_off_a_signature() -> void:
	_build_cage()
	var climber := _wrestler(Vector3(2.5, 0.0, 0.3), true, 0)
	var chaser := _wrestler(Vector3(2.5, 0.0, 1.1), true, 1)
	await _ticks(2)
	assert_bool(_escape.begin(climber)).is_true()
	await _ticks(CageEscape.CLIMB_TICKS + 20)
	assert_float(climber.global_position.y).is_greater(CageEscape.HIGH_FALL)
	assert_bool(_escape.begin(chaser)).is_true()
	for i in CageEscape.CHASE_TICKS + 80:
		await _ticks(1)
		if climber.fsm.current_state == WrestlerFSM.State.DOWN:
			break
	assert_int(climber.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_int(climber.knockdown_tier).is_equal(CombatSystem.Tier.SIGNATURE)


# --- the door ---------------------------------------------------------------

func test_the_door_opens_and_he_walks_out_through_it() -> void:
	_build_cage()
	var w := _wrestler(Vector3(-2.5, 0.0, 0.1))
	await _ticks(2)
	var won: Array = []
	_escape.escaped.connect(func(who: WrestlerController) -> void: won.append(who))
	assert_bool(_escape.at_door(w)).is_true()
	assert_bool(_escape.begin(w)).is_true()
	assert_int(_escape.climb_of(w).route).is_equal(CageEscape.Route.DOOR)
	await _ticks(CageEscape.DOOR_UNLOCK_TICKS - 5)
	assert_float(_cage.door_open_amount()).is_equal(0.0)
	await _ticks(CageEscape.DOOR_OPEN_TICKS - CageEscape.DOOR_UNLOCK_TICKS + 5)
	assert_float(_cage.door_open_amount()).is_greater(0.95)
	assert_bool(_escape.is_stoppable(w)).is_false()
	await _ticks(WrestlerController.RING_EXIT_TICKS + 5)
	assert_array(won).contains_exactly([w])
	assert_bool(w.outside_ring).is_true()
	assert_float(w.global_position.x).is_less(-_cage.spec.half)
	assert_float(absf(w.global_position.z)).is_less(_cage.spec.door_width * 0.5)


func test_a_blow_at_the_door_stops_him_and_the_door_shuts() -> void:
	_build_cage()
	var w := _wrestler(Vector3(-2.5, 0.0, 0.1))
	await _ticks(2)
	assert_bool(_escape.begin(w)).is_true()
	await _ticks(CageEscape.DOOR_UNLOCK_TICKS + 60)
	assert_float(_cage.door_open_amount()).is_greater(0.0)
	w._pending_hits.append(JAB)
	w._resolve_pending_hits()
	assert_int(w.fsm.current_state).is_not_equal(WrestlerFSM.State.CAGE_ESCAPE)
	assert_object(_escape.climb_of(w)).is_null()
	await _ticks(60)
	assert_float(_cage.door_open_amount()).is_equal(0.0)
	assert_bool(w.outside_ring).is_false()


# --- the steel as a weapon --------------------------------------------------

func test_whipped_into_the_cage_he_hits_the_steel_and_goes_down() -> void:
	_build_cage()
	var a := _wrestler(Vector3(0.0, 0.0, 0.0), true, 0)
	var b := _wrestler(Vector3(1.0, 0.0, 0.0), true, 1)
	await _ticks(2)
	var rams: Array = []
	b.hit_the_cage.connect(func(who: WrestlerController, _s: float) -> void: rams.append(who))
	var health := b.combat.health()
	b._irish_whip_target = a
	b._irish_whip_rebounded = false
	b._irish_whip_cage = true
	b.velocity = Vector3(WrestlerController.IRISH_WHIP_LAUNCH_SPEED, 0.0, 0.0)
	b._irish_whip_launch_velocity = b.velocity
	b.fsm.transition_to(WrestlerFSM.State.IRISH_WHIP)
	for i in 90:
		await _ticks(1)
		if b.fsm.current_state == WrestlerFSM.State.DOWN:
			break
	assert_int(b.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	assert_array(rams).contains_exactly([b])
	assert_float(b.combat.health()).is_less(health)
	assert_bool(b.rope_running).is_false()


func test_only_a_caged_whip_goes_into_the_steel() -> void:
	var w := _wrestler(Vector3.ZERO)
	assert_bool(w._wants_cage_ram({"cage": true}, false)).is_true()
	assert_bool(w._wants_cage_ram({"cage": true}, true)).is_false()
	var singles := _wrestler(Vector3.ZERO, false, 1)
	assert_bool(singles._wants_cage_ram({"cage": true}, false)).is_false()


# --- the rally and the AI ---------------------------------------------------

func _put_down(w: WrestlerController, tier: int, ticks: int) -> void:
	w.fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	w.fsm.transition_to(WrestlerFSM.State.DOWN)
	w.knockdown_tier = tier
	w._move_ticks_remaining = ticks


func test_off_a_signature_he_rallies_and_off_a_finisher_he_does_not() -> void:
	_build_cage()
	var climber := _wrestler(Vector3(2.5, 0.0, 0.3), true, 0)
	var down := _wrestler(Vector3(-1.0, 0.0, 0.0), true, 1)
	climber.is_ai = false
	down.opponent = climber
	climber.opponent = down
	await _ticks(2)
	_put_down(down, CombatSystem.Tier.SIGNATURE, 540)
	assert_bool(_escape.begin(climber)).is_true()
	await _ticks(CageEscape.RALLY_CAP_TICKS / CageEscape.RALLY_RATE + 4)
	assert_int(down.fsm.current_state).is_equal(WrestlerFSM.State.GETUP)
	# The rise off a rally is the quick one.
	assert_bool(down._rose_staged).is_false()

	_escape.forget(climber)
	climber.end_cage_escape(false)
	await _ticks(WrestlerController.GETUP_RISE_FAST_TICKS + 4)
	_put_down(down, CombatSystem.Tier.FINISHER, 780)
	climber.global_position = Vector3(2.5, 0.0, 0.3)
	await _ticks(1)
	assert_bool(_escape.begin(climber)).is_true()
	await _ticks(200)
	assert_int(down.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)


func _ai_pair() -> Array[WrestlerController]:
	var a := _wrestler(Vector3(1.6, 0.0, 0.4), true, 0)
	var b := _wrestler(Vector3(0.6, 0.0, 0.4), true, 1)
	a.display_name = "ROMAN REIGNS"
	b.display_name = "CODY RHODES"
	a.opponent = b
	b.opponent = a
	for w: WrestlerController in [a, b]:
		w.ai.target = w.opponent
		w.ai.setup_jitter(5, w.player_index)
	return [a, b]


func test_the_ai_goes_for_the_cage_off_a_finisher() -> void:
	_build_cage()
	var pair := _ai_pair()
	var a := pair[0]
	var b := pair[1]
	await _ticks(2)
	_put_down(b, CombatSystem.Tier.FINISHER, 780)
	b.set_physics_process(false)
	var started: Array = []
	_escape.attempt_started.connect(func(who: WrestlerController, route: int) -> void:
		started.append([who, route]))
	for i in 200:
		await _ticks(1)
		if not started.is_empty():
			break
	assert_int(started.size()).is_equal(1)
	assert_object(started[0][0]).is_equal(a)
	assert_int(a.fsm.current_state).is_equal(WrestlerFSM.State.CAGE_ESCAPE)
	assert_int(a.ai.cage_attempts).is_equal(1)


func test_the_ai_climbs_after_a_man_getting_out() -> void:
	_build_cage()
	var pair := _ai_pair()
	var a := pair[0]
	var b := pair[1]
	a.global_position = Vector3(2.5, 0.0, 0.3)
	b.global_position = Vector3(0.5, 0.0, 1.0)
	a.ai.set_physics_process(false)
	a.is_ai = false
	await _ticks(2)
	assert_bool(_escape.begin(a)).is_true()
	var pulled: Array = []
	_escape.pulled_off.connect(func(c: WrestlerController, by: WrestlerController) -> void:
		pulled.append(by))
	for i in CageEscape.CLIMB_TICKS + CageEscape.OVER_TICKS:
		await _ticks(1)
		if not pulled.is_empty():
			break
	assert_array(pulled).contains_exactly([b])


func test_singles_has_no_cage() -> void:
	var w := _wrestler(Vector3(2.5, 0.0, 0.3), false)
	await _ticks(2)
	assert_bool(w._pushing_into_cage({"cage_climb": true})).is_false()
	assert_int(w.fsm.current_state).is_not_equal(WrestlerFSM.State.CAGE_ESCAPE)
