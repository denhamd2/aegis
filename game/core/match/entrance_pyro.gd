class_name EntrancePyro
extends Node3D
## Entrance pyrotechnics, as each man's real entrance -- and 2K26's copy of
## it -- has them (gauntlet/refs/entrances.md, "Pyro"), each with a light
## flash into the haze.
##
## The owner: no sparkler or waterfall pyro for either man. Measured off the
## broadcasts 2K26 recreates (WWE.com clips, frames every 0.5 s):
##
##   Roman (R-41 41.5-44 s, on the slam): FIRE -- big orange flame bursts
##       from both sides of the set, three pulses, the room going red. No
##       pyro in the ring.
##   Cody (C-39 23.5-25 s, the WHOA): aerial FIREWORK shells bursting gold
##       over the set; on the fists driven down (27.5-29 s) a second volley
##       and a white flash. At the ring (C-SNME 1:46; 2K26 "pyro over the
##       ring"): shells bursting over the ring.
##
## So: flames (_flame) and aerial shells (_burst). No gerbs, no waterfall.
##
## A pyro hit is two things on a broadcast: the fire, and the room lighting up
## for a moment -- so every cue fires particles AND a light into the fog.
## Built only by EntranceDirector, only for an entrance; one-shot emitters,
## freed with the director at the bell.

const FLASH_COLOR := Color(1.0, 0.80, 0.45)
const STROBE_COLOR := Color(0.92, 0.95, 1.0)
## Roman's pyro flash: the room goes red on the slam (R-41 42 s).
const ROMAN_RED := Color(1.0, 0.12, 0.16)

## Fire: white-yellow at the core, through orange, to a dark red edge that
## burns out to nothing (the smoke is the haze's).
const FIRE_HOT := Color(1.0, 0.74, 0.30)
const FIRE_ORANGE := Color(1.0, 0.40, 0.06)
const FIRE_RED := Color(0.85, 0.16, 0.04)
## Roman's flame projectors: on the deck lip either side of the portals, and
## up on the screen's wings, both sides (R-41: flames high on both sides of
## the set). Three pulses a beat apart (EntranceDirector.ROMAN_BEAT).
const FLAME_DECK_XS := [-5.4, 5.4]
const FLAME_HIGH_XS := [-10.2, 10.2]
const FLAME_HIGH_Y := 12.4
const FLAME_PULSES := 3
const FLAME_PULSE_GAP := 0.836

## Firework shells: gold over the set for Cody's WHOA; red, white and blue
## over the ring. Bursting at SHELL_HEIGHT, staggered so a volley ripples.
const SHELL_GOLD := [Color(1.0, 0.96, 0.80), Color(1.0, 0.78, 0.30), Color(0.95, 0.45, 0.10)]
const SHELL_RED := [Color(1.0, 0.85, 0.85), Color(1.0, 0.18, 0.15), Color(0.6, 0.05, 0.05)]
const SHELL_WHITE := [Color(1.0, 1.0, 1.0), Color(0.85, 0.9, 1.0), Color(0.5, 0.55, 0.7)]
const SHELL_BLUE := [Color(0.85, 0.9, 1.0), Color(0.2, 0.4, 1.0), Color(0.05, 0.1, 0.5)]
const SET_SHELL_XS := [-9.0, -6.0, -3.0, 0.0, 3.0, 6.0, 9.0]
const SET_SHELL_HEIGHT := 14.0
const SHELL_STAGGER := 0.09
## Over the ring: under the rig (TRUSS_Y 7.6), over the four corners.
const RING_SHELL_HEIGHT := 6.8
const RING_SHELL_XZ := 2.4

## A burning flame lights what is near it for as long as it burns
## (refs/aaa_gap.md item 9, 2K26's "particle lighting"): full within
## SUSTAIN_ATTACK, held until SUSTAIN_HOLD of its life, then out -- and it
## flickers, by up to FLICKER, on summed sines so no two pulse together.
const SUSTAIN_ATTACK := 0.06
const SUSTAIN_HOLD := 0.7
const FLICKER := 0.3

var _flashes: Array = []   # [light, age, peak, life, sustained, phase]


## Cues fired later in the same hit: [seconds left, Callable].
var _pending: Array = []


