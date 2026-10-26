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
const LEFT_STRIKE_CLIPS := {&"pass": &"AN_Beechlawn_PassLeft", &"shot": &"AN_Beechlawn_ShotLeft", &"volley": &"AN_Beechlawn_VolleyLeft", &"half_volley": &"AN_Beechlawn_HalfVolleyLeft"}
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
var _shield_blend := 0.0
var _context_receiving := false
var _receive_index := 0
var _receive_clock := 0.0
var _receive_speed := 1.0
static var _receive_motion_cache: Dictionary = {}
static var _receive_metadata: Dictionary = {}
var _receive_marker := .2
var _receive_duration := .5
const CONTEXT_RECEIVE_CLIPS: Array[StringName] = [&"AN_Beechlawn_ReceiveStandRight",&"AN_Beechlawn_ReceiveStandLeft",&"AN_Beechlawn_ReceiveMoveRight",&"AN_Beechlawn_ReceiveMoveLeft"]
var _appearance_profile: FootballerProfile
var _appearance_team: FootballTeam
var _human_rig := false
var _presentation_active := false
var _base_head_parts: Dictionary = {}
var _base_body_materials: Dictionary = {}
var _face_mesh: MeshInstance3D
var _face_clock := 0.0
var pose_presentation: FootballPosePresentation
var _normal_head_parts: Dictionary = {}
var _normal_head_materials: Dictionary = {}
var _near_head_parts: Dictionary = {}
var _near_view := false
var _lod_initialized := false
var _hair_allowed := true
static var _kit_materials: Dictionary = {}
static var _head_variant_meshes: Dictionary = {}
static var _stride_motion_cache: Dictionary = {}
@export var jog_reference_speed := 6.0
@export var sprint_reference_speed := 8.6
@export var stop_pose_entry_speed := 2.6


func _ready() -> void:
	_prepare_looping_motion()
	_install_restart_actions()
	_install_aerial_actions()
	_install_volley_actions()
	_install_left_strikes()
	_install_match_motion()
	_install_stride_gaits()
	_install_keeper_high_actions()
	_install_presentation_actions()
	_install_skill_actions()
	_install_receive_actions()
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
	_update_detail_level()
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
		_install_left_strikes()
		_install_match_motion()
		_install_stride_gaits()
		_install_keeper_high_actions()
		_install_presentation_actions()
		_install_skill_actions()
		_install_receive_actions()
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
	_normal_head_parts = head_parts
	_normal_head_materials = {}
	_near_head_parts = {}
	var near_path := "res://assets/characters/shared/heads/near/" + appearance.head_variant.resource_path.get_file() if appearance.head_variant != null else ""
	if not near_path.is_empty() and ResourceLoader.exists(near_path):
		_near_head_parts = _head_parts(load(near_path))
	_lod_initialized = false
	_hair_allowed = appearance.hair_style != "bald"
	var body_parts := _head_parts(load("res://assets/characters/shared/body_shapes.glb"))
	for node in get_node("Rig").find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		var part_name := String(part.name)
		if body_parts.has(part_name):
			if not _base_body_materials.has(part_name):
				var originals: Array[Material] = []
				for surface in part.mesh.get_surface_count(): originals.append(part.mesh.surface_get_material(surface))
				_base_body_materials[part_name] = originals
			part.mesh = body_parts[part_name]
			for surface in part.mesh.get_surface_count():
				part.set_surface_override_material(surface,_base_body_materials[part_name][surface])
			var fullness := part.find_blend_shape_by_name("Fullness")
			if fullness >= 0:
				part.set_blend_shape_value(fullness, appearance.body_fullness)
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
				var source_material := part.mesh.surface_get_material(surface)
				if source_material != null and (source_material.resource_name == "MAT_Des_SideBackRoots" or String(source_material.resource_name).begins_with("MAT_PortraitScalpRoots_")):
					part.set_surface_override_material(surface,FootballCharacterLook.groom_root_for(source_material))
			var head_fullness := part.find_blend_shape_by_name("Fullness")
			if head_fullness >= 0: part.set_blend_shape_value(head_fullness, appearance.body_fullness)
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
			var material := part.get_active_material(index)
			if material != null and String(material.resource_name).begins_with("MAT_Beechlawn_HomeKit"):
				part.set_surface_override_material(index, kit_material)
		if part.name == "Skin_Head" and (appearance.head_albedo != null or appearance.skin_tint != Color.WHITE):
			var skin := part.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			if appearance.head_albedo != null:
				skin.albedo_texture = appearance.head_albedo
			skin.albedo_color = appearance.skin_tint
			part.set_surface_override_material(0,skin)
		if part.name == "Skin_Head" or String(part.name).begins_with("Eye_"):
			var source_materials: Array[Material] = []
			for index in part.mesh.get_surface_count(): source_materials.append(part.get_active_material(index))
			_normal_head_materials[part_name] = source_materials
	var rig_node := get_node("Rig") as Node3D
	_configure_oral_parts(head_parts)
	rig_node.scale = Vector3(appearance.build_scale, appearance.height_scale, appearance.build_scale)
	_add_back_print(profile, appearance)
	_prime_locomotion_pose()
	_bind_pose_presentation()


