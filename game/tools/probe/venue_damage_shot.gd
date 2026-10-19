extends Node3D
## The rocket launcher's damage, one of each: a frame per wrecked piece --
## a barricade panel, the announce desk, a ring post, the apron, the steps,
## an LED wall and the video wall on fire, the crowd on fire -- through the
## match's own renderer, a few seconds after the blasts so the fires are up.
##
##   xvfb-run -a godot4 --path game --rendering-driver vulkan \
##       --resolution 1280x720 tools/probe/venue_damage_shot.tscn -- --out /tmp/damage
##
## Writes <out>/<view>.png for each view below.

const MATCH_SCENE := "res://scenes/match.tscn"
## [name, camera at, looking at] -- the barricade, post, apron and steps views
## are aimed at the pieces this probe hits (_aim).
var VIEWS := [
	["desk", Vector3(3.6, 0.6, 3.6), Vector3(0.0, -0.4, 7.6)],
	["barricade", Vector3.ZERO, Vector3.ZERO],
	["post", Vector3.ZERO, Vector3.ZERO],
	["apron", Vector3.ZERO, Vector3.ZERO],
	["steps", Vector3.ZERO, Vector3.ZERO],
	["screens", Vector3(0.0, 3.0, -20.0), Vector3(0.0, 4.0, -36.0)],
	["crowd", Vector3(0.0, 2.5, -2.0), Vector3(-14.0, 1.0, 6.0)],
]

var _out := "/tmp/damage"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--out" and i + 1 < args.size():
			_out = args[i + 1]
	DirAccess.make_dir_recursive_absolute(_out)
	var scene: Node = load(MATCH_SCENE).instantiate()
	MatchRules.set_mode(scene, MatchRules.Mode.NO_HOLDS_BARRED)
	add_child(scene)
	await get_tree().process_frame
	var d := VenueDamage.of(scene.get_node("WrestlerA"))
	d.ensure_targets()
	# each piece, hit the way a rocket would hit it
	var panel: Array = ArenaBuilder.barricade_panels()[1]
	var out_dir: Vector3 = panel[2]
	var at: Vector3 = panel[0]
	d.blast(Vector3(at.x, ArenaBuilder.FLOOR_Y + 0.6, at.z) - out_dir * 0.2, -out_dir)
	_aim("barricade", Vector3(at.x, ArenaBuilder.FLOOR_Y + 1.4, at.z) - out_dir * 3.2,
			Vector3(at.x, ArenaBuilder.FLOOR_Y + 0.4, at.z))
	for t: VenueDamage.Target in d.targets:
		match t.name:
			"CommentaryDesk":
				d.blast(t.box * Vector3(0.0, 0.0, -t.half.z), Vector3.BACK, t)
			"PostES":
				d.blast(t.box.origin, Vector3.UP, t)
				_aim("post", t.place.origin + t.place.basis.z * 3.0 + Vector3.UP * 1.0,
						t.place.origin + Vector3.UP * 0.3)
			"ApronN":
				d.blast(t.box * Vector3(1.2, 0.0, t.half.z), t.box.basis.z, t)
				var on := t.box * Vector3(1.2, 0.0, t.half.z)
				_aim("apron", on + t.box.basis.z * 2.6 + Vector3.UP * 0.4, on)
			"SideScreenR", "SideScreenL":
				d.blast(t.box * Vector3(0.6, 0.4, t.half.z), t.box.basis.z, t)
			"VideoWall":
				d.blast(t.box * Vector3(-3.0, -0.8, t.face_z(-3.0)), Vector3.BACK, t)
	for t: VenueDamage.Target in d.targets:
		if t.kind == VenueDamage.Kind.RING_STEPS:
			d.blast(t.box.origin, Vector3.UP, t)
			_aim("steps", t.place.origin + t.place.basis.z * 3.0 + t.place.basis.x * 1.2 + Vector3.UP * 1.2,
					t.place.origin + Vector3.UP * 0.3)
			break
	d.blast(Vector3(-13.0, ArenaBuilder.FLOOR_Y + 1.0, 4.0), Vector3.UP, null, true)
	print("damaged: ", d.history.size(), " fires: ", d.fires.size())
	for _i in 150:
		await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true
	cam.fov = 55.0
	for v: Array in VIEWS:
		cam.global_position = v[1]
		cam.look_at(v[2], Vector3.UP)
		for _i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_out, v[0]])
	get_tree().quit()


func _aim(view: String, from: Vector3, at: Vector3) -> void:
	for v: Array in VIEWS:
		if v[0] == view:
			v[1] = from
			v[2] = at
