extends SceneTree
## Validate the reference-led Blender export without swapping the active roster.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var packed := load("res://assets/characters/_prototypes/shane_denham_08_prototype.glb") as PackedScene
	assert(packed != null, "Shane Denham GLB did not import as a scene")
	var actor := packed.instantiate()
	root.add_child(actor)
	await process_frame
	var skeleton := actor.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(skeleton != null and skeleton.get_bone_count() == 65,
		"Shane export must preserve the 65-bone Mixamo skeleton")
	var animation_player := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert(animation_player != null, "Shane export is missing its animation player")
	for clip_name in ["AN_Beechlawn_Idle", "AN_Beechlawn_Jog", "AN_Beechlawn_Sprint",
			"AN_Beechlawn_PassRight", "AN_Beechlawn_ShotRight"]:
		assert(animation_player.has_animation(clip_name), "Shane export lost clip %s" % clip_name)
	# The existing 54-frame shot is authored at 60 fps. A 30-fps export doubled
	# its duration and desynchronized the separate 0.3-second contact marker.
	var shot_seconds := animation_player.get_animation("AN_Beechlawn_ShotRight").length
	assert(shot_seconds > 0.8 and shot_seconds < 1.0,
		"Shane's shot export no longer preserves the authored timing: %s" % shot_seconds)
	var surface := skeleton.find_child("YBot_Surface", false, false) as MeshInstance3D
	var body := skeleton.find_child("YBot_Joints", false, false) as MeshInstance3D
	var head := skeleton.find_child("Skin_Head", false, false) as MeshInstance3D
	assert(head != null and head.mesh != null, "Shane's anatomical head is missing")
	var skin := head.mesh.surface_get_material(0) as BaseMaterial3D
	assert(skin != null and (skin.albedo_texture != null or not skin.albedo_color.is_equal_approx(Color.WHITE)),
		"The exported head lost its skin color and defaults to white")
	assert(surface != null and surface.mesh != null, "Shane jersey shell is missing")
	assert(body != null and body.mesh != null, "Unified human body mesh is missing")
	assert(surface.mesh.get_surface_count() >= 2, "The blue/black jersey stripe materials were lost")
	var textured_surface_count := 0
	var masked_hair := false
	for mesh in [surface.mesh, body.mesh]:
		for index in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(index) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				textured_surface_count += 1
			if material != null and material.resource_name == "MAT_Hair_ShortBrown":
				masked_hair = material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	assert(textured_surface_count > 0,
		"The supplied Beechlawn kit atlas was not retained in the GLB")
	assert(masked_hair, "Hair cards must import with alpha scissor rather than blended sorting")
	var triangles := 0
	for mesh_node in skeleton.find_children("*", "MeshInstance3D", true, false):
		if mesh_node.mesh != null:
			triangles += mesh_node.mesh.get_faces().size() / 3
	assert(triangles > 1000 and triangles < 120000,
		"Shane prototype triangle count is outside the lightweight gameplay range: %d" % triangles)
	print("Shane Denham Blender export loaded: 65 bones, kit texture present, geometry-based face, core clips present, %d triangles" % triangles)
	quit(0)
