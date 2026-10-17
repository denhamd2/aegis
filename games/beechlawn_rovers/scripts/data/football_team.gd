extends Resource
class_name FootballTeam
## Editable squad and kit data used when assembling the small-sided match.

@export var team_id: StringName
@export var display_name := "Unnamed Team"
@export var primary_kit_color := Color.WHITE
@export var secondary_kit_color := Color.BLACK
@export var goalkeeper_kit_color := Color(0.7, 0.7, 0.7)
@export var roster: Array[FootballerProfile] = []

func validate_roster() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	var slots := {}
	for profile in roster:
		if profile == null:
			errors.append("%s has a null roster entry" % display_name)
			continue
		if profile.player_id.is_empty():
			errors.append("%s contains a profile without player_id" % display_name)
		elif ids.has(profile.player_id):
			errors.append("%s repeats player_id %s" % [display_name, profile.player_id])
		else:
			ids[profile.player_id] = true
		if slots.has(profile.starting_slot):
			errors.append("%s repeats starting slot %s" % [display_name, profile.starting_slot])
		else:
			slots[profile.starting_slot] = true
		if profile.attributes == null:
			errors.append("%s has no attribute resource" % profile.display_name)
	if roster.size() != 4:
		errors.append("%s must have exactly 4 profiles for the first 4v4 slice" % display_name)
	if not slots.has("keeper"):
		errors.append("%s has no goalkeeper slot" % display_name)
	return errors
