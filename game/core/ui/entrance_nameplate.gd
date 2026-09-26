class_name EntranceNameplate
extends Control
## The lower third that names the man walking to the ring.
##
## Drawn, not built from themed Control nodes, for the reason
## `core/ui/title_screen.gd` gives at length: everything here is a fraction of
## the viewport, so it lays out identically at any resolution -- including
## whatever size the browser canvas happens to be in the Pages build, where
## there is no window size to anchor to. It also means the whole graphic is one
## `_draw()` that can be read top to bottom instead of a tree of containers
## whose result has to be run to be understood.
##
## Colours come off the Roster.Entry, not from a table here. `attire_body` and
## `attire_accent` are chosen so the two cards separate by hue at a glance
## (Roster's own comment), which is the same job this plate has, so there is
## nothing to add -- and a second table of per-wrestler colours is a second
## place to forget to add the third wrestler.

## Fraction of the viewport height the plate occupies, and where its top sits.
## Lower third, and clear of the bottom edge: at 720p this is a 72px bar with
## its baseline 137px off the floor of the frame.
const PLATE_HEIGHT := 0.10
const PLATE_TOP := 0.72
## How far in from the left edge the plate starts, and how wide it runs.
const PLATE_LEFT := 0.055
const PLATE_WIDTH := 0.46

## The accent stripe down the plate's leading edge, as a fraction of the
## plate's own width. This is where the wrestler's colour actually lives: a
## whole bar in Cody's gold would fight the gold already on the stage.
const STRIPE_WIDTH := 0.022

const PLATE_BG := Color(0.035, 0.038, 0.048, 0.88)
const PLATE_EDGE := Color(0, 0, 0, 0.5)

## Seconds the slide in and out take, and how far the plate travels doing it --
## a fraction of the viewport width, leftward, so it comes on from off frame.
const SLIDE_TIME := 0.38
const SLIDE_TRAVEL := 0.30

var entry: Roster.Entry = null

## 0 = fully off frame, 1 = fully on. Driven by EntranceDirector rather than by
## a clock here: the director owns the beats, and a plate with its own timer is
## a second source of truth about when the walk starts.
var reveal: float = 0.0

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Eased 0..1. Drawn straight from `reveal` the plate slides at a constant
## rate, which reads as a sheet of paper being pushed rather than as a graphic.
func _eased() -> float:
	var r := clampf(reveal, 0.0, 1.0)
	return r * r * (3.0 - 2.0 * r)


func _draw() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0 or entry == null:
		return
	var on := _eased()
	if on <= 0.001:
		return

	var plate := Vector2(view.x * PLATE_WIDTH, view.y * PLATE_HEIGHT)
	var origin := Vector2(
			view.x * PLATE_LEFT - view.x * SLIDE_TRAVEL * (1.0 - on),
			view.y * PLATE_TOP)
	var rect := Rect2(origin, plate)

	# The body, its edge, and the accent stripe. Alpha scales with the slide so
	# the plate fades as it travels -- it does not slide out of frame as a hard
	# rectangle, which at 30fps strobes along its own leading edge.
	draw_rect(Rect2(rect.position + Vector2(0, plate.y * 0.06), plate),
			Color(0, 0, 0, 0.35 * on))
	draw_rect(rect, Color(PLATE_BG.r, PLATE_BG.g, PLATE_BG.b, PLATE_BG.a * on))
	draw_rect(rect, Color(PLATE_EDGE.r, PLATE_EDGE.g, PLATE_EDGE.b,
			PLATE_EDGE.a * on), false, maxf(1.0, view.y * 0.002))
	var stripe := Rect2(rect.position,
			Vector2(plate.x * STRIPE_WIDTH, plate.y))
	draw_rect(stripe, Color(entry.attire_accent.r, entry.attire_accent.g,
			entry.attire_accent.b, on))

	# Name and tagline, tracked out the way every other caption in this project
	# is. The name sits on the plate's upper two thirds and the tagline under
	# it, both left-aligned off the stripe.
	var text_x := rect.position.x + plate.x * 0.055
	var name_size := int(maxf(12.0, plate.y * 0.40))
	var tag_size := int(maxf(9.0, plate.y * 0.20))
	TitleArt.draw_tracked(self, _font,
			Vector2(text_x, rect.position.y + plate.y * 0.46),
			entry.display_name(), name_size, plate.y * 0.045,
			Color(TitleArt.STEEL.r, TitleArt.STEEL.g, TitleArt.STEEL.b, on))
	TitleArt.draw_tracked(self, _font,
			Vector2(text_x, rect.position.y + plate.y * 0.80),
			entry.tagline, tag_size, plate.y * 0.055,
			Color(entry.attire_accent.r, entry.attire_accent.g,
					entry.attire_accent.b, 0.92 * on))
