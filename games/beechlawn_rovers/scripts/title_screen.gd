extends Control
## A static reference-led campaign image with native, keyboard-accessible UI.
const INK := Color("07101f")
const PAPER := Color("f5f5ed")
const MUTED := Color("b5c1d2")
const BLUE := Color("2159ee")
const LIME := Color("d5fa74")
const BODY := preload("res://assets/ui/fonts/BarlowSemiCondensed-Regular.ttf")
const BOLD := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const DISPLAY := preload("res://assets/ui/fonts/Anton-Regular.ttf")
var canvas: Control
var options_layer: ColorRect
var play_button: Button
var watch_button: Button
var start_button: Button
var options_button: Button
var close_button: Button
var volume_slider: HSlider
var volume_label: Label
var fullscreen_toggle: CheckButton
var camera_select: OptionButton
var intro_toggle: CheckButton
var mode_description: Label
var loading := false
var selected_mode := 0

func _ready() -> void:
	if OS.has_feature("web") and OS.has_feature("debug"):
		Engine.max_fps = 0
	var background := ColorRect.new()
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var art := TextureRect.new()
	art.texture = preload("res://assets/ui/title_key_art.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Fit the complete campaign image to the same aspect as the menu canvas:
	# covered cropping cut off the second portrait in 4:3 windows.
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# A transparent left-to-right wash protects text on ultra-wide aspect ratios.
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.02,0.04,0.09,0.72),Color(0.02,0.04,0.09,0.3),Color(0.02,0.04,0.09,0)])
	gradient.offsets = PackedFloat32Array([0.0,0.4,0.7])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	var wash := TextureRect.new()
	wash.texture = texture
	wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wash)
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas = Control.new()
	canvas.name = "MenuCanvas"
	add_child(canvas)
	canvas.size = Vector2(1600,900)
	_build_main()
	_build_options()
	resized.connect(_layout_canvas)
	_layout_canvas()
	_select_mode(MatchSession.mode)
	start_button.grab_focus()
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_MENU_READY = true; window.BEECHLAWN_MATCH_READY = false; window.BEECHLAWN_MATCH_STARTED = false; window.BEECHLAWN_INTRO_ACTIVE = false; window.BEECHLAWN_INTRO_DONE = false")
	print("BEECHLAWN_MENU_READY")

func _layout_canvas() -> void:
	var factor := minf(size.x/1600.0, size.y/900.0)
	canvas.scale = Vector2.ONE * factor
	canvas.position = (size - Vector2(1600,900)*factor)*0.5

