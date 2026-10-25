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
@export_enum("4v4", "4-4-2") var formation := "4v4"
@export var kickoff_slot := "center"
@export_range(4, 11) var active_player_count := 4

func validate_roster() -> PackedStringArray:
	var errors := PackedStringArray()
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
