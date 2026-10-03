# Handoff: AAA Roman Reigns vs Cody Rhodes, continuing from Stage 1

You are the lead developer continuing a staged improvement project on **aegis**
(`github.com/denhamd2/aegis`): an original 3D wrestling game in Godot 4.6.3
(Forward+, Jolt, GDScript) with Blender-as-a-library (`bpy` 4.2) asset scripts.
The owner, David, is a non-technical product manager. Keep updates short and
plain, and show results as rendered frames rather than descriptions.

## 0. Read first, in this order

1. `CLAUDE.md`: repo rules. There is no Blender app. Assets are built by
   idempotent, deterministic `bpy` scripts under `tools/blender/` and
   `game/tools/blender/` that output committed `.glb` files. The game must
   build and test without Blender.
2. `gauntlet/anchor/ARCHITECTURE.md`: **the contract**. 60 Hz fixed tick,
   seeded RNG only (never bare `randf()`), and `ReplaySystem` input. The FSM
   is authoritative. GrappleRig owns paired moves. MoveDef `.tres` files are
   the tuning surface. Cosmetic physics never feeds gameplay. Same seed must
   give the same `compute_end_state_hash()`.
3. `gauntlet/anchor/MATCH_FLOW.md`. Note that its "Reversals deliberately
   absent" line is stale: reversals exist (strike parry).
4. **`gauntlet/refs/aaa_master_plan.md`**: the master plan, with every
   measured finding from the Phase 0 audits. This prompt adds status and
   detail to it; it does not replace it.
5. `gauntlet/refs/owner/`: the owner's visual ground truth (AEW arena still,
   Roman's Ula Fala photo) and the Cody entrance video link.
6. `README.md` is an ~8.7k-line work log. **Grep it; do not read it whole.**
   Append a section per stage, in the same style as the last few entries.

## 1. Environment setup (a fresh container has none of this)

- **Godot:** download
  `https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_linux.x86_64.zip`,
  unzip, and use the binary as `godot`. Then
  `godot --headless --path game --import`, which takes a few minutes.
- **gdUnit4:** CI clones v6.2.1 into `game/addons/gdUnit4` (see
  `.github/workflows/ci.yml`). Do the same if it is missing. Run the suite
  exactly as CI does; the `--ignoreHeadlessMode` flag is required, or it exits
  103:
  `godot --headless --path game -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests -c --ignoreHeadlessMode`
  The baseline is **625 test cases, 0 failures** (80 files).
- **Rendering frames:**
  `xvfb-run -a godot --path game --rendering-driver vulkan --resolution 1600x900 tools/probe/<probe>.tscn -- --out <path>`
  Useful probes in `game/tools/probe/`:
  - `stage_wide_shot` (stage from behind the ring), `arena_shot` (the
    hard-cam match view), `compat_shot` (the web renderer)
  - `entrance_shots` (`--sparse`, `--until`, `--faceoff`), `fala_shot`,
    `coat_shot`, `corner_shot`
  - `audio_log` (a sound-versus-clock log; `--entrances`)
  - `ladder_probe` (AI-vs-AI match stats; **it has a bug, fixed in Stage 6**)
  - `pin_probe`, `reversal_tally`, `moveset_tally`
- `python3 -c "import bpy"` works (4.2). `ffmpeg` and `xvfb-run` are installed.
- **Speed:** headless match simulation runs at about 20 ticks/s, so a
  10-minute match takes about 30 minutes of wall time. Run long checks in the
  background.

## 2. Owner decisions already made (do not re-ask)

