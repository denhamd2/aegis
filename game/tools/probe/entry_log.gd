extends Node
## Logs each man's ring entry tick by tick through the real entrance flow:
## the director's root, where his hips actually are, and what the animation
## tree is playing. A "ghost" (ropes parting with no body there, a float, a
## snap into the ring) shows as the hips straying from the root, or the
## state machine not on the clip the beat asked for.
##
##   godot --headless --path game tools/probe/entry_log.tscn

const MATCH_SCENE := "res://scenes/match.tscn"
const KINDS := ["clip", "turn"]


func _ready() -> void:
	var pair := Roster.pair_from_spec("")
	var scene: Node = load(MATCH_SCENE).instantiate()
	TitleScreen.configure_match(scene, pair[0], pair[1], 7)
	scene.entrances = true
	get_tree().root.add_child.call_deferred(scene)
	await get_tree().process_frame
	await get_tree().process_frame
	var director: EntranceDirector = scene.get_node("EntranceDirector")
	var rang := [false]
	director.bell.connect(func(): rang[0] = true)
	var tick := 0
	var last_beat := -1
	var prev_hips := {}
	while not rang[0] and tick < 60 * 400:
		await get_tree().physics_frame
		tick += 1
		if director._beat >= director._beats.size():
			continue
		var b: Dictionary = director._beats[director._beat]
		var w: WrestlerController = b.get("who")
		if w == null:
			continue
		var shot := String(b.get("shot", ""))
		var near_ring := shot in ["ringside", "rope_wide", "ring_behind_low", "bow_close"]
		if not near_ring:
			continue
		var hips := w.global_position
		if w.skeleton:
			# The base rig calls it "pelvis" (Cody, Kenny); Roman's own rig "J_Hips".
			var i := w.skeleton.find_bone("pelvis")
			if i < 0:
				i = w.skeleton.find_bone("J_Hips")
			if i >= 0:
				hips = w.skeleton.global_transform * w.skeleton.get_bone_global_pose(i).origin
		var node := String(w._anim_playback.get_current_node()) if w._anim_playback else "?"
		var playing := ""
		if w.anim_tree:
			var m := w.anim_tree.tree_root as AnimationNodeStateMachine
			var an := m.get_node(node) as AnimationNodeAnimation if m.has_node(node) else null
			playing = String(an.animation) if an else node
		var jump: float = (hips - prev_hips.get(w, hips)).length()
		prev_hips[w] = hips
		var off := Vector2(hips.x - w.global_position.x, hips.z - w.global_position.z).length()
		if director._beat != last_beat or tick % 10 == 0 or jump > 0.15 or off > 0.6:
			print("ENTRY %s t%d beat%d %s %s clip=%s tree=%s root=%s hips=%s off=%.2f jump=%.2f vis=%s" % [
					w.entrance_style, tick, director._beat, b["kind"], shot, b.get("clip", ""),
					playing, _v(w.global_position), _v(hips), off, jump, w.visible])
			last_beat = director._beat
	print("ENTRY_DONE ticks=%d bell=%s" % [tick, rang[0]])
	get_tree().quit()


static func _v(p: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [p.x, p.y, p.z]
