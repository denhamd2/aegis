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
}

## Adjacency list of legal transitions. Anything not listed here is illegal.
const LEGAL_TRANSITIONS := {
	State.IDLE: [State.LOCOMOTION, State.RUN, State.STRIKE, State.TIE_UP, State.HIT_REACT, State.STUNNED],
	State.LOCOMOTION: [State.IDLE, State.RUN, State.STRIKE, State.TIE_UP, State.HIT_REACT, State.STUNNED],
	State.RUN: [State.LOCOMOTION, State.RUNNING_ATTACK, State.IDLE, State.HIT_REACT, State.STUNNED],
	State.STRIKE: [State.IDLE, State.LOCOMOTION, State.HIT_REACT, State.STUNNED],
	State.TIE_UP: [State.GRAPPLE_HOLD, State.IDLE, State.HIT_REACT],
	State.GRAPPLE_HOLD: [State.MOVE_EXEC, State.IRISH_WHIP, State.IDLE, State.FINISHER],
	State.MOVE_EXEC: [State.DOWN, State.IDLE, State.HIT_REACT, State.PIN_ATTACKER],
	State.HIT_REACT: [State.IDLE, State.DOWN, State.STUNNED],
	State.DOWN: [State.GETUP, State.PIN_DEFENDER, State.SUBMISSION_DEFENDER],
	State.GETUP: [State.IDLE, State.HIT_REACT],
	State.IRISH_WHIP: [State.RUN, State.HIT_REACT],
	State.RUNNING_ATTACK: [State.IDLE, State.HIT_REACT, State.DOWN],
	State.STUNNED: [State.IDLE, State.HIT_REACT, State.DOWN],
	State.PIN_ATTACKER: [State.IDLE, State.FINISHER],
	State.PIN_DEFENDER: [State.DOWN, State.GETUP],
	State.SUBMISSION_ATTACKER: [State.IDLE],
	State.SUBMISSION_DEFENDER: [State.DOWN, State.SUBMISSION_DEFENDER],
	State.FINISHER: [State.PIN_ATTACKER, State.IDLE],
}

signal state_changed(previous: State, current: State)

var current_state: State = State.IDLE
var ticks_in_state: int = 0

func _physics_process(_delta: float) -> void:
	ticks_in_state += 1

func transition_to(next_state: State) -> void:
	var legal: Array = LEGAL_TRANSITIONS.get(current_state, [])
	assert(legal.has(next_state),
		"Illegal FSM transition: %s -> %s" % [State.keys()[current_state], State.keys()[next_state]])
	var previous := current_state
	current_state = next_state
	ticks_in_state = 0
	state_changed.emit(previous, current_state)

func is_in(states: Array) -> bool:
	return states.has(current_state)
