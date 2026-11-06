class_name LimbDamageSell
extends SkeletonModifier3D
## Persistent injury in the walk. Damage only drives the drawn pose: movement
## speed, combat choices and the replay stay with WrestlerController.

const START_DAMAGE := 60.0
const FULL_DAMAGE := 100.0
const EASE_PER_TICK := 0.10
const STEP_TICKS := 30.0

var wrestler: WrestlerController
var bones := {"pelvis": "pelvis", "spine_01": "spine_01",
		"upperarm_r": "upperarm_r", "lowerarm_r": "lowerarm_r", "hand_r": "hand_r"}
var _ids := {}
var _leg_weight := 0.0
var _arm_weight := 0.0
var _last_frame := -1


static func injury_weight(damage: float) -> float:
	return smoothstep(START_DAMAGE, FULL_DAMAGE, damage)


func _ready() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for key: String in bones:
		_ids[key] = sk.find_bone(bones[key])


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null or wrestler == null or wrestler.fsm == null or wrestler.combat == null:
		return
	var walking := wrestler.fsm.is_in([WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN])
	var standing := walking or wrestler.fsm.current_state == WrestlerFSM.State.IDLE
	var frame := Engine.get_physics_frames()
	if frame != _last_frame:
		_last_frame = frame
		_leg_weight = move_toward(_leg_weight, injury_weight(float(wrestler.combat.limb_damage[
				CombatSystem.Limb.LEGS])) if walking else 0.0, EASE_PER_TICK)
		_arm_weight = move_toward(_arm_weight, injury_weight(float(wrestler.combat.limb_damage[
				CombatSystem.Limb.ARMS])) if standing else 0.0, EASE_PER_TICK)
	if _leg_weight < 0.001 and _arm_weight < 0.001:
		return
	var to_sk := sk.global_basis.inverse()
	var up := (to_sk * Vector3.UP).normalized()
	var right := (to_sk * wrestler.global_basis.x).normalized()
	var forward := (to_sk * -wrestler.global_basis.z).normalized()
	if _leg_weight > 0.001:
		var id := int(_ids.get("pelvis", -1))
		if id >= 0:
			var pose := sk.get_bone_global_pose(id)
			var phase := TAU * float(wrestler.fsm.ticks_in_state % int(STEP_TICKS)) / STEP_TICKS
			var pulse := sin(phase)
			pose.origin += up * (0.018 * _leg_weight * (1.0 + pulse))
			pose.basis = Basis(forward, deg_to_rad(5.0 * _leg_weight * pulse)) * pose.basis
			sk.set_bone_global_pose(id, pose)
	if _arm_weight > 0.001:
		for key: String in ["spine_01", "upperarm_r", "lowerarm_r", "hand_r"]:
			if int(_ids.get(key, -1)) < 0:
				return
		var at := func(key: String) -> Vector3:
			return sk.get_bone_global_pose(int(_ids[key])).origin
		var target: Vector3 = at.call("spine_01") + right * 0.28 - up * 0.32 + forward * 0.02
		var hand := sk.get_bone_global_pose(int(_ids["hand_r"]))
		var chain := [int(_ids["upperarm_r"]), int(_ids["lowerarm_r"]), int(_ids["hand_r"])]
		FootPlant._solve_leg(sk, chain, Transform3D(hand.basis,
				hand.origin.lerp(target, _arm_weight)))
