# Player production checks

Read before choosing tools for any player task. Detailed face/skin/hair checks live in [head production](head-production.md), cloth checks in [garment production](garment-production.md), and motion checks in [animation production](animation-production.md). Reuse transferable methods learned on Roman/Cody, not wrestler meshes, texture targets or hero budgets.

## Shared assets and independent heads

- Inspect the currently shipped `.blend` and GLB before invoking a generator. Keep source hashes or curve/rest-pose digests for systems meant to survive unchanged. Older base generators may omit later shared role, presentation or turn corrections.
- A mesh with the same bone names can still have different JOINTS indices, bind ordering or inverse binds. Compare the actual imported Skin against the live skeleton before swapping it. Exercise head/neck motion, not just a neutral still.
- Share body/kit/animation content while keeping playback and intended identity overrides independent. Validate another teammate, opposition, goalkeeper and referee. For captured sculpts, source/export audits and matching head/eye/hair packages, use the head-production gates.

## Geometry and deformation

- Independent open head/body islands can acquire opposite winding after normal recalculation. Check outward orientation and shared neck positions **and shading normals**; coincident positions alone do not prove a clean join.
- Keep sampled triangle/vertex cohorts fixed across comparisons; deliberately remap after topology changes. Lower counts from a different cohort do not demonstrate a repair.

## Evidence and runtime

- Label the actual source, head variant, material/atlas and renderer used for each capture. Shared-body Blender reviews can still use an older diagnostic head while the roster uses separate current head packages. Compare equivalent assets, views and lighting; promotional artwork cannot certify the playable mesh.
- A passing weight/import check proves structural compatibility, not artistic approval. Use the main skill's final-quality gate and record visible finishing tasks. Software rendering does not establish native Metal appearance, Mac fullscreen or M1 frame times.
- For cloud screenshots, use Playwright with the scene's first-draw/ready **and freeze** hooks. Ready alone did not prevent readback starvation on a continuously drawing SwiftShader canvas. Use `tools/capture/capture_beechlawn_web.py` or the isolated review helper; keep startup, screenshot and cleanup bounded. Test release menu/layout separately from debug software capture.

## Safe editing and bounded tools

- Inspect a tool's mutation scope before invoking it. Prefer read-only audit and disposable preview modes, then apply a validated change to the current source. Keep local diagnostic cohorts consistent or explicitly remap them after topology edits; counts from different meshes are not directly comparable.
- Snapshot Blender vertex-group assignments before editing them. When custom-normal attributes or mesh data change, reacquire affected RNA references before reading UVs or weights; stale handles can silently produce invalid data.
- Run headless Blender with `--python-exit-code 1` and a hard process deadline. A traceback can otherwise leave a successful process exit. Check expected fresh outputs and logs as well as exit status. EGL fallback warnings alone do not establish a failed render if the image and clean completion are present.
- Use the project's native Forward+ capture runner and inspect its current options. Keep large temporary captures/caches in ignored project build storage: the separate `/tmp` volume previously filled during obsolete Web exports. Check free space before retrying copy/export failures. Preserve `docs/.gdignore` so evidence images do not become runtime imports.
- Keep simulations, exports and native captures bounded, and wait for dependent stages to finish before using their outputs. Diagnose a failed or timed-out process before rerunning it; use the existing serial Godot test runner and native draw/readback completion markers.
