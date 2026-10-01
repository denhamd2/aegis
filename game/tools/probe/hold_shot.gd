extends Node
## Renders a wrestler's own submission hold (Cody's Figure-Four) through the
## real code path -- MatchReferee._start_own_hold() on a downed man -- at
## fixed ticks, from the side and three-quarter, without waiting for a match
## to reach it. pin_shot.tscn's pattern, for the hold.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x720 tools/probe/hold_shot.tscn -- --out /tmp/hold
##
## --wrestlers cody,roman (default): the first is the one with the hold.
## --ticks 0,40,80,124,170,230: physics ticks after the hold starts.

const MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/hold"
var _wrestlers := "cody,roman"
var _ticks: Array[int] = [0, 24, 48, 72, 96, 124, 150, 190, 230, 300]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--ticks" and i + 1 < args.size():
			_ticks = []
			for t in args[i + 1].split(","):
				_ticks.append(int(t))
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec(_wrestlers)
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	for f in 30:
		await get_tree().process_frame
	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	attacker.is_ai = false
	defender.is_ai = true
	# A lock-up the settle frames started would resume under the forced
	# states the moment the hold ends.
	referee._tying_up = false
	attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	defender.fsm.transition_to(WrestlerFSM.State.IDLE)
	await get_tree().physics_frame
	# Mid-ring, so the spot at his feet is inside the ropes.
	defender.global_position = Vector3(0.0, defender.global_position.y, -0.5)
	defender.fsm.transition_to(WrestlerFSM.State.STUNNED)
	defender.fsm.transition_to(WrestlerFSM.State.DOWN)
	defender._move_ticks_remaining = 100000
	# Forced down mid-stride he keeps his walking velocity; a real knockdown
	# goes through HIT_REACT, which stops him.
	defender.velocity = Vector3.ZERO
	for f in 20:
		await get_tree().physics_frame
	referee._start_own_hold(attacker, defender)

	var cam := Camera3D.new()
	cam.fov = 45.0
	scene.add_child(cam)
	var light := OmniLight3D.new()
	light.omni_range = 8.0
	light.light_energy = 1.2
	scene.add_child(light)
	var tick := 0
	var shot := 0
	while shot < _ticks.size():
		if tick == _ticks[shot]:
			var mid := (attacker.global_position + defender.global_position) * 0.5
			var across := defender.global_transform.basis.x.normalized()
			var along := defender.global_transform.basis.z.normalized()
			for view in [["side", across * 3.4 + Vector3(0, 1.2, 0)],
					["three_quarter", (across * 2.4 + along * 2.4) + Vector3(0, 1.6, 0)]]:
				cam.global_position = mid + (view[1] as Vector3) + Vector3(0, 0.3, 0)
				cam.look_at(mid + Vector3(0, 0.35, 0))
				cam.make_current()
				light.global_position = cam.global_position
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_jpg(
						"%s/hold_t%03d_%s.jpg" % [_out, tick, view[0]], 0.9)
			print("t%03d atk=%s def=%s holding=%s lock=%d sep=%.2f" % [tick,
					WrestlerFSM.State.keys()[attacker.fsm.current_state],
					WrestlerFSM.State.keys()[defender.fsm.current_state],
					referee.is_submission_active(), attacker._submission_lock_ticks,
					attacker.global_position.distance_to(defender.global_position)])
			print("   atk %s def %s defz %s to %s" % [attacker.global_position, defender.global_position, defender.global_transform.basis.z, attacker._cover_to.origin])
			shot += 1
		await get_tree().physics_frame
		tick += 1
	get_tree().quit()
