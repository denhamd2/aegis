extends Node
## Finishes a match by pinfall (the cover is driven directly, as pin_shot does)
## and grabs the post-match through the match camera: the bell, the winner
## card, the replay, the celebration shots. Prints the stage, each man's FSM
## state, Aubrey's mode and the winner-theme player's position at every grab.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/post_match_shot.tscn -- --out /tmp/pm

var _out := "/tmp/pm"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("cody"), Roster.by_id("roman"), 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = true
	b.is_ai = true
	for _i in 30:
		await get_tree().process_frame
	a.is_ai = false
	b.is_ai = false
	a.fsm.transition_to(WrestlerFSM.State.IDLE)
	b.fsm.transition_to(WrestlerFSM.State.IDLE)
	await get_tree().process_frame
	b.fsm.transition_to(WrestlerFSM.State.STUNNED)
	b.fsm.transition_to(WrestlerFSM.State.DOWN)
	b._move_ticks_remaining = 2000
	await get_tree().process_frame
	a.global_position = b.global_position \
			+ (a.global_position - b.global_position).normalized() * 0.9
	var ticks := 0
	while scene.post_match == null and ticks < 900:
		await get_tree().physics_frame
		ticks += 1
		if scene.get_node("MatchReferee").is_pin_active() and ticks > 60:
			scene.get_node("MatchReferee")._end_pin(true)
		if ticks % 120 == 0:
			print("POST_SHOT waiting t=%d a=%s b=%s pin=%s" % [ticks,
					WrestlerFSM.State.keys()[a.fsm.current_state],
					WrestlerFSM.State.keys()[b.fsm.current_state],
					scene.get_node("MatchReferee").is_pin_active()])
	if scene.post_match == null:
		get_tree().quit()
		return
	var pm: PostMatch = scene.post_match
	var last := ""
	var n := 0
	var since := 0.0
	var ref: RefereeActor = scene.referee_actor
	while not pm.is_done() and n < 40:
		await get_tree().process_frame
		since += get_process_delta_time()
		var tag: String = pm._stage + str(pm._celeb)
		if tag != last or since > 1.2:
			if tag != last:
				since = 0.0
			else:
				since = 0.0
			last = tag
			for _i in 4:
				await RenderingServer.frame_post_draw
			n += 1
			get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [_out, n, tag])
			print("POST_SHOT %02d %s winner=%s loser=%s ref=%s music=%s" % [n, tag,
					WrestlerFSM.State.keys()[pm.winner.fsm.current_state],
					WrestlerFSM.State.keys()[pm.loser.fsm.current_state],
					RefereeActor.Mode.keys()[ref.mode], scene.audio.theme_info()])
	get_tree().quit()
