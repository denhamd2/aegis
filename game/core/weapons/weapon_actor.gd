class_name WeaponActor
extends Node3D
## One weapon in the match: its model, the state it shows, where it is.
##
##   UNDER_RING  in the stock, not in the scene's play
##   HELD        in his right hand: follows the hand every frame through the
##               model's grip_r marker (the off hand is WeaponGrip's)
##   THROWN      flying: a ballistic arc integrated on the physics tick, with
##               one bounce and a slide to rest -- no rigid body, so a replay
##               throws it exactly the same way
##   FLOOR       lying where it came to rest, on the mat or the arena floor
##   SET_UP      stood up on purpose: a table up, a ladder open, tacks poured
##   BROKEN      its pieces flung out from where it broke, settled, then gone
##   EFFECT      a copy showing one of its effect roots (the gun's flash, the
##               extinguisher's cloud, the rocket in flight and its blast),
##               played out on the tick and then gone
##
## Wear (hit()) swaps the shown root Clean -> Dented -> Broken where the
## model has those states (WeaponDef.hits_to_dent / hits_to_break).

enum Mode { UNDER_RING, HELD, THROWN, FLOOR, SET_UP, BROKEN, EFFECT }

signal broke(weapon: WeaponActor)
## A thrown weapon reached `who` (WrestlerController) in flight.
signal struck(weapon: WeaponActor, who: Node3D)

const GRAVITY := 9.8
## A held weapon's grip sits this far into the palm from the knuckle line,
## and this far toward the fingertips.
const PALM_IN := 0.022
const PALM_TOWARD_FINGERS := 0.012
## Thrown: the first touchdown keeps this much of the fall as bounce and this
## much of the slide; then it slides to rest at SLIDE_DRAG per second.
const BOUNCE := 0.22
const KEEP_SLIDE := 0.55
const SLIDE_DRAG := 5.0
## A thrown weapon hits a man whose chest it passes within this of.
const HIT_RADIUS := 0.55
## Broken pieces lie this long before they go.
const PIECES_LINGER := 6.0
## Metals in the hall: it carries no reflections (EntranceProps on the
## title), so a pure conductor reads near-black between the lights. Capped
## here with a trace of its own colour as emission, as the title does.
const HALL_METALLIC := 0.55
const HALL_GLOW := 0.05

var def: WeaponDef
var mode: Mode = Mode.UNDER_RING
var holder: Node3D = null          # WrestlerController, while HELD
var hits := 0
var state_root := ""
## Throw state.
var velocity := Vector3.ZERO
var _spin := Vector3.ZERO
var _bounced := false
var _thrower: Node3D = null
var _targets: Array = []
## Broken pieces: [node, velocity, spin, resting].
var _pieces: Array = []
var _broken_for := 0.0
var _model: Node3D
var _roots := {}


## A weapon of `weapon_def`, showing `state` (its held state if empty).
static func make(weapon_def: WeaponDef, state := "") -> WeaponActor:
	var a := WeaponActor.new()
	a.def = weapon_def
	a.name = "Weapon_" + String(weapon_def.id)
	a._load_model()
	a.show_state(state if state != "" else a._held_root())
	return a


func _load_model() -> void:
	var packed := load(def.glb) as PackedScene
	if packed == null:
		push_error("WeaponActor: cannot load %s" % def.glb)
		_model = Node3D.new()
		add_child(_model)
		return
	_model = packed.instantiate()
	add_child(_model)
	if def.glb == WeaponCatalog.BELT_GLB:
		_dress_belt()
	else:
		for child in _model.get_children():
			if child is Node3D:
				_roots[String(child.name)] = child
	_dress_for_the_hall()


## The belt's model has no state roots: its Held* parts become one.
func _dress_belt() -> void:
	var root := Node3D.new()
	root.name = "ChampionshipBelt_Held"
	var mats := EntranceProps._materials()
	for child in _model.get_children():
		if child is Node3D and String(child.name).begins_with("Held"):
			_model.remove_child(child)
			root.add_child(child)
		elif child is Node3D:
			(child as Node3D).visible = false
	_model.add_child(root)
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := String(mi.name)
		if mats.has(key):
			mi.material_override = mats[key]
	_roots[root.name] = root


func _dress_for_the_hall() -> void:
	for node in _model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D and (m as BaseMaterial3D).metallic > HALL_METALLIC:
				var copy := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.metallic = HALL_METALLIC
				copy.emission_enabled = true
				if copy.albedo_texture:
					copy.emission_texture = copy.albedo_texture
				copy.emission = copy.albedo_color
				copy.emission_energy_multiplier = HALL_GLOW
				mi.set_surface_override_material(s, copy)


