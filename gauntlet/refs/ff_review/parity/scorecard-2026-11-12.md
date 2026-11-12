# Parity scorecard: our video-matched moves vs the AEW Fight Forever tutorial (12 November 2026)

**Owner's brief.** The owner, 12 Nov: "review the work we did over the past few
days on moves ... meant to replicate those from this reference video ... score
each of ours out of 10 in terms of parity with the reference -- e.g. speed,
cadence, smooth motion, like for like movements -- and create a plan for any
improvements needed."

**Reference.** "AEW Fight Forever Controls - Everything You Need To Get Started!
(Full Tutorial)", 12:37, 1280×720, 60 fps (owner's Drive copy).

- Each move was cut at 15 fps with timestamps burned in: `ref_<move>.jpg` in
  this folder.
- Frame counts below are read off those cuts, at 60 fps, so ±2 frames.

**Ours.**
- Timings come from source: `strike_*.tres` startup and active frames,
  `strike_recipes.gd` lengths, `paired_recipes.gd` trajectory lengths, and
  `wrestler_controller.gd` whip constants.
- Poses come from the committed per-move sheets in `../moves/`, which have the
  video and our rows stacked.

## Factors (each /10)

| Factor | What it scores |
| --- | --- |
| **Speed** | Frames from first movement to contact, and the total, against the reference. Within 10% scores 9–10; each further 15% costs about 1. |
| **Cadence** | The rhythm: wind-up, hold, contact and recovery shares, and any skip, hop or pause the reference has. |
| **Smooth** | No snaps, pops or floaty easing. Ours all pass `test_clip_cadence`, the per-frame bone-jump gate; this column is otherwise judged from the sheets. |
| **Like-for-like** | The same move: limbs, arc, stance, travel, airborne or grounded, and the defender's path. |
| **Contact/sell** | The defender's reaction against the reference: timing, direction, fall. Our strike sheets show only the attacker, so for strikes this is scored from the reaction clip the game plays. |

Overall is the mean of the five, rounded to 0.5.

## Scores

| # | Move (ours) | Ref | Ref: start→contact / total | Ours: start→contact / total | Speed | Cadence | Smooth | Like | Sell | **Overall** |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | High hook (`strike_hook`) | 1:01.30–1:01.90 | ~9 f / ~36 f | 11 f / 42 f | 8 | 7 | 7 | 4 | 4 | **6.0** |
| 2 | Front kick, body (`strike_front_kick_body`) | 1:03.63–1:05.0 | ~19 f / ~40 f (+60 f sell) | **32 f** / 56 f | 4 | 5 | 7 | 5 | 5 | **5.0** |
| 3 | Turning back kick, body | 1:05.73–1:06.70 | ~20 f / ~40 f | 24 f / 56 f | 8 | 7 | 7 | 6 | 5 | **6.5** |
| 4 | Clinch knee, body | 1:10.73–1:11.80 | ~16 f / ~45 f | 21 f / 46 f | 7 | 6 | 7 | 4 | 5 | **6.0** |
| 5 | Running flying knee | 1:12.80–1:13.73 | ~16 f / ~56 f | **25 f** / 68 f | 5 | 6 | 7 | 7 | 5 | **6.0** |
| 6 | Side kick knockdown | 1:16.53–1:17.27 | ~16 f / ~44 f | **26 f** / 64 f | 5 | 6 | 7 | 6 | 5 | **6.0** |
| 7 | Turning back kick knockdown | 1:19.80–1:20.80 | (a different move, see below) | 23 f / 60 f | 3 | 3 | 7 | **1** | 3 | **3.5** |
| 8 | Irish whip setup (`whip_setup`) | 3:01.70–3:02.50 | swing → release ~48 f | 1.2 s (72 f) | 7 | 6 | 7 | 6 | 6 | **6.5** |
| 9 | Whip runner + rope absorb | 3:02.47–3:03.60 | ~5 m/s; absorb ~16 f | **9 m/s; hold 30 f** | 3 | 4 | 7 | 6 | 6 | **5.0** |
| 10 | Return run, far-rope stop | 3:03.50–3:05.15 | ~4.5 m/s rope to rope | 7.65 → 7.0 m/s | 4 | 6 | 7 | 7 | 6 | **6.0** |
| 11 | Rebound slam (`rebound_slam`) | 3:17.85–3:20.10 | catch → mat ~99 f | 98 f | 10 | 8 | 7 | 6 | 7 | **7.5** |
| 12 | Rebound hurricanrana | 3:25.30–3:26.40 | takeoff → mat ~52 f; ~66 f total | 80 f | 7 | 7 | 7 | 7 | 7 | **7.0** |
| 13 | Running grapple inverted drop | 3:50.00–3:51.20 | arrival → mat ~69 f | **2.2 s (132 f)** | 4 | 5 | 7 | 6 | 6 | **5.5** |

**Batch average: 5.9 / 10.** The 9–10 Nov scores averaged 6.9, but that
reviewer worked from text and never saw the video beside our frames.

## What the side-by-sides show

### Speed: ours is consistently slow to the hit
Five of the seven strikes take 25–70% longer than the reference to reach
contact:
- front kick: 32 frames against about 19;
- side kick: 26 against about 16;
- flying knee: 25 against about 16;
- clinch knee: 21 against about 16;
- hook: 11 against about 9.

The reference's wind-ups are short and explosive. Ours load slowly.

### The whip runs at double speed
- The whip launches at 9 m/s, and the return run at 7–7.65 m/s. The
  reference crosses the 6 m ring in about 1.35 s, which is about 4.5–5 m/s.
