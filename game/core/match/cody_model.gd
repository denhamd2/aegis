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


func _ready() -> void:
	_install_animations()


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
