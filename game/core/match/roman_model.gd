extends Node3D
## Adapts the user-supplied Roman model to the game's universal wrestler rig.
## The source has no animations, so the base rig's animation library is reused
## after its tracks are remapped to Roman's named body bones.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"

const BONE_MAP := {
	"pelvis": "J_Hips",
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

## Materials the supplied .glb ships with no base colour at all, and the
## colour each should have.
##
## Seven of the model's sixteen materials carry only a normal map, so they
## render flat white -- including `Material.001`, which is the *face*. The
## missing albedo is not a lost file: the .glb embeds fourteen images, the
## repo carries the same fourteen as loose PNGs, and no material references a
## fifteenth. For the head the colour does exist and was simply not wired up
## (`body_color` already carries the head UVs -- `Material.009`, the eye
## caruncle, samples it), so that one is a reconnection. For the clothing and
## the wrist wear no colour texture exists anywhere in the asset, so those get
## a flat tint chosen to match Roman's actual ring gear rather than an
## invented texture. Both cases are called out per entry below.
const ALBEDO_FIXES := {
	# Face. body_color.png is a 4096x2048 atlas holding skin, the tribal
	# sleeve, the trunks and the mouth interior; the head UVs are in it.
	"Material.001": {"texture": "head_color", "color": Color.WHITE},
	# Ring gear. No colour texture for these exists in the asset -- only
	# tops_nrm/bottoms_nrm. Black matches the gear Roman actually wrestles in,
	# and the normal maps still carry the fabric detail.
	"Material.003": {"color": Color(0.055, 0.055, 0.062)}, # tops
	"Material.004": {"color": Color(0.045, 0.045, 0.052)}, # bottoms
	# Wrist tape and the arm accessory: same situation, only normal maps.
	"Material.006": {"color": Color(0.82, 0.80, 0.76)}, # l_wrist
	"Material.007": {"color": Color(0.82, 0.80, 0.76)}, # r_wrist
	"Material.012": {"color": Color(0.10, 0.10, 0.11)}, # r_a_acce
	# Eye and lash. Small, but white sclera and a black lash beat flat white.
	"Material.013": {"color": Color(0.085, 0.060, 0.045)},
	"Material.016": {"color": Color(0.04, 0.04, 0.04)},
}

## Hair and beard cards, and the mask texture each should use.
##
## The export wired these meshes' *packed data* maps in as base colour.
## hair_rai, hair_rai_4 and combinations_rai are not albedo: R and B carry
## identical data and the green channel is the strand opacity mask, so
## R=B high against low G renders as solid magenta -- which is exactly what
## the hair and beard looked like. tools/assets/build_roman_hair_alpha.py
## rebuilds each as white RGB plus that green channel as alpha; the colour
## then comes from the tint below, since the asset carries no hair colour.
const HAIR_FIXES := {
	"Material.017": "hair_4_alpha",
	"Material.018": "hair_alpha",
	"Material.019": "hair_4_alpha",
	"Material.020": "hair_alpha",
	"beard": "beard_alpha",
}

## Meshes hidden outright rather than materialled.
##
## The T-shirt goes because Roman wrestles bare-chested: the body mesh
## underneath is fully textured (body_color carries the torso, the tribal
## sleeve and the trunks), so removing the shirt reveals finished art rather
## than a hole. It also removes the worst of the clothing interpenetration --
## body and shirt are separate meshes with their own skin weights, and the
## torso was poking through the tee wherever the two disagreed.
##
## The model also ships a second, complete set of hair cards -- the source's
## "entrance" variants (M_Hair_Entrance and S_Hair_Entrance, which arrive as
## hair_ALPHA_skinned_002 and lambert1_skinned_001). Both sets were visible
## and occupy nearly the same space, so they z-fought: the two wrestlers use
## one model but resolved that fight differently, and one of them came out
## looking bald from the crown while the other had a full head of hair.
## Keeping one set of each pair fixes that and halves the hair overdraw.
const HIDDEN_MESHES := [
	"tops_skinned",
	"hair_ALPHA_skinned_002",
	"lambert1_skinned_001",
]

## Materials nudged outward along their normals to stop the body mesh poking
## through them. The body and the clothing are separate meshes with their own
## skin weights, so wherever the two disagree under animation the skin wins
## and erupts through the fabric -- which is what the tan blotches on the
## thighs and shins were. A fraction of a centimetre of grow is the cheap fix
## and is invisible at any camera distance the game uses; the alternative is
## re-weighting someone else's mesh.
const GROW_FIXES := {
	"Material.004": 0.006, # bottoms
	"Material.005": 0.004, # shoes
}

const TEXTURE_DIR := "res://assets/characters/roman_reigns_%s.png"
## Roman's hair and beard are near-black; kept slightly warm so they don't
## read as a flat silhouette under the arena's key light.
const HAIR_COLOR := Color(0.075, 0.062, 0.055)
## Alpha below this is cut away. Hair cards need a scissor rather than
## blending: sorted transparency on overlapping strands produces halos.
##
## Low, and that is the fix for the wrestler who kept going bald in wide
## shots. Every mip level averages a mostly-transparent mask further toward
## zero, so a threshold that looks right in close-up rejects the whole card a
## few metres out -- the near wrestler kept his hair and the far one lost it,
## from one model. Alpha-to-coverage is declared below and would normally
## soften exactly this, but it needs MSAA to do anything and this project
## renders without it, so the threshold has to carry it alone.
const HAIR_ALPHA_SCISSOR := 0.14
## The beard and brows are cut at their own, much lower threshold.
##
## They share one mesh and one mask (combinations_rai) whose strands are far
## sparser than the scalp's -- only 9.6% of its texels are opaque against the
## hair's 32%. At the scalp's 0.35 the sparse ends of the beard were cut away
## and it survived only where it was densest: a patch floating on the cheek
## with the jawline bare beneath it, and no eyebrows at all, because the brow
## cards live in the same sparse mask.
const BEARD_ALPHA_SCISSOR := 0.16
## Multiplier on the distance at which the hair meshes drop a LOD level.
## Large on purpose: a head of hair is a few thousand triangles on two
## characters, and losing it entirely is a far worse trade than drawing it.
const HAIR_LOD_BIAS := 16.0

func _ready() -> void:
	var body: Skeleton3D = _find_body_skeleton()
	if not body:
		push_error("Roman model has no body Skeleton3D")
		return
	_fix_materials()
	_copy_base_animation_library()

## Repairs the materials the export left unusable. Applied as surface
## overrides rather than by editing the .glb: the source asset stays exactly
## as supplied, and every fix is visible here as code with its reason next to
## it. Safe to call once at _ready -- it only touches the materials it names.
func _fix_materials() -> void:
	for node in find_children("", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance or not mesh_instance.mesh:
			continue
		if HIDDEN_MESHES.has(mesh_instance.name):
			mesh_instance.visible = false
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface)
			if source == null:
				continue
			var key := source.resource_name
			if not (ALBEDO_FIXES.has(key) or HAIR_FIXES.has(key)
					or GROW_FIXES.has(key)):
				continue
			var material := source.duplicate() as BaseMaterial3D
			if material == null:
				continue
			if GROW_FIXES.has(key):
				material.grow = true
				material.grow_amount = GROW_FIXES[key]
			if HAIR_FIXES.has(key):
				# Hold the hair at full detail well past its normal LOD range.
				# roman_reigns.glb is imported with generate_lods on, and a
				# decimated hair card is not a smaller hair card -- it is a
				# card whose alpha mask has been averaged toward transparent,
				# so the scissor takes the whole thing. That is why the two
				# wrestlers, one model, looked like different men: the near
				# one kept a full head of hair at LOD0 while the far one went
				# bald the moment it dropped a level. Alpha-to-coverage helps
				# the mip chain but cannot help a mesh that is no longer there.
				mesh_instance.lod_bias = HAIR_LOD_BIAS
				material.albedo_texture = _texture(HAIR_FIXES[key])
				material.albedo_color = HAIR_COLOR
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				var scissor: float = BEARD_ALPHA_SCISSOR if key == "beard" \
					else HAIR_ALPHA_SCISSOR
				material.alpha_scissor_threshold = scissor
				# Hair cards are single-sided geometry seen from both faces.
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				# Alpha-to-coverage, because a plain scissor test loses hair
				# with distance: the mip chain averages a mostly-transparent
				# mask down toward zero, more of it falls under the threshold
				# every mip level, and the crown thins out until the wrestler
				# reads as bald from the broadcast camera while looking fine
				# in close-up. That is what made the two wrestlers -- one
				# model, two distances -- look like different men.
				material.alpha_antialiasing_mode = \
					BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
				material.alpha_antialiasing_edge = scissor
			elif ALBEDO_FIXES.has(key):
				var fix: Dictionary = ALBEDO_FIXES[key]
				if fix.has("texture"):
					material.albedo_texture = _texture(fix["texture"])
				material.albedo_color = fix["color"]
			mesh_instance.set_surface_override_material(surface, material)

func _texture(suffix: String) -> Texture2D:
	return load(TEXTURE_DIR % suffix) as Texture2D

func get_game_skeleton() -> Skeleton3D:
	return _find_body_skeleton()

func game_bone_name(game_bone: String) -> String:
	return BONE_MAP.get(game_bone, game_bone)

func uses_universal_attire() -> bool:
	return false

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
			source_player.get_animation_library(""),
			_source_skeleton(source_root)))
	source_root.free()

