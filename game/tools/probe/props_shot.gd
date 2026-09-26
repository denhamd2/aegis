extends Node
## Roman in his entrance props, from the front, three-quarter, his left side
## and behind, standing on his mark in the ring.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 800x800 tools/probe/props_shot.tscn -- /tmp/props.png
##
## Writes /tmp/props_0.png .. _3.png at his chest and _4 .. _7 at his waist. This is the shot that found the ula fala
## rendering INSIDE his chest and the draped title hanging off the outside
## of his arm (EntranceProps.FITS).
func _ready() -> void:
	var pair := Roster.pair_from_spec("")
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var w: WrestlerController = scene.get_node("WrestlerA")
	for c in scene.get_children():
		if c.has_method("set_physics_process") and c != w: c.set_physics_process(false)
	w.set_physics_process(false)
	w.play_presentation_clip("strikes/roman_stand")
	var props := EntranceProps.dress(w)
	for _i in 20: await get_tree().process_frame
	var head := w.global_position + Vector3.UP * 1.5
	var fwd := -w.global_transform.basis.z
	var cam := Camera3D.new(); scene.add_child(cam)
	cam.global_position = head + fwd * 1.6 + Vector3.UP * 0.1
	cam.look_at(head, Vector3.UP); cam.fov = 30; cam.current = true
	var mc = scene.get_node_or_null("MatchCamera")
	if mc: mc.current = false
	for mi: MeshInstance3D in props.find_children("*", "MeshInstance3D", true, false):
		print(mi.name, " vis ", mi.is_visible_in_tree(), " aabb ", mi.global_transform * mi.get_aabb())
	print("neck bone ", props._bone("neck_01"), " scale ", props._scale, " w ", w.global_position)
	var right := w.global_transform.basis.x
	var views := [fwd * 1.6, (fwd - right).normalized() * 1.6, -right * 1.6, -fwd * 1.6]
	var waist := w.global_position + Vector3.UP * 1.0
	for k in views.size() * 2:
		var aim := head if k < views.size() else waist
		var off: Vector3 = views[k % views.size()]
		cam.global_position = aim + off * (1.0 if k < views.size() else 0.8) + Vector3.UP * 0.1
		cam.look_at(aim - Vector3.UP * 0.1, Vector3.UP)
		for _i in 4: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0].replace(".png", "_%d.png" % k))
	get_tree().quit()
