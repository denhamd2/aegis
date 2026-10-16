extends "res://tools/probe/clip_shot.gd"
var _camera_key: SpotLight3D
func _face_views() -> Dictionary:
	# Fit the reference's view direction with a longer portrait distance.
	return {"ffront": Vector3(.0865, .1484, 1.45),
		"f34": Vector3(-.42, .04, .45) * 2.3387,
		"fside": Vector3(-.62, .02, 0) * 2.3387}
func _face_fov() -> float:
	return 22.0
func _light() -> void:
	var template := (load("res://scenes/match.tscn") as PackedScene).instantiate()
	var env := (template.get_node("WorldEnvironment") as WorldEnvironment).duplicate() as WorldEnvironment
	env.environment = env.environment.duplicate(true)
	env.environment.ambient_light_energy = .12
	env.environment.volumetric_fog_enabled = false
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.035,.04,.05)
	add_child(env)
	template.free()
	_spot(EntranceDirector.walk_key_at(Vector3.ZERO, Vector3.BACK, Vector3.LEFT), EntranceDirector.WALK_KEY_ENERGY, Color(1,.98,.95), EntranceDirector.WALK_KEY_RANGE, EntranceDirector.WALK_KEY_ANGLE, true)
	_spot(EntranceDirector.walk_back_at(Vector3.ZERO, Vector3.BACK, Vector3.LEFT), EntranceDirector.WALK_BACK_ENERGY, Color(.88,.93,1), EntranceDirector.WALK_BACK_RANGE, EntranceDirector.WALK_BACK_ANGLE, false)
	_camera_key = SpotLight3D.new()
	_camera_key.light_color = Color(1,.95,.88)
	_camera_key.light_energy = EntranceDirector.CAM_KEY_ENERGY
	_camera_key.spot_attenuation = .4
	_camera_key.spot_angle_attenuation = 1.6
	_camera_key.light_specular = .25
	add_child(_camera_key)
	var model := find_child("RomanModel",true,false) as RomanModel
	if model:
		for material: BaseMaterial3D in model.get_meta("skin_materials",[]):
			SkinLook.set_wetness(material,Sweat.BASE)
		model.aim_eyes(func(): return Vector3(0,1.72,10))
		var lids := model.find_child("EyeLids",true,false) as EyeLids
		if lids:lids.hold(0)
func _spot(at: Vector3, energy: float, tint: Color, distance: float, angle: float, shadows: bool) -> void:
	var light := SpotLight3D.new()
	light.light_color = tint;light.light_energy = energy
	light.spot_range = distance;light.spot_angle = angle
	light.spot_angle_attenuation = 1.6;light.spot_attenuation = .6
	light.light_specular = .35;light.shadow_enabled = shadows;light.light_size = .12
	add_child(light);light.look_at_from_position(at,Vector3(0,1.3,0))
func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null or _camera_key == null:return
	var chest := Vector3(0,1.3,0)
	var to := chest-camera.global_position
	var right := to.normalized().cross(Vector3.UP).normalized()
	_camera_key.global_position = camera.global_position+Vector3.UP*EntranceDirector.CAM_KEY_UP+right*EntranceDirector.CAM_KEY_SIDE
	_camera_key.spot_range = to.length()+4
	_camera_key.spot_angle = clampf(rad_to_deg(atan2(1.4,to.length())),4,40)
	_camera_key.look_at(chest)
