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

enum Mode { UNDER_RING, HELD, THROWN, FLOOR, SET_UP, BROKEN, EFFECT, SLIDING }

signal broke(weapon: WeaponActor)
## A thrown weapon reached `who` (WrestlerController) in flight.
signal struck(weapon: WeaponActor, who: Node3D)

const GRAVITY := 9.8
## Every weapon drawn from under the ring has a finite match life, including
## when it is being carried. This makes the weapon pile turn over instead of
## leaving the first chair or bat available for the entire match.
const MATCH_LIFETIME_TICKS := 60 * 45
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
## A broken piece whose origin is this near the floor is the legs.
const LEGS_BELOW := 0.25
## A broken piece is kept this far (flat) from any of the bones of the man it
## broke under, below this height over the bone -- the body as a few fat
## capsules, enough that the steel and the boards land round his limbs.
const BODY_CLEAR := 0.3
const BODY_OVER := 0.35
const BODY_BONES := ["pelvis", "spine_03", "Head", "thigh_l", "thigh_r", "calf_l", "calf_r", "foot_l",
		"foot_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r", "hand_l", "hand_r"]
## Metals in the hall: it carries no reflections (EntranceProps on the
## title), so a pure conductor reads near-black between the lights. Capped
## here with a trace of its own colour as emission, as the title does.
const HALL_METALLIC := 0.55
const HALL_GLOW := 0.05
const SLIDE_SPEED := 6.0

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
var _slide_target := Vector3.ZERO
## Broken pieces: [node, velocity, spin, resting].
var _pieces: Array = []
## The man it broke under: its pieces land round him, not through him.
var _clear_of: Node3D = null
var _broken_for := 0.0
var match_lifetime_ticks := 0
var match_lifetime_limit := MATCH_LIFETIME_TICKS
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
	_retune_grips()


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
	# Handles, which the prop never had (it was made to be worn and held up,
	# not swung): the end of the right strap, and a hand's width in from it,
	# each with +Y running down the strap toward the plate -- so it hangs from
	# the hand by its strap and swings plate-first. Measured off the meshes:
	# straps to x = +-0.52, the plate centred at (0, -0.07), the face +Z.
	var along := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	for m: Array in [["grip_r", Vector3(0.24, -0.08, 0.0)], ["grip_l", Vector3(-0.06, -0.08, 0.0)],
			["strike", Vector3(0.0, -0.07, 0.0)]]:
		var marker := Node3D.new()
		marker.name = "ChampionshipBelt_Held__" + String(m[0])
		marker.transform = Transform3D(along, m[1])
		root.add_child(marker)
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := String(mi.name)
		if mats.has(key):
			mi.material_override = mats[key]
	_roots[root.name] = root


## The pane's glass as glass in the hall: under the ring's white key a
## glossy sheet at the export's 28% read as milky white board. Mostly clear,
## a green edge-tint, a low sheen: the lights catch it, the canvas shows
## through.
const GLASS_TINT := Color(0.78, 0.9, 0.88, 0.1)


func _dress_for_the_hall() -> void:
	for node in _model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for s in mi.get_surface_override_material_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D and m.resource_name.ends_with("_glass") and def.id == &"glass_pane":
				var glass := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass.albedo_color = GLASS_TINT
				glass.roughness = 0.05
				glass.metallic_specular = 0.25
				glass.cull_mode = BaseMaterial3D.CULL_DISABLED
				mi.set_surface_override_material(s, glass)
				continue
			if m is BaseMaterial3D and (m as BaseMaterial3D).metallic > HALL_METALLIC:
				var copy := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
				copy.metallic = HALL_METALLIC
				copy.emission_enabled = true
				if copy.albedo_texture:
					copy.emission_texture = copy.albedo_texture
				copy.emission = copy.albedo_color
				copy.emission_energy_multiplier = HALL_GLOW
				mi.set_surface_override_material(s, copy)


