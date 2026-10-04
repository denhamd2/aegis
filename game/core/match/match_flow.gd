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
##  * it scales how often each man acts (tempo_scale(), read by WrestlerAI):
##    the heel works slow, the man being worked over rarely answers;
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
## actions (above 1 he is slower). `reverse`: the multiplier on how often he
## reads and parries a blow. `rung`: the highest move the AI may reach for --
## "none", "signature" or "finisher". `stall`: whether he plays to the crowd
## between holds. Keyed by the man's persona; a neutral pair takes the neutral
## row on both sides.
const PHASES := [
	{"name": "feeling_out", "until": 60.0,
			"heel": {"takes": 0.30, "tempo": 1.30, "reverse": 1.0, "rung": "none", "stall": false},
			"face": {"takes": 0.30, "tempo": 1.30, "reverse": 1.0, "rung": "none", "stall": false},
			"neutral": {"takes": 0.30, "tempo": 1.30, "reverse": 1.0, "rung": "none", "stall": false}},
	{"name": "heat", "until": 210.0,
			"heel": {"takes": 0.10, "tempo": 1.05, "reverse": 1.0, "rung": "signature", "stall": true},
			"face": {"takes": 0.55, "tempo": 2.4, "reverse": 0.25, "rung": "none", "stall": false},
			"neutral": {"takes": 0.30, "tempo": 1.30, "reverse": 1.0, "rung": "signature", "stall": false}},
	{"name": "hope", "until": 245.0,
			"heel": {"takes": 0.45, "tempo": 1.4, "reverse": 0.6, "rung": "none", "stall": false},
			"face": {"takes": 0.20, "tempo": 0.85, "reverse": 1.5, "rung": "signature", "stall": false},
			"neutral": {"takes": 0.30, "tempo": 1.2, "reverse": 1.0, "rung": "signature", "stall": false}},
	{"name": "cutoff", "until": 300.0,
			"heel": {"takes": 0.10, "tempo": 0.95, "reverse": 1.0, "rung": "signature", "stall": true},
			"face": {"takes": 0.55, "tempo": 2.2, "reverse": 0.3, "rung": "none", "stall": false},
			"neutral": {"takes": 0.30, "tempo": 1.3, "reverse": 1.0, "rung": "signature", "stall": false}},
	{"name": "comeback", "until": 390.0,
			"heel": {"takes": 0.60, "tempo": 1.7, "reverse": 0.8, "rung": "signature", "stall": false},
			"face": {"takes": 0.20, "tempo": 0.8, "reverse": 1.4, "rung": "finisher", "stall": false},
			"neutral": {"takes": 0.35, "tempo": 1.2, "reverse": 1.0, "rung": "finisher", "stall": false}},
	# The finish is the winner's: which of them it is was settled at the bell
	# (WINNER_ROWS / LOSER_ROW below); these rows are the neutral fallback.
	{"name": "finish", "until": 1.0e9,
			"heel": {"takes": 0.60, "tempo": 1.0, "reverse": 1.0, "rung": "finisher", "stall": false},
			"face": {"takes": 0.60, "tempo": 1.0, "reverse": 1.0, "rung": "finisher", "stall": false},
			"neutral": {"takes": 0.55, "tempo": 1.0, "reverse": 1.0, "rung": "finisher", "stall": false}},
]
## In the finish the man the story is for gets the finisher and is barely
## marked; the other has a signature at most and takes it.
const WINNER_ROW := {"takes": 0.30, "tempo": 0.9, "reverse": 1.2, "rung": "finisher", "stall": false}
const LOSER_ROW := {"takes": 0.90, "tempo": 1.7, "reverse": 0.6, "rung": "none", "stall": false}
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
	if p["name"] == "finish" and winner != null:
		return WINNER_ROW if w == winner else LOSER_ROW
	return row(p, _kind.get(w, Persona.Kind.NEUTRAL))


## The multiplier on `w`'s wait between actions right now (1 = as authored).
func tempo_scale(w: WrestlerController) -> float:
	return float(_row_for(w)["tempo"])


## Whether a man pinned under a finisher has no kickout left in him.
func no_kickout_left() -> bool:
	return finisher_kickouts >= FINISHER_KICKOUTS_MAX


## How often `w` reads and parries a blow right now (1 = as authored).
func reverse_scale(w: WrestlerController) -> float:
	return float(_row_for(w)["reverse"])


## Whether `w` plays to the crowd between holds right now (the heel in control).
func wants_stall(w: WrestlerController) -> bool:
	return bool(_row_for(w)["stall"])


## The highest rung (move tier) the AI may reach for now: "none",
## "signature" or "finisher".
func rung(w: WrestlerController) -> String:
	return String(_row_for(w)["rung"])


## Whether a finisher may end the match now.
func finish_allowed() -> bool:
	return seconds() >= FINISH_FROM


func _apply() -> void:
	for w: WrestlerController in _wrestlers:
		w.combat.damage_taken_scale = damage_taken_scale(w)
		# What the AI may reach for. A human is never held back from a move he
		# has earned: the story is the AI's to keep, not the player's.
		var r := rung(w)
		w.combat.signature_blocked = w.is_ai and r == "none"
		w.combat.finisher_blocked = w.is_ai and r != "finisher"
