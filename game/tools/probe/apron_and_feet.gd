extends Node3D
## Two questions a wide frame cannot answer.
##
## 1. Is the apron banner complete, correctly sized and centred?
## 2. Are the wrestlers standing on the canvas, or floating above it?
##
## TWO WAYS OF ANSWERING (2) THAT DO NOT WORK, both tried here first, because
## each looks authoritative and neither is:
##
##   MESH AABB. The first version read MeshInstance3D.get_aabb() on the shoe
##   mesh and reported -0.0121 / -0.0130 as settled. For a SKINNED mesh that
##   returns the mesh's own bounds, which are the REST POSE -- it does not
##   follow the animation. The tell: both wrestlers reported the same two
##   numbers in completely different poses, across separate runs.
##
##   BONE GLOBAL POSE. skeleton.global_transform * get_bone_global_pose() does
##   move with the animation, but the heights it returns do not agree with the
##   rendered frame: during a strike it put J_Head BELOW J_Hips with the feet
##   above both, which would be an upside-down wrestler, while the render of
##   that same frame shows him upright. Whatever space those poses are in, it
##   is not the one the mesh is drawn in, so the numbers cannot be used as
##   ground clearance. They are not printed here, to stop them being quoted.
##
## WHAT DOES WORK is making the question visual and unambiguous: put the
## camera above and outside, look down at the feet so the near-white canvas
## fills the frame behind them, and let a black boot silhouette against a
## white mat answer it. A gap of even a centimetre is obvious; contact is
## obvious. unproject_position() prints where the mat plane directly under
## each wrestler lands on screen, so the reference line is a number rather
## than a guess.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 800x500 tools/probe/apron_and_feet.tscn -- --out /tmp/x

const MATCH_SCENE := "res://scenes/play.tscn"
## Grounded states worth a frame. A wrestler in DOWN, GETUP or a pin is
## legitimately not standing, so a gap there proves nothing.
const WANTED := ["IDLE", "STRIKE"]
const MAX_FRAMES := 400

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

	# --- The apron, square-on and low, so the whole skirt fills the frame.
	cam.fov = 40.0
	cam.global_position = Vector3(0.0, -0.5, 8.6)
	cam.look_at(Vector3(0.0, -0.65, 3.15), Vector3.UP)
	for _i in 8:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/apron.png" % _out)

	# --- The feet, against the canvas.
	cam.fov = 20.0
	var taken := {}
	for frame in MAX_FRAMES:
		await get_tree().process_frame
		for slot in ["WrestlerA", "WrestlerB"]:
			var w: Node = scene.get_node_or_null(slot)
			if w == null or w.fsm == null:
				continue
			var state: String = String(WrestlerFSM.State.keys()[w.fsm.current_state])
			var key := "%s_%s" % [slot, state]
			if not WANTED.has(state) or taken.has(key):
				continue
			taken[key] = true
			var p: Vector3 = w.global_position
			cam.global_position = Vector3(p.x + 2.2, 1.15, p.z + 2.2)
			cam.look_at(Vector3(p.x, 0.05, p.z), Vector3.UP)
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png("%s/feet_%s.png" % [_out, key])
			# The mat plane under him, and 10cm above it, as screen rows: the
			# scale bar for reading the saved frame.
			var mat_row := cam.unproject_position(Vector3(p.x, 0.0, p.z)).y
			var up10_row := cam.unproject_position(Vector3(p.x, 0.10, p.z)).y
			print("FEET %-20s frame=%3d  capsule_origin_y=%+.4f  mat plane at screen row %.1f, 1cm = %.2f rows" % [
				key, frame, p.y, mat_row, (mat_row - up10_row) / 10.0])
		if taken.size() >= 4:
			break
	print("FEET captured: %s" % str(taken.keys()))
	get_tree().quit()