## The source props sometimes put two-hand markers on different rungs or on
## opposite ends of an object rather than where a wrestler can hold it. Keep
## these authored contact points ergonomic so WeaponGrip can preserve the
## silhouette without stretching the arms.
func _retune_grips() -> void:
	var grip_l_y := NAN
	var grip_l_x := NAN
	match def.id:
		&"ladder":
			grip_l_y = 1.211
			grip_l_x = -0.18
		&"briefcase":
			grip_l_y = 0.025
			grip_l_x = -0.30
		&"shovel":
			grip_l_y = -0.14
		&"fire_extinguisher":
			grip_l_y = -0.27
		&"table", &"glass_pane":
			grip_l_x = -0.28
		&"championship_belt":
			return # its virtual grip markers are authored in _dress_belt
		_:
			return
	for root: Node3D in _roots.values():
		for child in root.get_children():
			if child is not Node3D or not String(child.name).ends_with("__grip_l"):
				continue
			var marker := child as Node3D
			var p := marker.position
			if not is_nan(grip_l_y):
				p.y = grip_l_y
			if not is_nan(grip_l_x):
				p.x = grip_l_x
			marker.position = p


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
##
## "grips" is the point halfway between grip_r and grip_l (in grip_r's turn):
## what a two-handed carry centres on, so the thing is held square in front
## of him with a hand either side, not hung off one hand.
func marker(marker_name: String) -> Transform3D:
	if marker_name == "grips":
		var r := marker("grip_r")
		return Transform3D(r.basis, (r.origin + marker("grip_l").origin) * 0.5)
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
	_rest_y = 0.02
	_thrower = thrower
	_targets = targets


## Send a weapon flat under the bottom rope to a spot on the canvas. No wrestler
## follows it: he can choose to climb back in carrying his weapon instead.
func slide_into_ring(target: Vector3) -> void:
	holder = null
	mode = Mode.SLIDING
	velocity = Vector3.ZERO
	_targets.clear()
	_slide_target = target
	_slide_target.y = ground_under(target) + 0.02
	global_position.y = ground_under(global_position) + 0.02
	_bounced = false


func _tick_slide(delta: float) -> void:
	var to_target := _slide_target - global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	var step := SLIDE_SPEED * delta
	if flat.length() <= step:
		global_position = _slide_target
		_lay_flat()
		mode = Mode.FLOOR
		_rest_on_floor(ground_under(global_position))
		return
	global_position += flat.normalized() * step
	global_position.y = ground_under(global_position) + 0.02
	_lay_flat()


## The surface under a point: the mat inside the ring, the arena floor
## outside it.
static func ground_under(p: Vector3) -> float:
	if absf(p.x) < RingBuilder.MAT_HALF and absf(p.z) < RingBuilder.MAT_HALF:
		return 0.0
	return ArenaBuilder.match_surface_y(p)


func _physics_process(delta: float) -> void:
	if mode != Mode.EFFECT:
		match_lifetime_ticks += 1
		if match_lifetime_ticks >= match_lifetime_limit:
			_expire_from_match()
			return
	match mode:
		Mode.THROWN:
			_tick_flight(delta)
		Mode.SLIDING:
			_tick_slide(delta)
		Mode.BROKEN:
			_tick_pieces(delta)
		Mode.EFFECT:
			_tick_effect(delta)
		Mode.HELD:
			_tick_fire()


## Release it cleanly from a hand before the actor is removed from the match.
func _expire_from_match() -> void:
	if holder is WrestlerController:
		var wrestler := holder as WrestlerController
		if wrestler.held_weapon == self:
			wrestler.drop_weapon()
	visible = false
	set_physics_process(false)
	queue_free()


# --- firing: the gun, the launcher, the extinguisher -----------------------------

var _fire_in := -1
var _fire_by: Node3D = null
## A launcher shot that goes wide: degrees off his aim, (yaw, pitch); ZERO for
## one that flies at the man in front of him (WrestlerController rolls it).
var _fire_miss := Vector2.ZERO
## EFFECT state: which, how long it has run, how long it lasts, and where the
## rocket is going.
var _effect := ""
var _effect_t := 0.0
var _effect_life := 0.0
var _effect_to := Vector3.ZERO
var _effect_velocity := Vector3.ZERO
## A rocket at the man (it flies to him and goes off on him), or wide of him
## (it flies on until it runs into something: VenueDamage.ray).
var _effect_homing := false
var _effect_travelled := 0.0

const EFFECT_LIFE := {"flash": 0.07, "cloud": 0.9, "rocket": 0.0, "blast": 1.3}
## Who hears about a weapon going off or breaking (MatchAudio, MatchCamera):
## on_weapon_event(weapon, event) with event "flash", "cloud", "rocket",
## "blast" or "broke". A group, not a signal: weapons are made mid-match,
## long after the listeners were set up.
const LISTENERS := &"weapon_listeners"
const ROCKET_SPEED := 32.0
## A rocket that hits nothing goes off in the air this far out.
const ROCKET_MAX_RANGE := 70.0
## It flies at the man only inside this much of his aim (the launcher's
## RANGED_CONE_DEG, with a little give).
const ROCKET_HOMING_CONE_DEG := 20.0


