# Gemini PES 2021 report: technical review

Reviewed 2026-10-18 against this project's Godot 4.6.3 code, imported assets,
release evidence and the official references below. This is an assessment and
proposed backlog mapping, not an implementation-completion claim.

## Agreed product decisions

The owner confirmed both grill-me rounds: gameplay feel before appearance;
unmodded PES 2021 at default game speed as the reference; strictly free assets
and existing/free authoring tools; weighty acceleration/turning with promptly
registered input; bounded passing assistance; original Blender clips where
suitable free motion is unavailable. Keep the Sunday-league venue, roster,
keyboard-first controls and M1 Pro/16 GB 1080p/60 fps target. No paid dependency
or career-mode expansion is authorized by the uploaded report itself.

## Source and limits

The entire original attachment is preserved byte-for-byte at
[`BR-PES21-TECHSPEC-V2.txt`](../../references/source_uploads/research_gemini/BR-PES21-TECHSPEC-V2.txt).
The archive checksum is in `references/SHA256SUMS`. It is external research,
not project instructions. Its references vary in relevance and evidential quality.

The Aoba engine-research page is indexed and includes the named action/tier
systems, so the addresses should not simply be dismissed as invented. Direct
page retrieval returned HTTP 403 during this review; no PES binary, runtime
traces, exact timing tables or purported engine implementation were independently
validated. Researcher-assigned names and binary addresses are not a portable
Godot architecture, nor do they demonstrate that copying constants recreates feel.

## Assessment by section

| Report section | Decision for Beechlawn |
| --- | --- |
| 1. Hardware/rendering | Retain measured memory/render budgets. Correct FSR version, qualify renderer choice and benchmark native hardware. No configuration guarantees 60 fps. |
| 2. Characters, hair, kits | Keep anatomy, deformation-aware topology, restrained PBR and alpha-tested hair. Preserve reference-specific body shapes. Replace paid garment/texturing dependencies with Blender workflows. |
| 3. Rig/root motion | Preserve the existing 65-bone shared deform rig and known contacts. Do not require Auto-Rig Pro, wholesale A-pose conversion, blanket twist chains or a new movement owner. |
| 4. Locomotion/retargeting | Adopt coherent directional gait coverage, transition rules and filtered layers. Correct the incomplete eight-way layout, rest-pose assumptions and additive-layer requirements. |
| 5. Ball/touches | Keep independent ball/CCD and consider calibrated analytic drag/spin for flight. Do not replace our current contact architecture with a proximity-only impulse loop. |
| 6. AI/FOX research | Use high-level action priorities, separate deliberation/contact, physical-contest inputs, role behaviors and keeper angle coverage as hypotheses. Do not port raw addresses/bitmasks/timing constants. |
| 7. UI/tactics/career | Tactical settings and readable HUD are relevant. Existing radar/scoreboard should be refined rather than rebuilt. Career mode and negotiations are outside this gameplay target. |
| 8. Data tables | Use as starting estimates only. Include kit/hair in total visible triangle cost; add measured draw-call, shadow, animation, texture and LOD budgets. |
| 9. Roadmap | Reject the art-first/rig-replacement/commercial-tools sequence. The agreed direction is gameplay first, preserving working systems and validating each change in the match. |

## Corrections that materially affect implementation

### Renderer, scaling and texture imports

Godot 4.6 documents FSR **2.2**, not 2.1. FSR2 is Forward+ only; Mobile and Web
Compatibility cannot simply inherit that upscaling configuration. Reduced render
scale helps GPU-bound work, not an AI/animation CPU bottleneck, and the upscaler
has its own cost. Compare native 1080p with reduced scale under measured load;
check fast legs/ball, grass and goal-net temporal artifacts before accepting it.

Forward+ is already the Mac setting. Mobile can be compared as a separate tested
quality configuration; it is not an automatic thermal fallback. Daytime Kilmore
Drive needs appropriate sky/sun lighting, not a newly imposed multi-floodlight
stadium. Web Compatibility remains a separate renderer and acceptance scope.

