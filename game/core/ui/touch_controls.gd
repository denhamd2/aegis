class_name TouchControls
extends CanvasLayer
## On-screen controls for a phone (the Android build): a thumbstick on the
## left for movement and the five action buttons on the right, plus SKIP top
## right (entrances, replays). They press the same InputMap actions the
## keyboard and pad do -- Input.action_press / action_release -- so nothing
## in the match knows a touchscreen from a controller.
##
## Shown only where there is a touchscreen and a human in the match
## (`wanted()`); the menus need nothing, because Godot turns taps into mouse
## clicks and the title screen already takes clicks.

## [action, label, held] -- held buttons stay down while the finger does
## (run, the submission hold); the rest are taps.
const BUTTONS := [["strike", "STRIKE", false], ["grapple", "GRAPPLE", false],
		["reversal", "REVERSE", false], ["run", "RUN", true],
		["submission_hold", "HOLD", true]]
const STICK_ACTIONS := ["move_left", "move_right", "move_up", "move_down"]
## Fractions of the viewport's height, so it scales to any phone.
const STICK_RADIUS := 0.13
const STICK_DEAD := 0.18
const BUTTON_RADIUS := 0.072

var _pad: _Pad


## A phone with a human player on it: touchscreen present (or forced with
## --touch on the command line, for testing on a desktop).
static func wanted(any_human: bool) -> bool:
	if not any_human:
		return false
	return DisplayServer.is_touchscreen_available() \
			or Array(OS.get_cmdline_user_args()).has("--touch")


func _ready() -> void:
	layer = 20
	_pad = _Pad.new()
	add_child(_pad)


## The button layout for a viewport of `size`: [action, label, held, centre,
## radius] per button, then the stick's [centre, radius].
static func layout(size: Vector2) -> Dictionary:
	var u := size.y
	var r := BUTTON_RADIUS * u
	var base := Vector2(size.x - u * 0.16, size.y - u * 0.18)
	# An arc of buttons round the right thumb.
	var spots := [base, base + Vector2(-r * 2.3, -r * 0.5), base + Vector2(-r * 0.6, -r * 2.3),
			base + Vector2(-r * 2.9, -r * 2.6), base + Vector2(-r * 4.4, -r * 0.2)]
	var buttons := []
	for i in BUTTONS.size():
		buttons.append(BUTTONS[i] + [spots[i], r])
	return {"buttons": buttons,
			"stick": [Vector2(u * 0.22, size.y - u * 0.22), STICK_RADIUS * u],
			"skip": Rect2(size.x - u * 0.2, u * 0.03, u * 0.17, u * 0.08)}


## The four move actions' strengths for a stick deflection `v` (-1..1 each
## axis), with a dead zone.
static func stick_strengths(v: Vector2) -> Dictionary:
	var out := {}
	var mag := v.length()
	if mag < STICK_DEAD:
		v = Vector2.ZERO
	elif mag > 1.0:
		v /= mag
	out["move_left"] = maxf(-v.x, 0.0)
	out["move_right"] = maxf(v.x, 0.0)
	out["move_up"] = maxf(-v.y, 0.0)
	out["move_down"] = maxf(v.y, 0.0)
	return out


class _Pad extends Control:
	var _stick_finger := -1
	var _stick_at := Vector2.ZERO
	## finger index -> action it holds
	var _fingers := {}

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _input(event: InputEvent) -> void:
		var lay := TouchControls.layout(get_viewport_rect().size)
		if event is InputEventScreenTouch:
			var t := event as InputEventScreenTouch
			if t.pressed:
				var stick: Array = lay["stick"]
				if t.position.distance_to(stick[0]) < float(stick[1]) * 1.6:
					_stick_finger = t.index
					_move_stick(t.position, lay)
					get_viewport().set_input_as_handled()
					return
				if (lay["skip"] as Rect2).has_point(t.position):
					_tap("ui_accept")
					get_viewport().set_input_as_handled()
					return
				for b: Array in lay["buttons"]:
					if t.position.distance_to(b[3]) < float(b[4]) * 1.15:
						_fingers[t.index] = b[0]
						Input.action_press(b[0])
						if not b[2]:
							_release_soon(b[0])
						get_viewport().set_input_as_handled()
						queue_redraw()
						return
			else:
				if t.index == _stick_finger:
					_stick_finger = -1
					_stick_at = Vector2.ZERO
					for a: String in TouchControls.STICK_ACTIONS:
						Input.action_release(a)
					queue_redraw()
				elif _fingers.has(t.index):
					Input.action_release(_fingers[t.index])
					_fingers.erase(t.index)
					queue_redraw()
		elif event is InputEventScreenDrag:
			var d := event as InputEventScreenDrag
			if d.index == _stick_finger:
				_move_stick(d.position, lay)
				get_viewport().set_input_as_handled()

	func _move_stick(at: Vector2, lay: Dictionary) -> void:
		var stick: Array = lay["stick"]
		_stick_at = ((at - (stick[0] as Vector2)) / float(stick[1])).limit_length(1.0)
		var s := TouchControls.stick_strengths(_stick_at)
		for a: String in s:
			if s[a] > 0.0:
				Input.action_press(a, s[a])
			else:
				Input.action_release(a)
		queue_redraw()

	## A tap is a press for two physics ticks, so is_action_just_pressed in
	## _physics_process sees it whatever the frame rate.
	func _release_soon(action: String) -> void:
		await get_tree().physics_frame
		await get_tree().physics_frame
		if not _fingers.values().has(action):
			Input.action_release(action)

	func _tap(action: String) -> void:
		Input.action_press(action)
		_release_soon(action)

	func _draw() -> void:
		var lay := TouchControls.layout(get_viewport_rect().size)
		var font := ThemeDB.fallback_font
		var stick: Array = lay["stick"]
		var c: Vector2 = stick[0]
		var r: float = stick[1]
		draw_circle(c, r, Color(0.05, 0.05, 0.07, 0.35))
		draw_arc(c, r, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		draw_circle(c + _stick_at * r, r * 0.42, Color(1, 1, 1, 0.45))
		for b: Array in lay["buttons"]:
			var down := _fingers.values().has(b[0])
			var bc: Vector2 = b[3]
			var br: float = b[4]
			draw_circle(bc, br, Color(1.0, 0.8, 0.24, 0.55) if down else Color(0.05, 0.05, 0.07, 0.45))
			draw_arc(bc, br, 0.0, TAU, 40, Color(1.0, 0.8, 0.24, 0.8), 3.0, true)
			var fs := int(br * 0.34)
			draw_string(font, bc + Vector2(-br, fs * 0.35), b[1], HORIZONTAL_ALIGNMENT_CENTER,
					br * 2.0, fs, Color(1, 1, 1, 0.9))
		var skip: Rect2 = lay["skip"]
		draw_rect(skip, Color(0.05, 0.05, 0.07, 0.45))
		draw_string(font, skip.position + Vector2(0, skip.size.y * 0.68), "SKIP",
				HORIZONTAL_ALIGNMENT_CENTER, skip.size.x, int(skip.size.y * 0.5), Color(1, 1, 1, 0.85))
