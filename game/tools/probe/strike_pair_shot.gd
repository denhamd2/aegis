extends Node
## Two-body strike reviewer: plays an attacker strike and the defender's hit
## reaction/sell on the real match wrestlers, then captures a side strip.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 960x540 tools/probe/strike_pair_shot.tscn -- \
##       --strike strikes/strike_cross --react Hit_React_Head --sell Sell_Head \
##       --wrestlers kenny,cody --out /tmp/strike_pair
##
## Parity review (gauntlet/refs/ff_review/parity): --move strike_front_kick_body
## takes the clip, the defender's reaction and sell, and the contact frame from
## the MoveDef (startup_frames), and --frames 0,10,19,23,40 grabs those 60 fps
## frames of the strike. The defender stands until contact and reacts from it,
## so the strip lines up beat for beat with the reference's.

const MATCH_SCENE := "res://scenes/match.tscn"

var _strike := "strikes/strike_cross"
var _react := "Hit_React_Head"
var _sell := "Sell_Head"
var _wrestlers := ""
var _out := "/tmp/strike_pair"
var _at: Array = [0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9]
var _move_id := ""
var _frames: Array = []
var _contact := -1
## The contact point is on his chest, not his capsule: the capsule radius
## (0.4) left every kick 0.2 m short of the body (parity loop 2 renders).
const TORSO_HALF_DEPTH := 0.2
var _carry := false
var _b_start := Vector3.ZERO


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--strike" and i + 1 < args.size():
			_strike = args[i + 1]
		elif args[i] == "--react" and i + 1 < args.size():
			_react = args[i + 1]
		elif args[i] == "--sell" and i + 1 < args.size():
			_sell = args[i + 1]
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--move" and i + 1 < args.size():
			_move_id = args[i + 1]
		elif args[i] == "--frames" and i + 1 < args.size():
			for token: String in args[i + 1].split(","):
				_frames.append(int(token))
		elif args[i] == "--contact" and i + 1 < args.size():
			_contact = int(args[i + 1])
		elif args[i] == "--at" and i + 1 < args.size():
			_at = []
			for token: String in args[i + 1].split(","):
				_at.append(float(token))
	if _move_id != "":
		var move: MoveDef = load("res://resources/moves/%s.tres" % _move_id)
		if move:
			_strike = StrikeRecipes.clip(_move_id) if StrikeRecipes.clip(_move_id) != "" else _strike
			_react = StrikeRecipes.reaction_for(move)
			_sell = StrikeRecipes.sell_for(_react)
			if _contact < 0:
				_contact = move.startup_frames
			# A knockdown strike plays the game's bump, not a flinch: the
			# defender goes over on BUMP_LARIAT_CLIP and is carried back the
			# way _bump_down() carries him (parity review, 12 Nov).
			if move.leaves_defender_down:
				_react = WrestlerController.BUMP_LARIAT_CLIP
				_sell = ""
				_carry = true
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = (load(MATCH_SCENE) as PackedScene).instantiate()
	if _wrestlers != "":
		var pair := Roster.pair_from_spec(_wrestlers)
		if pair.size() == 2:
			TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.is_ai = false
	b.is_ai = false
	a.global_position = Vector3(0.0, 0.0, 0.0)
	# At the move's own contact distance (its baked contact point plus the
	# body radius), not a fixed 0.9 m: at 0.9 the kicks landed knee-deep in
	# him (parity review, 12 Nov).
	var gap := 0.9
	if _move_id != "":
		var mv: MoveDef = load("res://resources/moves/%s.tres" % _move_id)
		if mv and mv.contact_radius > 0.0:
			gap = maxf(0.8, -mv.contact_offset.z + TORSO_HALF_DEPTH)
	# The match opens on the referee's immediate lock-up; left running, his
	# tie-up pulled the two men 0.2-0.6 m together in the one physics tick
	# below, so every sheet started half locked up (parity loop 2, 12 Nov).
	var referee := scene.get_node_or_null("MatchReferee")
	if referee and "_tying_up" in referee:
		referee._tying_up = false
	if referee:
		referee.process_mode = Node.PROCESS_MODE_DISABLED
	b.global_position = Vector3(0.0, 0.0, -gap)
	_b_start = b.global_position
	a.look_at(b.global_position, Vector3.UP)
	b.look_at(a.global_position, Vector3.UP)
	await get_tree().physics_frame
	a.anim_tree.active = false
	b.anim_tree.active = false
	# The skeleton modifiers (inertializer, foot lock, body life, flinch) hold
	# a cached pose between physics ticks; with none running they drew the
	# same frame for every grab (parity review, 12 Nov). Off for the strip.
	for w: WrestlerController in [a, b]:
		if w.skeleton:
			for m in w.skeleton.find_children("", "SkeletonModifier3D", true, false):
				(m as SkeletonModifier3D).active = false
		w.set_physics_process(false)
		w.velocity = Vector3.ZERO
	# And placed again once nothing can move them.
	a.global_position = Vector3.ZERO
	b.global_position = _b_start
	a.look_at(b.global_position, Vector3.UP)
	b.look_at(a.global_position, Vector3.UP)
	var pa := a.anim_player
	var pb := b.anim_player
	if not pa.has_animation(_strike):
		push_error("attacker clip missing: " + _strike)
		get_tree().quit(1)
		return
	if not pb.has_animation(_react):
		push_error("react clip missing: " + _react)
		get_tree().quit(1)
		return
	var hit_len: float = pb.get_animation(_react).length
	var clip_len: float = pa.get_animation(_strike).length
	var match_camera: Camera3D = scene.get_node_or_null("MatchCamera") as Camera3D
	if match_camera:
		match_camera.current = false
	for child in scene.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	# Nobody else in the shot: the referee walked in front of the knockdown
	# (parity loop 2 renders, 12 Nov).
	for ref_name in ["MatchReferee", "RefereeActor"]:
		var ref_node := scene.get_node_or_null(ref_name)
		if ref_node:
			ref_node.process_mode = Node.PROCESS_MODE_DISABLED
			if ref_node is Node3D:
				(ref_node as Node3D).visible = false
	var focus := (a.global_position + b.global_position) * 0.5 + Vector3(0.0, 1.0, 0.0)
	var across := (b.global_position - a.global_position).normalized().cross(Vector3.UP)
	var back := 3.0
	if _carry:
		# Framed on the whole knockdown: the striker to where the carry lands.
		var land := b.global_position + (b.global_position - a.global_position).normalized() \
				* _carried(WrestlerController.KNOCKDOWN_CARRY_TICKS)
		focus = (a.global_position + land) * 0.5 + Vector3(0.0, 0.8, 0.0)
		back = 4.2
	camera.global_position = focus + across * back + Vector3(0.0, 0.4, 0.0)
	# --cam-yaw DEG: orbit the camera round the focus (diagnosing a pose from
	# more than the one side; 12 Nov, the turning back kick's torso).
	var cy := OS.get_cmdline_user_args().find("--cam-yaw")
	if cy >= 0 and cy + 1 < OS.get_cmdline_user_args().size():
		var off := camera.global_position - focus
		camera.global_position = focus + off.rotated(Vector3.UP,
				deg_to_rad(float(OS.get_cmdline_user_args()[cy + 1])))
	camera.look_at(focus, Vector3.UP)
	camera.fov = 45.0
	# The arena is lit for the wide broadcast camera; a close review camera
	# needs its own key and fill or the two men read as silhouettes.
	var key := DirectionalLight3D.new()
	scene.add_child(key)
	# From the camera's side and above, not behind the pair: keyed from behind,
	# a chest turned to the camera mid-spin fell into the hair's shadow and
	# read as a black, collapsed torso (the owner: "Kenny is morphing").
	key.global_position = camera.global_position + Vector3(0.0, 2.5, 0.0) \
			+ (camera.global_position - focus).cross(Vector3.UP).normalized() * 1.5
	key.look_at(focus, Vector3.UP)
	key.light_energy = 3.0
	key.shadow_enabled = true
	var fill := OmniLight3D.new()
	scene.add_child(fill)
	fill.light_energy = 6.0
	fill.omni_range = 8.0
	fill.global_position = focus + Vector3(2.0, 2.0, 2.0)
	RenderingServer.render_loop_enabled = false
	if not _frames.is_empty():
		print("STRIKE_PAIR clip=%s react=%s sell=%s contact=%d len=%.3f" % [_strike, _react, _sell, _contact, clip_len])
		for f: int in _frames:
			var t := float(f) / 60.0
			pa.play(_strike)
			pa.pause()
			pa.seek(minf(t, clip_len - 0.001), true)
			pa.advance(0)
			var rt := float(f - maxi(_contact, 0)) / 60.0
			if _carry:
				b.global_position = _b_start + Vector3(0.0, 0.0, -_carried(f - _contact))
			if rt < 0.0 and pb.has_animation(StrikeRecipes.clip("idle_ready")):
				# Before contact he stands as the game stands him: idle_ready.
				var idle := StrikeRecipes.clip("idle_ready")
				pb.play(idle)
				pb.pause()
				pb.seek(fmod(float(f) / 60.0, pb.get_animation(idle).length), true)
				pb.advance(0)
			elif rt <= 0.0 or rt <= hit_len or not pb.has_animation(_sell):
				pb.play(_react)
				pb.pause()
				pb.seek(clampf(rt, 0.0, hit_len - 0.001), true)
				pb.advance(0)
			elif pb.has_animation(_sell):
				pb.play(_sell)
				pb.pause()
				pb.seek(minf(rt - hit_len, pb.get_animation(_sell).length - 0.001), true)
				pb.advance(0)
			if OS.get_cmdline_user_args().has("--debug"):
				var hip_a := a.skeleton.get_bone_global_pose(a.skeleton.find_bone("pelvis")).origin if a.skeleton else Vector3.ZERO
				var hip_b := b.skeleton.get_bone_global_pose(b.skeleton.find_bone("pelvis")).origin if b.skeleton else Vector3.ZERO
				print("DBGPOS f%d A=%s B=%s pelvisA=%s pelvisB=%s" % [f, a.global_position, b.global_position,
						a.skeleton.global_transform * hip_a, b.skeleton.global_transform * hip_b])
				var sk := a.skeleton
				var foot := sk.find_bone("foot_r") if sk else -1
				print("DBG f%d anim=%s pos=%.3f playing=%s foot_r=%s" % [f, pa.current_animation,
						pa.current_animation_position, pa.is_playing(),
						(sk.get_bone_global_pose(foot).origin if foot >= 0 else Vector3.ZERO)])
				continue
			RenderingServer.render_loop_enabled = true
			await RenderingServer.frame_post_draw
			RenderingServer.render_loop_enabled = false
			get_viewport().get_texture().get_image().save_png("%s/f%03d.png" % [_out, f])
		get_tree().quit()
		return
	for i in _at.size():
		var t: float = float(_at[i]) * clip_len
		pa.play(_strike)
		pa.pause()
		pa.seek(t, true)
		pa.advance(0)
		if t <= hit_len and pb.has_animation(_react):
			pb.play(_react)
			pb.pause()
			pb.seek(t, true)
			pb.advance(0)
		elif pb.has_animation(_sell):
			pb.play(_sell)
			pb.pause()
			pb.seek(minf(t - hit_len, pb.get_animation(_sell).length - 0.001), true)
			pb.advance(0)
		RenderingServer.render_loop_enabled = true
		await RenderingServer.frame_post_draw
		RenderingServer.render_loop_enabled = false
		var image := get_viewport().get_texture().get_image()
		image.save_png("%s/%s_%02d.png" % [_out, _strike.get_file(), int(float(_at[i]) * 100.0)])
		print("STRIKE_PAIR t=%.2f" % t)
	get_tree().quit()


## Metres _process_timed_state() has carried him n ticks into the bump.
func _carried(n: int) -> float:
	var v := WrestlerController.KNOCKDOWN_CARRY_SPEED
	var d := 0.0
	for i in clampi(n, 0, WrestlerController.KNOCKDOWN_CARRY_TICKS):
		v *= WrestlerController.KNOCKDOWN_CARRY_DECAY
		d += v / 60.0
	return d
