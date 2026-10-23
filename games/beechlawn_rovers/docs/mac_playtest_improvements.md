# Approved Mac playtest improvements

Owner approval: implement all five bundles, free/original assets, keyboard,
three-minute 11v11, Mac only. Latest installed build is unknown. Music plays
only in menus/intro; match has natural sounds. Automatic goals/major-incident
replays run at natural stoppages and are skippable. Wrestling is untouched.

1. **Build/presentation** (BR-024/025, in progress): visible v0.2.0, source SHA
   and packaging UTC; remove promotional/name captions; photographic Murray
   and owner Denham artwork; consistent blue scoreboard/venue/team/referee
   graphics; lower initial goal shot and grazing puddle shot.
2. **Movement/defending/keepers** (BR-002/007/009/021): shared arm gait,
   visible contact-timed standing tackle F, committed slide G, Ctrl jockey,
   J contain, H teammate pressure. Original directional save/catch/high-claim
   clips with legal physical glove contact and recovery.
3. **Attacks/set pieces** (BR-005/006/008/012/019): varied powerful elevated
   shots, natural wide play/cross-to-header/volley, short/long restarts,
   direct free kicks with legal walls, varied penalties with honest keepers.
4. **Pitch/net/audio** (BR-023/024): terrain-aligned instanced grass with
   mud/water exclusions and distance budgets; anchored visible net impact;
   original/licensed music and match/UI sounds with separate persisted buses.
5. **Celebrations/results/replays** (BR-026/027): goals, winners/draws,
   handshakes, Rematch/Title; bounded 12-second 30Hz pose/ball history, up to
   three bookmarks below 64MiB, collision-free ghosts, exact restart restore.

Each bundle requires mechanic regression checks, native Forward+ visual
inspection, strict natural AI chance checks and a verified universal Mac
release. Software Vulkan captures verify appearance, not M1 performance.
Keep 1080p60 performance and owner playtest acceptance open until measured.

Use typed match events for audio/presentation/replay, separating football
simulation and restart decisions from presentation. No forced goals, quotas,
team-specific boosts or copied PES assets. Existing 25 IDs remain stable;
BR-026 and BR-027 are appended (27 total).

## Evidence and status

- Baseline: ground/aerial controls, cross/header/volley, tackling and physical
  net contact tests pass, but do not establish visible match quality.
- Bundle 1: completed presentation scope, native evidence in `art_briefs/mac_presentation_2026_10_23/`; released source caddc00f1f47, universal Mac package verified by CI run 39934686896; public download HTTP 200.
- Bundle 2: implementation and focused contact/pose/control checks pass; native mirrored low-save sequences pass. Further full-body diving polish and native M1 feel remain open. Release gate pending.
- Bundles 3–5: approved, pending implementation and acceptance.
