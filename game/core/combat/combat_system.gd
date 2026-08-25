class_name CombatSystem
extends Node
## Per-limb damage accumulation, momentum, and derived gates
## (submission effectiveness, kickout difficulty).

enum Limb { HEAD, TORSO, ARMS, LEGS }

const MAX_LIMB_DAMAGE := 100.0
const MOMENTUM_MAX := 100.0
const SIGNATURE_THRESHOLD := 60.0
const FINISHER_THRESHOLD := 100.0

var limb_damage := {
	Limb.HEAD: 0.0,
	Limb.TORSO: 0.0,
	Limb.ARMS: 0.0,
	Limb.LEGS: 0.0,
}
var momentum: float = 0.0

func apply_move(move: MoveDef) -> void:
	limb_damage[Limb.HEAD] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.HEAD] + move.damage_head)
	limb_damage[Limb.TORSO] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.TORSO] + move.damage_torso)
	limb_damage[Limb.ARMS] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.ARMS] + move.damage_arms)
	limb_damage[Limb.LEGS] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.LEGS] + move.damage_legs)
	momentum = clamp(momentum - move.momentum_cost + move.momentum_gain, 0.0, MOMENTUM_MAX)

func total_damage() -> float:
	var sum := 0.0
	for v in limb_damage.values():
		sum += v
	return sum

func can_signature() -> bool:
	return momentum >= SIGNATURE_THRESHOLD

func can_finisher() -> bool:
	return momentum >= FINISHER_THRESHOLD

## Kickout target zone shrinks as total damage and opponent momentum rise.
## Returns a [0, 1] fraction of full-size window; 1.0 = easiest kickout.
func kickout_window_fraction(opponent_momentum: float) -> float:
	var damage_factor := 1.0 - (total_damage() / (MAX_LIMB_DAMAGE * 4.0))
	var momentum_factor := 1.0 - (opponent_momentum / MOMENTUM_MAX) * 0.4
	return clamp(damage_factor * momentum_factor, 0.05, 1.0)

## Submission break-point: higher limb damage on the targeted limb makes
## the defender's ring shrink faster (closer to tapping).
func submission_break_rate(target_limb: Limb) -> float:
	var base_rate := 1.0
	var limb_factor := 1.0 + (limb_damage[target_limb] / MAX_LIMB_DAMAGE)
	return base_rate * limb_factor
