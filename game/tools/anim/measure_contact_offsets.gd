extends SceneTree
## Bakes each strike's contact point: where the striking limb actually is, in
## the wrestler's own local space, on the tick its MoveDef applies damage.
##
##   godot4 --headless -s res://tools/anim/measure_contact_offsets.gd
##
## Why this exists
## ---------------
## Strikes used to resolve on `global_position.distance_to(opponent
## .global_position) <= STRIKE_HIT_RANGE`, one 1.15 m sphere between two
## capsule origins, shared by every strike in the game. It asked nothing about
## where the fist was, so it could not tell a jab from a boot and it could not
## tell forwards from backwards.
##
## Measured against the clips the game actually plays, the four strikes put
## their striking limb 0.42 / 0.55 / 0.82 / 0.82 m in front of the origin. A
## single 1.15 m test therefore landed the jab through a third of a metre of
## clear air and cut both kicks short of where the boot really was.
##
## What this prints is the fix's input: `contact_offset`, the limb's position
## in character-local space (forward is -Z, matching the model's own PI-Y
## mount in WrestlerController._install_character_model()). WrestlerController
## places a sphere there and tests it against the opponent's capsule, so a
## strike lands when and where the limb does.
##
## Re-run this after ANY change to the clips or to a strike's startup_frames,
## and paste the printed values back into the .tres files. The numbers are
## measurements, not preferences: nothing else in the project reproduces them.
##
## Method is the one tools/anim/measure_strike_contact.gd established --
## forward kinematics over the clip's own tracks, because neither
## AnimationPlayer.seek() nor Skeleton3D.set_bone_pose_rotation() reaches
## get_bone_global_pose() inside a `-s` script.

const RIG := "res://assets/characters/wrestler_base.glb"
const LIB := "res://resources/animations/strike_clips.tres"
const StrikeRecipes := preload("res://resources/animations/strike_recipes.gd")

## move .tres -> the clip its state actually plays. The four strikes name
## their clip through animation_pair_id; the running attacks leave that empty
## and inherit STATE_ANIMATIONS[RUNNING_ATTACK] instead, so they are named
## here rather than guessed.
const MOVES := {
	"res://resources/moves/strike_jab.tres": "",
	"res://resources/moves/strike_cross.tres": "",
	"res://resources/moves/strike_kick.tres": "",
	"res://resources/moves/strike_kick_heavy.tres": "",
	"res://resources/moves/running_attack_clothesline.tres": "running_clothesline",
	"res://resources/moves/running_attack_double_leg.tres": "running_clothesline",
}

## Candidate striking limbs. The one that travels furthest forward over the
## clip is the one throwing the strike -- measured, not declared, because a
## clip's own name is not evidence about which limb it swings.
const TIPS := ["hand_l", "hand_r", "foot_l", "foot_r"]

## Radius of the striking surface itself: a fist and a boot are not points.
## Chosen to match the limb, and small enough that the contact test stays a
## claim about the limb rather than about the body behind it.
const FIST_RADIUS := 0.12
const BOOT_RADIUS := 0.15

func _init() -> void:
	quit(_run())

func _run() -> int:
	var packed: PackedScene = load(RIG)
	var model: Node = packed.instantiate()
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var lib: AnimationLibrary = load(LIB)
	if not skeleton or not lib:
		push_error("missing rig or strike library")
		return 1

	print("contact offsets, character-local (forward is -Z), at each move's own contact tick")
	print("%-42s %-8s %-8s %-24s %s" % ["move", "clip", "limb", "contact_offset", "radius"])
	var failures := 0
	for path: String in MOVES:
		var move: MoveDef = load(path)
		var clip_name: String = MOVES[path]
		if clip_name == "":
			clip_name = String(move.animation_pair_id)
		if not lib.has_animation(clip_name):
			push_error("%s: no clip '%s' in %s" % [path, clip_name, LIB])
			failures += 1
			continue
		var anim: Animation = lib.get_animation(clip_name)

		# Which limb is throwing this? The tip that gets furthest forward.
		var limb := ""
		var best := -INF
		for tip_name in TIPS:
			var bone := skeleton.find_bone(tip_name)
			if bone < 0:
				continue
			var t := 0.0
			while t <= anim.length:
				var fwd: float = _global(skeleton, anim, bone, t).origin.z
				if fwd > best:
					best = fwd
					limb = tip_name
				t += 1.0 / 60.0
			t = 0.0

		# Sample it on the tick the MoveDef actually applies damage.
		var contact_t: float = min(move.startup_frames / 60.0, anim.length)
		var bone_index := skeleton.find_bone(limb)
		var pos: Vector3 = _global(skeleton, anim, bone_index, contact_t).origin
		# The model is mounted rotated PI about Y inside the controller
		# (WrestlerController._install_character_model()), so skeleton +Z --
		# the rig's own forward -- is the controller's -Z.
		var local := Vector3(-pos.x, pos.y, -pos.z)
		var radius: float = BOOT_RADIUS if limb.begins_with("foot") else FIST_RADIUS
		print("%-42s %-8s %-8s Vector3(%+0.3f, %+0.3f, %+0.3f)  %.2f"
				% [path.get_file(), clip_name.substr(0, 8), limb,
				   local.x, local.y, local.z, radius])
		print("    tick %d of %d   reach %.3f m forward of origin"
				% [move.startup_frames, roundi(anim.length * 60.0), -local.z])
	model.free()
	return 1 if failures > 0 else 0

## The bone's global transform at time `t`, built from the clip's tracks over
## the rest pose -- see the file comment for why the engine cannot be asked.
func _global(skeleton: Skeleton3D, anim: Animation, bone: int, t: float) -> Transform3D:
	var chain: Array[int] = []
	var walk := bone
	while walk >= 0:
		chain.push_front(walk)
		walk = skeleton.get_bone_parent(walk)
	var out := Transform3D.IDENTITY
	for index in chain:
		out = out * _local(skeleton, anim, index, t)
	return out

func _local(skeleton: Skeleton3D, anim: Animation, bone: int, t: float) -> Transform3D:
	var rest := skeleton.get_bone_rest(bone)
	var name := skeleton.get_bone_name(bone)
	var basis := rest.basis
	var origin := rest.origin
	var rotation_track := _find(anim, name, Animation.TYPE_ROTATION_3D)
	if rotation_track >= 0:
		basis = Basis(anim.rotation_track_interpolate(rotation_track, t))
	var position_track := _find(anim, name, Animation.TYPE_POSITION_3D)
	if position_track >= 0:
		origin = anim.position_track_interpolate(position_track, t)
	return Transform3D(basis, origin)

## Tracks are addressed by node path rather than find_track(), so this works
## on the rig's own clips and on a retargeted .glb with a different prefix.
func _find(anim: Animation, bone: String, type: int) -> int:
	for track in anim.get_track_count():
		if anim.track_get_type(track) != type:
			continue
		if String(anim.track_get_path(track).get_concatenated_subnames()) == bone:
			return track
	return -1
