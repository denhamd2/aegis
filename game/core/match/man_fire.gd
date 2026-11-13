class_name ManFire
extends Node3D
## A man who walks into a fire catches fire (the owner, 19 Oct): flames on his
## body until the referee puts them out with the extinguisher (FireCrew), and
## burn marks on his skin that stay for the rest of the match.
##
## He is alight when he is within REACH of a live fire in the venue
## (VenueDamage.fires), between his knees and his shoulders. Once put out he is
## wet for RELIGHT_SECONDS and cannot catch again at once. The burn marks only
## ever grow; the flames come and go.

signal ignited(wrestler: WrestlerController)
signal extinguished(wrestler: WrestlerController)

## Horizontal reach of a fire's centre, and its height against him.
const REACH := 1.1
const FLAME_LOW := -0.4
const FLAME_HIGH := 2.2
const RELIGHT_SECONDS := 1.5
## Burn marks deepen this much a second while he burns, up to MAX_BURN.
const BURN_RATE := 0.035
const MAX_BURN := 1.0
## The flames sit on his chest.
const FLAME_HEIGHT := 1.0
const BURN_SHADER := preload("res://core/materials/burn_overlay.gdshader")
const FIRE_HOT := Color(1.0, 0.92, 0.6)
const FIRE_ORANGE := Color(1.0, 0.5, 0.12)
const FIRE_RED := Color(0.75, 0.12, 0.04)

var wrestler: WrestlerController
var burning := false
## 0..1: how far the burn marks have spread over his skin. Only ever grows.
var burn := 0.0
var _overlays: Array[ShaderMaterial] = []
var _flames: GPUParticles3D
var _light: OmniLight3D
var _wet := 0.0
var _venue: VenueDamage
var _rng := RandomNumberGenerator.new()
## The fires he was put out in front of. They are doused for him: the foam
## goes into them, and they do not catch him again for the rest of the match.
var _doused: Array[Node3D] = []


## Hangs a ManFire on `w`, and burn marks on the skin `model` registered as
## "skin_materials" (the same surfaces the blood overlays go over).
static func attach(w: WrestlerController, model: Node) -> ManFire:
	var m := ManFire.new()
	m.name = "ManFire"
	m.wrestler = w
	m._rng.seed = hash(w.name)
	w.add_child(m)
	m._flames = _flame_particles()
	_as_tongues(m._flames)
	m._flames.position = Vector3(0.0, FLAME_HEIGHT, 0.0)
	m.add_child(m._flames)
	m._light = OmniLight3D.new()
	m._light.name = "Glow"
	m._light.light_color = FIRE_HOT
	m._light.light_energy = 1.0
	m._light.omni_range = 3.0
	m._light.position = Vector3(0.0, FLAME_HEIGHT, 0.0)
	m._light.visible = false
	m.add_child(m._light)
	if model:
		m._dress_skin(model)
	return m


func _dress_skin(model: Node) -> void:
	if not model.has_meta("skin_materials"):
		return
	var skin: Array = model.get_meta("skin_materials")
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := mi.get_surface_override_material(s)
			if m == null or not skin.has(m):
				continue
			var overlay := ShaderMaterial.new()
			overlay.shader = BURN_SHADER
			overlay.set_shader_parameter("seed_offset", _rng.randf_range(0.0, 50.0))
			overlay.render_priority = 2
			# last in the skin's chain: over the blood, which is over the skin
			var last: Material = m
			while last.next_pass != null:
				last = last.next_pass
			last.next_pass = overlay
			_overlays.append(overlay)


func _process(delta: float) -> void:
	if wrestler == null or not is_instance_valid(wrestler):
		return
	if _wet > 0.0:
		_wet = maxf(0.0, _wet - delta)
	if burning:
		# on his body wherever it is: standing, down, or bent over
		var chest := wrestler._bone_world("spine_03")
		if chest != Vector3.INF:
			_flames.global_position = chest
			_light.global_position = chest
		var before := burn
		burn = minf(MAX_BURN, burn + BURN_RATE * delta)
		if burn != before:
			_set_burn()
	elif _wet <= 0.0:
		_look_for_fire()


## Alight if a live fire is at his height and within reach of him.
func _look_for_fire() -> void:
	if _venue == null:
		_venue = VenueDamage.of(wrestler)
	if _venue == null:
		return
	for f: Node3D in _venue.fires:
		if _doused.has(f):
			continue
		var d := f.global_position - wrestler.global_position
		if Vector2(d.x, d.z).length() < REACH and d.y > FLAME_LOW and d.y < FLAME_HIGH:
			ignite()
			return


func ignite() -> void:
	if burning:
		return
	burning = true
	_flames.emitting = true
	_light.visible = true
	ignited.emit(wrestler)


