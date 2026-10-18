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
- The default scene is a three-minute keyboard 11v11 Sunday-league prototype,
  with a separate referee and shared human visuals. The old 4v4 scene remains a
  regression fixture. Treat native M1 performance, facial likeness, exact venue
  matching and full football rules as open acceptance gates.
- Follow `docs/backlog.md` and the approved `docs/11v11_implementation.md`.
  The owner authorized scaling to 11v11 before individual face production;
  do not reinstate the obsolete 4v4-only gate.
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

## Opt-in design interview

- The project-local `/grill-me` skill and its `grilling` interview protocol
  are available under `.agents/skills/`. Use them only when the user explicitly
  asks to be grilled, stress-tested, or interviewed about a design. Do not turn
  them into a gate for routine implementation, bug fixes, or continuing an
  already-approved backlog item.
- They are most useful before expensive or foundational choices: the football
  control model, ball/action architecture, AI and formation strategy, the move
  from 4v4 to 11v11, or a large character/animation production pass. For small
  tuning decisions, inspect the project and proceed with a stated assumption.
- Before asking the user, inspect the current code, backlog, and relevant
  archived references; ask only for decisions that depend on their preference.
  This workflow can deliberately pause for multiple design rounds, so invoke it
  only when the user requests that depth. Keep the interview scoped to
  Beechlawn; it does not apply to Aegis wrestling.

## Engineering skill routing

- For a hard bug or performance regression, use
  `.agents/skills/diagnosing-bugs/SKILL.md`. Build a repeatable check for the
  reported symptom, minimize it, then test ranked hypotheses and verify the
  fix against the original case. Surface hypotheses as a progress update and
  keep working without waiting unless a user decision is genuinely blocking.
  If the symptom needs the unavailable Mac, continue with cloud repros and
  code-level checks while keeping Mac validation explicitly open.
- When editing agent instructions or skills, read
  `.agents/skills/writing-for-agents/SKILL.md`; when editing a skill's
  frontmatter or invocation behavior, also read its sibling
  `SKILL-MECHANICS.md`. Keep always-loaded guidance brief, route detailed
  procedures through task-triggered pointers, and keep each rule in one
  authoritative place.
- These engineering guides apply only inside Beechlawn. They do not change
  Aegis wrestling guidance or replace the project-specific Blender, Godot,
  `gda`, `create-player`, or explicit `grill-me` workflows.

## Blender and validation

- Use the shared Blender skills through the root `AGENTS.md` routing table.
  Codex discovers their root `.agents/skills/` aliases when this project is
  the working directory; `.claude/skills/` remains their canonical source.
  Keep football-only skills in this project's own `.agents/skills/` directory.
  For footballer and kit work, use the character/rig/material guides;
  for park scenery, use environment/scene guides; for Godot assets, read
  `godot-export` before exporting. Do not use `import-wrestler` for football
  characters.
- For creating or substantially refining a footballer, read
  `.agents/skills/create-player/SKILL.md` first. It is scoped to Beechlawn and
  routes the shared Blender guides while using the archived player and kit
  references; it does not change Aegis wrestling workflows.
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
- Put a hard process deadline around every headless Godot test, for example
  `timeout --signal=TERM --kill-after=3s 45s godot --headless --path .
  --script res://tests/<test>.gd`. Several `SceneTree` smoke scripts call
  `quit()` only on success; a failed `assert` can leave Godot idling instead of
  returning an exit code. Never start a duplicate test while an earlier one is
  still running. If the deadline expires, capture the final log, terminate the
  process, diagnose the failing assertion, then rerun once.
- Prefer `python3 tools/run_smoke_tests.py [test.gd ...]`: it runs checks
  serially, applies a 45-second per-test deadline, terminates the process group
  on timeout, and prints the captured tail so a failed assertion is diagnosable.
  Do not launch overlapping Godot smoke suites or leave a session running after
  the test's useful output has completed.
- A passing static scene check does not cover dependencies inside imported
  binary scenes such as GLB. Record that scope limitation and use scene
  preflight/runtime checks to validate startup.
