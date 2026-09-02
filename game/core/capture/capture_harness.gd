extends Node
## Autoload. Drives a headless-ish, frame-stable capture of a replay for
## gauntlet critics: plays a ReplayResource under Movie Maker mode, dumps a
## labeled PNG at each beat of the match, and writes the
## capture_manifest.json that tools/capture/evidence_gate.py validates
## before any critic sees the capture.
##
## Invoked via tools/capture/run_capture.sh. Completely inert without its
## command-line arguments, so it never runs during normal play.
##
## None of this ran before. configure(), on_tick() and finish() had no
## callers anywhere, nothing parsed run_capture.sh's --capture-replay or
## --capture-output, and no manifest was ever written -- so the script
## exited 2 ("round is void") on every invocation it had ever had, and
## ARCHITECTURE.md's evidence gate was a description of machinery that did
## not exist.

signal capture_finished(manifest_path: String)

## The beats a capture dumps, per ARCHITECTURE.md.
const BEAT_LABELS := ["tie_up", "apex", "impact", "pin_start", "three_count"]

## The three every match must reach. A capture missing a tie-up, an apex or
## an impact is a broken capture and should void the round.
const ALWAYS_EXPECTED := ["tie_up", "apex", "impact"]

## The other two depend on how the match ends, and the manifest's expected
## frame count is computed from what actually happened rather than demanding
## all five unconditionally.
##
## Measured, before assuming: across 24 seeds every AI-vs-AI match ends by
## submission and not one ends by pinfall, so a flat "all five beats"
## expectation would void every capture the project can currently produce --
## not because the capture is broken but because the match legitimately had
## no pinfall in it. A gate that fails on correct input is not a gate.
## Skipped beats are named in the manifest with their reason so a critic can
## see what the capture does and does not show.

## How much of a paired move has played when its "apex" frame is taken.
## The trajectories put the victim at maximum height around the middle of
## the clip (see resources/animations/paired_recipes.gd).
const APEX_FRACTION := 0.5

## Fraction of the frame's width and height, in from each bottom corner,
## sampled to decide whether a HUD is really on screen. Sized to sit inside
## MatchHUD's plates without touching their edges.
const HUD_PROBE_WIDTH := 0.14
const HUD_PROBE_HEIGHT := 0.07
const HUD_PROBE_MARGIN := 0.03
## What the probe looks for: pixels of MatchHUD's vitality green, which is
## strongly green-dominant and appears nowhere in the ring (the mat is grey,
## the ropes red/white/blue, the wrestlers orange).
##
## The first version of this looked for luma *variance* instead, reasoning
## that a dark plate with bright bars stands out against a flat background.
## It does not: the negative test -- hide the HUD, re-run, the gate must
## fail -- passed anyway, because at the apex beat the bottom corners hold
## the bright ring mat against the dark hall and measure 0.61 range with no
## HUD at all. Measured across every beat frame of both runs, green-dominant
## pixels are 41-42% of each corner probe with the HUD and 0.0% without it,
## on every single frame. That is the signal.
const HUD_MIN_GREEN_FRACTION := 0.05
const HUD_GREEN_DOMINANCE := 1.4
const HUD_GREEN_MINIMUM := 0.35

var _output_dir: String
var _replay_path: String
var _record_path: String
var _active: bool = false
var _captured: Dictionary = {} # label -> true
var _frames_captured: int = 0
var _non_black_frames: int = 0
var _hud_present: bool = false
var _pending_apex_tick: int = -1
var _match: Node
var _saw_pin: bool = false
var _finish_method: String = ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_replay_path = _arg_value(args, "--capture-replay")
	_output_dir = _arg_value(args, "--capture-output")
	_record_path = _arg_value(args, "--record-replay")
	if _output_dir != "":
		DirAccess.make_dir_recursive_absolute(_output_dir)
	_active = _output_dir != ""

## The replay a capture run should play back, or "" for none. MatchSetup
## asks for this rather than parsing the command line itself.
func replay_to_play() -> String:
	return _replay_path

## Where a capture run should save its recording, or "" for none.
func replay_to_record() -> String:
	return _record_path

func is_capturing() -> bool:
	return _active

static func _arg_value(args: PackedStringArray, key: String) -> String:
	var index := Array(args).find(key)
	if index < 0 or index + 1 >= args.size():
		return ""
	return args[index + 1]

