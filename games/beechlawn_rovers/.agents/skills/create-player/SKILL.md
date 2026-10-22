---
name: create-player
description: Create or refine Beechlawn player likeness, body, hair, kits, animations or retargeting from archived references; validate shared assets and playback in Godot.
---

# Create a Beechlawn player

Scope: Beechlawn Rovers only. Keep wrestling assets and rules separate. The delivery target is a polished, reference-faithful playable player. Work toward that target through measured visual and technical gates; a first pass is an intermediate review, not a finished asset.

Paths below are relative to the **repository root**. Preserve the current production asset and improve it in place. Inspect the current source and runtime wiring before choosing a generator: rebuilding an older source can discard later animation, tailoring and material fixes.

Read [production checks](production-checks.md) before choosing tools or editing. For head geometry, eyes, skin or hair, also read [head production](head-production.md); for garments read [garment production](garment-production.md); for motion read [animation production](animation-production.md). Apply the relevant gates to changed systems and preserve evidence for untouched systems. These are internal quality checks, not extra permission requests.

## 1. Establish the reference and baseline

Read `games/beechlawn_rovers/docs/art_reference_implementation_plan.md` and `references/README.md` within that project. Retrieve archived originals; copy new uploads unchanged into its reference archive with provenance and SHA256. For face identity, use the owner's latest original portrait ahead of generated character-sheet faces; retain sheet profiles as secondary evidence and label unseen anatomy as an estimate. Resolve conflicting kit marks through recorded owner corrections. Use original work and supplied/free licensed assets; archive provenance and use terms with source material.

Write a short feature/gap brief: player and number, evidence filenames, head/body silhouette, facial landmarks, hairline, garment construction, graphics and five largest current mismatches. Separate expression, perspective and indoor lighting from identity. For motion-only work, use the brief to identify gait, contact, recovery and transition mismatches. Decide fixed front/profile/three-quarter/back, portrait and gameplay review views before editing. Preserve before captures with the same camera, pose, light, exposure and render settings used after.

Record the identity contract: exact player ID, team/role, current profile paths, master revision, individual delta, editable source, exported head/eyes/hair and affected aliases. Boardeaux player Des Feeney and referee Des Feeney Sr. are separate identities. Establish what is shared, what this task may change and which hashes/pose checks protect the rest. The current heads are reusable technical starting points; their unfinished likenesses and grooms are not approved visual templates.

Read these specialists when their branch applies:

| Work | Repository guide |
| --- | --- |
| Reference-led production | `.claude/skills/blender-director/SKILL.md` and its reference-image-match workflow |
| Anatomy, face or clothing | `.claude/skills/character-artist/SKILL.md` |
| Mesh edits and source organisation | `.claude/skills/blender-modeler/SKILL.md`; add `.claude/skills/blender-modeling/SKILL.md` for mesh-operation detail |
| Skin/cloth response | `.claude/skills/blender-materials/SKILL.md`, `.claude/skills/realistic-style/SKILL.md` |
| Hair silhouette/cards | `.claude/skills/hair-groom/SKILL.md` |
| UV layout or image registration | `.claude/skills/uv-workflow/SKILL.md`, `.claude/skills/blender-uv-texturing/SKILL.md` |
| Face/garment topology repair or transfer | `.claude/skills/retopology/SKILL.md` |
| Motion authoring, retargeting or transitions | `.claude/skills/blender-animation/SKILL.md`, `.claude/skills/animation/SKILL.md` and `.claude/skills/rigging/SKILL.md` |
| Changed weights, rest pose or rig | `.claude/skills/rigging/SKILL.md` |
| Godot delivery | `.claude/skills/godot-export/SKILL.md` |

Use available headless Blender/bpy directly when MCP is absent. Store editable sources and repeatable scripts in `tools/blender/beechlawn/`; exported assets belong to the football project. No Blender dependency at game startup.

**Gate:** identity contract, original evidence, current production source, immutable baseline views and prioritised gap list are recorded.

## 2. Fix form, then surfaces

Work from silhouette to facial planes to detail. Check neutral clay front/profile/three-quarter before tuning skin. Fit skull, jaw, cheek, brow/orbit, nose, lips, ears and neck as geometry. Keep lids fitted to curved eyeballs; iris placement cannot repair a wrong aperture. Treat a smile as a separate editable expression from neutral identity. Use proper oral geometry for an open smile; skin pigment cannot stand in for teeth or mouth depth. A single portrait cannot establish an exact hidden profile.

Preserve the common skeleton, rest transforms, bone names and body/kit interfaces. Scope motion edits to the intended clips/channels/events; model-only edits preserve the entire animation library. For common-head updates or individual likeness edits, follow [the shared head pipeline](../../../docs/art_briefs/shared_head_pipeline.md): the authoritative source is `footballer_head_master.blend`; individual sculpts are revisioned offsets. Protect the complete neck interface: positions, weights, normals, UVs and pigment. Prove the captured neutral head and both eyes match the shipped export before adding fine surface detail.

