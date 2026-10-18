extends Resource
class_name FootballTuning
## A small, editable tuning surface for the football fundamentals prototype.

@export_group("Player movement")
@export var jog_speed := 6.0
@export var sprint_speed := 8.6
@export var acceleration := 12.0
@export var braking := 15.0
@export var turn_rate := 9.0
@export var sprint_turn_scale := 0.66
@export var stamina_max := 100.0
@export var sprint_drain := 10.0
@export var stamina_recovery := 6.0

@export_group("Ball control")
@export var control_radius := 1.05
@export var dribble_touch_interval := 0.23
@export var close_touch_distance := 0.48
@export var sprint_touch_distance := 1.05
@export var dribble_max_height := 0.45
@export var kick_control_release_seconds := 0.12
@export_range(0.0, 0.6, 0.01) var ground_rolling_resistance := 0.18
@export_range(0.0, 0.8, 0.01) var ground_rolling_force_limit := 0.25
@export var action_input_buffer := 0.20
@export var first_time_pass_buffer := 0.90
@export var incoming_pass_prediction_window := 0.90
@export var shot_charge_duration := 1.0
@export var short_pass_speed := 12.0
@export var through_pass_speed := 18.0
@export var shot_min_speed := 13.0
@export var shot_max_speed := 30.0
@export var kick_assist_radius := 1.12
@export_range(1.5, 2.8, 0.1) var slide_tackle_reach := 2.2

@export_group("Goalkeeper")
@export_range(0.05, 0.6, 0.01) var goalkeeper_reaction_seconds := 0.22
@export_range(3.0, 10.0, 0.1) var goalkeeper_move_speed := 6.8
@export_range(0.5, 1.5, 0.05) var goalkeeper_save_reach := 0.95
@export_range(4.0, 12.0, 0.1) var goalkeeper_parry_speed := 8.0

@export_group("Pitch")
@export var field_length := 105.0
@export var field_width := 68.0
@export var goal_width := 7.32
@export var goal_height := 2.44
