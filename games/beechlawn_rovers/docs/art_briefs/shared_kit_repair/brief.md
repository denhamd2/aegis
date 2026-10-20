# BR-022 shared neckline repair — 20 October 2026

Scope: item 22/25, still in progress. Current production source is
`tools/blender/beechlawn/footballer_shared.blend`; do not rebuild an old player
prototype. Guides used: create-player, reference-image-match, character-artist,
blender-modeling, rigging and godot-export through headless Blender 4.3.2.

Reference: archived home-kit object sheets
`file_000000000da0824386b7ef8edd3a9c79.png` and
`file_00000000fcac81f4b3870dc4ce96ac38.png`. Their neckline is a narrow,
continuous black/blue V binding; cloth covers the shoulder/neck junction with
no floating tabs or exposed skin islands. Owner corrections remain authoritative:
Uhlsport at centre, Thomas Loomes & Co, oval EST 2004 crest. No graphic changes
were required or made in this pass.

Baseline gaps: two exposed neck/shoulder patches, an extra triangular throat
tab, inconsistent garment/skin weights at the neck, inflated shoulder caps,
and remaining underarm/chest fold artifacts. The first three are the repair
focus; the last two require further pattern/shoulder work and remain open.

`repair_shared_kit.py` removes a disconnected 33-vertex throat scrap from each
sleeve variant and its redundant binding, relaxes the deltoid region locally,
fits cloth to the unchanged skin with 3 mm clearance, and blends neck weights
from the actual skin reference. It rebuilds one 96-point continuous collar with
matching garment boundary weights and the existing `JerseyUV` atlas patches.
Its digest covers retained rig rest, all action curves and protected mesh
coordinates/UV/weights. No head master, individual sculpt, hair, kit image,
shorts, socks or animation asset is edited.

`before.png` and `footballer_shared_neutral_kit_detail.png` use identical camera,
pose and lighting. The render is a production-body diagnostic using the base
head; it does not show the separate updated runtime head/hair. Additional pose
and actual Godot evidence validate the delivered GLB, not promotional artwork.
The UV layer must retain the name used by the shared material nodes; a first
review caught and corrected an incorrectly named collar UV layer before release.

The silhouette and underarm folds still need refinement. This is a neckline
repair, not final kit or likeness approval. Native M1 performance is unmeasured.


Delivered GLB: 67,710 triangles across all mesh variants (both sleeve options
included), 16 mesh parts, 65 bones and 19 clips. Eight sampled poses and a fresh
Godot production-appearance capture are stored here. The new neckline is
continuous; shoulder/underarm pattern quality remains an explicit next task.
