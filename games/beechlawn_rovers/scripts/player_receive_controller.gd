extends RefCounted
class_name PlayerReceiveController
## One serial-bound, marker-gated ground reception. Never owns ball position.
const KINDS: Array[StringName] = [&"pass",&"through_pass",&"lofted_pass",&"cross",&"header_clearance",&"goalkeeper_distribution"]
var actor: FootballPlayer
var ball: FootballBall
var active := false
var foot: StringName = &"right"
var mode: StringName = &"carry"
var serial := -1
var contact_done := false
var contact_gap := INF
var _last_serial := -1
var release_seconds := 0.0
var _window := 0.0
var _capsule_exception := false

func configure(player: FootballPlayer, match_ball: FootballBall) -> void:
	actor = player
	ball = match_ball

func suppresses_dribble() -> bool:
	return (active and not contact_done) or release_seconds > 0

func defer_dribble() -> bool:
	if (active and not contact_done) or release_seconds > 0: return true
	return ball.last_touch == actor.team_name and ball.last_action in KINDS and _strike_intent()

func _strike_intent() -> bool:
	if actor._visual_pass_pending or actor._visual_shot_pending or actor._pending_pass > 0 or actor._pending_shot > 0 or actor._shot_charge >= 0:
		return true
	if actor.controlled_by_human:
		for action in ["pass","through_pass","shoot","lofted_pass","cross"]:
			if Input.is_action_just_pressed(action): return true
	return false

func _eligible() -> bool:
	return ball != null and actor.receive_target_time > 0 and ball.last_touch == actor.team_name and ball.last_action in KINDS \
		and not is_instance_valid(ball.goalkeeper_holder) and not actor._aerial_controller.committed() \
		and not actor._keeper_is_recovering() and actor._slide_tackle_time <= 0 and actor.skills.active == &""

func before_move(delta: float) -> void:
	release_seconds = maxf(0,release_seconds-delta)
	if active:
		if _strike_intent() or (not contact_done and (not _eligible() or ball.action_serial != serial)):
			cancel()
		elif not contact_done and (Vector2(actor.velocity.x,actor.velocity.z).length()>.8 or actor._stick.length()>.1):
			actor._footballer_visual.set_context_receive_moving()
		return
	if not _eligible() or _strike_intent() or ball.action_serial == _last_serial: return
	var visual := actor._footballer_visual
	if not is_instance_valid(visual) or not visual.can_receive_context(): return
	var ground := ball.surface_height(ball.position.x,ball.position.z) if ball.use_terrain else 0.0
	if ball.position.y > ground+FootballBall.RADIUS+.16: return
	var relative := ball.linear_velocity-Vector3(actor.velocity.x,0,actor.velocity.z)
	relative.y = 0
	if relative.length_squared() < .5: return
	var best := {}
	var marker := visual.receive_context_contact_time()
	for candidate: StringName in [&"right",&"left"]:
		var local := visual.receive_context_offset(candidate,Vector2(actor.velocity.x,actor.velocity.z).length()>.8)
		var target := actor.global_position+actor.global_basis*local
		var offset := ball.global_position-target
		offset.y = 0
		if offset.dot(relative) >= 0: continue
		var eta := -offset.dot(relative)/relative.length_squared()
		if eta < .045 or eta > marker*1.2: continue
		var miss := (offset+relative*eta).length()
		if miss > .22: continue
		# Stable right-foot tie-break; do not swap feet on floating-point noise.
		if best.is_empty() or miss < float(best.miss)-.015: best = {"foot":candidate,"eta":eta,"miss":miss}
	if best.is_empty(): return
	foot = best.foot
	mode = _input_mode()
	var speed := clampf(marker/float(best.eta),.85,1.5)
	var start := maxf(0,marker-float(best.eta)*speed)
	if not visual.play_context_receive(foot,Vector2(actor.velocity.x,actor.velocity.z).length()>.8,speed,start): return
	active = true
	contact_done = false
	contact_gap = INF
	serial = ball.action_serial
	_last_serial = serial
	_window = 0
	# Only this receiving body is exempted during the anatomical approach;
	# all other players, tackles and keeper contacts remain physical.
	if not actor.get_collision_exceptions().has(ball):
		actor.add_collision_exception_with(ball)
		_capsule_exception = true