## Put out: the flames stop and he is wet for a moment. The burn marks stay.
func extinguish() -> void:
	if not burning:
		return
	burning = false
	_flames.emitting = false
	_light.visible = false
	_wet = RELIGHT_SECONDS
	var venue := VenueDamage.of(wrestler)
	if venue:
		for f: Node3D in venue.fires:
			var d := f.global_position - wrestler.global_position
			if Vector2(d.x, d.z).length() < REACH:
				_doused.append(f)
	extinguished.emit(wrestler)


func _set_burn() -> void:
	for o in _overlays:
		o.set_shader_parameter("burn", burn)


## Every fire in the game is drawn with this (the owner, 20 Oct: "ensure all
## the other fire in the game follows this same style, and not the round
## balls"): a billboard of WeaponActor.flame_tongue -- tall, tapering, broken
## at the tip -- `size` across and up, its root a little below the particle
## so a tongue stands up off where it was born. Additive and tinted by the
## particle's colour ramp, the way the round puffs were.
## 9 Nov (the owner: "Make fire look more realistic"): drawn by
## flame.gdshader -- each tongue wavers and licks, coloured by its own heat --
## where a static sprite piled into one blown-out ball.
static func tongue_pass(size: Vector2, tint := Color.WHITE) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	quad.center_offset = Vector3(0.0, size.y * 0.36, 0.0)
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	mat.set_shader_parameter("tint", tint)
	quad.material = mat
	return quad


const FLAME_SHADER := preload("res://core/materials/flame.gdshader")
const SMOKE_SHADER := preload("res://core/materials/smoke.gdshader")


## Smoke where each flame dies (the flames' sub-emitter): dark, rising,
## spreading, gone in a couple of seconds.
static func _smoke_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Smoke"
	p.amount = 48
	p.lifetime = 1.8
	# A sub-emitter: it emits only when a flame dies. Left emitting on its
	# own, it puffed black smoke off every wrestler's back from the bell
	# (the owner, 9 Nov), on fire or not.
	p.emitting = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.UP
	m.spread = 20.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.6
	m.gravity = Vector3(0.0, 0.25, 0.0)
	m.damping_min = 0.4
	m.damping_max = 0.8
	m.scale_min = 0.6
	m.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(1.0, 1.0))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	m.color_ramp = ramp
	m.angle_min = -180.0
	m.angle_max = 180.0
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := ShaderMaterial.new()
	mat.shader = SMOKE_SHADER
	quad.material = mat
	p.draw_pass_1 = quad
	return p


## A fire's particles leaning a little this way and that, as flames do.
static func flicker(m: ParticleProcessMaterial) -> void:
	m.angle_min = -12.0
	m.angle_max = 12.0


## His flames over his body: a box over his chest of softer tongues than the
## stock flame, so they sit on him rather than piling into one white ball.
static func _as_tongues(p: GPUParticles3D) -> void:
	# 46 piled into one white column under the arena's glow (9 Nov); 16 read
	# as no fire at all on the render. More, bigger tongues that flicker and
	# carry a full-hot core (the dim core read as a muddy brown stain, not fire).
	p.amount = 70
	var m := p.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(0.32, 0.6, 0.26)
	m.scale_min = 0.8
	m.scale_max = 1.5
	m.angle_min = -12.0
	m.angle_max = 12.0
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	grad.colors = PackedColorArray([Color(FIRE_HOT, 1.0), Color(FIRE_ORANGE, 0.85),
			Color(FIRE_RED, 0.6), Color(FIRE_RED, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	m.color_ramp = ramp
	p.draw_pass_1 = tongue_pass(Vector2(0.5, 1.2), Color(1.4, 1.3, 1.1))


static func _flame_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Flames"
	p.amount = 40
	p.lifetime = 0.45
	p.emitting = false
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 0.2
	m.direction = Vector3.UP
	m.spread = 35.0
	m.initial_velocity_min = 0.3
	m.initial_velocity_max = 0.9
	m.gravity = Vector3(0.0, 1.0, 0.0)
	m.damping_min = 2.0
	m.damping_max = 3.0
	m.scale_min = 0.12
	m.scale_max = 0.24
	var shrink := Curve.new()
	shrink.add_point(Vector2(0.0, 0.6))
	shrink.add_point(Vector2(0.3, 1.0))
	shrink.add_point(Vector2(1.0, 0.15))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	m.scale_curve = shrink_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	grad.colors = PackedColorArray([FIRE_HOT, FIRE_ORANGE, FIRE_RED, Color(FIRE_RED, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	m.color_ramp = ramp
	p.process_material = m
	flicker(m)
	p.draw_pass_1 = tongue_pass(Vector2(0.2, 0.5))
	# One puff of smoke where every third tongue dies.
	var smoke := _smoke_particles()
	p.add_child(smoke)
	p.sub_emitter = NodePath("Smoke")
	m.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_END
	m.sub_emitter_amount_at_end = 1
	m.sub_emitter_keep_velocity = false
	return p


## A soft round dot, for the foam and spark sprites (fire is tongues).
static func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	return t
