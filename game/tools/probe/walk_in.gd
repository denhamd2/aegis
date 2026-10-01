extends Node
## The walk-in (GrappleRig._lead_in + FootPlant): how far each foot SKATES --
## slides horizontally while it is on the mat -- as GrappleRig carries both
## men from where they stood into the move's start marks.
##
##   godot4 --headless --path game tools/probe/walk_in.tscn \
##       [-- --moves grapple_vertical_suplex --gap 1.4 --turn 60 --no-plant]
##
## --gap is how far apart the two start (default 1.2 m, a man a step away),
## --turn how far the defender is turned off square. --no-plant switches
## FootPlant off, for the before number. Feet are read inside the skeleton's
## own update, since a modifier's result is invisible from outside it.

const ON_MAT := 0.05

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var moves := ["grapple_vertical_suplex", "signature_neckbreaker", "running_spear",
			"power_bodyslam", "running_tilt_a_whirl_ddt"]
	var gap := 1.2
	var turn := 0.0
	var plant := true
	var out := ""
	for i in args.size():
		match args[i]:
			"--moves": moves = Array(args[i + 1].split(","))
			"--gap": gap = float(args[i + 1])
			"--turn": turn = float(args[i + 1])
			"--no-plant": plant = false
			"--out": out = args[i + 1]
	var worst_all := 0.0
	for move_id: String in moves:
		var r := await _measure(move_id, gap, turn, plant, out)
		worst_all = maxf(worst_all, r["skate"])
		print("WALK_IN %-32s ticks %2d  carry A %.2f D %.2f m  skate worst %.3f m  total %.3f m  steps %d/%d  rope %.3f m"
				% [move_id, r["ticks"], r["carry_a"], r["carry_d"], r["skate"], r["total"], r["steps_a"], r["steps_d"], r.get("rope", 0.0)])
	print("WALK_IN_DONE worst skate %.3f m" % worst_all)
	get_tree().quit()


func _measure(move_id: String, gap: float, turn: float, plant: bool, out := "") -> Dictionary:
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	add_child(scene)
	await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var d: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, d]:
		w.is_ai = false
		if not plant and w.foot_plant:
			w.foot_plant.queue_free()
			w.foot_plant = null
	d.global_position = a.global_position - a.global_transform.basis.z * gap
	a.look_at(d.global_position, Vector3.UP)
	d.look_at(a.global_position, Vector3.UP)
	d.rotate_y(deg_to_rad(turn))
	await get_tree().physics_frame
	var rig: GrappleRig = scene.get_node("GrappleRig")
	a._is_grapple_attacker = true
	d._is_grapple_attacker = false
	a.opponent = d
	d.opponent = a
	a.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	d.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	var start_a := a.global_position
	var start_d := d.global_position
	var feet := {}
	var hooks := []
	for w: WrestlerController in [a, d]:
		var sk := w.skeleton
		var ids := [sk.find_bone(w._skeleton_bone_name("foot_l")), sk.find_bone(w._skeleton_bone_name("foot_r"))]
		var cb := func() -> void:
			for side in 2:
				feet["%s%d" % [w.name, side]] = sk.global_transform * sk.get_bone_global_pose(ids[side]).origin
		sk.skeleton_updated.connect(cb)
		hooks.append([sk, cb])
	if out != "":
		# --out DIR: a low side view of their feet every few ticks.
		DirAccess.make_dir_recursive_absolute(out)
		var cam := Camera3D.new()
		scene.add_child(cam)
		var mid := (a.global_position + d.global_position) * 0.5
		var side := a.global_transform.basis.x
		cam.global_position = mid + side * 3.4 + Vector3.UP * 0.9
		cam.look_at(mid + Vector3.UP * 0.6, Vector3.UP)
		cam.fov = 45.0
		cam.current = true
		var light := DirectionalLight3D.new()
		scene.add_child(light)
		light.look_at_from_position(cam.global_position, mid, Vector3.UP)
		light.light_energy = 0.6
	var clip_on := [false]
	rig.animation_player.animation_started.connect(func(_n: StringName) -> void: clip_on[0] = true)
	rig.begin(a, d, load("res://resources/moves/%s.tres" % move_id))
	var ticks := rig.lead_in_ticks
	var r := {"ticks": ticks, "skate": 0.0, "total": 0.0, "steps_a": 0, "steps_d": 0,
			"carry_a": 0.0, "carry_d": 0.0}
	var prev := {}
	var floor_y := {}
	var lifted := {}
	await get_tree().process_frame
	# Through the walk-in and the tick the move's clip takes over -- the
	# hand-off is where the feet used to snap -- and no further.
	var started := -1
	for tick in ticks + 12:
		await get_tree().physics_frame
		await get_tree().process_frame
		if started < 0 and clip_on[0]:
			started = tick
		if started >= 0 and tick > started + 1:
			break
		if out != "" and tick % 3 == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%s_%02d.png"
					% [out, move_id, "plant" if plant else "slide", tick])
		for k: String in feet:
			var p: Vector3 = feet[k]
			floor_y[k] = minf(floor_y.get(k, INF), p.y)
			if prev.has(k):
				var q: Vector3 = prev[k]
				var on_mat: bool = p.y - float(floor_y[k]) < ON_MAT and q.y - float(floor_y[k]) < ON_MAT
				if on_mat:
					var slide := Vector2(p.x - q.x, p.z - q.z).length()
					r["total"] = float(r["total"]) + slide
					r["skate"] = maxf(r["skate"], slide)
				var up: bool = p.y - float(floor_y[k]) >= ON_MAT
				if up and not lifted.get(k, false):
					r["steps_a" if k.begins_with("WrestlerA") else "steps_d"] += 1
				lifted[k] = up
			prev[k] = p
		var ropes := scene.find_children("*", "RingRopes", true, false)
		if not ropes.is_empty():
			r["rope"] = maxf(float(r.get("rope", 0.0)), ropes[0].max_deflection())
	r["carry_a"] = a.global_position.distance_to(start_a)
	r["carry_d"] = d.global_position.distance_to(start_d)
	for h: Array in hooks:
		h[0].skeleton_updated.disconnect(h[1])
	scene.queue_free()
	await get_tree().process_frame
	return r
