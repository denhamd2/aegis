# Release 1 handover — crowd lighting

Status: published for owner Mac review at
`d59d830dc51b7ec4bccd89dbd0e0167f7e3f0402`. The successful Mac job, matching
`mac-latest` tag SHA and `Aegis.zip` asset were verified. Arena appearance and
native M1 performance await owner review. The owner subsequently approved
related batches: priorities 2–3 together, then 4–6. Earlier GPU-host blockers
below are historical and do not block publication under that instruction.

## Resume result — 7 November

The workspace recovered, the saved draft branch was checked out, and latest
main was merged. The complete focused run now passes: **34 tests, zero errors
or failures** after asset import. The source restoration ambiguity below is
resolved: the saved draft is intact and comparison attempts restore it.
See [the validation record](crowd_lighting_2026_11_07/validation.md) and its
JUnit report for the passing checks and bounded-render results.
Both changed shader paths also compiled/rendered in an isolated Forward+
diagnostic, with the expected depth/height fade; its source, PNG and provenance
are preserved in the validation record. Full-arena acceptance is still open.

Full-arena Forward+ software rendering still has no usable saved comparison:
guarded attempts avoid executor loss but show corrupted live previews and
time out. The owner selected a **GPU-capable environment** for visual review.
The only attached 8 GiB executor exposes no GPU device, and no provisioning
or environment-switch tool is available; attach/configure a GPU host next.
Keep the release blocked on appearance review; no new Mac release was made.

The remainder records the original interruption for provenance.

The approved plan and three AEW stills were committed and pushed to main in
debd882bc9b1dd3c543b418591292d25e9898972. The last verified published Mac app
is 492ab0b049a875e29ce2742232d39733645b9046 at mac-latest; it has Aegis.zip.
The owner chose latest main rather than recovery of other-chat uncommitted changes.

## Draft changes

Reduce the distant crowd's house-light floor from 0.06 to 0.018. Add one
shared shader include for a smooth distance/height fade on indirect crowd fill,
including the photographic near-crowd material's residual emission. Keep real
front-row washes, all ring fixtures and exposure settings unchanged. Values
are provisional until before/after full-arena Forward+ images are reviewed.

A focused regression exercises actual audience dimming through ArenaLighting
and checks ring exposure/key energies stay constant. The first focused run
started too early, while initial asset import was running: 34 cases, 43 errors,
22 failures (exit 100), with missing imported meshes/textures in the log. The
new dimming case passed. Do not present that run as a passing suite.

## Interruption and recovery

Godot 4.6.3 and pinned gdUnit4 v6.2.1 were available/prepared. Initial import
finished. A temporary Xvfb and Mesa lavapipe setup in /tmp successfully
initialised Vulkan Forward+ on llvmpipe (LLVM 19.1.7, 256 bits). This is software
rendering and cannot establish Mac performance.

The full-arena baseline reference_look capture at 1280x720, 24 settle frames,
loaded its scene but produced no reviewed image before the executor disconnected.
The renderer process last observed had approximately 6.5 GB RSS. Memory pressure
is a hypothesis, not a confirmed cause. Recovery failed with:
"exec-server transport disconnected; failed to resume exec-server session:
recovery timed out after 45s". The environment was then marked unavailable:
ccarenv_b64_Y2NhcmVudl84ZTZiZDQ1MzVjOTg4MTkxODcwZjZjMGYyMzQxZDZmNQ.

The interrupted local comparison script temporarily restored the two runtime
files to HEAD for baseline capture, with after-versions backed up under
/tmp/aegis-render/after/game/core/arena/. Its finally block's restoration could
not be verified after disconnection. This branch preserves the proposed changes
independently of that local state; use its committed source for recovery.

On a usable render host:
1. Import assets completely before running tests.
2. Run test_reference_visuals, test_arena_beams, test_stage_lighting,
   test_arena_crowd and test_floor_crowd via the existing gdUnit command.
3. Compare base and draft through the same full-arena Forward+ pipeline, camera,
   resolution and settle count. Check the hard camera plus low/entrance coverage.
   Use the established evidence gates; no admissible capture has passed yet.
4. Tune the provisional values against the three saved AEW references.
5. Once validated, commit/push the release to main, wait for mac.yml and verify
   mac-latest targets the exact release commit with Aegis.zip present.
6. Record the result and remaining native M1 limitations before Release 2.
