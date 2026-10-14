extends GdUnitTestSuite
## A landed handgun hit is fatal, leaves no recoverable health, and cannot be
## recovered from through the ordinary DOWN timer.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")


func _wrestler() -> WrestlerController:
	var w: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	w.character_model_scene = load("res://scenes/kenny_model.tscn")
	add_child(w)
	await get_tree().physics_frame
	await get_tree().process_frame
	return w


func test_handgun_hit_drains_health_and_keeps_him_down() -> void:
	var victim := await _wrestler()
	victim._pending_hits.append(WeaponCatalog.swing_move(WeaponCatalog.by_id(&"handgun")))
	victim._resolve_pending_hits()

	assert_bool(victim.dead).is_true()
	assert_float(victim.combat.health()).is_equal(0.0)
	assert_float(victim.combat.green).is_equal(0.0)
	assert_int(victim.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
	for i in 600:
		victim.combat.tick_recovery()
		victim._process_down({})
	assert_float(victim.combat.health()).is_equal(0.0)
	assert_int(victim.fsm.current_state).is_equal(WrestlerFSM.State.DOWN)