func fire(cue: String) -> void:
	match cue:
		"stage":
			# A generic entrance: a volley of gold shells over the set.
			_shell_volley(SET_SHELL_XS, SET_SHELL_HEIGHT, SHELL_GOLD)
		"roman":
			# The OTC's slam: flame bursts from both sides of the set, on the
			# beat, and the room RED for a beat -- the flash is what reads.
			for k in FLAME_PULSES:
				_later(k * FLAME_PULSE_GAP, _flame_pulse)
			_flash(Vector3(0.0, 4.0, ArenaBuilder.STAGE_FRONT - 1.0), 30.0, 34.0, 1.5,
					ROMAN_RED)
		"cody_hit":
			# The WHOA: gold shells across the whole set, rippling.
			_shell_volley(SET_SHELL_XS, SET_SHELL_HEIGHT, SHELL_GOLD)
			_flash(Vector3(0.0, 6.0, ArenaBuilder.STAGE_FRONT - 1.0), 26.0, 34.0, 0.9)
		"cody_punch":
			# The fists driven down: the second, higher volley and a white pop.
			_shell_volley(SET_SHELL_XS, SET_SHELL_HEIGHT + 2.5, SHELL_GOLD)
			_flash(Vector3(0.0, 5.0, ArenaBuilder.STAGE_FRONT - 1.0), 30.0, 32.0, 0.35,
					STROBE_COLOR)
		"strobe":
			# A strobe hit on the WHOA in the dark: white, very short.
			_flash(Vector3(0.0, 6.0, ArenaBuilder.STAGE_FRONT - 2.0), 45.0, 45.0, 0.16,
					STROBE_COLOR)
		"over_ring":
			# Cody in his corner: shells over the ring's four corners, red,
			# white and blue (C-SNME 1:46; 2K26 "pyro over the ring").
			var colours := [SHELL_RED, SHELL_WHITE, SHELL_BLUE, SHELL_RED]
			var i := 0
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var at := Vector3(sx * RING_SHELL_XZ, RING_SHELL_HEIGHT, sz * RING_SHELL_XZ)
					var col: Array = colours[i]
					_later(i * SHELL_STAGGER * 2.0, func() -> void: _burst(at, col, 0.7))
					i += 1
			_flash(Vector3(0.0, 4.5, 0.0), 14.0, 16.0, 0.5)


func _later(seconds: float, what: Callable) -> void:
	if seconds <= 0.0:
		what.call()
	else:
		_pending.append([seconds, what])


func _shell_volley(xs: Array, height: float, colours: Array) -> void:
	for i in xs.size():
		# Middle out, so the volley opens from the centre of the set.
		var order := absi(i - xs.size() / 2)
		var at := Vector3(xs[i], height + (order % 2) * 1.2, ArenaBuilder.STAGE_FRONT - 4.0)
		_later(order * SHELL_STAGGER, func() -> void: _burst(at, colours))


func _flame_pulse() -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var z := ArenaBuilder.STAGE_FRONT - 0.6
	for x: float in FLAME_DECK_XS:
		_flame(Vector3(x, deck, z), 4.5)
	for x: float in FLAME_HIGH_XS:
		_flame(Vector3(x, FLAME_HIGH_Y, ArenaBuilder.SCREEN_FACE_Z + 1.5), 3.5)


func _physics_process(delta: float) -> void:
	for p: Array in _pending.duplicate():
		p[0] = float(p[0]) - delta
		if float(p[0]) <= 0.0:
			_pending.erase(p)
			(p[1] as Callable).call()
	for f: Array in _flashes:
		var light: OmniLight3D = f[0]
		f[1] += delta
		var t := float(f[1]) / float(f[3])
		if f[4]:
			var level := sustain_level(t) * flicker(float(f[1]), float(f[5]))
			light.light_energy = float(f[2]) * level
			# Yellow-white while it burns, red as it dies, as the flame's own
			# colour ramp goes.
			light.light_color = FIRE_HOT.lerp(FIRE_RED, smoothstep(SUSTAIN_HOLD, 1.0, t))
			light.visible = t < 1.0
		else:
			var k := clampf(1.0 - t, 0.0, 1.0)
			# Fast attack, quadratic decay: a flash, not a fade.
			light.light_energy = float(f[2]) * k * k
			light.visible = k > 0.0


## A burning jet's level, 0-1, over its life fraction `t`.
static func sustain_level(t: float) -> float:
	if t <= 0.0 or t >= 1.0:
		return 0.0
	var up := minf(t / SUSTAIN_ATTACK, 1.0)
	var down := 1.0 - smoothstep(SUSTAIN_HOLD, 1.0, t)
	return up * down