## A swing has started: if this weapon fires something, it goes off when the
## swing's startup is over.
func fire(after_ticks: int, by: Node3D, miss := Vector2.ZERO) -> void:
	if def.effects.is_empty():
		return
	_fire_in = after_ticks
	_fire_by = by
	_fire_miss = miss


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
			var opp: Node3D = _fire_by.get("opponent") if _fire_by else null
			var homing := false
			var to := at.origin + fwd * ROCKET_MAX_RANGE
			if opp and _fire_miss == Vector2.ZERO and opp.global_position.distance_to(at.origin) < reach:
				var flat_fwd := Vector3(fwd.x, 0.0, fwd.z)
				var flat_to := opp.global_position - at.origin
				flat_to.y = 0.0
				homing = flat_fwd.length() < 0.01 or rad_to_deg(flat_fwd.angle_to(flat_to)) \
						<= ROCKET_HOMING_CONE_DEG
			var dir := fwd
			if homing:
				to = opp.global_position + Vector3.UP * 1.1
				dir = (to - at.origin).normalized()
			else:
				# wide of him: off his aim by the miss, and on until it runs
				# into something -- a post, a panel, the desk, a screen, the
				# crowd (the owner, 19 Oct)
				dir = fwd.rotated(Vector3.UP, deg_to_rad(_fire_miss.x))
				var right := dir.cross(Vector3.UP)
				if right.length() > 0.01:
					dir = dir.rotated(right.normalized(), deg_to_rad(_fire_miss.y))
				dir = dir.normalized()
			# the rocket's nose is its -Z
			var r := _spawn_effect(host, "rocket", Transform3D(Basis.looking_at(dir, _up_for(dir)), at.origin))
			r._effect_to = to
			r._effect_velocity = dir * ROCKET_SPEED
			r._effect_homing = homing


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
	e._fire_by = _fire_by
	host.add_child(e)
	e.global_transform = Transform3D(at.basis.orthonormalized(), at.origin)
	if kind == "cloud":
		e.scale = Vector3.ONE * 0.2
	e._announce(kind)
	return e


func _announce(event: String) -> void:
	if is_inside_tree():
		get_tree().call_group(LISTENERS, &"on_weapon_event", self, event)


func _tick_effect(delta: float) -> void:
	_effect_t += delta
	match _effect:
		"cloud":
			var f := clampf(_effect_t / _effect_life, 0.0, 1.0)
			scale = Vector3.ONE * lerpf(0.2, 1.0, sqrt(f))
		"rocket":
			var step := _effect_velocity * delta
			if _effect_homing:
				global_position += step
				if global_position.distance_to(_effect_to) < ROCKET_SPEED * delta * 1.5:
					_rocket_blast(Vector3(_effect_to.x, VenueDamage.surface_under(_effect_to), _effect_to.z),
							Vector3.UP, null, false)
				return
			var damage := VenueDamage.of(self)
			var hit := damage.ray(global_position, global_position + step) if damage else {}
			if not hit.is_empty():
				_rocket_blast(hit["point"], hit["normal"], hit.get("target"), bool(hit.get("crowd", false)))
				return
			global_position += step
			_effect_travelled += step.length()
			if _effect_travelled >= ROCKET_MAX_RANGE:
				_rocket_blast(global_position, -step.normalized(), null, false)
			return
		"blast":
			var f := clampf(_effect_t / _effect_life, 0.0, 1.0)
			scale = Vector3.ONE * lerpf(0.3, 1.0, sqrt(f))
	if _effect_t >= _effect_life:
		queue_free()


## Where a rocket goes off: the fireball (on the floor under it, or at the
## height of what it hit), and the damage it does to the building.
func _rocket_blast(at: Vector3, normal: Vector3, target: Variant, crowd: bool) -> void:
	var floor_y := VenueDamage.surface_under(at)
	var base := Vector3(at.x, floor_y if at.y - floor_y < 1.2 else at.y - 0.6, at.z)
	var blast := _spawn_effect(get_parent(), "blast", Transform3D(Basis(), base))
	blast.scale = Vector3.ONE * 0.3
	var damage := VenueDamage.of(self)
	if damage:
		damage.blast(at, normal, target as VenueDamage.Target, crowd)
	queue_free()


