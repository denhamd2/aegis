extends GdUnitTestSuite
## camera.md's framing, as numbers.
##
## The old rig used `distance = clamp(separation * 1.6, 4.0, 9.0)`. At
## tie-up range (1.4m) that is 2.24m, which clamps to the 4.0m floor, so
## the camera sat at its minimum through every grapple in the match and a
## wrestler filled 0.29 of the frame -- wider than the reference's *widest*
## shot at the closest moment of the fight.
##
## Fill is measured (gauntlet/refs/camera.md, taken off the reference stills
## with tools/refs/measure_frame.py):
##   strike exchange  0.675 / 0.708 of frame height
##   wide standoff    0.32 / 0.41
## Everything below is asserted through Camera3D.unproject_position(), which
## is projection maths and needs no renderer -- so this holds under the
## headless CI run that ARCHITECTURE.md forbids judging visual slices on.

const MATCH_SCENE := preload("res://scenes/match.tscn")

## The separations the two reference framings were taken at, recovered by
## running the projection backwards through each frame's measured fill (see
## MatchCamera.FIT_SLOPE). The fit is the line through these two points, so
## these are the separations at which it must reproduce the reference -- a
## band checked at any other separation is checking an interpolation, not a
## measurement.
const ENGAGED_SEPARATION := 0.74
const STANDOFF_SEPARATION := 2.58

## The reference's own numbers, with room underneath for the foreshortening
## a real projection applies to an off-axis subject: the wrestler's 1.8m
## spans the frame's centre rather than sitting on the optical axis, which
## costs a few points of fill against the ideal solve.
const ENGAGED_FILL_MIN := 0.63
const ENGAGED_FILL_MAX := 0.75
const STANDOFF_FILL_MIN := 0.30
const STANDOFF_FILL_MAX := 0.47

## Corner to corner on this ring's 6m mat.
const MAX_SEPARATION := 8.49

func _match() -> Node:
	var scene: Node = auto_free(MATCH_SCENE.instantiate())
	add_child(scene)
	return scene

## Places the pair `separation` apart, puts the camera where the rig says,
## and reports what fraction of the frame's height one wrestler covers.
func _fill_at(scene: Node, separation: float) -> float:
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: Node3D = scene.get_node("WrestlerA")
	var b: Node3D = scene.get_node("WrestlerB")
	a.global_position = Vector3(-separation * 0.5, 0.0, 0.0)
	b.global_position = Vector3(separation * 0.5, 0.0, 0.0)
	var midpoint := (a.global_position + b.global_position) * 0.5
	camera.global_position = midpoint \
			+ Vector3(0.0, camera.height, camera.framing_distance(separation))
	camera.look_at(midpoint + Vector3.UP, Vector3.UP)
	var feet := camera.unproject_position(a.global_position)
	var head := camera.unproject_position(a.global_position + Vector3.UP * MatchCamera.SUBJECT_HEIGHT)
	return absf(head.y - feet.y) / camera.get_viewport().get_visible_rect().size.y

func test_an_engaged_pair_is_framed_as_tightly_as_the_reference() -> void:
	var fill := _fill_at(_match(), ENGAGED_SEPARATION)
	assert_float(fill).override_failure_message(
		"At the strike-exchange separation a wrestler fills %.3f of the frame. "
		% fill + "camera.md measures 0.675-0.708 there; the rig this replaced "
		+ "managed 0.29 at its tightest."
	).is_between(ENGAGED_FILL_MIN, ENGAGED_FILL_MAX)

## The other end of the fit: the camera has to open out as the wrestlers
## separate, and land in the reference's standoff band when it does.
func test_a_separated_pair_opens_out_to_the_standoff_band() -> void:
	var fill := _fill_at(_match(), STANDOFF_SEPARATION)
	assert_float(fill).override_failure_message(
		"At the standoff separation a wrestler fills %.3f of the frame; "
		% fill + "camera.md measures 0.32-0.41 there."
	).is_between(STANDOFF_FILL_MIN, STANDOFF_FILL_MAX)

