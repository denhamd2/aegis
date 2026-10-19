# Player production checks

Read the relevant branch when editing or validating that system. These lessons come from the Beechlawn body/head/kit passes and the transferable methods used on Roman/Cody; reuse the methods, not wrestler meshes, texture values or hero budgets.

## Shared assets and independent heads

- Inspect the currently shipped `.blend` and GLB before invoking a generator. Keep source hashes or curve/rest-pose digests for systems meant to survive unchanged. Older base generators may omit later shared role, presentation or turn corrections.
- A mesh with the same bone names can still have different JOINTS indices, bind ordering or inverse binds. Compare the actual imported Skin against the live skeleton before swapping it. Exercise head/neck motion, not just a neutral still.
- A new skull or eye layout may require matching eyeball and hair meshes. Package those parts together, keeping the shared body and animation library single. Apply the override by player identity; verify another teammate and the opposition retain the base.
- Sculpt deltas require matching topology fingerprints. Changing topology needs an explicit transfer and a new version; silent index reuse corrupts heads. Preserve the seam region and its weights.

## Geometry and deformation

- Independent open head/body islands can acquire opposite winding after normal recalculation. Check outward orientation and shared neck positions **and shading normals**; coincident positions alone do not prove a clean join.
- An anatomically plausible rest pose can still deform badly. The leg retarget pass exposed bone-roll differences despite matching joint positions: sample joint paths, foot orientation and complete clips. Do not alter rest transforms merely to improve a static render.
- Clay views isolate wrong cheek/jaw/orbit/nose planes from albedo or lighting problems. Compare the same lens/view before changing several systems together. Keep identity and expression separate, particularly for smiling owner photos.
- Prioritise the five largest visible mismatches. More polygons, pores, strand cards or gloss do not establish likeness. Explicitly retain uncertain profile dimensions when only a frontal photo is available.

## Kit, UV and colour

- Construct garment edges and joins: silhouette defects at collar, shoulder, sleeves, shorts and hem survive even a high-resolution print. Inspect raised arms and stride poses for clipping and exposed proxy seams.
- Use the archived kit boards and the reference plan's owner corrections. Typography, badges and sponsors are part of the garment's full graphic layout, not independent guessed labels. Keep the original oval crest proportions.
- Check UV triangles after triangulation/export: a printed panel can accidentally sample a plain trim region even if the overall UV rectangle looks valid. Inspect seams, mirrored lettering and mip bleed.
- A saved/reloaded PNG can shade differently from a generated Blender image buffer if colour spaces are mishandled. Review both Blender and glTF/Godot colour, and keep data maps non-colour.
- Skin detail should follow anatomical islands. Photograph projection brings perspective, lighting and expression with it; a front face patch cannot repair a sculpt or produce plausible side views.
- Hair needs its own pigment/roughness response. Smooth coarse root-shell edges, bury card roots and taper tips; check opaque scalp seams and alpha-tested coverage in the engine. Extra cards increase overdraw even when triangle counts look low.
- Inspect hair with the root shell hidden as well as together: a smooth opaque cap plus sparse tufts reads as painted hair. Curved guide geometry, varied clump size/direction and layered root coverage must carry the silhouette. A scalp-normal override on every strip can erase the groom's dimensional response; compare geometric normals and restrain broad white highlights. Check scalp intersections again after shell smoothing and at mip distance.

## Evidence and runtime

- Keep original references immutable and separate from runtime textures. Archive a fresh original photo before using it; source-derived estimates are not biometric measurements.
- Store fixed before/after portraits and clay views, then capture the exported mesh in Godot. Promotional image generation and studio beauty renders cannot certify match visuals.
- Pose evaluation and resource sharing must survive scene changes, lineup/intro, kickoff and player switching. Count actual live rigs so a cosmetic override does not leave a second animated actor behind.
- A passing weight/import check proves structural compatibility, not artistic approval. Report remaining gaps. Software rendering does not establish native Metal appearance, Mac fullscreen or M1 frame times.
- For cloud screenshots, verify the capture mode and first-draw/freeze hooks before blaming the asset. Software capture flags in this project are debug-only; a release export keeps full rendering. The isolated player review needs its own freeze hook. Test release menu/layout separately, use debug software captures for pose/integration, and retain native visual/performance acceptance.