## Called by MatchSetup once the match is built. Beats are taken from the
## match's own signals rather than from a precomputed label -> tick map:
## nothing can know before a match which tick its apex or its pinfall lands
## on, which is why the old beat_frames argument could never have been
## supplied by anything.
func attach(match_root: Node) -> void:
	if not _active:
		return
	_match = match_root
	var referee: MatchReferee = match_root.get_node("MatchReferee")
	var rig: Node = match_root.get_node("GrappleRig")
	var a: WrestlerController = match_root.get_node("WrestlerA")
	var b: WrestlerController = match_root.get_node("WrestlerB")

	rig.grapple_started.connect(_on_grapple_started)
	for wrestler: WrestlerController in [a, b]:
		wrestler.move_landed.connect(_on_move_landed)
		wrestler.pin_started.connect(_on_pin_started)
	referee.match_won.connect(_on_match_won)

func _process(_delta: float) -> void:
	if not _active or not _match:
		return
	if _pending_apex_tick >= 0 and Engine.get_physics_frames() >= _pending_apex_tick:
		_pending_apex_tick = -1
		_capture("apex")
	if not _captured.has("tie_up") and _both_tied_up():
		_capture("tie_up")

func _both_tied_up() -> bool:
	var a: WrestlerController = _match.get_node("WrestlerA")
	var b: WrestlerController = _match.get_node("WrestlerB")
	return a.fsm.current_state == WrestlerFSM.State.TIE_UP \
			and b.fsm.current_state == WrestlerFSM.State.TIE_UP

func _on_grapple_started(_attacker: Node3D, _defender: Node3D, move: MoveDef) -> void:
	if _captured.has("apex") or _pending_apex_tick >= 0:
		return
	var length := 1.0
	var library: AnimationLibrary = load("res://resources/animations/paired_moves.tres")
	if library and library.has_animation(move.animation_pair_id):
		length = library.get_animation(move.animation_pair_id).length
	_pending_apex_tick = Engine.get_physics_frames() \
			+ int(length * APEX_FRACTION * Engine.physics_ticks_per_second)

func _on_move_landed(_a: WrestlerController, _b: WrestlerController, _move: MoveDef) -> void:
	_capture("impact")

func _on_pin_started(_a: WrestlerController, _b: WrestlerController) -> void:
	_saw_pin = true
	_capture("pin_start")

func _on_match_won(_winner: WrestlerController, method: String) -> void:
	_finish_method = method
	if method == "pinfall":
		_capture("three_count")
	finish()

## Which beats this match could reach, and why the others could not.
func _expected_labels() -> Dictionary:
	var expected: Array[String] = []
	for label: String in ALWAYS_EXPECTED:
		expected.append(label)
	var skipped := {}
	if _saw_pin:
		expected.append("pin_start")
	else:
		skipped["pin_start"] = "no pin attempt in this match"
	if _finish_method == "pinfall":
		expected.append("three_count")
	else:
		skipped["three_count"] = "match ended by %s, not pinfall" \
				% (_finish_method if _finish_method != "" else "timeout")
	return {"expected": expected, "skipped": skipped}

## One frame per label, the first time that beat happens.
func _capture(label: String) -> void:
	if not _active or _captured.has(label):
		return
	var viewport := get_viewport()
	if not viewport:
		return
	var img := viewport.get_texture().get_image()
	if not img:
		return
	_captured[label] = true
	img.save_png("%s/%s_tick%04d.png" % [_output_dir, label, Engine.get_physics_frames()])
	_frames_captured += 1
	if not _is_black(img):
		_non_black_frames += 1
	if _has_hud(img):
		_hud_present = true

func _is_black(img: Image) -> bool:
	# Cheap sample rather than a full scan: check a small grid of pixels.
	var w := img.get_width()
	var h := img.get_height()
	for x in range(0, w, max(1, w / 8)):
		for y in range(0, h, max(1, h / 8)):
			if img.get_pixel(x, y).v > 0.02:
				return false
	return true

