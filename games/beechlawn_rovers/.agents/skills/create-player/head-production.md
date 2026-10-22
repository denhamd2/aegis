# Head, skin and hair production

Read before creating or changing a footballer's head, eyes, skin or groom.
Paths in code spans are relative to the repository root. Follow the main
skill's reference, shared-asset and animation requirements. A material-only
repair preserves the existing sculpt; it does not require starting it again.

## 1. Establish identity and correct the large shapes

Use the original portrait for identity, with generated sheet profiles as
secondary evidence. Record forehead/skull outline, eye-line and spacing,
lid opening, cheek/jowl width, nose bridge/tip/alar span, lip width, chin and
ear projection. Compare ratios in a matched view; allow for camera yaw,
perspective and expression instead of copying image pixels as dimensions.
List uncertain side/rear anatomy explicitly.

Work on the current master plus this player's captured delta. Keep the mouth
at a clean neutral rest and expressions separate. Move fitted curved eyeballs
and lids together; reduce exposed sclera through aperture/eye fit, not a
painted iris. Broad mouth scaling must fade through surrounding muzzle tissue;
check corners, lip closure and cheek pinching in three-quarter/profile.

Use monotonic lip closure with bounded offsets. A large sign/tanh field can
move upper and lower lip vertices past one another; check frontal triangle
winding against the master as well as the rendered mouth. Portrait landmarks
can guide bounded, eye-line-normalized width/height adjustments; keep their
input hashes/crops, preserve the pre-fit measurements, and account for yaw and
expression. They do not establish hidden 3D anatomy or certify likeness.

Sculpt in the source's actual local axes/units. A vertical face change must
also update the coordinate space used by brows, lips, beard masks and groom
roots. Des's canonical-coordinate mapping is one identity's solution, not a
universal offset for other players. Keep expression offsets attached to the
changed neutral Basis. Preserve the master neck interface.

**Gate:** the five largest reference mismatches are reviewed in fixed clay
front/three-quarter/profile and an early actual Godot portrait. Correct a
generic silhouette, protruding eyes, malformed mouth or pinched cheek before
fine skin/hair work. Technical import success does not pass this gate.

## 2. Bake individual pigment with a continuous neck

Use `tools/blender/beechlawn/skin_palette.py` for the owner's fair, untanned
roster direction, preserving each portrait's redness, freckles and age.
Indoor warmth is not a target tan. The first fair-skin trial washed out
highlights: reduce the bronze/orange cast with balanced pigment changes,
rather than raising every channel or changing world exposure. Check face,
neck, short-sleeve arms, hands and knees together in fixed daylight.

Preserve registered anatomical UVs. If reallocating islands, record the source
mapping once and explicitly transfer the neck samples; repeatedly normalizing
UVs or retaining texels at unrelated coordinates breaks the contract. Build
pigment masks from the resulting anatomy, not portrait projection. Use a
neutral base or only bounded high-frequency licensed skin detail when the
source carries another identity's broad face shading, brows or colour cast.
The licensed source's `Bronze` filename and a clipped tint multiplier must not
silently determine the final complexion.

Use a directly exportable image-driven Principled material. Inspect base-colour
factors, runtime tints and legacy vertex-colour multiplication; remove an
unintended tint from the affected head. Keep normal/roughness data linear,
and compare saved/reloaded sRGB PNGs with embedded GLB images. Preserve local
lip and pore variation without painting lighting into albedo.

Retain common master pigment at the protected neck and blend above it into
the individual face. Matching positions/normals alone leaves a visible collar
patch. Shared body recolours must propagate to hands and other exposed skin;
a head-only `skin_tint` cannot do this. Keep eyes, facial hair, kits and keeper
gloves separately masked. Change a roster-wide palette through its narrow
source/texture workflow; inspect `refresh_roster_skin.py` before running it,
because it also refreshes existing individual sources from captured recipes.
Capture any newer sculpt first. Do not rebuild the old whole-body generator
for a colour-only change.

**Gate:** fixed-light portrait and full-body views retain skin detail without
tan, washed-out highlights or a collar colour seam. Sample actual anatomical
UVs in the exported skin; unused atlas background is not evidence. Use
`audit_roster_skin.py` as an example and extend its identity/UV probes for a
new head. Its current thresholds are scoped regression guards, not measures
of ethnicity, likeness or universal skin realism.

## 3. Fit dimensional hair and facial hair

Fit scalp, receding hairline, sides/back, crown and parting to this skull.
Review the root shell alone, strands alone and both together. A smooth cap
with sparse tufts reads as painted hair; uniform thick clumps read as a
helmet. Use directional curved clumps, buried roots, tapered tips and varied
silhouette. Check intersections after smoothing and at mip distance. Compare
geometric normals before applying scalp-normal overrides to every strand.

