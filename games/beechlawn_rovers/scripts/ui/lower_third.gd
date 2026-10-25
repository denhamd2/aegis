extends Panel
class_name FootballLowerThird
## One responsive, title-safe layout for every broadcast caption.
const STYLE := preload("res://scripts/ui/broadcast_style.gd")
var title := Label.new()
var subtitle := Label.new()

func _init() -> void:
	name = "BroadcastLowerThird"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var plate := NinePatchRect.new()
	plate.texture = STYLE.plate()
	plate.patch_margin_left = 160
	plate.patch_margin_right = 160
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)
	plate.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for item in [title, subtitle]:
		add_child(item)
		STYLE.label(item, item == subtitle)
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		item.anchor_right = 1
		item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		item.offset_left = 80
		item.offset_right = -80
	title.add_theme_font_size_override("font_size", 30)
	title.offset_top = 18
	title.offset_bottom = 55
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.offset_top = 59
	subtitle.offset_bottom = 85

func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()

func _layout() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	var width := minf(1200, get_viewport_rect().size.x * .72)
	offset_left = -width * .5
	offset_right = width * .5
	offset_top = -140
	offset_bottom = -36

func _process(_delta: float) -> void:
	title.offset_top = 34 if subtitle.text.is_empty() else 18
	title.offset_bottom = 72 if subtitle.text.is_empty() else 55

func reveal(seconds: float) -> void:
	var blend := smoothstep(0, .4, seconds)
	modulate.a = blend
	position.y = get_viewport_rect().size.y - 140 + (1 - blend) * 8
