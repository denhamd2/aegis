# Rovers Arena seat/aisle alignment correction — BR-023 (23/27)

Owner report: the stand facing the broadcast camera and its seats appear slanted.
References: unchanged owner `references/source_uploads/chat_attachments/match_hud_stadium/70060.jpg`; before captures copied from the shipped v0.3.0 native evidence.

Reproduction: `python3 tools/test_arena_seating_alignment.py` reads the actual exported `seating.json`. Before correction: 43,982 off-grid straight-bank seat positions, up to 0.30 m phase error, 7,834 chairs encroaching on intended perpendicular aisles, and 24,064 chairs misoriented relative to their bank. Row elevations themselves remain level.

Ranked causes/predictions: (1) row-relative indexing and width/n spacing shift column/aisle phase as each successive row gets wider; a shared 0.6 m lateral grid must remove this drift. (2) mirrored Blender XY / Godot XZ orientation and radial instead of bank-normal yaw twist/reverse some chair banks; explicit coordinate conversion and perpendicular inward yaw must correct them. (3) camera roll or crowd billboards could add a perceived lean; level row-height checks and unchanged-camera native before/after views distinguish this from geometry errors.

Apply the debugging workflow and Blender director/environment/Godot-export guides. Preserve the normal 0.43 m rise / 0.76 m tread, all three tiers, shared instancing, camera, pitch, player/ball physics, kits and heads. Use a bank-centred fixed column grid and continuous 1.8 m stair aisles. Put each chair halfway across its level tread, face it perpendicular into the field, and convert Blender +Y to Godot -Z once at export. Keep section IDs tied to the Godot bank so crowd density does not change sides.

Validation: run the exported-data regression red then green, verify actual Godot near/far instance matrices and view from the unchanged broadcast/wide cameras. Keep editable .blend and original generator, with a Blender structure preview and native Forward+ evidence. This is an arena visual correction; no full-match AI retuning is required. M1 performance remains BR-025 acceptance.

## Outcome

The layout-only probe removed all lateral drift/aisle obstructions while retaining the facing failure. Correct bank-normal yaw and explicit coordinate conversion then cleared every exported-data check. Final layout has 50,032 seats on 464 level bank rows; all are upright and inward-facing. Headless tests exercise the production placement function; native Forward+ separately read back 3,858 actual GPU instance transforms with zero errors and identical near/far LOD placement. Broadcast, wide and pitch-level captures use the unchanged cameras. The source .blend/preview and GLB remain reproducible. Rows retain their normal rise; the spurious one-way diagonal drift is removed.
