# Recorded football audio replacement research — 2026-10-25

Owner rejected the synthesized music/effects. The selected **Cool Rock** by
Kevin MacLeod is installed in v0.5.0 under CC BY 4.0; the current source page and
[free licensing terms](https://incompetech.com/music/royalty-free/licenses/) were
checked. Its full 3:29 stereo master is downloaded from Incompetech, normalized
and encoded as Ogg Vorbis. Attribution is accessible through Options → Audio
credits and included in the Mac package with source/modification details.

## Free recorded effects shortlist

Primary Freesound pages were checked for author, recording description and
current license. CC0 permits commercial reuse; CC BY 4.0 requires attribution.
The table is a research shortlist, **not a claim of listening approval or that
these effects have replaced the current match audio**. Public high-quality MP3
previews of the first six are cached for review; full WAV downloads require
Freesound sign-in. Do not describe the MP3 previews as original 24-bit WAVs.

| Role | Source | License | Fit / next check |
| --- | --- | --- | --- |
| Boot impacts | [Soccer Kick.wav — musita182](https://freesound.org/people/musita182/sounds/261267/) | CC0-1.0 | 0.778 s, mono, Zoom H4N |
| Alternative kick | [Soccer Ball Kick — bittermelonheart](https://freesound.org/people/bittermelonheart/sounds/555042/) | CC0-1.0 | 0.738 s, Tascam DR-100 MkIII |
| Net impact | [Soccer net — Luisa_Sanchez](https://freesound.org/people/Luisa_Sanchez/sounds/813410/) | CC0-1.0 | 1.961 s, stereo |
| Referee | [Referee whistle sound.wav — Rosa-Orenes256](https://freesound.org/people/Rosa-Orenes256/sounds/538422/) | CC0-1.0 | 0.535 s, mono |
| Distant stadium bed | [Football stadium.wav — BeeProductive](https://freesound.org/people/BeeProductive/sounds/395592/) | CC0-1.0 | 42.162 s, stereo; recorded a few streets from stadium |
| Close crowd / chanting | [Football-match_Chanting-crowd_Ambience .stereo.wav — Dan_AudioFile](https://freesound.org/people/Dan_AudioFile/sounds/654084/) | CC-BY-4.0 | 14.830 s, stereo omni pair at Wimbledon |
| Goal reaction | [19 Football Crowd - Reaction To Goal.flac — D.jones](https://freesound.org/people/D.jones/sounds/528799/) | CC0-1.0 | 93.173 s, stereo; trim actual reaction after audition |
| Small crowd reaction | [small crowd cheering — HowardV](https://freesound.org/people/HowardV/sounds/264377/) | CC0-1.0 | 24.583 s; about 20 people, indoor hall so reverb may rule it out |

## Recommended integration

1. Replace pass/kick/whistle/net with trimmed mono recorded cues at actual
   contact events. Keep several natural variants and modest gain variation; do
   not detune the referee or chant voices randomly. Use sound-only review clips
   before mixing them into a match.
2. In the arena, use a quiet continuous stereo murmur and separately triggered
   crowd swells for attacks, saves, near misses and goals. Crowd reactions belong
   to the stands as a wide mix, not a short-range point source at the football.
3. Treat chanting as an occasional layer with cooldowns. Audition the Wimbledon
   sample for club-specific words, PA/music and loop quality before shipping.
   For Rovers-specific chants, record original voices with permission; this also
   avoids another club's identity.
4. Kilmore needs a sparse outdoor sideline ambience and a small cheering group,
   rather than a full stadium recording merely turned down. The HowardV clip is
   a candidate, but its indoor reverberation is a material limitation.
5. Crossfade loop seams; retain stereo crowd space, distance-filter on-pitch
   contacts and priority for whistles. Save independent Music/Match/UI volumes.
   Keep menu rock out of live play and recorded match replays.

Reject noncommercial-only clips for shipping, extracted PES/EA game sounds,
club-song recordings and files whose descriptions mention commercial PA music.
Some CC0 stadium recordings still include unrelated music; recording license
alone does not make that music suitable. The source-labelled James Brown PA,
West Ham song and urban fireworks examples are excluded from this shortlist.

## Validation scope

The source/licensing investigation and actual rock installation are complete.
The full 209.4 s stereo Ogg decodes at -18.99 LUFS / -1.88 dBTP. Actual native
Forward+ Movie Maker output is audible, unclipped and silent after Music bus
mute (`music_mix.json`). Menu launch/credits and existing pitch/audio checks pass.
The recorder completes with the known one-resource/ObjectDB teardown warning.
Existing match effects stay original until listening, editing and event/mix
acceptance are done. Cloud decoding, loudness and real AudioServer output can
be checked here; subjective mix on the owner's Mac speakers/headphones remains
an owner acceptance check. This advances BR-024 (24/27), still in progress.
