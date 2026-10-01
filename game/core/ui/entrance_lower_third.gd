class_name EntranceLowerThird
extends Control
## The ring-entrance name graphic: the owner's plate art with the wrestler's
## title (or nickname) on the small upper plate and his name across the main
## one, set in Teko Bold -- laid out off the owner's reference frame of Roman's
## entrance, captioned AEW CHAMPION.
##
## Measured off that reference (1672x941): the plate spans x 0.24-0.74 of the
## frame and y 0.77-0.95, a little left of centre; the subtitle is gold,
## tracked caps, about a third of the name's height; the name is near-white
## silver, slanted with the plate, and fills most of the main plate's height.
##
## Teko ships as a variable font whose weight axis tops out at Bold (700);
## there is no ExtraBold cut of it, so both lines are 700. It has no italic
## either, so the slant is a shear applied while drawing, matched to the
## plate's own lean.
##
## Drawn, like MatchHUD and the title screen, so it scales with the viewport.

const PLATE := "res://assets/ui/lower_third_plate.png"

## Where the plate sits, as fractions of the viewport (off the reference).
const PLATE_LEFT := 0.235
const PLATE_WIDTH := 0.51
const PLATE_BOTTOM := 0.955

## Inside the plate image (2103x455, lower_third_plate.png): the upper plate's
## centre line and the main plate's, as fractions of the image.
const SUB_CENTRE := Vector2(0.575, 0.105)
const NAME_CENTRE := Vector2(0.505, 0.60)
## The lean of the plate's slanted ends -- run over rise, measured on the
## image's left edge -- which the name is sheared to match.
const SHEAR := 0.38

const SUB_GOLD := Color(1.0, 0.80, 0.24)
const NAME_TOP := Color(1.0, 1.0, 1.0)
const NAME_SHADE := Color(0.72, 0.74, 0.80)

## The build, in seconds from show_card() -- a broadcast graphic keys on in
## layers, never as one fade (the owner asked for slick transitions):
## a light streak sweeps across and the plate wipes on behind it, behind a
## slanted edge leaning with the plate; the gold subtitle tracks in from
## wide; the name's letters rise into place one after another with a little
## overshoot; and once it has settled, a specular shine runs across the
## silver.
const STREAK_IN := Vector2(0.00, 0.34)
const PLATE_IN := Vector2(0.03, 0.40)
const SUB_IN := Vector2(0.20, 0.52)
const NAME_IN_AT := 0.26
const NAME_IN_EACH := 0.30
const NAME_STAGGER := 0.022
const SHINE := Vector2(0.78, 1.30)
## Out, in seconds from hide_card(): the letters slip away left in a fast
## stagger, the subtitle with them, then the plate wipes off to the right
## behind the streak.
const NAME_OUT_EACH := 0.16
const NAME_OUT_STAGGER := 0.010
const PLATE_OUT := Vector2(0.10, 0.38)
const STREAK_OUT := Vector2(0.08, 0.40)
const OUT_DONE := 0.42
const STREAK_COLOR := Color(1.0, 0.93, 0.78)

var title := ""
var subtitle := ""
var _plate: Texture2D
var _font: Font
## Seconds since show_card(), or -1 when the card is off.
var _in := -1.0
## Seconds since hide_card(), or -1 while it is not going out.
var _out := -1.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = load(PLATE) as Texture2D
	_font = TitleArt.teko(700)


func show_card(p_title: String, p_subtitle: String) -> void:
	title = p_title.to_upper()
	subtitle = p_subtitle.to_upper()
	if _in < 0.0 or _out >= 0.0:
		_in = 0.0
	_out = -1.0
	queue_redraw()


func hide_card() -> void:
	if _in >= 0.0 and _out < 0.0:
		_out = 0.0


func is_showing() -> bool:
	return _in >= 0.0 and _out < 0.0


func _process(delta: float) -> void:
	if _in < 0.0:
		return
	_in += delta
	if _out >= 0.0:
		_out += delta
		if _out >= OUT_DONE:
			_in = -1.0
			_out = -1.0
	queue_redraw()


