# Agent guidance

## Aegis priorities and incremental delivery

The owner's [prioritised backlog](gauntlet/refs/next_steps.md) controls work
order by impact, effort and dependencies. The
[quality plan](gauntlet/refs/incremental_quality_plan.md) retains scope,
acceptance and stable IDs; original numeric IDs no longer indicate execution
order. These documents supersede older handoffs where they conflict.
Keep commits focused and group related work into small batches with shared
validation and one Mac deployment. Verify `mac-latest` references the batch
commit before starting the next batch. Update the backlog and release ledger
with publication evidence, completed work and remaining limitations.
Documentation-only updates need no Mac rebuild or expensive regression run.

The owner explicitly authorised deployment for review on their Mac after the
focused checks pass. Missing cloud GPU/full-arena captures are not a publication
blocker: record appearance and native M1 performance as awaiting owner review,
publish the Mac build, verify its exact commit, then continue the priorities.

Aegis targets 60 fps (16.67 ms) on a MacBook M1 with 16 GB memory. Preserve
60 Hz simulation, smooth animation, Fight Forever pacing and broadcast quality.
Only native measurements establish Mac performance. Use the cheapest adequate
checks: mannequin logic/contact checks, real-mesh deformation renders, then
full-arena presentation captures. Keep complete regressions for broad gameplay
or animation changes; rerun costly checks only for changes or unresolved risks.

Use reference-led game-design, animation, modeling, lighting and materials
judgement without claiming employment or credits on reference games. Preserve
the approved entrances: fewer cuts, front/side walks, a slightly below-waist
lens, wide entry/handover coverage, and close poses/faceoff. Only the ending
replay is removed; in-match replay settings still apply. Mac is the delivery
platform; backlog ID 7 retires Web publishing after its dependency audit.

Read relevant files/skills only, batch independent inspections and keep concise
handovers. Keep [sourced guidance](gauntlet/refs/codex_working_guidance.md)
separate from project measurements. Use the routing and quality policy below:
delegate specialist work to its owner instead of doing it in the main context,
and keep small, self-contained edits in the main agent.

## Communication style

Keep updates concise (1–2 sentences) and non-technical during work. For routine
completion reports use **Completed**, **Validated**, **Remaining** and **Next**.
Do not show long code blocks, raw logs, reasoning traces or file contents unless
asked.

## Development strategy and model routing

Quality comes first, efficient execution second, token efficiency third. Do not
trade a major quality gain for a small saving. Work within the owner's OpenCode
Go subscription; never automatically use a model or service that can incur
charges outside it.

Verified catalog facts: `opencode-go/deepseek-v4.1-flash` exposes `low`, `high`
and `max` reasoning variants; `opencode-go/deepseek-v4-pro` exposes `high` and
`max` and is available in the subscription; Pro has no image input, while Flash
does. `opencode/nemotron-3.5-super-vl-free` is active, accepts image input and is
genuinely free: input, output and cache all cost zero. Reasoning variants are
pinned in agent frontmatter because the root default model does not retain a
`#variant`.

| Agent | Mode | Model | Role |
| --- | --- | --- | --- |
| `aegis-main` | primary | `opencode-go/deepseek-v4.1-flash#max` | Default owner: classify, plan, coordinate, implement gameplay, integrate, validate and report. |
| `blender-specialist` | subagent | `opencode-go/deepseek-v4.1-flash#max` | 3D asset work: modeling, rigging, UV, texturing, materials, lighting, animation, arenas, VFX and export. |
| `architect` | subagent | `opencode-go/deepseek-v4-pro#max` | Pro escalation for difficult reasoning, architecture, trade-offs and complex choreography; read-only. |
| `visual-qa` | subagent | `opencode/nemotron-3.5-super-vl-free` | Selective visual review of rendered wrestler models, animations, textures, lighting, arenas and gameplay screenshots; read-only and free. |

OpenCode also reads the root `AGENTS.md` and discovers the shared skills in
`.claude/skills/` and `.agents/skills/` from the repository root. Start a
Beechlawn session in `games/beechlawn_rovers/` to load that project's
`AGENTS.md` and `.agents/skills/`; a root session intentionally does not
advertise football-only rules or skills.

- Flash Max is the default for roughly 85–90% of work across every discipline.
  Keep it selected as the main model; do not switch the session to Pro.
