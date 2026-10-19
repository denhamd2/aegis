class_name WeaponWheel
extends Control
## The weapon wheel (No Holds Barred; gauntlet/refs/weapons_nhb.md): what he
## can pull out from under the ring, while he is down on one knee reaching
## for it. The match runs on behind it -- he can be hit out of it.
##
## Two rings, because there are 35 weapons and a wheel of 35 is a wheel of
## slivers:
##   inner  the six families (chairs, swung, carried, set pieces, sprays and
##          guns, whips and fists), chosen by the stick's angle;
##   outer  that family's weapons, fanned round its slice -- push the stick
##          out past OUTER and the family stays put while the angle picks one.
## Let go of WEAPON on one and it is the one he pulls out. Let go anywhere
## else and he gets up empty-handed.
##
## Stick, keys, mouse or a finger: whatever moves the move actions, or the
## mouse's offset from the wheel's centre.

## Stick radius past which the angle picks a weapon, and back inside which it
## picks a family again.
const OUTER := 0.62
const BACK_IN := 0.35
## The outer ring's fan: degrees per weapon, at least FAN_MIN wide in all.
const FAN_STEP := 22.0
const FAN_MIN := 60.0
## Below this the stick is centred: nothing chosen.
const DEAD := 0.25

const BG := Color(0.06, 0.06, 0.08, 0.86)
const SLICE := Color(0.14, 0.14, 0.17, 0.92)
const SLICE_HOT := Color(0.80, 0.18, 0.16, 0.95)
const ITEM := Color(0.10, 0.10, 0.12, 0.94)
const ITEM_HOT := Color(0.95, 0.80, 0.25, 0.98)
const TEXT := Color(0.96, 0.96, 0.96)
const TEXT_DIM := Color(1, 1, 1, 0.35)

var wrestler: WrestlerController
var _family := -1
var _locked := false
var _choice: WeaponDef = null
var _icons := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Before the wrestlers' physics, so a pick made on the tick the button is
	# let go reaches the controller on that same tick.
	process_physics_priority = -10
	for d in WeaponCatalog.all():
		var path := "res://assets/weapons/icons/%s.png" % d.id
		if ResourceLoader.exists(path):
			_icons[d.id] = load(path)


## Where the stick points to what is chosen: [family, weapon index in that
## family (-1: none)], given the family already held (`locked_family`, -1 if
## none). Pure, so the wheel's arithmetic is tested on its own.
static func pick_at(stick: Vector2, locked_family: int) -> Array:
	var r := stick.length()
	if r < DEAD:
		return [locked_family if r >= BACK_IN else -1, -1]
	var deg := fposmod(rad_to_deg(atan2(stick.x, -stick.y)), 360.0)    # 0 = up, clockwise
	var slice := 360.0 / WeaponDef.Family.size()
	var family := locked_family
	if family < 0 or r < BACK_IN:
		family = int(floor(fposmod(deg + slice * 0.5, 360.0) / slice))
	if r < OUTER:
		return [family, -1]
	var items := WeaponCatalog.in_family(family)
	var span := maxf(FAN_MIN, FAN_STEP * items.size())
	var centre := family * slice
	var off := wrapf(deg - centre, -180.0, 180.0)
	var index := int(floor((off + span * 0.5) / span * items.size()))
	return [family, clampi(index, 0, items.size() - 1)]


## The fan's angle for weapon `i` of `n` in a family centred at `centre`.
static func item_angle(centre: float, i: int, n: int) -> float:
	var span := maxf(FAN_MIN, FAN_STEP * n)
	return centre - span * 0.5 + span * (i + 0.5) / n


func _stick() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if v.length() > 0.1:
		return v
	var mouse := get_local_mouse_position() - size * 0.5
	var radius := size.y * 0.30
	if mouse.length() > radius * 0.15:
		return (mouse / radius).limit_length(1.0)
	return Vector2.ZERO


func _physics_process(_delta: float) -> void:
	if wrestler == null or not wrestler.is_rummaging():
		_family = -1
		_locked = false
		_choice = null
		visible = false
		return
	visible = true
	var stick := _stick()
	var got := pick_at(stick, _family if _locked else -1)
	_family = got[0]
	_locked = got[1] >= 0 or (_locked and stick.length() >= BACK_IN)
	var stock := WeaponStock.of(wrestler)
	_choice = null
	if got[1] >= 0:
		var d: WeaponDef = WeaponCatalog.in_family(got[0])[got[1]]
		if stock.in_stock(d.id):
			_choice = d
	if Input.is_action_just_released("weapon") and _choice:
		wrestler.pick_from_wheel(_choice.id)
	queue_redraw()


func _draw() -> void:
	if not visible:
		return
	var c := size * 0.5
	var u := size.y
	var r_in := u * 0.12
	var r_mid := u * 0.20
	var r_out := u * 0.36
	var font := ThemeDB.fallback_font
	draw_circle(c, r_out + u * 0.05, BG)
	_text(font, c + Vector2(0, -r_out - u * 0.065), "UNDER THE RING", int(u * 0.026), TEXT)
	var slice := 360.0 / WeaponDef.Family.size()
	for f in WeaponDef.Family.size():
		var a0 := deg_to_rad(f * slice - slice * 0.5 - 90.0)
		var a1 := deg_to_rad(f * slice + slice * 0.5 - 90.0)
		_ring_segment(c, r_in, r_mid, a0 + 0.02, a1 - 0.02, SLICE_HOT if f == _family else SLICE)
		var mid := deg_to_rad(f * slice - 90.0)
		_text(font, c + Vector2(cos(mid), sin(mid)) * (r_in + r_mid) * 0.5,
				WeaponDef.FAMILY_NAMES[f], int(u * 0.016), TEXT)
	if _family >= 0:
		var items := WeaponCatalog.in_family(_family)
		var stock := WeaponStock.of(wrestler)
		for i in items.size():
			var d := items[i]
			var deg := item_angle(_family * slice, i, items.size())
			var a := deg_to_rad(deg - 90.0)
			var at := c + Vector2(cos(a), sin(a)) * (r_mid + r_out) * 0.5
			var hot := _choice == d
			var plate := u * 0.045
			draw_circle(at, plate, ITEM_HOT if hot else ITEM)
			if _icons.has(d.id):
				var tex: Texture2D = _icons[d.id]
				var s := plate * 1.6
				draw_texture_rect(tex, Rect2(at - Vector2(s, s) * 0.5, Vector2(s, s)), false,
						Color(1, 1, 1, 1.0 if stock.in_stock(d.id) else 0.3))
			if hot:
				_text(font, c + Vector2(0, r_out + u * 0.045), d.display_name.to_upper(), int(u * 0.03), TEXT)
	_text(font, c, "WEAPON" if _choice == null else "LET GO", int(u * 0.018),
			TEXT_DIM if _choice == null else TEXT)


func _ring_segment(c: Vector2, r0: float, r1: float, a0: float, a1: float, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 12
	for k in steps + 1:
		var a := lerpf(a0, a1, float(k) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r1)
	for k in range(steps, -1, -1):
		var a := lerpf(a0, a1, float(k) / steps)
		pts.append(c + Vector2(cos(a), sin(a)) * r0)
	draw_colored_polygon(pts, color)


func _text(font: Font, centre: Vector2, text: String, px: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, px)
	draw_string(font, centre - Vector2(w.x * 0.5, -px * 0.35), text, HORIZONTAL_ALIGNMENT_CENTER, -1, px, color)
