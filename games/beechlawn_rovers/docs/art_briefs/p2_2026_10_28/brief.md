# P2 full-team formations and tactics — 28 October 2026

Baseline: `2c7e3e846ec064a054cbeb7cd9bb26efdca111e0` (Mac v0.5.7).
Scope: BR-011 through BR-014. The archived [69022 broadcast view](../../../references/source_uploads/chat_attachments/football_reference_upload_round_1/1-69022.jpg)
and [70060 stadium HUD view](../../../references/source_uploads/chat_attachments/match_hud_stadium/70060.jpg)
remain the camera and HUD references. The camera, stadium, crowd, turf and
player art were not remodeled for this pass.

## Implementation

The 11v11 team resource now offers 4-4-2, 4-3-3, 4-2-3-1 and 4-5-1. A match
copies each starting profile before assigning its team-relative position and
role. Identity, shirt, appearance, source squad and 4v4 resources remain
stable. Each lineup card uses the selected formation. Defensive midfielders
stay behind attacks; attacking midfielders run into advanced support. Existing
keeper, back, winger and striker positions still use the same fixed-step AI.

Width spreads lanes and outlets; depth changes the defensive line; pressing
controls the extra presser; directness changes forward-run and progressive-pass
selection; tempo changes carry distance and AI action cooldown. A second
presser comes from midfield or attack for full teams, retaining the back four
and holding midfielder. Existing ball-side shifts, outlet/runner triangles,
selective turnover counterpress and late lead protection continue.

## Validation

The new `p2_formations_tactics_smoke.gd` validates all four 11-player role
counts and unique positions, unchanged source/4v4 data, eleven lineup cards
per formation, mirrored away kickoff, width/depth/press response, defensive
cover and late lead adjustment. It passes in 7.1 s. Existing 4v4 tactics,
transition and 4-4-2 lineup checks pass. The default 180 s AI match produced
2/7 shots, 1/1 goals and no stationary-ball stall. A 4-3-3/4-2-3-1 match
produced 4/2 shots, 1/1 goals and no stall; a 4-5-1/4-4-2 match produced
2/7 shots, 0/2 goals and no stall. Both sides entered the final third in all
three matches. The nine-camera, broadcast direction, HUD/radar, graphics
budget and frame-profiler smokes also pass.

The matched [640×360 arena capture](budget/) has 1,208 draw calls and
1,157,084 primitives, identical to v0.5.7. Its peak Linux RSS is 4,311,156
KiB versus 4,289,380 KiB at baseline; the roughly 21 MiB difference is
process variation, with no new player geometry or rig. The [1280×720 stadium
frame](broadcast/) shows the 22-player kickoff, referee, score, clock, radar
and player labels in the live Forward+ composition. Both captures report the
llvmpipe software Vulkan adapter and zero stadium seating audit errors.
The [24-frame live attack sequence](live_attack/) advances the 60 Hz physics
loop by six steps per rendered frame under the shipping broadcast camera. The
camera follows a staged Beechlawn attack into the goalmouth; a physical shot
contact occurs at tick 19 and the live score changes to 1–0 by tick 144.
This staged fixture checks moving body/camera/score presentation; the three
full AI soaks above check naturally generated chances.

These checks establish cloud simulation and appearance only. Native M1
camera/input feel, physics and animation frame time, and sustained 1080p60
remain BR-013/014/025 acceptance checks.
