class_name KennyModel
extends Node3D
## Adapts the supplied Kenny Omega model to the game's wrestler rig.
##
## The supplied asset is a STATUE, and an unusual one: a photogrammetry scan of a
## physical action figure, delivered as a binary FBX inside two nested zips with
## a 4096-square diffuse and normal map beside it. Measured before anything was
## written: no armature, no vertex groups, no animations; ONE mesh of 285,913
## vertices and 571,794 triangles; and 0.176 units tall, because the thing that
## was scanned is 17.6 cm of plastic rather than a person.
##
## `tools/assets/fbx_to_static_glb.py` converts it (the rigger reads only glTF),
## stands it up the right way -- it is supplied upside down -- drops seven loose
## scan fragments and decimates it to a size the game can carry.
## `tools/assets/rig_static_wrestler.py` then gives it the base rig's own 65-bone
## hierarchy, and `assets/characters/kenny_omega.glb` is that output.
##
## What that leaves this script to do is small, for the same reasons it is small
## for CodyModel:
##
## * The bone NAMES and HIERARCHY are the base rig's exactly, so there is no
##   bone map and `game_bone_name()` is not implemented -- the controller's
##   pass-through fallback is already correct.
## * There is ONE skeleton, so `apply_physique_height()` is not implemented
##   either; the controller's single-skeleton fallback is correct. (Contrast
##   RomanModel, which is rigged on two and must scale both.)
## * There is ONE material, with its base colour and normal map both properly
##   wired in the supplied file. So there is no equivalent of RomanModel's
##   `_fix_materials()` here -- no packed data map in an albedo slot, no
##   untextured material, no alpha card. A photogrammetry scan has exactly one
##   surface and paints everything onto it, which costs fidelity but removes
##   this entire class of defect.
##
## The scan's limitations are worth stating, because they are permanent and no
## amount of adapter code touches them: the face is soft and the hair is a solid
## blob at close range, the lighting of the room it was scanned in is baked into
## the diffuse and will not respond to the arena lights, and the figure's
## pointing hand gesture is frozen into the mesh, so his fingers keep that shape
## in every animation.

## The rig every animation in this project is authored against.
const BASE_RIG := "res://assets/characters/wrestler_base.glb"


func _ready() -> void:
	_install_animations()
	_dress_skin()
	_dress_eyes()
	_dress_hair()
	_dress_gear()


# ---------------------------------------------------------------------------
# The AAA rebuild (tools/blender/kenny_aaa.py): what Godot's glTF import does
# not carry over. Each look is found by its Blender material name.
# ---------------------------------------------------------------------------

const SKIN_MATERIAL := "M_KennySkin"
const SKIN_PORE_TILES := 48.0


## His skin: SkinLook's subsurface, sheen and pores, as Aubrey's.
func _dress_skin() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		var surfaces := _surfaces_named(mi, SKIN_MATERIAL)
		if surfaces.is_empty():
			continue
		SkinLook.with_detail_uv(mi, surfaces)
		for surface: int in surfaces:
			var material := mi.mesh.surface_get_material(surface).duplicate() as BaseMaterial3D
			material.metallic_specular = 0.5
			SkinLook.apply(material)
			material.subsurf_scatter_transmittance_enabled = false
			SkinLook.add_pores(material, SKIN_PORE_TILES)
			mi.set_surface_override_material(surface, material)


const EYE_MATERIAL := "MI_KennyEyes"
const EYE_PARALLAX := 4.0
const CARD_MATERIALS := {"M_KennyBrows": 0.12, "M_KennyLashes": 0.3}


## His eyes (EyeKit, build_eyes.py's KENNY maps) and his brow and lash cards.
func _dress_eyes() -> void:
	EyeKit.dress(self, EYE_MATERIAL, EyeKit.eye_material("kenny", EYE_PARALLAX))
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source and CARD_MATERIALS.has(source.resource_name):
				mi.set_surface_override_material(surface, EyeKit.lash_material(
						source.albedo_texture, Color.WHITE, CARD_MATERIALS[source.resource_name]))


