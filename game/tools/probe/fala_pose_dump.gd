extends Node
## Dumps Roman's skinning matrices in a standing pose, for roman_props.py to
## build the ula fala against: the necklace has to lie on the man as he stands
## and walks, not on the T-posed bind pose of his .glb, where the trapezius
## is stretched flat and the clavicles are raised.
##
## For each bone of his body skeleton: S = global_pose * global_rest^-1 in
## skeleton space, as 12 numbers (the basis row by row, then the origin).
## That is the matrix the skin applies to a bind-pose vertex, with
## RomanHeadShape's neck widening included, because it is read off the real
## skeleton after the modifiers have run.
##
##   godot4 --headless --path game tools/probe/fala_pose_dump.tscn -- \
##       /abs/path/tools/blender/data/roman_fala_pose.json

const CLIP := "strikes/roman_stand"
const FRAMES := 45


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "/tmp/roman_fala_pose.json"
	var scene: Node = (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var pair := Roster.pair_from_spec("")
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = false
	add_child(scene)
	for i in 3:
		await get_tree().process_frame
	var roman: WrestlerController = scene.get_node("WrestlerA")
	for n in [roman, scene.get_node("WrestlerB")]:
		n.set_physics_process(false)
	roman.play_presentation_clip(CLIP, true)
	for i in FRAMES:
		await get_tree().process_frame
	var sk := roman.skeleton
	var bones := {}
	for i in sk.get_bone_count():
		var m := sk.get_bone_global_pose(i) * sk.get_bone_global_rest(i).affine_inverse()
		var b := m.basis
		var row := [b.x.x, b.y.x, b.z.x, m.origin.x,
				b.x.y, b.y.y, b.z.y, m.origin.y,
				b.x.z, b.y.z, b.z.z, m.origin.z]
		bones[sk.get_bone_name(i)] = row.map(func(v: float) -> float: return snappedf(v, 0.000001))
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"clip": CLIP, "frames": FRAMES, "skinning": bones}, "\t", true))
	f.close()
	print("FALA_POSE_DUMP %d bones -> %s" % [bones.size(), out])
	get_tree().quit()
