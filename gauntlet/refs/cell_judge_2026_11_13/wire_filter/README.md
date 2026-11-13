# Cell wire filtering follow-up

## Result: SHIP WITH NOTES

A targeted sampling refinement after the three completed judge loops. Overall
likeness stays **8.0/10**; no new global likeness or AAA acceptance is claimed.

`cell_wire.gdshader` analytically filters the Blender cell's existing five-period
diamond pattern and .09 strand profile over the pixel footprint. It retains the
authored base/normal/ORM textures, metal response, mesh geometry and transforms.
No Blender rebuild is needed because this corrects runtime sampling only. Steel
cage and experimental custom-spec materials keep their existing path.

The first alpha-to-coverage prototype was rejected: Godot forces alpha to1 for
scissor fragments without its alpha-edge path, turning minified roof wires into
an opaque sheet. It was never integrated. The accepted version uses alpha
blending with a depth prepass. Pure integration checks give .09 coverage per
stripe family over whole periods and .1719 for their independent union; a
resolved opening remains0. These are sampling checks, not performance evidence.

## Validation evidence

**35/35 focused cage/cell/roof cases pass**, zero failures/errors/orphans;
see [regression report](regression-tests.xml). Godot4.6.3 editor import
completed successfully with no reported errors.

- Production roof/wall/overview images are pixel-identical to the accepted
  prototype's same-camera captures (RGB mean difference0 in all three).
- Twelve consecutive frames move the roof camera .04m/frame. Stored pairs
  00/05/06/11 were selectively reviewed by the independent judge: distant wire
  survives better, with no obvious sampled panel pop or opaque flash. This is
  not exhaustive temporal validation. Both paths show TAA edge softening.
- Door-interior/exterior, a hidden roof panel and a lowered panel remain readable
  with default4xMSAA and with MSAA disabled. The judge reviewed all three
  MSAA-off state images. The doorway and broken roof opening stay clear.
- Forward+ Vulkan llvmpipe at960x540 with the existing locked lights/cameras;
  production `capture.json` records AA and study flags. No arena, characters or
  native Mac frame-time measurement is included.

Reproduce from the repo root with Godot and a working display:

```sh
godot --path game --resolution 960x540 tools/probe/cell_likeness_shot.tscn -- --out /tmp/cell-wire --capture-resolution 960x540 --wire-motion --wire-states
```

Add `--wire-no-msaa` for the no-MSAA check. Normal three-view captures remain the
default; study flags only affect this probe, not gameplay.

## Remaining limits

Transparent filtering adds blend/overdraw cost, with no geometry increase.
Native M1/16GB timing, full-arena highlights and exhaustive camera/door/roof
motion remain unverified. Broad specular veiling is still visible at grazing
angles and must not hide wrestlers under arena lights. Narrower built-up member
profiles, woven wire intersections and local fabrication detail remain open.

## Mac review targets

Review a cell match under arena lights: read both wrestlers through overlapping
walls, move the camera across grazing roof angles, open the door, and break a
roof panel. Check for a metallic film, shimmer or disappearing strands. Capture
frame-time spikes on the targetM1/16GB alongside the 16.67ms budget; these cloud
studies do not establish native frame pacing.

## Next bounded Blender refinement

Specialist recommendation, not yet implemented: replace `roof_truss()`'s flat
120mm walking strip with a shallow formed profile, retaining width, endpoints
and +.010m top. Suggested edge lands15mm, centre recess4mm, sheet thickness4mm,
and short downward folds. The paired-edge read is supported by the2K25 roof
view; the exact section is inferred and must be judged from a close roof view
before retention. Preserve +.027m fastener maximum, roof standing height,
panel origins, node/material counts and gameplay; avoid a triangle increase.

## Publication receipt

Verified13November2026: `mac-latest` resolves to
`b40f7721948520b5004cbdaca46d46af49ec2d68`.
[Mac run43502575366](https://github.com/denhamd2/aegis/actions/runs/43502575366)
succeeded; `Aegis.zip` is1,056,076,611bytes.
[Download](https://github.com/denhamd2/aegis/releases/tag/mac-latest).
Exact-commit [CI43502575462](https://github.com/denhamd2/aegis/actions/runs/43502575462)
was still running at publication; 35/35 local affected cases pass.
Owner Mac visual review and native performance remain open.
