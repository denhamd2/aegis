extends GdUnitTestSuite
## The owner, 16 Nov: "create a walk test for Roman, Cody and Kenny.
## Especially for their walks to the ring, but also during gameplay. They
## should look natural with their leg, body and arm movements during a walk,
## not robotic."
##
## Every walk the three men play (WalkMetrics.WALKS: Roman's Walk_Slow_Look,
## Cody's Walk_Crowd, Kenny's Kenny_Walk, the shared Entrance_Walk, and the
## gameplay Walk_Stalk, Run_Jog and Run_Drive) is measured off the baked clip
## on the base rig (tools/anim/walk_metrics.gd) and held to WalkMetrics'
## gates: the planted foot against the engine's speed, the loop seam, the arm
## swing and its opposition to the legs, the pelvis's turn with the stride and
## the shoulders' against it, the pelvis's drop, sway and roll, the head,
## the stride against the leg, and the robotic-ness checks (frozen joints, a
## rigid spine, holds). Cody and Kenny wear the base rig's proportions
## exactly, so these are their numbers; Roman's model is remapped onto it.
##
## KNOWN_FAILS is the ledger of what a walk still gets wrong. It is exact in
## both directions: a walk that fails a gate not listed fails this test, and
## so does one that now passes a gate that is listed -- so a fix has to strike
## its line here, and the ledger cannot go stale. Never add to it to make a
## change pass; `godot4 --headless --path game -s res://tools/probe/
## walk_quality.gd` prints every number and the gates it misses.

const WalkMetrics := preload("res://tools/anim/walk_metrics.gd")
const RIG := "res://assets/characters/wrestler_base.glb"
const LIB := "res://resources/animations/strike_clips.tres"

## Measured 16 Nov on main 12cd89f1 (gauntlet/refs/walks/README.md). Every
## walk paced: the hands, the hips and the shoulders all turned the wrong
## way round against the legs. _gait's walks also roll the planted foot the
## wrong way (the sole slides), carry the pelvis on a rail (no sway, no
## roll), and Walk_Stalk is a 16-frame walk cycle run at 3.5 m/s.
const KNOWN_FAILS := {
	"walk_slow_look": ["arm_opposition", "hip_rotation", "shoulder_counter"],
	"walk_crowd": ["arm_opposition", "hip_rotation", "shoulder_counter"],
	"kenny_walk": ["arm_opposition", "hip_rotation", "shoulder_counter"],
	"entrance_walk": ["skate", "arm_opposition", "hip_rotation", "pelvis_dip", "pelvis_sway",
			"pelvis_roll", "double_support", "no_flight"],
	"walk_stalk": ["skate", "arm_opposition", "hip_rotation", "spine_alive", "pelvis_dip",
			"pelvis_sway", "arm_swing", "cadence"],
	"run_jog": ["arm_opposition", "hip_rotation", "spine_alive", "pelvis_sway"],
	"run_drive": ["skate", "arm_opposition", "hip_rotation", "spine_alive", "pelvis_sway"],
}

var _skeleton: Skeleton3D
var _lib: AnimationLibrary
var _model: Node


func before() -> void:
	_model = (load(RIG) as PackedScene).instantiate()
	_skeleton = _model.find_child("Skeleton3D", true, false)
	_lib = load(LIB)


func after() -> void:
	if is_instance_valid(_model):
		_model.free()


func _measure(clip: String) -> Dictionary:
	var w: Dictionary = WalkMetrics.WALKS[clip]
	return WalkMetrics.analyze(_skeleton, _lib.get_animation(clip), w["speed"], w["cycles"])


func _failing(clip: String) -> Array:
	var verdict := WalkMetrics.judge(clip, _measure(clip))
	var out: Array = []
	for gate: String in verdict:
		if not verdict[gate][0]:
			out.append(gate)
	out.sort()
	return out


