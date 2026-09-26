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

## The owner-supplied key art every phase is drawn over: wordmark top centre,
## a wrestler either side pointing in, a dark arena in between.
## Credited in assets/ui/CREDITS.md.
const KEY_ART := "res://assets/ui/title_key_art.png"

## Where the UI may go, in 0..1 image coordinates: under the wordmark, inside
## the two wrestlers' outstretched arms, above the smoke. Measured on the
## 1672x941 art -- the wordmark ends at y 335, the left wrestler's reach at
## x 420, the right one's at x 1265, and the floor's hot reflections start at
## y 790. The layout below is placed in this box, so nothing lands on a face
## or on the logo at any window shape.
const SAFE_ART := Rect2(0.265, 0.385, 0.47, 0.45)

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
var _key_art: Texture2D
var _glow: Texture2D
var _vignette: Texture2D
## x fraction, y fraction, size/speed weight.
var _motes: Array = []
## Filled during _draw so the mouse can hit-test what was actually drawn.
var _menu_rects: Array = []
var _card_rects: Array = []


func _ready() -> void:
	# Teko Bold, the broadcast graphics' face -- see TitleArt.teko().
	_font = TitleArt.teko(700)
	_backdrop = TitleArt.make_backdrop_texture()
	_key_art = load(KEY_ART) as Texture2D
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
	# A match launched from the menu opens with the ring entrances. Set here
	# rather than in configure_match(), which the headless probes call to set
	# up matches they need live on tick 1.
	scene.entrances = true
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
		wrestler.entrance_subtitle = entry.entrance_subtitle()
		wrestler.entrance_style = entry.id
		wrestler.attire_body = entry.attire_body
		wrestler.attire_accent = entry.attire_accent
		# His own finisher, if he has one. Before add_child() like the rest, so
		# the controller has it from its first tick.
		wrestler.finisher_move = load(entry.finisher) as MoveDef \
				if entry.finisher != "" else null
		# And his own signature, joining the shared draw. A fresh array: the
		# pool match.tscn assigns is one resource shared by both slots, and
		# appending to it would hand Roman's punch to Cody as well.
		var pool: Array[MoveDef] = wrestler.signature_move_pool.duplicate()
		wrestler.own_signature = null
		if entry.signature != "":
			wrestler.own_signature = load(entry.signature) as MoveDef
			pool.append(wrestler.own_signature)
		wrestler.signature_move_pool = pool
	if "match_seed" in scene:
		scene.match_seed = match_seed


## --- Drawing ---------------------------------------------------------------

func _draw() -> void:
	var view := size
	if view.x <= 0.0 or view.y <= 0.0:
		return
	draw_texture_rect(_backdrop, Rect2(Vector2.ZERO, view), false)
	if _key_art != null:
		draw_texture_rect(_key_art, art_rect(view), false)
	else:
		# The procedural hall the screen shipped with, if the art is missing.
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

	if _key_art == null:
		draw_texture_rect(_vignette, Rect2(Vector2.ZERO, view), false)
	_draw_chrome(view)
	if _fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, _fade))


## Where the key art is drawn: scaled to COVER the view, centred, so it keeps
## its proportions at any window shape and a tall window crops the outer
## edges of the wrestlers rather than squashing them.
func art_rect(view: Vector2) -> Rect2:
	if _key_art == null:
		return Rect2(Vector2.ZERO, view)
	var art := Vector2(_key_art.get_width(), _key_art.get_height())
	var scale := maxf(view.x / art.x, view.y / art.y)
	var drawn := art * scale
	return Rect2((view - drawn) * 0.5, drawn)


## The UI's box in view pixels: SAFE_ART mapped through art_rect(), then kept
## on screen.
func safe_rect(view: Vector2) -> Rect2:
	var art := art_rect(view)
	var box := Rect2(art.position + SAFE_ART.position * art.size,
			SAFE_ART.size * art.size)
	return box.intersection(Rect2(Vector2.ZERO, view))


## Build tag and hint line -- the frame around every phase.
func _draw_chrome(view: Vector2) -> void:
	var small := int(maxf(12.0, view.y * 0.022))
	if _key_art != null:
		# The art's bottom edge is white smoke, and the hint line was
		# unreadable on it: a dark footer strip, fading up into the art.
		var strip := view.y * 0.085
		draw_rect(Rect2(0.0, view.y - strip * 0.62, view.x, strip * 0.62),
				Color(TitleArt.KEY_PANEL, 0.80))
		draw_rect(Rect2(0.0, view.y - strip, view.x, strip * 0.38),
				Color(TitleArt.KEY_PANEL, 0.35))
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x * 0.035, view.y * 0.955), "AEGIS BUILD", small,
			view.y * 0.002, TitleArt.KEY_GOLD_DIM)
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
	var w := TitleArt.tracked_width(_font, hint, small, view.y * 0.002)
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x - w - view.x * 0.035, view.y * 0.955), hint, small,
			view.y * 0.002, TitleArt.KEY_GOLD_DIM)


