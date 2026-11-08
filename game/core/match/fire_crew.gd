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
##
## The owner, 2 Nov: "Aubrey tries the extinguisher once. However if it
## doesn't reach him, she doesn't try again and he keeps burning." Measured
## causes, all fixed here:
## - she cannot leave the ring (RefereeActor.KEEP_IN), and the spot she was
##   sent to was beside him wherever he was -- outside, she never arrived, and
##   the errand hung for the rest of the match. Her spot is now inside the
##   ropes, the nearest she can get, and it follows him while she walks;
## - the flames went out on a timer whether the foam reached him or not. Now
##   only within SPRAY_REACH; out of it she holds, extinguisher up, at the
##   ropes nearest him (HOLD) and goes again the moment he is in reach;
## - a man who caught again while she was still on the job was ignored (he was
##   "already handled"), and nothing looked again after. She now ends a spray
##   by checking he is out, and whenever she is free she looks for anyone
##   still burning.

signal put_out(wrestler: WrestlerController)

## The stash: the extinguisher lies under the apron, just outside the ropes on
## the hard camera's side. She walks to the ropes and reaches under for it. Her
## walk stops at the ropes (RefereeActor.KEEP_IN), which is as near as she goes.
const STASH := Vector3(2.4, 0.0, 0.0)
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
## How far the foam carries: from her hand to him, flat.
const SPRAY_REACH := 4.0
## Inside the ropes by this much, so the walk can always arrive.
const ROPE_MARGIN := 0.25
## He has moved this far from where she was heading: she re-aims the walk.
const RETARGET := 0.6
const RECHECK_EVERY := 0.4

enum Step { IDLE, WAIT, FETCH_WALK, FETCH, REACH_WALK, SPRAY, RETURN, HOLD }

var referee: RefereeActor
var _step := Step.IDLE
var _man: ManFire
var _queue: Array[ManFire] = []
var _clock := 0.0
var _prop: Node3D
var _muzzle: Node3D
var _foam: GPUParticles3D
var _held := false
var _out := false
## Every man she watches, so she can look for one still burning.
var _fires: Array[ManFire] = []
var _heading := Vector3.INF
var _recheck := 0.0


func _ready() -> void:
	var packed := load(EXTINGUISHER) as PackedScene
	if packed:
		_prop = packed.instantiate()
		_prop.name = "Extinguisher"
		add_child(_prop)
		_prop.visible = false
		# The asset ships its own polygonal "Cloud" plume. On a wrestler's
		# weapon WeaponActor shows one state root at a time and keeps it
		# hidden; a raw instance shows every root, so Aubrey carrying it
		# displayed a solid cloud from the moment she picked it up. Hide it
		# here -- the soft particle spray below is the only discharge.
		for node in _prop.find_children("*Cloud*", "Node3D", true, false):
			(node as Node3D).visible = false
		_muzzle = _prop.find_child("FireExtinguisher_Clean__muzzle", true, false) as Node3D
	_foam = _foam_particles()
	add_child(_foam)


## Listens for each man's fire. `ref` is the referee who fetches it.
func watch(ref: RefereeActor, wrestlers: Array) -> void:
	referee = ref
	referee.errand_arrived.connect(_on_arrived)
	for w: Node in wrestlers:
		var m := w.find_child("ManFire", false, false) as ManFire
		if m:
			_fires.append(m)
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
		Step.IDLE:
			# anyone still burning -- caught again while she was busy
			for m in _fires:
				if is_instance_valid(m) and m.burning:
					_request(m)
					break
		Step.WAIT:
			# she goes while the match is on and she is following it: not in a
			# count or a submission (RefereeActor.begin_live_errand)
			if referee.begin_live_errand():
				referee.errand_go(STASH, STASH_FACE)
				# The prop stays out of sight until her hand is at the stash;
				# showing it there and then snapping it into her hand was a
				# visible pop (the model was never visible in the stash).
				_go(Step.FETCH_WALK)
		Step.FETCH:
			if not _held and _clock >= FETCH_CONTACT:
				_held = true
				_prop.visible = true
			if _held:
				_follow_hand(_prop)
			if _clock >= referee.errand_clip_length(FETCH_CLIP):
				_walk_to_him()
		Step.REACH_WALK:
			_follow_hand(_prop)
			if not _man.burning:
				_done_spraying()
				return
			# he moved: aim the walk at where he is now
			_recheck += delta
			if _recheck >= RECHECK_EVERY:
				_recheck = 0.0
				if _flat(_spray_spot()).distance_to(_heading) > RETARGET:
					_walk_to_him()
		Step.HOLD:
			# at the ropes, extinguisher up, until he is in reach
			_follow_hand(_prop)
			if not _man.burning:
				_done_spraying()
				return
			_recheck += delta
			if _recheck >= RECHECK_EVERY:
				_recheck = 0.0
				if in_reach():
					_start_spray()
				elif _flat(_spray_spot()).distance_to(_heading) > RETARGET:
					_walk_to_him()
		Step.SPRAY:
			_follow_hand(_prop)
			var nozzle := _prop.global_position + Vector3.UP * 0.3
			if _muzzle:
				# From the horn, not the tank: the discharge leaves the
				# muzzle the model was authored with.
				nozzle = _muzzle.global_position
			var target := _man.wrestler.global_position + Vector3.UP * FOAM_HEIGHT
			_foam.global_position = nozzle
			if target.distance_to(nozzle) > 0.2:
				_foam.look_at(target, Vector3.UP)
			_foam.emitting = true
			# out only where the foam reaches him
			if not _out and _clock >= SPRAY_OUT_AT and in_reach():
				_out = true
				_man.extinguish()
				put_out.emit(_man.wrestler)
			if _clock >= SPRAY_SECONDS:
				_foam.emitting = false
				if _man.burning:
					# missed, or he caught again: after him, still holding it
					_out = false
					_walk_to_him()
				else:
					_done_spraying()
		Step.RETURN:
			# Carry it back rather than letting it vanish where he stood; it
			# is put away (hidden) when she reaches her spot.
			_follow_hand(_prop)
			if _clock >= 0.6:
				_finish()


