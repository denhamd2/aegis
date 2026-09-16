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
	# Fill is a property of A SHOT, and there are four of them now. These are
	# the handheld's measurements, so the handheld's lens is what they are
	# read through -- the rig's default is the hard camera's 14 degrees, which
	# would report a fill for a lens camera.md never measured.
	camera.mode = MatchCamera.Mode.RINGSIDE
	camera.fov = camera.shot_fov()
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
	# Containment is the HANDHELD's guard, so it is read through the
	# handheld's lens. The rig's default is the master's 14 degrees now, and
	# projecting a 9m-wide pair through that reports them off the edge of a
	# frame no handheld was ever going to take.
	camera.mode = MatchCamera.Mode.RINGSIDE
	camera.fov = camera.shot_fov()
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
##
## "Tracking" stopped meaning one thing when the master arrived. The handheld
## follows the pair by MOVING; the hard camera follows them by PANNING from a
## fixed seat, and asserting that it moves would assert that it is not a hard
## camera. So what is asserted is the thing both shots owe: wherever the pair
## goes, the shot is pointed at them.
func test_no_shot_ever_stops_tracking() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: Node3D = scene.get_node("WrestlerA")
	var b: Node3D = scene.get_node("WrestlerB")
	for shot: int in [MatchCamera.Mode.HARD_CAM, MatchCamera.Mode.RINGSIDE,
			MatchCamera.Mode.FINISHER_CUT, MatchCamera.Mode.THREE_COUNT_CUT]:
		a.global_position = Vector3(2.4, 0.0, 2.4)
		b.global_position = Vector3(1.6, 0.0, 2.4)
		for tick in 30:
			# Re-asserted each tick because the shot clock and the match's own
			# events are entitled to cut away; what is under test is that the
			# shot, whichever it is, is aimed at the wrestlers.
			camera.mode = shot as MatchCamera.Mode
			camera._physics_process(1.0 / 60.0)
		camera.mode = shot as MatchCamera.Mode
		camera._physics_process(1.0 / 60.0)
		var midpoint := (a.global_position + b.global_position) * 0.5
		# Compared in PLAN, not in three dimensions. Every shot aims at a point
		# ABOVE the pair -- 1.0m for the handheld, 0.3m for the three-count --
		# so a 3D bearing to the pair's feet is off by atan(aim / distance)
		# even when the shot is framed perfectly, and at the handheld's 3.6m
		# that is 15 degrees of nothing. The bearing that says whether a shot
		# is tracking is the one in the horizontal plane.
		var forward3 := -camera.global_transform.basis.z
		var forward := Vector2(forward3.x, forward3.z).normalized()
		var delta := midpoint - camera.global_position
		var to_pair := Vector2(delta.x, delta.z).normalized()
		var off := absf(rad_to_deg(forward.angle_to(to_pair)))
		assert_float(off).override_failure_message(
			"In shot %d the camera is pointed %.1f degrees off the pair after "
			% [shot, off] + "they moved to the corner -- the shot has stopped "
			+ "tracking, which is what the early return used to do."
		).is_less(4.0)

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
	# Out onto the MASTER, which is where a broadcast comes out of a finish.
	assert_int(camera.mode).is_equal(MatchCamera.Mode.HARD_CAM)

## The finisher slot is empty in every shipped scene now -- the finisher
## moves and their paired animations were removed -- so the cut is wired to
## a slot nothing fills rather than to a move that exists. The camera rule
## is still the camera's rule, so the finisher here is a synthetic MoveDef
## dropped into that slot: what is under test is "a finisher cuts and a
## grapple does not", not which .tres is wired where.
func test_only_a_finisher_cuts() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: WrestlerController = scene.get_node("WrestlerA")
	var finisher := MoveDef.new()
	finisher.animation_pair_id = &"synthetic_finisher"
	a.finisher_move = finisher
	camera._on_grapple_started(a, scene.get_node("WrestlerB"), a.grapple_move)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.HARD_CAM)
	camera._on_grapple_started(a, scene.get_node("WrestlerB"), finisher)
	assert_int(camera.mode).is_equal(MatchCamera.Mode.FINISHER_CUT)


# ---------------------------------------------------------------------------
# The master shot
# ---------------------------------------------------------------------------

## THE MASTER IS THE HARD CAMERA, and it is where a match starts.
##
## The rig had one shot and it was a follow-cam strapped to the wrestlers.
## A televised match is covered from a FIXED camera in the bowl, cut away from
## and back; that camera is the default here, and the follow-cam it replaces
## at the top of the match is now the thing it cuts to.
func test_the_match_opens_on_the_hard_camera() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	assert_int(camera.mode).is_equal(MatchCamera.Mode.HARD_CAM)

