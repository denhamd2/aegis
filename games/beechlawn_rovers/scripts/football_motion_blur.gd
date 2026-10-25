@tool
class_name FootballMotionBlur
extends CompositorEffect
## Football-local adaptation of the existing velocity-buffer compositor.
## Cinematic only, depth-aware and capped at six pixels at 1920px width.

## The compute pass, compiled at runtime on the real device: headless Godot
## (the tests, the CI export) has no .glsl importer, and a preloaded shader
## file would fail to load there.
const SHADER_SOURCE := """#version 450

// FootballMotionBlur (motion_blur.gd): a per-pixel blur along the velocity buffer
// the Forward+ renderer already writes for TAA. Two passes over the same
// pipeline, so no pixel reads a neighbour another invocation has already
// overwritten: mode 0 copies the frame aside, mode 1 averages TAPS samples of
// that copy along each pixel's own motion and writes the frame back.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(rgba16f, set = 0, binding = 0) uniform restrict readonly image2D src;
layout(rgba16f, set = 0, binding = 1) uniform restrict writeonly image2D dst;
layout(rg16f, set = 0, binding = 2) uniform restrict readonly image2D velocity;

layout(set = 0, binding = 3) uniform sampler2D depth_texture;

layout(push_constant, std430) uniform Params {
	vec2 size;        // the internal render size, pixels
	float intensity;  // fraction of a frame's motion smeared (a shutter angle / 360)
	float max_px;     // longest smear, pixels
	float mode;       // 0 copy, 1 blur
	float pad0;
	float pad1;
	float pad2;
} p;

const int TAPS = 8;

void main() {
	ivec2 px = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = ivec2(p.size);
	if (px.x >= size.x || px.y >= size.y) {
		return;
	}
	if (p.mode < 0.5) {
		imageStore(dst, px, imageLoad(src, px));
		return;
	}
	// UV-space motion since the last frame, in pixels, scaled to the shutter.
	vec2 v = imageLoad(velocity, px).xy * p.size * p.intensity;
	float len = length(v);
	if (len < 0.75) {
		imageStore(dst, px, imageLoad(src, px));
		return;
	}
	if (len > p.max_px) {
		v *= p.max_px / len;
	}
	vec4 acc = vec4(0.0);
	float weight = 0.0;
	float depth = texelFetch(depth_texture, px, 0).r;
	for (int i = 0; i < TAPS; i++) {
		float t = float(i) / float(TAPS - 1) - 0.5;
		ivec2 q = clamp(px + ivec2(round(v * t)), ivec2(0), size - 1);
		float sample_depth = texelFetch(depth_texture, q, 0).r;
		if (abs(sample_depth - depth) > max(0.00001, abs(depth) * 0.08)) { continue; }
		acc += imageLoad(src, q);
		weight += 1.0;
	}
	imageStore(dst, px, weight > 0.0 ? acc / weight : imageLoad(src, px));
}
"""
## The longest smear, as a fraction of the frame's width.
const MAX_FRACTION := 0.003125
const CONTEXT := &"football_motion_blur"
const SCRATCH := &"copy"

## Fraction of a frame's motion smeared: 0.5 is a 180-degree film shutter.
var intensity := 0.0

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _sampler: RID
var _scratch_size := Vector2i.ZERO


static func supported(rendering_method: String) -> bool:
	return rendering_method == "forward_plus"


func _init() -> void:
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	needs_motion_vectors = true
	access_resolved_color = true
	access_resolved_depth = true
	_rd = RenderingServer.get_rendering_device()
	if _rd:
		RenderingServer.call_on_render_thread(_build)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _rd:
		if _shader.is_valid(): _rd.free_rid(_shader)
		if _sampler.is_valid(): _rd.free_rid(_sampler)


func _build() -> void:
	var spirv := compile(_rd)
	if spirv == null or spirv.compile_error_compute != "":
		push_warning("FootballMotionBlur: %s" % (spirv.compile_error_compute if spirv else "no device"))
		return
	_shader = _rd.shader_create_from_spirv(spirv)
	if _shader.is_valid():
		_pipeline = _rd.compute_pipeline_create(_shader)
		_sampler = _rd.sampler_create(RDSamplerState.new())


## The pass compiled to SPIR-V on `rd`, or null without a device.
static func compile(rd: RenderingDevice) -> RDShaderSPIRV:
	if rd == null:
		return null
	var source := RDShaderSource.new()
	source.language = RenderingDevice.SHADER_LANGUAGE_GLSL
	source.source_compute = SHADER_SOURCE
	return rd.shader_compile_spirv_from_source(source)


func _render_callback(_type: int, render_data: RenderData) -> void:
	if intensity <= 0.0 or not _pipeline.is_valid():
		return
	var buffers := render_data.get_render_scene_buffers() as RenderSceneBuffersRD
	if buffers == null:
		return
	var size := buffers.get_internal_size()
	if size.x == 0 or size.y == 0:
		return
	if not buffers.has_texture(CONTEXT, SCRATCH) or _scratch_size != size:
		if buffers.has_texture(CONTEXT, SCRATCH):
			buffers.clear_context(CONTEXT)
		buffers.create_texture(CONTEXT, SCRATCH, RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT,
				RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT,
				RenderingDevice.TEXTURE_SAMPLES_1, size, buffers.get_view_count(), 1, true, false)
		_scratch_size = size
	var groups := Vector3i(ceili(size.x / 8.0), ceili(size.y / 8.0), 1)
	for view in buffers.get_view_count():
		var color := buffers.get_color_layer(view)
		var velocity := buffers.get_velocity_layer(view)
		var depth := buffers.get_depth_layer(view)
		var scratch := buffers.get_texture_slice(CONTEXT, SCRATCH, view, 0, 1, 1)
		if not (color.is_valid() and velocity.is_valid() and scratch.is_valid() and depth.is_valid()):
			continue
		_pass(color, scratch, velocity, depth, size, 0.0, groups)
		_pass(scratch, color, velocity, depth, size, 1.0, groups)


func _pass(src: RID, dst: RID, velocity: RID, depth: RID, size: Vector2i, mode: float,
		groups: Vector3i) -> void:
	var uniforms := UniformSetCacheRD.get_cache(_shader, 0, [
		_image(0, src), _image(1, dst), _image(2, velocity), _depth_uniform(depth)])
	var params := PackedFloat32Array([size.x, size.y, intensity,
			MAX_FRACTION * size.x, mode, 0.0, 0.0, 0.0]).to_byte_array()
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	_rd.compute_list_bind_uniform_set(list, uniforms, 0)
	_rd.compute_list_set_push_constant(list, params, params.size())
	_rd.compute_list_dispatch(list, groups.x, groups.y, groups.z)
	_rd.compute_list_end()


static func _image(binding: int, texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(texture)
	return u


func _depth_uniform(texture: RID) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.binding = 3
	u.add_id(_sampler)
	u.add_id(texture)
	return u