- Pro is reserved for roughly 10–15% of genuinely complex work. It is not a
  quota and not a discipline label. The main agent invokes `architect`
  automatically when a trigger below is met, gives it a focused brief, then
  resumes implementation and testing after the specialist returns.
- `visual-qa` is selective, not automatic. Invoke it only when automated
  validation cannot settle a rendered visual claim, and do not run it after
  every change. Its scope is rendered wrestler models, animations, textures,
  lighting, arenas and gameplay screenshots.
- Do not use Gemini or any other paid visual model without the owner's explicit
  approval, even if it is included in the OpenCode Go allowance. If Nemotron is
  unavailable, report the limitation and stop; do not silently substitute a paid
  model.
- No separate gameplay subagent is configured by default: `aegis-main` owns
  gameplay, controls, physics, AI, cameras, UI and performance so one agent
  remains accountable. Add another agent only if the owner approves and the
  structure would materially benefit.
- Reuse the existing agents and skills. Do not create a subagent per skill. One
  task has one primary owner; do not fan the same question out to several
  agents.
- If a pinned model is unavailable, stop and report it. Do not silently
  substitute another model or route outside the subscription.
- The main agent owns integration, tests and the final report. Specialists
  return scripts, findings or plans; they do not publish.
- Do not commit or push a batch unless the owner has approved that batch for
  publication.

## Image generation and texture work

- Do not call `experimental_image_generate` or any external paid
  image-generation or editing service automatically. Do not activate an
  image-generation API without the owner's explicit approval. This applies to
  shell, HTTP, browser, plugin and MCP routes as well as the built-in tool.
- The project permission denies the built-in tool. Do not attempt to bypass that
  deny.
- Procedural texture creation, Blender modeling and materials remain with Flash
  Max and `blender-specialist`. Use Blender shader nodes, procedural materials,
  bakes, UV/texture workflows and existing project textures. Do not substitute
  generated images for project-authored or reference-matched assets.
- Visual QA remains free `opencode/nemotron-3.5-super-vl-free`, selective and
  read-only. It reviews existing evidence; it does not generate or edit images.

## Automatic Pro escalation

Escalate to `architect` when:

- two meaningful attempts have failed to resolve a significant problem;
- a difficult architectural decision is required;
- several tightly coupled systems need redesign;
- complex choreography or physics needs deeper analysis;
- a persistent visual-quality defect needs a different approach;
- a critical performance problem needs architectural investigation.

Give the specialist only the decision, constraints, relevant evidence and files,
and the options already considered. Do not send whole project histories or large
logs. It returns a recommendation, risks and a test plan; its task ends and the
main agent continues. Do not escalate merely because a task belongs to a
technical discipline, and do not assume Pro outperforms Flash without task
evidence.

## Discipline routing and validation

| Discipline | Default owner | Core work and validation |
| --- | --- | --- |
| Character modeling and rigging | `blender-specialist` | Proportions, anatomy, faces, bodies, clothing, game-ready topology, deformation, bone weights, IK/FK, scale, rig compatibility and LOD. Reuse working meshes and rigs. Validate topology, proportions, weights and deformation. |
| Texturing and materials | `blender-specialist` | PBR skin, fabric, leather and metal; UVs and texel density; atlases, normal/roughness maps; colour and material response; texture budgets; Godot-compatible materials. Reuse material libraries. Validate missing textures, broken UVs, assignments and memory. |
| Lighting and rendering | `blender-specialist`; `aegis-main` for in-game lighting | Broadcast arena lighting, skin/clothing response, shadows, exposure, contrast, reflections, atmosphere and consistency across camera angles. Prefer Godot Forward+ for in-game claims. Validate configuration and performance settings; use actual renders where available. |
| Wrestling animation | `blender-specialist` | Grapples, throws, strikes, submissions, reversals, locomotion, transitions, two-wrestler synchronization, contact constraints, timing, momentum, root motion, selling and Godot integration. Plan attacker and defender choreography together. Validate contacts, foot sliding, joint limits, continuity and exports. |
| Gameplay and controls | `aegis-main` | Responsive controls, grapple/strike systems, reversals, pins/submissions, match rules, move selection, positioning, camera integration, match flow and state transitions. Test timing, transitions, input handling and failure cases. |
| Physics and collision | `aegis-main` | Wrestler collision and contact, grapple positioning, knockdowns, impacts, ropes/boundaries, tables/ladders/weapons and animation/physics coordination. Prefer stable, predictable behaviour over unnecessary complexity. Validate collisions, contacts and state transitions. |
| Opponent AI | `aegis-main` | Decision-making, offence/defence, positioning, reversals, pacing, difficulty, contextual move selection, ring awareness and variety. Use deterministic simulations and scenario tests where practical. |
| Arenas, crowds, environments and VFX | `blender-specialist` | Arena geometry, ring/ringside assets, crowds, entrances and staging, screens/LED, lighting, atmosphere, pyrotechnics/effects, reuse, instancing and LOD. Prioritise believable broadcast presentation and efficient rendering. Validate scene/instancing and performance cost. |
| Cameras, UI, HUD and presentation | `aegis-main` | Broadcast camera behaviour, dynamic framing, entrances/cutscenes, HUD/match graphics, menus, replays, transitions and readability. Preserve the approved camera and entrance direction. Validate framing, readability, transitions and continuity. |
| Performance and optimization | `aegis-main` | Maintain 60 FPS on the M1/16 GB target; reduce render cost, geometry/material cost, animation playback cost, memory/texture pressure and unnecessary physics/AI work; profile bottlenecks. Only native measurements establish M1 performance. |

