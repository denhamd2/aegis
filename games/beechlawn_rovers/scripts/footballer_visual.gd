extends Node3D
class_name FootballerVisual
## Lightweight visual animation driver. Gameplay position and speed remain owned
## by FootballPlayer; this node only blends the shared Y-Bot proxy clips.

signal action_contact(action: StringName)
signal action_finished(action: StringName)

const PASS_CLIP: StringName = &"AN_Beechlawn_PassRight"
const PASS_EVENT_METADATA := "res://assets/characters/mixamo/y_bot_pass_contact.json"
const RECEIVE_CLIP: StringName = &"AN_Beechlawn_ReceiveRight"
const RECEIVE_EVENT_METADATA := "res://assets/characters/mixamo/y_bot_receive_contact.json"
const STOP_CLIP: StringName = &"AN_Beechlawn_StopFromRun"
const TURN_LEFT_CLIP: StringName = &"AN_Beechlawn_Turn90Left"
const TURN_RIGHT_CLIP: StringName = &"AN_Beechlawn_Turn90Right"
const SHOT_CLIP: StringName = &"AN_Beechlawn_ShotRight"
const SLIDE_TACKLE_CLIP: StringName = &"AN_Beechlawn_GroundedSlideTackle"
const GET_UP_CLIP: StringName = &"AN_Beechlawn_GetUpFromProne"
const SHOT_EVENT_METADATA := "res://assets/characters/mixamo/y_bot_shot_contact.json"
const AERIAL_CLIPS := {&"header": &"AN_Beechlawn_Header", &"chest_control": &"AN_Beechlawn_ChestControl"}
const VOLLEY_CLIPS := {&"volley": &"AN_Beechlawn_Volley", &"half_volley": &"AN_Beechlawn_HalfVolley"}

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation_player: AnimationPlayer = $Rig/AnimationPlayer
var _blend_position := 0.0
var _active_action: StringName = &""
var _active_clip: StringName = &""
var _action_has_contact := false
var _action_contact_times: Dictionary = {}
var _stop_latched := false
var _close_control_blend := 0.0
var _appearance_profile: FootballerProfile
var _appearance_team: FootballTeam
var _human_rig := false
var _presentation_active := false
var _base_head_parts: Dictionary = {}
var _face_mesh: MeshInstance3D
var _face_clock := 0.0
static var _kit_materials: Dictionary = {}
static var _head_variant_meshes: Dictionary = {}
@export var jog_reference_speed := 6.0
@export var sprint_reference_speed := 8.6


func _ready() -> void:
	_prepare_looping_motion()
	_install_restart_actions()
	_install_aerial_actions()
	_install_volley_actions()
	_install_match_motion()
	_install_presentation_actions()
	_build_locomotion_tree()
	# Reception/kick setup reads this skeleton's boot pose in physics. Idle
	# evaluation held the running pose for several ticks on slow renders.
	animation_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_tree.active = true
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	animation_player.animation_finished.connect(_on_animation_finished)
	_install_action_contact_marker(&"pass", PASS_CLIP, PASS_EVENT_METADATA)
	_install_action_contact_marker(&"receive", RECEIVE_CLIP, RECEIVE_EVENT_METADATA)
	_install_action_contact_marker(&"shot", SHOT_CLIP, SHOT_EVENT_METADATA)
	if _appearance_profile != null:
		configure_appearance(_appearance_profile, _appearance_team)
	else:
		_prime_locomotion_pose()


func _process(delta: float) -> void:
	if not is_instance_valid(_face_mesh): return
	_face_clock += delta
	var offset := float(absi(hash(_appearance_profile.player_id)) % 310) / 100.0 if _appearance_profile != null else 0.0
	var phase := fmod(_face_clock + offset, 4.3)
	var blink := _face_mesh.find_blend_shape_by_name("Blink")
	if blink >= 0:
		var amount := sin(clampf((phase - 4.05) / .22, 0, 1) * PI) if phase > 4.05 else 0.0
		_face_mesh.set_blend_shape_value(blink, amount)
	var smile := _face_mesh.find_blend_shape_by_name("Smile")
	if smile >= 0:
		var target := .65 if _presentation_active and animation_player.current_animation == &"AN_Beechlawn_Celebrate" else 0.0
		_face_mesh.set_blend_shape_value(smile, move_toward(_face_mesh.get_blend_shape_value(smile), target, delta * 2))


