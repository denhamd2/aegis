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


## Seated behind the desk facing the ring, which lies to -Z of it: his face
## is toward -Z of his body. (They sat facing away, the owner, 1 Nov: the
## models face +Z and were left unturned.)
func test_both_face_the_ring() -> void:
	for role in ["tony", "excalibur"]:
		var actor: CommentatorActor = auto_free(CommentatorActor.new())
		add_child(actor)
		assert_bool(actor.setup(role, Vector3.ZERO)).is_true()
		var head := _centre(actor.find_child(role.capitalize() + "SculptedHead", true, false))
		var body := _centre(actor.find_child(role.capitalize() + "SeatedBody", true, false))
		assert_float(head.z).override_failure_message("%s's head is %.2f m to +Z of his torso: facing away"
				% [role, head.z - body.z]).is_less(body.z - 0.05)


static func _centre(node: Node) -> Vector3:
	var mi := node as MeshInstance3D
	if mi == null:
		mi = node.find_children("", "MeshInstance3D", true, false)[0] as MeshInstance3D
	return mi.global_transform * mi.get_aabb().get_center()


func test_reference_specific_head_meshes_are_present() -> void:
	var tony: CommentatorActor = auto_free(CommentatorActor.new())
	add_child(tony)
	assert_bool(tony.setup("tony", Vector3.ZERO)).is_true()
	assert_object(tony.find_child("TonySculptedHead", true, false)).is_not_null()
	assert_object(tony.find_child("TonyGlassesFrame1", true, false)).is_not_null()

	var excalibur: CommentatorActor = auto_free(CommentatorActor.new())
	add_child(excalibur)
	assert_bool(excalibur.setup("excalibur", Vector3.ZERO)).is_true()
	assert_object(excalibur.find_child("ExcaliburSculptedHead", true, false)).is_not_null()
	assert_object(excalibur.find_child("ExcaliburFullHeadMaskShell", true, false)).is_not_null()
	assert_object(excalibur.find_child("ExcaliburEyeTrim1", true, false)).is_not_null()


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
