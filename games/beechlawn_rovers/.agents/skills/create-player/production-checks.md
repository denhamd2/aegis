# Player production checks

Read the relevant branch when editing or validating that system. These lessons come from the Beechlawn body/head/kit passes and the transferable methods used on Roman/Cody; reuse the methods, not wrestler meshes, texture values or hero budgets.

## Shared assets and independent heads

- Inspect the currently shipped `.blend` and GLB before invoking a generator. Keep source hashes or curve/rest-pose digests for systems meant to survive unchanged. Older base generators may omit later shared role, presentation or turn corrections.
- A mesh with the same bone names can still have different JOINTS indices, bind ordering or inverse binds. Compare the actual imported Skin against the live skeleton before swapping it. Exercise head/neck motion, not just a neutral still.
- A new skull or eye layout may require matching eyeballs and refitted hair. The head package carries head/eyes; hair selection is independent. Keep the shared body and animation library single. Verify another teammate and the opposition retain their assigned head/hair.
- Sculpt deltas require topology, coordinate-Basis and UV/weight fingerprints. A topology hash alone accepts stale sculpts after a common edit. Rebase compatible offsets against recorded master snapshots; transfer changed topology or UV/weights explicitly. Translate all expression keys with each identity offset so expression deltas remain intact. See the shared head pipeline linked by the main skill for source/build commands.

## Geometry and deformation

- Independent open head/body islands can acquire opposite winding after normal recalculation. Check outward orientation and shared neck positions **and shading normals**; coincident positions alone do not prove a clean join.
- Clay views isolate wrong cheek/jaw/orbit/nose planes from albedo or lighting problems. Compare the same lens/view before changing several systems together. Keep identity and expression separate, particularly for smiling owner photos.
- Prioritise the five largest visible mismatches. More polygons, pores, strand cards or gloss do not establish likeness. Explicitly retain uncertain profile dimensions when only a frontal photo is available.

## Skin, hair and colour

- A saved/reloaded PNG can shade differently from a generated Blender image buffer if colour spaces are mishandled. Review both Blender and glTF/Godot colour, and keep data maps non-colour.
- Skin detail should follow anatomical islands. Photograph projection brings perspective, lighting and expression with it; a front face patch cannot repair a sculpt or produce plausible side views.
- Hair needs its own pigment/roughness response. Smooth coarse root-shell edges, bury card roots and taper tips; check opaque scalp seams and alpha-tested coverage in the engine. Extra cards increase overdraw even when triangle counts look low.
- Inspect hair with the root shell hidden as well as together: a smooth opaque cap plus sparse tufts reads as painted hair. Curved guide geometry, varied clump size/direction and layered root coverage must carry the silhouette. A scalp-normal override on every strip can erase the groom's dimensional response; compare geometric normals and restrain broad white highlights. Check scalp intersections again after shell smoothing and at mip distance.

## Evidence and runtime

- Label the actual source, head variant, material/atlas and renderer used for each capture. Shared-body Blender reviews can still use an older diagnostic head while the roster uses separate current head packages. Compare equivalent assets, views and lighting; promotional artwork cannot certify the playable mesh.
- A passing weight/import check proves structural compatibility, not artistic approval. Report remaining gaps. Software rendering does not establish native Metal appearance, Mac fullscreen or M1 frame times.
- For cloud screenshots, verify the capture mode and first-draw/freeze hooks before blaming the asset. Software capture flags in this project are debug-only; a release export keeps full rendering. Use `tools/capture/capture_beechlawn_web.py` or the existing Playwright harness; Chromium's CLI screenshot/idle wait can stall on Godot's continuous render loop. The isolated player review needs its own ready/freeze hook. Test release menu/layout separately, use debug software captures for pose/integration, and retain native visual/performance acceptance.

## Safe editing and bounded tools

- Inspect a tool's mutation scope before invoking it. Prefer read-only audit and disposable preview modes, then apply a validated change to the current source. Keep local diagnostic cohorts consistent or explicitly remap them after topology edits; counts from different meshes are not directly comparable.
- Snapshot Blender vertex-group assignments before editing them. When custom-normal attributes or mesh data change, reacquire affected RNA references before reading UVs or weights; stale handles can silently produce invalid data.
- Run headless Blender with `--python-exit-code 1` and a hard process deadline. A traceback can otherwise leave a successful process exit. Check expected fresh outputs and logs as well as exit status. EGL fallback warnings alone do not establish a failed render if the image and clean completion are present.
- Use the project's disposable Web-review helper and inspect its current options. Large imported-texture caches filled the cloud runner's separate `/tmp` volume; staging now belongs under ignored `build/review-scratch`, with cleanup in `finally`. Check free space before retrying a copy/export failure. Preserve `docs/.gdignore` so evidence images do not become runtime imports.
- Keep simulations, exports and browser captures bounded, and wait for dependent stages to finish before using their outputs. Diagnose a failed or timed-out process before rerunning it; use the existing serial Godot test runner and browser readiness/freeze hooks.
