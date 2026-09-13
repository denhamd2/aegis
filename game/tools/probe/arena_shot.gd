extends Node
## Grabs a still of the arena with two real wrestlers in the ring.
##
## match.tscn on its own spawns the box mannequins -- the roster's models,
## colourways and names only arrive through TitleScreen.configure_match(),
## which is the call the title screen launches a match with. Every other
## shot probe here either renders a lone model (bare_render, roman_shots) or
## drives one state (state_shot, pin_shot); none of them frames the ARENA with
## the pair in it, which is what this is for.
##
## Shot through the scene's own MatchCamera, not a hand-placed one, so what it
## saves is the framing a player actually gets.
##
## Usage:
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1920x1080 tools/probe/arena_shot.tscn -- --out /tmp/arena

const MATCH_SCENE := "res://scenes/match.tscn"

var _out := "/tmp/arena"
var _wrestlers := ""
var _settle := 90

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--wrestlers" and i + 1 < args.size():
			_wrestlers = args[i + 1]
		elif args[i] == "--settle" and i + 1 < args.size():
			_settle = int(args[i + 1])
	DirAccess.make_dir_recursive_absolute(_out)

	var pair := Roster.pair_from_spec(_wrestlers)
	if pair.is_empty():
		get_tree().quit(1)
		return
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 1)
	scene.match_seed = 1
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	await get_tree().process_frame

	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	for w: WrestlerController in [a, b]:
		w.is_ai = true
	print("ARENA %s vs %s" % [pair[0].display_name(), pair[1].display_name()])

	# Let the models load and the two square up, then let the camera's own
	# follow settle -- grabbed on the first tick it frames the pair mid-lerp.
	for frame in _settle:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/arena.png" % _out)
	print("  wrote %s/arena.png  separation %.2f m" % [
			_out, a.global_position.distance_to(b.global_position)])
	get_tree().quit()
