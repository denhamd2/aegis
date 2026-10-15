# Audio credits

Every sound here is built by `tools/audio/build_sfx.py` from public-domain
(CC0) recordings. The script records which recording and which seconds each
file is cut from. No attribution is legally required for CC0; it is given
anyway.

| Files | Source | Author | Licence |
| --- | --- | --- | --- |
| `crowd_bed`, `crowd_walla_a` | [crowd int large dense arena stadium hall](https://freesound.org/people/kyles/sounds/635492/) | kyles | CC0 |
| `crowd_walla_b` | [Mexican "Lucha Libre": crowd yelling, whistling](https://freesound.org/people/felix.blume/sounds/141704/) | felix.blume | CC0 |
| `crowd_boo` | [Booing Crowd](https://freesound.org/people/NeoSpica/sounds/504621/), with [JM_AMB_INT_Crowd Sport 01 - Booing](https://freesound.org/people/Julien_Matthey/sounds/557189/) | NeoSpica, Julien_Matthey | CC0 |
| `crowd_cheer` | [R08-24 Large Crowd Screaming and Whistling](https://freesound.org/people/craigsmith/sounds/480725/), with [CRWDCheer_Cheering, Whistling](https://freesound.org/people/ShangusBurger/sounds/764273/) | craigsmith, ShangusBurger | CC0 |
| `crowd_roar` | [Crowd Cheer](https://freesound.org/people/FoolBoyMedia/sounds/397434/) | FoolBoyMedia | CC0 |
| `crowd_pop_*`, `crowd_finish` | [Stadium Crowd Reaction Excited 01](https://freesound.org/people/itmightgetloud/sounds/829453/) | itmightgetloud | CC0 |
| `crowd_ooh_*` | [Crowd Ooohs and Ahhhs in Excitement](https://freesound.org/people/noah0189/sounds/264499/) | noah0189 | CC0 |
| `bell_*` | [Boxing bell, various rings](https://freesound.org/people/TRP/sounds/571096/) | TRP | CC0 |
| `bump_*` | [Heavy wrestler fall on mat](https://freesound.org/people/kyles/sounds/454221/) | kyles | CC0 |
| `hit_punch_*` | [Punch Sounds](https://freesound.org/people/uEffects/sounds/208791/) | uEffects | CC0 |
| `pyro_boom` | [Booming punchy explosion](https://freesound.org/people/misosound/sounds/251759/) | misosound | CC0 |
| `pyro_bang` | [Sharp Explosion 4](https://freesound.org/people/Rudmer_Rotteveel/sounds/336011/) | Rudmer_Rotteveel | CC0 |
| `whoosh` | [quick woosh](https://freesound.org/people/florianreichelt/sounds/683101/) | florianreichelt | CC0 |
| `hit_kick_*`, `count_slap_*` | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `hit_metal_*`, `hit_wood_*`, `hit_glass_*` (over Kenney's heavy punches), `table_crack_*` (with the ring-bump recording above) | [Impact Sounds](https://kenney.nl/assets/impact-sounds) | Kenney | CC0 |
| `ui_*` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 |

## Chants

`chant_*`, `crowd_count_*` and `crowd_whoa_*` are built by
`tools/audio/build_chants.py`: each syllable spoken by dozens of different
synthetic voices, shouted, placed on the chant's beat and put in an arena-sized
reverb, with crowd hand claps cut from a CC0 recording. No free recording of a
crowd chanting these names exists, and broadcast audio is not ours to use.

| Part | Source | Author | Licence |
| --- | --- | --- | --- |
| The voices | [Piper](https://github.com/OHF-Voice/piper1-gpl) `en_US-libritts_r-medium` (904 speakers) | Piper / Open Home Foundation; voice trained on [LibriTTS-R](http://www.openslr.org/141/) (Koizumi et al., 2023) | Voice data CC BY 4.0 -- this line is the attribution it requires |
| The claps | [crowd clap rhythmic](https://freesound.org/people/johnnyguitar01/sounds/424793/) | johnnyguitar01 | CC0 |

Caveat, stated plainly: the Piper `libritts_r` voice was fine-tuned from
Piper's `lessac` voice, whose source recordings carry their own (research)
terms. Fine for this project as it stands; check it before any commercial
release, or replace the voices with recorded ones -- `build_chants.py` mixes
WAVs dropped in `~/.cache/aegis_audio/chant_takes/real/` straight in.

The entrance music in `music/` is the full soundtrack of the owner-supplied
entrance videos (Google Drive, 2026-09-26; 3:38 each), cut out by
`tools/audio/build_entrance_music.py`: the same recordings the titantron
clips in `assets/environment/video/` were cut from (see the CREDITS there),
at full length, so each song plays straight through the entrance. Nothing in
it is from a new source; the caveats there apply.

`music/title_theme.ogg` is the owner-supplied title-screen track ("AEW
Dynamite theme 2025-present, Sum 41 - You Wanted War", logo loop, 3:29),
supplied 2026-10-03 and transcoded from the owner's mp3 to Vorbis q6 with
metadata stripped. It is not wired in yet (Stage 2 of
`gauntlet/refs/aaa_master_plan.md`). Same caveats as the entrance music:
owner-supplied, not a licensed or CC0 source.

`announcer/` holds three ring-announcer calls (Justin Roberts): the main-event
intro, Roman Reigns' and Cody Rhodes'. Owner-supplied mp3s (2026-10-06),
loudness-normalised to -12 LUFS and transcoded to Vorbis q6, mono. The name in
each was found with an offline speech recogniser (Roman 16.98 s, Cody 7.26 s)
and the director starts each call so the card goes up on that moment
(`RingAnnouncer.NAME_AT`). Same caveats as the entrance music:
owner-supplied, not a licensed or CC0 source.

## Match commentary

`commentary/tony_gunshot.ogg` is the owner-supplied Tony Schiavone call,
"Oh my God, he shot him with a gun!" It is transcoded from the MP3 provided
for this project, with a -12 LUFS loudness target and a -1.5 dBTP peak ceiling
(the source dynamics yield -13 LUFS). The same rights caveat as the other
owner-supplied recordings applies.

`commentary/tony_danger_warning.ogg` is the owner-supplied Tony Schiavone
call, "I don't like the look of this one bit." It plays once when a wrestler
takes up a dangerous weapon without a dedicated call, such as the rocket
launcher, handgun, steel chair, baseball bat, ladder, barbed-wire weapons, or
light tubes. It is transcoded from the supplied MP3 to mono Vorbis q6 at 48 kHz
with metadata stripped and a -12 LUFS target and -1.5 dBTP peak ceiling. The
same rights caveat applies.

`commentary/tony_barbed_wire_chair.ogg` is the owner-supplied Tony Schiavone
call, "Oh my God! He's got a steel chair and it's wrapped in barb wire!!!
What a sick bastard he is!" It plays instead of the generic danger warning
when a wrestler picks up the barbed-wire chair. The supplied MP3 is transcoded
to mono Vorbis q6 at 48 kHz with metadata stripped and a -12 LUFS target and
-1.5 dBTP peak ceiling. The same rights caveat applies.

`commentary/excalibur_bed_of_nails.ogg` is the owner-supplied Excalibur call,
"He's got a bed of nails! Oh my God!" It plays when a wrestler picks up the
bed-of-nails weapon instead of the generic danger warning. The supplied MP3 is
transcoded to mono Vorbis q6 at 48 kHz with metadata stripped, a -12 LUFS
target and -1.5 dBTP peak ceiling. The same rights caveat applies.

`commentary/tony_roman_heel.ogg` is the owner-supplied Tony Schiavone call,
"Hey Roman! Go fuck yourself!" It plays once when Roman uses a dangerous
weapon or performs his in-match heel pose. It is transcoded from the supplied
MP3 to mono Vorbis q6 at 48 kHz with metadata stripped, a -12 LUFS target and
-1.5 dBTP peak ceiling. The same rights caveat applies.

`commentary/tony_welcome.ogg` is the owner-supplied Tony Schiavone call,
"Welcome, everybody, to AEW Dynamite! I'm Tony Schiavone, alongside the voice
of AEW, Excalibur — and folks, we have a huge night ahead of us here tonight!"
It follows Excalibur's show-opening line during the establishing shot; the
opening hold gives Tony and Justin Roberts' main-event introduction time to
finish before the crowd call and entrances. The supplied MP3 is transcoded to
mono Vorbis q6 at 48 kHz with metadata stripped, a -12 LUFS target and -1.5
dBTP peak ceiling. The same rights caveat applies.

`commentary/tony_sneaky_heel_easter_egg.ogg` is the owner-supplied Tony
Schiavone call, "You know, Excalibur, the last time I saw someone act so
sneaky was when Bernie Foley got Amy Gaffney fired from Workday. How Bernie
still has a job there is beyond me." It is selected by an independent seeded
one-in-three match draw and, when selected, plays once after Roman's heel taunt
or dangerous-weapon attack commentary. The supplied MP3 is transcoded to mono
Vorbis q6 at 48 kHz with metadata stripped, a -12 LUFS target and -1.5 dBTP
peak ceiling. The same rights caveat applies.

`commentary/tony_title_match.ogg` is the owner-supplied Tony Schiavone call,
"The championship is on the line, right here, right now." It plays in the
pre-match broadcast when a rostered champion is in the bout. It is transcoded
from the supplied MP3 to mono Vorbis q6 at 48 kHz with metadata stripped, a
-12 LUFS target and -1.5 dBTP peak ceiling. The same rights caveat applies.

`commentary/tony_cody_return.ogg` is the owner-supplied Tony Schiavone call,
"Excalibur, I never thought we'd see the day when Cody Rhodes would return to
an AEW ring. What a prick he turned out to be!" It is transcoded from the
supplied MP3 with a -12 LUFS target and -1.5 dBTP peak ceiling (the source
dynamics yield -14.5 LUFS). The same rights caveat applies.

`commentary/tony_roman_record.ogg` is the owner-supplied Tony Schiavone call
about Roman Reigns' undefeated run and being without The Bloodline tonight. It
is transcoded from the supplied MP3 with a -12 LUFS target and -1.5 dBTP peak
ceiling (the source dynamics yield -14.9 LUFS). The same rights caveat applies.

`commentary/tony_roman_spear.ogg` is the owner-supplied Tony Schiavone call,
"SPEARRRR!!! OH MY GOD!!!" It is transcoded from the supplied MP3 to mono
Vorbis q6 at 48 kHz with metadata stripped and a -12 LUFS target and -1.5 dBTP
peak ceiling (the short source measures -13.3 LUFS after encoding). The same
rights caveat applies.

`commentary/tony_enda_easter_egg.ogg` is the owner-supplied Tony Schiavone
call, "Enda Dowling does indeed fear Omar Anshasi." It is transcoded from the
supplied MP3 to mono Vorbis q6 at 48 kHz with metadata stripped and a -12 LUFS
target and -1.5 dBTP peak ceiling. It is a rare match cutaway when the Enda
sign is raised; the same rights caveat applies.

The following new Tony Schiavone lines are owner-supplied recordings,
transcoded from the supplied MP3s to mono Vorbis q6 at 48 kHz with metadata
stripped and a -12 LUFS target and -1.5 dBTP peak ceiling. They are cued by
MatchAudio; the same rights caveat applies:

- `commentary/tony_submission.ogg`: "He's got it locked in tight, and there
  is nowhere to go!" On the first submission hold.
- `commentary/tony_love_this_business.ogg`: "This is why we love this
  business right here." After a wrestler kicks out following a two-count.
- `commentary/tony_what_a_night.ogg`: "What a night this has been,
  Excalibur. What a night." After the post-match review, before Excalibur's
  existing sign-off.
- `commentary/tony_crowd_up.ogg`: "This crowd is up on their feet already."
  Tony's reply to Excalibur's pre-match crowd line, before the entrances.
- `commentary/tony_momentum_shift.ogg`: "He's turning this match around,
  Excalibur." Tony's response after Excalibur calls a wrestler's comeback.
- `commentary/tony_tension.ogg`: "You can feel the tension building here."
  During the face-off stare before the opening bell.

`commentary/excalibur_signoff.ogg` is the owner-supplied Excalibur sign-off,
"We'll see you right back here next Wednesday — same time, same place." It is
transcoded from the supplied MP3 to mono Vorbis q6 at 48 kHz with metadata
stripped and a -12 LUFS target and -1.5 dBTP peak ceiling (the short source
measures -13.1 LUFS after encoding). The same rights caveat applies.

`commentary/excalibur_strikes.ogg` is the owner-supplied Excalibur call,
"He's not holding back on those strikes, not one bit." It plays after a hard
punch connects, at most once per match. The supplied MP3 is
transcoded to mono Vorbis q6 at 48 kHz with metadata stripped, a -12 LUFS
target and -1.5 dBTP peak ceiling. The same rights caveat applies.

`commentary/excalibur_body_kicks.ogg` is the owner-supplied Excalibur call,
"He's working the body with those kicks, Tony, wearing him down." It plays
after a body-targeting kick connects, at most once per match. The
supplied MP3 is transcoded to mono Vorbis q6 at 48 kHz with metadata stripped,
a -12 LUFS target and -1.5 dBTP peak ceiling. The same rights caveat applies.

`commentary/excalibur_unbelievable.ogg` is the owner-supplied Excalibur
"Unbelievable!" call. It can follow a spectacular spot or late-match two-count
kickout (after four minutes of match time), at most once per match.
The supplied MP3 is transcoded to mono Vorbis q6 at 48 kHz with metadata
stripped, a -12 LUFS target and -1.5 dBTP peak ceiling. The same rights caveat
applies.

`commentary/excalibur_restore_order.ogg` is the owner-supplied Excalibur call,
"We've got to restore order here!" It plays during a burst of dangerous
weapon action, on a gunshot or explosion, or after a table spot, at most once
per match. The supplied MP3 is transcoded to mono Vorbis q6 at 48 kHz
with metadata stripped, a -12 LUFS target and -1.5 dBTP peak ceiling. The same
rights caveat applies.

The following Excalibur lines are also owner-supplied MP3s, transcoded to
mono Vorbis q6 at 48 kHz with metadata stripped and a -12 LUFS target and
-1.5 dBTP peak ceiling. Their transcript and cue are in MatchAudio and the
entrance timeline; the same rights caveat applies:

- `commentary/excalibur_wednesday.ogg`: "It's Wednesday night, and you know
  what that means!" The show-opening call, over the establishing shot.
- `commentary/excalibur_crowd.ogg`: "I'll tell you, Tony, this crowd has been
  buzzing about this one all week!" The pre-match crowd call, after Justin
  Roberts' main-event introduction and before the entrances.
- `commentary/excalibur_comeback.ogg`: "He's digging deep, Tony. I don't know
  how much more he has left." The first earned fired-up comeback of the match.
- `commentary/excalibur_cody_career.ogg`: "Cody Rhodes has built his entire
  career on proving people wrong, Tony." Excalibur's response after Tony's
  Cody-return call, during Cody's entrance.
- `commentary/excalibur_superman_punch.ogg`: "That Superman Punch came out of
  nowhere!" After Roman lands his Superman Punch signature move.
- `commentary/excalibur_two_count.ogg`: "A two-count, maybe two and a half —
  this is anybody's match." After a wrestler kicks out following a two-count,
  before Tony's follow-up call.
- `commentary/excalibur_kickout_one_seven_eighths.ogg`: "A kick-out at one
  and seven-eighths — somehow he found a way." A randomized alternate for the
  same two-count kickout beat.
- `commentary/excalibur_finish.ogg`: "Ring the bell! That's it! It's over!"
  The match-ending call, after the finish bell.
- `commentary/excalibur_coolest_job.ogg`: "Sometimes you just have to take a
  moment and realize we've got the coolest job in the world." A second
  post-bell call, queued after the finish call.
