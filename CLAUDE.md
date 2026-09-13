# Working in aegis

An original 3D wrestling vertical slice (Godot 4.6, Forward+, Jolt). Read
`gauntlet/anchor/ARCHITECTURE.md` before changing anything — it is the contract.
`README.md` is the running work log; `.claude/skills/BLENDER_SKILLS.md` records
where the vendored Blender skills came from and under what licence.

## Blender in this repo

**There is no Blender application here, and nothing listens on port 9876.**
What exists is `bpy` 4.2.0 — Blender as an importable Python library. The
vendored Blender skills are all written for a live Blender driven over
BlenderMCP, so *none of them can be invoked as a tool here*. (`import-wrestler`
is the exception: it is this project's own skill, written against this
container, and it runs.) The vendored ones are read as craft reference, and the
work is done the way this repo already does it:

- an idempotent script committed under `game/tools/blender/` (rig and animation
  work, e.g. `wrestling_clips.py`) or `tools/blender/` (environment, e.g.
  `arena_bowl.py`)
- run headless: `python3 game/tools/blender/wrestling_clips.py`
- output is a `.glb` committed to `game/assets/`, and it must be
  **deterministic** — the same input table produces a byte-identical file, which
  is what lets it be diffed and reviewed like the `.tres` bakes
- the game builds, runs and tests without Blender. Keep it that way.

Two practical consequences when reading a skill:

- Nine skills are directly usable: `blender-animation`, `-cameras`, `-export`,
  `-lighting`, `-materials`, `-modeling`, `-pro-workflow`, `-rendering` and
  `-uv-texturing` (RobLe3). Their bodies are plain `bpy` Python that runs
  unchanged in a headless script — only their `allowed-tools:` frontmatter names
  MCP, so ignore that and paste the code into a tool script. Note the prefix is
  not a reliable guide to this: `blender-director` and `blender-modeler` are
  arjun988 checklists with no runnable code, despite the name.
- The short checklist skills (arjun988 — `animation`, `rigging`, `godot-export`,
  and so on) carry no runnable code but do carry the numbers: polycount budgets,
  cycle frame counts, naming, validation gates. They share
  `.claude/skills/references/` (budgets, pipeline, checklists) — read that
  directory alongside them.

## Which skill for which job

Work down this table; the first row that matches the task is the one to read.

| The task | Read | Notes |
| --- | --- | --- |
| A new wrestler model dropped into the project, or an imported one renders wrong (magenta, bald, backwards, T-posed, floating beard, head-down animation) | **`import-wrestler`** | Project-specific and measured against this rig. It **overrides** every generic skill below — do not start from `character-artist` or `rigging` for an import. |
| Authoring a wrestling clip (bump, lock-up, cover, celebration) on the base rig | `blender-animation` (bpy keyframes, F-curves, easing) + `animation` (blocking → breakdown → splining, cycle frame counts) | This is the project's real gap: the 42 CC0 actions on `wrestler_base.glb` contain no wrestling. Extend `game/tools/blender/wrestling_clips.py`; rotations are Euler degrees over the rest pose, matching `paired_recipes.gd`. |
| Getting a clip or mesh out to the game | `godot-export` first (GLB, +Y up, Godot-friendly materials), then `blender-export` for the actual `bpy.ops.export_scene.gltf` arguments | Verify the track paths come back as `Armature/Skeleton3D:<bone>` — that is the shape `AnimationTree` consumes. |
| Skeletons, weights, IK/FK, constraints — anything before animation on a deforming mesh | `rigging` | See also `tools/assets/rig_static_wrestler.py`, which mounts a static mesh on the base rig precisely to avoid retargeting. |
| Ring, apron, entrance set, arena bowl, seating | `environment-artist`, `scene-assembly`, `procedural-modeling` / `geometry-nodes` for swept rows and arcs | The bowl's shape is fixed by `gauntlet/refs/arena.md` (obround, hockey-arena plan). Reference beats the skill. |
| Props: turnbuckles, steps, barricades, commentary desk | `prop-artist`; `hard-surface` only for genuinely mechanical parts | |
| Materials — canvas, ropes, skin, gear, chrome | `blender-materials` (Principled BSDF values, Sheen, subsurface) with `materials` as the shorter checklist | Nothing here overrides `gauntlet/refs/`-measured values. |
| UVs, texture atlases, baking | `uv-workflow`, `texture-workflow`, `blender-uv-texturing` | |
| Arena and ring lighting | `blender-lighting` (bpy setups, colour temperature) with `lighting` as the checklist | The shipped look is measured in `gauntlet/refs/` — calibrate to that, not to the skill's studio defaults. |
| Polycount, topology, material count, naming before committing an asset | `asset-optimization`, then `qa-review` as the ship/no-ship gate | Budgets live in `.claude/skills/references/polycount-budgets.md`. |
| Cleaning a dense or scanned mesh so it can be rigged | `retopology` | |
| Physics collision shapes | `collision-proxy` | Godot/Jolt shapes are authored in the scene, not imported — read this for the hull-simplification thinking only. |
| LODs | `lod-pipeline` | Not yet needed; the slice ships one LOD. |
| Hair cards, beards | `hair-groom` | Read `import-wrestler`'s beard/hair section first — the last defect there was scale, not grooming. |
| Gear and cloth that needs to drape | `cloth-sim` | Bake to shape keys; no runtime sim. |
| Framing a capture or probe shot | `blender-cameras` / `camera-cinematography` | Only for Blender-side renders. In-game framing is `game/core/camera/` and `gauntlet/refs/camera.md`. |
| Sequencing a multi-phase asset job, or unsure where to start | `blender-pro-workflow`, then `blender-director` | Useful for ordering (block-out → camera → light → forms → materials → detail → export). Both assume a live Blender; take the order, not the tooling. |

