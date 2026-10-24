# Shane and John likeness refinement — BR-022 (22/27, in progress)

Continue from v0.2.3, preserving current independent sources, common neck,
65-bone rig, actions, kits, fullness and the two distinct Des identities.
Use create-player, blender-director/reference matching, character-artist,
blender-modeler/modeling, realistic-style, blender-materials, hair-groom and
godot-export with headless Blender 4.3.2. No wrestling or Web changes.

Identity: `shane_denham`/Beechlawn #8 and `john_orourke`/home keeper #1.
Editable sources are `shane_denham_head.blend` and `john_orourke_head.blend`;
captured recipes, normal and near head/eyes packages, matching separate grooms
and all actual roster/fixture aliases must agree after delivery.

Original references: `shane_face_photo/69012.jpg` (smiling, slight yaw,
warm indoor light) and `john_orourke_photo/69010.jpg` (closed-mouth smile,
tilted close portrait). Paths are under archived chat attachments. Supplied
turnarounds provide secondary side/rear evidence. A hidden profile remains
estimated. John retains dark-blonde roots/wheat highlights and warm beard.

Priority gaps: generic facial planes and jaw; weak individual brow/lid forms;
incorrect nasal/lip proportions; uniform skin response; cap-like scalp and
hard beard boundaries. Fit neutral identity separately from expression and
photo roll/perspective. No rectangular photo face or generated beauty render
may stand in for a modeled runtime head.

The inherited portrait measurement matrix rotates image roll in the wrong
direction. Correct and regression-check it; preserve old measurements as
historical evidence. New normalized landmarks are guides, not scan data or a
likeness score. Use conservative symmetric fits for pose-dependent outlines.

Budget: retain head cage topology, one smooth near tier, shared 2K skin
atlases and fitted bounded fibre grooms. Do not increase all-roster LOD cost
to compensate for weak large forms. Original/licensed free assets only.

Review: baseline native pitch-side front/three-quarter captures under fixed
match lighting, matched clay views, geometry iteration then surfaces/groom,
native after front/turned/profile and closed lids/smile, source/export and
shared-asset audits, roster and representative pose checks. Record visible
remaining gaps honestly; technical passes do not establish AAA likeness or
M1 performance. Baseline captures are in `before/`.

## Implemented refinement

The saved cages now have individual brow, cheek/jaw, nasal and lip corrections,
fitted lower-lid transitions, anatomical skin relief/roughness and independent
short-crop/side-swept grooms. John retains blonde scalp highlights and his
approved warm beard palette. Shane's separate topology-fitted smile reveals
eight original upper teeth; neutral lips hide them. Optional dental parts use
the existing head bind and are removed on identity changes.

The portrait roll correction has a pupil-coordinate regression. Saved neutral
head/eyes, captured deltas and exports are audited together; the common neck,
body, rig, animation library and both Des identities remain protected.

Native shadow ablations isolated the regular under-eye bands to sun
self-shadowing. The chosen scene depth bias removes that measured pattern
with normal maps and cast shadows enabled. `shadow_diagnostics.json` retains
the comparison. The native match and goal montage still show player/post/net
shadows; Linux software Vulkan is not an M1 performance measurement.

## John's full side beard — 24 October follow-up

The reattached `69010.jpg` has the same SHA256 as the archived original; its
provenance records the repeated upload and explicit side-beard direction.
The previous front-Z pigment field and front-facing strand rejection removed
the lateral cheek/jaw, leaving a front bib. Coverage now wraps around the
head into the sideburns with local outward visibility checks and ear/lip/nose
exclusions. A first native turn exposed an overly hard cheek panel; the next
pass feathers its density into stronger jaw growth. Beard RGB and the
5,200 scalp / 12,000 facial / 680 brow guide budget stay unchanged.

`john_beard/` records the first coverage correction; `john_beard_final/`
records the softened follow-up so evidence is not silently overwritten. The bilateral
beard audit checks actual source/export fibres on cheek, jaw and sideburn,
fitted surface distance, ear exclusion and the unchanged warm palette.

## Evidence and acceptance

Matched clay: `clay_before/` and `clay_after/`. Native neutral and expression
reviews: `final_native/`, `final_smile/`, `final_blink/`. The final smile shows
upper crowns with no neutral dental exposure; both native blinks close the
apertures. `final_match/` and `final_presentation/` retain 22-player and intro
integration/shadow checks. Each capture manifest records the assets at that
capture; earlier John captures precede the side-beard correction.

Technical checks and a corrected beard do not establish AAA likeness. The
heads still need stronger individual orbital/muzzle forms, more natural
scalp clump silhouettes/root transitions, and less uniform skin at close
range. The fixed jaw-to-neck/kit interface also remains visible in profile.
BR-022 stays in progress until front, both profiles, expression/motion and
native Mac visual acceptance meet the reference target.

Final checks: all-four source/export audit; bilateral John beard audit;
protected scope (12 unchanged common/other-identity assets, six intended
Shane/John normal/near/groom exports); four serial native-head/roster/realism/
recorded-expression smoke checks; two portrait-coordinate tests and one
capture-deadline test. All pass. Existing ObjectDB exit warnings remain in
some headless tests; these passes do not certify leak-free shutdown.

John's final native folder contains six successful Forward+ views at 960×540
on llvmpipe, with match daylight, shadows and normal maps enabled. The
matching Blender front/three-quarter/profile reviews are in
`john_beard_blender/john_orourke/`. Source, export and evidence hashes are
recorded in `validation.json`. This pass has not been packaged into a new
Mac release; the existing v0.2.3 download predates these refinements.
