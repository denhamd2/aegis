# WWE 2K26 Cody Rhodes vs Roman Reigns (Throneful, PS5) — entrance and match measurements

Source: owner-supplied download of YouTube KVXzadXUshM (complete, 842 s, 1280x720 60 fps), kept
local in `raw/video/cody_roman_2k26.mp4` (gitignored). [M] measured from frames (contact sheets
every 5 s across the whole video, 1 s windows at 495, 600 and 745 s; ffmpeg scene-cut detector at
0.35), [I] inferred.

## Timeline [M, 1 s resolution]
| t (s) | Beat |
| --- | --- |
| 0-12 | Black, then a dark, high arena wide; only the screen and fixture glints lit. |
| ~20-30 | Cody on the stage under white portal light, dry ice at his feet; screen fills the frame behind him. |
| ~45-55 | The kneel at the stage front; the American Nightmare floor graphic below him. |
| ~75 | Waist-up, walking at the lens; ramp lined both sides with LED blinder boxes; front-row faces behind the barricade. |
| ~90 | Over-the-shoulder on the jacket back (the crest), coloured fixture dots in the dark roof. |
| ~95-100 | Steps up, ducks through the ropes; close low shot from the ring. |
| ~110 | On the second rope, arms out, low from inside the ring. |
| ~120-140 | Very wide, high, from the upper bowl: star-glint fixtures and pyro over the ring, the whole bowl full. |
| ~150-160 | Roman: the stage tiny in a long lens, the TC (Tribal Chief) screen art, him walking out. |
| ~170 | Full-screen ROMAN REIGNS type over him, finger to the sky, blue lightning on the screen. |
| 168-187 | Screen strobe and flicker (the cut detector fires 40+ times; these are light changes, not cuts). |

## Camera [M]
- Cody's entrance: ~17 cuts in ~150 s, so the average shot is about **8-9 s**. It is slow and
  cinematic, with long holds and gentle drift.
- Low shots from inside the ring for the rope entry and the pose.
- One very wide establishing shot from high in the bowl near the end.
- A 2K "RUN-IN" / "BREAK OUT" prompt sits top-left during the entrances.

## Lighting [M]
- Entrance frames are mostly black. The titantron is the dominant light.
- Fixtures show 6-8 point star glints in the roof and over the ring.
- Dry ice lies low on the stage only.
- LED blinder boxes (warm white, 2x3 cells) line both ramp edges at knee height.
- Front-row faces read warm. The far bowl is a dark field with red/blue spill.

## Crowd [M]
- The crowd is distinct people: faces, varied clothes, phones, signs.
- Front rows are packed right up to the barricade, which carries the WWE LIVE LED art.
- The far bowl is dense, small figures in the dark, readable as a crowd and never as blocks.

## Gear [M]
- Cody: gold epaulette jacket in red/white/gold with the crest on the back; white boots; gold-and-white tights.
- Roman: shirtless, dark trunks/pants, chain and ula fala.

## The match (bell ~300 s, three ~775 s: about 7 min 55 s) [M]
| t (s) | Beat |
| --- | --- |
| 185-290 | Roman's entrance: name type full-screen, lightning screen, ring entry, arm up on the buckle. |
| ~295 | Pre-match card: both names with "Draw energy / Approach / Rush" prompts. |
| 300-330 | Lock-up, early chain: Cody leg-lock submission with the HOLD meter, Roman rolls out. |
| 330-430 | Even exchanges: suplexes, strikes, Roman on the apron, crowd signs up. |
| 435-520 | Cody off the top; a finisher setup at the corner shot in a CLOSE cinematic angle (497 s); pin, big "2", kickout. Red screen vignette with droplets = a man in danger. |
| 560-680 | Long strike exchanges against the ropes (600-624: 25 s of back-and-forth with ring timing prompts); Cody "CHARGED FINISHER", Roman "POSSUM ATTACK" prompts. |
| 685-770 | Fight on the apron and the outside; Roman Samoan-drop-style lift; long stretches of one man working the other on the mat (stomps, a 15 s strut while Cody is down). |
| ~775 | Cody's final pin, ref's hand down; WINNER card. |
| 785-815 | 2K26 wipe, then REPLAY of the finish from 3-4 angles, slowed, framed red. |
| 820-840 | Celebration: chest-up close, low from the ring, a very wide from the crowd, arms out. |

## Match camera [M]
- **Only 13 cuts between the bell and the WINNER card, about 475 s**, so the average shot is
  about 37 s. The detected cuts are at:
  316.9, 319.9, 329.1, 333.1, 430.2, 448.4, 497.5, 625.1, 631.6, 665.9, 732.6, 771.0 and 774.9 s.
- The match is ONE continuous gameplay camera:
  - It sits a little above the top rope and about 6-9 m out, mostly on the hard-cam side.
  - It pans, dollies and reframes with the pair. It swings to a high corner angle when they go to
    the ropes, a corner or the apron.
- Cuts are only for set pieces: the finisher (a close, low, moving angle), the pin "2", the finish,
  and the replays.
- Our broadcast coverage cuts on every event (0.6-0.9 s) and holds a master for 7 s. 2K26 does the
  opposite.

## Mechanics on screen [M]
- Each HUD bar holds health (segmented), stamina and a finisher/momentum meter.
- A star rating is shown top-left during the match.
- The red damage vignette means a man is in danger.
- Strike exchanges and chain wrestling use ring-timing button prompts over each man.
- Context prompts: PIN, ESCAPE, CANCEL, FINISHER, CHARGED FINISHER, POSSUM ATTACK.
- Big pin-count numerals.

## Pacing [M]
- About 8 minutes, with long control stretches. The man on top walks around and works the
  downed man rather than chaining moves.
- Several near-falls before the finish, and two finisher attempts by Cody.
- Ref Aubrey is always in frame near the action.

## In-ring match lighting [M] (frames 335, 497, 612, 760, 826 s)
- **Wrestlers sit well below the mat.** Skin was measured with an R>G>B skin mask, as linear
  luminance inside the ring area.
  | | Skin mean | Mat | Skin / mat | Skin p95 |
  | --- | --- | --- | --- | --- |
  | 2K26 | 0.20-0.27 | 0.60-0.64 | 0.33-0.44 | 0.49-0.65 |
  | Ours (before this review) | 0.28-0.36 | 0.62 | 0.45-0.58 | 0.76 |

  Ours are about 35% too bright against the same mat, and the skin highlights are hot.
- **Light comes from overhead.** Shoulders, head and back are lit; sides and fronts fall into
  shadow. Bodies are modelled by the light rather than flat front-lit.
- **Rope shadows.** Several sets of soft, parallel rope-shadow lines criss-cross the whole mat,
  one set per overhead fixture at a different angle. They are faint, wide and soft-edged.
- **Shadows under bodies.**
  - A dark contact pool sits under every body.
  - Each leg has two or three faint offset shadows (multiple fixtures).
- **The ring is the brightest object.** The floor outside the apron and the barricade are much
  darker; light is a pool on the ring.
- **Close-ups.**
  - Warm skin with a sweat sheen and specular on the shoulders and face.
  - A cool rim from behind.
  - The crowd behind is soft (depth of field) and darker.
- **Crowd.** Front rows are warm-lit, readable faces; the rows behind fade darker. No coloured
  light falls on the crowd in the match.
