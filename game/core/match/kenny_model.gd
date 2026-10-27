class_name KennyModel
extends CodyModel
## Kenny Omega, built on Cody's model.
##
## The owner, 27 Oct: "Kenny's body isn't good. I'm thinking it would make
## sense to use Cody's body for Kenny and adjust it to Kenny, e.g. skin shade,
## no Cody tattoos" -- and of the face, "much closer to the reference in terms
## of detail and texture". Cody's is the project's best-finished body: rigged
## on the base rig's own 65 bones, gated against every clip, with 2048 skin
## atlases carrying real pores. Its tights and tall boots are Kenny's
## silhouette too, so his gear is a repaint, not new geometry.
##
## So this is CodyModel with Kenny's look swapped in at load (the hooks
## CodyModel exposes for it): the same mesh, rig, animations, helpers and
## adapter. What differs:
##
## * SKIN. Every skin atlas is Kenny's (tools/assets/build_kenny_textures.py):
##   retinted to his pinker, fairer tone, Cody's three tattoos gone, and on
##   the head his own face -- the owner's sheet's front head shot projected
##   onto these UVs (tools/blender/kenny_face_projection.py) over Cody's pore
##   detail, with his ginger-blond beard.
## * GEAR. White-and-gold tights, black-and-gold kneepads and boots, his
##   wrist tape: Cody's gear atlases repainted by the same script.
## * BUILD. Leaner than Cody's (BodyBulk.KENNY).
## * EYES. Cody's eyeballs with a paler grey-blue iris (the sheet's eye
##   close-up; kenny_eye_*.png from tools/assets/build_eyes.py).
## * HAIR. His shoulder-length dirty-blond curls (tools/blender/kenny_curls.py)
##   in place of Cody's short groom.

const CHAR := "res://assets/characters/"
## Cody's skin material -> Kenny's atlas.
const SKIN_TEXTURES := {
	"xmaterial_c3d4d9e78b44a79": CHAR + "kenny_head.png",
	"xmaterial_495900de7002683": CHAR + "kenny_body_abdomen.png",
	"xmaterial_90b39911eb484a2": CHAR + "kenny_body_arm_r.png",
	"xmaterial_90b2b911eb46cd8": CHAR + "kenny_body_arm_l.png",
	"xmaterial_5a329cd32db96c3": CHAR + "kenny_body_chest.png",
}
## Cody's gear material -> Kenny's atlas.
const GEAR_TEXTURES := {
	"xmaterial_e531cd813705b95": CHAR + "kenny_gear_tights.png",
	"xmaterial_c7ae1bc9f4b14": CHAR + "kenny_gear_belt.png",
	"xmaterial_6d1e7e57b971093": CHAR + "kenny_gear_boot_r.png",
	"xmaterial_6d205e57b97438d": CHAR + "kenny_gear_boot_l.png",
	"xmaterial_f003af958238385": CHAR + "kenny_gear_wrist.png",
}
## Fairer than Cody's arena tan (his SKIN_TINT, 0.8/0.68/0.58): the sheet's
## Kenny is pale and flushes red under the lights -- the lights' red, not the
## albedo's (build_kenny_textures.py SKIN_GAIN). But not much brighter than
## Cody: the entrance's stage spots are set for Cody's skin, and at 0.95/0.90/
## 0.86 they took Kenny's chest to (250,245,233) on the stage lip, clipped
## white, where Cody's sits well inside the range. Fairer in hue, close to
## Cody's in level.
const KENNY_SKIN_TINT := Color(0.80, 0.72, 0.66)
## Cody's level, a shade warmer -- the sheet's white of the eye is pink-white
## under his flushed lids, not grey: the colour is in the maps now (build_eyes.py,
## a grey iris). The first pass set this bluer and brighter than Cody's
## (0.86, 0.88, 0.92) on top of a periwinkle iris, and the owner saw the eyes
## glow, the wrong colour.
const KENNY_EYE_TONE := Color(0.82, 0.78, 0.76)

const CURLS := CHAR + "kenny_curls.glb"
const CURL_CARDS := CHAR + "kenny_curl_cards.png"
## The colour is in the curls' vertex colours (kenny_curls.py: dirty blond at
## the root to gold at the tips, per ringlet lighter or darker), so the
## material is white.
const CURL_ROUGHNESS := 0.55
const CAP_SPECULAR := 0.08
const CAP_ROUGHNESS := 0.9


func _body_gains() -> Dictionary:
	return BodyBulk.KENNY


func _skin_texture(material_name: String) -> Texture2D:
	var path: String = SKIN_TEXTURES.get(material_name, "")
	return load(path) if path != "" and ResourceLoader.exists(path) else null


## Cody's head toward Kenny's (KennyFaceShape): hooded eyes under a level
## brow, fuller cheeks, a broader bridge.
func _shape_face() -> void:
	KennyFaceShape.apply(self)


func _skin_tint() -> Color:
	return KENNY_SKIN_TINT


func _eye_tone() -> Color:
	return KENNY_EYE_TONE


func _eye_prefix() -> String:
	return "kenny"


func _fix_gear() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not GEAR_TEXTURES.has(source.resource_name):
				continue
			var path: String = GEAR_TEXTURES[source.resource_name]
			if not ResourceLoader.exists(path):
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.albedo_texture = load(path)
			mi.set_surface_override_material(surface, material)


func _add_hair() -> void:
	var skeleton := get_game_skeleton()
	if skeleton == null or not ResourceLoader.exists(CURLS):
		return
	var curls: Node = (load(CURLS) as PackedScene).instantiate()
	# The curls are skinned to this skeleton's own bones (head, neck and upper
	# back by height), so the lengths follow the shoulders instead of swinging
	# through them: they go under the skeleton, not on a bone attachment.
	for mi: MeshInstance3D in curls.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mi.duplicate() as MeshInstance3D
		skeleton.add_child(mesh_instance)
		mesh_instance.skeleton = NodePath("..")
		mesh_instance.material_override = _curl_material(mi.name == "CurlCap")
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON \
				if mi.name == "CurlCap" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curls.free()


func _curl_material(cap: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(CURL_CARDS)
	mat.vertex_color_use_as_albedo = true
	if cap:
		# The shadowed roots under the hair: matte. With HairLook's stretched
		# highlight the overhead key drew a pale band across his hairline that
		# read as a painted helmet (kenny pass 4).
		mat.metallic_specular = CAP_SPECULAR
		mat.roughness = CAP_ROUGHNESS
	else:
		mat.metallic_specular = 0.25
		mat.roughness = CURL_ROUGHNESS
		HairLook.apply(mat)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not cap:
		mat.texture_repeat = false
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.alpha_scissor_threshold = 0.3
		mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
		mat.alpha_antialiasing_edge = mat.alpha_scissor_threshold
	return mat
