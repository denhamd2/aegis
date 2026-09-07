extends Node
## One-off diagnostic: where is the Roman model actually, how big is it, and
## what does its pose look like at rest versus mid-animation.
##
## Aims cameras at the model's real world-space AABB rather than at assumed
## standing heights, so the framing is right whatever orientation the rig has
## ended up in.

const MATCH_SCENE := "res://scenes/roman_match.tscn"
const SETTLE_FRAMES := 4

var _out_dir := "/tmp/roman_diag"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = 3
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(3, w.player_index)
	var camera: Camera3D = scene.get_node("MatchCamera")

	# Counted locally, not off Engine.get_physics_frames(): that is a
	# process-global counter which is already well past these values by the
	# time the scene is up, so every beat fired at once and all three dumps
	# reported the same instant.
	var tick := 0
	for beat: Array in [[2, "rest"], [70, "tieup"], [150, "action"]]:
		var target_tick: int = beat[0]
		var label: String = beat[1]
		while tick < target_tick:
			await get_tree().physics_frame
			tick += 1
		_freeze(scene, camera, true)
		_dump(a, label)
		var aabb := _world_aabb(a)
		await _shoot_aabb(camera, aabb, "%s_front" % label, Vector3(0, 0.25, 1))
		await _shoot_aabb(camera, aabb, "%s_side" % label, Vector3(1, 0.25, 0))
		await _shoot_aabb(camera, aabb, "%s_high" % label, Vector3(0.6, 1.1, 0.6))
		await _shoot_aabb(camera, aabb, "%s_head" % label, Vector3(0, 0.15, 1), 0.42)
		_freeze(scene, camera, false)

	print("roman-diag: done -> %s" % _out_dir)
	get_tree().quit(0)

func _freeze(scene: Node, camera: Camera3D, frozen: bool) -> void:
	for n_name: String in ["WrestlerA", "WrestlerB", "MatchReferee"]:
		var n: Node = scene.get_node_or_null(n_name)
		if n:
			n.set_physics_process(not frozen)
			n.set_process(not frozen)
	camera.set_physics_process(not frozen)
	camera.set_process(not frozen)

func _dump(w: WrestlerController, label: String) -> void:
	var state: String = WrestlerFSM.State.keys()[w.fsm.current_state]
	var aabb := _world_aabb(w)
	print("\n=== %s === state=%s controller_pos=%.3v" % [label, state, w.global_position])
	print("  world AABB pos=%.3v size=%.3v centre=%.3v" % [aabb.position, aabb.size, aabb.get_center()])
	print("  height(Y)=%.3f  width(X)=%.3f  depth(Z)=%.3f" % [aabb.size.y, aabb.size.x, aabb.size.z])
	var skel := _find_skeleton(w)
	if skel:
		print("  skeleton=%s bones=%d scale=%.3v" % [skel.name, skel.get_bone_count(), skel.global_transform.basis.get_scale()])
		for bone_name: String in ["J_Hips", "J_Chest", "J_Head", "J_Foot_L"]:
			var idx := skel.find_bone(bone_name)
			if idx >= 0:
				var gp := (skel.global_transform * skel.get_bone_global_pose(idx)).origin
				print("    %-10s world %.3v" % [bone_name, gp])
	else:
		print("  NO Skeleton3D FOUND")
	for child in w.get_children():
		if child is Node3D:
			var n3: Node3D = child
			print("  child %-22s pos=%.3v rot_deg=%.1v scale=%.3v" % [
				child.name, n3.position, n3.rotation_degrees, n3.scale])

func _find_skeleton(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for child in n.get_children():
		var found := _find_skeleton(child)
		if found:
			return found
	return null

## Union of every VisualInstance3D AABB in the subtree, in world space.
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

func _shoot_aabb(camera: Camera3D, aabb: AABB, out_name: String,
		bearing: Vector3, fill: float = 1.0) -> void:
	var centre := aabb.get_center()
	var radius := maxf(aabb.size.length() * 0.5, 0.2) * fill
	var dir := bearing.normalized()
	# Far enough back that a sphere of `radius` fits the vertical FOV.
	var fov := 40.0
	var distance := radius / tan(deg_to_rad(fov * 0.5)) + radius
	camera.fov = fov
	camera.global_position = centre + dir * distance
	camera.look_at(centre, Vector3.UP)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		img.save_png("%s/%s.png" % [_out_dir, out_name])
