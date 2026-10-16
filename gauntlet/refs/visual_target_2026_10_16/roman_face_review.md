# Roman portrait refit — October 16

Status: implementation checkpoint; **final reference likeness and native
performance acceptance remain open**. Baseline for this comparison: `3405825`.
The master face target is the owner's “Roman entrance on Ramp - new.png”.

## Implemented

- Restored cheek/jaw width and reduced the old long-chin, narrow-nose and
  heavy-brow deformation. A small mouth-volume correction follows the same
  field as skin/beard/mouth parts. Eye meshes and the neck remain untouched.
- Finer, shorter eyebrow strokes and rougher brow fibres; shorter painted
  stubble at the beard transition. Reduced baked shading/contour contrast,
  retained pigment zones and the existing anatomical wrinkle normal. Its
  strength is now .65; face scattering is .18 with a hair exclusion mask.
- Calmer eye whites/corners, with the same iris dimensions, eye rig, aiming
  and blink timing. The upper-lid resting angle is -28 degrees.
- A separate nonmetallic root layer shares the head's mesh, skin and skeleton.
  It keeps dark roots from receiving the skin material's broad response.
  Earlier combined-material previews exposed a grey band and were rejected.

The portrait colour remains reconstructed from the damaged source's surviving
channel. This is not a new photographic scan. Main hair/beard cards, topology,
fine facial forms and texture fidelity still limit the reference match.

## The blink defect

Closed-eye review exposed two existing construction errors. Roman's head bone
local +Y points downward: the original lid frames had world-up Y approximately
**-0.998**. The builder now receives the actual up vector in head space; the
corrected frames have world-up Y approximately **+0.998**.

Godot's hemisphere `height` is the hemisphere's full height. The old builder
used twice the radius, producing an elongated cap. Height now equals radius,
with a thin moving lid margin and matching skin response. Full closure is
40 degrees; the final forced-closed view covers the sclera without the old
under-eye bulges. The cap remains a simplified approximation, not a facial rig.
The original blink durations and eye-tuck rule remain in charge. Tests check upward opening and
that the cap fits within its eye radius, alongside the existing blink tests.

## Rendered comparison

[Open the comparison viewer](roman_face_review/index.html). Images are stored
unchanged with hashes and camera/renderer metadata. The target image is the
original supplied PNG; its composition and lighting differ from the studies.

| View | Before | After |
| --- | --- | --- |
| Front | [Image](roman_face_review/before_front.png) | [Image](roman_face_review/after_front.png) |
| Three-quarter | [Image](roman_face_review/before_threequarter.png) | [Image](roman_face_review/after_threequarter.png) |
| Profile | [Image](roman_face_review/before_profile.png) | [Image](roman_face_review/after_profile.png) |

The neutral studies use Godot 4.6.3 Forward+/Vulkan, software llvmpipe,
960×540, a fixed clock and 12 settling frames. They omit the arena and use
bind poses. Additional closed-blink and adapted `Roman_Stand` /
`Walk_Slow_Look` frames inspect closure and the complete model's posed
attachments. The clip probe now pauses the exact sample and settles each
camera for three frames: an initial blank frame and one-view lag were caught
and rejected during review. These are sampled poses, not a motion reel or
Mac performance evidence. The posed probe uses its own diagnostic lights and emits resource
cleanup diagnostics at exit; it does not establish a clean shipping round.

## Remaining reference gaps

**Verdict: NO-SHIP for final visual acceptance.** The pass can be reviewed as
an implementation checkpoint; it does not satisfy the eight-reference goal.

- Major: facial planes and expression are still simplified. More accurate
  orbital shape, nose/alar forms, lips and cheek transitions need a measured
  sculpt/bake pass; parameter changes alone will not supply the target face.
- Major: the damaged head colour lacks scan-level pigment and pore detail.
  The visible forehead is still smooth; the existing wrinkle normal cannot
  create all missing skin detail.
- Major: the main hair and beard still read as cards/a mass, with a coarse
  cheek boundary, visible side-card ends and bright chin-edge artifacts.
  The new root layer improves the transition without replacing that groom.
- Open acceptance: the arena-lit moving entrance, all eight native views,
  coat/belt/necklace fit and steady 60 fps on the M1 Pro remain unverified.

## Verification and cost

See [validation](validation.md) for final test/round results and package audit.
The original supplied model, weights and animation files are unchanged.
The old art-specific narrow-jaw/long-chin assertion was replaced because the
owner changed the target. Its replacement checks symmetric, bounded refitting
with positive surface Jacobians; neck and eye-rig preservation checks remain.

The root layer adds one instance of the existing 7,652-triangle head mesh and
can add an alpha depth pass. It shares mesh/skin data and casts no extra shadow.
Lid margins add 160 small triangles. New maps are mipmapped and compressed:
2K colour/RM and 1K root/scatter masks. Actual GPU/frame-time cost remains to
be measured on the M1 Pro. The native capture runner now records chip, memory
and executable/PCK hashes so screenshots can be tied to the app actually run.