func _held_root() -> String:
	if def.held != "":
		return def.held
	return "ChampionshipBelt_Held" if _roots.has("ChampionshipBelt_Held") else String(_roots.keys()[0])


## Shows one state root and hides the rest.
func show_state(root_name: String) -> void:
	if not _roots.has(root_name):
		return
	state_root = root_name
	for key: String in _roots:
		(_roots[key] as Node3D).visible = key == root_name


func has_state(root_name: String) -> bool:
	return root_name != "" and _roots.has(root_name)


## A marker of the shown state (grip_r, grip_l, strike, muzzle, top, seat,
## rung_N), as a transform relative to this node; identity if it has none.
func marker(marker_name: String) -> Transform3D:
	var root: Node3D = _roots.get(state_root)
	if root == null:
		return Transform3D.IDENTITY
	for child in root.get_children():
		if String(child.name).ends_with("__" + marker_name) or String(child.name) == marker_name:
			return root.transform * (child as Node3D).transform
	return Transform3D.IDENTITY


func has_marker(marker_name: String) -> bool:
	var root: Node3D = _roots.get(state_root)
	if root == null:
		return false
	for child in root.get_children():
		if String(child.name).ends_with("__" + marker_name):
			return true
	return false


## The shown state's meshes' bounds, relative to this node.
func local_bounds() -> AABB:
	var root: Node3D = _roots.get(state_root)
	var box := AABB()
	var first := true
	if root == null:
		return box
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null or String(mi.name).contains("__piece"):
			continue
		var to_me := Transform3D.IDENTITY
		var n: Node = mi
		while n != self and n != null:
			to_me = (n as Node3D).transform * to_me
			n = n.get_parent()
		var b := to_me * mi.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


func global_marker(marker_name: String) -> Transform3D:
	return global_transform * marker(marker_name)


# --- holding --------------------------------------------------------------

func take(by: Node3D) -> void:
	holder = by
	mode = Mode.HELD
	velocity = Vector3.ZERO
	show_state(_worn_root())


func release() -> void:
	holder = null
	if mode == Mode.HELD:
		mode = Mode.FLOOR


## The grip frame of `wrestler`'s right hand, in world space: +Y along the
## handle out of the thumb side of the fist, +Z out of the back of the hand
## -- the same axes the models' grip_r markers are authored to.
static func grip_frame(wrestler: Node3D) -> Transform3D:
	var hand := _bone(wrestler, "hand_r")
	var index := _bone(wrestler, "index_01_r")
	var pinky := _bone(wrestler, "pinky_01_r")
	if hand == Vector3.INF or index == Vector3.INF or pinky == Vector3.INF:
		return Transform3D(wrestler.global_basis, hand if hand != Vector3.INF else wrestler.global_position)
	var knuckles := (index + pinky) * 0.5
	var fingers := (knuckles - hand).normalized()
	var y := (index - pinky).normalized()
	var z := fingers.cross(y).normalized()
	var x := y.cross(z).normalized()
	var at := knuckles - z * PALM_IN + fingers * PALM_TOWARD_FINGERS
	return Transform3D(Basis(x, y, z), at)


static func _bone(wrestler: Node3D, canonical: String) -> Vector3:
	if wrestler.has_method("_bone_world"):
		return wrestler._bone_world(canonical)
	return Vector3.INF


## Places a held weapon in the hand: its grip_r marker on the hand's grip
## frame. Runs after the skeleton has posed (WeaponGrip calls it), so it is
## where the hand is this frame, not last.
func follow_hand() -> void:
	if mode != Mode.HELD or holder == null:
		return
	global_transform = grip_frame(holder) * marker("grip_r").affine_inverse()


# --- throwing ---------------------------------------------------------------

## Thrown from where it is now at `launch` (m/s), turning at `spin` (rad/s);
## `targets` are the men it can hit on the way.
func throw(launch: Vector3, spin: Vector3, thrower: Node3D, targets: Array) -> void:
	holder = null
	mode = Mode.THROWN
	velocity = launch
	_spin = spin
	_bounced = false
	_thrower = thrower
	_targets = targets


## The surface under a point: the mat inside the ring, the arena floor
## outside it.
static func ground_under(p: Vector3) -> float:
	if absf(p.x) < RingBuilder.MAT_HALF and absf(p.z) < RingBuilder.MAT_HALF:
		return 0.0
	return ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT


