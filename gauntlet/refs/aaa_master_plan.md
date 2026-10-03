# AAA master plan — Roman Reigns vs Cody Rhodes

Phase 0 output: seven read-only audits and research passes, consolidated.
Each stage below is tested, committed, pushed to `main` (Pages deploys from
`main` only), and verified live before the next begins. Every finding here was
measured in the current build, not taken from earlier README claims.

## What the audits found (the facts the plan rests on)

### Match is short: the cause is measured, not guessed
Three seeded AI-vs-AI matches (ladder_probe, seeds 3/4/5): **63–85 s** of match
time, 3–4 knockdowns, 25–33 moves landed, finisher pinfall at 174–193 wear.

- There is no HP. The HUD bar is `total_damage / 200` (`match_hud.gd:144`),
  and matches end around 180–190, so the bar is ~50% after the first knockdown
  and never refills. That is the "health drops too fast" the owner sees.
- Moves are heavy against a flat `KNOCKDOWN_DAMAGE` of 100: bodyslam 26,
  running attacks 16–24 (Roman draws from a shared pool of 26 of them),
  signatures 30–40, finishers 50. Four to six big hits make a knockdown.
- **Nothing ever heals.** `limb_damage` and `wear` only increase; momentum
  never decays. There are no rest phases.
- AI cadence is a 40-tick strike cooldown with no lulls, ground attacks during
  every knockdown, no heel/face difference, and no Irish whips.
- Repo bug: `tools/probe/ladder_probe.gd:110` `tiers` lacks `"unknown"`, so it
  crashes on a ground attack or parry.

### WWE 2K26/2K25 (sourced, confidence noted)
- **Vitality is two-layer:** green recovers when not being hit; red is
  permanent. Low vitality makes kickouts, escapes and get-ups harder (2K25
  official help centre: High).
- Limb damage in four states drives submissions (High).
- **2K26 reversals cost stamina**, and an empty bar means "blown up": no
  reversals, no running (VGC/OperationSports: High existence, Low numbers).
- Signature → finisher stock → finisher → both men down → crawl to cover (Med).
- **Kickout difficulty rises with each finisher and signature landed**
  (2K25 slider names "Previous Finisher Influence 2 / 3+": High). This is the
  near-fall model.
- Rope break: either man touching the ropes breaks the count (Med). How 2K
  blocks pins outside the ring is not documented anywhere reachable, so we
  design the rule ourselves.
- No source gives 2K's match length, AI move-selection logic or heel/face AI.
  Those follow standard match structure, which is labelled as ours.

### Movesets (2K26 confirmed lists: signatures and finishers only)
- **Roman:** Superman Punch (running, corner vs grounded), Drive-By, Guillotine,
  Spear (running, corner vs grounded), Superman Punch → Spear super. Our build
  has Spear and Superman Punch only. **Roman has no moveset of his own**: he
  draws from the shared pool (claymores, hoedowns).
- **Cody:** Cody Cutter (standing, running, two springboard variants), Pedigree,
  Cross Rhodes (front, behind, Trinity super). Our build has Cross Rhodes
  (front), Cutter, Disaster Kick, Bionic Elbow, Dropdown Uppercut, Vertical
  Suplex, Powerslam, Alabama Slam, Figure-Four and Tope. Missing: Pedigree,
  Cross Rhodes from behind, and the springboard Cutter.

### 3D (measured from the .glb files)
- **Stage:** portals of radius 2.45 at x=±3.3 leave a **1.26 m gap**. The
  reference gap is about one portal diameter, and the outer portal edges sit
  level with the screen edges. The ramp is 3.6 m wide and jumps straight to a
  12 m deck with no taper. The backdrop is one flat dark box: no truss behind
  the screen, no drape, no lit perforated side panels.
- **Ring:** the connectors are already lengthened (0.07 → 0.12) and the ropes
  are already brought in (2.86 → 2.80): done. **The post collars are still
  there**: 12 pale rings, not in the reference. The hardware is light grey;
  the reference's is dark.
- **Announce table:** `CommentaryDeskLed` uses emissive ribbon art. It should
  be printed.
- **Barricade LEDs** cover only the two short ends. The long sides, including
  the hard-cam side, are plain black.