func _build_main() -> void:
	var crest := TextureRect.new()
	var crest_atlas := AtlasTexture.new()
	crest_atlas.atlas = preload("res://assets/ui/club_crest_source.jpg")
	# Display the original uploaded crest, removing only its large white margins.
	# Keep the native 692:974 aspect instead of stretching it into a round badge.
	crest_atlas.region = Rect2(294,134,692,974)
	crest_atlas.filter_clip = true
	crest.texture = crest_atlas
	crest.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var crest_material := ShaderMaterial.new()
	crest_material.shader = preload("res://assets/ui/club_crest_mask.gdshader")
	crest.material = crest_material
	crest.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crest.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crest.position = Vector2(64,42)
	crest.size = Vector2(68,78)
	canvas.add_child(crest)
	_label(canvas,"BEECHLAWN ROVERS",Vector2(150,53),23,BOLD)
	_label(canvas,"ROOTED IN DUBLIN.  READY FOR SUNDAY.",Vector2(150,87),16,BODY,MUTED)
	_rect(canvas,Rect2(1224,52,312,40),Color(0.02,0.04,0.09,0.7))
	_label(canvas,"KILMORE DRIVE  /  DUBLIN",Vector2(1240,60),19,BOLD)
	_rect(canvas,Rect2(64,169,46,4),LIME)
	_label(canvas,"BEECHLAWN",Vector2(59,190),77,DISPLAY)
	_label(canvas,"ROVERS",Vector2(59,278),105,DISPLAY)
	var year_lockup := Panel.new()
	year_lockup.position = Vector2(395,298)
	year_lockup.size = Vector2(112,70)
	year_lockup.add_theme_stylebox_override("panel",_style(Color(0.025,0.05,0.1,0.88),LIME))
	canvas.add_child(year_lockup)
	var year_label := _label(year_lockup,"27",Vector2(11,-3),68,DISPLAY,LIME)
	year_label.size = Vector2(94,76)
	_label(canvas,"Your club. Your pitch. Your match.",Vector2(65,413),26,BODY,MUTED)
	_label(canvas,"CHOOSE YOUR MATCH",Vector2(65,477),17,BOLD,MUTED)
	play_button = _button(canvas,"PLAY",Rect2(64,513,253,66))
	watch_button = _button(canvas,"WATCH AI vs AI",Rect2(331,513,253,66))
	play_button.name = "PlayMode"
	watch_button.name = "WatchMode"
	play_button.pressed.connect(_select_mode.bind(0))
	watch_button.pressed.connect(_select_mode.bind(1))
	mode_description = _label(canvas,"",Vector2(65,590),20,BODY,MUTED)
	start_button = _button(canvas,"START GAME",Rect2(64,638,520,72),true)
	start_button.name = "StartGame"
	start_button.pressed.connect(_start_match)
	options_button = _button(canvas,"OPTIONS",Rect2(64,726,520,48))
	options_button.name = "Options"
	options_button.pressed.connect(open_options)
	_label(canvas,"DAVID MURRAY  /  5",Vector2(1160,766),19,BOLD)
	_label(canvas,"DEREK MITCHELL  /  3",Vector2(1160,794),17,BODY,MUTED)
	_rect(canvas,Rect2(64,826,1472,1),Color(0.7,0.8,0.9,0.22))
	_label(canvas,"BEECHLAWN ROVERS   vs   BORDEAUX",Vector2(64,845),18,BOLD)
	_label(canvas,"11 v 11   ·   3 MINUTE MATCH",Vector2(602,845),17,BODY,MUTED)
	_label(canvas,"ARROWS  Navigate     ENTER  Select",Vector2(1230,845),17,BODY,MUTED)
	# Explicit keyboard order works independently of directional heuristics.
	var controls: Array[Control] = [play_button,watch_button,start_button,options_button]
	for index in controls.size():
		controls[index].focus_next = controls[index].get_path_to(controls[(index+1)%controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index+controls.size()-1)%controls.size()])

