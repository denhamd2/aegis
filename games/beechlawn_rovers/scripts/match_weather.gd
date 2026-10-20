extends Node3D
class_name MatchWeather
## Match-scoped environment copy: never mutates shared daylight resources.
const PRESETS: Dictionary = preload("res://data/presentation/match_weather.json").data
var surface: WetPitchSurface
var weather_id: StringName = &"sunny"
var rain: CPUParticles3D
var target: Node3D

static func valid_id(value: StringName) -> StringName:
	return value if PRESETS.has(str(value)) else &"sunny"

func setup(game: Node3D, requested: StringName) -> void:
	if rain != null:
		rain.queue_free()
		rain = null
	weather_id = valid_id(requested)
	var config: Dictionary = PRESETS[str(weather_id)]
	surface = load("res://data/presentation/kilmore_surface.tres") as WetPitchSurface
	target = game.get_node("Ball")
	var ball := target as FootballBall
	ball.wet_surface = surface if game.terrain_enabled else null
	ball.surface_wetness = float(config.wetness)
	var turf := game.get_node("Pitch/SundayLeagueTurf") as MeshInstance3D
	var grass := turf.material_override as ShaderMaterial
	configure_surface(grass, game.terrain_enabled, float(config.wetness))
	var world := game.get_node("WorldEnvironment") as WorldEnvironment
	var environment := world.environment.duplicate(true) as Environment
	world.environment = environment
	environment.ambient_light_energy = float(config.ambient)
	environment.fog_density = float(config.fog)
	# Depth haze works in native and Web. Volumetric fog is deliberately absent
	# from the clear broadcast and unsupported in the Compatibility renderer.
	environment.volumetric_fog_enabled = false
	var sky_material := environment.sky.sky_material as ShaderMaterial
	sky_material.set_shader_parameter("sky_energy", float(config.sky))
	sky_material.set_shader_parameter("overcast", float(config.overcast))
	var sun := game.get_node("Sun") as DirectionalLight3D
	sun.light_energy = float(config.sun)
	sun.light_angular_distance = 0.8 if weather_id == &"sunny" else 4.0
	if float(config.rain) > 0.0:
		_build_rain()
	if OS.has_feature("web") and OS.has_feature("debug"):
		JavaScriptBridge.eval("window.BEECHLAWN_WEATHER = '%s'" % weather_id)

static func configure_surface(material: ShaderMaterial, enabled: bool, wetness: float) -> void:
	var surface_data := load("res://data/presentation/kilmore_surface.tres") as WetPitchSurface
	material.set_shader_parameter("surface_masks", surface_data.masks)
	material.set_shader_parameter("wear_strength", 1.0 if enabled else 0.0)
	material.set_shader_parameter("wetness", wetness if enabled else 0.0)
	var mud_path := "res://assets/environment/surfaces/polyhaven/brown_mud/brown_mud_"
	material.set_shader_parameter("mud_albedo", load(mud_path+"diff_1k.jpg"))
	material.set_shader_parameter("mud_normal", load(mud_path+"nor_gl_1k.jpg"))
	material.set_shader_parameter("mud_roughness", load(mud_path+"rough_1k.jpg"))

func _build_rain() -> void:
	rain = CPUParticles3D.new()
	rain.name = "LightRain"
	rain.amount = 420
	rain.lifetime = 2.0
	rain.preprocess = 2.0
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(26,1,20)
	rain.direction = Vector3(0.06,-1,0.02)
	rain.spread = 3.0
	rain.gravity = Vector3(0,-3.0,0)
	rain.initial_velocity_min = 10.0
	rain.initial_velocity_max = 14.0
	rain.local_coords = false
	# The emitter is above the low broadcast camera; include falling drops
	# down to the pitch so the default small bounds do not cull the whole rain.
	rain.visibility_aabb = AABB(Vector3(-30,-32,-24),Vector3(60,36,48))
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var drop := QuadMesh.new()
	drop.size = Vector2(0.02,0.45)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.7,0.77,0.82,0.32)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	drop.material = material
	rain.mesh = drop
	add_child(rain)
	rain.global_position = target.global_position+Vector3.UP*13.0

func _process(_delta: float) -> void:
	if rain != null and is_instance_valid(target):
		rain.global_position = Vector3(target.global_position.x,13.0,target.global_position.z)
