# Reference upgrade: implementation and review

Status: **work in progress; visual acceptance pending**. The owner's
`Current.png` is the native Mac baseline and `New.png` is the target. Changes
below are in the working tree; this document does not imply a GitHub release.

## Implemented

- Recovered photographic face, hair and clothing UVs from the existing
  MIT-licensed Rocketbox source for the 24 near-floor variants. Five shared
  2048² colour atlases and five print masks replace baked vertex colour at
  close range. Clothing tint preserves photographed folds; optional chest
  prints follow shirt UVs. Far crowd and the sign-fan cutaway remain separate.
- Retained original seeded seat, clothing and pose selection. Near instances
  are divided into six-metre sections for frustum culling. Near materials
  receive real lighting; fan shadow casting remains disabled for this pass.
- Added four outward audience washes and four stationary blue aisle fixtures,
  separately dimmed for entrances. Existing ring keys, exposure and entrance
  sweeps retain their roles. Added visible long-side stair aisles to the bowl.
- Added satin pad-face roughness, rougher seams and small scuffs; reduced the
  old self-lit floor contribution. LED spill now has blue, amber and purple
  variation. Changed step sides and treads to neutral metallic diamond plate.
- Added repeatable master/corner/crowd/body capture views and a native Mac
  frame-pacing sample without screenshot writes. Metadata records the actual
  renderer and adapter; software/fixed-time captures cannot establish speed.

## Budgets and reproducibility

The near library has 24 variants, 144,069 triangles total, maximum 6,024 per
variant (6,000 body triangles plus phone geometry; limit 6,048). Its GLB is
approximately 5.2 MB. Colour atlases have mipmaps and desktop/Apple-compatible
VRAM compression; print masks use lossless single-channel data with mipmaps.
Five BC7 colour mip chains alone are about 27 MiB; masks,
geometry and other scene resources are additional costs, not included in that
figure. Native shared-memory and draw-call measurements remain necessary.

`tools/blender/textured_crowd.py` rebuilt to a second path with an identical
manifest and SHA-256:

```
abbf90cdf1427e517b40ba5661982472e40c29af8568e18258e70ec1863fc125
```

The bowl was rebuilt from `tools/blender/arena_bowl.py`, with 1,578,550
triangles. No rig dimensions, recovery rules or gameplay timing were changed
by this visual pass.

## Review procedure

On the target Apple Silicon Mac (reported 16 GB, exact chip unknown), use a
build containing these changes:

```bash
bash tools/capture/native_reference.sh /path/to/Aegis.app /path/to/review
```

This writes four 1080p-intended stills with actual image dimensions in their
JSON, followed by a real-time sample of 1,200 rendered frames with the first
120 excluded. Frame intervals include CPU, rendering, presentation and
VSync; they are not GPU-only timings. Capture the exact chip, actual render
resolution and memory before judging the 1080p/60 fps target.

Compare full frames and matching 100% crops against both owner references.
Check face/hand UVs, hair cutouts, garment folds, warm/cool separation,
reflections, metallic steps, feet/contact shadows and canvas highlight detail.
Then check motion for shimmer, LOD changes, crowd section popping and temporal
ghosting. Review entrances as well as the match; a good still is insufficient.

The bounded `--section --environment-only` probe is an asset diagnostic that
omits wrestlers, bowl and match logic. `--no-fog` additionally removes fog for
that review; `--no-screen-effects` disables SSAO/SSIL/SSR/glow. These omissions
are recorded in metadata. None is a full-match comparison or Mac performance
proof.

## Rendered evidence and capture checks

[`evidence/crowd-studio.png`](evidence/crowd-studio.png) and its JSON show five
variants using the actual production crowd shader under simple studio light,
rendered with Godot 4.6.3 Forward+/Vulkan on llvmpipe. This exposed mirrored
shirt lettering; the chest projection was corrected and the render repeated.
Photographic face/clothing UVs and corrected lettering were inspected. The
sheet is an asset diagnostic, not the target arena look.

A bounded arena section renders the crowd correctly under its actual fixtures
with screen effects disabled. The host's full post-processing result produced
black silhouettes/invalid halos, and another attempt was stopped after eight
minutes without a completed capture. Full-scene attempts exceeded the 8 GiB
container limit. Shipping screen effects were **not disabled** to fit this
host; full appearance acceptance still needs a faithful capture.

The window helper now explicitly sets capture pixel dimensions; a 1920x1080
studio output was verified. Native scripts pass `--capture-resolution` after
Godot's `--` separator. Godot consumes engine flags before exposing script
arguments, so the pacing tool checks its own process flags after sampling.
Separate fixed-time and real-time launches verified that `--fixed-fps` is
identified correctly. Unverified runtime flags never produce a positive
performance-evidence claim.

46 focused crowd/bowl/lighting cases passed. A later 11-case run passed the
four strengthened visual export checks and seven replay round-trip checks.
Python compilation, shell syntax and whitespace checks passed. This is not a
full-suite release verdict.

## Remaining acceptance work

- Obtain a faithful full Forward+ frame and native Mac timing evidence.
- Review and tune these material/light values from that frame; tests verify
  asset contracts and coverage, not a visual match.
- Complete wrestler skin/attire and canvas/apron polish after the lighting
  comparison, preserving the user's restrained sweat and blood requirements.
- Resolve the separately tracked ladder-aerial clearance failure before a
  release-ready full-suite verdict. Do not loosen its limits.

**QA verdict: NO-SHIP as a completed AAA reference match.** This is an
implemented first visual slice with further rendered review and tuning due.