func _tick_flight(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var p := global_position + velocity * delta
	# kept inside the barricade, or up the ramp and on the deck
	var lim := ArenaBuilder.BARRICADE_RADIUS - 0.3
	if ArenaBuilder.in_entrance_way(p):
		var way := ArenaBuilder.entrance_way_point(p, 0.2)
		if way.x != p.x:
			velocity.x *= -0.3
		if way.z != p.z:
			velocity.z *= -0.3
		p = way
	else:
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
	if p.y <= ground + _rest_y:
		global_position.y = ground + _rest_y
		if not _bounced:
			_bounced = true
			velocity = Vector3(velocity.x * KEEP_SLIDE, -velocity.y * BOUNCE, velocity.z * KEEP_SLIDE)
			_lay_flat()
			_rest_on_floor(ground)
		else:
			velocity.y = 0.0
			var flat := Vector2(velocity.x, velocity.z)
			flat = flat.move_toward(Vector2.ZERO, SLIDE_DRAG * delta)
			velocity.x = flat.x
			velocity.z = flat.y
			if flat.length() < 0.02:
				velocity = Vector3.ZERO
				mode = Mode.FLOOR
				_rest_on_floor(ground)


## On the floor the way the thing itself would lie: of the quarter-turns from
## how it landed, the one that puts its weight lowest, its lowest point on the
## floor. Laying the handle flat and the origin on the floor was right for a
## bat and wrong for anything with breadth: a folded table stood on its edge
## half through the mat with its handles 36 cm under it, and the can sank.
var _rest_y := 0.02     # its origin's height over the floor as it lies


func _rest_on_floor(ground: float) -> void:
	var root: Node3D = _roots.get(state_root)
	if root == null:
		return
	var to_local := global_transform.affine_inverse()
	var verts := PackedVector3Array()
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var into := to_local * mi.global_transform
		for surface in mi.mesh.get_surface_count():
			var all: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var step := maxi(1, all.size() / 200)
			for i in range(0, all.size(), step):
				verts.append(into * all[i])
	if verts.is_empty():
		return
	var landed := global_basis.orthonormalized()
	var yaw := Basis(Vector3.UP, global_rotation.y)
	var best := landed
	var best_score := INF
	var best_low := 0.0
	for ix in 4:
		for iz in 4:
			var b := yaw * Basis(Vector3.RIGHT, ix * PI / 2.0) * Basis(Vector3.BACK, iz * PI / 2.0)
			var low := INF
			var sum := 0.0
			for v in verts:
				var y := (b * v).y
				low = minf(low, y)
				sum += y
			# its weight's height over the floor; within a centimetre, the
			# way nearest how it landed
			var score := sum / verts.size() - low
			score += 0.001 * (b.x.distance_to(landed.x) + b.y.distance_to(landed.y))
			if score < best_score:
				best_score = score
				best = b
				best_low = low
	global_transform = Transform3D(best, Vector3(global_position.x, ground - best_low, global_position.z))
	_rest_y = -best_low      # it slides on that side, at that height, till it stops


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
func set_up_at(at: Vector3, yaw: float, state_override := "") -> void:
	holder = null
	mode = Mode.SET_UP
	show_state(state_override if state_override != "" else \
			(def.set_up if def.set_up != "" else _held_root()))
	var place := at
	# A set piece is wider than the wrestler's root. Clamp its full rotated
	# footprint inside the barricade line; clamping only the root let tables
	# visibly hang through the wall when set near ringside.
	if ArenaBuilder.in_entrance_way(place):
		# up the ramp or on the deck: its footprint kept on the walkway
		var b := local_bounds()
		var reach := maxf(b.size.x, b.size.z) * 0.5
		var on := ArenaBuilder.entrance_way_point(place, minf(reach, 1.2))
		place.x = on.x
		place.z = on.z
	elif absf(place.x) > RingBuilder.MAT_HALF or absf(place.z) > RingBuilder.MAT_HALF:
		var bounds := local_bounds()
		var basis := Basis(Vector3.UP, yaw)
		var centre_offset := basis * bounds.get_center()
		var half := bounds.size * 0.5
		var extent_x := absf(basis.x.x) * half.x + absf(basis.z.x) * half.z
		var extent_z := absf(basis.x.z) * half.x + absf(basis.z.z) * half.z
		var safe_x := ArenaBuilder.BARRICADE_RADIUS - extent_x - 0.22
		var safe_z := ArenaBuilder.BARRICADE_RADIUS - extent_z - 0.22
		place.x = clampf(place.x + centre_offset.x, -safe_x, safe_x) - centre_offset.x
		place.z = clampf(place.z + centre_offset.z, -safe_z, safe_z) - centre_offset.z
	global_transform = Transform3D(Basis(Vector3.UP, yaw),
			Vector3(place.x, ground_under(place), place.z))
	_announce("set_up")


## A standing A-frame ladder is an interactive climbing surface. The laid-out
## state remains available for the paired ladder-slam spot.
func is_climbable_ladder() -> bool:
	return def != null and def.id == &"ladder" and mode == Mode.SET_UP \
			and state_root == "Ladder_Open" and has_marker("rung_1") and has_marker("rung_9")


# --- fire --------------------------------------------------------------------

## Set alight (the owner, 19 Oct: "the flaming table"): a set-up table burns
## along its top until a man goes through it, and its pieces burn on the floor
## until they go. A man who lands on it catches fire (WrestlerController
## _land_on, ManFire.ignite). Only a set-up table: anything else stays as it is.
var ablaze := false
var _fire: Node3D = null
## The flames along a burning top: how many, how big, and how far up off it.
const ABLAZE_FLAMES := 70
const ABLAZE_LIFT := 0.04
## A burning table's flames: orange tongues, not a white sheet. The man's own
## flames (ManFire) start near white, which is right on a body but piled up
## additively along a whole table top read as one blown-out glare.
const TABLE_FLAME_RAMP := [Color(1.0, 0.70, 0.30, 0.55), Color(1.0, 0.42, 0.08, 0.45),
		Color(0.70, 0.10, 0.02, 0.25), Color(0.30, 0.04, 0.01, 0.0)]


## A set piece that can be set alight: the table, standing.
func can_set_ablaze() -> bool:
	return def != null and def.id == &"table" and mode == Mode.SET_UP and not ablaze


func set_ablaze() -> void:
	if ablaze:
		return
	ablaze = true
	var box := local_bounds()
	_fire = Node3D.new()
	_fire.name = "TableFire"
	add_child(_fire)
	_fire.position = Vector3(box.get_center().x, box.end.y + ABLAZE_LIFT, box.get_center().z)
	var flames := _table_flames(ABLAZE_FLAMES)
	flames.lifetime = 0.7
	var m := flames.process_material as ParticleProcessMaterial
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(box.size.x * 0.46, 0.02, box.size.z * 0.42)
	m.initial_velocity_min = 0.5
	m.initial_velocity_max = 1.2
	m.scale_min = 0.55
	m.scale_max = 1.0
	flames.visibility_aabb = AABB(Vector3(-1.5, -0.3, -1.0), Vector3(3.0, 2.2, 2.0))
	flames.emitting = true
	_fire.add_child(flames)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = ManFire.FIRE_HOT
	glow.light_energy = 1.3
	glow.omni_range = 4.0
	glow.position = Vector3.UP * 0.4
	_fire.add_child(glow)
	_announce("ignite")


## The burning top's flames, carried onto each broken piece: smaller, and they
## go with the piece when it goes.
func _burn_pieces() -> void:
	if _fire:
		_fire.queue_free()
		_fire = null
	for entry: Array in _pieces:
		var n: Node3D = entry[0]
		var flames := _table_flames(12)
		(flames.process_material as ParticleProcessMaterial).scale_max = 0.6
		flames.emitting = true
		n.add_child(flames)


## ManFire's flames with the table's darker ramp and a tongue for a sprite:
## tall and tapering, so a burning top reads as flames licking up off it
## rather than ManFire's round dots, which piled along a table into a haze.
static func _table_flames(amount: int) -> GPUParticles3D:
	var flames := ManFire._flame_particles()
	flames.amount = amount
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.3, 0.75, 1.0])
	grad.colors = PackedColorArray(TABLE_FLAME_RAMP)
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	var m := flames.process_material as ParticleProcessMaterial
	m.color_ramp = ramp
	m.angle_min = -12.0
	m.angle_max = 12.0
	var quad := (flames.draw_pass_1 as QuadMesh).duplicate() as QuadMesh
	quad.size = Vector2(0.22, 0.55)
	quad.center_offset = Vector3(0.0, 0.2, 0.0)
	var mat := (quad.material as StandardMaterial3D).duplicate() as StandardMaterial3D
	mat.albedo_texture = flame_tongue()
	quad.material = mat
	flames.draw_pass_1 = quad
	return flames


