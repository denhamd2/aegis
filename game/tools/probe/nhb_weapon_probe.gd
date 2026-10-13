extends Node
## No Holds Barred, AI against AI, headless: does each man go and get a
## weapon, what does he pull out, does he land it, does anyone go through a
## table -- and the same again from the same seed.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/nhb_weapon_probe.tscn \
##       -- --seeds 1,2,3 [--budget 21600] [--wrestlers roman,cody]

const MATCH_SCENE := "res://scenes/match.tscn"

var _seeds: Array = [1, 2, 3]
var _budget := 21600
var _wrestlers := "roman,cody"
## --spear D: no match -- Roman's running spear into Cody standing with a
## table set up D metres behind him; where Cody lands, and the table.
var _spear := -1.0
## --give ID: hand WrestlerA weapon ID at tick 900 (after the opening lock-up).
var _give := ""
## --shots DIR: not headless -- a frame through the match's own camera a beat
## after each weapon hit and each man through a set piece (DIR/shot_NN.png).
static var shots_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--seeds": _seeds = Array(args[i + 1].split(",")).map(func(s): return int(s))
			"--budget": _budget = int(args[i + 1])
			"--wrestlers": _wrestlers = args[i + 1]
			"--spear": _spear = float(args[i + 1])
			"--give": _give = args[i + 1]
			"--shots": shots_dir = args[i + 1]
	if _spear >= 0.0:
		await _spear_through(_spear)
		get_tree().quit()
		return
	for s in _seeds:
		var r: Dictionary = await run(self, s, _budget, _wrestlers, _give)
		print("SEED %d  %s" % [s, JSON.stringify(r)])
	get_tree().quit()


## One match; returns what the weapons did. Static so a test can run it.
static func run(host: Node, seed_value: int, budget: int, wrestlers := "roman,cody", give := "") -> Dictionary:
	var scene: Node = load(MATCH_SCENE).instantiate()
	if wrestlers != "mannequin":
		var pair := Roster.pair_from_spec(wrestlers)
		TitleScreen.configure_match(scene, pair[0], pair[1], seed_value)
	scene.match_seed = seed_value
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	host.add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(seed_value, w.player_index)
			if OS.get_cmdline_user_args().has("--no-weapons"):
				w.ai._weapon_runs = WrestlerAI.WEAPON_RUNS
	var r := {"hits": [], "set_pieces": [], "pulled": [], "set_up": [], "won": "", "ticks": 0}
	var shoot_at := []                  # ticks to take a frame on
	for w: WrestlerController in [a, b]:
		w.move_landed.connect(func(by, _d, move):
			var def := WeaponCatalog.of_move(move)
			if def:
				r["hits"].append("%s:%s@%d" % [by.display_name, def.id, r["ticks"]])
				shoot_at.append(int(r["ticks"]) + 3))
		w.set_piece_landed.connect(func(who, weapon, broke):
			r["set_pieces"].append("%s:%s%s@%d" % [who.display_name, weapon.def.id, "!" if broke else "", r["ticks"]])
			shoot_at.append(int(r["ticks"]) + 2)
			shoot_at.append(int(r["ticks"]) + 40))
	r["finishers"] = []
	r["pins"] = []
	for w: WrestlerController in [a, b]:
		w.move_landed.connect(func(by, _d, move):
			if move and by.tier_of(move) == CombatSystem.Tier.FINISHER:
				r["finishers"].append("%s@%d out%s" % [by.display_name, r["ticks"], by.outside_ring]))
		w.pin_started.connect(func(att, _def): r["pins"].append("%s@%d" % [att.display_name, r["ticks"]]))
	referee.match_won.connect(func(winner, method): r["won"] = "%s by %s" % [winner.display_name if winner else "-", method])
	var seen := {}
	# --render-at T,T,...: draw only around those ticks (the rest is
	# simulated undrawn -- a software-rendered arena runs at ~1 fps)
	var windows: Array = []
	var args := OS.get_cmdline_user_args()
	var ri := args.find("--render-at")
	if ri >= 0 and ri + 1 < args.size():
		windows = Array(args[ri + 1].split(",")).map(func(x): return int(x))
		RenderingServer.render_loop_enabled = false
	for t in budget:
		if not windows.is_empty():
			var on := false
			for w: int in windows:
				on = on or (t >= w - 30 and t <= w + 60)
			RenderingServer.render_loop_enabled = on
		await host.get_tree().physics_frame
		r["ticks"] = t
		if give != "" and t == 900:
			var g := WeaponStock.of(a).pull(WeaponCatalog.by_id(StringName(give)))
			g.global_transform = WeaponActor.grip_frame(a) * g.marker("grip_r").affine_inverse()
			a.take_weapon(g)
			r["given"] = "%s in state %d" % [give, a.fsm.current_state]
		var stock := scene.get_node_or_null("WeaponStock") as WeaponStock
		if stock:
			for actor in stock.actors:
				if is_instance_valid(actor) and not seen.has(actor):
					seen[actor] = true
					r["pulled"].append("%s@%d" % [actor.def.id, t])
				if is_instance_valid(actor) and actor.mode == WeaponActor.Mode.SET_UP and not seen.has([actor]):
					seen[[actor]] = true
					r["set_up"].append("%s@%d" % [actor.def.id, t])
		if give != "" and OS.get_cmdline_user_args().has("--trace"):
			var st := scene.get_node_or_null("WeaponStock") as WeaponStock
			var pcs: Array = st.set_up_pieces() if st else []
			if not pcs.is_empty() and t % 30 == 0:
				var tb: WeaponActor = pcs[0]
				print("T %d  rc %d plan %d  A %s st%d charge %s  B %s st%d  B-table %.2f  out %s/%s" % [t, a.ai._run_cooldown, a.ai._weapon_plan,
						a.global_position.snappedf(0.1), a.fsm.current_state, a.ai._charging,
						b.global_position.snappedf(0.1), b.fsm.current_state,
						Vector2(b.global_position.x - tb.global_position.x, b.global_position.z - tb.global_position.z).length(),
						a.outside_ring, b.outside_ring])
		if OS.get_cmdline_user_args().has("--state") and t % 600 == 0:
			print("S %d  A st%d plan%d out%s wear%.0f fin%s held%s | B st%d plan%d out%s wear%.0f fin%s held%s" % [t,
					a.fsm.current_state, a.ai._weapon_plan, a.outside_ring, a.combat.wear, a.combat.can_finisher(),
					a.held_weapon.def.id if a.has_weapon() else "-",
					b.fsm.current_state, b.ai._weapon_plan, b.outside_ring, b.combat.wear, b.combat.can_finisher(),
					b.held_weapon.def.id if b.has_weapon() else "-"])
		if shots_dir != "" and shoot_at.has(t) and RenderingServer.render_loop_enabled:
			await RenderingServer.frame_post_draw
			var n := DirAccess.get_files_at(shots_dir).size() if DirAccess.dir_exists_absolute(shots_dir) else 0
			DirAccess.make_dir_recursive_absolute(shots_dir)
			host.get_viewport().get_texture().get_image().save_png("%s/shot_%02d_t%d.png" % [shots_dir, n, t])
		if r["won"] != "":
			break
	r["runs"] = [a.ai.weapon_runs_started if a.ai else 0, b.ai.weapon_runs_started if b.ai else 0]
	r["swings"] = [a.ai.weapon_swings_thrown if a.ai else 0, b.ai.weapon_swings_thrown if b.ai else 0]
	scene.queue_free()
	await host.get_tree().process_frame
	return r


