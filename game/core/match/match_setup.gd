extends Node3D
## Root script for match.tscn. Resolves cross-wrestler NodePaths after the
## scene tree is built (opponent refs can't be wired at parse time in a
## flat .tscn) and starts a deterministic replay recording for the match.

@export var match_seed: int = 1

@onready var wrestler_a: WrestlerController = $WrestlerA
@onready var wrestler_b: WrestlerController = $WrestlerB
@onready var referee: MatchReferee = $MatchReferee

func _ready() -> void:
	wrestler_a._resolve_paths()
	wrestler_b._resolve_paths()
	referee.match_seed = match_seed
	referee.match_won.connect(_on_match_won)
	if ReplaySystem:
		ReplaySystem.start_recording(match_seed)

func _on_match_won(winner: WrestlerController, method: String) -> void:
	print("Match won by %s via %s" % [winner.name, method])
	# Freeze both wrestlers immediately — without this they keep polling
	# input and trying to act next tick, and a defender left mid-pin
	# (PIN_DEFENDER only legally leads to DOWN/GETUP) throws an illegal
	# FSM transition the moment it tries to do anything else post-match.
	wrestler_a.set_physics_process(false)
	wrestler_b.set_physics_process(false)