Treat moustache, goatee, beard, brows and scalp as distinct regions with soft,
anatomically placed boundaries and their own pigment/roughness. A rectangular
beard patch or dark mark across the nose is a failed mask, not finished hair.
Refit roots after every relevant face/skull edit. Reuse compatible rig/mesh
contracts, not another player's hairline or reference-specific mask constants.

Keep scalp, beard and brows on independent colour controls. John's scalp uses
dark-blonde roots and wheat highlights; his approved warm beard is unchanged.
Clip root-shell triangles to the smooth hairline instead of selecting whole
polygons, and project entire curved fibres onto the fitted facial surface to
avoid jagged roots or floating jaw spikes. Preserve deterministic strand
placement when changing pigment alone.

**Gate:** head turns and close/profile views show fitted dimensional hair and
readable facial hair, without exposed cap edges or coarse repeated clumps.
Count groom geometry/alpha over the full roster: Des's single groom is used
by eleven away actors. A higher strand count alone does not prove improvement
or affordable M1 cost. Historical John/referee mouth and mask defects remain
negative examples; validate the latest exported groom rather than inheriting
approval from the corrected generator.

## 4. Prove the complete source-to-runtime chain

Saving a `.blend` does not update its sculpt delta. Capture the edited neutral
head **and both eyes**, validate the master revision/identity, rebuild the
head and fitted groom, import in Godot, then verify all intended profile
aliases. Preserve shared topology/UV/weight fingerprints and neck corner
normals. Unknown revisions or changed topology require an explicit transfer.

Compare exported geometry with the editable source in both directions and
record the GLB hash. Inspect image names/content, colour streams, bind/joint
ordering and matching head/eye/hair selection. A valid resource path can
still reference a stale eye layout. `audit_des_player_export.py` demonstrates
the audit for Des; adapt it for a new identity rather than treating a passing
Des audit as coverage of another player. `audit_four_head_finish.py` extends
source/eye/neck/material and lip-winding checks across the four finishing-pass
identities. Legacy authoring entry points delegate to
`author_four_head_finish.py`; keep those routes current when replacing a recipe.
Resolve glTF objects through node-to-
mesh indices; object and mesh-data names need not match, and exported UV image
orientation must be handled explicitly when sampling.

For material-only updates, prefer narrow payload changes with protected
non-image buffer hashes. For geometry updates, compare the untouched body,
rig, UVs and animation curves against the recorded baseline. Inspect the
current action inventory rather than hard-coding a historical clip count.

**Gate:** source, captured recipe, export, import and real roster selection
agree; unchanged assets retain their proofs. Exercise a teammate, opposition,
goalkeeper and referee to catch accidental shared-material/identity changes.

## 5. Diagnose engine differences before changing the sculpt

| Symptom | Isolate first | Required final check |
| --- | --- | --- |
| Blender is smooth; Godot has diagonal bands | Disable only shadows, then only the normal map, with camera/light fixed; compare source/export normals and tangents if still implicated | Re-enable normal maps and cast shadows; recheck ball, boots and posts after any sun-bias change |
| Face/collar colours disagree | Actual head/body atlas samples, UV registration, base-colour factors and runtime tints | Continuous neck plus exposed limbs in the real role/profile |
| Eyes, beard or hair miss the sculpt | Current source versus captured head/eye delta, mask coordinate space, matching groom revision | Matching source/export geometry and turned views |
| Colour shifts or looks chalky | Saved PNG versus packed/imported image, colour spaces, source cast/tint limits and channel clipping | Matched daylight before/after with visible skin variation |
| Fine fibres look like dark speckles | Fixed-crop shadow ablation versus multisample antialiasing, keeping pigment unchanged | Retain strand colour/shadows, record sampling and measure target GPU cost |
| A ready Web scene times out on screenshot | Confirm the first draw and invoke its existing `BEECHLAWN_FREEZE_FRAME` hook before bounded readback | Fresh image, clean browser log and no leftover process |

Des's shadow normal-bias adjustment worked for one camera/renderer; its exact
value and forehead-band crop are not universal presets. Preserve before and
after captures in separate paths, with asset hash, identity/profile, pose,
camera, lighting and renderer recorded. Diagnostic ablations have their own
folders. Keep current player previews grounded on the Kilmore Drive pitch;
isolated wide material-fixture views do not establish actual broadcast framing.

Evidence: [Des player](../../../docs/art_briefs/des_feeney_player_likeness/brief.md),
[fair skin](../../../docs/art_briefs/fair_skin_review/brief.md),
[John](../../../docs/art_briefs/john_orourke_likeness/brief.md),
[referee](../../../docs/art_briefs/des_feeney_referee_likeness/brief.md) and
[pitch-side reviews](../../../docs/art_briefs/pitch_review_stage/brief.md).
These cases establish methods and remaining gaps, not final AAA approval.