static func _phase(t: float, window: Vector2) -> float:
	return clampf((t - window.x) / (window.y - window.x), 0.0, 1.0)


static func _expo_out(t: float) -> float:
	return 1.0 if t >= 1.0 else 1.0 - pow(2.0, -10.0 * t)


static func _back_out(t: float) -> float:
	var c1 := 1.40
	var u := t - 1.0
	return 1.0 + (c1 + 1.0) * u * u * u + c1 * u * u


static func _smooth(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)


func _draw() -> void:
	if _in < 0.0 or _plate == null:
		return
	var view := get_viewport_rect().size
	var w := view.x * PLATE_WIDTH
	var h := w * float(_plate.get_height()) / float(_plate.get_width())
	var rect := Rect2(view.x * PLATE_LEFT, view.y * PLATE_BOTTOM - h, w, h)
	# The slanted edge's lean over the plate's height, as the plate leans.
	var lean := h * SHEAR * 0.5
	var going := _out >= 0.0

	# The plate: shown between a left and a right edge that sweep across it.
	var right_edge := _expo_out(_phase(_in, PLATE_IN))
	var left_edge := _smooth(_phase(_out, PLATE_OUT)) if going else 0.0
	# It drifts in the last few pixels as it lands.
	rect.position.x += (1.0 - right_edge) * -view.x * 0.012
	_draw_plate(rect, lean, left_edge, right_edge)
	# The streak rides the edge that is moving.
	var streak := _phase(_out, STREAK_OUT) if going else _phase(_in, STREAK_IN)
	if streak > 0.0 and streak < 1.0:
		var at := left_edge if going else right_edge
		_draw_streak(rect, lean, at, sin(streak * PI))

	# Subtitle: gold tracked caps, tracking in from wide.
	if subtitle != "":
		var sub_in := _expo_out(_phase(_in, SUB_IN))
		var sub_out := _smooth(clampf(_out / NAME_OUT_EACH, 0.0, 1.0)) if going else 0.0
		var sub_alpha := sub_in * (1.0 - sub_out)
		if sub_alpha > 0.0:
			var sub_size := int(h * 0.125)
			var sub_track := sub_size * (0.04 + 0.9 * (1.0 - sub_in))
			var sub_w := _tracked_width(subtitle, sub_size, sub_track)
			var sub_c := rect.position + rect.size * SUB_CENTRE
			_draw_tracked(Vector2(sub_c.x - sub_w * 0.5 - sub_out * sub_size * 2.0,
					sub_c.y + sub_size * 0.34), subtitle, sub_size, sub_track,
					Color(SUB_GOLD, sub_alpha))

	# Name: big, slanted with the plate, silver shaded from white at the top.
	var name_size := int(h * 0.60)
	var name_track := name_size * 0.01
	var name_w := _tracked_width(title, name_size, name_track)
	var max_w := rect.size.x * 0.80
	if name_w > max_w:
		name_size = int(name_size * max_w / name_w)
		name_track = name_size * 0.01
		name_w = _tracked_width(title, name_size, name_track)
	var c := rect.position + rect.size * NAME_CENTRE
	var baseline := Vector2(c.x - name_w * 0.5, c.y + name_size * 0.33)
	var shear := Transform2D(Vector2(1, 0), Vector2(-SHEAR * 0.5, 1), Vector2.ZERO)
	draw_set_transform_matrix(Transform2D(0.0, baseline) * shear
			* Transform2D(0.0, -baseline))
	var shine := _phase(_in, SHINE)
	var shine_x := lerpf(-0.25, 1.25, _smooth(shine)) * name_w
	var x := baseline.x
	for i in title.length():
		var ch := title[i]
		var adv := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1,
				name_size).x
		var t_in := clampf((_in - NAME_IN_AT - i * NAME_STAGGER) / NAME_IN_EACH,
				0.0, 1.0)
		var alpha := clampf(t_in * 1.8, 0.0, 1.0)
		var off := Vector2(0.0, (1.0 - _back_out(t_in)) * name_size * 0.42)
		if going:
			var t_out := _smooth(clampf((_out - i * NAME_OUT_STAGGER) / NAME_OUT_EACH,
					0.0, 1.0))
			alpha *= 1.0 - t_out
			off.x -= t_out * name_size * 0.35
		if alpha > 0.0:
			var at := Vector2(x, baseline.y) + off
			# Drop shadow, then the face in two passes -- a darker full
			# glyph, then the top of it in white: the metallic top-lit read
			# of the reference -- then the shine as it passes this letter.
			draw_string(_font, at + Vector2(name_size * 0.03, name_size * 0.04), ch,
					HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(0, 0, 0, 0.75 * alpha))
			draw_string(_font, at, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size,
					Color(NAME_SHADE, alpha))
			draw_string(_font, at + Vector2(0.0, -name_size * 0.03), ch,
					HORIZONTAL_ALIGNMENT_LEFT, -1, name_size, Color(NAME_TOP, alpha * 0.92))
			if shine > 0.0 and shine < 1.0:
				var d := (x + adv * 0.5 - baseline.x - shine_x) / (name_w * 0.10)
				var glint := exp(-d * d) * sin(shine * PI)
				if glint > 0.02:
					draw_string(_font, at + Vector2(0.0, -name_size * 0.03), ch,
							HORIZONTAL_ALIGNMENT_LEFT, -1, name_size,
							Color(1.0, 1.0, 1.0, glint * alpha))
		x += adv + name_track
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The plate between two edges (0 = its left end, 1 = its right), each edge
## slanted like the plate's own ends.
func _draw_plate(rect: Rect2, lean: float, from: float, to: float) -> void:
	if to <= from:
		return
	var span := rect.size.x + lean
	var xl := rect.position.x + from * span - lean
	var xr := rect.position.x + to * span - lean
	var top := rect.position.y
	var bottom := rect.end.y
	var pts := PackedVector2Array([
		Vector2(clampf(xl + lean, rect.position.x, rect.end.x), top),
		Vector2(clampf(xr + lean, rect.position.x, rect.end.x), top),
		Vector2(clampf(xr, rect.position.x, rect.end.x), bottom),
		Vector2(clampf(xl, rect.position.x, rect.end.x), bottom)])
	var uvs := PackedVector2Array()
	for p in pts:
		uvs.append(Vector2((p.x - rect.position.x) / rect.size.x,
				(p.y - top) / rect.size.y))
	draw_colored_polygon(pts, Color.WHITE, uvs, _plate)


