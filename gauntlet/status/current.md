# Current task — October 16, 2026

The owner approved implementing the eight-reference visual plan. Target:
Apple M1 Pro, 16 GB, steady 60 fps; prefer free assets and existing tools;
match the new references' skin. Initially benchmark at 1080p internal.

Published baseline: `fb69eae`. Current work is the first material/lighting
pass and proof tooling, not final AAA acceptance or a new published release.
The checkpoint branch is `codex/oct16-visual-look`. A local universal Mac
preview is in `build/mac-visual-preview/Aegis.zip`; native validation is open.

Start with the [visual plan](../refs/visual_target_2026_10_16/plan.md),
[implementation record](../refs/visual_target_2026_10_16/progress.md) and
[validation](../refs/visual_target_2026_10_16/validation.md).

The experimental cached stage probe remains disabled: cloud software Vulkan
produces black output with it. Preserve that default pending native review.
Never infer native Metal appearance or M1 Pro frame time from CPU rendering.

Character reconstruction, all eight native reference comparisons, motion
review and native performance acceptance remain open. Preserve fixed-tick
gameplay, seeded replays and GrappleRig contact while doing cosmetic work.
