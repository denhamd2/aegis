class_name CombatSystem
extends RefCounted
## Per-limb damage accumulation, momentum, and derived gates
## (submission effectiveness, kickout difficulty).

enum Limb { HEAD, TORSO, ARMS, LEGS }

const MAX_LIMB_DAMAGE := 100.0
const MOMENTUM_MAX := 100.0
const POWER_THRESHOLD := 30.0
const SIGNATURE_THRESHOLD := 60.0
const FINISHER_THRESHOLD := 100.0

var limb_damage := {
	Limb.HEAD: 0.0,
	Limb.TORSO: 0.0,
	Limb.ARMS: 0.0,
	Limb.LEGS: 0.0,
}
var momentum: float = 0.0

## Damage and momentum go to different wrestlers on a landed move — the
## defender takes the damage, the attacker builds the momentum. Call
## apply_damage() on the defender's CombatSystem and apply_momentum() on
## the attacker's; apply_move() (both, on one instance) only makes sense
## for tests/tools that don't model two separate wrestlers.
func apply_move(move: MoveDef) -> void:
	apply_damage(move)
	apply_momentum(move)

func apply_damage(move: MoveDef) -> void:
	limb_damage[Limb.HEAD] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.HEAD] + move.damage_head)
	limb_damage[Limb.TORSO] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.TORSO] + move.damage_torso)
	limb_damage[Limb.ARMS] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.ARMS] + move.damage_arms)
	limb_damage[Limb.LEGS] = min(MAX_LIMB_DAMAGE, limb_damage[Limb.LEGS] + move.damage_legs)

func apply_momentum(move: MoveDef) -> void:
	momentum = clamp(momentum - move.momentum_cost + move.momentum_gain, 0.0, MOMENTUM_MAX)

func total_damage() -> float:
	var sum := 0.0
	for v in limb_damage.values():
		sum += v
	return sum

func can_power() -> bool:
	return momentum >= POWER_THRESHOLD

func can_signature() -> bool:
	return momentum >= SIGNATURE_THRESHOLD

func can_finisher() -> bool:
	return momentum >= FINISHER_THRESHOLD

## Total damage at which the kickout window is fully closed.
##
## This used to be MAX_LIMB_DAMAGE * 4.0 -- 400, every limb destroyed --
## which is a number no match ever approaches. Measured over a real match:
## wrestlers are knocked down between 101 and 184 total damage, and across
## that whole range the window only moved from 0.59 to 0.46. So every pin
## was escaped, and the pinfall -- minigame, three-count and all -- had
## never decided a match in this project's history. Scaled to the range
## matches actually occupy, the same span now runs 0.39 down to 0.05.
const KICKOUT_DAMAGE_REFERENCE := 200.0

## Kickout target zone shrinks as total damage and opponent momentum rise.
## Returns a [0, 1] fraction of full-size window; 1.0 = easiest kickout.
func kickout_window_fraction(opponent_momentum: float) -> float:
	var damage_factor := 1.0 - (total_damage() / KICKOUT_DAMAGE_REFERENCE)
	var momentum_factor := 1.0 - (opponent_momentum / MOMENTUM_MAX) * 0.4
	return clamp(damage_factor * momentum_factor, 0.05, 1.0)

## Submission break-point: higher limb damage on the targeted limb makes
## the defender's ring shrink faster (closer to tapping).
func submission_break_rate(target_limb: Limb) -> float:
	var base_rate := 1.0
	var limb_factor: float = 1.0 + (float(limb_damage[target_limb]) / MAX_LIMB_DAMAGE)
	return base_rate * limb_factor

## Limb with the highest accumulated damage — used to decide whether a
## downed opponent is a submission target (see MatchReferee).
func most_damaged_limb() -> Limb:
	var worst: Limb = Limb.HEAD
	for limb in limb_damage:
		if limb_damage[limb] > limb_damage[worst]:
			worst = limb
	return worst
