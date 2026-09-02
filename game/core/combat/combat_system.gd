class_name CombatSystem
extends RefCounted
## Per-limb damage accumulation, momentum, and derived gates
## (submission effectiveness, kickout difficulty).

enum Limb { HEAD, TORSO, ARMS, LEGS }

const MAX_LIMB_DAMAGE := 100.0
const MOMENTUM_MAX := 100.0

## Momentum a winner actually earns over one match. Measured across seven
## AI-vs-AI seeds: 59, 63, 64, 64, 64, 75, 64 -- so 64 is both the median
## and the mode, off 7-13 landed moves.
##
## The ladder used to be scaled to MOMENTUM_MAX instead, and that is the
## same mistake the kickout window had before KICKOUT_DAMAGE_REFERENCE: a
## scale no match ever occupies. SIGNATURE_THRESHOLD was 60, which a winner
## crosses on the move that finishes the fight, and FINISHER_THRESHOLD was
## 100 -- the meter's ceiling, unreachable by definition once a signature
## costing 60 is checked one branch below it.
##
## Measured before the change, over those same seven seeds: peak momentum
## equalled total momentum earned in every single one, which means nothing
## was ever spent. Both top rungs of the ladder, four authored moves and
## their paired animations, never fired in a match.
##
## 64 is the *pre-change* figure and it is kept as the denominator because
## that is the economy the fractions below were derived against. The economy
## feeds back on itself -- firing the ladder shortens the match, so a winner
## now earns 40-55 rather than 59-75 -- and the thresholds were re-verified
## against that narrower range rather than re-derived from it, which would
## chase its own tail.
const MOMENTUM_REFERENCE := 64.0

## The ladder, as fractions of what a match affords rather than of a ceiling
## nobody reaches. These are *reachability* values, chosen so all three tiers
## fire in a real match: gauntlet/refs/ measures nothing about how often a
## wrestler should hit a signature or a finisher, so none of them may be
## defended as how it should feel.
const POWER_THRESHOLD := MOMENTUM_REFERENCE * 0.1875     # 12
const SIGNATURE_THRESHOLD := MOMENTUM_REFERENCE * 0.375  # 24
## Late, but inside a winner's earnings rather than past them: the finisher
## should be the move that ends the match, not one that unlocks after it.
##
## Set by iteration against a measurement, because the economy feeds back on
## itself: firing the ladder shortens the match, which lowers the momentum
## the match earns. At 45 the signature fired in all ten seeds and the
## finisher in none -- peak momentum landed at 27-44, one point short.
const FINISHER_THRESHOLD := MOMENTUM_REFERENCE * 0.5  # 32

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
