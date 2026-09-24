extends GdUnitTestSuite
## GrappleRig._compute_pair_transform() -- where a paired move plays out.
##
## Paired clips are authored around the origin, and begin() used to align both
## wrestlers straight onto the GrappleAnchor. That anchor has no transform
## override in match.tscn, so it sits at the world origin and every grapple
## teleported the pair to the middle of the ring from wherever they were
## standing -- on camera, a repeated snap-together-and-stack. The rig now
## builds a per-call frame at the pair's own midpoint, and bakes it into the
## duplicated clip's keys so the animation doesn't drag them back.

func _make_rig() -> GrappleRig:
	var rig: GrappleRig = auto_free(GrappleRig.new())
	add_child(rig)
	var anchor: Marker3D = Marker3D.new()
	rig.add_child(anchor)
	rig.anchor = anchor
	return rig

func _make_body(at: Vector3) -> CharacterBody3D:
	var body: CharacterBody3D = auto_free(CharacterBody3D.new())
	add_child(body)
	body.global_position = at
	return body

func test_pair_frame_sits_at_the_midpoint_not_the_origin() -> void:
	var rig := _make_rig()
	var attacker := _make_body(Vector3(1.0, 0.0, 2.0))
	var defender := _make_body(Vector3(1.0, 0.0, 1.0))

	var frame := rig._compute_pair_transform(attacker, defender)

	assert_vector(frame.origin).is_equal_approx(Vector3(1.0, 0.0, 1.5), Vector3.ONE * 0.001)

func test_pair_frame_faces_the_attacker_toward_the_defender() -> void:
	var rig := _make_rig()
	var attacker := _make_body(Vector3(-1.0, 0.0, 0.0))
	var defender := _make_body(Vector3(1.0, 0.0, 0.0))

	var frame := rig._compute_pair_transform(attacker, defender)

	# The clips stand the attacker at +X and the defender at -X, so the
	# frame's -X is the line from the attacker to the defender -- here, world
	# +X. (It used to be the frame's -Z, a quarter-turn off that line.)
	assert_vector(frame.basis * Vector3.LEFT).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)

## A move started against the ropes must not sweep a body through them --
## collision is off for both wrestlers for the clip's whole duration.
func test_pair_frame_is_clamped_inside_the_ring() -> void:
	var rig := _make_rig()
	var attacker := _make_body(Vector3(2.9, 0.0, 2.9))
	var defender := _make_body(Vector3(2.9, 0.0, 2.6))

	var frame := rig._compute_pair_transform(attacker, defender)

	assert_float(frame.origin.x).is_less_equal(GrappleRig.RING_HALF_EXTENT)
	assert_float(frame.origin.z).is_less_equal(GrappleRig.RING_HALF_EXTENT)

## Height is taken from the anchor, not the pair: clip vertical keys are
## authored against mat level and either wrestler may be mid-drift.
func test_pair_frame_takes_height_from_the_anchor() -> void:
	var rig := _make_rig()
	var attacker := _make_body(Vector3(0.0, 0.4, 0.0))
	var defender := _make_body(Vector3(1.0, -0.3, 0.0))

	var frame := rig._compute_pair_transform(attacker, defender)

	assert_float(frame.origin.y).is_equal_approx(0.0, 0.001)

## Coincident wrestlers give no separation axis to face along; fall back to
## the attacker's own facing rather than producing a zero/NaN basis.
func test_coincident_pair_falls_back_to_attacker_facing() -> void:
	var rig := _make_rig()
	var attacker := _make_body(Vector3.ZERO)
	var defender := _make_body(Vector3.ZERO)
	attacker.rotation.y = PI / 2.0

	var frame := rig._compute_pair_transform(attacker, defender)

	# The frame's -X is the attacker-to-defender line (see
	# test_pair_frame_faces_the_attacker_toward_the_defender).
	assert_vector(frame.basis * Vector3.LEFT).is_equal_approx(
		-attacker.global_transform.basis.z, Vector3.ONE * 0.001
	)

