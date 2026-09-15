extends Node
## The same clip, the same frame, on every rig the game ships — where do the
## hands and the head actually end up?
##
## Written because an authored pose that measures correct on the mannequin is
## not evidence about what a match renders. Idle_Ready puts both fists up in
## front of the chest on `wrestler_base`, and the roster models playing the
## same clip stand differently enough that the pose was reported as "weird" --
## which is either a retarget defect or a trick of the camera, and nothing in
## the repo could tell the two apart.
##
## So this samples the live Skeleton3D after the AnimationPlayer has written
## the pose, and prints each rig's hands and head in SKELETON space, normalised
## by that rig's own height so a taller model does not read as a different
## pose. Two rigs playing the same clip should agree to a couple of
## centimetres; anything larger is a retarget finding with a number attached.
##
## Usage:
##   godot4 --headless --path game tools/probe/pose_compare.tscn -- \
##       --clips Idle_Ready,Strike_Jab --at 0.0,0.35

const BASE_RIG := "res://assets/characters/wrestler_base.glb"
const CLIPS := "res://assets/animations/wrestling_clips.glb"

## The rigs to compare, and the bone each one calls the base rig's bone. An
## empty map means the names are the base rig's already.
const RIGS := {
	"base": {"scene": BASE_RIG, "map": {}},
	"cody": {"scene": "res://scenes/cody_model.tscn", "map": {}},
	"roman": {"scene": "res://scenes/roman_model.tscn", "map": {
		"hand_l": "J_Wrist_L", "hand_r": "J_Wrist_R",
		"upperarm_l": "J_Shoulder_L", "upperarm_r": "J_Shoulder_R",
		"Head": "J_Head", "pelvis": "J_Hips", "foot_l": "J_Foot_L",
	}},
}

const SAMPLED := ["hand_r", "hand_l", "Head", "pelvis"]

## Bones reported as an offset from another bone rather than from the root.
##
## A hand measured from the skeleton root carries every proportion difference
## between the root and the shoulder, and Roman's shoulders genuinely sit
## lower on his body than the mannequin's -- 0.925 of his height against
## 0.984 of the mannequin's, read off the rest skeletons. That is the model,
## not the retarget, and reporting it as retarget error hides whatever is
## left. Measured from the shoulder, the arm pose is compared with itself.
const RELATIVE := {"hand_r": "upperarm_r", "hand_l": "upperarm_l"}

var _clips: Array = ["Idle_Ready"]
var _at: Array = [0.0]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--clips" and i + 1 < args.size():
			_clips = Array(args[i + 1].split(","))
		elif args[i] == "--at" and i + 1 < args.size():
			_at = []
			for token: String in args[i + 1].split(","):
				_at.append(float(token))

	var library: AnimationLibrary = _clip_library()
	if library == null:
		get_tree().quit(1)
		return

	for clip_name: String in _clips:
		if not library.has_animation(clip_name):
			print("!! %s is not in %s" % [clip_name, CLIPS])
			continue
		var history := {}
		for rig_id: String in RIGS:
			history[rig_id] = []
		for fraction: float in _at:
			print("\n=== %s at %.2f of its length ===" % [clip_name, fraction])
			var rows := {}
			for rig_id: String in RIGS:
				rows[rig_id] = await _sample(rig_id, library, clip_name, fraction)
				history[rig_id].append(rows[rig_id])
			_report(rows)
		_report_travel(clip_name, history)
	get_tree().quit()


## How far each bone gets from where the clip started.
##
## The number a reaction lives or dies on. Hit_React_Head reads as a head
## snapping back, or it does not, and "the table says head pitch -18" is not
## evidence either way: the head bone sits at the base of the skull, so
## rotating it barely moves it, and what actually carries a head across the
## frame is the spine chain underneath. Measured travel is the only thing that
## tells those apart -- and the first measurement it produced was 4.6 cm of
## head on a clip whose table looks, on paper, like a man being knocked
## backwards.
func _report_travel(clip_name: String, history: Dictionary) -> void:
	print("\n--- %s: travel from frame 0 ---" % clip_name)
	for rig_id: String in history:
		var frames: Array = history[rig_id]
		if frames.is_empty() or (frames[0] as Dictionary).is_empty():
			continue
		var first: Dictionary = frames[0]
		var parts: Array[String] = []
		for game_bone: String in SAMPLED:
			if not first.has(game_bone):
				continue
			var worst := 0.0
			for frame: Dictionary in frames:
				if not frame.has(game_bone):
					continue
				worst = maxf(worst, (frame[game_bone] - first[game_bone]).length())
			parts.append("%s %.1fcm" % [game_bone, worst * 100.0])
		print("  %-6s %s" % [rig_id, " ".join(parts)])


