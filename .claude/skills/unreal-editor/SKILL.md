---
name: unreal-editor
description: Drive the Unreal 5.9 editor (the aegis port at ~/Documents/Unreal Projects/MyProject2) and the live Blender 5.3 through their MCP servers — running editor Python, building, playing in PIE, capturing frames and video, authoring Niagara/PCG/materials, and scripting Blender. Use for ANY Unreal port task (porting a Godot system, cameras, crowd, lighting, pyro, wrestlers, match types, weapons) and any Blender modelling or animation work, before reaching for window screenshots or hand-editing assets.
---

# Unreal editor and Blender, through their MCPs

The Unreal port is the future engine for aegis (full parity with Godot is the
goal). Both editors run on this Mac with MCP servers; the clients are committed
in the Unreal repo's `Tools/MCP/`. Set `T="$HOME/Documents/Unreal Projects/MyProject2/Tools/MCP"`.
Run them with the sandbox disabled (they open local sockets).

## Unreal: the bridge

| Command | Does |
|---|---|
| `python3 "$T/ue.py" py file.py` | Runs Python in the editor. Top-level `await` works; the last expression is returned as `returnValue`. |
| `python3 "$T/ue.py" call <Toolset.Tool> '<json>'` | Calls any toolset tool. |
| `python3 "$T/ue.py" call list_toolsets '{}'` / `describe_tools '{"tool_names":[...]}'` | Discovery: always read a tool's schema before first use. |
| `python3 "$T/shot.py" out.png [maxRes] [--editor]` | Saves the PIE frame as drawn, at that instant. **The only way to look at the game.** Then Read the PNG. `--editor` grabs the editor viewport instead (for checking placement with PIE stopped; aim it with `EditorAppToolset.SetCameraTransform`). PIL is not installed: Read the frames one by one rather than tiling them. |
| `bash "$T/build.sh"` | Full C++ build: quits the editor, builds (log `/tmp/aegis_build.log`), relaunches. Needed for **every** C++ change, .cpp included: Live Coding is not available in this Mac build. |

After an editor relaunch: `rm -f "$T/ue_sid"`, then loop `ue.py py probes/dirty.py`
until it returns a `returnValue`.

### Toolsets worth knowing (≈120 exist)

- **SceneCaptureToolset**: `CaptureGameViewport` (what `shot.py` wraps), `RecordViewport` / `StartViewportRecording` (MP4, for checking animation and timing), `Capture` offscreen diagnostic modes (lighting-only, normals, overdraw). Read the engine skill `SceneCaptureDiagnosticsSkill` (via `ToolsetRegistry.AgentSkillToolset.GetSkills`) before lighting or material diagnosis.
- **LiveCodingToolset**: present, but `IsLiveCodingReady` is false in this Mac build configuration. Do not wait on it; use `build.sh`.
- **EditorToolset.EditorAppToolset**: StartPIE / StopPIE / IsPIERunning, CaptureAssetImage (thumbnail any mesh or material), Set/GetCameraTransform, FocusOnActors.
- **NiagaraToolsets.\***: create systems from templates, add emitters/modules/renderers, set stack inputs, read compile state and stack issues. Pyro, sparks, confetti, smoke.
- **PCGToolset** (+ engine PCG skills): graphs for scattering instances (crowd seats, chairs).
- **EditorToolset.MaterialToolset / MaterialInstanceToolset / TextureGraphToolset**: build and inspect materials; `GetStatistics` for shader cost.
- **MetaSoundToolset**, **animation_toolset ControlRigTools**, **SequencerScripting.\***: audio, rigs, sequences.
- **PerfToolset.GpuProfilerToolset / StatsToolset**: per-pass GPU cost. Check after adding crowds, lights or particles: `PerfToolset.GpuProfilerToolset.TriggerGPUProfile '{"minInclusiveMs":1.0}'`, `PerfToolset.StatsToolset.GetFrameTimings '{}'`. With the editor in the background frames are throttled to ~333 ms and the broadcast camera keeps cutting, so A/B a change over several samples, not one.
- **ConsoleToolset.LogsToolset**: read the output log (build and runtime errors).
- **FabToolset**: search Fab. Installing anything needs the owner's explicit OK, and its licence goes in CREDITS.

