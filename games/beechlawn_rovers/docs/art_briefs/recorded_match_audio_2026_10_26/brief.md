# Recorded match audio — BR-024 (24/27)

The owner selected Cool Rock and authorized continuing the replacement of the
synthetic match audio with free recorded football effects, crowds and chants.
This slice is audio/presentation only; player assets, authoritative ball/player
physics, tactics, scoring and the fixed 60 Hz simulation are unchanged.

## Installed bank

Twenty edited recordings/recorded Foley derivatives replace all synthetic match
effects. Only the original UI click remains. The full Cool Rock song and its
music policy are unchanged.

| Content | Recording and license | Game use |
| --- | --- | --- |
| Boot contact | [musita182](https://freesound.org/people/musita182/sounds/261267/), [bittermelonheart](https://freesound.org/people/bittermelonheart/sounds/555042/) — CC0 | Two strike/pass takes; filtered head/glove Foley derivatives |
| Grass steps | [OwlStorm / Ashe Kirk](https://freesound.org/people/OwlStorm/sounds/151228/), [second take](https://freesound.org/people/OwlStorm/sounds/151230/) — CC0 | Alternating subtle near-field steps |
| Whistle | [Rosa-Orenes256](https://freesound.org/people/Rosa-Orenes256/sounds/538422/) — CC0 | Single referee whistle and edited triple full-time whistle |
| Net | [Luisa_Sanchez](https://freesound.org/people/Luisa_Sanchez/sounds/813410/) — CC0 | Physical net-contact rustle |
| Post Foley | [Anthousai](https://freesound.org/people/Anthousai/sounds/406556/) — CC0 | Recorded metal-pipe strike with retained decay |
| Stadium murmur/reaction | [BeeProductive](https://freesound.org/people/BeeProductive/sounds/395592/) — CC0 | Quiet distant bed and a separate short rise |
| Stadium goal | [D.jones](https://freesound.org/people/D.jones/sounds/528799/) — CC0 | Roar excerpt, allowing the ball/net sounds to remain separate |
| Stadium chant | [Dan_AudioFile](https://freesound.org/people/Dan_AudioFile/sounds/654084/) — CC BY 4.0 | Intermittent field-recorded football chant; not a club-specific bespoke recording |
| Park ambience | [ValentinPetiteau](https://freesound.org/people/ValentinPetiteau/sounds/563547/) — CC0 | European park birds/light wind, rather than an attenuated stadium |
| Park supporters | [Joseph SARDIN / BigSoundBank](https://bigsoundbank.com/applause-about-25-50-people-5-s0816.html) — CC0 | Outdoor small-group applause, longer for goals, shorter for chances |
| Rain | [SpinOpel](https://freesound.org/people/SpinOpel/sounds/772244/) — CC0 | Rain preset only, at either venue |

The bank adds about 2.5 MB. Freesound downloads are their public HQ MP3 previews;
they are **not** the original 24-bit WAVs described on some source pages.
BigSoundBank uses its public original stereo WAV. No extracted PES/EA audio,
noncommercial-only recordings, known PA music or club-song candidates are used.
Earlier research also rejected fireworks/vuvuzelas, gym/hall reverb and several
club-specific samples. The low-quality two-person phone cheer was not shipped.

Exact downloaded/shipped hashes, source links, license notices, excerpt times,
filtering, normalization, channel layouts and baked loop wraps are in
`assets/audio/provenance.json`. The full notices ship and are accessible through
Options → Audio Credits in a bounded, scrollable dialog. Rebuild from local
hash-verified inputs with `tools/build_recorded_audio.py SOURCE_DIR`.

## Runtime behavior

Twelve spatial field voices present real typed contacts. The two boot/step takes
alternate without using the gameplay RNG. Cooldowns use presentation elapsed
time, including Movie Maker, instead of host wall-clock speed. Strikes, post/net
and whistles outrank steps when the pool is full; whistle/chant pitch stays fixed.

Crowd bed, reaction, chant and rain use independent broadcast layers. Goals can
preempt lesser reactions, while save/chance cooldowns prevent repeated roars.
Own goals follow the awarded team. Shot attempts raise stadium attention;
subsequent goal-kick/corner restarts can trigger a missed-chance response. Throw-ins
and ordinary goal kicks no longer receive arbitrary referee whistles.

Stadium chants first become eligible after 28 seconds of live play, then wait
42–57 seconds between starts. Reactions and whistles suppress them with a fast
fade; presentation/replay/full-time cannot start new chants. Park matches never
start stadium chants. Full time has a distinct whistle; menu return stops all
match layers and disconnects the old event source. Replayed contacts cannot
trigger duplicate live reactions.

## Verification and limits

- `bank_validation.json`: source/shipped hashes, finite unclipped decodes and
  boundary continuity for all three baked ambience loops.
- `recorded_audio_smoke.gd`: actual 11v11 event wiring at both venues, recorded
  variants/cooldowns, full voice pool priority, ducking, chant spacing, rain,
  own goals, replay rejection, full-time and teardown; ball/clock/score invariance.
- Existing pitch/audio, title, replay/results and presentation checks retain
  normal match/menu behavior. Package CI runs the new event check against both
  source and the actual exported PCK.
- `tools/capture_recorded_audio.py OUTPUT` captures two real native Forward+
  AudioServer mixes through an isolated 3D listener: broadcast distance 31.6 m,
  close-up 5.4 m. It checks field/whistle/goal audibility, clipping, venue chant
  selection and silence when Music/Match/UI buses are muted. This deliberately
  avoids unrelated stadium/player shader work; it is not a full-match render.

Source descriptions and a local tiny.en speech-recognition pass did not yield
an intelligible transcript from the selected crowd clips. That is not proof of
wordless content or an ear audition. This session cannot listen to audio.
Automated signal/routing checks do not establish pleasing timbre, exact broadcast
balance, perceived repetition or M1 latency/performance. BR-024 remains in
progress pending target-Mac speakers/headphones review; broader reactions and
future licensed commentary remain separate acceptance work.
