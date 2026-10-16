Aegis — plan for matching the eight supplied visual references

Reviewed 16 original PNG files from the supplied Google Drive folder: eight current/reference pairs, all distinct. Source-code audit: `fb69eae8be85d4e78b8aedc99ceb46d100ce152f`, the published Mac build at the time of this review. The user confirms the current screenshots were taken today, 2026-10-16, on an Apple M1 Pro Mac with 16 GB memory. Capture metadata should record the exact build SHA during baseline verification. This is a research and production plan; appearance improvements described below have not yet been implemented or verified.

Confirmed user priorities: match all eight new references as closely as possible while maintaining steady 60 fps on the Apple M1 Pro with 16 GB memory, using free assets and existing tools. Match the reference skin, including its wet sheen. These govern every visual and tooling choice below. The initial measurement resolution remains 1080p internal rendering; the user's usual display and internal rendering resolution are not yet specified.

The strongest route is a shared lighting/material pass followed by targeted reconstruction of the hero characters. The wide arena references are primarily a lighting, reflection, surface-response and crowd-presentation problem. The portrait references also require better facial forms, hair construction and authored textures. Changing exposure or adding polygons alone will not produce those faces.

The reference PNGs are art targets. Their composition, richness, detail hierarchy and finish guide the work. Preserve the game's actual identities, consistent arena geometry, readable sign text, black ramp barricade facing, concrete under the mats, capped bleeding, and functional controls. The user's latest instruction makes the new references authoritative for skin appearance and wetness, superseding the earlier restrained-sweat preference. Some generated details change between views; those require one consistent 3D design rather than independent imitations for each camera.

**What the audit established**

| Evidence | Finding | Consequence for the plan |
| --- | --- | --- |
| All eight current PNGs | Approximately 3.4K wide, with an embedded display ICC profile. The references are approximately 1.7K wide and have no embedded ICC profile. | Honour the source ICC profile, assume sRGB for the untagged references, and compare at matched output size/crop before using colour or sharpness metrics. Screenshot dimensions alone do not establish the game's internal rendering resolution. |
| `game/project.godot` | Forward+, a Mac Forward+ override, 4x MSAA, TAA, 60 Hz simulation and physics interpolation are already enabled. | Test their actual runtime behaviour and cost. Increasing animation sample rate or enabling another AA setting is not an adequate diagnosis. |
| `game/scenes/match.tscn` | AgX, glow, SSAO, SSIL, SSR and volumetric fog already exist. | Tune the existing pipeline through controlled comparisons, avoiding layers of compensating adjustments. |
| Reflection-probe search | Only `RingReflections`, centred at `(0,3,0)` with size `(26,12,26)`, was found. The stage is positioned near Z = -38. | Stage and much of the ramp lack that probe's coverage. Investigate a separate stage/ramp reflection solution and reliable off-screen fallback. |
| `MaterialLibrary` | Stage deck roughness is already 0.26. The truss is metallic but has roughness 1.0 and residual house emission. | Broad, directional reflections and convincing truss metal need coverage and material calibration, rather than a blanket roughness reduction. |
| `cody_rhodes.glb` | Source total: 74,213 triangles, 12 materials; no authored normal or metallic/roughness texture slots. | Add coherent anatomical normal and region-specific roughness maps. Runtime generic pores currently supply some microdetail, but not authored facial relief. |
| `roman_reigns.glb` | Source total: 79,150 triangles, 16 materials, two skins. Runtime code repairs and augments materials. | Audit the resolved runtime materials and both skeletons before changing the mesh. The GLB's original material slots do not describe the whole shipped look. |
| `cody_hair.glb` | Source total: 53,284 triangles, used as layered shells. | A large triangle count is already present. Rebuild strand flow, clumps, hairline and silhouette where required; do not simply subdivide the shell. |
| `cody_coat.glb` and `EntranceCoat` | Source total: 26,820 triangles; runtime cloth/metal materials, normal/ORM maps and a following skeleton already exist. | Diagnose lighting, material-channel interpretation, normals and cloth form together. The bright coat is not evidence that the coat has an emissive material. |
| Motion code | `MatchSmoothing`, `Inertializer`, `FootPlant` and `FootLock` already exist. | Review clip quality, integration and modifier order before introducing another smoothing/IK layer. |

Triangle totals above describe source files, including parts which can be hidden at runtime. They are not measurements of drawn geometry or GPU cost.

**The work required for each pair**

