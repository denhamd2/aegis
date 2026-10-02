class_name AubreyModel
extends Node3D
## The referee, Aubrey Edwards (assets/characters/aubrey_aaa.glb, built by
## tools/blender/aubrey_aaa.py: a MakeHuman/MPFB body, uniform and head kit on
## the skeleton of her first build, aubrey_edwards.glb, which
## tools/blender/referee_aubrey.py made from Quaternius' CC0 base characters).
##
## She is rigged on the base rig's own skeleton -- the same 65 bone names in
## the same hierarchy -- so, like CodyModel, there is no bone map and no
## retarget: the keys are copied and only the track paths are rebased.
##
## One thing differs from Cody, and it is why the position tracks go. The
## base rig's clips key a POSITION on every bone, not only on the pelvis, and
## those positions are the base rig's proportions: its shoulder sits 4 cm
## further out than hers, its hip 2 cm further. Played as they are, every clip
## would stretch her onto a man's frame -- shoulders pulled wide of the
## shirt, legs spread. So only the rotations are kept, and the pelvis position
## (the one that carries crouches, kneels and the walk's bob), shifted by the
## difference between the two rigs' pelvis rests so her feet stay on the mat.
##
## Presentation only: nothing in a match reads her. RefereeActor drives her.

const BASE_RIG := "res://assets/characters/wrestler_base.glb"
const STRIKES := "res://resources/animations/strike_clips.tres"
## The base rig's pelvis rest, local to its parent `root` bone, which is
## Z-up (wrestler_base.glb, measured): what the pelvis tracks are keyed in.
const BASE_PELVIS_REST := Vector3(0.0, 0.0501, 0.9167)
## She is 1.70 m; the model's body is 1.744 m to the crown (aubrey_aaa.glb,
## measured; the first build's cartoon body was 1.767).
const HEIGHT := 1.70
const KIT_HEIGHT := 1.744


func _ready() -> void:
	var source := get_node_or_null("Source") as Node3D
	if source:
		source.scale = Vector3.ONE * (HEIGHT / KIT_HEIGHT)
	_install_animations()
	_dress_skin()
	_dress_fabric()
	_dress_hair()
	_dress_eyes()
	_add_ponytail_springs()


## Her eyes (character_aaa_plan.md S1): true 11.8 mm eyeballs, front-projected
## at 30 mm per UV unit like Roman's, painted grey-green with a hazel centre
## (tools/assets/build_eyes.py AUBREY_AAA). Her lids, liner and smoky shadow
## are in her skin texture now.
const EYE_MATERIAL := "MI_AubreyEyes"
## Roman's eye projection, so Roman's depth.
const EYE_PARALLAX := 4.0
## Brow and lash cards (MakeHuman's, recoloured in their own textures).
## [material, scissor]: lashes crisp at 0.3; the brows' finer strands
## vanished there, leaving a thin black line, so they cut at 0.12.
const CARD_MATERIALS := {"M_AubreyBrows": 0.12, "M_AubreyLashes": 0.3}


func _dress_eyes() -> void:
	EyeKit.dress(self, EYE_MATERIAL, EyeKit.eye_material("aubrey_aaa", EYE_PARALLAX))
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source and CARD_MATERIALS.has(source.resource_name):
				mi.set_surface_override_material(surface, EyeKit.lash_material(
						source.albedo_texture, Color.WHITE, CARD_MATERIALS[source.resource_name]))


## Her skin (aubrey_aaa_skin.jpg, make-up painted in): light scattering under
## it (SkinLook) and the shared pore tile. The body's UV square spans about
## 1.2 m of her, like Roman's body, so the same tiling -- ~2.5 cm a tile.
const SKIN_MATERIAL := "M_AubreySkin"
const SKIN_PORE_TILES := 48.0


func _dress_skin() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var surfaces := []
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface)
			if source and source.resource_name == SKIN_MATERIAL:
				surfaces.append(surface)
		if surfaces.is_empty():
			continue
		SkinLook.with_detail_uv(mi, surfaces)
		for surface: int in surfaces:
			var material := mi.mesh.surface_get_material(surface).duplicate() as BaseMaterial3D
			material.metallic_specular = 0.5
			SkinLook.apply(material)
			# No red light through thin skin: her lids' edges are that thin,
			# and under the overhead key they glowed as pink rims round her
			# eyes.
			material.subsurf_scatter_transmittance_enabled = false
			SkinLook.add_pores(material, SKIN_PORE_TILES)
			mi.set_surface_override_material(surface, material)



## Her hair (tools/blender/aubrey_aaa.py): the slicked cap and the long
## ponytail share one strand texture; the highlight runs across the strands
## like the wrestlers' (HairLook), and the ragged hairline is a scissor. The
## cap feathers out over its last centimetre by vertex alpha.
const HAIR_MATERIAL := "M_AubreyHair"
## Slicked, not lacquered: at the source's 0.5 roughness and full dielectric
## reflectance the arena's lights came back off the cap as a grey sheen.
const HAIR_ROUGHNESS := 0.7
const HAIR_SPECULAR := 0.15


func _dress_hair() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != HAIR_MATERIAL:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.vertex_color_use_as_albedo = true
			material.roughness = HAIR_ROUGHNESS
			material.metallic_specular = HAIR_SPECULAR
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.35
			# The hairline's feather as coverage, not a hard cut.
			material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
			material.alpha_antialiasing_edge = 0.35
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			HairLook.apply(material)
			mi.set_surface_override_material(surface, material)


