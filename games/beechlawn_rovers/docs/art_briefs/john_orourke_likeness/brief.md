# John O’Rourke #1 likeness pass — work in progress

Latest source, groom, four-image PBR package and runtime evidence supersede
this historical pass: see [the four-head finish](../four_head_finish/brief.md).
The current authoring entry points delegate to `author_four_head_finish.py`;
materials/grooms use `player_head_finish.py` and `player_head_groom.py`.

Current task is BR-022, player likeness and reusable head variants (22 of 25 backlog items). John has a dedicated sculpt delta on the shared humanoid head, a separate UV skin atlas and auburn swept groom. His roster profile is the Beechlawn goalkeeper #1; the shared body and rig remain intact.

## Reference use

- `references/source_uploads/chat_attachments/john_orourke_photo/69010.jpg`: primary facial identity and expression reference. The small, slightly angled source photo is preserved unchanged and is not projected onto the face.
- `references/source_uploads/drive_folder/file_0000000061e481f4a2d80607671edf6e.png`: front, side, rear, expression and goalkeeper-kit evidence; use the side/rear panels for the hairline, swept auburn hair and beard silhouette.

## Work in this pass

The John delta broadens the cheek transition and rounds the lower face, adjusts the nose/alar area, and reduces the inherited mouth opening. A John-specific UV atlas replaces Shane's face map, adds muted skin pigment, blue-grey eyes and a warm beard colour. Hair remains a separate groom asset, keeping the head mesh replaceable and the shared body/skeleton reusable. The portrait photo is not used as a face texture or decal.

## Review status

`web/john_portrait.png` is an actual Godot Web/Compatibility renderer capture of the roster review scene on Kilmore Drive. The sculpt, skin map and groom are correctly selected for John's goalkeeper slot. The current face still looks too generic and stylized beside the reference: the mouth geometry reads poorly, the beard boundary is too smooth, and the hair clumps remain conspicuous. This iteration is a technical likeness prototype, not an AAA-quality match, and should not be presented as finished. The next art pass should prioritize a closed, anatomically clean resting mouth; a softer cheek/jaw transition; less prominent eyes; and a finer, less uniform hair silhouette, with front/three-quarter/profile captures after each sculpt change.

Godot smoke test `shared_head_roster_smoke.gd` passes with John using his own head and groom, Boardeaux reusing Des Feeney's head, and all players/referee retaining the shared body. Web rendering is a visual review only; it does not measure native M1 performance.
