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
	return Engine.get_physics_frames() >= int(_out_until.get(id, 0))


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


## Set pieces stood up somewhere: [actor, ...].
func set_up_pieces() -> Array[WeaponActor]:
	var out: Array[WeaponActor] = []
	for a in actors:
		if is_instance_valid(a) and a.mode == WeaponActor.Mode.SET_UP:
			out.append(a)
	return out
