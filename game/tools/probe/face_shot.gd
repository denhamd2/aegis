extends Node
## Eyes and faces, for any two wrestlers and the referee: a close-up of each
## man's eyes and his face from the front, in a frozen face-off under the
## match rig, and the same for the referee (RefereeActor), frozen where she
## parks. Written for the head-kit eyes round (character_aaa_plan.md S1),
## where Roman's close-up lived in hair_shot.tscn and the others had none.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/face_shot.tscn -- \
##       --a kenny --b cody --out /tmp/faces [--only kenny]
##
## Framing is off the head bone (whatever the rig calls it): the eyes sit
## EYE_UP above it and EYE_AHEAD in front, near enough on every model here.

const EYE_UP := 0.06
const EYE_AHEAD := 0.09

var _out := "/tmp/faces"
var _a := "kenny"
var _b := "cody"
var _only := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if i + 1 >= args.size():
			continue
		match args[i]:
			"--out": _out = args[i + 1]
			"--a": _a = args[i + 1]
			"--b": _b = args[i + 1]
			"--only": _only = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id(_a), Roster.by_id(_b), 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
		w.play_presentation_clip("strikes/face_off", true)
	a.global_position = Vector3(-0.45, 0, 0)
	b.global_position = Vector3(0.45, 0, 0)
	a.rotation.y = atan2(-1.0, 0.0)
	b.rotation.y = atan2(1.0, 0.0)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	for _i in 20:
		await RenderingServer.frame_post_draw
	var subjects := [[_a, a, Vector3(1, 0, 0)], [_b, b, Vector3(-1, 0, 0)]]
	var ref := scene.find_child("RefereeActor", true, false) as Node3D
	if ref:
		ref.process_mode = Node.PROCESS_MODE_DISABLED
		subjects.append(["referee", ref, Vector3.ZERO])
	for subject: Array in subjects:
		var id: String = subject[0]
		if _only != "" and id != _only:
			continue
		var node: Node3D = subject[1]
		var forward: Vector3 = subject[2]
		if forward == Vector3.ZERO:
			forward = node.global_transform.basis.z.normalized()
		var eyes := _eyes(node)
		if eyes == Vector3.INF:
			var head := _head(node)
			if head == Vector3.INF:
				push_warning("face_shot: no head bone on %s" % id)
				continue
			eyes = head + Vector3.UP * EYE_UP + forward * EYE_AHEAD
		# Only this subject: the other man stands 0.9 m off, inside the
		# face shot's camera distance.
		for other: Array in subjects:
			(other[1] as Node3D).visible = other[1] == node
		for shot: Array in [["eyes", 0.30, 14.0], ["face", 0.75, 26.0]]:
			cam.fov = shot[2]
			cam.look_at_from_position(eyes + forward * (shot[1] as float) + Vector3.UP * 0.01, eyes)
			for _i in 30:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, id, shot[0]])
	print("FACE_SHOT done")
	get_tree().quit()


## Where the eyes are: between the eye bones if the rig has them, else the
## centre of a mesh named for the eyes, else INF.
static func _eyes(root: Node) -> Vector3:
	for sk: Skeleton3D in root.find_children("*", "Skeleton3D", true, false):
		var sum := Vector3.ZERO
		var n := 0
		for i in sk.get_bone_count():
			var name := sk.get_bone_name(i).to_lower()
			if name in ["eye_l", "eye_r", "j_eye_l", "j_eye_r"]:
				sum += (sk.global_transform * sk.get_bone_global_pose(i)).origin
				n += 1
		if n == 2:
			return sum / 2.0
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if String(mi.name).to_lower() == "eyes" and mi.mesh:
			return mi.global_transform * mi.get_aabb().get_center()
	return Vector3.INF


## The head bone's world position on the first skeleton under `root` that
## has one, or INF.
static func _head(root: Node) -> Vector3:
	for sk: Skeleton3D in root.find_children("*", "Skeleton3D", true, false):
		for i in sk.get_bone_count():
			var name := sk.get_bone_name(i).to_lower()
			if name == "head" or name == "j_head" or name.ends_with(":head"):
				return (sk.global_transform * sk.get_bone_global_pose(i)).origin
	return Vector3.INF
