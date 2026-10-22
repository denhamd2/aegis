# BR-008 — purposeful, fair attacking flow (22 October 2026)

BR-008, item **8 of 25**, remains in progress for human play-quality and final
animation acceptance. This pass completes its approved cloud chance-creation
gate. The next recommended gameplay work is **BR-009 (9/25)**: refine save
selection, catch/parry outcomes and recovery using the now-repeatable contested
attacks, keeping the existing physical reach and reaction constraints.

## What was demonstrated and fixed

The six-match baseline produced 30/32 total shots, but Beechlawn met the
per-match chance target only 4/6 times. This was fragile attacking flow, not a
consistent home advantage. An initial correction alone still failed (38/17
shots, qualifying 6/4). Both reports are retained beside the final result.

Four targeted regressions failed against the preceding implementation:

- An AI-selected progressive short pass was silently retargeted to a nearer,
  collinear teammate at animation contact. An optional explicit recipient now
  survives windup; its current position/lead is recalculated at contact. An
  unavailable recipient cancels instead of selecting someone else. Existing
  human direction assistance and live boot-contact validation remain.
- A stale last touch claimed possession of a loose deflection four metres away.
  A read-only tactical snapshot distinguishes controlled, incoming, loose,
  contested and stopped phases. Rules retain last-touch ownership for restarts.
  Controlled turnovers, rather than mere deflections, start transition windows.
- With no established owner, equal opposing dribble reaches favored the first
  physics caller. The capped spring now waits for physical separation/contact
  in a <=3 cm opposing tie; an established legal control lease stays stable.
  Same-team ties and marking assignments use formation slots, not node order.
- A directly trailing pursuer forced a forward pass despite an open carry lane.
  Side/front pressure can justify releasing the ball; pursuit from behind
  alone no longer prevents progressing into shooting range.

Both tactical teams read one snapshot at the same editable 0.20 s interval,
with alternating execution order. Unique short-outlet and forward-run targets
preserve centre-back cover. Pass progress/distance/risk weights and support/run
distances are exposed through FootballTuning, shared identically by both sides.
The added `ai_action_chosen` signal is observation only. Shot distance, kick
reach, movement speeds, player ratings and goalkeeper settings are unchanged.

The reverse-actor full-match probe changed outcomes without reversing the
advantage. It did not substantiate processing order as the sole cause.
Mirrored central/wide/pressured/blocked decisions, receiving/turnover checks,
reversed fresh tactical updates, marking and support assignments now have
separate regression coverage. Exact rigid-body traces are not promised across
machines; the match suite gates outcomes, not identical scores or trajectories.

## Full-match acceptance

Six fixed, sunny, 180-second Watch matches: each kickoff side, normal formation
and two symmetric legal starting offsets (1.0 m wider / 1.2 m narrower).
A contested shot means an opposing outfielder was within 5 m at physical kick.
Both sides must make >=2 physical shots and >=1 contested shot in >=5/6 matches,
and each aggregate shot share must be 35–65%. These are test-only thresholds;
there are no runtime shot quotas, forced goals or team-specific boosts.

| Kickoff side, variation | Physical shots H / A | Contested H / A |
| --- | --- | --- |
| Beechlawn Rovers, 0 | 6 / 4 | 6 / 3 |
| Beechlawn Rovers, 1 | 5 / 5 | 4 / 5 |
| Beechlawn Rovers, 2 | 9 / 3 | 7 / 3 |
| Boardeaux, 0 | 7 / 10 | 4 / 5 |
| Boardeaux, 1 | 3 / 3 | 3 / 2 |
| Boardeaux, 2 | 2 / 6 | 1 / 6 |

**Result: 6/6 qualifying for each team; 32/31 total shots (50.8%/49.2%).**
No sampled live-ball stall. Structured reports include control changes,
contact-inferred completed/intercepted passes, final-third entries, selected
AI actions and cancelled contacts. Completion counts are diagnostic lower
bounds: fast redirects or intervening restart events can supersede an arrival.
The snapshots and metrics never move the ball or authorize contact.

## Reproduction and evidence

```sh
python3 games/beechlawn_rovers/tools/check_ai_chances.py build/ai-chances
python3 games/beechlawn_rovers/tools/run_smoke_tests.py ai_pass_commitment_smoke.gd ai_loose_possession_smoke.gd contested_dribble_order_smoke.gd ai_carry_space_smoke.gd tactical_possession_smoke.gd ai_tactical_parity_smoke.gd
```

The six-match gate is part of the separate football Mac release workflow.
All 58 regression invocations (56 distinct scripts) passed locally, including
movement grounding, first-time actions, both keeper controllers, passing/tackles,
throw-ins, discipline/dismissals, physical net contacts and full-match rules.
The suite log is retained here. Native Forward+ attack clips and the build record
are retained beside this brief. Cloud Linux rendering does not establish native
M1 Pro graphics, input feel, sustained 1080p60 or final PES-quality acceptance.
Football Web remains retired; wrestling is unchanged.

Native proof: [broadcast frames](native_attacks.jpg),
[Beechlawn sampled clip](home_attack.mp4), [Boardeaux sampled clip](away_attack.mp4).
Each fixture uses all 22 actual actors and the production Close Broadcast camera;
one attacker starts near the area with a trailing defender. Both sides choose
and execute a physical shot at tick 19. These are controlled attack fixtures,
not the six natural full matches. Simulation runs at 60 Hz; capture samples
10 frames/s at 640x360 through Forward+/Vulkan, llvmpipe LLVM 19.1.7 / Xvfb.
The normal Mac game's animation/frame rate is not established by these clips.

The local Mac archive passed ZIP CRC, bundle identifier, arm64/x86_64 Mach-O
and packed-resource checks. The mirrored tactical test also passed using the
PCK extracted from that archive under Linux Godot, covering the shipped scripts
and resources. This is not execution of the Mac binary. The local archive hash
and verification scope are in [validation.json](validation.json).
