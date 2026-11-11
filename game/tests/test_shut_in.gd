extends GdUnitTestSuite
## The Casket and Ambulance matches (gauntlet/refs/casket_match.md,
## ambulance_match.md): whipped at the open casket (the back of the ambulance)
## he goes in over its side; the lid (the doors) shut on him wins it -- or, a
## near-miss before the finish, he shoves it back and climbs out. No pins.


func _match(mode: int) -> Node:
	var scene: Node = auto_free(load("res://scenes/match.tscn").instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1,
			false, mode)
	for part in ["Arena", "LightRig"]:
		scene.get_node(part).free()
	scene.entrances = false
	add_child(scene)
	return scene


func _ticks(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func test_the_rules() -> void:
	for mode: int in [MatchRules.Mode.CASKET, MatchRules.Mode.AMBULANCE]:
		var n := Node.new()
		MatchRules.set_mode(n, mode)
		assert_bool(MatchRules.pins_count(n)).is_false()
		assert_bool(MatchRules.no_holds_barred(n)).is_true()
		assert_bool(MatchRules.caged(n)).is_false()
		n.free()
	assert_str(MatchRules.label(MatchRules.Mode.CASKET)).is_equal("CASKET")
	assert_str(MatchRules.label(MatchRules.Mode.AMBULANCE)).is_equal("AMBULANCE")


func test_the_casket_stands_at_ringside_open() -> void:
	var scene := _match(MatchRules.Mode.CASKET)
	await _ticks(2)
	var casket := scene.get_node_or_null("Casket") as CasketProp
	assert_object(casket).is_not_null()
	var shut := scene.get_node("ShutIn") as ShutIn
	assert_object(shut.container).is_same(casket)
	assert_float(casket.shut_amount()).is_equal(0.0)
	# On the floor, outside the ring, inside the barricade.
	var m := casket.mouth()
	assert_float(absf(m.x)).is_between(RingBuilder.MAT_HALF, ArenaBuilder.BARRICADE_RADIUS)
	assert_float(casket.global_position.y).is_less(-0.9)


func test_the_ambulance_is_backed_down_the_ramp() -> void:
	var scene := _match(MatchRules.Mode.AMBULANCE)
	await _ticks(2)
	var amb := scene.get_node_or_null("Ambulance") as AmbulanceProp
	assert_object(amb).is_not_null()
	assert_bool(ArenaBuilder.in_entrance_way(amb.mouth()) or amb.mouth().z < -5.5).is_true()
	# Its bed is up in the back, above the ramp.
	assert_float(amb.bed().origin.y).is_greater(amb.mouth().y + 0.6)


func _whip_in(scene: Node, near_miss: bool) -> Array:
	var roman := scene.get_node("WrestlerA") as WrestlerController
	var cody := scene.get_node("WrestlerB") as WrestlerController
	var referee := scene.get_node("MatchReferee") as MatchReferee
	var shut := scene.get_node("ShutIn") as ShutIn
	var won: Array = []
	referee.match_won.connect(func(w: WrestlerController, how: String) -> void: won.append([w, how]))
	for w in [roman, cody]:
		w.is_ai = false
		w.outside_ring = true
	var m: Vector3 = shut.container.mouth()
	cody.global_position = m + Vector3(0.2, 0.0, 0.0)
	roman.global_position = m + Vector3(1.4, 0.0, 0.0)
	await _ticks(1)
	cody._irish_whip_target = roman
	cody._irish_whip_rebounded = false
	cody._irish_whip_shut_in = true
	cody.velocity = (m - cody.global_position).normalized() * 2.0
	cody._irish_whip_launch_velocity = cody.velocity
	cody.fsm.transition_to(WrestlerFSM.State.IRISH_WHIP)
	await _ticks(2)
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.SHUT_IN)
	# The story decides (MatchFlow): forced here, finish or near-miss.
	shut._holds = not near_miss
	for i in 400:
		await _ticks(1)
		if not won.is_empty() or (near_miss and not cody.is_shut_in()):
			break
	return [roman, cody, won, shut]


func test_shut_in_the_casket_he_loses() -> void:
	var scene := _match(MatchRules.Mode.CASKET)
	await _ticks(2)
	var r: Array = await _whip_in(scene, false)
	var won: Array = r[2]
	assert_int(won.size()).is_equal(1)
	assert_object(won[0][0]).is_same(r[0])
	assert_str(won[0][1]).is_equal("casket")
	assert_float((r[3] as ShutIn).container.shut_amount()).is_equal(1.0)
	assert_bool((r[1] as WrestlerController).is_shut_in()).is_true()


func test_a_near_miss_he_shoves_the_lid_back_and_climbs_out() -> void:
	var scene := _match(MatchRules.Mode.CASKET)
	await _ticks(2)
	var r: Array = await _whip_in(scene, true)
	var won: Array = r[2]
	assert_int(won.size()).is_equal(0)
	var cody := r[1] as WrestlerController
	assert_bool(cody.is_shut_in()).is_false()
	assert_int(cody.fsm.current_state).is_equal(WrestlerFSM.State.IDLE)
	assert_float((r[3] as ShutIn).container.shut_amount()).is_less(0.05)
	# Back out on his feet at the mouth.
	var m: Vector3 = (r[3] as ShutIn).container.mouth()
	assert_float(Vector2(cody.global_position.x - m.x, cody.global_position.z - m.z).length()).is_less(0.3)


func test_shut_in_the_ambulance_he_loses() -> void:
	var scene := _match(MatchRules.Mode.AMBULANCE)
	await _ticks(2)
	var r: Array = await _whip_in(scene, false)
	var won: Array = r[2]
	assert_int(won.size()).is_equal(1)
	assert_str(won[0][1]).is_equal("ambulance")
