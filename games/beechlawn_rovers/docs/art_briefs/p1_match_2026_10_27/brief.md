# P1 match and keeper distribution — 27 October 2026

Baseline: `b8e2a83787c1aacc9a421a5a9c9cae557b118bd6` (Mac v0.5.6).
Scope: BR-008, BR-009 and BR-010. This is cloud validation; target-Mac
appearance, input feel and sustained 1080p60 remain open under BR-008/009/025.

## Reference and gap

The archived [John O’Rourke sheet](../../../references/source_uploads/chat_attachments/character_roster_sheets/2-69011.jpg)
sets the keeper kit, gloves and silhouette; the archived
[broadcast composite](../../../references/source_uploads/chat_attachments/football_reference_upload_round_1/1-69022.jpg)
sets the pitch-view diagnostic context. Neither still specifies throw timing.
The shipping `footballer_shared.blend` and `footballer_base.glb`, their 65-bone
rest, `KeeperSet`, the existing hand-following ball hold and the fixed 60 Hz
match clock are the motion baseline. Before this pass, a claimed ball launched
after a timer without any distribution body motion. F3 showed only text speed
data; tactical targets, collision shapes and keeper prediction were invisible.

## Implementation

- `author_keeper_distribution.py` produces an animation-only 58-frame GLB and
  editable blend from the current shared rig. The right arm draws back and
  distributes while the left guides the hold. No root or gameplay movement is
  authored. Both keeper visuals load the same clip. Its 0.5 s hand marker
  calls the existing rigid-body distribution once. Stoppages clear the pending
  marker; the keeper finishes follow-through before moving again. The ball
  remains a held rigid body, tracks the throwing glove through a damped force,
  and is released through the normal `kick()` impulse with `hands` contact.
- F3 now toggles a match-level overlay in Play and Watch modes. It projects
  actual player/ball velocities, collision capsules, AI role/target positions,
  live reception targets and keeper interception prediction. It is hidden by
  default and survives automatic or manual player selection.
- The existing 4v4 milestone smoke now checks the current 2.0 m visual goal
  depth separately from its 1.8 m net collider, and aims its shot with the
  live controlled player after pass handover.

## Validation

Serial deadline-bound Godot checks passed: `milestone1_smoke`,
`p1_debug_overlay_smoke`, `keeper_distribution_smoke`,
`keeper_distribution_hand_smoke`, `goalkeeper_smoke`,
`goalkeeper_outcomes_smoke`, `keeper_live_contact_smoke`,
`full_match_restarts_smoke`, `match_flow_smoke`, `ai_vs_ai_smoke`,
`ai_tactical_parity_smoke`, `ai_attack_choice_smoke`, `defensive_ai_smoke`,
`transition_ai_smoke`, and `eleven_v_eleven_match_soak`. The 4v4 AI run
covered 720 physics frames: six moving outfielders, two passes, one shot and
no two-second movement stall. The three-minute 11v11 run produced 2/7 shots,
2/1 keeper saves, a 1–1 score and no stationary sample. The live hand test
measured 0.180 m from the ball to the right glove at release. Both teams pass
single-release, cancellation and recovery checks.

[Native Forward+ debug-off/on frames](debug/) show ordinary play without
diagnostics, visible target/collision guides after F3, and a separate live
keeper-prediction/pass-target view. [Native keeper frames](distribution/)
sample each side before, through and after the authored release. The report
records clip time, held state and glove gap: at 0.217/0.417/0.467 s, the
ball stays held 0.058/0.141/0.192 m from the throwing glove; at 0.567 s it
has released. The sequence uses a staged legal hold and a real imported clip,
controller and ball, so it proves the distribution path rather than a
naturally generated catch frequency.

The matched [normal-play arena capture](budget/) at 640×360 records 1,208
draw calls and 1,157,084 primitives, exactly the v0.5.6 numbers. Peak Linux
process RSS was 4,289,380 KiB versus the prior 4,307,132 KiB; this small
difference is process noise, not a claimed memory optimization. At 1280×720,
the F3 fixture records 1,205 draws with the overlay off and 1,537 with it on;
the extra 332 occur only during development use. All captures used llvmpipe
Vulkan Forward+, not Metal. The new GLB is 72 KiB and adds no skeleton or
ordinary-play mesh draw. Existing keeper faces, kit materials and body rig
remain unchanged.

The imported GLB, Blender source, contact metadata, captures, and numeric
reports are retained. The known cached-resource exit diagnostic may appear
after an otherwise passing headless test; no new script or shader failure was
accepted. Native M1 Pro/16 GB playtests must still check human-vs-AI tactical
feel, the throw's appearance and sustained 1080p60.