func _prepare_looping_motion() -> void:
	# AnimationNodeAnimation.loop_mode alone does not override imported clips.
	# Own the library before changing motion; one-shot actions stay one-shot.
	var library := animation_player.get_animation_library(&"").duplicate() as AnimationLibrary
	for name in [&"AN_Beechlawn_Idle", &"AN_Beechlawn_Jog", &"AN_Beechlawn_Sprint",
			&"AN_Beechlawn_CloseControl", &"AN_Beechlawn_KeeperSet", &"AN_Beechlawn_WalkOn", &"AN_Beechlawn_WarmupJog"]:
		if library.has_animation(name):
			var motion := library.get_animation(name).duplicate() as Animation
			motion.loop_mode = Animation.LOOP_LINEAR
			library.remove_animation(name)
			library.add_animation(name, motion)
	animation_player.remove_animation_library(&"")
	animation_player.add_animation_library(&"", library)


func configure_appearance(profile: FootballerProfile, team: FootballTeam = null) -> void:
	_appearance_profile = profile
	_appearance_team = team
	if not is_node_ready():
		return
	if not _human_rig:
		animation_tree.active = false
		var old := get_node("Rig")
		remove_child(old)
		old.free()
		var shared := load("res://assets/characters/shared/footballer_base.glb") as PackedScene
		var rig := shared.instantiate() as Node3D
		rig.name = "Rig"
		rig.rotation.y = PI
		add_child(rig)
		animation_player = rig.get_node("AnimationPlayer") as AnimationPlayer
		animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		animation_player.animation_finished.connect(_on_animation_finished)
		_human_rig = true
		_prepare_looping_motion()
		_install_restart_actions()
		_install_aerial_actions()
		_install_volley_actions()
		_install_match_motion()
		_install_presentation_actions()
		_install_action_contact_marker(&"pass", PASS_CLIP, PASS_EVENT_METADATA)
		_install_action_contact_marker(&"receive", RECEIVE_CLIP, RECEIVE_EVENT_METADATA)
		_install_action_contact_marker(&"shot", SHOT_CLIP, SHOT_EVENT_METADATA)
		animation_tree.active = true
	var appearance := profile.appearance
	if appearance == null:
		appearance = FootballAppearance.new()
	var short_sleeves := appearance.kit in ["bordeaux_outfield", "referee", "spectator"]
	if appearance.kit.ends_with("keeper") and animation_player.has_animation(&"AN_Beechlawn_KeeperSet"):
		animation_tree.tree_root = animation_tree.tree_root.duplicate(true)
		var tree := animation_tree.tree_root as AnimationNodeBlendTree
		var movement := tree.get_node("Locomotion") as AnimationNodeBlendSpace1D
		var keeper_idle := AnimationNodeAnimation.new()
		keeper_idle.animation = &"AN_Beechlawn_KeeperSet"
		keeper_idle.loop_mode = Animation.LOOP_LINEAR
		movement.set_blend_point_node(0,keeper_idle)
	var kit_material := _shared_kit_material(appearance.kit)
	var head_parts := _head_parts(preload("res://assets/characters/shared/heads/master.glb")).duplicate()
	head_parts.merge(_head_parts(appearance.head_variant), true)
	var hair_parts := _head_parts(appearance.hair_variant)
	for node in get_node("Rig").find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var part_name := String(part.name)
		if part_name == "Skin_Head": _face_mesh = part
		if part_name == "Skin_Head" or part_name.begins_with("Eye_") or part_name.begins_with("Hair_"):
			if not _base_head_parts.has(part_name):
				_base_head_parts[part_name] = part.mesh
			# Reuse this actor's skin/skeleton; the package supplies compatible
			# head, eye and hair meshes without another live animated rig.
			part.mesh = head_parts.get(part_name, _base_head_parts[part_name])
			if part_name.begins_with("Hair_"):
				part.mesh = hair_parts.get(part_name, part.mesh)
				part.visible = appearance.hair_style != "bald"
			for surface in part.mesh.get_surface_count():
				part.set_surface_override_material(surface, null)
		if part.name == "YBot_Surface":
			part.visible = not short_sleeves
		elif part.name == "Kit_Shirt_ShortSleeve":
			part.visible = short_sleeves
		elif part.name == "Kit_shirt_BoundHems":
			part.visible = not short_sleeves
		if part.name == "Skin_Hands" and appearance.kit.ends_with("keeper"):
			var glove := StandardMaterial3D.new()
			glove.albedo_color = Color(0.78,0.76,0.58)
			glove.roughness = 0.82
			part.material_override = glove
		for index in part.mesh.get_surface_count():
			var material := part.mesh.surface_get_material(index)
			if material != null and String(material.resource_name).begins_with("MAT_Beechlawn_HomeKit"):
				part.set_surface_override_material(index, kit_material)
		if part.name == "Skin_Head" and (appearance.head_albedo != null or appearance.skin_tint != Color.WHITE):
			var skin := part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			if appearance.head_albedo != null:
				skin.albedo_texture = appearance.head_albedo
			skin.albedo_color = appearance.skin_tint
			part.set_surface_override_material(0,skin)
	var rig_node := get_node("Rig") as Node3D
	rig_node.scale = Vector3(appearance.build_scale, appearance.height_scale, appearance.build_scale)
	_add_back_print(profile, appearance)
	_prime_locomotion_pose()


