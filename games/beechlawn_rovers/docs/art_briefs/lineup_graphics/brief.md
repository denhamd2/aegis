# Walkout starting elevens

BR-014 (item 14 of 25), in progress, with roster-data changes under BR-005.
The owner requested home-first TV graphics, faces in a 4-4-2, supplied crests,
Robbie Roden and Des Feeney as player-managers, and retirement of Beechlawn #2.

## Sources and design

The original navy broadcast panel was generated with GPT Images and is saved
as `assets/ui/lineups/panel.png`. Godot draws all names, shirt numbers, crests
and portraits over it. Team/player resources remain the editable source of
truth; no names or numbers are baked into the generated artwork.

`assets/ui/lineups/sources.json` records each portrait source and SHA256. The
archived character sheets were copied unchanged, then sampled at their front
head panel by a UI shader. Their historical shirt numbers and source markings
remain intact. The supplied tall oval Beechlawn crest and the Boardeaux crest
already present in the kit atlas are reused. These are UI portraits, not
evidence of finished individual 3D models or new facial sculpts.

The portrait files import at a maximum dimension of 1024. Profiles store paths;
the overlay loads textures on demand rather than retaining them in the match
roster. The overlay and its portrait references are released with the intro.
Native M1 memory/performance acceptance remains unmeasured.

## Presentation and roster

The 22-second walkout shows Beechlawn for eleven seconds, then Boardeaux for
eleven, with eased graphic fades. The camera leaves the live walk visible on
the right. Actor walking speed stays at its authored 1.2 m/s; the extended
camera path follows their longer approach. The separate lineup camera pan
remains the slower 12-second sweep. Skip and natural completion restore the
same authoritative frozen kickoff state.

Provisional positions follow the existing number-based 4-4-2 assignments:

| Row, left to right | Beechlawn |
| --- | --- |
| Strikers | 9 Damo Murphy, 10 Robbie Roden |
| Midfield | 11 Michael McCabe, 6 Deco McCabe, 8 Shane Denham, 7 David Denham |
| Defence | 3 Derek Mitchell, 5 David Murray, 4 Kev Mullen, 14 Colly Roden |
| Goalkeeper | 1 John O’Rourke |

These are editable proposed positions, not factual claims about the real
players. Colly retains the right-back assignment formerly associated with #2.
Beechlawn team resources reject number 2 in both the active squad and reserves.
The actual roster number is 14, so runtime shirt printing and the graphic agree.
Boardeaux uses Des Feeney's supplied face and name for all eleven distinct
squad-numbered profiles, including its keeper. Robbie and Des remain players
while their team resources also name them as managers.

## Validation

`lineup_graphic_smoke.gd` verifies sequencing, 11 portraits, four formation rows,
one keeper, manager names, all-Des away identities, #14/#2 protection, frozen
match state and overlay cleanup. `pre_match_intro_smoke.gd` verifies complete
natural playback, skip and same-side handoff for all camera families. Team,
roster-resource and Play/Watch title checks also pass.

Actual Web captures and browser results are saved here by
`tools/check_lineups_web.py`: [home](lineup_home.png), [away](lineup_away.png),
[small layout](lineup_home_small.png) and [kickoff handoff](broadcast_after_intro.png).
The software WebGL check covers composition and integration; sun shadows are
disabled and native M1 rendering/performance remain open.
