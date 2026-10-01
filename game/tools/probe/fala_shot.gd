extends Node
## Roman's ula fala on him, standing and mid-stride, from the front, three-
## quarter, side and back -- the fit check for roman_props.py's fala and
## EntranceProps' placement. Lit by the arena, in the ring.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 960x540 tools/probe/fala_shot.tscn -- /tmp/fala
##
## Writes <out>/fala_<pose>_<view>.png.

const VIEWS := {"front": 0.0, "three_q": 40.0, "side": 90.0, "back": 180.0}
const POSES := [["stand", "strikes/roman_stand", 20], ["walk", "strikes/walk_crowd", 17],
		["walk2", "strikes/walk_crowd", 33]]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/fala"
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
	cam.fov = 26.0
	for pose: Array in POSES:
		roman.play_presentation_clip(pose[1], true)
		for i in int(pose[2]):
			await get_tree().process_frame
		for view: String in VIEWS:
			var fwd := -roman.global_transform.basis.z
			var dir := fwd.rotated(Vector3.UP, deg_to_rad(VIEWS[view]))
			var chest := roman.global_position + Vector3.UP * 1.55
			cam.global_position = chest + dir * 2.4 + Vector3.UP * 0.25
			cam.look_at(chest, Vector3.UP)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/fala_%s_%s.png" % [out, pose[0], view])
	print("FALA_SHOT done ", props != null)
	get_tree().quit()
