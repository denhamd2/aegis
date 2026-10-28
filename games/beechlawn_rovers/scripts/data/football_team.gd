extends Resource
class_name FootballTeam
## Editable squad and kit data used when assembling the small-sided match.

@export var team_id: StringName
@export var display_name := "Unnamed Team"
@export var manager_name := ""
@export var retired_shirt_numbers := PackedInt32Array()
@export var primary_kit_color := Color.WHITE
@export var secondary_kit_color := Color.BLACK
@export var goalkeeper_kit_color := Color(0.7, 0.7, 0.7)
@export var roster: Array[FootballerProfile] = []
@export var reserves: Array[FootballerProfile] = []
@export_enum("4v4", "4-4-2", "4-3-3", "4-2-3-1", "4-5-1") var formation := "4v4"
@export var kickoff_slot := "center"
@export_range(4, 11) var active_player_count := 4
## Neutral values retain the established 4-4-2 match behavior.
@export_range(0.0, 1.0, 0.05) var tactical_width := 0.5
@export_range(0.0, 1.0, 0.05) var tactical_depth := 0.5
@export_range(0.0, 1.0, 0.05) var pressing := 0.5
@export_range(0.0, 1.0, 0.05) var directness := 0.5
@export_range(0.0, 1.0, 0.05) var tempo := 0.5

## Each entry is [role, attacking-frame X, pitch Y]. Slots identify players;
## formations assign match responsibilities without changing squad identities.
const FORMATION_CHANGES := {
	"4-3-3": {
		"left_midfield": ["defensive_midfielder", -19.0, 0.0],
		"right_midfield": ["central_midfielder", -10.0, 10.0],
		"striker_right": ["attacking_midfielder", -10.0, -10.0],
		"left_wing": ["winger", -1.0, -24.0],
		"right_wing": ["winger", -1.0, 24.0],
		"striker_left": ["striker", 3.0, 0.0],
	},
	"4-2-3-1": {
		"left_midfield": ["defensive_midfielder", -19.0, -9.0],
		"right_midfield": ["defensive_midfielder", -19.0, 9.0],
		"striker_right": ["attacking_midfielder", -7.0, 0.0],
		"left_wing": ["winger", -8.0, -24.0],
		"right_wing": ["winger", -8.0, 24.0],
		"striker_left": ["striker", 4.0, 0.0],
	},
	"4-5-1": {
		"left_midfield": ["defensive_midfielder", -20.0, 0.0],
		"right_midfield": ["central_midfielder", -12.0, 9.0],
		"striker_right": ["central_midfielder", -12.0, -9.0],
		"left_wing": ["winger", -10.0, -24.0],
		"right_wing": ["winger", -10.0, 24.0],
		"striker_left": ["striker", 4.0, 0.0],
	},
}

func match_copy() -> FootballTeam:
	var copy := duplicate(false) as FootballTeam
	var assigned: Array[FootballerProfile] = []
	var changes: Dictionary = FORMATION_CHANGES.get(formation, {}) if active_player_count == 11 else {}
	for original in roster:
		var profile := original.duplicate(false) as FootballerProfile
		if changes.has(profile.starting_slot):
			var placement: Array = changes[profile.starting_slot]
			profile.tactical_role = placement[0]
			profile.starting_position = Vector2(placement[1], placement[2])
		assigned.append(profile)
	copy.roster = assigned
	return copy

func validate_roster() -> PackedStringArray:
	var errors := PackedStringArray()
	if active_player_count == 11 and formation not in ["4-4-2", "4-3-3", "4-2-3-1", "4-5-1"]:
		errors.append("%s has unsupported eleven-player formation %s" % [display_name, formation])
	var ids := {}
	var slots := {}
	var keepers := 0
	for profile in roster + reserves:
		if profile == null:
			errors.append("%s has a null roster entry" % display_name)
			continue
		if profile.player_id.is_empty():
			errors.append("%s contains a profile without player_id" % display_name)
		elif ids.has(profile.player_id):
			errors.append("%s repeats player_id %s" % [display_name, profile.player_id])
		else:
			ids[profile.player_id] = true
		if profile.jersey_number in retired_shirt_numbers:
			errors.append("%s uses retired squad number %d" % [profile.display_name, profile.jersey_number])
		if roster.has(profile):
			if slots.has(profile.starting_slot):
				errors.append("%s repeats starting slot %s" % [display_name, profile.starting_slot])
			else:
				slots[profile.starting_slot] = true
			if profile.role == "goalkeeper":
				keepers += 1
		if profile.attributes == null:
			errors.append("%s has no attribute resource" % profile.display_name)
	if roster.size() != active_player_count:
		errors.append("%s requires %d active profiles" % [display_name, active_player_count])
	if keepers != 1 or not slots.has("keeper"):
		errors.append("%s requires exactly one active goalkeeper in the keeper slot" % display_name)
	if not slots.has(kickoff_slot):
		errors.append("%s has no kickoff slot %s" % [display_name, kickoff_slot])
	return errors
