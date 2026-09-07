extends Node
## Renders a look-at-him shotlist of the Roman model in a live match.
##
##   xvfb-run -a --server-args="-screen 0 1600x900x24" godot4 \
##       --path game --rendering-driver vulkan --resolution 1600x900 \
##       tools/probe/roman_shots.tscn -- --out /tmp/shots
##
## Not the same job as CaptureHarness's --art-shots, which is why this is a
## separate tool rather than more entries in ART_SHOTS. That shotlist has six
## *fixed* world-space cameras aimed at the arena and fires them on the
## frozen spawn standoff, deliberately: fixed cameras on a fixed pose are
## what makes round N and round N-1 comparable frame for frame when judging
## a surface. This one is the opposite on both counts -- cameras placed
## relative to wherever the wrestler actually is, at beats the match reaches
## on its own -- because the question here is "what does he look like in
## play", not "did the ring change since last round".
##
## Runs in the real match scene, like every other camera tool in this
## project, for the reason documented on CaptureHarness._silhouette_step():
## a `-s` SceneTree script does not register the project's class_name
## globals, so _apply_colorway() never runs and the wrestlers render in the
## .glb's own gold.
##
## Renders on forward_plus via the Vulkan driver -- the pipeline the game
## ships. Under xvfb that is llvmpipe, i.e. software-rasterised, which
## ARCHITECTURE.md's renderer rule allows for a visual look (carrying the
## software_rasterised caveat) and forbids for any performance claim.

const MATCH_SCENE := "res://scenes/roman_match.tscn"

## Physics ticks to let the match run before the first beat. The
## reachability probe measured the opening tie-up landing around tick 51, so
## everything here is well past the spawn standoff and into real play.
const BEATS := [
	{"tick": 1, "label": "faceoff"},
	{"tick": 70, "label": "tieup"},
	{"tick": 190, "label": "action"},
	{"tick": 320, "label": "exchange"},
	{"tick": 520, "label": "action2"},
]

## Two-shots framing both wrestlers at once, for the face-off. Placed
## relative to the midpoint between them and the axis they are squared up
## on, so the pair stays centred however far apart they have drifted --
## a fixed world camera would frame the ring, not the confrontation.
##
## bearing_deg is measured off the A->B axis: 90 is broadside (both men in
## profile, the classic stare-down framing), 0 would be looking down the axis
## with one man hidden behind the other.
##
## Swung past 90 toward the west side so these agree with BROADCAST_SHOTS and
## with the game camera: the lens still faces the crowd, and the entrance
## stage on -Z comes round to frame-left rather than sitting directly behind
## the camera. Straight broadside kept the stage out of shot but put it at six
## o'clock, which is not the framing asked for.
const PAIR_SHOTS := [
	{"name": "pair_broadside", "bearing_deg": 118.0, "distance": 4.8,
		"height": 1.65, "look_height": 1.25, "fov": 38.0},
	{"name": "pair_broadside_low", "bearing_deg": 118.0, "distance": 4.2,
		"height": 0.70, "look_height": 1.30, "fov": 42.0},
	{"name": "pair_three_quarter", "bearing_deg": 138.0, "distance": 4.6,
		"height": 1.80, "look_height": 1.20, "fov": 40.0},
	{"name": "pair_over_shoulder", "bearing_deg": 152.0, "distance": 3.6,
		"height": 1.72, "look_height": 1.55, "fov": 44.0},
	{"name": "pair_high", "bearing_deg": 110.0, "distance": 4.4,
		"height": 3.10, "look_height": 1.00, "fov": 44.0},
]

## Frames to let the renderer settle after a camera jump before saving. The
## first frame after a jump can still carry the previous view's temporal
## state (SSAO/SSR history), and a shot saved into that is not the shot
## asked for -- same reason CaptureHarness uses ART_SETTLE_FRAMES.
const SETTLE_FRAMES := 4