## The base rig's own skeleton, needed for its bone rest poses -- see
## adapt_animation_library().
func _source_skeleton(source_root: Node) -> Skeleton3D:
	for candidate in source_root.find_children("", "Skeleton3D", true, false):
		var skeleton := candidate as Skeleton3D
		if skeleton and skeleton.find_bone("pelvis") >= 0:
			return skeleton
	return null

## Retargets the base rig's animation library onto Roman's bones.
##
## `source_skeleton` is the base rig's own Skeleton3D, and it is what makes
## this a retarget rather than a rename. A bone track stores a rotation in the
## bone's *local* space, which is only meaningful relative to that skeleton's
## rest pose -- and these two rigs do not share one. Copying keys across
## verbatim (which this did) hands Roman's bones rotations authored against a
## different set of rest orientations, and the result was not subtly off: he
## played every animation upside down, head at 0.32m and feet at 1.73m, with
## the mesh torn apart. Measured by tools/probe/roman_diag.tscn; the model
## itself stands up correctly with nothing driving it
## (tools/probe/roman_bare.tscn), which is what localised the fault here.
##
## The fix is the standard rest-relative conversion: take the key's offset
## from the *source* rest orientation, and re-apply that offset to the
## *target* rest orientation.
##
##     delta  = src_rest^-1 * key
##     output = tgt_rest * delta
##
## A key that matches the source's rest pose then lands exactly on Roman's
## rest pose instead of somewhere 180 degrees away from it.
##
## Passing null for `source_skeleton` keeps the old verbatim copy. Nothing
## should rely on that -- it exists so the function stays callable without a
## rig to compare against.
func adapt_animation_library(source: AnimationLibrary,
		source_skeleton: Skeleton3D = null) -> AnimationLibrary:
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
			var track_type := source_animation.track_get_type(track)
			for skeleton in skeletons:
				var target_bone: String = BONE_MAP[bone]
				var output_track := animation.add_track(track_type)
				animation.track_set_path(output_track, NodePath("%s:%s" % [
						get_path_to(skeleton), target_bone]))
				animation.track_set_interpolation_type(output_track,
						source_animation.track_get_interpolation_type(track))
				var rest := _rest_pair(source_skeleton, bone, skeleton, target_bone)
				for key in source_animation.track_get_key_count(track):
					animation.track_insert_key(output_track,
							source_animation.track_get_key_time(track, key),
							_retarget_key(track_type,
									source_animation.track_get_key_value(track, key),
									rest),
							source_animation.track_get_key_transition(track, key))
		target.add_animation(name, animation)
	return target

