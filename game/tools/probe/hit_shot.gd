extends Node
## Renders the first heavy blows of an AI match: the frames either side of
## each, so the flinch (HitFlinch) and the hit-stop can be seen.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 --fixed-fps 60 \
##       --resolution 960x540 tools/probe/hit_shot.tscn -- --out /tmp/hits \
##       [--seed 1 --hits 2 --min 0.9 --wrestlers roman,cody]
##
## Each blow is framed from the side of the line between the two men.

var _out := "/tmp/hits"
var _seed := 1
var _hits := 2
var _min := 0.9
var _spec := ""
## --dry: headless, no frames -- print the tick and size of every blow.
var _dry := false
## --skip N: run the first N ticks headless-fast before looking.
var _skip := 0
## --reversals: film parries (WrestlerController.reversed) instead of blows.
var _reversals := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		match args[i]:
			"--out": _out = args[i + 1]
			"--seed": _seed = int(args[i + 1])
			"--hits": _hits = int(args[i + 1])
			"--min": _min = float(args[i + 1])
			"--wrestlers": _spec = args[i + 1]
			"--dry": _dry = true
			"--skip": _skip = int(args[i + 1])
			"--reversals": _reversals = true
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec(_spec)
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], _seed)
	scene.match_seed = _seed
	add_child(scene)
	var ws: Array[WrestlerController] = [scene.get_node("WrestlerA"), scene.get_node("WrestlerB")]
	for w in ws:
		w.is_ai = true
	var cam := Camera3D.new()
	scene.add_child(cam)
	cam.fov = 40.0
	var seen := [0, 0]
	var shot := 0
	var tick := 0
	while shot < _hits and tick < 20000:
		await get_tree().physics_frame
		tick += 1
		if _reversals:
			for i in 2:
				if ws[i].reversals_landed > seen[i]:
					seen[i] = ws[i].reversals_landed
					if _dry:
						print("REVERSAL t%d %s" % [tick, ws[i].name])
						shot += 1
					elif tick >= _skip:
						await _film(cam, ws[1 - i], ws[i], shot, 24)
						shot += 1
			continue
		for i in 2:
			var f := ws[i].hit_flinch
			if f == null:
				continue
			var n := f._hits.size()
			if n > 0 and f._hits[n - 1]["start"] != seen[i] \
					and float(f._hits[n - 1]["strength"]) >= _min:
				seen[i] = f._hits[n - 1]["start"]
				if _dry:
					print("BLOW t%d %s %s %.2f" % [tick, ws[i].name, f._hits[n - 1]["zone"], f._hits[n - 1]["strength"]])
					shot += 1
					continue
				if tick < _skip:
					continue
				await _film(cam, ws[i], ws[1 - i], shot)
				shot += 1
			elif n > 0:
				seen[i] = f._hits[n - 1]["start"]
	get_tree().quit()


func _film(cam: Camera3D, victim: WrestlerController, hitter: WrestlerController, n: int, ticks := 16) -> void:
	var mid := (victim.global_position + hitter.global_position) * 0.5
	var line := victim.global_position - hitter.global_position
	line.y = 0.0
	var side := Vector3.UP.cross(line.normalized())
	cam.global_position = mid + side * 3.6 + Vector3.UP * 1.3
	cam.look_at(mid + Vector3.UP * 1.1, Vector3.UP)
	cam.current = true
	for t in ticks:
		await RenderingServer.frame_post_draw
		if t % 2 == 0:
			get_viewport().get_texture().get_image().save_png("%s/hit%d_%02d.png" % [_out, n, t])
		await get_tree().physics_frame
