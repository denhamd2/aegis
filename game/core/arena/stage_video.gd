extends Node
class_name StageVideo
## Puts the looping entrance clip on the video wall, and gets out of the way
## when it cannot.
##
## Everything here is cosmetic in the sense `gauntlet/anchor/ARCHITECTURE.md`
## means it: this node creates no `CollisionObject3D`, joins no physics layer,
## and nothing gameplay reads can reach it. `MatchReferee.compute_end_state_hash()`
## is computed from the seed, the tick count, damage and momentum, none of
## which a video texture can touch. It hangs under `Arena`, where the rest of
## the hall's cosmetics live.
##
## ## Why the wiring is the way it is
##
## Five details below are load-bearing, and each of them is a way this fails
## silently rather than loudly:
##
## - **`EMISSION_OP_MULTIPLY` with a white emission colour.** MULTIPLY resolves
##   `EMISSION = emission * emission_texture * energy`, so a white emission
##   makes the video *be* the light coming off the wall. ADD would resolve to
##   `(white + video) * energy` and wash the panel to white whatever is
##   playing on it. This is the single most likely wiring mistake here.
## - **Not `SHADING_MODE_UNSHADED`.** Unshaded outputs ALBEDO and drops
##   EMISSION entirely, so the wall would stop glowing, stop crossing the
##   Environment's glow threshold, and stop showing up in the stage deck's
##   screen-space reflection -- which is half of why the deck was made glossy.
## - **`uv1_scale` is forced to ONE** by the caller. `MaterialLibrary` derives
##   that from `tile_metres`, and the curved face is the first surface in the
##   project with normalised UVs.
## - **`TEXTURE_FILTER_LINEAR`, not the library's mipmapped anisotropic.** A
##   video texture has no mip chain; asking a mipless texture for mipmapped
##   sampling is wasted at best and samples black on some GLES3 drivers -- and
##   the Web build is exactly that path.
## - **The player lives in a SubViewport.** It is a Control, so it draws; the
##   requirement is that it decode without any of that drawing reaching the
##   screen. A CanvasLayer cannot do it at any layer value -- see the comment
##   at the placement itself, which is where that shipped from.
## - **The emission energy is solved, not typed.** It is derived from the
##   still frame's own mean linear luminance, so the wall lands on the level
##   below whatever the clip's exposure happens to be. Same arithmetic
##   `MaterialLibrary.house_compensate()` performs for a multiplied emission
##   map, applied to a picture.

const VIDEO_PATH := "res://assets/environment/video/dynamite_tron.ogv"
## One frame of the same clip. Two jobs, and it is one asset because they are
## the same requirement seen twice: it is what a frame-locked run shows (see
## `frame_locked()`), and it is what the wall falls back to when the clip
## cannot be decoded.
const STILL_PATH := "res://assets/environment/video/dynamite_tron_still.png"

## Linear luminance the lit wall is solved to.
##
## The blank panel this replaces was measured at 0.35 and capped there. That
## number was taken of a flat panel whose entire area sat at one value; a
## picture's mean is well below its peak, so the same mean buys a much brighter
## *highlight* -- which is what crosses the Environment's `glow_hdr_threshold`
## of 1.25 and blooms, and what the reference photographs show.
##
## 1.10 was tried first and is too much: it clipped the clip's own highlights
## and the logo came back as a white slab with the colour gone, which is the
## same failure the old flat panel had at 1.35 and the reason the 0.35 cap
## existed. 0.55 keeps the picture readable while the brightest parts of it
## still bloom. The re-measured p95 this was settled on is in README.md.
const SCREEN_LEVEL := 0.55

## The clip is 16:9 and the wall is 3:1, so something has to give.
##
## Stretching to fit is the one option that is simply wrong -- a squashed logo
## reads as a mistake from any seat. What a broadcast operator does instead is
## take the middle band of a 16:9 source: 1.78 / 0.62 = 2.87, near enough the
## wall's 3.0 that the residual stretch is invisible, and the Dynamite logo
## occupies roughly the middle 55% of the frame's height so a 62% band keeps
## all of it and crops background pattern only.
##
## Applied as uv1_scale/offset rather than by re-encoding, so the committed
## clip stays the source as supplied and the crop stays a decision this file
## makes and can revise.
const VIDEO_UV_SCALE := Vector2(1.0, 0.62)
const VIDEO_UV_OFFSET := Vector2(0.0, 0.19)

## Frames to wait for `get_video_texture()` to return something before giving
## up and falling back to the still. It is null until playback has produced a
## first frame -- notably it is NOT valid on the same frame as `play()` -- so
## this cannot be a single check.
const BIND_TIMEOUT_FRAMES := 120

var _player: VideoStreamPlayer = null
var _screen: MeshInstance3D = null
var _material: StandardMaterial3D = null
var _bound := false
var _frames := 0
var _video_path := VIDEO_PATH


## Build the node for `screen`, binding into `mat`.
##
## `video_path` is injectable so a test can point it at a file that is not
## there and assert the fallback, which is the branch that matters most and
## the one hardest to reach by accident.
static func attach(screen: MeshInstance3D, mat: StandardMaterial3D,
		video_path: String = VIDEO_PATH) -> StageVideo:
	var node := StageVideo.new()
	node.name = "StageVideo"
	node._screen = screen
	node._material = mat
	node._video_path = video_path
	return node


## True when this run has to be frame-identical round to round.
##
## `CaptureHarness.ART_SHOTS` exists so that round N and round N-1 can be
## compared frame for frame; a freely playing video destroys that, because the
## frame on the wall then depends on how fast the machine decoded. So a
## frame-locked run never starts the player at all and shows the still
## instead. Every capture then renders the same pixels by construction.
##
## Note for anyone tempted by the obvious alternative: seeking is not
## available. `VideoStreamPlayer.stream_position`'s setter is a no-op for
## Godot's built-in Theora backend, so "play, then seek to a fixed position"
## is not a mechanism this can rest on.
static func frame_locked() -> bool:
	var args := OS.get_cmdline_user_args()
	for flag: String in ["--art-shots", "--silhouette-shot", "--capture-output"]:
		if Array(args).has(flag):
			return true
	return false


