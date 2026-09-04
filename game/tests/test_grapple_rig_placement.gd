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

	# Godot forward is -Z; the defender lies along +X from the attacker.
	assert_vector(-frame.basis.z).is_equal_approx(Vector3.RIGHT, Vector3.ONE * 0.001)

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

	assert_vector(-frame.basis.z).is_equal_approx(
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
	# Defender is yawed 180 degrees from the attacker, as the authored clips
	# expect (WrestlerA's track is the lifter, WrestlerB's the thrown role).
	var facing_dot := (-attacker.global_transform.basis.z).dot(
		-defender.global_transform.basis.z
	)
	assert_float(facing_dot).is_equal_approx(-1.0, 0.001)