static func _head_parts(packed: PackedScene) -> Dictionary:
	if packed == null:
		return {}
	if _head_variant_meshes.has(packed):
		return _head_variant_meshes[packed]
	var variant := packed.instantiate()
	var parts: Dictionary = {}
	for node in variant.find_children("*", "MeshInstance3D", true, false):
		var name := String(node.name)
		if name == "Skin_Head" or name.begins_with("Eye_") or name.begins_with("Hair_"):
			parts[name] = (node as MeshInstance3D).mesh
	variant.free()
	_head_variant_meshes[packed] = parts
	return parts


func _prime_locomotion_pose() -> void:
	if _active_action != &"" or _presentation_active:
		return
	# The proxy Rig is replaced by the shared human Rig during configuration.
	# Rebind caches and evaluate idle now, before a rendered bind-pose frame.
	animation_tree.anim_player = animation_tree.get_path_to(animation_player)
	animation_tree.clear_caches()
	animation_tree.active = true
	animation_tree.advance(0.0)


func play_presentation(clip: StringName, phase_seconds := 0.0) -> bool:
	if not animation_player.has_animation(clip):
		return false
	var animation := animation_player.get_animation(clip)
	if animation.loop_mode != Animation.LOOP_LINEAR:
		var loop := animation.duplicate() as Animation
		loop.loop_mode = Animation.LOOP_LINEAR
		var library := animation_player.get_animation_library(&"")
		library.remove_animation(clip)
		library.add_animation(clip, loop)
	_presentation_active = true
	_active_action = &""
	_active_clip = &""
	animation_tree.active = false
	animation_player.play(clip, 0.0)
	animation_player.seek(fposmod(phase_seconds, maxf(animation.length, 0.01)), true)
	return true


func end_presentation() -> void:
	_presentation_active = false
	animation_player.stop()
	_active_action = &""
	_active_clip = &""
	_prime_locomotion_pose()


static func _shared_kit_material(kit: String) -> StandardMaterial3D:
	if _kit_materials.has(kit):
		return _kit_materials[kit]
	var material := StandardMaterial3D.new()
	material.resource_name = "SharedKit_" + kit
	material.albedo_texture = load("res://assets/characters/textures/shared/%s.png" % kit)
	# Atlas-aligned cloth, elastic and print response. Data maps stay linear;
	# the shared pigment remains sRGB and player identity stays separate.
	material.roughness = 1.0
	material.roughness_texture = load("res://assets/characters/textures/shared/%s_roughness.png" % kit)
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.normal_enabled = true
	material.normal_texture = load("res://assets/characters/textures/shared/fabric_knit_normal.png")
	material.normal_scale = 0.35
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_kit_materials[kit] = material
	return material


