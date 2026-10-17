extends SceneTree
## Validates the editable roster/resources before the 4v4 match assembles them.

func _initialize() -> void:
	var home := load("res://data/teams/beechlawn_rovers.tres") as FootballTeam
	var away := load("res://data/teams/bordeaux.tres") as FootballTeam
	assert(home != null, "Beechlawn team resource failed to load")
	assert(away != null, "Bordeaux team resource failed to load")
	assert(home.validate_roster().is_empty(), "Beechlawn roster is invalid: %s" % home.validate_roster())
	assert(away.validate_roster().is_empty(), "Bordeaux roster is invalid: %s" % away.validate_roster())
	assert(home.roster.size() == 4 and away.roster.size() == 4, "Both teams must have four slots")
	assert(home.roster[0].display_name == "John O’Rourke", "Goalkeeper identity/diacritic was lost")
	assert(home.roster[1].display_name == "Shane Denham" and home.roster[1].jersey_number == 8,
		"Shane Denham sheet identity was lost")
	assert(home.roster[2].display_name == "David Murray" and home.roster[2].jersey_number == 5,
		"David Murray sheet identity was lost")
	assert(home.roster[3].display_name == "Robbie Roden" and home.roster[3].jersey_number == 10,
		"Robbie Roden sheet identity was lost")
	for profile in home.roster + away.roster:
		assert(profile.attributes != null, "%s has no editable attributes" % profile.display_name)
		assert(profile.attributes.pace == 50 and profile.attributes.goalkeeper_reflexes == 50,
			"Unspecified ratings must remain neutral placeholders")
	for profile in away.roster:
		assert(profile.visual_base == "Des Feeney", "Bordeaux slots must use the supplied visual base")
		assert(profile.jersey_number == 0, "Do not invent Bordeaux squad numbers")
	print("Beechlawn/Bordeaux roster resource checks passed")
	quit(0)
