# Kilmore cloud sky — BR-023 (23/25, in progress)

## Reference and direction

The environment board (`football_reference_upload_round_2/2-69021.jpg`) and
archived Street View `panorama_shared_link_heading_yaw_191.jpg` establish natural
cloud layers, a brighter horizon and clear visibility across the local park.
The broadcast reference `69022` is sunnier. The owner then explicitly requested
less overcast weather and sunlight across the pitch: use a partly cloudy daytime
preset, blue openings, slightly warm direct sun, cool sky fill and visible
shadows. Google/reference captures guide the look, not runtime textures.

The old ProceduralSkyMaterial was a featureless gradient with flat ambient colour.
Use a free photographic panorama for cloud form and real directional lighting
for sun/shadows. Volumetric fog is neither the cloud source nor part of this pass;
Godot Web Compatibility does not support it. Very light conventional distance
haze affects the far environment without obscuring the pitch.

## Implementation

The shared editable Environment is `data/presentation/kilmore_daylight.tres`.
Both actual match scenes and the player review scene use it. Its sky is Poly
Haven's CC0 **Kloofendal 48d Partly Cloudy (Pure Sky)**, by Greg Zaal and Jarod
Guest. Original 4096×2048 HDR bytes, source/download/license URLs and SHA256 are
under `assets/environment/sky/polyhaven/`. It contains no foreign buildings or
terrain and is not claimed to be a photograph of Kilmore Drive.

The 4K sky remains static and uses a cached 256-pixel radiance map. The import
builds mipmaps and clamps extreme HDR exposure, preventing the tiny solar texel
from overwhelming ambient lighting. The original unclipped HDR is retained.
The directional sun supplies shadowed direct light; its approximately 48°
elevation and azimuth are derived from the brightest upper-hemisphere HDR pixel
using Godot's spherical sky mapping. Rotation is recorded in `source.json`.
Its 0.8° angular size softens shadow edges; the shadow distance covers the pitch
and nearby surroundings. Sky fill is reduced to preserve sun/shade contrast.
`shaders/kilmore_day_sky.gdshader` samples the photograph once, with editable
sky-only saturation/energy and a narrow horizon blend. The first HDR render was
too saturated blue; reducing sky saturation preserves natural cloud colour
without grading the kits or turf. No per-frame cloud simulation or raymarching
is used. Direct light energy is 0.8 and ambient sky energy 0.5 after the sunny
exposure check, keeping light/shade separation without washing out white kits.
Sky sampling follows Godot's built-in bilinear panorama convention. Implicit
mip derivatives across the longitude wrap produced a thin grey vertical stripe
in review; using bilinear sampling avoids that discontinuity. The source image
was not repainted to hide it.

## Review and acceptance

Before/after Web shots use the same 960×540 camera/query and frozen kickoff
state. Standard `software=1` shots disable sun shadows for bounded SwiftShader
cost, so they establish cloud form, horizon and colour only. A separate debug
`software=1&shadows=1` capture keeps real directional shadows and limits rendering
to 1 fps; the production build retains its normal rendering and enabled shadows.

Capture broadcast and touchline views, verify team/ball readability, sun/shade
contrast and no foreign landscape, and run the existing 11v11/camera/intro checks.
`tools/blender/beechlawn/review_kilmore_sky.py` renders the selected source world
for look review; actual Godot captures are engine acceptance. Native M1 frame
times and Metal appearance remain pending. The sky/light pass does not establish
photorealistic approval for unfinished venue geometry or player likeness.
