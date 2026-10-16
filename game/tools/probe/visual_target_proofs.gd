extends Node
## Reproducible proof shots for the owner's eight-pair October 16 reference set.
## --bounded uses the actual stage assets without the bowl to fit small hosts.
## --studio --portrait-view all captures fixed front/three-quarter/profile
## studies of each hero. Neither study mode measures animation or frame rate.
## Software Forward+ is appearance evidence only, never M1 Pro performance.

const WindowCapture := preload("res://tools/probe/capture_window.gd")
const SHOTS := ["stage", "roman_ramp", "cody_coat"]

var _out := "/tmp/aegis-visual-proofs"
var _only := ""
var _settle := 24
var _bounded := false
var _studio := false
var _portrait := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_bounded = args.has("--bounded")
	_studio = args.has("--studio")
	for i in maxi(args.size() - 1, 0):
		match args[i]:
			"--out": _out = args[i + 1]
			"--only": _only = args[i + 1]
			"--settle": _settle = maxi(12, int(args[i + 1]))
			"--portrait-view": _portrait = args[i + 1]
	if _portrait not in ["", "front", "threequarter", "profile", "all"]:
		push_error("Unknown portrait view: " + _portrait)
		get_tree().quit(2)
		return
	if (not _only.is_empty() and not SHOTS.has(_only)) \
			or ((_studio or not _portrait.is_empty()) and _only == "stage"):
		push_error("Unknown proof shot: " + _only)
		get_tree().quit(2)
		return
	if (not _portrait.is_empty() or args.has("--dry-skin")) and not (_bounded or _studio):
		push_error("Portrait and dry-skin diagnostics require --studio or --bounded.")
		get_tree().quit(2)
		return
	WindowCapture.configure(get_window())
	if DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "forward_plus":
		push_error("Visual proofs require the shipping Forward+ renderer.")
		get_tree().quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(_out) != OK:
		push_error("Cannot create proof output directory: " + _out)
		get_tree().quit(1)
		return
	if _bounded or _studio:
		await _material_study()
		return
	var scene: Node = load("res://scenes/match.tscn").instantiate()
	TitleScreen.configure_match(scene, Roster.by_id("cody"), Roster.by_id("roman"), 3)
	scene.entrances = true
	add_child(scene)
	var director := scene.get_node("EntranceDirector") as EntranceDirector
	director.set_physics_process(false)
	var camera := scene.get_node("MatchCamera") as MatchCamera
	camera.set_physics_process(false)
	var rig := scene.get_node("LightRig") as ArenaLighting
	if args.has("--stage-probe"):
		rig.stage_reflections = true
		rig._build_stage_reflections()
	var cody := scene.get_node("WrestlerA") as WrestlerController
	var roman := scene.get_node("WrestlerB") as WrestlerController
	for actor: WrestlerController in [cody, roman]:
		actor.set_physics_process(false)
		actor.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		if actor.ai:
			actor.ai.set_physics_process(false)
		if actor.inertializer:
			actor.inertializer.active = false
	if director._skip_button:
		director._skip_button.hide()
	RenderingServer.global_shader_parameter_set("crowd_flash_rate", 0.0)
	RenderingServer.global_shader_parameter_set("crowd_excitement", 0.0)
	var captures: Array[Dictionary] = []
	for shot: String in SHOTS:
		if not _only.is_empty() and _only != shot:
			continue
		print("VISUAL_PROOF preparing ", shot)
		director._dim_house(false)
		rig.set_look(ArenaLighting.Look.ENTRANCE)
		cody.visible = false
		roman.visible = false
		var actor: WrestlerController = null
		match shot:
			"stage":
				camera.set_entrance_shot(Vector3(0, 11.6, 14), Vector3(0, 3.5, -18), 56, true, 1.0 / 60.0, false)
			"roman_ramp":
				actor = roman
				camera.set_entrance_shot(Vector3(0, 1.68, -24.2), Vector3(0, 1.44, -26), 34, true, 1.0 / 60.0, false)
			"cody_coat":
				actor = cody
				camera.set_entrance_shot(Vector3(-0.7, 1.68, -24.2), Vector3(0, 1.44, -26), 34, true, 1.0 / 60.0, false)
		if actor:
			actor.global_position = Vector3(0, 0, -26)
			actor.opponent.global_position = actor.global_position + Vector3.BACK * 6.0
			actor.rotation.y = PI
			actor.visible = true
			actor.play_presentation_clip("strikes/roman_stand" if actor == roman else "strikes/face_off", true)
			actor.anim_tree.advance(0.8)
			if actor == roman and not director._props.has(actor):
				director._props[actor] = EntranceProps.dress(actor, true)
			if actor == cody and not director._coats.has(actor):
				director._coats[actor] = EntranceCoat.dress(actor)
			director._dim_house(true, EntranceDirector.WALK_HOUSE_DIM, EntranceDirector.WALK_AMBIENT_DIM)
		director._follow_off = false
		director._aim_follow_spot(actor)
		for _frame in _settle:
			await RenderingServer.frame_post_draw
		var picture := get_viewport().get_texture().get_image()
		var path := _out.path_join(shot + ".png")
		if picture.save_png(path) != OK:
			get_tree().quit(1)
			return
		captures.append({"shot": shot, "image": path, "width": picture.get_width(),
			"height": picture.get_height(), "camera_at": str(camera.global_position),
			"camera_basis": str(camera.global_basis), "fov": camera.fov})
		print("VISUAL_PROOF saved ", path)
	var manifest := {"captures": captures, "seed": 3, "settle_frames": _settle,
		"scope": "complete_arena"}
	manifest.merge(_render_metadata())
	var file := FileAccess.open(_out.path_join("proof_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	get_tree().quit()


## Load the actual material adapters without their animation-library copy.
## The bind-pose study is explicitly labelled: it judges material response,
## not animation, prop fit, complete-arena appearance or Mac performance.
func _study_model(id: String) -> Node3D:
	var model: Node3D = (load(Roster.by_id(id).model_scene) as PackedScene).instantiate()
	model.set_meta("material_study", true)
	model.position = Vector3(0, 0, -26)
	add_child(model)
	if id == "cody":
		BodyBulk.apply(model, model.get_game_skeleton(), BodyBulk.CODY)
		model._fix_look()
		model._fix_eyes()
		model._add_hair()
	else:
		BodyBulk.apply(model, model.get_game_skeleton(), BodyBulk.ROMAN)
		RomanFaceShape.apply(model)
		model._fix_materials()
		model._fix_eyes()
		var lids: EyeLids = model.build_eye_lids()
		if lids:
			lids.hold(0.0) # Comparable stills; the separate blink diagnostic overrides it.
		model._trim_beard()
		model._volumize_hair()
	for material: BaseMaterial3D in model.get_meta("skin_materials", []):
		SkinLook.set_wetness(material, 0.0 if OS.get_cmdline_user_args().has("--dry-skin") else Sweat.BASE)
	return model


func _study_spot(at: Vector3, aim: Vector3, energy: float, tint: Color,
		range_m: float, angle: float, specular: float, shadow: bool = false) -> SpotLight3D:
	var light := SpotLight3D.new()
	light.light_color = tint
	light.light_energy = energy
	light.spot_range = range_m
	light.spot_angle = angle
	light.spot_angle_attenuation = 1.6
	light.spot_attenuation = 0.6
	light.light_specular = specular
	light.light_volumetric_fog_energy = 0.0
	light.shadow_enabled = shadow
	light.light_size = 0.12 if shadow else 0.0
	add_child(light)
	light.look_at_from_position(at, aim)
	return light


func _material_study() -> void:
	var template: Node = load("res://scenes/match.tscn").instantiate()
	var world: WorldEnvironment = template.get_node("WorldEnvironment").duplicate()
	world.environment = world.environment.duplicate(true)
	add_child(world)
	if not _studio:
		var arena := Node3D.new()
		arena.set_script(load("res://tools/probe/visual_target_stage.gd"))
		arena.name = "Arena"
		add_child(arena)
		var rig := ArenaLighting.new()
		rig.name = "LightRig"
		rig.stage_reflections = OS.get_cmdline_user_args().has("--stage-probe")
		add_child(rig)
		rig.set_look(ArenaLighting.Look.ENTRANCE)
		if OS.get_cmdline_user_args().has("--no-glints") and rig._glints:
			rig._glints.visible = false
	else:
		world.environment.ambient_light_energy = 0.12
		world.environment.background_color = Color(0.04, 0.04, 0.05)
		world.environment.volumetric_fog_enabled = false
	template.free()
	var no_fog := OS.get_cmdline_user_args().has("--no-fog")
	if no_fog:
		world.environment.volumetric_fog_enabled = false
		for volume in find_children("*", "FogVolume", true, false):
			(volume as FogVolume).visible = false
	var camera := Camera3D.new()
	add_child(camera)
	camera.make_current()
	var roman: Node3D = null
	var cody: Node3D = null
	var coat: Node3D = null
	var lights: Array[SpotLight3D] = []
	var captures: Array[Dictionary] = []
	for shot: String in SHOTS:
		if (_studio or not _portrait.is_empty()) and shot == "stage":
			continue
		if not _only.is_empty() and _only != shot:
			continue
		for model: Node3D in [roman, cody, coat]:
			if model:
				model.visible = false
		for light in lights:
			light.visible = shot != "stage"
		if shot == "stage":
			camera.fov = 56
			camera.look_at_from_position(Vector3(0, 11.6, 14), Vector3(0, 3.5, -18))
		else:
			camera.fov = 34
			camera.look_at_from_position(Vector3(-0.7 if shot == "cody_coat" else 0.0, 1.68, -24.2), Vector3(0, 1.44, -26))
			if shot == "roman_ramp":
				if roman == null:
					roman = _study_model("roman")
				roman.visible = true
			else:
				if cody == null:
					cody = _study_model("cody")
					coat = (load(EntranceCoat.COAT) as PackedScene).instantiate()
					coat.position = cody.position
					var materials := EntranceCoat._materials()
					for node in coat.find_children("*", "MeshInstance3D", true, false):
						for part: String in materials:
							if String(node.name).begins_with(part):
								for surface in mini(node.mesh.get_surface_count(), materials[part].size()):
									node.set_surface_override_material(surface, materials[part][surface])
					add_child(coat)
				cody.visible = true
				coat.visible = true
			if lights.is_empty():
				var at := Vector3(0, 0, -26)
				lights.append(_study_spot(EntranceDirector.walk_key_at(at, Vector3.BACK, Vector3.LEFT), at + Vector3.UP * 1.3,
					EntranceDirector.WALK_KEY_ENERGY, Color(1, .98, .95), EntranceDirector.WALK_KEY_RANGE,
					EntranceDirector.WALK_KEY_ANGLE, .35, true))
				lights.append(_study_spot(EntranceDirector.walk_back_at(at, Vector3.BACK, Vector3.LEFT), at + Vector3.UP * 1.4,
					EntranceDirector.WALK_BACK_ENERGY, Color(.88, .93, 1), EntranceDirector.WALK_BACK_RANGE,
					EntranceDirector.WALK_BACK_ANGLE, .35))
		var views := ["front", "threequarter", "profile"] if _portrait == "all" else [_portrait]
		for view: String in views:
			if not view.is_empty():
				var eye := Vector3(0, 1.76, -25.18)
				if view == "threequarter": eye = Vector3(-.55, 1.80, -25.32)
				elif view == "profile": eye = Vector3(-.84, 1.76, -26)
				camera.fov = 30
				camera.look_at_from_position(eye, Vector3(0, 1.72, -26))
			for _frame in _settle:
				await RenderingServer.frame_post_draw
			var picture := get_viewport().get_texture().get_image()
			var path := _out.path_join(shot + ("_" + view if not view.is_empty() else "") + ".png")
			if picture.save_png(path) != OK:
				get_tree().quit(1)
				return
			captures.append({"shot": shot, "view": view, "image": path, "width": picture.get_width(), "height": picture.get_height(),
				"camera_at": str(camera.global_position), "camera_basis": str(camera.global_basis), "fov": camera.fov})
			print("VISUAL_MATERIAL_STUDY saved ", path)
	var file := FileAccess.open(_out.path_join("proof_manifest.json"), FileAccess.WRITE)
	var manifest := {"captures": captures, "settle_frames": _settle,
		"scope": "isolated_bind_pose_material_study" if _studio else "bounded_stage_bind_pose_material_study",
		"volumetric_fog_disabled_for_review": no_fog or _studio,
		"glints_disabled_for_review": OS.get_cmdline_user_args().has("--no-glints"),
		"lighting_scope": "key_and_back_only; no_follow_spot_or_camera_fill"}
	manifest.merge(_render_metadata())
	file.store_string(JSON.stringify(manifest, "\t"))
	get_tree().quit()


func _render_metadata() -> Dictionary:
	var adapter := RenderingServer.get_video_adapter_name()
	return {
		"pipeline": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"video_adapter": adapter,
		"software_rasterised": RenderingServer.get_video_adapter_type() == RenderingDevice.DEVICE_TYPE_CPU
			or adapter.to_lower().contains("llvmpipe") or adapter.to_lower().contains("lavapipe"),
		"performance_evidence": false,
		"runtime_flags": WindowCapture.runtime_flags(),
		"os": OS.get_name(), "godot": Engine.get_version_info().string,
		"skin_base_wetness": Sweat.BASE, "skin_max_wetness": Sweat.MAX_WETNESS,
		"face_film_share": SkinLook.FACE_FILM_SHARE,
		"face_film_roughness_gain": SkinLook.FACE_FILM_ROUGHNESS_GAIN,
		"roman_face_normal_strength": RomanModel.FACE_NORMAL_STRENGTH,
		"roman_face_scatter_strength": RomanModel.FACE_SCATTER_STRENGTH,
		"roman_lid_open_degrees": RomanModel.LID_OPEN,
		"roman_lid_closed_degrees": EyeLids.CLOSED_ANGLE,
		"roman_hair_underpaint_tint": str(RomanModel.HAIR_UNDERPAINT_TINT),
		"roman_beard_fibre_cards": RomanBeardGroom.CARDS,
		"roman_face_film_share": RomanModel.FACE_FILM_SHARE,
		"roman_face_film_roughness_gain": RomanModel.FACE_FILM_ROUGHNESS_GAIN,
		"key_energy": EntranceDirector.WALK_KEY_ENERGY, "key_side_m": EntranceDirector.WALK_KEY_SIDE,
		"camera_fill_energy": EntranceDirector.CAM_KEY_ENERGY,
		"skin_dry_diagnostic": OS.get_cmdline_user_args().has("--dry-skin"),
		"stage_probe_requested": OS.get_cmdline_user_args().has("--stage-probe")}