static var _tongue: ImageTexture


## A flame tongue, white on clear (the ramp colours it): wide and solid at
## the root, narrowing and breaking up toward the tip.
static func flame_tongue() -> ImageTexture:
	if _tongue:
		return _tongue
	var w := 48
	var h := 112
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		var up := 1.0 - float(y) / float(h - 1)          # 0 at the root, 1 at the tip
		var half := 0.46 * pow(1.0 - up, 0.55) * (1.0 + 0.08 * sin(up * 19.0))
		var lean := 0.05 * sin(up * 6.3)
		for x in w:
			var u := float(x) / float(w - 1) - 0.5 - lean
			var edge := 1.0 - smoothstep(half * 0.35, half, absf(u))
			var a := edge * smoothstep(0.0, 0.10, up) * (1.0 - smoothstep(0.62, 1.0, up))
			var core := 1.0 - smoothstep(0.0, half * 0.6, absf(u))
			var v := clampf(0.75 + 0.25 * core, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v, a))
	_tongue = ImageTexture.create_from_image(img)
	return _tongue


# --- the ladder bridge --------------------------------------------------------

## Laid across from the apron to the barricade (the owner, 19 Oct: "ladder
## bridge"): a set piece a man is put through, and it folds under him -- the
## laid-out ladder swapped for the bent one (ladder_bent.glb), hanging in a V
## into the gap, where it stays. Folded, it is no longer a set piece.
const BENT_LADDER := "res://assets/weapons/ladder_bent.glb"
var bridge := false
var folded := false