- **Ula Fala:** a rigid mesh re-posed each frame from the `neck_01` position
  plus the `spine_03` rotation, in `_process`. It does not deform with chest
  or clavicles, it lags the skeleton update by up to a frame, and it is
  undersized (0.32 m loop, hanging 0.15 m; the photo hangs to the pecs, with
  larger spikes).

### Presentation
- **Title:** plays `crowd_bed` (a real NHL arena recording, likely with
  audible chatter). There is no music, and the bed is cut dead on launch.
- **Match crowd:** a 52 s bed plus a 17.5 s roar plus pops. No phase-driven
  intensity, no heel/face reaction, no entrance layer, no chants.
- **Flashes:** a whole spectator figure flares at +3.5 emission. Each one is a
  figure-sized blob, not a point of light.
- **Crowd visuals:** box people. Bald cube heads, 6 repeated ringside poses,
  rigid vertical bob, one global excitement value (the whole house jumps at
  once), lit by one global scalar, and the far tiers read as a voxel mosaic.
- **Cody's smoke:** a portal-mouth FogVolume rather than dry ice rolling out
  of the tunnel. It ends at the WHOA, and **it is invisible on the web**:
  FogVolume does nothing on gl_compatibility.
- **Props:** `fala_off`, `title_down` and `coat_off` just hide the mesh. There
  is no timekeeper. At the bell, both men teleport to their marks.
- **Camera:** in the default GAMEPLAY coverage, RINGSIDE orbits the pair to
  stay side-on. Real TV keeps the hard cam on one side and reaches reverse
  angles only by cuts.
- **Deploy check** is file-exists only; there is no full-flow capture tool.

## Implementation order

The suggested order holds, with two changes. Crowd visuals join Stage 2,
because they share the crowd shader with the flashes. Movesets come before
AI, because AI weights need the moves to exist.

### Stage 1 — Foundation / 3D
1. Stage (`tools/blender/entrance_set.py`, `arena_builder.gd` constants,
   `test_stage_set.gd`):
   - Portals spaced about one diameter apart, outer edges under the screen
     edges, and a wider centre panel.
   - The ramp flares into the deck.
   - Truss and rig behind and above the screen; lit perforated side panels;
     black drape on the side walls.
2. Ring (`tools/blender/ring.py`, `ring_builder.gd`, `test_ring_model.gd`):
   remove the collars and darken the hardware. Connectors and inset stay as
   they are (already done).
3. Announce table: printed, lit material with no emission.
4. Barricade LEDs on the long sides, emission kept in the existing budget.
5. Ula Fala (`roman_props.py`, `entrance_props.gd`):
   - Rebuild to the photo's scale (fuller, larger spikes, front hanging to the
     pecs).
   - Skin it to clavicles, spine and neck like `entrance_coat.gd`, so it
     deforms with the chest.
   - Update after the skeleton, never in `_process` against the AnimationTree.

**Gate:** tests; Vulkan frames versus the reference; Ula Fala frames through
the arm-raise.

### Stage 2 — Audio, crowd visuals, flashes
1. Title music from the owner's file (`menu_theme.ogg`): starts on title
   `_ready` and loops at a measured seamless point. It continues through
   select, fades out over the launch stinger, and gets a test.
2. Select screen: a new walla bed built from CC0 archive.org recordings
   (USC/Red Library, licence verified per file). High-passed and diffused
   past intelligibility, and checked with spectral and envelope stats.
3. Match crowd, layered:
   - Two or three beds of co-prime lengths running out of sync.
   - Intensity layers crossfaded by a match-phase driver.
   - Reaction one-shots with pitch and pan variation.
   - Heel and face reaction (boo layer for Roman, cheer swell for Cody).
   - An entrance layer.
   - No abrupt jumps: every gain change is slewed.
4. Crowd figures (`tools/blender/crowd.py`, `floor_crowd.py`, crowd shader):
   - Rounded heads with hair caps (palette).
   - Tapered shoulders and torsos.
   - 16 floor variants instead of 6.
   - Yaw jitter in the bowl.
   - Per-figure roles (clap, arm wave, stand) in a UV channel.
   - Cheers travel as a per-section wave instead of one global jump.
   - Light response from ring wash and beams.
   - Seat jitter, and fill that varies by section.
   - Keep the architecture (baked bowl plus floor MultiMesh); add a far
     visibility range for the web.
