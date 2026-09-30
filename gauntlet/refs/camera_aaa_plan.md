# Camera work to AAA: entrances to the final bell (plan)

The owner asked: improve the camera during the match, research what WWE 2K26
uses, and plan camera work to AAA standard from the entrances through to the
end of the game. This is that plan. Nothing in it is built yet except where
marked DONE.

## What 2K26 does (research)

**Sources**
- 2K26's own camera settings: Camera Cuts, Dynamic Camera, Camera Shake
  (Off/Low/High), Entrance Camera, Replay Frequency, and a Broadcast camera
  mode used for "Watch Show".
  - Refs: [noobfeed settings guide](https://www.noobfeed.com/articles/wwe-2k26-guide-best-camera-controls-and-gameplay-settings),
    [F4W review](https://www.f4wonline.com/news/wwe/wwe-2k26-review-more-improvements-new-issues/).
- 2K's own notes on the release: "improved depth of field, reduced dead
  zones, and enhanced camera shakes".
  - Ref: [2K Ringside Report coverage](https://www.sportsgamersonline.com/games/wrestling/wwe-2k26-ringside-report-featuring-new-presentation-gameplay-camera-more/).
- The storyboard of a full 2K26 match: [Cody Rhodes vs Randy Orton, steel cage](https://www.youtube.com/watch?v=UFDXaZuZRy4).
  - 115 thumbnails, read shot by shot.
- Entrances: see `entrances.md`, section "2K26".

**What the match storyboard shows**

| Moment | 2K26 shot |
| --- | --- |
| Before the bell | Match card graphic (both men, match type), then a close intro shot of each man in the ring |
| Normal play | A **dynamic ringside camera**, not a distant hard cam. It sits just above the top rope outside the ring, 4–7 m from the pair, and swings around the ring to keep them side-on. It uses 3/4 angles with a corner post in frame, zooming in and out with their distance |
| Strikes, slams | **Impact cuts**: very low, near mat level, bodies filling the frame, under a second. Camera shake on the hit |
| Top rope, climbing | **High angle** looking down at the ring, or low angle up at the man on top |
| Selling, comeback | Waist-up close on the face (long lens, background soft) |
| Pin | **Mat-level shot** with the referee's hand and the count in frame |
| Finish | Winner name card, then **REPLAY**: the finish again from 3–4 angles, slowed |
| After | Winner close, ringside wide, arena wide, hero close with arms out, and a **star rating** ("Instant Classic") |

**What we have today**
- A broadcast hard camera 28 m away in the stands on a long lens.
- It cuts on a fixed timer (7 s / 4.5 s) to a ringside camera.
- One low cut for finishers and one for the three-count.
- Missing: the dynamic player camera, impact cuts, shake, depth of field in
  the match, replays, the winner sequence, the pre-match intro, and any
  settings.

## The plan

### A. Entrances (A1 done; the rest is polish)

- **A1. DONE.**
  - The 2K26 shot order for both men.
  - High shots under the rig.
  - A walk key light, so the wrestlers are lit all the way to the ring.
- **A2. Camera moves inside shots.** 2K26 entrance shots are never locked
  off. Every hold gets a slow push-in, a crane or an orbit, eased, plus a
  touch of handheld drift on the ringside and steadicam shots.
- **A3. Focus.** Depth of field on every close and medium entrance shot,
  focused on the face, with a slow focus pull on the reveal shots.
- **A4. Cut on the music.** Roman gets a beat map like Cody's, so cuts land
  on the beat.
- **A5. Pre-match intro** (2K26 thumbnails 0–2):
  - a match card graphic after both entrances;
  - a close intro shot of each man in his corner;
  - the referee's check;
  - then the stare-down and the bell (already built).

### B. The match camera (the biggest gap)

- **B1. A new default gameplay camera, the 2K-style dynamic ringside cam.**
  - **Position:** just above the top rope (about 2.4–2.8 m), outside the
    ring, 4–8 m from the pair. Distance comes from the existing framing fit.
  - **Angle:** it orbits the ring to stay side-on to the line between the
    wrestlers. It has hysteresis and a soft dead zone, so it doesn't swing on
    every step, and it moves on a spring-damped rig, not snaps.
  - **Obstructions:** it avoids ring posts and cuts around them rather than
    shooting through. A ray test to both men triggers a swing.
- **B2. Keep the broadcast hard camera** as "Broadcast mode" (2K26's
  Watch Show). It is best for watching AI-vs-AI and for recordings.
- **B3. Event cuts** (2K26 "Camera Cuts"), short and returning to the
  gameplay cam:
  - big strike: low 3/4 close, 0.6–0.9 s;
  - slam or bump: mat-level shot timed to the landing. The bump detector
    built for the sound already finds that frame;
  - top rope or dive: a high angle, or low looking up;
  - finisher: a multi-angle sequence (setup close, impact low, reaction
    wide);
  - near-fall: the mat-level ref shot, with the hand and count;
  - kickout: the reaction wide;
  - taunt, sell or comeback: an 85 mm waist-up close with soft background.
- **B4. Camera shake** on impacts: a "trauma" model, strength set by the move
  tier and bump speed. Default Low.
- **B5. Depth of field in the match**, on close cuts only. The gameplay cam
  stays sharp.
- **B6. Cutaways** in quiet moments after a big pop: the crowd, and the sign
  fans when they're up.

### C. The finish and after

- **C1.** The bell, then a **winner card** (reusing the entrance lower-third
  style).
- **C2. Instant replay.**
  - Record the last ~8 s of both men's positions and poses in a ring buffer.
    This is presentation only, so the match stays deterministic.
  - Play the finish back from 2–3 new angles at half speed, with a REPLAY
    badge.
  - Frequency setting: Off / Finish only / Big moves.
- **C3. Celebration sequence:** winner close, ringside wide, arena wide from
  under the rig, and a hero close with arms out.
- **C4. Match rating:** a star rating card from the match's own stats
  (near-falls, reversals, signature moves, length), then back to the menu.

### D. Rules, settings and checks

- **D1. Shot grammar**, enforced in code:
  - stay on one side of the ring for cuts (the 180° rule);
  - no shot under 0.8 s;
  - cut on action;
  - never shoot through posts or ropes;
  - headroom and rule-of-thirds framing.
- **D2. Camera settings menu**, like 2K26's:
  - Camera: Gameplay / Broadcast;
  - Camera Cuts: on / off;
  - Dynamic zoom;
  - Shake: Off / Low / High;
  - Replays: Off / Finish / Frequent.
- **D3. Checks:**
  - a shot-lint probe over a whole AI match: how often wrestlers are blocked
    from view, how much of the frame they fill, cut lengths, time spent
    through the ropes;
  - a storyboard of our match next to the 2K26 storyboard;
  - tests for every rule above.
  - Final videos render on Vulkan (Forward+), the renderer the game ships.

## Recommended order

1. **B1 + B4: the gameplay camera and shake.** It's what a player looks at
   99% of the time, and the biggest step toward 2K.
2. **B3 + B5: event cuts and focus.** Where the match starts to look
   directed.
3. **C1–C4: the finish, replay, celebration and rating.** The payoff moment
   2K26 leans on hardest.
4. **A2–A5: entrance polish and the pre-match intro.**
5. **B2, B6, D1–D3: broadcast mode, cutaways, settings, shot-lint.** These run
   alongside the others.

Each step ends with a rendered storyboard and a short clip sent for sign-off
before the next begins.
