extends GdUnitTestSuite
## The Guillotine ends with the man on the mat, not hoisted over it.
##
## Stage 8 review: Cody, guillotined, lay folded with his legs flung up. Three
## things lifted him, each measured with the move run through the real
## GrappleRig: Roman's root was keyed so he sat back INTO the man (his body lay
## through Roman's lap by ~0.6 m, and the separation pushed him up and clear);
## the contact pull kept drawing a man on the canvas up toward Roman's arm; and
## Roman's grip IK held the head after the clip had let go of it. His pelvis
## sat at waist height (0.8 m) when he should have been face down on the mat.


func _run_guillotine() -> Array:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var d: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, d]:
		w.is_ai = false
		w.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var move: MoveDef = load("res://resources/moves/grapple_guillotine.tres")
	d.global_position = a.global_position - a.global_transform.basis.z * 0.9
	a.look_at(d.global_position, Vector3.UP)
	d.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame
	var rig: GrappleRig = scene.get_node("GrappleRig")
	a._is_grapple_attacker = true
	d._is_grapple_attacker = false
	a.opponent = d
	d.opponent = a
	a.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	d.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	rig.begin(a, d, move)
	# [clip time, defender pelvis height over the mat, attacker gripping]
	var samples := []
	var sk := d.skeleton
	var pelvis := sk.find_bone(d._skeleton_bone_name("pelvis"))
	var ticks := 0
	while rig.is_active() and ticks < 400:
		await get_tree().physics_frame
		ticks += 1
		var player := rig.animation_player
		if player == null or not player.is_playing():
			continue
		var at := sk.global_transform * sk.get_bone_global_pose(pelvis).origin
		samples.append([player.current_animation_position, at.y - d.global_position.y,
				a._is_gripping_state()])
	scene.queue_free()
	await get_tree().process_frame
	return samples


func test_the_guillotined_man_lies_on_the_mat_and_roman_lets_go() -> void:
	var samples: Array = await _run_guillotine()
	assert_int(samples.size()).is_greater(60)
	var after := 0
	var highest := 0.0
	var held_late := false
	for s: Array in samples:
		# Face down by frame 37 of 62 (1.23 s): from 1.35 s on he is lying.
		if float(s[0]) >= 1.35:
			after += 1
			highest = maxf(highest, float(s[1]))
		# Roman lets go as he lands sitting (attacker_grips_until 0.55).
		if float(s[0]) >= 1.25 and s[2]:
			held_late = true
	assert_int(after).is_greater(20)
	# Lying is ~0.2; the hoisted man was 0.8. Head room for the roll.
	assert_float(highest).override_failure_message(
			"the guillotined man's pelvis rose to %.2f m off the mat" % highest) \
			.is_less(0.45)
	assert_bool(held_late).override_failure_message(
			"Roman's grip still held the man's head after the clip let go") \
			.is_false()
