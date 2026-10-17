extends Node3D
class_name FootballerVisual
## Lightweight visual animation driver. Gameplay position and speed remain owned
## by FootballPlayer; this node only blends the shared Y-Bot proxy clips.

signal action_contact(action: StringName)
signal action_finished(action: StringName)

const PASS_CLIP: StringName = &"AN_Beechlawn_PassRight"
const PASS_EVENT_METADATA := "res://assets/characters/mixamo/y_bot_pass_contact.json"

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $Rig/AnimationPlayer
@onready var surface: MeshInstance3D = $Rig/YBot_Armature/Skeleton3D/YBot_Surface
@onready var joints: MeshInstance3D = $Rig/YBot_Armature/Skeleton3D/YBot_Joints

var _last_blend := -1.0
var _active_action: StringName = &""


func _ready() -> void:
	animation_tree.active = true
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_player.animation_finished.connect(_on_animation_finished)
	_install_pass_contact_marker()


func play_pass() -> bool:
	if _active_action != &"" or not animation_player.has_animation(PASS_CLIP):
		return false
	_active_action = &"pass"
	animation_tree.active = false
	animation_player.play(PASS_CLIP)
	return true


func on_pass_contact_marker() -> void:
	if _active_action == &"pass":
		action_contact.emit(_active_action)


func set_locomotion_speed(speed_mps: float, sprinting: bool = false) -> void:
	var locomotion := clampf(speed_mps / 6.0, 0.0, 1.0)
	if sprinting:
		locomotion = maxf(locomotion, 0.72)
	if absf(locomotion - _last_blend) < 0.015:
		return
	_last_blend = locomotion
	animation_tree.set("parameters/blend_position", locomotion)


func set_team_color(team_color: Color) -> void:
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = team_color
	body_material.roughness = 0.78
	surface.material_override = body_material
	var joint_material := StandardMaterial3D.new()
	joint_material.albedo_color = team_color.darkened(0.28)
	joint_material.roughness = 0.86
	joints.material_override = joint_material


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != PASS_CLIP or _active_action == &"":
		return
	var finished_action := _active_action
	_active_action = &""
	animation_tree.active = true
	action_finished.emit(finished_action)


func _install_pass_contact_marker() -> void:
	var library := animation_player.get_animation_library(&"")
	if library == null or not library.has_animation(PASS_CLIP):
		push_error("Y-Bot animation library is missing %s" % PASS_CLIP)
		return
	if not FileAccess.file_exists(PASS_EVENT_METADATA):
		push_error("Missing Blender-authored pass contact metadata: %s" % PASS_EVENT_METADATA)
		return
	var parsed_events: Variant = JSON.parse_string(FileAccess.get_file_as_string(PASS_EVENT_METADATA))
	if typeof(parsed_events) != TYPE_DICTIONARY:
		push_error("Could not parse pass contact metadata: %s" % PASS_EVENT_METADATA)
		return
	var event_data: Dictionary = parsed_events
	if event_data.get("clip", "") != String(PASS_CLIP) or event_data.get("event", "") != "ball_contact":
		push_error("Pass contact metadata does not match %s" % PASS_CLIP)
		return
	var contact_time := float(event_data.get("frame", -1)) / maxf(float(event_data.get("fps", 0)), 1.0)
	if contact_time <= 0.0:
		push_error("Invalid pass contact frame/fps metadata")
		return
	var clip := library.get_animation(PASS_CLIP).duplicate() as Animation
	var marker_path := NodePath("..:on_pass_contact_marker")
	var marker_exists := false
	for track_index in clip.get_track_count():
		if clip.track_get_type(track_index) == Animation.TYPE_METHOD \
				and clip.track_get_path(track_index) == marker_path:
			marker_exists = true
			break
	if not marker_exists:
		var marker_track := clip.add_track(Animation.TYPE_METHOD)
		clip.track_set_path(marker_track, marker_path)
		clip.track_insert_key(marker_track, contact_time,
			{"method": "on_pass_contact_marker", "args": []})
	library.remove_animation(PASS_CLIP)
	library.add_animation(PASS_CLIP, clip)
