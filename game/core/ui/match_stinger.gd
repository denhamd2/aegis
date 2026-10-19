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
## The covering band is the match-up screen (the owner, 19 Oct: the black
## card with just the names "stays on the screen for a while and the music
## stops ... a slick designed screen ... and also a loading bar"): a wide of
## the Dynamite arena (ARENA, the 2026 set with the LED side walls) pushing in
## slowly behind the two names, with the match's loading bar along the foot.
## The title theme plays on under it and fades as the arena is revealed
## (`revealing`).
##
## A CanvasLayer on the root, so it outlives the TitleScreen that starts it
## and the scene swap it hides. Presentation only; frees itself when done.

signal covered
## The cover starts to come off: the match is on screen from here.
signal revealing

## The arena the match-up is set against. Credited in assets/ui/CREDITS.md.
const ARENA := "res://assets/ui/matchup_arena.jpg"
## The arena pushes in this much over PUSH_TIME, for life on a held screen.
const PUSH := 0.06
const PUSH_TIME := 12.0
## Where the picture starts to darken toward the foot, and the match-up's
## centre line, as fractions of the screen's height: the stage and the ring
## above, the names in the lower third.
const SHADE_FROM := 0.40
const MATCHUP_Y := 0.70

const LAYER := 100
## Band sweeps, seconds.
const IN_TIME := 0.42
const OUT_TIME := 0.48
## Each band follows the one before by this much.
const STAGGER := 0.07
## The shortest time the covered screen holds, so the match-up can be read.
const MIN_HOLD := 0.9
## Slant of the band edges from vertical, degrees.
const SLANT_DEG := 18.0
## Frames the match draws under the cover before the reveal: shaders compile
## and the first shot settles on these, not on screen.
const SETTLE_FRAMES := 4

enum Stage { IN, HOLD, OUT, DONE }

var left_name := ""
var right_name := ""
var left_line := ""
var right_line := ""
var mode_label := "MAIN EVENT"
## How far the match has loaded, 0..1, set by TitleScreen as it builds it.
var progress := 0.0
## What the bar shows: eased toward `progress`, so a step reads as a fill.
var _shown := 0.0
var _arena: Texture2D
var _life := 0.0
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
	if ResourceLoader.exists(ARENA):
		_arena = load(ARENA) as Texture2D
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
	left_line = left.entrance_subtitle()
	right_line = right.entrance_subtitle()


## The match is in the tree: let it settle for a few frames, then reveal it.
func reveal() -> void:
	_reveal_asked = true


func is_covering() -> bool:
	return _stage == Stage.HOLD


func _process(delta: float) -> void:
	_t += delta
	# Clamped: a frame that stalled while the match was built does not jump
	# the push or the bar.
	_life += minf(delta, 0.05)
	_shown = move_toward(_shown, progress, minf(delta, 0.05) * 1.6)
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
				progress = 1.0
				if _settle <= 0 and _hold >= MIN_HOLD and _shown >= 1.0:
					_stage = Stage.OUT
					_t = 0.0
					revealing.emit()
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
		if k == bands.size() - 1 and _arena != null:
			_arena_band(trail, lead, skew, view)
		else:
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


