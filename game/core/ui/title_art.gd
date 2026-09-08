class_name TitleArt
extends RefCounted
## Drawing primitives for the landing screen: the palette, the logo, the
## arena backdrop, and the two text helpers everything else is built from.
##
## Everything here is procedural. The project ships no font, no logo bitmap
## and no menu art, and the alternative to drawing the screen was committing
## binaries no one in the repo can regenerate. Procedural also means the whole
## screen is resolution-independent -- every size below is a fraction of the
## viewport, so the 1920x1080 desktop window and a browser canvas at whatever
## the tab happens to be get the same layout rather than a scaled bitmap.
##
## The look is broadcast-arena, matched to the same corpus the match itself is
## lit against (gauntlet/refs/stage.md): a black hall, hard coloured keys from
## above, haze the beams are visible in, and a ring silhouette sitting in the
## bottom of frame. It is a *stylised* echo of that, not a measured one -- the
## reference corpus measures gameplay frames and no menu exists in it, so
## nothing here claims a number from gauntlet/refs/.

## --- Palette ---------------------------------------------------------------
## Crimson is the action colour (menu cursor, confirm, the logo's "2") and the
## one saturated hue on the screen; steel carries the type; gold is reserved
## for the second wrestler's colourway so the two cards never both read red.
const INK := Color(0.031, 0.035, 0.047)
const INK_DEEP := Color(0.012, 0.013, 0.020)
const STEEL := Color(0.87, 0.89, 0.93)
const STEEL_DIM := Color(0.50, 0.54, 0.62)
const STEEL_DARK := Color(0.20, 0.22, 0.27)
const CRIMSON := Color(0.83, 0.13, 0.16)
const CRIMSON_DEEP := Color(0.42, 0.05, 0.07)
const GOLD := Color(0.86, 0.68, 0.26)
const HAZE := Color(0.42, 0.52, 0.78)

## --- Textures --------------------------------------------------------------

