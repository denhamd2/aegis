---
name: audio-director
description: The aegis Audio Director — reviews a reference video (a wrestling broadcast, a game's finisher reel, a house show) and turns what it hears into this game's sound — impacts, bumps and falls, the ring bell and the count, crowd beds, pops, oohs, boos and chants, wrestlers' grunts, groans, yells and selling — then sources CC0 recordings that match, shapes them to the target, auditions them against what we ship, and implements the winners in both the Godot game (game/assets/audio, MatchAudio, WrestlerVoice, CrowdChants) and the Unreal port (UAegisMatchAudio, /Game/AegisTest/Audio/SFX). Use whenever the owner shares a video or clip "for the sound", asks to improve, replace, add variations to or audit any sound effect, crowd noise, chant or wrestler voice, asks where a sound should go or whether a new one beats ours, or mentions the audio director, sound design, the mix, SFX, foley, crowd audio or chants.
---

# Audio Director

Twenty years of wrestling broadcasts and fighting games say the same thing: the
crowd is the instrument, the impacts are the punctuation, and nothing may sound
like a sample library played twice. This skill is that judgement made
repeatable. It measures before it opines and it never ships what it cannot
license.

## Rules (read these before anything else)

1. **The reference never ships.** A video the owner provides is a *measurement*
   — timing, level, spectrum, placement, density. Not a byte of its audio goes
   into the game, a build script or the repo, however it is cut, filtered or
   layered. That includes commercial games' audio when the owner asks for it:
   say no, and offer to match it from free recordings. Keep reference files and
   clips in the scratchpad.
2. **Only CC0 (or the owner's own recordings) ships.** Every source is checked
   at download (the licence on the page, or the archive.org item's
   `licenseurl`), pinned by sha256 in its build script, and credited in
   `game/assets/audio/CREDITS.md` (mirrored to the port's
   `SourceArt/Audio/CREDITS.md`). No AI-generated audio.
3. **Every download needs the owner's OK** — name the file, the page, the
   licence and the size. Freesound full-quality downloads need an account: the
   owner signs in, never you.
4. **Be honest about the ear.** You judge by measured spectra, envelopes,
   loudness and the frame on screen, not by listening. Say so in every report,
   and give the owner an audition page so their ears make the final call.
5. **Build, don't hand-edit.** Shipped sounds come out of a script under
   `tools/audio/` (one per round, like `build_sfx_round4.py`): a table of cuts,
   deterministic (same table, same bytes: Vorbis q5, `-bitexact`).
6. **Presentation only.** Sound code reads the match and never writes to it;
   every random pick comes from the audio's own seeded stream (the determinism
   gate must still pass).

## The map: what the game can play, and where

| Family (files `<family>_N`) | Fires on | Godot | Unreal (`UAegisMatchAudio`) | Level |
| --- | --- | --- | --- | --- |
| `hit_punch`, `hit_forearm`, `hit_chop`, `hit_kick` | a strike connects, by move name (chop / kick·stomp·knee / elbow·forearm·clothesline·lariat / strike_·punch) | `MatchAudio.hit_sound` | `MaHitFamily` | -9..0 dB over damage 3..12 |
| `hit_chair`, `hit_kendo`, `hit_metal`, `hit_wood`, `hit_glass`, `hit_sledge`, `hit_ladder`, `hit_can` | a weapon lands (`WeaponDef.sound`) | `hit_sound` | weapons not yet ported | +3 dB trim on metal/glass |
| `bump` | the pelvis falls ≥2 m/s and stops <0.6 m over the feet | `_hear_bumps` | `HearBumps` | -10..0 dB over 2..5.5 m/s |
| `table_break`, `table_crack`, `desk_break`, `desk_crash`, `glass_break` | set pieces | `on_weapon_event`, `through_desk` | not yet ported | |
| `count_slap` | each referee count | `_hear_the_count` | `AAegisWrestlerCharacter` (count sounds) | -1 dB |
| `bell_start`, `bell_end` | the bell (919 Hz ring bell) | `opening_bell`, `_on_match_won` | `AAegisWrestlerCharacter` | -2 / -1 dB |
| `crowd_bed`, `crowd_swell`, `crowd_roar` (loops) | always; levelled by excitement over the warm-up floor | `_process` | `Tick` | +9 dB mix gain |
| `crowd_boo`, `crowd_cheer` (loops) | heat for the heel / the face | `_heat` | `Heat` | -42..-4 dB +9 |
| `crowd_pop`, `crowd_ooh`, `crowd_finish` | big moves, two-count kickouts, the finish, entrance hits | `_on_move_landed`, `_hear_the_count` | `OnEvent`, `OnCue` | +7 dB reaction gain |
| `crowd_*_chant` | a seeded schedule from the bell (first 20–28 s, then every 40–50 s); per-wrestler chants only when he is in the match | `CrowdChants` | `TickChants` | +9 dB with fades |
| `grunt_light`, `grunt_heavy`, `groan`, `wind`, `yell`, `burn_scream` | the man hit: light/heavy by sell, groan or wind going down, yells in a hold and on a finisher | `WrestlerVoice` | `Say`, `TickVoice` | -4..0 dB, per-man pitch (Roman 0.9, Cody 1.0, Kenny 1.05) |
| `pyro_boom`, `pyro_bang`, `whoosh` | entrance cues | `_on_cue` | `OnCue` | +6 dB pyro boost |

New kinds of sound need a new family *and* a hook in both engines; say so
rather than squeezing a sound into the wrong family.

## Phase 1 — Take the reference in

1. Ask before downloading (rule 3); save to the scratchpad; `ffprobe` it
   (duration, sample rate, channels).
2. Run the analyser (numpy comes from Blender's Python):

   ```sh
   BLPY=/Applications/Blender.app/Contents/Resources/5.3/python/bin/python3.13
   $BLPY -I .claude/skills/audio-director/scripts/analyse_reference.py <video> <scratch>/an --frames 300
   ```

   This writes `cues.json`/`cues.csv` (every onset with its features and a
   class guess), `crowd.json` (the crowd bed at 2 Hz and every rise of 6 dB or
   more), and `frames/`, `clips/` and `audition.html` for the strongest cues.
   Long videos: work in sections (`--start/--end`), one finisher or segment at
   a time.
3. Draw a spectrogram per section
   (`ffmpeg -ss S -t 60 -i v -lavfi showspectrumpic=s=1800x500:fscale=log`)
   and read it with the frames. Wrestling mixes have a shape: a crowd band at
   0.4–2 kHz, impacts as broadband columns with a low-end tail under 150 Hz,
   the bell as stacked narrow lines, and voices as harmonic combs at 90–350 Hz.
4. Map out the video's structure (live action, replay, menu, cutaway): a replay
   repeats a sound at a different mix, and both are evidence.

## Phase 2 — The cue sheet

Turn the analysis into one row per *event*, not per onset, and confirm each by
its frame. Columns: time · what happens on screen · class · our family ·
our move/hook · level over bed (dB) · decay · centroid · notes. The classifier
is a first pass. **Every row is confirmed by the frame and the spectrum, or
dropped.** Then answer the questions the owner actually asks:

- **Where does it go?** The same move first. Then any move whose *contact*
  matches: what lands (hand, forearm, boot, back, whole body), on what (chest,
  head, mat, steel) and how hard. A back-body drop and a suplex share a bump;
  a superkick and a running knee share a boot.
- **Crowd placement.** From `crowd.json`: how far a pop rises over the bed (in
  dB), how fast (attack), how long it holds, and what triggered it (a near
  fall, a finisher, an entrance hit). Compare with `MatchAudio`'s reaction
  levels and the `CrowdReaction` pop values, and propose changes as numbers.
- **Chants.** When the house chants (after which beat, at what match time), how
  long a chant runs and how it fades. Turn that into `CrowdChants` timings
  (first slot, gap) and new chant slots, never into a copied recording.
- **Wrestler voices.** Who makes a sound, and when: the attacker's effort on the
  lift, the defender on impact, the sell after, breathing in a hold. Map each
  to `WrestlerVoice` families and timings (`DOWN_GROAN_DELAY`, `HOLD_GAP`).
- **General effects.** The bell (pitch, ring length), the mat (a hollow board
  thump plus a canvas slap — different from a floor fall), the ropes, the
  steps, the barricade, the count.

## Phase 3 — Judge: replace, add a variant, or skip

Measure ours and the target side by side (the same analyser, or `ffmpeg`
`astats`, `ebur128` and spectrograms). Then rule:

| Verdict | When |
| --- | --- |
| **Replace** | Ours fails the target on what the ear notices first: the wrong body (a punch that sounds like a slap), the wrong weight (a centroid more than an octave off, or no low end under 150 Hz on a slam), a muddy or clipped transient, an audible loop seam, or a band-limited source (optical transfers stop near 5 kHz) where the target is full range. |
| **Add a variant** | Ours is right but too few, or repeats audibly in a minute of play (fewer than 4 takes in a family that fires more than once every 10 s). A variant must sit within ±2 LU and the same spectral shape, or it reads as a different sound. |
| **Skip** | The candidate is no better on measurement, needs more processing than it is worth (a heavy denoise leaves artefacts), carries the room of another venue, has speech or music in it, or is not CC0. |
| **New family** | The target has an event we have no family for (ropes, steps, barricade). Propose it with its hook in both engines. |

Taste, in practice: impacts are short (under 150 ms to −20 dB) with the weight
in the tail, not the click. Crowds are never dry or still: layer and slew, and
never let the same pop fire twice in a row. Voices are sparse: a grunt every hit
becomes comedy (`MIN_GAP` 0.6 s, 50 % on light hits). The finish is the loudest
moment of the match, and nothing else should get within 3 dB of it.

## Phase 4 — Source the CC0 match

Search, in this order: Freesound (filter `license:"Creative Commons 0"`), the
Internet Archive's USC sound-effect archive (CC0, but band-limited), Kenney,
OpenGameArt (CC0 only), BigSoundBank. For each candidate give: URL, author,
licence as stated on the page, duration, sample rate, and why it fits (which
measured property). Present the shortlist and **wait for the owner's OK per
download.** Cache downloads in `~/.cache/aegis_audio/<round>`, never in the repo.

## Phase 5 — Shape it to the target

Write `tools/audio/build_sfx_round<N>.py` in the style of round 4: a table of
cuts (source sha256, in/out seconds, gain, filters, fades), then the same chain
for every row: trim → align the peak → high-pass the rumble that is not the
body → EQ toward the target's band balance → a downward gate on room noise →
fades → a look-ahead limiter if the target is that dense → a loudness match to
the family (ebur128) → Vorbis q5 with `-bitexact`. Name outputs
`<family>_<n>.ogg` in `game/assets/audio/`, appending variants after the
existing takes so nothing already wired changes.

## Phase 6 — Audition

Build a page (an Artifact, or `audition.html` in the scratchpad) with each slot
showing: the reference clip (local only; never published), our current take,
and each candidate, with spectrograms and loudness numbers side by side. Write
your verdict per slot and leave the owner's column empty. Also run
`tools/audio/listening_reel.py` so the candidates are heard over the crowd
bed at match level.

## Phase 7 — Implement in both engines

1. Godot: the files under `game/assets/audio/`, `CREDITS.md` rows, and any level
   or hook changes in `core/audio/` (constants are named, with a comment
   saying why).
2. Unreal: rerun the port's import (`Tools/MCP/ue.py py
   Tools/Audio/import_sfx.py`; files the importer rejects get a 48 kHz WAV in
   `SourceArt/Audio/Converted/`), mirror `CREDITS.md`, and put matching
   constants and hooks in `Source/MyProject2/AegisMatchAudio.cpp`.
3. Families are found by name in both engines, so a new take needs no code.
   Rebuild the port (`Tools/MCP/build.sh`) only when you change code.

## Verification (the rule this sits under)

A skill says what should be heard; only a measurement says what the build
plays. Before anything is called done:

- Godot: `tools/audio/measure_mix.py` on a probe recording — about −18 LUFS
  integrated over a match, short-term peaks near −10 on a big pop, never past
  −1 dBTP.
- Unreal: in PIE, `UAegisMatchAudio.GetPlayed()` lists what fired and
  `GetMixLabel()` gives the layer levels. Check every new hook fired on its
  event, and run the determinism gate.
- Report what was measured, what was only judged by eye from a spectrogram, and
  what still needs the owner's ears.

`references/cue-sheet-template.md` holds the cue sheet columns and an
example row.