func _physics_process(delta: float) -> void:
	match mode:
		Mode.THROWN:
			_tick_flight(delta)
		Mode.BROKEN:
			_tick_pieces(delta)
		Mode.EFFECT:
			_tick_effect(delta)
		Mode.HELD:
			_tick_fire()


# --- firing: the gun, the launcher, the extinguisher -----------------------------

var _fire_in := -1
var _fire_by: Node3D = null
## EFFECT state: which, how long it has run, how long it lasts, and where the
## rocket is going.
var _effect := ""
var _effect_t := 0.0
var _effect_life := 0.0
var _effect_to := Vector3.ZERO
var _effect_velocity := Vector3.ZERO

const EFFECT_LIFE := {"flash": 0.07, "cloud": 0.9, "rocket": 0.0, "blast": 1.3}
const ROCKET_SPEED := 32.0


## A swing has started: if this weapon fires something, it goes off when the
## swing's startup is over.
func fire(after_ticks: int, by: Node3D) -> void:
	if def.effects.is_empty():
		return
	_fire_in = after_ticks
	_fire_by = by


func _tick_fire() -> void:
	if _fire_in < 0:
		return
	_fire_in -= 1
	if _fire_in > 0:
		return
	_fire_in = -1
	var m := global_marker("muzzle")
	var out := muzzle_out(m)
	if def.swing == WeaponDef.Swing.SPRAY and _fire_by:
		# the horn swings on its hose: the cloud goes where he faces, a little down
		out = (-_fire_by.global_basis.z * Vector3(1, 0, 1)).normalized() + Vector3.DOWN * 0.15
	# the flash and the cloud stand out of the muzzle along their +Z
	var at := Transform3D(Basis.looking_at(-out, _up_for(out)), m.origin)
	var host := get_parent()
	match def.swing:
		WeaponDef.Swing.GUN:
			_spawn_effect(host, "flash", at)
		WeaponDef.Swing.SPRAY:
			_spawn_effect(host, "cloud", at)
		WeaponDef.Swing.LAUNCHER:
			var fwd := out
			var reach := float(WeaponCatalog.RANGED[def.swing])
			var to := at.origin + fwd * reach
			var opp: Node3D = _fire_by.get("opponent") if _fire_by else null
			if opp and opp.global_position.distance_to(at.origin) < reach:
				to = opp.global_position + Vector3.UP * 1.1
			var dir := (to - at.origin).normalized()
			# the rocket's nose is its -Z
			var r := _spawn_effect(host, "rocket", Transform3D(Basis.looking_at(dir, _up_for(dir)), at.origin))
			r._effect_to = to
			r._effect_velocity = dir * ROCKET_SPEED


## The way a muzzle marker points out. Markers are authored with their game
## +Y and +Z (tools/blender/weapons/weapon_kit.py marker()); the glTF export
## turns an empty's axes so the authored +Z arrives as its +Y.
static func muzzle_out(m: Transform3D) -> Vector3:
	return m.basis.y.normalized()


static func _up_for(dir: Vector3) -> Vector3:
	return Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.BACK


func _spawn_effect(host: Node, kind: String, at: Transform3D) -> WeaponActor:
	var e := WeaponActor.make(def, String(def.effects.get(kind, "")))
	e.mode = Mode.EFFECT
	e._effect = kind
	e._effect_life = float(EFFECT_LIFE[kind])
	host.add_child(e)
	e.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)
	if kind == "cloud":
		e.scale = Vector3.ONE * 0.2
	return e


func _tick_effect(delta: float) -> void:
	_effect_t += delta
	match _effect:
		"cloud":
			var f := clampf(_effect_t / _effect_life, 0.0, 1.0)
			scale = Vector3.ONE * lerpf(0.2, 1.0, sqrt(f))
		"rocket":
			global_position += _effect_velocity * delta
			if global_position.distance_to(_effect_to) < ROCKET_SPEED * delta * 1.5:
				var blast := _spawn_effect(get_parent(), "blast",
						Transform3D(Basis(), Vector3(_effect_to.x, ground_under(_effect_to), _effect_to.z)))
				blast.scale = Vector3.ONE * 0.3
				queue_free()
			return
		"blast":
			var f := clampf(_effect_t / _effect_life, 0.0, 1.0)
			scale = Vector3.ONE * lerpf(0.3, 1.0, sqrt(f))
	if _effect_t >= _effect_life:
		queue_free()


