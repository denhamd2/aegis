# Match commentary clips

Commentary is event-driven and serialized through one broadcast voice lane in
`core/audio/match_audio.gd`. The game raises a named event at the moment it
happens; the catalog maps that event to one or more recorded takes. This keeps
audio files independent of gameplay code and lets new MP3 uploads become
drop-in takes.

To add a line:

1. Put the supplied recording in this directory. Keep the original speaker and
   take in its filename, for example `tony_table_break_take_02.mp3`.
2. Add its imported resource path to the matching `COMMENTARY_CLIPS` event in
   `MatchAudio`. Put multiple takes for the same event in the same array; the
   match-seeded selector varies the take without changing gameplay replays.
3. If this is a new situation, add a small `commentary_event_for_*` selector
   beside the other event selectors and call `_queue_commentary()` from the
   signal or cue that owns that situation. Use the narrowest reliable trigger.
4. Add an assertion to `tests/test_match_audio.gd` for the trigger and the
   missing-asset-safe queue behavior. Record owner-supplied audio in
   `assets/audio/CREDITS.md`.

Use the default one-call-per-match policy for unique story beats such as an
entrance reveal, a gunshot or a finisher. For recurring calls, pass
`once_per_match = false` and a cooldown in seconds to `_queue_commentary`; the
voice lane leaves a short breath between queued lines. Commentary stays on the
broadcast voice bus, above the crowd bed. Do not attach commentary playback to
draw-frame gameplay decisions or make it affect a match result.
