# BR-022 collar and raglan finish

Item 22 of 25, in progress. Baseline e3f3d12. Use create-player,
director/reference-match, character/modeling, UV, rigging and Godot-export
guidance via headless Blender/bpy; no Blender MCP is connected.

References: the archived home kit object board
file_000000000da0824386b7ef8edd3a9c79.png, Shane turnaround
file_00000000d76881f48f576ff4249aa3b2.png and Bordeaux board
file_000000008a9881f49c8ce1ebe2521b75.png under source_uploads/drive_folder.
The home kit shows a smooth, narrow black V binding with blue trim and raglan
lines travelling from neckline to armhole. Keep the supplied original marks,
Thomas Loomes & Co, centered Uhlsport and the oval EST 2004 crest.

Prioritized gaps:
1. Neckline retains irregular tiny edge spans and side/back height steps.
2. Narrow binding copies those steps and has inconsistent visual width.
3. Actual Godot home atlas lacks the blue raglan detail visible in the old
   Blender source atlas, so the two review paths disagree.
4. Raglan line needs to follow the shirt in moving-arm and keeper poses.
5. Cloth micro-detail, exact keeper pattern and individual likeness stay open.

Smooth the local garment opening and fit a regularly sampled binding to it.
Add narrow surface-following raglan strips to the existing collar mesh, using
existing trim swatches and interpolated cloth weights. Align the shared source
preview's pigment image with its current runtime atlas. No image repainting,
new material allocation, runtime cloth or extra mesh parts. Preserve body/skin
including neck normals, independent heads, 65 bone rests and all 19 clips.
Keep waist and exposed-arm regressions intact. Render matching runtime-atlas
close-ups, both sleeve variants and fixed moving-arm poses; then use actual
Godot roster appearance and Play/Watch checks. Native M1 performance stays open.

## Accepted local result

The first closest-point projected collar strip collapsed at two neighbouring
samples and later still looked lumpy in the close-up. It was rejected. A clean
parametric V loft now shapes the opening and its first cloth rows together,
with a short falloff into the existing shirt. The higher sides/back retain the
front V while clearing the source skin. The band is evenly sampled and fitted
to that supporting loft; all raglan strip points follow the actual shirt
surface and inherit interpolated, normalized cloth weights (maximum four).

On each sleeve variant, the neck fit moves 770 vertices by at most 2.029 cm.
A further 16 local yoke-clearance adjustments are at most 4.42 mm. Body, neck
normals, head packages, original shirt topology/UVs/weights, cuffs, bone rests
and all animation curves remain protected by the source hash. The same
11,878-triangle shirt cohort remains at 975 inverted samples summed across
nine poses; it has not been made fold-free by this local change.

The new trim has 96 collar samples, a nominal 1.05 cm band and four 5.4 mm
raglan strips. It adds 960 triangles overall, bringing all-variant geometry to
68,244 triangles, with the same 16 mesh parts, 65 bones and 19 clips. These
counts include both shirt variants and are not measured per-actor GPU cost.
The maximum pre-offset collar-to-supporting-cloth gap is about 1.12 mm.

No kit image is repainted. The shared Blender source now loads the existing
home-role pigment rather than the old identity-baked preview atlas. Godot's
extracted default image `footballer_base_beechlawn_outfield.png` has the exact
same SHA256 as `textures/shared/beechlawn_outfield.png`. Existing role material
replacement still handles both teams, keepers and referee. The trim occupies
the existing binding mesh/material and atlas colour swatches.

## Regression and integration evidence

`validate_shared_collar.py` checks actual evaluated mesh data with a 0.1 mm
numerical tolerance. It fails on the e3f3d12 source with 6–8 penetrating collar
vertices per pose, reaching about 2.8 mm penetration. On the final source,
all 480 sampled collar vertices clear the evaluated skin in each of nine
poses; minimum signed clearance is about 2.23 mm. All 1,536 new trim triangles
remain nondegenerate and have zero inversions in those fixed poses. These
vertex/triangle samples do not establish all-pose or per-pixel acceptance.

The general source validator also retains all 12 bare-arm probes, 20 posed
waist overlap samples, sculpt-delta compatibility and non-T-pose locomotion;
the binding now participates in its max-four normalized-weight check.
Shared-head roster, shared resources, pose safety and 11v11 headless checks
pass. Six actual Web views cover Shane front/pass/back, Bordeaux short sleeves,
John in a save and the referee, without browser errors. Play/Watch, kickoff,
options, return-to-title and minimum UI layout checks pass in software WebGL.

`source_comparison.jpg` uses matched Blender close-ups with the runtime atlas
on both sides. `before_after.jpg` compares the previous and current Godot roster
path. Both sleeve variants have nine-pose sheets. Blender heads are the older
base diagnostic; Web captures use the live independent heads. Asset fixtures
disable sun shadows for software rendering. Native Mac was not run.

The first disposable Web export ran out of space while copying imports into
the cloud runner's separate 4.9 GB /tmp volume. Known previous review/download
outputs were removed, and the helper now stages its cache under ignored
`build/review-scratch`, hides it from Godot and removes it in `finally`. The
same import/export then passed, with existing hard deadlines retained.

BR-022 (22/25) remains in progress. Next refine fabric normal/roughness response
against the kit references under the match's sun and shade, retaining the
shared fit and these skin/waist/pose checks. Exact keeper graphics, individual
likeness and native M1 1080p/60 performance remain open acceptance gates.
