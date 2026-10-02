extends Node
## Entrance stills from a beat by INDEX, for lighting passes
## (gauntlet/refs/lighting_2k26.md items 7-12; README "Lighting 2K26 items
## 5-12, verified on pixels"). entrance_shots --from-shot jumps to the first
## beat with a shot name, which is Cody's where both men share one, and skips
## the cues of the beats before it; this takes the index and replays the cues
## you name, so Roman's ring poses render with his house dim and tron on.
##
##   godot4 --headless --path game tools/probe/lighting_2k26_entrance.tscn -- --list
##   xvfb-run -a godot4 --path game --rendering-driver vulkan --resolution 960x540 \
##       --fixed-fps 30 tools/probe/lighting_2k26_entrance.tscn -- --out /tmp/e \
##       --from-beat 65 --events tron_on,dim_on --frames 400 --every 50 --tag on
##
## A/B switches, applied every frame after the director's own writes:
##   --no-posetop  hides the item-12 PoseTop;
##   --old-bloom   the look before item 10: glow threshold 1.25, the in-ring
##                 follow spot at full, ring keys/top at 100% of the match look.
## Props and the coat are not re-cued (a jump past Cody's beat 9 has no coat).

const MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/l2k_e"
var _from := 0
var _events: PackedStringArray = []
var _frames := 120
var _every := 30
var _no_top := false
var _old_bloom := false
var _tag := "x"
var _director: EntranceDirector
var _rig: ArenaLighting


func _ready() -> void:
	process_priority = 10000
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var nxt: String = args[i + 1] if i + 1 < args.size() else ""
		match args[i]:
			"--out": _out = nxt
			"--from-beat": _from = int(nxt)
			"--events": _events = nxt.split(",", false)
			"--frames": _frames = int(nxt)
			"--every": _every = int(nxt)
			"--no-posetop": _no_top = true
			"--old-bloom": _old_bloom = true
			"--tag": _tag = nxt
	DirAccess.make_dir_recursive_absolute(_out)
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	_director = scene.get_node("EntranceDirector")
	_rig = get_tree().get_first_node_in_group("arena_lighting") as ArenaLighting
	if "--list" in args:
		for i in _director._beats.size():
			var b: Dictionary = _director._beats[i]
			print("L2KB %d %s %s %s who=%s ticks=%s ev=%s" % [i, b["kind"], b.get("shot", ""),
					b.get("clip", ""), (b["who"] as Node).name if b.get("who") else "-",
					b.get("ticks", ""), b.get("events", [])])
		get_tree().quit()
		return
	var bt: Dictionary = _director._beats[_from]
	var w: WrestlerController = bt["who"]
	w.visible = true
	if bt.has("path"):
		w.global_position = bt["path"][0]
	elif bt.has("from"):
		w.global_position = bt["from"]
	else:
		w.global_position = Vector3(-0.4, 0.0, -0.6)
	if _old_bloom:
		# Undo item 10's ring share before any dim scales it.
		for l in _rig._ring_lights:
			l.light_energy /= ArenaLighting.ENTRANCE_RING_SHARE
	for e in _events:
		_director._event(w, e)
	_director._beat = _from
	_director._start_beat()
	print("L2KE jump beat %d %s %s" % [_from, bt["kind"], bt.get("shot", "")])
	for f in _frames:
		RenderingServer.render_loop_enabled = (f % _every == 0) or (f % _every >= _every - 2)
		if RenderingServer.render_loop_enabled:
			await RenderingServer.frame_post_draw
		else:
			await get_tree().process_frame
		if f % _every == 0:
			get_viewport().get_texture().get_image().save_png(
					"%s/%s_%04d.png" % [_out, _tag, f])
			print("L2KE frame %d beat %d %s" % [f, _director._beat,
					(_director._beats[_director._beat] as Dictionary).get("shot", "")])
	get_tree().quit()


func _process(_delta: float) -> void:
	if _director == null:
		return
	if _no_top and _director._top:
		_director._top.visible = false
	if _old_bloom:
		var env := _rig._environment()
		if env:
			env.glow_hdr_threshold = ArenaLighting.GLOW_THRESHOLD_MATCH
		if _director._follow and _director._follow.visible:
			_director._follow.light_energy = EntranceDirector.FOLLOW_SPOT_ENERGY
