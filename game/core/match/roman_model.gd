class_name RomanModel
extends Node3D
## Adapts the user-supplied Roman model to the game's universal wrestler rig.
## The source has no animations, so the base rig's animation library is reused
## after its tracks are remapped to Roman's named body bones.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"

const BONE_MAP := {
	"pelvis": "J_Hips",
	"spine_01": "J_Spine1",
	"spine_02": "J_Spine2",
	"spine_03": "J_Chest",
	"neck_01": "J_Neck",
	"Head": "J_Head",
	"clavicle_l": "J_Clavicle_L",
	"upperarm_l": "J_Shoulder_L",
	"lowerarm_l": "J_Elbow_L",
	"hand_l": "J_Wrist_L",
	"index_01_l": "J_IndexF0_L",
	"index_02_l": "J_IndexF1_L",
	"index_03_l": "J_IndexF2_L",
	"middle_01_l": "J_MiddleF0_L",
	"middle_02_l": "J_MiddleF1_L",
	"middle_03_l": "J_MiddleF2_L",
	"pinky_01_l": "J_PinkyF0_L",
	"pinky_02_l": "J_PinkyF1_L",
	"pinky_03_l": "J_PinkyF2_L",
	"ring_01_l": "J_RingF0_L",
	"ring_02_l": "J_RingF1_L",
	"ring_03_l": "J_RingF2_L",
	"thumb_01_l": "J_ThumbF1_L",
	"thumb_02_l": "J_ThumbF2_L",
	"thumb_03_l": "J_ThumbF3_L",
	"clavicle_r": "J_Clavicle_R",
	"upperarm_r": "J_Shoulder_R",
	"lowerarm_r": "J_Elbow_R",
	"hand_r": "J_Wrist_R",
	"index_01_r": "J_IndexF0_R",
	"index_02_r": "J_IndexF1_R",
	"index_03_r": "J_IndexF2_R",
	"index_04_leaf_r": "J_IndexF3_R",
	"middle_01_r": "J_MiddleF0_R",
	"middle_02_r": "J_MiddleF1_R",
	"middle_03_r": "J_MiddleF2_R",
	"middle_04_leaf_r": "J_MiddleF3_R",
	"pinky_01_r": "J_PinkyF0_R",
	"pinky_02_r": "J_PinkyF1_R",
	"pinky_03_r": "J_PinkyF2_R",
	"pinky_04_leaf_r": "J_PinkyF3_R",
	"ring_01_r": "J_RingF0_R",
	"ring_02_r": "J_RingF1_R",
	"ring_03_r": "J_RingF2_R",
	"ring_04_leaf_r": "J_RingF3_R",
	"thumb_01_r": "J_ThumbF1_R",
	"thumb_02_r": "J_ThumbF2_R",
	"thumb_03_r": "J_ThumbF3_R",
	"thigh_l": "J_Leg_L",
	"calf_l": "J_Knee_L",
	"foot_l": "J_Foot_L",
	"ball_l": "J_Toe_L",
	"thigh_r": "J_Leg_R",
	"calf_r": "J_Knee_R",
	"foot_r": "J_Foot_R",
	"ball_r": "J_Toe_R",
}

func _ready() -> void:
	var body: Skeleton3D = _find_body_skeleton()
	if not body:
		push_error("Roman model has no body Skeleton3D")
		return
	_copy_base_animation_library()
	# Iris/pupil geometry is headless-safe (plain nodes); colours need a real
	# renderer, same split WrestlerAttire uses for the same reason.
	_build_eye_details(body)
	if DisplayServer.get_name() != "headless":
		_normalize_face_materials()

func get_game_skeleton() -> Skeleton3D:
	return _find_body_skeleton()func game_bone_name(game_bone: String) -> String:
	return BONE_MAP.get(game_bone, game_bone)

func uses_universal_attire() -> bool:
	return false

