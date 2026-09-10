extends Node
## Finds which strike clip floats, and on which frames.
##
## gauntlet/status/roman_reigns_next.md carries this defect measured but not
## fixed: at ticks 150 and 160 in STRIKE the whole skeleton bunches between
## 1.5 m and 1.9 m with the HEAD as the lowest joint, while the controller root
## sits on the mat and reports is_on_floor(). A body floating horizontally at
## chest height. Ticks 140 and 200 are also STRIKE and are correct, so it is
## specific frames of specific clips -- and nothing named which.
##
## head_y < hips_y is the test, because that is the signature in the table: a
## standing man's head is never below his hips, whatever he is doing with his
## arms.
##
## Run it against BOTH rigs. That is the bisection the last pass skipped:
##   scenes/match.tscn        base mannequin, clips used as generated
##   scenes/roman_match.tscn  same clips after RomanModel's retarget
## bad on both  -> the baked mocap excerpt is at fault
## bad on Roman only -> it is still the retarget for these clips
## The status doc concluded the former, but by inference rather than by
## measuring it, which is why these frames are still open.
##
## Usage:
##   godot4 --headless --path game --fixed-fps 6000 \
##       tools/probe/strike_clip_probe.tscn -- --scene res://scenes/match.tscn

## Whichever name each rig uses for the joints the test needs.
const HEAD_BONES := ["Head", "J_Head", "head"]
const HIPS_BONES := ["pelvis", "J_Hips", "hips", "Hips"]

var _scene_path := "res://scenes/match.tscn"
var _moves_dir := "res://resources/moves"
## When set, the worst frame of each clip is saved here. The status doc is
## explicit that "the numbers can say 'wrong', but only footage says which clip
## and which frames".
var _out := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--scene" and i + 1 < args.size():
			_scene_path = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
			DirAccess.make_dir_recursive_absolute(_out)

	var scene: Node = load(_scene_path).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var w: WrestlerController = scene.get_node("WrestlerA")
	var other: WrestlerController = scene.get_node("WrestlerB")
	w.is_ai = false
	other.is_ai = false
	# Well clear, so nothing this wrestler does can be interrupted by a hit --
	# an interrupted strike stops early and would hide the frames being hunted.
	other.global_position = w.global_position + Vector3(0.0, 0.0, 14.0)
	for frame in 20:
		await get_tree().physics_frame

	var skeleton: Skeleton3D = w.find_child("Skeleton3D", true, false)
	if skeleton == null:
		print("!! no Skeleton3D on the wrestler")
		get_tree().quit(1)
		return
	var head := _find_bone(skeleton, HEAD_BONES)
	var hips := _find_bone(skeleton, HIPS_BONES)
	if head < 0 or hips < 0:
		print("!! could not find head/hips bones in: %s" % [_bone_names(skeleton)])
		get_tree().quit(1)
		return

	print("=== strike clip probe: %s ===" % _scene_path)
	# Control first. If IDLE does not put the head well above the hips then the
	# measurement is broken, not the clips -- and this session has already had
	# two probes that confidently measured the wrong thing.
	w.fsm.transition_to(WrestlerFSM.State.IDLE)
	for frame in 10:
		await get_tree().physics_frame
	var idle_head: float = (skeleton.global_transform
			* skeleton.get_bone_global_pose(head).origin).y
	var idle_hips: float = (skeleton.global_transform
			* skeleton.get_bone_global_pose(hips).origin).y
	print("  CONTROL idle: head %.3f  hips %.3f  (head above hips: %s)"
			% [idle_head, idle_hips, idle_head > idle_hips])
	var any_bad := false
	for move in _strike_moves():
		var bad := await _run_clip(w, skeleton, head, hips, move)
		any_bad = any_bad or bad
	print("VERDICT %s" % ("FLOATING FRAMES FOUND" if any_bad else "every strike clip keeps the head above the hips"))
	get_tree().quit()


func _strike_moves() -> Array:
	var moves: Array = []
	var dir := DirAccess.open(_moves_dir)
	for file in dir.get_files():
		var name := file.get_basename()
		# running_* too: they are played in a different state, but this is a
		# test of the CLIP, and running_double_leg is the last recipe still
		# sourced from the mocap bake that the three strikes were reverted off.
		if not (name.begins_with("strike_") or name.begins_with("running_")):
			continue
		moves.append(load("%s/%s" % [_moves_dir, file.replace(".remap", "")]))
	moves.sort_custom(func(a, b): return String(a.animation_pair_id) < String(b.animation_pair_id))
	return moves


## Plays one strike through the real code path and samples every frame of it.
func _run_clip(w: WrestlerController, skeleton: Skeleton3D, head: int, hips: int,
		move: MoveDef) -> bool:
	w.fsm.transition_to(WrestlerFSM.State.IDLE)
	await get_tree().physics_frame
	w._play_strike_clip(move)
	w._start_move(WrestlerFSM.State.STRIKE, move)

	var bad_frames: Array[int] = []
	var worst := 0.0
	var worst_frame := -1
	var frame := 0
	while w.fsm.current_state == WrestlerFSM.State.STRIKE and frame < 200:
		await get_tree().physics_frame
		var head_y: float = (skeleton.global_transform
				* skeleton.get_bone_global_pose(head).origin).y
		var hips_y: float = (skeleton.global_transform
				* skeleton.get_bone_global_pose(hips).origin).y
		if head_y < hips_y:
			bad_frames.append(frame)
			if hips_y - head_y > worst:
				worst = hips_y - head_y
				worst_frame = frame
		frame += 1

	var id := String(move.animation_pair_id)
	if bad_frames.is_empty():
		print("  %-22s %3d frames  clean" % [id, frame])
		if _out != "":
			await _shoot(w, move, move.startup_frames, id)
		return false
	print("  %-22s %3d frames  !! head below hips on %d frame(s): %s  (worst %.3f m under)"
			% [id, frame, bad_frames.size(), bad_frames, worst])
	if _out != "":
		await _shoot(w, move, worst_frame, id)
	return true


## Replays the clip and grabs its worst frame.
func _shoot(w: WrestlerController, move: MoveDef, at: int, id: String) -> void:
	w.fsm.transition_to(WrestlerFSM.State.IDLE)
	await get_tree().physics_frame
	w._play_strike_clip(move)
	w._start_move(WrestlerFSM.State.STRIKE, move)
	for frame in at:
		await get_tree().physics_frame
	var camera := Camera3D.new()
	get_tree().current_scene.add_child(camera)
	camera.current = true
	var focus := w.global_position + Vector3(0.0, 0.9, 0.0)
	camera.global_position = focus + Vector3(2.8, 1.2, 2.8)
	camera.look_at(focus, Vector3.UP)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_f%02d.png" % [_out, id, at])
	camera.queue_free()
	print("      wrote %s/%s_f%02d.png" % [_out, id, at])


func _find_bone(skeleton: Skeleton3D, candidates: Array) -> int:
	for name: String in candidates:
		var index := skeleton.find_bone(name)
		if index >= 0:
			return index
	return -1


func _bone_names(skeleton: Skeleton3D) -> Array:
	var names: Array = []
	for i in mini(skeleton.get_bone_count(), 12):
		names.append(skeleton.get_bone_name(i))
	return names
