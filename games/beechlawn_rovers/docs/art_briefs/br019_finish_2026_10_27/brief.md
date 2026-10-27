# Shooting and aerial actions — BR-019 (19/27)

Source baseline: `4a61945946fc6d703b261b225b83e0a93626afce` (Mac v0.5.5).
This pass finishes the field-player aerial contest, strike-body variation and
keeper high-cross claim gaps identified in the prior
[aerial](../aerial_play_2026_10_22/brief.md),
[advanced-shot](../advanced_shots_2026_10_23/brief.md),
[bilateral-strike](../left_foot_ai_2026_10_25/brief.md) and
[free-kick](../free_kick_polish_2026_10_26/brief.md) reviews.

## Reference and gap

The archived player/keeper turnarounds, goal and ball sheets and gameplay
composite are indexed in `references/README.md`. They establish anatomy,
kit and ball scale, but are stills rather than motion capture. The shipping
right-foot action, its evaluated 60 Hz Godot poses, and the original authored
header and keeper reach provide the motion authority. Before this pass, a
close defender might not prepare to challenge a cross; simultaneous equal
forehead gaps could cancel both actions; all ground-shot styles reused the
same body clip; and a secure high cross used the overhead save clip.

## Implementation

An aerial defender near a forecast descending contact now prepares a real
header. Eligible head and keeper-glove contacts are compared using evaluated
world positions, current action serial and existing live contact windows.
The nearest legal contact wins; within 2 cm, existing heading/jumping/strength
or keeper handling/jumping ratings and stable player ID break the tie. One
ball impulse follows, with no ball or body teleport. Keeper hands qualify only
inside their own penalty area after the usual reaction and motion readiness.
The existing 20 cm aerial contact and 28 cm foot-contact bounds are unchanged.

Eight 60 Hz animation-only clips add six left/right power, finesse and low
shots, a braced challenged header and a high two-hand claim/recovery. They
retain the 65-bone rest and the original meshes, heads, kits and base motions.
Each shot style and selected foot locks at action start. Its authored marker
opens the existing live-foot window; the independent ball still decides actual
contact. The keeper catches only when the existing glove, handling and speed
checks allow it, otherwise parrying as before. The shared rig and bounded
physics-clock playback are retained for every match actor.

## Motion and scene review

[Blender contact and follow-through poses](blender/) compare the protected
standard kick and header with the new styles on the same mesh, rig, camera and
frame. The power shot leans back into its follow-through, finesse rotates
across the body, and low puts the chest over the ball. The claim lifts both
hands and then gathers. [Native right power](shot_power/match_broadcast.png)
and [left finesse](shot_finesse_left/match_broadcast.png) use the real match
controller and report 0.241 m and 0.241 m selected-boot gaps, below the 0.28 m
limit. The [close cross sequence](cross_duel_close/match_broadcast.png) shows
the defender and keeper around the attacker; its actual `HeaderDuel` forehead
contact measured 0.147 m, below the 0.20 m limit. The separate
[high-claim sequence](keeper_claim_home/match_broadcast.png) records an actual
`goalkeeper_catch` at the dedicated clip. These controlled fixtures establish
motion/contact, while the seeded complete matches measure natural play.

The [matched Rovers Arena broadcast](arena_broadcast/match_broadcast.png)
remains at 1,208 draw calls and 1,157,084 primitives, identical to v0.5.5.
The seating audit still reports zero errors. Peak Linux process RSS rose from
4,274,476 to 4,307,132 KiB (+32,656 KiB) in the matching 640 × 360 software
Vulkan capture; this is not a target-Mac memory or frame-rate result.

## Validation and delivery

The [validation record](validation.json) gives test outcomes, motion contacts,
native renderer metadata and matched scene costs. Matching Blender pose
reviews and native Forward+ sequences are archived beside it. The targeted
checks cover both attack directions, caller-order-neutral header duels,
out-of-reach misses, legal handling bounds, dedicated keeper motion, both-foot
style shots while standing/moving, interruptions, replays and natural complete
matches. Serial Godot tests use hard deadlines. The source/GLB audit confirms
the unchanged 65-bone rest and eight animation-only clips.

BR-025 (25/27, in progress) retains native M1 Pro / 16 GB input-feel,
appearance and sustained 1080p60 acceptance. Linux software Vulkan evidence
shows the actual Forward+ controllers and motion but does not measure Metal
throughput or certify the target hardware.
