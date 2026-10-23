# Turf, broadcast direction and four-head follow-up

The owner chose the presentation/turf pass before the four likenesses, retaining
Mac-only delivery and free/original assets. This updates BR-023 (23/27),
BR-026/027 (26/27, 27/27), then BR-022 (22/27). Primary IDs/order remain intact.

## Reference-to-asset gaps and changes

- The earlier sparse tufts read as tall weeds in the owner's screenshot. They
  are replaced by 15.3–28.8 mm tapered leaves with three leaves per crown.
  Camera-local .75 m cells provide denser coverage at the same six triangles
  per crown. At most 16 active cells/40k crowns/240k triangles draw; one hidden
  next-shot set has the same maximum residency and builds incrementally before
  a cut. Broadcast-distance turf retains its surface material. World-space
  detail/normal/roughness sampling blends with the blades, mud thins growth and
  standing-water masks exclude it. No blade physics or blade shadows are added.
- Venue, team, referee and match captions share a 72%-width blue lower third,
  capped at 1200 design pixels (1152 at 1600×900), centered 36 pixels above the
  lower edge. Height is 104; protected end artwork, centered text, two-line
  spacing, safe margins and eased entrance replace separate left anchors.
  The scoreboard retains its top-left location and blue identity.
- Goals use a six-second wide/medium/scorer-close sequence. Replays show up to
  six seconds of the move and then up to three seconds of half-speed contact
  from another station. Saves/posts/cards use shorter corresponding coverage.
  Full time retains twelve seconds, cutting through reactions, medium views
  and handshake close-ups. Camera cuts snap to their new station; damping
  applies within the shot. Obstructions select an alternate side, then a stable
  wide fallback, while net weave and hidden live replay actors are excluded
  from opaque-occluder checks. Gameplay cameras are restored on finish/skip.
- Incident metadata supplies recorded time, participant and team. Ghosts retain
  real meshes/materials and recorded bone, facial, ball and net poses. Live
  physics, rules, clock, goals and audio events remain isolated during replay.
- The four heads retained an overlong common crown, hollow/angular cheek
  planes and insufficient individual nose/mouth proportions. Repeatable Blender
  source edits shorten crowns, soften cheeks/jaws with protected apertures,
  refine those proportions, strengthen brows and retain separate grooms. Shane's
  crop is shorter, John's blonde scalp and brown beard remain independent,
  player Des retains a receded crown/goatee, and the older referee retains grey
  facial hair and structural age folds. Regional linear roughness replaces the
  nearly uniform brightness-derived map. Fitted blink and restrained smile
  shapes animate per instance and are recorded in replays.
- The original shared body, rig, neck interface, UVs and shipping gait leg/root
  keys remain protected. The four sources, recipes and exports agree under the
  updated integrity audit. Football-only create-player guidance records the
  silhouette, roughness and expression lessons.

## Research and provenance

Konami's [PES2021 description](https://www.konami.com/games/eu/en/products/pes2021/)
confirms enhanced turf and realism; its [PES2020 presentation description](https://www.konami.com/games/eu/en/products/pes2020/)
describes broadcast presentation and replay detail. Neither documents the exact
FOX Engine grass implementation. Our short geometry/surface blend is an original
Godot implementation, using [MultiMesh guidance](https://docs.godotengine.org/en/stable/classes/class_multimesh.html),
not an assertion that PES models every field blade or uses our precise method.
Matching Grass005 normal/roughness maps are CC0 from ambientCG; their source,
license and SHA-256 hashes are stored alongside them. The existing colour map
matches the downloaded package byte-for-byte. Player portraits and kit sheets
remain the archived originals in references/README.md; no portrait plane or
projected face image is introduced. Body/animation assets remain shared.

## Verification and limits

Focused checks cover responsive banner bounds at 1280×720, 1920×1080 and 4:3;
both teams' celebration cuts; incident metadata/half-speed poses; replay
isolation/skip/results; actual head/eye/groom selection and live blinks;
unchanged gait/pose safety; intro staging; turf geometry/terrain/water masks;
weather, net contact, HUD and full-body keeper contacts. Handshake partners
now walk within 15 mm of their targets: the live right-wrist gap is 0.174 m,
allowing the hands to meet without moving the players into a scripted line.

The test runner now stops script/assertion failures immediately. A healthy
180-second match advanced through 12,572 physics ticks in about 64 host seconds;
the former 75-second deadline had little cold-start/host-load margin. Longer
bounded budgets and progress records distinguish this from a frozen match.
A separate teardown regression reproduced four unparented restart controllers
from four unstarted review scenes. Creating and parenting that node together
in _ready removes the leak and preserves normal match initialization.

Native Forward+ evidence uses Linux llvmpipe at 960×540. The outro is a labelled
scripted integration fixture, not proof of a naturally generated goal. Head
views are actual roster assets on the pitch; Blender views check source forms.
Software captures do not certify native M1 appearance, animation feel or 60 fps.

The heads are improved, **not approved as exact/AAA likenesses**. The base still
reads generic in parts of the orbital/muzzle anatomy and needs further
individual sculpt/hair/skin finishing against the originals. Hidden side/rear
anatomy remains estimated. BR-022 remains open; those artistic gaps cannot be
closed by an import audit. Exact venue realism and M1 acceptance also remain
open. The final validation manifest records completed checks and release status.