1. **Stage, ramp and light rigging**

Current: the foreground truss is a broad dull blue band; fixture housings read as black blocks; the stage, ramp and crowd have limited separation. The new image has recognisable reflective metal tubes, visible fixtures, shafts in haze, richer pools of colour across the audience, and broad reflections running down the ramp.

Work: establish steel/aluminium roughness variation and correct normals; add bevels/clamps/cabling only where they affect silhouette or highlights; make the lens and its actual light source agree. Improve the stage and ramp reflection coverage, then shape restrained blue/pink audience washes against neutral ring light. Refine the high camera to show more of the set while keeping the foreground truss believable and clear of the key screen/pyro area. Check camera position before considering a structural rig move.

Acceptance: the truss reads as round metal without self-illumination doing the main work; stage and ramp have coherent coloured reflections; the audience occupies layered space; important stage artwork and full rocket trajectories remain readable through the intro camera moves.

2. **Roman entrance — walking from tunnel**

Current: the portal is a flat luminous shape, the LED image is muted, and Roman lacks a strong physical connection to the deck. The target adds stronger screen contrast, convincing floor reflections, lit practical fixtures, contact shadows and local atmospheric depth.

Work: give the portal rim a coherent painted finish and edge response, retain depth in the perforated backing, and calibrate emissive LEDs separately from the exposure of skin. Match visible floor fixtures with their light/shaft contribution. Improve the deck's normal scale, panel boundaries and roughness breakup; supply off-screen reflections and a stable boot contact shadow. Audit the first walk strides and the transition off the tunnel surface.

Acceptance: Roman is grounded from his first visible step, with no foot hover or sliding; the floor receives the colour of the visible set; LED highlights stay bright while their coloured artwork remains legible.

3. **Roman entrance on ramp — portrait**

Current: the face is pale, smooth and insufficiently shaped; eyes look wide and weakly seated in their sockets; the beard forms a fairly solid mass; the necklace is visibly angular. The new image has a defined brow/jaw, convincing eyes, skin colour variation, individual beard/hair clumps, a dense tattoo and shaped glossy red necklace elements.

Work: first isolate the contributions of follow spot, walk key, camera key and scattering. Then fit the head's brow, eyelids, cheek planes, nose, mouth and jaw in front/three-quarter/profile views. Author face/body normal and roughness detail without baking illumination into base colour. Improve eyebrow and beard transition, hairline and wet hair clumps. Rebuild selected ula fala elements with curved silhouette and local variation. Retain dark detail in the tattoo under all cues.

Acceptance: Roman remains recognisable in a neutral light rig and in the actual entrance; the gaze is focused, eyelids seat the eyes, the beard merges naturally into the cheek/jaw, and neither facial planes nor tattoo disappear under the lights.

4. **Roman pose on ramp**

Current: raising the arm exposes soft anatomy and a somewhat rigid hand, while the belt is washed out and broad around the waist. The target has a coherent shoulder/chest transition, a natural index-finger pose, fitting belt, restrained gold highlights and textured trousers.

Work: review the raised-arm deformation and neck/head alignment; refine skin weights and pose-space corrective shapes where necessary. Polish the finger curl, wrist, elbow, shoulder and settling of the pose. Treat belt strap and plates separately: fit to the moving waist, keep hard plates rigid, bake fine engraving, and give gold its reflection environment. Add cloth seams/folds at the appropriate scale.

Acceptance: no armpit collapse, stretched neck, floating belt or back clipping at approach/peak/settle; the pointing hand is readable; gold retains engraving rather than becoming a white patch.

5. **Cody mid-body close-up — entrance on ramp**

Current: the white coat regions clip heavily, gold and pale fabric merge, the hair forms a bright solid cap, and face/neck surfaces are overly smooth. The new image separates red/blue fabric, white panels, gold ornaments, fine seams, hair clumps and facial detail under a more directional key.

Work: use this as a principal clipping/material calibration shot. Check resolved coat colour, ORM channels, normals and rim response under isolated lights. Rebuild or refine lapel thickness, collars, shoulder scale silhouettes and folds only after the highlight behaviour is stable. Author head/body anatomical detail and regional roughness. Improve the shape and asymmetry of brows, eyelids and mouth; replace the helmet-like hair silhouette with groom-derived clumps/cards and fine edge breakup. Inspect the exposed neck and its attachment under turns.