The escalation triggers above cover the discipline-specific Pro cases: difficult
rig architecture or persistent deformation, persistent material-system problems,
visual-quality-versus-performance decisions, complex choreography or
synchronization, gameplay-system architecture, coupled physics instability, AI
decision-policy redesign, arena/instancing architecture, camera/presentation
architecture and major optimization trade-offs.

## Progressive quality assurance

Apply this to every discipline. Run the cheapest meaningful check first.

- **Level 1 — automated checks.** Topology, scale, materials, transforms and rig
  checks; UVs, dimensions, file references and memory estimates; joint limits,
  contact points, keyframes and root motion; state transitions, inputs, timing
  and move logic; AI scenario tests and decision consistency; collision and
  stability tests; lighting configuration and performance settings; UI layout
  and scene validation; repeatable benchmarks where execution is available.
  Make these programmatic where possible. Do not invoke AI vision or Pro for
  routine validation.
- **Level 2 — selective visual testing.** Only when a working Blender, Godot or
  remote rendering environment exists. Generate a small number of representative
  images, use low-resolution previews first, and inspect only changed or
  problematic areas. Prefer automated diagnostics over AI visual review; use
  vision selectively and do not resend identical frames or analyse whole videos.
  Do not invoke `visual-qa` automatically after every change; Level 1 checks must
  come first.
- **Level 3 — final quality validation.** Use more complete evidence only for
  major milestones or acceptance-ready work: character turnarounds, deformation
  captures, animation previews, arena lighting captures, gameplay recordings, UI
  captures, Forward+ evidence and native Mac performance tests. Preserve all
  existing Aegis evidence and acceptance requirements.

If testing could not actually run, label the result unverified.

## Android and remote validation

Development runs through OpenCode on Android/Termux. Never assume Blender,
Godot or Mac execution is available. Inspect existing CI, capture tools and
remote execution possibilities first. Playwright is acceptable only where a
working browser-based game or viewer exists; it is not authoritative Forward+
visual evidence. Do not create expensive rendering infrastructure without
permission. Continue productive implementation with static analysis and
applicable automated tests when rendering is unavailable, and record outstanding
visual and native-performance validation for later.

## Token efficiency

- Use Flash Max by default; invoke Pro only for justified complexity.
- Reuse existing agents, skills, rigs, materials and infrastructure.
- Inspect only relevant files; avoid repeated full-project searches.
- Keep specialist context focused; do not send whole histories or large logs.
- Prefer small patches over complete rewrites.
- Avoid unnecessary parallel agent calls.
- Do not repeat tests when relevant inputs have not changed.
- Run automated checks before expensive visual inspection.
- Do not send whole videos to AI by default.
- Do not regenerate complete assets when a local correction suffices.
- Preserve concise checkpoints to avoid repeated context gathering.
- Use project-specific validation rather than generic repeated checks.
- Do not use unapproved paid tools or services.
- Quality improvements should justify their computational and token cost. The
  goal is maximum quality and progress per unit of token usage, not minimum
  token usage at any cost.

## Blender skills and tools

