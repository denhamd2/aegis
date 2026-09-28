class_name BroadcastLook
extends CanvasLayer
## The broadcast finish over the frame (gauntlet/refs/aaa_gap.md item 10): a
## very light lens vignette always, and sensor grain on a replay.
##
## A TV camera's lens falls off toward the corners, and 2K26's presentation
## keeps a trace of it; a game frame lit edge to edge reads as a render. Grain
## says "replay" the way a broadcast's slightly degraded replay feed does.
##
## Drawn as one ColorRect with a canvas shader that only ADDS darkening and
## noise -- it never reads the screen, so it costs one full-screen quad. Under
## the HUD (layer 0 < the HUD's), so the plates and the count stay clean.
## Presentation only.

## Darkening at the corners, 0-1. Very light on purpose: the mat's exposure
## anchor is measured over the middle of the frame and must not move.
const VIGNETTE := 0.22
## Where the falloff starts and ends, as a distance from the centre in
## aspect-corrected screen units (0.5 is the middle of a side edge).
const VIGNETTE_INNER := 0.45
const VIGNETTE_OUTER := 0.95
## Grain on a replay: the noise's alpha.
const GRAIN := 0.06

var replay := false
var _material: ShaderMaterial


func _ready() -> void:
	layer = -1
	var rect := ColorRect.new()
	rect.name = "Finish"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = _shader()
	_material.set_shader_parameter("vignette", VIGNETTE)
	_material.set_shader_parameter("inner", VIGNETTE_INNER)
	_material.set_shader_parameter("outer", VIGNETTE_OUTER)
	_material.set_shader_parameter("grain", GRAIN if replay else 0.0)
	rect.material = _material
	add_child(rect)


func set_grain(on: bool) -> void:
	replay = on
	if _material:
		_material.set_shader_parameter("grain", GRAIN if on else 0.0)


static func _shader() -> Shader:
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;

uniform float vignette = 0.2;
uniform float inner = 0.45;
uniform float outer = 0.95;
uniform float grain = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 size = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 c = (UV - 0.5) * vec2(size.x / size.y, 1.0);
	float fall = smoothstep(inner, outer, length(c)) * vignette;
	// Grain: per-pixel noise re-rolled 24 times a second, centred on grey so
	// it lifts and darkens about equally.
	float n = hash(floor(FRAGCOORD.xy) + floor(TIME * 24.0) * 17.0) - 0.5;
	// Two layers in one blend: black at `fall` (the vignette), then a grey
	// noise speck at `grain` over that. Standard over-compositing:
	// out = a1*black + (1-a1)*(a2*speck + (1-a2)*frame).
	float a2 = grain * abs(n) * 2.0;
	float a = a2 + fall * (1.0 - a2);
	vec3 speck = vec3(0.5 + n);
	COLOR = vec4(speck * a2 / max(a, 1e-4), a);
}
"""
	return shader