func test_align_puts_the_two_wrestlers_back_to_back_at_the_frame() -> void:
	var rig := _make_rig()
	var attacker := _make_body(Vector3(1.0, 0.0, 2.0))
	var defender := _make_body(Vector3(1.0, 0.0, 1.0))
	rig._pair_transform = rig._compute_pair_transform(attacker, defender)

	rig._align_to_pair(attacker, defender)

	assert_vector(attacker.global_position).is_equal_approx(
		Vector3(1.0, 0.0, 1.5), Vector3.ONE * 0.001
	)
	# No trajectory to read, so the authored convention: the attacker faces
	# the defender's side of the frame, which is where the defender stood.
	assert_vector(-attacker.global_transform.basis.z).is_equal_approx(
		Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)
	# Defender is yawed 180 degrees from the attacker, as the authored clips
	# expect (WrestlerA's track is the lifter, WrestlerB's the thrown role).
	var facing_dot := (-attacker.global_transform.basis.z).dot(
		-defender.global_transform.basis.z
	)
	assert_float(facing_dot).is_equal_approx(-1.0, 0.001)

## Through a paired move the defender's root keeps the yaw it was authored
## with and loses only its pitch and roll. It used to lose all three, which
## turned every thrown man a quarter-turn away from the man throwing him.
func test_the_defender_root_keeps_its_authored_yaw() -> void:
	var authored := Quaternion(Basis.from_euler(Vector3(deg_to_rad(-60.0),
			deg_to_rad(-90.0), deg_to_rad(20.0))))
	var kept := GrappleRig.defender_root_yaw(authored)
	var facing := Basis(kept) * Vector3.FORWARD
	# Yaw -90 turns Godot's -Z forward onto +X: toward an attacker at +0.40.
	assert_vector(facing).is_equal_approx(Vector3(1.0, 0.0, 0.0), Vector3.ONE * 0.001)
	# And stands him up: no pitch or roll survives.
	assert_vector(Basis(kept) * Vector3.UP).is_equal_approx(Vector3.UP, Vector3.ONE * 0.001)

func test_the_two_roots_face_each_other_through_a_paired_move() -> void:
	var library: AnimationLibrary = load("res://resources/animations/paired_moves.tres")
	var wrong: Array[String] = []
	for name in library.get_animation_list():
		var anim := library.get_animation(name)
		var facing := {}
		for i in anim.get_track_count():
			if anim.track_get_type(i) != Animation.TYPE_ROTATION_3D:
				continue
			var path := String(anim.track_get_path(i))
			var rot: Quaternion = anim.track_get_key_value(i, 0)
			if path.ends_with("WrestlerB"):
				rot = GrappleRig.defender_root_yaw(rot)
			facing[path.get_slice("/", 1)] = Basis(rot) * Vector3.FORWARD
		if facing.size() != 2:
			continue
		# First key: the lock-up, attacker at +X facing -X, defender opposite.
		if facing["WrestlerA"].dot(facing["WrestlerB"]) > -0.99:
			wrong.append("%s: A %s, B %s" % [name, facing["WrestlerA"], facing["WrestlerB"]])
	assert_array(wrong).override_failure_message(
		"Paired moves that open with the two men not facing each other: %s" % [wrong]
	).is_empty()

## The lead-in lands each man on his clip's first frame, standing where the
## trajectory's first key puts him -- not both on the pair frame's origin.
func test_each_role_starts_on_its_trajectorys_first_key() -> void:
	var rig := _make_rig()
	var player := AnimationPlayer.new()
	rig.add_child(player)
	player.add_animation_library("", load("res://resources/animations/paired_moves.tres"))
	rig.animation_player = player
	var move: MoveDef = load("res://resources/moves/power_bodyslam.tres")
	var a := rig._role_start(move, true)
	var b := rig._role_start(move, false)
	assert_vector(a.origin).is_equal_approx(Vector3(0.40, 0.0, 0.0), Vector3.ONE * 0.001)
	assert_vector(b.origin).is_equal_approx(Vector3(-0.40, 0.0, 0.0), Vector3.ONE * 0.001)
	# Facing each other down the line between them.
	assert_vector(a.basis * Vector3.FORWARD).is_equal_approx(Vector3.LEFT, Vector3.ONE * 0.001)
	assert_vector(b.basis * Vector3.FORWARD).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)
