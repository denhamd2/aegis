extends Node
## Holds the frame rate (GraphicsSettings, AUTO) and shows it (F3).
##
## Every WINDOW seconds it looks at the average frame time: over BUDGET_HIGH
## the 3D resolution comes down a STEP, under BUDGET_LOW it goes back up --
## the gap between the two keeps it from hunting. A single slow frame (a
## shader compiled for the first time, a level loading) is a spike, not a
## trend, and does not move it; the overlay counts spikes so the owner can
## tell the two apart on his machine.
##
## Presentation only: it changes how many pixels are drawn, never a tick of
## the match.

const WINDOW := 0.5
## 60 fps is 16.7 ms a frame.
const BUDGET_HIGH := 17.4
const BUDGET_LOW := 13.0
const STEP := 0.05
## A frame this much over 60 fps's time is a visible hitch.
const SPIKE_MS := 25.0

var auto_scale := GraphicsSettings.AUTO_START
var _sum := 0.0
var _frames := 0
var _worst := 0.0
var _spikes := 0
var _applied := -1
var _label: Label
var _layer: CanvasLayer
var _headless := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	if _headless:
		set_process(false)
		return
	_layer = CanvasLayer.new()
	_layer.layer = 128
	add_child(_layer)
	_label = Label.new()
	_label.position = Vector2(12, 8)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	_label.visible = false
	_layer.add_child(_label)
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and (event as InputEventKey).keycode == KEY_F3:
		_label.visible = not _label.visible
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	var q := GraphicsSettings.current()
	if q != _applied:
		_apply()
	var ms := delta * 1000.0
	_sum += ms
	_frames += 1
	_worst = maxf(_worst, ms)
	if ms > SPIKE_MS:
		_spikes += 1
	if _sum < WINDOW * 1000.0:
		return
	var avg := _sum / float(_frames)
	if q == GraphicsSettings.Quality.AUTO:
		var next := step_scale(auto_scale, avg)
		if not is_equal_approx(next, auto_scale):
			auto_scale = next
			_apply()
	if _label.visible:
		var s: Array = GraphicsSettings.settings_for(q, auto_scale)
		_label.text = "%d fps  %.1f ms  worst %.0f ms  hitches %d\n3D %d%%  %s  %s" % [
				roundi(1000.0 / maxf(avg, 0.001)), avg, _worst, _spikes, roundi(float(s[0]) * 100.0),
				GraphicsSettings.Quality.keys()[q], RenderingServer.get_current_rendering_driver_name()]
	_sum = 0.0
	_frames = 0
	_worst = 0.0


## AUTO's next 3D scale from the last window's average frame time.
static func step_scale(scale: float, avg_ms: float) -> float:
	if avg_ms > BUDGET_HIGH:
		return maxf(GraphicsSettings.MIN_SCALE, snappedf(scale - STEP, 0.01))
	if avg_ms < BUDGET_LOW:
		return minf(GraphicsSettings.MAX_SCALE, snappedf(scale + STEP, 0.01))
	return scale


func _apply() -> void:
	_applied = GraphicsSettings.current()
	GraphicsSettings.apply(get_tree().root, _applied, auto_scale)
