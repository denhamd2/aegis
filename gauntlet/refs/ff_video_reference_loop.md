# Video-reference move loop (9 November 2026)

Source: `AEW Fight Forever Controls - Everything You Need To Get Started!`
(720p60, 12:36). Move names and inputs are shown on the in-game move-list
screens; the tutorial categories are shown top-left.

## Per-move workflow

1. **Extract the reference.** Record the move name, category, input, timestamp,
   duration in frames at 60 fps, impact frame, attacker and defender key poses,
   sell, camera/effects and any sound cue. Save six to eight reference frames.
2. **Author in our game.** Build the attacker and defender clip, MoveDef,
   recipe and root trajectory; add the impact, sell and recovery beats; match
   the reference speed, power and effects. Keep both roles authored and the
   pair clearance within limits.
3. **Bake and render.** Bake the GLB, import, rebuild paired moves/poses,
   run the focused gates, and render a per-move sheet with a beat on the
   reference impact frame.
4. **Art-director review.** DeepSeek V4 Pro scores the move on:
   animation, poses, effects, selling, attacking, realism, speed and power.
   Each factor is /10, with an overall /10. It must give specific, actionable
   feedback tied to beats and reference frames.
5. **Improve and repeat.** The main agent applies the feedback, re-bakes,
   re-renders and re-scores. Repeat until the overall score is 10/10 with no
   factor below 9/10.
6. **Record and move on.** Add the reference frames, sheet, score history and
   verdict to `ff_visual_qa_ledger.md`; commit and deploy the batch; only then
   start the next move.

## Scoring rubric

| Factor | What the art director judges |
| --- | --- |
| Animation | timing, spacing, arcs, overlap, continuity, weight |
| Poses | silhouette, anatomy, contact, readability at impact |
| Effects | impact/deformation, camera, particles, shake, sound cue |
| Selling | defender reaction, rebound, settle, damage read |
| Attacking | attacker intent, drive, follow-through, recovery |
| Realism | physics, grip, leverage, balance, no floating |
| Speed | match the reference's frames from start to impact to recovery |
| Power | sense of mass and force at the lift and the impact |

## Rules

- The reference is the authority for timing and pose, not a generic move.
- Do not call a move complete without its reference frames, per-move sheet,
  and a fresh score.
- The art director cannot see images; it works from the visual reviewer's
  frame-by-frame evidence and the reference data. Keep that evidence explicit.
- If a move needs a new effect or camera cue that the game does not have,
  build it as part of the same batch rather than substituting a weaker cue.
- Preserve the existing move's gameplay wiring and tier unless the reference
  shows a different input/context.
