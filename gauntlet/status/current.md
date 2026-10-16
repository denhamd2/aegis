# Current task — October 16, 2026

The owner approved implementing the eight-reference visual plan. Target:
Apple M1 Pro, 16 GB, steady 60 fps; prefer free assets and existing tools;
match the new references' skin. Initially benchmark at 1080p internal.

Published baseline before this update: `fb69eae`; consult the mac-latest release for the current published revision. The first material/lighting checkpoint is
`fdf97e0`; `3405825` adds a finer Cody groom, beard detail
and softer facial wet highlights. The next Roman face checkpoint refits the
face, rebuilds the portrait maps and fixes inverted/elongated blink caps.
These are incremental studies, not final AAA acceptance or a new published release. The checkpoint branch is
`codex/oct16-visual-look`. The local universal Mac preview lives in
`build/mac-visual-preview/Aegis.zip`; consult its artifact metadata for revision.

Start with the [visual plan](../refs/visual_target_2026_10_16/plan.md),
[implementation record](../refs/visual_target_2026_10_16/progress.md) and
[validation](../refs/visual_target_2026_10_16/validation.md). The
[character review](../refs/visual_target_2026_10_16/character_review.md) contains
the previous twelve before/after portraits. The [Roman face review](../refs/visual_target_2026_10_16/roman_face_review.md)
adds a same-camera comparison viewer, closed-blink diagnostics and six adapted
pose samples. Final affected checks: **43/43 passed** (`report_417`). The full
round clip-authoring pin failure remains open; no gate was repinned.

The experimental cached stage probe remains disabled: cloud software Vulkan
produces black output with it. Preserve that default pending native review.
Never infer native Metal appearance or M1 Pro frame time from CPU rendering.

Character reconstruction, all eight native reference comparisons, motion
review and native performance acceptance remain open. Preserve fixed-tick
gameplay, seeded replays and GrappleRig contact while doing cosmetic work.

Latest: [reference-directed Roman rebuild](../refs/visual_target_2026_10_16/roman_reference_rebuild.md).
The owner accepted this version for now and requested all accumulated changes
committed and published in the Mac build. Final affected material/face/hair/state
checks: 25/25 passed, plus the physics-synchronized state test suite 6/6 passed
(overlapping coverage). Full round: 962/964 passed before final follow-ups;
one timing failure was repaired, the baseline authoring pin remains open.
The rejected dense-fit experiment is outside the repository. Native performance
and final eight-reference acceptance remain unverified.