### Editor Python pitfalls

- `unreal.Rotator(a, b, c)` positional order is **(roll, pitch, yaw)**. Always pass keywords: `unreal.Rotator(roll=0, pitch=0, yaw=y)`.
- `set_editor_property` runs PostEditChange, which reruns an actor's construction script; there is no `rerun_construction_scripts` in Python. Properties a script sets must be `EditAnywhere`.
- Interchange drops a glTF armature node's own transform (Rocketbox: scale 0.01 and a 90° X turn): apply it in Blender before export or the mesh comes in 100× large and head-down.
- Instanced meshes: never `MarkRenderStateDirty` per frame (2 s frames at 7,000 instances); `SetCustomData` with dirty false is a cheap delta update. Keep crowds out of Lumen, distance fields and ray tracing.

### Probes (`$T/probes/`), all run with `ue.py py`

| Probe | Use |
|---|---|
| `ldring.py` | Load the RingTest map |
| `repie.py` / `endpie.py` | Restart / end PIE |
| `ffwd.py` | Prepend `TARGET="<beat>"`, `DIL=8.0`, `AFTER=0.0`, `END=1.0`: time-dilates to an entrance beat. `END=0.0001` freezes there for `shot.py`; `thaw.py` restores. Overshoots beats shorter than ~2 s at DIL 8: go to the beat before at DIL 8, then the target at DIL 1. |
| `st.py` | Prepend `WAIT=1.0`: beat, commentary voice, queue, name card, lines said, camera shot |
| `watch.py` | Logs beat and voice changes through an entrance |
| `pos2.py`, `vt.py` | Wrestler and camera positions, live view target |
| `det600t.py` | **Determinism gate**: three same-seed runs must give identical hashes (baseline 300 → `8a241b7f…`, 600 → `7104cbb9…`). Run after any change that could touch the sim. |

## Blender: the bridge

Blender 5.3 (`/Applications/Blender.app/Contents/MacOS/Blender`) runs with the
`blender_mcp` add-on on `localhost:9876`.

- `python3 "$T/bl.py" run file.py`: executes `bpy` in the live Blender and returns stdout. Use it to iterate on a model, rig or clip and look at it.
- `python3 "$T/bl.py" cmd get_viewport_screenshot '{"max_size":1200,"filepath":"/abs/out.png"}'`, then Read the PNG. Also available: `get_scene_info`, `get_object_info`.
- Poly Haven (`search_polyhaven_assets`, `download_polyhaven_asset`) is CC0: fine for textures and HDRIs, credited.
- **Never** use the add-on's Hyper3D, Meshy, Tripo or Hunyuan generators: no provenance. Sketchfab models carry per-model licences, so they need the owner's OK.
- What gets committed is still an idempotent headless script (`Blender -b --python …`) producing a deterministic output, and every animation is 60 fps (see CLAUDE.md). Use the live session to iterate, then bake the result into the script.
- The Blender Lab MCP extension is installed but off. It shares port 9876, so only one of the two can run at a time.

## Port conventions (Unreal repo)

- Coordinates: UE = ring centre `(5694.8, 14654.5, 0)` + `(gx, gz, gy) × 100` from Godot metres (Y up → Z up). Mat Z ≈ 0, floor Z = −110.
- Unity build with `-Wshadow -Werror`: names in anonymous namespaces collide across .cpp files. Prefix them per file.
- Presentation systems (cameras, broadcast, crowd, lighting, pyro) read the sim and never write to it. The determinism gate must still pass.
- Commits: `git -c user.name="$(git -C ~/code/aegis config user.name)" -c user.email="$(git -C ~/code/aegis config user.email)" commit …`. The repo has no remote, so never push.
- Godot sources to port from live in `~/code/aegis/game/core/` and `~/code/aegis/tools/blender/`. Seat and placement data can be exported from those with Blender headless (see `Tools/Crowd/export_bowl_seats.py`).

## The rule under all of this

Close every visual claim on a `shot.py` frame (or an MP4 from `RecordViewport`),
and every sim claim on `det600t.py`. Not on a probe's numbers alone, and not
on a window screenshot.
