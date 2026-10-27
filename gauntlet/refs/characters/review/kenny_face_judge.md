# Kenny's face: art-director judge loop (27 Oct)

The owner: "Add an art director judge to critically review Kenny's reference
facial details vs ours and make improvements based on those findings. Have it
score likeness out of 10 ... Run this in a loop to a max of four runs." Then,
on the screenshots so far: "The beard on the side of his face doesn't look
right ... his eyes don't match with the reference. Ours looks glowing and
slightly wrong color."

The judge is done inline against a fixed rubric, not by a sub-agent (the
owner's standing rule). Each run: rebuild, render
`tools/probe/model_turnaround.tscn` (head front, three-quarter, side), set it
against the sheet (`gauntlet/refs/characters/kenny_omega_sheet.png`, HEAD
REFERENCES and FACE DETAILS), score, fix the largest weighted gaps. Sheet:
`kenny_face_judge.png` (reference, then runs 1-4, then run 4 under match
light).

## Rubric

| Feature | Weight | What 10 looks like |
| --- | --- | --- |
| Shape (head, forehead, jaw) | 25% | His broad face, high receding forehead |
| Eyes | 15% | Pale grey-blue iris darker than a pink-white sclera, small pupil, hooded lids, no glow |
| Beard | 15% | Short auburn beard, densest on chin and jaw, along the jaw into the sideburns |
| Brows | 10% | Sandy ginger, soft, low contrast |
| Nose | 10% | |
| Mouth | 10% | |
| Skin | 10% | Flushed, freckled, fair |
| Hair framing | 5% | Slicked back off the temples, ringlets behind the ears |

## Scores

| Run | Shape | Eyes | Beard | Brows | Nose | Mouth | Skin | Hair | Likeness |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 5 | 6 | 7 | 4 | 6 | 6 | 6 | 6 | **5.7** |
| 2 | 5 | 7 | 7 | 7 | 6 | 6 | 6 | 6 | **6.2** |
| 3 | 4 | 7 | 7 | 7 | 6 | 6 | 6 | 4 | **5.8** |
| 4 | 6 | 7 | 7 | 7 | 6 | 6 | 6 | 7 | **6.5** |

## Run 1: eyes and the side beard (the owner's two notes)

Findings, measured:
- **Eyes glowed.** On the old maps the iris rendered (79,89,122) under match
  light: as bright as his forehead and brighter than his sclera (42,34,43). The
  sheet's iris sits darker than the white of his eye. Cause: a periwinkle
  tint on Cody's iris (1.62, 1.82, 2.05) plus a bluer, brighter material tone.
- **Side beard.** The stubble was a polygon drawn on the head atlas. It
  stopped in a straight vertical edge mid-cheek, short of the ear. Where the
  photo projection faded out there was a seam. The beard was salt-and-pepper
  specks, not hair.

Fixes:
- **Iris** (`tools/assets/build_eyes.py`):
  - re-coloured grey with a hint of blue-green (`KENNY_IRIS_TINT`; its level
    was then set under match light, below);
  - drawn in to 0.9 of its radius by a radial warp, so the white keeps its own
    veins to the new limbus. A flat white ring painted there first glowed as
    a halo.
- **Sclera:** lighter and warmer, with less of the lids' shade on it.
- **Material tone** (`KennyModel.KENNY_EYE_TONE`): Cody's level, a shade warm.
- **Beard** (`build_kenny_textures.beard_masks`): placed in 3D, from each
  texel's bind-pose point on the head.
  - It follows a measured cheek line and neckline, and reaches round to the
    ear above the jaw's corner and under it below.
  - It is drawn over the photo and Cody's skin alike, so there is no seam.
  - The hairs are short auburn strokes, about a fifth of them ginger-blond,
    over skin shaded by the sheet's chin/cheek ratio (0.74, 0.65, 0.66).

## Run 2: brows, pupil

Findings:
- The brows were Cody's, dark brown strokes at about half the skin's level.
  The sheet's are sandy ginger at about 0.7, redder.
- The pupil was large.
- The white of the eye read cool grey.

Fixes:
- **Brows:** each hair is taken to the sheet's colour by how dark it is against
  the skin round it (`BROWS`, `BROW_SHADE`).
- **Pupil:** 2.0 mm down to 1.6 mm (`KENNY_PUPIL_R`).
- **White of the eye:** a pinker, warmer sclera and tone.

Tried and dropped: the same recolour on the lash line. It caught the whole lid
and drew a darker ring round each eye, more eyeliner rather than less.

The dark crescent under each lower lid in these renders is the probe's single
hard key light. Cody renders it the same way in the same probe, and it is not
in the texture.

## Run 3: the hairline (overshot)

Finding: Cody's scalp runs flat across the forehead at 1.787 m and drops
square at the temples. It read as a helmet. The sheet has a high forehead that
recedes at the temples into an M.

Fix: a shared hairline table (`build_kenny_textures.HAIRLINE`), read by both
the head texture and `tools/blender/kenny_curls.py`.
- The scalp below the line becomes forehead in the texture.
- No cap or slick grows from it in the curls.

Read off the sheet by pupil distance it came out at +1 cm at the centre and
+2.5 cm at the temples. On the head that bared him nearly to the crown. Near
the top of the skull a centimetre of height is a lot of scalp, and the photo's
head tilt cannot be told from its hairline. The cloned forehead also showed
its creases twice.

## Run 4: a soft M

Fix:
- **Hairline:** about half the recession (+0.5 cm at the centre, +1.5 cm at the
  temple corners), with Cody's square corner rounded.
- **Bared skin:** its tone from round about, its pores from further down the
  forehead, so no doubled creases.

## Closing the eyes under match light (`tools/probe/face_shot.tscn`)

The turnaround's stand-in light is not the match's, and the owner's "glowing"
was seen in the match. So the eyes were closed on the real arena light.
Iris, sclera and cheek were measured on the close-up:

| Iris tint | Iris | Sclera | Read |
| --- | --- | --- | --- |
| first pass (1.62, 1.82, 2.05) | (73, 85, 125) | (49, 39, 46) | periwinkle, 1.7x the white: glows |
| run 1 (0.94, 1.04, 1.06) | (0, 0, 5) | (51, 33, 34) | black: in the brow's shade it falls into the tonemap's toe |
| (1.17, 1.29, 1.31) | (9, 8, 16) | (51, 34, 34) | dark slate |
| **shipped (1.40, 1.54, 1.57)** | **(29, 27, 37)** | **(50, 30, 31)** | grey-blue at about 0.6 of the white, as the sheet's arena photo has it |

The before/after pair is the last row of `kenny_face_judge.png`.

## Where it stands, and what it would take to go further

6.5/10 after four runs. What holds it there:
- **Shape (25%) is Cody's bones.** At matched pupil distance the nose, mouth
  and chin land close and the face width is close too. What remains is
  Cody's longer nose and narrower cheekbones, and only a mesh change moves
  those.
- **Skin (10%).** The sheet's face is flushed red under arena light; ours is
  peach. The skin tint was tuned away from brick-red and lilac earlier this
  round, and the stage spots clip a redder chest. A face-only flush is the
  next step, checked under the entrance lights.
- **Hair.** The slick cards over the crown read as brushed streaks, not wet
  curls. The ringlets are right in kind.
