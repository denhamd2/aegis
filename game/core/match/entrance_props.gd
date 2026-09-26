class_name EntranceProps
extends Node3D
## Roman's entrance props on his body: the ula fala at his neck and the AEW
## title, either draped over his left shoulder or held in his left hand
## (tools/blender/roman_props.py; gauntlet/refs/entrances.md).
##
## Each prop FOLLOWS a bone rather than being parented to it. The bone gives
## the position; the wrestler's own upright frame gives the orientation. A
## belt parented to hand_l would turn with every twist of the wrist as the arm
## goes up, and the plates would end the raise facing the rafters; held this
## way the plates face the camera the whole way, which is how a man shows a
## title off.
##
## Scaled per model by shoulder span against the base rig's 0.384 m (measured
## in Blender off wrestler_base.glb), so one set of props fits the mannequin
## and Roman's much bigger frame.
##
## Presentation only: nothing here has collision or touches match state, and
## EntranceDirector frees it at the bell.

const ULA_FALA := "res://assets/props/ula_fala.glb"
const TITLE := "res://assets/props/aew_title.glb"
const BASE_SHOULDER_SPAN := 0.384

## Part name -> material. Gold is a metal lit by the follow spot and the
## stage washes; the hall's ambient carries no reflections (material_library's
## note on arena_truss), so a pure conductor renders near-black between the
## lights. A little emission keeps it reading as gold in the dark.
static func _materials() -> Dictionary:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.36)
	gold.metallic = 0.85
	gold.roughness = 0.28
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.72, 0.30)
	gold.emission_energy_multiplier = 0.12
	var strap := StandardMaterial3D.new()
	strap.albedo_color = Color(0.03, 0.03, 0.03)
	strap.roughness = 0.55
	var gem := StandardMaterial3D.new()
	gem.albedo_color = Color(0.92, 0.94, 1.0)
	gem.roughness = 0.08
	gem.metallic_specular = 1.0
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.62, 0.06, 0.04)
	red.roughness = 0.62
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.88, 0.32, 0.07)
	orange.roughness = 0.62
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.10, 0.07, 0.05)
	cord.roughness = 0.9
	return {
		"TitleGold": gold, "HeldGold": gold, "TitleStrap": strap,
		"HeldStrap": strap, "TitleGem": gem, "HeldGem": gem,
		"FalaRed": red, "FalaOrange": orange, "FalaCord": cord,
	}

var _w: WrestlerController
var _scale := 1.0
var _fala: Node3D
var _title: Node3D
## Where the title is: "draped", "held", or "" (put down).
var _title_state := "draped"


static func dress(wrestler: WrestlerController) -> EntranceProps:
	var props := EntranceProps.new()
	props.name = "EntranceProps"
	props._w = wrestler
	props.top_level = true
	wrestler.add_child(props)
	return props


func _ready() -> void:
	var mats := _materials()
	_fala = _load(ULA_FALA, mats)
	_title = _load(TITLE, mats)
	var l := _bone("upperarm_l")
	var r := _bone("upperarm_r")
	if l != Vector3.INF and r != Vector3.INF:
		_scale = clampf(l.distance_to(r) / BASE_SHOULDER_SPAN, 0.7, 1.8)
	set_title("draped")
	_follow()


func _load(path: String, mats: Dictionary) -> Node3D:
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("EntranceProps: %s failed to load" % path)
		return Node3D.new()
	var root: Node3D = packed.instantiate()
	add_child(root)
	for node in root.find_children("", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var key := String(mi.name)
		if mats.has(key):
			mi.material_override = mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func set_title(state: String) -> void:
	_title_state = state
	if _title == null:
		return
	for node in _title.find_children("", "MeshInstance3D", true, false):
		var n := String(node.name)
		(node as Node3D).visible = (state == "draped" and n.begins_with("Title")) \
				or (state == "held" and n.begins_with("Held"))


func set_fala_visible(on: bool) -> void:
	if _fala:
		_fala.visible = on


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if _w == null:
		return
	var frame := Basis(Vector3.UP, _w.global_rotation.y).scaled(Vector3.ONE * _scale)
	var neck := _bone("neck_01")
	if _fala and neck != Vector3.INF:
		_fala.global_transform = Transform3D(frame, neck)
	var anchor := _bone("hand_l") if _title_state == "held" else _bone("upperarm_l")
	if _title and anchor != Vector3.INF:
		_title.global_transform = Transform3D(frame, anchor)


func _bone(canonical: String) -> Vector3:
	var sk := _w.skeleton
	if sk == null:
		return Vector3.INF
	var i := sk.find_bone(_w._skeleton_bone_name(canonical))
	if i < 0:
		return Vector3.INF
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin
