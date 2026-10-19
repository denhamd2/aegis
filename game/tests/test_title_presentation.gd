extends GdUnitTestSuite
## The AEW title (TitlePresentation): on the timekeeper's table from the
## start, not on Roman's waist, and after the match carried table ->
## timekeeper -> Aubrey -> the winner, in a hand or on the table at every
## tick, never popping. Stepped by hand at 60 Hz, as test_prop_handoff is.

const MATCH := "res://scenes/match.tscn"
const DT := 1.0 / 60.0
const MAX_STEP := 0.20


func _match() -> Dictionary:
	var scene: Node = load(MATCH).instantiate()
	add_child(scene)
	auto_free(scene)
	return {"scene": scene, "ref": scene.get_node("RefereeActor"),
			"keeper": scene.get_node("Timekeeper"), "title": TitlePresentation.of(scene),
			"winner": scene.get_node("WrestlerA"), "loser": scene.get_node("WrestlerB")}


func _step(m: Dictionary) -> void:
	for w: WrestlerController in [m["winner"], m["loser"]]:
		if w.anim_tree:
			w.anim_tree.advance(DT)
		if w.skeleton:
			w.skeleton.force_update_all_bone_transforms()
	(m["ref"] as RefereeActor)._process(DT)
	(m["keeper"] as Timekeeper)._process(DT)
	(m["title"] as TitlePresentation)._process(DT)
	for p: AnimationPlayer in [(m["ref"] as RefereeActor)._player, (m["keeper"] as Timekeeper)._player]:
		if p:
			p.advance(DT)


func test_the_title_waits_on_the_timekeeper_s_table() -> void:
	var m := _match()
	await get_tree().process_frame
	var title: TitlePresentation = m["title"]
	assert_object(title).is_not_null()
	assert_bool(title.on_table()).is_true()
	var p := title.belt.global_position
	assert_float(Vector2(p.x, p.z).distance_to(Vector2(PropHandoff.TABLE_AT.x, PropHandoff.TABLE_AT.z))) \
			.is_less(0.7)
	assert_float(p.y).is_greater(PropHandoff.TABLE_AT.y + Timekeeper.TABLE_SIZE.y - 0.05)


func test_aubrey_presents_it_to_the_winner_hand_to_hand() -> void:
	var m := _match()
	await get_tree().process_frame
	var winner: WrestlerController = m["winner"]
	var title: TitlePresentation = m["title"]
	winner.global_position = Vector3(-0.5, 0.0, 0.3)
	winner.celebrate()
	winner.set_physics_process(false)
	title.present(winner, m["ref"])
	var holders := []
	var worst := 0.0
	var last := title.belt.global_position
	var ticks := 0
	while not title.is_done() and ticks < 60 * 45:
		_step(m)
		ticks += 1
		var h := title.holder()
		if holders.is_empty() or holders[-1] != h:
			holders.append(h)
		var now := title.belt.global_position
		worst = maxf(worst, now.distance_to(last))
		last = now
	assert_bool(title.is_done()).is_true()
	assert_array(holders).is_equal(["table", "keeper", "referee", "winner"])
	assert_float(worst).override_failure_message("the belt jumped %.2f m in a tick" % worst) \
			.is_less(MAX_STEP)
	# not timed out: the whole sequence ran
	assert_float(title._total).is_less(TitlePresentation.MAX_SECONDS)
	# and it is in his hand
	var hand := winner.skeleton.global_transform * winner.skeleton.get_bone_global_pose(
			winner.skeleton.find_bone(winner._skeleton_bone_name("hand_l"))).origin
	assert_float(title.belt.global_position.distance_to(hand)).is_less(0.35)