## Vertical background wash: near-black at the truss line, a touch of blue in
## the middle distance, black again on the floor.
static func make_backdrop_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.38, 0.72, 1.0])
	gradient.colors = PackedColorArray([
		INK_DEEP,
		Color(0.055, 0.065, 0.095),
		Color(0.038, 0.042, 0.060),
		Color(0.008, 0.009, 0.013),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 8
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)
	return tex


## A soft round falloff, drawn white and tinted by `modulate` at every call
## site. One texture serves the fixture glows, the card backlights and the
## logo bloom, so the screen has a single, consistent falloff shape.
static func make_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.42), Color(1, 1, 1, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


## The inverse of the glow: transparent in the middle, black at the corners.
static func make_vignette_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(0, 0, 0, 0), Color(0, 0, 0, 0.10), Color(0, 0, 0, 0.86),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	return tex


## --- Type ------------------------------------------------------------------
##
## Letter-spaced ("tracked") capitals are the one typographic move this screen
## makes, and it has to be done a character at a time: draw_string() has no
## tracking parameter, and the fallback font is the only font in the project.
## Drawing per character is also what makes the logo's shine sweep possible --
## a per-pixel mask over a drawn string is not available to a CanvasItem, but
## brightening each glyph by its distance to the sweep is.

static func tracked_width(font: Font, text: String, size: int,
		tracking: float) -> float:
	var width := 0.0
	for i in text.length():
		width += font.get_char_size(text.unicode_at(i), size).x + tracking
	return maxf(0.0, width - tracking)


## `origin` is the text's baseline-left, matching draw_string().
static func draw_tracked(canvas: CanvasItem, font: Font, origin: Vector2,
		text: String, size: int, tracking: float, color: Color) -> float:
	var x := origin.x
	for i in text.length():
		var code := text.unicode_at(i)
		canvas.draw_char(font, Vector2(x, origin.y), text[i], size, color)
		x += font.get_char_size(code, size).x + tracking
	return x - origin.x


## As above, but each glyph is lifted toward `shine` by how close it sits to a
## sweep centred at `sweep_x`. Run the sweep off-screen and back and the logo
## catches the light like a chrome plate under a moving fixture.
static func draw_tracked_shine(canvas: CanvasItem, font: Font, origin: Vector2,
		text: String, size: int, tracking: float, base: Color, shine: Color,
		sweep_x: float, sweep_width: float) -> float:
	var x := origin.x
	for i in text.length():
		var code := text.unicode_at(i)
		var advance := font.get_char_size(code, size).x
		var centre := x + advance * 0.5
		var t := clampf(1.0 - absf(centre - sweep_x) / maxf(1.0, sweep_width),
				0.0, 1.0)
		# Squared so the highlight has a tight core rather than a wash.
		canvas.draw_char(font, Vector2(x, origin.y), text[i], size,
				base.lerp(shine, t * t))
		x += advance + tracking
	return x - origin.x


## --- Backdrop --------------------------------------------------------------

## Four truss fixtures throwing beams down into haze, plus their pools on the
## floor. `t` is seconds since the screen opened; the beams breathe and drift
## rather than sit still, which is what keeps a static menu from reading as a
## screenshot.
static func draw_beams(canvas: CanvasItem, view: Vector2, glow: Texture2D,
		t: float) -> void:
	# x fraction, hue, sway phase.
	var fixtures := [
		[0.14, HAZE, 0.0],
		[0.37, Color(0.62, 0.30, 0.72), 1.7],
		[0.63, Color(0.85, 0.32, 0.30), 3.1],
		[0.88, HAZE, 4.6],
	]
	for fixture: Array in fixtures:
		var fx: float = view.x * float(fixture[0])
		var hue: Color = fixture[1]
		var phase: float = float(fixture[2])
		var sway := sin(t * 0.28 + phase) * view.x * 0.045
		var pulse := 0.72 + 0.28 * sin(t * 0.9 + phase * 1.3)
		var apex := Vector2(fx, -view.y * 0.06)
		var foot := Vector2(fx + sway, view.y * 0.80)
		var spread := view.x * 0.052
		var top := hue
		top.a = 0.20 * pulse
		var bottom := hue
		bottom.a = 0.0
		canvas.draw_polygon(
			PackedVector2Array([
				apex + Vector2(-spread * 0.16, 0.0),
				apex + Vector2(spread * 0.16, 0.0),
				foot + Vector2(spread, 0.0),
				foot + Vector2(-spread, 0.0),
			]),
			PackedColorArray([top, top, bottom, bottom]))
		# The fixture lens itself, and the pool it lays on the floor.
		draw_glow(canvas, glow, apex + Vector2(0.0, view.y * 0.02),
				view.x * 0.10, Color(hue.r, hue.g, hue.b, 0.30 * pulse))
		draw_glow(canvas, glow, foot + Vector2(0.0, view.y * 0.055),
				view.x * 0.30, Color(hue.r, hue.g, hue.b, 0.13 * pulse))


## Slow-rising motes in the beams. Positions come from a seeded generator so
## the drift is the same every time the screen opens.
static func draw_haze(canvas: CanvasItem, view: Vector2, motes: Array,
		t: float) -> void:
	for mote: Vector3 in motes:
		var rise := fposmod(mote.y - t * 0.012 * mote.z, 1.0)
		var drift := sin(t * 0.35 + mote.x * 24.0) * 0.012
		var pos := Vector2((mote.x + drift) * view.x, rise * view.y)
		var radius := view.x * 0.0011 * mote.z
		var alpha := 0.16 * mote.z * (0.6 + 0.4 * sin(t * 1.4 + mote.x * 40.0))
		canvas.draw_circle(pos, radius, Color(0.72, 0.80, 1.0, alpha))


## The ring, read as a silhouette from the hard camera: apron band, four posts,
## three ropes, and a rim light along the top rope where the truss catches it.
## Drawn in near-black so it reads as foreground depth, never as content.
static func draw_ring_silhouette(canvas: CanvasItem, view: Vector2) -> void:
	var apron_top := view.y * 0.855
	var mat := Color(0.020, 0.022, 0.030, 1.0)
	canvas.draw_rect(Rect2(0.0, apron_top, view.x, view.y - apron_top), mat)
	# Apron skirt: a slightly lighter band, so the ring has two planes.
	canvas.draw_rect(Rect2(0.0, apron_top, view.x, view.y * 0.055),
			Color(0.055, 0.058, 0.072, 1.0))
	canvas.draw_line(Vector2(0.0, apron_top), Vector2(view.x, apron_top),
			Color(0.30, 0.34, 0.44, 0.55), maxf(1.0, view.y * 0.0018))

	var post_w := view.x * 0.016
	var post_h := view.y * 0.155
	for fx: float in [0.06, 0.94]:
		var x := view.x * fx - post_w * 0.5
		canvas.draw_rect(Rect2(x, apron_top - post_h, post_w, post_h),
				Color(0.075, 0.080, 0.095, 1.0))
		canvas.draw_rect(Rect2(x, apron_top - post_h, post_w * 0.28, post_h),
				Color(0.16, 0.17, 0.20, 1.0))
	for i in 3:
		var y := apron_top - post_h * (0.30 + 0.24 * i)
		var thickness := maxf(1.0, view.y * 0.0035)
		canvas.draw_line(Vector2(view.x * 0.06, y), Vector2(view.x * 0.94, y),
				Color(0.10, 0.11, 0.14, 1.0), thickness)
		canvas.draw_line(Vector2(view.x * 0.06, y - thickness * 0.5),
				Vector2(view.x * 0.94, y - thickness * 0.5),
				Color(0.42, 0.47, 0.58, 0.30), thickness * 0.35)


## --- Utility ---------------------------------------------------------------

static func draw_glow(canvas: CanvasItem, glow: Texture2D, centre: Vector2,
		diameter: float, tint: Color) -> void:
	canvas.draw_texture_rect(glow,
			Rect2(centre - Vector2(diameter, diameter) * 0.5,
					Vector2(diameter, diameter)), false, tint)


## A rectangle with two opposite corners cut off. Used for anything large --
## cards, the controls panel -- where the parallelogram below would read as a
## skewed box rather than a designed edge.
static func draw_cut_panel(canvas: CanvasItem, rect: Rect2, cut: float,
		fill: Color, edge: Color = Color(0, 0, 0, 0),
		edge_width: float = 0.0) -> void:
	var p := rect.position
	var s := rect.size
	var points := PackedVector2Array([
		p + Vector2(cut, 0.0),
		p + Vector2(s.x, 0.0),
		p + Vector2(s.x, s.y - cut),
		p + Vector2(s.x - cut, s.y),
		p + Vector2(0.0, s.y),
		p + Vector2(0.0, cut),
	])
	canvas.draw_colored_polygon(points, fill)
	if edge_width > 0.0 and edge.a > 0.0:
		var loop := points.duplicate()
		loop.append(points[0])
		canvas.draw_polyline(loop, edge, edge_width)


## A panel with one clipped corner -- the shape every plate on this screen
## uses (cards, menu cursor, the logo's lower bar) so they read as one kit.
static func draw_clipped_panel(canvas: CanvasItem, rect: Rect2, clip: float,
		fill: Color, edge: Color = Color(0, 0, 0, 0),
		edge_width: float = 0.0) -> void:
	var points := PackedVector2Array([
		rect.position + Vector2(clip, 0.0),
		rect.position + Vector2(rect.size.x, 0.0),
		rect.position + rect.size - Vector2(clip, 0.0),
		rect.position + Vector2(0.0, rect.size.y),
	])
	canvas.draw_colored_polygon(points, fill)
	if edge_width > 0.0 and edge.a > 0.0:
		canvas.draw_polyline(
			PackedVector2Array([points[0], points[1], points[2], points[3],
					points[0]]),
			edge, edge_width)


## --- Logo ------------------------------------------------------------------
##
## Three plates in one lockup, drawn under a shear so the whole thing leans
## like a sports-game wordmark: the wordmark itself in brushed steel with a
## travelling highlight, a crimson bar carrying the subtitle, and the numeral
## sitting on the end of that bar in gold.
##
## Returns the rect the lockup occupies (unsheared), so the caller can hang
## the menu off the bottom of it rather than off a guessed constant.
static func draw_logo(canvas: CanvasItem, font: Font, centre: Vector2,
		unit: float, t: float) -> Rect2:
	var word := "AEW"
	var word_size := int(unit * 0.20)
	var word_track := unit * 0.020
	var word_w := tracked_width(font, word, word_size, word_track)

	var sub := "FIGHT FOREVER"
	var sub_size := int(unit * 0.045)
	var sub_track := unit * 0.028
	var sub_w := tracked_width(font, sub, sub_size, sub_track)

	var numeral := "2"
	var numeral_size := int(unit * 0.115)

	var bar_h := unit * 0.085
	var bar_w := maxf(word_w, sub_w + unit * 0.26)
	var gap := unit * 0.022
	var total_h := word_size + gap + bar_h
	var top := centre.y - total_h * 0.5
	var word_baseline := top + word_size * 0.88
	var bar_rect := Rect2(centre.x - bar_w * 0.5, top + word_size + gap,
			bar_w, bar_h)

	# The lean. Everything below is drawn in a sheared space; the returned
	# rect is the upright one, because layout is easier to reason about
	# unsheared and the lean only ever costs half a glyph of width.
	var shear := -0.14
	canvas.draw_set_transform_matrix(Transform2D(
			Vector2(1.0, 0.0), Vector2(shear, 1.0),
			Vector2(-shear * centre.y, 0.0)))

	# Bloom behind the wordmark, so it sits in the hall's haze rather than on
	# top of it.
	# (Drawn inside the shear only so it tracks the letters exactly.)
	var word_x := centre.x - word_w * 0.5

	# Drop shadow, then a steel face with the highlight sweeping across it
	# roughly every seven seconds.
	draw_tracked(canvas, font, Vector2(word_x, word_baseline + unit * 0.010),
			word, word_size, word_track, Color(0, 0, 0, 0.75))
	draw_tracked(canvas, font, Vector2(word_x, word_baseline + unit * 0.004),
			word, word_size, word_track, Color(0.16, 0.18, 0.23, 1.0))
	var sweep := fposmod(t * 0.16, 1.0) * (word_w + unit * 0.8) \
			- unit * 0.4 + word_x
	draw_tracked_shine(canvas, font, Vector2(word_x, word_baseline), word,
			word_size, word_track, STEEL_DIM, Color(1, 1, 1), sweep,
			unit * 0.11)

	# Subtitle bar. The clipped corners match every other plate on the screen.
	draw_clipped_panel(canvas, bar_rect, bar_h * 0.42, CRIMSON_DEEP)
	draw_clipped_panel(canvas,
			Rect2(bar_rect.position, Vector2(bar_rect.size.x, bar_h * 0.52)),
			bar_h * 0.42, CRIMSON)
	var sub_x := bar_rect.position.x + unit * 0.03
	draw_tracked(canvas, font,
			Vector2(sub_x, bar_rect.position.y + bar_h * 0.68), sub, sub_size,
			sub_track, Color(0.98, 0.96, 0.94))

	# The numeral, sat on the right end of the bar and overhanging it -- the
	# one element allowed to break the lockup's box, which is what stops the
	# whole thing reading as a label.
	var num_w := font.get_char_size(numeral.unicode_at(0), numeral_size).x
	var num_x := bar_rect.position.x + bar_rect.size.x - num_w - unit * 0.012
	var num_baseline := bar_rect.position.y + bar_h * 0.92
	canvas.draw_char(font, Vector2(num_x, num_baseline + unit * 0.006),
			numeral, numeral_size, Color(0, 0, 0, 0.7))
	canvas.draw_char(font, Vector2(num_x, num_baseline), numeral,
			numeral_size, GOLD)

	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return Rect2(centre.x - bar_w * 0.5, top, bar_w, total_h)