## The per-beat shotlist, in the subject's own frame rather than world
## space: "forward" is the way he is facing, so a portrait stays a portrait
## wherever he has walked to and whichever way he has turned.
##
## height is metres up from his feet; distance is metres out along the
## chosen bearing; yaw_deg is measured off his facing (0 = dead in front,
## 90 = his left side, 180 = behind him).
const SHOTS := [
	{"name": "face_front", "yaw_deg": 8.0, "distance": 1.05, "height": 1.62,
		"look_height": 1.58, "fov": 34.0},
	{"name": "face_three_quarter", "yaw_deg": 42.0, "distance": 1.15,
		"height": 1.60, "look_height": 1.55, "fov": 34.0},
	{"name": "face_profile", "yaw_deg": 88.0, "distance": 1.20, "height": 1.58,
		"look_height": 1.54, "fov": 36.0},
	{"name": "torso_three_quarter", "yaw_deg": 35.0, "distance": 2.05,
		"height": 1.35, "look_height": 1.15, "fov": 40.0},
	{"name": "full_body_front", "yaw_deg": 15.0, "distance": 3.60,
		"height": 1.30, "look_height": 1.00, "fov": 42.0},
	{"name": "full_body_back", "yaw_deg": 168.0, "distance": 3.40,
		"height": 1.35, "look_height": 1.05, "fov": 42.0},
	{"name": "low_hero", "yaw_deg": 25.0, "distance": 2.60, "height": 0.45,
		"look_height": 1.45, "fov": 46.0},
	{"name": "high_over", "yaw_deg": 60.0, "distance": 2.40, "height": 2.85,
		"look_height": 1.00, "fov": 46.0},
	# QA framings. Tight on the head from three sides to judge beard, eyes,
	# nose, brows and hairline, and tight on the legs from two to check
	# nothing is erupting through the trousers or boots.
	{"name": "qa_head_front", "yaw_deg": 4.0, "distance": 0.62, "height": 1.66,
		"look_height": 1.62, "fov": 30.0},
	{"name": "qa_head_quarter", "yaw_deg": 38.0, "distance": 0.66,
		"height": 1.65, "look_height": 1.60, "fov": 30.0},
	{"name": "qa_head_side", "yaw_deg": 92.0, "distance": 0.70, "height": 1.63,
		"look_height": 1.58, "fov": 32.0},
	{"name": "qa_head_back", "yaw_deg": 172.0, "distance": 0.74, "height": 1.66,
		"look_height": 1.60, "fov": 32.0},
	{"name": "qa_legs_front", "yaw_deg": 10.0, "distance": 1.85, "height": 0.62,
		"look_height": 0.48, "fov": 40.0},
	{"name": "qa_legs_side", "yaw_deg": 86.0, "distance": 1.95, "height": 0.60,
		"look_height": 0.46, "fov": 40.0},
	{"name": "qa_boots", "yaw_deg": 30.0, "distance": 1.05, "height": 0.42,
		"look_height": 0.14, "fov": 38.0},
]

## Broadcast framings, in world space and fixed -- this is the angle the
## match is actually watched from, so it should not follow him around.
## wide_broadcast matches CaptureHarness.ART_SHOTS' entry of the same name
## (the framing refs/frames/wide_standoff_broadcast_angle.jpg was shot at),
## so these two are directly comparable; the rest tighten in on the action.
## These sat on +Z looking toward -Z, which points the lens straight down the
## entrance ramp: the stage filled the background of every broadcast frame.
## They are on the west side now, matching the anchor the game's own
## MatchCamera is parked on in match.tscn -- camera at -X looking toward +X,
## so the crowd bank fills frame centre and the -Z stage sits off frame-left,
## at nine o'clock, instead of behind the ring.
const BROADCAST_SHOTS := [
	{"name": "broadcast_wide", "position": Vector3(-6.40, 2.55, 1.70),
		"target": Vector3(0.0, 1.05, 0.0), "fov": 41.0},
	{"name": "broadcast_mid", "position": Vector3(-5.00, 1.95, 1.30),
		"target": Vector3(0.0, 1.10, 0.0), "fov": 38.0},
	{"name": "broadcast_hard_cam", "position": Vector3(-6.40, 2.30, 0.0),
		"target": Vector3(0.0, 1.10, 0.0), "fov": 40.0},
	{"name": "broadcast_ringside_low", "position": Vector3(-5.20, 0.62, 2.60),
		"target": Vector3(0.0, 1.10, 0.0), "fov": 50.0},
	# Outside the ropes on the west side, low and close on the steel steps.
	# The steps straddle both the -X and +X sides at Z ~ +0.35
	# (ring_builder.gd STEP_* constants), three treads in bare bright metal.
	{"name": "ringside_steps", "position": Vector3(-6.30, 0.85, 2.90),
		"target": Vector3(-3.55, -0.45, 0.35), "fov": 46.0},
	{"name": "ringside_steps_wide", "position": Vector3(-7.40, 1.60, 4.20),
		"target": Vector3(-3.30, -0.30, 0.35), "fov": 52.0},
	# Wide enough to read the ring as an object: mat, ropes, posts and the
	# full branded apron skirt on two sides at once.
	{"name": "ring_and_apron_wide", "position": Vector3(-8.60, 2.10, 6.40),
		"target": Vector3(0.0, -0.35, 0.0), "fov": 50.0},
	{"name": "apron_face_on", "position": Vector3(-7.20, 0.55, 0.0),
		"target": Vector3(0.0, -0.55, 0.0), "fov": 44.0},
	# From the entrance stage looking back down the ramp at the ring -- the
	# reverse of the broadcast angle, which is the shot an entrance uses.
	{"name": "from_stage", "position": Vector3(0.0, 3.30, -13.5),
		"target": Vector3(0.0, 0.30, 0.0), "fov": 46.0},
	{"name": "from_stage_low", "position": Vector3(0.0, 1.30, -8.5),
		"target": Vector3(0.0, 0.90, 0.0), "fov": 50.0},
]