func _clip_library() -> AnimationLibrary:
	var packed: PackedScene = load(CLIPS)
	if packed == null:
		push_error("cannot load %s" % CLIPS)
		return null
	var root: Node = packed.instantiate()
	var player: AnimationPlayer = root.find_child("AnimationPlayer", true, false)
	if player == null:
		push_error("%s has no AnimationPlayer" % CLIPS)
		root.free()
		return null
	var library: AnimationLibrary = player.get_animation_library(
			player.get_animation_library_list()[0])
	# Duplicated off the instance, which is then freed: the library outlives
	# the scene it came from and every rig below gets its own adapted copy.
	library = library.duplicate(true)
	root.free()
	return library


## One rig's pose, in skeleton space, scaled by the rig's own height.
func _sample(rig_id: String, library: AnimationLibrary, clip_name: String,
		fraction: float) -> Dictionary:
	var spec: Dictionary = RIGS[rig_id]
	var packed: PackedScene = load(spec["scene"])
	if packed == null:
		return {}
	var model: Node3D = packed.instantiate()
	add_child(model)
	await get_tree().process_frame

	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = null
	if model.has_method("get_game_skeleton"):
		skeleton = model.get_game_skeleton()
	else:
		skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	if player == null or skeleton == null:
		print("  %-6s no player/skeleton" % rig_id)
		model.queue_free()
		return {}

	# Through the model's own adapter, which is the path the match uses: a
	# comparison that skipped it would be measuring a rig the game never plays.
	var adapted := library
	if model.has_method("adapt_animation_library"):
		adapted = model.adapt_animation_library(library)
	player.add_animation_library(&"probe", adapted)
	var key := "probe/%s" % clip_name
	if not player.has_animation(key):
		print("  %-6s has no %s after adapting" % [rig_id, key])
		model.queue_free()
		return {}

	var animation := player.get_animation(key)
	player.play(key)
	# Paused and read on the spot. Awaiting a frame after the seek lets the
	# player advance by one delta before the skeleton is sampled, and a delta
	# is 3% of a half-second strike -- enough to put two rigs on different
	# frames of the same clip and report it as a retarget difference.
	player.pause()
	player.seek(animation.length * fraction, true)

	# Height from the rig itself rather than a constant: Roman and Cody are
	# not the mannequin's 1.65 m, and an unnormalised hand position would make
	# every taller model look like a different pose.
	var height := _rig_height(skeleton, spec["map"])
	var out := {"height": height}
	for game_bone: String in SAMPLED + RELATIVE.values():
		var bone_name: String = spec["map"].get(game_bone, game_bone)
		var index := skeleton.find_bone(bone_name)
		if index < 0:
			continue
		out[game_bone] = skeleton.get_bone_global_pose(index).origin
	model.queue_free()
	await get_tree().process_frame
	return out


## Head bone height above the planted foot, in the rig's REST pose: a stable
## per-rig scale that does not move with the clip.
func _rig_height(skeleton: Skeleton3D, map: Dictionary) -> float:
	var head := skeleton.find_bone(map.get("Head", "Head"))
	var foot := skeleton.find_bone(map.get("foot_l", "foot_l"))
	if head < 0 or foot < 0:
		return 1.0
	return absf(skeleton.get_bone_global_rest(head).origin.y
			- skeleton.get_bone_global_rest(foot).origin.y)


## A bone's position, measured from whatever RELATIVE says it hangs off.
func _relative(row: Dictionary, game_bone: String) -> Vector3:
	var anchor: String = RELATIVE.get(game_bone, "")
	if anchor == "" or not row.has(anchor):
		return row[game_bone]
	return row[game_bone] - row[anchor]


## Prints each rig's sampled bones, and every other rig's disagreement with
## the base rig once both are expressed as a fraction of their own height.
func _report(rows: Dictionary) -> void:
	var base: Dictionary = rows.get("base", {})
	for rig_id: String in rows:
		var row: Dictionary = rows[rig_id]
		if row.is_empty():
			continue
		var height: float = row["height"]
		var parts: Array[String] = []
		for game_bone: String in SAMPLED:
			if not row.has(game_bone):
				continue
			var p: Vector3 = row[game_bone] / height
			parts.append("%s(%+.3f %+.3f %+.3f)" % [game_bone, p.x, p.y, p.z])
		print("  %-6s h=%.2f  %s" % [rig_id, height, " ".join(parts)])
		if rig_id == "base" or base.is_empty():
			continue
		var deltas: Array[String] = []
		for game_bone: String in SAMPLED:
			if not row.has(game_bone) or not base.has(game_bone):
				continue
			var d: float = (_relative(row, game_bone) / height
					- _relative(base, game_bone) / float(base["height"])).length()
			deltas.append("%s %.1fcm" % [game_bone, d * height * 100.0])
		if not deltas.is_empty():
			print("         vs base: %s" % "  ".join(deltas))