func _on_arrived() -> void:
	match _step:
		Step.FETCH_WALK:
			_go(Step.FETCH)
			referee.errand_play(FETCH_CLIP)
		Step.REACH_WALK:
			if in_reach():
				_start_spray()
			else:
				# the ropes are as near as she gets: hold there
				_go(Step.HOLD)
				referee.errand_idle()


## Whether the foam reaches him from where she stands.
func in_reach() -> bool:
	if _man == null or referee == null:
		return false
	return _flat(referee.global_position).distance_to(_flat(_man.wrestler.global_position)) <= SPRAY_REACH


func _walk_to_him() -> void:
	_go(Step.REACH_WALK)
	_recheck = 0.0
	_heading = _flat(_spray_spot())
	referee.errand_go(_heading, _to_man_flat())


func _start_spray() -> void:
	_go(Step.SPRAY)
	_out = false
	referee.errand_play(AIM_CLIP)


func _done_spraying() -> void:
	_foam.emitting = false
	referee.end_live_errand()
	_go(Step.RETURN)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


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
	if _step == Step.SPRAY and _muzzle and _man and is_instance_valid(_man.wrestler):
		_aim_at_man(prop)


## Points the horn at the man with the tank hanging below it, rather than
## letting the shortest-arc turn roll the body and hose to any angle.
##
## The muzzle node's +Z is the discharge axis (the same one WeaponActor's
## cloud effect uses). Pointing that at him leaves one free roll; this solves
## it by putting the prop's own +Y (up the tank from the grip) as close to
## world up as the constraint allows. Two passes: the roll moves the muzzle,
## so the direction is re-solved from where the horn ended up.
func _aim_at_man(prop: Node3D) -> void:
	var target := _man.wrestler.global_position + Vector3.UP * FOAM_HEIGHT
	for _i in 2:
		var want := target - _muzzle.global_position
		if want.length() < 0.01:
			return
		want = want.normalized()
		# 1. The horn's discharge axis onto him.
		var have := _muzzle.global_transform.basis.z.normalized()
		prop.global_basis = (Basis(Quaternion(have, want)) * prop.global_basis).orthonormalized()
		# 2. Roll about that axis until the tank stands up under the grip.
		var up := Vector3.UP - want * want.dot(Vector3.UP)
		var tank := prop.global_basis.y - want * prop.global_basis.y.dot(want)
		if up.length() > 0.01 and tank.length() > 0.01:
			var roll := tank.normalized().signed_angle_to(up.normalized(), want)
			prop.global_basis = (Basis(want, roll) * prop.global_basis).orthonormalized()
	# The last roll shifts the muzzle; one final aim-only correction.
	var at := target - _muzzle.global_position
	if at.length() > 0.01:
		var horn := _muzzle.global_transform.basis.z.normalized()
		prop.global_basis = (Basis(Quaternion(horn, at.normalized())) * prop.global_basis).orthonormalized()


## Where she stands to spray him: on the stash's side of him, out of reach --
## and never past the ropes, which she cannot cross. Outside, that is the
## point of the ropes nearest him.
func _spray_spot() -> Vector3:
	var man := _man.wrestler.global_position
	var from := Vector3(STASH.x, 0.0, STASH.z) - Vector3(man.x, 0.0, man.z)
	if from.length() < 0.01:
		from = Vector3.RIGHT
	var spot := Vector3(man.x, 0.0, man.z) + from.normalized() * SPRAY_STANDOFF
	var edge := RefereeActor.KEEP_IN - ROPE_MARGIN
	if absf(man.x) > edge or absf(man.z) > edge:
		spot = Vector3(man.x, 0.0, man.z)
	return Vector3(clampf(spot.x, -edge, edge), 0.0, clampf(spot.z, -edge, edge))


## She faces him from where she stands.
func _to_man_flat() -> Vector3:
	var man := _man.wrestler.global_position
	var to := Vector3(man.x - _spray_spot().x, 0.0, man.z - _spray_spot().z)
	return to.normalized() if to.length() > 0.01 else Vector3.FORWARD


func _finish() -> void:
	_man = null
	_heading = Vector3.INF
	_step = Step.IDLE
	_clock = 0.0
	_held = false
	_prop.visible = false
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