## Face-material ground truth, measured off the shipped .glb (see
## assets/characters/CREDITS.md "Roman face findings"), not guessed:
## - M_Head carries ONLY wrinkles_normal; the face colour map ("Image",
##   brows/beard-stubble/lips/tattoo layout) is embedded but referenced by
##   nothing, so the head renders without its colour.
## - The "beard" material and all four hair materials point their albedo at
##   *_rai PACKED DATA textures (green+alpha channels all zero, red/blue
##   hold roughness-ish values), so the beard renders magenta and the hair
##   purple -- and the three BLEND hair materials read the all-zero alpha
##   and vanish entirely.
## - M_EYE has no texture and no vertex colours: flat glossy white.
## - M_Teeth/M_Tongue/M_MouthBag have NO material at all: default grey.
## The fix below re-points all of it at runtime (the .glb is user-supplied
## and must not be hand-edited in the repo): orphan colour map restored,
## data textures unlinked in favour of flat colours, missing materials
## supplied. Determinism-safe: visuals only, no FSM/RNG/physics touched.
const FACE_ALBEDO := "res://assets/characters/roman_reigns_Image.png"
const BEARD_COLOR := Color(0.07, 0.055, 0.045)
const HAIR_COLOR := Color(0.05, 0.042, 0.038)
const TEETH_COLOR := Color(0.87, 0.85, 0.79)
const MOUTH_COLOR := Color(0.28, 0.09, 0.08)

## Geometric irises. The eyeballs are untextured, so the iris/pupil are small
## spheres seated on the cornea, parented to the J_Eye bones (which exist but
## carry no animation tracks, so the eyes ride the head rigidly -- matching
## the base rig, which has no eye bones at all). Offsets are in each eye
## bone's LOCAL space, converted once from the .glb bind pose: eyeballs
## ~2.5cm, bone ~6mm behind the mesh centroid, cornea apex ~+9mm forward in
## root space (+Z facial forward). If a re-export moves the bones, re-measure
## with tools (parse M_EYE centroids vs J_Eye globals) -- do not hand-tune.
const IRIS_R := 0.006
const PUPIL_R := 0.0028
const IRIS_COLOR := Color(0.10, 0.07, 0.05)
const PUPIL_COLOR := Color(0.012, 0.010, 0.010)
const EYE_TARGETS := {
	"J_Eye_L": [Vector3(-0.001077, -0.006686, -0.005771),
		Vector3(-0.001568, -0.009389, -0.007743)],
	"J_Eye_R": [Vector3(0.001110, -0.006769, -0.005661),
		Vector3(0.001613, -0.009503, -0.007587)],
}

func _normalize_face_materials() -> void:
	var face_tex: Texture2D = load(FACE_ALBEDO)
	for mi in find_children("", "MeshInstance3D", true, false):
		var mesh_instance := mi as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		var node_name := String(mesh_instance.name).to_lower()
		# Unmaterialed mouth parts first: their surfaces carry no material to
		# inspect, so they are found by node name only.
		if node_name.contains("teeth"):
			_paint_all_surfaces(mesh_instance, TEETH_COLOR, 0.35, false)
			continue
		if node_name.contains("tongue") or node_name.contains("mouthbag"):
			_paint_all_surfaces(mesh_instance, MOUTH_COLOR, 0.6, false)
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if not (source is StandardMaterial3D):
				continue
			var normal_path := ""
			var albedo_path := ""
			var normal_tex := (source as StandardMaterial3D).normal_texture
			if normal_tex:
				normal_path = normal_tex.resource_path
			var albedo_tex := (source as StandardMaterial3D).albedo_texture
			if albedo_tex:
				albedo_path = albedo_tex.resource_path
			if normal_path.contains("wrinkles_normal"):
				# The head: keep its wrinkle normals, restore the orphan
				# face colour map (brows, stubble, lips, tattoo).
				var head_mat := (source as StandardMaterial3D).duplicate()
				head_mat.albedo_texture = face_tex
				mesh_instance.set_surface_override_material(surface, head_mat)
			elif String(
					(source as StandardMaterial3D).resource_name) == "beard":
				# Beard mass: flat dark colour, opaque, visible from both
				# sides. The linked data texture is never sampled again.
				var beard_mat := (source as StandardMaterial3D).duplicate()
				beard_mat.albedo_texture = null
				beard_mat.albedo_color = BEARD_COLOR
				beard_mat.roughness = 0.65
				beard_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_instance.set_surface_override_material(surface, beard_mat)
			elif albedo_path.contains("hair_rai"):
				# Hair mass or cards: flat near-black, forced opaque (the
				# all-zero alpha channel makes BLEND vanish), double-sided
				# so cards survive from behind.
				var hair_mat := (source as StandardMaterial3D).duplicate()
				hair_mat.albedo_texture = null
				hair_mat.albedo_color = HAIR_COLOR
				hair_mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				hair_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				mesh_instance.set_surface_override_material(surface, hair_mat)

