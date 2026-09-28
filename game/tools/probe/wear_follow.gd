extends Node
## Does what he wears follow his body through the modifiers? Roman is rigged
## on two skeletons -- body and head on one, bottoms, shoes, hair, beard and
## wrist tape on the other -- and both play the same clip. Anything that bends
## the body AFTER the clip (grip IK, FootPlant, Inertializer) bends only the
## first unless something carries it across.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/wear_follow.tscn \
##       [-- --moves grapple_vertical_suplex,running_spear]
##
## Prints, per move, the furthest the worn skeleton's hand and foot sat from
## the body's, as drawn.

const BONES := ["hand_l", "hand_r", "foot_l", "foot_r", "Head"]


func _ready() -> void:
	var moves := ["grapple_vertical_suplex", "running_spear", "power_bodyslam"]
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--moves":
			moves = Array(args[i + 1].split(","))
	var worst_all := 0.0
	for move_id: String in moves:
		var r := await _measure(move_id)
		worst_all = maxf(worst_all, r["worst"])
		print("WEAR %-30s worst %.3f m  (%s)" % [move_id, r["worst"], r["where"]])
	print("WEAR_DONE worst %.3f m" % worst_all)
	get_tree().quit()


func _measure(move_id: String) -> Dictionary:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var d: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, d]:
		w.is_ai = false
	d.global_position = a.global_position - a.global_transform.basis.z * 1.2
	a.look_at(d.global_position, Vector3.UP)
	d.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame
	var body := a.skeleton
	var worn: Skeleton3D = null
	for s: Skeleton3D in a.find_children("", "Skeleton3D", true, false):
		if s != body and s.find_bone("J_Hips") >= 0:
			worn = s
	var drawn := [{}, {}]
	var model := a.anim_player.get_parent()
	for pair: Array in [[body, 0], [worn, 1]]:
		var sk: Skeleton3D = pair[0]
		var slot: Dictionary = drawn[pair[1]]
		sk.skeleton_updated.connect(func() -> void:
			for b: String in BONES:
				var id := sk.find_bone(model.game_bone_name(b))
				if id >= 0:
					slot[b] = sk.global_transform * sk.get_bone_global_pose(id).origin)
	var rig: GrappleRig = scene.get_node("GrappleRig")
	a._is_grapple_attacker = true
	d._is_grapple_attacker = false
	a.opponent = d
	d.opponent = a
	a.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	d.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	rig.begin(a, d, load("res://resources/moves/%s.tres" % move_id))
	var r := {"worst": 0.0, "where": ""}
	for tick in 120:
		await get_tree().physics_frame
		await get_tree().process_frame
		for b: String in BONES:
			if drawn[0].has(b) and drawn[1].has(b):
				var gap: float = (drawn[0][b] as Vector3).distance_to(drawn[1][b])
				if gap > r["worst"]:
					r["worst"] = gap
					r["where"] = "%s t%d" % [b, tick]
	scene.queue_free()
	await get_tree().process_frame
	return r