5. Flashes: a small point sprite at the head, 1–2 frames long. Irregular,
   clustered, rare at rest, and bursting on pyro and finishers. The figure
   itself is never lit.

**Gate:** tests; audio stats; frames at hard-cam distance and close-up.

### Stage 3 — Entrances, props, Aubrey, timekeeper
1. Cody dry ice:
   - Ground-hugging sheets rolling out of the tunnel mouth and down the
     ramp, built from GPU particles (soft, lit) so they also work on the web.
     FogVolume stays an extra on Forward+.
   - Cody walks out through the dry ice; it lingers past the WHOA.
   - Fast lights sweep the crowd on the crowd cut-aways.
2. Roman entrance review with the new Ula Fala: lighting, camera, crowd and
   audio cues.
3. Prop handoff:
   - A timekeeper actor at a ringside table.
   - A per-prop sequence: wrestler lifts the prop off → hand-to-hand to
     Aubrey (attach-point swap on contact frames) → Aubrey walks to the ropes
     and hands it down → the timekeeper takes it and sets it on the table.
   - One prop at a time, with no hide/teleport.
   - Bell-time teleport replaced by walking to the marks.

**Gate:** entrance probe frames at every handoff; "no prop visibility pops"
test.

### Stage 4 — Ring mechanics
1. Pin legality, a referee rule:
   - Cover allowed only if both men's torsos and hips are inside the ropes,
     the defender's head and shoulders are not under the bottom rope, and
     they are not on the apron.
   - Otherwise the AI drags the man to the centre first, or does not cover.
   - Rope contact during a count is an immediate break.
   - New tests for under-rope, over-rope and part-way-out positions.
2. Ropes: AI Irish whips and rebound attacks; rope-hang selling; whip
   timing. The cosmetic rope sim keeps its one-way rule.

### Stage 5 — Movesets
- **Roman:**
  - His own moveset dict (cuts the borrowed claymores).
  - Samoan Drop, Guillotine, Drive-By.
  - Superman Punch with the rope-rebound wind-up.
  - Corner Spear.
  - "Acknowledge Me" over a downed man.
- **Cody:**
  - Pedigree.
  - Cross Rhodes from behind.
  - Springboard Cody Cutter.
  - Bionic-elbow shimmy build-up.
- **Animation:** new clips authored in
  `game/tools/blender/wrestling_clips.py`, with paired recipes in
  `paired_recipes.gd`.

### Stage 6 — Match AI and pacing
1. Health model to 2K's two layers: recoverable wear that heals while out of
   contact, plus permanent wear. The HUD shows real vitality.
2. Damage rescaled with `KNOCKDOWN_DAMAGE` and the kickout reference in step.
3. Stamina-costed reversals with a blown-up state; kickout odds escalating per
   finisher and signature landed.
4. A match-phase director that biases AI weights: feeling-out → heel control
   (Roman: stalling, rest holds, cut-offs) → face hope spot → cut-off → Cody
   fire-up comeback → near-falls → finish. Rest periods and slower Roman
   tempo.
5. **Target: 8–12 min match, 2–4 near-falls, and at least one kickout from a
   finisher.** Measured across five or more seeds with the fixed ladder probe.

### Stage 7 — Camera
- The hard cam stays on one side: no orbiting with the pair. Reverse angles
  come by cuts only, at impacts and resets.
- Cut rhythm 3–6 s; low hand-held on near-falls; reaction and crowd shots in
  dead time; finisher cinematics; replays after finishers and near-falls.
- Test: across a full match, camera yaw never moves continuously beyond the
  deadzone.

### Stage 8 — Polish, final QA, end-to-end recording
- An independent QA agent reviews frames from every section.
- Fixes go in, then a full end-to-end capture tool: title (with music) →
  select → both entrances → full match → finish, rendered on Vulkan with
  audio muxed.

## Known limits, stated up front
- The web build renders on gl_compatibility: no volumetric fog, simpler glow.
  Every effect gets a compat path, but the web is judged for playability, not
  for the visual bar.
- 2K's internal numbers (damage, regen, AI weights) are not public. Ours are
  tuned to the measured match-shape target, not copied.
- The headless sim runs at about 20 ticks/s, so a 10-minute match takes about
  30 minutes to verify. Pacing checks run in the background.