Acceptance: white cloth retains texture and fold detail, gold reflects as metal, red remains rich, blue reads as fabric, and hair retains strand direction without becoming a luminous cream shell. The face works from both entrance angles, not only one portrait.

6. **Cody in ring — dark ramp and stage**

Current: large areas of the audience disappear into black; the ramp feels empty and matte; the ring, crowd and stage seem disconnected. The target has a brighter but still layered audience, visible stage-to-ring reflections, clearer apron/steps detail and spatially coherent beams.

Work: establish a dedicated entrance/waiting cue with a measured lower limit for audience visibility. Add local washes and fixture-driven haze, improve the ramp's reflection fallback, and revisit apron/steps materials. Tune the ramp/ringside floor by material zone so polished stage finish, vinyl pads, canvas and concrete remain distinguishable. Use the same physical set and shared materials as the tunnel and stage views.

Acceptance: rows remain distinguishable across the whole bowl, the eye travels naturally from Cody to the stage, steps show metal relief, and stage/ringside materials retain their different finishes. Ramp barricade facing remains plain black.

7. **Cody and Roman models — close faceoff in ring**

Current: anatomy is broad and smooth; hands are open and rigid; Cody's hair is a solid pale form; Roman's beard/hair and tattoo lack the target's depth. Aubrey's facial form and bright shirt stand out as weak links. The target uses convincing faces, layered hair, natural hands, visible gear structure and consistent lighting across all three people.

Work: use the finished hero heads/materials from the entrance work, with in-ring lighting validation. Refine shoulder/neck transitions, natural hand poses and skin/gear normal detail. Bring Aubrey's head, bun, eyes and shirt material to the same standard; white stripes should behave as cloth. Add a small, controlled faceoff performance: breathing, blinking, eye focus and subtle weight transfer with clear hand-to-thigh clearance. Use modest portrait depth of field while keeping both wrestlers readable.

Acceptance: both wrestlers and Aubrey belong to the same scene; eyes stay on the appropriate subject; hands neither hover rigidly nor intersect legs; head turns preserve likeness; ref shirt and skin retain detail without clipping.

8. **Roman and Code in Ring Faceoff — high corner wide shot**

Current: the overall layout is sound, but the canvas has broad smeared-looking marks and soft surface detail, ropes are bright uniform lines, and the surrounding floor/crowd lacks the reference's richer response. The target has a tactile canvas, padded corners, fine metal/rope detail, controlled contact shadows and varied audience lighting.

Work: author correctly scaled canvas weave, subtle wrinkles and local scuffs; keep branding separate from physical relief so it does not become raised or distorted. Refine rope coating, pad seams and post/connector highlights. Improve ringside vinyl roughness variation and reflection coverage, with concrete retained underneath and in concourses. Use higher-quality crowd assets where the camera can resolve them, with lower-cost representations at distance.

Acceptance: the canvas reads as matte fabric, the ringside pads as vinyl, steps/posts as metal and crowd areas as concrete. Shadows ground all actors and ropes retain stable edges while the camera moves. Reflection changes must not make the canvas look wet.

**The research translated into this project**

Use a small material/lighting calibration scene and the actual game renderer. Fix albedo, normals, material masks and highlight response before applying a final grade. The PBR workflow described by Frostbite's rendering team depends on consistent material inputs and lighting. Here that means removing compensating brightening/darkening where it obscures the actual cause, then re-testing the same surface under ring, tunnel and ramp cues. [Sébastien Lagarde and Charles de Rousiers: Moving Frostbite to Physically Based Rendering](https://seblagarde.wordpress.com/2015/07/14/siggraph-2014-moving-frostbite-to-physically-based-rendering/).

For faces, use authored layers with distinct jobs: base colour carries pigment, normal maps carry form/detail, roughness controls the changing highlight, and scattering supports flesh without erasing anatomy. Epic's scanned-character example documents separate skin maps and eye/hair construction. These are useful production principles; its Unreal shader cannot simply be copied into Godot. Use 4K face maps where the camera can resolve them, then set body/gear resolution from actual screen coverage rather than applying 8K everywhere. [Epic: Photorealistic Character](https://dev.epicgames.com/documentation/en-us/unreal-engine/photorealistic-character?application_version=4.27).