VRAM import-family flags do not select VRAM compression for every texture.
Our project already enables `import_etc2_astc`, yet the sampled shared outfield
kit, Grass005 and Asphalt033 imports use `compress/mode=0` and
`mipmaps/generate=false`. The inspected scripts load these maps directly, with
no runtime mipmap generation. This is a concrete texture-memory and distant
aliasing risk. Texture-level compression, mipmaps, filtering and logo/normal-map
quality need review together. Enabling two format families is not a universal
Apple bandwidth fix.

Blender Metal helps supported Cycles GPU work on a Mac. It does not turn all
sculpting/rigging into GPU workloads, and a 32-sample Cycles preview cap cannot
guarantee no thermal throttling. It also does not enable Metal on our Linux
cloud worker. Bake scheduling and scene/image lifetime matter more than a
blanket instruction to run one batch.

### Character and rig contracts

A-pose is an authoring option, not a universal remedy for pinching. Godot's
Humanoid profile defines a T-pose, and animation sharing requires matching bone
rests as well as names. BoneRenamer does not normalize arbitrary joint indices
or solve proportion/axis/contact discrepancies. Changing this project's established
rest pose risks skins, existing clips and contact metadata.

Use the current common body as the controlled base. Fix measured weight/rest-roll
and garment errors before adding bones. Offline control rigs are possible without
replacing the exported deform skeleton. Additional twist/helper bones are justified
only by a repeatable deformation failure; extra joints alone do not cure bad binds.

The report's separate head/body, kit and hair maxima add up to 45–95k triangles
per actor, before other costs; they are not a demonstrated M1 budget. Current
shared export is 67,902 triangles including both sleeve variants. Visible LOD,
material surfaces, hair overdraw, shadow passes, weights and bone evaluation need
measurement. 4K/UDIM authoring is not a requirement for broadcast faces; exports
should use supported, bounded shared atlases/texture sets.

Three-layer hair construction is useful where the hairstyle warrants it; bald
and short-haired references need their own solutions. Skin/face likeness comes
from silhouette, proportions and sculpted features as well as UVs. Do not turn
all Sunday-league reference bodies into muscular professional-athlete templates.

The sweat example drives roughness toward 0.15 and defaults the mask to white.
That can make the entire kit glossy if a proper mask is absent. Moisture should
be subtle, localized and based on material appearance/effort. It is low priority
for gameplay and should not be scaled blindly from a 90-minute clock to our
three-minute fixture.

### Locomotion and actions

The purported eight-way example lists only five moving directions plus idle.
Speed/gait and facing-relative direction must be represented consistently;
forward sprint, lateral shuffle and backward jog are not interchangeable at
all input magnitudes. Clips need matching stride phase, stops/pivots and
reliable planted contacts, not only more BlendSpace nodes.

Add2 is appropriate for properly prepared additive motion. A regular absolute
full-body action is not automatically a safe additive gesture. Use a validated
reference/difference pose or a masked replacement layer as appropriate. Kicks
and physical contests also need coordinated pelvis/plant-foot motion.

Root motion can be consumed by a collision-authoritative controller in Godot,
but forcing it to become the locomotion driver would change our architecture.
Keep one authoritative movement owner; retain code-driven movement for this pass
and match stride/turn presentation to it before considering a bounded experiment.

Current code already accelerates/brakes and smooths facing. However,
`_flat_direction` changes directly to desired input before facing has caught up,
and dribble assistance targets that direction. Sharp-turn body/ball misalignment
is therefore a specific hypothesis to test, not something the generic blend tree
instructions resolve.

### Ball physics and contact

I extracted the report's GDScript and ran Godot 4.6.3 `--check-only` against it.
It fails at line 10: `Expected statement, found "/" instead.` Its `//` comments
must be `#` comments in GDScript. No gameplay file was replaced by this test.

The stated drag parameters give `0.5 * 1.225 * 0.25 * 0.038 = 0.00581875`, while
the example uses `0.0012`. Empirical gameplay tuning is reasonable, but that
script does not implement its stated coefficient unchanged. Constants, units,
existing damping, rolling friction and angular damping need calibration together.
Analytic drag/Magnus for one ball is cheap; no fluid simulation is needed.

