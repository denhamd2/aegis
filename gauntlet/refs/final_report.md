# AAA pass — final report

Branch `ccr-5f96c954-z0l7gs`, pushed to `main` stage by stage. The running log
with measurements is `README.md`; the contract is `gauntlet/anchor/ARCHITECTURE.md`.

## What was built

| Area | Result |
| --- | --- |
| Stage set, ring, arena | Wider stage, truss, printed (not LED) announce-desk signage, Ula Fala recoloured; ring and arena bowl rebuilt to the owner's references. |
| Audio | Title theme (`menu_music.gd`), menu SFX, in-match crowd bed that follows heel/face favour and match phase (`match_audio.gd`, four crowd loops). |
| Crowd | Varied floor and seat spectators (`crowd.py`, `floor_crowd.glb`), per-section excitement (`crowd_reaction.gd`), camera flashes as additive billboards with independent clocks (`crowd_flashes.gd`) — no clones in lock-step. |
| Cody's entrance | Web-safe dry ice (particles, no FogVolume) from the portal; Roman entrance reviewed. |
| Prop handoff | Wrestler -> Aubrey -> timekeeper -> table, one holder at a time, eased swaps, no pop or teleport (`prop_handoff.gd`, `timekeeper.gd`, six new clips in `wrestling_clips.py`). Frame-verified. |
| Rules | Pin legality (cover drags to centre; rope break honoured before the count), rope-break before first slap, cover/kickout legality. |
| Pacing | `MatchFlow` phases (feeling out, heat, comeback, finish), recoverable plus permanent wear, persona tempo (Roman heel, Cody face), finisher rungs and rest, seed-picked winner. Matches run about 8-12 min. |
| AI | Irish whips (`WHIP_CHANCE` 0.18 after the opening grapple). |
| Camera | Cut-based broadcast bearing, no constant orbit (`test_camera_no_orbit.gd`). |
| Moveset | Roman's own moveset in `roster.gd`. |

## Measurements

Headless deterministic sim, 60 Hz, `tools/probe/pace_probe.gd`:

- 7 seeds before whips: 8-12 min, correct winner every time.
- With whips: seed 3 471 s, seed 5 493 s (7 whips each, 2-3 near-falls, pinfall by the designated winner); earlier whip run 493 / 740 / 668 s.
- Full gdUnit suite: 685 tests, 0 errors, 0 failures.

## Independent QA (stills)

A separate reviewer compared the frames to `gauntlet/refs/owner/`. Triage:

- **Fixed or already by design:** WRESTLERA/B names are the probe fixture's, not the game's; the title key-art and Kenny Omega card are owner-supplied (`assets/ui/CREDITS.md`, not cleared for distribution).
- **Open, minor:** the belt reads as a dark strap when seen from behind in the handoff probe (plates face the referee, as intended); the stage video wall is hot (level tuned in the 2K26 lighting round, left alone); the web (`gl_compatibility`) look is darker than Vulkan; flashes are faint in a still.
- **Open, larger art work:** the crowd is blocky at the high camera; the timekeeper's table is a plain block.

## Known gaps

- Cody's coat is hidden on `coat_off`; a rest-pose coat is T-shaped and not carryable.
- New paired moves (Samoan Drop, Guillotine, Drive-By, Pedigree, corner spear, Superman Punch rebound) are not built.
- No continuous end-to-end video: software rendering costs about 0.7 s per tick, so a match cannot be recorded in this sandbox. On a GPU machine run `tools/capture/run_capture.sh` (and `tools/probe/match_timelapse.tscn`).
- `tools/capture/qa_frames.sh` reproduces the still-frame QA set.
