extends Node
## The match-up screen (MatchStinger's cover) held mid-load, for review.
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       --resolution 1920x1080 tools/probe/matchup_shot.tscn -- \
##       --out /tmp/matchup.png --left roman --right cody --progress 0.55


func _ready() -> void:
	var out := "/tmp/matchup.png"
	var left := "roman"
	var right := "cody"
	var progress := 0.55
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--out": out = args[i + 1]
			"--left": left = args[i + 1]
			"--right": right = args[i + 1]
			"--progress": progress = float(args[i + 1])
	var s := MatchStinger.new()
	s.setup(Roster.by_id(left), Roster.by_id(right))
	s.mode_label = MatchRules.label(MatchRules.Mode.ONE_ON_ONE) + "  MAIN EVENT"
	get_tree().root.add_child.call_deferred(s)
	await get_tree().process_frame
	s.set_process(false)
	s._stage = MatchStinger.Stage.HOLD
	s.progress = progress
	s._shown = progress
	s._life = 4.0
	s._draw.queue_redraw()
	for _i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	print("MATCHUP_SHOT ", out)
	get_tree().quit()
