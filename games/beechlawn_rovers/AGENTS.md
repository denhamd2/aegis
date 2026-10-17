# Beechlawn Rovers agent guidance

These instructions apply only inside `games/beechlawn_rovers/`. This is a
separate football game and Godot project. Do not apply its gameplay rules,
controls, player data, assets, or performance assumptions to Aegis wrestling.
Likewise, Aegis-specific ring, paired-move, wrestler-rig, arena, and combat
requirements do not govern this project.

## Scope and project state

- Open and run `games/beechlawn_rovers/project.godot` as its own Godot 4.6
  project. Keep code, scenes, imported assets, and exports under this project
  unless a genuinely shared Blender utility belongs in `tools/blender/`.
- The intended setting is a Sunday-league match at a local park. The current
  build has an early 4v4 blockout and player switching; do not claim passing AI,
  goalkeeper behavior, a complete match, or 11v11 systems until implemented
  and verified.
- Follow `docs/backlog.md` for the planned order and acceptance checks. The
  first team match is a 4v4 slice: three outfield players and a goalkeeper per
  side. Apply the supplied Beechlawn and Bordeaux character sheets only here.
- Keep gameplay authoritative in Godot's fixed physics loop; animation presents
  actions and must not independently drive the ball. Prefer simple collision
  shapes and measured CPU/GPU work.
- When finishing Beechlawn work, proactively identify the next highest-priority
  backlog item, its dependencies or blockers, and a concrete recommended next
  action. In every next-step description, orient the user with its backlog ID
  and ordinal position among the primary backlog items (for example, BR-008,
  item 8 of 25), state whether it is in progress or complete, and name its
  dependency or next acceptance check. Keep the backlog order visible; when
  hardware validation is blocked, continue with equivalent cloud checks where
  possible and clearly leave hardware-only acceptance pending.

## Blender and validation

- Use the shared `.claude/skills/` guides through the root `AGENTS.md` routing
  table. For footballer and kit work, use the character/rig/material guides;
  for park scenery, use environment/scene guides; for Godot assets, read
  `godot-export` before exporting. Do not use `import-wrestler` for football
  characters.
- Before any backlog item that changes visual assets, animation, camera, or
  lighting, consult `docs/art_reference_implementation_plan.md` and the
  relevant entries in `references/README.md`; retrieve the archived originals
  from `references/source_uploads/` and Google captures from
  `references/google_captures/`. The archive is the durable source of truth;
  do not rely on chat history or silently substitute generic assets. Preserve
  the originals and store derivatives with the asset work. For reference-led
  work, start with `blender-director` and the reference-image workflow, then
  read only the specialist guides for the actual task. Record a short
  reference-to-asset gap analysis and validate with a matching Blender render
  plus the relevant in-game camera/test.
- Blender 4.3.2 is available headlessly; no Blender MCP tool is connected.
  Keep Blender source scripts repeatable and keep the game build runnable
  without Blender.
- Use Blender skills as the relevant repo-local guides, not as a claim of
  callable MCP access. Use headless `bpy` for direct inspection/editing and
  `gda`/Godot checks for engine integration; report the actual tools used.
- The target is a stable 60 fps at 1080p on Apple M1 Pro with 16 GB. Treat this
  as a measured goal, not an established result. Validate with Godot gameplay
  and profiling on the target Mac before reporting performance success.

## Godot automation

- The project-scoped `gda` Agent Skill is installed at
  `.agents/skills/gda/SKILL.md`; read it before using the `gda` CLI for project
  validation or live runtime inspection.
- Use headless scene/script checks directly against this project. `gda daemon
  start` installs a harness and edits Godot project settings, so run live tests
  in a disposable project copy unless changes to the actual project are
  intentional; inspect and clean up the harness afterward.
- A passing static scene check does not cover dependencies inside imported
  binary scenes such as GLB. Record that scope limitation and use scene
  preflight/runtime checks to validate startup.
