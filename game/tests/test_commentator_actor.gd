extends GdUnitTestSuite
## The two live broadcast voices occupy real seats at the commentary desk and
## move with the recorded line assigned to their voice.


func test_both_character_models_load_with_animated_pivots() -> void:
	for role in ["tony", "excalibur"]:
		var actor: CommentatorActor = auto_free(CommentatorActor.new())
		add_child(actor)
		assert_bool(actor.setup(role, Vector3.ZERO)).is_true()
		assert_object(actor._head).is_not_null()
		assert_object(actor._spine).is_not_null()
		assert_object(actor._left_arm).is_not_null()
		assert_object(actor._right_arm).is_not_null()
		assert_bool(actor.is_in_group("commentators")).is_true()
		assert_float(actor.rotation.y).is_equal_approx(0.0, 0.001)


func test_recorded_commentary_is_assigned_to_the_correct_voice() -> void:
	assert_str(MatchAudio.commentator_for_event("gunshot")).is_equal("tony")
	assert_str(MatchAudio.commentator_for_event("roman_spear")).is_equal("tony")
	assert_str(MatchAudio.commentator_for_event("tony_enda_easter_egg")).is_equal("tony")
	assert_str(MatchAudio.commentator_for_event("excalibur_superman_punch")) \
			.is_equal("excalibur")
	assert_str(MatchAudio.commentator_for_event("excalibur_finish")).is_equal("excalibur")


func test_only_the_active_speaker_gets_the_speaking_pose() -> void:
	var tony: CommentatorActor = auto_free(CommentatorActor.new())
	add_child(tony)
	assert_bool(tony.setup("tony", Vector3.ZERO)).is_true()
	tony.commentary_started("excalibur", 4.0)
	assert_float(tony._speaking_for).is_equal(0.0)
	tony.commentary_started("tony", 4.0)
	assert_float(tony._speaking_for).is_equal(4.0)
