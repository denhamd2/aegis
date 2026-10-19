# Partly cloudy match sky

Original unmodified 4096×2048 HDR panorama: [Kloofendal 48d Partly Cloudy (Pure Sky)](https://polyhaven.com/a/kloofendal_48d_partly_cloudy_puresky), by Greg Zaal (original) and Jarod Guest (sky edits), Poly Haven.

License: **CC0-1.0** ([Poly Haven asset license](https://polyhaven.com/license), [CC0 legal text](https://creativecommons.org/publicdomain/zero/1.0/legalcode)). Free use and redistribution, including game builds. Provenance, original hash and download URL are in `source.json`.

This is a sky-only lighting/background asset selected for broken clouds, blue
sky and direct sunlight, following the owner's brighter-weather correction.
It is not a photograph of Kilmore Drive. Archived Google/reference
images informed the look and are not used as runtime textures.

Godot uses the HDR through `data/presentation/kilmore_daylight.tres`. The
4K texture and cached 256-pixel radiance map avoid per-frame cloud raymarching.
An original lightweight sky shader balances saturation and the low horizon.
The import's HDR exposure clamp controls the extreme solar texel; the matching
directional light supplies shadowed sunlight. Its direction is derived from
the actual HDR sun position (about 48° elevation), retaining cool sky fill and
gently warm direct light. Basic distance haze is subtle; volumetric fog is disabled.
