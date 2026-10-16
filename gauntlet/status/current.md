# Current task — October 16, 2026

The owner approved implementing the eight-reference visual plan. Target:
Apple M1 Pro, 16 GB, steady 60 fps; prefer free assets and existing tools;
match the new references' skin. Initially benchmark at 1080p internal.

Published baseline: `fb69eae`. The first material/lighting checkpoint is
`fdf97e0`; the next character checkpoint adds a finer Cody groom, beard detail
and softer facial wet highlights. These are incremental studies, not final
AAA acceptance or a new published release. The checkpoint branch is
`codex/oct16-visual-look`. The local universal Mac preview lives in
`build/mac-visual-preview/Aegis.zip`; consult its artifact metadata for revision.

Start with the [visual plan](../refs/visual_target_2026_10_16/plan.md),
[implementation record](../refs/visual_target_2026_10_16/progress.md) and
[validation](../refs/visual_target_2026_10_16/validation.md). The
[character review](../refs/visual_target_2026_10_16/character_review.md) contains
all twelve before/after portraits and the remaining art defects. Final
affected character checks: 32/32 passed. The historical full-suite
clip-authoring pin failure remains open; no gate was repinned.

The experimental cached stage probe remains disabled: cloud software Vulkan
produces black output with it. Preserve that default pending native review.
Never infer native Metal appearance or M1 Pro frame time from CPU rendering.

Character reconstruction, all eight native reference comparisons, motion
review and native performance acceptance remain open. Preserve fixed-tick
gameplay, seeded replays and GrappleRig contact while doing cosmetic work.
