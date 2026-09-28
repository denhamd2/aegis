# Ropes: how they behave when a body meets them

The reference for `game/core/ring/ring_ropes.gd` (the live ropes), the
`Rope_Rebound` clip, the springboard's rope contact, and the Irish whip's rope
load in `wrestler_controller.gd`. As with every file in this folder, it holds
measurements and the derivations from them. It is not a matter of taste.

## Construction (published specs)

- **Cable and cover.** A wrestling rope is steel cable inside a rubber or
  vinyl hose sleeve, about 1–1.5 in (25–38 mm) across, then taped.
  - The game's rope is 36 mm across (`ROPE_RADIUS` 0.018).
- **Tension.** Each span is tightened at the corner turnbuckles. A tight rope
  keeps a wrestler from going through the ropes; a looser one gives more on
  rebounds.
- **Spacing.** Three ropes at about 1, 3 and 5 ft on a 20 ft ring.
  - The slice's ring is 6 m inside the ropes, with ropes at 0.5, 0.85 and
    1.2 m. Those numbers are frozen by `refs/ring.md` and `camera.md`.
- **Ties.** Rope ties join the three ropes at mid-span on some rings. They are
  not modelled; each span moves on its own.
- No published figure gives deflection or vibration. Those numbers are
  derived below and checked against footage.

## Footage (WWE.com, `30-second-fury-rey-mysterio-s-619`)

- **Man draped over the middle rope near the corner.** The rope bends to a
  sharp V at the point of contact and stays straight either side of it. The
  top rope is untouched. Close to the post there is visibly less give than
  mid-span, which is what a string pinned at the turnbuckles does.
- **619 swing and springboards.** The rope being stood on or swung through is
  pressed or pulled out of line by roughly a hand's width to a forearm's
  length (~0.1–0.3 m). The neighbouring rope stays put. After release the rope
  rings for a few visible swings, not a buzz.
- **Going through the ropes (tope, roll out, roll in).** The two ropes either
  side of the body part around it: the upper one rides up over the shoulders,
  the lower one is pressed down under the chest and hips.

## Derived numbers

- **Rebound deflection.**
  - A 110 kg man running into the ropes at 5–6 m/s takes the rope ~0.3–0.5 m
    out of line.
  - Stopping him over that distance needs an effective stiffness k of about
    m·v²/x² ≈ 17 kN/m, with a contact time of about 0.25 s (half a period of
    that mass on that spring).
  - The game's whip launches at 9 m/s (`IRISH_WHIP_LAUNCH_SPEED`), which is
    gameplay tuning, not measurement. The load depth is therefore capped
    rather than scaled with speed.
- **Free vibration.**
  - A span's fundamental is f₁ = (1/2L)·√(T/μ). For a ~6 m span of taped 1 in
    cable at working tension, that gives 7–10 Hz.
  - We use **7 Hz**. The hose and tape damp out the top of that range, and
    the footage shows a slow, heavy wobble.
  - Damping ratio is **0.08**: the rope rings down to a third in about
    0.35 s, which is two or three visible swings.
- **Maximum deflection.** The rope is capped at **0.75 m** out of line. Past
  that, a body is going through the ropes, not stretching them.

## What the game does with them

| Contact | Where it lives | Target | Measured (`tools/probe/rope_shot.tscn`) |
| --- | --- | --- | --- |
| Rebound off the ropes (dive spot) | `Rope_Rebound` clip; body side-on, arm over the top rope | 0.3–0.5 m | 0.53 m peak on the top and middle ropes |
| Irish whip into the ropes | `wrestler_controller.gd` rope load | 0.3–0.5 m, ~0.25 s contact | see the rope-load tests |
| Out through the ropes (roll out) | contact only | ropes part | 0.35 m |
| Tope suicida through the ropes | contact only | ropes part | 0.46 m |
| Roll in under the bottom rope | contact only | rope lifted | 0.46 m |
| Springboard off the middle rope | `Springboard_DK_Attacker` boot on the rope | ~0.1–0.2 m down | 0.17 m |

The ropes are **one-way and cosmetic**:
- Bodies are sampled into spheres along their bones, and rope nodes are
  pushed out of them. Nothing pushes back on a body.
- The rope colliders in `scenes/ring.tscn` are unchanged.
- The only gameplay change is the whip's rope load. The AI never whips
  (`wrestler_ai.gd`), so AI matches are not affected by it.
