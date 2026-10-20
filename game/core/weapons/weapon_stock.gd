class_name WeaponStock
extends Node3D
## Every weapon in a No Holds Barred match: what is under the ring and what
## is out -- held, thrown, lying on the floor, set up, broken. One per match,
## a child of the match scene, made the first time anyone reaches for one.
##
## Under the ring is the whole catalogue, at every apron side, and as many
## of each as anyone wants: a second chair can come out while the first is
## still lying in the ring (the owner, 19 Oct).

## A weapon on the floor this close to his feet can be picked up.
const PICKUP_REACH := 0.95
## Laid out on the entrance deck from the opening bell: the most dangerous
## things in the building, several of each -- the guns, the launchers, the
## knives and the swords (the owner, 19 Oct) -- with the wire and the hammer
## that were here first. Either side of the walkway, on the deck's full
## width behind its flare (ArenaBuilder.stage_half_width).
const STAGE_LAYOUT := [
	[&"handgun", Vector3(-3.0, 0.0, -35.6)], [&"knife", Vector3(-4.6, 0.0, -35.6)],
	[&"sword", Vector3(-6.2, 0.0, -35.6)], [&"rpg", Vector3(-3.2, 0.0, -33.9)],
	[&"knife", Vector3(-4.8, 0.0, -33.9)], [&"barbed_wire_chair", Vector3(-6.4, 0.0, -33.9)],
	[&"sledgehammer", Vector3(-2.6, 0.0, -32.2)], [&"knife", Vector3(-3.9, 0.0, -32.2)],
	[&"rpg", Vector3(3.0, 0.0, -35.6)], [&"sword", Vector3(4.6, 0.0, -35.6)],
	[&"handgun", Vector3(6.2, 0.0, -35.6)], [&"knife", Vector3(3.2, 0.0, -33.9)],
	[&"sword", Vector3(4.8, 0.0, -33.9)], [&"light_tubes", Vector3(6.4, 0.0, -33.9)],
	[&"barbed_wire_bat", Vector3(2.6, 0.0, -32.2)], [&"handgun", Vector3(3.9, 0.0, -32.2)],
]
const STAGE_WEAPON_LIFETIME_TICKS := 60 * 180

var actors: Array[WeaponActor] = []
var stage_actors: Array[WeaponActor] = []


static func of(node: Node) -> WeaponStock:
	var host := node.get_parent() if node.get_parent() else node
	var existing := host.get_node_or_null("WeaponStock")
	if existing:
		return existing as WeaponStock
	var s := WeaponStock.new()
	s.name = "WeaponStock"
	host.add_child(s)
	return s


## Whether `id` is under the ring: anything in the catalogue, at any point
## in the match -- the gun and the launcher included (the owner, 19 Oct).
func in_stock(id: StringName) -> bool:
	return WeaponCatalog.by_id(id) != null


## Takes `def` out from under the ring: a new actor in the scene.
func pull(def: WeaponDef) -> WeaponActor:
	var a := WeaponActor.make(def)
	add_child(a)
	actors.append(a)
	return a


## Seed the deck once at bell time. Stage weapons are ordinary loose actors:
## either wrestler can take them and their normal wear/lifetime still applies.
func seed_stage_weapons() -> void:
	if not MatchRules.no_holds_barred(self) or not stage_actors.is_empty():
		return
	for i in STAGE_LAYOUT.size():
		var id: StringName = STAGE_LAYOUT[i][0]
		var actor := pull(WeaponCatalog.by_id(id))
		actor.name = "StageWeapon%02d_%s" % [i, id]
		actor.mode = WeaponActor.Mode.FLOOR
		actor.match_lifetime_limit = STAGE_WEAPON_LIFETIME_TICKS
		actor.global_position = STAGE_LAYOUT[i][1]
		actor.rotation.y = float(i % 3) * 0.61 - 0.4
		# laid down on its side, as a thrown one comes to rest: a sword
		# stood on its point is not laid out
		actor._rest_on_floor(WeaponActor.ground_under(actor.global_position))
		stage_actors.append(actor)


## The nearest stage prop still lying loose, for an AI making a weapon run.
func nearest_stage_weapon(at: Vector3) -> WeaponActor:
	var best: WeaponActor = null
	var best_d := INF
	for actor in stage_actors:
		if not is_instance_valid(actor) or actor.mode != WeaponActor.Mode.FLOOR:
			continue
		var d := Vector2(actor.global_position.x - at.x,
				actor.global_position.z - at.z).length()
		if d < best_d:
			best = actor
			best_d = d
	return best


## The nearest weapon lying loose on one side of the ropes (`inside` the
## ring or out of it) within `reach` of `at`, or null: one slid in, dropped,
## or knocked out of a man's hands, for an AI to go and pick up.
func nearest_loose(at: Vector3, inside: bool, reach: float) -> WeaponActor:
	var best: WeaponActor = null
	var best_d := reach
	for a in actors:
		if not is_instance_valid(a) or a.mode != WeaponActor.Mode.FLOOR:
			continue
		var p := a.global_position
		var in_ring := absf(p.x) < RingBuilder.MAT_HALF and absf(p.z) < RingBuilder.MAT_HALF
		if in_ring != inside:
			continue
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best = a
			best_d = d
	return best


## The nearest weapon lying loose within reach of `at`, or null.
func loose_near(at: Vector3) -> WeaponActor:
	var best: WeaponActor = null
	var best_d := PICKUP_REACH
	for a in actors:
		if not is_instance_valid(a) or a.mode != WeaponActor.Mode.FLOOR:
			continue
		var d := Vector2(a.global_position.x - at.x, a.global_position.z - at.z).length()
		if d < best_d:
			best = a
			best_d = d
	return best


## Every tick, with a set piece standing: anyone coming down on it lands on it.
func _physics_process(delta: float) -> void:
	if set_up_pieces().is_empty() or get_parent() == null:
		return
	for n in get_parent().get_children():
		if n is WrestlerController:
			(n as WrestlerController).tick_fall_onto_set_piece(delta)


## A man landing on a set piece: this far outside its footprint still
## counts, and up to this far above its top (his pelvis on a table is well
## above the boards before they give).
const LAND_PAD := 0.25
const LAND_ABOVE := 0.6
const CHAIRS: Array[StringName] = [&"steel_chair", &"barbed_wire_chair"]


## The set piece (a table, the tacks, the bed of nails, the wire board)
## stood up under `p`, or null.
func set_piece_under(p: Vector3) -> WeaponActor:
	for a in set_up_pieces():
		if a.def.set_piece and _over(a, p):
			return a
	return null


## A chair lying loose under `p`, or null.
func chair_under(p: Vector3) -> WeaponActor:
	for a in actors:
		if is_instance_valid(a) and a.mode == WeaponActor.Mode.FLOOR and a.def.id in CHAIRS and _over(a, p):
			return a
	return null


static func _over(a: WeaponActor, p: Vector3) -> bool:
	# in the world's frame: a chair on the floor lies on its side
	var box := (a.global_transform * a.local_bounds()).grow(LAND_PAD)
	return p.x >= box.position.x and p.x <= box.end.x and p.z >= box.position.z \
			and p.z <= box.end.z and p.y <= box.end.y + LAND_ABOVE


## Set pieces stood up somewhere: [actor, ...].
func set_up_pieces() -> Array[WeaponActor]:
	var out: Array[WeaponActor] = []
	for a in actors:
		if is_instance_valid(a) and a.mode == WeaponActor.Mode.SET_UP and not a.folded:
			out.append(a)
	return out