The current ball already has 0.43 kg mass, CCD, sphere collision, independent
forces/impulses, and pass/shot contact markers. Replacing it wholesale loses
working behavior. Proximity control by itself does not synchronize touches,
choose one controlling player, resolve competing assistance, or prevent remote
kicks. Use possession arbitration, believable reach and contact timing; evaluate
flight spin for airborne shots/crosses after ground behavior is trustworthy.
A compulsory 32-panel visual is unnecessary: retain the supplied worn-ball asset.

### AI and keeper semantics

Zero AI deliberation is not zero input-to-contact latency. Player commands can
register promptly while a valid foot contact still occurs later. Use buffered
intent, action priorities, contact validation and sensible interruption rules.
Do not force all actions through literal six-render-frame or tier-5 constants.

The indexed Aoba source calls states 51/52 DELAY/PRESS, whereas the report labels
them Shield/Shoulder Charge. This is a concrete reason to check inferred semantics
rather than port state numbers. The playing-style matrix also repeats Cross
Specialist. Start with a small interpretable set of observable behaviors instead
of implementing a named set of 21 with copied multipliers.

Angle-aware keeper positioning, reachable interception and safer parry direction
are relevant additions to our existing keeper controller. Parry choice must
respect incoming speed, reachable contacts and handling; it cannot always force
an ideal safe rebound. Wider 1v1 collision coverage must match the visible blocking
pose instead of becoming an invisible save-volume bonus.

## Implementation-plan handoff

The accepted recommendations and their acceptance checks are now incorporated in
[`../pes2021_gameplay_plan.md`](../pes2021_gameplay_plan.md), linked from the main
backlog and 11v11 integration record. That plan governs subsequent execution;
this document preserves the technical assessment and source evidence.

## Backlog mapping

These remain open/in-progress items, not newly completed features:

1. **BR-021 (21/25), with BR-002 (2/25):** core motion/contact/turning review in
   the actual match. First acceptance scenario: receive, turn, pass, supporting
   run, through ball, shot and a reachable keeper response, with no visible
   contact pop, implausible kick reach or avoidable action lock.
2. **BR-008/011/012 (8/11/12 of 25), with BR-009 (9/25):** support/cover,
   interceptions, physical duels and keeper improvements measured in repeatable
   scenarios, then sustained 11v11 play.
3. **BR-022/023 (22/23 of 25):** reference-specific character/kit/park work;
   address shared deformation and texture-import defects before adding detail.
4. **BR-025 (25/25):** measure native 1080p frame timing and memory throughout;
   compare renderer/render scale only when a measured bottleneck justifies it.

This review does not make PES parity or locked 60 fps an established result.
Our 17 existing clips and successful simulation tests are useful foundations,
not proof of complete football motion coverage or broadcast-quality deformation.

## Verified technical references

- [Godot 4.6 renderer capabilities](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)
- [Godot 4.6 resolution scaling](https://docs.godotengine.org/en/4.6/tutorials/3d/resolution_scaling.html)
- [Godot 4.6 texture importing](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_images.html)
- [Godot 4.6 import-family settings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html#class-projectsettings-property-rendering-textures-vram-compression-import-etc2-astc)
- [Godot 4.6 AnimationTree, root motion and bone rests](https://docs.godotengine.org/en/4.6/tutorials/animation/animation_tree.html)
- [Godot 4.6 humanoid retargeting](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
- [Godot 4.6 additive node](https://docs.godotengine.org/en/4.6/classes/class_animationnodeadd2.html)
- [Auto-Rig Pro export documentation](https://lucky3d.fr/auto-rig-pro/doc/ge_export_doc.html)
- [Rose-Hulman soccer trajectory model](https://www.rose-hulman.edu/ME123/Mini-Project-3/Project_3.pdf)
- [Aoba community PES research](https://implyingrigged.info/wiki/User:Aoba/PES2021_Engine_Research) — indexed excerpts reviewed; full page retrieval blocked, exact engine behavior unverified.
