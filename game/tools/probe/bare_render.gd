extends Node3D
## Renders a character model scene on its own -- no match, no controller, no
## AnimationTree driving it -- and prints where its bones actually are.
##
## This is the bisection tool for the single most confusing class of import
## bug. A wrestler who is inverted, torn apart or facing backwards in a match
## has one of two faults, and they need completely different fixes:
##
##   stands up correctly here, wrong in a match  -> the ANIMATION RETARGET
##   wrong here too                              -> the ASSET or its IMPORT
##
## Guessing between those costs days. Running this costs a minute.
##
## Usage, from the repo root:
##   godot4 --headless --path game tools/probe/bare_render.tscn \
##       -- --scene res://scenes/<name>_model.tscn --out /tmp/bare
##
## Add --bones J_Hips,J_Chest,J_Head,J_Foot_L to name the bones to report; the
## defaults are the base rig's. Pass the target model's own names, from the
## audit probe's skeleton listing.
##
## Headless prints the numbers but cannot save frames. For images, which is the
## only way to judge anything about how it LOOKS:
##   xvfb-run -a --server-args="-screen 0 1280x720x24" godot4 --path game \
##       --rendering-driver opengl3 --resolution 1280x720 \
##       tools/probe/bare_render.tscn -- --scene res://... --out /tmp/bare

const SETTLE_FRAMES := 4
const DEFAULT_BONES := "pelvis,spine_03,Head,foot_l,foot_r,hand_l"

var _scene_path := ""
var _out_dir := "/tmp/bare_render"
var _bones: PackedStringArray = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var bones := DEFAULT_BONES
	for i in args.size():
		if args[i] == "--scene" and i + 1 < args.size():
			_scene_path = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
		elif args[i] == "--bones" and i + 1 < args.size():
			bones = args[i + 1]
	_bones = bones.split(",", false)
	if _scene_path == "":
		push_error("bare_render: pass --scene res://scenes/<name>_model.tscn")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)

	_build_studio()
	var model: Node3D = load(_scene_path).instantiate() as Node3D
	if model == null:
		push_error("bare_render: %s did not instantiate as a Node3D" % _scene_path)
		get_tree().quit(1)
		return
	add_child(model)
	# Two frames: one for _ready() on the model's own script (material repairs,
	# skeleton scaling), one for those to land in the transform hierarchy.
	await get_tree().process_frame
	await get_tree().process_frame

	_report(model)
	if DisplayServer.get_name() != "headless":
		await _shoot_all(model)
	else:
		print("\nheadless: numbers only, no frames saved. Re-run under xvfb-run")
		print("with --rendering-driver opengl3 to judge how it looks -- and it")
		print("does have to be judged that way. A bone-position table can say a")
		print("model is upright and say nothing about whether it faces the right")
		print("way, whether the hair renders, or whether skin is coming through")
		print("the clothes.")
	print("\nbare_render: done -> %s" % _out_dir)
	get_tree().quit(0)


func _build_studio() -> void:
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.18, 0.19, 0.22)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 0.9
	world.environment = environment
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.6
	add_child(key)


