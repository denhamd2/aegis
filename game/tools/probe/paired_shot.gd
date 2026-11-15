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
##   xvfb-run -a godot4 --path game --rendering-method forward_plus --rendering-driver vulkan \
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
## --dist M sets how far the side camera sits (default 4.2); moves that travel,
## like the Spear, need more.
## --match-cam: shoot through the game's own MatchCamera (Fight Forever coverage
## by default) instead of the probe's side camera -- a frame before the move,
## then the move as the player sees it: the cut in for the lock-up and the cut
## back out on the impact.
## --bare: the two men alone -- arena, crowd, ring, HUD and referee hidden,
## a plain floor gridded every 0.5 m, studio light, the defender tinted blue.
## For judging a move's mechanics with nothing else in the frame. --top looks
## straight down on the pair instead of from the side.
## --at fractions over 1.0 look past the move's end, into the knockdown or the
## stance it hands off to (1.5 is half the move's length again).
## --corner: the defender trapped in the near-right corner (CORNER_SPOT), the
## attacker a run-in's length out in front -- for the corner moves, which are
## only ever thrown at a man in the buckle.
## --run-in M: a running move as the game plays it -- the attacker starts M
## metres from the defender and runs in (RUN state) to the clip's first mark,
## over --run-ticks N physics ticks (default: at 6 m/s), then the move starts
## with his run carried into it. The defender holds the clip's first pose
## through the run (kneeling in the corner, doubled over).
## --ticks a,b,c: capture at these 60 fps ticks on the shot's timeline (tick 0
## is the run's first tick with --run-in, else the clip's first frame), named
## <move>_<tick>.png -- true frame numbers, where --at names by percentage.

const MATCH_SCENE := "res://scenes/match.tscn"
const MOVES_DIR := "res://resources/moves"

