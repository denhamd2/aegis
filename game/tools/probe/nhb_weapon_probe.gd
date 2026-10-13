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


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--seeds": _seeds = Array(args[i + 1].split(",")).map(func(s): return int(s))
			"--budget": _budget = int(args[i + 1])
			"--wrestlers": _wrestlers = args[i + 1]
	for s in _seeds:
		var r: Dictionary = await run(self, s, _budget, _wrestlers)
		print("SEED %d  %s" % [s, JSON.stringify(r)])
	get_tree().quit()


## One match; returns what the weapons did. Static so a test can run it.
static func run(host: Node, seed_value: int, budget: int, wrestlers := "roman,cody") -> Dictionary:
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
	var r := {"hits": [], "set_pieces": [], "pulled": [], "won": "", "ticks": 0}
	for w: WrestlerController in [a, b]:
		w.move_landed.connect(func(by, _d, move):
			var def := WeaponCatalog.of_move(move)
			if def:
				r["hits"].append("%s:%s@%d" % [by.display_name, def.id, r["ticks"]]))
		w.set_piece_landed.connect(func(who, weapon, broke):
			r["set_pieces"].append("%s:%s%s@%d" % [who.display_name, weapon.def.id, "!" if broke else "", r["ticks"]]))
	referee.match_won.connect(func(winner, method): r["won"] = "%s by %s" % [winner.display_name if winner else "-", method])
	var seen := {}
	for t in budget:
		await host.get_tree().physics_frame
		r["ticks"] = t
		var stock := scene.get_node_or_null("WeaponStock") as WeaponStock
		if stock:
			for actor in stock.actors:
				if is_instance_valid(actor) and not seen.has(actor):
					seen[actor] = true
					r["pulled"].append("%s@%d" % [actor.def.id, t])
		if r["won"] != "":
			break
	r["runs"] = [a.ai.weapon_runs_started if a.ai else 0, b.ai.weapon_runs_started if b.ai else 0]
	r["swings"] = [a.ai.weapon_swings_thrown if a.ai else 0, b.ai.weapon_swings_thrown if b.ai else 0]
	scene.queue_free()
	await host.get_tree().process_frame
	return r
