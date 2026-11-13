# Frequent weapon realism — 13 November 2026

First art slice: steel chair, folding table and ladder. This is a bounded
realism improvement, not a claim of finished AAA quality or native frame rate.

## Changes

- Steel chair: stamped pivot washers on all three states; enamel normal
  strength 6.0→2.5 avoids a hammered-metal finish. Existing barbed-chair
  output is intentionally not regenerated or changed.
- Table: hinge sleeves around the folding axles in all states. Warmer,
  darker wood laminate with more legible grain and higher satin roughness
  reduces the pale broad highlight under a studio key.
- Ladder: shallow top-step rivet heads, fine directional brushed aluminium
  normal/roughness maps. Existing rung geometry/routes are unchanged here.
- Existing deterministic source builders regenerate only these weapons via
  `chairs.main(only="steel_chair")` and `set_pieces.main(frequent_only=True)`.
  No external textures or image-generation services were used.

## Validation

Blender 4.3.2 regeneration succeeded. Python syntax and `git diff --check`
passed. Godot 4.6.3 imported the assets successfully (sandbox editor socket
warnings do not affect import). Generated/extracted texture dependencies are
included with the GLBs.

[Asset audit](asset_audit.json): material counts remain three per weapon;
mesh counts and marker/state-root names unchanged. Marker/root transforms
match to 1e-6 (table grip quaternion exporter roundoff <6e-8). Finite
accessor bounds and the 15,000-triangle per-state ceiling pass.

| State | Before triangles | After triangles |
| --- | ---: | ---: |
| Chair folded / open / bent | 6514 / 6290 / 6786 | 6978 / 6754 / 7250 |
| Table up / folded / broken | 2688 / 2248 / 5160 | 2768 / 2328 / 5240 |
| Ladder open / closed / laid out | 8208 / 7672 / 7672 | 8648 / 8112 / 8112 |

No new texture maps, texture dimensions, materials or draw surfaces.
Chair GLB 1,372,728→1,391,800 bytes; table 1,932,016→1,934,176;
ladder 2,779,824→2,370,816. Triangle increases remain below 8% per state.

## Reproduce the visual comparison

Use `tools/probe/weapon_shot.tscn` with Forward+, Vulkan and a visible display:
`--glb res://assets/weapons/steel_chair.glb --node SteelChair_Open
--out OUTPUT --view three_quarter --settle 8 --capture-resolution 640x480`.
Repeat with table/Table_Up and ladder/Ladder_Open. The scene's fixed neutral
studio lighting, camera and mannequin are identical before/after.

Captures use software llvmpipe, 640×480, Godot 4.6.3 Forward+. They establish
isolated material/geometry appearance only; arena lighting and native
M1/16 GB performance remain owner-review items. These prop studies are not
animation acceptance evidence.

## Visual review result

Before/after PNGs and renderer logs are in [before](before/) and [after](after/).
All six captures completed successfully and were inspected in this Codex session.
The table is the clearest improvement: the pale broad highlight is reduced,
wood stays warmer, and the top retains its visible grain. Chair and ladder
silhouettes remain consistent; their finish/hardware changes are subtle at
640×480 and are not represented as a dramatic visual upgrade. No visible
missing materials or detached parts appeared in the three reviewed states.
The other states were checked structurally, not rendered in this bounded pass.
Chair/table visible-state bounds match exactly; ladder depth differs by
0.00045 m after bevel evaluation, with height/width and all gameplay markers
unchanged. Native close-up review remains useful before declaring final art
acceptance; remaining weapon families and casket/ambulance are still open.

## Runtime checks

Catalogue16, set-piece9 and ladder-climb6 cases pass: **31 passing cases**.
The all-weapon grip case fails on eight paths (including table carry and ladder
swing). Controlled substitution of all three ORIGINAL GLBs, import and the same
case reproduces the same eight failing weapons; table/ladder misses remain
about6.3–6.4cm. This is an existing runtime/contact problem on the integrated
animation source, not a green grip gate or a corrected animation claim.
Final art assets were restored and reimported after this baseline comparison.
See [focused report](tests.xml) and [baseline grip report](baseline-grip.xml).
