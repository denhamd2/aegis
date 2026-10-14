extends Node
## Blood, for review: each man's face at rising bleed levels, his back after
## the tacks, and the canvas after a bloody match -- dried stains from
## earlier, a fresh pool where a man lay, spatter, drips and a smear.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/blood_shot.tscn -- --out /tmp/blood
##
## Frozen face-off under the match rig, like face_shot.tscn. The bleed is
## set on Blood directly (shown and bled), so a level is a level, not a
## replayed match.

const LEVELS := [0.0, 0.15, 0.35, 0.6, 1.0]

var _out := "/tmp/blood"
var _a := "roman"
var _b := "cody"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--out": _out = args[i + 1]
			"--a": _a = args[i + 1]
			"--b": _b = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	Blood.enabled = true
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
	var ref := scene.find_child("RefereeActor", true, false) as Node3D
	if ref:
		ref.process_mode = Node.PROCESS_MODE_DISABLED
		ref.visible = false
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	for _i in 20:
		await RenderingServer.frame_post_draw

	for pair: Array in [[_a, a, b, Vector3(1, 0, 0)], [_b, b, a, Vector3(-1, 0, 0)]]:
		var w: WrestlerController = pair[1]
		var other: WrestlerController = pair[2]
		var fwd: Vector3 = pair[3]
		var blood := w.get_node_or_null("Blood") as Blood
		if blood == null:
			push_warning("blood_shot: no Blood on %s" % pair[0])
			continue
		other.visible = false
		var head := blood.bone_at(&"head")
		for level: float in LEVELS:
			_bleed(blood, level, 0.0, 1.0)
			# a three-quarter close-up, the way a broadcast holds on a bloody face
			cam.fov = 30.0
			cam.global_position = head + fwd * 1.05 + Vector3.UP * 0.02 + fwd.cross(Vector3.UP) * 0.35
			cam.look_at(head + Vector3.DOWN * 0.12)
			await _save("%s_face_%03d.png" % [pair[0], int(level * 100)])
		# chest and face, wide enough to see where it has run to, wet then dried
		for wet: float in [1.0, 0.15]:
			_bleed(blood, 1.0, 0.0, wet)
			cam.fov = 40.0
			cam.global_position = head + fwd * 1.9 + Vector3.DOWN * 0.3
			cam.look_at(head + Vector3.DOWN * 0.38)
			await _save("%s_chest_wet%03d.png" % [pair[0], int(wet * 100)])
		# his back after the tacks
		_bleed(blood, 0.0, 0.55, 1.0)
		cam.global_position = head - fwd * 1.9 + Vector3.DOWN * 0.4
		cam.look_at(head + Vector3.DOWN * 0.5)
		await _save("%s_back.png" % pair[0])
		_bleed(blood, 0.0, 0.0, 1.0)
		other.visible = true

	# The canvas after a bloody match: old stains dried, then a fresh pool.
	var canvas := CanvasBlood.of(get_tree())
	a.visible = false
	b.visible = false
	canvas.clock = 0.0
	canvas.stamp(Vector3(1.4, 0, -1.1), 0.16, 0.5, 0.5)
	canvas.spatter(Vector3(1.3, 0, -1.0), Vector3(1, 0, -0.6), 1.0)
	for i in 30:
		canvas.drip(Vector3(0.9 + i * 0.03, 0, 0.6 + sin(i * 0.7) * 0.1), 1.2)
	canvas.clock = 400.0
	for i in 8:
		canvas.stamp(Vector3(-0.4 + i * 0.012, 0, 0.2), 0.14 + i * 0.01, 0.16, 0.45)
	canvas.smear(Vector3(-0.3, 0, 0.25), Vector3(0.45, 0, 0.55), 0.09, 0.6)
	canvas.spatter(Vector3(-0.2, 0, 0.0), Vector3(-1, 0, -0.4), 1.3)
	canvas.flush()
	var cm: ShaderMaterial = canvas.material
	cm.set_shader_parameter("now", 420.0)
	canvas.set_process(false)
	cam.fov = 45.0
	cam.global_position = Vector3(-3.4, 2.4, 0.0)
	cam.look_at(Vector3(0.3, 0, -0.2))
	await _save("canvas_wide.png")
	cam.fov = 35.0
	cam.global_position = Vector3(-1.4, 1.3, 0.4)
	cam.look_at(Vector3(0.0, 0, 0.3))
	await _save("canvas_close.png")
	print("BLOOD SHOT DONE")
	get_tree().quit()


func _bleed(b: Blood, head: float, back: float, wet: float) -> void:
	b.head = head
	b.shown_head = head
	b.back = back
	b.shown_back = back
	b.wet = wet
	for m in b.materials:
		m.set_shader_parameter("bleed_head", head)
		m.set_shader_parameter("bleed_back", back)
		m.set_shader_parameter("wet", wet)


func _save(file: String) -> void:
	for _i in 6:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file))
