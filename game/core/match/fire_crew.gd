class_name FireCrew
extends Node
## Aubrey puts a burning man out (the owner, 19 Oct): she takes the fire
## extinguisher from its stash under the ringside apron, walks it to him, and
## sprays him with foam until the flames are out. Presentation only: ManFire
## holds the fire itself; this only sends the referee and the foam.
##
## One man at a time; a second man set alight waits his turn. A job is:
## WAIT (until she is free to leave her spot), FETCH (walk to the stash and
## pick up), REACH (walk to him, out of his reach but close), SPRAY (aim, the
## foam, the flames out partway through), then back to her spot.

signal put_out(wrestler: WrestlerController)

## The stash: the extinguisher lies under the apron, just outside the ropes on
## the hard camera's side. She walks to the ropes and reaches under for it. Her
## walk stops at the ropes (RefereeActor.KEEP_IN), which is as near as she goes.
const STASH := Vector3(2.4, 0.0, 0.0)
const STASH_PROP := Vector3(3.2, -0.5, 0.0)
const STASH_FACE := Vector3(1.0, 0.0, 0.0)
const EXTINGUISHER := "res://assets/weapons/fire_extinguisher.glb"
const FETCH_CLIP := "strikes/weapon_pickup"
const AIM_CLIP := "strikes/weapon_aim"
## Seconds into the fetch the extinguisher is in her hand.
const FETCH_CONTACT := 0.5
## How far from him she stands to spray: out of his reach, close enough to hit.
const SPRAY_STANDOFF := 1.5
const SPRAY_SECONDS := 2.2
## Seconds into the spray the flames are out.
const SPRAY_OUT_AT := 0.6
const FOAM_HEIGHT := 1.1

enum Step { IDLE, WAIT, FETCH_WALK, FETCH, REACH_WALK, SPRAY, RETURN }

var referee: RefereeActor
var _step := Step.IDLE
var _man: ManFire
var _queue: Array[ManFire] = []
var _clock := 0.0
var _prop: Node3D
var _foam: GPUParticles3D
var _held := false
var _out := false


func _ready() -> void:
	var packed := load(EXTINGUISHER) as PackedScene
	if packed:
		_prop = packed.instantiate()
		_prop.name = "Extinguisher"
		add_child(_prop)
		_prop.visible = false
	_foam = _foam_particles()
	add_child(_foam)


## Listens for each man's fire. `ref` is the referee who fetches it.
func watch(ref: RefereeActor, wrestlers: Array) -> void:
	referee = ref
	referee.errand_arrived.connect(_on_arrived)
	for w: Node in wrestlers:
		var m := w.find_child("ManFire", false, false) as ManFire
		if m:
			m.ignited.connect(func(_who: WrestlerController) -> void: _request(m))


func busy() -> bool:
	return _step != Step.IDLE


func _request(m: ManFire) -> void:
	if _man == m or _queue.has(m):
		return
	if _step == Step.IDLE:
		_man = m
		_step = Step.WAIT
		_clock = 0.0
		_out = false
	else:
		_queue.append(m)


func _process(delta: float) -> void:
	if referee == null:
		return
	_clock += delta
	match _step:
		Step.WAIT:
			# she goes while the match is on and she is following it: not in a
			# count or a submission (RefereeActor.begin_live_errand)
			if referee.begin_live_errand():
				referee.errand_go(STASH, STASH_FACE)
				_prop.visible = true
				_prop.global_position = STASH_PROP
				_go(Step.FETCH_WALK)
		Step.FETCH:
			if not _held and _clock >= FETCH_CONTACT:
				_held = true
			if _held:
				_follow_hand(_prop)
			if _clock >= referee.errand_clip_length(FETCH_CLIP):
				_go(Step.REACH_WALK)
				referee.errand_go(_spray_spot(), _to_man_flat())
		Step.SPRAY:
			_follow_hand(_prop)
			var nozzle := _prop.global_position + Vector3.UP * 0.3
			var target := _man.wrestler.global_position + Vector3.UP * FOAM_HEIGHT
			_foam.global_position = nozzle
			if target.distance_to(nozzle) > 0.2:
				_foam.look_at(target, Vector3.UP)
			_foam.emitting = true
			if not _out and _clock >= SPRAY_OUT_AT:
				_out = true
				_man.extinguish()
				put_out.emit(_man.wrestler)
			if _clock >= SPRAY_SECONDS:
				_foam.emitting = false
				_prop.visible = false
				_held = false
				referee.end_live_errand()
				_go(Step.RETURN)
		Step.RETURN:
			if _clock >= 0.6:
				_finish()


func _on_arrived() -> void:
	match _step:
		Step.FETCH_WALK:
			_go(Step.FETCH)
			referee.errand_play(FETCH_CLIP)
		Step.REACH_WALK:
			_go(Step.SPRAY)
			referee.errand_play(AIM_CLIP)


func _go(next: Step) -> void:
	_step = next
	_clock = 0.0


## Her hand, carrying the extinguisher: the same bone holder PropHandoff uses.
func _follow_hand(prop: Node3D) -> void:
	var sk := referee.skeleton()
	if sk == null:
		return
	prop.global_transform = PropHandoff._holder_transform(
			PropHandoff._bone_holder(sk, "hand_r", referee, Vector3.ZERO))


## Where she stands to spray him: on the stash's side of him, out of reach.
func _spray_spot() -> Vector3:
	var man := _man.wrestler.global_position
	var from := Vector3(STASH.x, 0.0, STASH.z) - Vector3(man.x, 0.0, man.z)
	if from.length() < 0.01:
		from = Vector3.RIGHT
	return Vector3(man.x, 0.0, man.z) + from.normalized() * SPRAY_STANDOFF


## She faces him from where she stands.
func _to_man_flat() -> Vector3:
	var man := _man.wrestler.global_position
	return -Vector3(_spray_spot().x - man.x, 0.0, _spray_spot().z - man.z).normalized()


func _finish() -> void:
	_man = null
	_step = Step.IDLE
	_clock = 0.0
	_held = false
	if not _queue.is_empty():
		_request(_queue.pop_front())


func _foam_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Foam"
	p.amount = 160
	p.lifetime = 0.85
	p.emitting = false
	p.local_coords = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0.0, 0.0, -1.0)     # out along the nozzle (look_at points -Z at him)
	m.spread = 11.0
	m.initial_velocity_min = 3.6
	m.initial_velocity_max = 5.0
	m.damping_min = 3.0
	m.damping_max = 4.2
	m.gravity = Vector3(0.0, -0.6, 0.0)
	m.scale_min = 0.12
	m.scale_max = 0.3
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.5))
	grow.add_point(Vector2(0.6, 1.0))
	grow.add_point(Vector2(1.0, 1.4))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	m.scale_curve = grow_tex
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(0.97, 0.97, 0.96, 0.0), Color(0.95, 0.95, 0.94, 0.7),
			Color(0.9, 0.9, 0.89, 0.0)])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	m.color_ramp = ramp
	p.process_material = m
	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = ManFire._soft_dot()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = mat
	p.draw_pass_1 = quad
	return p
