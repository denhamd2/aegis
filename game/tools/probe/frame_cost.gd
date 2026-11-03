extends Node
## What the game's own code costs a frame, with no GPU in it: an AI-vs-AI
## match headless, Roman v Cody, one physics tick a frame, the engine's
## process and physics-process times read every frame (the owner, 3 Nov:
## "is this my machine performance limits, our animations or something
## else?"). 60 fps leaves 16.7 ms a frame for everything; what this prints is
## the share the scripts take before a single pixel is drawn.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/frame_cost.tscn \
##       -- --seconds 120 --seed 3
##
## Prints the average, the 95th and 99th percentile and the worst frame, for
## process (frame scripts, skeleton modifiers), physics (the match's tick) and
## both together, and how many frames went over 8 ms of script time.

const MATCH_SCENE := "res://scenes/match.tscn"


func _ready() -> void:
	var seconds := 120
	var seed_value := 3
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--seconds": seconds = int(args[i + 1])
			"--seed": seed_value = int(args[i + 1])
	var scene: Node = load(MATCH_SCENE).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		w.is_ai = true
	var proc: Array[float] = []
	var phys: Array[float] = []
	var both: Array[float] = []
	# skip the first second: loading and first use
	for i in 60:
		await get_tree().process_frame
	for i in seconds * 60:
		await get_tree().process_frame
		var p := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var f := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc.append(p)
		phys.append(f)
		both.append(p + f)
	for row: Array in [["process", proc], ["physics", phys], ["both", both]]:
		var v: Array = (row[1] as Array).duplicate()
		v.sort()
		var n := v.size()
		var avg := 0.0
		for x: float in v:
			avg += x
		avg /= float(n)
		print("FRAME_COST %-8s avg %5.2f ms  p95 %5.2f  p99 %5.2f  worst %6.2f" % [row[0], avg,
				v[int(n * 0.95)], v[int(n * 0.99)], v[n - 1]])
	var over := both.filter(func(x: float) -> bool: return x > 8.0).size()
	print("FRAME_COST frames over 8 ms of script: %d of %d" % [over, both.size()])
	get_tree().quit()