The shared skill guides live in `.claude/skills/`, with Codex-discoverable
directory aliases under `.agents/skills/`. Open the relevant `SKILL.md` before
specialized art work and follow its useful workflow guidance. Keep edits in
the canonical `.claude/skills/` directories; the aliases share those files.
See `.agents/README.md` for discovery scope, invocation and client limits.
There are 38 retained guides; `.claude/skills/BLENDER_SKILLS.md` records their
provenance and the reason some earlier candidates were removed.

Where Blender is installed (for example the owner's Mac), Blender 4.3.2 and
`bpy` are available through the Blender executable
(`blender -b --python <script>`). Android Termux does not provide Blender or
Godot locally, and no Blender MCP tool is connected to this session. Use a
small, repeatable headless Blender script only where a Blender binary or an
already-configured remote executor exists; do not claim to have driven the
Blender UI, an MCP session, or a render that did not run. Keep Godot builds and
tests independent of Blender. Store generated sources/exports with the owning
game and follow its existing naming and asset pipeline.

Read only the guides needed for the task; do not load all 38 by default. This
catalog covers every retained guide in `.claude/skills/` and distinguishes
similarly named guides so the right detail is loaded without duplicating whole
workflows:

| Guide | Use it when |
| --- | --- |
| `blender-director` | Starting a reference-led or multi-discipline asset; analyze the brief, route specialists, set validation gates. Use before detailed specialist work when references or several disciplines are involved. |
| `blender-pro-workflow` | A complete production task spans blockout, camera, lighting, modeling, materials, render/compositing, and delivery; use for end-to-end order and recovery practices. |
| `blender-modeler` | General Blender scene organization, blockouts, non-destructive modifier work, collections, and cleanup. |
| `blender-modeling` | Creating or editing mesh geometry with operators, bmesh, booleans, bevels, arrays, solidify, or subdivision. Use with `blender-modeler` only when both scene workflow and mesh-operation detail matter. |
| `character-artist` | Human or humanoid anatomy, face, clothing, facial expression, and animation-ready character topology. |
| `import-wrestler` | Importing or fixing a wrestler in Aegis only; read first and follow its Aegis-specific rig, assets, and validation rules. Never use for Beechlawn footballers. |
| `realistic-style` | Realistic/photoreal look direction, real-world scale, high-to-low workflows, scan cleanup, and PBR realism. |
| `retopology` | Converting a sculpt/high-poly source into clean, deformable, efficient topology before UVs or rigging. |
| `rigging` | Armatures, bone hierarchy, constraints, IK/FK, weights, facial rigs, drivers, and deformation checks. |
| `hair-groom` | Hair or fur curves, clumps, cards, strand flow, scalp coverage, alpha and real-time groom budgets. |
| `cloth-sim` | Garment pattern/blockout, pinning, simulation, cache/bake, or shape-key delivery for cloth. |
| `blender-animation` | Authoring keyframes, motion curves, drivers, shape keys, constraints, reusable NLA actions, and animation timing in Blender. |
| `animation` | A compact checklist for game-ready idle/locomotion/combat cycles and animation cleanup; pair with `blender-animation` when authoring or editing the motion itself. |
| `environment-artist` | Game-ready terrain, buildings, vegetation, architecture, modular environments, and spatial storytelling. |
| `geometry-nodes` | Reusable procedural node systems, instancing/scatter, or procedural terrain/building/foliage assets. |
| `procedural-modeling` | Procedural or modifier-based generation of rocks, roads, buildings, pipes, vegetation, and repeated forms; pair with `geometry-nodes` for node-graph implementation. |
| `scene-assembly` | Assembling large scenes through linked collections, overrides, reusable sets, and streaming-aware organization. |
| `prop-artist` | Grounded everyday, sports, furniture, and hero props where readable form and use matter more than mechanical complexity. |
| `hard-surface` | Mechanical, industrial, vehicle, weapon, robotic, or sci-fi parts with precise bevel, panel, and Boolean workflows. |
| `genre-action-combat` | Combat-space and prop-language choices for wrestling, fighting, beat-'em-up, and action-game readability; do not apply its combat conventions to football. |
| `blender-materials` | Principled BSDF look development for skin, fabric, metal, glass, wood, and procedural surface response; the detailed Blender material implementation guide. |
| `materials` | A shorter material recipe/checklist for common PBR and stylized surfaces, reuse, and production consistency. Pair with `blender-materials` when node-level detail is needed. |
| `uv-workflow` | Seam placement, unwraps, packing, texel density, UDIMs, or lightmap UV layout. |
| `blender-uv-texturing` | Fitting image textures/atlases/decals to UVs, texture projection, baking, and preparing texture-driven assets for glTF. |
| `texture-workflow` | Production texture/bake sequence: AO, curvature, normal/roughness, decals, atlases, and texture-memory budgets. |
| `blender-cameras` | Camera setup and framing: lens, focus, depth of field, composition, and camera constraints/animation. |
| `camera-cinematography` | Shot language, camera movement, sequencing, and cinematic composition beyond the camera's technical settings. |
| `blender-lighting` | Building and configuring Blender light rigs, HDRIs, color temperature, shadow softness, and light groups. |
| `lighting` | A concise lighting/look checklist for cinematic or game scenes; pair with `blender-lighting` for implementation detail. |
| `blender-rendering` | Selecting/configuring Cycles or Eevee, samples, denoising, color management, render passes, and output. |
| `rendering` | A shorter render setup/optimization checklist; pair with `blender-rendering` when engine settings or output details need depth. |
| `lod-pipeline` | Designing screen-size LOD tiers, naming them, and validating transitions for game meshes. |
| `asset-optimization` | Auditing and optimizing geometry, topology, UVs, materials, collections, and package cost before delivery. |
| `collision-proxy` | Authoring simple game collision meshes, convex hulls, capsules, and engine-compatible collision names. |
| `qa-review` | A formal asset QA gate: naming, visual evidence, checklists, validation findings, and ship/no-ship status. |
| `godot-export` | Exporting Blender assets specifically to Godot with compatible glTF scale, materials, animation clips, and collision setup. Read before Godot-bound delivery. |
| `blender-export` | Choosing and configuring a Blender output format (GLB/glTF, FBX, OBJ, USD, STL) and embedding/unpacking assets. |
| `export-pipeline` | Cross-format delivery concerns such as transforms, pivots, normals, materials, animations, and collision verification; use with the target-specific export guide. |

Project-local workflow guides:

| Guide | Scope |
| --- | --- |
| `games/beechlawn_rovers/.agents/skills/create-player/SKILL.md` | Required starting point for Beechlawn player modeling, kits, animation or retargeting from archived references. It is football-project-only and routes the shared specialists above; do not use it for Aegis wrestlers. |
| `games/beechlawn_rovers/.agents/skills/grill-me/SKILL.md` and `grilling/SKILL.md` | Optional, explicit design-interview workflow for Beechlawn decisions with costly downstream impact. Use only when the user asks to be grilled/stress-tested; never make it a default blocker for routine implementation or Aegis work. |

Project-specific routing takes precedence over generic routing: Beechlawn
footballer work starts with
`games/beechlawn_rovers/.agents/skills/create-player/SKILL.md`, then only the
specialists that task needs. Aegis wrestler import starts with `import-wrestler`.

The `blender-*` guides generally give implementation detail; their shorter
overlapping guides are useful checklists. The guides are not all executable
automation. In particular, adapt any live-session/MCP instructions to the
headless Blender workflow available here. The skill map is shared production
guidance only; project-specific gameplay, art, rig, export, validation, and
performance rules apply only to their owning game. For Aegis visual claims,
validate through its capture/evidence gates. For Beechlawn, follow
`games/beechlawn_rovers/AGENTS.md` and validate in its own Godot project.

## Project boundaries

- Aegis wrestling and Beechlawn Rovers are separate Godot projects. Keep their
  scenes, assets, exports, and build/release workflows separate.
- Football rules, player controls, character sheets and match systems are
  Beechlawn-specific. Never use them to change or
  reinterpret the wrestling game's systems. Wrestling-specific rig, move,
  arena, and evidence rules do not constrain Beechlawn assets or gameplay.
  Both games have their own M1 performance requirements; measure each project
  separately rather than transferring results between them.
- Before changing Aegis gameplay architecture, read
  `gauntlet/anchor/ARCHITECTURE.md`. Use that project's measured references as
  the authority for wrestling-game visuals.
- Beechlawn-specific instructions live under `games/beechlawn_rovers/`; that
  project's staged scope and acceptance criteria are in its `docs/backlog.md`.