## The covering band with the arena in it: the picture is fixed to the
## screen, so the band's edge wipes it on and off rather than sliding it.
func _arena_band(trail: float, lead: float, skew: float, view: Vector2) -> void:
	var pts := PackedVector2Array([Vector2(trail, view.y), Vector2(lead, view.y),
			Vector2(lead + skew, 0.0), Vector2(trail + skew, 0.0)])
	var art := Vector2(_arena.get_width(), _arena.get_height())
	var zoom := 1.0 + PUSH * smoothstep(0.0, 1.0, _life / PUSH_TIME)
	var drawn := art * maxf(view.x / art.x, view.y / art.y) * zoom
	var at := (view - drawn) * 0.5
	var uvs := PackedVector2Array()
	for q in pts:
		uvs.append((q - at) / drawn)
	_draw.draw_polygon(pts, PackedColorArray([Color.WHITE]), uvs, _arena)
	# The stage and the ring stay bright; the floor of the picture falls away
	# to the panel's dark under the names and the bar.
	_draw.draw_polygon(pts, PackedColorArray([Color(0, 0, 0, 0.10)]))
	var from := view.y * SHADE_FROM
	var cut := 1.0 - from / view.y
	var shade := PackedVector2Array([
			Vector2(trail + skew * cut, from), Vector2(lead + skew * cut, from),
			Vector2(lead, view.y), Vector2(trail, view.y)])
	_draw.draw_polygon(shade, PackedColorArray([Color(TitleArt.KEY_PANEL, 0.0),
			Color(TitleArt.KEY_PANEL, 0.0), Color(TitleArt.KEY_PANEL, 0.94),
			Color(TitleArt.KEY_PANEL, 0.94)]))


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
	var cy := view.y * MATCHUP_Y
	var y := cy + size * 0.35
	var lw := TitleArt.tracked_width(_font, left_name, size, track)
	var rw := TitleArt.tracked_width(_font, right_name, size, track)
	var shift := view.x * 0.08 * slide
	# A soft dark strip behind the text block, so the names hold on a busy
	# picture (the owner's arena has the ring and its ropes right behind them).
	var top := cy - size * 1.75
	var mid := cy - size * 0.9
	var low := cy + size * 1.1
	var clear := Color(TitleArt.KEY_PANEL, 0.0)
	var dark := Color(TitleArt.KEY_PANEL, 0.62 * a)
	_draw.draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(view.x, top),
			Vector2(view.x, mid), Vector2(0, mid)]), PackedColorArray([clear, clear, dark, dark]))
	_draw.draw_rect(Rect2(0.0, mid, view.x, low - mid), dark)
	_draw.draw_polygon(PackedVector2Array([Vector2(0, low), Vector2(view.x, low),
			Vector2(view.x, low + size), Vector2(0, low + size)]), PackedColorArray([dark, dark, clear, clear]))
	TitleArt.draw_tracked(_draw, _font, Vector2(view.x * 0.44 - lw - shift, y),
			left_name, size, track, Color(TitleArt.STEEL, a))
	TitleArt.draw_tracked(_draw, _font, Vector2(view.x * 0.56 + shift, y),
			right_name, size, track, Color(TitleArt.STEEL, a))
	var vs := int(size * 1.1)
	var vw := TitleArt.tracked_width(_font, "VS", vs, track)
	TitleArt.draw_tracked(_draw, _font, Vector2((view.x - vw) * 0.5, cy + vs * 0.35),
			"VS", vs, track, Color(TitleArt.KEY_GOLD, a))
	# Each man's line (his title or his nickname) over his name.
	var sub := int(size * 0.30)
	var lsw := TitleArt.tracked_width(_font, left_line, sub, track)
	TitleArt.draw_tracked(_draw, _font, Vector2(view.x * 0.44 - lsw - shift, cy - size * 0.48),
			left_line, sub, track, Color(left_accent.lightened(0.35), a * 0.95))
	TitleArt.draw_tracked(_draw, _font, Vector2(view.x * 0.56 + shift, cy - size * 0.48),
			right_line, sub, track, Color(right_accent.lightened(0.35), a * 0.95))
	# The broadcast tag over the lot, between two gold hairlines.
	var tag := int(size * 0.40)
	var tw := TitleArt.tracked_width(_font, mode_label, tag, track * 2.0)
	var ty := cy - size * 1.15
	TitleArt.draw_tracked(_draw, _font, Vector2((view.x - tw) * 0.5, ty),
			mode_label, tag, track * 2.0, Color(TitleArt.KEY_GOLD, a * 0.95))
	var hair := maxf(1.0, view.y * 0.0018)
	var gap := view.x * 0.012
	var reach := view.x * 0.16
	var hy := ty - tag * 0.33
	_draw.draw_rect(Rect2((view.x - tw) * 0.5 - gap - reach, hy, reach, hair),
			Color(TitleArt.KEY_GOLD, a * 0.7))
	_draw.draw_rect(Rect2((view.x + tw) * 0.5 + gap, hy, reach, hair),
			Color(TitleArt.KEY_GOLD, a * 0.7))
	# Accent rules under each name, in his colour.
	var rule_y := cy + size * 0.55
	_draw.draw_rect(Rect2(view.x * 0.44 - lw - shift, rule_y, lw, maxf(2.0, view.y * 0.004)),
			Color(left_accent, a))
	_draw.draw_rect(Rect2(view.x * 0.56 + shift, rule_y, rw, maxf(2.0, view.y * 0.004)),
			Color(right_accent, a))
	_draw_loading(view, a)


## The match's loading bar along the foot of the screen: thin, gold on dark,
## its percentage beside it, READY once the arena is built.
func _draw_loading(view: Vector2, alpha: float) -> void:
	if alpha <= 0.0:
		return
	var w := view.x * 0.42
	var h := maxf(4.0, view.y * 0.007)
	var at := Vector2((view.x - w) * 0.5, view.y * 0.885)
	_draw.draw_rect(Rect2(at, Vector2(w, h)), Color(1, 1, 1, 0.12 * alpha))
	var fill := w * clampf(_shown, 0.0, 1.0)
	_draw.draw_rect(Rect2(at, Vector2(fill, h)), Color(TitleArt.KEY_GOLD, alpha))
	# A bright head on the fill, so it reads as moving.
	if _shown < 1.0 and fill > 0.0:
		var pulse := 0.6 + 0.4 * sin(_life * 7.0)
		_draw.draw_rect(Rect2(at + Vector2(maxf(0.0, fill - h * 3.0), 0.0), Vector2(minf(fill, h * 3.0), h)),
				Color(1, 1, 1, 0.55 * pulse * alpha))
	var label := "LOADING  %d%%" % int(round(_shown * 100.0)) if _shown < 1.0 else "READY"
	var size := int(view.y * 0.024)
	var track := view.y * 0.003
	var lw := TitleArt.tracked_width(_font, label, size, track)
	TitleArt.draw_tracked(_draw, _font, Vector2((view.x - lw) * 0.5, at.y + h + size * 1.35),
			label, size, track, Color(TitleArt.STEEL, 0.85 * alpha))