## THE HARD CAMERA SITS IN THE BUILDING, not near the ring.
##
## Asserted against the arena's own constants rather than against the literal
## in match_camera.gd, so that moving the bowl moves the test with it. The
## anchor has to be beyond the barricade -- a camera inside it is a handheld --
## and out past the lower tier's first row, which is where a hard camera goes.
func test_the_hard_camera_is_anchored_out_in_the_bowl() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	var out := Vector2(camera.hard_cam_position.x, camera.hard_cam_position.z).length()
	assert_float(out) \
		.override_failure_message(
			"the hard camera is %.1fm from ring centre; the barricade is at "
			% out + "%.1f, so this is a ringside camera" \
			% ArenaBuilder.BARRICADE_RADIUS) \
		.is_greater(ArenaBuilder.BARRICADE_RADIUS)
	var first_row: float = ArenaBuilder.BOWL_STRAIGHT_X + ArenaBuilder.BOWL_FIRST_ROW
	assert_float(out) \
		.override_failure_message(
			"the hard camera is %.1fm out; the lower tier's first row on this "
			% out + "side is %.1f, so it is standing on the floor" % first_row) \
		.is_greater(first_row)
	assert_float(camera.hard_cam_position.y) \
		.override_failure_message("a hard camera is above the crowd, not in it") \
		.is_greater(ArenaBuilder.FLOOR_Y + 3.0)

## AND IT LOOKS DOWN. The whole difference between a master and the handheld
## it cuts to is the angle: one is above the ring looking into it, the other
## is beside the ring looking across it.
##
## 8 to 25 degrees is the band a hard camera lives in. Below 8 it is a
## ringside camera on a riser; above 25 it is the overhead the establishing
## shot uses, which `aew_grand_slam_broadcast.png` measures at ~40.
func test_the_hard_camera_looks_down_at_the_ring() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	var flat := Vector2(camera.hard_cam_position.x, camera.hard_cam_position.z).length()
	var drop: float = camera.hard_cam_position.y - camera.hard_cam_aim
	var depression := rad_to_deg(atan(drop / flat))
	assert_float(depression) \
		.override_failure_message(
			"the hard camera looks down at %.1f degrees" % depression) \
		.is_between(8.0, 25.0)

## THE LENS IS A PROPERTY OF THE SHOT, not of the camera.
##
## This is the change that let the master exist at all. Distance and focal
## length are independent: the same subject fill comes out of a wide lens up
## close and a long lens far away, and the two images look nothing alike. With
## a single `fov` on the Camera3D the rig could move but never cut, so every
## shot it had was taken on the handheld's 41-degree lens.
##
## The master must be substantially LONGER than the handheld; if it is not,
## the hard camera is a wide-angle shot from the back of the bowl, which
## frames the building rather than the match.
func test_each_shot_carries_its_own_lens() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	assert_float(camera.hard_cam_fov) \
		.override_failure_message(
			"the master is on a %.0f-degree lens against the handheld's %.0f: "
			% [camera.hard_cam_fov, camera.ringside_fov]
			+ "a master from 28m needs the longer lens, not the wider one") \
		.is_less(camera.ringside_fov * 0.6)
	camera.mode = MatchCamera.Mode.HARD_CAM
	assert_float(camera.shot_fov()).is_equal_approx(camera.hard_cam_fov, 0.001)
	camera.mode = MatchCamera.Mode.RINGSIDE
	assert_float(camera.shot_fov()).is_equal_approx(camera.ringside_fov, 0.001)
	camera.mode = MatchCamera.Mode.THREE_COUNT_CUT
	assert_float(camera.shot_fov()).is_equal_approx(camera.three_count_fov, 0.001)

## THE HARD CAMERA HOLDS BOTH WRESTLERS, corner to corner.
##
## A long lens from 28m is unforgiving: it is solved for the ring, and a pair
## at opposite corners is the widest the pair can ever be. Asserted through
## unproject_position(), which is projection maths and needs no renderer.
func test_the_hard_camera_frames_the_whole_ring() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var a: Node3D = scene.get_node("WrestlerA")
	var b: Node3D = scene.get_node("WrestlerB")
	a.global_position = Vector3(-3.0, 0.0, -3.0)
	b.global_position = Vector3(3.0, 0.0, 3.0)
	camera.mode = MatchCamera.Mode.HARD_CAM
	camera._physics_process(1.0 / 60.0)
	var size := camera.get_viewport().get_visible_rect().size
	for corner: Node3D in [a, b]:
		var head := camera.unproject_position(
				corner.global_position + Vector3.UP * MatchCamera.SUBJECT_HEIGHT)
		var feet := camera.unproject_position(corner.global_position)
		for point: Vector2 in [head, feet]:
			assert_bool(point.x >= 0.0 and point.x <= size.x
					and point.y >= 0.0 and point.y <= size.y) \
				.override_failure_message(
					"a wrestler at a far corner projects to %s, outside a "
					% point + "%s frame: the master's lens is too long" % size) \
				.is_true()