Hair needs scalp coverage, a reference-shaped hairline/crown and directional clumps before flyaways. Inspect root edges and card ends from several angles. Bound transparency, shadow cost and strand count to the football camera.

For kit construction, UVs or garment deformation, read [garment production](garment-production.md) before editing. Match garment silhouette before texture polish: torso and shoulder mass, collar, sleeve joins, cuffs, shorts leg openings, sock bands and boots. Map supplied complete panel graphics onto the constructed garment, including crest, sponsor, manufacturer and trim. Keep text size and placement reference-led. Check front and back with folded limbs, not only a bind pose.

Preserve anatomical UV islands and register pigment to them. Base colour carries pigment; geometry and restrained normal/roughness maps carry form and relief. Keep photographic illumination out of albedo. A rectangular portrait overlay is not a facial texture solution. Colour maps are sRGB; normal/roughness/masks are linear. Mask hair separately from skin scattering/wetness. Use exporter-supported PBR nodes and inspect the saved image after reload to catch colour-space changes.

For clip authoring/import, retargeting, locomotion, transitions or T-pose defects, read [animation production](animation-production.md) before editing. It covers source timing, bone roll, shared playback, movement and contact gates.

**Gate:** compare the five priority gaps against the reference, first in clay and an early Godot portrait, then textured and in motion where affected. Correct visible proportion or eye/mouth defects before pores, wrinkles or strand-count polish. Record remaining likeness, garment and texture gaps before final export.

## 3. Integrate and prove

Export compatible GLB with stable part/material/action names and editable source. For a head package, reuse the live body skeleton and animation player; validate joint-index/bind compatibility and swap the matching eyes/hair when needed. Hook the variant into the actual player resources, including retained small-sided fixtures. An isolated prototype render alone does not update the match.

Use `games/beechlawn_rovers/tools/capture_native.py` for primary cloud appearance
reviews on native Forward+, following `docs/web_capture_notes.md`. Keep browser
captures for the Web renderer and functional checks; headless tests establish
structure and logic. Software Vulkan stills do not establish Mac GPU parity or
performance.

Inspect the actual Godot import in pitch-side portrait, three-quarter/profile, full-body and actual broadcast views, then representative idle, sprint, kick and turn poses. Confirm the review selects the intended roster profile and exported variant; a screenshot label or fallback Shane profile is insufficient. If shoulders, legs or clothing changed, extend checks to crouch, slide/get-up and keeper poses. Test transitions and contact timing where affected; sample complete changed clips and action boundaries, rather than treating a few pose stills as animation approval. Use bounded, serial Godot checks through the project runner; diagnose a timeout before starting another copy.

Count active rigs, mesh surfaces, triangles, texture dimensions/mips and transparent layers. Shared resources should propagate body/kit/animation updates while per-player sculpt and playback stay independent. Validate the assembled 22 players plus referee, not just the isolated asset. Cloud/Web captures establish integration and layout; native M1 Pro 1080p/60 fps remains a target until measured there.

Save before/after evidence, export/import results and unresolved gaps beside the asset brief. Generated promotional artwork is source art, not evidence of the playable mesh. Report the exact asset and backlog ID/ordinal changed; keep likeness approval separate from technical validation.

**Gate:** the intended roster player uses the reviewed export, common assets remain intact, relevant runtime checks pass and evidence/limitations are recorded.

## 4. Finish against the reference

Assess the actual playable model against every applicable criterion below.
Record pass/open with a linked view or moving review and the specific remaining
correction. Fix visible failures within the authorized task; do not rename an
unfinished asset "final" because it loads, or stop at a prototype when the
request is a finished player. Owner visual acceptance is distinct from these
internal checks and does not require asking permission for routine corrections.

| Final-quality criterion | Evidence required |
| --- | --- |
| Individual likeness | Recognisable skull/face silhouette and feature proportions in front, three-quarter and profile; identify estimated unseen anatomy |
| Clean facial anatomy | Fitted eyes/lids, natural lip closure, mouth corners, nose, ears and neck; neutral and intended expressions remain convincing |
| Skin finish | Reference-led fair complexion, retained detail, believable roughness/normal response and continuous neck/exposed limbs under unchanged daylight |
| Hair and facial hair | Reference-shaped hairline, dimensional groom and fine soft boundaries; no exposed cap, coarse repeated clumps or misplaced moustache mask |
| Body and kit | Reference-led build, complete correctly placed graphics, clean collar/sleeves/hem/socks and role-correct gloves; no visible local intersections in reviewed motion |
| Runtime motion | Intended head/eyes/hair on the shared rig; convincing changed clips/transitions and plausible live ball contact where affected |
| Delivery integrity | Source/recipe/export agree, untouched shared assets survive, actual roster/browser checks pass and target-renderer limitations are explicit |

A missing criterion is an open finishing task with a concrete next correction.
Keep technical validation, visual finish and native hardware acceptance as
separate recorded outcomes. Exact reconstruction of anatomy hidden by a single
blurred photo remains uncertain even when the visible model is polished.
