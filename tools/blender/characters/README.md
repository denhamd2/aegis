# Kenny native authority

`Kenny.blend` owns Kenny's body, 67-bone bind rig/weights, hair, packed seed maps,
owner texture inputs and frozen guide paths. Historical donor provenance is
recorded in its `SeedManifest` text block: this body started as a copy of the
supplied Cody mesh/rig. Independent ownership means no continuing dependency on
Cody's character scripts, identity assets or rebuilds; it does not claim a new
scan or erase that history.

Run from the repository root:

```sh
blender -b --factory-startup --python tools/blender/characters/kenny_character.py -- build
blender -b --factory-startup --python tools/blender/characters/kenny_character.py -- audit
blender -b --factory-startup --python tools/blender/characters/kenny_character.py -- identity-audit
```

Normal builds load only this native source and neutral libraries. They regenerate
the currently recorded revision from the frozen owned seed, preserve the body
topology/binds and write only Kenny game assets. `--round N` is the artist's
explicit revision selector. `bootstrap` is a one-time migration command that
refuses to overwrite an existing source; its captured inputs are historical,
not normal regeneration dependencies. Do not rerun it to pick up donor changes.

The packed `KennyRawSeed` also holds the historical owned body positions and
per-loop normals, fit normal offsets and complete Kenny RELAX/SOFTEN parameters.
This repaired the first capture's loss of cross-UV smoothing and incomplete face
bake. `capture-parity` was a one-time fingerprint-checked migration from project
history; it is not a normal build step or a continuing external input. Normal
builds transport split normals through the sculpt and export fresh tangents.

`COL_Kenny_Seed` holds the hidden frozen baseline meshes. `SeedMap::*` images
and `KennyGuideSeed` text own regeneration inputs; current `Body`/`Curl*` meshes
are editable. To export deliberate manual edits without regenerating them,
save the native file and use the same script's `export` action. `review --out
/tmp/kenny-preview` renders the native preview; acceptance uses the game's locked
views and actual animated poses. Compatibility entry points in `tools/assets/`
and `tools/blender/` route here instead of maintaining other active builders.

The face is baked in the exported body; runtime `KennyFaceShape.apply` must be
disabled. `BodyBulk.KENNY`, skin tint and eye tone remain runtime and are not
baked again. No morph targets are exported, so the game's expression installer
can append its own. Material keys remain stable. The owner's dark-brown eye
choice is preserved. All seed/working maps are packed; source paths are portable.

Cloud renders do not establish native M1 frame time. Keep the existing character
budget and validate appearance, deformation, expression, hair contacts and
performance separately.

The R7 clay-stage source bundle additionally includes `kenny_reference_fit.py`
and `kenny_reference_landmarks.json`. They fit the owned RAW head directly from
explicit neutral-reference measurements instead of the legacy head stack.
Cold rebuilds must copy both files alongside the builder/native source. The
repository reference photograph is optional analysis evidence: when absent,
geometry/audits still build, and only its landmark-overlay PNG is skipped.
The R7 path retains existing pigment/groom until the hair-hidden clay gate
accepts the head. Landmark residuals and local Jacobian bounds are engineering
measurements, not a likeness score or a self-intersection guarantee.

R7 draft2 preserves the exact frozen owned neck seam below 1.575 m. Photo
camera anchors consistently denote iris centres, with uncertainties recorded
in the annotation JSON. The quarter pose includes pitch and perspective;
three camera anchors do not identify lens distance, so sensitivity is reported
and its low residual is not a likeness result. Use `--audit-out PATH` to keep
new drafts separate from archived evidence.

After the clay gate, `surface-author --round 7 --audit-out PATH` is an optional
authoring recipe in `kenny_reference_surface.py`. It reads the confirmed photo
only for that deliberate action, projects onto the accepted mesh's existing
UVs, partially removes broad lighting, and compensates the live tint's chroma
at equal luminance. It packs `SurfaceMap::kenny_head.png` into the native file;
ordinary builds restore this owned map directly without reading a photo or a
game output. Unobserved areas use the packed pre-projection owned map. Repeated
authoring starts from that same fallback rather than the previous projection.
The photographed eye interiors are excluded; the owner-approved brown eyes
remain separate. This low-resolution portrait projection is a surface preview,
not a scan or proof of accepted likeness.

`surface-boundary --round 7 --audit-out PATH` is the subsequent local boundary
recipe. It freezes its preceding owned surface map in the native file and
holds the central face pigment while continuing forehead skin frequency across
the scalp, removing residual temple/nape hair pigment and matching the head
side of actual body-material borders. It does not reopen the photo or alter
geometry. Normal builds still consume only the final packed map. The frozen
boundary seed makes repeated boundary authoring idempotent; a deliberate new
`surface-author` causes the next boundary action to capture that new source.

R8 adds `kenny_hero_groom.py` to the normal source bundle. The one-time
`groom-author --round 8 --audit-out PATH` action creates `COL_Kenny_HeroGuides`
with editable Bezier guides, named regions, radius/profile/taper attributes,
and a packed macro atlas. Do not rerun it to reset artist edits. Enable the
hidden guide collection in Blender to edit its control points and handles;
`build --round 8` resweeps those curves into the four established `Curl*`
objects using their existing owned skinning/sway contract. Root/collision
projection uses Kenny's accepted body, never an external identity asset.

This stage is a rounded macro-mass blockout. Dedicated opaque texture cores
make the neutral silhouette/coverage gate depend on geometry, not blonde
stripes. Fine fibres, alpha edges, temporal stability and final material
response remain later acceptance work. `--round 7` explicitly reconstructs the
retained R6 comparison groom even after R8 authoring, while retaining the
canonical head/surface; `--round 6` remains the older full comparison path.
