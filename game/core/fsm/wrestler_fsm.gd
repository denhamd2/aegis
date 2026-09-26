class_name WrestlerFSM
extends Node
## Deterministic finite-state machine driving a single wrestler.
##
## Runs exclusively from _physics_process at the project's fixed 60 Hz tick.
## Illegal transitions assert in debug builds so grey-box and gauntlet
## builders discover FSM violations immediately instead of at capture time.

enum State {
	IDLE,
	LOCOMOTION,
	RUN,
	STRIKE,
	TIE_UP,
	GRAPPLE_HOLD,
	MOVE_EXEC,
	HIT_REACT,
	DOWN,
	GETUP,
	IRISH_WHIP,
	RUNNING_ATTACK,
	STUNNED,
	PIN_ATTACKER,
	PIN_DEFENDER,
	SUBMISSION_ATTACKER,
	SUBMISSION_DEFENDER,
	FINISHER,
	## The winner's celebration. Terminal: the match is over, so nothing
	## leads out of it and no timeout applies.
	VICTORY,
	## The walk to the ring, before the match exists. Reachable only from
	## IDLE, driven only by EntranceDirector, and gone by the referee's first
	## tick -- so no match state leads into it and nothing in the tick reads
	## it.
	##
	## It is in the enum rather than outside the FSM because
	## WrestlerController builds its blend graph from LEGAL_TRANSITIONS and
	## STATE_ANIMATIONS: a pose the FSM does not know about has no node in the
	## AnimationNodeStateMachine and so could not be cross-faded into IDLE at
	## the handoff -- the wrestler would pop from his last walking frame into
	## the ready stance on the tick the match starts.
	##
	## APPENDED, not inserted before IDLE where it belongs in reading order,
	## for the reason Roster's comment gives about Kenny: nothing here
	## serialises a state's ordinal today (the replay stores inputs, and
	## compute_end_state_hash() takes the seed, the tick count, damage and
	## momentum), but renumbering sixteen match states to make room for a
	## cosmetic one is a large, silent blast radius for no gain.
	ENTRANCE,
}

## Adjacency list of legal transitions. Anything not listed here is illegal.
const LEGAL_TRANSITIONS := {
	# The entrance, and the one way out of it. IDLE -> ENTRANCE is how the
	# director takes a wrestler who has just been built; ENTRANCE -> IDLE is
	# the handoff to the match. Nothing else on either side: a wrestler cannot
	# walk out of a tie-up, and a man on the ramp cannot strike.
	State.ENTRANCE: [State.IDLE],
	State.IDLE: [State.ENTRANCE, State.LOCOMOTION, State.RUN, State.STRIKE, State.TIE_UP, State.HIT_REACT, State.STUNNED, State.PIN_ATTACKER, State.SUBMISSION_ATTACKER, State.VICTORY],
	State.LOCOMOTION: [State.IDLE, State.RUN, State.STRIKE, State.TIE_UP, State.HIT_REACT, State.STUNNED, State.PIN_ATTACKER, State.SUBMISSION_ATTACKER, State.VICTORY],
	State.RUN: [State.LOCOMOTION, State.RUNNING_ATTACK, State.IDLE, State.HIT_REACT, State.STUNNED, State.VICTORY],
	State.STRIKE: [State.IDLE, State.LOCOMOTION, State.HIT_REACT, State.STUNNED, State.VICTORY],
	State.TIE_UP: [State.GRAPPLE_HOLD, State.IDLE, State.HIT_REACT, State.VICTORY],
	State.GRAPPLE_HOLD: [State.MOVE_EXEC, State.IRISH_WHIP, State.IDLE, State.FINISHER, State.VICTORY],
	State.MOVE_EXEC: [State.DOWN, State.IDLE, State.HIT_REACT, State.PIN_ATTACKER, State.VICTORY],
	State.HIT_REACT: [State.IDLE, State.DOWN, State.STUNNED, State.VICTORY],
	State.DOWN: [State.GETUP, State.PIN_DEFENDER, State.SUBMISSION_DEFENDER, State.VICTORY],
	State.GETUP: [State.IDLE, State.HIT_REACT, State.VICTORY],
	State.IRISH_WHIP: [State.RUN, State.HIT_REACT, State.VICTORY],
	State.RUNNING_ATTACK: [State.IDLE, State.HIT_REACT, State.DOWN, State.VICTORY],
	State.STUNNED: [State.IDLE, State.HIT_REACT, State.DOWN, State.VICTORY],
	State.PIN_ATTACKER: [State.IDLE, State.FINISHER, State.VICTORY],
	State.PIN_DEFENDER: [State.DOWN, State.GETUP, State.VICTORY],
	State.SUBMISSION_ATTACKER: [State.IDLE, State.VICTORY],
	State.SUBMISSION_DEFENDER: [State.DOWN, State.SUBMISSION_DEFENDER, State.VICTORY],
	State.FINISHER: [State.PIN_ATTACKER, State.IDLE, State.VICTORY],
	State.VICTORY: [],
}

signal state_changed(previous: State, current: State)

var current_state: State = State.IDLE
var ticks_in_state: int = 0

func _physics_process(_delta: float) -> void:
	ticks_in_state += 1

func transition_to(next_state: State) -> void:
	if next_state == current_state:
		ticks_in_state = 0
		return
	var legal: Array = LEGAL_TRANSITIONS.get(current_state, [])
	assert(legal.has(next_state),
		"Illegal FSM transition: %s -> %s" % [State.keys()[current_state], State.keys()[next_state]])
	var previous := current_state
	current_state = next_state
	ticks_in_state = 0
	state_changed.emit(previous, current_state)

func is_in(states: Array) -> bool:
	return states.has(current_state)
