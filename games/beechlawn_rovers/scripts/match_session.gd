extends Node
## Menu launch intent and inexpensive, persistent presentation preferences.
## Directly opened match scenes retain their normal human-controlled defaults.
enum MatchMode { PLAY, WATCH }
const SETTINGS_PATH := "user://presentation.cfg"
var mode: MatchMode = MatchMode.PLAY
var launched_from_menu := false
var master_volume := 0.8
var music_volume := .45
var match_volume := .8
var ui_volume := .65
var fullscreen := false
const CameraPresets := preload("res://scripts/gameplay_camera_presets.gd")
var camera_preset: StringName = CameraPresets.DEFAULT
var camera_height := 0.0
var camera_zoom := 0.0
var camera_angle := 0.0
var show_intro := true
var weather_preset: StringName = &"sunny"
var cinematic_depth_of_field := true
var cinematic_motion_blur := true
var temporal_aa := false
var venue_id: StringName = &"kilmore_drive"
var switch_mode: StringName = &"assisted"

func _ready() -> void:
	if "--print-build-info" in OS.get_cmdline_user_args():
		var info = JSON.parse_string(FileAccess.get_file_as_string("res://data/build_info.json"))
		if not info is Dictionary:
			push_error("Packaged build identity is missing or invalid")
			get_tree().quit(1)
		else:
			print("BEECHLAWN_BUILD_INFO ",JSON.stringify(info))
			get_tree().quit()
		return
	load_preferences()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--venue="): venue_id = FootballMatchVenue.valid_id(StringName(arg.trim_prefix("--venue=")))
	apply_preferences()

func load_preferences(path: String = SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	for field in ["music_volume","match_volume","ui_volume"]:
		set(field, clampf(float(config.get_value("audio",field,get(field))),0,1))
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	camera_preset = CameraPresets.valid_id(StringName(str(config.get_value("camera", "preset", CameraPresets.DEFAULT))))
	camera_height = clampf(float(config.get_value("camera", "height", 0.0)), -4.0, 12.0)
	camera_zoom = clampf(float(config.get_value("camera", "zoom", 0.0)), -1.0, 1.0)
	camera_angle = clampf(float(config.get_value("camera", "angle", 0.0)), -20.0, 20.0)
	venue_id = FootballMatchVenue.valid_id(StringName(str(config.get_value("match", "venue", "kilmore_drive"))))
	switch_mode = &"manual" if str(config.get_value("match", "switching", "assisted")) == "manual" else &"assisted"
	show_intro = bool(config.get_value("presentation", "intro", true))
	weather_preset = MatchWeather.valid_id(StringName(str(config.get_value("presentation", "weather", "sunny"))))
	cinematic_depth_of_field = bool(config.get_value("graphics", "cinematic_depth_of_field", true))
	cinematic_motion_blur = bool(config.get_value("graphics", "cinematic_motion_blur", true))
	temporal_aa = bool(config.get_value("graphics", "temporal_aa", false))

func save_preferences(path: String = SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	for field in ["music_volume","match_volume","ui_volume"]: config.set_value("audio",field,get(field))
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("camera", "preset", camera_preset)
	config.set_value("camera", "height", camera_height)
	config.set_value("camera", "zoom", camera_zoom)
	config.set_value("camera", "angle", camera_angle)
	config.set_value("match", "venue", str(venue_id))
	config.set_value("match", "switching", str(switch_mode))
	config.set_value("presentation", "intro", show_intro)
	config.set_value("presentation", "weather", str(weather_preset))
	for field in ["cinematic_depth_of_field", "cinematic_motion_blur", "temporal_aa"]:
		config.set_value("graphics", field, get(field))
	return config.save(path)

func apply_preferences() -> void:
	get_viewport().use_taa = temporal_aa and RenderingServer.get_current_rendering_method() == "forward_plus"
	get_viewport().msaa_3d = Viewport.MSAA_2X if get_viewport().use_taa else Viewport.MSAA_4X
	AudioServer.set_bus_volume_linear(0, master_volume)
	for bus in ["Music","Match","UI"]:
		AudioServer.set_bus_volume_linear(AudioServer.get_bus_index(bus),float(get(bus.to_lower()+"_volume")))
	if not OS.has_feature("web") and not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func is_spectator() -> bool:
	return launched_from_menu and mode == MatchMode.WATCH

func return_to_title() -> void:
	launched_from_menu = false
	# Debug screenshot captures may have paused the tree; never carry that back.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