func _spear_through(d: float) -> void:
	var scene: Node = load(MATCH_SCENE).instantiate()
	var pair := Roster.pair_from_spec("roman,cody")
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(scene)
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var cody: WrestlerController = scene.get_node("WrestlerB")
	(scene.get_node("MatchReferee") as MatchReferee)._tying_up = false
	for w: WrestlerController in [roman, cody]:
		w.is_ai = false
		w.fsm.transition_to(WrestlerFSM.State.IDLE)
	roman.global_position = Vector3(0.0, 0.0, 1.0)
	cody.global_position = Vector3(0.0, 0.0, 0.0)
	roman.look_at(Vector3(0.0, 0.0, -5.0), Vector3.UP)
	cody.look_at(Vector3(0.0, 0.0, 5.0), Vector3.UP)
	for t in 10:
		await get_tree().physics_frame
	var table := WeaponStock.of(cody).pull(WeaponCatalog.by_id(&"table"))
	table.set_up_at(Vector3(0.0, 0.0, -d), 0.0)
	var move := roman._pick_tier_move(roman.running_attack_move, roman.running_attack_move_pool)
	print("SPEAR move %s paired %s" % [move.resource_path.get_file() if move else "-", roman._can_run_into_paired(move)])
	roman.fsm.transition_to(WrestlerFSM.State.RUN)
	roman._begin_running_paired(move)
	var landed := [""]
	cody.set_piece_landed.connect(func(_w, _a, b): landed[0] = "broke" if b else "landed")
	for t in 240:
		await get_tree().physics_frame
		if t % 20 == 0 or cody.fsm.current_state == WrestlerFSM.State.DOWN and landed[0] == "":
			pass
		if cody.fsm.current_state == WrestlerFSM.State.DOWN and t % 10 == 0:
			print("t %d cody DOWN root %s pelvis %s table %s" % [t, cody.global_position.snappedf(0.01),
					cody._bone_world("pelvis").snappedf(0.01), landed[0]])
	print("SPEAR d %.2f -> %s" % [d, landed[0]])
