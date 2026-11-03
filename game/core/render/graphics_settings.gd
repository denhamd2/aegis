class_name GraphicsSettings
## How hard the 3D is rendered, against the machine it runs on (the owner,
## 3 Nov: on his MacBook M1 "at times the gameplay can become a bit janky and
## animations can get a bit like stop motion").
##
## The animation is drawn between physics ticks already (Inertializer), so a
## steady frame rate is smooth. What is not steady is the frame rate: the
## Mac renders the 3D at the panel's full Retina size -- about four million
## pixels with MSAA 4x, TAA, volumetric fog and a 6,000-figure crowd -- and
## a frame that misses its 16.7 ms slot waits for the next v-sync, so the
## picture drops to 30 for a moment: stop motion. So the 3D is rendered
## below the panel's size and upscaled (MetalFX on a Mac's Metal renderer,
## FSR elsewhere); the HUD and menus stay at full size.
##
## AUTO (the default) holds 60 fps by moving the 3D resolution between
## MIN_SCALE and 1.0 as the frame time asks (FramePacer). The others are
## fixed.
##
## Command line (after `--`): --graphics auto|high|balanced|performance.
enum Quality { AUTO, HIGH, BALANCED, PERFORMANCE }

static var quality := Quality.AUTO
static var _read_args := false

## Each fixed tier: [3D scale, MSAA, upscaled].
const TIERS := {
	Quality.HIGH: [1.0, Viewport.MSAA_4X, false],
	Quality.BALANCED: [0.77, Viewport.MSAA_2X, true],
	Quality.PERFORMANCE: [0.6, Viewport.MSAA_DISABLED, true],
}
## AUTO's range, and where it starts: the balanced tier's look, moving.
const MIN_SCALE := 0.6
const MAX_SCALE := 1.0
const AUTO_START := 0.85
const AUTO_MSAA := Viewport.MSAA_2X


static func current() -> Quality:
	if not _read_args:
		_read_args = true
		var args := OS.get_cmdline_user_args()
		for i in args.size() - 1:
			if args[i] == "--graphics":
				match args[i + 1]:
					"high": quality = Quality.HIGH
					"balanced": quality = Quality.BALANCED
					"performance": quality = Quality.PERFORMANCE
					_: quality = Quality.AUTO
	return quality


static func set_quality(q: Quality) -> void:
	current()
	quality = q


## The upscaler for a 3D scale under 1 on this machine: MetalFX's spatial
## upscaler on Apple's Metal renderer, FSR 1 on the others.
static func upscaler(driver: String) -> Viewport.Scaling3DMode:
	if driver == "metal":
		return Viewport.SCALING_3D_MODE_METALFX_SPATIAL
	return Viewport.SCALING_3D_MODE_FSR


## [scale, msaa, upscaled] for `q`, AUTO at `auto_scale`.
static func settings_for(q: Quality, auto_scale: float) -> Array:
	if q == Quality.AUTO:
		return [clampf(auto_scale, MIN_SCALE, MAX_SCALE), AUTO_MSAA, auto_scale < 0.999]
	return TIERS[q]


## Puts `q` on `viewport` (the game's root window).
static func apply(viewport: Viewport, q: Quality, auto_scale := AUTO_START) -> void:
	if viewport == null:
		return
	var s := settings_for(q, auto_scale)
	viewport.msaa_3d = s[1]
	viewport.scaling_3d_scale = s[0]
	viewport.scaling_3d_mode = upscaler(RenderingServer.get_current_rendering_driver_name()) \
			if s[2] else Viewport.SCALING_3D_MODE_BILINEAR
