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
@export_range(0.4, 0.8, 0.01) var kick_setup_touch_distance := 0.60
@export_range(0.15, 0.3, 0.01) var kick_foot_contact_radius := 0.28
@export_range(0.0, 0.1, 0.005) var kick_contact_grace_seconds := 0.065
@export_range(1.5, 2.8, 0.1) var slide_tackle_reach := 2.2

@export_group("Shielding and skills")
@export_range(.8, 3.0, .1) var skill_cooldown := 1.4
@export_range(.2, .6, .05) var shield_speed_scale := .35

@export_group("Advanced strikes")
@export_range(1.0, 1.25, .01) var power_shot_multiplier := 1.12
@export_range(10.0, 45.0, 1.0) var finesse_spin := 30.0
@export_range(0.0, .008, .0005) var finesse_magnus := .003
@export_range(0.0, .3, .01) var special_shot_error_radians := .10
@export_range(.5, 1.1, .01) var volley_contact_height := .78
@export_range(.12, .4, .01) var half_volley_contact_height := .20

@export_group("Aerial play")
@export_range(25.0, 55.0, 1.0) var lofted_pass_max_range := 48.0
@export_range(0.3, 1.2, 0.05) var lofted_pass_charge_seconds := 0.75
@export_range(1.8, 2.2, 0.01) var header_contact_height := 1.97
@export_range(0.15, 0.26, 0.01) var aerial_contact_radius := 0.20
@export_range(2.5, 4.0, 0.1) var header_jump_speed := 3.4
@export_range(8.0, 18.0, 0.5) var header_speed := 14.0

@export_group("AI decisions")
@export_range(0.1, 0.4, 0.01) var ai_decision_interval := 0.20
@export_range(0.05, 0.5, 0.01) var ai_pass_progress_weight := 0.20
@export_range(0.0, 0.3, 0.01) var ai_pass_distance_weight := 0.12
@export_range(1.0, 15.0, 0.5) var ai_pass_risk_weight := 9.0
@export_range(4.0, 12.0, 0.5) var ai_support_distance := 7.0
@export_range(5.0, 14.0, 0.5) var ai_forward_run_distance := 8.0
@export_range(16.0, 28.0, 0.5) var ai_shot_range := 22.0

@export_group("Goalkeeper")
@export_range(0.05, 0.6, 0.01) var goalkeeper_reaction_seconds := 0.22
@export_range(3.0, 10.0, 0.1) var goalkeeper_move_speed := 6.8
@export_range(0.5, 1.5, 0.05) var goalkeeper_save_reach := 0.95
@export_range(4.0, 12.0, 0.1) var goalkeeper_parry_speed := 8.0
@export_range(0.2, 0.6, 0.01) var goalkeeper_catch_half_width := 0.42

@export_range(0.1, 0.5, 0.01) var goalkeeper_standing_recovery_seconds := 0.24
@export_range(0.4, 1.2, 0.01) var goalkeeper_stretch_recovery_seconds := 0.65

@export_range(0.5, 5.0, 0.1) var goalkeeper_rebound_gather_speed := 3.0

@export_group("Pitch")
@export var field_length := 105.0
@export var field_width := 68.0
@export var goal_width := 7.32
@export var goal_height := 2.44
