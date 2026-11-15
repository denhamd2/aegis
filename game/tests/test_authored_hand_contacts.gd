extends GdUnitTestSuite
## A forearm surface contact must not become a forced wrist target.

func move() -> MoveDef:
	return load("res://resources/moves/running_grapple_inverted_drop.tres")

func points() -> Dictionary:
	return {"lowerarm_r": Vector3.ZERO, "hand_r": Vector3(1, 0, 0),
			"lowerarm_l": Vector3(-10, 0, 0), "hand_l": Vector3(-11, 0, 0)}

func anchor() -> Dictionary:
	return {"upperarm_l": Transform3D(Basis(), Vector3(.4, .08, 0))}

func test_authored_policy_never_falls_back_to_waist_ik_or_model_pull() -> void:
	assert_bool(PairedContacts.authored_hands(move())).is_true()
	assert_bool(PairedContacts.pulls(move())).is_false()
	for phase in [0.0, 37.0/66, 43.0/66, 55.0/66, 59.0/66, 1.0]:
		assert_array(PairedContacts.authored_contact_samples(move(), phase, points(), anchor())).is_empty()

func test_expected_contact_uses_anatomical_right_forearm_not_free_left_or_wrist() -> void:
	var contacts := PairedContacts.authored_contact_samples(move(), 49.0/66, points(), anchor())
	assert_int(contacts.size()).is_equal(1)
	assert_bool(contacts[0]["valid"]).is_true()
	assert_float(contacts[0]["gap_m"]).is_equal_approx(0.0, .00001)
	assert_vector(contacts[0]["closest"]).is_equal_approx(Vector3(.4, 0, 0), Vector3.ONE*.00001)
	assert_float((points()["hand_r"] as Vector3).distance_to(contacts[0]["target"])).is_greater(.5)

func test_contact_observation_is_invariant_under_pair_translation_and_yaw() -> void:
	var frame := Transform3D(Basis(Vector3.UP, .8), Vector3(3, .2, -4))
	var pose := points()
	for bone in pose:
		pose[bone] = frame * pose[bone]
	var target := anchor()
	target["upperarm_l"] = frame * target["upperarm_l"]
	var contact := PairedContacts.authored_contact_samples(move(), 49.0/66, pose, target)[0]
	assert_bool(contact["valid"]).is_true()
	assert_float(contact["gap_m"]).is_equal_approx(0.0, .00001)
	assert_float(contact["centreline_distance_m"]).is_equal_approx(.08, .00001)

func test_missing_anchors_and_effectors_are_required_failures_not_dropped_samples() -> void:
	for sample in [PairedContacts.authored_contact_samples(move(), 49.0/66, {}, anchor())[0],
			PairedContacts.authored_contact_samples(move(), 49.0/66, points(), {})[0]]:
		assert_bool(sample["valid"]).is_false()
		assert_str(sample["reason"]).is_not_empty()

func test_legacy_contact_moves_keep_their_existing_policy() -> void:
	for spec in [["finisher_spear", "waist", true], ["signature_neckbreaker", "neck", true],
			["signature_superman_punch", "none", true], ["signature_cody_cutter", "neck", false]]:
		var legacy: MoveDef = load("res://resources/moves/%s.tres" % spec[0])
		assert_bool(PairedContacts.authored_hands(legacy)).is_false()
		assert_str(PairedContacts.family(legacy)).is_equal(spec[1])
		assert_bool(PairedContacts.pulls(legacy)).is_equal(spec[2])

func test_profile_windows_and_geometry_are_valid() -> void:
	var profile := PairedContacts.hand_profile(move())
	assert_array(profile["expected"]).is_not_empty()
	for expected: Dictionary in profile["expected"]:
		var window: Vector2 = expected["window"]
		assert_float(window.x).is_greater_equal(0.0)
		assert_float(window.y).is_greater_equal(window.x)
		assert_float(window.y).is_less_equal(1.0)
		assert_int(expected["effector"].size()).is_equal(2)
		assert_float(expected["surface_radius"]).is_greater(0.0)
		assert_float(expected["effector_radius"]).is_greater(0.0)

func test_deep_contact_keeps_signed_penetration_visible() -> void:
	var target := {"upperarm_l": Transform3D(Basis(), Vector3(.4, 0, 0))}
	var contact := PairedContacts.authored_contact_samples(move(), 49.0/66, points(), target)[0]
	assert_float(contact["gap_m"]).is_equal_approx(0.0, .00001)
	assert_float(contact["signed_gap_m"]).is_less(0.0)
	assert_float(contact["penetration_m"]).is_greater(PairClearance.ARM_LIMIT)
