extends Node
## Renders a paired move across its whole length, without waiting for a match
## to climb the momentum ladder to it.
##
## Nothing rendered these. pin_shot.tscn drives begin_pin() directly and
## state_shot.tscn forces an FSM state, but a paired move goes through
## GrappleRig, needs both wrestlers, and only turns up once the ladder has been
## earned -- thousands of frames under a software rasteriser. So the signatures
## were being tuned on numbers alone, which is exactly how a move gets a legal
## trajectory and stops reading as the move.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/paired_shot.tscn -- \
##       --move signature_backbreaker --out /tmp/paired
##
## --at takes fractions of the move's length; the default walks the whole arc.
## --side frames the pair square-on from the side, perpendicular to the line
## between them, which is the view a throw's height and landing read from.
## --orbit DEG swings that side camera round the pair by DEG degrees (90 looks
## down the line between them), and --lit adds a fill light from the camera,
## because the arena lights a pair from above and behind and a probe frame
## reads as two silhouettes without it. Neither changes the move.

const MATCH_SCENE := "res://scenes/match.tscn"
const MOVES_DIR := "res://resources/moves"

var _out := "/tmp/paired"
var _move_id := "signature_backbreaker"
var _at: Array = [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
var _side := false
var _orbit := 0.0
var _lit := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--move" and i + 1 < args.size():
			_move_id = args[i + 1]
		elif args[i] == "--side":
			_side = true
		elif args[i] == "--orbit" and i + 1 < args.size():
			_orbit = float(args[i + 1])
		elif args[i] == "--lit":
			_lit = true
		elif args[i] == "--at" and i + 1 < args.size():
			_at = []
			for token: String in args[i + 1].split(","):
				_at.append(float(token))
	DirAccess.make_dir_recursive_absolute(_out)

	var scene: Node = load(MATCH_SCENE).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	attacker.is_ai = false
	defender.is_ai = false

	var move: MoveDef = load("%s/%s.tres" % [MOVES_DIR, _move_id])
	if move == null:
		print("!! no MoveDef at %s/%s.tres" % [MOVES_DIR, _move_id])
		get_tree().quit(1)
		return

	# Square them up at grapple distance first, the way a tie-up leaves them --
	# GrappleRig computes the pair frame from where the two bodies actually
	# are, so starting them scattered renders a different move.
	defender.global_position = attacker.global_position \
			- attacker.global_transform.basis.z * 0.9
	attacker.look_at(defender.global_position, Vector3.UP)
	defender.look_at(attacker.global_position, Vector3.UP)
	await get_tree().physics_frame

	var rig: Node = scene.get_node("GrappleRig")
	rig.begin(attacker, defender, move)
	print("PAIRED_SHOT %s" % _move_id)

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var focus := attacker.global_position + Vector3(0.0, 0.9, 0.0)
	camera.global_position = focus + Vector3(3.2, 1.4, 3.2)
	if _side:
		var mid := (attacker.global_position + defender.global_position) * 0.5
		var across := (defender.global_position - attacker.global_position) \
				.normalized().cross(Vector3.UP)
		across = across.rotated(Vector3.UP, deg_to_rad(_orbit))
		focus = mid + Vector3(0.0, 0.8, 0.0)
		camera.global_position = focus + across * 4.2 + Vector3(0.0, 0.3, 0.0)
		camera.fov = 45.0
	camera.look_at(focus, Vector3.UP)
	if _lit:
		var fill := DirectionalLight3D.new()
		scene.add_child(fill)
		fill.light_energy = 2.0
		fill.global_transform = camera.global_transform

	# Step the physics forward and grab at each fraction of the move. The
	# lowest bone is printed with every frame because "does it still read as
	# the move" and "does anybody go through the mat" are both being asked
	# here, and only one of them is answerable from a number.
	var total := int(move.total_frames())
	var grabbed := 0
	for frame in total + 4:
		await get_tree().physics_frame
		# MatchCamera takes `current` back when it cuts; hold the probe's.
		camera.current = true
		var fraction := float(frame) / float(total)
		if grabbed >= _at.size() or fraction < _at[grabbed]:
			continue
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s_%02d.png" % [_out, _move_id, int(_at[grabbed] * 100)])
		print("  t=%.2f  defender y=%.2f  attacker y=%.2f"
				% [fraction, defender.global_position.y, attacker.global_position.y])
		grabbed += 1
	get_tree().quit()
