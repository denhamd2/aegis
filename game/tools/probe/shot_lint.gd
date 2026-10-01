extends Node
## The camera's shot grammar, checked over a whole show (camera_aaa_plan.md D3):
## both entrances, the face-off, an AI match and the post-match, headless.
##
## Every frame it asks of the shot on screen:
##   * RIG    -- does the overhead light rig (OverheadRig's own triangles) cut
##               the line from the lens to either wrestler's head? The owner's
##               rule: the rig never blocks a high shot.
##   * POST   -- does a ring post?
##   * SHORT  -- a cut held under MatchCamera.MIN_SHOT (D1).
## and prints a line for each blocked stretch with the shot it happened on.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/shot_lint.tscn \
##       [-- --seed 3 --budget 60000 --no-entrances]

const POST_R := 0.12
const POSTS := [Vector2(3.3, 3.3), Vector2(-3.3, 3.3), Vector2(3.3, -3.3), Vector2(-3.3, -3.3)]

var _seed := 3
var _budget := 60000
var _entrances := true
var _rig: Array = []   # [TriangleMesh, Transform3D]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--seed": _seed = int(args[i + 1])
			"--budget": _budget = int(args[i + 1])
			"--no-entrances": _entrances = false
	var pair := Roster.pair_from_spec("")
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], _seed)
	scene.entrances = _entrances
	add_child(scene)
	for w in [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]:
		(w as WrestlerController).is_ai = true
	await get_tree().process_frame
	var rig := scene.find_child("OverheadRig", true, false)
	if rig == null:
		rig = get_tree().root.find_child("OverheadRig", true, false)
	if rig:
		for mi: MeshInstance3D in rig.find_children("", "MeshInstance3D", true, false):
			if mi.mesh:
				_rig.append([mi.mesh.generate_triangle_mesh(), mi.global_transform])
	print("LINT rig meshes: ", _rig.size())
	var camera: MatchCamera = scene.get_node("MatchCamera")
	var ws: Array = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	var frames := 0
	var blocked := {"RIG": 0, "POST": 0}
	var run := {"RIG": 0, "POST": 0}
	var short := 0
	var shot_len := 0
	var last_pos := camera.global_position
	var last_mode := camera.mode
	var stage := ""
	var director := scene.get_node_or_null("EntranceDirector")
	if director:
		director.beat_started.connect(func(s): stage = s)
	while frames < _budget:
		await get_tree().physics_frame
		frames += 1
		var post := scene.get_node_or_null("PostMatch") as PostMatch
		if post and post.is_done():
			break
		var at := camera.global_position
		# A cut: the lens jumped. Shots under MIN_SHOT are a grammar fault.
		if at.distance_to(last_pos) > 1.0 or camera.mode != last_mode:
			if shot_len > 0 and shot_len < int(MatchCamera.MIN_SHOT * 60) and last_mode != MatchCamera.Mode.ENTRANCE:
				short += 1
			shot_len = 0
		shot_len += 1
		last_pos = at
		last_mode = camera.mode
		var forward := -camera.global_transform.basis.z
		for kind in ["RIG", "POST"]:
			var hit := false
			for w: WrestlerController in ws:
				if not w.visible:
					continue
				var head := w.global_position + Vector3.UP * 1.6
				# Only what is in front of the lens matters.
				if (head - at).normalized().dot(forward) < 0.5:
					continue
				if kind == "RIG" and _rig_blocks(at, head):
					hit = true
				elif kind == "POST" and _post_blocks(at, head):
					hit = true
			if hit:
				run[kind] += 1
				blocked[kind] += 1
			elif run[kind] > 0:
				if run[kind] >= 6:
					print("  %s blocked %d frames ending f%d, mode %s, stage %s, cam %s" % [kind, run[kind], frames,
							MatchCamera.Mode.keys()[camera.mode], stage, str(at.snapped(Vector3.ONE * 0.1))])
				run[kind] = 0
	print("LINT_DONE frames %d  rig-blocked %d (%.1f%%)  post-blocked %d (%.1f%%)  short cuts %d" % [frames,
			blocked["RIG"], 100.0 * blocked["RIG"] / maxf(frames, 1), blocked["POST"],
			100.0 * blocked["POST"] / maxf(frames, 1), short])
	get_tree().quit()


func _rig_blocks(from: Vector3, to: Vector3) -> bool:
	for entry: Array in _rig:
		var tm: TriangleMesh = entry[0]
		var inv: Transform3D = (entry[1] as Transform3D).affine_inverse()
		var r: Dictionary = tm.intersect_segment(inv * from, inv * to)
		if not r.is_empty():
			return true
	return false


func _post_blocks(from: Vector3, to: Vector3) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	for p: Vector2 in POSTS:
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if (a + ab * t).distance_to(p) < POST_R:
			# And the sight line passes the post below its top (1.6 m).
			var y := lerpf(from.y, to.y, t)
			if y < 1.6 and t > 0.02 and t < 0.98:
				return true
	return false
