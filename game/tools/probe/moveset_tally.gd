extends Node
## Plays seeded AI-vs-AI matches with the roster pair and tallies every move
## each man starts, by name -- the check that a wrestler's own moveset
## (Roster.Entry.moveset) is actually thrown in a match, not just wired.
##
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/moveset_tally.tscn -- --seeds 1,2,3,4,5,6 --wrestlers roman,cody

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array[int] = []
var _wrestlers := ""
var _max_ticks := 30000


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--seeds" and i + 1 < args.size():
			for t in args[i + 1].split(","):
				_seeds.append(int(t))
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--ticks" and i + 1 < args.size():
			_max_ticks = int(args[i + 1])
	if _seeds.is_empty():
		_seeds = [1, 2, 3]
	var pair := Roster.pair_from_spec(_wrestlers)
	var tally := {}
	for seed_value in _seeds:
		var scene: Node = load(MATCH_SCENE).instantiate()
		TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
		(scene.get_node("WrestlerA") as WrestlerController).is_ai = true
		add_child(scene)
		var ref: Node = scene.get_node("MatchReferee")
		var done := [false]
		var how := [""]
		ref.match_won.connect(func(_w, m): done[0] = true; how[0] = m)
		var last := {}
		var ticks := 0
		var dived := false
		while not done[0] and ticks < _max_ticks:
			await get_tree().physics_frame
			ticks += 1
			if not dived and scene.has_node("DiveSpot"):
				dived = true
				tally["cody dive spot"] = tally.get("cody dive spot", 0) + 1
			for n in ["WrestlerA", "WrestlerB"]:
				var w: WrestlerController = scene.get_node(n)
				var m: MoveDef = w._active_move
				if m == null and w._submission_hold_move:
					m = w._submission_hold_move
				if m != last.get(n) and m != null:
					var key := "%s %s" % [pair[0 if n == "WrestlerA" else 1].id, m.animation_pair_id]
					tally[key] = tally.get(key, 0) + 1
					print("  seed %d tick %d: %s" % [seed_value, ticks, key])
				last[n] = m
				# The staples: whipped, trapped in a corner, set for the Spear.
				var who: String = pair[0 if n == "WrestlerA" else 1].id
				for flag: Array in [["whipped", w.fsm.current_state == WrestlerFSM.State.IRISH_WHIP],
						["corner trapped", w.is_corner_trapped()], ["spear set-up", w._stalking]]:
					var was := "%s %s" % [n, flag[0]]
					if flag[1] and not last.get(was, false):
						tally["%s %s" % [who, flag[0]]] = tally.get("%s %s" % [who, flag[0]], 0) + 1
						print("  seed %d tick %d: %s %s" % [seed_value, ticks, who, flag[0]])
					last[was] = flag[1]
		print("seed %d: %d ticks, done=%s by %s" % [seed_value, ticks, done[0], how[0]])
		scene.queue_free()
		await get_tree().process_frame
	var keys := tally.keys()
	keys.sort()
	for k in keys:
		print("  %-44s %d" % [k, tally[k]])
	get_tree().quit()
