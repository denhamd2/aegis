# Hell in a Cell: three judge/revision loops

Owner request, 13 November2026: three independent visual-judge feedback and
revision loops toward10/10 WWE2K likeness. **No score is guaranteed.**

Target assumption: silver WWE2K25 cell, pending any more specific owner frame.
Fixed references: [roof gameplay screenshot](https://www.wrestlinggames.de/sites/default/files/content/WWE2K25/screenshots_review/wwe_2k25_20250318152901.png)
from [this review](https://www.wrestlinggames.de/tests/wwe-2k25), and
[official wall/interior screenshot](https://assets.2k.com/1a6ngf98576c/QIlAT6Vakf10MnbamL2AG/0ecde9894ae36056dccfa5e5e9255bba/Hell_in_a_Cell__1___1___1_.jpg)
from [2K25 match types](https://wwe.2k.com/2k25/features/match-types/).
Copies for visual criticism/comparison are in `reference/`; no reference pixels
are used in game textures.

## Locked comparison

Read-only independent Codex visual judge. Same three roof/wall/overview cameras,
FOV,960×540 Forward+ llvmpipe capture and lighting each round. Actual ring is
included; crowd/characters/branding are excluded. `capture.json` records settings.
Camera is approximate, not reverse-engineered from the reference. Material and
whole-cell proportion confidence are limited by lighting and cropped references.
No image establishes native M1 frame rate.

Rubric: visible silhouette/proportions30%, panel/roof arrangement25%, structural
construction20%, chain-link scale/readability15%, material response10%.
Scores describe observable features, **not certification of whole-cell10/10**.
Do not change unseen total bay/row counts or dimensions to improve a score.

## Judge ledger

| State | Proportions | Layout | Construction | Mesh | Materials | Weighted /10 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Baseline | 6.5 | 7.0 | 3.0 | 4.5 | 3.5 | **5.3** |
| After loop1 | 7.0 | 7.0 | 7.5 | 4.5 | 3.5 | **6.4** |

Baseline feedback: roof solid bars are the largest certain mismatch; reference
has deep open triangulated trusses and narrow walking strips. Mesh reads as a
fine white veil. Steel is too uniformly pale/diffuse.

Loop1 revision: replace roof beams with .30m-deep open chord/web trusses and
.12m walking strips, keeping deck height and4×4 bays. Remove overlapping solid
perimeter bars. Build wall horizontal rails from paired chords and open webs.
Triangles20,550→37,278;29 meshes and2 materials unchanged. No collider/query or
roof-panel transform changes. Native cost remains unmeasured.

Judge after loop1: substantial structural match improvement; unchanged mesh and
materials now dominate. Next: enlarge diamonds roughly1.5× while thinning wire,
then restore darker metallic body with sharp highlights. Inspect restrained
walking-strip/joint detail after those changes; don't add arbitrary diagonals.

Remaining loops2 and3 are pending. Keep the Blender source authoritative and
retain source/renders/judge feedback per revision. Only final affected regression
checks and one related Mac deployment are required after the three revisions.

Loop2 source/render: cell-only chain-link repeat64→102.4px (8→5wholeperiods
per512px tile), physical repeat .0625→.100m. Fivewholeperiods preserve tile
continuity;96px would not tile exactly within512px. Profile .19→.09, so larger
openings retain thin wire. Same camera/light, geometry, color and BRDF values.
37,278 triangles/29 meshes/2materials unchanged. Judge after-score pending.
