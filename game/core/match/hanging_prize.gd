class_name HangingPrize
extends Node3D
## The Ladder match's prize (gauntlet/refs/ladder_match.md): the title belt
## hung over the middle of the ring on a cable from the lighting rig, high
## enough that only a man stood on top of a ladder reaches it. He unhooks it
## over UNHOOK_TICKS of tugging (WrestlerController._tick_unhook); knocked
## off before then and the clip springs back. Pulled down, it wins
## (`taken`, MatchReferee.declare_prize).
##
## Built in code: a steel cable and a snap hook, and the owner's title
## (assets/props/aew_title.glb, an exception recorded in its CREDITS) on it.

signal taken(winner: WrestlerController)

const GROUP := &"hanging_prize"
## Where the belt's hook hangs: over the ring's centre, the height a man on
## the ladder's top rung reaches with his arms up. ladder.glb's top is
## 3.01 m; he stands LADDER_TOP_FOOT_GAP under it, and his hands reach about
## 2 m above his boots.
const AT := Vector3(0.0, 4.72, 0.0)
## Tugging this long at it unhooks it (2.5 s).
const UNHOOK_TICKS := 150
## Within this of being under it, on the ladder's top, he can reach it.
const REACH_XZ := 0.5
const CABLE_TOP := 11.0
const CABLE_RADIUS := 0.006

var unhook := 0
var won_by: WrestlerController
var _belt: Node3D
var _cable: MeshInstance3D
var _sway := 0.0
var _tug := 0.0


static func build(parent: Node) -> HangingPrize:
	var p := HangingPrize.new()
	p.name = "HangingPrize"
	parent.add_child(p)
	return p


static func of(node: Node) -> HangingPrize:
	if node == null or not node.is_inside_tree():
		return null
	return node.get_tree().get_first_node_in_group(GROUP) as HangingPrize


func _ready() -> void:
	add_to_group(GROUP)
	position = Vector3.ZERO
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.32, 0.33, 0.35)
	steel.metallic = 0.9
	steel.roughness = 0.35
	_cable = MeshInstance3D.new()
	_cable.name = "Cable"
	var cyl := CylinderMesh.new()
	cyl.top_radius = CABLE_RADIUS
	cyl.bottom_radius = CABLE_RADIUS
	cyl.height = CABLE_TOP - AT.y
	cyl.radial_segments = 6
	_cable.mesh = cyl
	_cable.material_override = steel
	_cable.position = Vector3(AT.x, (CABLE_TOP + AT.y) * 0.5, AT.z)
	add_child(_cable)
	var hook := MeshInstance3D.new()
	hook.name = "Hook"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.025
	torus.outer_radius = 0.04
	hook.mesh = torus
	hook.material_override = steel
	hook.position = AT
	hook.rotation_degrees = Vector3(0, 0, 90)
	add_child(hook)
	_belt = _load_belt()
	if _belt:
		add_child(_belt)
		_place_belt(0.0)


func _load_belt() -> Node3D:
	var packed := load(EntranceProps.TITLE) as PackedScene
	if packed == null:
		return null
	var model: Node3D = packed.instantiate()
	var mats := EntranceProps._materials()
	for node in model.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := String(mi.name)
		if mats.has(key):
			mi.material_override = mats[key]
		# The belt as it is held up: the plate and the strap, not the worn
		# loop round a waist.
		mi.visible = key.begins_with("Held")
	var pivot := Node3D.new()
	pivot.name = "Belt"
	pivot.add_child(model)
	return pivot


## Hung from the hook by its strap, the plate facing the hard camera (-X)
## and turning slowly on the cable; tugged, it jerks.
func _place_belt(t: float) -> void:
	if _belt == null or won_by:
		return
	_belt.position = AT + Vector3(0.0, -0.06 - 0.03 * _tug, 0.0)
	_belt.rotation = Vector3(0.0, sin(t * 0.4) * 0.35 + PI * 0.5, sin(t * 1.3) * 0.04 * (1.0 + _tug))


func _physics_process(delta: float) -> void:
	_sway += delta
	_tug = move_toward(_tug, 0.0, delta * 4.0)
	_place_belt(_sway)


## Where his hands go to hold it: either side of the hook.
func grip(side: float) -> Vector3:
	return AT + Vector3(0.0, -0.10, 0.0) + Vector3(0.0, 0.0, 0.07 * side)


## Whether a man at `p` (his root, on the ladder) is under it.
func reachable_from(p: Vector3) -> bool:
	return Vector2(p.x - AT.x, p.z - AT.z).length() <= REACH_XZ


## One tick of tugging by `w`; returns whether it came down.
func tug(w: WrestlerController) -> bool:
	if won_by:
		return true
	unhook += 1
	_tug = 1.0
	if unhook >= UNHOOK_TICKS:
		won_by = w
		_drop_to(w)
		taken.emit(w)
		return true
	return false


## Knocked off before he had it: it springs back.
func let_go() -> void:
	if not won_by:
		unhook = 0


func unhook_share() -> float:
	return clampf(float(unhook) / UNHOOK_TICKS, 0.0, 1.0)


func _drop_to(w: WrestlerController) -> void:
	if _cable:
		_cable.scale = Vector3(1, 1, 1)
	if _belt:
		# In his hands, held up: it goes with him from here.
		var hold := Node3D.new()
		hold.name = "PrizeHeld"
		w.add_child(hold)
		hold.position = Vector3(0.0, 2.05, -0.15)
		_belt.reparent(hold, false)
		_belt.position = Vector3.ZERO
		_belt.rotation = Vector3(0.0, PI, 0.0)