func _draw_title(view: Vector2) -> void:
	var safe := safe_rect(view)
	if _key_art == null:
		# No art: the drawn wordmark the screen shipped with.
		TitleArt.draw_logo(self, _font, Vector2(view.x * 0.5, view.y * 0.30),
				view.y, _time)
	# The art carries the wordmark, so the menu starts under it: a column of
	# plates centred in the dark space between the two wrestlers.
	var unit := safe.size.y
	var row_h := unit * 0.165
	var row_w := minf(safe.size.x * 0.52, unit * 1.05)
	var top := safe.position.y + unit * 0.20
	var size_px := int(row_h * 0.58)
	_menu_rects.clear()
	for i in _menu.size():
		var rect := Rect2(safe.get_center().x - row_w * 0.5, top + row_h * i,
				row_w, row_h * 0.80)
		_menu_rects.append(rect)
		var selected := i == menu_index
		var label: String = _menu[i]
		var track := row_h * 0.045
		var text_w := TitleArt.tracked_width(_font, label, size_px, track)
		var baseline := rect.position.y + rect.size.y * 0.67
		var line := maxf(1.0, view.y * 0.0016)
		if selected:
			# The cursor is the art's gold, flanked by its violet and teal --
			# the two corners of the key art meeting on the row you're on. It
			# pulses so the screen never freezes when nobody is touching it.
			var pulse := 0.82 + 0.18 * sin(_time * 3.4)
			var c := rect.position + rect.size * 0.5
			TitleArt.draw_glow(self, _glow, c - Vector2(row_w * 0.42, 0.0),
					row_w * 0.9, Color(TitleArt.KEY_VIOLET, 0.30 * pulse))
			TitleArt.draw_glow(self, _glow, c + Vector2(row_w * 0.42, 0.0),
					row_w * 0.9, Color(TitleArt.KEY_TEAL, 0.26 * pulse))
			TitleArt.draw_clipped_panel(self, rect, rect.size.y * 0.42,
					Color(TitleArt.KEY_GOLD, 0.95), Color(1, 0.95, 0.8, 0.6),
					line)
			TitleArt.draw_tracked(self, _font,
					Vector2(rect.position.x + (row_w - text_w) * 0.5, baseline),
					label, size_px, track, TitleArt.INK_DEEP)
		else:
			TitleArt.draw_clipped_panel(self, rect, rect.size.y * 0.42,
					Color(TitleArt.KEY_PANEL, 0.72),
					Color(TitleArt.KEY_GOLD_DIM, 0.55), line)
			TitleArt.draw_tracked(self, _font,
					Vector2(rect.position.x + (row_w - text_w) * 0.5, baseline),
					label, size_px, track, TitleArt.STEEL)


