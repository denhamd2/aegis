class_name MatchCamera
extends Camera3D
## Ringside rig that keeps both wrestlers in frame, plus scripted cuts for
## finishers and the three-count. Framing constants are placeholders until
## gauntlet/refs/camera.md is filled in from measured reference footage —
## see ARCHITECTURE.md "Reference-driven tuning."

@export var wrestler_a: Node3D
@export var wrestler_b: Node3D
@export var min_distance: float = 4.0
@export var max_distance: float = 9.0
@export var height: float = 1.8
@export var follow_speed: float = 6.0

enum Mode { FOLLOW, FINISHER_CUT, THREE_COUNT_CUT }
var mode: Mode = Mode.FOLLOW

func _physics_process(delta: float) -> void:
	if mode != Mode.FOLLOW or not wrestler_a or not wrestler_b:
		return
	var midpoint := (wrestler_a.global_position + wrestler_b.global_position) * 0.5
	var separation := wrestler_a.global_position.distance_to(wrestler_b.global_position)
	var distance := clamp(separation * 1.6, min_distance, max_distance)

	var to_camera := (global_position - midpoint)
	to_camera.y = 0.0
	if to_camera.length() < 0.01:
		to_camera = Vector3.BACK
	to_camera = to_camera.normalized() * distance

	var target_position := midpoint + to_camera + Vector3.UP * height
	global_position = global_position.lerp(target_position, 1.0 - exp(-follow_speed * delta))
	look_at(midpoint + Vector3.UP * 1.0, Vector3.UP)

func cut_to_finisher() -> void:
	mode = Mode.FINISHER_CUT

func cut_to_three_count() -> void:
	mode = Mode.THREE_COUNT_CUT

func resume_follow() -> void:
	mode = Mode.FOLLOW