# ---------------------------------------------------------------------------
# The shot clock
# ---------------------------------------------------------------------------

## THE RIG CUTS. This is the one behaviour that separates coverage from a
## follow-cam, and the rig did not have it: between events it now alternates
## master and handheld on a timer.
func test_the_shot_clock_cuts_between_master_and_handheld() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	var step := 1.0 / 60.0
	var seen := {}
	# Two full cycles' worth of ticks, so the assertion is about alternating
	# rather than about one cut happening.
	var ticks := int((camera.hard_cam_hold + camera.ringside_hold) * 2.0 / step) + 4
	for tick in ticks:
		camera._update_mode(step)
		seen[camera.mode] = true
	assert_bool(seen.has(MatchCamera.Mode.HARD_CAM)).override_failure_message(
		"the shot clock never showed the master").is_true()
	assert_bool(seen.has(MatchCamera.Mode.RINGSIDE)).override_failure_message(
		"the shot clock never cut to the handheld -- the rig is still a "
		+ "single-camera rig, it just has a longer lens now").is_true()

## AND IT HOLDS EACH SHOT. A cut every tick is not coverage either; the master
## holds longer than the handheld, which is the shape of a broadcast.
func test_the_master_holds_longer_than_the_handheld() -> void:
	var camera: MatchCamera = _match().get_node("MatchCamera")
	assert_float(camera.hard_cam_hold).is_greater(camera.ringside_hold)
	var step := 1.0 / 60.0
	# One tick short of the hold, the master is still on.
	for tick in int(camera.hard_cam_hold / step) - 1:
		camera._update_mode(step)
	assert_int(camera.mode).override_failure_message(
		"the master cut away before its hold elapsed").is_equal(
		MatchCamera.Mode.HARD_CAM)
	camera._update_mode(step)
	camera._update_mode(step)
	assert_int(camera.mode).override_failure_message(
		"the master never cut away").is_equal(MatchCamera.Mode.RINGSIDE)

## AN EVENT PRE-EMPTS THE CLOCK. A scheduled cut landing in the middle of a
## finish is the one thing a shot clock must never do.
func test_a_finisher_preempts_the_shot_clock() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var rig: GrappleRig = scene.get_node("GrappleRig")
	var step := 1.0 / 60.0
	# A live grapple, driven through the rig's own state rather than faked:
	# the finisher cut is defined as lasting exactly as long as the move it is
	# cutting to, so a cut with no move under it SHOULD end immediately, and a
	# test that forced it to persist would be testing the wrong rule.
	rig._active = true
	camera.cut_to_finisher()
	# Well past both holds. The clock must not cut away from a live finish.
	for tick in int((camera.hard_cam_hold + camera.ringside_hold) * 2.0 / step):
		camera._update_mode(step)
	assert_int(camera.mode).override_failure_message(
		"the shot clock cut away from a live finisher").is_equal(
		MatchCamera.Mode.FINISHER_CUT)
	# And when the move ends, so does the cut -- back out onto the master.
	rig._active = false
	camera._update_mode(step)
	assert_int(camera.mode).override_failure_message(
		"the finisher cut outlived its move").is_equal(MatchCamera.Mode.HARD_CAM)

## A CUT IS INSTANT. Lerping between two angles is a camera MOVE, and a move
## between the bowl and ringside is a 28m fly-in. The rig used to lerp into
## every mode change because there was only ever one position to lerp from.
func test_a_cut_snaps_rather_than_flying() -> void:
	var scene := _match()
	var camera: MatchCamera = scene.get_node("MatchCamera")
	camera._physics_process(1.0 / 60.0)
	camera._physics_process(1.0 / 60.0)
	assert_vector(camera.global_position).override_failure_message(
		"the master did not reach its anchor").is_equal_approx(
		camera.hard_cam_position, Vector3.ONE * 0.01)
	camera.mode = MatchCamera.Mode.RINGSIDE
	camera._physics_process(1.0 / 60.0)
	var out := Vector2(camera.global_position.x, camera.global_position.z).length()
	assert_float(out) \
		.override_failure_message(
			"one tick after cutting to the handheld the camera is %.1fm out, "
			% out + "still flying in from the hard camera's 28.5m") \
		.is_less_equal(camera.max_distance + 0.01)
