# BR-019 — lofted passing, crossing and aerial contacts

BR-019, item **19 of 25, in progress**, brought forward by the owner after the
keeper-handling pass. Scope: keyboard lofted passes/crosses, AI use and runs,
aerial receiving and attacking/defensive headers. Advanced shot variants,
volleys and full goalkeeper cross-claim motion remain separate acceptance gates.

## Production contract and reference gaps

Use the current shared human rig/body (`tools/blender/beechlawn/footballer_shared.blend`)
and current roster heads/kits. Relevant archived references: Shane #8 and the
other player turnarounds, John #1/keeper kits, worn-ball and goal/net sheets,
and the gameplay composite indexed in `references/README.md`. Static sheets
establish build, kit and ball scale; they do not establish a captured header
or chest-control performance. These motions are original authored animation,
not EA/PES or downloaded proprietary clips. No new paid assets.

Five gaps: no airborne pass control, no cross targeting/runs, ground-only
interception forecasts, no marker-gated forehead/chest contacts, and no authored
aerial motion/recovery. Current ground kick/receive events, shared rest/bind
transforms, source actions, meshes, heads, UVs, materials and kit graphics must
survive. New motion is an animation-only library on the unchanged 65-bone rig;
geometry and texture budgets do not increase. Author/export at 60 fps.

Active guides: create-player, production/animation checks, blender-director,
blender-animation, animation, rigging and godot-export. Use headless bpy, no MCP.
A short bounded CharacterBody jump supplies real vertical motion for a header;
no visual root translation drives the ball. Independent physics remains
60 Hz. Authored contact markers only open a short validation window; actual
forehead/chest proximity, incoming trajectory and action serial authorize the
impulse. Misses stay misses. The existing foot-contact marker gates loft/cross
kicks. No ball teleport, parenting, runtime shot quota or team-specific boost.

## Implementation and acceptance order

1. Damped ballistic launch/prediction, bounded directional targeting and power.
2. R hold/release loft, T hold/release cross; existing camera key C unchanged.
3. Animation-only header/chest clips, physical jump/recovery and contact checks.
4. Intended receivers, near/far-post runs, defensive aerial positioning and AI
   choice. Space requests a header in aerial context; ground shots retain Space.
5. Mirrored launch/landing, contact timing/misses, opponent contest, ground-flow
   and keeper regressions. Full-match tests must still produce contested shots.
6. Native moving close/broadcast views on both teams; actual head/chest/ball
   distances and complete clip transitions, then Mac package verification.

Before/after views use the same sunny match scene/camera/exposure. No cloud-sky
asset previews. Preserve the original source and export hashes before authoring.
A headless test alone cannot approve motion quality. Native cloud Forward+ is
appearance/integration evidence; M1 Pro input feel and 1080p60 remain unmeasured.

## Implemented, 22–23 October

- Separate `FootballBallFlight`, `LoftedPassPlanner` and
  `PlayerAerialController` modules keep prediction, targeting and contacts out
  of the tactical monolith. The damped ballistic solver predicts short airborne
  travel; real collisions, ground and bounces remain authoritative.
- R/T hold-release use directional candidate bounds and range/power; crosses
  target head height in the area. The selected recipient survives wind-up and
  starts its approach early; one extra attacker occupies the opposite post.
- AI wide carriers can cross, and blocked progressive lanes can trigger a lob.
  Nearby defenders forecast the descending ball, head clear in their area or
  intercept suitable midfield lobs with chest control. Ground decision priority
  is retained where useful. Team shape still comes from the tactical layer.
- Original Blender header/chest clips, exported separately on the unchanged
  shared rig, open anatomical contact windows. A header uses a real, bounded
  CharacterBody jump. Both contacts validate evaluated bone points within
  20 cm and the current action serial. Equal header reaches do not reward
  processing order. No ball repositioning occurs in the new action path.
- Opposing lofts/crosses enter the existing keeper reaction/catch/parry logic,
  preserving own-area restrictions, supported heights, reach and recovery.
  Dedicated jumping cross claims and low/dive animation remain open BR-009.

### Reproduced problems and corrections

The first chest fixture failed: the coarse capsule reversed the incoming ball
before the authored chest marker. A narrow forecasted exception to only that
actor's capsule allows anatomical contact; success, miss, interruption and
stoppage restore collision. The reach limit stays 20 cm.

