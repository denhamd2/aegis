extends GdUnitTestSuite
## Real clip clock, without loading an arena or wrestler meshes.

class ProbeCamera extends MatchCamera:
	func _ready() -> void:
		pass

var saved := {}

func before_test() -> void:
	CameraSettings.shake_scale()
	saved = {"coverage": CameraSettings.coverage, "shake": CameraSettings.shake,
			"cuts": CameraSettings.cuts}
	CameraSettings.shake = CameraSettings.Shake.LOW

func after_test() -> void:
	CameraSettings.coverage = saved["coverage"]
	CameraSettings.shake = saved["shake"]
	CameraSettings.cuts = saved["cuts"]

func fixture(startup := 60, active := 6, recovery := 34) -> Dictionary:
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var rig := GrappleRig.new()
	root.add_child(rig)
	var player := AnimationPlayer.new()
	root.add_child(player)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var move := MoveDef.new()
	move.startup_frames = startup
	move.active_frames = active
	move.recovery_frames = recovery
	var clip := Animation.new()
	clip.length = move.total_frames() / 60.0
	var track := clip.add_track(Animation.TYPE_POSITION_3D)
	clip.track_set_path(track, NodePath("Body"))
	clip.position_track_insert_key(track, 0.0, Vector3.ZERO)
	clip.position_track_insert_key(track, clip.length, Vector3.RIGHT)
	var library := AnimationLibrary.new()
	library.add_animation("impact", clip)
	player.add_animation_library("", library)
	player.play("impact")
	player.advance(0.0)
	rig.animation_player = player
	rig._active = true
	var camera := ProbeCamera.new()
	root.add_child(camera)
	camera.set_physics_process(false)
	camera.grapple_rig = rig
	var wrestler: WrestlerController = auto_free(WrestlerController.new())
	wrestler.finisher_move = move
	return {"root": root, "body": body, "rig": rig, "player": player,
			"camera": camera, "wrestler": wrestler, "move": move, "length": clip.length}

func seek(f: Dictionary, phase: float) -> void:
	f.player.seek(phase * float(f.length), true)

func test_every_coverage_fires_once_at_contact_even_with_residual_shake_and_cuts_off() -> void:
	for coverage in [CameraSettings.Coverage.BROADCAST, CameraSettings.Coverage.GAMEPLAY,
			CameraSettings.Coverage.FIGHT_FOREVER]:
		var f := fixture()
		CameraSettings.coverage = coverage
		CameraSettings.cuts = false
		f.camera._arm_impact_shake(f.wrestler, f.move)
		f.camera._trauma = .15
		seek(f, .59)
		f.camera._impact_shake_due()
		assert_float(f.camera._trauma).is_equal_approx(.15, .00001)
		seek(f, .60)
		f.camera._impact_shake_due()
		assert_float(f.camera._trauma).is_equal_approx(1.0, .00001)
		f.camera._shake(1.0/60)
		var decayed: float = f.camera._trauma
		f.camera._impact_shake_due()
		assert_float(f.camera._trauma).is_equal_approx(decayed, .00001)

func test_finisher_shots_do_not_replay_a_consumed_impact_after_the_pulse_settles() -> void:
	var f := fixture()
	CameraSettings.coverage = CameraSettings.Coverage.BROADCAST
	f.camera._arm_impact_shake(f.wrestler, f.move)
	seek(f, .70)
	f.camera._impact_shake_due()
	f.camera._shake(1.0)
	var a := Node3D.new()
	var b := Node3D.new()
	f.root.add_child(a)
	f.root.add_child(b)
	a.position.x = -1
	b.position.x = 1
	f.camera._finish_attacker = a
	f.camera._finish_defender = b
	f.camera._finish_shot = 1
	f.camera._finish_shot_t = MatchCamera.MIN_SHOT
	f.camera._finisher_shot(1.0/60)
	assert_float(f.camera._trauma).is_equal(0.0)

func test_off_clears_active_and_new_cues_without_replaying_them_when_reenabled() -> void:
	var f := fixture()
	f.camera.add_trauma(1.0)
	CameraSettings.shake = CameraSettings.Shake.OFF
	f.camera._shake(1.0/60)
	assert_float(f.camera._trauma).is_equal(0.0)
	assert_float(f.camera.h_offset).is_equal(0.0)
	assert_float(f.camera.v_offset).is_equal(0.0)
	f.camera.add_trauma(.75)
	assert_float(f.camera._trauma).is_equal(0.0)
	f.camera._arm_impact_shake(f.wrestler, f.move)
	seek(f, .60)
	f.camera._impact_shake_due()
	CameraSettings.shake = CameraSettings.Shake.LOW
	f.camera._shake(1.0/60)
	assert_float(f.camera._trauma).is_equal(0.0)

func test_running_catch_and_authored_landing_have_different_camera_beats() -> void:
	var move: MoveDef = load("res://resources/moves/running_grapple_inverted_drop.tres")
	assert_float(MatchCamera.impact_fraction(move)).is_equal_approx(118.0/132, .000001)
	assert_float(MatchCamera.impact_fraction(move)).is_greater(float(move.startup_frames)/move.total_frames())

func test_cancelled_pair_discards_its_pending_impact() -> void:
	var f := fixture()
	f.camera._arm_impact_shake(f.wrestler, f.move)
	f.rig._active = false
	f.camera._impact_shake_due()
	f.rig._active = true
	seek(f, .8)
	f.camera._impact_shake_due()
	assert_float(f.camera._trauma).is_equal(0.0)

