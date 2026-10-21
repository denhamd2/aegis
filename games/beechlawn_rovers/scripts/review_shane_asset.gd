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

func _ready() -> void:
	var source := MATCH_SCENE.instantiate()
	source.set("terrain_enabled", true)
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
	review_sky_material.set_shader_parameter("sky_saturation", 0.52)
	review_sky_material.set_shader_parameter("sky_energy", 1.16)
	review_sky_material.set_shader_parameter("horizon_haze", 0.24)
	review_sky_material.set_shader_parameter("dark_sky_lift", 0.6)
	if OS.has_feature("web") and OS.has_feature("debug"):
		if str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('software')")) == "1":
			$Sun.shadow_enabled = false
			Engine.max_fps = 8
		var requested_lighting = str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('lighting')"))
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
	if OS.has_feature("web"):
		var requested = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('player')")
		# Explicit review-only allowlist; use the real roster appearance path.
		match str(requested):
			"john": profile = load("res://data/squads/home_01.tres")
			"away_keeper": profile = load("res://data/squads/away_01.tres")
			"des": profile = load("res://data/squads/away_09.tres")
			"referee": profile = load("res://data/officials/referee.tres")
			"paddy": profile = load("res://data/squads/home_69.tres")
	visual.configure_appearance(profile)
	visual.animation_tree.active = false
	player.rotation.y = PI
	animation = visual.animation_player
	_neutral_pose()
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	var view := "front"
	if OS.has_feature("web"):
		var requested = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('view')")
		if requested != null:
			view = str(requested)
		var posed = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('pose')")
		var review_clips := {
			"idle":"Idle", "sprint":"Sprint", "pass":"PassRight", "shot":"ShotRight",
			"turn":"Turn90Right", "slide":"GroundedSlideTackle",
			"get_up":"GetUpFromProne", "keeper_set":"KeeperSet", "keeper_save":"KeeperSave",
		}
		if posed != null and review_clips.has(str(posed)):
			animation.play("AN_Beechlawn_"+str(review_clips[str(posed)]))
			animation.advance(0.0)
			var requested_frame = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('frame')")
			if requested_frame != null:
				var seconds := maxf(0.0, (str(requested_frame).to_float()-1.0)/60.0)
				animation.seek(minf(seconds,animation.current_animation_length),true)
			animation.pause()
	_set_view(view)
	var clean_capture := OS.has_feature("web") and str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('clean')")) == "1"
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
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_REVIEW_LIGHTING = " + JSON.stringify({"preset":review_lighting, "sun_shadows":$Sun.shadow_enabled, "occluder":has_node("ReviewShadeCaster")}))
		JavaScriptBridge.eval("window.BEECHLAWN_REVIEW_READY = true")

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
		"threequarter_portrait", "profile_portrait":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 25.0
			camera.position = REVIEW_SPOT + (Vector3(.78, 1.67, .95) if view == "threequarter_portrait" else Vector3(1.20, 1.67, 0))
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
