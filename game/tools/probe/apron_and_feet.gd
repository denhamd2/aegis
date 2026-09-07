extends Node3D
## Two questions that a wide frame cannot answer, answered on the same run.
##
## 1. Is the banner fully visible on the apron? Godot's BoxMesh unwraps into a
##    3x2 atlas and cropped it to a third of its width; the mesh is a QuadMesh
##    now and this frames one apron side square-on so the whole artwork can be
##    checked rather than inferred from a distant frame.
##
## 2. Are the wrestlers standing on the mat, or floating? Reported as a doubt
##    off a screenshot, which cannot settle it -- a foot a centimetre above the
##    canvas and a foot on it are the same pixels at that distance. This reads
##    the lowest vertex of each wrestler's rendered mesh in world space and
##    prints its height against the mat surface at y = 0.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/apron_and_feet.tscn -- --out /tmp/x

const MATCH_SCENE := "res://scenes/play.tscn"

var _out := "/tmp/apron"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load(MATCH_SCENE).instantiate()
	add_child(scene)
	await get_tree().process_frame

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 40.0
	# Square-on to the north apron, low, so the skirt fills the frame.
	cam.global_position = Vector3(0.0, -0.5, 8.6)
	cam.look_at(Vector3(0.0, -0.65, 3.15), Vector3.UP)

	for _i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/apron.png" % _out)

	# Let the match settle so the wrestlers are in a real standing pose, not
	# their spawn frame, before asking where their feet are.
	for _i in 90:
		await get_tree().process_frame
	for slot in ["WrestlerA", "WrestlerB"]:
		var w: Node = scene.get_node_or_null(slot)
		if w == null:
			continue
		var lowest := INF
		var lowest_mesh := ""
		for node in w.find_children("", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null or not mi.visible:
				continue
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			if aabb.position.y < lowest:
				lowest = aabb.position.y
				lowest_mesh = String(mi.name)
		print("FEET %-10s lowest_vertex_y=%+.4f  (mat surface is y=0)  mesh=%s  origin_y=%+.4f" % [
			slot, lowest, lowest_mesh, w.global_position.y])
	get_tree().quit()
