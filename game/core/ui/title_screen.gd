class_name TitleScreen
extends Control
## The landing screen: logo, menu, controls card, and the wrestler select that
## launches a match with the two men a player picked.
##
## Before this the shipped build booted straight into scenes/play.tscn with
## Roman hardcoded into BOTH slots -- there was no way to reach Cody without
## editing a .tscn, and no screen anywhere in the project that said what the
## game was. This is that screen, and it is also the only place the roster is
## chosen; play.tscn stays as the direct-to-match scene the probes and the
## capture harness point at, unchanged.
##
## Drawn rather than built from Control nodes. The reason is the same one
## MatchHUD gives: the project ships no font, no theme and no menu art, so a
## node-built menu would be default-themed buttons on a grey panel. Drawing it
## means the screen is one coherent piece of art at any resolution, including
## the browser canvas, where the Pages build runs at whatever size the tab is.
##
## Nothing here touches match state. The screen hands two Roster entries to
## configure_match() and frees itself; the match it launches is the same
## scenes/match.tscn every test builds against.

const MATCH_SCENE_PATH := "res://scenes/match.tscn"

enum Phase { TITLE, CONTROLS, SELECT, VERSUS, LAUNCH }

## Menu rows. QUIT is dropped on Web, where SceneTree.quit() leaves the player
## staring at a dead canvas with no way back.
const MENU_FIGHT := "FIGHT"
const MENU_CONTROLS := "CONTROLS"
const MENU_QUIT := "QUIT"

## How long the VS card holds before the match loads, and how long the fade to
## black takes. Both are presentation; the match's own clock starts fresh.
const VERSUS_HOLD := 1.15
const FADE_TIME := 0.45

## The bindings the controls card lists, in the order it lists them, paired
## with the label shown for each. The KEYS come from the InputMap at runtime,
## not from this table -- a rebind in project.godot changes the card without
## anyone remembering to edit it.
const CONTROL_ROWS := [
	["MOVE", ["move_up", "move_left", "move_down", "move_right"]],
	["RUN", ["run"]],
	["STRIKE", ["strike"]],
	["GRAPPLE", ["grapple"]],
	["REVERSAL", ["reversal"]],
	["SUBMISSION", ["submission_hold"]],
]

var phase: int = Phase.TITLE
var menu_index: int = 0
var cursor: int = 0
## Locked-in picks, player 1 first. Entries, not ids, so the launcher never
## has to look anything up again.
var picks: Array = []

