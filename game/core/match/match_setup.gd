extends Node3D
## Root script for match.tscn. Resolves cross-wrestler NodePaths after the
## scene tree is built (opponent refs can't be wired at parse time in a
## flat .tscn) and starts a deterministic replay recording for the match.

@export var match_seed: int = 1

## Where to write this match's ReplayResource once it ends. Empty in normal
## play; set from the command line by CaptureHarness so a capture can record
## the match it is about to replay. Nothing saved a recording before this
## existed, so there was no replay anywhere in the repo for the capture
## pipeline to consume.
@export var record_replay_path: String = ""

## A ReplayResource to play back instead of recording a fresh match. The
## match seed comes from the replay when one is supplied -- every seeded
## decision in the match (AI jitter, tie-up tie-breaks, grapple tier draws)
## derives from it, so replaying with a different seed would reproduce the
## inputs against a different world.
@export var playback_replay_path: String = ""

@onready var wrestler_a: WrestlerController = $WrestlerA
@onready var wrestler_b: WrestlerController = $WrestlerB
@onready var referee: MatchReferee = $MatchReferee

func _ready() -> void:
	# A capture run supplies its replay paths on the command line;
	# CaptureHarness parses them and is inert without them, so this is a
	# no-op in normal play.
	if CaptureHarness and CaptureHarness.is_capturing():
		if CaptureHarness.replay_to_play() != "":
			playback_replay_path = CaptureHarness.replay_to_play()
		if CaptureHarness.replay_to_record() != "":
			record_replay_path = CaptureHarness.replay_to_record()
	elif CaptureHarness and CaptureHarness.replay_to_record() != "":
		# --record-replay on its own records a match without capturing it,
		# which is how run_capture.sh produces the replay it then captures.
		record_replay_path = CaptureHarness.replay_to_record()

	# A recorded match has to finish. The shipped scene leaves WrestlerA as
	# the human slot, and an AI-vs-passive match is an infinite strike loop
	# that never reaches a finish (see the README's first capture), so a
	# recording run puts both sides on the AI.
	if record_replay_path != "":
		wrestler_a.is_ai = true
		wrestler_b.is_ai = true

	var replay: ReplayResource = null
	if playback_replay_path != "":
		replay = load(playback_replay_path) as ReplayResource
		if replay:
			match_seed = replay.match_seed
		else:
			push_error("Cannot load replay: %s" % playback_replay_path)
	wrestler_a._resolve_paths()
	wrestler_b._resolve_paths()
	referee.match_seed = match_seed
	wrestler_a.match_seed = match_seed
	wrestler_b.match_seed = match_seed
	referee.match_won.connect(_on_match_won)
	# Only matters once both wrestlers are AI (e.g. an AI-vs-AI match) — with
	# a single AI opponent the other side's input is either a human or idle,
	# already naturally distinct. See WrestlerAI.setup_jitter()'s doc comment.
	if wrestler_a.is_ai and wrestler_a.ai:
		wrestler_a.ai.setup_jitter(match_seed, wrestler_a.player_index)
	if wrestler_b.is_ai and wrestler_b.ai:
		wrestler_b.ai.setup_jitter(match_seed, wrestler_b.player_index)
	if ReplaySystem:
		if replay:
			ReplaySystem.start_playback(replay)
		else:
			ReplaySystem.start_recording(match_seed)
	if CaptureHarness:
		CaptureHarness.attach(self)

func _on_match_won(winner: WrestlerController, method: String) -> void:
	print("Match won by %s via %s" % [winner.name, method])
	# Freeze both wrestlers immediately — without this they keep polling
	# input and trying to act next tick, and a defender left mid-pin
	# (PIN_DEFENDER only legally leads to DOWN/GETUP) throws an illegal
	# FSM transition the moment it tries to do anything else post-match.
	wrestler_a.set_physics_process(false)
	wrestler_b.set_physics_process(false)
	_save_replay()
	# A recording run has nothing more to do once the match is decided, and
	# a capture run's harness has already written its manifest.
	if record_replay_path != "" or (CaptureHarness and CaptureHarness.is_capturing()):
		get_tree().quit()

## Writes the recording out, if this run was asked for one. Saved after the
## freeze above so the resource holds exactly the ticks the match ran and
## not a trailing frame from a wrestler still polling.
func _save_replay() -> void:
	if record_replay_path == "" or not ReplaySystem or not ReplaySystem.replay:
		return
	var err := ResourceSaver.save(ReplaySystem.replay, record_replay_path)
	if err != OK:
		push_error("Saving replay to %s failed: %d" % [record_replay_path, err])
		return
	print("Replay saved: %s (%d ticks)"
			% [record_replay_path, ReplaySystem.replay.duration_ticks()])
