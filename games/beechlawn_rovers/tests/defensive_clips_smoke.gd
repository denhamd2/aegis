extends SceneTree

const CLIP_PATH := "res://assets/characters/mixamo/y_bot_animation_set.glb"
const REQUIRED := [
	"AN_Beechlawn_Idle",
	"AN_Beechlawn_Jog",
	"AN_Beechlawn_Sprint",
	"AN_Beechlawn_SlideTackle",
	"AN_Beechlawn_ShoulderImpactSell",
]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CLIP_PATH) as PackedScene
	assert(packed != null, "Defensive clip GLB failed to import")
	var actor := packed.instantiate()
	root.add_child(actor)
	await process_frame
	var players: Array[AnimationPlayer] = []
	var skeletons: Array[Skeleton3D] = []
	_collect(actor, players, skeletons)
	assert(players.size() == 1, "Expected one imported AnimationPlayer")
	assert(skeletons.size() == 1, "Expected one imported Y-Bot skeleton")
	assert(skeletons[0].get_bone_count() == 65, "Animation source skeleton mismatch")
	var library := players[0].get_animation_library("")
	assert(library != null, "Default imported animation library is missing")
	for clip_name in REQUIRED:
		assert(library.has_animation(clip_name), "Missing imported clip: %s" % clip_name)
		var animation := library.get_animation(clip_name)
		var minimum_length := 0.45 if clip_name == "AN_Beechlawn_Sprint" else 0.6
		assert(animation.length > minimum_length, "Clip is unexpectedly short: %s" % clip_name)
		assert(animation.get_track_count() >= 10, "Clip has too few bone tracks: %s" % clip_name)
		print("CLIP %s length=%.2f tracks=%d" % [clip_name, animation.length, animation.get_track_count()])
	print("Beechlawn defensive clips import and skeleton checks passed")
	quit(0)


func _collect(node: Node, players: Array[AnimationPlayer], skeletons: Array[Skeleton3D]) -> void:
	if node is AnimationPlayer:
		players.append(node)
	if node is Skeleton3D:
		skeletons.append(node)
	for child in node.get_children():
		_collect(child, players, skeletons)
