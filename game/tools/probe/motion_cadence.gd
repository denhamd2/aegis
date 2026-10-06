extends Node
## Is Roman's walk drawn smoothly between physics ticks? Runs the entrance from
## his walk down the ramp at --fixed-fps 120 (two drawn frames per 60 Hz tick)
## and counts the drawn frames on which his hand and his root did not move --
## a held pose, the "stop motion" the owner saw on a 120 Hz Mac.
##
##   godot4 --headless --path game --fixed-fps 120 tools/probe/motion_cadence.tscn
##   add `-- --rough` to measure with the smoothing turned off, for comparison.

const FRAMES := 240


func _ready() -> void:
	var rough := "--rough" in OS.get_cmdline_user_args()
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
		if w.entrance_style == "roman":
			roman = w
	for i in director._beats.size():
		var bt: Dictionary = director._beats[i]
		if bt.get("who") == roman and bt.get("kind") == "walk" and bt.get("shot", "") == "steadicam_low":
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
	print("MOTION_CADENCE rough=%s frames=%d held_hand=%d held_root=%d" % [
			rough, FRAMES, held_hand, held_root])
	get_tree().quit()
