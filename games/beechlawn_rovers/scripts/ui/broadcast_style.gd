extends RefCounted
## Shared original blue campaign plate used by intro captions and match HUD.
const BOLD := preload("res://assets/ui/fonts/BarlowSemiCondensed-SemiBold.ttf")
const CYAN := Color(0.60, 0.83, 1.0)

static func plate() -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = preload("res://assets/ui/lineups/referee_lower_third.png")
	atlas.region = Rect2(0, 210, 2172, 275)
	atlas.filter_clip = true
	return atlas

static func background(parent: Control) -> TextureRect:
	var image := TextureRect.new()
	image.name = "BlueBroadcastPlate"
	image.texture = plate()
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.move_child(image, 0)
	return image

static func label(label: Label, muted := false) -> void:
	label.add_theme_font_override("font", BOLD)
	label.add_theme_color_override("font_color", CYAN if muted else Color.WHITE)
