class_name AmbulanceProp
extends Node3D
## The Ambulance match's ambulance (gauntlet/refs/ambulance_match.md), with
## source-authored visual geometry: an original unbranded box-body ambulance
## -- white, a red band
## and chevrons, a light bar, its two rear doors swung wide -- backed down the
## entrance ramp after the entrances, its rear toward the ring. Shut a man in
## the back to win.
##
## The ShutIn container contract: mouth(), bed(), lip(), set_shut(t),
## method().

const GROUP := &"ambulance"
## The rear bumper this far up the ramp from its foot (ArenaBuilder.RAMP_FOOT_Z).
const REAR_Z := -7.4
const LENGTH := 5.9
const WIDTH := 2.2
const BOX_H := 2.25
const CAB_LEN := 1.6
const FLOOR_UP := 0.85
const WHEEL_R := 0.42
const DOOR_OPEN := deg_to_rad(100.0)

var _doors: Array[Node3D] = []
var _shut := 0.0
var _ground := 0.0
var _tilt := 0.0


static func build(parent: Node) -> AmbulanceProp:
	var a := AmbulanceProp.new()
	a.name = "Ambulance"
	parent.add_child(a)
	return a


static func of(node: Node) -> AmbulanceProp:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as AmbulanceProp


func _ready() -> void:
	add_to_group(GROUP)
	# Standing on the ramp's slope: the rear wheels low, the front high.
	var rear_y := ArenaBuilder.match_surface_y(Vector3(0.0, 0.0, REAR_Z + 0.9))
	var front_y := ArenaBuilder.match_surface_y(Vector3(0.0, 0.0, REAR_Z - LENGTH + 1.0))
	_ground = rear_y
	_tilt = atan2(front_y - rear_y, LENGTH - 1.9)
	position = Vector3(0.0, rear_y, REAR_Z)
	rotation.x = _tilt
	var art: Node3D = preload("res://assets/props/ambulance.glb").instantiate()
	add_child(art)
	art.get_node("Body").reparent(self, false)
	for side in [-1.0, 1.0]:
		var suffix := "R" if side > 0 else "L"
		var pivot := Node3D.new()
		pivot.name = "Door" + suffix
		pivot.position = Vector3(side * WIDTH * 0.5, FLOOR_UP, 0.0)
		add_child(pivot)
		art.get_node("Door" + suffix + "Visual").reparent(pivot, false)
		_doors.append(pivot)
	art.free()
	_build_collision(LENGTH - CAB_LEN)
	set_shut(0.0)


## The body's sides, front and roof are solid; the rear is open for the man
## thrown in (his path in is scripted, ShutIn).
func _build_collision(box_len: float) -> void:
	var body := StaticBody3D.new()
	body.name = "AmbulanceCollision"
	add_child(body)
	for spec: Array in [
			[Vector3(WIDTH, FLOOR_UP + 0.04, LENGTH), Vector3(0, (FLOOR_UP + 0.04) * 0.5, -LENGTH * 0.5)],
			[Vector3(0.1, BOX_H, box_len), Vector3(WIDTH * 0.5, FLOOR_UP + BOX_H * 0.5, -box_len * 0.5)],
			[Vector3(0.1, BOX_H, box_len), Vector3(-WIDTH * 0.5, FLOOR_UP + BOX_H * 0.5, -box_len * 0.5)],
			[Vector3(WIDTH, 1.6, CAB_LEN), Vector3(0, FLOOR_UP + 0.55, -box_len - CAB_LEN * 0.5)]]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = spec[0]
		shape.shape = box
		shape.position = spec[1]
		body.add_child(shape)


## 0 open, 1 shut.
func set_shut(t: float) -> void:
	_shut = clampf(t, 0.0, 1.0)
	for i in _doors.size():
		var side := 1.0 if _doors[i].name == "DoorR" else -1.0
		# Swung out round its hinge toward the ring (+Z), then shut flush.
		_doors[i].rotation.y = side * (1.0 - _shut) * DOOR_OPEN


func shut_amount() -> float:
	return _shut


## Where a man is thrown in from: on the ramp behind the open doors.
func mouth() -> Vector3:
	var p := global_transform * Vector3(0.0, 0.0, 0.9)
	p.y = ArenaBuilder.match_surface_y(p)
	return p


## Lying on the compartment floor, head toward the cab (-Z).
func bed() -> Transform3D:
	var p := global_transform * Vector3(-0.3, FLOOR_UP + 0.06, -1.55)
	return Transform3D(Basis.IDENTITY, p)


## Over the rear sill.
func lip() -> Vector3:
	return global_transform * Vector3(0.0, FLOOR_UP + 0.25, -0.1)


func method() -> String:
	return "ambulance"
