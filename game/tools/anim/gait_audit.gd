extends SceneTree
## Audits the looping locomotion cycles for the two defects that make a
## wrestler read as gliding rather than walking.
##
##   godot4 --headless -s res://tools/anim/gait_audit.gd
##
## 1. FOOT SKATE. While a foot is on the mat it must travel backward at
##    exactly the speed WrestlerController translates the body forward, or the
##    canvas slides under the boot. This is a RATE, not a distance: a running
##    cycle covers most of its ground in flight, where nothing is planted and
##    nothing is constrained, so comparing stride length against speed * cycle
##    time condemns every correct run cycle ever authored. What matters is
##    backward travel divided by time planted.
##
##    Measured before the cycles were regenerated from _gait() in
##    tools/blender/wrestling_clips.py:
##
##      walk_stalk  0.42 m/s delivered against MOVE_SPEED 3.5  (6.6x skate)
##      run_drive   2.01 m/s delivered against RUN_SPEED  7.0  (7.3x skate)
##
## 2. LOOP SEAM. The pose at the end of a looping clip must equal the pose at
##    its start, or the whole body pops once per cycle. run_drive used to move
##    its left forearm 0.132 m across the seam -- every 0.667 s -- because
##    frame 0 named elbow poles and the closing frame did not, so the IK
##    solved the same hand target two different ways.
##
## Run this after any change to the cycles, to MOVE_SPEED/RUN_SPEED, or to the
## `seconds` those clips are retimed to in resources/animations/
## strike_recipes.gd. All three feed the same arithmetic.

const RIG := "res://assets/characters/wrestler_base.glb"
const LIB := "res://resources/animations/strike_clips.tres"

## Clip -> the engine speed it is played at, from WrestlerController.
const CYCLES := {
	"walk_stalk": 3.5,   # MOVE_SPEED
	"run_drive": 7.0,    # RUN_SPEED
}
## Clips that loop but carry the body at no speed at all: the feet should not
## travel while planted, and the seam still has to close.
const STATIONARY := ["idle_ready", "tie_up_collar"]

## Ankle height below which the foot counts as on the mat. The rig plants at
## 0.104, and the swing arc in _gait() is shaped to clear this within a frame
## of toe-off so the planted window measured here is the one authored.
const PLANT_HEIGHT := 0.13
## How far a planted foot's delivered speed may sit from the engine's before
## this is a finding. Generous, because the 60 Hz sampling grid below cannot
## resolve a 30 fps contact window to better than one sample at either end.
const RATE_TOLERANCE := 0.15
## A seam this size is a visible pop.
const SEAM_TOLERANCE := 0.005

func _init() -> void:
	quit(_run())

func _run() -> int:
	var model: Node = (load(RIG) as PackedScene).instantiate()
	var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
	var lib: AnimationLibrary = load(LIB)
	if not skeleton or not lib:
		push_error("missing rig or strike library")
		return 1

	var failures := 0
	for clip_name: String in CYCLES:
		failures += _audit(skeleton, lib, clip_name, CYCLES[clip_name])
	for clip_name in STATIONARY:
		failures += _audit(skeleton, lib, clip_name, 0.0)

	model.free()
	print("")
	print("gait audit: %s" % ("PASS" if failures == 0 else "%d FINDING(S)" % failures))
	return 1 if failures > 0 else 0

func _audit(skeleton: Skeleton3D, lib: AnimationLibrary, clip_name: String,
		speed: float) -> int:
	if not lib.has_animation(clip_name):
		push_error("no clip '%s' in %s" % [clip_name, LIB])
		return 1
	var anim: Animation = lib.get_animation(clip_name)
	print("\n=== %-14s %.3fs  loop_mode=%d  engine speed %.1f m/s"
			% [clip_name, anim.length, anim.loop_mode, speed])
	var findings := 0

	if anim.loop_mode == Animation.LOOP_NONE:
		print("  FINDING: authored as a cycle but baked LOOP_NONE -- it will")
		print("           play once and freeze on its last frame.")
		findings += 1

	# --- loop seam ---
	var seam := 0.0
	var seam_bone := ""
	for bone in skeleton.get_bone_count():
		var moved: float = (_global(skeleton, anim, bone, 0.0).origin
				- _global(skeleton, anim, bone, anim.length).origin).length()
		if moved > seam:
			seam = moved
			seam_bone = skeleton.get_bone_name(bone)
	if seam > SEAM_TOLERANCE:
		print("  FINDING: loop seam -- %s jumps %.4f m between the last frame"
				% [seam_bone, seam])
		print("           and the first. A pose named at frame 0 is probably")
		print("           missing from the closing frame.")
		findings += 1
	else:
		print("  loop seam clean (worst bone moves %.4f m)" % seam)

	# --- planted rate ---
	for foot in ["foot_l", "foot_r"]:
		var bone := skeleton.find_bone(foot)
		if bone < 0:
			continue
		var planted := 0.0
		var travelled := 0.0
		var previous := 0.0
		var contiguous := false
		var t := 0.0
		var step := 1.0 / 60.0
		while t <= anim.length:
			var p: Vector3 = _global(skeleton, anim, bone, t).origin
			if p.y < PLANT_HEIGHT:
				if contiguous:
					# The rig's own forward is +Z, so backward travel -- the
					# direction a planted foot must move -- is a falling z.
					travelled += previous - p.z
					planted += step
				previous = p.z
				contiguous = true
			else:
				contiguous = false
			t += step
		if planted <= 0.0:
			print("  %s never touches the mat" % foot)
			continue
		var delivered: float = travelled / planted
		var verdict := "ok"
		if speed <= 0.0:
			if absf(delivered) > RATE_TOLERANCE:
				verdict = "FINDING: stationary clip, but the planted foot travels"
				findings += 1
		elif absf(delivered - speed) / speed > RATE_TOLERANCE:
			verdict = "FINDING: %.1fx skate" % (speed / maxf(delivered, 0.001))
			findings += 1
		print("  %s planted %.3fs, travels %.3f m back -> %.2f m/s  %s"
				% [foot, planted, travelled, delivered, verdict])
	return findings

## Forward kinematics over the clip's own tracks -- neither
## AnimationPlayer.seek() nor Skeleton3D.set_bone_pose_rotation() reaches
## get_bone_global_pose() inside a `-s` script, so every naive sample reads
## back identical rest values.
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

func _find(anim: Animation, bone: String, type: int) -> int:
	for track in anim.get_track_count():
		if anim.track_get_type(track) != type:
			continue
		if String(anim.track_get_path(track).get_concatenated_subnames()) == bone:
			return track
	return -1
