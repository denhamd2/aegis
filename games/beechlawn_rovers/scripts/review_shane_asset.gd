extends Node3D
## Isolated exported-asset review with the match's light/environment settings.
## Uses the production appearance path without running football simulation.

const PLAYER: PackedScene = preload("res://scenes/footballer_visual.tscn")
const PROFILE = preload("res://data/squads/home_08.tres")
const MATCH_SCENE: PackedScene = preload("res://scenes/training_ground.tscn")
const VENUE = preload("res://scripts/kilmore_drive_venue.gd")
const REVIEW_SPOT := Vector3(-14.0, 0.0, 19.0)
var camera: Camera3D
var player: Node3D
var animation: AnimationPlayer
var _capture_callback: JavaScriptObject
var review_lighting := "default"
var review_normal_maps := true
var _native_options: Dictionary = {}

func _ready() -> void:
	_load_native_options()
	FootballCharacterLook.scattering_enabled = str(_option("ablation")) != "scattering"
	if str(_option("ablation")) == "transmittance": FootballCharacterLook.transmittance_enabled = false
	var source := MATCH_SCENE.instantiate()
	source.set("terrain_enabled", true)
	# The review builds markings before the match node enters the tree. Supply
	# the venue normally installed by TrainingGround._ready() first.
	source.set("venue", FootballMatchVenue.from_id(&"kilmore_drive"))
	var markings_mesh: Mesh = source.call("_build_line_mesh")
	add_child(source.get_node("WorldEnvironment").duplicate())
	add_child(source.get_node("Sun").duplicate())
	source.free()
	# Keep the photographed clouds, but give pitch-side portraits a lighter,
	# less saturated Dublin daylight than the dark blue source panorama.
	var review_world := $WorldEnvironment as WorldEnvironment
	var review_environment := review_world.environment.duplicate(true) as Environment
	review_world.environment = review_environment
	var review_sky := review_environment.sky.duplicate(true) as Sky
	review_environment.sky = review_sky
	var review_sky_material := review_sky.sky_material.duplicate(true) as ShaderMaterial
	review_sky.sky_material = review_sky_material
	if str(_option("sky")) != "match":
		review_sky_material.set_shader_parameter("sky_saturation", 0.52)
		review_sky_material.set_shader_parameter("sky_energy", 1.16)
		review_sky_material.set_shader_parameter("horizon_haze", 0.24)
		review_sky_material.set_shader_parameter("dark_sky_lift", 0.6)
	if OS.has_feature("debug") and (OS.has_feature("web") or not _native_options.is_empty()):
		if str(_option("software")) == "1":
			$Sun.shadow_enabled = false
			Engine.max_fps = 8
		var requested_lighting = str(_option("lighting"))
		if requested_lighting in ["sun", "shade", "soft"]:
			review_lighting = requested_lighting
			# Deliberate material QA: keep real shadowing even on SwiftShader.
			$Sun.shadow_enabled = true
			$Sun.directional_shadow_max_distance = 48.0
			if review_lighting == "soft":
				# Partly cloudy match daylight preserves pale kit details in a
				# preview without placing an artificial shade box in the image.
				$Sun.light_energy = 0.42
				$Sun.light_angular_distance = 2.5
			if review_lighting == "shade":
				var occluder := MeshInstance3D.new()
				occluder.name = "ReviewShadeCaster"
				var box := BoxMesh.new()
				box.size = Vector3(8.0, 0.2, 8.0)
				occluder.mesh = box
				# +Z points towards the directional light. Cast shade across the
				# whole player while keeping sky illumination/exposure unchanged.
				occluder.position = REVIEW_SPOT + Vector3(0, 1.0, 0) + $Sun.global_basis.z * 8.0
				occluder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				add_child(occluder)
		# Review-only ablations isolate shading defects without changing match
		# presentation. Keep the light energy identical to the chosen preset.
		if str(_option("shadows")) == "0":
			$Sun.shadow_enabled = false
		for parameter in {"shadow_bias":"shadow_bias", "normal_bias":"shadow_normal_bias", "shadow_distance":"directional_shadow_max_distance"}:
			var value = _option(parameter)
			if value != null and str(value).is_valid_float():
				$Sun.set({"shadow_bias":"shadow_bias", "normal_bias":"shadow_normal_bias", "shadow_distance":"directional_shadow_max_distance"}[parameter], maxf(0.0, str(value).to_float()))
		review_normal_maps = str(_option("normal_maps")) != "0"
		if OS.has_feature("web"):
			_capture_callback = JavaScriptBridge.create_callback(_freeze_capture)
			JavaScriptBridge.get_interface("window").BEECHLAWN_FREEZE_FRAME = _capture_callback
	# Show footballers on the actual Kilmore park, on Web as well as desktop.
	# This is the static non-detailed park layout; it avoids match simulation.
	VENUE.build(self, 105.0, 68.0)
	var ground := MeshInstance3D.new()
	ground.name = "ReviewPitch"
	ground.mesh = PitchSurface.make_mesh()
	var turf := ShaderMaterial.new()
	turf.shader = load("res://shaders/park_grass.gdshader")
	turf.set_shader_parameter("grass_albedo", load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Color.jpg"))
	turf.set_shader_parameter("grass_normal",load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_NormalGL.jpg"))
	turf.set_shader_parameter("grass_roughness",load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Roughness.jpg"))
	MatchWeather.configure_surface(turf, true, 0.65)
	ground.material_override = turf
	add_child(ground)
	var paint := MeshInstance3D.new()
	paint.name = "ReviewPitchMarkings"
	paint.mesh = markings_mesh
	var paint_material := ShaderMaterial.new()
	paint_material.shader = load("res://shaders/chalk_paint.gdshader")
	paint.material_override = paint_material
	add_child(paint)
	player = PLAYER.instantiate()
	add_child(player)
	player.position = REVIEW_SPOT + Vector3(0, PitchSurface.height_at(REVIEW_SPOT.x, REVIEW_SPOT.z), 0)
	var visual := player as FootballerVisual
	var profile := PROFILE
	if OS.has_feature("web") or not _native_options.is_empty():
		var requested = _option("player")
		# Explicit review-only allowlist; use the real roster appearance path.
		match str(requested):
			"john": profile = load("res://data/squads/home_01.tres")
			"robbie": profile = load("res://data/squads/home_10.tres")
			"david": profile = load("res://data/squads/home_05.tres")
			"away_keeper": profile = load("res://data/squads/away_01.tres")
			"des": profile = load("res://data/squads/away_09.tres")
			"referee": profile = load("res://data/officials/referee.tres")
			"paddy": profile = load("res://data/squads/home_69.tres")
	visual.configure_appearance(profile)
	if str(_option("msaa")) == "4":
		get_viewport().msaa_3d = Viewport.MSAA_4X
	if str(_option("hair_shadows")) == "0":
		for part in player.find_children("Hair_*Cards", "MeshInstance3D", true, false):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not review_normal_maps:
		var head := player.find_child("Skin_Head", true, false) as MeshInstance3D
		for surface in head.mesh.get_surface_count():
			var material := head.get_active_material(surface).duplicate() as StandardMaterial3D
			material.normal_enabled = false
			head.set_surface_override_material(surface, material)
	visual.animation_tree.active = false
	player.rotation.y = PI
	animation = visual.animation_player
	_neutral_pose()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	var view := "front"
	if OS.has_feature("web") or not _native_options.is_empty():
		var requested = _option("view")
		if requested != null:
			view = str(requested)
		var posed = _option("pose")
		var review_clips := {
			"idle":"Idle", "sprint":"Sprint", "pass":"PassRight", "shot":"ShotRight",
			"turn":"Turn90Right", "slide":"GroundedSlideTackle",
			"get_up":"GetUpFromProne", "keeper_set":"KeeperSet", "keeper_save":"KeeperSave",
		}
		if posed != null and review_clips.has(str(posed)):
			animation.play("AN_Beechlawn_"+str(review_clips[str(posed)]))
			animation.advance(0.0)
			var requested_frame = _option("frame")
			if requested_frame != null:
				var seconds := maxf(0.0, (str(requested_frame).to_float()-1.0)/60.0)
				animation.seek(minf(seconds,animation.current_animation_length),true)
			animation.pause()
	_set_view(view)
	_apply_ablation()
	if _native_options.has("capture-dir"):
		# Fixed expressions make matched head/aperture reviews reproducible.
		visual.set_process(false)
		for name in ["Blink","Smile"]:
			var index := visual._face_mesh.find_blend_shape_by_name(name)
			if index >= 0:
				visual._face_mesh.set_blend_shape_value(index,1.0 if str(_option("expression")).to_lower()==name.to_lower() else 0.0)
	var clean_capture := str(_option("clean")) == "1"
	if not clean_capture:
		var label := Label.new()
		label.text = profile.display_name + " — shared asset review\n1 front · 2 back · 3 profile · 4 face · 5 broadcast · Space idle/reset\nLighting: " + review_lighting + " · sun shadows: " + str($Sun.shadow_enabled) + " · likeness in review"
		label.position = Vector2(20, 20)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 2)
		var layer := CanvasLayer.new()
		add_child(layer)
		layer.add_child(label)
	print("SHANE_ASSET_REVIEW_READY view=", view, " renderer=", RenderingServer.get_current_rendering_method())
	await RenderingServer.frame_post_draw
	if _native_options.has("capture-dir"):
		print("NATIVE_FIRST_DRAW_COMPLETE")
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_REVIEW_LIGHTING = " + JSON.stringify({"msaa_3d":get_viewport().msaa_3d, "preset":review_lighting, "sun_shadows":$Sun.shadow_enabled, "shadow_bias":$Sun.shadow_bias, "normal_bias":$Sun.shadow_normal_bias, "shadow_distance":$Sun.directional_shadow_max_distance, "normal_maps":review_normal_maps, "occluder":has_node("ReviewShadeCaster")}))
		JavaScriptBridge.eval("window.BEECHLAWN_REVIEW_READY = true")
	elif _native_options.has("capture-dir"):
		await _capture_native(profile, view)


func _load_native_options() -> void:
	if OS.has_feature("web"):
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--") and argument.contains("="):
			var pair := argument.substr(2).split("=", true, 1)
			_native_options[pair[0]] = pair[1]

func _apply_ablation() -> void:
	var ablation := str(_option("ablation"))
	var visual := player as FootballerVisual
	if ablation == "near_heads": visual._near_head_parts = {}
	if ablation == "pose" and is_instance_valid(visual.pose_presentation): visual.pose_presentation.enabled = false
	visual._update_detail_level()
	if ablation=="sun_shadows": $Sun.shadow_enabled=false
	if ablation=="shadow_bias": $Sun.shadow_bias=.10
	if ablation=="close_shadows": $Sun.directional_shadow_max_distance=48.0
	if ablation=="normal_maps":
		review_normal_maps=false
		var face := player.find_child("Skin_Head",true,false) as MeshInstance3D
		for surface in face.mesh.get_surface_count():
			var material := face.get_active_material(surface).duplicate() as StandardMaterial3D
			material.normal_enabled=false
			face.set_surface_override_material(surface,material)
	if ablation == "morphs":
		for node in player.find_children("*", "MeshInstance3D",true,false):
			var part := node as MeshInstance3D
			if part.mesh.get_blend_shape_count()==0: continue
			var plain := ArrayMesh.new()
			for surface in part.mesh.get_surface_count():
				plain.add_surface_from_arrays(part.mesh.surface_get_primitive_type(surface),part.mesh.surface_get_arrays(surface))
				plain.surface_set_material(surface,part.mesh.surface_get_material(surface))
			part.mesh = plain

func _option(key: String) -> Variant:
	if OS.has_feature("web"):
		return JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('" + key + "')")
	return _native_options.get(key)

func _capture_native(profile: FootballerProfile, view: String) -> void:
	# A real display/render device is required. --headless uses a dummy renderer.
	var method := RenderingServer.get_current_rendering_method()
	if method != "forward_plus":
		push_error("Native look review requires Forward+, got " + method)
		get_tree().quit(2)
		return
	var warmup_frames := 24 if get_viewport().use_taa else 4
	for _frame in range(warmup_frames):
		await RenderingServer.frame_post_draw
		print("NATIVE_WARMUP_FRAME ", _frame + 1)
	var output := str(_native_options["capture-dir"])
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("Cannot create native capture directory: " + output)
		get_tree().quit(2)
		return
	var image := get_viewport().get_texture().get_image()
	var filename := str(_option("player")) + "_" + view
	if image.save_png(output.path_join(filename + ".png")) != OK:
		get_tree().quit(2)
		return
	var actual_face := player.find_child("Skin_Head",true,false) as MeshInstance3D
	var actual_material := actual_face.get_active_material(0) as StandardMaterial3D
	var report := {
		"player_id":String(profile.player_id), "name":profile.display_name,
		"view":view, "rendering_method":method,
		"adapter":RenderingServer.get_video_adapter_name(),
		"vendor":RenderingServer.get_video_adapter_vendor(),
		"api":RenderingServer.get_video_adapter_api_version(),
		"display_server":DisplayServer.get_name(), "godot":Engine.get_version_info().string,
		"resolution":[image.get_width(),image.get_height()],
		"msaa_3d":get_viewport().msaa_3d, "sun_shadows":$Sun.shadow_enabled,
		"shadow_bias":$Sun.shadow_bias,"normal_bias":$Sun.shadow_normal_bias,"shadow_distance":$Sun.directional_shadow_max_distance,
		"sky":"match" if str(_option("sky")) == "match" else "review",
		"lighting":review_lighting, "pose":str(_option("pose")),
		"expression":str(_option("expression")),
		"normal_maps":review_normal_maps, "warmup_frames":warmup_frames,
		"temporal_aa":get_viewport().use_taa,
		"runtime_head_mesh":actual_face.mesh.resource_path,
		"closeup_detail":(player as FootballerVisual)._near_view,
		"body_fullness":(player as FootballerVisual)._appearance_profile.appearance.body_fullness,
		"skin_scattering":actual_material.subsurf_scatter_enabled,
		"skin_transmittance":actual_material.subsurf_scatter_transmittance_enabled,
		"ablation":str(_option("ablation")),
		"scope":"Native Forward+ still; hardware-specific Mac appearance and performance remain unmeasured.",
	}
	var file := FileAccess.open(output.path_join(filename + ".json"), FileAccess.WRITE)
	if file == null:
		get_tree().quit(2)
		return
	file.store_string(JSON.stringify(report,"  ") + "\n")
	print("BEECHLAWN_NATIVE_CAPTURE ", JSON.stringify(report))
	get_tree().quit()

func _freeze_capture(_arguments: Array) -> void:
	get_tree().paused = true
	Engine.max_fps = 1

func _neutral_pose() -> void:
	animation.stop()
	var skeleton := player.find_child("Skeleton3D", true, false) as Skeleton3D
	skeleton.reset_bone_poses()
	for side in ["Left", "Right"]:
		# Godot normalizes glTF's colon to an underscore on import.
		var index := skeleton.find_bone("mixamorig_" + side + "Arm")
		assert(index >= 0, "Review pose is missing the imported arm bone")
		var rest := skeleton.get_bone_global_rest(index)
		var angle := deg_to_rad(-75.0 if side == "Left" else 75.0)
		# glTF converts Blender armature-local Z to skeleton-local Y. Rotating
		# around the old Z axis folds the arms behind the back in this import.
		var desired := Transform3D(Basis(Vector3.UP, angle) * rest.basis, rest.origin)
		var parent := skeleton.get_bone_parent(index)
		var local := skeleton.get_bone_global_rest(parent).affine_inverse() * desired
		var rotation := skeleton.get_bone_rest(index).basis.inverse() * local.basis
		skeleton.set_bone_pose_rotation(index, rotation.get_rotation_quaternion())

func _set_view(view: String) -> void:
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 26.0
	var target := REVIEW_SPOT + Vector3(0, 0.94, 0)
	match view:
		"kit":
			camera.fov = 13.0
			camera.position = REVIEW_SPOT + Vector3(0,1.60,4.7)
			target = REVIEW_SPOT + Vector3(0,1.45,0)
		"back": camera.position = REVIEW_SPOT + Vector3(0, 1.45, -5.5)
		"profile": camera.position = REVIEW_SPOT + Vector3(5.5, 1.45, 0)
		"portrait":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 25.0
			camera.position = REVIEW_SPOT + Vector3(0, 1.67, 1.20)
			target = REVIEW_SPOT + Vector3(0, 1.67, 0)
		"head_detail":
			# Skin/lid inspection uses the actual roster mesh and unchanged
			# pitch daylight, with a longer lens instead of a wide close camera.
			camera.fov = 16.0
			camera.position = REVIEW_SPOT + Vector3(0, 1.67, 1.12)
			target = REVIEW_SPOT + Vector3(0, 1.67, 0)
		"threequarter_portrait", "threequarter_opposite", "profile_portrait", "profile_opposite", "rear_portrait":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 25.0
			var turned := view.begins_with("threequarter")
			var side := -1.0 if view.ends_with("opposite") else 1.0
			camera.position = REVIEW_SPOT + (Vector3(.78 * side, 1.67, .95) if turned else Vector3(1.20 * side, 1.67, 0))
			if view == "rear_portrait":
				camera.position = REVIEW_SPOT + Vector3(.65, 1.70, -1.05)
			target = REVIEW_SPOT + Vector3(0, 1.67, 0)
		"broadcast":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 50.0
			camera.position = REVIEW_SPOT + Vector3(0, 17, 36)
			target = REVIEW_SPOT
		_: camera.position = REVIEW_SPOT + Vector3(0, 1.45, 5.5)
	camera.look_at(target)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			if animation.is_playing():
				_neutral_pose()
			else:
				animation.play("AN_Beechlawn_Idle")
			return
		var views := {KEY_1:"front", KEY_2:"back", KEY_3:"profile", KEY_4:"portrait", KEY_5:"broadcast"}
		if views.has(event.keycode):
			_set_view(views[event.keycode])
