# Lighting against WWE 2K26 — measured, with a plan

The owner asked for the game's lighting, entrances and match, to match WWE 2K26
as closely as possible. This file records what was measured and what to change,
in priority order. Nothing here is implemented yet.

## Sources

- 2K26 entrances: 70 frames from the storyboard of
  [WWE 2K26 Entrances: Cody Rhodes, John Cena, Roman Reigns, Seth Rollins](https://www.youtube.com/watch?v=V_zBO1vzw7A)
  (Roman and Cody).
- 2K26 match: 112 frames from the storyboard of a full 2K26 Cody vs Orton match.
- Ours: 84 Vulkan (Forward+) entrance frames from `entrance_shots.tscn`, and
  match frames from `match_look.tscn`. Vulkan only; the OpenGL fallback drops
  lights and does not count.
- Reviews agree on four things:
  - "the lighting does a lot of the heavy lifting";
  - dynamic shadows across the ring and crowd;
  - sweat that "glistens under arena lights";
  - improved particle lighting from pyro.

  ([Vital Clash](https://www.thevitalclash.com/2026/02/wwe-2k26-graphics-look-unreal-and.html),
  [Voices of Wrestling](https://www.voicesofwrestling.com/2026/04/25/wwe-2k26-review-bigger-budgets-bigger-expectations/),
  [Operation Sports](https://www.operationsports.com/wwe-2k26-vs-2k25-early-graphics-comparison/))

## The measurement

Medians per frame, from `scratchpad/look/stats.py`, on the same maths as
`tools/refs/measure_look.py`. The storyboard tiles are small and compressed,
so treat these numbers as bands, not exact targets.

| | p50 | p90 | p99 | bright >0.5 | dark <0.01 | saturation | white balance B/G |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 2K26 entrance | 0.013 | 0.225 | 0.871 | 4.0% | 43.8% | 0.48 | 1.03 |
| ours, entrance | 0.041 | 0.590 | 0.835 | 12.6% | 26.9% | 0.48 | 1.03 |
| 2K26 match | 0.078 | 0.474 | 0.630 | 7.2% | 1.7% | 0.23 | 1.16 |
| ours, match | 0.072 | 0.702 | 0.759 | 21.7% | 0.2% | 0.29 | 1.09 |

**2K26 runs two different lighting looks:**

- **Entrance — a concert.**
  - Nearly half the frame is black.
  - A few very hot sources: the titantron, fixture lenses with star glints,
    and pyro.
  - The colour washes are saturated.
- **Match — a TV studio.**
  - The whole hall is evenly lit. Almost nothing is black, and the crowd is
    visible as people.
  - The key light is a cool white.
  - The mat is a light grey with texture, not a glowing sheet.

**Where we differ:**

- **Entrance:** our frames are about 3× too bright in the mid-tones. The neon
  portals and the titantron fill the frame and are lit flat. When the
  wrestler is lit on the in-ring low shots, his white gear blooms into a
  glow.
- **Match:** 22% of our frame is hot against 2K26's 7%. Almost all of that is
  the canvas: on the low ringside shots it reads milky white. Our crowd is a
  blue silhouette in haze; theirs reads as faces and colour. The haze also
  lifts our blacks, giving the frame a grey veil.

## Recommendations — the match (most screen time, so first)

1. **Bring the mat down to a textured light grey.**
   - Target: the mat at 0.40–0.45 on the ringside shot, and the share of the
     frame above 0.5 under 10%.
   - Lower the top-fill and key energies (or the mat's albedo) on the
     gameplay camera's angle. Re-check that wrestlers still separate from the
     mat with `measure_silhouette.py`.
   - Add a subtle canvas normal and roughness map so the light breaks up
     instead of reading as a sheet.
2. **Light the crowd as people, not silhouettes.**
   - 2K26's crowd sits around 0.05–0.10 with warm skin and colour.
   - Raise the house wash on the first 8–10 rows only, warm (about 4000 K).
     The far bowl falls off into dark.
   - Note: `lighting.md` found that the house fixtures do not reach the bowl
     today. The bowl is lit by `_house_lit` emission, so the fix is the near
     rows' emission plus a real light per section. Turning the wash up alone
     will do nothing.
3. **Clear the veil.**
   - Cut the ring-area haze (`FOG_DENSITY`, `ring_reach`) by about half
     during the match. Keep the hall haze for shafts in the upper bowl.
   - Target: dark pixels at about 2%, so blacks are black again.
4. **Cool, crisp key with a stronger rim.**
   - 2K26's key is cooler (B/G 1.16 against our 1.09). Shift `KEY_COLOR`
     toward about 6500 K.
   - Raise `RIM_COLOR` energy so shoulders and heads catch a bright edge
     against the crowd. This is the "pops" reviewers describe.
5. **Sweat sheen.**
   - 2K26's skin glistens under the rig. Ramp a wet specular (lower
     roughness, a clear-coat layer) as the match goes on, driven by match
     time and damage.
   - The material hooks exist from AAA item 6. This is a ramp, not new
     shading.
6. **LED boards as light sources.**
   - In 2K26 the ribbon boards and barricade LEDs throw purple and blue onto
     the front rows and the apron.
   - Give ours emission that lights the scene: SSIL picks it up, plus a few
     low-energy coloured omnis along the ribbon.

## Recommendations — the entrances

7. **Darken the house to concert level.**
   - Target: about 40% black and p50 about 0.015.
   - `_dim_house` already dims the rig. Take it further, and dim the bowl's
     emission to near-off for the walk, so only the stage, beams and
     follow-spot read.
8. **Star glints on the fixtures.**
   - 2K26's signature: 6–8 point star filters on every lens facing the
     camera (Roman's opening shots).
   - Add a camera-facing additive star sprite at each fixture lens. Scale it
     by how directly the lens faces the lens of the camera.
9. **Moving beams on the music.**
   - Our 16 beams are static (`arena_lighting.gd`: "Static, not sweeping").
   - 2K26 sweeps and chases them through the haze. Animate pan and tilt, and
     strobe on the beat. Roman's beat grid now exists (A4), and Cody's music
     is already measured.
10. **Stop the in-ring bloom wash.**
    - On the in-ring low shots our wrestler blooms into white (Cody's coat
      under the corner lights).
    - Raise `glow_hdr_threshold` for entrance close-ups, or cap the
      follow-spot energy in the ring, so gear keeps its texture as 2K26's
      does.
11. **Titantron and portal light the man, not the frame.**
    - Pull the titantron and portal emission down a stop on camera, keeping
      their light contribution, so the screen is hot but not frame-filling
      white.
    - A coloured backlight from the tron should edge-light the wrestler. That
      is how 2K26 separates him from the screen.
12. **Hard white top light on the in-ring pose.**
    - When he poses in the ring, 2K26 hits him with a hard overhead white
      against a dark crowd: Roman's ring shots, tiles 51–58.
    - Add a narrow top spot cued on the pose beats, with the house down.

## Effort and order

| # | Item | Effort | Look gained |
| --- | --- | --- | --- |
| 1 | Mat to grey + texture | small | high |
| 3 | Clear the veil | small | high |
| 2 | Crowd lit near rows | medium | high |
| 4 | Cool key, stronger rim | small | medium |
| 7 | Concert-dark entrance | small | high |
| 10 | No in-ring bloom wash | small | medium |
| 8 | Star glints | medium | high (signature) |
| 9 | Moving beams on the beat | medium | high |
| 11 | Tron/portal exposure | small | medium |
| 12 | Hard top light on poses | small | medium |
| 5 | Sweat sheen ramp | medium | medium |
| 6 | LED boards as light | medium | medium |

**Gate:** each item is verified on Vulkan frames with this measurement and
`measure_silhouette.py`. The mat↔wrestler separation in `VISUAL_BAR.md`
stays the priority-1 bar.
