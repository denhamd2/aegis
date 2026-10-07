class_name PossumSpot
extends Node
## The possum attack (gauntlet/refs/moveset_audit_2k26.md; 2K26 640 s): the man
## down waits for the other to come and stand over his legs, then sweeps them
## from the mat, and both are down. Once a match, for a wrestler whose moveset
## carries "possum" (Roman), and only while the AI is playing him -- a player
## is never taken out of his own hands.
##
## A set piece like DiveSpot, for the same reasons: both men frozen, the
## standing man eased onto the spot at the downed man's shins, both playing
## presentation clips (Possum_Sweep, Swept_Legs); at the end the swept man is
## down, and the sweeper goes back to the mat he never left. No match ticks.

const TPS := 60.0
## Where the swept man stands, in the downed man's own frame: past his boots
## (his head is up -Z), facing up his body.
const STAND_AT := Vector3(0.0, 0.0, 0.95)
## How near the standing man has to be to that spot for the sweep to be on.
const NEAR := 0.9
## The downed man has been down at least this long: it is a man coming round,
## not a reflex.
const MIN_DOWN_TICKS := 40
const EASE_TICKS := 10
const SPOT_TICKS := 84
## Possum_Sweep frame 12.
const CONTACT := 24

var sweeper: WrestlerController
var swept: WrestlerController
var _camera: MatchCamera
var _frozen: Array = []
var _tick := 0
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _yaw := 0.0


static func wants(down: WrestlerController, standing: WrestlerController) -> bool:
	if down.possum_move == null or down._possum_used or not down.is_ai:
		return false
	if down.fsm.current_state != WrestlerFSM.State.DOWN \
			or down.fsm.ticks_in_state < MIN_DOWN_TICKS:
		return false
	if not standing.fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]) \
			or standing.last_landed_tier >= CombatSystem.Tier.FINISHER:
		return false
	var spot := down.global_transform * STAND_AT
	return DiveSpot._flat(standing.global_position).distance_to(DiveSpot._flat(spot)) <= NEAR


func begin(p_sweeper: WrestlerController, p_swept: WrestlerController) -> void:
	sweeper = p_sweeper
	swept = p_swept
	var match_root := get_parent()
	_camera = match_root.get_node_or_null("MatchCamera") as MatchCamera
	for node: Node in [sweeper, swept, sweeper.ai, swept.ai,
			match_root.get_node_or_null("MatchReferee"),
			match_root.get_node_or_null("GrappleRig")]:
		if node:
			_frozen.append([node, node.is_physics_processing()])
			node.set_physics_process(false)
	for w: WrestlerController in [sweeper, swept]:
		w.velocity = Vector3.ZERO
	_from = swept.global_position
	_to = sweeper.global_transform * STAND_AT
	_to.y = _from.y
	var up_his_body := sweeper.global_transform.basis * Vector3(0, 0, -1)
	_yaw = atan2(-up_his_body.x, -up_his_body.z)
	if swept.fsm.current_state != WrestlerFSM.State.IDLE:
		swept.fsm.transition_to(WrestlerFSM.State.IDLE)
	swept.play_presentation_clip("strikes/swept_legs")
	sweeper.play_presentation_clip("strikes/possum_sweep")
	_shot(true, 1.0 / TPS)


func _physics_process(delta: float) -> void:
	_tick += 1
	var e := clampf(float(_tick) / EASE_TICKS, 0.0, 1.0)
	swept.global_position = _from.lerp(_to, e * e * (3.0 - 2.0 * e))
	swept.rotation.y = rotate_toward(swept.rotation.y, _yaw, 8.0 * delta)
	if _tick == CONTACT and sweeper.possum_move:
		swept.combat.apply_damage(sweeper.possum_move)
		sweeper.combat.apply_momentum(sweeper.possum_move)
	_shot(false, delta)
	if _tick >= SPOT_TICKS:
		_finish()


func _shot(cut: bool, delta: float) -> void:
	if _camera == null:
		return
	var mid := (sweeper.global_position + swept.global_position) * 0.5
	var along := DiveSpot._flat(swept.global_position - sweeper.global_position).normalized()
	var side := Vector3.UP.cross(along).normalized()
	# The side the referee is not on: she walks the ring through this, and
	# from her side she filled the frame (the owner-facing render).
	if _referee_side() > 0.0:
		side = -side
	_camera.set_entrance_shot(mid + side * 3.6 + Vector3(0, 1.3, 0),
			mid + Vector3(0, 0.5, 0), 48.0, cut, delta)


## +1 if the referee is on `side`'s side of the pair, -1 if not: chosen once, at the
## start, so the camera never swaps sides mid-spot.
var _ref_side := 0.0


func _referee_side() -> float:
	if _ref_side != 0.0:
		return _ref_side
	_ref_side = -1.0
	var ref := get_parent().find_child("RefereeActor", true, false) as Node3D
	if ref:
		var mid := (sweeper.global_position + swept.global_position) * 0.5
		var along := DiveSpot._flat(swept.global_position - sweeper.global_position).normalized()
		var side := Vector3.UP.cross(along).normalized()
		_ref_side = 1.0 if side.dot(ref.global_position - mid) > 0.0 else -1.0
	return _ref_side


func _finish() -> void:
	for entry: Array in _frozen:
		(entry[0] as Node).set_physics_process(entry[1])
	for w: WrestlerController in [sweeper, swept]:
		w.velocity = Vector3.ZERO
		w.end_presentation(true)
	# He went over backward: his head is behind where he faced. Turned round on
	# the mat, and down, the knockdown a move gives.
	swept._turn_round_on_the_mat()
	swept._go_down()
	# The sweeper never left the mat: back to his own down clip.
	sweeper._restart_state_clip(WrestlerFSM.State.DOWN,
			WrestlerController.clip_for_state(WrestlerFSM.State.DOWN, false))
	if _camera:
		_camera.resume_play()
	queue_free()
