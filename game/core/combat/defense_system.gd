class_name DefenseSystem
extends RefCounted
## Shared tuning for active guard. A health advantage improves defense, but a
## wrestler who is behind can still defend himself.

static func is_guardable_strike(move: MoveDef, weapon := false) -> bool:
	if move == null or weapon or move.momentum_cost > 0.0:
		return false
	var damage := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	return damage > 0.0 and damage <= 10.0

static func blocked_damage_scale(defender_health: float, attacker_health: float,
		stamina: float) -> float:
	var advantage := clampf(defender_health, 0.0, 1.0) - clampf(attacker_health, 0.0, 1.0)
	var scale := 0.70 - maxf(advantage, 0.0) * 0.22 \
			+ maxf(-advantage, 0.0) * 0.12 + (1.0 - clampf(stamina, 0.0, 1.0)) * 0.12
	return clampf(scale, 0.40, 0.82)

static func ai_guard_chance(defender_health: float, attacker_health: float,
		stamina: float) -> float:
	var advantage := clampf(defender_health, 0.0, 1.0) - clampf(attacker_health, 0.0, 1.0)
	var chance := 0.12 + clampf(defender_health, 0.0, 1.0) * 0.10 \
			+ maxf(advantage, 0.0) * 0.35 - maxf(-advantage, 0.0) * 0.12
	return clampf(chance * (0.55 + 0.45 * clampf(stamina, 0.0, 1.0)), 0.06, 0.42)
