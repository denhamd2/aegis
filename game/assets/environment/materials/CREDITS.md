# Third-party assets in this directory

Written by `tools/assets/fetch_cc0.py` at import time, per
`gauntlet/anchor/ARCHITECTURE.md`. Every entry names the source, the author
and the licence.

Everything here is from **ambientCG** and is **CC0 1.0 Universal** (public
domain dedication) -- https://creativecommons.org/publicdomain/zero/1.0/.
ambientCG's [licence page](https://docs.ambientcg.com/license/) states that
attribution is optional; this file is that credit anyway.

## What changed, and why the old note here is wrong now

The previous version of this file recorded a decision: *only* Color and
Roughness were imported, at 512px, with mipmaps off, because every capture
was software-rendered and `evidence_gate.py --visual` voided all of them, so
normal maps "could not be shown to buy anything".

`ARCHITECTURE.md`'s amended renderer rule retired that. A `forward_plus`
capture is admissible whatever rasterised it, so material believability is
judgeable, so the full map set earns its place. What is here now:

- **1K PNG**, not 512px JPG. The 512 JPGs are still present because
  `scenes/ring.tscn` references two of them by path.
- **Color + NormalGL + Roughness + AmbientOcclusion**, plus Metalness where
  the asset ships one. Normal maps are the **GL** convention (+Y up), which
  is what Godot wants; the DX variants were not kept.
- **Displacement maps were not kept.** No shader here does parallax or
  tessellation, so they would be bytes nothing samples.
- **Mipmaps are on** (`mipmaps/generate=true` in every `.import`), and normal
  maps carry `compress/normal_map=1`. They were off, which is why distant
  tiled surfaces shimmered.

### Derived files: `*_RoughnessBand.png`

`core/materials/material_library.gd` holds roughness inside 0.30-0.90. Five
of the scanned roughness maps run outside that window at one end or the
other, so a `*_RoughnessBand.png` sits beside them: the same scan, linearly
rescaled from its own observed range into the band. Generated with Pillow at
import time; the command is in the round report. A derived work of a CC0
original is CC0.

### IP guardrail

Per `gauntlet/anchor/ARCHITECTURE.md`: these are generic CC0 surface scans.
No WWE-, AEW- or any other promotion-derived geometry, textures, logos,
trade dress or likenesses are used anywhere in this directory, and none may
be added.


## Carpet012

- source: https://ambientcg.com/view?id=Carpet012
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: seating-bowl treads and risers (`arena_bowl`)
- files: Carpet012_1K-PNG_AmbientOcclusion.png, Carpet012_1K-PNG_Color.png, Carpet012_1K-PNG_NormalGL.png, Carpet012_1K-PNG_RoughnessBand.png, Carpet012_Color.jpg, Carpet012_Roughness.jpg


## Concrete033

- source: https://ambientcg.com/view?id=Concrete033
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: stage backdrop and hall shell
- files: Concrete033_1K-PNG_AmbientOcclusion.png, Concrete033_1K-PNG_Color.png, Concrete033_1K-PNG_NormalGL.png, Concrete033_1K-PNG_Roughness.png


## Concrete034

- source: https://ambientcg.com/view?id=Concrete034
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: legacy: superseded by Concrete033, kept only for the 512px JPGs
- files: Concrete034_Color.jpg, Concrete034_Roughness.jpg


## DiamondPlate009

- source: https://ambientcg.com/view?id=DiamondPlate009
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: barricades, stage deck, tunnel mouth, ring steel
- files: DiamondPlate009_1K-PNG_AmbientOcclusion.png, DiamondPlate009_1K-PNG_Color.png, DiamondPlate009_1K-PNG_NormalGL.png, DiamondPlate009_1K-PNG_RoughnessBand.png


## Fabric030

- source: https://ambientcg.com/view?id=Fabric030
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: ring apron skirt (`ring_apron`) -- normal/roughness only
- files: Fabric030_1K-PNG_AmbientOcclusion.png, Fabric030_1K-PNG_Color.png, Fabric030_1K-PNG_NormalGL.png, Fabric030_1K-PNG_RoughnessBand.png


## Fabric036

- source: https://ambientcg.com/view?id=Fabric036
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: ring canvas (`ring_canvas`)
- files: Fabric036_1K-PNG_AmbientOcclusion.png, Fabric036_1K-PNG_Color.png, Fabric036_1K-PNG_NormalGL.png, Fabric036_1K-PNG_RoughnessBand.png


## Fabric061

- source: https://ambientcg.com/view?id=Fabric061
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: turnbuckle pads (`ring_turnbuckle_pad`) -- normal/roughness only
- files: Fabric061_1K-PNG_AmbientOcclusion.png, Fabric061_1K-PNG_Color.png, Fabric061_1K-PNG_NormalGL.png, Fabric061_1K-PNG_RoughnessBand.png


## Fabric063

- source: https://ambientcg.com/view?id=Fabric063
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: legacy: still referenced by scenes/ring.tscn's apron material
- files: Fabric063_1K-PNG_AmbientOcclusion.png, Fabric063_1K-PNG_Color.png, Fabric063_1K-PNG_NormalGL.png, Fabric063_1K-PNG_Roughness.png, Fabric063_Color.jpg, Fabric063_Roughness.jpg


## Metal032

- source: https://ambientcg.com/view?id=Metal032
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: ring posts (`ring_post`), overhead truss (`arena_truss`)
- files: Metal032_1K-PNG_Color.png, Metal032_1K-PNG_Roughness.png, Metal032_Color.jpg, Metal032_Metalness.jpg, Metal032_Roughness.jpg


## PavingStones150

- source: https://ambientcg.com/view?id=PavingStones150
- provider: ambientCG
- author: Lennart Demes / ambientCG
- licence: **CC0 1.0**
- used for: arena floor (`arena_floor`)
- files: PavingStones150_1K-PNG_AmbientOcclusion.png, PavingStones150_1K-PNG_Color.png, PavingStones150_1K-PNG_NormalGL.png, PavingStones150_1K-PNG_RoughnessBand.png
