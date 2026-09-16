extends Node
## One strike, tick by tick, on two roster models: does the punch arrive, and
## does the man it arrives at move?
##
## Every existing shot probe frames ONE wrestler. state_shot.gd deliberately
## parks the opponent 12 m away so the frame is about a single pose, and
## clip_shot.gd plays a clip on a lone mannequin with nothing to hit. Neither
## can answer "did that land" -- which is a question about two men and the
## distance between them -- and strike_connect_probe.gd answers it as a rate
## with no picture attached.
##
## So this sets the pair up at a distance the move's own measured reach says
## it covers, throws it, and grabs EVERY tick from wind-up to recovery, with
## both FSM states and the contact geometry printed beside each frame. A
## landed strike shows the defender leaving IDLE for HIT_REACT within a tick
## of the contact frame; a whiff shows him standing there, and the printed gap
## says by how much it missed.
##
## Usage:
##   xvfb-run -a godot4 --path game --resolution 1280x720 \
##       tools/probe/exchange_shot.tscn -- \
##       --wrestlers roman,cody --moves strike_jab,strike_cross --out /tmp/ex
##
## --gap scales the starting separation against the move's own reach: 0.85 is
## comfortably inside it, 1.05 is a deliberate miss for comparison.

const MATCH_SCENE := "res://scenes/match.tscn"
const MOVE_DIR := "res://resources/moves/"

var _out := "/tmp/exchange"
var _wrestlers := ""
var _moves: Array = ["strike_jab"]
var _gap := 0.85
## Ticks past the end of the strike, so the defender's whole reaction is in
## the strip rather than just its first frame. HIT_REACT_TICKS is 20.
var _tail := 24


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--moves" and i + 1 < args.size():
			_moves = Array(args[i + 1].split(","))
		elif args[i] == "--gap" and i + 1 < args.size():
			_gap = float(args[i + 1])
		elif args[i] == "--tail" and i + 1 < args.size():
			_tail = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)

	var pair := Roster.pair_from_spec(_wrestlers)
	if pair.is_empty():
		get_tree().quit(1)
		return
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	# Hand-driven, not AI: the probe decides when the punch is thrown, so the
	# frame numbering below means the same thing on every run.
	attacker.is_ai = false
	defender.is_ai = false
	print("EXCHANGE %s -> %s" % [pair[0].display_name(), pair[1].display_name()])

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true

	for move_id: String in _moves:
		await _throw(attacker, defender, camera, move_id)
	get_tree().quit()


func _throw(attacker: WrestlerController, defender: WrestlerController,
		camera: Camera3D, move_id: String) -> void:
	var path := "%s%s.tres" % [MOVE_DIR, move_id]
	if not ResourceLoader.exists(path):
		print("!! no move %s" % path)
		return
	var move: MoveDef = load(path)

	# Square them up along X at a fraction of this move's OWN reach, rather
	# than at one shared distance. strike_reach() is what the controller
	# tests against, so a gap derived from it is a gap the move can be
	# expected to cover -- and a jab and a heavy kick do not agree about what
	# "in range" is (0.42 m of fist against 0.82 m of boot).
	var reach := WrestlerController.strike_reach(move)
	var half := reach * _gap * 0.5
	_reset(attacker, Vector3(-half, 0.0, 0.0))
	_reset(defender, Vector3(half, 0.0, 0.0))
	attacker.look_at(defender.global_position, Vector3.UP)
	defender.look_at(attacker.global_position, Vector3.UP)
	await get_tree().physics_frame

	attacker._play_strike_clip(move)
	attacker._start_move(WrestlerFSM.State.STRIKE, move)

	var total := move.total_frames() + _tail
	var landed_on := -1
	for tick in total:
		var offset := move.total_frames() - attacker._move_ticks_remaining
		var reacting := defender.fsm.current_state == WrestlerFSM.State.HIT_REACT
		if reacting and landed_on < 0:
			landed_on = tick
		# Framed square-on to the line between them, tight enough that a head
		# snapping back is readable. The pair sit on X, so the camera sits on
		# Z and slightly above the contact height.
		var focus := (attacker.global_position + defender.global_position) * 0.5 \
				+ Vector3(0.0, 1.15, 0.0)
		camera.global_position = focus + Vector3(0.0, 0.35, 3.1)
		camera.look_at(focus, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
				"%s/%s_t%02d.png" % [_out, move_id, tick])
		var to_them: Vector3 = defender.global_position - attacker.global_position
		to_them.y = 0.0
		print("  %-18s t=%02d off=%2d  %-10s %-10s  gap %.2f  off-facing %2.0f deg  %s" % [
				move_id, tick, offset,
				WrestlerFSM.State.keys()[attacker.fsm.current_state],
				WrestlerFSM.State.keys()[defender.fsm.current_state],
				to_them.length(),
				rad_to_deg((-attacker.global_transform.basis.z).angle_to(
						to_them.normalized())),
				"CONTACT" if attacker._active_move_hit_applied else ""])
		await get_tree().physics_frame

	# The contact tick is what the MoveDef declares; the reaction tick is what
	# the defender actually did. They should be one or two apart -- the hit is
	# queued on the attacker's tick and resolved by MatchReferee after both
	# wrestlers have stepped.
	var contact := move.startup_frames
	if landed_on < 0:
		var gap: float = attacker.global_position.distance_to(defender.global_position)
		print("  %s MISSED -- gap %.2f m against reach %.2f m"
				% [move_id, gap, WrestlerController.strike_reach(move)])
	else:
		print("  %s landed: contact frame %d, defender reacted on tick %d (+%d)"
				% [move_id, contact, landed_on, landed_on - contact])


## Back to a standing, idle, stationary wrestler at `where`.
func _reset(w: WrestlerController, where: Vector3) -> void:
	w._active_move = null
	w._move_ticks_remaining = 0
	w._active_move_hit_applied = false
	w._pending_hits.clear()
	w._pending_hit_reaction = null
	w.velocity = Vector3.ZERO
	w.global_position = where
	if w.fsm.current_state != WrestlerFSM.State.IDLE:
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
