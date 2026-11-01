extends GdUnitTestSuite
## Laid out on a table and dived through it (No Holds Barred; the owner,
## 1 Nov: "lay him on the table, then dive off the top rope through him").
## The table lay (GrappleRig.TABLE_LAY) is the body slam's lift with the man
## set down on his back on a table standing in the ring; TopRopeSpot's table
## takes it from there -- the corner, the climb, the moonsault onto him up on
## the table, through it, both to the mat -- and the match covers him.

const MATCH := "res://scenes/match.tscn"
const LAY := preload("res://resources/moves/table_lay.tres")
## Where the table stands: a step off the middle toward the (1, 1) corner,
## in reach of a dive from it, its length along x.
const TABLE_AT := Vector3(0.6, 0.0, 0.9)


func _cody_vs_roman() -> Node:
	var scene: Node = auto_free(load(MATCH).instantiate())
	TitleScreen.configure_match(scene, Roster.by_id("cody"), Roster.by_id("roman"), 1)
	add_child(scene)
	return scene


## The two of them squared up beside the table, in No Holds Barred, with
## the table up: [cody, roman, table].
func _beside_the_table(scene: Node) -> Array:
	var cody := scene.get_node("WrestlerA") as WrestlerController
	var roman := scene.get_node("WrestlerB") as WrestlerController
	(scene.get_node("MatchReferee") as MatchReferee)._tying_up = false
	for w: WrestlerController in [cody, roman]:
		MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
		w.velocity = Vector3.ZERO
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	var table := WeaponStock.of(cody).pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(TABLE_AT, 0.0)
	cody.global_position = TABLE_AT + Vector3(0.4, 0.0, 0.7)
	roman.global_position = TABLE_AT + Vector3(-0.4, 0.0, 0.7)
	return [cody, roman, table]


func test_the_lay_is_a_paired_move_on_the_body_slams_lift() -> void:
	assert_bool(PairedRecipes.RECIPES.has("table_lay")).is_true()
	assert_bool(PairedRecipes.TRAJECTORIES.has("table_lay")).is_true()
	assert_bool(LAY.leaves_defender_down).is_true()
	# the body slam's lift and turn, key for key, to the hang
	var slam: Array = PairedRecipes.TRAJECTORIES["power_bodyslam"]["defender"]["pos"]
	var lay: Array = PairedRecipes.TRAJECTORIES["table_lay"]["defender"]["pos"]
	for i in 5:
		assert_array(lay[i]).is_equal(slam[i])


func test_laid_on_the_table_he_lies_on_its_top_and_cody_goes_up_top() -> void:
	var scene := _cody_vs_roman()
	await await_millis(40)
	var picked := _beside_the_table(scene)
	var cody: WrestlerController = picked[0]
	var roman: WrestlerController = picked[1]
	var table: WeaponActor = picked[2]
	await get_tree().physics_frame
	var rig := scene.get_node("GrappleRig") as GrappleRig
	cody._is_grapple_attacker = true
	roman._is_grapple_attacker = false
	cody.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	roman.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	cody._active_move = LAY
	rig.begin(cody, roman, LAY)
	rig.grapple_finished.connect(cody._on_grapple_finished, CONNECT_ONE_SHOT)
	var top := WrestlerController.table_top_y(table)
	var box := table.global_transform * table.local_bounds()
	var spot: TopRopeSpot = null
	for i in 400:
		await get_tree().physics_frame
		spot = scene.get_node_or_null("TopRopeSpot") as TopRopeSpot
		if spot:
			break
	# the dive through it starts the tick he is down on it
	assert_object(spot).is_not_null()
	assert_object(roman.on_table()).is_same(table)
	assert_bool(table.mode == WeaponActor.Mode.SET_UP).is_true()
	assert_float(roman.global_position.y).is_equal_approx(top, 0.01)
	assert_bool(cody._top_rope_used).is_true()
	# and he stays on its top, on his back over it, while Cody goes up:
	# never a frame dropped to the mat, never a frame floating over it
	for i in 60:
		await get_tree().physics_frame
		var hips := roman._bone_world("pelvis")
		assert_float(hips.y).override_failure_message("tick %d: hips at %.2f, table top %.2f"
				% [i, hips.y, top]).is_between(top + 0.05, top + 0.40)
		assert_bool(hips.x >= box.position.x and hips.x <= box.end.x
				and hips.z >= box.position.z and hips.z <= box.end.z).override_failure_message(
				"tick %d: hips %s off the table %s" % [i, hips, box]).is_true()
	assert_bool(table.mode == WeaponActor.Mode.SET_UP).is_true()