var _out := "/tmp/paired"
var _move_id := "signature_backbreaker"
var _at: Array = [0.0, 0.2, 0.35, 0.5, 0.65, 0.8, 1.0]
var _side := false
var _orbit := 0.0
var _lit := false
var _dist := 4.2
## --wrestlers roman,kenny: the real men at their real sizes, attacker first.
var _wrestlers := ""
var _bare := false
var _match_cam := false
var _top := false
var _weapon_id := ""
## --weapon-ahead M: the --weapon set up M metres in front of the attacker
## (a powerbomb's table, WrestlerAI.POWERBOMB_DROP) instead of 1.3 m behind
## him (the suplex's).
var _weapon_ahead := -WrestlerAI.SUPLEX_DROP
var _corner := false
var _run_in := 0.0
var _run_ticks := 0
var _ticks: Array = []


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
		elif args[i] == "--bare":
			_bare = true
		elif args[i] == "--match-cam":
			_match_cam = true
		elif args[i] == "--top":
			_top = true
		elif args[i] == "--corner":
			_corner = true
		elif args[i] == "--run-in" and i + 1 < args.size():
			_run_in = float(args[i + 1])
		elif args[i] == "--run-ticks" and i + 1 < args.size():
			_run_ticks = int(args[i + 1])
		elif args[i] == "--ticks" and i + 1 < args.size():
			_ticks = []
			for token: String in args[i + 1].split(","):
				_ticks.append(int(token))
		elif args[i] == "--dist" and i + 1 < args.size():
			_dist = float(args[i + 1])
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--weapon" and i + 1 < args.size():
			_weapon_id = args[i + 1]
		elif args[i] == "--weapon-ahead" and i + 1 < args.size():
			_weapon_ahead = float(args[i + 1])
		elif args[i] == "--at" and i + 1 < args.size():
			_at = []
			for token: String in args[i + 1].split(","):
				_at.append(float(token))
	DirAccess.make_dir_recursive_absolute(_out)
	# A library move ("ff/tiger_driver_98") names its frames by the move alone.
	var shot := _move_id.get_file()

	var scene: Node = load(MATCH_SCENE).instantiate()
	if _bare:
		# Omit cosmetic builders before _ready creates crowds/lights. Hiding
		# them after entering the tree still pays the full arena GPU cost.
		for name in ["Arena", "LightRig", "RingReflections"]:
			var cosmetic := scene.get_node_or_null(NodePath(name))
			if cosmetic:
				cosmetic.free()
		var world := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if world:
			world.environment = Environment.new()
	if _wrestlers != "":
		var pair := Roster.pair_from_spec(_wrestlers)
		if pair.size() == 2:
			TitleScreen.configure_match(scene, pair[0], pair[1], 1)
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
	if _corner:
		var spot := WrestlerController.CORNER_SPOT
		defender.global_position = Vector3(spot, 0.0, spot)
		attacker.global_position = Vector3(spot - 0.85, 0.0, spot - 0.85)
	attacker.look_at(defender.global_position, Vector3.UP)
	defender.look_at(attacker.global_position, Vector3.UP)
	await get_tree().physics_frame
	var spot_weapon: WeaponActor = null
	if _weapon_id != "":
		# Set pieces only take a man's landing in No Holds Barred
		# (WrestlerController._land_on_set_piece): without it the table never
		# broke under him.
		for w: WrestlerController in [attacker, defender]:
			MatchRules.set_mode(w, MatchRules.Mode.NO_HOLDS_BARRED)
		spot_weapon = WeaponStock.of(attacker).pull(WeaponCatalog.by_id(StringName(_weapon_id)))
		spot_weapon.set_up_at(attacker.global_position - attacker.global_basis.z * _weapon_ahead,
				attacker.rotation.y)

	if _bare:
		_strip(scene, attacker, defender, spot_weapon)

	# Settled under the match camera before the hold, not during it: two men
	# left in GRAPPLE_HOLD for 90 ticks pick a move of their own.
	var match_camera: MatchCamera = scene.get_node_or_null("MatchCamera")
	if _match_cam and match_camera:
		match_camera.current = true
		match_camera.mode = match_camera.master_mode()
		match_camera._held = 5.0
		for i in 90:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s_pre.png" % [_out, shot])
	var rig: Node = scene.get_node("GrappleRig")
	var total := int(move.total_frames())
	# --run-in: where the rig will put each man (the pair frame it computes
	# from where they stand now), and the run up to the attacker's mark.
	var plan_a := attacker.global_transform
	var plan_d := defender.global_transform
	var mark_a := plan_a
	var mark_d := plan_d
	var run_from := plan_a
	var run := 0
	var run_dir := Vector3.ZERO
	var run_speed := 0.0
	if _run_in > 0.0:
		rig.set("_move", move)
		var pair_xform: Transform3D = rig.call("_compute_pair_transform", attacker, defender)
		rig.set("_move", null)
		var start_a: Transform3D = rig.call("_role_start", move, true)
		var start_d: Transform3D = rig.call("_role_start", move, false)
		mark_a = pair_xform * start_a
		mark_d = pair_xform * start_d
		run_dir = mark_a.origin - mark_d.origin
		run_dir.y = 0.0
		var gap := run_dir.length()
		run_dir = run_dir / gap if gap > 0.001 else attacker.global_transform.basis.z
		if _run_in > gap + 0.05:
			run_from = Transform3D(mark_a.basis, mark_d.origin + run_dir * _run_in)
			run = _run_ticks if _run_ticks > 0 else int(ceil((_run_in - gap) / 6.0 * 60.0))
			run_speed = (_run_in - gap) / float(run) * 60.0
	# The capture schedule: [clip tick (negative: during the run), file name].
	var targets: Array = []
	if not _ticks.is_empty():
		for t in _ticks:
			targets.append([int(t) - run, "%s_%03d.png" % [shot, int(t)], int(t)])
	else:
		for f in _at:
			targets.append([int(round(float(f) * total)), "%s_%02d.png" % [shot, int(float(f) * 100)], f])
	var grabbed := 0
	var captures: Array[Dictionary] = []
	var camera: Camera3D = null
	Engine.max_physics_steps_per_frame = 1
	if run > 0:
		camera = _make_camera(scene, run_from.origin, mark_d.origin, false)
		attacker.set_physics_process(false)
		defender.set_physics_process(false)
		defender.global_transform = mark_d
		attacker.global_transform = run_from
		attacker.fsm.transition_to(WrestlerFSM.State.RUN)
		if defender.has_method("begin_walk_in"):
			defender.begin_walk_in(mark_d, mark_d, run, move, false)
		RenderingServer.render_loop_enabled = false
		for tick in run:
			await get_tree().physics_frame
			camera.current = true
			var k := float(tick + 1) / float(run)
			attacker.global_transform = Transform3D(mark_a.basis, run_from.origin.lerp(mark_a.origin, k))
			while grabbed < targets.size() and int(targets[grabbed][0]) <= tick + 1 - run:
				await _grab(targets[grabbed], tick + 1, 0, -1.0, captures, attacker, defender)
				grabbed += 1
		# Back where the pair frame was planned from (unrendered): the rig
		# carries both onto their marks again in a tick or two, his run
		# carried in at its own speed.
		attacker.global_transform = plan_a
		defender.global_transform = plan_d
		attacker.set_physics_process(true)
		defender.set_physics_process(true)
		(attacker as CharacterBody3D).velocity = -run_dir * maxf(run_speed, 3.0)
	# As a match starts one (WrestlerController._begin_running_paired): roles
	# set and both in GRAPPLE_HOLD, or the grip IK -- the hands -- never runs.
	if not OS.get_cmdline_user_args().has("--no-grip"):
		attacker._is_grapple_attacker = true
		defender._is_grapple_attacker = false
		attacker.opponent = defender
		defender.opponent = attacker
		attacker.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
		defender.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	rig.begin(attacker, defender, move)
	print("PAIRED_SHOT %s" % _move_id)

	if camera == null:
		camera = _make_camera(scene, attacker.global_position, defender.global_position,
				_match_cam and match_camera != null)

	# Step the physics forward and grab at each fraction of the move. The
	# lowest bone is printed with every frame because "does it still read as
	# the move" and "does anybody go through the mat" are both being asked
	# here, and only one of them is answerable from a number.
	# Counted from the clip's first frame, not from begin(): the rig first
	# walks both men onto their marks (GrappleRig._lead_in), and for a running
	# move that starts 1.4 m out that walk-in is over half a second -- every
	# frame of the Casualty of War's first sheet was labelled 0.57 s early.
	# One physics tick per frame, and nothing drawn but the grabs. Under the
	# software rasteriser a frame takes longer than a tick, so the engine ran
	# up to eight catch-up ticks while each grab was drawn, and every frame
	# showed the move 0.1-0.2 s later than its label (the Casualty of War's
	# lariat came out at "0.14 s" instead of 0.30). Drawing every tick
	# (--fixed-fps) fixes that too, but takes a quarter of an hour.
	var last_tick := total
	for target in targets:
		last_tick = maxi(last_tick, int(target[0]))
	RenderingServer.render_loop_enabled = false
	var frame := 0
	while frame < 2000 + last_tick:
		await get_tree().physics_frame
		# MatchCamera takes `current` back when it cuts; hold the probe's.
		if not _match_cam:
			camera.current = true
		var lead := int(rig.get("lead_in_ticks"))
		frame += 1
		if frame - 1 >= lead + last_tick + 4:
			break
		if grabbed >= targets.size():
			break
		if frame - 1 - lead < maxi(0, int(targets[grabbed][0]) - 1):
			continue
		var paired_seconds: float = rig.animation_player.current_animation_position \
				if rig.animation_player.is_playing() else -1.0
		await _grab(targets[grabbed], frame - 1, lead, paired_seconds, captures, attacker, defender)
		print("  t=%.2f  defender y=%.2f  attacker y=%.2f"
				% [float(frame - 1 - lead) / float(total), defender.global_position.y, attacker.global_position.y])
		grabbed += 1
	var manifest := FileAccess.open(_out.path_join("capture_manifest.json"), FileAccess.WRITE)
	if manifest:
		manifest.store_string(JSON.stringify({"move": _move_id,
				"renderer": RenderingServer.get_current_rendering_method(),
				"bare": _bare, "match_camera": _match_cam, "captures": captures}, "\t"))
	get_tree().quit()


