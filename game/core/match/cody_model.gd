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
## Darker and warmer since the owner's 2K26 Cody vs Roman match: there his
## skin is a tan that sits well below the mat -- skin luminance 0.22-0.24
## against ours at 0.34 with the old brightening tint (1.08, 1.06, 1.0) --
## gauntlet/refs/cody_roman_2k26.md, "In-ring match lighting".
const SKIN_TINT := Color(0.8, 0.68, 0.58)
## And less of a mirror: a dielectric's default 0.5 specular threw the truss
## keys back off his back as a white patch (p95 0.73 against 2K26's 0.52).
const SKIN_SPECULAR := 0.3
## Pore tiles across one UV square of his skin atlases (SkinLook.add_pores):
## his torso-and-arms atlas spans about 1.2 m of skin, so ~2.5 cm a tile.
const PORE_TILES := 48.0
## His head has a separate, much smaller atlas. Body density here reduced
## the pores below a pixel even in close-ups; keep facial detail at its scale.
const HEAD_PORE_TILES := 16.0


## Swept clump cards over a scalp cap (tools/blender/cody_groom.py). Distinct
## tapered tips break the outline; short side growth stays against the head.
const HAIR := "res://assets/characters/cody_groom.glb"
const HAIR_STRANDS := "res://assets/characters/cody_hair_strands.png"
const HAIR_CARDS := "res://assets/characters/cody_groom_cards.png"
const HAIR_ROOT := Color(0.50, 0.43, 0.34)
const HAIR_TIP := Color(0.80, 0.74, 0.62)
const HAIR_ROUGHNESS := 0.50


func _ready() -> void:
	# Review probes can assemble the material adapter after entering the tree
	# without copying the complete gameplay animation library.
	if get_meta("material_study", false):
		return
	# His arms, shoulders and chest to 2K26's build (BodyBulk), first, so
	# everything after works on the finished mesh.
	# The mirror seam down his centre line first, so it shades and inflates
	# as one surface (BodyBulk.mend_flipped_seams).
	BodyBulk.mend_flipped_seams(self)
	BodyBulk.apply(self, get_game_skeleton(), _body_gains())
	# Before the animations: they add the helpers' tracks if the bones exist.
	HipHelpers.install(get_game_skeleton())
	# The same fix at the shoulders: an arm raised overhead (the win, the
	# title) caved the top of the shoulder in and ballooned the deltoid.
	ShoulderHelpers.install(get_game_skeleton())
	_install_animations()
	_fix_look()
	_fix_gear()
	_fix_eyes()
	_add_hair()


## The hooks KennyModel overrides: Kenny is built on this model (the owner,
## 27 Oct: "use Cody's body for Kenny"), with his own skin, gear, eyes and
## hair swapped in here. Each returns what Cody wears.

## BodyBulk gains for this man's build.
func _body_gains() -> Dictionary:
	return BodyBulk.CODY


## The albedo to put on skin material `material_name` in place of the
## supplied one, or null to keep it.
func _skin_texture(material_name: String) -> Texture2D:
	if material_name == HEAD_MATERIAL and ResourceLoader.exists(HEAD_BLOND):
		return load(HEAD_BLOND)
	return null


func _skin_tint() -> Color:
	return SKIN_TINT


## His gear as supplied: Cody's own.
func _fix_gear() -> void:
	pass


func _eye_tone() -> Color:
	return EYE_TONE


## Whose eye maps (tools/assets/build_eyes.py) go on these eyeballs.
func _eye_prefix() -> String:
	return "cody"


## His eyes (character_aaa_plan.md S1): the eyeball's photographic texture,
## kept but corrected -- his iris tinted to his blue, the bloodshot sclera
## calmed -- with the head kit's lid occlusion, roughness, iris depth and
## wet film (tools/assets/build_eyes.py, EyeKit). Each eyeball is a 13.1 mm
## sphere on Eye_L / Eye_R with a flat front projection, so the painted iris
## turns with EyeAim. (The 36-vertex shells round them are their backs and
## take the same material unseen.)
const EYE_MATERIAL := "xmaterial_7d08cd4d239faf3"
## Iris depth as parallax: the same hint of it as Roman's.
const EYE_PARALLAX := 4.0


