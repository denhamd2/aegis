extends Node
## Measures the way into the ring tick by tick: how far the lower boot is off
## whatever it stands on (floor, tread, platform, apron, mat), and how fast
## the root turns, over each man's climb, apron step and step through the
## ropes. A float shows as the lower boot well above its surface; a snap as
## a turn rate far over EntranceDirector.TURN_RATE.
##
##   godot4 --headless --path game tools/probe/entry_contact.tscn -- --who cody
##
## Prints one line per tick and a summary per clip (max float, max sink, max
## turn), so a fix can be checked as numbers before it is checked on frames.

const ANKLE := 0.104

var _who := "cody"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		if args[i] == "--who":
			_who = args[i + 1]
	var pair := Roster.pair_from_spec("roman,cody")
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	# Straight to the turn before this man's climb, standing where it starts.
	var start := -1
	for i in director._beats.size():
		var b: Dictionary = director._beats[i]
		var w: WrestlerController = b.get("who")
		if w and w.entrance_style == _who and b.get("clip", "") == "strikes/climb_steps":
			start = i - 1
			break
	if start < 0:
		print("ENTRY_CONTACT no climb for ", _who)
		get_tree().quit()
		return
	var climb: Dictionary = director._beats[start + 1]
	var man: WrestlerController = climb["who"]
	man.visible = true
	man.global_position = climb["from"]
	man.rotation.y = atan2(-(climb["facing"] as Vector3).x, -(climb["facing"] as Vector3).z)
	man.play_presentation_clip(director._wait_clip(man), true)
	director._beat = start
	director._start_beat()
	var skel := man.find_child("Skeleton3D", true, false) as Skeleton3D
	var stats := {}
	var last_yaw := man.rotation.y
	var tick := 0
	while director._beat < director._beats.size() and tick < 900:
		await get_tree().physics_frame
		tick += 1
		var b: Dictionary = director._beats[director._beat]
		var clip: String = b.get("clip", b["kind"])
		if not clip.begins_with("strikes/climb") and not clip.begins_with("strikes/apron") \
				and not clip.begins_with("strikes/rope") and b["kind"] != "turn":
			if stats.size() > 0 and clip != "turn":
				break
			continue
		var gaps := []
		for bone: String in ["foot_l", "foot_r"]:
			var idx := skel.find_bone(bone)
			if idx < 0:  # Roman's own rig
				idx = skel.find_bone("J_Foot_" + bone.right(1).to_upper())
			var p := skel.global_transform * skel.get_bone_global_pose(idx).origin
			gaps.append(p.y - ANKLE - surface_at(p))
		var low: float = minf(gaps[0], gaps[1])
		var turn := absf(wrapf(man.rotation.y - last_yaw, -PI, PI)) * 60.0
		last_yaw = man.rotation.y
		var s: Dictionary = stats.get(clip, {"float": -9.0, "sink": 9.0, "turn": 0.0, "n": 0})
		s["float"] = maxf(s["float"], low)
		s["sink"] = minf(s["sink"], low)
		s["turn"] = maxf(s["turn"], turn)
		s["n"] += 1
		stats[clip] = s
		print("tick %4d %-36s lowboot %+.3f  L %+.3f R %+.3f  turn %.2f rad/s" % [tick, clip,
				low, gaps[0], gaps[1], turn])
	for clip in stats:
		var s: Dictionary = stats[clip]
		print("ENTRY_CONTACT %-36s ticks %3d  max float %+.3f  max sink %+.3f  max turn %.2f" % [
				clip, s["n"], s["float"], s["sink"], s["turn"]])
	get_tree().quit()


## The top of whatever is under `p`: the steps' tiers and platform (ring.py
## build_steps), the apron, the mat, else the ringside floor.
static func surface_at(p: Vector3) -> float:
	var edge := maxf(absf(p.x), absf(p.z))
	if absf(p.x) <= RingBuilder.APRON_OUT and absf(p.z) <= RingBuilder.APRON_OUT:
		return 0.0 if edge < 3.0 else RingBuilder.APRON_TOP
	var floor_y := ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT
	var corner := EntranceDirector.ENTRY_CORNER
	var apron_corner := Vector3(corner.x * RingBuilder.APRON_OUT, 0.0, corner.y * RingBuilder.APRON_OUT)
	var out := RingBuilder.step_out_dir(corner)
	var across := Vector3(-corner.y, 0.0, corner.x).normalized()
	var d := p - apron_corner
	var o := d.dot(out)
	var a := d.dot(across)
	var apex := RingBuilder.STEP_APRON_GAP * sqrt(2.0)
	if absf(a) > RingBuilder.STEP_WIDTH * 0.5 or o < -absf(a) + apex:
		return floor_y
	var top_front := apex + RingBuilder.STEP_PLATFORM
	var treads := RingBuilder.STEP_TREADS
	var rise := (RingBuilder.STEP_TOP_Y - RingBuilder.STEP_FLOOR_Y) / treads
	for i in range(treads - 1, -1, -1):
		var front := top_front + RingBuilder.STEP_RUN * (treads - 1 - i)
		if o <= front:
			return RingBuilder.STEP_FLOOR_Y + rise * (i + 1)
	return floor_y