func _ready() -> void:
	# Nothing renders under the headless display server, so nothing needs
	# decoding. Ten test suites instantiate match.tscn and none of them should
	# pay for Theora.
	if DisplayServer.get_name() == "headless":
		_bind_still("headless")
		return
	if frame_locked():
		_bind_still("frame-locked run")
		return
	if not ResourceLoader.exists(_video_path):
		_bind_still("no clip at %s" % _video_path)
		return
	var stream: VideoStream = load(_video_path) as VideoStream
	if stream == null:
		_bind_still("%s did not load as a VideoStream" % _video_path)
		return

	var feed := _make_feed(stream)
	add_child(feed)
	_player = feed.get_node("Feed")
	_player.play()


## Builds the off-screen home for the player: a SubViewport with the
## VideoStreamPlayer inside it.
##
## VideoStreamPlayer is a Control, so it has to live somewhere that draws --
## and the whole trick is that it must decode without any of that drawing
## reaching the screen. A SubViewport is the only placement that guarantees
## both: it renders to its own target, is never composited into the window
## unless a SubViewportContainer asks for it, and its children process
## normally, so the decoder runs and `get_video_texture()` fills.
##
## THIS WAS A CanvasLayer AT layer = -128, AND THAT IS WRONG. A negative layer
## orders a CanvasLayer against *other CanvasLayers*; it does not put one
## behind the 3D world, because 3D is always drawn behind every canvas item.
## On top of that, `expand = false` makes the player draw at the video's native
## 1280x720 and ignore whatever rect it was given. The two together shipped to
## the browser build with the clip painted across the middle of the game --
## decoding perfectly, and displaying itself as well.
##
## Split out as a function so `test_stage_set.gd` can assert the placement
## without a renderer, a clip, or a display server. The bug was invisible to
## every test that existed because all of them ran headless, where the player
## is never built at all.
##
## The viewport is 2x2 because nothing ever reads its texture: the frames reach
## the wall through `get_video_texture()`, which hands back the decoder's own
## texture and does not care what size the viewport around it is.
static func _make_feed(stream: VideoStream) -> SubViewport:
	var feed := SubViewport.new()
	feed.name = "FeedViewport"
	feed.size = Vector2i(2, 2)
	feed.disable_3d = true
	feed.transparent_bg = true
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var player := VideoStreamPlayer.new()
	player.name = "Feed"
	player.stream = stream
	player.loop = true
	player.autoplay = false
	player.expand = true
	player.volume_db = -80.0
	player.size = Vector2(2, 2)
	feed.add_child(player)
	return feed


func _process(_delta: float) -> void:
	if _bound:
		set_process(false)
		return
	_frames += 1
	if _player == null:
		return
	var tex := _player.get_video_texture()
	if tex != null:
		_bind(tex, "clip")
	elif _frames > BIND_TIMEOUT_FRAMES:
		push_warning("StageVideo: no video texture after %d frames; "
				% BIND_TIMEOUT_FRAMES + "falling back to the still.")
		_player.stop()
		_bind_still("decode produced no frames")


## Bind once. The texture a playing VideoStreamPlayer hands back is updated in
## place for the life of playback, so re-assigning it every frame re-uploads
## material state for nothing.
func _bind(tex: Texture2D, source: String) -> void:
	_bound = true
	_material.albedo_texture = tex
	# A lit response rather than a doubling: the emission below is what the
	# wall is seen by, and leaving albedo at full white would add the stage
	# fixtures' bounce on top of a surface that is already its own light.
	_material.albedo_color = Color(0.55, 0.55, 0.55)
	_material.emission_enabled = true
	_material.emission = Color(1, 1, 1)
	_material.emission_texture = tex
	_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_material.emission_energy_multiplier = SCREEN_LEVEL / maxf(_still_mean(), 0.0001)
	_material.uv1_scale = Vector3(VIDEO_UV_SCALE.x, VIDEO_UV_SCALE.y, 1.0)
	_material.uv1_offset = Vector3(VIDEO_UV_OFFSET.x, VIDEO_UV_OFFSET.y, 0.0)
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	if OS.is_stdout_verbose():
		print("StageVideo: bound %s to the wall." % source)


func _bind_still(reason: String) -> void:
	if not ResourceLoader.exists(STILL_PATH):
		# The wall keeps the self-emissive material the builder already gave
		# it. Blank, correct, and no error.
		if OS.is_stdout_verbose():
			print("StageVideo: %s, and no still either; wall left blank." % reason)
		set_process(false)
		return
	var tex := load(STILL_PATH) as Texture2D
	if tex == null:
		set_process(false)
		return
	_bind(tex, "still (%s)" % reason)
	set_process(false)


## Mean linear luminance of the still, used to solve the emission energy.
##
## Measured off the still rather than off a live video frame on purpose: a
## video frame's mean moves as the clip plays, and an emission energy that
## moved with it would make the wall's *level* a function of what happened to
## be on screen. The still is one fixed number, so the wall's level is fixed
## and only its picture changes.
func _still_mean() -> float:
	if not ResourceLoader.exists(STILL_PATH):
		return 0.5
	var tex := load(STILL_PATH) as Texture2D
	if tex == null:
		return 0.5
	return MaterialLibrary.mean_linear(tex)


## Whether the wall is showing something. False means the builder's blank
## material is still on it.
func is_bound() -> bool:
	return _bound
