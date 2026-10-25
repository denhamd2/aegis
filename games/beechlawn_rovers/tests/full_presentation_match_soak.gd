extends "res://tests/eleven_v_eleven_match_soak.gd"
func _initialize() -> void:
	OS.set_environment("BEECHLAWN_REPLAY_COMPLETE","1")
	OS.set_environment("BEECHLAWN_START_VARIATION","1")
	super._initialize()
