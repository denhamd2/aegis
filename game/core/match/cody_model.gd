class_name CodyModel
extends Node3D
## Adapts the supplied Cody Rhodes model to the game's wrestler rig.
##
## The supplied asset is a STATUE: 14 separate meshes, 74k triangles, no skin, no
## skeleton, no animations -- verified in the glTF itself (no `skins` array, and
## no JOINTS_0/WEIGHTS_0 on any primitive). `tools/assets/rig_static_wrestler.py`
## gives it the base rig's own 65-bone hierarchy, transferring weights from the
## base rig's mannequin, and `assets/characters/cody_rhodes.glb` is that output.
##
## What that leaves this script to do is small, because the rigging step already
## made the bones match:
##
## * The bone NAMES and HIERARCHY are the base rig's exactly, so there is no
##   bone map, and `game_bone_name()` is not implemented -- the controller's
##   pass-through fallback is already correct.
## * There is ONE skeleton, so `apply_physique_height()` is not implemented
##   either; the controller's single-skeleton fallback is correct. (Contrast
##   RomanModel, which is rigged on two and must scale both.)
## * The materials are sound as supplied -- twelve materials, every one with its
##   own base colour, no packed data maps in albedo slots, nothing untextured.
##   The Phase 0 audit reported zero findings against them, so there is no
##   equivalent of RomanModel's `_fix_materials()` here. That is the asset being
##   better, not a repair being skipped.
##
## Two things do need doing, and both are below.

## The rig every animation in this project is authored against.
const BASE_RIG := "res://assets/characters/wrestler_base.glb"


## His look, to the owner's reference photographs (three: a press portrait,
## an in-ring close-up and an entrance shot).
##
## HAIR. The model paints it on the scalp as a short ash-brown crop; the
## references show platinum blond. The re-coloured head texture is built by
## tools/assets/build_cody_textures.py from the supplied one (face, brows,
## tattoo and ears untouched) and swapped in here for the head material.
## Its SHAPE -- longer on top and swept up and back in the photos -- is
## geometry the model does not have: the hair is paint on a skull, so the
## volume is out of reach without new hair cards.
##
## SKIN. Measured medians: the references' cheek (199,142,117) and forehead
## (209,155,132) against the texture's cheek (181,128,109) -- the same hue a
## touch brighter and more golden. A tint on every skin material, and a
## little sheen: a wrestler under arena light is never matte.
const HEAD_MATERIAL := "xmaterial_c3d4d9e78b44a79"
const HEAD_BLOND := "res://assets/characters/cody_rhodes_head_blond.png"
const SKIN_MATERIALS := ["xmaterial_495900de7002683", "xmaterial_90b39911eb484a2",
		"xmaterial_90b2b911eb46cd8", "xmaterial_5a329cd32db96c3", HEAD_MATERIAL]
const SKIN_TINT := Color(1.08, 1.06, 1.0)
const SKIN_ROUGHNESS := 0.5


## His hair as GEOMETRY (tools/blender/cody_hair.py): shells over the
## scalp, tall at the front of the top and swept back, short at the sides.
## Each shell is cut at its own alpha threshold and coloured from a darker
## root (inner) to platinum (outer), so the stack reads as strands.
const HAIR := "res://assets/characters/cody_hair.glb"
const HAIR_STRANDS := "res://assets/characters/cody_hair_strands.png"
const HAIR_ROOT := Color(0.90, 0.83, 0.66)
const HAIR_TIP := Color(0.96, 0.90, 0.74)


func _ready() -> void:
	_install_animations()
	_fix_look()
	_add_hair()


