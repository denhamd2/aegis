# Surface V3: local boundary continuation

This pass starts from a fingerprinted, frozen owned copy of V2 packed in Kenny.blend (BoundarySeed::kenny_head_v2.png). It does not reopen/project the source photograph or rebake the central face. Normal builds continue restoring the final packed SurfaceMap only. V2 full albedo and recipe are archived at ../surface_preview2.

The local forehead/scalp continuation uses the V2 forehead's colour and fine frequency, with a smooth3D blend above1.740m; no flat RGB slab or hair-hiding geometry. The temple hair patch is located through final UV/world correspondence (UV(.30,.32)→(-.0541,1.7276,-.04366), mirrored side(.70,.32)→(.06448,1.72474,-.04391)). Its V2 contribution is quantified in the boundary audit rather than assumed to be entirely new photo or entirely old fallback. A bounded C1 temple mask removes this pigment, and a broader nape continuation removes the old fallback cut.

Thirty coincident head/body material-border pairs sample the adjacent owned body textures. Colour correction stays on the head side, within35mm of the boundary; no body geometry, maps, rig, lights or runtime profile change. Fine continuation frequency is taken from the owned V2 forehead patch and mapped continuously by world coordinates.

The central brow/nose/lip/stubble hold region has0linear colour delta. All geometry/groom remain draft2; source eyes/protected neck0 and67binds/weights unchanged. Only headPNG/embedded image in bodyGLB changed. Native94.33MB remains under100MB; total112499tri.

Actual lit/unlit boundary review remains required. Lit darkness is not used to brighten this pass: parent's separate normal-off and mesh-normal audits ruled out a widespread normal transport failure; neutral-pose diagnostic identified~13deg gameplayIdle head pitch. Gameplay pose/cameras remain untouched. No completed likeness or10/10 claim.