func test_off_the_top_they_go_through_the_table_and_he_is_covered() -> void:
	var scene := _cody_vs_roman()
	await await_millis(40)
	var picked := _beside_the_table(scene)
	var cody: WrestlerController = picked[0]
	var roman: WrestlerController = picked[1]
	var table: WeaponActor = picked[2]
	await get_tree().physics_frame
	var rig := scene.get_node("GrappleRig") as GrappleRig
	var referee := scene.get_node("MatchReferee") as MatchReferee
	cody._is_grapple_attacker = true
	roman._is_grapple_attacker = false
	cody.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	roman.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	cody._active_move = LAY
	rig.begin(cody, roman, LAY)
	rig.grapple_finished.connect(cody._on_grapple_finished, CONNECT_ONE_SHOT)
	var landed := []
	roman.set_piece_landed.connect(func(_who, weapon, broke): landed.append([weapon, broke]))
	var spot: TopRopeSpot = null
	for i in 400:
		await get_tree().physics_frame
		spot = scene.get_node_or_null("TopRopeSpot") as TopRopeSpot
		if spot:
			break
	assert_object(spot).is_not_null()
	var hp := roman.combat.health()
	var cody_hp := cody.combat.health()
	var finished := [false]
	spot.finished.connect(func() -> void: finished[0] = true)
	for i in 900:
		await get_tree().physics_frame
		if finished[0]:
			break
	assert_bool(finished[0]).is_true()
	# through it: broken under him, once
	assert_array(landed).is_equal([[table, true]])
	assert_bool(table.mode == WeaponActor.Mode.SET_UP).is_false()
	assert_object(roman.on_table()).is_null()
	# both on the mat, him hurt by the dive and the table, Cody by the table
	assert_float(roman.global_position.y).is_equal_approx(0.0, 0.05)
	assert_float(roman.combat.health()).is_less(hp)
	assert_float(cody.combat.health()).is_less(cody_hp)
	# and covered where they came down
	assert_bool(roman.fsm.is_in([WrestlerFSM.State.DOWN, WrestlerFSM.State.PIN_DEFENDER])).is_true()
	assert_bool(referee._pinning).is_true()


func test_a_man_with_a_dive_off_the_top_lines_up_the_lay() -> void:
	var scene := _cody_vs_roman()
	await await_millis(40)
	var picked := _beside_the_table(scene)
	var cody: WrestlerController = picked[0]
	var roman: WrestlerController = picked[1]
	var table: WeaponActor = picked[2]
	await get_tree().physics_frame
	for w: WrestlerController in [cody, roman]:
		w.combat.tier_reached = 0
		w.velocity = Vector3.ZERO
	cody.ai._lay_rolls[table.get_instance_id()] = true
	assert_bool(cody.ai._wants_table_lay(table)).is_true()
	# where it starts, as the rig will stand it: beside the table's long side
	var lay := load(WrestlerAI.TABLE_LAY_MOVE) as MoveDef
	var start := cody.ai._lay_frame(table, lay) * Vector3(0.40, 0.0, 0.0)
	assert_float(absf(start.z - TABLE_AT.z)).is_between(0.55, 0.85)
	# on it, Roman in reach: he locks up for the lay
	cody.global_position = start
	roman.global_position = start + (Vector3(-0.8, 0.0, 0.0) if start.x > TABLE_AT.x else Vector3(0.8, 0.0, 0.0))
	var to := roman.global_position - cody.global_position
	var input: Dictionary = cody.ai._line_up_input({}, to, Vector2(to.x, to.z).length())
	assert_bool(input.get("grapple", false)).is_true()
	assert_object(cody.prefer_hold_move).is_same(lay)
	# Roman has no dive off the top: never the lay
	roman.ai._lay_rolls[table.get_instance_id()] = true
	assert_bool(roman.ai._wants_table_lay(table)).is_false()
	# nor Cody once his dive off the top is spent
	cody._top_rope_used = true
	assert_bool(cody.ai._wants_table_lay(table)).is_false()
