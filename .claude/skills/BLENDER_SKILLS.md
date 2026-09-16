# Vendored Blender skills

Third-party Claude Code skills, copied in on request. Provenance recorded here
for the same reason `game/assets/characters/CREDITS.md` records it for vendored
art: third-party material entering this repo without a source and a licence is a
problem later, not now.

141 were vendored initially; **103 were since deleted** as irrelevant to a
wrestling game, leaving 37 vendored skills plus this project's own
`import-wrestler`. Root `CLAUDE.md` records which survive, which job each is for,
and why the rest went.

| source | vendored | kept | commit | licence |
| --- | --- | --- | --- | --- |
| https://github.com/kevinbadi/blender-skills | 16 | **0** | `b2f0f816d320b56ae86d52597a35284e0e6cc929` | none stated — see below |
| https://github.com/RobLe3/cc-blender-skill | 30 | 9 | `11016c9a5847897491dde935c346571bd7548e3d` | MIT (`LICENSE` in repo root) |
| https://github.com/arjun988/blender-skills | 94 | 28 | `8f778d2405a214b508d4c7d80742be8e43acdd52` | MIT (`LICENSE` in repo root) |

arjun988's also ships a SHARED `references/` directory
(9 files: polycount budgets, asset pipeline, validation checklists and so on)
which is installed as a sibling of the skills rather than inside one, because
its skills link to it as `../references/*.md` (13 of the survivors still do) and
those links break otherwise. It is reference material, not a skill, and has no SKILL.md.

Taken from the repositories' default branches on 2026-09-13. Only the skill
directories were copied — `cc-blender-skill`'s `knowledge/`, `docs/` and `src/`
trees were left behind, and both repos' `.git` was dropped.

## Licence warning on kevinbadi/blender-skills — resolved by deletion

That repository carries **no LICENSE file**, so the default position was that
all rights are reserved and there was no grant to redistribute it here. All 16
of its skills — `image-to-3d`, `multi-image-to-3d`, `blender-toolkit`,
`product-polish`, `threejs-export`, the five `polyhaven-*`, and the six
camera-move skills (`turntable`, `slow-zoom`, `dolly-rotate`, `crane-shot`,
`dynamic-full-loop`, `perfect-loop`) — have been deleted. They were product-shot
automation with no use in this project, so nothing was traded away to close the
question. What remains is MIT on both counts.

They are still in git history, which is where they should stay: restoring one
re-opens the licence question, and none of them is worth that.

## None of these run in this container

All three sets drive a **running Blender application through the BlenderMCP addon on
port 9876**. This container has no `blender` binary and nothing listening on
that port — it has `bpy` 4.2.0, which is Blender as a Python *library*, and is
what `tools/assets/*.py` already uses. The two are not interchangeable: the
skills issue commands to a live Blender session, `bpy` runs headless in-process.

To make the survivors live, a machine needs Blender >= 4.0 with the BlenderMCP
addon running and listening on 9876, and that MCP server configured in Claude
Code. Nothing else: the skills that wanted OpenCV, a `MESHY_API_KEY` or `ffmpeg`
were all in the deleted set, so no survivor needs a credential or a binary
beyond Blender itself.

## What was checked before installing

A skill is not data — it is instructions that steer an agent — so all of them
were read before being copied rather than after:

- every one has valid frontmatter with `name` and `description` (141 of 141 at
  the time; re-checked at 38 of 38 after the deletions),
  so none will fail silently at load
- no credential access beyond the documented `MESHY_API_KEY`; nothing touching
  `~/.ssh`, `~/.aws`, or arbitrary env
- no destructive shell: no `rm -rf`, no `curl … | sh`, no `sudo`
- no git writes at all
- no instruction to skip review, tests, or user confirmation. The three
  "skip confirmation" matches are about Blender's own Rigify bone-map dialog,
  and `reference-to-3d`'s "do not ask vaguely" is an instruction to ask
  *better*, not less
- network references are Blender docs, PolyHaven, tutorial sites, and one real
  endpoint: `api.meshy.ai`

Nothing was excluded. No name collided with another skill or with
`import-wrestler`. arjun988's set was audited the same way and came back clean
on every count -- the single "secret" match is the phrase "secret wall" in a
metroidvania level-design note.

## What is actually relevant to this project

Routing — which skill to read for which job, and the ~100 to leave alone — is
in the repo's root `CLAUDE.md`. The short version: most of these are for product
renders and stylised art, not a wrestling game. The ones worth reading when
animation work resumes are arjun988's `animation`, `rigging`, `retopology`,
`export-pipeline` and especially `godot-export`, plus RobLe3's
`blender-animation` and `blender-export`. That set covers the gap this project
actually has: authoring a performance clip in Blender and getting it onto the
base rig as glTF.

One correction to "none of these run in this container" above. None can be
*invoked* — they are written for a live Blender over BlenderMCP. But nine of RobLe3's
`blender-*` skills (`-animation`, `-cameras`, `-export`, `-lighting`,
`-materials`, `-modeling`, `-pro-workflow`, `-rendering`, `-uv-texturing`) carry
their bodies as plain `bpy` Python, and that code runs unchanged in a headless
script here; only their `allowed-tools:` frontmatter names MCP. The rest of
RobLe3's 30 are the OpenCV-dependent reference-matching family, which does not
run. arjun988's are checklists with no code, so they transfer
as numbers. kevinbadi's genuinely do not transfer: they automate product shots
and write to paths this container does not have.