- The code says why: `IRISH_WHIP_LAUNCH_SPEED` was "chosen" because "no
  reference footage found ... confirm/retune via later reference capture"
  (`wrestler_controller.gd:268`).
- The rope absorb holds for 0.50 s. The reference's lean into the ropes lasts
  about 0.27 s.
- This one is seen in every match.

### Move 7 is not the reference's move
- At 1:20.26 Kenny swings his arm, hooks the man round the neck and drives him
  back-first to the mat: an arm-hook takedown with both men going down.
- Ours is a turning back kick to a standing knockdown. Like-for-like fails
  outright.

### Like-for-like gaps on the others
- **Hook:** the reference is a full lunge. The back leg stretches out
  straight behind and the body travels about half a metre into the punch.
  Ours is a small step-and-hook.
- **Front kick:** the reference skips into it, arms flung up, both feet off
  the mat (1:03.70–1:03.77). Ours is a grounded chamber and kick.
- **Clinch knee:** the reference is a jumping knee that extends into a
  push-kick, the attacker airborne (1:10.80–1:11.13). Ours is a grounded knee.
- **Side kick knockdown:** the reference's chamber is high, at chest height,
  with a deep lean back. Ours is lower.
- **Rebound slam:** the reference lifts the man high over the shoulder before
  the slam. Ours carries him low.
- **Running grapple:** the reference is quick: hook, spin and flip. Ours takes
  twice as long, and the lift is slow.

### Sells
- In the reference the defender doubles over and holds it for about 0.5 s
  after a body kick or knee. A knockdown kick puts him flat on his back
  within about 28 frames.
- Our strikes play generic reaction clips. None of them is keyed to its
  strike's reference timing.

### What is right
- The rebound slam's timing is within 1 frame of the reference.
- The rana's shape (legs round the head, the flip, both down) matches.
- The body back kick's speed is close.

## Improvement plan

Ranked by gap × how often the move is seen in a match. Effort: S is under
half a day, M about a day, L a few days.

| Pri | Fix | Moves | Where | Effort |
| --- | --- | --- | --- | --- |
| 1 | **Whip speed to the reference.** Launch 9 → 5.0 m/s; rope rebound out about 5 m/s; return run about 4.5–5 m/s; rope-absorb hold 0.50 → 0.27 s. Re-check `IRISH_WHIP_MAX_TICKS` (2.0 s) against the slower crossing, the rebound-strike meet distance and the AI's whip timings. | 9, 10, and every whip, rebound and rope run | `wrestler_controller.gd` (`IRISH_WHIP_LAUNCH_SPEED`, `ROPE_LOAD_HOLD_SECONDS`, `_rope_load_speed`, the return run); `Whip_Run` regenerated at the new speed so the feet match | M |
| 2 | **Re-author move 7 as the reference's arm-hook takedown.** Both men go down, the defender back-first. Keep the turning back kick as a separate move, or drop it from the pools. | 7 | `wrestling_clips.py` (a new paired clip), `paired_recipes.gd`, `strike_turning_back_kick_knockdown.tres` or a new MoveDef, `roster.gd` pools | M |
| 3 | **Strike wind-ups cut to the reference's frame counts.** Front kick 32 → 19, side kick 26 → 16, flying knee 25 → 16, clinch knee 21 → 16, hook 11 → 9. Re-key, don't just speed up: shorter loads, the same recoveries. | 1–6 | `wrestling_clips.py` strike keys; `startup_frames` in each `.tres`; `strike_recipes.gd` seconds | M |
| 4 | **Running grapple to about 1.2 s.** Quicker hook-and-spin, a faster flip; keep the head-first landing. | 13 | `paired_recipes.gd` `running_grapple_inverted_drop`, its clips | S–M |
| 5 | **Like-for-like re-keys:** | | `wrestling_clips.py` | M |
| | - hook lunge (back leg extended, about 0.5 m of travel); | 1 | | |
| | - front kick skip-hop with the arm fling; | 2 | | |
| | - clinch jumping knee into the push extension; | 4 | | |
| | - side kick chamber higher, with the lean back; | 6 | | |
| | - rebound slam lifted higher over the shoulder. | 11 | | |
| 6 | **Strike sells keyed to the reference.** Head snap for the hook; a 0.5 s fold-over for body kicks and knees; flat on his back within about 28 frames for knockdowns. Hit-stop on contact (`impact_presentation_plan.md`). | 1–7 | the reaction clips in `wrestling_clips.py`, the `MoveDef` reaction fields, `CombatSystem` hit-stop | M–L |
| 7 | **Rana tightened** from 80 frames to about 66. | 12 | `paired_recipes.gd`, its clips | S |
| 8 | **Review tooling.** Strike sheets render with the defender (`strike_pair_shot`), so sells can be scored; sheet frames sort numerically (they sort as text today: 00, 100, 14…); a per-frame bone-speed trace for the Smooth column. | all | `tools/anim/contact_sheet.sh`, `tools/probe/strike_pair_shot.gd`, `tools/probe/motion_cadence.gd` | S |
| 9 | **Not built yet:** the 3-hit combination (1:26.07, 1:26.54, 1:26.62) and the head, gut and knockdown sells as their own clips. | new | `wrestling_clips.py`, `strike_recipes.gd` | M |

**Process for each fix:**
1. Re-key or re-time.
2. Bake (`wrestling_clips.py` → import → paired poses and moves → fit → strike clips).
3. Render a side-by-side against the `ref_*.jpg` cut.
4. Re-score here.
5. Run `test_clip_cadence`, `test_pose_lint`, `test_pair_clearance` and `test_clip_authoring_gate` (re-pin).
6. Deploy.

**Target:** every move at 8 or above, with Speed and Like-for-like at 9 or above.
