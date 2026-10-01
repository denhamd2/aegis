extends Node
## The ringside sign fans (SignFans): through the face-off shot's own lens
## (EntranceDirector "faceoff_side": 3.4 m off the pair at 1.5 m, 34 degrees),
## and close up, seated, rising and holding their signs up.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 --resolution 960x540 \
##       tools/probe/sign_fans_shot.tscn -- --out /tmp/fans

var _out := "/tmp/fans"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out":
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	# Chest to chest in the middle, as the stare-down has them.
	ws[0].global_position = Vector3(0, 0, -0.375)
	ws[1].global_position = Vector3(0, 0, 0.375)
	for w in ws:
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
	var fans := get_tree().get_first_node_in_group("sign_fans") as SignFans
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.fov = EntranceDirector.FACEOFF_CAM_FOV
	cam.current = true
	var shots := [
		["faceoff", Vector3(-EntranceDirector.FACEOFF_CAM_DISTANCE, EntranceDirector.FACEOFF_CAM_HEIGHT, 0), Vector3(0, 1.45, 0), EntranceDirector.FACEOFF_CAM_FOV],
	]
	for n in fans.fans.size():
		# In front of him, off his right shoulder, a little above his head.
		var f: SignFan = fans.fans[n]
		var ahead := f.global_transform.basis.z.normalized()
		var at := f.global_position + ahead * 2.6 + f.global_transform.basis.x * 0.8 + Vector3.UP * 1.7
		shots.append(["close%d" % n, at, f.global_position + Vector3.UP * 1.2, 50.0])
	for i in 30:
		await get_tree().process_frame
	await _snap(cam, shots, "0_seated")
	for fan in fans.fans:
		fan.raise(6.0)
	for t in [0.4, 0.9, 1.6, 2.6]:
		await get_tree().create_timer(t - (0.0 if t == 0.4 else [0.4, 0.9, 1.6][[0.9, 1.6, 2.6].find(t)])).timeout
		await _snap(cam, shots, "1_up_%.1f" % t)
	await get_tree().create_timer(6.0).timeout
	await _snap(cam, shots, "2_down")
	get_tree().quit()


func _snap(cam: Camera3D, shots: Array, tag: String) -> void:
	for s: Array in shots:
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = s[3]
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, s[0], tag])
