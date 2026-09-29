class_name MatchStinger
extends CanvasLayer
## The broadcast wipe between the wrestler select and the ring entrance.
##
## It used to be a fade to black, then a hard cut to the match -- with the
## frame frozen in between while the two picked models loaded, a half-second
## hitch of nothing on a black screen. This is the TV stinger instead:
##
##   IN    slanted bands sweep across left to right -- violet, teal, then the
##         dark panel that covers the screen -- and the match-up is set on it;
##   HOLD  the screen is covered while the match loads and draws its first
##         frames underneath (TitleScreen starts the loads during the VS card,
##         so this is usually only a few frames);
##   OUT   the bands carry on off to the right in reverse order, the panel
##         first, and the arena's opening shot is revealed behind them on a
##         soft flash of light.
##
## A CanvasLayer on the root, so it outlives the TitleScreen that starts it
## and the scene swap it hides. Presentation only; frees itself when done.

signal covered

const LAYER := 100
## Band sweeps, seconds.
const IN_TIME := 0.42
const OUT_TIME := 0.48
## Each band follows the one before by this much.
const STAGGER := 0.07
## The shortest time the covered screen holds, so the match-up can be read.
const MIN_HOLD := 0.55
## Slant of the band edges from vertical, degrees.
const SLANT_DEG := 18.0
## Frames the match draws under the cover before the reveal: shaders compile
## and the first shot settles on these, not on screen.
const SETTLE_FRAMES := 4

enum Stage { IN, HOLD, OUT, DONE }

var left_name := ""
var right_name := ""
var left_accent := TitleArt.KEY_VIOLET
var right_accent := TitleArt.KEY_TEAL

var _stage := Stage.IN
var _t := 0.0
var _hold := 0.0
var _reveal_asked := false
var _settle := -1
var _draw: Control
var _font: Font


func _ready() -> void:
	layer = LAYER
	_font = TitleArt.teko(700)
	_draw = Control.new()
	_draw.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw.draw.connect(_on_draw)
	add_child(_draw)


## The two men, as the select screen named them, and their colours.
func setup(left: Roster.Entry, right: Roster.Entry) -> void:
	left_name = left.display_name()
	right_name = right.display_name()
	left_accent = left.attire_accent
	right_accent = right.attire_accent


## The match is in the tree: let it settle for a few frames, then reveal it.
func reveal() -> void:
	_reveal_asked = true


func is_covering() -> bool:
	return _stage == Stage.HOLD


func _process(delta: float) -> void:
	_t += delta
	match _stage:
		Stage.IN:
			if _t >= IN_TIME + STAGGER * 2.0:
				_stage = Stage.HOLD
				_t = 0.0
				covered.emit()
		Stage.HOLD:
			_hold += delta
			if _reveal_asked:
				if _settle < 0:
					_settle = SETTLE_FRAMES
				else:
					_settle -= 1
				if _settle <= 0 and _hold >= MIN_HOLD:
					_stage = Stage.OUT
					_t = 0.0
		Stage.OUT:
			if _t >= OUT_TIME + STAGGER * 2.0 + FLASH_TIME:
				_stage = Stage.DONE
				queue_free()
	_draw.queue_redraw()


## 0..1 progress of band `k` (0 first) at time `t` into a sweep of `length`.
static func band_progress(t: float, k: int, length: float) -> float:
	var s := clampf((t - STAGGER * k) / length, 0.0, 1.0)
	# Quick out of the blocks, eased into place: a cubic ease-in-out.
	return 4.0 * s * s * s if s < 0.5 else 1.0 - pow(-2.0 * s + 2.0, 3.0) / 2.0


const FLASH_TIME := 0.35


