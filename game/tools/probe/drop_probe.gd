extends Node
## Where a paired move puts the man it throws: his hips, in the thrower's
## starting frame (x to the thrower's right, fwd in front of him), at their
## lowest and at the fastest point of the fall -- the numbers a set-piece spot
## stands the table by (WrestlerAI's SUPLEX_DROP, POWERBOMB_DROP). Run
## headless:
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/drop_probe.tscn \
##       -- --move ff/powerbomb_1 --wrestlers roman,cody
##
## A wrapper scene rather than a `-s` script, so the project's class_name
## globals and autoloads are there (ladder_probe.gd).

const MATCH_SCENE := "res://scenes/match.tscn"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var move_id := "grapple_vertical_suplex"
	var wrestlers := ""
	# --desk: out on the floor at the announce desk, lined up as WrestlerAI
	# does (the powerbomb facing it, the suplex with his back to it), in No
	# Holds Barred: where his hips cross the worktop, and whether it broke.
	var desk := args.has("--desk")
	# --sep: every 6 ticks, how far the runtime separation has moved each
	# man's model and the deepest pair of segments touching (PairClearance).
	var sep := args.has("--sep")
	for i in args.size() - 1:
		match args[i]:
			"--move": move_id = args[i + 1]
			"--wrestlers": wrestlers = args[i + 1]
	var scene: Node = load(MATCH_SCENE).instantiate()
	if wrestlers != "":
		var pair := Roster.pair_from_spec(wrestlers)
		if pair.size() == 2:
			TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var d: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = false
	d.is_ai = false
	# Squared up at grapple distance, as a tie-up leaves them (paired_shot.gd).
	d.global_position = a.global_position - a.global_transform.basis.z * 0.9
	if desk:
		var bomb := move_id.contains("powerbomb")
		var landing := Vector3(ArenaBuilder.DESK_X, WrestlerController.FLOOR_LEVEL, ArenaBuilder.DESK_Z)
		for w: WrestlerController in [a, d]:
			MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
			w.outside_ring = true
		a.global_position = landing - Vector3(0.0, 0.0, WrestlerAI.POWERBOMB_DROP if bomb else WrestlerAI.SUPLEX_DROP)
		d.global_position = a.global_position + Vector3(0.0, 0.0, 0.55 if bomb else -0.9)
	a.look_at(d.global_position, Vector3.UP)
	d.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame
	if desk:
		# the match's stock, there from the bell as in a match (match_setup):
		# it is what watches a thrown man come down on the desk
		WeaponStock.of(d)
		print("DESK lined up: attacker z %.2f, defender z %.2f" % [a.global_position.z, d.global_position.z])
	var origin := a.global_position
	var basis := a.global_transform.basis
	var move: MoveDef = load("res://resources/moves/%s.tres" % move_id)
	var rig: Node = scene.get_node("GrappleRig")
	a._is_grapple_attacker = true
	d._is_grapple_attacker = false
	a.opponent = d
	d.opponent = a
	a.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	d.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	# the move's end handed to his controller, as a match does
	a._active_move = move
	rig.begin(a, d, move)
	rig.grapple_finished.connect(a._on_grapple_finished, CONNECT_ONE_SHOT)
	var lowest := INF
	var low_at := Vector3.ZERO
	var fastest := 0.0
	var fast_at := Vector3.ZERO
	var was := INF
	# Where his hips come down through a table's top (0.74 m; WeaponCatalog's
	# table) in the fall: the fastest of the crossings on the way down (bent
	# over for the lift, his hips dip below it at a walk first).
	var top := 0.8
	var through := Vector3.INF
	var through_speed := 0.0
	var state := -1
	for t in int(move.total_frames()) + int(rig.get("lead_in_ticks")) + 30:
		await get_tree().physics_frame
		if desk and d.fsm.current_state != state:
			state = d.fsm.current_state
			print("  t%d defender state %d, down ticks %d, bonus %d" % [t, state, d._move_ticks_remaining, d._down_bonus])
		var hips := d._bone_world("pelvis")
		if hips == Vector3.INF:
			continue
		if sep and t % 6 == 0:
			var dp := PairClearance.depth(a, d)
			var hrel := hips - origin
			print("  t%3d  sepD %s  sepA %s  hips y %.2f fwd %.2f  body %.3f arm %.3f %s" % [t,
					d.paired_separation.snapped(Vector3.ONE * 0.01), a.paired_separation.snapped(Vector3.ONE * 0.01),
					hips.y, -hrel.dot(basis.z), dp["body"], dp["arm"], dp["where"]])
			print("        push %s  release %d  grip %.2f  pulls %s" % [PairClearance.push(a, d).snapped(Vector3.ONE * 0.001),
					a._paired_release_ticks, a._grip_blend, PairedContacts.pulls(move)])
		var rel := hips - origin
		var at := Vector3(rel.dot(basis.x), hips.y, -rel.dot(basis.z))
		if was != INF and hips.y < 1.2 and (was - hips.y) * 60.0 > fastest:
			fastest = (was - hips.y) * 60.0
			fast_at = at
		if was != INF and was >= top and hips.y < top and (was - hips.y) * 60.0 > through_speed:
			through_speed = (was - hips.y) * 60.0
			through = at
		if desk and was != INF and (was - hips.y) * 60.0 > 0.8 and hips.y < WeaponStock.desk_top_y() + 0.3:
			print("  t%d hips y %.2f z %.2f (desk %.2f..%.2f) peak %.2f thrown %s under %s broken %s" % [t, hips.y,
					hips.z, ArenaBuilder.DESK_Z - ArenaBuilder.DESK_DEPTH * 0.5, ArenaBuilder.DESK_Z
					+ ArenaBuilder.DESK_DEPTH * 0.5, d._hips_peak, rig.defender() == d,
					WeaponStock.of(d).desk_under(hips), WeaponStock.of(d).desk_broken])
		was = hips.y
		if hips.y < lowest:
			lowest = hips.y
			low_at = at
	if desk:
		# and how long he stays down in the wreck: the whole stay in DOWN,
		# read the tick before he leaves it
		for t in 600:
			var was_in := d.fsm.ticks_in_state
			var hold := d._through_hold
			var in_down := d.fsm.current_state == WrestlerFSM.State.DOWN
			await get_tree().physics_frame
			if in_down and d.fsm.current_state != WrestlerFSM.State.DOWN:
				print("DESK down %.1f s in the wreck (hold %d ticks), then state %d"
						% [(was_in + 1) / 60.0, hold, d.fsm.current_state])
				break
	print("DROP %s: hips lowest %.2f m at x %.2f, fwd %.2f; fastest fall %.1f m/s at x %.2f, height %.2f, fwd %.2f; through %.2f m at x %.2f, fwd %.2f"
			% [move_id, lowest, low_at.x, low_at.z, fastest, fast_at.x, fast_at.y, fast_at.z,
			top, through.x, through.z])
	get_tree().quit()
