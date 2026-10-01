extends Node
## Posed standing height of each man, as the match shows him: the head
## bone's world height in a standing clip, plus the model's own head-bone-to-
## crown distance (measured at bind) times his scale. The model heights in
## Roster are bind-pose tops; a foreign rig driven by the base rig's clips can
## stand taller or shorter than that, and this is what the eye compares.
##
##   godot4 --headless --path game tools/probe/stature_probe.tscn

const HEAD := {"roman": ["J_Head", "head_skinned"], "cody": ["Head", "Body"],
		"kenny": ["Head", "Body"]}


func _ready() -> void:
	for id: String in ["roman", "cody", "kenny"]:
		var entry := Roster.by_id(id)
		# Bind-pose crown above the head bone.
		var model: Node3D = (load(entry.model_scene) as PackedScene).instantiate()
		add_child(model)
		await get_tree().process_frame
		var sk: Skeleton3D = model.find_child("Skeleton3D", true, false)
		var hb := sk.find_bone(HEAD[id][0])
		var bind_head := (sk.global_transform * sk.get_bone_global_rest(hb)).origin.y
		var mesh := model.find_child(HEAD[id][1], true, false) as MeshInstance3D
		var crown := (mesh.global_transform * mesh.get_aabb()).end.y - bind_head
		model.free()
		# Posed, in a match scene, in each standing clip.
		var scene: Node = load("res://scenes/match.tscn").instantiate()
		TitleScreen.configure_match(scene, entry, Roster.by_id("kenny"), 1)
		add_child(scene)
		for _i in 3:
			await get_tree().process_frame
		var w: WrestlerController = scene.get_node("WrestlerA")
		w.set_physics_process(false)
		for clip: String in ["strikes/face_off", "strikes/idle_ready"]:
			w.play_presentation_clip(clip, true)
			for _i in 20:
				await get_tree().process_frame
			var s2 := w.skeleton
			var i2 := s2.find_bone(w._skeleton_bone_name("Head") if id != "roman" else "J_Head")
			var y := (s2.global_transform * s2.get_bone_global_pose(i2)).origin.y
			print("%s %s: head bone %.3f + crown %.3f x %.3f = stands %.3f (billed %.3f)"
					% [id, clip, y, crown, w.physique_height, y + crown * w.physique_height,
					entry.stature_m])
		scene.free()
	get_tree().quit()
