# Kenny Omega to WWE 2K quality: plan (20 Oct)

The owner asked for five things:

1. "Kenny's model (face and body) doesn't look good or realistic. Refer back to his character sheet and also research images of him in 2026."
2. "Check Kenny's entrance video … research what Kenny's usual entrance is, poses, walking gait, pyro, etc and animate this."
3. "Ensure Kenny has a full moveset, use his Fight Forever moves."
4. "Do a full research of Kenny's fighting style. He is also a babyface. Ensure his style, speed, athleticism and ring psychology is baked in."
5. "Research Kenny's poses and taunts and ensure they are created. Aim for AAA WWE 2K quality with Kenny's modelling and face."

The current-state comparison is `gauntlet/refs/characters/review/kenny_vs_sheet.png`. It was rendered in-game through `tools/probe/face_shot.tscn` under match lighting.

## Where he stands today

- **Model.** `tools/blender/kenny_aaa.py` builds him. It uses an MPFB body fitted to the base rig's 65 bones. His gear (white-and-gold tights, kneepads, boots, wrist tape), hair cards and a likeness pass were done in stages 1–5.
- **Entrance video.** It is wired in. `StageVideo.ENTRANCES["kenny"]` plays `kenny_entrance.ogv` with music from the chorus, and the screens turn on and off on cue.
- **Entrance walk.** There is no routine of his own. He uses the generic `_add_entrance` walk and route in: no poses and no pyro.
- **Moveset.** The roster gives him only the One-Winged Angel. `ff_library.gd` already tags his Fight Forever set:
  - signatures: Running V-Trigger 3, Powerbomb/V-Trigger Combo, Snap Dragon Suplex 2 and 3
  - specials: Running V-Trigger 1, V-Trigger 1, One-Winged Angel

  None of these are wired to him beyond the finisher.
- **Persona.** He has no face/heel entry. He falls to "neutral" in `MatchFlow`, so he has no babyface story.

## 1. Face and body: the gaps, most visible first

| # | Gap (game against the sheet) | Fix |
| --- | --- | --- |
| 1 | **Hair.** The top is a slicked cap with curls only at the sides and back. The sheet has curly volume over the crown with a centre-left part, wet strands falling at the temples and in front of the ears, and shoulder-length ringlets. | Re-groom in `kenny_aaa.py`'s hair stage. Scalp cards follow the part, curl clumps carry over the crown, and 6–10 face-framing strands hang in front of the ears. Root-to-tip tone runs from dirty blond to light gold, with darker wet roots. Use alpha-to-coverage cards as Roman's do. The budget comes from `references/polycount-budgets.md`. Read `import-wrestler`'s hair section first. |
| 2 | **Face shape.** A generic, narrow-eyed MPFB face. The sheet has a heavy brow ridge, deep-set hooded eyes, broad cheekbones, a slightly wide nose and a strong square jaw. | MPFB modifier targets (brow ridge, eye depth, eyelid hood, cheek width, jaw width and squareness, nose width), measured as landmark ratios off the four sheet head shots against our front and three-quarter renders. Iterate to within 5% on each ratio. |
| 3 | **Stubble.** There is none, only a dark chin shadow. The sheet has a dense blond-ginger beard and moustache, about 5 mm. | A short beard card shell over the jaw, chin and upper lip, plus a darker stubble mask in the albedo underneath, as Roman's beard is built. Read `import-wrestler`'s beard section first: the last beard defect was scale. |
| 4 | **Skin.** Waxy and orange, with no pores or creases. The sheet is flushed red-pink with sweat, crow's feet and forehead lines. | Bake detail normals for forehead lines, crow's feet and nasolabial folds, and add `SkinLook.add_pores` at head density, as Cody's skin has. Retint toward the sheet's measured cheek and forehead medians, and add flush on the nose, cheeks and ears. Wetness rides `Sweat`, as for the others. |
| 5 | **Brows.** Painted slabs that float off the skin. | Short strand cards laid on the brow ridge, and a matching brow mask in the albedo. |
| 6 | **Lashes.** Thick and pale on the lower lid. | `EyeKit.lash_material` with darker, sparser lower lashes. |
| 7 | **Eyes.** Small and narrow. The sheet's are pale blue with hooded lids. | Open the lids (lid shape key), use a paler iris tint, and apply Cody's soft-cornea fix from day one. |
| 8 | **Body.** To be measured. | Front, side and back turnaround renders in his gear against the sheet's turnaround. Check shoulder width, lat flare, arm girth and calf size. Correct with `BodyBulk` as Cody's build was. |

