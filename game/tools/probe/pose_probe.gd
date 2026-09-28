extends Node
## The tie-up and grapple hold as a live match plays them, close: saves a
## frame every quarter second of TIE_UP and the first two of GRAPPLE_HOLD.

func _ready() -> void:
	var out := "/tmp/claude-0/-home-user-aegis/bdf5dfbe-1f16-5e7c-8506-e0a0298b74d5/scratchpad/pose"
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()
	cam.fov = 38.0
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	var saved := 0
	for f in 420:
		await get_tree().process_frame
		var mid := (a.global_position + b.global_position) * 0.5
		cam.look_at_from_position(mid + Vector3(0.3, 1.3, 3.6), mid + Vector3.UP * 1.0)
		if a.fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD and saved < 2 and f % 6 == 0:
			saved += 1
			print("hold frame %d gap %.2f" % [f, a.global_position.distance_to(b.global_position)])
			get_viewport().get_texture().get_image().save_png("%s/hold_%d.png" % [out, saved])
		if a.fsm.current_state == WrestlerFSM.State.TIE_UP and f % 15 == 0 and f < 400:
			print("frame %d: A %s  B %s  gap %.2f m" % [f, WrestlerFSM.State.keys()[a.fsm.current_state],
					WrestlerFSM.State.keys()[b.fsm.current_state], a.global_position.distance_to(b.global_position)])
			get_viewport().get_texture().get_image().save_png("%s/tie_%03d.png" % [out, f])
	get_tree().quit()