## The two rest transforms a key has to be converted between, or an empty
## dictionary when either bone is missing (then the key passes through).
func _rest_pair(source_skeleton: Skeleton3D, source_bone: String,
		target_skeleton: Skeleton3D, target_bone: String) -> Dictionary:
	if source_skeleton == null:
		return {}
	var source_index := source_skeleton.find_bone(source_bone)
	var target_index := target_skeleton.find_bone(target_bone)
	if source_index < 0 or target_index < 0:
		return {}
	# Parent global rest rotations, defaulting to identity at a root bone.
	# These are what let a key be rotated *into* the target's frame rather
	# than merely rebased onto its rest -- see _retarget_key().
	var source_parent := Quaternion.IDENTITY
	var source_parent_index := source_skeleton.get_bone_parent(source_index)
	if source_parent_index >= 0:
		source_parent = source_skeleton.get_bone_global_rest(
				source_parent_index).basis.get_rotation_quaternion()
	var target_parent := Quaternion.IDENTITY
	var target_parent_index := target_skeleton.get_bone_parent(target_index)
	if target_parent_index >= 0:
		target_parent = target_skeleton.get_bone_global_rest(
				target_parent_index).basis.get_rotation_quaternion()
	return {
		"source": source_skeleton.get_bone_rest(source_index),
		"target": target_skeleton.get_bone_rest(target_index),
		"source_parent": source_parent,
		"target_parent": target_parent,
	}

