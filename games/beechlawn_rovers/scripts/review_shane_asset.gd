extends Node3D
## Isolated exported-asset review with the match's light/environment settings.
## Uses the production appearance path without running football simulation.

const PLAYER: PackedScene = preload("res://scenes/footballer_visual.tscn")
const PROFILE = preload("res://data/squads/home_08.tres")
const MATCH_SCENE: PackedScene = preload("res://scenes/training_ground.tscn")
const VENUE = preload("res://scripts/kilmore_drive_venue.gd")
var camera: Camera3D
var player: Node3D
var animation: AnimationPlayer
var _capture_callback: JavaScriptObject

func _ready() -> void:
	var source := MATCH_SCENE.instantiate()
	add_child(source.get_node("WorldEnvironment").duplicate())
	add_child(source.get_node("Sun").duplicate())
	source.free()
	if OS.has_feature("web") and OS.has_feature("debug"):
		if str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('software')")) == "1":
			$Sun.shadow_enabled = false
			Engine.max_fps = 8
		_capture_callback = JavaScriptBridge.create_callback(_freeze_capture)
		JavaScriptBridge.get_interface("window").BEECHLAWN_FREEZE_FRAME = _capture_callback
	# Close asset review shares the match's sky, sun and pitch shader. Full park
	# shadow-caster cost overwhelms software WebGL and is a separate scene gate.
	if not OS.has_feature("web"):
		VENUE.build(self, 105.0, 68.0)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(105.0, 68.0)
	ground.mesh = plane
	var turf := ShaderMaterial.new()
	turf.shader = load("res://shaders/park_grass.gdshader")
	turf.set_shader_parameter("grass_albedo", load("res://assets/environment/surfaces/ambientcg/Grass005/Grass005_1K-JPG_Color.jpg"))
	MatchWeather.configure_surface(turf, true, 0.65)
	ground.material_override = turf
	add_child(ground)
	player = PLAYER.instantiate()
	add_child(player)
	var visual := player as FootballerVisual
	var profile := PROFILE
	if OS.has_feature("web"):
		var requested = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('player')")
		# Explicit review-only allowlist; use the real roster appearance path.
		match str(requested):
			"john": profile = load("res://data/squads/home_01.tres")
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
		if posed != null and str(posed) == "idle":
			animation.play("AN_Beechlawn_Idle")
			animation.advance(0.0)
			var requested_frame = JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('frame')")
			if requested_frame != null:
				var seconds := maxf(0.0, (str(requested_frame).to_float()-1.0)/60.0)
				animation.seek(minf(seconds,animation.current_animation_length),true)
			animation.pause()
	_set_view(view)
	var label := Label.new()
	label.text = profile.display_name + " — shared head pipeline review\n1 front · 2 back · 3 profile · 4 face · 5 broadcast · Space idle/reset\nShared body/rig; individual likeness remains in review"
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
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.1
	var target := Vector3(0, 0.94, 0)
	match view:
		"back": camera.position = Vector3(0, 0.94, -4.7)
		"profile": camera.position = Vector3(4.7, 0.94, 0)
		"portrait":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 25.0
			camera.position = Vector3(0, 1.67, 1.20)
			target = Vector3(0, 1.67, 0)
		"threequarter_portrait", "profile_portrait":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 25.0
			camera.position = Vector3(.78, 1.67, .95) if view == "threequarter_portrait" else Vector3(1.20, 1.67, 0)
			target = Vector3(0, 1.67, 0)
		"broadcast":
			camera.projection = Camera3D.PROJECTION_PERSPECTIVE
			camera.fov = 50.0
			camera.position = Vector3(0, 17, 36)
			target = Vector3.ZERO
		_: camera.position = Vector3(0, 0.94, 4.7)
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
