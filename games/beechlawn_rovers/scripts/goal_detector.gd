extends Node3D
class_name GoalDetector

signal goal_scored(team_name: String, side: int)

@export var defending_end := 1
@export var field_length := 105.0
@export var goal_width := 7.32
@export var goal_height := 2.44
var ball: FootballBall
var _previous_progress := -INF
var _previous_position := Vector3.ZERO
var _scored := false
var _score_cooldown := 0.0

func _ready() -> void:
	if is_instance_valid(ball):
		_previous_position = ball.global_position
		_previous_progress = (ball.global_position.x - field_length * 0.5 * defending_end) * defending_end

func _physics_process(delta: float) -> void:
	if not is_instance_valid(ball):
		return
	_score_cooldown = maxf(0.0, _score_cooldown - delta)
	var line_x := field_length * 0.5 * defending_end
	var progress := (ball.global_position.x - line_x) * defending_end
	# The whole 220 mm sphere must cross the line; interpolating the line-crossing
	# point prevents fast shots from skipping over the goal test between ticks.
	if not _scored and _score_cooldown <= 0.0 and _previous_progress < FootballBall.RADIUS \
			and progress >= FootballBall.RADIUS:
		var fraction := clampf((FootballBall.RADIUS - _previous_progress) / maxf(progress - _previous_progress, 0.0001), 0.0, 1.0)
		var crossing_y := lerpf(_previous_position.y, ball.global_position.y, fraction)
		var crossing_z := lerpf(_previous_position.z, ball.global_position.z, fraction)
		if crossing_y - FootballBall.RADIUS <= goal_height \
				and absf(crossing_z) + FootballBall.RADIUS <= goal_width * 0.5:
			_scored = true
			_score_cooldown = 1.7
			goal_scored.emit("Beechlawn Rovers" if defending_end == 1 else "Boardeaux", defending_end)
	if progress < 0.0:
		_scored = false
	_previous_progress = progress
	_previous_position = ball.global_position