func _paint_all_surfaces(mesh_instance: MeshInstance3D, color: Color,
		roughness: float, metal: bool) -> void:
	for surface in mesh_instance.mesh.get_surface_count():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = roughness
		mat.metallic = 1.0 if metal else 0.0
		mesh_instance.set_surface_override_material(surface, mat)

func _build_eye_details(body: Skeleton3D) -> void:
	var headless := DisplayServer.get_name() == "headless"
	for bone in EYE_TARGETS:
		var bone_idx := body.find_bone(bone)
		if bone_idx < 0:
			push_warning("RomanModel: skeleton has no bone '%s'" % bone)
			continue
		var targets: Array = EYE_TARGETS[bone]
		_add_eye_sphere(body, bone, bone_idx, "RomanIris" + bone.right(6),
			targets[0], IRIS_R, IRIS_COLOR, headless)
		_add_eye_sphere(body, bone, bone_idx, "RomanPupil" + bone.right(6),
			targets[1], PUPIL_R, PUPIL_COLOR, headless)

func _add_eye_sphere(body: Skeleton3D, bone: String, bone_idx: int,
		slot: String, offset: Vector3, radius: float, color: Color,
		headless: bool) -> void:
	for child in body.get_children():
		if String(child.name) == slot:
			return # already built
	var attachment := BoneAttachment3D.new()
	attachment.name = slot
	body.add_child(attachment)
	attachment.bone_name = bone
	attachment.bone_idx = bone_idx
	var ball := SphereMesh.new()
	ball.radius = radius
	ball.height = radius * 2.0
	ball.radial_segments = 12
	ball.rings = 6
	var instance := MeshInstance3D.new()
	instance.mesh = ball
	if not headless:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.25
		mat.metallic = 0.0
		instance.material_override = mat
	instance.position = offset
	attachment.add_child(instance)

func _find_body_skeleton() -> Skeleton3D:
	for candidate in find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.get_bone_count() < 200 \
				and skeleton.find_bone("J_Hips") >= 0:
			return skeleton
	return null

func _animation_skeletons() -> Array[Skeleton3D]:
	var out: Array[Skeleton3D] = []
	for candidate in find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.find_bone("J_Hips") >= 0:
			out.append(skeleton)
	return out

func _copy_base_animation_library() -> void:
	var packed: PackedScene = load(BASE_RIG)
	var source_root: Node = packed.instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var target_player := $AnimationPlayer as AnimationPlayer
	if not source_player or not target_player:
		push_error("Roman model could not load the base animation library")
		source_root.free()
		return
	target_player.add_animation_library("", adapt_animation_library(
			source_player.get_animation_library("")))
	source_root.free()

func adapt_animation_library(source: AnimationLibrary) -> AnimationLibrary:
	var target := AnimationLibrary.new()
	var skeletons := _animation_skeletons()
	for name in source.get_animation_list():
		var source_animation: Animation = source.get_animation(name)
		var animation := Animation.new()
		animation.length = source_animation.length
		animation.loop_mode = source_animation.loop_mode
		animation.step = source_animation.step
		for track in source_animation.get_track_count():
			var path := source_animation.track_get_path(track)
			var bone := String(path.get_concatenated_subnames())
			if not BONE_MAP.has(bone):
				continue
			for skeleton in skeletons:
				var output_track := animation.add_track(
						source_animation.track_get_type(track))
				animation.track_set_path(output_track, NodePath("%s:%s" % [
						get_path_to(skeleton), BONE_MAP[bone]]))
				animation.track_set_interpolation_type(output_track,
						source_animation.track_get_interpolation_type(track))
				for key in source_animation.track_get_key_count(track):
					animation.track_insert_key(output_track,
							source_animation.track_get_key_time(track, key),
							source_animation.track_get_key_value(track, key),
							source_animation.track_get_key_transition(track, key))
		target.add_animation(name, animation)
	return target