# Audio credits

Every sound here is built by `tools/audio/build_sfx.py` from public-domain
(CC0) recordings. The script records which recording and which seconds each
file is cut from. No attribution is legally required for CC0; it is given
anyway.

| Files | Source | Author | Licence |
| --- | --- | --- | --- |
| `crowd_bed` | [Boston Garden Celtics Ambience](https://freesound.org/people/Douglas711/sounds/424297/) (TD Garden) | Douglas711 | CC0 |
| `crowd_walla_a` | [crowd int large dense arena stadium hall](https://freesound.org/people/kyles/sounds/635492/) | kyles | CC0 |
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
