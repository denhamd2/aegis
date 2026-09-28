# The AAA gap: what makes WWE 2K26 look real, and what we can do about it

The owner asked for research into WWE 2K26's lighting, modelling and texturing,
and for a list of improvements that the tools this repo actually has can
deliver. Those tools are:
- Godot 4.6 Forward+
- headless `bpy` 4.2
- Python with PIL and numpy

Every item below is feasible with them. Anything that isn't feasible is listed
at the end with the reason.

## What 2K26 does (sources at the end)

- **It is last-gen-free.** Visual Concepts dropped PS4/XB1 for 2K26, so every
  budget went to current hardware: better character models, hair and physics.
- **Hair.** Hair textures are "much crisper" than in 2K25. Hair uses two-tone
  colour blending (root to tip), real hair physics, and saturated highlights.
- **Lighting carries it.** Reviews credit the lighting with "doing a lot of the
  heavy lifting" in making it feel like a broadcast. The 2K26 lighting is a
  touch brighter, which lifts colour.
  - The ring is lit hard from an overhead truss.
  - The crowd falls away into the dark.
  - The white mat bounces light up onto the wrestlers.
  - Ray-traced reflections are on, on PC and PS5.
- **Presentation.** Camera angles were reworked toward the TV broadcast.
  Particle lighting was added: pyro and sparks light the wrestlers and the set.
  Player-triggered pyro is part of the entrance.
- **Skin.** Faces are scanned. Skin is soft-lit by subsurface scattering, has
  pore-level detail and specular breakup, and builds up sweat over a match.
- **Colour.** 2K26 reads "more vibrant" than 2K25. The grade does real work.

## What we have (audited in this repo, September 2026)

| Area | Status | Where |
| --- | --- | --- |
| Filmic tonemap, glow, SSAO, SSR, volumetric fog, saturation lift | Have | `scenes/match.tscn` Environment |
| Shadow-casting ring keys, fixtures with shafts | Have | `core/lighting/arena_lighting.gd` |
| **Anti-aliasing** | **None**. No MSAA, TAA or FXAA in `project.godot`. | This is the jagged edges on hair, ropes and shoulders in the owner's screenshots. |
| **Skin subsurface scattering** | **None**. No material sets `subsurf_scatter`. | Skin reads as painted plastic under the keys. |
| Reflections for metal | None. No ReflectionProbe, and the hall ambient carries none. | Posts, title plates and turnbuckle hardware go near-black between lights (see the notes in `ring_builder.gd` and `entrance_props.gd`). |
| Bounce light from the mat | None. SSIL and SDFGI are off. | Chins and torsos lack the lift a white canvas gives them. |
| Sweat | None | |
| Hair anti-aliasing | Alpha scissor only, except Roman's alpha-to-coverage | Cody's hair shells stair-step. |

## The improvements, in order of look gained per hour

Each item is small and self-contained. Each must be verified on a render
through `tools/capture/`, then `round_check.sh`, before it counts.

1. **Anti-aliasing.** This is the single biggest "not AAA" tell in the current
   frames.
   - Turn on MSAA 4x plus TAA in `project.godot`
     (`rendering/anti_aliasing/quality/msaa_3d`, `use_taa`).
   - Switch Cody's hair shells to alpha-to-coverage, as Roman's hair already
     is.
   - Tools: settings only.
   - Risk: frame cost. Measure it on the capture rig.
   - Recalibration: the evidence gate's edge metrics may move, so rebaseline
     deliberately.
2. **Skin subsurface scattering.**
   - Set `subsurf_scatter_enabled` with skin mode on every skin material:
     `RomanModel` / `CodyModel` / `KennyModel` `SKIN_MATERIALS`, around
     strength 0.35–0.5.
   - Turn on transmittance so ears and fingers glow red when backlit by the
     rim lights.
   - This is what makes 2K's faces read as flesh.
   - Tools: material parameters.
3. **A ReflectionProbe over the ring**, plus a dim reflected ambient.
   - Posts, turnbuckle hardware, the title belt and the ring steps finally
     reflect the arena. Skin gets a real specular environment too.
   - It retires three separate "emission so metal isn't black" workarounds.
   - Tools: one node in `match.tscn`, set to update once.
