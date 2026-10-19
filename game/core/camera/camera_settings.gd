class_name CameraSettings
extends RefCounted
## The camera options 2K26 exposes (gauntlet/refs/camera_aaa_plan.md, D2):
## which camera covers the match, whether it cuts to the action, how hard it
## shakes, and when it shows a replay. Static, so the title screen's options
## and the command line set them once and every camera reads them.
##
## Command line (after `--`): --camera ff|gameplay|broadcast, --cuts on|off,
## --shake off|low|high, --replays off|finish|frequent, --motion-blur on|off.

enum Coverage { GAMEPLAY, BROADCAST, FIGHT_FOREVER }
enum Shake { OFF, LOW, HIGH }
enum Replays { OFF, FINISH, FREQUENT }

## FIGHT_FOREVER is the default (the owner, 18 October: in-match animation
## and camera to AEW Fight Forever's style, replacing the 2K26 tuning): a high,
## wide camera following the pair from one side, cut to a low ringside close-up
## for every grapple and back out wide on the impact
## (gauntlet/refs/aew_ff_animation_review.md).
## GAMEPLAY is the 2K-style dynamic ringside camera cut with the hard camera;
## BROADCAST stays on the hard camera and its handheld on the shot clock
## (2K26's Watch Show), which is what reads best for AI-vs-AI.
static var coverage := Coverage.FIGHT_FOREVER
static var cuts := true
static var shake := Shake.LOW
static var replays := Replays.FINISH
## Camera motion blur (MotionBlur): on, where the renderer supports it.
static var motion_blur := true

const SHAKE_SCALE := {Shake.OFF: 0.0, Shake.LOW: 1.0, Shake.HIGH: 1.8}

static var _read := false


static func shake_scale() -> float:
	_read_command_line()
	return SHAKE_SCALE[shake]


static func cuts_enabled() -> bool:
	_read_command_line()
	return cuts


static func fight_forever() -> bool:
	_read_command_line()
	return coverage == Coverage.FIGHT_FOREVER


static func gameplay() -> bool:
	_read_command_line()
	return coverage == Coverage.GAMEPLAY


static func motion_blur_enabled() -> bool:
	_read_command_line()
	return motion_blur


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
				coverage = {"broadcast": Coverage.BROADCAST, "gameplay": Coverage.GAMEPLAY}.get(
						v, Coverage.FIGHT_FOREVER)
			"--cuts":
				cuts = v != "off"
			"--shake":
				shake = {"off": Shake.OFF, "high": Shake.HIGH}.get(v, Shake.LOW)
			"--motion-blur":
				motion_blur = v != "off"
			"--replays":
				replays = {"off": Replays.OFF, "frequent": Replays.FREQUENT}.get(v, Replays.FINISH)
