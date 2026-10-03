extends Node
## Each man's way into the ring through the ropes (EntranceDirector's
## Rope_Step_Through_Apron beat), with the live ropes (core/ring/ring_ropes.gd)
## measured all the way through: the largest deflection on each rope and the
## fastest any rope node moves. The owner found the rope movement on the way
## in "weird and unnatural"; refs/ropes.md has a man going through the ropes
## part them by a hand's width or so and ease them back.
##
##   godot4 --headless --path game --fixed-fps 60 tools/probe/rope_entry_shot.tscn
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 --resolution 960x540 \
##       --fixed-fps 60 tools/probe/rope_entry_shot.tscn -- --out /tmp/rope_entry --every 4
##
## Prints ROPE_ENTRY <who> peak <m> by rope height, and the fastest any part
## of a rope moves on screen, frame to frame, in m/s.

var _out := ""
var _every := 4
var _verbose := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--verbose":
			_verbose = true
		elif args[i] == "--every" and i + 1 < args.size():
			_every = int(args[i + 1])
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	for who: String in ["roman", "cody"]:
		await _run(who)
	get_tree().quit()


func _run(who: String) -> void:
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("roman"), Roster.by_id("cody"), 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var ropes := scene.find_child("LiveRopes", true, false) as RingRopes
	# Its own camera: the match camera re-frames itself every frame.
	var camera := Camera3D.new()
	camera.fov = 50.0
	scene.add_child(camera)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 8.0
	lamp.light_energy = 2.0 if _out != "" else 0.0
	scene.add_child(lamp)
	# Jump to his apron step, the beat before the ropes.
	var at := -1
	for i in director._beats.size():
		var b: Dictionary = director._beats[i]
		var w: WrestlerController = b.get("who")
		if w and w.entrance_style == who and b.get("clip", "") == "strikes/apron_step":
			at = i
	if at < 0:
		push_error("no apron step for " + who)
		scene.queue_free()
		return
	var w: WrestlerController = director._beats[at]["who"]
	w.visible = true
	director._beat = at
	director._start_beat()
	var peak := {}
	var top_speed := 0.0
	var prev := {}
	var frame := 0
	var through_from := -1
	while frame < 400:
		await get_tree().physics_frame
		frame += 1
		var beat: Dictionary = director._beats[mini(director._beat, director._beats.size() - 1)]
		var stepping: bool = beat.get("clip", "") == "strikes/rope_step_through_apron"
		if stepping and through_from < 0:
			through_from = frame
		# The step and a second after it, while the ropes ring down.
		if through_from < 0 or frame > through_from + 80 + 60:
			if through_from >= 0:
				break
			continue
		var fastest := 0.0
		for r: RingRopes.Rope in ropes._ropes:
			var key := "%d_%d" % [r.side, int(r.height * 100)]
			var before: Array = prev.get(key, [])
			for i in r.d.size():
				var h := int(r.height * 100)
				peak[h] = maxf(peak.get(h, 0.0), r.d[i].length())
				# What the eye sees: how far the rope moved since last frame.
				if before.size() == r.d.size():
					fastest = maxf(fastest, (r.d[i] - (before[i] as Vector2)).length() * 60.0)
			prev[key] = r.d.duplicate()
		top_speed = maxf(top_speed, fastest)
		if _verbose:
			var rel := func(b: String) -> String:
				var q: Vector3 = w._bone_world(b)
				return "%s(%.2f in %.2f)" % [b, q.y - ropes.global_position.y,
						-RingBuilder.ROPE_SPAN - q.z]
			print("  f%03d max %.2f m, %.1f m/s | %s %s %s" % [frame - through_from,
					ropes.max_deflection(), fastest, rel.call("pelvis"), rel.call("neck_01"),
					rel.call("hand_l")])
		if _out != "" and frame % _every == 0:
			# From outside the ring along the apron, away from the post and
			# side-on to him (the referee waits inside, in the way of any
			# shot from in there), so the ropes run across the frame and
			# their give reads; lit by a lamp of its own.
			camera.make_current()
			var into := -w.global_transform.basis.z
			var side := Vector3.UP.cross(into).normalized()
			if side.dot(-w.global_position) < 0.0:
				side = -side
			camera.global_position = w.global_position - into * 0.9 + side * 2.6 + Vector3.UP * 1.2
			camera.look_at(w.global_position + into * 0.2 + Vector3.UP * 0.9)
			lamp.global_position = camera.global_position + Vector3.UP * 1.0
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
					"%s/%s_%03d.png" % [_out, who, frame - through_from])
	var heights := peak.keys()
	heights.sort()
	var parts := []
	for h: int in heights:
		parts.append("%d cm %.2f" % [h, peak[h]])
	print("ROPE_ENTRY %s peak %s  top speed %.2f m/s" % [who, ", ".join(parts), top_speed])
	scene.queue_free()
	await get_tree().process_frame
