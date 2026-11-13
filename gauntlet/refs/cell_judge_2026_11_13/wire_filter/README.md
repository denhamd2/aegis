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
see [regression report](regression-tests.xml).

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
