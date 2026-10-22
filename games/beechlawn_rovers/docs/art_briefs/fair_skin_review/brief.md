# Fair roster complexion — BR-022 (22/25, in progress)

Owner direction, 22 October 2026: all players should have fair, untanned skin.
Use each supplied portrait for individual undertones, rather than deriving
pigment from nationality. This direction is scoped to the football project.

References: archived Shane `shane_face_photo/69012.jpg`, Boardeaux player Des
`boardeaux_des_photo/69016.jpg`, John `john_orourke_photo/69010.jpg`, referee
`des_feeney_referee_likeness/69015.jpg` and the character roster sheets, all
under `references/source_uploads/chat_attachments/`. Indoor warmth/exposure
is not a target tan. Facial-hair, eyes and kit colours remain distinct.

The shared skin previously centred on sRGB (0.68, 0.43, 0.345), with Des at
(0.48, 0.33, 0.27). Those authored targets introduced a strong bronze cast.
The source sampler's tint ceiling also retained warmth from its licensed
Bronze base. The largest gaps were face/body saturation, Des's dark base,
consistency at the collar, exposed arms/hands/legs and repeatable regeneration.

`tools/blender/beechlawn/skin_palette.py` now holds editable art targets.
`refresh_roster_skin.py` updates the current packed Blender skin sources and
only the shared GLB's embedded skin PNGs, checking every other buffer view
byte-for-byte. Individual head recipes retain the shared neck texels and
blend into their own fair pigment above the join. Rebuild head exports with
`build_roster_heads.py` afterward. This retains the tailored body, all 19
clips, geometry, normals, kit, eye textures and separate hair packages.

Review uses the actual Godot roster profiles, pitch-side portrait and full-body
views at 1280×720, soft daylight, shadows and normal maps enabled. Hold camera,
lighting and exposure fixed across before/after. Inspect face/neck/hands and
short-sleeve arms together. Cloud Compatibility screenshots establish visible
integration only; native Mac appearance/performance and final likeness approval
remain open. Validation results are recorded alongside this brief.

The first palette trial over-lifted highlights in the fixed-light Shane
portrait (`iteration_1/`). The second balances the red channel downward and
raises green/blue moderately, removing the bronze cast while retaining a
natural pink complexion. Scene lighting/exposure are unchanged. The Web
capture helper now calls the existing first-draw freeze hook before readback;
continuous SwiftShader redraw caused one full-body screenshot timeout.

## Validation

Final palette v2 passes four Godot roster/resource/pose checks and six actual
browser captures, with no console errors. Shane/Des before-and-after capture
metadata confirms identical lighting. All four head packages pass anatomical
forehead pigment and neck continuity checks; exported neck p99 error is at
most 2/255. The fixed Des forehead-band regression also passes (0.713/1.3).
The shared GLB retains all 3,840 non-skin-image buffer views byte-for-byte,
including its 19 clips. See `validation.json`, `skin_uv_audit.json`,
`source_refresh.json` and `runtime_checks.log` for evidence and scope.

- [Shane portrait](after/shane/shane_portrait.png) and [full body](after/shane/shane_front.png).
- [Des portrait](after/des/des_portrait.png) and [exposed arms/legs](after/des/des_front.png).
- [John portrait](after/john/john_portrait.png) and [referee portrait](after/referee/referee_portrait.png).
- [Blender material review](blender/des_player_front.png).

These remain prototype likenesses with open sculpt, hair, beard, shading and
garment fidelity gaps. This pass corrects complexion; it does not approve final
AAA likeness or native Mac rendering. Builds have not been deployed in this pass.