Whole-cross fixtures then exposed a stationary intended receiver before local
reach, tactical outlet movement during foot wind-up, and delayed/unprimed aerial
animation callbacks. Reserving the run early, forecasting the intended receiver
before local reach, priming the clip and dispatching only aerial markers in the
physics animation step resolved these cases. Ground callback policy is restored
afterward. Fixture `seek` calls use update-only to avoid causing the event under
test. Synthetic physical keyboard events pass at normal 60 Hz; accelerated
physics bursts coalesced queued input, so keyboard tests use real cadence.

### Focused results

Five new regressions pass, with no assertions disabled:

| Check | Measured result/scope |
| --- | --- |
| Flight | Mirrored 12/28/40 m launches; maximum landing error 0.2083 m |
| Contact | Two attacking headers and four chest controls, including opposing-lob interceptions; physical jump about 0.266 m; measured header gap 0.110–0.113 m |
| Safety | Remote/mistimed misses, interruption/collision cleanup, equal/closest contests in reversed evaluation order |
| Keyboard/keepers | One actual R and T charge-release launch; opposing deliveries can be saved/caught; own kicked pass is excluded |
| Whole cross | Foot marker → AI approach → forehead header in both directions; defended attempts have opponent distance about 1.77/1.79 m at contact |

No perfect mesh collision or commercial animation-quality claim follows from
these distances. The anatomical point plus sphere reach is gameplay assistance.
Chest control has a committed short recovery; buffered follow-up combinations
during that clip are not newly implemented. Motion assets and native fixtures
cover this initial slice, not every aerial height or contest outcome.

### Native and Blender evidence

`header`, `chest`, `cross_home` and `cross_away` evidence directories contain
numbered frames assembled at 10 fps from six real 60 Hz ticks per frame. Their
JSON records adapter, actor identity, ball path and actual contact points. Close
fixtures use actual Shane and explicitly scripted incoming balls. Broadcast
fixtures use actual production foot delivery and live receiving/defending AI
with a keeper; unrelated actors are parked. They establish controlled native
integration, not natural chance frequency or Mac performance.

Blender stills use the source diagnostic head and are labelled accordingly;
current roster likeness comes from native views. The animation audit samples
every authored frame and preserves protected-source hashes. Shared body/base
GLB, existing clips, heads and kit textures are unchanged.

### Remaining acceptance

BR-019 (19/25) stays **in progress**. Native M1 input feel and 1080p60 are
unmeasured. Volleys/half-volleys, driven/early/lofted cross variants, finesse and
low-shot variants, richer aerial duels and dedicated goalkeeper high-claim
motion are still open. The recommended next focused gameplay work is BR-009
(9/25), original directional low-save/dive motion with measured hand contact,
using the current airborne prediction as a dependency rather than expanding
keeper reach. Full first-time receiving/combinations and stride/plant polish
remain BR-021 (21/25).

## Full-match acceptance and delivery gate

The 17 selected existing contact/movement/keeper/ground-flow regressions pass,
alongside all five new aerial checks. Six complete seeded sunny short matches
finish with no long ball stalls. Physical shots and contested attempts:

| Kickoff / variation | Beechlawn shots (contested) | Boardeaux shots (contested) |
| --- | --- | --- |
| Home / 0 | 5 (5) | 3 (1) |
| Home / 1 | 5 (4) | 6 (4) |
| Home / 2 | 3 (2) | 2 (2) |
| Away / 0 | 1 (1) | 6 (4) |
| Away / 1 | 5 (5) | 3 (2) |
| Away / 2 | 4 (3) | 7 (6) |

The unchanged chance gate passes: Beechlawn qualifies 5/6 scenarios, Boardeaux
6/6; aggregate shots 23/27 (46%/54%). The one-shot Beechlawn scenario remains
visible as a tuning limit. These are acceptance thresholds in test code, never
runtime quotas, forced goals or team-specific boosts. Full metrics are in
`full-match-summary.json`; CI repeats its full regression matrix and six matches
before universal Mac export/ZIP validation and release publication.

Natural aerial counts (Beechlawn / Boardeaux): crosses **7/11**, headers
**4/3**, lofted passes **0/1**, chest controls **1/0**. Crosses and headers
appear in ordinary play. Lob/chest usage remains rare; the mirrored focused
fixtures prove those paths work, but they do not establish varied natural
frequency. Preserve this as future BR-008/BR-019 tactical tuning, alongside
the one low-chance scenario, rather than forcing actions to satisfy quotas.