4. **Screen-space indirect light (SSIL).** The bright canvas bounces onto the
   wrestlers from below, which is 2K's under-lift on chins and chests.
   - Tools: an Environment toggle.
   - Recalibration: re-measure the mat exposure anchor in `VISUAL_BAR.md`.
5. **Sweat over the match.**
   - A per-wrestler `sweat` value from 0 to 1, driven by ticks and damage
     taken.
   - It lowers skin roughness from about 0.5 to 0.25 and raises specular.
   - A small tiled pore normal map adds a highlight breakup that only shows
     once he is wet.
   - Tools: GDScript and one numpy-generated normal texture.
   - It is presentation only, so the determinism contract is untouched.
6. **Pore / micro-detail normal on skin.**
   - Generate a tiling pore-and-fine-wrinkle normal map procedurally with
     numpy, and apply it as `detail_normal` at a small UV scale.
   - It breaks up the perfectly smooth highlight that reads as CG.
7. **Hair shading.**
   - Anisotropic specular along the strands, using Godot's `anisotropy` with
     the strand flow already baked in `cody_hair.py`'s UVs.
   - Root-to-tip two-tone, which Cody's shells already have. Deepen it and
     add it to Roman's.
   - This matches 2K26's headline hair improvement.
8. **Soft shadows on the ring keys.**
   - Give the four shadow-casting ring keys a `light_size` for
     contact-hardening (PCSS) shadows: crisp at the feet, soft away from the
     body, the look of a big truss fixture.
   - Tools: four numbers.
9. **Particle light from pyro.**
   - Each pyro burst in `entrance_pyro.gd` gets a short-lived OmniLight
     flicker, so sparks light the wrestler and the set as 2K26's particle
     lighting does.
   - Tools: GDScript.
10. **Broadcast post-processing.**
    - Depth of field on entrance close-ups and the face-off, using
      CameraAttributesPractical far blur.
    - A very light vignette, and sensor grain on replays.
    - Evaluate AgX tonemapping against the current filmic curve. It gives
      broadcast-like highlight roll-off on white gear and the bright mat, but
      needs the `VISUAL_BAR` recalibration.
11. **A living crowd.**
    - A vertex-shader bob and cheer on the crowd cards, driven by match
      events (near-falls, finishers).
    - Phone flashes and camera pops during entrances.
    - 2K's crowd reacts. Ours is static.
12. **Eyes that look.**
    - Aim Roman's eye bones at the opponent's head during the face-off and
      cover.
    - Cody's eyes are part of his body mesh and would need a split.
    - A blink where the model has the shapes.
    - 2K26's faces are alive in the close-ups, and ours stare.

## Not feasible here, and why

- **Scanned heads and 4K/8K artist-painted textures.** There is no capture rig
  and no licensed scans. The assets we have are the assets. Items 2, 5 and 6
  are the closest substitutes.
- **Strand-based hair.** Godot 4.6 has no strand renderer. Cards and shells
  with anisotropy (item 7) are the ceiling.
- **Ray-traced GI and reflections.** Not in Godot 4.6 Forward+. Items 3 and 4
  are the screen-space and probe equivalents.
- **Motion-captured animation.** There is no capture. Authored clips in
  `wrestling_clips.py` remain the method.

## Sources

- [GamingBolt: WWE 2K26 — 15 new features worth knowing](https://gamingbolt.com/wwe-2k26-15-new-features-worth-knowing)
- [Operation Sports: WWE 2K26 vs 2K25 early graphics comparison](https://www.operationsports.com/wwe-2k26-vs-2k25-early-graphics-comparison/)
- [Gaming Respawn: WWE 2K26 review](https://gamingrespawn.com/featured/64532/wwe-2k26-review/)
- [VideoGamer: 2K26 creation suite improvements](https://www.videogamer.com/news/wwe-2k26-creation-suite-improvements/)
- [NGOHQ: WWE 2K25 review (ray tracing on PC)](https://www.ngohq.com/2025/07/02/wwe-2k25-review/)