var _roster: Array = []
var _menu: Array = []
var _time := 0.0
var _versus_time := 0.0
var _fade := 0.0
var _font: Font
var _backdrop: Texture2D
var _glow: Texture2D
var _vignette: Texture2D
## x fraction, y fraction, size/speed weight.
var _motes: Array = []
## Filled during _draw so the mouse can hit-test what was actually drawn.
var _menu_rects: Array = []
var _card_rects: Array = []


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_backdrop = TitleArt.make_backdrop_texture()
	_glow = TitleArt.make_glow_texture()
	_vignette = TitleArt.make_vignette_texture()
	_roster = Roster.entries()
	_menu = [MENU_FIGHT, MENU_CONTROLS]
	if not OS.has_feature("web"):
		_menu.append(MENU_QUIT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260908
	for _i in 90:
		_motes.append(Vector3(rng.randf(), rng.randf(),
				rng.randf_range(0.35, 1.0)))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(delta: float) -> void:
	_time += delta
	if phase == Phase.VERSUS:
		_versus_time += delta
		if _versus_time >= VERSUS_HOLD:
			phase = Phase.LAUNCH
	elif phase == Phase.LAUNCH:
		_fade = minf(1.0, _fade + delta / FADE_TIME)
		if _fade >= 1.0:
			set_process(false)
			_launch()
	queue_redraw()


## --- Input -----------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.VERSUS or phase == Phase.LAUNCH:
		return
	if event.is_action_pressed("ui_cancel"):
		_back()
		accept_event()
		return
	if event.is_action_pressed("ui_accept"):
		_accept()
		accept_event()
		return
	match phase:
		Phase.TITLE:
			if event.is_action_pressed("ui_down"):
				menu_index = wrapi(menu_index + 1, 0, _menu.size())
				accept_event()
			elif event.is_action_pressed("ui_up"):
				menu_index = wrapi(menu_index - 1, 0, _menu.size())
				accept_event()
		Phase.SELECT:
			if event.is_action_pressed("ui_right"):
				cursor = wrapi(cursor + 1, 0, _roster.size())
				accept_event()
			elif event.is_action_pressed("ui_left"):
				cursor = wrapi(cursor - 1, 0, _roster.size())
				accept_event()


func _gui_input(event: InputEvent) -> void:
	if phase == Phase.VERSUS or phase == Phase.LAUNCH:
		return
	if event is InputEventMouseMotion:
		if phase == Phase.TITLE:
			for i in _menu_rects.size():
				if (_menu_rects[i] as Rect2).has_point(event.position):
					menu_index = i
		elif phase == Phase.SELECT:
			for i in _card_rects.size():
				if (_card_rects[i] as Rect2).has_point(event.position):
					cursor = i
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		if phase == Phase.CONTROLS:
			_back()
		elif phase == Phase.TITLE:
			for i in _menu_rects.size():
				if (_menu_rects[i] as Rect2).has_point(event.position):
					menu_index = i
					_accept()
		elif phase == Phase.SELECT:
			for i in _card_rects.size():
				if (_card_rects[i] as Rect2).has_point(event.position):
					cursor = i
					_accept()


func _accept() -> void:
	match phase:
		Phase.TITLE:
			match _menu[menu_index]:
				MENU_FIGHT:
					phase = Phase.SELECT
					picks.clear()
					cursor = 0
				MENU_CONTROLS:
					phase = Phase.CONTROLS
				MENU_QUIT:
					get_tree().quit()
		Phase.CONTROLS:
			phase = Phase.TITLE
		Phase.SELECT:
			picks.append(_roster[cursor])
			if picks.size() >= 2:
				phase = Phase.VERSUS
				_versus_time = 0.0
			else:
				# Park the opponent cursor on the other man, which is the
				# pick a player wants far more often than the mirror match.
				cursor = wrapi(cursor + 1, 0, _roster.size())


func _back() -> void:
	match phase:
		Phase.CONTROLS:
			phase = Phase.TITLE
		Phase.SELECT:
			if picks.is_empty():
				phase = Phase.TITLE
			else:
				picks.pop_back()


## --- Launch ----------------------------------------------------------------

func _launch() -> void:
	var scene: Node = (load(MATCH_SCENE_PATH) as PackedScene).instantiate()
	configure_match(scene, picks[0], picks[1],
			randi_range(1, 1 << 30))
	var tree := get_tree()
	var old := tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	old.queue_free()


## Puts two roster entries into an un-entered scenes/match.tscn instance:
## models, colourways, HUD names, and which slot the player drives.
##
## Static, and taking the scene as an argument, so the wiring a match depends
## on is testable without opening the menu -- and so the launch path has
## exactly one description of "what a picked wrestler means".
##
## Called BEFORE the instance enters the tree, which is what makes setting
## character_model_scene enough: WrestlerController installs its model in
## _ready(), so the heavy .glb is loaded once, for the pick, and the box
## mannequin default is never instantiated on the way past.
static func configure_match(scene: Node, player: Roster.Entry,
		opponent: Roster.Entry, match_seed: int) -> void:
	var slots := [
		[scene.get_node("WrestlerA"), player, false],
		[scene.get_node("WrestlerB"), opponent, true],
	]
	for slot: Array in slots:
		var wrestler: WrestlerController = slot[0]
		var entry: Roster.Entry = slot[1]
		wrestler.is_ai = slot[2]
		wrestler.character_model_scene = load(entry.model_scene)
		wrestler.display_name = entry.display_name()
		wrestler.attire_body = entry.attire_body
		wrestler.attire_accent = entry.attire_accent
	if "match_seed" in scene:
		scene.match_seed = match_seed


## --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	draw_texture_rect(_backdrop, Rect2(Vector2.ZERO, view), false)
	TitleArt.draw_beams(self, view, _glow, _time)
	TitleArt.draw_haze(self, view, _motes, _time)
	TitleArt.draw_ring_silhouette(self, view)

	match phase:
		Phase.TITLE:
			_draw_title(view)
		Phase.CONTROLS:
			_draw_title(view)
			_draw_controls(view)
		Phase.SELECT:
			_draw_select(view)
		Phase.VERSUS, Phase.LAUNCH:
			_draw_select(view)
			_draw_versus(view)

	draw_texture_rect(_vignette, Rect2(Vector2.ZERO, view), false)
	_draw_chrome(view)
	if _fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, _fade))


