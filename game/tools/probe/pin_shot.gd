extends Node
## Renders the cover, without waiting for a match to reach one.
##
## The pin is the last thing on screen every match and was the worst-looking
## thing in a captured video -- the attacker standing beside the fallen man
## with a boot through his head while the referee counted. extreme_poses.gd
## deliberately does not cover the pin states ("they need the momentum ladder
## climbed first, which is thousands of frames under a software rasteriser"),
## which makes them exactly the states nobody was looking at.
##
## This drives begin_pin() directly instead: knock one man down, cover him,
## render. That exercises the real code path -- WrestlerController.begin_pin()
## and its placement -- rather than posing anything by hand, and it turns a
## thousands-of-frames wait into a couple of seconds, which is what makes
## iterating on the pose possible at all.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1280x720 tools/probe/pin_shot.tscn -- --out /tmp/pin
##
## Add --scene to point it at another model's match scene.

const DEFAULT_MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/pin"
var _scene_path := DEFAULT_MATCH_SCENE
## --match-camera: judge the shot the MATCH camera actually takes, instead of
## the three hand-placed angles below.
##
## Those three answer "is the cover pose right", which is what this probe was
## built for and which they still do. They cannot answer "can a viewer SEE the
## cover", because they are not the camera a player looks through -- and the
## recorded match showed the three-count shot from under the canvas, with the
## cover hidden behind the near mat edge for the whole count.
##
## In this mode the pin is started by the REFEREE rather than by calling
## begin_pin() directly, because MatchCamera cuts on referee.is_pin_active()
## and a hand-driven pin never sets it.
var _match_camera := false
## --at-edge: put the cover near the ring edge instead of near centre.
##
## Load-bearing, not a nicety. Shot at ring centre the three-count framing is
## FINE -- the cover is clear and well composed. The defect in the recorded
## match only appears where that match's pin happened, out by the ropes, where
## the camera sits at min_distance BEYOND the apron and the near mat edge rises
## into the sight line. A probe that only ever shoots the middle of the ring
## would have reported no problem and been believed.
var _at_edge := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--scene" and i + 1 < args.size():
			_scene_path = args[i + 1]
		elif args[i] == "--match-camera":
			_match_camera = true
		elif args[i] == "--at-edge":
			_at_edge = true
	DirAccess.make_dir_recursive_absolute(_out)

	var scene: Node = load(_scene_path).instantiate()
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var attacker: WrestlerController = scene.get_node("WrestlerA")
	var defender: WrestlerController = scene.get_node("WrestlerB")
	# Both on the AI so neither stands inert waiting for a player.
	attacker.is_ai = true
	defender.is_ai = true

	# Let the match settle a moment so the pair are on the mat and squared up
	# rather than at their spawn transforms.
	for frame in 30:
		await get_tree().process_frame

	# Walk both men to the states the pin legally starts from. The FSM asserts
	# on an illegal transition (it caught STRIKE -> DOWN here), and the pin is
	# entered from IDLE on the attacker's side and from DOWN on the defender's,
	# so the route is IDLE -> STUNNED -> DOWN rather than a jump straight to it.
	# The AI is switched off first so nothing transitions them back out from
	# under the shot.
	attacker.is_ai = false
	defender.is_ai = false
	attacker.fsm.transition_to(WrestlerFSM.State.IDLE)
	defender.fsm.transition_to(WrestlerFSM.State.IDLE)
	await get_tree().process_frame
	defender.fsm.transition_to(WrestlerFSM.State.STUNNED)
	defender.fsm.transition_to(WrestlerFSM.State.DOWN)
	await get_tree().process_frame
	if _match_camera:
		await _shoot_match_camera(scene, attacker, defender)
		get_tree().quit()
		return

	attacker.begin_pin(defender, 1)
	# A few frames so the cross-fade into the cover finishes; a frame grabbed
	# on the transition tick shows the blend, not the pose.
	for frame in 20:
		await get_tree().process_frame

	print("PIN_SHOT attacker=%s defender=%s" % [
			WrestlerFSM.State.keys()[attacker.fsm.current_state],
			WrestlerFSM.State.keys()[defender.fsm.current_state]])
	print("PIN_SHOT separation %.3f m" % attacker.global_position
			.distance_to(defender.global_position))
	# Where the prone man's head actually is, in his OWN frame. The cover
	# offset has to be expressed against this rather than guessed: a prone
	# body's node rotation is still its standing yaw, so which way along z the
	# head lies is not something to assume -- the first attempt put the coverer
	# down by the boots.
	var skel: Skeleton3D = defender.find_child("Skeleton3D", true, false)
	if skel:
		for bone_name: String in ["Head", "pelvis", "foot_l"]:
			var bi := skel.find_bone(bone_name)
			if bi < 0:
				continue
			var world: Vector3 = skel.global_transform * skel.get_bone_global_pose(bi).origin
			var local: Vector3 = defender.global_transform.affine_inverse() * world
			print("  defender %-7s local=(%+.3f, %+.3f, %+.3f)"
					% [bone_name, local.x, local.y, local.z])

	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var focus := defender.global_position + Vector3(0.0, 0.4, 0.0)
	# Three angles, because a cover can read from one and be a mess from the
	# next: side-on is where interpenetration shows, the low angle is where a
	# body floating off the mat shows.
	var shots := {
		"side": focus + Vector3(2.6, 1.5, 0.0),
		"three_quarter": focus + Vector3(2.0, 1.7, 2.0),
		"low": focus + Vector3(0.0, 0.5, 2.8),
	}
	for name: String in shots:
		camera.global_position = shots[name]
		camera.look_at(focus, Vector3.UP)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/pin_%s.png" % [_out, name])
		print("  wrote %s/pin_%s.png" % [_out, name])
	get_tree().quit()


## Grabs the three-count through the scene's own MatchCamera.
##
## The attacker is left standing in cover range and IDLE and the referee's
## _check_for_downed_opponent_action() starts the pin itself on the next tick,
## which is what sets _pinning and makes MatchCamera cut to THREE_COUNT_CUT.
## Frames are taken at the counts themselves (MatchReferee.COUNT_TICKS) so the
## shot is judged at the moments a viewer is actually looking at it.
func _shoot_match_camera(scene: Node, attacker: WrestlerController,
		defender: WrestlerController) -> void:
	var referee: MatchReferee = scene.get_node("MatchReferee")
	if _at_edge:
		# RingBuilder's mat is 6 m square, so 2.6 m out is up against the
		# ropes -- where a real match's finish often lands, and where the
		# camera has to shoot across the apron to see anything.
		var shift := Vector3(2.6 - defender.global_position.x, 0.0, 0.0)
		defender.global_position += shift
		attacker.global_position += shift
	# Inside COVER_RANGE (1.2 m) so the referee's own check fires.
	attacker.global_position = defender.global_position \
			+ (attacker.global_position - defender.global_position).normalized() * 0.9
	var grabbed := 0
	var tick := 0
	var counts: Array = [10, 40, 92, 167, 227]
	while tick <= 240 and grabbed < counts.size():
		await get_tree().physics_frame
		tick += 1
		if tick == counts[grabbed]:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s/count_t%03d.png" % [_out, tick])
			print("  t%03d pinning=%s count=%d -> %s/count_t%03d.png" % [
					tick, referee.is_pin_active(), referee.pin_count(),
					_out, tick])
			grabbed += 1
