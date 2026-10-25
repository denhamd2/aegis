# Des Feeney Sr. referee likeness — work in progress

Latest source, groom, four-image PBR package and runtime evidence supersede
this historical pass: see [the four-head finish](../four_head_finish/brief.md).
The current authoring entry points delegate to `author_four_head_finish.py`;
materials/grooms use `player_head_finish.py` and `player_head_groom.py`.

This is a separate identity from Des Feeney, Boardeaux #9. The referee keeps the shared player body and rig, but uses a unique face delta, skin atlas and official profile. The pass is part of BR-022, player likeness and reusable head variants (22 of 25 backlog items).

## References

- `references/source_uploads/chat_attachments/des_feeney_referee_likeness/69015.jpg` is the close portrait for facial identity, age, hairline and moustache.
- `.../69018.jpg` is the referee turnaround and expression sheet for front/profile/rear proportions and black official kit details.
- Both uploads are preserved byte-for-byte and checksummed. The portrait is not projected or used as a decal; it informs the sculpt and original UV pigment work.

## Implementation in this pass

- Added an editable referee-specific sculpt source and delta on the shared head base. It changes cheek and jowl width, lower-face contour, nose profile and brow/under-eye volume while preserving the neck seam and common body rig.
- Added a referee-only skin and eye atlas with restrained age detail and a procedural grey moustache pigment pass.
- Bound the referee profile to `des_feeney_sr.glb`; Boardeaux #9 remains its own roster identity and head asset.
- Saved three actual Godot Web/Compatibility captures in `web/`: portrait, three-quarter and profile. The captures use the project’s pitch-side review scene, not generated concept art.

## Review status and next correction

This is still a likeness prototype, not an AAA-quality match. The Godot review shows a generic-looking bald base face, a moustache that currently reads as a dark upper-lip/nose mark rather than hair, and a profile whose nose and head silhouette need another proportion pass. The wrinkles and skin shading also look too stylized. These misses are visible in the current captures and must be addressed before calling the likeness complete.

The immediate next art task is to correct the face UV placement and bake, add a conforming fine grey moustache groom or a reliable shaped UV mask, and tune the head silhouette against the sheet’s front and profile views. Then capture neutral, three-quarter and profile views again. A single portrait cannot establish unseen geometry exactly, so the supplied turnaround should guide the side silhouette. Do not present this iteration as finished or claim exact/AAA fidelity.

Validation: the roster smoke suite is run after the referee profile is switched to its unique head. Web software rendering is visual evidence only; it does not establish native M1 performance.