## Build tag and hint line -- the frame around every phase.
func _draw_chrome(view: Vector2) -> void:
	var small := int(maxf(9.0, view.y * 0.016))
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x * 0.035, view.y * 0.955), "AEGIS BUILD", small,
			view.y * 0.006, Color(0.45, 0.49, 0.58))
	var hint := ""
	match phase:
		Phase.TITLE:
			hint = "UP / DOWN  NAVIGATE      ENTER  SELECT"
		Phase.CONTROLS:
			hint = "ESC  BACK"
		Phase.SELECT:
			hint = "LEFT / RIGHT  CHANGE      ENTER  LOCK IN      ESC  BACK"
	if hint == "":
		return
	var w := TitleArt.tracked_width(_font, hint, small, view.y * 0.006)
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x - w - view.x * 0.035, view.y * 0.955), hint, small,
			view.y * 0.006, Color(0.45, 0.49, 0.58))


func _draw_title(view: Vector2) -> void:
	var logo_centre := Vector2(view.x * 0.5, view.y * 0.34)
	# Bloom under the lockup: the hall's haze catching the wordmark.
	TitleArt.draw_glow(self, _glow, logo_centre, view.x * 0.85,
			Color(0.30, 0.40, 0.72, 0.18))
	var logo := TitleArt.draw_logo(self, _font, logo_centre, view.y, _time)

	var row_h := view.y * 0.072
	var row_w := view.x * 0.24
	var top := logo.position.y + logo.size.y + view.y * 0.10
	var size_px := int(view.y * 0.030)
	_menu_rects.clear()
	for i in _menu.size():
		var rect := Rect2(view.x * 0.5 - row_w * 0.5, top + row_h * i,
				row_w, row_h * 0.82)
		_menu_rects.append(rect)
		var selected := i == menu_index
		var label: String = _menu[i]
		var track := view.y * 0.010
		var text_w := TitleArt.tracked_width(_font, label, size_px, track)
		var baseline := rect.position.y + rect.size.y * 0.66
		if selected:
			# The cursor plate pulses, so the screen never freezes even when
			# nobody is touching it.
			var pulse := 0.82 + 0.18 * sin(_time * 3.4)
			TitleArt.draw_glow(self, _glow, rect.position + rect.size * 0.5,
					row_w * 1.5, Color(0.83, 0.13, 0.16, 0.20 * pulse))
			TitleArt.draw_clipped_panel(self, rect, rect.size.y * 0.42,
					Color(TitleArt.CRIMSON.r, TitleArt.CRIMSON.g,
							TitleArt.CRIMSON.b, 0.92),
					Color(1, 1, 1, 0.35), maxf(1.0, view.y * 0.0016))
			TitleArt.draw_tracked(self, _font,
					Vector2(rect.position.x + (row_w - text_w) * 0.5, baseline),
					label, size_px, track, Color(1, 1, 1))
		else:
			TitleArt.draw_clipped_panel(self, rect, rect.size.y * 0.42,
					Color(0.06, 0.07, 0.09, 0.55),
					Color(0.30, 0.33, 0.40, 0.55), maxf(1.0, view.y * 0.0012))
			TitleArt.draw_tracked(self, _font,
					Vector2(rect.position.x + (row_w - text_w) * 0.5, baseline),
					label, size_px, track, TitleArt.STEEL_DIM)