var _out_dir := "/tmp/roman_shots"
var _written: Array[String] = []

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out_dir = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out_dir)

	var scene: Node = load(MATCH_SCENE).instantiate()
	scene.match_seed = 3
	add_child(scene)
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	# roman_match.tscn now sets is_ai on both, but setup_jitter() is only
	# applied by MatchSetup for a recording run -- without it both AIs mash
	# tie-up on identical ticks.
	for w: WrestlerController in [a, b]:
		w.is_ai = true
		if w.ai:
			w.ai.setup_jitter(3, w.player_index)

	var camera: Camera3D = scene.get_node("MatchCamera")
	var tick := 0
	for beat: Dictionary in BEATS:
		while tick < int(beat["tick"]):
			await get_tree().physics_frame
			tick += 1
		# MatchCamera solves its own follow framing every physics frame, so
		# it has to stop before it is posed -- left running it lerps back
		# toward the follow solve between the pose and the save, and every
		# shot comes out framed on the ring regardless of what was asked
		# for. Both wrestlers freeze too, so all the shots in one beat are
		# the same instant from different angles rather than a walk.
		_freeze(scene, camera, true)
		var state: String = WrestlerFSM.State.keys()[a.fsm.current_state]
		print("beat %s at tick %d -- WrestlerA in %s at %.2v"
			% [beat["label"], tick, state, a.global_position])
		for shot: Dictionary in PAIR_SHOTS:
			await _shoot_pair(camera, a, b, shot, "%s_%s" % [beat["label"], shot["name"]])
		for shot: Dictionary in SHOTS:
			await _shoot_subject(camera, a, shot, "%s_%s" % [beat["label"], shot["name"]])
		# The same head framings on wrestler B. Both wrestlers are the same
		# model, so any difference between these and A's is a bug in how the
		# instance is set up rather than in the asset -- which is exactly the
		# question when one of them keeps his hair and the other does not.
		for shot: Dictionary in SHOTS:
			if not String(shot["name"]).begins_with("qa_head"):
				continue
			await _shoot_subject(camera, b, shot, "%s_b_%s" % [beat["label"], shot["name"]])
		for shot: Dictionary in BROADCAST_SHOTS:
			await _shoot_world(camera, shot, "%s_%s" % [beat["label"], shot["name"]])
		_freeze(scene, camera, false)

	print("roman-shots: wrote %d files to %s" % [_written.size(), _out_dir])
	get_tree().quit(0)

func _freeze(scene: Node, camera: Camera3D, frozen: bool) -> void:
	for node_name: String in ["WrestlerA", "WrestlerB", "MatchReferee"]:
		var n: Node = scene.get_node_or_null(node_name)
		if n:
			n.set_physics_process(not frozen)
			n.set_process(not frozen)
	camera.set_physics_process(not frozen)
	camera.set_process(not frozen)

## Places the camera on a bearing measured off the subject's own facing, so
## "front" means his front wherever he is standing and however he has turned.
func _shoot_subject(camera: Camera3D, subject: WrestlerController,
		shot: Dictionary, out_name: String) -> void:
	var forward := -subject.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.001:
		forward = Vector3.FORWARD
	forward = forward.normalized()
	var bearing := forward.rotated(Vector3.UP, deg_to_rad(float(shot["yaw_deg"])))
	var feet := subject.global_position
	# The controller's origin is the capsule centre, not the soles, so drop
	# to the floor first and let every height in SHOTS be read as "metres
	# above the mat", which is how they were chosen.
	feet.y = 0.0
	var position := feet + bearing * float(shot["distance"])
	position.y = float(shot["height"])
	var target := feet
	target.y = float(shot["look_height"])
	await _pose_and_save(camera, position, target, float(shot["fov"]), out_name)

## Frames both wrestlers, on a bearing measured off the axis between them.
func _shoot_pair(camera: Camera3D, a: WrestlerController, b: WrestlerController,
		shot: Dictionary, out_name: String) -> void:
	var axis := b.global_position - a.global_position
	axis.y = 0.0
	if axis.length() < 0.001:
		axis = Vector3.RIGHT
	axis = axis.normalized()
	var midpoint := (a.global_position + b.global_position) * 0.5
	midpoint.y = 0.0
	var bearing := axis.rotated(Vector3.UP, deg_to_rad(float(shot["bearing_deg"])))
	var position := midpoint + bearing * float(shot["distance"])
	position.y = float(shot["height"])
	var target := midpoint
	target.y = float(shot["look_height"])
	await _pose_and_save(camera, position, target, float(shot["fov"]), out_name)

func _shoot_world(camera: Camera3D, shot: Dictionary, out_name: String) -> void:
	await _pose_and_save(camera, shot["position"], shot["target"],
		float(shot["fov"]), out_name)

func _pose_and_save(camera: Camera3D, position: Vector3, target: Vector3,
		fov: float, out_name: String) -> void:
	camera.fov = fov
	camera.global_position = position
	if position.distance_to(target) > 0.01:
		camera.look_at(target, Vector3.UP)
	for _i in SETTLE_FRAMES:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img:
		var path := "%s/%s.png" % [_out_dir, out_name]
		img.save_png(path)
		_written.append(path)
