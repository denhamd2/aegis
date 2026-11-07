extends Node
## HUD review with both readiness badges lit. --hud-only omits the arena
## and models for cheap layout checks; it is not arena/character evidence.
##
##   xvfb-run -a godot4 --path game --rendering-driver opengl3 \
##       --resolution 1440x900 tools/probe/hud_shot.tscn -- --out /tmp/hud.png

var _out := "/tmp/hud.png"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	if args.has("--hud-only"):
		await _hud_only()
		return
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
	a.combat.finisher_lit = true
	b.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD + 1.0
	var hud: MatchHUD = scene.get_node("MatchHUD/Draw")
	var audio := scene.get_node_or_null("MatchAudio") as MatchAudio
	if audio:
		audio.cheer = 0.8
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	print("HUD_SHOT lean=%.2f" % hud.crowd_lean())
	get_tree().quit()


func _hud_only() -> void:
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	var layer := CanvasLayer.new()
	add_child(layer)
	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.11)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(background)
	var a := WrestlerController.new()
	var b := WrestlerController.new()
	var ref := MatchReferee.new()
	a.name = "WrestlerA"
	b.name = "WrestlerB"
	a.display_name = "Roman Reigns"
	b.display_name = "Kenny Omega"
	a.is_ai = false
	b.is_ai = true
	a.combat = CombatSystem.new()
	b.combat = CombatSystem.new()
	a.combat.momentum = CombatSystem.FINISHER_THRESHOLD + 2.0
	a.combat.finisher_lit = true
	a.combat.comeback_ticks = 120
	b.combat.momentum = CombatSystem.SIGNATURE_THRESHOLD + 1.0
	var hud := MatchHUD.new()
	hud.wrestler_a = a
	hud.wrestler_b = b
	hud.referee = ref
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	# A landed move must not put a white title over the middle of the screen.
	a.move_landed.emit(a, b, load("res://resources/moves/power_samoan_drop.tres"))
	for i in 24:
		await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var error := get_viewport().get_texture().get_image().save_png(_out)
	print("HUD_SHOT scope=hud_only ready_a=%s ready_b=%s pipeline=%s" % [
			MatchHUD.meter_state(a.combat), MatchHUD.meter_state(b.combat),
			RenderingServer.get_current_rendering_method()])
	a.free()
	b.free()
	ref.free()
	get_tree().quit(error)
