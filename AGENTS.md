# Agent guidance

## Blender skills and tools

The shared skill guides live in `.claude/skills/`, with Codex-discoverable
directory aliases under `.agents/skills/`. Open the relevant `SKILL.md` before
specialized art work and follow its useful workflow guidance. Keep edits in
the canonical `.claude/skills/` directories; the aliases share those files.
See `.agents/README.md` for discovery scope, invocation and client limits.
There are 38 retained guides; `.claude/skills/BLENDER_SKILLS.md` records their
provenance and the reason some earlier candidates were removed.

In this environment, Blender 4.3.2 and `bpy` are available through the Blender
executable (`blender -b --python <script>`). No Blender MCP tool is connected to
this Codex session. Use a small, repeatable headless Blender script for direct
inspection or edits; do not claim to have driven the Blender UI or an MCP
session. Keep Godot builds and tests independent of Blender. Store generated
sources/exports with the owning game and follow its existing naming and asset
pipeline.

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
- Football rules, player controls, character sheets, match systems, and the M1
  performance target are Beechlawn-specific. Never use them to change or
  reinterpret the wrestling game's systems. Wrestling-specific rig, move,
  arena, and evidence rules do not constrain Beechlawn assets or gameplay.
- Before changing Aegis gameplay architecture, read
  `gauntlet/anchor/ARCHITECTURE.md`. Use that project's measured references as
  the authority for wrestling-game visuals.
- Beechlawn-specific instructions live under `games/beechlawn_rovers/`; that
  project's staged scope and acceptance criteria are in its `docs/backlog.md`.
