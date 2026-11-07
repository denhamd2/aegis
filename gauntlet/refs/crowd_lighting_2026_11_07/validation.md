# Release 1 validation — resumed 7 November 2026

Status: **34 focused tests and isolated shader rendering pass; owner authorised
Mac publication and will review arena appearance on their Mac**.
This records validation for [PR #13](https://github.com/denhamd2/aegis/pull/13).
Native appearance and M1 performance remain unverified. Earlier GPU-host
requirements below are historical; they do not block publication under the
owner's latest instruction.

## Passing checks

Godot 4.6.3 and gdUnit4 v6.2.1, after initial asset import completed:

- **34 cases, 0 errors, 0 failures**, exit code 0; 3.562 seconds reported by
  the runner. Inspect the [JUnit report](focused_tests.xml).
- Suites: `test_reference_visuals`, `test_arena_beams`, `test_stage_lighting`,
  `test_arena_crowd`, and `test_floor_crowd`.
- Includes the new real-rig check that dimming the audience leaves match
  exposure and ring-key energies unchanged, plus the existing fixture-coverage,
  crowd-colour, mesh, UV and placement checks.

Command, with writable XDG data/cache/config directories set for this host:

```sh
godot --headless --path game \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/test_reference_visuals.gd \
  -a res://tests/test_arena_beams.gd \
  -a res://tests/test_stage_lighting.gd \
  -a res://tests/test_arena_crowd.gd \
  -a res://tests/test_floor_crowd.gd \
  -c --ignoreHeadlessMode
```

These headless checks do not establish rendered lighting, GPU shader behaviour,
Mac appearance or frame pacing. The earlier pre-import failing test run is
superseded by this successful post-import run.

## Isolated shader render

Both changed shader paths compiled and rendered successfully through Vulkan
Forward+ in a small standalone scene: exit code 0, 24 settle frames, saved
960×540 image, no shader errors in the process log. The six bowl-material boxes
span world X = 14, 24 and 34 metres at world Y = 1 and 9 metres; the image shows
fill decreasing with distance and elevation. A seventh box compiles the actual
photographic `Fan00` material. This checks the shader path, not real spectator
geometry, full-arena lighting or character deformation.

Inspect the [image](diagnostic/material_check.png),
[exact diagnostic source](diagnostic/material_check.gd) and
[recorded provenance](diagnostic/manifest.json). This process used llvmpipe,
`LP_NUM_THREADS=2` and `GALLIVM_PERF=nopt`. Its simple environment intentionally
omits arena post-processing. It is component evidence only and is not a
passing full-arena evidence-gate manifest or an M1 performance sample.

## Full-arena capture attempts

The recovered executor has an **8 GiB cgroup memory limit** and no configured
hardware Vulkan device. The driver reports Forward+ via Vulkan on
`llvmpipe (LLVM 19.1.7, 256 bits)`. Software rendering cannot measure M1 performance.

Baseline source was restored from `90815cb` for comparison, while draft source
was backed up and restored in a `finally` block. The restored working files
were checked after each attempt; no draft shader edits were lost.

The retries used `reference_look.tscn`, the complete arena geometry and lighting,
the normal master camera, 960×540, fixed 60 Hz and `--environment-only` to omit
actors and match logic. These are explicitly asset-only captures, not complete
match or performance evidence.

| Attempt | Result |
| --- | --- |
| 24 settle frames; conservative 6,500 MiB total-memory guard | Guard stopped the process after 198.82 s. Approximately 2 GiB was file cache, so this total-memory limit was unnecessarily conservative. No comparison image was saved. |
| 24 settle frames; 6,000 MiB guard on anonymous/kernel/shared memory | Timed out after 420.04 s. Peak cgroup usage including file cache: 7,246,897,152 bytes. No comparison image or acceptance manifest was saved. |
| Short two-frame compiler diagnostic, `GALLIVM_PERF=nopt` | Timed out after 180.36 s. Peak total usage including file cache: 6,970,806,272 bytes. No comparison image or acceptance manifest was saved. |

Live X11 previews of the **baseline** showed severe white clipping and later
large black regions. The compiler diagnostic showed the same unusable preview.
These interim display grabs are diagnostic only; they have neither converged
capture metadata nor a passing evidence gate. They cannot establish how the
published Mac app looks, a reference match, or a lighting improvement.

The Mesa option exists in the installed driver; its meaning is documented in
the [Mesa Gallivm source](https://chromium.googlesource.com/external/gitlab.freedesktop.org/mesa/mesa/+/60a06a90cb77414b3276edddbd5f8bb5fafd684c/src/gallium/auxiliary/gallivm/lp_bld_init.c).
It was confined to the diagnostic process; game settings and CI were unchanged.

Prior cgroup counters recorded four out-of-memory kills. Those counters did
not increase during the guarded retries. The capture faults' precise cause
remains unresolved; do not claim a confirmed engine or driver defect.

## Remaining release gate

Obtain usable before/after full-arena Forward+ captures on a suitable host,
including normal match and low/entrance coverage, and tune the provisional
shader values against the three AEW stills. A GPU-capable environment or native
Mac review is needed to resolve the current visual blocker. Native M1 frame
pacing and memory pressure remain unverified.

The owner selected **a GPU-capable environment** for the remaining review.
The only attached executor exposes no hardware Vulkan device, `/dev/dri` or
NVIDIA device nodes, and the available tools expose no GPU provisioning or
environment-switch action. A GPU host must be attached/configured before the
remaining capture can run. Keep using the saved draft and passing evidence;
do not restart the earlier failed test/import work.

No preview, production release, Release 2 work or Web-retirement change has
been published during this resume.
