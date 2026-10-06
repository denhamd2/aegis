extends Node
## One frame of the match HUD with its broadcast extras lit: the banner and
## clock, both plates' ready pips, a move-name pop-up and a leaning crowd.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1440x900 tools/probe/hud_shot.tscn -- --out /tmp/hud.png

var _out := "/tmp/hud.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 3)
	scene.entrances = false
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	get_tree().current_scene = scene
	for _i in 30:
		await get_tree().physics_frame
	var a: WrestlerController = scene.get_node("WrestlerA")
	var b: WrestlerController = scene.get_node("WrestlerB")
	a.combat.momentum = CombatSystem.FINISHER_THRESHOLD + 2.0
	b.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD + 1.0
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	hud._elapsed = 312.0
	hud._on_move_landed(a, b, load("res://resources/moves/power_samoan_drop.tres"))
	var audio := scene.get_node_or_null("MatchAudio") as MatchAudio
	if audio:
		audio.cheer = 0.8
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("HUD_SHOT lean=%.2f" % hud.crowd_lean())
	get_tree().quit()
