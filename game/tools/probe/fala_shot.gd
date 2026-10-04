extends Node
## Roman's ula fala on him, standing and mid-stride, from the front, three-
## quarter, side and back -- the fit check for roman_props.py's fala and
## EntranceProps' placement. Lit by the arena, in the ring.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/fala_shot.tscn -- /tmp/fala [pose,pose]
##
## Writes <out>/fala_<pose>_<view>.png. The optional second argument is a
## comma list of pose names (default: all), the optional third of view names -- one pose per run keeps the
## renderer's memory down. Poses take a frame count: a clip is held that many
## frames in, so `raise_a`/`raise_b` catch the finger going up.

const VIEWS := {"front": 0.0, "three_q": 40.0, "side": 90.0, "back": 180.0,
		"close": 0.0, "close_q": 40.0, "close_back": 150.0}
const CLOSE := ["close", "close_q", "close_back"]
const POSES := [["stand", "strikes/roman_stand", 45], ["walk", "strikes/walk_crowd", 17],
		["walk2", "strikes/walk_crowd", 33],
		["raise_a", "strikes/finger_hold", 14], ["raise_b", "strikes/finger_hold", 26],
		["finger", "strikes/finger_hold", 70], ["title", "strikes/title_raise", 60],
		["hips", "strikes/hands_hips", 40], ["off", "strikes/ula_fala_off", 25]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/fala"
	var only: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	var views: PackedStringArray = args[2].split(",") if args.size() > 2 else PackedStringArray()
	DirAccess.make_dir_recursive_absolute(out)
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = false
	add_child(scene)
	for i in 3:
		await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	var other: WrestlerController = scene.get_node("WrestlerB")
	other.visible = false
	for n in [roman, other]:
		n.set_physics_process(false)
	roman.global_transform = Transform3D(Basis(Vector3.UP, PI), Vector3(0.0, roman.global_position.y, 0.0))
	var props := EntranceProps.dress(roman, false)
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.current = true
	cam.fov = 24.0
	for pose: Array in POSES:
		if not only.is_empty() and not only.has(pose[0]):
			continue
		roman.play_presentation_clip(pose[1], true)
		for i in int(pose[2]):
			await get_tree().process_frame
		for view: String in VIEWS:
			if not views.is_empty() and not views.has(view):
				continue
			var fwd := -roman.global_transform.basis.z
			var dir := fwd.rotated(Vector3.UP, deg_to_rad(VIEWS[view]))
			var chest := roman.global_position + Vector3.UP * 1.50
			var dist := 1.0 if CLOSE.has(view) else 1.9
			cam.global_position = chest + dir * dist + Vector3.UP * 0.2
			cam.look_at(chest, Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/fala_%s_%s.png" % [out, pose[0], view])
	print("FALA_SHOT done ", props != null)
	get_tree().quit()
