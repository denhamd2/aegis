extends Node
## Two-body strike reviewer: plays an attacker strike and the defender's hit
## reaction/sell on the real match wrestlers, then captures a side strip.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x540 tools/probe/strike_pair_shot.tscn -- \
##       --strike strikes/strike_cross --react Hit_React_Head --sell Sell_Head \
##       --wrestlers kenny,cody --out /tmp/strike_pair

const MATCH_SCENE := "res://scenes/match.tscn"

var _strike := "strikes/strike_cross"
var _react := "Hit_React_Head"
var _sell := "Sell_Head"
var _wrestlers := ""
var _out := "/tmp/strike_pair"
var _at: Array = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--strike" and i + 1 < args.size():
			_strike = args[i + 1]
		elif args[i] == "--react" and i + 1 < args.size():
			_react = args[i + 1]
		elif args[i] == "--sell" and i + 1 < args.size():
			_sell = args[i + 1]
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--at" and i + 1 < args.size():
			_at = []
			for token: String in args[i + 1].split(","):
				_at.append(float(token))
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	if _wrestlers != "":
		var pair := Roster.pair_from_spec(_wrestlers)
		if pair.size() == 2:
			TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = false
	b.is_ai = false
	a.global_position = Vector3(0.0, 0.0, 0.0)
	b.global_position = Vector3(0.0, 0.0, -0.9)
	a.look_at(b.global_position, Vector3.UP)
	b.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame
	a.anim_tree.active = false
	b.anim_tree.active = false
	var pa := a.anim_player
	var pb := b.anim_player
	if not pa.has_animation(_strike):
		push_error("attacker clip missing: " + _strike)
		get_tree().quit(1)
		return
	if not pb.has_animation(_react):
		push_error("react clip missing: " + _react)
		get_tree().quit(1)
		return
	var hit_len: float = pb.get_animation(_react).length
	var clip_len: float = pa.get_animation(_strike).length
	var match_camera: Camera3D = scene.get_node_or_null("MatchCamera") as Camera3D
	if match_camera:
		match_camera.current = false
	for child in scene.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var focus := (a.global_position + b.global_position) * 0.5 + Vector3(0.0, 1.0, 0.0)
	var across := (b.global_position - a.global_position).normalized().cross(Vector3.UP)
	camera.global_position = focus + across * 3.0 + Vector3(0.0, 0.4, 0.0)
	camera.look_at(focus, Vector3.UP)
	camera.fov = 45.0
	# The arena is lit for the wide broadcast camera; a close review camera
	# needs its own key and fill or the two men read as silhouettes.
	var key := DirectionalLight3D.new()
	scene.add_child(key)
	key.rotation_degrees = Vector3(-48, -28, 0)
	key.light_energy = 3.0
	key.shadow_enabled = true
	var fill := OmniLight3D.new()
	scene.add_child(fill)
	fill.light_energy = 6.0
	fill.omni_range = 8.0
	fill.global_position = focus + Vector3(2.0, 2.0, 2.0)
	RenderingServer.render_loop_enabled = false
	for i in _at.size():
		var t: float = float(_at[i]) * clip_len
		pa.play(_strike)
		pa.pause()
		pa.seek(t, true)
		pa.advance(0)
		if t <= hit_len and pb.has_animation(_react):
			pb.play(_react)
			pb.pause()
			pb.seek(t, true)
			pb.advance(0)
		elif pb.has_animation(_sell):
			pb.play(_sell)
			pb.pause()
			pb.seek(minf(t - hit_len, pb.get_animation(_sell).length - 0.001), true)
			pb.advance(0)
		RenderingServer.render_loop_enabled = true
		await RenderingServer.frame_post_draw
		RenderingServer.render_loop_enabled = false
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s_%02d.png" % [_out, _strike.get_file(), int(float(_at[i]) * 100.0)])
		print("STRIKE_PAIR t=%.2f" % t)
	get_tree().quit()
