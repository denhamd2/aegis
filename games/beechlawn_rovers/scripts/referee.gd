extends CharacterBody3D
## Presentation official, separate from all selectable/ball-interaction actors.

@onready var ball: FootballBall = get_node("../Ball")
@onready var visual: FootballerVisual = $Visual
var _target := Vector3.ZERO
var _decision_left := 0.0

func _ready() -> void:
	var identity := FootballerProfile.new()
	identity.player_id = &"des_feeney_sr"
	identity.display_name = "Des Feeney Sr."
	identity.appearance = FootballAppearance.new()
	identity.appearance.kit = "referee"
	visual.configure_appearance(identity)
	position = Vector3(-5.0, 0.0, 9.0)
	add_to_group("match_officials")

func _physics_process(delta: float) -> void:
	var match_scene := get_parent()
	var stopped := bool(match_scene.get("_full_time")) or bool(match_scene.get("_kickoff_pending")) or float(match_scene.get("_goal_pause_timer")) > 0.0
	_decision_left -= delta
	if _decision_left <= 0.0:
		_decision_left = 0.2
		_target = ball.global_position + Vector3(-6.5, 0.0, 8.0 if ball.global_position.z < 15.0 else -8.0)
		_target.x = clampf(_target.x, -44.0, 44.0)
		_target.z = clampf(_target.z, -27.0, 27.0)
	var direction := _target - global_position
	direction.y = 0.0
	var desired := direction.normalized() * minf(5.8, direction.length() * 1.5) if not stopped else Vector3.ZERO
	for node in get_tree().get_nodes_in_group("football_players"):
		var away := global_position - (node as Node3D).global_position
		away.y = 0.0
		if away.length_squared() < 2.25 and away.length_squared() > 0.001:
			desired += away.normalized() * (1.5 - away.length()) * 2.0
	velocity.x = move_toward(velocity.x, desired.x, 12.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 12.0 * delta)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-velocity.x, -velocity.z), 1.0-exp(-8.0*delta))
	visual.set_locomotion_speed(speed, false, false, false, delta)
