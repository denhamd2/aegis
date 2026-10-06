# Audio credits

Every sound here is built by `tools/audio/build_sfx.py` from public-domain
(CC0) recordings. The script records which recording and which seconds each
file is cut from. No attribution is legally required for CC0; it is given
anyway.

| Files | Source | Author | Licence |
| --- | --- | --- | --- |
| `crowd_bed` | [Rogers Arena - NHL game atmosphere](https://freesound.org/people/SEF7/sounds/706497/) | SEF7 | CC0 |
| `crowd_walla_a` | [R08-05 Large Group at Event](https://archive.org/details/Red_Library_Crowds_Outdoor) (Red Library, archive.org) | Red Library | CC0 |
| `crowd_walla_b` | [R28-29 Large Crowd Quiet, Then Big Reaction](https://archive.org/details/Red_Library_Crowds_Outdoor) | Red Library | CC0 |
| `crowd_boo` | [R08-09 Large Unhappy Crowd](https://archive.org/details/Red_Library_Crowds_Outdoor) | Red Library | CC0 |
| `crowd_cheer` | [R25-22 Large Excited Crowd](https://archive.org/details/Red_Library_Crowds_Outdoor) | Red Library | CC0 |
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
| `ui_*` | [Interface Sounds](https://kenney.nl/assets/interface-sounds) | Kenney | CC0 |

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
