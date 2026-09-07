extends Node3D
## Renders roman_model.tscn on its own -- no match, no controller, no
## AnimationTree driving it -- to separate "the imported model is wrong"
## from "the animation retarget is wrong".
##
## If the bare model stands up correctly here and only falls apart inside a
## match, the defect is in the base-rig animation remap (roman_model.gd's
## BONE_MAP). If it is inverted here too, the defect is in the asset or its
## import.

const MODEL := "res://scenes/roman_model.tscn"
const SETTLE_FRAMES := 4

var _out_dir := "/tmp/roman_bare"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.19, 0.22)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.85)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, 35, 0)
	key.light_energy = 1.6
	add_child(key)

	var model: Node3D = load(MODEL).instantiate()
	add_child(model)
	await get_tree().process_frame
	await get_tree().process_frame

	var skel := _find_skeleton(model)
	if skel:
		print("bones=%d  skeleton scale=%.3v" % [skel.get_bone_count(), skel.global_transform.basis.get_scale()])
		for bone_name: String in ["J_Hips", "J_Chest", "J_Neck", "J_Head",
				"J_Foot_L", "J_Foot_R", "J_Wrist_L"]:
			var idx := skel.find_bone(bone_name)
			if idx >= 0:
				var gp := (skel.global_transform * skel.get_bone_global_pose(idx)).origin
				print("  %-10s world %.3v" % [bone_name, gp])
			else:
				print("  %-10s NOT FOUND" % bone_name)
	else:
		print("NO Skeleton3D")

	var aabb := _world_aabb(model)
	print("AABB pos=%.3v size=%.3v centre=%.3v" % [aabb.position, aabb.size, aabb.get_center()])

	print("\n--- mesh instances ---")
	for vi: VisualInstance3D in _visuals(model):
		if vi is MeshInstance3D:
			var mi: MeshInstance3D = vi
			var wb := mi.global_transform * mi.get_aabb()
			var mats := ""
			for s in mi.get_surface_override_material_count():
				var mat := mi.mesh.surface_get_material(s) if mi.mesh else null
				var albedo := "none"
				if mat is BaseMaterial3D:
					var bm: BaseMaterial3D = mat
					var tex := bm.get_texture(BaseMaterial3D.TEXTURE_ALBEDO)
					albedo = tex.resource_path.get_file() if tex else "NO ALBEDO"
				mats += "%s[%s] " % [mat.resource_name if mat else "null", albedo]
			print("  %-20s vis=%s centreX=%+.3f size=%.2v  %s" % [
				mi.name, mi.visible, wb.get_center().x, wb.size, mats])

	var camera := Camera3D.new()
	add_child(camera)
	for shot: Array in [["front", Vector3(0, 0.15, 1)], ["side", Vector3(1, 0.15, 0)],
			["back", Vector3(0, 0.15, -1)], ["high", Vector3(0.7, 0.9, 0.7)]]:
		await _shoot(camera, aabb, shot[0], shot[1])

	# Head close-ups, framed off the head bone rather than the whole-body
	# AABB, so the face can actually be judged.
	if skel:
		var head_idx := skel.find_bone("J_Head")
		if head_idx >= 0:
			var head := (skel.global_transform * skel.get_bone_global_pose(head_idx)).origin
			var head_aabb := AABB(head - Vector3(0.16, 0.10, 0.16), Vector3(0.32, 0.34, 0.32))
			for shot: Array in [["face_front", Vector3(0, 0.06, 1)],
					["face_three_quarter", Vector3(0.7, 0.06, 0.8)],
					["face_side", Vector3(1, 0.06, 0.05)]]:
				await _shoot(camera, head_aabb, shot[0], shot[1])
	print("roman-bare: done -> %s" % _out_dir)
	get_tree().quit(0)

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for child in n.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

func _world_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for vi: VisualInstance3D in _visuals(n):
		var world := vi.global_transform * vi.get_aabb()
		if first:
			out = world
			first = false
		else:
			out = out.merge(world)
	return out

func _visuals(n: Node) -> Array[VisualInstance3D]:
	var found: Array[VisualInstance3D] = []
	if n is VisualInstance3D and (n as VisualInstance3D).visible:
		found.append(n)
	for child in n.get_children():
		found.append_array(_visuals(child))
	return found

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
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [_out_dir, out_name])