func _add_hair() -> void:
	var skeleton := get_game_skeleton()
	if skeleton == null or not ResourceLoader.exists(HAIR):
		return
	var head := skeleton.find_bone("Head")
	if head < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "HairAttachment"
	skeleton.add_child(attach)
	attach.bone_name = "Head"
	# The hair is authored in skeleton space; hang it on the bone by the
	# inverse of the bone's own rest, so at rest it sits exactly where it
	# was built and from then on rides the head.
	var holder := Node3D.new()
	holder.name = "Hair"
	holder.transform = skeleton.get_bone_global_rest(head).affine_inverse()
	attach.add_child(holder)
	var hair: Node = (load(HAIR) as PackedScene).instantiate()
	holder.add_child(hair)
	var strands: Texture2D = load(HAIR_STRANDS)
	var shells := hair.find_children("HairShell*", "MeshInstance3D", true, false)
	var count := shells.size()
	for mi: MeshInstance3D in shells:
		var k := float(String(mi.name).trim_prefix("HairShell").to_int()) / maxf(count - 1, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = strands
		mat.albedo_color = HAIR_ROOT.lerp(HAIR_TIP, k)
		mat.roughness = 0.34
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		if k > 0.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.15 + 0.45 * k
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _fix_look() -> void:
	for node in find_children("", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not SKIN_MATERIALS.has(source.resource_name):
				continue
			var material := source.duplicate() as BaseMaterial3D
			if source.resource_name == HEAD_MATERIAL and ResourceLoader.exists(HEAD_BLOND):
				material.albedo_texture = load(HEAD_BLOND)
			material.albedo_color = material.albedo_color * SKIN_TINT
			material.roughness = SKIN_ROUGHNESS
			mesh_instance.set_surface_override_material(surface, material)


## Cody wrestles in his own gear, so the generated trunks must not be painted on.
##
## This is the one method the controller has no safe default for: absent it,
## `_uses_universal_attire()` returns true and `WrestlerAttire.build()` paints
## procedural trunks and boots over a model that already has them.
func uses_universal_attire() -> bool:
	return false


## Fills this model's AnimationPlayer with the base rig's clips.
##
## The keys are copied UNCHANGED. Only the node path is rewritten, because this
## model sits under a `Source` node and the base rig's tracks name
## "Armature/Skeleton3D:<bone>" relative to their own root.
##
## No rest-space conversion, and that is worth explaining because it is the
## opposite of what RomanModel needs and the reasoning is easy to get backwards.
## This skeleton IS the base rig's -- same bone names, same hierarchy, same
## parent chain -- and differs only in its REST pose, which is the supplied
## model's A-pose rather than the base rig's T-pose. In Godot an animation track
## sets a bone's local pose directly, so identical local poses down an identical
## hierarchy produce identical GLOBAL poses: the arm goes exactly where the base
## rig's arm goes. The rest pose does not enter into that. What it does define is
## the BIND pose, which the mesh's skin already accounts for, so the vertices
## deform correctly from the A-pose they were bound in.
##
## Running the keys through a rest-space conversion instead applies the A-pose
## offset a second time. Rendered, that is a wrestler standing upright with his
## legs and head correct and his arms folded across his waist -- which reads as
## a subtly broken retarget and is in fact a retarget that should not be there.
## RomanModel needs one because its skeleton is a genuinely foreign rig whose
## bones are named and rolled differently; this one does not, because it is not.
func _install_animations() -> void:
	var player := $AnimationPlayer as AnimationPlayer
	var skeleton := get_game_skeleton()
	if player == null or skeleton == null:
		push_error("CodyModel: expected an AnimationPlayer and a Skeleton3D")
		return
	var source_root: Node = (load(BASE_RIG) as PackedScene).instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) \
			as AnimationPlayer
	if source_player == null:
		push_error("CodyModel: the base rig has no AnimationPlayer to read")
		source_root.free()
		return
	player.add_animation_library("",
			adapt_animation_library(source_player.get_animation_library("")))
	source_root.free()


## Rebases a library authored against the base rig onto this model's node paths.
##
## `WrestlerController` calls this for PAIRED_POSES and STRIKE_CLIPS, whose
## tracks are also written as "Armature/Skeleton3D:<bone>" and would otherwise
## resolve to nothing here -- silently, leaving the wrestler inert through every
## grapple and strike rather than erroring.
##
## `source_skeleton` is accepted and ignored: the controller passes one argument
## and RomanModel's signature takes two, and matching the shape keeps the
## duck-typed call site identical for both models.
func adapt_animation_library(source: AnimationLibrary,
		_source_skeleton: Skeleton3D = null) -> AnimationLibrary:
	var skeleton := get_game_skeleton()
	if skeleton == null:
		push_error("CodyModel: no Skeleton3D to rebase animation tracks onto")
		return source
	var skeleton_path := get_path_to(skeleton)
	var target := AnimationLibrary.new()
	for name in source.get_animation_list():
		var source_animation: Animation = source.get_animation(name)
		var animation: Animation = source_animation.duplicate(true)
		for track in animation.get_track_count():
			var bone := String(animation.track_get_path(track)
					.get_concatenated_subnames())
			# Leave any non-bone track alone rather than guessing at it.
			if bone == "":
				continue
			animation.track_set_path(track,
					NodePath("%s:%s" % [skeleton_path, bone]))
		target.add_animation(name, animation)
	return target


func get_game_skeleton() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D
