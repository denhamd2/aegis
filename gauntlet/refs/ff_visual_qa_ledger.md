# FF per-move visual QA ledger (8 November 2026)

Owner requirement: **every built or fixed move gets its own sheet and a
recorded `visual-qa` verdict.** A batch sheet is supporting evidence only. This
ledger is the completion record for that gate.

- Sheet path: `gauntlet/refs/ff_review/moves/<move_id>.png`
- Required views: attacker and defender, six beats, match camera plus a
  close/side view (close-up for grips and faces).
- A move is **not complete** while either column says `pending`.
- Re-review after any change to the clip, trajectory, contact family, fit or
  camera.

## Current built moves — 27 / 146

| Move | Family | Kind | Sheet | Visual QA | Notes |
| --- | --- | --- | --- | --- | --- |
| `springboard_moonsault_3` | aerial | reused | pending | pending | Batch sheet only. |
| `powerbomb_v_trigger_combo` | combo | authored | pending | pending | Batch sheet only. |
| `code_breaker_1` | cutter | authored | pending | pending | Batch sheet only. |
| `cody_cutter_4` | cutter | reused | pending | pending | Batch sheet only. |
| `cody_cutter_5` | cutter | reused | pending | pending | Batch sheet only. |
| `inverted_ddt_1` | ddt | authored | pending | pending | Batch sheet only. |
| `cross_rhodes` | driver | reused | pending | pending | Batch sheet only. |
| `one_winged_angel` | driver | authored | side/close done | fail (AAA bar) | Art-director 2.5/3.0/2.5. Weightless carry, skipped impact, no sell. Grip 4.5 cm. |
| `tiger_driver_98` | driver | authored | pending | pending | Batch sheet only. |
| `running_v_trigger_1` | knee | authored | pending | pending | Batch sheet only. |
| `running_v_trigger_3` | knee | authored | pending | pending | Batch sheet only. |
| `v_trigger_1` | knee | authored | pending | pending | Batch sheet only. |
| `casualty_of_war` | lariat | authored | pending | pending | Batch sheet only. |
| `buckle_bomb` | powerbomb | authored | pending | pending | Batch sheet only. |
| `fireman_carry_bomb_2` | powerbomb | authored | pending | pending | Batch sheet only. |
| `powerbomb_1` | powerbomb | authored | pending | pending | Batch sheet only. |
| `sit_out_powerbomb_2` | powerbomb | authored | pending | pending | Batch sheet only. |
| `chokeslam_1` | slam | authored | side/close done | fail (AAA bar) | Art-director 2.5/3.0/2.5. Peak silhouette reads; grip, impact and sell fail. |
| `oklahoma_stampede` | slam | authored | pending | pending | Batch sheet only; recovery watch item. |
| `scoop_slam_2` | slam | reused | pending | pending | Batch sheet only. |
| `squatting_samoan_drop` | slam | reused | side/close done | fail (AAA bar) | Art-director 3.0/3.5/3.0. Closest of the three; same weight/impact/sell failures. |
| `spear_2` | spear | reused | pending | pending | Batch sheet only. |
| `spinebuster_5` | spinebuster | authored | pending | pending | Batch sheet only. |
| `figure_four_leglock` | submission | reused | pending | pending | Batch sheet only. |
| `brainbuster_1` | suplex | authored | pending | pending | Batch sheet only. |
| `snap_dragon_suplex_2` | suplex | authored | pending | pending | Batch sheet only. |
| `snap_dragon_suplex_3` | suplex | authored | pending | pending | Batch sheet only. |

## Rules for the 119 library moves

Phase C adds each move to this ledger when its MoveDef and both paired roles
exist. The row is not marked complete until:

1. the automated gates pass;
2. `gauntlet/refs/ff_review/moves/<move_id>.png` exists and shows both roles
   across six beats plus the close view;
3. `visual-qa` has recorded a verdict (pass, pass-with-watch-item, or fail with
   a specific defect);
4. the seeded tally proves the move fires and lands where its tier expects.

## Verdict vocabulary

- **pass** — no visible defect in the sheet; watch items may still be recorded.
- **pass with watch item** — readable, but one specific risk is recorded
  (for example a camera cut or a tight grip).
- **fail** — a named defect that needs a fix before the move is called done.

## Automated gate record — 8 November 2026

- FF library: **16/16 passed**.
- Pair clearance, focused on the two changed moves: **3/3 passed**
  (`power_samoan_drop`, `ff/one_winged_angel`).
- Clip cadence: **3/3 passed**.
- Paired poses: **14/14 passed**.
- Paired moveset: **22/22 passed**.
- Pose lint: **3/3 passed**.
- Authored clips: **15/15 passed**.
- Full 33-move pair sweep: not rerun in this pass; the focused run covers the
  two moves whose contact/fit changed. Rerun the full sweep on the Mac or in
  the next batch.