func _add_back_print(profile: FootballerProfile, appearance: FootballAppearance) -> void:
	if profile.jersey_number <= 0:
		return
	var skeletons := get_node("Rig").find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	var skeleton := skeletons[0] as Skeleton3D
	if skeleton.has_node("IdentityPrint"):
		skeleton.get_node("IdentityPrint").free()
	var bone := skeleton.find_bone("mixamorig_Spine2")
	if bone < 0:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "IdentityPrint"
	attachment.bone_name = skeleton.get_bone_name(bone)
	skeleton.add_child(attachment)
	for index in 2:
		var label := Label3D.new()
		label.name = "PlayerName" if index == 0 else "SquadNumber"
		label.text = appearance.print_name if index == 0 else str(profile.jersey_number)
		label.font_size = 48 if index == 0 else 140
		label.pixel_size = 0.001 if index == 0 else 0.0016
		# John's white number crosses pale cutouts in the keeper back graphic.
		# A narrow dark edge matches the reference print and keeps it readable.
		label.outline_size = (3 if index == 0 else 7) if appearance.kit == "beechlawn_keeper" else 0
		if appearance.kit == "beechlawn_keeper":
			label.outline_modulate = Color(0.10, 0.13, 0.19)
		label.modulate = Color(0.02, 0.03, 0.04) if appearance.kit == "bordeaux_outfield" else Color(0.94, 0.94, 0.92)
		label.double_sided = false
		attachment.add_child(label)
		var height := 1.40 if index == 0 else 1.20
		var desired := global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.17))
		label.transform = (skeleton.global_transform * skeleton.get_bone_global_rest(bone)).affine_inverse() * desired


func play_pass(playback_speed: float = 1.0) -> bool:
	# A buffered first-time pass must take priority over a receive settle.
	return _play_action(&"pass", PASS_CLIP, playback_speed, true)


func play_receive(playback_speed: float = 1.0) -> bool:
	return _play_action(&"receive", RECEIVE_CLIP, playback_speed)

func play_aerial(action: StringName, playback_speed := 1.0) -> bool:
	var started := _play_action(action, AERIAL_CLIPS.get(action, VOLLEY_CLIPS.get(action, &"")), playback_speed, true)
	if started:
		# Airborne contacts pass in a few physics ticks. Flush the new action now
		# and call its marker in the physics animation update, not a later frame.
		animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
		animation_player.advance(0.0)
	return started

func play_keeper_save(style: StringName = &"KeeperCatch", preparation: float = .25) -> bool:
	return _play_action(&"keeper_save", StringName("AN_Beechlawn_" + String(style)), clampf(.25 / maxf(preparation,.09),1,2.8), true, true)


func sustain_keeper_recovery() -> float:
	if _active_action != &"keeper_save": return 0
	var remaining := animation_player.current_animation_length-animation_player.current_animation_position
	# Updating the same playing clip preserves its time while restoring normal
	# follow-through speed after accelerated short-range preparation.
	animation_player.play(_active_clip,0,1)
	return maxf(0,remaining)

func play_stop() -> bool:
	return _play_action(&"stop", STOP_CLIP, 1.0)


func play_turn(turn_right: bool) -> bool:
	var clip := TURN_RIGHT_CLIP if turn_right else TURN_LEFT_CLIP
	return _play_action(&"turn", clip, 1.0)


func play_shot(playback_speed: float = 1.0) -> bool:
	return _play_action(&"shot", SHOT_CLIP, playback_speed, true)


func play_get_up() -> bool:
	return _play_action(&"get_up", GET_UP_CLIP)


func play_slide_tackle() -> bool:
	if is_recovery_active():
		return false
	return _play_action(&"slide_tackle", SLIDE_TACKLE_CLIP, 1.0, false, true)


func is_recovery_active() -> bool:
	return _active_action in [&"get_up", &"header", &"chest_control", &"volley", &"half_volley"]

func can_start_ball_action() -> bool:
	return _active_action in [&"", &"turn", &"stop", &"receive"] \
		or (_action_has_contact and _active_action in [&"pass", &"shot"])


func action_contact_time(action: StringName) -> float:
	return float(_action_contact_times.get(action, -1.0))


