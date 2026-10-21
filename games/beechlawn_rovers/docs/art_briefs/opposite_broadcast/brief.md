# Opposite-touchline broadcast — 21 October 2026

BR-014, item 14 of 25, remains in progress. The owner requested the gameplay
broadcast camera on the opposite side of the pitch.

Reviewed the archived broadcast composite, the art-reference implementation
plan and the eight-heading Street View contact sheet under
`references/google_captures/street_view/`. The reference goal is readable,
close Sunday-league match framing with the surrounding park behind the action.
The owner's requested side supersedes the previous camera-side convention.
Applied the camera-cinematography guide's composition and move-end checks;
this is a Godot camera change with no Blender geometry or asset edits.

All six sideline preset offsets now use the opposite Z side, retaining their
heights, offset magnitudes and FOVs. Close Broadcast remains 12 m high and
26 m from its focus at a 50-degree FOV. Switching between sideline families
preserves the match axis. End-to-end, player and overhead presets retain
their own viewing conventions. Existing camera-relative movement and aiming
use the live camera basis, so screen-right now means the corresponding
opposite world direction. The moving-contact fixture chooses that screen
direction explicitly instead of assuming that world-right is screen-right.
The reversal fixture does the same for world-left; its old hard-coded
screen-left command correctly accelerated from this side rather than braking.
The isolated aim fixture now requests a genuinely lateral screen-up shot from
either touchline when checking goal assistance.

Validation: `broadcast_camera_smoke.gd` checks every preset's visibility and
screen-relative keyboard movement, opposite touchline placement, and default
framing at both goal/touchline extremes. `pre_match_intro_smoke.gd` covers
natural/skip handoff and kickoff. The actual Web match capture is
[broadcast.png](broadcast.png), with browser results in
[web_review.json](web_review.json). Software WebGL capture has sun shadows
disabled; native Mac lighting, performance and human playtesting remain open.
Venue and player art fidelity are unchanged by this framing adjustment.

Follow-up: the lineup sweep lasts 12 seconds rather than 4.2. Its unchanged
17 m eased dolly peaks at about 2.13 m/s instead of 6.07 m/s. The intro regression
checks that speed, natural completion, skip and kickoff restoration. The final
handoff now begins on the selected gameplay camera's side, avoiding a fast
cross-pitch move from the previous hard-coded side. Boardeaux is the confirmed
team spelling across runtime ownership labels, UI, messages and shirt prints;
lowercase legacy resource filenames/IDs remain stable, and archived evidence
retains its original captured text.

The refreshed title, lineup and broadcast captures show the corrected spelling.
Capture checks completed without game console errors. The one-off capture
driver timed out during its final `about:blank` cleanup navigation afterward;
the Playwright context exited and no live browser processes remained. This
cleanup result is separate from the recorded rendering/intro checks.
