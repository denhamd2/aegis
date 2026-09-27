extends Node3D
## The AEW title on its own, under a neutral studio three-point rig, from the
## seven angles the owner's texture brief asks for: front, three-quarter,
## side, and close-ups of the centre plate, a side plate, the leather and the
## snaps. The belt is the HELD shape -- straight, plates to camera.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/belt_shot.tscn -- /tmp/belt
##
## Writes /tmp/belt_<view>.png. Lighting per the blender-lighting skill's
## three-point recipe for metal: warm key, cool fill at a quarter, a rim.

const VIEWS := {
	"front": [Vector3(0.0, 0.0, -1.55), Vector3.ZERO, 40.0],
	"three_quarter": [Vector3(0.9, 0.2, -1.2), Vector3.ZERO, 40.0],
	"side": [Vector3(1.4, 0.05, -0.12), Vector3(0.0, 0.0, 0.0), 40.0],
	"centre_close": [Vector3(0.0, 0.0, -0.45), Vector3(0.0, 0.0, 0.0), 40.0],
	"side_plate_close": [Vector3(0.28, 0.0, -0.30), Vector3(0.225, 0.0, 0.0), 40.0],
	"leather_close": [Vector3(-0.47, 0.02, -0.16), Vector3(-0.47, 0.0, 0.0), 40.0],
	"snaps_close": [Vector3(-0.50, 0.0, -0.22), Vector3(-0.505, 0.0, 0.0), 40.0],
}


func _ready() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "/tmp/belt"
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.09, 0.09, 0.10)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.35, 0.35, 0.38)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	add_child(env)
	_light(Vector3(1.2, 1.0, -1.4), Color(1.0, 0.93, 0.82), 4.0)    # key
	_light(Vector3(-1.3, 0.4, -1.0), Color(0.85, 0.9, 1.0), 1.0)    # fill
	_light(Vector3(0.0, 1.2, 1.4), Color(0.9, 0.93, 1.0), 2.5)      # rim
	var belt: Node3D = (load(EntranceProps.TITLE) as PackedScene).instantiate()
	add_child(belt)
	var mats := EntranceProps._materials()
	for mi: MeshInstance3D in belt.find_children("*", "MeshInstance3D", true, false):
		mi.visible = String(mi.name).begins_with("Held")
		if mats.has(String(mi.name)):
			mi.material_override = mats[String(mi.name)]
	# The held belt's grip is its origin; centre the plates on the world origin.
	belt.position = Vector3(0.0, 0.08, 0.02)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	for view: String in VIEWS:
		var v: Array = VIEWS[view]
		cam.fov = v[2]
		cam.global_position = v[0]
		cam.look_at(v[1], Vector3.UP)
		for _i in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%s.png" % [out, view])
	get_tree().quit()


func _light(at: Vector3, color: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = 6.0
	add_child(l)
	l.position = at
