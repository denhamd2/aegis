extends Node
## Is Roman's walk drawn smoothly between physics ticks? Runs the entrance from
## his walk down the ramp at --fixed-fps 120 (two drawn frames per 60 Hz tick)
## and counts the drawn frames on which his hand and his root did not move --
## a held pose, the "stop motion" the owner saw on a 120 Hz Mac.
##
##   godot4 --headless --path game --fixed-fps 120 tools/probe/motion_cadence.tscn
##   add `-- --rough` to measure with the smoothing turned off, for comparison,
##   and `-- --who cody` to measure Cody's walk instead.
##   `-- --match` measures the match instead: an AI-vs-AI match from the bell,
##   both men, the hand read as DRAWN (a recorder at the end of the bone
##   stack, after every modifier) rather than as the clip left it.

const FRAMES := 240


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var rough := "--rough" in args
	if "--match" in args:
		await _match(rough)
		return
	var who := "roman"
	if "--who" in args and args.find("--who") + 1 < args.size():
		who = args[args.find("--who") + 1]
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 3)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var roman: WrestlerController = null
	for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		if w.entrance_style == who:
			roman = w
	for i in director._beats.size():
		var bt: Dictionary = director._beats[i]
		if bt.get("who") == roman and bt.get("kind") == "walk" and bt.get("shot", "") in ["steadicam_low", "steadicam_front"] \
				and bt.get("path", [Vector3.ZERO])[0].z > ArenaBuilder.STAGE_FRONT:
			roman.visible = true
			roman.global_position = bt["path"][0]
			director._beat = i
			director._start_beat()
			break
	if rough:
		for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
			w.set_presentation_rate(false)
			w.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var skeleton: Skeleton3D = roman.find_child("Skeleton3D", true, false)
	var hand := skeleton.find_bone("J_Wrist_L")
	if hand < 0:
		hand = skeleton.find_bone("hand_l")
	for _i in 30:
		await get_tree().process_frame
	var held_hand := 0
	var held_root := 0
	var last_hand := Vector3.INF
	var last_root := Vector3.INF
	for _i in FRAMES:
		await get_tree().process_frame
		var root := roman.get_global_transform_interpolated().origin
		var h := skeleton.get_bone_global_pose(hand).origin
		if last_hand != Vector3.INF and h.distance_to(last_hand) < 1e-6:
			held_hand += 1
		if last_root != Vector3.INF and root.distance_to(last_root) < 1e-6:
			held_root += 1
		last_hand = h
		last_root = root
	print("MOTION_CADENCE who=%s rough=%s frames=%d held_hand=%d held_root=%d" % [
			who, rough, FRAMES, held_hand, held_root])
	get_tree().quit()


## Reads a bone where it is drawn: last in the skeleton's modifier stack, so
## after the Inertializer, the IK and everything else has had its say.
##
## The stack runs twice on a frame with a physics tick -- once as the mixer
## applies in the tick, once at idle before the frame is drawn -- and only the
## second is drawn. So it keeps the last value each frame, and frames are
## compared after the run: read from a script mid-frame, the tick's pose
## showed a frame early and the frame after it counted as held.
class DrawnBone extends SkeletonModifier3D:
	var bone := -1
	## Process frame -> where the bone was last put that frame.
	var by_frame := {}

	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk and bone >= 0:
			by_frame[Engine.get_process_frames()] = sk.get_bone_global_pose(bone).origin


func _match(rough: bool) -> void:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 3)
	scene.match_seed = 3
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var recorders: Array[DrawnBone] = []
	for w: WrestlerController in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		w.is_ai = true
		if rough:
			w.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
			if w.inertializer:
				w.inertializer.interpolate_pose = false
		var skeleton: Skeleton3D = w.skeleton
		for name: String in ["hand_r", "head"]:
			var rec := DrawnBone.new()
			rec.bone = skeleton.find_bone(w._skeleton_bone_name(name))
			skeleton.add_child(rec)
			recorders.append(rec)
	# Into the match, past the opening: the men are moving.
	for _i in 600:
		await get_tree().process_frame
	var first := Engine.get_process_frames()
	for _i in FRAMES + 1:
		await get_tree().process_frame
	var held := [0, 0, 0, 0]
	for k in 4:
		var seen: Dictionary = recorders[k].by_frame
		for f in range(first + 1, first + FRAMES + 1):
			if seen.has(f) and seen.has(f - 1) and (seen[f] as Vector3).distance_to(seen[f - 1]) < 1e-6:
				held[k] += 1
	print("MOTION_CADENCE match rough=%s frames=%d held_a hand=%d head=%d  held_b hand=%d head=%d" % [
			rough, FRAMES, held[0], held[1], held[2], held[3]])
	get_tree().quit()
