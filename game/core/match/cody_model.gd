class_name CodyModel
extends RiggedWrestlerModel
## Cody's identity profile; the shared adapter contains no character identity data.
## Original supplied geometry was rigged onto the common wrestler skeleton.

const HEAD_MATERIAL := "xmaterial_c3d4d9e78b44a79"
const HEAD_BLOND := "res://assets/characters/cody_rhodes_head_blond.png"
const SKIN_MATERIALS := ["xmaterial_495900de7002683", "xmaterial_90b39911eb484a2",
		"xmaterial_90b2b911eb46cd8", "xmaterial_5a329cd32db96c3", HEAD_MATERIAL]
const SKIN_TINT := Color(0.8, 0.68, 0.58)
const SKIN_SPECULAR := 0.3
const PORE_TILES := 48.0
const HEAD_PORE_TILES := 16.0
const HAIR := "res://assets/characters/cody_groom.glb"
const HAIR_STRANDS := "res://assets/characters/cody_hair_strands.png"
const HAIR_CARDS := "res://assets/characters/cody_groom_cards.png"
const HAIR_ROOT := Color(0.50, 0.43, 0.34)
const HAIR_TIP := Color(0.80, 0.74, 0.62)
const HAIR_ROUGHNESS := 0.50
const EYE_MATERIAL := "xmaterial_7d08cd4d239faf3"
const EYE_PARALLAX := 4.0
const EYE_TONE := Color(0.80, 0.79, 0.78)
const EYE_COAT := 0.3
const EYE_COAT_ROUGHNESS := 0.3
const EYE_SPECULAR := 0.25
const EYE_ROUGHNESS := 0.3

func _body_gains() -> Dictionary:
	return BodyBulk.CODY

func _shape_face() -> void:
	pass

func _skin_texture(material_name: String) -> Texture2D:
	if material_name == HEAD_MATERIAL and ResourceLoader.exists(HEAD_BLOND):
		return load(HEAD_BLOND)
	return null

func _skin_tint() -> Color:
	return SKIN_TINT

func _fix_gear() -> void:
	pass

func _eye_tone() -> Color:
	return EYE_TONE

func _eye_prefix() -> String:
	return "cody"

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
	for mi: MeshInstance3D in hair.find_children("Hair*", "MeshInstance3D", true, false):
		var cap := mi.name == "HairCap"
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load(HAIR_STRANDS if cap else HAIR_CARDS)
		mat.albedo_color = HAIR_ROOT.lerp(HAIR_TIP, .6) if cap else HAIR_TIP
		mat.metallic_specular = .25
		mat.roughness = HAIR_ROUGHNESS
		# The highlight as a band across the strands (u runs round the head,
		# the strands along v), not a round spot.
		HairLook.apply(mat)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		# Per-vertex root shading and a clump atlas give depth without closed
		# overlapping scalp shells. Cards use their own non-tiling atlas UVs.
		mat.vertex_color_use_as_albedo = true
		if not cap:
			mat.texture_repeat = false
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.22
			# Alpha to coverage, as Roman's hair cards: with MSAA on
			# (project.godot) the strand edges resolve to partial coverage
			# instead of the hard stair-step a bare scissor cuts.
			mat.alpha_antialiasing_mode = \
					BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
			mat.alpha_antialiasing_edge = mat.alpha_scissor_threshold
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cap \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _shape_body() -> void:
	CodyBodyShape.apply(self)

func _skin_profile() -> Dictionary:
	return {"materials": SKIN_MATERIALS, "head_material": HEAD_MATERIAL,
		"head_roughness": "res://assets/characters/cody_skin_head_roughness.png",
		"body_roughness": "res://assets/characters/skin_body_roughness.png",
		"head_wet": "res://assets/characters/cody_skin_head_wet.png",
		"specular": SKIN_SPECULAR, "pore_tiles": PORE_TILES, "head_pore_tiles": HEAD_PORE_TILES}

func _eye_profile() -> Dictionary:
	return {"prefix": _eye_prefix(), "tone": _eye_tone(), "material": EYE_MATERIAL,
		"parallax": EYE_PARALLAX, "coat": EYE_COAT, "coat_roughness": EYE_COAT_ROUGHNESS,
		"specular": EYE_SPECULAR, "roughness": EYE_ROUGHNESS}

func expression_profile() -> Dictionary:
	return FaceExpression.make_profile([HEAD_MATERIAL, "head_shared_inside_mouth_iw9"], 1.639, -.012)
