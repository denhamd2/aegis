# Game audio

The owner selected **Cool Rock**, Kevin MacLeod, on 2026-10-25. Its full
instrumental recording replaces the synthesized menu loop. The shipped Ogg
retains stereo, is normalized to -19 LUFS / -2 dBTP and loops as a complete song.
Music is restricted to the title/options and pre-match presentation. The saved
Music bus remains independent of Match and UI.

`CREDITS.txt` is shipped and shown through Options → Audio credits.
`LICENSE-CC-BY-4.0.txt` links the legal terms; `provenance.json` records source,
license, hashes and changes.

Twenty edited recorded clips replace the synthesized match effects. Mono
48 kHz WAVs cover field contact, grass steps and whistles; stereo Oggs cover
the two distinct venue beds, crowd reactions, intermittent stadium chants and
rain. Kilmore uses European park ambience and outdoor small-group applause;
it never receives a mass-stadium chant. Only the UI click remains synthesized.

Freesound sources are the publicly downloadable HQ MP3 previews, not the
original WAV uploads. BigSoundBank applause uses its public original WAV.
`provenance.json` records exact downloads, licenses, hashes and per-clip edits.
Header/glove contact is adapted ball-contact Foley; the post is a recorded
metal-pipe strike. These are not claims of recordings of those exact events.

`python3 tools/build_recorded_audio.py SOURCE_DIR` recreates the edited bank
from hash-verified local downloads using numpy, scipy and ffmpeg. Loops have
a baked equal-power wrap; speech/whistles are never pitch-randomized in play.
The 12 field voices prioritize strikes/whistles above steps; crowd/reaction/
chant are independent 2D broadcast layers. Match events drive reactions,
with cooldowns, replay isolation and fast crowd ducking for whistles.

`tests/recorded_audio_smoke.gd` checks live 11v11 wiring at both venues.
`tools/capture_recorded_audio.py OUTPUT` records real native AudioServer
output from broadcast and close-up listening positions, checking clipping,
event audibility and bus mute. This is signal QA, not subjective approval;
listening on the target Mac remains required. See the production brief in
`docs/art_briefs/recorded_match_audio_2026_10_26/`.

`tools/synthesize_match_audio.py OUTPUT` regenerates historical source clips into
an explicit scratch directory, without overwriting this licensed catalogue.
