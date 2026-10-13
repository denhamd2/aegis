extends Node3D
## Renders the weapon wheel's icons: every weapon in the catalogue, its held
## state, three-quarter view, on a transparent background, into
## assets/weapons/icons/<id>.png. Re-run when a weapon model changes.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 256x256 tools/probe/weapon_icons.tscn

const OUT := "res://assets/weapons/icons/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Its own viewport: transparent and exactly square, which the window is
	# neither.
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	var world := WorldEnvironment.new()
	world.environment = env
	vp.add_child(world)
	for spec in [[Vector3(-45, 145, 0), 1.3], [Vector3(-20, 30, 0), 0.6]]:
		var light := DirectionalLight3D.new()
		vp.add_child(light)
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	cam.fov = 30.0
	for d in WeaponCatalog.all():
		var a := WeaponActor.make(d)
		vp.add_child(a)
		var box := _bounds(a)
		var centre := box.get_center()
		var reach := maxf(box.size.length(), 0.15)
		# from the front (the weapons face -Z), a little to the right, above
		cam.global_position = centre + Vector3(0.75, 0.5, -0.85).normalized() * reach * 1.95
		cam.look_at(centre, Vector3.UP)
		for i in 12:
			await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path(OUT + String(d.id) + ".png"))
		print("ICON %s" % d.id)
		a.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for node in n.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if not mi.is_visible_in_tree():
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