func _configure_oral_parts(parts: Dictionary) -> void:
	# Optional individual oral geometry shares the live head's bind/skeleton.
	# Reconfiguration removes the previous identity's parts synchronously.
	for node in get_node("Rig").find_children("Mouth_*", "MeshInstance3D",true,false):
		node.free()
	for part_name in parts:
		if not String(part_name).begins_with("Mouth_"): continue
		var part := MeshInstance3D.new()
		part.name=part_name
		part.mesh=parts[part_name]
		part.skin=_face_mesh.skin
		part.skeleton=_face_mesh.skeleton
		_face_mesh.get_parent().add_child(part)
		part.transform=_face_mesh.transform


static func _head_parts(packed: PackedScene) -> Dictionary:
	if packed == null:
		return {}
	if _head_variant_meshes.has(packed):
		return _head_variant_meshes[packed]
	var variant := packed.instantiate()
	var parts: Dictionary = {}
	for node in variant.find_children("*", "MeshInstance3D", true, false):
		var name := String(node.name)
		parts[name] = (node as MeshInstance3D).mesh
	variant.free()
	_head_variant_meshes[packed] = parts
	return parts


func _bind_pose_presentation() -> void:
	if is_instance_valid(pose_presentation):
		pose_presentation.snap()
		return
	var skeleton := get_node("Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null: return
	pose_presentation = FootballPosePresentation.new()
	pose_presentation.name = "PosePresentation"
	skeleton.add_child(pose_presentation)
	pose_presentation.watch(skeleton, get_parent() as Node3D, [animation_tree, animation_player])


func bone_world_position(bone_name: StringName) -> Vector3:
	var skeleton := get_node("Rig").find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null: return global_position
	var index := skeleton.find_bone(bone_name)
	if index < 0: return global_position
	if is_instance_valid(pose_presentation): return pose_presentation.bone_world_position(index)
	return skeleton.to_global(skeleton.get_bone_global_pose(index).origin)


func _update_detail_level() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var distance := camera.global_position.distance_to(_face_mesh.global_position + Vector3.UP*1.6)
	var close := distance < (9.0 if _near_view else 8.0)
	for node in get_node("Rig").find_children("Hair_*", "MeshInstance3D", true, false):
		if String(node.name).ends_with("Cards"): node.visible = _hair_allowed and distance < 18.0
	if _lod_initialized and close == _near_view: return
	_near_view = close; _lod_initialized = true
	var parts := _near_head_parts if close and not _near_head_parts.is_empty() else _normal_head_parts
	for node in get_node("Rig").find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if part.name != "Skin_Head" and not String(part.name).begins_with("Eye_"): continue
		var weights: Dictionary = {}
		for index in part.mesh.get_blend_shape_count(): weights[part.mesh.get_blend_shape_name(index)] = part.get_blend_shape_value(index)
		if parts.has(String(part.name)): part.mesh = parts[String(part.name)]
		for index in part.mesh.get_blend_shape_count():
			part.set_blend_shape_value(index, float(weights.get(part.mesh.get_blend_shape_name(index), 0)))
		for index in part.mesh.get_surface_count():
			var sources: Array = _normal_head_materials[String(part.name)]
			part.set_surface_override_material(index, FootballCharacterLook.material_for(sources[mini(index,sources.size()-1)],part.name == "Skin_Head",close))


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
	cancel_context_receive()
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
	# Noninteractive broadcast motion can evaluate every rendered frame. Match
	# actions return to fixed-tick evaluation before any football contact.
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	_active_action = &""
	_active_clip = &""
	animation_tree.active = false
	animation_player.play(clip, 0.0)
	animation_player.seek(fposmod(phase_seconds, maxf(animation.length, 0.01)), true)
	if is_instance_valid(pose_presentation): pose_presentation.snap()
	return true


func end_presentation() -> void:
	_presentation_active = false
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
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
		# The print follows the fuller back instead of sinking into the shirt.
		var back_offset := appearance.body_fullness * (0.011 if index == 1 else 0.002)
		var desired := global_transform * Transform3D(Basis.IDENTITY, Vector3(0.0, height, 0.17 + back_offset))
		label.transform = (skeleton.global_transform * skeleton.get_bone_global_rest(bone)).affine_inverse() * desired


func play_pass(playback_speed: float = 1.0, foot: StringName = &"right") -> bool:
	# A buffered first-time pass must take priority over a receive settle.
	return _play_action(&"pass", LEFT_STRIKE_CLIPS[&"pass"] if foot == &"left" else PASS_CLIP, playback_speed, true)


func strike_foot() -> StringName:
	return &"left" if _active_clip in LEFT_STRIKE_CLIPS.values() else &"right"


func play_receive(playback_speed: float = 1.0) -> bool:
	return _play_action(&"receive", RECEIVE_CLIP, playback_speed)

func play_aerial(action: StringName, playback_speed := 1.0, foot: StringName = &"right") -> bool:
	var clip: StringName = AERIAL_CLIPS.get(action, VOLLEY_CLIPS.get(action, &""))
	if foot == &"left" and action in VOLLEY_CLIPS: clip = LEFT_STRIKE_CLIPS[action]
	var started := _play_action(action, clip, playback_speed, true)
	if started:
		# Airborne contacts pass in a few physics ticks. Flush the new action now
		# and call its marker in the physics animation update, not a later frame.
		animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
		animation_player.advance(0.0)
	return started

func play_keeper_save(style: StringName = &"KeeperCatch", preparation: float = .25) -> bool:
	var minimum_speed := .55 if String(style).begins_with("KeeperHigh") or String(style).contains("DiveFull") else 1.0
	return _play_action(&"keeper_save", StringName("AN_Beechlawn_" + String(style)), clampf(.25 / maxf(preparation,.09),minimum_speed,2.8), true, true)


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


func play_shot(playback_speed: float = 1.0, foot: StringName = &"right") -> bool:
	return _play_action(&"shot", LEFT_STRIKE_CLIPS[&"shot"] if foot == &"left" else SHOT_CLIP, playback_speed, true)


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
		or (_action_has_contact and _active_action in [&"pass", &"shot", &"skill"])


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
			and _active_action in [&"pass", &"shot", &"receive", &"skill"] \
			and action in [&"pass", &"shot", &"header", &"chest_control"]
		if not interrupt_action and not interrupt_locomotion and not interrupt_follow_through \
				and (not interrupt_receive or _active_action != &"receive"):
			return false
		var interrupted_action := _active_action
		_clear_context_receive()
		if interrupted_action == &"skill": animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
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
	# Fixed-tick contacts must run at the marker, before a fast arrival has
	# advanced into the body on the next deferred callback.
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE if action in [&"pass",&"shot"] or String(action).begins_with("restart_") else AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
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
	# All footwork loops share a normalized phase. Scale this branch alone;
	# one-shot football actions retain their authored marker timing.
	var jog_cadence := lerpf(1.14,1.333333333,clampf((speed_mps-jog_speed*.25)/(jog_speed*.25),0,1))
	if speed_mps>jog_speed*.5:
		jog_cadence=lerpf(1.333333333,1.5,clampf((speed_mps-jog_speed*.5)/(jog_speed*.5),0,1))
	var sprint_weight := clampf((speed_mps-jog_speed)/(sprint_speed-jog_speed),0,1)
	var cadence := lerpf(jog_cadence,1.875,sprint_weight)
	cadence = lerpf(cadence,1.333333333,_close_control_blend)
	animation_tree.set("parameters/GaitRate/scale",cadence if speed_mps>.05 else 1.0)
	animation_tree.set("parameters/ClosePace/blend_amount",clampf(speed_mps/3.36,0,1))
	if _active_action == &"stop" and not braking and speed_mps > 1.2:
		animation_player.stop()
		_active_action = &""
		_active_clip = &""
		animation_tree.active = true
	if not braking:
		_stop_latched = false
	# Keep stepping during fast deceleration. At the default 15 m/s² braking,
	# 2.6 m/s leaves about 0.23 m of travel for the final planted weight shift.
	elif not _stop_latched and speed_mps > 0.8 and speed_mps <= stop_pose_entry_speed and _active_action == &"":
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
	locomotion.sync = true
	for point_index in range(3):
		locomotion.add_blend_point(source.get_blend_point_node(point_index),
			source.get_blend_point_position(point_index))
	var slow_jog := AnimationNodeAnimation.new()
	slow_jog.animation = &"AN_Beechlawn_SlowJog"
	locomotion.add_blend_point(slow_jog,.275)
	var walk := AnimationNodeAnimation.new()
	walk.animation = &"AN_Beechlawn_Walk"
	locomotion.add_blend_point(walk,.1375)
	var close_animation := source.get_blend_point_node(3) as AnimationNodeAnimation
	var tree := AnimationNodeBlendTree.new()
	tree.add_node("Locomotion", locomotion, Vector2(0, 0))
	tree.add_node("CloseControlAnimation", close_animation, Vector2(0, 180))
	var close_idle := AnimationNodeAnimation.new()
	close_idle.animation = &"AN_Beechlawn_Idle"
	var close_pace := AnimationNodeBlend2.new()
	close_pace.sync = true
	tree.add_node("CloseIdle", close_idle, Vector2(0, 270))
	tree.add_node("ClosePace", close_pace, Vector2(170, 180))
	tree.connect_node("ClosePace",0,"CloseIdle")
	tree.connect_node("ClosePace",1,"CloseControlAnimation")
	var close_mode := AnimationNodeBlend2.new()
	close_mode.sync = true
	tree.add_node("CloseControl", close_mode, Vector2(340, 80))
	tree.connect_node("CloseControl", 0, "Locomotion")
	tree.connect_node("CloseControl", 1, "ClosePace")
	tree.add_node("GaitRate",AnimationNodeTimeScale.new(),Vector2(480,80))
	tree.connect_node("GaitRate",0,"CloseControl")
	var shield_animation := AnimationNodeAnimation.new()
	shield_animation.animation = &"AN_Beechlawn_Shield"
	var shield := AnimationNodeBlend2.new()
	shield.filter_enabled = true
	var motion := animation_player.get_animation(&"AN_Beechlawn_Shield")
	for track in motion.get_track_count(): shield.set_filter_path(motion.track_get_path(track), true)
	tree.add_node("ShieldAnimation", shield_animation, Vector2(0, 360))
	tree.add_node("Shield", shield, Vector2(480, 80))
	tree.connect_node("Shield", 0, "GaitRate")
	tree.connect_node("Shield", 1, "ShieldAnimation")
	# One selected receive layer keeps the dormant 22-player graph cheap.
	# Clip/seek/blend parameters are actor-local; immutable motions stay shared.
	var receive_space := AnimationNodeBlendSpace1D.new()
	receive_space.min_space = 0
	receive_space.max_space = 3
	receive_space.blend_mode = AnimationNodeBlendSpace1D.BLEND_MODE_INTERPOLATED
	for index in CONTEXT_RECEIVE_CLIPS.size():
		var receive_animation := AnimationNodeAnimation.new()
		receive_animation.animation = CONTEXT_RECEIVE_CLIPS[index]
		receive_space.add_blend_point(receive_animation,index)
	tree.add_node("ReceiveClip",receive_space)
	tree.add_node("ReceiveSeek",AnimationNodeTimeSeek.new())
	tree.add_node("Receive",AnimationNodeBlend2.new())
	tree.connect_node("ReceiveSeek",0,"ReceiveClip")
	tree.connect_node("Receive",0,"Shield")
	tree.connect_node("Receive",1,"ReceiveSeek")
	tree.connect_node("output",0,"Receive")
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
	if finished_action in AERIAL_CLIPS or finished_action in VOLLEY_CLIPS or finished_action in [&"skill",&"pass",&"shot"] or String(finished_action).begins_with("restart_"):
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

static func _gait_track(path: NodePath) -> bool:
	if path.get_subname_count()==0:return false
	var bone:=String(path.get_subname(0))
	return bone=="mixamorig_Hips" or bone.contains("Leg") or bone.contains("Foot") or bone.contains("Toe")

func _install_stride_gaits() -> void:
	var library := animation_player.get_animation_library(&"")
	var cache_key:=&"human" if _human_rig else &"proxy"
	if _stride_motion_cache.has(cache_key):
		for name in _stride_motion_cache[cache_key]:
			if library.has_animation(name):library.remove_animation(name)
			library.add_animation(name,_stride_motion_cache[cache_key][name])
		return
	var source := (load("res://assets/characters/shared/stride_gaits.glb") as PackedScene).instantiate()
	var player := source.get_node("AnimationPlayer") as AnimationPlayer
	var merged: Dictionary={}
	for name in player.get_animation_list():
		if name=="RESET":continue
		var target:=StringName(String(name).trim_suffix("_Footwork"))
		# Reuse the existing spine/head/finger content for the slower gaits;
		# authored lower-body and arm tracks replace their movement channels.
		var template:=&"AN_Beechlawn_Jog" if target in [&"AN_Beechlawn_SlowJog",&"AN_Beechlawn_Walk",&"AN_Beechlawn_CloseControl"] else target
		if not library.has_animation(template):continue
		var motion:=library.get_animation(template).duplicate() as Animation
		var original_length:=motion.length
		# Preserve unrelated pose content, retimed to the common gait phase.
		for track in range(motion.get_track_count()-1,-1,-1):
			if _gait_track(motion.track_get_path(track)) or _arm_track(motion.track_get_path(track)):
				motion.remove_track(track)
			else:
				for key in range(motion.track_get_key_count(track)-1,-1,-1):
					motion.track_set_key_time(track,key,motion.track_get_key_time(track,key)/maxf(.01,original_length))
		var footwork:=player.get_animation(name)
		for track in footwork.get_track_count():
			if _gait_track(footwork.track_get_path(track)) or _arm_track(footwork.track_get_path(track)):footwork.copy_track(track,motion)
		motion.length=1.0
		motion.loop_mode=Animation.LOOP_LINEAR
		if library.has_animation(target):library.remove_animation(target)
		library.add_animation(target,motion)
		merged[target]=motion
	# Pose content is immutable after assembly. AnimationTree playback remains
	# per actor; proxy and final-human imports have separate cache entries.
	_stride_motion_cache[cache_key]=merged
	source.free()

func play_standing_tackle() -> bool:
	return _play_action(&"standing_tackle", &"AN_Beechlawn_StandingTackle", 1.0, true, true)

func _install_keeper_high_actions() -> void:
	var library := animation_player.get_animation_library(&"")
	for path in ["res://assets/characters/shared/keeper_high_saves.glb","res://assets/characters/shared/keeper_full_dives.glb"]:
		var source := (load(path) as PackedScene).instantiate()
		var player := source.get_node("AnimationPlayer") as AnimationPlayer
		for name in player.get_animation_list():
			if name == "RESET": continue
			if library.has_animation(name): library.remove_animation(name)
			library.add_animation(name,player.get_animation(name).duplicate())
		source.free()

func hand_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	var skeletons := get_node("Rig").find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty(): return result
	var skeleton := skeletons[0] as Skeleton3D
	for side in ["Left", "Right"]:
		var id := skeleton.find_bone("mixamorig_" + side + "Hand")
		if id >= 0: result.append(bone_world_position(skeleton.get_bone_name(id)))
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
	var wall_source := (load("res://assets/characters/shared/free_kick_wall.glb") as PackedScene).instantiate()
	var wall_player := wall_source.get_node("AnimationPlayer") as AnimationPlayer
	for name in [&"AN_Beechlawn_WallBrace",&"AN_Beechlawn_WallJump"]:
		if not library.has_animation(name):
			var motion := wall_player.get_animation(name).duplicate() as Animation
			motion.loop_mode = Animation.LOOP_LINEAR if name == &"AN_Beechlawn_WallBrace" else Animation.LOOP_NONE
			library.add_animation(name,motion)
	wall_source.free()

func play_wall(jump: bool) -> void:
	_play_action(&"wall", &"AN_Beechlawn_WallJump" if jump else &"AN_Beechlawn_WallBrace",1,false,true)

func restart_contact_offset(shooting: bool) -> Vector3:
	# Sample the real imported pose without firing its method track. Convert
	# through the assembled player's actual height/rig transform, not a proxy.
	var clip := SHOT_CLIP if shooting else PASS_CLIP
	var marker := action_contact_time(&"shot" if shooting else &"pass")
	animation_tree.active = false
	animation_player.play(clip,0)
	animation_player.seek(marker,true,true)
	var skeleton := get_node("Rig").find_child("Skeleton3D",true,false) as Skeleton3D
	var bone := skeleton.find_bone("mixamorig_RightToe_End")
	var offset: Vector3 = get_parent().to_local(skeleton.to_global(skeleton.get_bone_global_pose(bone).origin))
	end_presentation()
	return offset

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

func _install_left_strikes() -> void:
	var source := (load("res://assets/characters/shared/left_strikes.glb") as PackedScene).instantiate()
	var source_player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for action: StringName in LEFT_STRIKE_CLIPS:
		var clip: StringName = LEFT_STRIKE_CLIPS[action]
		if not library.has_animation(clip): library.add_animation(clip,source_player.get_animation(clip).duplicate())
	source.free()
	for action: StringName in LEFT_STRIKE_CLIPS:
		_install_action_contact_marker(action,LEFT_STRIKE_CLIPS[action],"res://assets/characters/shared/left_"+String(action)+"_contact.json")

func _install_skill_actions() -> void:
	var source := (load("res://assets/characters/shared/skill_actions.glb") as PackedScene).instantiate()
	var player := source.get_node("AnimationPlayer") as AnimationPlayer
	var library := animation_player.get_animation_library(&"")
	for name in player.get_animation_list():
		if name == "RESET": continue
		var motion := player.get_animation(name).duplicate() as Animation
		if name == "AN_Beechlawn_Shield":
			# glTF's forced sampling expands an upper-body action to every bone.
			# Strip those baked lower-body tracks before creating its filter.
			for track in range(motion.get_track_count()-1, -1, -1):
				var path := motion.track_get_path(track)
				var bone := String(path.get_subname(0)) if path.get_subname_count() > 0 else ""
				var upper := bone.begins_with("mixamorig_Spine") or bone.begins_with("mixamorig_LeftHand") or bone.begins_with("mixamorig_RightHand")
				upper = upper or bone in ["mixamorig_LeftShoulder", "mixamorig_RightShoulder", "mixamorig_LeftArm", "mixamorig_RightArm", "mixamorig_LeftForeArm", "mixamorig_RightForeArm"]
				if not upper: motion.remove_track(track)
			motion.loop_mode = Animation.LOOP_LINEAR
		if library.has_animation(name): library.remove_animation(name)
		library.add_animation(name, motion)
		if name == "AN_Beechlawn_Shield": continue
		var suffix := "right" if String(name).ends_with("Right") else "left"
		var kind := String(name).trim_prefix("AN_Beechlawn_").trim_suffix("Right").trim_suffix("Left").to_lower()
		_install_action_contact_marker(&"skill", name, "res://assets/characters/shared/"+kind+"_"+suffix+"_contact.json")
	source.free()

func play_skill(clip: StringName, cancel_shot := false) -> bool:
	if not _play_action(&"skill", clip, 1.0, true, cancel_shot): return false
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	animation_player.advance(0)
	return true

func cancel_skill() -> void:
	if _active_action != &"skill": return
	animation_player.stop()
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	_active_action = &""
	_active_clip = &""
	animation_tree.active = true
	action_finished.emit(&"skill")

func set_shielding(value: bool, delta: float) -> void:
	_shield_blend = move_toward(_shield_blend, 1.0 if value else 0.0, delta*8)
	animation_tree.set("parameters/Shield/blend_amount", _shield_blend)

func reset_to_idle() -> void:
	_clear_context_receive()
	end_presentation()
	animation_player.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_DEFERRED
	_blend_position=0.0
	_close_control_blend=0.0
	_shield_blend=0.0
	animation_tree.set("parameters/Shield/blend_amount", 0.0)
	animation_tree.set("parameters/Locomotion/blend_position",0.0)
	animation_tree.set("parameters/CloseControl/blend_amount",0.0)
	animation_tree.advance(0.0)

func _install_receive_actions() -> void:
	if _receive_motion_cache.is_empty():
		var source := (load("res://assets/characters/shared/receive_actions.glb") as PackedScene).instantiate()
		var player := source.get_node("AnimationPlayer") as AnimationPlayer
		for clip in CONTEXT_RECEIVE_CLIPS:
			var motion := player.get_animation(clip).duplicate() as Animation
			motion.loop_mode = Animation.LOOP_NONE
			_receive_motion_cache[clip] = motion
			var suffix := String(clip).trim_prefix("AN_Beechlawn_Receive")
			var kind := "move" if suffix.begins_with("Move") else "stand"
			var side := "left" if suffix.ends_with("Left") else "right"
			var event: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/shared/receive_%s_%s_contact.json"%[kind,side]))
			_receive_metadata[clip] = event
		source.free()
	var library := animation_player.get_animation_library(&"")
	for clip in CONTEXT_RECEIVE_CLIPS:
		if library.has_animation(clip): library.remove_animation(clip)
		library.add_animation(clip,_receive_motion_cache[clip])

func can_receive_context() -> bool:
	return not _presentation_active and _active_action in [&"",&"stop",&"turn"]

func context_receiving() -> bool: return _context_receiving
func context_receive_clock() -> float: return _receive_clock

func set_context_receive_moving() -> void:
	if not _context_receiving or _receive_index>=2: return
	animation_tree.set("parameters/Receive/blend_amount",0.0)
	_receive_index += 2
	_active_clip = CONTEXT_RECEIVE_CLIPS[_receive_index]
	_set_receive_filter()

func receive_context_offset(foot: StringName, moving: bool) -> Vector3:
	var index := (2 if moving else 0)+(1 if foot == &"left" else 0)
	var point: Array = _receive_metadata[CONTEXT_RECEIVE_CLIPS[index]].toe_at_contact_cm
	# Source local centimetres, Y up/Z forward; shipped Rig has a PI yaw.
	return Vector3(-float(point[0]),float(point[1]),-float(point[2]))*.01

func receive_context_contact_time() -> float:
	var event: Dictionary = _receive_metadata[CONTEXT_RECEIVE_CLIPS[0]]
	return float(event.frame)/float(event.fps)

func receive_context_position(foot: StringName) -> Vector3:
	return bone_world_position(&"mixamorig_LeftToe_End" if foot == &"left" else &"mixamorig_RightToe_End")

func play_context_receive(foot: StringName, moving: bool, speed: float, start := 0.0) -> bool:
	if not can_receive_context(): return false
	animation_player.stop()
	_receive_index = (2 if moving else 0)+(1 if foot == &"left" else 0)
	_active_action = &"receive"
	_active_clip = CONTEXT_RECEIVE_CLIPS[_receive_index]
	var event: Dictionary = _receive_metadata[_active_clip]
	_receive_marker = float(event.frame)/float(event.fps)
	_receive_duration = animation_player.get_animation(_active_clip).length
	_set_receive_filter()
	_context_receiving = true
	_action_has_contact = false
	_receive_clock = start
	_receive_speed = speed
	animation_tree.active = true
	advance_context_receive(0)
	return true

func advance_context_receive(delta: float) -> void:
	if not _context_receiving: return
	var before := _receive_clock
	_receive_clock += delta*_receive_speed
	var amount := minf(clampf(_receive_clock/.08,0,1),clampf((_receive_duration-_receive_clock)/.10,0,1))
	animation_tree.set("parameters/Receive/blend_amount",amount)
	animation_tree.set("parameters/ReceiveSeek/seek_request",minf(_receive_clock,_receive_duration))
	# One fixed-tick clock drives both sampled pose and the exported marker.
	# Seeking method tracks can skip callbacks, so this metadata crossing is
	# dispatched explicitly after the mixer has captured the same physics pose.
	animation_tree.advance(0)
	if before < _receive_marker and _receive_clock >= _receive_marker and not _action_has_contact:
		on_action_contact_marker()
	if _context_receiving and _receive_clock >= _receive_duration:
		cancel_context_receive()

func _clear_context_receive() -> void:
	if not _context_receiving: return
	animation_tree.set("parameters/Receive/blend_amount",0.0)
	var blend := (animation_tree.tree_root as AnimationNodeBlendTree).get_node("Receive") as AnimationNodeBlend2
	blend.filter_enabled = false
	_context_receiving = false

func cancel_context_receive() -> void:
	if not _context_receiving: return
	_clear_context_receive()
	_active_action = &""
	_active_clip = &""
	animation_tree.active = true
	action_finished.emit(&"receive")

func _set_receive_filter() -> void:
	animation_tree.set("parameters/ReceiveClip/blend_position",float(_receive_index))
	var blend := (animation_tree.tree_root as AnimationNodeBlendTree).get_node("Receive") as AnimationNodeBlend2
	blend.filter_enabled = _receive_index>=2
	if not blend.filter_enabled: return
	var side := "Right" if _receive_index==2 else "Left"
	var motion := animation_player.get_animation(CONTEXT_RECEIVE_CLIPS[_receive_index])
	for track in motion.get_track_count():
		var path := motion.track_get_path(track)
		var bone := String(path.get_subname(0)) if path.get_subname_count()>0 else ""
		var selected := bone in ["mixamorig_"+side+"UpLeg","mixamorig_"+side+"Leg","mixamorig_"+side+"Foot","mixamorig_"+side+"ToeBase","mixamorig_"+side+"Toe_End"]
		blend.set_filter_path(path,selected or bone.contains("Arm") or bone.contains("Hand") or bone.contains("Spine") or bone.contains("Shoulder"))
