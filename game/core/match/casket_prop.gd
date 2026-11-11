class_name CasketProp
extends Node3D
## The Casket match's casket (gauntlet/refs/casket_match.md), built in code: an
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
	var lacquer := StandardMaterial3D.new()
	lacquer.albedo_color = Color(0.025, 0.022, 0.024)
	lacquer.roughness = 0.14
	lacquer.metallic_specular = 0.8
	lacquer.clearcoat_enabled = true
	lacquer.clearcoat = 1.0
	lacquer.clearcoat_roughness = 0.08
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.83, 0.64, 0.30)
	brass.metallic = 0.95
	brass.roughness = 0.28
	var satin := StandardMaterial3D.new()
	satin.albedo_color = Color(0.86, 0.81, 0.72)
	satin.roughness = 0.55
	satin.rim_enabled = true
	satin.rim = 0.4
	var drape := StandardMaterial3D.new()
	drape.albedo_color = Color(0.20, 0.03, 0.05)
	drape.roughness = 0.8
	# The bier, draped.
	_box(Vector3(0, BIER_H * 0.5, 0), Vector3(WIDTH + 0.12, BIER_H, LENGTH + 0.1), drape)
	var base := BIER_H
	# The body: floor and four walls, open at the top.
	_box(Vector3(0, base + WALL * 0.5, 0), Vector3(WIDTH, WALL, LENGTH), lacquer)
	_box(Vector3(WIDTH * 0.5 - WALL * 0.5, base + BODY_H * 0.5, 0), Vector3(WALL, BODY_H, LENGTH), lacquer)
	_box(Vector3(-WIDTH * 0.5 + WALL * 0.5, base + BODY_H * 0.5, 0), Vector3(WALL, BODY_H, LENGTH), lacquer)
	_box(Vector3(0, base + BODY_H * 0.5, LENGTH * 0.5 - WALL * 0.5), Vector3(WIDTH, BODY_H, WALL), lacquer)
	_box(Vector3(0, base + BODY_H * 0.5, -LENGTH * 0.5 + WALL * 0.5), Vector3(WIDTH, BODY_H, WALL), lacquer)
	# A moulded rim and a plinth band.
	_box(Vector3(0, base + BODY_H - 0.015, LENGTH * 0.5 - 0.02), Vector3(WIDTH + 0.03, 0.03, 0.04), lacquer)
	_box(Vector3(0, base + BODY_H - 0.015, -LENGTH * 0.5 + 0.02), Vector3(WIDTH + 0.03, 0.03, 0.04), lacquer)
	_box(Vector3(0, base + 0.03, 0), Vector3(WIDTH + 0.04, 0.06, LENGTH + 0.04), lacquer)
	# The lining: a padded bed and a pillow at the head (+Z).
	_box(Vector3(0, base + 0.11, 0), Vector3(WIDTH - WALL * 2.0, 0.12, LENGTH - WALL * 2.0), satin)
	_box(Vector3(0, base + 0.20, LENGTH * 0.5 - 0.22), Vector3(WIDTH * 0.6, 0.08, 0.28), satin)
	# Brass swing bars down both long sides, on three posts each.
	for side in [-1.0, 1.0]:
		var x: float = side * (WIDTH * 0.5 + 0.05)
		_box(Vector3(x, base + BODY_H * 0.45, 0), Vector3(0.025, 0.025, LENGTH * 0.82), brass)
		for z in [-0.75, 0.0, 0.75]:
			_box(Vector3(side * (WIDTH * 0.5 + 0.025), base + BODY_H * 0.45, z),
					Vector3(0.05, 0.03, 0.03), brass)
	# The lid, hinged on the far (-X) long edge.
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "LidPivot"
	_lid_pivot.position = Vector3(-WIDTH * 0.5, base + BODY_H, 0)
	add_child(_lid_pivot)
	_box(Vector3(WIDTH * 0.5, 0.04, 0), Vector3(WIDTH + 0.03, 0.08, LENGTH + 0.03), lacquer, _lid_pivot)
	_box(Vector3(WIDTH * 0.5, 0.10, 0), Vector3(WIDTH * 0.8, 0.05, LENGTH * 0.9), lacquer, _lid_pivot)
	_box(Vector3(WIDTH * 0.5, -0.005, 0), Vector3(WIDTH - 0.08, 0.01, LENGTH - 0.08), satin, _lid_pivot)
	_build_collision(base)
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
