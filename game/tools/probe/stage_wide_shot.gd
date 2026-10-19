extends Node3D
## A wide frame of the entrance set from behind the ring, for judging the stage
## against the owner's AEW still. Held still so two runs frame the same set.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1600x900 tools/probe/stage_wide_shot.tscn -- --out /tmp/stage.png
##
## --nhb lays the No Holds Barred stage weapons out on the deck
## (WeaponStock.STAGE_LAYOUT), as the bell does.
## --pyro CUE --wait SECONDS fires EntrancePyro's CUE (opening, cody_hit, roman,
## ...) and holds that long before the frame.
## --sign SECONDS raises the ENDA FEARS OMAR fan and frames him the way the
## opening's sign cutaway does (EntranceDirector.opening_shot_at), that long
## after he starts up.

const MATCH_SCENE := "res://scenes/play.tscn"
var _out := "/tmp/stage_wide.png"
var _pos := Vector3(0.0, 3.6, 5.5)
var _look := Vector3(0.0, 4.6, -38.0)
var _fov := 62.0


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
		elif args[i] == "--pos" and i + 1 < args.size():
			_pos = _vec(args[i + 1])
		elif args[i] == "--look" and i + 1 < args.size():
			_look = _vec(args[i + 1])
		elif args[i] == "--fov" and i + 1 < args.size():
			_fov = float(args[i + 1])
	add_child(load(MATCH_SCENE).instantiate())
	await get_tree().process_frame
	if args.has("--nhb"):
		MatchRules.set_mode(self, MatchRules.Mode.NO_HOLDS_BARRED)
		var stock := WeaponStock.new()
		stock.name = "WeaponStock"
		add_child(stock)
		stock.seed_stage_weapons()
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = _fov
	cam.global_position = _pos
	cam.look_at(_look, Vector3.UP)
	var cue := ""
	var wait := 0.0
	for i in args.size():
		if args[i] == "--pyro" and i + 1 < args.size():
			cue = args[i + 1]
		elif args[i] == "--wait" and i + 1 < args.size():
			wait = float(args[i + 1])
	var sign_wait := -1.0
	for i in args.size():
		if args[i] == "--sign" and i + 1 < args.size():
			sign_wait = float(args[i + 1])
	if sign_wait >= 0.0:
		var fans := get_tree().get_first_node_in_group("sign_fans") as SignFans
		if fans:
			fans.raise_enda_easter_egg(60.0)
		var fan: SignFan = fans.enda_easter_egg_fan() if fans else null
		if fan:
			# from the ring side, a few metres off, at his chest
			var at := fan.global_position
			var to_ring := Vector3(-signf(at.x), 0.0, 0.0)
			_look = at + Vector3.UP * 1.25
			_pos = _look + to_ring * 3.2 + Vector3.UP * 0.15 + Vector3(0.0, 0.0, 0.6)
			_fov = 40.0
		for _i in int(sign_wait * 60.0):
			await get_tree().physics_frame
		cam.fov = _fov
		cam.global_position = _pos
		cam.look_at(_look, Vector3.UP)
	if cue != "":
		var pyro := EntrancePyro.new()
		add_child(pyro)
		pyro.fire(cue)
		for _i in int(wait * 60.0):
			await get_tree().physics_frame
	for _i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out)
	get_tree().quit()


func _vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
