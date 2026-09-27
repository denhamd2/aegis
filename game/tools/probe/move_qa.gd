extends Node
## Plays every paired move through the real GrappleRig and measures the
## defects that read as amateur animation, so a QA pass is a table rather
## than 33 contact sheets looked at once.
##
## Usage:
##   godot4 --headless --path game --fixed-fps 60 tools/probe/move_qa.tscn \
##       -- [--roster] [--moves a,b,c] [--why] [--pops]
##
## --roster fights Roman vs Cody (the models a player sees) instead of the
## mannequin match.tscn falls back to.
##
## Per move, over the move and HANDOFF_TICKS after it (so the handoff into
## the knockdown or the stance is measured too):
##
##   mat     lowest bone origin, metres. Below -0.03 is a limb through the mat.
##   merge   closest approach between the two men's core bones (pelvis,
##           spine, head, thighs). Under 0.12 m is one body inside the other.
##   pop     the largest one-tick move of any bone, m/tick at 60 Hz, and the
##           tick it happened on. Over 0.20 (12 m/s) is a snap, not motion.
##   end     whether the defender finishes face-up (his chest toward the
##           lights), which is what Down_Supine plays from.
##
## Flags print on the right: MAT, MERGE, POP@t, FACEDOWN. --why adds where
## the worst of each happened; --pops lists every tick over the pop bar.

const MATCH_SCENE := "res://scenes/match.tscn"
const MOVES_DIR := "res://resources/moves"
const HANDOFF_TICKS := 40
const CORE := ["pelvis", "spine_01", "spine_02", "spine_03", "Head", "thigh_l", "thigh_r"]

var _roster := false
var _pops := false
var _only: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--roster":
			_roster = true
		elif args[i] == "--pops":
			_pops = true
		elif args[i] == "--moves" and i + 1 < args.size():
			for t: String in args[i + 1].split(","):
				_only.append(t)
	var ids: Array[String] = []
	for id: String in PairedRecipes.RECIPES:
		if _only.is_empty() or _only.has(id):
			ids.append(id)
	ids.sort()
	print("MOVE_QA %d moves%s" % [ids.size(), " (roster)" if _roster else ""])
	print("%-36s %6s %6s %12s %5s  flags" % ["move", "mat", "merge", "pop", "end"])
	for id in ids:
		await _qa(id)
	get_tree().quit()


func _move_def(id: String) -> MoveDef:
	for file in DirAccess.get_files_at(MOVES_DIR):
		if not file.ends_with(".tres"):
			continue
		var m: MoveDef = load("%s/%s" % [MOVES_DIR, file])
		if m and String(m.animation_pair_id) == id:
			return m
	return null


func _qa(id: String) -> void:
	var move := _move_def(id)
	if move == null:
		print("%-36s no MoveDef" % id)
		return
	var scene: Node = load(MATCH_SCENE).instantiate()
	if _roster:
		var pair := Roster.pair_from_spec("")
		TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = false
	b.is_ai = false
	b.global_position = a.global_position - a.global_transform.basis.z * 0.9
	a.look_at(b.global_position, Vector3.UP)
	b.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame

	# The move's own path through the controller, so resolution and the
	# handoff into DOWN or HIT_REACT are the real ones.
	a._is_grapple_attacker = true
	b._is_grapple_attacker = false
	a.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	b.fsm.transition_to(WrestlerFSM.State.TIE_UP)
	a.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	b.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	a._active_move = move
	var rig: GrappleRig = scene.get_node("GrappleRig")
	rig.begin(a, b, move)
	rig.grapple_finished.connect(a._on_grapple_finished, CONNECT_ONE_SHOT)

	var total := move.total_frames() + GrappleRig.LEAD_IN_TICKS + HANDOFF_TICKS
	var lowest := INF
	var closest := INF
	var pop := 0.0
	var pop_tick := -1
	var pop_what := ""
	var low_what := ""
	var prev := {}
	for tick in total:
		await get_tree().physics_frame
		var now := {}
		for w: WrestlerController in [a, b]:
			var sk := w.skeleton
			for i in sk.get_bone_count():
				# The importer's *_leaf end markers deform nothing and point
				# wherever the last bone's roll sends them; the root carries
				# no skin either, and jumps by design when GrappleRig hands
				# the clip's root motion back to the body at the end.
				var bone_name := sk.get_bone_name(i)
				if bone_name.contains("leaf") or bone_name == "root":
					continue
				var p := sk.global_transform * sk.get_bone_global_pose(i).origin
				var key := "%s/%s" % [w.name, sk.get_bone_name(i)]
				now[key] = p
				if p.y < lowest:
					lowest = p.y
					low_what = "%s %s t%d" % [key, WrestlerFSM.State.keys()[w.fsm.current_state],
							tick - GrappleRig.LEAD_IN_TICKS]
		# Skip the lead-in slide: it is a deliberate transform lerp.
		if tick > GrappleRig.LEAD_IN_TICKS + 1:
			var tick_pop := 0.0
			var tick_what := ""
			for k in now:
				if prev.has(k):
					var d: float = (now[k] - prev[k]).length()
					if d > tick_pop:
						tick_pop = d
						tick_what = k
					if d > pop:
						pop = d
						pop_tick = tick - GrappleRig.LEAD_IN_TICKS
						var who: WrestlerController = a if k.begins_with("WrestlerA") else b
						pop_what = "%s %s" % [k, WrestlerFSM.State.keys()[who.fsm.current_state]]
			if _pops and tick_pop > 0.20:
				print("    t%3d %.2f %s" % [tick - GrappleRig.LEAD_IN_TICKS, tick_pop, tick_what])
		prev = now
		for na: String in CORE:
			var ia := a.skeleton.find_bone(a._skeleton_bone_name(na))
			if ia < 0:
				continue
			var pa := a.skeleton.global_transform * a.skeleton.get_bone_global_pose(ia).origin
			for nb: String in CORE:
				var ib := b.skeleton.find_bone(b._skeleton_bone_name(nb))
				if ib < 0:
					continue
				var pb := b.skeleton.global_transform * b.skeleton.get_bone_global_pose(ib).origin
				closest = minf(closest, pa.distance_to(pb))

	var chest := b.skeleton.find_bone(b._skeleton_bone_name("spine_03"))
	var basis := (b.skeleton.global_transform.basis
			* b.skeleton.get_bone_global_pose(chest).basis).orthonormalized()
	# The chest's forward (+Z of spine_03 on this rig) against world up.
	var face_up := basis.z.normalized().dot(Vector3.UP)
	var down := b.fsm.current_state in [WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP]

	var flags := ""
	if lowest < -0.03:
		flags += " MAT"
	if closest < 0.12:
		flags += " MERGE"
	if pop > 0.20:
		flags += " POP@%d" % pop_tick
	if down and face_up < 0.3:
		flags += " FACEDOWN"
	print("%-36s %6.2f %6.2f %6.2f@%-5d %5s %s" % [id, lowest, closest, pop, pop_tick,
			("%+.1f" % face_up) if down else "up", flags])
	if OS.get_cmdline_user_args().has("--why"):
		print("    low: %s   pop: %s   move frames %d" % [low_what, pop_what, move.total_frames()])

	scene.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
