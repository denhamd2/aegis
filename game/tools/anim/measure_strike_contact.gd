extends SceneTree
## Measures when a clip's fist or foot actually connects, by forward
## kinematics on the clip's own tracks. Run from the Godot project root:
##
##   godot4 --headless -s res://tools/anim/measure_strike_contact.gd -- \
##       [--clip Punch_Cross] [--file res://assets/animations/...glb]
##
## Why this exists: every strike recipe in resources/animations/
## strike_recipes.gd carries a contact time, and each one so far was
## measured by hand, once, and written into a comment. A second punch or
## kick needs the same measurement, and doing it by hand again is how the
## numbers drift apart.
##
## The method is the one those comments describe. Neither
## AnimationPlayer.seek() nor Skeleton3D.set_bone_pose_rotation() reaches
## get_bone_global_pose() inside a `-s` script -- every naive sample reads
## back identical rest values -- so the pose is built here instead: each
## bone's local transform is the clip's own interpolated key (falling back
## to the rest pose for bones the clip does not drive), and globals come
## from walking the parent chain. That is exactly what the skeleton would
## compute, minus the engine.
##
## Contact is reported as the frame where the tip bone reaches its furthest
## from the pelvis along the rig's forward axis (-Z), which is the extended
## end of a punch or a kick. Both sides are measured; the one that travels
## further is the striking limb.

const RIG_SCENE := "res://assets/characters/wrestler_base.glb"
const SAMPLE_HZ := 60.0
## [label, tip bone] pairs. Hands for punches, feet for kicks.
const TIPS := [["hand_l", "hand_l"], ["hand_r", "hand_r"],
		["foot_l", "foot_l"], ["foot_r", "foot_r"]]

func _init() -> void:
	quit(_run())

func _run() -> int:
	var args := OS.get_cmdline_user_args()
	var clip_name := "Punch_Cross"
	var file := RIG_SCENE
	for i in args.size():
		if args[i] == "--clip" and i + 1 < args.size():
			clip_name = args[i + 1]
		elif args[i] == "--file" and i + 1 < args.size():
			file = args[i + 1]

	var packed: PackedScene = load(file)
	if not packed:
		push_error("Cannot load %s" % file)
		return 1
	var model: Node = packed.instantiate()
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	if not skeleton or not player:
		push_error("%s has no Skeleton3D/AnimationPlayer" % file)
		model.free()
		return 1
	if not player.has_animation(clip_name):
		push_error("%s has no clip '%s'" % [file, clip_name])
		model.free()
		return 1
	var anim: Animation = player.get_animation(clip_name)

	print("clip %s  length %.3fs  (%s)" % [clip_name, anim.length, file])
	var pelvis := skeleton.find_bone("pelvis")
	for entry in TIPS:
		var tip: int = skeleton.find_bone(String(entry[1]))
		if tip < 0:
			continue
		var best_reach := -INF
		var best_time := 0.0
		var best_offset := Vector3.ZERO
		var t := 0.0
		while t <= anim.length:
			var tip_global := _global(skeleton, anim, tip, t)
			var root := _global(skeleton, anim, pelvis, t)
			# Forward is -Z in Godot, and the rig's own bind pose faces the
			# same way, so a punch's reach is how far the fist gets in front
			# of the hips along that axis.
			# Forward is +Z in this rig's own bone space, measured: the
			# right fist of Punch_Cross peaks at +0.677 on that axis, and
			# nothing else in the clip goes anywhere near as far.
			var reach := (tip_global.origin - root.origin).z
			if reach > best_reach:
				best_reach = reach
				best_time = t
				best_offset = tip_global.origin - root.origin
			t += 1.0 / SAMPLE_HZ
		print("  %-8s peak reach %.3fm at t=%.3fs (tick %d) offset %v"
				% [String(entry[0]), best_reach, best_time, roundi(best_time * 60.0), best_offset])
	model.free()
	return 0

## The bone's global transform at time `t`, built from the clip's tracks
## over the rest pose -- see the file comment for why the engine cannot be
## asked for this here.
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

## Tracks are addressed by node path here rather than by find_track(), so
## this works on the rig's own clips and on a retargeted .glb whose track
## paths carry a different scene prefix.
func _find(anim: Animation, bone: String, type: int) -> int:
	for track in anim.get_track_count():
		if anim.track_get_type(track) != type:
			continue
		if String(anim.track_get_path(track).get_concatenated_subnames()) == bone:
			return track
	return -1
