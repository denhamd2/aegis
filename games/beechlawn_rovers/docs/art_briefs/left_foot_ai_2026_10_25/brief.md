# BR-019 + BR-008 — bilateral strikes and attacking choice

Approved order: BR-019 (19/27, in progress), then BR-008 (8/27, in progress).
Motion-only add-on on the shared 65-bone player template. Existing heads, eyes,
hair, bodies, kits, gaits, rest matrices and current clips remain unchanged.

The live game has only right-foot pass/shot/volley/half-volley clips. Receptions
already choose left/right. Ground and aerial strike guards sample the right toe,
and the AI returns any available shot before considering wide delivery. Its shot
style is selected only by zone. These are the scoped gaps; exact likeness,
keeper reach and M1 hardware acceptance remain separate work.

Use Godot-evaluated shipping right actions as motion authority, since their leg-roll
corrections can differ from an older Blender source. Bake mirrored world pose
deltas onto the unchanged source rest, preserving bone rolls and all contact
seconds. Four animation-only left clips, no runtime solver or extra locomotion
branches. Lock the chosen boot for the action and sample that live toe at contact.
Choose contextually from ball side/arrival; retain the stable right tie-break.

Validation: full-clip source/import symmetry and duration, one marker, actual
bilateral standing/moving passes/shots/crosses, both team directions, first-time
interruptions, off-axis misses and recovery. Native close/broadcast moving review
plus a matching Blender pose comparison. The AI follow-up must preserve open
central shots while comparing useful crosses/passes against tight-angle attempts;
record mirrored decision scenarios and six full seeded matches at each venue.
No shot quotas, forced goals, rating boosts or keeper nerfs. Final M1 feel/performance
still needs actual Mac hardware.

## Implementation findings

The base GLB starts its first keys at 1/60 s but lasts 0.9 s; shifting those keys
to zero shortened the left clips and moved contact. Preserve the initial hold.
Godot and Blender also evaluate the older cubic volley curves differently, so
`tools/export_strike_motion.gd` captures actual shipping right poses at 60 Hz.
The Blender recipe reflects their rest-relative deltas onto the unchanged master
rest and preserves the original three source hashes. New imported full-clip
mirroring differs by at most 0.317 mm across all 65 joints.

A 6.5 cm centre tie-break was wider than the forecast lateral placement of one
away volley (6.496 cm). A stable 4 cm centre corridor selects the intended boot
while the clip locks it for the full action. Both directions then retain close
left boot contacts for volleys and physically bounced half-volleys.

The live incoming left-shot test also exposed deferred method delivery one tick
after its marker. At 12 m/s the ball reached the body first. Ground pass/shot
markers now execute during physics animation evaluation, matching aerial actions;
contact radius and independent ball physics remain unchanged. Both incoming
side and recovery/interruption behavior are regression checks.

## Native render scope

The initial close-view attempt saved two frames near its 240 s limit after a
long software-renderer draw startup. It had not yet reached the shot marker.
A settled initial viewport and telephoto motion framing then completed the full
30-frame shot sequence with a real left-foot power strike (0.242 m toe gap),
goal and independent goal-net rebound. The normal head/cloth LOD follows the
actual camera distance; close skin and exact M1 appearance remain separate gates.
The Blender views use the protected source body and diagnostic base head, and
are pose/rig evidence rather than individual-face likeness approval.

## Completed validation

Nineteen unique regression scripts pass, including 25 moving ground-strike
cases, both-foot first-time returns, bilateral volleys/half-volleys, receive
isolation, pass/shot selection, goalkeeper response, player switching and
recorded faces. Twelve complete chance fixtures pass: Kilmore 30/19 shots and
6/6 qualifying fixtures for both teams; arena 27/36, qualifying 5/6 and 6/6.
Every fixture includes at least one contested shot from each team. One arena
fixture has a single Beechlawn shot, so broader tactical consistency stays open.
The unchanged full-match thresholds gate this pass; these totals do not claim
that every team's shot count increased versus the previous build. The unskipped
replay/celebration/full-time sequence also reaches results.

Three native sequences pass using actual production controllers and assets:
left power shot (0.242 m contact gap), left volley (0.103 m), and Colly Roden's
left driven cross (0.199 m) met by Damo Murphy's volley (0.047 m). Captures are
960×540 Forward+ on software Vulkan with explicit Balanced 60, not measured
Mac 60 fps. The videos use the simulation cadence reported in each JSON.
Original 190 protected character/source hashes and the 65-bone rest survive.

- [Ground strike sequence](native_shot_telephoto/match_broadcast.json)
- [Volley sequence](native_volley_telephoto/match_broadcast.json)
- [Cross and volley sequence](native_cross/match_broadcast.json)
- [Machine-readable validation](validation.json)

BR-019 (19/27) and BR-008 (8/27) remain in progress beyond this completed slice.
Recommended next: BR-021 (21/27, in progress), broader strike support-foot and
arm follow-through polish, followed by expanded aerial contests. Its next gate
is matching native moving reviews while preserving current real contacts.