func _tick_flight(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var p := global_position + velocity * delta
	# kept inside the barricade
	var lim := ArenaBuilder.BARRICADE_RADIUS - 0.3
	if absf(p.x) > lim:
		p.x = signf(p.x) * lim
		velocity.x *= -0.3
	if absf(p.z) > lim:
		p.z = signf(p.z) * lim
		velocity.z *= -0.3
	global_position = p
	if not _bounced:
		rotate_object_local(Vector3.RIGHT, _spin.x * delta)
		rotate_object_local(Vector3.UP, _spin.y * delta)
		for who: Node3D in _targets:
			if who == _thrower:
				continue
			var chest := who.global_position + Vector3.UP * 1.2
			if chest.distance_to(p) < HIT_RADIUS:
				struck.emit(self, who)
				_targets = []
				velocity = Vector3(velocity.x * -0.15, 0.5, velocity.z * -0.15)
				break
	var ground := ground_under(p)
	if p.y <= ground + 0.02:
		global_position.y = ground + 0.02
		if not _bounced:
			_bounced = true
			velocity = Vector3(velocity.x * KEEP_SLIDE, -velocity.y * BOUNCE, velocity.z * KEEP_SLIDE)
			_lay_flat()
		else:
			velocity.y = 0.0
			var flat := Vector2(velocity.x, velocity.z)
			flat = flat.move_toward(Vector2.ZERO, SLIDE_DRAG * delta)
			velocity.x = flat.x
			velocity.z = flat.y
			if flat.length() < 0.02:
				velocity = Vector3.ZERO
				mode = Mode.FLOOR


## Down on its side, along the way it was going -- a held weapon's handle
## (its +Y) lies flat.
func _lay_flat() -> void:
	var yaw := atan2(velocity.x, velocity.z) if Vector2(velocity.x, velocity.z).length() > 0.05 \
			else global_rotation.y
	global_basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI / 2.0)


## Dropped where it is: straight down, laid flat.
func drop() -> void:
	holder = null
	throw(Vector3(0.0, 0.5, 0.0), Vector3.ZERO, null, [])


## Set down on purpose, upright at `at` facing `yaw`, in its set-up state.
func set_up_at(at: Vector3, yaw: float) -> void:
	holder = null
	mode = Mode.SET_UP
	show_state(def.set_up if def.set_up != "" else _held_root())
	global_transform = Transform3D(Basis(Vector3.UP, yaw), Vector3(at.x, ground_under(at), at.z))


# --- wear --------------------------------------------------------------------

## One hit landed with it (or on it). Returns true if it broke.
func hit(seed: int) -> bool:
	hits += 1
	if def.can_break() and hits >= def.hits_to_break:
		shatter(seed)
		return true
	show_state(_worn_root())
	return false


func _worn_root() -> String:
	if def.can_dent() and hits >= def.hits_to_dent and has_state(def.dented):
		return def.dented
	return _held_root()


## Broken: the Broken state's pieces fly from where they are, on a spread
## seeded from `seed` (the match tick), so a replay breaks it the same way.
func shatter(seed: int) -> void:
	if not has_state(def.broken):
		mode = Mode.BROKEN
		_broken_for = PIECES_LINGER
		visible = false
		broke.emit(self)
		return
	var keep := global_transform
	show_state(def.broken)
	holder = null
	mode = Mode.BROKEN
	_broken_for = 0.0
	_pieces = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var root: Node3D = _roots[def.broken]
	var parts := root.find_children("*__piece_*", "Node3D", true, false)
	if parts.is_empty():
		parts = root.get_children()
	for node in parts:
		var n := node as Node3D
		if n == null:
			continue
		var out := (n.global_position - keep.origin)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var v := out * rng.randf_range(0.8, 2.6) + Vector3.UP * rng.randf_range(1.0, 3.0)
		var spin := Vector3(rng.randf_range(-9, 9), rng.randf_range(-6, 6), rng.randf_range(-9, 9))
		_pieces.append([n, v, spin, false])
	broke.emit(self)


func _tick_pieces(delta: float) -> void:
	_broken_for += delta
	if _broken_for >= PIECES_LINGER:
		visible = false
		set_physics_process(false)
		return
	for piece: Array in _pieces:
		if piece[3]:
			continue
		var n: Node3D = piece[0]
		var v: Vector3 = piece[1]
		v.y -= GRAVITY * delta
		var p := n.global_position + v * delta
		var ground := ground_under(p) + 0.01
		if p.y <= ground:
			p.y = ground
			if v.length() < 1.0:
				piece[3] = true
			v = Vector3(v.x * 0.4, -v.y * 0.2, v.z * 0.4)
		else:
			var s: Vector3 = piece[2]
			n.rotate_x(s.x * delta)
			n.rotate_z(s.z * delta)
		n.global_position = p
		piece[1] = v