## The bindings, read off the InputMap so the card cannot go stale.
func _draw_controls(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.72))
	var panel := Rect2(view.x * 0.28, view.y * 0.20, view.x * 0.44,
			view.y * 0.60)
	TitleArt.draw_cut_panel(self, panel, view.y * 0.035,
			Color(0.05, 0.055, 0.075, 0.96), Color(0.35, 0.39, 0.48, 0.8),
			maxf(1.0, view.y * 0.0018))
	var head_size := int(view.y * 0.030)
	TitleArt.draw_tracked(self, _font,
			panel.position + Vector2(view.x * 0.030, view.y * 0.070),
			"CONTROLS", head_size, view.y * 0.012, TitleArt.STEEL)
	draw_rect(Rect2(panel.position + Vector2(view.x * 0.030, view.y * 0.085),
			Vector2(panel.size.x - view.x * 0.060, maxf(1.0, view.y * 0.002))),
			TitleArt.CRIMSON)

	var row_size := int(view.y * 0.022)
	var y := panel.position.y + view.y * 0.135
	for row: Array in CONTROL_ROWS:
		TitleArt.draw_tracked(self, _font,
				Vector2(panel.position.x + view.x * 0.030, y), row[0],
				row_size, view.y * 0.007, TitleArt.STEEL_DIM)
		var keys := _binding_labels(row[1])
		var kw := TitleArt.tracked_width(_font, keys, row_size, view.y * 0.007)
		TitleArt.draw_tracked(self, _font,
				Vector2(panel.position.x + panel.size.x - view.x * 0.030 - kw,
						y), keys, row_size, view.y * 0.007, TitleArt.STEEL)
		y += view.y * 0.062


## First keyboard event bound to each action, joined -- e.g. "W A S D".
func _binding_labels(actions: Array) -> String:
	var parts: Array[String] = []
	for action: String in actions:
		if not InputMap.has_action(action):
			continue
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: int = event.physical_keycode if event.physical_keycode != 0 \
						else event.keycode
				parts.append(_key_label(code))
				break
	return " ".join(parts)


## OS.get_keycode_string() renders a modifier as a CHORD PREFIX, not as a key:
## KEY_CTRL comes back as "Ctrl+" followed by a control character (U+0015),
## which on the card printed as "CTRL+" with an invisible tail. Run is bound to
## Ctrl in project.godot, so that is the row a player actually reads.
static func _key_label(keycode: int) -> String:
	var raw := OS.get_keycode_string(keycode)
	var text := ""
	for i in raw.length():
		# Drop anything unprintable; the modifier's tail is the only source.
		if raw.unicode_at(i) > 32:
			text += raw[i]
	return text.trim_suffix("+").to_upper()


func _draw_select(view: Vector2) -> void:
	var head_size := int(view.y * 0.034)
	var head := "SELECT YOUR WRESTLER"
	var hw := TitleArt.tracked_width(_font, head, head_size, view.y * 0.014)
	TitleArt.draw_tracked(self, _font,
			Vector2((view.x - hw) * 0.5, view.y * 0.115), head, head_size,
			view.y * 0.014, TitleArt.STEEL)

	var side := "PLAYER 1" if picks.is_empty() else "OPPONENT  ·  CPU"
	var side_color := Color(0.35, 0.62, 0.95) if picks.is_empty() \
			else Color(0.93, 0.55, 0.18)
	var side_size := int(view.y * 0.022)
	var sw := TitleArt.tracked_width(_font, side, side_size, view.y * 0.012)
	if phase == Phase.SELECT:
		TitleArt.draw_tracked(self, _font,
				Vector2((view.x - sw) * 0.5, view.y * 0.160), side, side_size,
				view.y * 0.012, side_color)

	var card := Vector2(view.x * 0.235, view.y * 0.52)
	var gap := view.x * 0.035
	var total := card.x * _roster.size() + gap * (_roster.size() - 1)
	var x := (view.x - total) * 0.5
	var y := view.y * 0.215
	_card_rects.clear()
	for i in _roster.size():
		var rect := Rect2(x + (card.x + gap) * i, y, card.x, card.y)
		_card_rects.append(rect)
		_draw_card(rect, _roster[i], i == cursor and phase == Phase.SELECT,
				view)