## The probe's own camera: square to the line between `a` and `d` (--side),
## straight down (--top), or the default three-quarter view on the attacker.
func _make_camera(scene: Node, a: Vector3, d: Vector3, defer_to_match: bool) -> Camera3D:
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = not defer_to_match
	var focus := a + Vector3(0.0, 0.9, 0.0)
	camera.global_position = focus + Vector3(3.2, 1.4, 3.2)
	if _side:
		var mid := (a + d) * 0.5
		var across := (d - a).normalized().cross(Vector3.UP)
		across = across.rotated(Vector3.UP, deg_to_rad(_orbit))
		focus = mid + Vector3(0.0, 0.8, 0.0)
		camera.global_position = focus + across * _dist + Vector3(0.0, 0.3, 0.0)
		camera.fov = 45.0
	if _top:
		var mid := (a + d) * 0.5
		focus = mid
		camera.global_position = mid + Vector3(0.0, _dist + 2.0, 0.001)
		camera.fov = 45.0
	camera.look_at(focus, Vector3.UP)
	if _lit:
		var fill := DirectionalLight3D.new()
		scene.add_child(fill)
		fill.light_energy = 2.0
		fill.global_transform = camera.global_transform
	return camera


## Draws one frame and saves it as target[1]; `tick` is the physics tick it
## was drawn on, counted from the clip's start after `lead` walk-in ticks.
func _grab(target: Array, tick: int, lead: int, paired_seconds: float,
		captures: Array[Dictionary], attacker: WrestlerController,
		defender: WrestlerController) -> void:
	RenderingServer.render_loop_enabled = true
	await RenderingServer.frame_post_draw
	RenderingServer.render_loop_enabled = false
	var image := get_viewport().get_texture().get_image()
	var filename: String = target[1]
	image.save_png(_out.path_join(filename))
	captures.append({"file": filename, "requested": target[2],
			"requested_tick": int(target[0]), "paired_seconds": paired_seconds,
			"elapsed_tick": tick, "lead_in_ticks": lead})
	print("CAPTURE_CLOCK %s requested_tick %d paired_seconds %.6f" % [filename,
			int(target[0]), paired_seconds])
	if OS.get_cmdline_user_args().has("--bones"):
		for w: WrestlerController in [attacker, defender]:
			print("    %s root %s yaw %.0f  %s" % [w.name, _v3(w.global_position),
					rad_to_deg(w.global_rotation.y), _bones(w)])


