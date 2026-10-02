extends Node
## The referee under the match rig, for her AAA rebuild (character_aaa_plan.md
## stage 5): the wrestlers hidden, she is moved to the ring's centre facing the
## hard camera's side, frozen in a pose, and framed full length from the
## front, side, back and three-quarter, then in her working poses -- standing
## by, watching a man down, the count's slap and the hand raise.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 900x1200 tools/probe/referee_shot.tscn -- --out /tmp/ref

const POSES := [["stand", "strikes/ref_stand", 0.5], ["watch", "strikes/ref_watch", 0.8],
		["slap", "strikes/ref_slap", 0.4], ["raise", "strikes/ref_raise_hand", 1.2]]
## Her yaw: facing -X, the hard camera's side.
const FACING := PI * 0.5
const CHEST := 1.15
## Frames to let a cut settle (TAA, SSR, auto-exposure) before the grab.
const SETTLE_FRAMES := 8

var _out := "/tmp/ref"
var _face_only := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--face":
			_face_only = true
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	for name in ["WrestlerA", "WrestlerB"]:
		var w := scene.get_node(name) as WrestlerController
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
		w.visible = false
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var ref := scene.find_child("RefereeActor", true, false) as Node3D
	ref.process_mode = Node.PROCESS_MODE_DISABLED
	ref.global_position = Vector3.ZERO
	ref.rotation.y = FACING
	var player := ref.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	# Her ponytail's springs settled where she stood: moved and then frozen
	# with her, they kept pointing back there -- the tail stood out sideways
	# in every frame. They are reset where she now stands and keep running.
	var springs := ref.find_child("Ponytail", true, false) as SpringBoneSimulator3D
	if springs:
		springs.process_mode = Node.PROCESS_MODE_ALWAYS
		springs.reset()
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	var front := ref.global_transform.basis.z.normalized()
	var side := front.cross(Vector3.UP)
	# Her face and eyes: framed off her eyeballs (Aubrey_Eyes), front and
	# three-quarter, standing.
	player.play("strikes/ref_stand")
	player.seek(0.5, true)
	player.pause()
	for _i in 4:
		await RenderingServer.frame_post_draw
	var eyes_mesh := ref.find_child("Aubrey_Eyes", true, false) as MeshInstance3D
	var skeleton := ref.find_child("Skeleton3D", true, false) as Skeleton3D
	var head := skeleton.find_bone("Head")
	var head_pos := (skeleton.global_transform * skeleton.get_bone_global_pose(head)).origin
	var eyes := head_pos + Vector3.UP * 0.075 * skeleton.global_transform.basis.get_scale().y + front * 0.12
	if eyes_mesh:
		print("REFEREE_SHOT eyes mesh found")
	for shot: Array in [["face", front, 0.75, 22.0], ["face_q34", (front + side * 0.8).normalized(), 0.75, 22.0],
			["eyes", front, 0.32, 14.0]]:
		cam.fov = shot[3]
		cam.look_at_from_position(eyes + (shot[1] as Vector3) * (shot[2] as float) - Vector3.UP * 0.01, eyes - Vector3.UP * 0.03)
		for _i in SETTLE_FRAMES:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, shot[0]])
		print("REFEREE_SHOT %s" % shot[0])
	if _face_only:
		get_tree().quit()
		return
	for pose: Array in POSES:
		player.play(pose[1])
		player.seek(pose[2], true)
		player.pause()
		var views := [["front", front]] if pose[0] != "stand" else [
				["front", front], ["side", side], ["back", -front], ["q34", (front + side).normalized()]]
		for view: Array in views:
			cam.fov = 30.0
			cam.look_at_from_position(Vector3(0, CHEST, 0) + (view[1] as Vector3) * 4.2 + Vector3.UP * 0.25,
					Vector3(0, CHEST - 0.25, 0))
			for _i in SETTLE_FRAMES:
				await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, pose[0], view[0]])
			print("REFEREE_SHOT %s_%s" % [pose[0], view[0]])
	print("REFEREE_SHOT done")
	get_tree().quit()