## The owner's 2K26 comparison: his eyes read as a startled, glowing blue
## stare -- a bright white sclera all round a saturated iris. Real eyes sit
## darker than paper white in shadowed sockets; this takes the whole eye down
## to EYE_TONE, the sclera to a soft off-white and the blue with it.
const EYE_TONE := Color(0.80, 0.79, 0.78)
## The wet film, softer than the kit's glass (1.0 at 0.03): on his eyes that
## mirrored every truss key as its own hard white point, two per eye with a
## glow halo round them -- the owner's "face needs improving" close-up read
## as a glassy stare. A thin, rougher coat and a dielectric's lower
## reflectance: one small catchlight, under the glow threshold.
const EYE_COAT := 0.3
const EYE_COAT_ROUGHNESS := 0.3
const EYE_SPECULAR := 0.25
## And the cornea is not mirror-smooth: the kit's roughness map takes it
## to ~0, which turns each truss light into a point over the bloom
## threshold however low the reflectance. One even, slightly soft surface.
const EYE_ROUGHNESS := 0.3


func _fix_eyes() -> void:
	var eye := EyeKit.eye_material(_eye_prefix(), EYE_PARALLAX)
	eye.albedo_color = _eye_tone()
	eye.clearcoat = EYE_COAT
	eye.clearcoat_roughness = EYE_COAT_ROUGHNESS
	eye.metallic_specular = EYE_SPECULAR
	eye.roughness_texture = null
	eye.roughness = EYE_ROUGHNESS
	EyeKit.dress(self, EYE_MATERIAL, eye)


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


func _fix_look() -> void:
	var skin: Array[BaseMaterial3D] = []
	for node in find_children("", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		# A UV2 on the skin surfaces for the pore layer (SkinLook.add_pores).
		var skin_surfaces := []
		for surface in mesh_instance.mesh.get_surface_count():
			var m := mesh_instance.mesh.surface_get_material(surface)
			if m and SKIN_MATERIALS.has(m.resource_name):
				skin_surfaces.append(surface)
		SkinLook.with_detail_uv(mesh_instance, skin_surfaces)
		for surface in mesh_instance.mesh.get_surface_count():
			var source := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not SKIN_MATERIALS.has(source.resource_name):
				continue
			var material := source.duplicate() as BaseMaterial3D
			var albedo := _skin_texture(source.resource_name)
			if albedo:
				material.albedo_texture = albedo
			material.albedo_color = material.albedo_color * _skin_tint()
			material.roughness = 1.0
			material.roughness_texture = load("res://assets/characters/cody_skin_head_roughness.png"
					if source.resource_name == HEAD_MATERIAL else "res://assets/characters/skin_body_roughness.png")
			material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
			material.metallic_specular = SKIN_SPECULAR
			SkinLook.apply(material, source.resource_name == HEAD_MATERIAL)
			if source.resource_name == HEAD_MATERIAL:
				material.clearcoat_texture = load("res://assets/characters/cody_skin_head_wet.png")
			SkinLook.add_pores(material, HEAD_PORE_TILES if source.resource_name == HEAD_MATERIAL else PORE_TILES)
			skin.append(material)
			mesh_instance.set_surface_override_material(surface, material)
	# For Sweat (WrestlerController attaches it).
	set_meta("skin_materials", skin)


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
		HipHelpers.add_tracks(animation, skeleton, skeleton_path)
		ShoulderHelpers.add_tracks(animation, skeleton, skeleton_path)
		target.add_animation(name, animation)
	return target


func get_game_skeleton() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D


## His eyes on whatever `look_target` returns (EyeAim). The eye bones are
## added to the .glb by tools/assets/rig_cody_eyes.py, each at its eyeball's
## centre. The line of sight is EyeAim's default, his face's forward at rest.
## Not the bone's own +Y, though that is the axis it points along in Blender:
## after the glTF round trip the bone's +Y measured 155 degrees off where he
## was looking. Idempotent; a no-op on a model without them.
const EYE_BONES := ["Eye_L", "Eye_R"]


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
