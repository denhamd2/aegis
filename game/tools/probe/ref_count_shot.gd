extends Node
## Aubrey's count, judged where it goes wrong: a real cover (the referee's own
## pin fields, WrestlerController.begin_pin) at the centre, out by the ropes and
## in a corner, and her kneeling spot measured against BOTH men's bones.
## Prints the clearance and renders each from the side and from above.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/ref_count_shot.tscn -- --out /tmp/refcount

const SPOTS := {"centre": Vector3(0.3, 0.0, 0.2), "ropes": Vector3(2.3, 0.0, 0.4),
		"corner": Vector3(2.2, 0.0, -2.2), "near_ropes": Vector3(-2.3, 0.0, 1.0)}

var _out := "/tmp/refcount"
var _no_render := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--no-render":
			_no_render = true
	DirAccess.make_dir_recursive_absolute(_out)
	await get_tree().process_frame
	var only := OS.get_environment("REFONLY")
	for key: String in SPOTS:
		for yaw in [0.0, 90.0, 200.0]:
			if only != "" and only != "%s%d" % [key, int(yaw)]:
				continue
			await _one(key, SPOTS[key], deg_to_rad(yaw))
	get_tree().quit()


func _one(key: String, at: Vector3, yaw: float) -> void:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	scene.entrances = false
	get_tree().root.add_child(scene)
	for f in 10:
		await get_tree().physics_frame
	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	var referee: MatchReferee = scene.get_node("MatchReferee")
	for w in [attacker, defender]:
		w.is_ai = false
		if w.ai:
			w.ai.set_physics_process(false)
	attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	defender.fsm.transition_to(WrestlerFSM.State.IDLE)
	await get_tree().physics_frame
	defender.global_position = at
	defender.rotation.y = yaw
	attacker.global_position = at + Vector3(cos(yaw), 0.0, -sin(yaw)) * 0.9
	attacker.last_landed_tier = CombatSystem.Tier.FINISHER
	defender.fsm.transition_to(WrestlerFSM.State.STUNNED)
	defender.fsm.transition_to(WrestlerFSM.State.DOWN)
	defender._cover_eligible = true
	referee._pinning = true
	referee._pin_ticks = 0
	referee._pin_count_shown = 0
	referee._pin_attacker = attacker
	referee._pin_defender = defender
	referee._rope_side = Vector3.ZERO
	attacker.begin_pin(defender, 7)
	var actor: RefereeActor = scene.get_node("RefereeActor")
	var worst := INF
	for f in 240:
		await get_tree().physics_frame
		if f == 140 and not _no_render and yaw == 0.0:
			await _render(scene, key, at, actor.global_position)
		if OS.get_environment("REFTRACE") != "" and f % 20 == 0:
			print("  f%03d %s at=(%+.2f,%+.2f) target=%s" % [f, RefereeActor.Mode.keys()[actor.mode],
					actor.global_position.x, actor.global_position.z, str(actor._cover_target)])
		if actor.mode == RefereeActor.Mode.COUNTING and f > 150:
			worst = minf(worst, RefereeActor.body_clearance(actor.global_position,
					[attacker, defender], actor.global_transform.basis.z))
	var kneel := actor.global_position
	# What the old rule chose: 0.62 m past his neck, clamped at 3.0.
	var neck: Vector3 = defender._bone_world("neck_01")
	neck.y = 0.0
	var hips := Vector3(defender.global_position.x, 0.0, defender.global_position.z)
	var up := (neck - hips).normalized()
	var old := neck + up * 0.62
	old.x = clampf(old.x, -3.0, 3.0)
	old.z = clampf(old.z, -3.0, 3.0)
	print("REFCOUNT %s yaw=%3d old_rule clearance=%.2f" % [key, int(rad_to_deg(yaw)),
			RefereeActor.body_clearance(old, [attacker, defender], -up)])
	print("REFCOUNT %s yaw=%3d mode=%s at=(%+.2f,%+.2f) clearance=%.2f worst=%.2f" % [key,
			int(rad_to_deg(yaw)), RefereeActor.Mode.keys()[actor.mode], kneel.x, kneel.z,
			RefereeActor.body_clearance(kneel, [attacker, defender],
			actor.global_transform.basis.z), worst])
	scene.queue_free()
	await get_tree().process_frame


## Mid-count, from the side and from above.
func _render(scene: Node, key: String, at: Vector3, kneel: Vector3) -> void:
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.fov = 50.0
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var focus := (at + kneel) * 0.5 + Vector3.UP * 0.3
	for view: Array in [["side", Vector3(0.0, 1.6, 3.2)], ["top", Vector3(0.01, 4.5, 0.0)]]:
		cam.global_position = focus + (view[1] as Vector3)
		cam.look_at(focus, Vector3.UP)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, key, view[0]])
	cam.queue_free()
