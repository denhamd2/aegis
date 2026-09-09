extends Node
## Renders a named FSM state, full body, without waiting for a match to reach it.
##
## extreme_poses.gd waits for states to turn up in a live match and frames the
## HEAD, which is the right tool for "does the hair punch through the scalp".
## It is the wrong tool for "is this whole pose broken", and the states it
## cannot reach at all (the pin, and anything up the momentum ladder) are
## exactly the ones nobody has looked at. This forces the state instead and
## frames the whole wrestler.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/state_shot.tscn -- \
##       --states DOWN,GETUP,STRIKE --out /tmp/states
##
## The FSM asserts on an illegal transition, so each state is reached by a
## legal route rather than jumped to -- see ROUTES.

## How to get to a state from IDLE. Every entry is a legal chain through
## wrestler_fsm.gd's own table; a state missing from here cannot be forced and
## says so rather than tripping the assert.
const ROUTES := {
	"IDLE": [],
	"LOCOMOTION": ["LOCOMOTION"],
	"RUN": ["RUN"],
	"STRIKE": ["STRIKE"],
	"TIE_UP": ["TIE_UP"],
	"GRAPPLE_HOLD": ["TIE_UP", "GRAPPLE_HOLD"],
	"HIT_REACT": ["HIT_REACT"],
	"STUNNED": ["STUNNED"],
	"DOWN": ["STUNNED", "DOWN"],
	"GETUP": ["STUNNED", "DOWN", "GETUP"],
}

var _out := "/tmp/states"
var _scene_path := "res://scenes/match.tscn"
var _states: Array = ["DOWN", "GETUP", "STRIKE", "HIT_REACT"]
## Frames after entering the state at which to grab, so a whole state can be
## looked at rather than one instant of it.
var _at_frames: Array = [2, 8, 16, 24, 32]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--scene" and i + 1 < args.size():
			_scene_path = args[i + 1]
		elif args[i] == "--states" and i + 1 < args.size():
			_states = Array(args[i + 1].split(","))
		elif args[i] == "--at" and i + 1 < args.size():
			_at_frames = []
			for token: String in args[i + 1].split(","):
				_at_frames.append(int(token))
	DirAccess.make_dir_recursive_absolute(_out)

	var scene: Node = load(_scene_path).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var subject: WrestlerController = scene.get_node("WrestlerA")
	var other: WrestlerController = scene.get_node("WrestlerB")
	subject.is_ai = false
	other.is_ai = false
	# Out of shot, so the frame is about one man's pose.
	other.global_position = Vector3(0.0, 0.0, 12.0)

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true

	for state_name: String in _states:
		if not ROUTES.has(state_name):
			print("!! no route to %s -- add one to ROUTES" % state_name)
			continue
		subject.fsm.transition_to(WrestlerFSM.State.IDLE)
		await get_tree().process_frame
		for step: String in ROUTES[state_name]:
			subject.fsm.transition_to(WrestlerFSM.State[step])
		# Sampled ACROSS the state, not once inside it. A single grab is what
		# hid this: two frames in, GETUP looks like a man standing up, and the
		# defect -- he tucks into a ball on the mat for about half a second
		# first -- is entirely in the middle of the clip. These are also short
		# states that time out into the next one (at 12 frames DOWN reported
		# GETUP and GETUP reported IDLE), so the reached state is printed with
		# every frame rather than assumed to still be the one asked for.
		var elapsed := 0
		for offset: int in _at_frames:
			while elapsed < offset:
				await get_tree().process_frame
				elapsed += 1
			var reached := String(WrestlerFSM.State.keys()[subject.fsm.current_state])
			var focus := subject.global_position + Vector3(0.0, 0.6, 0.0)
			camera.global_position = focus + Vector3(2.4, 1.1, 2.4)
			camera.look_at(focus, Vector3.UP)
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.save_png("%s/state_%s_at%02d.png" % [_out, state_name, offset])
			print("STATE_SHOT %-12s at=%2d reached=%s" % [state_name, offset, reached])
	get_tree().quit()
