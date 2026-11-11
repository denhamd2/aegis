class_name AmbulanceProp
extends Node3D
## The Ambulance match's ambulance (gauntlet/refs/ambulance_match.md), built
## in code: an original, unbranded box-body ambulance -- white, a red band
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
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.93, 0.93, 0.91)
	white.roughness = 0.3
	white.metallic_specular = 0.7
	white.clearcoat_enabled = true
	white.clearcoat = 0.6
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.78, 0.06, 0.07)
	red.roughness = 0.35
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.05, 0.07, 0.09)
	glass.roughness = 0.05
	glass.metallic = 0.4
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color(0.03, 0.03, 0.03)
	tyre.roughness = 0.85
	var chrome := StandardMaterial3D.new()
	chrome.albedo_color = Color(0.8, 0.8, 0.82)
	chrome.metallic = 1.0
	chrome.roughness = 0.2
	var inside := StandardMaterial3D.new()
	inside.albedo_color = Color(0.55, 0.58, 0.6)
	inside.roughness = 0.6
	var lamp_red := StandardMaterial3D.new()
	lamp_red.albedo_color = Color(1.0, 0.1, 0.1)
	lamp_red.emission_enabled = true
	lamp_red.emission = Color(1.0, 0.05, 0.05)
	lamp_red.emission_energy_multiplier = 2.5
	var lamp_blue := lamp_red.duplicate() as StandardMaterial3D
	lamp_blue.albedo_color = Color(0.2, 0.3, 1.0)
	lamp_blue.emission = Color(0.1, 0.2, 1.0)
	var box_len := LENGTH - CAB_LEN
	var floor_y := FLOOR_UP
	var cz := -box_len * 0.5          # the box's centre, from the rear (z = 0) forward (-Z)
	var wall := 0.06
	# The patient compartment: floor, roof, sides and front bulkhead; open at
	# the rear, where the doors are.
	_box(Vector3(0, floor_y, cz), Vector3(WIDTH, 0.08, box_len), inside)
	_box(Vector3(0, floor_y + BOX_H, cz), Vector3(WIDTH, 0.08, box_len), white)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (WIDTH * 0.5 - wall * 0.5), floor_y + BOX_H * 0.5, cz),
				Vector3(wall, BOX_H, box_len), white)
		# The red band and the lower skirt down each side.
		_box(Vector3(side * (WIDTH * 0.5 + 0.005), floor_y + BOX_H * 0.42, cz),
				Vector3(0.01, 0.28, box_len - 0.1), red)
		_box(Vector3(side * (WIDTH * 0.5 - wall * 0.5), floor_y - 0.25, cz),
				Vector3(wall, 0.5, box_len), white)
	_box(Vector3(0, floor_y + BOX_H * 0.5, -box_len + wall * 0.5), Vector3(WIDTH, BOX_H, wall), white)
	# Inside: a stretcher along the left wall, a bench along the right.
	_box(Vector3(-0.42, floor_y + 0.45, cz - 0.3), Vector3(0.6, 0.08, 2.0), chrome)
	_box(Vector3(0.75, floor_y + 0.3, cz - 0.4), Vector3(0.5, 0.45, 2.2), inside)
	# The cab ahead of it: lower, with a windscreen.
	var cab_z := -box_len - CAB_LEN * 0.5
	_box(Vector3(0, floor_y + 0.55, cab_z), Vector3(WIDTH - 0.05, 1.5, CAB_LEN), white)
	_box(Vector3(0, floor_y + 1.05, -box_len - CAB_LEN + 0.02), Vector3(WIDTH - 0.25, 0.6, 0.04), glass)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (WIDTH * 0.5 - 0.01), floor_y + 0.95, cab_z), Vector3(0.04, 0.5, 0.9), glass)
	_box(Vector3(0, floor_y - 0.3, -LENGTH + 0.05), Vector3(WIDTH, 0.25, 0.12), chrome)
	# The light bar over the cab and lamps at the box's corners.
	_box(Vector3(-0.4, floor_y + 1.4, cab_z), Vector3(0.7, 0.12, 0.25), lamp_red)
	_box(Vector3(0.4, floor_y + 1.4, cab_z), Vector3(0.7, 0.12, 0.25), lamp_blue)
	for side in [-1.0, 1.0]:
		_box(Vector3(side * (WIDTH * 0.5 - 0.12), floor_y + BOX_H + 0.08, -0.08),
				Vector3(0.16, 0.1, 0.1), lamp_red)
	# The rear step and bumper.
	_box(Vector3(0, floor_y - 0.2, 0.18), Vector3(WIDTH - 0.3, 0.06, 0.32), chrome)
	# Wheels.
	for z in [-0.9, -LENGTH + 1.0]:
		for side in [-1.0, 1.0]:
			var w := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = WHEEL_R
			cyl.bottom_radius = WHEEL_R
			cyl.height = 0.28
			w.mesh = cyl
			w.material_override = tyre
			w.rotation.z = PI * 0.5
			w.position = Vector3(side * (WIDTH * 0.5 - 0.12), WHEEL_R, z)
			add_child(w)
	# The rear doors, each hinged at its outer edge, swung wide.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.name = "Door%s" % ("R" if side > 0 else "L")
		pivot.position = Vector3(side * WIDTH * 0.5, floor_y, 0.0)
		add_child(pivot)
		var leaf_w := WIDTH * 0.5 - 0.02
		_box(Vector3(-side * leaf_w * 0.5, BOX_H * 0.5, 0.0), Vector3(leaf_w, BOX_H - 0.06, 0.05),
				white, pivot)
		_box(Vector3(-side * leaf_w * 0.5, BOX_H * 0.72, 0.03), Vector3(leaf_w * 0.6, 0.45, 0.01),
				glass, pivot)
		_box(Vector3(-side * leaf_w * 0.5, BOX_H * 0.42, 0.03), Vector3(leaf_w, 0.28, 0.01), red, pivot)
		_doors.append(pivot)
	_build_collision(box_len)
	set_shut(0.0)


func _box(at: Vector3, size: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	(parent if parent else self).add_child(mi)
	return mi


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
