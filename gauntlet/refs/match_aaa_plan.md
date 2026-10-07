# The match vs WWE 2K26: strikes, selling, smoothness, camera

The owner, after playing:
> The punches and kicks didn't look like wrestling punches and kicks, they didn't look good.
> The animation again looked a bit stop motion like at certain parts.

**Sources**
- The owner's 2K26 Cody vs Roman (`raw/video/cody_roman_2k26.mp4`):
  - the strike exchange at 598-626 s, sampled at 2 fps and at 10 fps around single punches (599-601 s, 608-610 s).
- Our strike clips rendered side-on (`tools/probe/clip_shot`).
- `tools/probe/motion_cadence -- --match`.
- 2K26 reviews (MP1ST, Roundtable Co-op, Gaming Nexus):
  - reversals are tied to stamina;
  - transitions between strikes, grapples and counters are smoother;
  - heavier reactions to big blows;
  - start-of-match actions, including trading blows.

## What 2K26 does

**Strikes.**
- **The punch is a worked, looping right hand.**
  - The right shoulder loads back and high, with the fist cocked by the head; the left hand often reaches out to the other man's shoulder.
  - The lead foot steps in, the hips and shoulders turn through, and the fist comes *round* to the jaw with the elbow bent. The arm finishes across the body.
- **Distance.** They throw from almost chest to chest.
- **Hands between shots.** Open and low, never a boxer's guard at the chin.
- **Body shots fold a man over:** a gut punch, or a kick to the gut that is a sole driven into the stomach with the kicker staying over it.

**Selling.**
- The head snaps, he gives a step, and he stays bent or holds his jaw for about 1-1.5 s.
- In a run of blows the reactions build, and he never springs back to a stance between shots.

**Camera.** One gameplay camera for the whole match (13 cuts in about 475 s; `cody_roman_2k26.md`), just above the top rope, panning with the pair. It shakes on big impacts, not on every blow.

## What ours did (measured)

| Area | Ours | Cause |
| --- | --- | --- |
| Stop motion | One man's drawn pose held on 111-118 of 240 frames at 120 fps (`motion_cadence --match --rough`) | The entrance fix (9fd047f) drew poses every frame, but at the bell the mixer goes back to the 60 Hz physics tick (gameplay reads bones there), so on a 120 Hz display every match pose was held for two frames, unevenly. The grip IK targets were set once a tick in the world, so locked-up hands stepped too. |
| Hitches | 3-tick freeze on every cross and both kicks | Hit-stop at strength ≥ 0.6. 2K26 has none on an ordinary blow. |
| Punches | A boxer's jab and cross, straight from a fists-at-the-chin guard | Authored as boxing (`Strike_Jab`, `Strike_Forearm`), starting and ending on STANCE. |
| Kicks | A karate front kick: body thrown back 14°, arms flung behind | `Strike_Kick` and `Strike_Kick_Heavy`. |
| Selling | 0.33 s, then straight back to the stance | `HIT_REACT_TICKS` 20, with the clip ending on STANCE. |
| Camera | Already one follow camera with no cut on a strike (B3) | Small gaps only: shake on every blow. |

## What was done

1. **Smooth in the match.**
   - Changes:
     - `Inertializer.interpolate_pose` draws the animation layer between the last two tick poses by the physics interpolation fraction, one tick behind, the way physics interpolation draws the root. The tick pose under it is untouched, so gameplay and replays are unchanged.
     - The grip IK targets are drawn the same way (`WrestlerController.draw_grip_between_ticks`).
     - `MatchSmoothing.snap` cuts both.
   - Measured, held frames at 120 fps: 111/118 → 0/14. The 14 are one real still moment: a hold whose hands genuinely grip still for 7 ticks.
   - Hit-stop now applies only at the top of the scale (signatures, the big boot), for 2 ticks.
2. **Wrestling strikes** (`wrestling_clips.py`). Every strike starts and ends on READY, the open-handed stance:
   - **`Strike_Forearm`** (strike_cross) is the worked right hand: load, step, turn, round to the jaw, across the body.
   - **`Strike_Jab`** is a worked left round to the jaw.
   - **`Strike_Kick`** is the kick to the gut.
   - **`Strike_Kick_Heavy`** is a big boot that steps through.
   - **New `Strike_Gut_Punch`** for Roman.
   - Contact frames are unchanged, so the frame data holds. Contact points were re-measured.
3. **Selling.**
   - The hit reactions now end hurt (`HEAD_HURT`, `GUT_HURT`).
   - Left alone, he plays `Sell_Head` or `Sell_Gut` for `SELL_TICKS` (40) more.
   - An AI man waits his sell out, and anything a player does cuts it short.
   - A third blow landing inside a sell rocks him (`FLURRY_STUN_AT`, STUNNED).
4. **Camera:** shake only on heavy blows.