func _draw_card(rect: Rect2, entry: Roster.Entry, active: bool,
		view: Vector2) -> void:
	# A locked wrestler keeps his card lit and gets a chip, so a player can
	# see who player 1 took while choosing the opponent.
	var lock_index := -1
	for i in picks.size():
		if (picks[i] as Roster.Entry).id == entry.id:
			lock_index = i
			break
	var locked := lock_index >= 0
	var body := rect
	if active:
		# The selected card rises. Motion is the cheapest way to say "this
		# one" on a screen with no sound.
		body.position.y -= view.y * 0.012 + sin(_time * 3.0) * view.y * 0.004
	var accent: Color = entry.attire_accent

	if active or locked:
		TitleArt.draw_glow(self, _glow, body.position + body.size * 0.5,
				body.size.x * 2.0,
				Color(accent.r, accent.g, accent.b, 0.22 if active else 0.12))
	TitleArt.draw_cut_panel(self, body, body.size.x * 0.11,
			Color(0.055, 0.060, 0.078, 0.94),
			accent if (active or locked) else Color(0.26, 0.29, 0.36, 0.85),
			maxf(1.0, view.y * (0.0028 if active else 0.0014)))

	# Portrait plate: a monogram over the wrestler's own colourway. There are
	# no portrait renders in the project, and a card with an empty box on it
	# is worse than a card that owns the space it has.
	var pad := body.size.x * 0.075
	var plate := Rect2(body.position + Vector2(pad, pad),
			Vector2(body.size.x - pad * 2.0, body.size.y * 0.46))
	TitleArt.draw_cut_panel(self, plate, plate.size.x * 0.13,
			accent.darkened(0.78).lerp(Color(0.03, 0.035, 0.05), 0.35))
	var mono_size := int(plate.size.y * 0.72)
	var mono := entry.initials()
	var mw := TitleArt.tracked_width(_font, mono, mono_size, plate.size.x * 0.02)
	TitleArt.draw_tracked(self, _font,
			Vector2(plate.position.x + (plate.size.x - mw) * 0.5,
					plate.position.y + plate.size.y * 0.80),
			mono, mono_size, plate.size.x * 0.02,
			Color(accent.r, accent.g, accent.b, 0.92))
	# A diagonal sash across the plate, in the accent, so the two portraits
	# differ in shape and not only in letters.
	draw_colored_polygon(PackedVector2Array([
			plate.position + Vector2(0.0, plate.size.y * 0.72),
			plate.position + Vector2(plate.size.x * 0.42, plate.size.y),
			plate.position + Vector2(0.0, plate.size.y),
		]), Color(accent.r, accent.g, accent.b, 0.55))

	var first_size := int(body.size.y * 0.045)
	var last_size := int(body.size.y * 0.082)
	var text_x := body.position.x + pad
	var name_y := plate.position.y + plate.size.y + body.size.y * 0.10
	TitleArt.draw_tracked(self, _font, Vector2(text_x, name_y),
			entry.first_name, first_size, body.size.x * 0.012,
			TitleArt.STEEL_DIM)
	TitleArt.draw_tracked(self, _font,
			Vector2(text_x, name_y + last_size * 1.05), entry.last_name,
			last_size, body.size.x * 0.006, TitleArt.STEEL)
	TitleArt.draw_tracked(self, _font,
			Vector2(text_x, name_y + last_size * 1.05 + body.size.y * 0.055),
			entry.tagline, int(body.size.y * 0.030), body.size.x * 0.008,
			Color(accent.r, accent.g, accent.b, 0.85))

	var bar_y := body.position.y + body.size.y - pad - body.size.y * 0.135
	var stats := [["POWER", entry.power], ["SPEED", entry.speed],
			["TECH", entry.technique]]
	for i in stats.size():
		var row: Array = stats[i]
		var ry := bar_y + body.size.y * 0.048 * i
		var label_size := int(body.size.y * 0.026)
		TitleArt.draw_tracked(self, _font, Vector2(text_x, ry + label_size),
				row[0], label_size, body.size.x * 0.006,
				Color(0.45, 0.49, 0.58))
		var track_x := text_x + body.size.x * 0.28
		var track_w := body.size.x - body.size.x * 0.28 - pad * 2.5
		var track_h := body.size.y * 0.016
		draw_rect(Rect2(track_x, ry + label_size * 0.35, track_w, track_h),
				Color(0.14, 0.15, 0.19))
		draw_rect(Rect2(track_x, ry + label_size * 0.35,
				track_w * float(row[1]), track_h), accent)

	if locked:
		var chip := Rect2(body.position + Vector2(body.size.x * 0.62,
				-view.y * 0.018), Vector2(body.size.x * 0.30, view.y * 0.036))
		var chip_color := Color(0.35, 0.62, 0.95) if lock_index == 0 \
				else Color(0.93, 0.55, 0.18)
		TitleArt.draw_clipped_panel(self, chip, chip.size.y * 0.42, chip_color)
		var chip_text := "P1" if lock_index == 0 else "CPU"
		var cs := int(chip.size.y * 0.62)
		var cw := TitleArt.tracked_width(_font, chip_text, cs,
				chip.size.x * 0.02)
		TitleArt.draw_tracked(self, _font,
				Vector2(chip.position.x + (chip.size.x - cw) * 0.5,
						chip.position.y + chip.size.y * 0.72),
				chip_text, cs, chip.size.x * 0.02, Color(1, 1, 1))