func test_all_shake_levels_allow_the_real_root_animation_to_advance() -> void:
	var original_scale := Engine.time_scale
	for setting in [CameraSettings.Shake.OFF, CameraSettings.Shake.LOW, CameraSettings.Shake.HIGH]:
		var f := fixture(12, 2, 26)
		CameraSettings.shake = setting
		f.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		f.camera._arm_impact_shake(f.wrestler, f.move)
		var previous := -1.0
		var peak := 0.0
		for tick in 32:
			await get_tree().physics_frame
			var time: float = f.player.current_animation_position
			if tick > 1:
				assert_float(time).is_greater(previous)
			previous = time
			f.camera._impact_shake_due()
			peak = maxf(peak, f.camera._trauma)
			f.camera._shake(1.0/60)
			assert_float(absf(f.camera.h_offset)).is_less(.2)
			assert_float(absf(f.camera.v_offset)).is_less(.2)
		assert_float(f.body.position.x).is_greater(.6)
		assert_float(peak).is_equal_approx(0.0 if setting == CameraSettings.Shake.OFF else 1.0, .00001)
		assert_float(Engine.time_scale).is_equal(original_scale)
		assert_bool(get_tree().paused).is_false()
		f.root.free()


func test_paired_completion_does_not_shake_twice_or_suppress_a_later_strike() -> void:
	var f := fixture()
	CameraSettings.coverage = CameraSettings.Coverage.FIGHT_FOREVER
	CameraSettings.cuts = false
	f.camera._on_grapple_started(f.wrestler, f.body, f.move)
	seek(f, .6)
	f.camera._impact_shake_due()
	f.camera._shake(1.0)
	f.rig._active = false
	f.camera._on_grapple_finished(f.wrestler, f.body)
	f.camera._on_move_landed(f.wrestler, f.wrestler, f.move)
	assert_float(f.camera._trauma).is_equal(0.0)
	f.camera._on_move_landed(f.wrestler, f.wrestler, f.move)
	assert_float(f.camera._trauma).is_equal(1.0)


func test_completion_without_a_delivered_impact_keeps_the_landed_event_cue() -> void:
	var f := fixture()
	CameraSettings.coverage = CameraSettings.Coverage.FIGHT_FOREVER
	CameraSettings.cuts = false
	f.camera._on_grapple_started(f.wrestler, f.body, f.move)
	f.rig._active = false
	f.camera._on_grapple_finished(f.wrestler, f.body)
	f.camera._on_move_landed(f.wrestler, f.wrestler, f.move)
	assert_float(f.camera._trauma).is_equal(1.0)


func test_an_omitted_completion_notification_expires_without_suppressing_future_hits() -> void:
	var f := fixture()
	CameraSettings.coverage = CameraSettings.Coverage.FIGHT_FOREVER
	CameraSettings.cuts = false
	f.camera._on_grapple_started(f.wrestler, f.body, f.move)
	seek(f, .6)
	f.camera._impact_shake_due()
	f.camera._shake(1.0)
	f.rig._active = false
	f.camera._on_grapple_finished(f.wrestler, f.body)
	await get_tree().process_frame
	f.camera._on_move_landed(f.wrestler, f.wrestler, f.move)
	assert_float(f.camera._trauma).is_equal(1.0)


func bind_slam_cut(f: Dictionary) -> void:
	var other := Node3D.new()
	f.root.add_child(other)
	other.position.x = 2
	CameraSettings.coverage = CameraSettings.Coverage.BROADCAST
	CameraSettings.cuts = true
	f.camera._held = MatchCamera.MIN_SHOT
	assert_bool(f.camera._try_cut(MatchCamera.Cut.SLAM, f.body, other)).is_true()
	f.camera._cut_grapple = true
	f.camera._cut_impact_at = .6


func test_a_broadcast_slam_cannot_top_up_or_repeat_its_scheduled_throw_pulse() -> void:
	var f := fixture()
	f.wrestler.finisher_move = null
	f.move.leaves_defender_down = true
	f.camera._arm_impact_shake(f.wrestler, f.move)
	bind_slam_cut(f)
	seek(f, .6)
	f.camera._impact_shake_due()
	assert_float(f.camera._trauma).is_equal_approx(MatchCamera.TRAUMA_THROW, .00001)
	f.camera._shake(1.0/60)
	var decayed: float = f.camera._trauma
	f.camera._event_shot(1.0/60)
	assert_float(f.camera._trauma).is_equal_approx(decayed, .00001)
	f.camera._shake(1.0)
	f.camera._cut_landed = false
	f.camera._event_shot(1.0/60)
	assert_float(f.camera._trauma).is_equal(0.0)


func test_standalone_slam_fallback_is_kept_but_ordinary_paired_holds_stay_steady() -> void:
	var f := fixture()
	bind_slam_cut(f)
	seek(f, .6)
	f.camera._event_shot(1.0/60)
	assert_float(f.camera._trauma).is_equal_approx(MatchCamera.TRAUMA_SLAM, .00001)
	f.camera._trauma = 0.0
	f.camera._cut_landed = false
	f.wrestler.finisher_move = null
	f.move.leaves_defender_down = false
	f.camera._arm_impact_shake(f.wrestler, f.move)
	f.camera._impact_shake_due()
	f.camera._event_shot(1.0/60)
	assert_float(f.camera._trauma).is_equal(0.0)
	f.move.damage_arms = 6.0
	f.rig._active = false
	f.camera._on_grapple_finished(f.wrestler, f.body)
	f.camera._on_move_landed(f.wrestler, f.wrestler, f.move)
	assert_float(f.camera._trauma).is_equal(0.0)
