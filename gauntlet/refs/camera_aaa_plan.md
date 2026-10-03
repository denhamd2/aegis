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

## How TV wrestling is actually shot (research)

**The camera plot.** A WWE show runs a **jib, three hard cameras and four
handhelds** on the floor.
- The **hard camera** is the play-by-play master, in the first raised
  mezzanine with the video wall to its left. Wrestlers are trained to "play
  to" it.
- The **handhelds** move round ringside for impact.
- The **jib** gives the sweeping elevated moves.
- Refs: [TV Technology, WWF production](https://www.tvtechnology.com/miscellaneous/a-behindthescenes-look-at-the-wwfs-unique-broadcast-production-challenges),
  [Jim Cornette on the hard camera](https://x.com/TheJimCornette/status/1085161773592920065?lang=en).

**How the director cuts it**
- Cut to the hard cam for scale, to ringside for impact, and to close-ups for
  a moment's emotion.
- Shoot low through the near ropes to break up flat frames.
- Use low-angle power shots for dominance.
- Crash-zoom on a superkick or a kickout.
- Show crowd reactions to confirm that a moment was big.
- Pull focus between foreground and background.
- Use slow motivated push-ins, and a slow-motion replay of anything spectacular.
- Ref: [ten wrestling videography techniques](https://edcreative.xyz/level-up-your-show-10-wrestling-videography-techniques-for-maximum-impact/).

### The face-off

The stare-down is the one place a wrestling broadcast holds still. The
"unresolved staredown" holds a steady angle: no cutting, no zooming, "letting
tension hang in the air". It is built as a short, strict sequence:

| # | Shot | Lens / position | Length |
| --- | --- | --- | --- |
| F1 | **Wide establishing:** the ring, both men walking to centre | Hard cam or jib, under the rig | 2–3 s |
| F2 | **The two-shot in profile:** both faces, noses a foot apart, square to the line between them, eye height | ~50 mm, 3.4 m; ours today (`faceoff_side`) | 3–4 s, **locked off** |
| F3 | **Over-the-shoulder, A → B:** past A's shoulder and ear onto B's face | ~85 mm, background soft | 1.5–2 s |
| F4 | **Reverse, B → A:** the matching shot the other way, same side of the line (180° rule) | ~85 mm | 1.5–2 s |
| F5 | **Extreme close-ups, eyes:** each man's eyes, cut back and forth, faster each time | ~135 mm | 0.8 s each, 2–4 cuts |
| F6 | **Low hero two-shot:** from the mat between them, up at both, the lights flaring behind | ~24 mm, 0.4 m high | 1.5 s |
| F7 | **Back to the wide** as the referee separates them and calls for the bell | Hard cam | to the bell |

- **The rules for it:**
  - Never cross the line between the two men.
  - The only camera movement is a slow push-in on F2.
  - The pace speeds up only in the F5 eye cuts, which is what builds the
    tension.
  - Crowd noise swells under it; the bell resolves it.
- **The 2K26 version:** the storyboard shows the match intro close-ups (a
  close on each man in his corner) right before this.

### Different angles for different moments

Match the camera to the beat, and never cut just because a timer ran out.

| Moment | Angle | Why |
| --- | --- | --- |
| Neutral / circling | Gameplay cam: above the top rope, side-on to the pair, ~35 mm | Readability: both men, their feet and the ropes |
| Lock-up, chain holds | Tighter side-on, 50 mm, slight low | The grapple is the story; faces in frame |
| Strike exchange | Handheld 3/4 low through the ropes; a small shake on each hit | Impact and energy |
| Big strike (superkick, spear, bionic elbow) | Crash-zoom in at contact, 0.5 s | "Inject chaos and urgency" |
| Slam or bump | Mat-level wide, square to the fall, cut on the landing frame | The landing is the payoff |
| Body on the mat, other man standing | Low power shot past the fallen man, up at the standing one | Dominance |
| Top rope, climbing | Jib high over the ring looking down, or low from the mat up at him against the rig lights | Height and danger |
| Rope break, corner | Tight on the hand on the rope / the man in the corner | The rule and the struggle |
| Selling, hurt | 85 mm waist-up, face, background soft | Emotion |
| Comeback fire-up | Slow push-in to a close, then crash back to the wide as he explodes | Build, then release |
| Taunt | Low hero shot, crowd behind | Crowd connection |
| Near-fall | Mat-level at the referee's hand; on the kickout, a crash zoom and a crowd reaction shot | The emotional peak before the finish |
| Finisher (DONE, below) | A three-shot cinematic sequence, then a hold on the aftermath | The only way to win, so it gets the most direction |
| Pinfall 1-2-3 | Mat-level on the hand and the shoulders; the third slap tight | The end of the story |
| Winner | Low hero, arms raised; the arena wide under the rig; the replay | Payoff |

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
- **A6. The face-off sequence F1–F7** (table above), replacing today's single
  profile two-shot. It is timed to the walk-in, the stare and the separation
  beats that already exist (`EntranceDirector` "pair" beats).
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
  - finisher (DONE): only a finisher (Spear, Cross Rhodes, Kenny's) can win
    now; any other cover is kicked out at "2.9". The finisher is shot as a
    sequence, cut on the move's own progress:
    - a tight 3/4 on the attacker's face, ~85 mm, pushing in, crowd soft;
    - a mat-level ~24 mm wide square to the pair, with a camera shake as
      the body lands;
    - a high crane over the downed man;
    - a 1.6 s low hero shot of the winner standing over him, then the
      mat-level three-count;
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

## Status (audited against the code)

| Item | State | Where |
| --- | --- | --- |
| A1 2K26 shot order, high shots under the rig, walk key | DONE | `EntranceDirector` |
| A2 moves inside shots, handheld drift | DONE | `MatchCamera.set_entrance_shot` (push, drift) |
| A3 focus on close entrance shots | DONE | `MatchCamera._entrance_focus` |
| A4 cuts on the music | DONE | Roman and Cody walk cuts are whole beats (tests) |
| A5 pre-match intro: card, check, corner closes | DONE | `EntranceDirector._add_intro` |
| A6 face-off F1-F7 | DONE | `EntranceDirector._faceoff_seq` |
| Entrances: no early tunnel, eye-level walks | DONE | INTRO_PORTAL_MAX, walk lint (tests) |
| B1 dynamic ringside gameplay camera | DONE | `MatchCamera` GAMEPLAY_* |
| B2 broadcast mode | DONE | `CameraSettings.Coverage.BROADCAST` |
| B3 event cuts: strike, slam, finisher sequence, near-fall, kickout reaction, hero, fire-up | DONE | `MatchCamera` Cut, finisher, pin shot |
| B3 dive | DONE | `DiveSpot._frame_shot` (wide; low on the floor for the tope) |
| B4 trauma shake, Off/Low/High | DONE | `MatchCamera._shake`, `CameraSettings.Shake` |
| B5 focus on close cuts only | DONE | `MatchCamera` event shots |
| B6 crowd and sign-fan cutaways | DONE | `MatchCamera._watch_sign_fans` |
| C1 winner card | DONE | `PostMatch` |
| C2 finish replay | DONE | `PostMatch` + `ReplayBuffer` |
| C2 frequent replays (big moves mid-match) | DONE (was a gap: the menu offered it, nothing read it) | `InstantReplay` |
| C3 celebration sequence | DONE | `PostMatch.CELEBRATION` |
| C4 match rating | DONE | `PostMatch.match_rating` |
| D1 shot grammar (180, min shot 0.8 s) | DONE | `MatchCamera.MIN_SHOT`, hard-cam side |
| D2 camera settings menu | DONE | title screen CAMERA |
| D3 shot lint probe | DONE | `tools/probe/shot_lint.tscn` |
