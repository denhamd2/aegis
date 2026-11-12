extends Node
## The pre-match, logged: from the second man in his corner to six seconds
## after the bell -- every beat and shot as it starts, both men's positions
## and states every 10 ticks, and the referee's spot. For the owner's 12 Nov
## review ("a weird glitch that they go from the corner, sprint in and go
## back"; "the ref stands in front of him"; "the sequence goes on too long").
##
##   godot --headless --path game --fixed-fps 6000 tools/probe/prematch_log.tscn

const MATCH_SCENE := "res://scenes/match.tscn"


func _ready() -> void:
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var a := scene.get_node("WrestlerA") as WrestlerController
	var b := scene.get_node("WrestlerB") as WrestlerController
	var ref := scene.get_node_or_null("RefereeActor") as Node3D
	var rang := [false]
	var bell_tick := [-1]
	# A lambda captures a local by value: `tick` read inside one is the 0 it
	# held when the lambda was made, which ended the log at the bell. The
	# counter lives in an array the lambda shares.
	var now := [0]
	var tick := 0
	director.bell.connect(func(): rang[0] = true; bell_tick[0] = now[0])
	var last_beat := -1
	var logging := false
	var from_tick := -1
	while tick < 60 * 600:
		await get_tree().physics_frame
		tick += 1
		now[0] = tick
		if rang[0] and tick > bell_tick[0] + 360:
			break
		if director._beat < director._beats.size() and director._beat != last_beat:
			var bt: Dictionary = director._beats[director._beat]
			var shot := String(bt.get("shot", ""))
			if not logging and shot in ["faceoff", "walk_in_tv", "faceoff_side", "match_card"]:
				logging = true
				from_tick = tick
			if logging:
				print("BEAT t%d +%.1fs #%d %s shot=%s ticks=%s" % [tick, (tick - from_tick) / 60.0,
						director._beat, bt["kind"], shot, bt.get("ticks", "-")])
			last_beat = director._beat
		if logging and tick % 10 == 0:
			print("POS t%d +%.1fs A %s %s  B %s %s  ref %s%s" % [tick, (tick - from_tick) / 60.0,
					WrestlerFSM.State.keys()[a.fsm.current_state], _v(a.global_position),
					WrestlerFSM.State.keys()[b.fsm.current_state], _v(b.global_position),
					_v(ref.global_position) if ref else "-", "  (bell)" if rang[0] else ""])
	print("PREMATCH_DONE from_corners_to_bell=%.1fs" % [(bell_tick[0] - from_tick) / 60.0])
	get_tree().quit()


static func _v(p: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [p.x, p.y, p.z]