## Every skeleton, because a model rigged on more than one needs all of them
## reported: a body at 1.05 inside hair at 1.00 is invisible in a single-
## skeleton dump and is exactly the fault that reads as "he went bald".
func _report(model: Node3D) -> void:
	print("\n=== %s ===" % _scene_path)
	var skeletons := model.find_children("", "Skeleton3D", true, false)
	if skeletons.is_empty():
		print("!! no Skeleton3D")
	for node in skeletons:
		var skeleton := node as Skeleton3D
		print("\n  skeleton %s  bones=%d  scale=%.3v" % [
				model.get_path_to(skeleton), skeleton.get_bone_count(),
				skeleton.global_transform.basis.get_scale()])
		for bone_name in _bones:
			var index := skeleton.find_bone(bone_name)
			if index < 0:
				continue
			var world := (skeleton.global_transform
					* skeleton.get_bone_global_pose(index)).origin
			print("    %-12s world %.3v" % [bone_name, world])
	if skeletons.size() > 1:
		print("\n  Compare the scales above. They must match. A model rigged on")
		print("  several skeletons whose scales differ has part of the character")
		print("  sized inside the rest of it, which shows up as the head pushing")
		print("  through the hair or the body through the clothes -- and reads,")
		print("  wrongly, as three separate art bugs.")

	var aabb := _world_aabb(model)
	print("\n  AABB position=%.3v size=%.3v" % [aabb.position, aabb.size])
	print("  height=%.3f m" % aabb.size.y)
	# A head below the hips is the retarget signature, and it is worth naming
	# explicitly because the rendered result -- a torn, folded mesh -- does not
	# obviously say "rest-pose conversion" to anyone looking at it.
	var head := _bone_world(skeletons, "Head")
	var hips := _bone_world(skeletons, "pelvis")
	if head != Vector3.INF and hips != Vector3.INF and head.y < hips.y:
		print("!! HEAD IS BELOW THE HIPS (head %.3f, hips %.3f)." % [head.y, hips.y])
		print("!! In a bare render that means the ASSET or its import, not the")
		print("!! retarget -- nothing is driving this pose. In a match with a")
		print("!! correct bare render, it means the retarget copied bone tracks")
		print("!! verbatim instead of converting them through rest space.")

	print("\n  --- visible meshes ---")
	for visual in _visuals(model):
		var mesh_instance := visual as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		var materials := ""
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface)
			var albedo := "NO ALBEDO"
			if material is BaseMaterial3D:
				var texture := (material as BaseMaterial3D).get_texture(
						BaseMaterial3D.TEXTURE_ALBEDO)
				if texture:
					albedo = texture.resource_path.get_file()
			materials += "%s[%s] " % [
					material.resource_name if material else "null", albedo]
		print("    %-28s %s" % [mesh_instance.name, materials])
	print("  (get_active_material, so this is what the model's own _ready()")
	print("   actually installed -- not what the .glb shipped.)")


func _bone_world(skeletons: Array, bone_name: String) -> Vector3:
	for node in skeletons:
		var skeleton := node as Skeleton3D
		var index := skeleton.find_bone(bone_name)
		if index >= 0:
			return (skeleton.global_transform
					* skeleton.get_bone_global_pose(index)).origin
	return Vector3.INF


func _world_aabb(node: Node) -> AABB:
	var out := AABB()
	var first := true
	for visual in _visuals(node):
		var world := visual.global_transform * visual.get_aabb()
		if first:
			out = world
			first = false
		else:
			out = out.merge(world)
	return out


func _visuals(node: Node) -> Array[VisualInstance3D]:
	var found: Array[VisualInstance3D] = []
	if node is VisualInstance3D and (node as VisualInstance3D).visible:
		found.append(node)
	for child in node.get_children():
		found.append_array(_visuals(child))
	return found


## Whole-body from four bearings plus three face angles. The face shots are
## framed off the head bone rather than the body AABB, because a face judged
## from a full-body frame is four pixels wide and every hair and eye defect
## found so far was invisible at that size.
func _shoot_all(model: Node3D) -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	var aabb := _world_aabb(model)
	for shot: Array in [
			["front", Vector3(0, 0.15, 1)],
			["side", Vector3(1, 0.15, 0)],
			["back", Vector3(0, 0.15, -1)],
			["high", Vector3(0.7, 0.9, 0.7)]]:
		await _shoot(camera, aabb, shot[0], shot[1])

	var head := _bone_world(model.find_children("", "Skeleton3D", true, false), "Head")
	if head == Vector3.INF:
		return
	var head_aabb := AABB(head - Vector3(0.16, 0.10, 0.16), Vector3(0.32, 0.34, 0.32))
	for shot: Array in [
			["face_front", Vector3(0, 0.06, 1)],
			["face_three_quarter", Vector3(0.7, 0.06, 0.8)],
			["face_side", Vector3(1, 0.06, 0.05)]]:
		await _shoot(camera, head_aabb, shot[0], shot[1])


func _shoot(camera: Camera3D, aabb: AABB, out_name: String, bearing: Vector3) -> void:
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.2)
	camera.fov = 40.0
	camera.global_position = centre + bearing.normalized() \
			* (radius / tan(deg_to_rad(20.0)) + radius)
	camera.look_at(centre, Vector3.UP)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image:
		image.save_png("%s/%s.png" % [_out_dir, out_name])
