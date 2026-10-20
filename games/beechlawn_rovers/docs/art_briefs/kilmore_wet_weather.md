# BR-023 damp goalmouths and match weather — 20 October 2026

Item 23/25, in progress; ball resistance also touches BR-004's physical-ball
system. The archived local-park boards and satellite captures show worn,
irregular keeper traffic areas. The owner explicitly requested muddy goalmouths,
standing water and selectable weather. Individual puddle outlines are authored
interpretations, not surveyed depressions or copies of satellite imagery.
The existing road/grass setback, shallow terrain and faded chalk are retained.

## Implementation

- Original repeatable `build_goalmouth_masks.py` creates a 1024×512 PNG: red
  mud, green standing water. A free CC0 Poly Haven Brown Mud scan (Rob Tuytel, 1K albedo/OpenGL normal/roughness) adds actual soil relief; unchanged originals, license and checksums are archived under `assets/environment/surfaces/polyhaven/brown_mud/`. Three irregular shallow pools at each end sit
  within a wider muddy keeper arc; the two ends vary. No purchased assets.
- A shared editable `kilmore_surface.tres` supplies that exact image to both
  the ground material and FootballBall. The mask stays lossless with automatic 3D compression disabled for CPU access. CPU bilinear sampling matches GPU
  pixel-centre sampling. Water has lower roughness, sky/sun specular response
  and subtle ripples; muddy edges retain rough soil/grain variation.
- Water is a shallow surface material, not a fluid simulation. There are no
  screen-space reflections, moving water volumes or splash/footprint system.
- Grounded balls receive additional mass-scaled, exponential resistance in the
  fixed physics loop. Airborne balls and held balls are excluded. Both teams
  use the same physics. Existing dribble forces remain capped and independent.
- Options offers Sunny (damp pitch), Cloudy, Light rain and Morning mist.
  Preferences persist across launches. Sunny retains the requested direct
  sunlight and visible wet goalmouths. Other presets adjust fill, sun, sky,
  haze and wetness. Light rain adds bounded CPU particles near play; changing
  away removes them. These are weather presets, not a season/drainage model.
- Match-scoped environment copies preserve the shared daylight resource and
  avoid weather settings leaking into separate reviews or the next match.

## Broadcast background research and choice

Godot 4.6 documentation:
- [Environment/post-processing](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html)
- [Volumetric fog](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html)
- [Renderer feature comparison](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)

Volumetric fog is a Forward+ feature; it is unavailable in Mobile and
Compatibility (our Web renderer). It suits genuine mist/light shafts, not a
blanket fix for a clear Sunday-league backdrop. The sunny broadcast keeps very
light depth haze and sharp player/ball visibility. Mist uses stronger depth
haze, supported across the builds. No fog-volume dependency or gameplay DOF.
Photographic sky, coherent sunlight, credible cast/contact shadows, better
vegetation/building shapes, material variation and reference-led placement
remain the larger realism priorities. Haze cannot substitute for those assets.

## Validation

`wet_weather_smoke.gd` checks actual ground-ball slowdown, airborne exclusion,
both ends, clear midfield/out-of-bounds, 60/120 Hz coefficient consistency,
persisted preferences, preset application/rain cleanup and unmodified shared
lighting. WebGL evidence and shadow on/off comparison are saved in
`wet_weather_evidence/`. Cloud evidence does not establish native M1 1080p/60fps.


Shadow follow-up: the real directional light retains the full-pitch 150 m
shadow range and its existing depth bias 0.04 / normal bias 0.8. A lower
0.02/0.2 trial introduced visible bands on curved skin, so it was rejected.
The ball/post/player inspection uses an explicitly staged, stationary ball in
a debug-only query. The ball close-up looks against the light direction so
its short ground shadow is not hidden behind the ball. Normal Play/Watch
kickoff placement is unchanged. Shadow-on/off images state the actual mode.
Mud scan maps use mipmaps and anisotropic filtering to limit distant shimmer.

Art-review tooling now prints stage timings and bounded timeout diagnostics.
An optional validated import cache avoids repeating cold imports for every
camera review, excludes transient importer files and tolerates disappearing
optional cache entries. This does not replace the release workflow's cold
import and actual release checks.
