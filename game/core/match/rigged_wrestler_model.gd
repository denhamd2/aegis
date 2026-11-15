class_name RiggedWrestlerModel
extends Node3D
## Shared base-rig adaptation. Identity resources and tuning belong to subclasses.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"
const EYE_BONES := ["Eye_L", "Eye_R"]

func _ready() -> void:
	if get_meta("material_study", false): return
	BodyBulk.mend_flipped_seams(self)
	BodyBulk.apply(self, get_game_skeleton(), _body_gains())
	_shape_face()
	_shape_body()
	HipHelpers.install(get_game_skeleton())
	ShoulderHelpers.install(get_game_skeleton())
	_install_animations()
	_fix_look()
	_fix_gear()
	_fix_eyes()
	_add_hair()

func _body_gains() -> Dictionary:
	return {}

func _shape_face() -> void:
	pass

func _shape_body() -> void:
	pass

func _skin_profile() -> Dictionary:
	return {}

func _eye_profile() -> Dictionary:
	return {}

func _skin_texture(_material_name: String) -> Texture2D:
	return null

func _skin_tint() -> Color:
	return Color.WHITE

func _fix_gear() -> void:
	pass

func _add_hair() -> void:
	pass

func expression_profile() -> Dictionary:
	return {}

func _fix_look() -> void:
	var profile := _skin_profile()
	if profile.is_empty(): return
	var skin: Array[BaseMaterial3D] = []
	var names: Array = profile["materials"]
	var head_name: String = profile["head_material"]
	for node in find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null: continue
		var skin_surfaces := []
		for surface in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(surface)
			if material and names.has(material.resource_name): skin_surfaces.append(surface)
		SkinLook.with_detail_uv(mi, skin_surfaces)
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not names.has(source.resource_name): continue
			var material := source.duplicate() as BaseMaterial3D
			var albedo := _skin_texture(source.resource_name)
			if albedo: material.albedo_texture = albedo
			var is_head := source.resource_name == head_name
			material.albedo_color *= _skin_tint()
			material.roughness = 1.0
			material.roughness_texture = load(profile["head_roughness"] if is_head else profile["body_roughness"])
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.metallic_specular = profile["specular"]
			SkinLook.apply(material, is_head)
			if is_head: material.clearcoat_texture = load(profile["head_wet"])
			SkinLook.add_pores(material, profile["head_pore_tiles"] if is_head else profile["pore_tiles"],
					profile.get("pore_mix", SkinLook.DETAIL_MIX))
			skin.append(material)
			mi.set_surface_override_material(surface, material)
	set_meta("skin_materials", skin)

func _fix_eyes() -> void:
	var profile := _eye_profile()
	if profile.is_empty(): return
	var eye := EyeKit.eye_material(profile["prefix"], profile["parallax"])
	eye.albedo_color = profile["tone"]
	eye.clearcoat = profile["coat"]
	eye.clearcoat_roughness = profile["coat_roughness"]
	eye.metallic_specular = profile["specular"]
	eye.roughness_texture = null
	eye.roughness = profile["roughness"]
	EyeKit.dress(self, profile["material"], eye)

func uses_universal_attire() -> bool:
	return false

func _install_animations() -> void:
	var player := $AnimationPlayer as AnimationPlayer
	var skeleton := get_game_skeleton()
	if player == null or skeleton == null:
		push_error("RiggedWrestlerModel: expected an AnimationPlayer and a Skeleton3D")
		return
	var source_root: Node = (load(BASE_RIG) as PackedScene).instantiate()
	var source_player := source_root.find_child("AnimationPlayer", true, false) \
			as AnimationPlayer
	if source_player == null:
		push_error("RiggedWrestlerModel: the base rig has no AnimationPlayer to read")
		source_root.free()
		return
	player.add_animation_library("",
			adapt_animation_library(source_player.get_animation_library("")))
	source_root.free()

func adapt_animation_library(source: AnimationLibrary,
		_source_skeleton: Skeleton3D = null) -> AnimationLibrary:
	var skeleton := get_game_skeleton()
	if skeleton == null:
		push_error("RiggedWrestlerModel: no Skeleton3D to rebase animation tracks onto")
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
		HipHelpers.add_tracks(animation, skeleton, skeleton_path)
		ShoulderHelpers.add_tracks(animation, skeleton, skeleton_path)
		target.add_animation(name, animation)
	return target

func get_game_skeleton() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D

func aim_eyes(look_target: Callable) -> void:
	var skeleton := get_game_skeleton()
	if skeleton == null or skeleton.find_bone(EYE_BONES[0]) < 0:
		return
	var aim := skeleton.get_node_or_null("EyeAim") as EyeAim
	if aim == null:
		aim = EyeAim.new()
		aim.name = "EyeAim"
		aim.eye_bones = PackedStringArray(EYE_BONES)
		skeleton.add_child(aim)
	aim.look_target = look_target
