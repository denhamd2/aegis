extends GdUnitTestSuite
## A man walking into the other man stops; so do his feet (stage 8 review:
## the walk cycle kept playing while the bodies held him still).

const DT := 1.0 / 60.0


func _scene() -> Node:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	add_child(scene)
	return scene


func test_a_blocked_walker_shows_the_stance_and_walks_again_when_free() -> void:
	var scene := _scene()
	await get_tree().physics_frame
	var w: WrestlerController = scene.get_node("WrestlerA")
	w.is_ai = false
	# Driven by hand: with no input his own tick would stand him in IDLE.
	w.set_physics_process(false)
	w.fsm.transition_to(WrestlerFSM.State.LOCOMOTION)
	w.anim_tree.advance(0.5)
	var here := w.global_position
	# Trying to walk, going nowhere.
	for _i in WrestlerController.BLOCKED_TICKS - 1:
		w._hold_feet_when_blocked(here, DT)
	assert_bool(w.feet_held()).override_failure_message(
			"held before BLOCKED_TICKS: a single stalled tick is not a block").is_false()
	w._hold_feet_when_blocked(here, DT)
	assert_bool(w.feet_held()).is_true()
	w.anim_tree.advance(0.5)
	assert_str(String(w._anim_playback.get_current_node())).is_equal("IDLE")
	# Free again: a full walking step this tick.
	var step := Vector3(WrestlerController.MOVE_SPEED * DT, 0.0, 0.0)
	w._hold_feet_when_blocked(here - step, DT)
	assert_bool(w.feet_held()).is_false()
	w.anim_tree.advance(0.5)
	assert_str(String(w._anim_playback.get_current_node())).is_equal("LOCOMOTION")
	# And it is only ever presentation: the FSM never left LOCOMOTION.
	assert_int(w.fsm.current_state).is_equal(WrestlerFSM.State.LOCOMOTION)
	scene.queue_free()


func test_a_man_walking_freely_keeps_his_walk() -> void:
	var scene := _scene()
	await get_tree().physics_frame
	var w: WrestlerController = scene.get_node("WrestlerA")
	w.is_ai = false
	w.fsm.transition_to(WrestlerFSM.State.LOCOMOTION)
	var step := Vector3(0.0, 0.0, WrestlerController.MOVE_SPEED * DT)
	for _i in 30:
		w._hold_feet_when_blocked(w.global_position - step, DT)
	assert_bool(w.feet_held()).is_false()
	scene.queue_free()
