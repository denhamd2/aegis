class_name PairedContacts
extends RefCounted
## Where the attacker's hands go in each paired move (gauntlet/refs/
## animation_gap.md, Phase 2: contact). Read by
## WrestlerController._aim_paired_contact.
##
## Before this, every paired move aimed both hands at the same place -- his
## chest, or his hips if the attacker lifts -- including the strikes: through
## a Superman Punch, a Gamengiri or a clothesline the attacker's arms reached
## out and took hold of the man he was kicking. A move now says what it holds:
##
##   "neck"  -- right hand round the back of his neck, left on his upper back:
##              the headlock every neckbreaker, cutter, DDT, flatliner and
##              stunner is thrown from.
##   "waist" -- both hands round his waist: spears, the backbreaker set-up,
##              the liger bomb.
##   "legs"  -- right hand under his far thigh, left on his upper back: the
##              cradle a body slam, powerslam or fallaway carries him in.
##   "facelock" -- from in front and above, both hands over the top of his
##              neck and head: the cravate. "neck" reached round the BACK of
##              it and drove the forearm through his chest (PairClearance).
##   "wrist" -- Cross Rhodes: right hand on his right wrist (the wrist-clutch),
##              left behind his neck.
##   "waist_behind" -- the chain's rear waistlock: from behind, hands locked
##              at his hip bones. "waist" wraps to the front of his hips,
##              which from behind is past arm's length (20 cm short).
##   "wringer" -- the chain wristlock: both hands on his right wrist and
##              forearm, turning it over.
##   "none"  -- hands his own: every strike, kick and dive.
##
## Unlisted moves keep the old behaviour (chest, or hips when lifting).

const MOVES := {
	# Chain wrestling (Phase 4).
	"chain_headlock": "neck",
	"chain_wristlock": "wringer",
	"chain_waistlock": "waist_behind",
	# The headlock family.
	"signature_neckbreaker": "neck",
	"running_reverse_swing_neckbreaker": "neck",
	"running_dragon_twist_cutter": "neck",
	"signature_cody_cutter": "neck",
	"running_rolling_codebreaker": "neck",
	"running_rolling_thunder_flatliner": "neck",
	"running_tilt_a_whirl_ddt": "neck",
	"running_stundog_millionaire": "neck",
	"running_jumping_cravate_driver": "facelock",
	"grapple_clinch_knee": "neck",
	"grapple_vertical_suplex": "neck",
	# Round the waist.
	"finisher_spear": "waist",
	"running_spear": "waist",
	"signature_backbreaker": "waist",
	"running_float_over_liger_bomb": "waist",
	"running_tilt_a_whirl_backstabber": "waist",
	# Cradled.
	"power_bodyslam": "legs",
	"power_powerslam": "legs",
	"power_alabama_slam": "legs",
	"power_samoan_drop": "legs",
	"signature_pedigree": "wrist",
	"running_fallaway_moonsault_slam": "legs",
	# The wrist-clutch.
	"finisher_cross_rhodes": "wrist",
	# Strikes, kicks and dives: nothing to hold.
	"signature_superman_punch": "none",
	"signature_disaster_kick": "none",
	"running_bicycle_knee": "none",
	"running_cave_in": "none",
	"running_claymore": "none",
	"running_clothesline_from_hell": "none",
	"running_cyclone_kick": "none",
	"running_gamengiri": "none",
	"running_hoedown": "none",
	"running_knee_lift": "none",
	"running_last_shot": "none",
	"running_leaping_mushroom_stomp": "none",
	"running_leg_lariat": "none",
	"running_play_of_the_day": "none",
	"running_single_leg_dropkick": "none",
	"running_spinning_back_elbow": "none",
}

## Moves the contact pull (GrappleRig._pull_into_reach) leaves alone: the
## cutter is a jump, and drawing his head in put it in the path of the
## attacker's legs a few frames later (6.6 cm, PairClearance).
const NO_PULL := ["signature_cody_cutter"]

## Where a "behind" hand sits past the bone, away from the attacker: round
## the back of the neck or the waist, not on the front of it.
const WRAP := 0.07
## Half a waist, for the two waist hands.
const WAIST_HALF := 0.15
## Half a waist at the hip bones, for "waist_behind".
const WAIST_BEHIND_HALF := 0.17


static func family(move: MoveDef) -> String:
	if move == null:
		return ""
	return MOVES.get(move.resource_path.get_file().get_basename(), "")


## [left target, right target] in world space for `family`, on `opponent`,
## as held by a man whose chest is at `from`. Empty if the bones are missing.
static func targets(family_name: String, opponent: WrestlerController, from: Vector3) -> Array:
	var sk := opponent.skeleton
	if sk == null:
		return []
	var at := func(bone: String) -> Vector3:
		var i := sk.find_bone(opponent._skeleton_bone_name(bone))
		return sk.global_transform * sk.get_bone_global_pose(i).origin if i >= 0 else Vector3.INF
	var neck: Vector3 = at.call("neck_01")
	var chest: Vector3 = at.call("spine_03")
	if neck == Vector3.INF or chest == Vector3.INF:
		return []
	var away := (chest - from)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.001 else Vector3.ZERO
	var upper_back := chest + away * WRAP + Vector3.UP * 0.04
	match family_name:
		"neck":
			return [upper_back, neck + away * WRAP + Vector3.UP * 0.02]
		"waist":
			var hips: Vector3 = at.call("pelvis")
			var side := away.cross(Vector3.UP).normalized() * WAIST_HALF
			return [hips + away * WRAP - side, hips + away * WRAP + side]
		"legs":
			var near: Vector3 = at.call("thigh_l")
			var far: Vector3 = at.call("thigh_r")
			var thigh := near if near.distance_to(from) > far.distance_to(from) else far
			var knee_side: Vector3 = at.call("calf_l" if thigh == near else "calf_r")
			return [upper_back, thigh.lerp(knee_side, 0.35)]
		"facelock":
			var head: Vector3 = at.call("Head")
			return [neck + Vector3.UP * 0.06, head + Vector3.UP * 0.04]
		"wrist":
			var wrist: Vector3 = at.call("hand_r")
			return [neck + away * WRAP, wrist]
		"waist_behind":
			var hips: Vector3 = at.call("pelvis")
			var side := away.cross(Vector3.UP).normalized() * WAIST_BEHIND_HALF
			return [hips + away * 0.03 - side, hips + away * 0.03 + side]
		"wringer":
			var hand: Vector3 = at.call("hand_r")
			var forearm: Vector3 = at.call("lowerarm_r")
			return [hand, forearm.lerp(hand, 0.55)]
	return []
