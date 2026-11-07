extends Node
## Isolate the real rebound/return controller at fixed positions. No arena,
## AI lottery or renderer: compare attack arrival and failed-opportunity speed.

func _ready() -> void:
	var rows: Array[Dictionary] = []
	for spec in [["near", Vector3(-0.5, 0, 0), false, Vector3(3, 0, 0)],
			["far", Vector3(-2.6, 0, -2.6), false, Vector3(3, 0, 2.3)],
			["down", Vector3(-0.5, 0, 0), true, Vector3(3, 0, 0)]]:
		var runner := WrestlerController.new()
		var target := WrestlerController.new()
		for man in [runner, target]:
			add_child(man)
			man.set_physics_process(false)
			man.fsm = WrestlerFSM.new()
			man.combat = CombatSystem.new()
		runner.opponent = target
		target.opponent = runner
		runner.running_attack_move = load("res://resources/moves/running_attack_clothesline.tres")
		target.position = spec[1]
		target.fsm.current_state = WrestlerFSM.State.DOWN if spec[2] else WrestlerFSM.State.IDLE
		runner.rope_running = true
		runner._irish_whip_target = target
		runner._rope_load_tick = 100
		runner._rope_load_speed = WrestlerController.RUN_SPEED
		runner._rope_load_from = spec[3]
		runner._rope_load_out = Vector3.RIGHT
		runner.fsm.current_state = WrestlerFSM.State.IRISH_WHIP
		runner._tick_rope_load()
		var row := {"case": spec[0], "result": "expired", "ticks": 0}
		for tick in 100:
			if not runner.is_whip_returning():
				break
			var gap := runner.position.distance_to(target.position)
			runner._process_irish_whip_return({"strike": gap <= WrestlerController.STRIKE_HIT_RANGE + 0.4})
			row["ticks"] = tick + 1
			if runner.fsm.current_state == WrestlerFSM.State.RUNNING_ATTACK:
				row["result"] = "attack"
				break
			if runner.fsm.current_state != WrestlerFSM.State.RUN:
				row["result"] = "recovered"
				break
			runner.position += runner.velocity / 60.0
		row["end_speed"] = runner.velocity.length()
		rows.append(row)
		runner.fsm.free()
		target.fsm.free()
		runner.free()
		target.free()
	var output := "/tmp/aegis-rope-return.json"
	var args := OS.get_cmdline_user_args()
	if args.has("--out"):
		output = args[args.find("--out") + 1]
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(rows, "\t"))
	print(JSON.stringify(rows))
	get_tree().quit()
