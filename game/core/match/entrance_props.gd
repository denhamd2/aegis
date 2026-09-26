class_name EntranceProps
extends Node3D
## Roman's entrance props on his body: the ula fala at his neck and the AEW
## title, either worn round his waist or held in his left hand
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
	},
}

## Part name -> material. Gold is a metal lit by the follow spot and the
## stage washes; the hall's ambient carries no reflections (material_library's
## note on arena_truss), so a pure conductor renders near-black between the
## lights. A little emission keeps it reading as gold in the dark.
static func _materials() -> Dictionary:
	# AEW_PlateArt: the plate artwork off the owner's atlas, cut to each
	# plate's outline (alpha), with relief, roughness and metal maps made from
	# the same art (tools/assets/build_title_textures.py). ORM so metal and
	# enamel on one plate each get their own response under the follow spot.
	var art := ORMMaterial3D.new()
	art.resource_name = "AEW_PlateArt"
	art.albedo_texture = load("res://assets/props/aew_title_art.png")
	art.normal_enabled = true
	art.normal_texture = load("res://assets/props/aew_title_art_normal.png")
	art.normal_scale = 0.8
	art.orm_texture = load("res://assets/props/aew_title_art_orm.png")
	art.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	art.alpha_scissor_threshold = 0.5
	art.cull_mode = BaseMaterial3D.CULL_DISABLED
	art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	# The hall's ambient carries no reflections (material_library's note on
	# arena_truss), so a pure conductor goes near-black between the lights;
	# a trace of the art's own colour as emission keeps the gold reading.
	art.emission_enabled = true
	art.emission_texture = art.albedo_texture
	art.emission_energy_multiplier = 0.06
	# AEW_Gold: the slabs' edges -- the plate depth seen from the side.
	var gold := StandardMaterial3D.new()
	gold.resource_name = "AEW_Gold"
	gold.albedo_color = Color(0.93, 0.74, 0.40)
	gold.metallic = 1.0
	gold.roughness = 0.32
	# AEW_Leather: the tiling grain from the atlas's close-up swatch. The
	# strap's UVs are world metres (cube-projected), so this is tiles/metre.
	var leather := StandardMaterial3D.new()
	leather.resource_name = "AEW_Leather"
	leather.albedo_texture = load("res://assets/props/aew_leather.png")
	leather.albedo_color = Color(0.32, 0.31, 0.30)
	leather.normal_enabled = true
	leather.normal_texture = load("res://assets/props/aew_leather_normal.png")
	leather.normal_scale = 0.35
	leather.roughness = 0.55
	leather.uv1_scale = Vector3.ONE * 11.0
	# AEW_Snaps: brass rings, after the atlas's snap swatch.
	var snap := StandardMaterial3D.new()
	snap.resource_name = "AEW_Snaps"
	snap.albedo_color = Color(0.78, 0.60, 0.32)
	snap.metallic = 1.0
	snap.roughness = 0.4
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
		"TitleArt": art, "HeldArt": art, "TitleGold": gold, "HeldGold": gold,
		"TitleStrap": leather, "HeldStrap": leather,
		"TitleSnap": snap, "HeldSnap": snap,
		"FalaRed": red, "FalaOrange": orange, "FalaCord": cord,
	}


var _w: WrestlerController
var _scale := 1.0
var _fit: Dictionary = {}
var _fala: Node3D
var _title: Node3D
## Where the title is: "worn" (round his waist), "held", or "" (put down).
var _title_state := "worn"


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
	set_title("worn")
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
		(node as Node3D).visible = (state == "worn" and n.begins_with("Title")) \
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
	var neck := _bone("neck_01")
	if _fala and neck != Vector3.INF:
		_fala.global_transform = Transform3D(
				turn * Basis.from_scale(fala_fit * _scale),
				neck + turn * (_fit.get("fala_offset", Vector3.ZERO) as Vector3))
	if _title == null:
		return
	if _title_state == "held":
		var hand := _bone("hand_l")
		if hand != Vector3.INF:
			# Real size: the belt is authored in metres off the atlas.
			_title.global_transform = Transform3D(turn, hand)
	else:
		# Worn: authored at Roman's own measured waist, so 1:1 on his hips.
		var hips := _bone("pelvis")
		if hips != Vector3.INF:
			_title.global_transform = Transform3D(turn, hips)


func _bone(canonical: String) -> Vector3:
	var sk := _w.skeleton
	if sk == null:
		return Vector3.INF
	var i := sk.find_bone(_w._skeleton_bone_name(canonical))
	if i < 0:
		return Vector3.INF
	return (sk.global_transform * sk.get_bone_global_pose(i)).origin
