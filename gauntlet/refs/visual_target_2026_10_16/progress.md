# October 16 visual target — implementation record

Status: shared-look and first character checkpoints. **NO-SHIP for final visual acceptance.**
The eight-reference target has not been reached. Published baseline: `fb69eae`.

The owner's confirmed target is an Apple M1 Pro with 16 GB unified memory,
steady 60 fps, free assets/existing tools, and skin matching the new references.
Use 1920×1080 internal rendering for the first native measurement; the actual
play resolution remains unconfirmed. The [plan](plan.md) and
[source manifest](source_manifest.json) retain the eight pairs and research.

## Implemented in this pass

- Separate, deterministic roughness and wet-film maps. Head masks exclude
  painted scalp; Cody's forehead/nose/lips have distinct roughness response.
  His head now uses a lower pore tiling density than his body atlas.
- A visible entrance wet layer with modest, bounded match progression, plus
  lower subsurface scattering to retain facial and shoulder planes. Existing
  base colour, tattoos, mesh geometry, skeletons and animation clips remain
  the basis of this pass.
- A wider off-axis entrance key, reduced frontal fill and follow-spot energy,
  and one soft shadow-casting walk key. Brighter entrance audience wash;
  existing aisle-dimming constraint retained.
- Brighter, less uniformly rough aluminium truss material with restrained
  normal relief. These are material/light calibration changes, not a rebuild
  of the set or crowd.
- Three repeatable proof views (`stage`, `roman_ramp`, `cody_coat`) in
  `game/tools/probe/visual_target_proofs.tscn`, integrated into
  `tools/capture/native_reference.sh`. Camera motion is disabled for these
  still comparisons. Metadata names renderer, driver, adapter, software
  rasterisation, resolution, sampling mode and material/light settings.

## Reflection experiment — disabled by default

A cached, boxed stage reflection probe is available only for explicit review
with `--stage-probe`. Its capture mask includes static stage/truss/fixture
geometry and excludes wrestlers, carried props and camera-facing glints.

The cloud Forward+/Vulkan llvmpipe preview turns black when this probe is
enabled. Hiding it restores the character and stage. Disabling SSR, SSIL and
SSAO did not restore the image. This is an unresolved probe/backend interaction,
not evidence that native Metal is correct. The default game keeps its existing
reflection setup. Do not enable the extra probe until its native proof passes.

## Review scope and next work

The cloud has a locally installed Xvfb and software Vulkan driver but only
8 GiB available to the process group. Full-arena proof attempts approached
that limit. Bounded studies load the real stage/material adapters without
copying the complete animation library. They use a bind pose and only the
walk key/back light; they do not establish animation quality, coat/necklace
fit, complete-arena lighting, Metal equivalence or Mac frame rate. Fog/glint
isolation is recorded in their manifests. Failed or ablated diagnostic shots
must not be presented as gameplay proofs.

The [first character checkpoint](character_review.md) replaces Cody's shell
hair with a 16,844-triangle cap/card groom, adds Roman beard material detail,
calms Cody's iris tint and softens facial wet highlights. The same six
portrait cameras were reviewed before/after. It is an incremental result;
likeness, root/beard transitions and coat construction remain major gaps.

Next: finish native shared-look/portrait comparisons and continue the character
phase (facial forms, skin relief, eye/hair/beard construction,
anatomy/correctives, coat/belt/necklace), ring/audience refinement and the
moving-image/performance pass. Do not expand
costly rendering features without measuring the target Mac. The existing
fixed 60 Hz simulation, paired contact and replay rules remain authoritative.

On the Mac, run the complete appearance/pacing tool against the preview app:

```bash
bash tools/capture/native_reference.sh /path/to/Aegis.app /path/to/captures
```

The fixed-clock proof shots are appearance evidence. Only the separate
real-time `match_look` sample is intended for frame pacing; a 60 fps target
has not yet been verified on the owner's Mac.

Validation results are recorded in [validation.md](validation.md).
