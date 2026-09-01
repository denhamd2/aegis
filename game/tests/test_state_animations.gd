extends GdUnitTestSuite
## WrestlerController.STATE_ANIMATIONS -- guards the FSM-state -> clip-name
## table against the base mesh's actual AnimationPlayer.
##
## _build_animation_tree() skips a clip name it can't find with a bare
## `continue`, so a typo'd or renamed clip silently removes that state from
## the blend graph rather than failing. That failure mode is invisible in a
## headless "does the match complete" check -- the FSM still transitions
## fine, the wrestler just stops being animated -- and it shipped: the table
## asked for "Idle"/"Walk"/"Sprint"/"Push"/"Crouch_Idle" while the CC0 rig
## (assets/characters/wrestler_base.glb) names those clips "Idle_Loop",
## "Walk_Loop", "Sprint_Loop", "Push_Loop" and "Crouch_Idle_Loop". IDLE,
## LOCOMOTION and RUN therefore had no node at all, so a standing/walking/
## running wrestler held its previous pose (bind pose at match start) for
## most of the match's runtime.
##
## This suite is the regression guard for that: it asserts against the real
## imported AnimationPlayer, so renaming a clip in the .glb breaks a test
## instead of quietly de-animating a state.

const WRESTLER_SCENE := preload("res://scenes/wrestler.tscn")

## Instantiating the scene (rather than WrestlerController.new()) is what
## brings in the .glb's AnimationPlayer -- the clip names only exist on the
## imported mesh, not on the script.
func _make_wrestler() -> WrestlerController:
	var wrestler: WrestlerController = auto_free(WRESTLER_SCENE.instantiate())
	add_child(wrestler)
	return wrestler

func test_every_state_animation_exists_on_the_rig() -> void:
	var wrestler := _make_wrestler()
	var player := wrestler.anim_player
	assert_object(player).is_not_null()

	var missing: Array[String] = []
	for state_id in WrestlerController.STATE_ANIMATIONS:
		var clip_name: String = WrestlerController.STATE_ANIMATIONS[state_id]
		if not player.has_animation(clip_name):
			missing.append("%s -> %s" % [WrestlerFSM.State.keys()[state_id], clip_name])

	assert_array(missing).override_failure_message(
		"STATE_ANIMATIONS names clips that don't exist on the rig: %s" % [missing]
	).is_empty()

## Every state with a clip must end up as a real node in the blend graph --
## the table being correct is only half of it, the tree has to actually be
## built from it.
func test_blend_graph_has_a_node_for_every_mapped_state() -> void:
	var wrestler := _make_wrestler()
	assert_object(wrestler.anim_tree).is_not_null()
	var state_machine := wrestler.anim_tree.tree_root as AnimationNodeStateMachine
	assert_object(state_machine).is_not_null()

	var missing: Array[String] = []
	for state_id in WrestlerController.STATE_ANIMATIONS:
		var state_name: String = WrestlerFSM.State.keys()[state_id]
		if not state_machine.has_node(state_name):
			missing.append(state_name)

	assert_array(missing).override_failure_message(
		"States mapped in STATE_ANIMATIONS but absent from the blend graph: %s" % [missing]
	).is_empty()

## IDLE specifically has to exist: _build_animation_tree() only calls
## playback.start() when it does, so losing IDLE means the tree never starts
## at all and *no* state animates until something else travels into it.
## start() only queues the node -- the tree has to actually process a physics
## frame (anim_tree runs on ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS) before
## get_current_node() reports it rather than the implicit "Start".
func test_playback_starts_in_idle() -> void:
	var wrestler := _make_wrestler()
	await await_millis(50)
	var playback: AnimationNodeStateMachinePlayback = wrestler.anim_tree["parameters/playback"]
	assert_str(playback.get_current_node()).is_equal(
		WrestlerFSM.State.keys()[WrestlerFSM.State.IDLE]
	)