func _check(clip: String) -> void:
	var known: Array = KNOWN_FAILS.get(clip, []).duplicate()
	known.sort()
	var failing := _failing(clip)
	assert_array(failing).override_failure_message(
			"%s: failing gates %s, ledger says %s -- run tools/probe/walk_quality.gd"
			% [clip, str(failing), str(known)]).is_equal(known)


func test_every_walk_the_three_men_play_is_baked_and_loops() -> void:
	for clip: String in WalkMetrics.WALKS:
		assert_bool(_lib.has_animation(clip)).override_failure_message("no " + clip).is_true()
		assert_int(_lib.get_animation(clip).loop_mode).is_not_equal(Animation.LOOP_NONE)
	for clip: String in KNOWN_FAILS:
		assert_bool(WalkMetrics.WALKS.has(clip)).is_true()


func test_roman_entrance_walk() -> void:
	_check("walk_slow_look")


func test_cody_entrance_walk() -> void:
	_check("walk_crowd")


func test_kenny_entrance_walk() -> void:
	_check("kenny_walk")


func test_shared_entrance_and_face_off_walk() -> void:
	_check("entrance_walk")


func test_gameplay_walk() -> void:
	_check("walk_stalk")


func test_gameplay_jog() -> void:
	_check("run_jog")


func test_gameplay_run() -> void:
	_check("run_drive")


## The gates catch a robot: Cody's walk with the arms and spine taken off it
## (the tracks dropped, so those joints hold their rest pose) must fail on
## frozen limbs, a rigid spine and no arm swing.
func test_a_walk_with_frozen_arms_and_spine_fails() -> void:
	var anim: Animation = _lib.get_animation("walk_crowd").duplicate(true)
	for t in range(anim.get_track_count() - 1, -1, -1):
		var bone := String(anim.track_get_path(t).get_concatenated_subnames())
		if bone.begins_with("spine_") or bone.begins_with("upperarm_") or bone.begins_with("lowerarm_") \
				or bone.begins_with("clavicle_") or bone.begins_with("hand_"):
			anim.remove_track(t)
	var w: Dictionary = WalkMetrics.WALKS["walk_crowd"]
	var verdict := WalkMetrics.judge("walk_crowd", WalkMetrics.analyze(_skeleton, anim, w["speed"], w["cycles"]))
	for gate in ["frozen_limbs", "spine_alive", "arm_swing", "arm_swing_free"]:
		assert_bool(verdict[gate][0]).override_failure_message("a frozen walk passed " + gate).is_false()


## And a march: the same walk with the time of the legs shifted half a
## stride against the body (the arms and shoulders now go with the legs of
## their own side) must fail on the opposition.
func test_a_paced_walk_fails() -> void:
	var anim: Animation = _lib.get_animation("walk_crowd").duplicate(true)
	var cycle := anim.length / float(WalkMetrics.WALKS["walk_crowd"]["cycles"])
	var src: Animation = _lib.get_animation("walk_crowd")
	for t in anim.get_track_count():
		var bone := String(anim.track_get_path(t).get_concatenated_subnames())
		if not (bone.begins_with("upperarm_") or bone.begins_with("lowerarm_") or bone.begins_with("hand_")):
			continue
		if anim.track_get_type(t) != Animation.TYPE_ROTATION_3D:
			continue
		for k in anim.track_get_key_count(t):
			var at := fmod(anim.track_get_key_time(t, k) + cycle * 0.5, anim.length)
			anim.track_set_key_value(t, k, src.rotation_track_interpolate(t, at))
	var w: Dictionary = WalkMetrics.WALKS["walk_crowd"]
	var r := WalkMetrics.analyze(_skeleton, anim, w["speed"], w["cycles"])
	var base := _measure("walk_crowd")
	# Shifting the arms half a stride flips their phase against the legs.
	assert_float(r["hands_vs_feet"] * base["hands_vs_feet"]).is_less(0.0)