func after_move(delta: float) -> void:
	if not active: return
	var visual := actor._footballer_visual
	if not is_instance_valid(visual) or not visual.context_receiving():
		cancel()
		return
	visual.advance_context_receive(delta)
	if _window > 0 and not contact_done:
		_window = maxf(0,_window-delta)
		_attempt_contact()
		if _window <= 0 and not contact_done: cancel()

func on_marker() -> void:
	if not active or contact_done: return
	_window = .05
	_attempt_contact()

func _attempt_contact() -> void:
	if not _eligible() or ball.action_serial != serial:
		cancel()
		return
	var position := actor._footballer_visual.receive_context_position(foot)
	contact_gap = ball.global_position.distance_to(position)
	if contact_gap > actor.tuning.receive_foot_contact_radius: return
	mode = _input_mode()
	var step_version := actor._stoppage_version
	if ball.receive_touch(actor,position,_outlet_direction(),mode):
		if step_version != actor._stoppage_version:
			cancel(true)
			return
		contact_done = true
		_window = 0
		release_seconds = .24 if mode == &"sprint" else .10
		actor.receive_target_time = 0
		actor.set_meta("last_receive",{"foot":foot,"mode":mode,"gap":contact_gap,"serial":serial,"time":actor._footballer_visual.context_receive_clock()})
		_restore_capsule()
		actor.status_changed.emit("First touch")

func _input_mode() -> StringName:
	if actor.controlled_by_human:
		if Input.is_action_pressed("close_control"): return &"close"
		var movement := Input.get_vector("move_left","move_right","move_up","move_down")
		return &"sprint" if Input.is_action_pressed("sprint") and (movement.length()>.1 or Vector2(actor.velocity.x,actor.velocity.z).length()>.8) else &"carry"
	for other in actor.get_tree().get_nodes_in_group("football_players"):
		if other != actor and other.team_name != actor.team_name and other.global_position.distance_to(actor.global_position)<2.0: return &"close"
	return &"sprint" if actor.ai_sprinting and actor.ai_move_direction.length()>.1 else &"carry"

func _outlet_direction() -> Vector3:
	var forward := -actor.global_basis.z
	forward.y = 0
	var desired := actor.ai_move_direction
	if actor.controlled_by_human:
		var right := actor.camera.global_basis.x
		var camera_forward := -actor.camera.global_basis.z
		right.y=0; camera_forward.y=0
		var movement := Input.get_vector("move_left","move_right","move_up","move_down")
		desired = right.normalized()*movement.x-camera_forward.normalized()*movement.y
		desired.y=0
		if movement.length()<.1:
			desired = Vector3(actor.velocity.x,0,actor.velocity.z)
	if desired.length_squared()<.01: return forward.normalized()
	# An opposite input turns the body; it cannot pull a live ball through it.
	var angle := forward.signed_angle_to(desired.normalized(),Vector3.UP)
	return forward.rotated(Vector3.UP,clampf(angle,-PI*.40,PI*.40)).normalized()

func _restore_capsule() -> void:
	if _capsule_exception and is_instance_valid(actor) and is_instance_valid(ball): actor.remove_collision_exception_with(ball)
	_capsule_exception = false

func cancel(clear_history := false) -> void:
	_restore_capsule()
	if active and is_instance_valid(actor._footballer_visual): actor._footballer_visual.cancel_context_receive()
	active = false
	_window = 0
	if clear_history:
		_last_serial = -1
		release_seconds = 0
		serial = -1
		contact_done = false
		contact_gap = INF