## A thin bright slanted bar with a soft glow round it, at `at` along the
## plate, `strength` 0..1.
func _draw_streak(rect: Rect2, lean: float, at: float, strength: float) -> void:
	var span := rect.size.x + lean
	var x := rect.position.x + at * span - lean
	var top := rect.position.y - rect.size.y * 0.08
	var bottom := rect.end.y + rect.size.y * 0.08
	var lean_ext := lean * (bottom - top) / rect.size.y
	for layer: Array in [[rect.size.x * 0.05, 0.22], [rect.size.x * 0.012, 0.95]]:
		var half: float = layer[0] * 0.5
		var col := Color(STREAK_COLOR, float(layer[1]) * strength)
		draw_colored_polygon(PackedVector2Array([
			Vector2(x + lean_ext - half, top), Vector2(x + lean_ext + half, top),
			Vector2(x + half, bottom), Vector2(x - half, bottom)]), col)


func _tracked_width(text: String, size: int, track: float) -> float:
	var w := 0.0
	for i in text.length():
		w += _font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
				size).x + track
	return w - track


func _draw_tracked(origin: Vector2, text: String, size: int, track: float,
		color: Color) -> void:
	var x := origin.x
	for i in text.length():
		draw_string(_font, Vector2(x, origin.y), text[i],
				HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
		x += _font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1,
				size).x + track
