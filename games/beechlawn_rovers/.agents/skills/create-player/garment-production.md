# Garment production

Use for body/kit fit, clothing topology, atlas registration or deformation. Paths are relative to the repository root. Use the current shared source and runtime, with the main skill's reference and preservation gates.

## Diagnose the surface before editing

Separate silhouette, cloth topology, skin coverage, weights, UVs, normals and runtime material replacement. A black band may be shorts protruding through a shirt, rather than missing texture. White speckles may come from degenerate UV tangents. A missing forearm may be an inherited long-sleeve body mask. Reproduce the actual case in evaluated geometry and a matched render before choosing the repair.

Fit garments to anatomical landmarks with smooth, bounded transitions. Retain corresponding body weights when cutting/subdividing garments; nearest-surface rebinding can jump across the inner-thigh gap or onto the opposite limb. Prune to four positive influences and normalize. Preserve the underlying licensed source for recovering masked skin.

## Shape and topology

- Cloth spans the chest and shoulder blades. Remove copied nipple folds, deep anatomical hollows and hard muscle caps with a local cloth envelope; inspect front/profile/back clay views. Broad smoothing or inflation can worsen armholes and change the intended build.
- Construct connected hem rows and a thin folded return. Disconnected ribbons or extra trim over an inverted edge leave the defect underneath. Check winding, nonzero triangle areas and thickness after triangulation.
- A smooth V boundary needs smooth supporting yoke rows. Closest-point projection can send adjacent collar samples to one corner, collapsing faces or producing a lumpy band. Use a continuous supporting loft or sound local topology, retain even sample spacing and check the fitted band against skin and cloth.
- Project seams onto their own garment surface and interpolate that surface's weights. Fit the same shared detail to long and short sleeves and inspect keepers' arm poses. Keep additional topology/material cost explicit.
- Sleeve taper must clear actual arm skin, with wrist/cuff and neck interfaces retained. A broad body bounding box does not prove skin exists through an opening. Check both bare forearms through the wrist; restore missing coverage from the licensed anatomical source without replacing the live body with an old archive.
- Check the waist in a posed idle/stride, with shirt and shorts together. Sample evaluated surfaces to detect the waistband in front of the hem; adjust local clearance before adding decorative folds.

## Atlas and engine agreement

Map the complete supplied garment layout: stripes, trim, crest, manufacturer, sponsor and identity printing. Use the reference plan's owner corrections and preserve the oval crest proportions. Keep shared team/role graphics separate from player name/number resources.

Compare the material actually assigned by `scripts/footballer_visual.gd` with Blender's source material. The older studio atlas showed raglan piping that vanished when Godot replaced it with a role atlas. Use the same pigment for matched reviews, or document an intentional difference. Verify keeper/opponent/referee variants; a good home-kit render does not validate them.

Validate the material data, not just its connection. The earlier roughness map
was constant, so wiring it could not distinguish cloth from print. Keep shared
knit detail separate from role-specific roughness masks, sample the imported
print/shirt/sock response, and verify normal/roughness colour spaces and mips.
The canonical mask can use red while glTF packs roughness into green; inspect
the actual exported/imported channel. Check distant graphics and hair for mip
aliasing, retaining shared maps instead of per-player texture copies.

For keeper patterns, use flat panel artwork rather than folds/shadows from a
posed torso. Record generated-pattern provenance and remaining approximation;
apply supplied crests, manufacturer and sponsor marks separately with checked
lettering. Shared sleeve/collar/sock UVs must sample the correct role swatch:
John's white socks previously inherited blue cuffs from the collar region.
Check both keeper front/back/save views through their real roster profiles.
Glove geometry, palm/cuff detail and save deformation are separate finishing
work; a flat glove-coloured hand is not a finished goalkeeper glove.

Keep UV chart names expected by the material nodes, including `JerseyUV` where used. Inspect exported triangles for zero-area UVs, mirrored lettering, seam interpolation and mip bleed. Repair cut-edge UVs within appropriate fabric swatches; printed chest faces must retain their local artwork sample. Inspect saved/reloaded textures with correct colour spaces.

## Prove the local change

Use fixed neutral textured/clay close-ups, both sleeve variants, then idle, sprint, pass, shot, turn, slide/get-up and keeper poses. Hold the sampled triangle cohort constant when comparing fold diagnostics; topology edits require a deliberate remap. Separate trim inversions from the larger shirt's unresolved folds. A zero count on one region or sparse vertex samples does not establish all-pose, per-pixel approval.

Run the relevant existing source checks with `blender -b --python-exit-code 1`: `tools/blender/beechlawn/validate_shared_character.py` covers skin/waist/weights/interfaces; `validate_shared_collar.py` covers evaluated collar clearance and fixed-pose trim geometry. Use `--help` or read the script before invoking mutating tools. Follow with actual roster native Forward+ views and the main skill's runtime checks. Record the measured scope, remaining gaps and counts including hidden sleeve variants.

Reference cases: `docs/art_briefs/shared_shoulder_fit/brief.md`, `shared_cloth_finish/brief.md`, `shared_sleeve_fit/brief.md` and `shared_collar_raglan/brief.md`, all under `games/beechlawn_rovers/`. They explain the failures and evidence; their historic counts and tuning values are not universal targets.
