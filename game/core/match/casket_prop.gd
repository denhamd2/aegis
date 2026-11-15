class_name CasketProp
extends Node3D
## The Casket match's casket (gauntlet/refs/casket_match.md), with
## source-authored visual geometry: an
## original design, no downloaded geometry. A black lacquered rectangular
## casket with brass swing-bar handles down each side and a cream satin
## lining, on a low draped bier at ringside on the hard-camera side, its lid
## hinged along the far long edge and stood open toward the barricade.
##
## The ShutIn container contract: mouth() where a man is thrown in from,
## bed() where he lies, set_shut(t), and the opening's facing.

const GROUP := &"casket"
## Where it stands: ringside floor, hard-camera side (-X), long axis along Z,
## clear of the apron and the barricade (6.0).
const AT := Vector3(-4.75, 0.0, 1.9)
const LENGTH := 2.15
const WIDTH := 0.78
const BODY_H := 0.50
const BIER_H := 0.32
const WALL := 0.05
## The lid stands open this far (radians) about its hinge.
const LID_OPEN := deg_to_rad(105.0)

var _lid_pivot: Node3D
var _shut := 0.0


static func build(parent: Node) -> CasketProp:
	var c := CasketProp.new()
	c.name = "Casket"
	parent.add_child(c)
	return c


static func of(node: Node) -> CasketProp:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as CasketProp


func _ready() -> void:
	add_to_group(GROUP)
	position = Vector3(AT.x, ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT, AT.z)
	var art: Node3D = preload("res://assets/props/casket.glb").instantiate()
	add_child(art)
	art.get_node("Body").reparent(self, false)
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "LidPivot"
	_lid_pivot.position = Vector3(-WIDTH * 0.5, BIER_H + BODY_H, 0)
	add_child(_lid_pivot)
	art.get_node("LidVisual").reparent(_lid_pivot, false)
	art.free()
	_build_collision(BIER_H)
	set_shut(0.0)


func _build_collision(base: float) -> void:
	var body := StaticBody3D.new()
	body.name = "CasketCollision"
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH + 0.12, base + BODY_H, LENGTH + 0.1)
	shape.shape = box
	shape.position = Vector3(0, (base + BODY_H) * 0.5, 0)
	body.add_child(shape)


## 0 open, 1 shut.
func set_shut(t: float) -> void:
	_shut = clampf(t, 0.0, 1.0)
	if _lid_pivot:
		# Rotating about +Z lifts the lid's free (+X) edge up and over.
		_lid_pivot.rotation.z = (1.0 - _shut) * LID_OPEN


func shut_amount() -> float:
	return _shut


## Where a man is thrown in from: on the floor beside its ring-side (+X) wall.
func mouth() -> Vector3:
	return global_position + Vector3(WIDTH * 0.5 + 0.55, 0.0, 0.0)


## Where his root goes, lying in it on his back: upright (the down clip lays
## the body out along the root's -Z, his head that way), turned so his head
## is at the pillow (+Z), at the lining's height.
func bed() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), global_position + Vector3(0.0, BIER_H + 0.12, -0.05))


## Where the man thrown in goes over the side: the top of its ring-side wall.
func lip() -> Vector3:
	return global_position + Vector3(WIDTH * 0.5, BIER_H + BODY_H + 0.15, 0.0)


func method() -> String:
	return "casket"