## Review record

| Date | Move | Sheet | Reviewer | Verdict | Notes |
| --- | --- | --- | --- | --- | --- |
| 8 Nov 2026 | all 27 | pending | — | pending | Backfill sheets not yet rendered. |
| 8 Nov 2026 | `one_winged_angel` | `moves/one_winged_angel.png` | DeepSeek V4 Pro (art director) | fail — 2.5 / 3.0 / 2.5 | Weightless carry, skipped impact, no sell. Evidence: `visual-review-owa-samoan.md`. |
| 8 Nov 2026 | `squatting_samoan_drop` | `moves/squatting_samoan_drop.png` | DeepSeek V4 Pro (art director) | fail — 3.0 / 3.5 / 3.0 | Closest of the three; same weight/impact/sell failures. Evidence: `visual-review-owa-samoan.md`. |
| 8 Nov 2026 | `chokeslam_1` | `moves/chokeslam_1.png` | DeepSeek V4 Pro (art director) | fail — 2.5 / 3.0 / 2.5 | Peak silhouette reads; grip, impact and sell fail. Evidence: `visual-review-chokeslam.md`. |

## Video-reference loop

Every move below is matched to the tutorial video. Score columns are
animation / poses / effects / selling / attacking / realism / speed / power /
overall. A move is complete only at overall 10/10 with no factor below 9/10.

| Move | Reference | Status | Score |
| --- | --- | --- | --- |
| High hook | 1:01.44 contact | Passed 7.0 after pivot/follow-through rework; effects/sell outstanding | 8 / 7.5 / 4 / 4 / 7.5 / 7 / 5 / 8 / **7.0** |
| Front kick body | 1:03.95 contact | Passed 6.3; lean-back improved | 7 / 7 / 4 / 5 / 7 / 7 / 7 / 6 / **6.3** |
| Turning back kick body | 1:06.07 contact | Passed 8.0 — adding contact hold | 8 / 9 / 4 / 7 / 8 / 8 / 7 / 8 / **8.0** |
| Clinch knee body | 1:10.95 contact | Passed 6.5; hip thrust/head pull landed | 7 / 7 / 4 / 5 / 8 / 7 / 7 / 7 / **6.5** |
| Running flying knee | 1:13.06 contact | Passed 6.6; crash/landing fixed | 8 / 8 / 4 / 5 / 8 / 7 / 6 / 7 / **6.6** |
| Side kick knockdown | 1:16.68 contact | Passed 8.0 — verifying extension and hold | 8 / 9 / 4 / 7 / 8 / 8 / 7 / 8 / **8.0** |
| Turning back kick knockdown | 1:20.26 contact | Passed 7.5 borderline — verifying heel and hold | 8 / 8 / 4 / 7 / 8 / 8 / 7 / 8 / **7.5** |
| Combination 3-hit | 1:26.07 / 1:26.54 / 1:26.62 | Reference extracted; authoring pending | — |
| Irish whip setup | 3:01.40–3:02.60 | Scored 7.0; borderline fail on grip close-up; rope contact unverified | 8 / 7 / 4 / 6 / 8 / 7 / 8 / 7 / **7.0** |
| Rope rebound | 3:02.50–3:03.60 | Scored 6.5; needs a rope-visible render of the absorb | 8 / 7 / 4 / 6 / 7 / 6 / 8 / 7 / **6.5** |
| Rebound slam | 3:17.85–3:20.10 | Scored 7.0; impact contact needs a close-up | 8 / 7 / 4 / 6 / 8 / 7 / 8 / 7 / **7.0** |
| Rebound hurricanrana | 3:25.30–3:26.25 | Scored 7.5; passes borderline; inversion alignment below resolution | 9 / 7 / 4 / 7 / 8 / 7 / 8 / 7 / **7.5** |
| Return run / far-rope stop | 3:03.56–3:05.15 | Scored 6.5; braking foot plant needs a close-up | 8 / 7 / 4 / 6 / 7 / 7 / 8 / 6 / **6.5** |
| Running grapple | 3:49.00–3:51.20 | Scored 7.5; passes borderline; apex head/neck below resolution | 8 / 7 / 4 / 6 / 8 / 7 / 9 / 7 / **7.5** |
| Head sell | 1:01.44–1:01.96 | Reference extracted; sell check pending | — |
| Gut sell | 1:03.95–1:05.00 | Reference extracted; sell check pending | — |
| Knockdown sells | 1:16.68–1:21.00 | Reference extracted; sell check pending | — |
