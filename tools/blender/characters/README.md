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
