class_name DryIce
extends Node3D
## Cody's dry ice: low, slow, soft sheets of it pouring out of the tunnel and
## rolling down the ramp, and lingering after he is through.
##
## CPU particles (billboard quads with a soft radial sprite), not a FogVolume:
## the web build runs on gl_compatibility, which has no FogVolume, so the old
## smoke was simply absent in the browser. These draw the same on every
## renderer. The FogVolume stays as a Forward+ extra (EntranceDirector).
##
## Cosmetic only: it reads nothing from the match and writes nothing back. Its
## own seeded randomness keeps a recording the same twice.

const LIFETIME := 9.0
const AMOUNT := 220
## How far the bank spreads across the portal mouth, and how thin it lies.
const MOUTH_HALF := Vector3(2.2, 0.10, 1.6)
## Along the ramp, metres a second: slow, and slowing.
const SPEED_MIN := 0.45
const SPEED_MAX := 1.05
## Each puff is a wide, short quad: a sheet, not a ball.
const PUFF_SIZE := Vector2(3.6, 1.35)
const PUFF_LIFT := 0.50
## Dim by design: the house is dark for his entrance, and smoke lit by one
## backlight is a blue-grey, not white.
const TINT := Color(0.66, 0.74, 0.92)
const PEAK_ALPHA := 0.14

var _particles: CPUParticles3D
var _stopped := false


## Pours out from `at`, rolling toward `toward` (flattened to the floor).
func start(at: Vector3, toward: Vector3) -> void:
	var dir := Vector3(toward.x, 0.0, toward.z)
	dir = dir.normalized() if dir.length() > 0.01 else Vector3(0, 0, 1)
	# Placed first: the particles live in world space and are pre-run when they
	# enter the tree, so they must enter it where they are to pour.
	global_position = at
	_particles = CPUParticles3D.new()
	_particles.name = "Puffs"
	_particles.amount = AMOUNT
	_particles.lifetime = LIFETIME
	# Already a bank when the camera finds it, not a trickle.
	_particles.preprocess = LIFETIME * 0.6
	_particles.randomness = 1.0
	_particles.fixed_fps = 30
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = MOUTH_HALF
	_particles.direction = dir + Vector3(0, 0.02, 0)
	_particles.spread = 14.0
	_particles.initial_velocity_min = SPEED_MIN
	_particles.initial_velocity_max = SPEED_MAX
	_particles.damping_min = 0.05
	_particles.damping_max = 0.18
	_particles.gravity = Vector3(0, -0.02, 0)
	_particles.angle_min = -180.0
	_particles.angle_max = 180.0
	_particles.scale_amount_min = 0.9
	_particles.scale_amount_max = 1.5
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.55))
	grow.add_point(Vector2(1.0, 1.7))
	_particles.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.18, 0.7, 1.0])
	ramp.colors = PackedColorArray([
		Color(TINT, 0.0), Color(TINT, PEAK_ALPHA), Color(TINT, PEAK_ALPHA * 0.7),
		Color(TINT, 0.0)])
	_particles.color_ramp = ramp
	var quad := QuadMesh.new()
	quad.size = PUFF_SIZE
	_particles.mesh = quad
	_particles.material_override = _material()
	_particles.position = Vector3(0.0, PUFF_LIFT, 0.0)
	_particles.local_coords = false
	add_child(_particles)
	_particles.emitting = true


## No more pours; what is out drifts on and thins away, then this frees itself.
func stop() -> void:
	if _stopped:
		return
	_stopped = true
	if _particles:
		_particles.emitting = false
	get_tree().create_timer(LIFETIME + 0.5).timeout.connect(queue_free)


func is_stopped() -> bool:
	return _stopped


static func _material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = _sprite()
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static var _sprite_cache: Texture2D

## A soft radial puff: opaque in the middle, nothing at the edge.
static func _sprite() -> Texture2D:
	if _sprite_cache == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_sprite_cache = t
	return _sprite_cache
