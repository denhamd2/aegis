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
##       tools/probe/extreme_poses.tscn -- --out /tmp/extreme \
##       [--scene res://scenes/<name>_match.tscn]
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

## Default scene. Override with --scene for another wrestler: the question this
## probe answers -- does anything clip or detach in the poses a standing shotlist
## never reaches -- recurs for every model, not just Roman's.
const DEFAULT_MATCH_SCENE := "res://scenes/roman_match.tscn"
## States worth a frame, and all reachable early in a match. The pin and
## submission states are deliberately NOT here: they need the momentum ladder
## climbed first, which is thousands of frames under a software rasteriser.
## Add them when there is a GPU to run this on.
const WANTED := ["DOWN", "MOVE_EXEC", "HIT_REACT", "GETUP"]

## Give up rather than run forever if a state never arrives. Overridable with
## --frames: how long a state takes to turn up depends on the match, and a
## budget that is too small looks exactly like a model with no defects.
const DEFAULT_MAX_FRAMES := 500

## Head bone, by whichever name the model's rig uses.
const HEAD_BONES := ["Head", "J_Head", "head"]

## Box drawn around the head bone for framing, in metres.
const HEAD_BOX := Vector3(0.34, 0.36, 0.34)

## Where the camera stands relative to the head: a three-quarter view from
## above, far enough back to show the shoulders and the mat under a downed
## wrestler, which is where clothing and hair push through if they are going to.
const STANDOFF := Vector3(0.75, 0.45, 0.75)

var _out := "/tmp/extreme"
var _match_scene := DEFAULT_MATCH_SCENE
var _max_frames := DEFAULT_MAX_FRAMES
var _seen := {}
var _scene: Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--scene" and i + 1 < args.size():
			_match_scene = args[i + 1]
		elif args[i] == "--frames" and i + 1 < args.size():
			_max_frames = args[i + 1].to_int()
	DirAccess.make_dir_recursive_absolute(_out)
	print("extreme_poses: %s" % _match_scene)
	_scene = load(_match_scene).instantiate()
	add_child(_scene)
	await get_tree().process_frame

	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 34.0

	for frame in _max_frames:
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
			# Claim the viewport immediately before the shot. The match scene
			# owns a camera of its own and makes it current, so a probe camera
			# set current once at startup quietly loses it and every capture
			# comes back as the broadcast view of an empty ring.
			cam.current = true
			cam.global_position = h.get_center() + STANDOFF
			cam.look_at(h.get_center(), Vector3.UP)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"%s/%s_%s.png" % [_out, name_of, slot])
			print("EXTREME %-14s %s at frame %d" % [name_of, slot, frame])
	print("EXTREME captured %d of %d states: %s" % [
		_seen.size(), WANTED.size(), str(_seen.keys())])
	if _seen.is_empty():
		print("EXTREME !! nothing was captured. Either no wanted state arrived "
			+ "within %d frames (raise --frames), or the head bone was not "
			% _max_frames + "found on this rig (looked for %s)." % str(HEAD_BONES))
	get_tree().quit()


## A box around the head, framed off the head BONE rather than off a mesh name.
##
## This used to look for a MeshInstance3D called "head_skinned", which is a name
## the Roman asset happens to use. Every other model fails that test silently:
## the Cody model joins its parts into one mesh called "Body", so the lookup
## returned null on every frame, every capture was skipped, and the probe
## reported success having written no files at all. A bone name is the right
## key because the rig is the thing this project controls -- the mesh names come
## from whoever exported the asset.
func _head_aabb(w: Node) -> Variant:
	var skeleton := w.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		return null
	var index := -1
	for candidate in HEAD_BONES:
		index = skeleton.find_bone(candidate)
		if index >= 0:
			break
	if index < 0:
		return null
	var head := (skeleton.global_transform
			* skeleton.get_bone_global_pose(index)).origin
	return AABB(head - HEAD_BOX * 0.5, HEAD_BOX)
