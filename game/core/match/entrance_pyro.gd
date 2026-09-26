class_name EntrancePyro
extends Node3D
## Entrance pyrotechnics: gerbs, mortar air bursts and ring-post sparks, each
## with a light flash into the haze (gauntlet/refs/entrances.md).
##
## A pyro hit is two things on a broadcast: the fire, and the room lighting up
## for a moment -- the flash on the crowd and in the haze is what reads on a
## wide shot, more than the sparks themselves. So every cue fires particles
## AND a short-lived light that feeds the volumetric fog.
##
## Built only by EntranceDirector, only for an entrance; one-shot emitters,
## freed with the director at the bell. Nothing here runs during a match or a
## capture.

## Sparks: white-hot at the core, through gold, to a dying orange.
const SPARK_HOT := Color(1.0, 0.96, 0.80)
const SPARK_GOLD := Color(1.0, 0.72, 0.26)
const SPARK_EMBER := Color(0.95, 0.35, 0.08)
const FLASH_COLOR := Color(1.0, 0.80, 0.45)

## Where things fire. The stage-front gerbs stand along the lip of the deck,
## either side of the ramp; the mortars go up behind the set; the post sparks
## sit on the four ring posts' tops (RingBuilder POST_XZ 3.0, POST_TOP 1.58
## less the ring's -0.1 placement).
const GERB_XS := [-5.2, -3.8, 3.8, 5.2]
const MORTAR_XS := [-4.5, 0.0, 4.5]
const MORTAR_HEIGHT := 13.0
const POST_TOP_Y := 1.48

var _flashes: Array = []   # [light, age, peak, life]


func fire(cue: String) -> void:
	match cue:
		"stage":
			var z := ArenaBuilder.STAGE_FRONT - 0.25
			for x: float in GERB_XS:
				_gerb(Vector3(x, ArenaBuilder.STAGE_DECK_Y, z), 11.0, 1.4, 320)
			for x: float in MORTAR_XS:
				_burst(Vector3(x, MORTAR_HEIGHT, ArenaBuilder.STAGE_FRONT - 4.0))
			_flash(Vector3(0.0, 3.0, ArenaBuilder.STAGE_FRONT - 1.0), 22.0, 26.0, 0.7)
		"posts":
			for sx: float in [-3.0, 3.0]:
				for sz: float in [-3.0, 3.0]:
					_gerb(Vector3(sx, POST_TOP_Y, sz), 6.5, 1.0, 180)
			_flash(Vector3(0.0, 3.5, 0.0), 12.0, 14.0, 0.5)


func _physics_process(delta: float) -> void:
	for f: Array in _flashes:
		var light: OmniLight3D = f[0]
		f[1] += delta
		var k := clampf(1.0 - float(f[1]) / float(f[3]), 0.0, 1.0)
		# Fast attack, quadratic decay: a flash, not a fade.
		light.light_energy = float(f[2]) * k * k
		light.visible = k > 0.0


func _spark_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.gravity = Vector3(0.0, -9.8, 0.0)
	m.damping_min = 0.6
	m.damping_max = 1.4
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.8, 1.0])
	grad.colors = PackedColorArray([SPARK_HOT, SPARK_GOLD, SPARK_EMBER,
			Color(SPARK_EMBER, 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	m.color_ramp = tex
	m.scale_min = 0.6
	m.scale_max = 1.2
	return m


func _spark_mesh(size: float) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size * 3.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(3.0, 2.6, 2.0)   # over 1: they bloom
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	return quad


## A gerb: a fountain straight up, the classic stage-front spark jet.
func _gerb(at: Vector3, speed: float, life: float, amount: int) -> void:
	var p := GPUParticles3D.new()
	var m := _spark_material()
	m.spread = 6.0
	m.initial_velocity_min = speed * 0.85
	m.initial_velocity_max = speed * 1.1
	p.process_material = m
	p.draw_pass_1 = _spark_mesh(0.035)
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.0   # a jet over the lifetime, not one pop
	p.fixed_fps = 60
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 16, 8))
	add_child(p)
	p.global_position = at
	p.emitting = true
	_flash(at + Vector3.UP * 1.5, 6.0, 8.0, life)


## A mortar air burst: a sphere of sparks high over the set.
func _burst(at: Vector3) -> void:
	var p := GPUParticles3D.new()
	var m := _spark_material()
	m.spread = 180.0
	m.gravity = Vector3(0.0, -2.2, 0.0)
	m.initial_velocity_min = 5.0
	m.initial_velocity_max = 8.5
	p.process_material = m
	p.draw_pass_1 = _spark_mesh(0.07)
	p.amount = 500
	p.lifetime = 1.8
	p.one_shot = true
	p.explosiveness = 1.0
	p.fixed_fps = 60
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	add_child(p)
	p.global_position = at
	p.emitting = true
	_flash(at, 20.0, 30.0, 0.9)


func _flash(at: Vector3, energy: float, reach: float, life: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = FLASH_COLOR
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 3.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	light.light_energy = energy
	_flashes.append([light, 0.0, energy, life])
