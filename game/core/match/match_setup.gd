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

## Walk the two wrestlers out before the match starts.
##
## FALSE by default, and that default is load-bearing rather than cautious.
## `ARCHITECTURE.md` makes determinism a hard requirement and the README
## records that the AI-vs-AI probes return byte-identical output run to run, so
## an entrance is only allowed to exist on a path nothing measures: the ten
## places the suite instantiates this scene, the probes under tools/probe/,
## scenes/play.tscn and tools/capture/run_capture.sh all get an un-configured
## instance and so get no entrance at all.
##
## `TitleScreen.configure_entrances()` is the one caller that sets it, and it is
## deliberately NOT `configure_match()`: nine probes call that one, and setting
## the flag there gave every one of them an entrance -- ladder_probe's seed 1
## went from 914 ticks to 5119. See that function's comment, and
## tests/test_entrance_is_off_by_default.gd, which is the standing guard.
@export var play_entrances: bool = false

## Roster entries, player first, for the nameplate and the accent colour. Set
## alongside `play_entrances` by TitleScreen; empty means the entrance runs with
## a neutral plate rather than refusing to run.
var entrance_entries: Array = []

@onready var wrestler_a: WrestlerController = $WrestlerA
@onready var wrestler_b: WrestlerController = $WrestlerB
@onready var referee: MatchReferee = $MatchReferee
@onready var entrance: EntranceDirector = $EntranceDirector

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

	# The entrances go HERE: after every wire is made and before the recording
	# starts. Both of those matter.
	#
	# After the wiring, because the director walks real WrestlerControllers with
	# their models installed and their FSMs built -- it is not a cutscene played
	# by stand-ins, and a wrestler whose paths were not resolved has no
	# AnimationTree to walk with.
	#
	# Before `start_recording()`, because the replay's tick 0 has to be the
	# match's tick 0. Start it first and the recording carries however many
	# thousand ticks the walk took, `duration_ticks()` stops meaning the length
	# of the match, and every capture built on the replay is offset by an
	# entrance.
	if play_entrances:
		await _run_entrances()

	if ReplaySystem:
		if replay:
			ReplaySystem.start_playback(replay)
		else:
			ReplaySystem.start_recording(match_seed)
	if CaptureHarness:
		CaptureHarness.attach(self)


## Hands the director everything it needs and waits for the walk.
##
## It looks things up here rather than in the director because this is the
## script that owns scenes/match.tscn's shape: the director takes nodes, so it
## can be run in a test against a fixture that has no arena in it at all.
func _run_entrances() -> void:
	if entrance == null:
		push_error("play_entrances is set but scenes/match.tscn has no "
				+ "EntranceDirector")
		return
	entrance.wrestlers = [wrestler_a, wrestler_b]
	entrance.entries = entrance_entries
	entrance.referee = referee
	entrance.match_camera = get_node_or_null("MatchCamera")
	entrance.camera = get_node_or_null("EntranceCamera")
	entrance.hud = get_node_or_null("MatchHUD")
	entrance.arena = get_node_or_null("Arena")
	entrance.lighting = get_node_or_null("LightRig")
	if entrance.nameplate == null:
		entrance.nameplate = get_node_or_null("EntranceOverlay/Plate")
	await entrance.run()

func _on_match_won(winner: WrestlerController, method: String) -> void:
	print("Match won by %s via %s" % [winner.name, method])
	# The winner celebrates. Done BEFORE the freeze below, because it is a
	# real FSM transition and the freeze stops the controller processing --
	# the clip itself keeps playing either way, since the AnimationTree runs
	# on its own and does not depend on _physics_process.
	if winner and winner.has_method("celebrate"):
		winner.celebrate()
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
