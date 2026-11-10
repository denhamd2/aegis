extends Node3D
## A table (or the glass) going, on a bare stage: the set piece stood up,
## shattered, and grabbed at a few ticks after -- to look at the pieces and
## the debris in the air and where they come to rest.
##
##   xvfb-run -a godot --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/break_shot.tscn -- \
##       --id table --out /tmp/break [--ticks 4,14,40,150]

var _id := &"table"
var _out := "/tmp/break"
var _ticks: Array[int] = [4, 14, 40, 150]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--id": _id = StringName(args[i + 1])
			"--out": _out = args[i + 1]
			"--ticks":
				_ticks.clear()
				for t: String in args[i + 1].split(","):
					_ticks.append(int(t))
	DirAccess.make_dir_recursive_absolute(_out)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.17, 0.2)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12, 12)
	floor.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.33, 0.34, 0.36)
	floor.material_override = mat
	# Ring centre: WeaponActor.ground_under reads the mat there, at y 0.
	var at := Vector3.ZERO
	floor.position = at
	add_child(floor)
	var cam := Camera3D.new()
	cam.fov = 45.0
	add_child(cam)
	cam.global_position = at + Vector3(2.4, 1.5, 2.6)
	cam.look_at(at + Vector3(0, 0.45, 0), Vector3.UP)
	cam.current = true
	await get_tree().process_frame
	var w := WeaponActor.make(WeaponCatalog.by_id(_id))
	add_child(w)
	w.set_up_at(at, 0.0)
	for i in 10:
		await get_tree().physics_frame
	await _grab("before")
	w.shatter(7)
	var tick := 0
	for want in _ticks:
		while tick < want:
			await get_tree().physics_frame
			tick += 1
		await _grab("t%03d" % want)
	get_tree().quit()


func _grab(label: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _id, label])
	print("WROTE ", label)