## The curls: strand cards, scissored with alpha-to-coverage (a hundred and
## ninety crossing clumps must not sort against each other) and seen from
## both sides. The cap: its hairline feathered by vertex alpha.
const HAIR_MATERIALS := {"M_KennyHair": 0.4, "M_KennyHairCap": 0.5}
const HAIR_ROUGHNESS := 0.6
const HAIR_SPECULAR := 0.25


func _dress_hair() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not HAIR_MATERIALS.has(source.resource_name):
				continue
			var material := source.duplicate() as BaseMaterial3D
			if source.resource_name == "M_KennyHairCap":
				material.vertex_color_use_as_albedo = true
			material.roughness = HAIR_ROUGHNESS
			material.metallic_specular = HAIR_SPECULAR
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = HAIR_MATERIALS[source.resource_name]
			material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
			material.alpha_antialiasing_edge = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			HairLook.apply(material)
			mi.set_surface_override_material(surface, material)


## His gear: the painted albedo with its roughness and metal map (gold leaf
## is metal; satin, leather and tape are not) and a cloth rim.
const GEAR_MATERIAL := "M_KennyGear"
const GEAR_ORM := "res://assets/characters/kenny_aaa_gear_orm.png"


func _dress_gear() -> void:
	var orm := load(GEAR_ORM) as Texture2D
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		for surface: int in _surfaces_named(mi, GEAR_MATERIAL):
			var material := mi.mesh.surface_get_material(surface).duplicate() as StandardMaterial3D
			if orm:
				material.roughness_texture = orm
				material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
				material.roughness = 1.0
				material.metallic_texture = orm
				material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
				material.metallic = 1.0
			material.rim_enabled = true
			material.rim = 0.3
			material.rim_tint = 0.7
			mi.set_surface_override_material(surface, material)


func _surfaces_named(mi: MeshInstance3D, material_name: String) -> Array:
	var out := []
	if mi.mesh == null:
		return out
	for surface in mi.mesh.get_surface_count():
		var source := mi.mesh.surface_get_material(surface)
		if source and source.resource_name == material_name:
			out.append(surface)
	return out


## Kenny wrestles in his own gear, so the generated trunks must not be painted on.
##
## This is the one method the controller has no safe default for: absent it,
## `_uses_universal_attire()` returns true and `WrestlerAttire.build()` paints
## procedural trunks and boots over a model that already has them -- and here
## they are not merely modelled but scanned into the single body mesh, so there
## is nothing to hide them behind either.
func uses_universal_attire() -> bool:
	return false


## Fills this model's AnimationPlayer with the base rig's clips.
##
## The keys are copied UNCHANGED. Only the node path is rewritten, because this
## model sits under a `Source` node and the base rig's tracks name
## "Armature/Skeleton3D:<bone>" relative to their own root.
##
## No rest-space conversion. This skeleton IS the base rig's -- same bone names,
## same hierarchy, same parent chain -- and differs only in its REST pose, which
## is the supplied model's own pose rather than the base rig's T-pose. In Godot
## an animation track sets a bone's local pose directly, so identical local poses
## down an identical hierarchy produce identical GLOBAL poses. The rest pose does
## not enter into that; what it defines is the BIND pose, which the mesh's skin
## already accounts for, so the vertices deform correctly from the pose they were
## bound in.
##
## Converting instead applies the pose offset a second time, which renders as a
## wrestler whose legs and head are right and whose arms are folded across his
## waist. RomanModel needs the conversion because its skeleton is a genuinely
## foreign rig; this one does not, because it is not.
func _install_animations() -> void:
	var player := $AnimationPlayer as AnimationPlayer
	var skeleton := get_game_skeleton()
	if player == null or skeleton == null:
		push_error("KennyModel: expected an AnimationPlayer and a Skeleton3D")
		return
	var source_root: Node = (load(BASE_RIG) as PackedScene).instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) \
			as AnimationPlayer
	if source_player == null:
		push_error("KennyModel: the base rig has no AnimationPlayer to read")
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
		push_error("KennyModel: no Skeleton3D to rebase animation tracks onto")
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