## Measured off the pixels, never asserted. The gate exists to catch a
## capture that *claims* a HUD -- a run with the HUD accidentally hidden,
## or a scene that never instanced one -- so a hardcoded `true` here would
## defeat the only check standing between a broken capture and a critic.
func _has_hud(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	var probe_w := int(w * HUD_PROBE_WIDTH)
	var probe_h := int(h * HUD_PROBE_HEIGHT)
	var margin_x := int(w * HUD_PROBE_MARGIN)
	var margin_y := int(h * HUD_PROBE_MARGIN)
	var corners := [
		Vector2i(margin_x, h - margin_y - probe_h),
		Vector2i(w - margin_x - probe_w, h - margin_y - probe_h),
	]
	for corner: Vector2i in corners:
		if not _has_vitality_bar(img, corner, probe_w, probe_h):
			return false
	return true

## A wrestler damaged to 100% on every limb would show an all-red bar and no
## green -- but a capture's tie-up beat happens at zero damage, and
## _hud_present is true if any beat frame shows the HUD, so that case cannot
## arise in a capture that reached its beats.
func _has_vitality_bar(img: Image, origin: Vector2i, probe_w: int, probe_h: int) -> bool:
	var green := 0
	var sampled := 0
	for x in range(origin.x, min(img.get_width(), origin.x + probe_w), 2):
		for y in range(origin.y, min(img.get_height(), origin.y + probe_h), 2):
			var c := img.get_pixel(x, y)
			sampled += 1
			if c.g > c.r * HUD_GREEN_DOMINANCE and c.g > c.b * HUD_GREEN_DOMINANCE \
					and c.g > HUD_GREEN_MINIMUM:
				green += 1
	if sampled == 0:
		return false
	return float(green) / float(sampled) >= HUD_MIN_GREEN_FRACTION

func finish() -> void:
	if not _active:
		return
	_active = false
	var applicable := _expected_labels()
	var manifest := {
		"expected_frame_count": (applicable["expected"] as Array).size(),
		"actual_frame_count": _frames_captured,
		"non_black_frame_ratio": (float(_non_black_frames) / max(1, _frames_captured)),
		"hud_present": _hud_present,
		"replay_end_state_hash": _end_state_hash(),
		"beat_labels": BEAT_LABELS,
		"expected_labels": applicable["expected"],
		"captured_labels": _captured.keys(),
		"skipped_labels": applicable["skipped"],
		"finish_method": _finish_method,
	}
	manifest.merge(renderer_provenance())
	var manifest_path := "%s/capture_manifest.json" % _output_dir
	var f := FileAccess.open(manifest_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	capture_finished.emit(manifest_path)

## Which renderer produced this capture, and whether a visual-quality critic
## may look at it.
##
## ARCHITECTURE.md: "llvmpipe captures are sufficient for timing and feel
## slices only. Ring/materials/lighting critics need GPU-backed captures."
## VISUAL_BAR.md repeats it as "confirm the capture was GPU-backed before
## citing a visual gap." Nothing recorded the renderer, so there was no way
## to confirm it -- the whole rule rested on whoever ran the capture
## remembering how they ran it. A manifest that cannot answer the question
## cannot enforce the rule, so it answers it here and
## tools/capture/evidence_gate.py --visual enforces it.
##
## Software rasterisers name themselves in the adapter string (Mesa's
## llvmpipe and softpipe, and swiftshader), and DEVICE_TYPE_CPU is the
## driver's own admission that it has no GPU. Anything that is neither is
## treated as GPU-backed.
static func renderer_provenance() -> Dictionary:
	var adapter := RenderingServer.get_video_adapter_name()
	var device_type := RenderingServer.get_video_adapter_type()
	return {
		"rendering_driver": str(ProjectSettings.get_setting(
				"rendering/renderer/rendering_method", "")),
		"video_adapter": adapter,
		"gpu_backed": is_gpu_backed(adapter, device_type),
	}

const SOFTWARE_ADAPTERS := ["llvmpipe", "softpipe", "swiftshader", "swrast"]

static func is_gpu_backed(adapter: String, device_type: int) -> bool:
	if device_type == RenderingDevice.DEVICE_TYPE_CPU:
		return false
	var lowered := adapter.to_lower()
	for name: String in SOFTWARE_ADAPTERS:
		if lowered.contains(name):
			return false
	return adapter != ""

func _end_state_hash() -> String:
	if not ReplaySystem or not ReplaySystem.replay or not _match:
		return ""
	var a: WrestlerController = _match.get_node("WrestlerA")
	var b: WrestlerController = _match.get_node("WrestlerB")
	return ReplaySystem.compute_end_state_hash({
		"seed": ReplaySystem.replay.match_seed,
		"ticks": ReplaySystem.current_tick,
		"a_damage": "%.4f" % a.combat.total_damage(),
		"b_damage": "%.4f" % b.combat.total_damage(),
		"a_momentum": "%.4f" % a.combat.momentum,
		"b_momentum": "%.4f" % b.combat.momentum,
	})