## 1 - FLICKER .. 1: three incommensurate sines, offset per light.
static func flicker(age: float, phase: float) -> float:
	var n := sin(age * 37.0 + phase) + sin(age * 61.0 + phase * 1.7) \
			+ sin(age * 23.0 + phase * 2.3)
	return 1.0 - FLICKER * (0.5 + n / 6.0)


func _ramp(colours: Array) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	grad.colors = PackedColorArray([colours[0], colours[1], colours[2],
			Color(colours[2], 0.0)])
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	return tex


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


## A soft round puff for fire: a radial falloff, additive, so overlapping
## puffs build a hot core and a ragged edge.
static var _puff_tex: ImageTexture


static func _puff() -> ImageTexture:
	if _puff_tex:
		return _puff_tex
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - size * 0.5, y + 0.5 - size * 0.5).length() / (size * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	_puff_tex = ImageTexture.create_from_image(img)
	return _puff_tex


## A flame burst: a column of fire thrown up from a projector, about a
## second long -- the fireball of a flame unit, not a spark fountain.
func _flame(at: Vector3, height: float) -> void:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 9.0
	m.initial_velocity_min = height * 2.0
	m.initial_velocity_max = height * 2.6
	m.gravity = Vector3(0.0, 2.0, 0.0)          # hot gas rises
	m.damping_min = height * 1.6
	m.damping_max = height * 2.2
	m.scale_min = 0.9
	m.scale_max = 1.6
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.4, 1.0))
	grow.add_point(Vector2(1.0, 1.3))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	m.color_ramp = _ramp([FIRE_HOT, FIRE_ORANGE, FIRE_RED])
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(1.6, 1.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.vertex_color_use_as_albedo = true
	# Just over 1, so the core blooms but the body of the fireball stays
	# orange -- at 2.4 the overlapping puffs summed to a white jet.
	mat.albedo_color = Color(1.25, 1.1, 1.0)
	mat.albedo_texture = _puff()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = mat
	p.draw_pass_1 = quad
	p.amount = 55
	p.lifetime = 0.9
	p.one_shot = true
	p.explosiveness = 0.55
	p.fixed_fps = 60
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, height + 6.0, 8))
	add_child(p)
	p.global_position = at
	p.emitting = true
	# The fire lights the set and the man in front of it while it burns.
	_flash(at + Vector3.UP * height * 0.5, 14.0, 14.0, p.lifetime, FIRE_HOT, true)


## A firework shell: a sphere of trailing stars bursting high in the air,
## drooping as it fades (C-39's gold "chrysanthemums" over the set).
func _burst(at: Vector3, colours: Array = SHELL_GOLD, size := 1.0) -> void:
	var p := GPUParticles3D.new()
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 180.0
	m.gravity = Vector3(0.0, -2.4, 0.0)
	m.damping_min = 0.8
	m.damping_max = 1.6
	m.initial_velocity_min = 5.5 * size
	m.initial_velocity_max = 7.5 * size
	m.scale_min = 0.6
	m.scale_max = 1.2
	m.color_ramp = _ramp(colours)
	p.process_material = m
	p.draw_pass_1 = _spark_mesh(0.07 * size)
	p.amount = int(420 * size)
	p.lifetime = 1.9
	p.one_shot = true
	p.explosiveness = 1.0
	p.fixed_fps = 60
	p.trail_enabled = false
	p.visibility_aabb = AABB(Vector3(-12, -12, -12), Vector3(24, 24, 24))
	add_child(p)
	p.global_position = at
	p.emitting = true
	_flash(at, 16.0 * size, 28.0 * size, 0.8, colours[1])


func _flash(at: Vector3, energy: float, reach: float, life: float,
		color: Color = FLASH_COLOR, sustained := false) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.omni_range = reach
	light.omni_attenuation = 1.2
	light.light_volumetric_fog_energy = 3.0
	light.shadow_enabled = false
	add_child(light)
	light.global_position = at
	light.light_energy = 0.0 if sustained else energy
	# Phase from the position, so the flicker is the same every run.
	var phase := fposmod(at.x * 12.9898 + at.z * 78.233, TAU)
	_flashes.append([light, 0.0, energy, life, sustained, phase])
