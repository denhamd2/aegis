# Rovers Arena crowd allocation and motion — BR-023 (23/27, in progress)

Source baseline: `f005bb739a7ff506fad119a2c35beba620126077` (Mac v0.5.4).
The owner approved the 80/20 clothing split and lower north-east visitor
allocation. The primary location reference is [Everton's East Stand story](https://stories.evertonfc.com/east-stand/);
our 3,118 away seats are the model's allocation, not Everton's exact allotment.
The archived crowd and stadium references are under
`references/stadium_supporters_2026_10_25/` and the prior production notes under
`docs/art_briefs/stadium_supporters_2026_10_25/`.

## Reference gap and implementation

The existing bowl already models 49,554 spectator seats, with separate aisles,
entrances and access routes. Its old occupancy rules left 4,869 seats empty and
treated the whole North stand as visitors. Section `support_side` now assigns
only IDs 0, 1, 47, 48 and 49 to Boardeaux: all three lower NorthEast blocks
and adjoining lower North blocks 0 and 1. Structural bank roles still drive
tiers and stadium geometry. Exactly 46,436 seats support Beechlawn and 3,118
support Boardeaux. No seats, routes or architecture were added or moved.

The previous VAT shaders computed a garment tint but omitted it from `ALBEDO`.
Both distance shaders now use the existing garment mask and apply team primary
and secondary colours only to clothing, with photographic fabric variation.
The same mask is exported as `UV2.y` on all 12 close-up GLBs. Blender source,
original photo UVs, optional extra UVs, skeleton rest, weights, index data and
all nine animation samples remain intact. Each side has an exact rounded
80% team-colour / 20% casual split: 37,149 team-colour home supporters and
2,494 team-colour away supporters. Twelve garment variants vary shade and
combination while skin, faces and hair retain their source colours.

Most bodies use the existing seated idle clips and varied per-instance phase.
Chance events draw attention; scoring-side reactions use score deltas so own
goals work. Crowd state snapshots restore live play after replays. A bounded
16-gameplay / 32-cinematic close-rig pool and three GPU VAT levels remain.
Sixty-four selected fans animate with the independent `Fan_Flag` body state:
36 South home, 12 elsewhere home, 16 away. Flag palette follows supporter
affiliation; pole and cloth transforms follow the sampled animated hand, with
different flutter phases. Kilmore's eight standing casual spectators keep
their prior material and attendance.

## Native evidence and measured cost

The matched [v0.5.4 before view](broadcast_before/match_broadcast.png) and
[v0.5.5 after view](broadcast_after/match_broadcast.png) use the actual sunny
22-player Rovers Arena match, kickoff Close Broadcast camera, Balanced 60 and
640×360 Forward+ on Linux llvmpipe. Their [reports and manifests](validation.json)
record the exact adapter, commands, image hashes and bounded capture cleanup.
The 3,837-seat GPU alignment sample has zero errors in both views; maintained
turf remains 32,768 triangles in both. The v0.5.4 mowing and glare repair is
visually present in the new capture.

| Broadcast metric | v0.5.4 | v0.5.5 | Change |
| --- | ---: | ---: | ---: |
| Occupied modeled seats | 44,685 | 49,554 | +4,869 |
| Draw calls | 1,202 | 1,208 | +6 |
| Rendered primitives | 1,130,204 | 1,157,084 | +26,880 |
| Godot peak resident memory, KiB | 4,192,968 | 4,274,476 | +81,508 |

Peak memory is the Linux Godot process `VmHWM` while each matched capture ran;
it includes software Vulkan compilation and is not an M1 memory estimate.
The [native motion sequence](motion/match_broadcast.json) supplies close,
middle and far views, both teams' goal reactions and ordinary waving. The
reported sampled pole/hand gap is below 0.05 m at every station. Compare
[ordinary away supporters](motion/match_broadcast.png),
[the chance](motion/crowd_mid_chance.png),
[away celebration](motion/crowd_away_goal_close.png),
[a distant goal view](motion/crowd_away_goal_far.png) and
[home celebration](motion/crowd_home_goal_close.png). These are event and LOD
appearance evidence; only the matched kickoff views above are used for the
cost comparison.

## Validation and remaining acceptance

The 12-export audit checks garment masks, 80 bones and nine clips per model.
Serial hard-deadline Godot checks cover exact attendance and affiliation,
colour distribution, 64 flags, crowd reactions, both own-goal directions,
exact replay/live restoration, seating/presentation, graphics budget, replay
results and unchanged Kilmore behaviour. `test_arena_seating_alignment.py`,
`test_capture_native.py`, Python syntax and `git diff --check` pass. The known
cached-resource exit diagnostic remains in some smoke checks; no new script
or shader errors occur in native captures.

Next acceptance is BR-025 (25/27, in progress): inspect the published Mac
v0.5.5 crowd colours, flags and LOD transitions and measure the combined
1080p60 workload on the target M1 Pro / 16 GB Mac. Linux software-renderer
stills cannot establish that hardware result. Wider venue-likeness acceptance
for BR-023 remains in progress.