## Across from `from` (the apron's edge) to `to` (the barricade's top), the
## rails level with the higher of the two.
func set_bridge(from: Vector3, to: Vector3) -> void:
	holder = null
	mode = Mode.SET_UP
	show_state("Ladder_Laid_Out")
	bridge = true
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z).normalized()
	var mid := (from + to) * 0.5
	# Ladder_Laid_Out lies along its Z, its rails 0.10 over its origin
	global_transform = Transform3D(Basis(Vector3.UP, atan2(along.x, along.z)),
			Vector3(mid.x, maxf(from.y, to.y) - 0.10, mid.z))
	_announce("set_up")


## Under him: the bent ladder in place of the bridge, from now on.
func fold_bridge() -> void:
	if folded:
		return
	folded = true
	for root: Node3D in _roots.values():
		root.visible = false
	var packed := load(BENT_LADDER) as PackedScene
	if packed:
		var bent := packed.instantiate() as Node3D
		bent.name = "Bent"
		add_child(bent)
		# the bent model's origin is the bridge's middle at its rails
		bent.position = Vector3(0.0, 0.10, 0.0)
	_announce("broke")


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
func shatter(seed: int, body: Node3D = null) -> void:
	_clear_of = body
	if not has_state(def.broken):
		mode = Mode.BROKEN
		_broken_for = PIECES_LINGER
		visible = false
		broke.emit(self)
		_announce("broke")
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
	# a piece's trim (the table top's edge band) goes with its piece
	var by_name := {}
	for node in parts:
		by_name[String(node.name)] = node
	for node in parts.duplicate():
		var base := String(node.name).trim_suffix("_trim")
		if base != String(node.name) and by_name.has(base):
			(node as Node3D).reparent(by_name[base])
			parts.erase(node)
	for node in parts:
		var n := node as Node3D
		if n == null:
			continue
		var out := (n.global_position - keep.origin)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized()
		var v: Vector3
		var spin: Vector3
		if n.global_position.y - keep.origin.y < LEGS_BELOW:
			# the legs' frame: knocked over where it stood, not thrown
			v = out * rng.randf_range(0.3, 0.8) + Vector3.UP * rng.randf_range(0.4, 0.8)
			var over := Vector3.UP.cross(out) * signf(rng.randf_range(-1, 1) + 0.001)
			spin = over * rng.randf_range(5.0, 8.0)
		else:
			v = out * rng.randf_range(0.8, 2.6) + Vector3.UP * rng.randf_range(0.6, 1.8)
			spin = Vector3(rng.randf_range(-9, 9), rng.randf_range(-6, 6), rng.randf_range(-9, 9))
		_pieces.append([n, v, spin, false])
	if ablaze:
		_burn_pieces()
	broke.emit(self)
	_announce("broke")


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
		var push := _clear_of_body(n, p)
		if push != Vector3.ZERO:
			p += push
			# what drove it into him is spent; it slides off him instead
			var into := -push.normalized()
			if v.dot(into) > 0.0:
				v -= into * v.dot(into)
		var ground := ground_under(p) + 0.01
		if p.y <= ground:
			p.y = ground
			if v.length() < 1.0:
				piece[3] = true
				_lie_on_flattest_side(n, ground)
				# turned flat it may have swung into him: off him again
				for i in 8:
					var off := _clear_of_body(n, n.global_position)
					if off.length() < 0.005:
						break
					n.global_position += off
			v = Vector3(v.x * 0.4, -v.y * 0.2, v.z * 0.4)
		else:
			var s: Vector3 = piece[2]
			if s.length() > 0.0:
				n.global_rotate(s.normalized(), s.length() * delta)
		if not piece[3]:
			n.global_position = p
		piece[1] = v


