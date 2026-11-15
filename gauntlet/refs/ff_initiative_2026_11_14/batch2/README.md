# Owner-approved all-changes Mac review build —15 November2026

**Deployed and verified:** `mac-latest` points exactly to
`f681d07caf2165df10aa4b9e22ad1632eee3c66b`; Mac run43695558573 succeeded and
Aegis.zip is uploaded (1,032,804,653bytes). [Delivery receipt](mac_publication.json).

Owner explicitly requested committing and deploying all current changes. This
includes the bounded running-drop source correction, validation tools and the
previously paused Kenny R7V3/R8 art/native-source work. Publication verification
is pending. No global solver experiment is included.

## Implemented and validated

- Authored left-leg release/sell guards preserve the original curves through55,
  all non-left-leg motion and the final66 handoff. Full317clip GLB is regenerated;
  full versus scoped running clips match exactly. Only two paired-role entries
  are rebaked; other entries remain intact. Reference/MoveDef duration unchanged.
- Mannequin overlap .090→.031m. Cody→Roman and Roman→Cody maxima remain unchanged.
- Scoped baking and isolated import use production Godot settings, including
  optimizer behavior. Canonical production/isolated imports match exactly.
- Lightweight contact fixtures match the original metrics. Opt-in traces record
  actual clip time, world-space points, cosmetic offsets, post-IK points and
  phase-specific grip coverage. Bare captures omit cosmetic arena builders;
  frame manifests verify exact requested74/118ticks.
- **49 focused cases pass**, zero test errors/failures/orphans: timing, roles,
  placement, actual replay, paired poses, cadence, pose lint, reviewed source gate
  and affected contact checks (PAIR_ONLY=running_grapple_inverted_drop; existing
  real-roster finishers/signatures also run). This is not a whole-suite result.
- Kenny:21cases, one failing case/two beard-to-ear assertions. Other20cases pass.
  Current new groom has no overall likeness score;4.6/10 remains the last fully
  scored baseline. Assets, native Blender source and diagnostic evidence included.

## Remaining acceptance

Independent visual QA: **PARTIAL / PENDING full-move acceptance**. Side release
silhouette improves; real-mesh knee/leg clearance, load hand roles, mat contact,
normal-speed motion and presentation remain open. The existing solver can raise
Roman by33cm; experimental planar correction regressed the opposite pairing and
is excluded. Generic waist binding does not match the reference's asymmetric
load/wrap roles. Game-camera images are too wide for detailed judgement; bare
views do not establish arena presentation. No AAA/10/10 or M1 performance claim.

[Eight-dimension review](tooling/source3_visual_review.md),
[experiment summary](tooling/contact_matrix_summary.json),
[gameplay/animation report](tooling/release_validation.xml),
[Kenny report](tooling/kenny_release_validation.xml). Shutdown material/resource
warnings remain in capture/test logs; editor sandbox socket warnings are also
recorded. The full CI baseline has known unrelated failures.

## Publication merge and audio check

Changes committed as9866d64; newer main contained five commentary commits.
They merged cleanly into release commitf681d07caf2165df10aa4b9e22ad1632eee3c66b.
The separate post-merge audio suite ran53cases: two failing cases/three
assertions concerning Tony carnage versus Excalibur restore-order cue selection.
Those imported-main behaviors are preserved for owner review, not silently
changed to make tests green. [Audio report](tooling/merged_audio_validation.xml).
No gameplay/animation test failure is hidden by that separate result.
