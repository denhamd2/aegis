class_name PostMatchMenu
extends CanvasLayer
## What comes after the rating: rematch, change wrestlers, back to the title,
## or quit (desktop). Shown by MatchSetup when PostMatch finishes; same face,
## colours and controls as the title screen (ui_up/ui_down/ui_accept, mouse).
##
## The same menu is the PAUSE menu (`pause_mode`, MatchSetup on Escape): the
## match stops, and the choice is resume, restart the match from the bell,
## the title screen, or quit (desktop). Escape again resumes.

const TITLE_SCENE := "res://scenes/title.tscn"
const REMATCH := "REMATCH"
const CHANGE := "CHANGE WRESTLERS"
const TITLE := "TITLE SCREEN"
const QUIT := "QUIT"
const RESUME := "RESUME"
const RESTART := "RESTART MATCH"

## Shown over a match in progress: the tree is paused while it is up.
var pause_mode := false

var options: Array[String] = []
var index := 0
var _view: _Panel


func _ready() -> void:
	layer = 20
	if pause_mode:
		# Runs while the match it paused does not.
		process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().paused = true
		options = [RESUME, RESTART, TITLE]
	else:
		options = [REMATCH, CHANGE, TITLE]
	if not OS.has_feature("web"):
		options.append(QUIT)
	_view = _Panel.new()
	_view.menu = self
	add_child(_view)


func _unhandled_input(event: InputEvent) -> void:
	if pause_mode and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		choose(RESUME)
		return
	if event.is_action_pressed("ui_down"):
		index = wrapi(index + 1, 0, options.size())
	elif event.is_action_pressed("ui_up"):
		index = wrapi(index - 1, 0, options.size())
	elif event.is_action_pressed("ui_accept"):
		choose(options[index])
	else:
		return
	get_viewport().set_input_as_handled()
	_view.queue_redraw()


func choose(option: String) -> void:
	var tree := get_tree()
	# Never leave the next scene paused.
	if pause_mode:
		tree.paused = false
	match option:
		RESUME:
			pass
		RESTART:
			# The same two men from the bell -- no entrances a second time.
			if not TitleScreen.rematch(tree, false):
				tree.reload_current_scene()
		REMATCH:
			if not TitleScreen.rematch(tree):
				tree.change_scene_to_file(TITLE_SCENE)
		CHANGE:
			TitleScreen.resume_select = true
			tree.change_scene_to_file(TITLE_SCENE)
		TITLE:
			tree.change_scene_to_file(TITLE_SCENE)
		QUIT:
			tree.quit()
	queue_free()


class _Panel extends Control:
	var menu: PostMatchMenu
	var _font: Font
	var _rects: Array[Rect2] = []

	func _ready() -> void:
		_font = TitleArt.teko(700)
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func _gui_input(event: InputEvent) -> void:
		if not event is InputEventMouse:
			return
		for i in _rects.size():
			if not _rects[i].has_point((event as InputEventMouse).position):
				continue
			if event is InputEventMouseMotion and menu.index != i:
				menu.index = i
				queue_redraw()
			elif event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT:
				menu.index = i
				menu.choose(menu.options[i])

	func _draw() -> void:
		var view := size
		draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.55))
		var w := view.x * 0.34
		var row := view.y * 0.075
		var h := row * (menu.options.size() + 1.2)
		var at := Vector2((view.x - w) * 0.5, (view.y - h) * 0.5)
		draw_rect(Rect2(at, Vector2(w, h)), Color(TitleArt.KEY_PANEL, 0.94))
		draw_rect(Rect2(at, Vector2(w, maxf(1.0, view.y * 0.003))), TitleArt.KEY_GOLD)
		var size_px := int(view.y * 0.045)
		_rects.clear()
		for i in menu.options.size():
			var text: String = menu.options[i]
			var y := at.y + row * (i + 0.9)
			var r := Rect2(at.x, y - row * 0.6, w, row)
			_rects.append(r)
			var active := i == menu.index
			if active:
				draw_rect(r, Color(TitleArt.KEY_VIOLET, 0.35))
			var tw := TitleArt.tracked_width(_font, text, size_px, view.y * 0.003)
			TitleArt.draw_tracked(self, _font, Vector2((view.x - tw) * 0.5,
					y + size_px * 0.3), text, size_px, view.y * 0.003,
					TitleArt.KEY_GOLD if active else TitleArt.STEEL)