## The guard, which is the only thing the fit cannot promise: past roughly
## 3.9m of separation the fit wants more distance than max_distance allows,
## and from there on containment is what keeps both men on screen. Corner to
## corner the fit alone asks for 17.1m against a 9.0m ceiling.
func test_both_wrestlers_stay_on_screen_at_full_ring_separation() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: Node3D = scene.get_node("WrestlerA")
	var b: Node3D = scene.get_node("WrestlerB")
	a.global_position = Vector3(-MAX_SEPARATION * 0.5, 0.0, 0.0)
	b.global_position = Vector3(MAX_SEPARATION * 0.5, 0.0, 0.0)
	var midpoint := (a.global_position + b.global_position) * 0.5
	camera.global_position = midpoint \
			+ Vector3(0.0, camera.height, camera.framing_distance(MAX_SEPARATION))
	camera.look_at(midpoint + Vector3.UP, Vector3.UP)
	var width := camera.get_viewport().get_visible_rect().size.x
	for wrestler: Node3D in [a, b]:
		var x := camera.unproject_position(wrestler.global_position + Vector3.UP).x
		assert_float(x).override_failure_message(
			"A wrestler projects to x=%.0f on a %.0f-wide frame at full ring "
			% [x, width] + "separation -- he is off the edge of the shot."
		).is_between(0.0, width)

## The guard has to stay out of the way of the framing everywhere the fit
## can actually reach, or it is not a guard, it is the rule.
func test_the_containment_guard_does_not_drive_the_framing() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	for separation: float in [ENGAGED_SEPARATION, 1.4, 2.0, STANDOFF_SEPARATION, 3.0]:
		var fit: float = MatchCamera.FIT_INTERCEPT + MatchCamera.FIT_SLOPE * separation
		assert_float(camera.containment_distance(separation)).override_failure_message(
			"At separation %.2f the guard (%.2f) is further out than the fit (%.2f), "
			% [separation, camera.containment_distance(separation), fit]
			+ "so it -- not the measurement -- is choosing the shot."
		).is_less(fit)

func test_the_camera_pulls_back_monotonically_as_the_pair_separates() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	var previous := 0.0
	for separation: float in [1.0, 1.4, 2.0, 3.0, 4.0, 5.0]:
		var distance := camera.framing_distance(separation)
		assert_float(distance).override_failure_message(
			"Distance went backwards at separation %.1f" % separation
		).is_greater_equal(previous)
		previous = distance

## camera.md: the standoff camera sits "just outside the near ropes". This
## ring's ropes are at 3.1m from centre.
func test_the_camera_never_comes_inside_the_ropes() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	for separation: float in [0.0, 0.5, 1.0, 1.4]:
		assert_float(camera.framing_distance(separation)).is_greater_equal(3.1)

## The bug this slice started from. Both cut helpers set a mode whose only
## effect was an early return at the top of _physics_process, so the camera
## stopped tracking and had nothing to start it again -- calling either
## would have frozen the shot for the rest of the match. Nothing called
## them, which is the only reason it never happened in a real match.
func test_a_cut_still_tracks_the_wrestlers() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: Node3D = scene.get_node("WrestlerA")
	var b: Node3D = scene.get_node("WrestlerB")
	camera.cut_to_finisher()
	var before := camera.global_position
	a.global_position = Vector3(5.0, 0.0, 5.0)
	b.global_position = Vector3(5.0, 0.0, 4.0)
	for tick in 30:
		camera._physics_process(1.0 / 60.0)
	assert_vector(camera.global_position).override_failure_message(
		"The camera did not move while cut. It used to return early in this "
		+ "mode, which froze the shot permanently."
	).is_not_equal(before)

## A cut is a *lower* camera -- camera.md's impact framing "drops lower,
## closer to mat height" than the follow-cam's chest-to-head height.
func test_a_cut_drops_the_camera_below_the_follow_height() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	assert_float(camera.cut_height).is_less(camera.height)

## And it has to end. A finisher cut that outlives its paired move leaves
## the rest of the match framed for a move that already finished.
func test_a_finisher_cut_ends_when_the_grapple_does() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	camera.cut_to_finisher()
	camera._on_grapple_finished(null, null)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.FOLLOW)

func test_only_a_finisher_cuts() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: WrestlerController = scene.get_node("WrestlerA")
	camera._on_grapple_started(a, scene.get_node("WrestlerB"), a.grapple_move)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.FOLLOW)
	camera._on_grapple_started(a, scene.get_node("WrestlerB"), a.finisher_move)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.FINISHER_CUT)
