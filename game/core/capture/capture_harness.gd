extends Node
## Autoload. Drives a headless, frame-stable capture of a replay for
## gauntlet critics: plays a ReplayResource under Movie Maker mode
## (constant delta, buffered audio), and dumps labeled PNG frames at
## specific beat offsets (tie-up, apex, impact, pin start, three-count)
## in addition to the movie file.
##
## Invoked via tools/capture/run_capture.sh, which launches the project
## headless with --write-movie and the beat-frame args below. This script
## never runs implicitly during normal play.

signal capture_finished(manifest_path: String)

const BEAT_LABELS := ["tie_up", "apex", "impact", "pin_start", "three_count"]

var _output_dir: String
var _beat_frames: Dictionary = {} # label -> tick
var _replay: ReplayResource
var _frames_captured: int = 0
var _non_black_frames: int = 0

func configure(output_dir: String, replay: ReplayResource, beat_frames: Dictionary) -> void:
	_output_dir = output_dir
	_replay = replay
	_beat_frames = beat_frames
	DirAccess.make_dir_recursive_absolute(_output_dir)

## Called once per physics tick by the scene driving the capture.
func on_tick(tick: int, viewport: Viewport) -> void:
	for label in _beat_frames.keys():
		if _beat_frames[label] == tick:
			_dump_frame(viewport, label, tick)

func _dump_frame(viewport: Viewport, label: String, tick: int) -> void:
	var img := viewport.get_texture().get_image()
	var path := "%s/%s_tick%04d.png" % [_output_dir, label, tick]
	img.save_png(path)
	_frames_captured += 1
	if not _is_black(img):
		_non_black_frames += 1

func _is_black(img: Image) -> bool:
	# Cheap sample rather than a full scan: check a small grid of pixels.
	var w := img.get_width()
	var h := img.get_height()
	for x in range(0, w, max(1, w / 8)):
		for y in range(0, h, max(1, h / 8)):
			if img.get_pixel(x, y).v > 0.02:
				return false
	return true

func finish(hud_present: bool, end_state_hash: String) -> void:
	var manifest := {
		"expected_frame_count": _beat_frames.size(),
		"actual_frame_count": _frames_captured,
		"non_black_frame_ratio": (float(_non_black_frames) / max(1, _frames_captured)),
		"hud_present": hud_present,
		"replay_end_state_hash": end_state_hash,
		"beat_labels": BEAT_LABELS,
	}
	var manifest_path := "%s/capture_manifest.json" % _output_dir
	var f := FileAccess.open(manifest_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest, "\t"))
	f.close()
	capture_finished.emit(manifest_path)
