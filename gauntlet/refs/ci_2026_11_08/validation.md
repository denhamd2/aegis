# ID 7: affected-suite selection, suite profiling and Mac-only delivery

Date: 8 November 2026. Scope: [quality plan](../incremental_quality_plan.md) ID 7.
Status: implemented and locally validated; CI execution and native timings await
publication. Do not read this as a measured CI saving, a measured suite profile
or native Mac evidence.

## What changed

| Piece | Change |
| --- | --- |
| `tools/ci/select_tests.py` | Maps a change to the gdUnit suites that can reach it, through `res://` references plus `class_name`/autoload identifiers. Every uncertain answer is `full`. |
| `tools/ci/profile_suite.py` | Reads gdUnit4's JUnit `results.xml`: slowest suites, slowest cases, and **fixed setup** per suite (suite time minus the sum of its case times). |
| `.github/workflows/ci.yml` | Selects suites before installing Godot; skips the Godot import and run for docs/workflow-only changes; runs the selected subset otherwise; keeps the report and profile as an artifact. Merges the three Python-only jobs into one, so they share a single checkout. |
| Web publishing | `.github/workflows/pages.yml` deleted; the `Web` export preset removed and the remaining presets renumbered. Mac (`macOS`, preset 0) and Linux (preset 1, not published) remain. |

## Dependency audit before retiring Web publishing

Searched the repository for the Web preset, Pages workflow and build output:

- `game/export_presets.cfg`'s `Web` preset was referenced only by
  `.github/workflows/pages.yml` and `README.md`.
- `.github/workflows/mac.yml` exports by the preset **name** `macOS`, so
  renumbering presets cannot redirect the Mac build.
- The Linux preset is independent and is kept for local parity.
- Football (`games/beechlawn_rovers/**`) has its own Web build tools and
  `build/web` output. They are a separate Godot project and were not touched.
  `.github/workflows/retire-beechlawn-web.yml` remains for its pending one-time
  Pages cleanup.
- `gl_compatibility` fallbacks in rendering code (`arena_lighting.gd`,
  `stage_video.gd`, `material_library.gd`, `title_screen.gd`) are renderer
  support, not publishing. They stay; only comments that described the Web
  build as a current target were reworded.
- Deleting the workflow stops future Web deployments; it does not take down
  the already-published Pages site. Removing the site itself is a
  repository-settings action (or the pending football retirement workflow),
  outside this change.

## Local measurements (Termux, Python only — no Godot)

Selector on this checkout (798 indexed game files, 151 suites):

| Change | Result | Time |
| --- | --- | --- |
| `gauntlet/refs/next_steps.md` (docs) | `none` | 0.14 s |
| `game/tests/test_blood.gd` (one suite) | `subset`, 1/151 | 3.7 s |
| `game/core/ai/wrestler_ai.gd` (core) | `full`, 146/151 affected | 3.9 s |

The first version spent minutes in `index()`: it searched every file once per
declared `class_name` (798 × 120 regexes over 70 MB). A single identifier-token
pass gives the same 10,772 hits in about 2 s. Prose mentions are not the cause
of the density: removing comments and strings moves a core change from 146 to
131 affected suites, still above the 80% full-suite threshold. Core coupling is
real, so core edits correctly pay for a full run; the saving is concentrated in
docs/workflow-only pushes and isolated test or resource edits.

Self-tests: **28 pass** (`python3 -m unittest discover -s tools/ci/tests`),
covering direct/transitive `res://` and `class_name` edges, autoload use,
non-dependency text, every full-suite fallback, the `.github/` path
normalisation regression, deleted files, `--output`, and the profiler against
JUnit fixtures.

## Not measured / remaining limitations

- **No Godot or gdUnit run was made here.** Termux has no Godot binary and no
  remote executor is configured. The selected-subset invocation (`-a` repeated),
  the report path and the CI job behaviour are implemented but have not been
  executed. The first push must show them working.
- **No CI saving is claimed.** Suite wall time, setup share and selection
  savings require a real run. `tools/ci/profile_suite.py` is wired to produce
  those numbers; its output is the input for reducing repeated test setup.
- **Test-fixture consolidation is deliberately not done yet.** With no way to
  run GdUnit locally, refactoring scene setup across ~52 suites would be
  unvalidated. The profiler exists to target that work with evidence.
- Native M1 performance and owner Mac appearance review remain open for the ID 8
  publication (`bf053267`, below).