func _play_action(action: StringName, clip: StringName, playback_speed: float = 1.0,
		interrupt_receive: bool = false, interrupt_action: bool = false) -> bool:
	if not animation_player.has_animation(clip):
		return false
	if _active_action != &"":
		var interrupt_locomotion := _active_action in [&"turn", &"stop"] \
			and action not in [&"turn", &"stop"]
		var interrupt_follow_through := _action_has_contact \
			and _active_action in [&"pass", &"shot", &"receive"] \
			and action in [&"pass", &"shot", &"header", &"chest_control"]
		if not interrupt_action and not interrupt_locomotion and not interrupt_follow_through \
				and (not interrupt_receive or _active_action != &"receive"):
			return false
		var interrupted_action := _active_action
		animation_player.stop()
		_active_action = &""
		_active_clip = &""
		animation_tree.active = true
		action_finished.emit(interrupted_action)
	_active_action = action
	_active_clip = clip
	_action_has_contact = false
	animation_tree.active = false
	var start_time := 0.0
	var blend_seconds := 0.08
	if action in [&"pass", &"shot"] and playback_speed > 1.5:
		# A fast first-time return skips redundant anticipation instead of
		# racing the entire swing and follow-through at five to ten times speed.
		var marker := action_contact_time(action)
		var arrival := marker / playback_speed
		playback_speed = 1.5
		start_time = maxf(0.0, marker - arrival * playback_speed)
		blend_seconds = minf(blend_seconds, arrival * 0.35)
	animation_player.play(clip, blend_seconds, playback_speed)
	if start_time > 0.0:
		animation_player.seek(start_time, true)
	return true


func on_action_contact_marker() -> void:
	if _active_action != &"" and not _action_has_contact:
		_action_has_contact = true
		action_contact.emit(_active_action)


func set_locomotion_speed(speed_mps: float, _sprinting: bool = false,
		braking: bool = false, close_control: bool = false,
		delta: float = 1.0 / 60.0) -> void:
	# The authored blend points are idle=0, jog=0.55 and sprint=1. Intent does
	# not determine gait: a held sprint still starts at idle and accelerates.
	var jog_speed := maxf(jog_reference_speed, 0.01)
	var sprint_speed := maxf(sprint_reference_speed, jog_speed + 0.01)
	var locomotion := 0.55 * clampf(speed_mps / jog_speed, 0.0, 1.0)
	if speed_mps > jog_speed:
		locomotion = lerpf(0.55, 1.0, clampf((speed_mps - jog_speed) / (sprint_speed - jog_speed), 0.0, 1.0))
	_blend_position = lerpf(_blend_position, locomotion, 1.0 - exp(-10.0 * delta))
	_close_control_blend = lerpf(_close_control_blend,
		1.0 if close_control and speed_mps > 0.35 else 0.0,
		1.0 - exp(-12.0 * delta))
	if absf(float(animation_tree.get("parameters/Locomotion/blend_position")) - _blend_position) >= 0.005:
		animation_tree.set("parameters/Locomotion/blend_position", _blend_position)
	if absf(float(animation_tree.get("parameters/CloseControl/blend_amount")) - _close_control_blend) >= 0.005:
		animation_tree.set("parameters/CloseControl/blend_amount", _close_control_blend)
	if _active_action == &"stop" and not braking and speed_mps > 1.2:
		animation_player.stop()
		_active_action = &""
		_active_clip = &""
		animation_tree.active = true
	if not braking:
		_stop_latched = false
	elif not _stop_latched and speed_mps > 0.8 and _active_action == &"":
		_stop_latched = play_stop()