The approved skin target includes the reference's richer natural colour, visible pores and fine creases, defined anatomical relief, and wet highlights on face, chest, shoulders and arms. Author region-specific roughness and a separate masked wet layer with fine breakup/beads so highlights move coherently with the character. Calibrate this response together with the entrance and ring lights, preserving facial planes and tattoo detail. Match wetness in the reference entrance and faceoff shots as well as during a match; any time-based progression must remain within the approved reference range. Use texture-driven layers and existing material features within the 60 fps budget. Judge skin against the relevant reference crops under matching cameras and under moving light, with retained pore detail and no broad clipped patches. Increasing one global clearcoat value is insufficient to establish a match.

For stage/floor reflections, combine screen-space detail with a local probe fallback for things outside the camera view. Godot explicitly supports that combination. Test a stage probe and, if required, a ramp zone with appropriate box projection, capture masks and conservative resolution. Capture the environment without freezing an actor into a cached reflection. Prefer a stable representative capture and controlled cue updates; continuously recapturing every probe is costly. Changing LED video will still need testing because a cached probe cannot reproduce every changing off-screen pixel. [Godot 4.6: Reflection probes](https://docs.godotengine.org/en/4.6/tutorials/3d/global_illumination/reflection_probes.html).

For static architecture, consider baked neutral indirect light after the basic look works. The arena is assembled in code at runtime, so baking requires an editor/build-time scene generated from the same layout, with suitable UV2. Bake stable architecture and low-frequency indirect light; preserve dynamic ring shadows, show lighting, screens and destructible props. Do not bake a bright show cue into a room that later needs to dim. [Godot 4.6: LightmapGI](https://docs.godotengine.org/en/4.6/tutorials/3d/global_illumination/using_lightmap_gi.html).

For beams, keep haze local and give only meaningful fixtures a volumetric contribution. Review moving beams for trails/flicker and fog for excessive veiling of the crowd. Godot documents the temporal-reprojection tradeoff and lower-cost mesh alternatives; select the technique per effect and quality tier. [Godot 4.6: Volumetric fog](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html).

The recent AAA research is instructive about budgets: MachineGames' SIGGRAPH 2025 hair presentation sets explicit performance and platform constraints around its strand system. That supports assigning a measured budget and good authoring workflow, rather than treating strands as an automatic upgrade. For Aegis, begin with groom-derived cards/clumps, anisotropic shading, consistent tangents, solid scalp coverage and controlled transparency; assess a more complex hair renderer only if the demonstrated gap warrants it. [MachineGames: Strand Hair in Indiana Jones and the Great Circle, SIGGRAPH 2025](https://advances.realtimerendering.com/s2025/content/Strand%20Hair%20in%20IJGC%20-%20Final%20Slides%20%28Post-Conference%29.pdf).

For crowds, concentrate real geometric faces/hands and richer animation around the sign and other close camera regions. Use a varied medium-distance library and batched distant people. Split instanced crowds by spatial region so an entire arena-sized batch does not remain visible unnecessarily. This builds on the existing textured crowd work. [Godot 4.6: Optimizing 3D performance](https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html), [Godot: MultiMesh culling and batching](https://docs.godotengine.org/en/4.6/tutorials/performance/using_multimesh.html).

For asset export, bake unsupported procedural detail into deliberate image maps and validate its channel/colour-space interpretation in Godot. Do not assume Blender's final appearance transfers through GLB. Tangent-space normals must match the exported geometry/tangents; non-colour maps need data import settings. [Blender: glTF material/export guidance](https://docs.blender.org/manual/en/4.2/addons/import_export/scene_gltf2.html), [Godot 4.6: Standard and ORM materials](https://docs.godotengine.org/en/4.6/tutorials/3d/standard_material_3d.html).

**Smoothness requires a separate moving-image pass**

The PNGs reveal pose and surface defects, but cannot establish frame pacing, foot sliding or transition quality. Record reproducible 10–20 second native clips for tunnel walk, ramp tracking, finger raise/settle, Cody coat handling, faceoff, normal locomotion and a high-impact paired move. Include referee and nearby crowd motion.

Measure CPU and GPU frame times separately, with warm assets and shaders, using real-time playback rather than Movie Maker's fixed-FPS clock. Log resolution, adapter, driver, renderer, display refresh and build SHA. Reuse `tools/capture/native_reference.sh`, the existing reference/match probes and motion/foot-skate probes; extend the shot set to these eight views.

Retain the 60 Hz authoritative simulation. Audit visual interpolation exactly once across root, skeleton, props and camera; clear interpolation on true cuts/placements. Inspect starts/stops/turns, stride-speed matching, planted-foot drift, pelvis travel, arm swing, neck posture, gaze, blinking and secondary motion. Improve the actual clips where the performance is weak. A well-authored 30 fps animation can interpolate smoothly; changing its sample rate to 60 fps does not supply missing weight or a better pose. Godot distinguishes these timing issues from rendering stutter. [Godot 4.6: Jitter, stutter and input lag](https://docs.godotengine.org/en/4.6/tutorials/rendering/jitter_stutter.html).

For paired moves, preserve GrappleRig's contact ownership and add cosmetic follow-through around its existing events. Sports-game research on multi-character interactions reinforces the need to treat entry/exit transitions and synchronisation as part of the performance. A full motion-matching migration would require its own content and evaluation project; the first pass should repair the smaller set of performances the player actually sees. [EA/GDC: Environmental and Motion Matched Interactions — Madden, FIFA and Beyond](https://gdcvault.com/play/1027465/Animation-Summit-Environmental-and-Motion).

**Available skills and practical delivery**

The installed executable is Blender 4.3.2. The local skills supply craft workflows; work can be authored through reproducible Blender Python scripts and Godot code. Their references to a live BlenderMCP session do not establish that such a session is connected.

| Work | Applicable local skills/tools | Deliverable |
| --- | --- | --- |
| Reference fit and production order | `blender-pro-workflow`, `camera-cinematography` | Locked view specifications and comparable proof captures. |
| Heads, anatomy and deformation | `import-wrestler`, `character-artist`, `retopology`, `rigging` | Improved mesh/forms, preserved rig contracts, corrective poses and reviewed head views. |
| Hair, brows and beard | `hair-groom`, `blender-modeling`, `blender-materials` | Groom-derived game geometry, atlases, stable material/tangent setup and LODs. |
| Coat, belt, necklace and arena | `environment-artist`, `prop-artist`, `cloth-sim`, `hard-surface` | Targeted geometry and fit improvements; baked cosmetic cloth where appropriate. |
| Maps and finish | `materials`, `blender-uv-texturing`, `texture-workflow` | Cohesive colour/normal/roughness/AO/metal masks with verified imports. |
| Motion | `animation`, `blender-animation` | Reference-driven clips, corrected transitions and grounded performance. |
| Shipping quality | `godot-export`, `asset-optimization`, `qa-review`, existing capture/evidence tools | Valid GLBs, render comparisons, performance evidence and regression checks. |

Image generation can help create detail references, base-colour source material and masks. Lighting must be removed from colour sources where necessary, and geometry-derived normal/AO maps must be baked or authored consistently. A generated face image is not a production-ready, rigged 3D head.

The highest-risk part is near-reference facial likeness. Begin by testing the existing head topology against measured front/profile/three-quarter landmarks. Where necessary, reconstruct or sculpt the head in Blender and transfer it onto the established rig. Use existing references and freely licensed source material, with repeated neutral-light and in-engine review. The approved workflow uses the existing tools and free assets; achieving likeness can require substantial manual refinement of forms, topology and textures.

For standard surfaces, existing scanned materials can be improved and supplemented with coherent PBR sets; Poly Haven is one available CC0 source. Source choice should follow the required finish rather than texture resolution alone. [Poly Haven licence](https://polyhaven.com/license).

**Implementation sequence and exit conditions**

| Stage | Scope and dependency | Exit evidence |
| --- | --- | --- |
| 0 — Baseline | Use the supplied screenshots taken today as the observed baseline; capture the shipped build in the eight views with build metadata; normalize comparison colour/size; record M1 Pro timing. Establish shot IDs and observed gaps. | Eight repeatable baseline views, representative motion clips and honest runtime metadata. |
| 1 — Shared look | Isolate lights; calibrate exposure/material response; resolve stage/ramp reflections; tune local haze, truss and LED balance. Review the stage-wide, Roman portrait and Cody-coat shot early. | Approved environmental proof plus retained detail in white cloth and skin. Verify adjacent cues during camera movement. |
| 2 — Hero characters | Improve heads, skin map sets, eyes, hair/beard/brows, targeted anatomy/correctives and natural hand poses. Refine coat, belt and necklace. | Neutral-light front/profile/three-quarter review and actual entrance/faceoff captures; clean deformation at raised arm, bent torso, turn and coat handling. |
| 3 — Ring and audience | Improve canvas/ropes/pads/steps/apron, audience lighting and visible fan geometry/materials. Preserve the sign and ramp-barrier requirements. | Both ring-wide views, sign close-up and gameplay camera compared with the references. |
| 4 — Performance and movement | Correct content and integration defects exposed by the motion clips; choose AA/reflection/fog/crowd settings from measured Mac cost. Evaluate baked architecture only where it pays back. | Smooth native playback, clear foot contacts, no doubled interpolation, stable hair/ropes/LEDs and recorded frame-time distributions. |
| 5 — Final shot matching | Tune all eight views together; check the normal gameplay camera, intro pyro, entrances, prop handoff and full match. | Final old/new game comparison set, short motion reel, relevant deformation/contact tests, determinism checks, evidence gate and Mac build validation. |

Complete each stage with a bounded change and rendered review. Do not wait until the entire arena and roster have been rebuilt before checking the result. Start with the three proof shots in stage 1; they expose the dominant lighting/material problems before expensive character work.

**Confirmed frame-rate priority and Mac validation targets**

Steady 60 fps is the user's requirement on the confirmed Apple M1 Pro Mac with 16 GB unified memory. Initially measure at 1080p internal rendering. Native Retina resolution requires a separate performance test. Match, entrances, close-ups, crowd cutaways and the opening pyro all need native measurement against the same 60 fps goal. Track sustained performance and memory pressure across the complete sequence as well as short proof captures.

Each frame has approximately 16.7 ms. Aim for headroom below that limit; use p95 at or below 16.7 ms after warm-up as an initial gate and report p99, missed frames and worst spikes as well. A mean of 60 fps alone does not establish steadiness. These are proposed acceptance criteria, not achieved results.

Preserve hero faces, silhouettes, authored material quality and readable ring lighting first. Fit the frame budget through local or baked lighting where appropriate, controlled reflection updates, lower-cost fog, suitable shadow coverage, texture residency and crowd LOD/batching. Any optional quality presets must also target 60 fps on their supported hardware. Capture the three proof shots and moving sequences early enough to expose expensive choices before extending them across the scene.

Profile texture residency, CPU/GPU time, draw calls, transparency overdraw and unified-memory pressure. Evaluate the existing MSAA-plus-TAA combination against alternatives using the ropes, hair and LED details. Preload/prewarm visible variants where appropriate and verify first-use stutters separately. Cloud/software rendering may support visual investigation through Forward+, but cannot establish target-Mac speed or complete Metal equivalence.

**How success is judged**

Use the same camera, action beat and output size for comparison; honour colour profiles. Review whole-frame composition and face/material crops. Measure clipped highlight area and subject/background separation in defined regions. Review facial landmarks and silhouettes before pore detail. Test moving highlights/reflections as the camera crosses each zone. Use perceptual comparisons as guidance, with human review; pixel scores against generated images cannot establish likeness, physical consistency or animation quality.

The reference files establish the new art target. Some older written targets deliberately require darker crowds/drier floors and are stale relative to these images; reconcile those visual criteria explicitly against the supplied references. Preserve gameplay, determinism and contact gates, and retain the previous appearance evidence so changed art direction remains reviewable.

The desired result is one consistent, playable 3D scene that approaches all eight targets. Environmental lighting/material improvements are feasible with the current stack. Exact portrait likeness and every sharp off-screen reflection are the largest uncertainties; they require higher-quality assets and repeated in-engine review, rather than a promise based on a successful export or test run.

**Confirmed preferences and remaining information**

- Performance priority: steady 60 fps, confirmed by the user.
- Asset budget: prefer free assets and existing tools, confirmed by the user. Plan all implementation work within that constraint.
- Hardware: Apple M1 Pro, 16 GB memory, confirmed by the user.
- Visual priority: match all eight new references as closely as possible within the confirmed performance and tooling constraints.
- Skin and sweat: match the new references, including their wet sheen, colour, pores and highlight definition, confirmed by the user's latest instruction. This supersedes the earlier restrained-sweat preference.
- Screenshot date: taken today, 2026-10-16, confirmed by the user. Record the build SHA in new captures so comparison evidence stays tied to a specific revision.
- Remaining measurement detail: usual display/internal rendering resolution. Use the stated 1080p internal baseline for initial profiling and assess the actual playing resolution during native Mac verification.

The adjacent `manifest.json` records exact filenames, Drive IDs, dimensions, ICC presence, file sizes and SHA-256 checksums for the 16 inspected source images.
