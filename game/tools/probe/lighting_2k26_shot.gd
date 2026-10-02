extends Node
## A/B stills for gauntlet/refs/lighting_2k26.md items 6, 7, 8 and 9, toggled
## in one scene so the two frames of a pair differ only by the item:
##   led_on / led_off        -- the ribbon-board spill omnis (item 6) shown /
##                              hidden, match look, camera on the front rows
##                              under the suite ribbon;
##   glint_<look>_on / _off  -- glint_strength at its look's value / 0
##                              (item 8), from a low ringside camera up into
##                              the rig, in the match look and the entrance
##                              look;
##   beams_entrance_0..2     -- a high wide, ~1.3 s apart, the entrance look's
##                              moving beams (item 9) and its dark house
##                              (item 7); aims and levels printed per frame;
##   beams_match_0..1        -- the same wide in the match look: static beams,
##                              the crowd lit.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/lighting_2k26_shot.tscn -- --out /tmp/l2k

var _out := "/tmp/l2k"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 1)
	scene.entrances = false
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	for n in ["WrestlerA", "WrestlerB"]:
		var w: WrestlerController = scene.get_node(n)
		w.set_physics_process(false)
		if w.ai:
			w.ai.set_physics_process(false)
	var hud := scene.get_node_or_null("MatchHUD")
	if hud and "visible" in hud:
		hud.visible = false
	var rig := get_tree().get_first_node_in_group("arena_lighting") as ArenaLighting
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.make_current()

	# Item 6: the spill omnis, on and off.
	var spill: Array[Light3D] = []
	for child in rig.get_children():
		if String(child.name).begins_with("RibbonSpill"):
			spill.append(child)
	print("L2K ribbon spill lights: %d" % spill.size())
	var target: Vector3 = spill[0].global_position if not spill.is_empty() else Vector3(0, 4, 20)
	for s in spill:
		if absf(s.global_position.x) < absf(target.x) and s.global_position.z > 0.0:
			target = s.global_position
	print("L2K spill target %s" % target)
	cam.fov = 50.0
	cam.look_at_from_position(Vector3(0.0, 2.6, 4.0), target - Vector3(0.0, 2.5, 0.0))
	for on in [true, false]:
		for s in spill:
			s.visible = on
		await _shoot("led_%s" % ("on" if on else "off"))
	for s in spill:
		s.visible = true

	# Item 8: glints in each look.
	cam.fov = 60.0
	cam.look_at_from_position(Vector3(0.0, 1.0, 7.0), Vector3(0.0, 6.5, 0.0))
	for look: ArenaLighting.Look in [ArenaLighting.Look.MATCH, ArenaLighting.Look.ENTRANCE]:
		rig.set_look(look)
		var name := "match" if look == ArenaLighting.Look.MATCH else "entrance"
		var strength: float = ArenaLighting.GLINT_MATCH if look == ArenaLighting.Look.MATCH \
				else ArenaLighting.GLINT_ENTRANCE
		RenderingServer.global_shader_parameter_set("glint_strength", strength)
		await _shoot("glint_%s_on" % name)
		RenderingServer.global_shader_parameter_set("glint_strength", 0.0)
		await _shoot("glint_%s_off" % name)
	# Item 9: the moving beams. The entrance look is still on; a wide on the
	# rig, then the same frame a beat-and-a-half later, the beams logged.
	cam.fov = 62.0
	cam.look_at_from_position(Vector3(0.0, 8.0, 22.0), Vector3(0.0, 4.0, 0.0))
	rig.sync_beat(EntranceDirector.ROMAN_BEAT)
	for t in 3:
		await _shoot("beams_entrance_%d" % t)
		_log_beams(rig)
		for _i in 26:
			await RenderingServer.frame_post_draw
	rig.set_look(ArenaLighting.Look.MATCH)
	for t in 2:
		await _shoot("beams_match_%d" % t)
		_log_beams(rig)
		for _i in 26:
			await RenderingServer.frame_post_draw
	print("L2K done")
	get_tree().quit()


func _log_beams(rig: ArenaLighting) -> void:
	var line := "L2K beams:"
	for beam: SpotLight3D in rig._beams.slice(0, 4):
		var f: Vector3 = -beam.global_transform.basis.z
		line += " [%s aim %.2f,%.2f,%.2f e %.2f]" % [beam.name, f.x, f.y, f.z, beam.light_energy]
	print(line)


func _shoot(label: String) -> void:
	for _i in 12:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, label])
	print("L2K shot %s" % label)