func _on_draw() -> void:
	var view := _draw.get_viewport_rect().size
	var skew := view.y * tan(deg_to_rad(SLANT_DEG))
	var span := view.x + skew * 2.0
	# The key art's own violet and teal, deepened so they read as a broadcast
	# wipe rather than a highlight: the men's accent colours blended in here
	# washed out to lavender and lime on the first render.
	var bands := [TitleArt.KEY_VIOLET.darkened(0.25), TitleArt.KEY_TEAL.darkened(0.35),
			TitleArt.KEY_PANEL]
	for k in bands.size():
		var lead := -skew
		var trail := -skew
		match _stage:
			Stage.IN:
				lead = -skew + span * band_progress(_t, k, IN_TIME)
			Stage.HOLD:
				lead = view.x + skew
			Stage.OUT:
				# The panel (last in) goes first.
				lead = view.x + skew
				trail = -skew + span * band_progress(_t, bands.size() - 1 - k, OUT_TIME)
			Stage.DONE:
				continue
		if lead <= trail:
			continue
		_band(trail, lead, skew, view.y, bands[k])
		# A gold rule on each leading edge while it moves.
		if _stage == Stage.IN and lead < view.x + skew:
			_edge(lead, skew, view.y, TitleArt.KEY_GOLD)
		if _stage == Stage.OUT and trail > -skew:
			_edge(trail, skew, view.y, TitleArt.KEY_GOLD)
	_draw_matchup(view)
	# The light the arena comes up on.
	if _stage == Stage.OUT:
		var clear := OUT_TIME + STAGGER * 2.0
		if _t > clear * 0.55:
			var f := clampf((_t - clear * 0.55) / FLASH_TIME, 0.0, 1.0)
			_draw.draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 0.22 * (1.0 - f) * (1.0 - f)))


## A band between two slanted edges: x at the bottom of the screen, leaning
## right by `skew` at the top.
func _band(trail: float, lead: float, skew: float, h: float, color: Color) -> void:
	_draw.draw_colored_polygon(PackedVector2Array([
			Vector2(trail, h), Vector2(lead, h),
			Vector2(lead + skew, 0.0), Vector2(trail + skew, 0.0)]), color)


func _edge(x: float, skew: float, h: float, color: Color) -> void:
	_draw.draw_line(Vector2(x, h), Vector2(x + skew, 0.0), color, maxf(2.0, h * 0.004))


## The match-up, on the panel while it covers: each name sliding in from its
## own side, VS in gold between them.
func _draw_matchup(view: Vector2) -> void:
	var a := 0.0
	var slide := 0.0
	match _stage:
		Stage.IN:
			var p := band_progress(_t, 2, IN_TIME)
			a = clampf((p - 0.6) / 0.4, 0.0, 1.0)
			slide = 1.0 - a
		Stage.HOLD:
			a = 1.0
			slide = 0.0
		Stage.OUT:
			a = 1.0 - clampf(_t / (OUT_TIME * 0.35), 0.0, 1.0)
			slide = (1.0 - a) * 0.5
		_:
			return
	if a <= 0.0:
		return
	var size := int(view.y * 0.085)
	var track := view.y * 0.004
	var y := view.y * 0.5 + size * 0.35
	var lw := TitleArt.tracked_width(_font, left_name, size, track)
	var shift := view.x * 0.08 * slide
	TitleArt.draw_tracked(_draw, _font, Vector2(view.x * 0.44 - lw - shift, y),
			left_name, size, track, Color(TitleArt.STEEL, a))
	TitleArt.draw_tracked(_draw, _font, Vector2(view.x * 0.56 + shift, y),
			right_name, size, track, Color(TitleArt.STEEL, a))
	var vs := int(size * 1.1)
	var vw := TitleArt.tracked_width(_font, "VS", vs, track)
	TitleArt.draw_tracked(_draw, _font, Vector2((view.x - vw) * 0.5, view.y * 0.5 + vs * 0.35),
			"VS", vs, track, Color(TitleArt.KEY_GOLD, a))
	# The broadcast tag above the match-up.
	var tag := int(size * 0.42)
	var tw := TitleArt.tracked_width(_font, "MAIN EVENT", tag, track * 2.0)
	TitleArt.draw_tracked(_draw, _font, Vector2((view.x - tw) * 0.5, view.y * 0.5 - size * 0.62),
			"MAIN EVENT", tag, track * 2.0, Color(TitleArt.KEY_GOLD, a * 0.9))
	# Accent rules under each name, in his colour.
	var rule_y := view.y * 0.5 + size * 0.55
	_draw.draw_rect(Rect2(view.x * 0.44 - lw - shift, rule_y, lw, maxf(2.0, view.y * 0.004)),
			Color(left_accent, a))
	var rw := TitleArt.tracked_width(_font, right_name, size, track)
	_draw.draw_rect(Rect2(view.x * 0.56 + shift, rule_y, rw, maxf(2.0, view.y * 0.004)),
			Color(right_accent, a))
