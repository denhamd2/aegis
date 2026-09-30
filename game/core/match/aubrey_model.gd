class_name AubreyModel
extends Node3D
## The referee, Aubrey Edwards (assets/characters/aubrey_edwards.glb, built by
## tools/blender/referee_aubrey.py from Quaternius' CC0 base characters).
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
## She is 1.70 m; the kit's body is 1.767 m.
const HEIGHT := 1.70
const KIT_HEIGHT := 1.767


func _ready() -> void:
	var source := get_node_or_null("Source") as Node3D
	if source:
		source.scale = Vector3.ONE * (HEIGHT / KIT_HEIGHT)
	_install_animations()
	_dress_fabric()
	_dress_hair()
	_add_ponytail_springs()


## Her hair (tools/blender/referee_aubrey.py): the tight cap and the curled
## ponytail share one strand texture; the highlight runs across the strands
## like the wrestlers' (HairLook), and the ragged hairline is a scissor.
const HAIR_MATERIAL := "M_AubreyHair"


func _dress_hair() -> void:
	for mi: MeshInstance3D in find_children("", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		for surface in mi.mesh.get_surface_count():
			var source := mi.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.resource_name != HAIR_MATERIAL:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			material.alpha_scissor_threshold = 0.35
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
## (This rig's bones point up, so +y is up the bone.) The skull's centre is
## 12 cm up the Head bone; the upper back's sphere sits on the spine.
const PONYTAIL_COLLIDERS := [["Head", 0.1, Vector3(0.0, 0.12, 0.0)],
		["neck_01", 0.06, Vector3.ZERO], ["spine_03", 0.1, Vector3(0.0, 0.08, 0.0)]]


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
