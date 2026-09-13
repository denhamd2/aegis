# Vendored Blender skills

46 third-party Claude Code skills, copied in on request. Provenance recorded
here for the same reason `game/assets/characters/CREDITS.md` records it for
vendored art: third-party material entering this repo without a source and a
licence is a problem later, not now.

| source | skills | commit | licence |
| --- | --- | --- | --- |
| https://github.com/kevinbadi/blender-skills | 16 | `b2f0f816d320b56ae86d52597a35284e0e6cc929` | **none stated — see below** |
| https://github.com/RobLe3/cc-blender-skill | 30 | `11016c9a5847897491dde935c346571bd7548e3d` | MIT (`LICENSE` in repo root) |
| https://github.com/arjun988/blender-skills | 94 | `8f778d2405a214b508d4c7d80742be8e43acdd52` | MIT (`LICENSE` in repo root) |

141 skills in total. arjun988's also ships a SHARED `references/` directory
(9 files: polycount budgets, asset pipeline, validation checklists and so on)
which is installed as a sibling of the skills rather than inside one, because
48 of its skills link to it as `../references/*.md` and those links break
otherwise. It is reference material, not a skill, and has no SKILL.md.

Taken from the repositories' default branches on 2026-09-13. Only the skill
directories were copied — `cc-blender-skill`'s `knowledge/`, `docs/` and `src/`
trees were left behind, and both repos' `.git` was dropped.

## Licence warning on kevinbadi/blender-skills

That repository carries **no LICENSE file**, so the default position is that
all rights are reserved and there is no grant to redistribute it. It is
vendored here because it was asked for; if this repo is ever published or
shipped, that is worth settling with the author first. The 16 affected skills
are the `image-to-3d`, `multi-image-to-3d`, `blender-toolkit`, `product-polish`,
`threejs-export`, the five `polyhaven-*`, and the six camera-move skills
(`turntable`, `slow-zoom`, `dolly-rotate`, `crane-shot`, `dynamic-full-loop`,
`perfect-loop`).

## None of these run in this container

Both sets drive a **running Blender application through the BlenderMCP addon on
port 9876**. This container has no `blender` binary and nothing listening on
that port — it has `bpy` 4.2.0, which is Blender as a Python *library*, and is
what `tools/assets/*.py` already uses. The two are not interchangeable: the
skills issue commands to a live Blender session, `bpy` runs headless in-process.

To make them live, a machine needs:

- Blender with the BlenderMCP addon running and listening on 9876
  (`cc-blender-skill` wants >= 4.0; `blender-skills` wants 5.x)
- that MCP server configured in Claude Code
- `python3 -m pip install opencv-python numpy scipy Pillow` for
  `cc-blender-skill`'s image-analysis skills
- a Meshy API key in `MESHY_API_KEY` for `image-to-3d` and `multi-image-to-3d`
  only — **no key is stored in this repo**
- `ffmpeg` for the camera-move skills, which write ProRes video to `~/Desktop`
  (a path that does not exist here)

## What was checked before installing

A skill is not data — it is instructions that steer an agent — so all 46 were
read before being copied rather than after:

- every one has valid frontmatter with `name` and `description` (141 of 141),
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
