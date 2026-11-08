# Kenny Omega: lifelike review and plan (8 Nov)

## Context
The owner (8 Nov) asked for three things:
1. Review our Kenny against his reference images: the face, body, skin texture and colour, height, and his entrance.
2. Say what it takes to match them exactly, at AAA quality.
3. Then do it.

**References:**
- `gauntlet/refs/characters/kenny_omega_sheet.png`: turnaround, heads, hair, skin and gear close-ups.
- The judge record, `gauntlet/refs/characters/review/kenny_face_judge.md`, which ends at loop 3, run 12 (1 Nov).

## Where he stands (reviewed 8 Nov from the latest renders)
| Area | Today | Gap to the sheet | Score |
| --- | --- | --- | --- |
| Head shape | Cody's head, photo-fitted from 12 landmarks (`build_kenny_head.py` → `kenny_head_shape.tres`) | Brow ridge too prominent in profile, chin too far back, face reads long and narrow (his is broad), cheeks flat | 7 |
| Hair | `kenny_curls.py` cards | Crown reads as brushed streaks, not wet ringlets. The tone is too brown and orange; his is dirty blond with platinum tips. Missing: the strands in front of the ears and the volume at the part | 7 |
| Skin | Cody's atlases retinted (`KENNY_SKIN_TINT` 0.80/0.72/0.66) | Orange and waxy in close-up. Clips white on the stage lip in the entrance renders. The sheet is pink-red flush, sweat sheen, freckling on the shoulders and chest | 7 |
| Eyes, brows, lashes | Grey-blue iris, lids lowered | Irises read large and glassy. Dark crescent under the lower lid. Brows are heavy painted bands, not hairs | 7–8 |
| Beard | Texture, plus a moustache darken (0.70) | Painted, with no 3D stubble. His is a 5 mm ginger-blond beard that breaks the jaw silhouette | 7.5 |
| Body/build | Cody's body + `BodyBulk.KENNY` (+8 mm on the arms only) | Never measured (plan item 8 is still open). Kenny is leaner through the waist, with fuller pecs and delts and a less vascular forearm | ? |
| Height | Correct: `Roster` stands him at his billed 1.829 m (6'0") against Cody's 1.880 (`stature_scale`, applied by the title screen in every mode) | None (corrected 8 Nov: the first read missed `Roster.stature_m`) | OK |
| Gear | Cody's atlases repainted white and gold | Not checked against the sheet's filigree, black-and-gold kneepads and boot panels at close range | ? |
| Entrance | `_add_kenny_entrance`: walk, stage pose with pyro, hand slaps, second-rope wings | Labelled "unverified against footage". Ring arrival is too dark in the renders. His walk is Cody's gait at 1.1 m/s, not his loose, bouncy one | 6 |

**The honest ceiling:** reshaping Cody's head tops out at about 7.5–8. The rules rule out the usual routes to "exact":
- **AI image-to-3D:** banned by `CREDITS.md` provenance.
- **Hand sculpting:** cannot run headless.

So the most likely route is a **dense photo-fit**. It moves the whole head from silhouette contours (front, three-quarter and profile outlines), not 12 points. With the hair, skin and beard passes on top, that should get him to about 8.5. The renders decide each step.

## Steps (each a judge run: before-and-after sheet, score, ship)
1. **Fresh baseline renders.** Turnaround in match light, face shots (`tools/probe/face_shot.tscn`), and an entrance strip (`entrance_shots.tscn --who kenny`). One review sheet scoring every row above.
2. **Height and build** (`kenny_model.gd`, `body_bulk.gd`):
   - Scale him to 1.83 m through the model root's scale, with the feet kept on the mat. Check `entry_contact` and the paired-move clearance tests.
   - Measure the turnaround widths at shoulder, chest, waist, arm and calf against the sheet's front and side views, normalised to height. Correct with `BodyBulk.KENNY`.
3. **Head, dense fit** (`tools/assets/build_kenny_head.py`):
   - Add contour constraints: jaw and cheek outline from the front, and the full profile line from brow to chin.
   - Solve as a smooth displacement field, kept symmetric, off the neck.
   - Re-bake `kenny_head_shape.tres`, which must stay byte-identical on rebuild.
   - The targets are the three gaps above: brow, chin and face width.
4. **Skin** (`tools/assets/build_kenny_textures.py`, `KENNY_SKIN_TINT`):
   - Retint to the sheet's measured medians: forehead, cheek, chest and shoulder.
   - Add flush on the nose, cheeks, ears and upper chest, and light freckling.
   - Raise the sweat sheen to match Cody's.
   - Tone the entrance stage spots down, or cap the tint's level, so the lip does not clip.
5. **Eyes and brows:** fix the shadow crescent under the lower lid, a smaller iris scale, and strand-card brows (`EyeKit`, `kenny_curls.py`).
6. **Beard:**
   - A short card shell (Roman's method) over the jaw, chin and lip, at 5 mm.
   - Read `import-wrestler`'s beard section first: scale was the last defect there.
7. **Hair** (`kenny_curls.py`):
   - Wet ringlet clumps over the crown from the centre-left part.
   - 6–10 face-framing strands.
   - Root-to-tip ramp from dirty blond to platinum.
8. **Gear:** a close-up check against the sheet's pants, boots and kneepads panels, and a repaint of what differs.
9. **Entrance:**
   - Research his current (2025–26) entrance from footage write-ups and fix `entrance_director.gd` to match. Under question: the Terminator kneel, the hand slaps, the rope wings and the pyro beats.
   - Author a loose `Kenny_Walk` gait in `wrestling_clips.py` at 60 fps, then re-bake.
   - Light the ring arrival so he isn't a silhouette.

## Verification
- **Per step:**
  - focused tests: `test_kenny_model`, `test_entrance_cameras`, `test_entrance_director`, `test_sixty_fps`, `test_clip_authoring_gate`;
  - a render sheet scored in `kenny_face_judge.md` (loop 4);
  - `tools/capture/evidence_gate.py`.
- **Before each push:** the full suite. Renders, bpy and the suite never run in parallel.
- **README entry** per step. Deploy with the usual push to the branch and then main, after pulling opencode's changes first.

Order: 1 → 2 → 4 → 3 → 7 → 6 → 5 → 8 → 9. The cheap, high-visibility items come first: height, skin and the entrance light.