func _build_options() -> void:
	options_layer = ColorRect.new()
	options_layer.name = "OptionsOverlay"
	options_layer.color = Color(0.015,0.025,0.05,0.97)
	options_layer.size = Vector2(1600,900)
	canvas.add_child(options_layer)
	_label(options_layer,"MAKE IT YOUR MATCH",Vector2(100,52),18,BOLD,LIME)
	_label(options_layer,"OPTIONS",Vector2(96,80),62,DISPLAY)
	_label(options_layer,"SOUND & PRESENTATION",Vector2(100,194),20,BOLD,LIME)
	_label(options_layer,"MASTER VOLUME",Vector2(100,244),23,BOLD)
	volume_label = _label(options_layer,"80%",Vector2(640,244),23,BOLD,LIME)
	volume_slider = HSlider.new()
	volume_slider.name = "MasterVolume"
	volume_slider.position = Vector2(100,292)
	volume_slider.size = Vector2(610,34)
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.value = roundi(MatchSession.master_volume*100.0)
	options_layer.add_child(volume_slider)
	volume_slider.value_changed.connect(_volume_changed)
	_volume_changed(volume_slider.value)
	fullscreen_toggle = CheckButton.new()
	fullscreen_toggle.text = "FULLSCREEN"
	fullscreen_toggle.position = Vector2(100,352)
	fullscreen_toggle.size = Vector2(610,52)
	fullscreen_toggle.add_theme_font_override("font",BOLD)
	fullscreen_toggle.add_theme_font_size_override("font_size",23)
	fullscreen_toggle.button_pressed = MatchSession.fullscreen
	options_layer.add_child(fullscreen_toggle)
	fullscreen_toggle.toggled.connect(_fullscreen_changed)
	if OS.has_feature("web"):
		fullscreen_toggle.hide()
		_label(options_layer,"Use your browser's fullscreen control",Vector2(100,368),21,BODY,MUTED)
	intro_toggle = CheckButton.new()
	intro_toggle.name = "PrematchIntro"
	intro_toggle.text = "PRE-MATCH BROADCAST INTRO"
	intro_toggle.position = Vector2(100,438)
	intro_toggle.size = Vector2(610,52)
	intro_toggle.add_theme_font_override("font",BOLD)
	intro_toggle.add_theme_font_size_override("font_size",22)
	intro_toggle.button_pressed = MatchSession.show_intro
	intro_toggle.toggled.connect(func(enabled: bool): MatchSession.show_intro = enabled)
	options_layer.add_child(intro_toggle)
	_label(options_layer,"Walk-on, lineup, player and pitch close-ups.\nSpace or Enter skips straight to kickoff.",Vector2(100,505),21,BODY,MUTED)
	_label(options_layer,"GAMEPLAY CAMERA",Vector2(820,194),20,BOLD,LIME)
	camera_select = OptionButton.new()
	camera_select.name = "GameplayCamera"
	camera_select.position = Vector2(820,244)
	camera_select.size = Vector2(680,52)
	camera_select.add_theme_font_override("font",BOLD)
	camera_select.add_theme_font_size_override("font_size",24)
	var presets := preload("res://scripts/gameplay_camera_presets.gd")
	var ids := presets.PRESETS.keys()
	for id in ids:
		camera_select.add_item(str(presets.PRESETS[id]["name"]))
	camera_select.select(ids.find(MatchSession.camera_preset))
	camera_select.item_selected.connect(func(index: int): MatchSession.camera_preset = ids[index])
	options_layer.add_child(camera_select)
	_presentation_slider("HEIGHT", "camera_height", 324, -4.0, 12.0, 0.5, 1.0, " m")
	_presentation_slider("ZOOM", "camera_zoom", 412, -100.0, 100.0, 5.0, 100.0, "%")
	_presentation_slider("ANGLE", "camera_angle", 500, -20.0, 20.0, 1.0, 1.0, "°")
	_rect(options_layer,Rect2(100,610,1400,1),Color(0.5,0.6,0.8,0.25))
	_label(options_layer,"KEYBOARD CONTROLS",Vector2(100,638),19,BOLD,LIME)
	_label(options_layer,"W A S D  Move    SHIFT  Sprint    CTRL  Close control    E  Pass    Q  Through ball    SPACE  Shoot\nF  Tackle    G  Slide    TAB  Switch player    C  Camera    ESC  Title    F3  Debug",Vector2(100,676),22,BODY,PAPER)
	close_button = _button(options_layer,"SAVE & BACK",Rect2(100,790,1400,62),true)
	close_button.name = "SaveOptions"
	close_button.pressed.connect(close_options)
	options_layer.hide()

func _presentation_slider(title: String, field: String, y: float, minimum: float,
		maximum: float, increment: float, scale_value: float, unit: String) -> void:
	_label(options_layer,title,Vector2(820,y),19,BOLD)
	var value: float = float(MatchSession.get(field)) * scale_value
	var value_label := _label(options_layer,"%.1f%s" % [value,unit],Vector2(1400,y),19,BOLD,LIME)
	var slider := HSlider.new()
	slider.name = field
	slider.position = Vector2(820,y+35)
	slider.size = Vector2(680,28)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.value = value
	slider.value_changed.connect(func(new_value: float):
		MatchSession.set(field,new_value/scale_value)
		value_label.text = "%.1f%s" % [new_value,unit])
	options_layer.add_child(slider)

