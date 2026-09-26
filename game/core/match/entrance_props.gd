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

## Per-model fit, on top of the shoulder-span scale, keyed by entrance_style.
##
## Shoulder span alone put Roman's ula fala INSIDE him. His J_Shoulder bones
## sit 0.31 m apart -- 0.82 of the mannequin's -- but he is far thicker
## through the neck and chest than the mannequin: measured off M_Body, his
## neck is 0.18 m across at its base, his trapezius runs to +-0.24 m, and his
## chest stands 0.16 m proud of the neck line 0.15 m down. So the loop, sized
## for the mannequin and then shrunk, came out 8.6 cm in radius inside a
## neck 9 cm in radius and never rendered; the draped belt floated off the
## shoulder as loose gold tiles. Found in a close render, where the necklace
## simply was not there.
##
## `fala` / `title` scale the props in the wrestler's frame (x across, y up,
## z forward) and the offsets move their origins, in metres, in that frame
## (+z is BEHIND him, -z in front -- the props are authored forward -Z).
const FITS := {
	"roman": {
		"fala": Vector3(1.6, 0.85, 1.75), "fala_offset": Vector3(0.0, 0.03, 0.0),
		"title": Vector3(1.2, 1.75, 1.9), "title_offset": Vector3(0.05, 0.0, -0.02),
	},
}

## Part name -> material. Gold is a metal lit by the follow spot and the
## stage washes; the hall's ambient carries no reflections (material_library's
## note on arena_truss), so a pure conductor renders near-black between the
## lights. A little emission keeps it reading as gold in the dark.
static func _materials() -> Dictionary:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.36)
	gold.metallic = 0.85
	gold.roughness = 0.36
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.72, 0.30)
	gold.emission_energy_multiplier = 0.035
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
var _fit: Dictionary = {}
var _fala: Node3D
var _title: Node3D
## Where the title is: "draped", "held", or "" (put down).
var _title_state := "draped"


static func dress(wrestler: WrestlerController) -> EntranceProps:
	var props := EntranceProps.new()
	props.name = "EntranceProps"
	props._w = wrestler
	props._fit = FITS.get(wrestler.entrance_style, {})
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
	var turn := Basis(Vector3.UP, _w.global_rotation.y)
	var fala_fit: Vector3 = _fit.get("fala", Vector3.ONE)
	var title_fit: Vector3 = _fit.get("title", Vector3.ONE)
	var neck := _bone("neck_01")
	if _fala and neck != Vector3.INF:
		_fala.global_transform = Transform3D(
				turn * Basis.from_scale(fala_fit * _scale),
				neck + turn * (_fit.get("fala_offset", Vector3.ZERO) as Vector3))
	var held := _title_state == "held"
	var anchor := _bone("hand_l") if held else _bone("upperarm_l")
	if _title and anchor != Vector3.INF:
		# Held, the belt is a hand's width: only the draped shape has a
		# shoulder to fit.
		var fit := Vector3.ONE * title_fit.x if held else title_fit
		_title.global_transform = Transform3D(turn * Basis.from_scale(fit * _scale),
				anchor + (Vector3.ZERO if held
				else turn * (_fit.get("title_offset", Vector3.ZERO) as Vector3)))


func _bone(canonical: String) -> Vector3:
	var sk := _w.skeleton
	if sk == null:
		return Vector3.INF
	var i := sk.find_bone(_w._skeleton_bone_name(canonical))
	if i < 0:
		return Vector3.INF
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin
