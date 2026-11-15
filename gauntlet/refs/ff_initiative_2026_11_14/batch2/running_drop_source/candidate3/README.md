# Candidate3 — frozen, provisional source variant

File:/tmp/aegis-running-drop-candidate3.glb
SHA256:a229582f89cb14de0a68f2b6b9dee0bfc948d8db4e23577a7a01152d069b2452

Newly authored left-leg release routes knee and ankle together outward, with
guard poses61/63–64. Temporary original action curves are reconstructed from
the original pose table, not a generated game output. All non-left-leg curves
are restored wholesale; the original scalar handles through55 and at66 are
frozen to prevent AUTO_CLAMPED from changing pre-window motion.

Raw GLB export comparison against production confirms: entire attacker within
4.2e−7floatcomponentnoise; defender prefix through55 within5.4e−7; final66
within3.6e−7; all non-left-leg tracks within5.4e−7. Only thigh_l,calf_l,foot_l
rotation tracks change meaningfully. First changed sample55.5. A complete
source patch and build log are adjacent. This is not a passing visual/joint
direction or runtime-clearance claim.

Candidate2 properly imported measurements failed: default body.060at62 and
Cody→Roman.105at63.5. Its world trace also establishes a major solver-history
component: at63 the left-knee/ankle coordinates RELATIVE TO PELVIS match the
published baseline, but the whole defender is~23.6cm farther forward. The
published source itself is lifted by runtime paired_separation.Y=.329m at59
and.278m at63. Architect/main now own no_pull/horizontal_push ablations.

C3 therefore remains frozen and provisional. It must not be accepted as a
compensation for a~33cm runtime lift or scored using the earlier world corridor
after the solver changes. Correct source/import parity is now established;
main's production-equivalent isolated import is authoritative. Old30fps and
raw60fps GLTFDocument bake results remain diagnostic history.

No production animation library replacement, publication or further recipe
change is performed here. Preserve all paused Kenny source/assets. Next is
main/architect separator-source factorial validation, followed by scoped
source selection and actual six-beat paired+match-camera review if justified.
