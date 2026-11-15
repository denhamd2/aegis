extends "res://tools/probe/model_turnaround.gd"
## Fixed isolated runtime character views, not full-arena/native performance evidence.

func _ready() -> void:
	preload("res://tools/probe/capture_window.gd").configure(get_window())
	var character := "kenny"
	var selected_view := ""
	var expression := ""
	var diagnostic := ""
	var animation_name := "Idle"
	var phase := .3
	_out = "/tmp/aegis-kenny-judge/baseline"
	var args := OS.get_cmdline_user_args()
	var hide_hair := args.has("--hide-hair")
	for i in maxi(args.size() - 1, 0):
		match args[i]:
			"--character": character = args[i + 1]
			"--out": _out = args[i + 1]
			"--view": selected_view = args[i + 1]
			"--expression": expression = args[i + 1]
			"--diagnostic": diagnostic = args[i + 1]
			"--animation": animation_name = args[i + 1]
			"--phase": phase = clampf(args[i + 1].to_float(), 0.0, 1.0)
	if character not in ["kenny", "cody"]:
		get_tree().quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	_set_stage()
	var model: Node3D = load("res://scenes/%s_model.tscn" % character).instantiate()
	add_child(model)
	await get_tree().process_frame
	var player := model.get_node("AnimationPlayer") as AnimationPlayer
	if not player.has_animation(animation_name):
		push_error("Unknown capture animation: %s; available: %s" % [animation_name, player.get_animation_list()])
		get_tree().quit(2)
		return
	player.play(animation_name)
	player.seek(player.get_animation(animation_name).length * phase, true)
	player.pause()
	model.set_process(false)
	if hide_hair:
		for mesh: MeshInstance3D in model.find_children("Curl*", "MeshInstance3D", true, false):
			mesh.visible = false
	if diagnostic == "groom_clay":
		var atlas := (load(KennyModel.CURL_CARDS) as Texture2D).get_image()
		if atlas.is_compressed(): atlas.decompress()
		atlas.convert(Image.FORMAT_LA8)
		atlas.convert(Image.FORMAT_RGBA8)
		atlas.generate_mipmaps()
		var neutral_atlas := ImageTexture.create_from_image(atlas)
		for mesh: MeshInstance3D in model.find_children("Curl*", "MeshInstance3D", true, false):
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(.45, .45, .45)
			material.roughness = .85
			material.metallic_specular = .05
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			if not String(mesh.name).begins_with("CurlCap"):
				material.albedo_texture = neutral_atlas
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = .25
				material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE_AND_TO_ONE
				material.alpha_antialiasing_edge = .25
			mesh.material_override = material
	elif not diagnostic.is_empty():
		var skin_names: Array = model._skin_profile()["materials"]
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var original := mesh.get_active_material(surface) as BaseMaterial3D
				if original == null or not skin_names.has(original.resource_name): continue
				var material := original.duplicate() as BaseMaterial3D
				material.normal_enabled = false
				material.detail_enabled = false
				if diagnostic == "unlit": material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				if diagnostic == "grey":
					material.albedo_texture = null
					material.albedo_color = Color(.55, .55, .55)
					material.vertex_color_use_as_albedo = false
					material.ao_enabled = false
					material.clearcoat_enabled = false
					material.roughness_texture = null
					material.roughness = .8
				mesh.set_surface_override_material(surface, material)
	if not expression.is_empty():
		var face := FaceExpression.new()
		face.install(model)
		model.add_child(face)
		for mesh in face.meshes:
			mesh.set_blend_shape_value(0 if expression == "pain_open" else 1, .75)
	var skeleton: Skeleton3D = model.get_game_skeleton()
	var head := skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin + Vector3(0, .08, 0)
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var shots := []
	for kind in ["body", "head"]:
		for view in VIEWS:
			var yaw := deg_to_rad(VIEWS[view])
			var target: Vector3 = Vector3(0, 1.05, 0) if kind == "body" else head
			var distance := 3.6 if kind == "body" else .85
			var fov := 34.0 if kind == "body" else 30.0
			if kind == "head" and view == "back":
				target.y -= .05
				distance = 1.0
				fov = 35.0
			var eye := target + Vector3(sin(yaw), 0, cos(yaw)) * distance + Vector3.UP * .04
			shots.append([kind + "_" + view, eye, target, fov, Vector3.UP])
	shots.append(["hair_top", head + Vector3(0, .67, .22), head, 34.0, Vector3.FORWARD])
	# An optional wider diagnostic includes the complete rear curl envelope.
	# The established nine scored shots keep their original cameras.
	if selected_view.split(",").has("hair_overview"):
		var overview_target := head + Vector3(0, -.02, -.08)
		shots.append(["hair_overview", overview_target + Vector3(0, .85, .24), overview_target, 40.0, Vector3.FORWARD])
	for shot in shots:
		if not selected_view.is_empty() and not selected_view.split(",").has(shot[0]): continue
		camera.fov = shot[3]
		camera.look_at_from_position(shot[1], shot[2], shot[4])
		for frame in 12: await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join(shot[0] + ".png"))
		print("CHARACTER_LIKENESS_CAPTURE ", shot[0])
	var record := {"character": character, "views": shots, "selected_view": selected_view,
		"animation": animation_name, "phase": phase,
		"hide_hair": hide_hair,
		"expression": expression, "diagnostic": diagnostic, "pipeline": RenderingServer.get_current_rendering_method(),
		"adapter": RenderingServer.get_video_adapter_name(), "native_performance": false,
		"msaa": get_viewport().msaa_3d, "taa": get_viewport().use_taa}
	FileAccess.open(_out.path_join("capture.json"), FileAccess.WRITE).store_string(JSON.stringify(record,"\t"))
	get_tree().quit()
