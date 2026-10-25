# Create-player workflow review — 22 October 2026

BR-022, item 22 of 25, in progress. This review updates the football-only
skill from recent production evidence. It changes guidance, not playable art.
The owner's delivery target is polished final players. The current heads
remain unfinished because their visible anatomy, likeness and hair have open
defects; a working shared rig and passing imports do not close those tasks.

## Evidence-to-workflow review

| Observed problem or improvement | Practice now required | Skill location |
| --- | --- | --- |
| Des player/referee are separate people; Boardeaux aliases deliberately share the player | Record exact identity, role, profiles, source, master revision, delta and aliases before edits | Main skill, step 1 |
| Generic facial structure survived multiple texture/groom passes | Compare priority landmarks and clay front/turned/profile views, then an early Godot portrait before fine detail | Head production, step 1 |
| Raised source features/eyes were absent from the captured runtime delta | Capture head and both eyes; compare actual source/export geometry and record hash | Head production, step 4; Des export audit |
| Eye, skin-mask and groom coordinates can diverge after face edits | Fit lids/eyes and update anatomy-dependent masks/roots in the same coordinate space | Head production, steps 1–3 |
| Source skin carried broad bronze colour; the first fair palette washed out highlights | Use editable reference-led pigment, anatomical UV probes and fixed-light face/full-body review | Head production, step 2; fair-skin evidence |
| New face atlas exposed a different-coloured neck polygon | Protect geometry, normals, UV mapping and shared neck pigment together | Main skill, step 2; head production, step 2 |
| Blender was smooth while Godot showed diagonal bands | Isolate shadows/normal maps before resculpting, then check full-match contact shadows | Head production, symptom table; Des diagnostics |
| Root caps, repeated clumps and painted facial-hair masks remained visibly unfinished | Inspect root/strands separately, refit after sculpting, judge reference-shaped silhouette and face-hair boundaries | Head production, step 3 |
| Screenshot readiness did not stop SwiftShader readback starvation | Use first-draw/ready plus the existing freeze callback and hard deadlines | Production checks; head-production symptom table |
| Studio/default material looked different from the runtime role override | Review the actual atlas, PBR channels, mips and imported role resources | Garment production, atlas/engine agreement |
| Constant roughness data and blue keeper sock cuffs defeated intended details | Sample real imported cloth/print/sock masks and role-specific UV swatches | Garment production, atlas/engine agreement |
| Kit panels, logos and player printing have different reuse requirements | Use flat pattern art with provenance, supplied marks and separate profile names/numbers | Garment production |
| Collar projection collapsed samples; sleeves omitted skin; old builders could discard recent work | Preserve the current source, local topology/clearance and sampled cohorts; keep existing cloth regressions | Garment production; production checks |
| Retarget axes/timing, translating pivots, first-frame T-poses and moving contact caused prior failures | Retain existing axis/time, startup/transition, independent playback and gameplay contact gates | Animation production, reviewed and retained |
| Good technical checks were being treated as sufficient progress toward final art | Record visual finish, technical integration and hardware acceptance separately; fix visible failures before final delivery | Main skill, step 4 |

Detailed source evidence: [Des player](des_feeney_player_likeness/brief.md),
[fair complexion](fair_skin_review/brief.md),
[John](john_orourke_likeness/brief.md),
[referee](des_feeney_referee_likeness/brief.md),
[Shane](shane_photo_likeness/brief.md),
[fabric](shared_fabric_response/brief.md),
[keeper kit](keeper_kit_graphics/brief.md),
[collar](shared_collar_raglan/brief.md),
[cloth](shared_cloth_finish/brief.md),
[sleeves](shared_sleeve_fit/brief.md),
[pitch-side capture](pitch_review_stage/brief.md) and
[turn/motion](shared_turn_polish.md).

## Next finishing pass: Des Feeney, Boardeaux player

The latest original portrait `boardeaux_des_photo/69016.jpg` and the actual
`fair_skin_review/after/des/des_portrait.png` show the remaining priorities:

1. Refit skull-to-face proportions, cheek/jowl fullness and lower-face taper
   against the original. Establish these in matched clay front/turned/profile
   views; separate the photograph's expression and indoor shading from anatomy.
2. Refine fitted eyelids/orbits, lip volume/closure, muzzle transitions, nose
   and ears. Use local topology repair where existing loops cannot support
   clean forms; preserve the shared neck, rig and expression offsets.
3. Refine short receded side/back hair and the moustache/goatee with fine,
   directional growth and softer boundaries. The current dark triangular
   goatee and sparse coarse fibres fail the finish criterion.
4. Calibrate fair skin, restrained pores, roughness/normal response and eyes
   in actual Godot daylight, retaining highlight detail and neck continuity.
   Brighter skin alone cannot establish likeness or a polished surface.
5. Capture the final source/delta, export matching head/eyes/hair and verify
   the actual Boardeaux profile in close, turned, full-body and broadcast
   views, neutral/expression states and relevant motion. All eleven away
   actors should inherit the finished identity while the referee stays separate.

Use the main skill's final-quality table to record evidence and remaining
corrections. Then apply the proven process to the other individual heads.
Propagate common anatomy/material/rig improvements through the master only
when they are genuinely shared; retain each person's identity deltas and groom.
Native Mac visual/performance acceptance stays open until hardware is available.

## Guidance verification

Check local Markdown links and repository tool/guide paths, skill frontmatter,
mandatory branch routing and project boundaries. This is a documentation-only
change; it does not require rebuilding Blender assets or rerunning gameplay.
No new gameplay tests, asset changes or deployment are part of this review.

Result: local links/tool paths, frontmatter and mandatory branch routing pass.
Existing root/project `AGENTS.md` already require this football-local skill;
their routing remains intact. Duplicate head-specific notes were moved from
general production checks into the new head branch; existing motion/contact
checks remain in their established animation guide.
