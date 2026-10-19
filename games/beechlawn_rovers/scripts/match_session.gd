extends Node
## Menu launch intent and inexpensive, persistent presentation preferences.
## Directly opened match scenes retain their normal human-controlled defaults.
enum MatchMode { PLAY, WATCH }
const SETTINGS_PATH := "user://presentation.cfg"
var mode: MatchMode = MatchMode.PLAY
var launched_from_menu := false
var master_volume := 0.8
var fullscreen := false
const CameraPresets := preload("res://scripts/gameplay_camera_presets.gd")
var camera_preset: StringName = CameraPresets.DEFAULT
var camera_height := 0.0
var camera_zoom := 0.0
var camera_angle := 0.0
var show_intro := true

func _ready() -> void:
	load_preferences()
	apply_preferences()

func load_preferences(path: String = SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	master_volume = clampf(float(config.get_value("audio", "master_volume", 0.8)), 0.0, 1.0)
	fullscreen = bool(config.get_value("display", "fullscreen", false))
	camera_preset = CameraPresets.valid_id(StringName(str(config.get_value("camera", "preset", CameraPresets.DEFAULT))))
	camera_height = clampf(float(config.get_value("camera", "height", 0.0)), -4.0, 12.0)
	camera_zoom = clampf(float(config.get_value("camera", "zoom", 0.0)), -1.0, 1.0)
	camera_angle = clampf(float(config.get_value("camera", "angle", 0.0)), -20.0, 20.0)
	show_intro = bool(config.get_value("presentation", "intro", true))

func save_preferences(path: String = SETTINGS_PATH) -> Error:
	var config := ConfigFile.new()
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("display", "fullscreen", fullscreen)
	config.set_value("camera", "preset", camera_preset)
	config.set_value("camera", "height", camera_height)
	config.set_value("camera", "zoom", camera_zoom)
	config.set_value("camera", "angle", camera_angle)
	config.set_value("presentation", "intro", show_intro)
	return config.save(path)

func apply_preferences() -> void:
	AudioServer.set_bus_volume_linear(0, master_volume)
	if not OS.has_feature("web") and not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func is_spectator() -> bool:
	return launched_from_menu and mode == MatchMode.WATCH

func return_to_title() -> void:
	launched_from_menu = false
	# Debug screenshot captures may have paused the tree; never carry that back.
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title_screen.tscn")