## A piece come to rest: turned by quarter turns to whichever way up puts its
## weight lowest -- a panel flat, the legs' frame on its side with its brace
## up, not propped on it -- with its underside on the floor, nearest the way
## it landed.
static func _lie_on_flattest_side(n: Node3D, ground: float) -> void:
	var mi := n as MeshInstance3D
	if mi == null or mi.mesh == null:
		return
	var verts := PackedVector3Array()
	for surface in mi.mesh.get_surface_count():
		var all: PackedVector3Array = mi.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var step := maxi(1, all.size() / 300)
		for i in range(0, all.size(), step):
			verts.append(all[i])
	if verts.is_empty():
		return
	var yaw := Basis(Vector3.UP, n.global_rotation.y)
	var landed := n.global_basis
	var best := Basis()
	var best_score := INF
	var best_low := 0.0
	for ix in 4:
		for iz in 4:
			var b := yaw * Basis(Vector3.RIGHT, ix * PI / 2.0) * Basis(Vector3.BACK, iz * PI / 2.0)
			var low := INF
			var sum := 0.0
			for v in verts:
				var y := (b * v).y
				low = minf(low, y)
				sum += y
			# its weight's height over the floor; within a centimetre, the
			# one nearest how it landed
			var score := sum / verts.size() - low
			score += 0.001 * (b.x.distance_to(landed.x) + b.y.distance_to(landed.y))
			if score < best_score:
				best_score = score
				best = b
				best_low = low
	var at := n.global_position
	n.global_transform = Transform3D(best, Vector3(at.x, ground - best_low, at.z))


## How far to move a piece at `p` (its origin) to clear the man it broke
## under: its footprint (the centre and the four corners of its box, flat)
## pushed out from each of his bones it is over.
func _clear_of_body(n: Node3D, p: Vector3) -> Vector3:
	if _clear_of == null or not is_instance_valid(_clear_of) or not _clear_of.has_method("_bone_world"):
		return Vector3.ZERO
	var samples: Array[Vector3] = [p]
	var mi := n as MeshInstance3D
	if mi and mi.mesh:
		var box := Transform3D(n.global_basis, p) * mi.mesh.get_aabb()
		var c := box.get_center()
		var lo := box.position.y
		samples = [Vector3(c.x, lo, c.z)]
		for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
			samples.append(Vector3(box.position.x + box.size.x * corner.x, lo,
					box.position.z + box.size.z * corner.y))
	var push := Vector3.ZERO
	for bone: String in BODY_BONES:
		var b: Vector3 = _clear_of._bone_world(bone)
		if b == Vector3.INF:
			continue
		for at in samples:
			if at.y > b.y + BODY_OVER:
				continue
			var d := Vector3(at.x - b.x, 0.0, at.z - b.z) + push
			var gap := d.length()
			if gap >= BODY_CLEAR:
				continue
			# out the way the piece as a whole lies from him, so the corners
			# do not push it two ways at once
			var whole := Vector3(samples[0].x - b.x, 0.0, samples[0].z - b.z)
			var out := whole.normalized() if whole.length() > 0.001 else (d / gap if gap > 0.001 else Vector3(1, 0, 0))
			push += out * (BODY_CLEAR - gap)
	return push
