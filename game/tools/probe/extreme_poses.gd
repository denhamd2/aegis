extends Node3D
## Does the hair or beard break in the poses the standing shotlist never
## reaches -- flat on the mat, mid-move, mid hit-reaction?
##
## Kept rather than deleted, alongside roman_shots.gd, because the question it
## answers recurs every time the model or the rig changes. The hair and beard
## are skinned to a DIFFERENT skeleton from the body (471 bones against 114),
## which is the split that caused the bald crown, so "do the two still agree
## when the body is somewhere unusual" is a standing regression risk rather
## than a one-off.
##
## Usage:
##   xvfb-run -a --server-args="-screen 0 800x600x24" godot4 --path game \
##       --rendering-driver vulkan --resolution 800x600 \
##       tools/probe/extreme_poses.tscn -- --out /tmp/extreme
##
## Slow under a software rasteriser -- it has to play a real match until the
## states turn up -- so run it in the background and come back to it.
##
## Attachment is already proven stable through 200 frames of standing and
## grappling. What that cannot show is clipping: a head on the canvas, or a
## body inverted mid-slam, is where hair on its own skeleton would push
## through the mat or through the opponent. This waits for the match to enter
## each state on its own and frames the head there rather than posing anything
## by hand, so what is captured is what a player would actually see.

const MATCH_SCENE := "res://scenes/roman_match.tscn"
## States worth a frame, and all reachable early in a match. The pin and
## submission states are deliberately NOT here: they need the momentum ladder
## climbed first, which is thousands of frames under a software rasteriser.
## Add them when there is a GPU to run this on.
const WANTED := ["DOWN", "MOVE_EXEC", "HIT_REACT", "GETUP"]

## Give up rather than run forever if a state never arrives.
const MAX_FRAMES := 500

var _out := "/tmp/extreme"
var _seen := {}
var _scene: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	_scene = load(MATCH_SCENE).instantiate()
	add_child(_scene)
	await get_tree().process_frame

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 34.0

	for frame in MAX_FRAMES:
		await get_tree().process_frame
		if _seen.size() >= WANTED.size():
			break
		for slot in ["WrestlerA", "WrestlerB"]:
			var w: Node = _scene.get_node_or_null(slot)
			if w == null or w.fsm == null:
				continue
			var name_of: String = String(WrestlerFSM.State.keys()[w.fsm.current_state])
			if not WANTED.has(name_of) or _seen.has(name_of):
				continue
			var head: Variant = _head_aabb(w)
			if head == null:
				continue
			var h: AABB = head
			_seen[name_of] = frame
			# Stand off the head at 3/4, high enough to see the crown, which
			# is where hair would punch through if it were going to.
			cam.global_position = h.get_center() + Vector3(0.55, 0.28, 0.55)
			cam.look_at(h.get_center(), Vector3.UP)
			await get_tree().process_frame
			get_viewport().get_texture().get_image().save_png(
				"%s/%s_%s.png" % [_out, name_of, slot])
			print("EXTREME %-14s %s at frame %d" % [name_of, slot, frame])
	print("EXTREME captured %d of %d states: %s" % [
		_seen.size(), WANTED.size(), str(_seen.keys())])
	get_tree().quit()


func _head_aabb(w: Node) -> Variant:
	for node in w.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if String(mi.name) == "head_skinned" and mi.mesh:
			return mi.global_transform * mi.get_aabb()
	return null
