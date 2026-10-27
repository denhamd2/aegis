extends Node
## The voice lane through the entrances (RingAnnouncer): each of Justin's
## calls and each commentary line as it starts, the cues that queued them,
## and the moment each man's name card goes up -- against the entrance
## clock. Headless, at real time: under --fixed-fps the match outruns the
## audio, which plays on the wall clock. Ends at the bell.
##
##   godot4 --headless --path game tools/probe/voice_lane_log.tscn \
##       -- --wrestlers kenny,cody

func _ready() -> void:
	var spec := ""
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--wrestlers" and i + 1 < args.size():
			spec = args[i + 1]
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec(spec)
	TitleScreen.configure_match(scene, pair[0], pair[1], 2)
	scene.entrances = true
	add_child(scene)
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var voice: RingAnnouncer = director.voice_announcer()
	var tick := [0]
	director.cue.connect(func(what: String) -> void:
		if what.begins_with("announce") or what.begins_with("called_") \
				or MatchAudio.commentary_event_for_cue(what) != "":
			print("CUE   %6.1fs  %s" % [tick[0] / 60.0, what]))
	var last := ""
	var card := false
	var who := ""
	while tick[0] < 60 * 400:
		await get_tree().physics_frame
		tick[0] += 1
		var p: AudioStreamPlayer = voice._player
		var now := p.stream.resource_path.get_file() if p.playing and p.stream else ""
		if now != last:
			if now != "":
				print("VOICE %6.1fs  %-28s %5.1fs" % [tick[0] / 60.0, now, p.stream.get_length()])
			last = now
		var w = director._beats[mini(director._beat, director._beats.size() - 1)].get("who")
		var name_now: String = w.display_name if w is WrestlerController else ""
		if name_now != who:
			print("BEAT  %6.1fs  entrance: %s" % [tick[0] / 60.0, name_now])
			who = name_now
		if director._card.is_showing() != card:
			card = director._card.is_showing()
			print("CARD  %6.1fs  %s" % [tick[0] / 60.0, "up" if card else "down"])
		if not is_instance_valid(director) or director._beat >= director._beats.size():
			break
	print("END   %6.1fs" % (tick[0] / 60.0))
	get_tree().quit()
