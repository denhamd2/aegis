# Rovers Arena mowing visibility and turf glare — BR-023 (23/27, in progress)

The owner reports faint mowing bands and bright pitch glare on the Mac in
Rovers Arena, sunny weather. Baseline source: 9d4d335a0128df6e8baa02823e1119923e13ce74.

## Reference and scope

The unchanged owner broadcast reference
`references/source_uploads/chat_attachments/match_hud_stadium/70060.jpg` has
readable alternating cuts without a broad white reflection. The Hill Dickinson
`references/hill_dickinson_2026_10_25/bdp_pitch.jpg` shows clear longitudinal
and cross-cut maintained turf under natural light. Originals remain research
references, never shipped as textures. The existing native sunny stadium
broadcast capture reproduces weak band contrast and a broad paler turf sheen.

This is a Godot shader/material repair. No Blender mesh, textures, rig,
characters, mowing geometry, physics, weather presets, sun energy, shadows or
tone mapping need rebuilding. Preserve the damp pitch and localized reflective
Kilmore puddles. The shared grass colour function must keep surface, blade and
fin LODs consistent, with no extra geometry or texture fetches.

## Feedback loop and ranked hypotheses

1. View-direction terms can cancel the mowing signal from the opposite broadcast
   side. Prediction: one of four fixed camera directions has weak band contrast
   even when geometry and lighting are unchanged.
2. Sunny weather still sets 0.65 dampness across arena grass, lowering roughness.
   Prediction: production-vs-diffuse-only renders show a broad reflective lift.
3. Broad sinusoidal normal offsets on mowing bands or texture normals amplify
   that lift. Prediction: removing only broad mowing normal waves reduces its
   view-dependent variation while preserving real texture detail.

The native `--venue-view turf` diagnostic isolates the actual production
surface, weather, sky and sun, hiding other geometry before rendering. Four
opposite camera stations sample projected world-space stripe centres. Paired
diffuse-only renders change SPECULAR alone, separating reflectance from diffuse
lighting. This minimized fixture complements complete 22-player broadcast
captures; it does not replace them or establish native Metal/M1 parity.

## Acceptance

Compare fixed sunny arena broadcast views before/after and the four material
stations. Mowing remains readable from either camera side, the turf stays matte,
and sunlit/shaded areas remain distinct. Check rain/cloudy variants and actual
Kilmore goalmouth puddles; retain the grass geometry budget and ball drag.
Run relevant native/shader and wet-weather/budget checks serially with deadlines.
Target-Mac appearance and sustained 1080p60 remain BR-025 (25/27, in progress).

## Implemented repair and evidence

The maintained-turf colour retains a positive cut response with bounded view
variation. Shared surface/blade/fin colours use the same function. Removing the
strip-sized normal waves restores the cross-cut signal; fine texture normals
remain. Arena damp grass has a roughness floor with a small wet adjustment and
restrained specular strength. Kilmore retains its prior shader response,
including separate reflective standing-water masks. Sun, sky, shadows, tone
mapping, weather, ball drag, meshes and textures are unchanged.

The sequential native experiments isolate the causes:

| Production material | Minimum main / cross contrast | Maximum reflective lift |
| --- | --- | --- |
| Original | 3.6% / 0.6% | 33.1% |
| Mowing colour only | 14.8% / 0.7% | 33.5% |
| Remove broad normal waves | 20.9% / 11.7% | 33.4% |
| Final matte damp turf | 23.3% / 12.3% | 3.8% |

Contrast is the difference between alternating stripe-group mean linear
luminance divided by their mean, sampled at 48 projected centres per camera.
Reflective lift is the positive increase relative to the paired SPECULAR=0
render. These are controlled fixture measurements, not universal visual ratings.
The [baseline check](baseline_check.log) fails on the reported symptom; the
[final sunny check](final_check.log) and [rain check](rain_check.log) pass.

Compare the complete [before](broadcast_before/match_broadcast.png) and
[after](broadcast_after/match_broadcast.png) sunny stadium captures: identical
camera, Balanced60, 960×540, daylight and actual22+referee. Mowing reads through
sunlight and roof shadow, with the broad pale sheen reduced. Draw calls (1,202),
primitives (1,165,574) and broadcast turf triangles (32,768) are unchanged.
The [cloudy scene](broadcast_cloudy/match_broadcast.png) and
[Kilmore goalmouth](kilmore/match_puddle.png) retain their intended lighting and
localized water response. Close Kilmore turf remains below240k triangles.

Five regression fixtures pass: wet weather/physical water drag, graphics budget,
stadium structure, pitch/selection markings and realism/optics/turf bounds.
Python capture cleanup and compilation checks pass. Captures retain metadata,
image hashes and bounded process-cleanup records; see [validation.json](validation.json).
Some existing logic fixtures log cached-resource exit diagnostics and full
native review shutdown may log GPU texture cleanup warnings; none is a shader
compilation failure. Strict actual package startup/normal-close checks remain
required by release verification. No Mac performance or appearance acceptance
is claimed from these software Vulkan captures.

Next: BR-025 (25/27, in progress), recheck the packaged sunny Rovers Arena on
Mac for readable mowing, restrained glare and sustained1080p60. Broader BR-023
venue realism remains in progress.