func _build_locomotion_tree() -> void:
	# Packed-scene instances may share the AnimationTree's generated root resource.
	# Reuse it when a previous actor in the same scene already built the layers.
	if animation_tree.tree_root is AnimationNodeBlendTree:
		return
	var source := animation_tree.tree_root as AnimationNodeBlendSpace1D
	if source == null or source.get_blend_point_count() < 4:
		push_error("Footballer visual requires idle, jog, sprint and close-control blend nodes")
		return
	var locomotion := AnimationNodeBlendSpace1D.new()
	locomotion.min_space = source.min_space
	locomotion.max_space = source.max_space
	locomotion.blend_mode = source.blend_mode
	for point_index in range(3):
		locomotion.add_blend_point(source.get_blend_point_node(point_index),
			source.get_blend_point_position(point_index))
	var close_animation := source.get_blend_point_node(3) as AnimationNodeAnimation
	var tree := AnimationNodeBlendTree.new()
	tree.add_node("Locomotion", locomotion, Vector2(0, 0))
	tree.add_node("CloseControlAnimation", close_animation, Vector2(0, 180))
	tree.add_node("CloseControl", AnimationNodeBlend2.new(), Vector2(260, 80))
	tree.connect_node("CloseControl", 0, "Locomotion")
	tree.connect_node("CloseControl", 1, "CloseControlAnimation")
	tree.connect_node("output", 0, "CloseControl")
	animation_tree.tree_root = tree


func set_team_color(team_color: Color) -> void:
	var surface := get_node_or_null("Rig/YBot_Armature/Skeleton3D/YBot_Surface") as MeshInstance3D
	var joints := get_node_or_null("Rig/YBot_Armature/Skeleton3D/YBot_Joints") as MeshInstance3D
	if surface == null or joints == null:
		push_warning("Y-Bot visual is missing its expected skinned body surfaces")
		return
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = team_color
	body_material.roughness = 0.78
	surface.material_override = body_material
	var joint_material := StandardMaterial3D.new()
	joint_material.albedo_color = team_color.darkened(0.28)
	joint_material.roughness = 0.86
	joints.material_override = joint_material


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != _active_clip or _active_action == &"":
		return
	var finished_action := _active_action
	if finished_action in AERIAL_CLIPS or finished_action in VOLLEY_CLIPS:
		animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	if finished_action == &"slide_tackle" and animation_player.has_animation(GET_UP_CLIP):
		_active_action = &"get_up"
		_active_clip = GET_UP_CLIP
		animation_player.play(GET_UP_CLIP, 0.06, 1.0)
		action_finished.emit(finished_action)
		return
	_active_action = &""
	_active_clip = &""
	animation_tree.active = true
	action_finished.emit(finished_action)


func _install_action_contact_marker(action: StringName, clip_name: StringName,
		metadata_path: String) -> void:
	var library := animation_player.get_animation_library(&"")
	if library == null or not library.has_animation(clip_name):
		push_error("Y-Bot animation library is missing %s" % clip_name)
		return
	if not FileAccess.file_exists(metadata_path):
		push_error("Missing Blender-authored action contact metadata: %s" % metadata_path)
		return
	var parsed_events: Variant = JSON.parse_string(FileAccess.get_file_as_string(metadata_path))
	if typeof(parsed_events) != TYPE_DICTIONARY:
		push_error("Could not parse action contact metadata: %s" % metadata_path)
		return
	var event_data: Dictionary = parsed_events
	if event_data.get("clip", "") != String(clip_name) or event_data.get("event", "") != "ball_contact":
		push_error("Action contact metadata does not match %s" % clip_name)
		return
	var contact_time := float(event_data.get("frame", -1)) / maxf(float(event_data.get("fps", 0)), 1.0)
	if contact_time <= 0.0:
		push_error("Invalid action contact frame/fps metadata for %s" % clip_name)
		return
	_action_contact_times[action] = contact_time
	var clip := library.get_animation(clip_name).duplicate() as Animation
	var marker_path := NodePath("..:on_action_contact_marker")
	var legacy_marker_path := NodePath("..:on_pass_contact_marker")
	var marker_exists := false
	for track_index in range(clip.get_track_count() - 1, -1, -1):
		if clip.track_get_type(track_index) == Animation.TYPE_METHOD \
				and clip.track_get_path(track_index) == legacy_marker_path:
			clip.remove_track(track_index)
			continue
		if clip.track_get_type(track_index) == Animation.TYPE_METHOD \
				and clip.track_get_path(track_index) == marker_path:
			marker_exists = true
			break
	if not marker_exists:
		var marker_track := clip.add_track(Animation.TYPE_METHOD)
		clip.track_set_path(marker_track, marker_path)
		clip.track_insert_key(marker_track, contact_time,
			{"method": "on_action_contact_marker", "args": []})
	library.remove_animation(clip_name)
	library.add_animation(clip_name, clip)

