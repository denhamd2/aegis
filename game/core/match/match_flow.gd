class_name MatchFlow
extends Node
## The shape of the match: a televised bout is a story told in an order -- a
## feeling-out, the heel in control, the face's hope, the cut-off, the
## comeback, the near-falls and the finish -- not two men trading blows until
## one has had enough. This director sets the pace.
##
## It does three things, all as a function of the match clock and each man's
## persona (Persona: Roman the heel, Cody the face), so it is deterministic
## and the same seed plays the same match:
##
##  * it scales the damage each man takes (CombatSystem.damage_taken_scale),
##    so the man being beaten down is beaten down slowly and the man in
##    control is barely marked;
##  * it adds small, bounded cadence variation (tempo_scale(), read by
##    WrestlerAI) without letting a story phase create long idle gaps;
##  * it decides when a finisher can end the match (finish_allowed()): before
##    that a finisher is a near-fall, which is also how the match gets its
##    kickouts of a finisher.
##
## Together with CombatSystem's recoverable wear (the green part of the bar,
## which comes back while nobody is hitting him) this is what makes a match
## last minutes, not seconds. gauntlet/refs/aaa_master_plan.md, Stage 6.
##
## Gameplay, not presentation: it changes what a match does, so it sits in the
## hash. It reads only the tick count and the two men's state; no randomness.

## What each phase asks of each man. `takes`: the share of damage he takes
## (1.0 = as authored). `tempo`: the multiplier on the wait between his
## actions (above 1 is slower; AI tempo is capped at 1). `reverse`: how often
## he reads and parries a blow. `rung`: the highest move the AI may reach for --
## "none", "signature" or "finisher". `stall`: whether he plays to the crowd
## between holds. `lead`: his share of the offence (initiative()). Keyed by
## the man's persona; a neutral pair takes the neutral row on both sides.
const PHASES := [
	{"name": "feeling_out", "until": 60.0,
			"heel": {"takes": 0.30, "tempo": 0.95, "reverse": 1.0, "rung": "none", "stall": false, "lead": 0.6},
			"face": {"takes": 0.30, "tempo": 0.95, "reverse": 1.0, "rung": "none", "stall": false, "lead": 0.6},
			"neutral": {"takes": 0.30, "tempo": 0.95, "reverse": 1.0, "rung": "none", "stall": false, "lead": 1.0}},
	{"name": "heat", "until": 210.0,
			"heel": {"takes": 0.10, "tempo": 0.90, "reverse": 1.0, "rung": "signature", "stall": true, "lead": 1.0},
			"face": {"takes": 0.55, "tempo": 1.0, "reverse": 0.25, "rung": "none", "stall": false, "lead": 0.3},
			"neutral": {"takes": 0.30, "tempo": 0.95, "reverse": 1.0, "rung": "signature", "stall": false, "lead": 1.0}},
	{"name": "hope", "until": 245.0,
			"heel": {"takes": 0.45, "tempo": 0.95, "reverse": 0.6, "rung": "none", "stall": false, "lead": 0.4},
			"face": {"takes": 0.20, "tempo": 0.85, "reverse": 1.5, "rung": "signature", "stall": false, "lead": 1.0},
			"neutral": {"takes": 0.30, "tempo": 0.95, "reverse": 1.0, "rung": "signature", "stall": false, "lead": 1.0}},
	{"name": "cutoff", "until": 300.0,
			"heel": {"takes": 0.10, "tempo": 0.90, "reverse": 1.0, "rung": "signature", "stall": true, "lead": 1.0},
			"face": {"takes": 0.55, "tempo": 1.0, "reverse": 0.3, "rung": "none", "stall": false, "lead": 0.3},
			"neutral": {"takes": 0.30, "tempo": 0.95, "reverse": 1.0, "rung": "signature", "stall": false, "lead": 1.0}},
	{"name": "comeback", "until": 420.0,
			"heel": {"takes": 0.60, "tempo": 0.95, "reverse": 0.8, "rung": "signature", "stall": false, "lead": 0.3},
			"face": {"takes": 0.20, "tempo": 0.8, "reverse": 1.4, "rung": "finisher", "stall": false, "lead": 1.0},
			"neutral": {"takes": 0.35, "tempo": 0.95, "reverse": 1.0, "rung": "finisher", "stall": false, "lead": 1.0}},
	# The finish is the winner's: which of them it is was settled at the bell
	# (WINNER_ROWS / LOSER_ROW below); these rows are the neutral fallback.
	{"name": "finish", "until": 1.0e9,
			"heel": {"takes": 0.60, "tempo": 0.90, "reverse": 1.0, "rung": "finisher", "stall": false, "lead": 0.8},
			"face": {"takes": 0.60, "tempo": 0.90, "reverse": 1.0, "rung": "finisher", "stall": false, "lead": 0.8},
			"neutral": {"takes": 0.55, "tempo": 0.95, "reverse": 1.0, "rung": "finisher", "stall": false, "lead": 1.0}},
]
## In the finish the man the story is for gets the finisher and is barely
## marked; the other has a signature at most and takes it.
const WINNER_ROW := {"takes": 0.30, "tempo": 0.85, "reverse": 1.2, "rung": "finisher", "stall": false,
		"lead": 1.0}
const LOSER_ROW := {"takes": 0.90, "tempo": 0.95, "reverse": 0.6, "rung": "none", "stall": false,
		"lead": 0.25}
