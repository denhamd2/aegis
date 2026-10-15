class_name WeaponStock
extends Node3D
## Every weapon in a No Holds Barred match: what is under the ring and what
## is out -- held, thrown, lying on the floor, set up, broken. One per match,
## a child of the match scene, made the first time anyone reaches for one.
##
## Under the ring is the whole catalogue, at every apron side. A weapon
## pulled out is out of the stock for RESTOCK_TICKS, so the same one is not
## pulled out ten times running.

const RESTOCK_TICKS := 60 * 45
## A weapon on the floor this close to his feet can be picked up.
const PICKUP_REACH := 0.95
## The gun and launcher are late-match escalation weapons, not opening picks.
const LATE_MATCH_ONLY: Array[StringName] = [&"handgun", &"rpg"]
const LATE_MATCH_UNLOCK_SECONDS := 300.0

var _out_until := {}           # id -> physics frame it is back under the ring
var actors: Array[WeaponActor] = []


static func of(node: Node) -> WeaponStock:
	var host := node.get_parent() if node.get_parent() else node
	var existing := host.get_node_or_null("WeaponStock")
	if existing:
		return existing as WeaponStock
	var s := WeaponStock.new()
	s.name = "WeaponStock"
	host.add_child(s)
	return s


## Whether `id` is under the ring now.
func in_stock(id: StringName) -> bool:
	return is_selectable(id) and Engine.get_physics_frames() >= int(_out_until.get(id, 0))


## Whether the match allows this weapon to be selected from under the ring.
## Matches without a MatchFlow (isolated tests and tools) keep the full stock.
func is_selectable(id: StringName) -> bool:
	if id not in LATE_MATCH_ONLY:
		return true
	var flow := get_parent().get_node_or_null("MatchFlow") as MatchFlow
	return flow == null or flow.seconds() >= LATE_MATCH_UNLOCK_SECONDS


## Takes `def` out from under the ring: a new actor in the scene.
func pull(def: WeaponDef) -> WeaponActor:
	_out_until[def.id] = Engine.get_physics_frames() + RESTOCK_TICKS
	var a := WeaponActor.make(def)
	add_child(a)
	actors.append(a)
	return a


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
		if is_instance_valid(a) and a.mode == WeaponActor.Mode.SET_UP:
			out.append(a)
	return out