func _draw_versus(view: Vector2) -> void:
	# A quick wipe in from black, then the card sits until the match loads.
	var t := clampf(_versus_time / 0.28, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.72 * t))
	var band_h := view.y * 0.22
	var band := Rect2(0.0, view.y * 0.5 - band_h * 0.5, view.x * t, band_h)
	draw_rect(band, Color(0.05, 0.055, 0.075, 0.92))
	draw_rect(Rect2(band.position, Vector2(band.size.x, maxf(1.0,
			view.y * 0.002))), TitleArt.CRIMSON)
	draw_rect(Rect2(band.position.x, band.position.y + band_h,
			band.size.x, maxf(1.0, view.y * 0.002)), TitleArt.CRIMSON)
	if t < 1.0:
		return
	var name_size := int(view.y * 0.052)
	var left: Roster.Entry = picks[0]
	var right: Roster.Entry = picks[1]
	var lw := TitleArt.tracked_width(_font, left.display_name(), name_size,
			view.y * 0.008)
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x * 0.44 - lw, view.y * 0.5 + name_size * 0.35),
			left.display_name(), name_size, view.y * 0.008, TitleArt.STEEL)
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x * 0.56, view.y * 0.5 + name_size * 0.35),
			right.display_name(), name_size, view.y * 0.008, TitleArt.STEEL)
	var vs_size := int(view.y * 0.085)
	var vw := TitleArt.tracked_width(_font, "VS", vs_size, view.y * 0.004)
	TitleArt.draw_glow(self, _glow, Vector2(view.x * 0.5, view.y * 0.5),
			view.x * 0.16, Color(0.83, 0.13, 0.16, 0.55))
	TitleArt.draw_tracked(self, _font,
			Vector2((view.x - vw) * 0.5, view.y * 0.5 + vs_size * 0.35), "VS",
			vs_size, view.y * 0.004, Color(1, 1, 1))