**Gate.** A side-by-side sheet for each pass: front, three-quarter and profile, under match light and under the face-shot rig. `tools/capture/evidence_gate.py` must pass before it ships. Every change stays in the deterministic `kenny_aaa.py` build.

## 2. His entrance (research)

**What he does, broadcast after broadcast.**
- He walks out to "Battle Cry" behind the anime and video-game build-up on the tron. At All In 2026 it was a *My Hero Academia* intro with an All Might voiceover. His video is already on our screens.
- Unhurried, bouncy and loose, rolling his shoulders, and playing to the fans on both sides.
- He stops at the top of the ramp for the "Terminator" moment: down on one knee, head bowed, while the crowd claps to the Terminator riff, before he rises.
- He slaps hands down the ramp and climbs the apron at the corner.
- On the middle rope he spreads his arms and looks out (the "angel" pose), then drops down and points to the crowd.

**Our routine.** `_add_kenny_entrance`, on the same pattern as Cody's.
- **Clips:**
  - `Kenny_Walk`: a loose, bouncy gait with a little shoulder roll and the head moving.
  - `Kenny_Terminator_Kneel`: kneel, head bowed, rise.
  - `Kenny_Hand_Slaps`: walking gestures to both sides.
  - `Kenny_Corner_Wings`: on the middle rope, arms spread, looking out.
- **Pyro:** a white-and-gold burst as he rises from the kneel, and the "pyro_over_ring" fall as he stands on the ropes. Rocket-style pyro, per the owner's note on sparkles (task #107).
- **Camera:** shot lists on the same storyboard as Cody's and Roman's.

## 3–5. Moveset, style, poses and taunts

- **Moveset.** His Fight Forever set goes into the roster: Running V-Trigger and V-Trigger, Snap Dragon Suplexes, the Powerbomb/V-Trigger Combo, and the One-Winged Angel as his finisher. Add the Tiger Driver '98 (already in `resources/moves/ff/`) as a signature. Each move needs a clip check through `clip_shot`, then the pair-clearance gate.
- **Style and psychology, in the AI's numbers.** Speed and athleticism: a fast tempo row, more running and aerial picks, and a dive to the outside when the opponent is on the floor.
  - **The V-Trigger as a health bar.** He comes back to the knee again and again, so it has a high repeat weight from the "hope" phase on.
  - **The OWA as the end.** It is used only in the finish window. An early attempt gets reversed, which is the near-fall story.
- **Babyface.** He is added to `Persona` as a face. He sells big in the heat (the face rows in `MatchFlow.PHASES` already do this). He fires up with V-Triggers in the comeback. The crowd pops (`CrowdReaction`) on his signatures.
- **Taunts and poses.** He sometimes does the Terminator kneel before a dive, with the crowd clapping. Others:
  - "Goodbye and goodnight" with the finger pointed before the OWA
  - the arms-spread angel on the turnbuckle
  - a mocking finger-guns taunt

  They are authored in `wrestling_clips.py`, are reachable from the taunt input, and the AI uses them in the comeback.

## Order

1. Face and hair passes (1–7), each with a review sheet.
2. Body measurement and fix (8).
3. Moveset wiring and the babyface persona, with an AI tally probe.
4. Entrance clips, the routine, pyro and cameras.
5. Taunts.

Each step is tested and shipped on its own.

Sources:
- [Fightful: Omega enters to "You Say Run" with an All Might voiceover at All In](https://www.fightful.com/wrestling-news/kenny-omega-enters-to-you-say-run-with-all-might-voiceover-at-aew-all-in)
- [Wrestling Inc: the anime-themed All In 2026 entrance](https://www.wrestlinginc.com/2247211/kenny-omega-aew-all-in-2026-world-title-loss-entrance-my-hero-academia/)
- [Wrestling Inc: the Terminator entrance and dive ritual](https://www.wrestlinginc.com/news/2017/01/kenny-omega-says-he-leaving-japan-620966)
- [WhatCulture: the V-Trigger as a "health bar" drain](https://whatculture.com/wwe/10-wrestling-moves-that-blew-your-mind-the-first-time-you-saw-them?page=4)
- [TV Tropes: the V-Trigger as a lead-up to the One-Winged Angel](https://tvtropes.org/pmwiki/pmwiki.php/Fridge/KennyOmega)
- [Sportskeeda: Omega's finishers](https://www.sportskeeda.com/aew/kenny-omega-finisher)
- [EGM: Fight Forever gameplay, Omega v Cole](https://egmnow.com/?p=22813)