## A finisher can end the match from this second on (before it, a cover off a
## finisher is a near-fall). Matches that run long are ended anyway.
const FINISH_FROM := 420.0
## Once the match may end, a man kicks out of this many finishers and no more:
## the near-fall the crowd comes out of its seats for, and then the finish.
const FINISHER_KICKOUTS_MAX := 1

var tick := 0
## Kickouts of a finisher that could have ended the match (MatchReferee).
var finisher_kickouts := 0
## Who the finish is for, settled at the bell from the match seed: the heel
## wins about half of them, the face the rest.
var winner: WrestlerController = null
var _wrestlers: Array = []
var _kind := {}


func watch(wrestlers: Array) -> void:
	_wrestlers = wrestlers
	for w: WrestlerController in wrestlers:
		_kind[w] = Persona.of(w.display_name)
		w.flow = self
	winner = pick_winner(wrestlers, int((wrestlers[0] as WrestlerController).match_seed))
	_apply()


## The man the finish is for: by the seed, so the same seed tells the same
## story and different seeds tell both.
static func pick_winner(wrestlers: Array, match_seed: int) -> WrestlerController:
	var roll: int = absi(match_seed * 2654435761 >> 7) % 2
	return wrestlers[roll]


func _physics_process(_delta: float) -> void:
	tick += 1
	if tick % 30 == 0:
		_apply()


func seconds() -> float:
	return float(tick) / 60.0


## The phase the clock is in.
func phase() -> Dictionary:
	return phase_at(seconds())


static func phase_at(clock: float) -> Dictionary:
	for p: Dictionary in PHASES:
		if clock < float(p["until"]):
			return p
	return PHASES[PHASES.size() - 1]


static func row(p: Dictionary, kind: int) -> Dictionary:
	match kind:
		Persona.Kind.HEEL:
			return p["heel"]
		Persona.Kind.FACE:
			return p["face"]
	return p["neutral"]


## The share of damage `w` takes right now.
func damage_taken_scale(w: WrestlerController) -> float:
	return float(_row_for(w)["takes"])


## What the phase asks of `w`: his persona's row, or in the finish the
## winner's or the loser's.
func _row_for(w: WrestlerController) -> Dictionary:
	var p := phase()
	# A man on the controller is nobody's character to play: he gets the
	# neutral row, so the story does not decide his exchanges for him.
	if not w.is_ai:
		return p["neutral"]
	if p["name"] == "finish" and winner != null:
		return WINNER_ROW if w == winner else LOSER_ROW
	return row(p, _kind.get(w, Persona.Kind.NEUTRAL))


## The multiplier on `w`'s wait between actions right now (1 = as authored).
func tempo_scale(w: WrestlerController) -> float:
	return clampf(float(_row_for(w)["tempo"]), 0.75, 1.0)


## Whether a man pinned under a finisher has no kickout left in him.
func no_kickout_left() -> bool:
	return finisher_kickouts >= FINISHER_KICKOUTS_MAX


## How often `w` reads and parries a blow right now (1 = as authored).
func reverse_scale(w: WrestlerController) -> float:
	return float(_row_for(w)["reverse"])


## Whether `w` plays to the crowd between holds right now (the heel in control).
func wants_stall(w: WrestlerController) -> bool:
	return bool(_row_for(w)["stall"])


## How much of the offence is `w`'s right now (0-1): the share of his
## chances to strike or lock up that the AI takes. The man the phase is for
## works; the other sells and fights back in bursts (the heel's heat, the
## face's hope and comeback; gauntlet/refs/ff_ai_flow.md). Measured before
## this, Cody threw 240 moves to Roman's 103 in a match whose heat is Roman's,
## and nobody held control for more than three moves.
func initiative(w: WrestlerController) -> float:
	return float(_row_for(w).get("lead", 1.0))


## How far into the story the AI may reach for a move (MovePlaybook.Place):
## the opening's moves at first, the slams of the middle from the heat, the
## big moves for the comeback and the finish.
func story_place(w: WrestlerController) -> int:
	if not w.is_ai:
		return MovePlaybook.Place.LATE
	match String(phase()["name"]):
		"feeling_out":
			return MovePlaybook.Place.BASIC
		"heat", "hope", "cutoff":
			return MovePlaybook.Place.MID
	return MovePlaybook.Place.LATE


## The highest rung (move tier) the AI may reach for now: "none",
## "signature" or "finisher".
func rung(w: WrestlerController) -> String:
	return String(_row_for(w)["rung"])


## Whether a finisher may end the match now.
func finish_allowed() -> bool:
	return seconds() >= FINISH_FROM


## Into the finish this long without his finisher, the man the story is for
## is handed it: the meter to the signature and the finisher lit, as a taunt
## would (CombatSystem.taunted). Measured, the winner could otherwise spend
## four minutes in control without the meter coming round, and the match ran
## out with no winner (flow_probe seed 2).
const FINISH_NUDGE_AFTER := 30.0


func _apply() -> void:
	if winner != null and winner.is_ai and finish_allowed() \
			and seconds() >= FINISH_FROM + FINISH_NUDGE_AFTER \
			and not winner.combat.can_finisher() and not winner.combat.finisher_resting():
		winner.combat.momentum = maxf(winner.combat.momentum, CombatSystem.SIGNATURE_THRESHOLD)
		winner.combat.finisher_lit = true
	for w: WrestlerController in _wrestlers:
		w.combat.damage_taken_scale = damage_taken_scale(w)
		# What the AI may reach for. A human is never held back from a move he
		# has earned: the story is the AI's to keep, not the player's.
		var r := rung(w)
		w.combat.signature_blocked = w.is_ai and r == "none"
		w.combat.finisher_blocked = w.is_ai and r != "finisher"