func _select_mode(value: int) -> void:
	selected_mode = value
	for index in 2:
		var button := play_button if index == 0 else watch_button
		button.add_theme_stylebox_override("normal",_style(Color("163c9c") if index == value else Color(0.025,0.05,0.1,0.8),LIME if index == value else Color("3c4d69")))
		button.add_theme_color_override("font_color",LIME if index == value else PAPER)
	mode_description.text = "Take control of Beechlawn Rovers. Keyboard vs AI." if value == 0 else "Sit back. Both teams play a fully AI-controlled match."

func open_options() -> void:
	if loading:
		return
	options_layer.show()
	for button in [play_button,watch_button,start_button,options_button]:
		button.focus_mode = Control.FOCUS_NONE
	volume_slider.grab_focus()

func close_options() -> void:
	if MatchSession.save_preferences() != OK:
		close_button.text = "COULD NOT SAVE — TRY AGAIN"
		return
	options_layer.hide()
	for button in [play_button,watch_button,start_button,options_button]:
		button.focus_mode = Control.FOCUS_ALL
	options_button.grab_focus()

func _volume_changed(value: float) -> void:
	MatchSession.master_volume = value/100.0
	AudioServer.set_bus_volume_linear(0,MatchSession.master_volume)
	volume_label.text = "%d%%" % roundi(value)

func _fullscreen_changed(enabled: bool) -> void:
	MatchSession.fullscreen = enabled
	MatchSession.apply_preferences()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and options_layer.visible:
		close_options()
		get_viewport().set_input_as_handled()

func _start_match() -> void:
	if loading or options_layer.visible:
		return
	loading = true
	MatchSession.mode = selected_mode
	MatchSession.launched_from_menu = true
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.BEECHLAWN_MENU_READY = false")
	start_button.text = "PREPARING MATCH…"
	for button in [play_button,watch_button,start_button,options_button]:
		button.disabled = true
	# Paint the loading feedback before the one-time 3D scene import/instantiation.
	await get_tree().process_frame
	await get_tree().process_frame
	var result := get_tree().change_scene_to_file("res://scenes/match_11v11.tscn")
	if result != OK:
		loading = false
		MatchSession.launched_from_menu = false
		start_button.text = "RETRY START GAME"
		for button in [play_button,watch_button,start_button,options_button]:
			button.disabled = false

func _button(parent: Node, text: String, rect: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = rect.position
	button.size = rect.size
	button.add_theme_font_override("font",BOLD)
	button.add_theme_font_size_override("font_size",25 if primary else 23)
	button.add_theme_color_override("font_color",INK if primary else PAPER)
	button.add_theme_color_override("font_focus_color",INK if primary else PAPER)
	button.add_theme_color_override("font_hover_color",INK if primary else PAPER)
	button.add_theme_color_override("font_pressed_color",INK if primary else PAPER)
	button.add_theme_stylebox_override("normal",_style(LIME if primary else Color(0.025,0.05,0.1,0.8),LIME if primary else Color("3c4d69")))
	button.add_theme_stylebox_override("hover",_style(Color("e4ffad") if primary else Color("1c3673"),LIME))
	button.add_theme_stylebox_override("pressed",_style(Color("adce59") if primary else Color("2254c8"),PAPER))
	var focus := _style(Color(0,0,0,0),PAPER)
	focus.set_border_width_all(2)
	focus.expand_margin_left = 5
	focus.expand_margin_right = 5
	focus.expand_margin_top = 5
	focus.expand_margin_bottom = 5
	button.add_theme_stylebox_override("focus",focus)
	parent.add_child(button)
	return button

func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style

func _label(parent: Node, text: String, at: Vector2, font_size: int, font: Font, color := PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_override("font",font)
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _rect(parent: Node, rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	line.position = rect.position
	line.size = rect.size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