func _retarget_key(track_type: int, value: Variant, rest: Dictionary) -> Variant:
	if rest.is_empty():
		return value
	var source_rest: Transform3D = rest["source"]
	var target_rest: Transform3D = rest["target"]
	var source_parent: Quaternion = rest["source_parent"]
	var target_parent: Quaternion = rest["target_parent"]
	match track_type:
		Animation.TYPE_ROTATION_3D:
			var source_basis := source_rest.basis.get_rotation_quaternion()
			var target_basis := target_rest.basis.get_rotation_quaternion()
			# Rebasing a key onto the target's rest -- target * source^-1 * key
			# -- fixes a difference in rest *orientation* but not one in bone
			# *roll*, because it never leaves local space: a rotation about
			# the source bone's own axis stays about that axis, whatever the
			# target's axis happens to be. That is why the gross inversion
			# went away while the arms stayed folded across the face.
			#
			# So take the key's offset from the source's rest, carry it out to
			# world space through the source parent's global rest, back into
			# the target's local space through the target parent's, and only
			# then apply it to the target's rest. Now a bend is a bend about
			# the same world axis on both rigs regardless of how either
			# skeleton names or rolls that bone.
			# The delta is taken in the *parent's* frame, not the bone's own.
			# A bone's global orientation is parent_global * local, so its
			# offset from rest in global terms is
			#     P * (key * rest^-1) * P^-1
			# -- key post-multiplied by the inverse rest, not pre-multiplied.
			# Pre-multiplying (rest^-1 * key) measures the offset in the
			# bone's own rotating frame, which conjugating by P then carries
			# to the wrong place: it straightened the legs, whose rest axes
			# happen to agree between the rigs, and left the arms folded up
			# over the head, whose do not.
			var delta := (value as Quaternion) * source_basis.inverse()
			var world := source_parent * delta * source_parent.inverse()
			var local := target_parent.inverse() * world * target_parent
			return (local * target_basis).normalized()
		Animation.TYPE_POSITION_3D:
			# Position tracks are the translation part of the same pose, so
			# they get the same treatment: the offset the key makes from the
			# source's rest position, rotated into the target's frame and
			# scaled by the two bones' rest lengths, then applied to the
			# target's rest position. Without the scale a taller rig inherits
			# a shorter one's stride and the feet slide.
			var offset := (value as Vector3) - source_rest.origin
			var rotation := target_rest.basis.get_rotation_quaternion() \
					* source_rest.basis.get_rotation_quaternion().inverse()
			var source_length := source_rest.origin.length()
			var scale := 1.0
			if source_length > 0.0001:
				scale = target_rest.origin.length() / source_length
			return target_rest.origin + (rotation * offset) * scale
		_:
			return value