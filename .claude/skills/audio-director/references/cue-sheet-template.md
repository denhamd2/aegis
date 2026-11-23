# Cue sheet template

One row per event, confirmed by its frame. Times are the reference's own
timecode; levels are dB over the crowd bed just before the event (the
analyser's `above_bed_db`).

| Time | On screen | Class | Our family | Hook / move | Over bed | Decay | Centroid | Verdict | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 01:13.7 | powerbomb lands, replay angle | body | `bump` | `_hear_bumps` / `finisher_*` | +16 dB | 0.42 s | 310 Hz | replace | ours stops at 4.8 kHz (optical); the target has a canvas slap at 2–4 kHz over a 70 Hz board thump |

Crowd rows use `crowd.json`:

| Time | Trigger | Rise | Attack | Hold | Our reaction | Proposal |
| --- | --- | --- | --- | --- | --- | --- |
| 02:20.0 | near fall at two | +9 dB | 0.4 s | 2.5 s | `crowd_ooh` +4 dB, `crowd_pop` +3 dB | hold the swell 1 s longer: `CrowdReaction.pop(0.8)` on a two-count |

Chant rows: when it starts (match time or after which beat), length, fade,
and which `CrowdChants` slot it maps to.
