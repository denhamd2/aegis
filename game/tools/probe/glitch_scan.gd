extends Node
## Scans seeded AI matches for the two glitches seen in the e2e recording:
##
##   SLIDE  a man who is on the mat (DOWN / PIN_DEFENDER / GETUP /
##          SUBMISSION_DEFENDER) travelling across it faster than SLIDE_SPEED
##          for SLIDE_TICKS or more -- a body skating, not a move carrying it;
##   AWAY   both men upright and close, each with his back half-turned to the
##          other, for AWAY_TICKS or more.
##
## Each hit prints the tick, both states, the move in play, the distance moved
## and which way everyone faced, so the cause can be read off the log.
##
##   godot4 --headless --path game --fixed-fps 6000 tools/probe/glitch_scan.tscn \
##       [-- --seeds 1,2,3,4 --budget 20000]

const SLIDE_SPEED := 0.6
const SLIDE_TICKS := 6
const AWAY_TICKS := 30
const AWAY_DIST := 3.0
const ON_MAT := [WrestlerFSM.State.DOWN, WrestlerFSM.State.PIN_DEFENDER,
		WrestlerFSM.State.GETUP, WrestlerFSM.State.SUBMISSION_DEFENDER]
const UPRIGHT := [WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION,
		WrestlerFSM.State.RUN, WrestlerFSM.State.STRIKE, WrestlerFSM.State.HIT_REACT,
		WrestlerFSM.State.STUNNED, WrestlerFSM.State.TAUNT]

var _seeds: Array[int] = []
var _budget := 20000


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seeds":
				for t in args[i + 1].split(","):
					_seeds.append(int(t))
			"--budget": _budget = int(args[i + 1])
	if _seeds.is_empty():
		_seeds = [1, 2, 3, 4]
	var pair := Roster.pair_from_spec("")
	var total := {"slide": 0, "away": 0}
	for s in _seeds:
		var r := await _run(s, pair)
		total["slide"] += r["slide"]
		total["away"] += r["away"]
		print("SCAN seed %d: %d ticks, %d slides, %d face-aways, %s" % [s, r["ticks"], r["slide"], r["away"], r["end"]])
	print("SCAN_DONE slides %d, face-aways %d" % [total["slide"], total["away"]])
	get_tree().quit()


static func _body_forward(w: WrestlerController) -> Vector3:
	var l: Vector3 = w._bone_world("upperarm_l")
	var r: Vector3 = w._bone_world("upperarm_r")
	if l == Vector3.INF or r == Vector3.INF:
		return -w.global_basis.z
	var f := Vector3.UP.cross(r - l)
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else -w.global_basis.z


static func _name(state: int) -> String:
	return WrestlerFSM.State.keys()[state]


static func _move(w: WrestlerController) -> String:
	var m: MoveDef = w._active_move
	return "-" if m == null else String(m.resource_path).get_file().get_basename()


func _run(seed_value: int, pair: Array) -> Dictionary:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
	scene.match_seed = seed_value
	add_child(scene)
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	var referee: MatchReferee = scene.get_node("MatchReferee")
	var r := {"ticks": 0, "slide": 0, "away": 0, "end": "no finish"}
	var over := [false]
	referee.match_won.connect(func(w, m): over[0] = true; r["end"] = "%s by %s" % [w.name, m])
	for w in ws:
		w.is_ai = true
	var last := [ws[0].global_position, ws[1].global_position]
	var run := [0, 0]
	var run_from := [Vector3.ZERO, Vector3.ZERO]
	var run_states := [[], []]
	var away_run := 0
	var prev_state := [0, 0]
	var run_detail := ["", ""]
	var dt := 1.0 / Engine.physics_ticks_per_second
	while r["ticks"] < _budget and not over[0]:
		await get_tree().physics_frame
		r["ticks"] += 1
		for i in 2:
			var w := ws[i]
			var p := w.global_position
			var v := Vector3(p.x - last[i].x, 0, p.z - last[i].z) / dt
			var st: int = w.fsm.current_state
			if ON_MAT.has(st) and v.length() > SLIDE_SPEED:
				if run[i] == 0:
					run_from[i] = last[i]
					run_states[i] = []
					run_detail[i] = "prev=%s vel=%s knock=%d y=%.2f rope=%s cover=%s" % [_name(prev_state[i]),
							str(w.velocity.snapped(Vector3.ONE * 0.01)), w._knockback_ticks, p.y,
							str(w._rope_load_body), str(w._cover_partner)]
				run[i] += 1
				var tag := "%s/%s" % [_name(st), _move(w)]
				if not run_states[i].has(tag):
					run_states[i].append(tag)
			else:
				if run[i] >= SLIDE_TICKS:
					r["slide"] += 1
					var o := ws[1 - i]
					print("  SLIDE t=%d %s %d ticks %.2fm %s | other %s/%s grapple=%s" % [
							r["ticks"], w.name, run[i], (p - run_from[i]).length(),
							", ".join(run_states[i]), _name(o.fsm.current_state), _move(o),
							str(w.get("_grapple_locked"))])
					print("      start: ", run_detail[i])
				run[i] = 0
			last[i] = p
			prev_state[i] = st
		# Facing: the controller's forward (-Z) against the other man.
		var both_up: bool = UPRIGHT.has(ws[0].fsm.current_state) and UPRIGHT.has(ws[1].fsm.current_state)
		var d := ws[1].global_position - ws[0].global_position
		d.y = 0
		# Which way the BODY faces, off the shoulders -- the model can be
		# turned away from its controller, and that is what a viewer sees.
		var f0 := _body_forward(ws[0])
		var f1 := _body_forward(ws[1])
		var away := both_up and d.length() < AWAY_DIST and d.length() > 0.2 \
				and f0.dot(d.normalized()) < -0.2 and f1.dot(-d.normalized()) < -0.2
		if away:
			away_run += 1
		else:
			if away_run >= AWAY_TICKS:
				r["away"] += 1
				print("  AWAY t=%d for %d ticks, dist %.2f, states %s/%s %s/%s ctrl-vs-body A %.2f B %.2f" % [
						r["ticks"], away_run, d.length(), _name(ws[0].fsm.current_state), _move(ws[0]),
						_name(ws[1].fsm.current_state), _move(ws[1]),
						(-ws[0].global_basis.z).dot(f0), (-ws[1].global_basis.z).dot(f1)])
			away_run = 0
	scene.queue_free()
	await get_tree().process_frame
	return r
