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

## How long it takes to wipe in and out, in seconds.
const WIPE := 0.28

var title := ""
var subtitle := ""
var _plate: Texture2D
var _font: Font
## 0 = gone, 1 = fully on. Driven by show_card()/hide_card() through _process.
var _shown := 0.0
var _target := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate = load(PLATE) as Texture2D
	_font = TitleArt.teko(700)


func show_card(p_title: String, p_subtitle: String) -> void:
	title = p_title.to_upper()
	subtitle = p_subtitle.to_upper()
	_target = 1.0


func hide_card() -> void:
	_target = 0.0


func is_showing() -> bool:
	return _target > 0.0


func _process(delta: float) -> void:
	var step := delta / WIPE
	var before := _shown
	_shown = move_toward(_shown, _target, step)
	if _shown != before or _shown > 0.0:
		queue_redraw()


func _draw() -> void:
	if _shown <= 0.0 or _plate == null:
		return
	var view := get_viewport_rect().size
	var t := _shown * _shown * (3.0 - 2.0 * _shown)
	var w := view.x * PLATE_WIDTH
	var h := w * float(_plate.get_height()) / float(_plate.get_width())
	var rect := Rect2(view.x * PLATE_LEFT, view.y * PLATE_BOTTOM - h, w, h)
	# Wipes in from the left: the plate slides a little and fades up, the way
	# a broadcast graphic keys on, rather than popping.
	var slide := (1.0 - t) * -view.x * 0.04
	rect.position.x += slide
	var alpha := t
	draw_texture_rect(_plate, rect, false, Color(1, 1, 1, alpha))

	# Subtitle: gold tracked caps, centred on the upper plate.
	if subtitle != "":
		var sub_size := int(h * 0.125)
		var sub_track := sub_size * 0.04
		var sub_w := _tracked_width(subtitle, sub_size, sub_track)
		var sub_c := rect.position + rect.size * SUB_CENTRE
		_draw_tracked(Vector2(sub_c.x - sub_w * 0.5, sub_c.y + sub_size * 0.34),
				subtitle, sub_size, sub_track, Color(SUB_GOLD, alpha))

	# Name: big, slanted with the plate, silver shaded from white at the top.
	var name_size := int(h * 0.60)
	var name_track := name_size * 0.01
	var name_w := _tracked_width(title, name_size, name_track)
	# Never wider than the main plate's straight run.
	var max_w := rect.size.x * 0.80
	if name_w > max_w:
		name_size = int(name_size * max_w / name_w)
		name_track = name_size * 0.01
		name_w = _tracked_width(title, name_size, name_track)
	var c := rect.position + rect.size * NAME_CENTRE
	var baseline := Vector2(c.x - name_w * 0.5, c.y + name_size * 0.33)
	var shear := Transform2D(Vector2(1, 0), Vector2(-SHEAR * 0.5, 1), Vector2.ZERO)
	# Shear about the baseline so the text leans in place.
	draw_set_transform_matrix(Transform2D(0.0, baseline) * shear
			* Transform2D(0.0, -baseline))
	# Drop shadow, then the face in two passes: a darker full glyph, then the
	# top of it in white -- the metallic top-lit read of the reference.
	_draw_tracked(baseline + Vector2(name_size * 0.03, name_size * 0.04), title,
			name_size, name_track, Color(0, 0, 0, 0.75 * alpha))
	_draw_tracked(baseline, title, name_size, name_track,
			Color(NAME_SHADE, alpha))
	_draw_tracked(baseline + Vector2(0.0, -name_size * 0.03), title, name_size,
			name_track, Color(NAME_TOP, alpha * 0.92))
	draw_set_transform_matrix(Transform2D.IDENTITY)


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
