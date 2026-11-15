# Kenny continued likeness review: corrected round 6

**Verdict: recovery to an effective tie with published round 3, not a demonstrated likeness improvement.**
**Overall: 4.6/10** (raw weighted score 4.575).

| Criterion | Weight | Round 6 /10 | Contribution |
| --- | ---: | ---: | ---: |
| Head and face | 40% | 4.0 | 1.600 |
| Hair | 25% | 4.0 | 1.000 |
| Body proportions | 20% | 6.5 | 1.300 |
| Skin and materials | 15% | 4.5 | 0.675 |
| Total | 100% | **4.6** | **4.575** |

Score sequence: baseline 4.1; rounds 1–6: 4.0, 4.5, 4.6, 4.1, 3.9, 4.6.
The highest supported states are round 3 and corrected round 6, effectively tied.
These subjective scores do not imply measurement precision to a tenth of a point.

## Evidence

All nine actual textured runtime captures in
`/tmp/aegis-kenny-judge/round6-final` were inspected: head front, three-quarter,
side and back; hair top; body front, three-quarter, side and back. Published
round 3's front, back and top views were also inspected directly alongside
the new state. Cameras, lighting and the rubric are unchanged.

The targets remain the four directly inspected primary repository references
in `gauntlet/refs/characters/`: `kenny_3view.jpg`, `kenny_omega_sheet.png`,
`kenny_hair_top.png` and `kenny_hair_back.png`. The owner has confirmed these
are the correct target. Brown irises remain an accepted owner preference.

## What round 6 establishes

- Restoring the earlier face removes the round 5 forehead-track regression.
  It returns to the same approximate facial identity that supported round 3's
  face score; it is not a new eyebrow or facial-shape likeness gain.
- Dense hair mass is recovered, and the forelock sits closer to the head than
  the rigid forward hook in round 4. This is substantially better than the
  exposed helmet-like round 5 state.
- Nevertheless, plain cap exposure remains at the crown/back and the visible
  clumps are still broad, stiff pale ribbons rather than the reference's loose,
  irregular rounded curls. The cleaner forelock and remaining cap/ribbon
  limitations do not establish an overall win over the published round 3.
- Body proportions are stable and broadly athletic. Coarse brow/skin detail,
  opaque beard coverage and residual shoulder/pectoral surface stretching
  continue to limit realism. The generic over-scowled facial identity remains
  the largest weighted problem.

No new obvious static missing-geometry/render failure was found in these views.
This supports retaining round 6 as a recovered engineering/art candidate with
notes, but does not justify claiming that it improves likeness over round 3.
Neither state reaches close-reference or 10/10 likeness acceptance. Source
independence, protected rig weights, test counts and renderer success are
separate engineering evidence and earn no visual points.

## Highest-payoff strategy beyond the plateau

Change the authoring approach rather than continuing small brow/card parameter
adjustments on the same generic foundation:

1. **Reference-measured neutral head sculpt.** Lock front, profile and
   three-quarter camera/landmark overlays. Fit forehead/brow, eye setback,
   nasal bridge/tip, cheek-to-jaw transition and chin silhouettes in a neutral
   clay material before evaluating face pigment. Preserve the established rig
   and protected eye/neck constraints, then validate deformations on the
   accepted shape. A new coefficient or a rebaked copy alone is not proof of
   a Kenny-specific sculpt.
2. **Authored hero curl groom.** Build overlapping curl masses following
   curved growth paths, including an asymmetric forelock and natural nape
   volume. First pass the grey silhouette and crown/back coverage against the
   actual top/back references; then bake/render finer strands and alpha detail.
   A visible flat cap plus decorative ribbons is not that foundation.
3. **Texture detail after shape acceptance.** Re-bake skin/brow detail onto the
   accepted geometry, control stubble density and local roughness, and check
   UV/material continuity before adding more pores or shine.

Iteration count does not close the owner's likeness goal. This review neither
stops work solely because six revisions exist nor promises that another small
parameter loop will improve the score. Full-arena appearance, animated hair,
native M1 performance and exact photographic camera matching remain outside
the evidence from these fixed studio captures.
