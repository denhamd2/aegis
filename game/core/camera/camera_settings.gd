class_name CameraSettings
extends RefCounted
## The camera options 2K26 exposes (gauntlet/refs/camera_aaa_plan.md, D2):
## which camera covers the match, whether it cuts to the action, how hard it
## shakes, and when it shows a replay. Static, so the title screen's options
## and the command line set them once and every camera reads them.
##
## Command line (after `--`): --camera gameplay|broadcast, --cuts on|off,
## --shake off|low|high, --replays off|finish|frequent.

enum Coverage { GAMEPLAY, BROADCAST }
enum Shake { OFF, LOW, HIGH }
enum Replays { OFF, FINISH, FREQUENT }

## GAMEPLAY is the 2K-style dynamic ringside camera cut with the hard camera;
## BROADCAST stays on the hard camera and its handheld on the shot clock
## (2K26's Watch Show), which is what reads best for AI-vs-AI.
static var coverage := Coverage.GAMEPLAY
static var cuts := true
static var shake := Shake.LOW
static var replays := Replays.FINISH

const SHAKE_SCALE := {Shake.OFF: 0.0, Shake.LOW: 1.0, Shake.HIGH: 1.8}

static var _read := false


static func shake_scale() -> float:
	_read_command_line()
	return SHAKE_SCALE[shake]


static func cuts_enabled() -> bool:
	_read_command_line()
	return cuts


static func gameplay() -> bool:
	_read_command_line()
	return coverage == Coverage.GAMEPLAY


static func replay_finish() -> bool:
	_read_command_line()
	return replays != Replays.OFF


## FREQUENT: big moves replayed mid-match too (InstantReplay).
static func replay_frequent() -> bool:
	_read_command_line()
	return replays == Replays.FREQUENT


static func _read_command_line() -> void:
	if _read:
		return
	_read = true
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		var v := String(args[i + 1])
		match args[i]:
			"--camera":
				coverage = Coverage.BROADCAST if v == "broadcast" else Coverage.GAMEPLAY
			"--cuts":
				cuts = v != "off"
			"--shake":
				shake = {"off": Shake.OFF, "high": Shake.HIGH}.get(v, Shake.LOW)
			"--replays":
				replays = {"off": Replays.OFF, "frequent": Replays.FREQUENT}.get(v, Replays.FINISH)