- **Deploy:** after each stage is tested, push to the working branch, then
  fast-forward `main` to it and push `main`. `.github/workflows/pages.yml`
  deploys the Web build from `main` only; Android builds from `main` too.
  Then check the Actions run succeeded and load the live Pages site
  (`https://denhamd2.github.io/aegis/` if Pages is configured; confirm via
  the run's deploy step). Do not start the next stage until the live deploy
  is verified.
- **Match target:** an AI-vs-AI match of **8–12 minutes**, with **2–4
  near-falls** and at least one kickout from a finisher. Roman is the
  **heel**; Cody is the **babyface**.
- **The arena bowl and overhead rig may change** as a consequence of
  widening the stage. The owner approved this explicitly.
- **Token use:** delegate research, audits and routine implementation to
  cheaper subagents (Sonnet/Haiku). Keep the main session for orchestration,
  integration, hard debugging and final QA. Never let two agents edit the same
  file, scene or asset at once. Parallel agents each get their own git
  worktree, and their branches are merged by the orchestrator.
- **Quality bar:** every visual claim is closed on a rendered Vulkan frame
  compared with `gauntlet/refs/owner/`. Every asset rebuild must be
  byte-deterministic (build twice, same sha256). Each stage gets its own
  commit or commits with clear messages. Never make one giant commit.

## 3. Where the project is now

### Done and on the working branch (`ccr-5f96c954-z0l7gs`, also pushed to `main`)
- **Phase 0:** `gauntlet/refs/aaa_master_plan.md` (commit `3fb9357`).
- **Stage 1, ring** (commit `33ca981`, merged in `fe59c1e`):
  - All 12 pale post collars are removed (`tools/blender/ring.py`
    `build_turnbuckles()`; the `POST_COLLAR_*` constants are deleted from
    `game/core/ring/ring_builder.gd`).
  - `M_TurnbuckleHardware` is dark gunmetal: albedo 0.10, roughness 0.4,
    metallic 0.8.
  - `ring.glb` is rebuilt deterministically.
  - **Verified as already done earlier:** `TURNBUCKLE_BODY_LENGTH` 0.12
    (longer connectors), `ROPE_END` 2.80 (ropes in), pads 2.90, posts at
    3.17. 625/625 tests pass.
- The owner's references are committed to `gauntlet/refs/owner/`.
- **Title music** is committed as `game/assets/audio/music/title_theme.ogg`
  (3:29, Vorbis q6), credited in `game/assets/audio/CREDITS.md`, and **not
  wired in yet**.

### Stage 1 items that were in progress when this handoff was written
Two subagents were working in local worktrees in the previous session. Their
unfinished state was snapshotted to GitHub as two branches, each a single
commit on top of `5edc236`:

- **`origin/wip/stage1-stage-set`**: the stage, desk and barricade work.
- **`origin/wip/stage1-ula-fala`**: the Ula Fala rebuild.

**First run `git log --oneline origin/ccr-5f96c954-z0l7gs -15`.** If you see
finished "Stage …" or "Ula Fala …" commits there, they landed: verify them
and move on.

Otherwise, start from the WIP branches. These are untested snapshots taken
mid-iteration:
1. Check each one out into its own worktree.
2. Re-import, run the suite and render frames.
3. Finish against the notes below.
4. Merge into the working branch.

The WIP branches can be deleted once the work is merged.

**(a) Stage set, announce table and barricade LEDs.** Look for a "Stage …"
commit touching `tools/blender/entrance_set.py`.
- Approach the agent took, and the owner approved:
  - `STAGE_HALF_WIDTH` 6.0 → **8.0** (the deck is 16 m).
  - `PORTAL_OFFSET_X` 3.3 → **5.0**.
  - New `STAGE_FLARE_LENGTH` 4.5: the 3.6 m ramp flares into the deck.
  - `arena_bowl.glb` (the seat cut-out `stage_gap()` in
    `tools/blender/arena_bowl.py` reads `STAGE_HALF_WIDTH`) and
    `overhead_rig.glb` (accent-boom uprights in `overhead_rig.py`) are
    rebuilt to match.
- Also in that work:
  - A truss frame behind the video wall and black drape.
  - Perforated side panels (`STAGE_SIDE_PANEL`, level 0.55).
  - A new `stage_centre_screen.png`.
  - Tests `test_stage_set.gd`, `test_stage_lighting.gd` and
    `test_ringside_desk.gd` updated.
- **Still open at handoff,** from a frame review of
  `stage_wide_shot` against the owner still:
  - The truss and drape were not visible from the ring view; the area
    around the screen read as flat black.
  - The centre panel between the portals should be a large lit rectangle
    about the portals' height.
  - Check that nothing collides with seats at the widened opening.
- **Announce table:** `CommentaryDeskLed` (in `game/core/arena/arena_builder.gd`,
  around line 870) must become **printed signage**: a lit StandardMaterial3D
  with the art as albedo, roughness about 0.5, **no emission**. The
  commentary monitors stay emissive.
- **Barricade LEDs:** `barricade_face()` in
  `game/core/lighting/arena_lighting.gd` (around line 1031) only puts LED art
  on the two ±X short ends. Extend it to the long sides, including the
  hard-cam side, as in the owner still. Keep the per-panel energy and keep
  the spill-light count sane (merge spills). LEDs must not over-light the
  arena.
- If you redo any of this, every touched `.glb` must be deterministic.
  Gate it on `stage_wide_shot`, `arena_shot` and `compat_shot` frames.

**(b) Roman's Ula Fala.** Look for an "Ula Fala …" commit touching
`tools/blender/roman_props.py` and `game/core/match/entrance_props.gd`.
- **Original defect:**
  - A rigid mesh re-posed in `_process` from the `neck_01` position plus the
    `spine_03` rotation. It does not deform with the chest or clavicles, it
    lags the skeleton update, and it is undersized (0.32 m loop, hanging only
    0.15 m, with 84 tiny keys).
  - Prop removal (`fala_off` in `entrance_director.gd`) just hides it.
- **The in-progress rebuild (v5 frames):**
  - Dense, larger spikes sitting on the collarbones and hanging to the
    upper pecs, which is close to the photo.
  - **Open feedback:**
    - The colour was too pink/salmon and too glossy. The target is deep
      red (#B0141E to #D42A2A), darker at the base, with soft specular.
    - The shoulder spikes flared out horizontally like wings. They must
      droop along the trapezius.
  - Must be verified not floating and not clipping at: the walk, the
    stage-lip pose, both arm-raise frames (`finger_hold`), and ringside
    before `ula_fala_off`.
- **Attachment target:** skin it to the skeleton (neck_01, spine_03,
  clavicle_l, clavicle_r, blended along the loop) like `entrance_coat.gd`
  does. At minimum, update after the skeleton pose, never against the
  AnimationTree in `_process`. Keep the `set_fala_visible` API; Stage 3
  replaces hiding with a real handoff.
- A test `game/tests/test_ula_fala.gd` was being written.

**When Stage 1 is complete:** run the full suite, README entry, commit,
push the branch, fast-forward and push `main`, verify the Pages deploy.

## 4. Remaining stages, in order

Order rationale:
- Crowd visuals sit in Stage 2 because they share the crowd shader with the
  flashes.
- Movesets come before AI because the AI can only weight moves that exist.
- Ring mechanics come before AI because AI Irish whips need them.

After **every** stage: tests green, frames reviewed against the refs, README
section, commit, push the branch, fast-forward and push `main`, verify the live
deploy, then record the result in the README.

### Stage 2: Audio, crowd visuals, camera flashes

**Title music.**
- `game/core/ui/title_screen.gd` is the title, select and VS card, all one
  script and scene (`scenes/title.tscn`).
- Today `_ready` starts a looping `crowd_bed` through `SfxPool` at
  `MENU_CROWD_DB` -16 (around lines 109–126). `_launch()` (around lines
  322–342) frees the scene and cuts the audio dead.
- Replace the menu crowd bed with `title_theme.ogg` as music:
  - Start on title `_ready`.
  - Loop seamlessly. Find a musical loop point, or crossfade-fold the tail
    into the head the way `tools/audio/build_sfx.py` (lines 149–157) builds
    its loops. Prefer a build-script step that writes the loop metadata, so
    it stays reproducible.
  - It should continue (or crossfade) on the select screen if that sounds
    right, and fade out over the launch stinger, not cut.
- Tests:
  - It starts.
  - The stream has looping enabled with a sane loop point.
  - Leaving the screen fades it, with no abrupt stop.

**Selection-screen crowd** (if the select keeps a crowd under or instead of
the music):
- The current `crowd_bed.ogg` (52 s; Freesound 706497, Rogers Arena NHL)
  likely has intelligible chatter.
- Build a new walla bed from **CC0** archive.org recordings. These download
  fine from the container:
  - `https://archive.org/download/Red_Library_Crowds_Outdoor/…`: R25-22
    "Large Excited Crowd", R28-29 "Large Crowd Quiet Then Big Reaction",
    R08-05 "Large Group at Event", R08-09 "Large Unhappy Crowd" (boos).
  - `SSE_Library_AMBIENCE` SPORT folder: "AMBSprt_Baseball walla from high
    in stands".
  - Verify each file's `licenseurl` in the archive.org metadata is CC0.
    **Never** use anything labelled "talking", BBC Sound Effects (RemArc,
    not permissive), Pixabay, ZapSplat or Uppbeat.
- Make it unintelligible: layer several sources, high-pass, add a short
  diffusion/reverb, and slightly detune the layers.
- Do it in `tools/audio/build_sfx.py` so it is reproducible, and credit it in
  `CREDITS.md`.
- Verify with stats: the energy in the 500 Hz–3 kHz band should not show
  speech-like modulation, measured as a low 4–8 Hz envelope modulation
  index. Also check spectrogram images.

**In-match crowd** (`game/core/audio/match_audio.gd`; reactions in
`game/core/arena/crowd_reaction.gd`):
- Today:
  - `crowd_bed` loops at -5 dB, rising to -1 dB.
  - The `crowd_roar` loop (17.5 s) rides `excitement^1.5`.
  - `crowd_pop_*` one-shots, `crowd_ooh` on two-counts, `crowd_finish`.
- Target layering:
  - 2–3 bed loops of **co-prime lengths** (e.g. 23 / 31 / 41 s) running out
    of sync, so no loop point is audible.
  - Intensity layers crossfaded by a slewed driver; never step a gain.
  - A **match-phase** intensity: quiet feeling-out, building through the
    control segment, peaks on near-falls.
  - Reaction one-shots with random pitch (±3%) and pan.
  - **Heel/face reactions:** a boo layer for Roman's control and taunts, a
    cheer swell for Cody's fire-up.
  - An **entrance layer** for each man's music hits.
  - Chant-style rhythmic claps are optional.
- Keep the broadcast mix (non-positional). It must stay out of the replay
  hash.
- Verify with `tools/probe/audio_log` and `tools/capture/mix_sound_log.py`.

**Crowd visuals.** The audit with renders found box people: bald cube heads,
6 repeated ringside poses, a rigid vertical bob, one global excitement value
(the whole house jumps at once), lit by one global scalar, and far tiers that
read as a voxel mosaic. Extend the architecture; do not replace it.
- **Bowl:** baked per-seat figures in `arena_bowl.glb`, built by
  `tools/blender/crowd.py` (413 lines):
  - The "Crowd" mesh is the first 4 rows, about 13 boxes per figure.
  - "CrowdFar" is about 4,900 four-box figures.
  - COLOR_0 carries 14 shirt colours and 6 skins; the phase is in UV.x.
- **Floor:** about 1,490 ringside chairs as 6 MultiMesh variants from
  `tools/blender/floor_crowd.py`, placed in `arena_builder.gd` (around lines
  1054–1118).
- **Shader:** `_crowd_material()` in `arena_builder.gd` (around lines
  1273–1366).
- **Do:**
  - **Model:** rounded heads with hair caps (4–6 styles, a hair-colour
    palette), a neck, tapered shoulders and torso, bent arms.
  - **Floor variants:** 6 → about 16, including standing and arms-up.
  - **Bowl yaw:** jitter ±15–25° so not every figure stares at ring centre.
  - **Per-figure roles** in a second UV channel (clap, wave, stand/sit)
    animated in the vertex shader.
  - **Cheers:** a **per-section wave** (phase offset by world position)
    instead of one global jump.
  - **Lighting response:** feed a few globals from `arena_lighting.gd` (ring
    wash, beam colours) and add cheap lower-body AO.
  - **Seating:** jitter seat positions 5–8 cm, vary fill by section and
    tier, add standing clusters and a few signs.
  - **Web:** a `visibility_range`/impostor for the far tiers on web.
  - Fix the stale "the hall is EMPTY" header comments (`arena_builder.gd`
    lines 13–20 and 61–65, `arena_bowl.py` line 28).
- Tests: `test_arena_crowd.gd` and `test_floor_crowd.gd` (phase spread,
  palette).
- Judge it on frames at hard-cam distance and in a ringside close-up. It must
  not read as cutouts or clones.

**Camera flashes:**
- Today each flash makes a **whole figure** go `EMISSION += 3.5` (a
  figure-sized blob), from a per-figure 0.08 s-slot hash at a constant
  `ENTRANCE_FLASH_RATE` 0.012.
- Code locations: `crowd_reaction.gd` line 38; switched on at
  `entrance_director.gd` line 537 and off at line 917. Beyond 16 m only.
- Replace with a **small point flash at head or hand height**:
  - Lasts 1–2 frames (about 30–60 ms), with a soft bloom and a few frames
    of decay.
  - Irregular and clustered: sections facing the action are denser.
  - A low rate at rest (about 0.1–0.3 Hz per active emitter); bursts on pyro
    hits, finishers and pin counts.
  - **Never synchronised**, never the whole figure lit.
- It must be believable on the web (gl_compatibility) too.

**Lighting audit for this stage:** LEDs (ribbon `RIBBON_ART_PEAK` 1.1 plus
24 `RibbonSpill` omnis, stage LEDs, barricades) must not over-expose. Compare
against `gauntlet/refs/lighting_2k26.md`.

### Stage 3: Entrances, props, Aubrey, timekeeper

The entrance director is `game/core/match/entrance_director.gd` (2031 lines,
tick-driven). Roman's entrance is `_add_roman_entrance` (lines 933–1020);
Cody's is `_add_cody_entrance` (lines 1053–1205).

**Cody's dry ice:**
- Today it is a `FogVolume` `PortalSmoke` at the portal mouth (`_smoke_on`,
  lines 1816–1830). It switches off at the WHOA and **does nothing on the web**
  (gl_compatibility has no FogVolume).
- Build ground-hugging dry ice from **GPU particles**: soft, lit, low and
  slow sheets that pour out of the tunnel and roll down the ramp, so it works
  on both renderers.
- Keep the FogVolume as a Forward+ extra.
- Cody walks out through it, and it lingers and dissipates after the WHOA.
- Add **fast-moving light sweeps across the crowd** on the crowd cutaways.
- Check against the owner's video (MITB 2023) and real references: arms-out
  WHOA, pyro on the beat.

**Roman's entrance review:** with the new Ula Fala, check the lighting,
camera, crowd and audio cues. Fix anything that breaks realism.

**Prop handoff:**
- Today `fala_off`, `title_down` and `coat_off` **hide meshes**, and there is
  **no timekeeper** in the repo (comments only). `_ring_bell` (lines 872–925)
  `queue_free()`s the props and **teleports** both men to their marks.
- Build a believable per-prop sequence, **one prop at a time**:
  1. The wrestler lifts it off.
  2. A hand-to-hand pass to Aubrey (`RefereeActor`,
     `game/core/match/referee_actor.gd`, on `scenes/aubrey_model.tscn`;
     today she parks at PARK (2.35, 0, -1.4)). The prop swaps attach point
     on the contact frame, so there is no pop.
  3. Aubrey walks to the ropes and hands it down.
  4. A **new timekeeper actor** at a ringside table takes it and sets it on
     the table.
- The bell-time teleport is replaced by walking to the marks.
- New clips are authored in `game/tools/blender/wrestling_clips.py`.
  Rotations are Euler degrees over the rest pose. **Watch the pitch sign:**
  the README records repeated bugs where a positive pitch tips a man
  backward.
- Tests:
  - No prop visibility pops.
  - At most one prop in transit at a time.
  - No body interpenetration (capsule distance) between wrestler, referee
    and timekeeper.
- Gate on `entrance_shots` frames at every handoff beat.

### Stage 4: Ring mechanics

**Pin legality**, enforced as a referee rule in
`game/core/match/match_referee.gd`:
- Today a cover starts at `_check_for_downed_opponent_action` (line 229) with
  **no ring-bounds check**. Position is only clamped by
  `keep_inside_the_ring()` (`wrestler_controller.gd` line 1577) to |x|,|z| ≤
  2.6.
- Today a rope break waits until tick ~194, after the 2-count.
- **New rule:** a cover is legal only if both men's hips and torso are inside
  the ropes (ropes at |x|/|z| ≈ 2.98). The defender's head and shoulders must
  not be under the bottom rope, and nobody may be on the apron or outside.
- If the cover is illegal, the AI drags the man to the centre first, or does
  not cover.
- Rope contact during a count is an **immediate** break: the referee stops
  the count when contact happens, not at a fixed tick. Finishers stay
  unbreakable only if they are fully legal at cover start.
- Add tests: under-rope, over-rope, part-way out, apron, and legal-centre.

**Ropes:**
- Gameplay ropes are kinematic code in `wrestler_controller.gd` (constants
  around lines 139–156, `_begin_rope_load` around line 1980, whip launch 9,
  rebound damping 0.85).
- The cosmetic `RingRopes` (`game/core/ring/ring_ropes.gd`, one-way) must
  stay one-way.
- Add:
  - **AI Irish whips.** The AI never whips today; it was removed at
    `wrestler_ai.gd` line 408. `_begin_irish_whip` is at
    `wrestler_controller.gd` line 1903.
  - Rebound attacks.
  - Rope-hang selling.
  - Believable collision timing.
- Read `gauntlet/refs/ropes.md` (it holds the measured rope-entry fix).

### Stage 5: Movesets

Wiring:
- Movesets are wired through `Roster.Entry.moveset` (`game/core/ui/roster.gd`;
  Roman at line 118, Cody at lines 175–185) and applied in
  `TitleScreen.configure_match` (`title_screen.gd` lines 342–420).
- Shared defaults live in `scenes/match.tscn` lines 259–267.
- MoveDefs live in `game/resources/moves/*.tres`. Paired moves are in
  `game/resources/animations/paired_recipes.gd`, `paired_moves.tres` and
  `paired_poses.tres`, built by `tools/anim/build_paired_*.gd`. Strikes are in
  `strike_recipes.gd`.

**Roman has no moveset dict,** so he draws claymores and hoedowns from the
shared running pool of 26. Give him his own:
- Strikes: jab, clubbing blows, cross, Samoan headbutt.
- Running: clothesline, Spear.
- **Samoan Drop** (new paired clip).
- **Guillotine Choke** (a 2K26 signature; front standing).
- **Drive-By** dropkick (a 2K26 signature; apron/corner).
- **Superman Punch with the rope-rebound wind-up** (2K26 signature; the
  wind-up does not exist yet).
- **Corner Spear** and **Superman Punch on a grounded opponent in the
  corner**.
- An **"Acknowledge Me"** taunt over a downed opponent.
- Spear finisher (exists).

**Cody:**
- **Pedigree** (a confirmed 2K26 signature; missing).
- **Cross Rhodes from behind** (a 2K26 finisher; only the front version
  exists).
- **Springboard/running Cody Cutter** variants (only standing exists).
- A visible **Bionic Elbow shimmy build-up**.
- A belt-pose victory.
- Keep his existing moves: Cross Rhodes, Cutter, Disaster Kick, Bionic
  Elbow, Dropdown Uppercut, Vertical Suplex, Powerslam, Alabama Slam,
  Figure-Four, Tope, springboard Disaster Kick.

**Super finishers** (Superman Punch → Spear; Cross Rhodes Trinity) are
optional and only worth doing after a finisher-stock concept exists.

**Do not recreate moves that already work.** Clips go in
`wrestling_clips.py`; validate each new move on `clip_shot`/`dive_shot`
frames and with the reachability probe.

### Stage 6: Match AI and pacing

**Measured today:** 3 seeded AI-vs-AI matches lasted **63–85 s**, with 3–4
knockdowns and 25–33 moves, ending around 174–193 wear.

**Root causes, in order:**
1. **Heavy damage against a flat `KNOCKDOWN_DAMAGE` 100**
   (`wrestler_controller.gd` line 75). Bodyslam is 26, running attacks
   16–24, signatures 30–40, finishers 50.
2. **The HUD "health" is a damage meter:** `total_damage / 200`
   (`match_hud.gd` lines 144–147). It is about half gone after the first
   knockdown and **never refills**.
3. **No healing anywhere:** `limb_damage` and `wear` only increase, and
   momentum never decays.
4. Ground attacks during every knockdown.
5. A 40-tick strike cooldown with no rest phases.

**First fix the probe:** `tools/probe/ladder_probe.gd` line 110 — the `tiers`
dict lacks `"unknown"`, so it crashes on ground attacks and parries.

**Implement, based on sourced 2K mechanics:**
- **Two-layer vitality** (2K25 official help centre):
  - Recoverable damage that regenerates after N seconds without being hit,
    plus permanent damage.
  - Kickouts, escapes and get-ups read total vitality.
  - The HUD shows real vitality (green recoverable over red permanent).
- **Rescale damage** together with `KNOCKDOWN_DAMAGE`,
  `KICKOUT_DAMAGE_REFERENCE` (200) and `BodyLife.DAMAGE_FULL` (160). The
  tuning lives in MoveDef `.tres` files wherever possible.
- **Stamina-costed reversals with a blown-up state** (2K26):
  - Reversal, sprint and dodge share one pool. At empty, there are no
    reversals or running for a while.
  - Rare early in the match, and not a constant mid-match state (2K26 patch
    1.07 lesson).
  - The AI reversal chance is `REVERSAL_CHANCE` 0.45 (`wrestler_ai.gd` line
    205). Scale it by stamina.
- **Kickout odds escalate** with each finisher and signature landed (the 2K25
  "Previous Finisher Influence" sliders): the 1st finisher is kickable, the
  2nd less so, the 3rd nearly decisive.
  - Keep the existing **"only a finisher wins"** rule (`_finished` in
    `match_referee.gd`, `test_finisher_only.gd`).
  - Kickout is the `PinMinigame` window via `kickout_window_fraction`
    (`combat_system.gd` line 299).
- **A match-phase director** that biases AI weights:
  feeling-out → Roman's heel control (stalling, rest holds, cut-offs, slower
  tempo, Acknowledge Me) → Cody's hope spot → cut-off → Cody's fire-up
  comeback (`fire_up`, `wrestler_controller.gd` line 2894; comeback constants
  at `combat_system.gd` lines 113–134) → near-falls → finish.
  - Rest periods.
  - Signatures and finishers timed to the phase, not just to
    `_opponent_is_ripe()` (`wrestler_ai.gd` line 672).
- **Determinism:** every new random draw goes through the seeded RNG.
  `test_determinism.gd` must pass.
- **Verify across 5+ seeds** with the fixed `ladder_probe`. Each match should
  be 8–12 min with 2–4 near-falls and at least one finisher kickout. Roman
  should show visibly heel tempo and Cody face tempo. Report a duration and
  health-curve table in the README.

### Stage 7: Camera and presentation

The camera is `game/core/camera/match_camera.gd`.
- **Today:**
  - The modes are `HARD_CAM`, `RINGSIDE`, `FINISHER_CUT`, `THREE_COUNT_CUT`,
    `ENTRANCE`, `FINISHER_AFTER` and `EVENT_CUT`. A shot clock alternates a
    7.0 s master with a 4.5 s handheld.
  - In the default `CameraSettings.Coverage.GAMEPLAY`, **RINGSIDE orbits the
    pair** (`_gameplay_bearing`, lines 878–912; 28° deadzone, 0.9 rad/s).
- **Target**, from real TV conventions (2K26's orbit behaviour is
  undocumented):
  - The hard cam stays on one side and never crosses the line.
  - Reverse angles come by **cuts only**, at impacts and resets.
  - Cut rhythm 3–6 s, with cuts on impact frames.
  - A low handheld on the referee's hand for near-falls.
  - Reaction and crowd shots in dead time (`_watch_sign_fans` exists).
  - Signature and finisher cinematics.
  - Replays after finishers and big near-falls (`instant_replay.gd`,
    `replay_buffer.gd`).
- **Test:** across a full match, camera yaw never moves continuously beyond
  the deadzone. Reverse angles appear only as cuts.
- Settings live in `camera_settings.gd`; existing references are
  `gauntlet/refs/camera.md` and `camera_aaa_plan.md`.

### Stage 8: Final AAA polish, independent QA, end-to-end recording

- **Independent QA:** use a fresh subagent that did not implement anything.
  It plays through and reviews frames and audio logs for:
  - the title (music and visuals) and select screen;
  - Roman's entrance (Ula Fala, lighting, camera, crowd, audio, stage);
  - Cody's entrance (dry ice, moving crowd lights);
  - the full match (camera, crowd, lighting, ropes, pin legality, movesets,
    vitality, momentum, AI pacing, heel/face behaviour, selling, reversals,
    near-falls, finish, referee).
  Fix everything practical rather than just reporting it.
- **End-to-end recording:** no full-flow capture exists today.
  `tools/capture/run_capture.sh` only drives `scenes/match.tscn`. Build one:
  - Godot Movie Maker (`--write-movie --fixed-fps`) on Vulkan under xvfb.
  - Covers title (with music) → select → VS → Roman's full entrance → Cody's
    full entrance → the full match → finish and replay.
  - Audio muxed with ffmpeg.
  - Commit the tool, not the video. Put the video in a GitHub release or
    the Pages site and report its location.
- **Final report to the owner:**
  - what was done
  - the research findings that shaped the work
  - the commits for each stage
  - deploy verification per stage
  - limitations
  - QA problems found and how they were fixed
  - where the video is

## 5. Known limits (state them; don't hide them)

- **The web build is gl_compatibility:** no FogVolume or volumetrics, and a
  simpler glow. Every effect needs a compat path, and `renderer_gain` /
  `COMPAT_*` gains in `arena_lighting.gd` handle exposure. The web build is
  judged for playability; the visual bar is judged on Vulkan frames.
- **2K's internal numbers are not public.** Ours are tuned to the measured
  match-shape target and must be labelled as such.
- **Pages verification today is a file-exists check.** Do at least one real
  load of the live site per stage (fetch `index.html`, `index.pck` size, the
  Actions run status).