## The ponytail swings: its five bones on a spring, heavier and livelier
## than Roman's slicked hair (a curled ponytail bounces), kept off her head,
## neck and upper back.
const PONYTAIL_ROOT := "ponytail_1"
const PONYTAIL_END := "ponytail_5"
const PONYTAIL_STIFFNESS := 1.1
const PONYTAIL_DRAG := 0.4
const PONYTAIL_GRAVITY := 0.6
## [bone, radius, offset in the bone's frame]
## (This rig's bones point up, so +y is up the bone.) Each sphere sits just
## inside her (aubrey_aaa.glb, measured from each centre to the surface
## behind it: skull 7.2 cm, neck 8.2, upper back 7.1). The first build's
## spheres (head 10 cm, back 10 cm) were sized for the cartoon head and stood
## 3 cm proud of the new one, and with the chain's own radius they shoved the
## long ponytail, which lies against her, out sideways.
const PONYTAIL_COLLIDERS := [["Head", 0.067, Vector3(0.0, 0.12, 0.0)],
		["neck_01", 0.06, Vector3.ZERO], ["spine_03", 0.066, Vector3(0.0, 0.08, 0.0)]]


func _add_ponytail_springs() -> void:
	var skeleton := get_game_skeleton()
	if skeleton == null or skeleton.find_bone(PONYTAIL_ROOT) < 0 or skeleton.has_node("Ponytail"):
		return
	var sim := SpringBoneSimulator3D.new()
	sim.name = "Ponytail"
	skeleton.add_child(sim)
	sim.set_setting_count(1)
	sim.set_root_bone_name(0, PONYTAIL_ROOT)
	sim.set_end_bone_name(0, PONYTAIL_END)
	sim.set_extend_end_bone(0, true)
	sim.set_end_bone_length(0, 0.05)
	sim.set_stiffness(0, PONYTAIL_STIFFNESS)
	sim.set_drag(0, PONYTAIL_DRAG)
	sim.set_gravity(0, PONYTAIL_GRAVITY)
	sim.set_radius(0, 0.02)
	sim.set_enable_all_child_collisions(0, true)
	for spec: Array in PONYTAIL_COLLIDERS:
		var bone := skeleton.find_bone(spec[0])
		if bone < 0:
			continue
		var sphere := SpringBoneCollisionSphere3D.new()
		sphere.name = "Collide_" + String(spec[0])
		sphere.radius = spec[1]
		sim.add_child(sphere)
		sphere.set_bone(bone)
		sphere.position_offset = spec[2]


## Cloth, not plastic: woven fabric catches light at grazing angles (the fuzz
## of its fibres), which glTF has no slot for. A rim term stands in for that
## sheen on her shirt, trim and trousers, tinted by the cloth's own colour.
const FABRIC := {"M_RefStripes": 0.35, "M_RefTrim": 0.3, "M_Trousers": 0.4}
const FABRIC_RIM_TINT := 0.7


func _dress_fabric() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or not FABRIC.has(source.resource_name):
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.rim_enabled = true
			material.rim = FABRIC[source.resource_name]
			material.rim_tint = FABRIC_RIM_TINT
			mi.set_surface_override_material(surface, material)


func _install_animations() -> void:
	var player := $AnimationPlayer as AnimationPlayer
	if player == null or get_game_skeleton() == null:
		push_error("AubreyModel: expected an AnimationPlayer and a Skeleton3D")
		return
	var root: Node = (load(BASE_RIG) as PackedScene).instantiate()
	var rig_player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if rig_player:
		player.add_animation_library("", adapt_animation_library(rig_player.get_animation_library("")))
	root.free()
	if ResourceLoader.exists(STRIKES):
		player.add_animation_library(StrikeRecipes.LIBRARY,
				adapt_animation_library(load(STRIKES) as AnimationLibrary))


## The library rebased onto this model's skeleton, rotations only bar the
## pelvis (see the class note).
func adapt_animation_library(source: AnimationLibrary) -> AnimationLibrary:
	var skeleton := get_game_skeleton()
	var skeleton_path := get_path_to(skeleton)
	var pelvis := skeleton.find_bone("pelvis")
	var shift := Vector3.ZERO
	if pelvis >= 0:
		shift = skeleton.get_bone_rest(pelvis).origin - BASE_PELVIS_REST
	var target := AnimationLibrary.new()
	for name in source.get_animation_list():
		var animation: Animation = source.get_animation(name).duplicate(true)
		for track in range(animation.get_track_count() - 1, -1, -1):
			var bone := String(animation.track_get_path(track).get_concatenated_subnames())
			if bone == "":
				continue
			var kind := animation.track_get_type(track)
			if kind == Animation.TYPE_SCALE_3D or (kind == Animation.TYPE_POSITION_3D and bone != "pelvis"):
				animation.remove_track(track)
				continue
			animation.track_set_path(track, NodePath("%s:%s" % [skeleton_path, bone]))
			if kind == Animation.TYPE_POSITION_3D:
				for k in animation.track_get_key_count(track):
					animation.track_set_key_value(track, k, animation.track_get_key_value(track, k) + shift)
		target.add_animation(name, animation)
	return target


func get_game_skeleton() -> Skeleton3D:
	return find_child("Skeleton3D", true, false) as Skeleton3D