## The bindings, read off the InputMap so the card cannot go stale.
func _draw_controls(view: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.72))
	var panel := Rect2(view.x * 0.28, view.y * 0.20, view.x * 0.44,
			view.y * 0.60)
	TitleArt.draw_cut_panel(self, panel, view.y * 0.035,
			Color(TitleArt.KEY_PANEL, 0.96), Color(TitleArt.KEY_GOLD_DIM, 0.8),
			maxf(1.0, view.y * 0.0018))
	var head_size := int(view.y * 0.044)
	TitleArt.draw_tracked(self, _font,
			panel.position + Vector2(view.x * 0.030, view.y * 0.070),
			"CONTROLS", head_size, view.y * 0.004, TitleArt.KEY_GOLD)
	draw_rect(Rect2(panel.position + Vector2(view.x * 0.030, view.y * 0.085),
			Vector2(panel.size.x - view.x * 0.060, maxf(1.0, view.y * 0.002))),
			TitleArt.KEY_GOLD)

	var row_size := int(view.y * 0.032)
	var y := panel.position.y + view.y * 0.135
	for row: Array in CONTROL_ROWS:
		TitleArt.draw_tracked(self, _font,
				Vector2(panel.position.x + view.x * 0.030, y), row[0],
				row_size, view.y * 0.002, TitleArt.STEEL_DIM)
		var keys := _binding_labels(row[1])
		var kw := TitleArt.tracked_width(_font, keys, row_size, view.y * 0.002)
		TitleArt.draw_tracked(self, _font,
				Vector2(panel.position.x + panel.size.x - view.x * 0.030 - kw,
						y), keys, row_size, view.y * 0.002, TitleArt.STEEL)
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
	var safe := safe_rect(view)
	var unit := safe.size.y
	var head_size := int(unit * 0.105)
	var head := "SELECT YOUR WRESTLER"
	var hw := TitleArt.tracked_width(_font, head, head_size, unit * 0.010)
	TitleArt.draw_tracked(self, _font,
			Vector2(safe.get_center().x - hw * 0.5,
					safe.position.y + unit * 0.075),
			head, head_size, unit * 0.010, TitleArt.KEY_GOLD)

	var side := "PLAYER 1" if picks.is_empty() else "OPPONENT  ·  CPU"
	# Player 1 in the left wrestler's violet, the CPU in the right one's teal:
	# the art already says which side is which.
	var side_color := TitleArt.KEY_VIOLET.lightened(0.25) if picks.is_empty() \
			else TitleArt.KEY_TEAL
	var side_size := int(unit * 0.062)
	var sw := TitleArt.tracked_width(_font, side, side_size, unit * 0.010)
	if phase == Phase.SELECT:
		TitleArt.draw_tracked(self, _font,
				Vector2(safe.get_center().x - sw * 0.5,
						safe.position.y + unit * 0.155),
				side, side_size, unit * 0.010, side_color)

	# The cards share the safe box's width; their height follows from a
	# portrait card's proportions and is capped by the box.
	var gap := safe.size.x * 0.03
	var n := float(_roster.size())
	var card_w := (safe.size.x - gap * (n - 1.0)) / n
	var card := Vector2(card_w, minf(card_w * 1.62, unit * 0.76))
	var x := safe.position.x
	var y := safe.position.y + unit * 0.22
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
			Color(TitleArt.KEY_PANEL, 0.90),
			accent if (active or locked) else Color(TitleArt.KEY_GOLD_DIM, 0.7),
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

	var first_size := int(body.size.y * 0.060)
	var last_size := int(body.size.y * 0.115)
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
			entry.tagline, int(body.size.y * 0.042), body.size.x * 0.004,
			Color(accent.r, accent.g, accent.b, 0.85))

	var bar_y := body.position.y + body.size.y - pad - body.size.y * 0.135
	var stats := [["POWER", entry.power], ["SPEED", entry.speed],
			["TECH", entry.technique]]
	for i in stats.size():
		var row: Array = stats[i]
		var ry := bar_y + body.size.y * 0.048 * i
		var label_size := int(body.size.y * 0.036)
		TitleArt.draw_tracked(self, _font, Vector2(text_x, ry + label_size),
				row[0], label_size, body.size.x * 0.006,
				TitleArt.KEY_GOLD_DIM)
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
		var chip_color := TitleArt.KEY_VIOLET if lock_index == 0 \
				else TitleArt.KEY_TEAL.darkened(0.2)
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
	draw_rect(band, Color(TitleArt.KEY_PANEL, 0.92))
	draw_rect(Rect2(band.position, Vector2(band.size.x, maxf(1.0,
			view.y * 0.002))), TitleArt.KEY_GOLD)
	draw_rect(Rect2(band.position.x, band.position.y + band_h,
			band.size.x, maxf(1.0, view.y * 0.002)), TitleArt.KEY_GOLD)
	if t < 1.0:
		return
	var name_size := int(view.y * 0.075)
	var left: Roster.Entry = picks[0]
	var right: Roster.Entry = picks[1]
	var lw := TitleArt.tracked_width(_font, left.display_name(), name_size,
			view.y * 0.003)
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x * 0.44 - lw, view.y * 0.5 + name_size * 0.35),
			left.display_name(), name_size, view.y * 0.003, TitleArt.STEEL)
	TitleArt.draw_tracked(self, _font,
			Vector2(view.x * 0.56, view.y * 0.5 + name_size * 0.35),
			right.display_name(), name_size, view.y * 0.003, TitleArt.STEEL)
	var vs_size := int(view.y * 0.085)
	var vw := TitleArt.tracked_width(_font, "VS", vs_size, view.y * 0.004)
	TitleArt.draw_glow(self, _glow, Vector2(view.x * 0.46, view.y * 0.5),
			view.x * 0.16, Color(TitleArt.KEY_VIOLET, 0.50))
	TitleArt.draw_glow(self, _glow, Vector2(view.x * 0.54, view.y * 0.5),
			view.x * 0.16, Color(TitleArt.KEY_TEAL, 0.42))
	TitleArt.draw_tracked(self, _font,
			Vector2((view.x - vw) * 0.5, view.y * 0.5 + vs_size * 0.35), "VS",
			vs_size, view.y * 0.004, TitleArt.KEY_GOLD)