## Everything but the two men, gone; a plain gridded floor and studio light.
func _strip(scene: Node, attacker: Node3D, defender: Node3D,
		keep_weapon: WeaponActor = null) -> void:
	for child in scene.get_children():
		if child == attacker or child == defender:
			continue
		if keep_weapon != null and (child == keep_weapon or child == keep_weapon.get_parent()):
			continue
		if child is Node3D:
			(child as Node3D).visible = false
		elif child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child is CanvasItem:
			(child as CanvasItem).visible = false
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.64, 0.67)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.35
	for node in scene.find_children("*", "WorldEnvironment", true, false):
		(node as WorldEnvironment).environment = env
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(12.0, 12.0)
	floor.mesh = plane
	var grid := ShaderMaterial.new()
	grid.shader = Shader.new()
	grid.shader.code = """shader_type spatial;
void fragment() {
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 g = abs(fract(w.xz * 2.0 + 0.5) - 0.5) / fwidth(w.xz * 2.0);
	float line = 1.0 - min(min(g.x, g.y), 1.0);
	ALBEDO = mix(vec3(0.42), vec3(0.2), line);
	ROUGHNESS = 0.9;
}"""
	floor.material_override = grid
	scene.add_child(floor)
	floor.global_position = Vector3(attacker.global_position.x, 0.0, attacker.global_position.z)
	for spec in [[Vector3(-50, 35, 0), 1.0, true], [Vector3(-25, -140, 0), 0.45, false]]:
		var light := DirectionalLight3D.new()
		scene.add_child(light)
		light.rotation_degrees = spec[0]
		light.light_energy = spec[1]
		light.shadow_enabled = spec[2]
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.32, 0.5, 0.95)
	for mesh in defender.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = blue


## --bones: world positions of the head and pelvis (the Cross Rhodes landing,
## 12 Nov: which way round is he lying, and is he on the mat).
static func _bones(w: WrestlerController) -> String:
	var sk := w.skeleton
	if sk == null:
		return "-"
	var out := ""
	var low := INF
	var low_name := ""
	for i in sk.get_bone_count():
		var name := sk.get_bone_name(i).to_lower()
		var at := sk.global_transform * sk.get_bone_global_pose(i).origin
		if at.y < low:
			low = at.y
			low_name = name
		if name == "head" or name == "pelvis":
			out += "%s %s  " % [name, _v3(at)]
	return out + "lowest %.3f (%s)" % [low, low_name]


static func _v3(p: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [p.x, p.y, p.z]