### Where two skills have the same name

The two surviving vendored sets overlap. Default to the deeper `blender-*` version for
anything you will actually write code for, and the short one for the numbers:

`blender-animation` > `animation` · `blender-materials` > `materials` ·
`blender-lighting` > `lighting` · `blender-rendering` > `rendering` ·
`blender-modeling` > `blender-modeler` · `blender-export` > `export-pipeline`,
except `godot-export`, which wins on target-format questions.

### What was deleted, and why it is not coming back

141 skills were vendored; 103 were deleted and **38 remain** — every one of them
in the table above. If you find yourself wanting one of the deleted names, the
reasoning was:

- **all 16 kevinbadi skills** (`image-to-3d`, `multi-image-to-3d`,
  `blender-toolkit`, `product-polish`, `threejs-export`, the five `polyhaven-*`,
  the six camera-move skills). That repository ships **no licence**, so there was
  no grant to redistribute them here — which is reason enough on its own. They
  are also product-shot automation that writes ProRes to `~/Desktop`, and the two
  Meshy ones produce meshes with no provenance, which is exactly what
  `game/assets/characters/CREDITS.md` exists to prevent.
- **54 art-direction skills** — every `*-style`, `*-mood`, `*-worlds`, `*-horror`
  and most `genre-*`. The slice's look is set by `gauntlet/refs/ring.md`,
  `stage.md` and `arena.md`, which are measurements of real venues; a skill that
  argues for PS1 fog or cel shading can only pull away from that. Two were kept:
  `realistic-style` for the vocabulary and `genre-action-combat` for readable
  combat space. Neither outranks the refs.
- **the 16-skill reference-matching family** (`reference-to-3d`,
  `multiview-fit-loop`, `wireframe-to-3d`, `contour-to-mesh` and the rest). They
  need OpenCV, which is not installed, and they exist for 1:1 brand and mascot
  reconstruction — the opposite of this project, where footage is a *measurement*
  reference and the assets stay original.
- **`unity-export` and `unreal-export`.** This ships to Godot.
- **15 with no current use**: `vehicle-artist`, `vegetation-artist`, `archviz`,
  `creature-artist`, `sculpting`, `vfx-fx`, `physics-sim`, `compositing`,
  `set-dressing`, `lookdev`, `orbital-hud-motion`, `blender-skill-harmonizer`,
  `text-to-blender`, `quality-refinement-autoloop`, `animation-quality-gate`.
  Sculpting is gestural and cannot be driven headless at all; the last two
  duplicate `tools/capture/evidence_gate.py`, which is the gate that actually
  runs.

`.claude/skills/references/` is not a skill and stays — 13 of the survivors link
into it as `../references/*.md`. Everything is recoverable from git history if a
call here proves wrong.

### The rule these all sit under

A skill describes what a live Blender session would do. Only a rendered frame
and a passing gate say what this build does. Close every appearance claim on
pixels through `tools/capture/`, and every asset claim on
`tools/capture/evidence_gate.py` — not on a skill's checklist.
