class_name MovePlaybook
extends RefCounted
## Where a move belongs in the story of a match, and how often it may be seen
## in one (the owner, 19 Oct: "lots of repetition of moves between Roman and
## Cody ... the flow of the match has to make logical sense";
## gauntlet/refs/ff_ai_flow.md).
##
## Measured before this (flow_probe --moves 1, Roman v Cody, seed 1): the
## Brainbuster at 10 s, 20 s and 39 s, the Sit-Out Powerbomb eleven times,
## the Bionic Elbow 44 times. A televised match saves its biggest moves for
## late and shows each of them once; the slams of the middle a couple of
## times; only the strikes come round again and again.
##
## Read by WrestlerController._pick_tier_move() for the AI. Presentation of
## the story, not the rules: a man on the controller picks from his whole
## tier, and anything the story has run out of still beats throwing nothing.

## The earliest part of the match a move belongs to (MatchFlow.story_place):
## the opening, the middle (the heat and the hope), or the stretch run.
enum Place { BASIC, MID, LATE }

## Moves whose place or allowance is not the one their name gives them.
## [place, uses a match; 0 is unlimited].
const OVERRIDES := {
	&"power_bodyslam": [Place.BASIC, 3],
	&"ff_powerbomb_1": [Place.MID, 1],
	&"ff_spinebuster_5": [Place.MID, 1],
	&"ff_chokeslam_1": [Place.MID, 1],
}


static func _entry(move: MoveDef) -> Array:
	if move == null:
		return [Place.BASIC, 0]
	var id := move.animation_pair_id
	if OVERRIDES.has(id):
		return OVERRIDES[id]
	var s := String(id)
	if s.begins_with("strike_") or s.begins_with("ground_"):
		return [Place.BASIC, 0]
	if s.begins_with("grapple_"):
		return [Place.BASIC, 3]
	if s.begins_with("running_"):
		return [Place.BASIC, 2]
	if s.begins_with("power_"):
		return [Place.MID, 2]
	if s.begins_with("signature_"):
		return [Place.MID, 2]
	if s.begins_with("finisher_"):
		return [Place.LATE, 0]
	if s.begins_with("ff_"):
		# The library's specials: the big moves of the stretch run.
		return [Place.LATE, 1]
	return [Place.BASIC, 0]


## The earliest place in the match `move` belongs (Place).
static func place_of(move: MoveDef) -> int:
	return int(_entry(move)[0])


## How many times a match `move` may be thrown; 0 is no limit.
static func max_uses(move: MoveDef) -> int:
	return int(_entry(move)[1])