func _install_match_motion() -> void:
	var source := (load("res://assets/characters/shared/match_motion.glb") as PackedScene).instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for clip in source_player.get_animation_list():
		if clip == "RESET": continue
		var target := StringName(String(clip).trim_suffix("_Arms"))
		var motion := source_player.get_animation(clip).duplicate() as Animation
		if String(clip).ends_with("_Arms") and library.has_animation(target):
			# Runtime export has leg-retarget corrections absent from early source
			# actions. Replace only arm tracks; keep all shipping leg/root keys.
			var arms := motion
			motion = library.get_animation(target).duplicate() as Animation
			for index in range(motion.get_track_count()-1, -1, -1):
				if _arm_track(motion.track_get_path(index)): motion.remove_track(index)
			for index in arms.get_track_count():
				if _arm_track(arms.track_get_path(index)): arms.copy_track(index, motion)
			motion.loop_mode = Animation.LOOP_LINEAR
		if library.has_animation(target): library.remove_animation(target)
		library.add_animation(target, motion)
	source.free()
	_install_action_contact_marker(&"standing_tackle", &"AN_Beechlawn_StandingTackle", "res://assets/characters/shared/standing_tackle_contact.json")

static func _arm_track(path: NodePath) -> bool:
	if path.get_subname_count() == 0: return false
	return String(path.get_subname(0)) in ["mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand"]

func play_standing_tackle() -> bool:
	return _play_action(&"standing_tackle", &"AN_Beechlawn_StandingTackle", 1.0, true, true)

func hand_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var skeletons := get_node("Rig").find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return result
	var skeleton := skeletons[0] as Skeleton3D
	for side in ["Left", "Right"]:
		var id := skeleton.find_bone("mixamorig_" + side + "Hand")
		if id >= 0: result.append(skeleton.to_global(skeleton.get_bone_global_pose(id).origin))
	return result

func _install_presentation_actions() -> void:
	var source := (load("res://assets/characters/shared/match_presentation.glb") as PackedScene).instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for name in [&"AN_Beechlawn_Celebrate",&"AN_Beechlawn_Handshake"]:
		if not library.has_animation(name): library.add_animation(name,source_player.get_animation(name).duplicate())
	source.free()

func _install_restart_actions() -> void:
	var scene := load("res://assets/characters/shared/restart_actions.glb") as PackedScene
	var source := scene.instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for name in [&"AN_Beechlawn_ThrowIn", &"AN_Beechlawn_ShowCard"]:
		if not library.has_animation(name): library.add_animation(name,source_player.get_animation(name).duplicate())
	source.free()
	_install_action_contact_marker(&"restart_throw", &"AN_Beechlawn_ThrowIn", "res://assets/characters/shared/throw_contact.json")

func _install_aerial_actions() -> void:
	var scene := load("res://assets/characters/shared/aerial_actions.glb") as PackedScene
	var source := scene.instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for name in AERIAL_CLIPS.values():
		if not library.has_animation(name): library.add_animation(name, source_player.get_animation(name).duplicate())
	source.free()
	_install_action_contact_marker(&"header", AERIAL_CLIPS[&"header"], "res://assets/characters/shared/header_contact.json")
	_install_action_contact_marker(&"chest_control", AERIAL_CLIPS[&"chest_control"], "res://assets/characters/shared/chest_contact.json")

func _install_volley_actions() -> void:
	var scene := load("res://assets/characters/shared/advanced_actions.glb") as PackedScene
	var source := scene.instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for name in VOLLEY_CLIPS.values():
		if not library.has_animation(name): library.add_animation(name, source_player.get_animation(name).duplicate())
	source.free()
	for action in VOLLEY_CLIPS:
		_install_action_contact_marker(action, VOLLEY_CLIPS[action], "res://assets/characters/shared/" + str(action) + "_contact.json")

func reset_to_idle() -> void:
	end_presentation()
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	_blend_position=0.0
	_close_control_blend=0.0
	animation_tree.set("parameters/Locomotion/blend_position",0.0)
	animation_tree.set("parameters/CloseControl/blend_amount",0.0)
	animation_tree.advance(0.0)
