# Candidate4: gradual finger closure during recovery

Status: integrated final candidate;72 focused cases pass, publication approved. Candidate3's
bounded wrap/inverted boot-arc improvement passed independent visual QA, but
its new recovery cadence spike blocked publication. Existing landing/torso/
toe limitations remain separate; this correction does not broaden that scope.

Actual raw frame64 angular contribution matches the imported result:
666.82° summed over bone rotation tracks, of which470.21° (~70.5%) was finger
closure. Source63 fists.2→66.8 closed26finger chains in the final three frames.
Candidate4 changes ONLY source63 fist_r/fist_l to.55, so the hands begin
reforming earlier after release.59.2 and final66.8 are unchanged.

`candidate3_to_4_raw_parity.json` confirms only26attacker finger-rotation tracks
changed. ALL attacker body/arm tracks and ALL defender tracks remain EXACTLY
unchanged. No pose, root placement, timing, contact proxy, threshold or budget
was altered to pass this check.

Raw diagnostic `raw_cadence_diagnostic.json` applies the existing3.5×local
median definition: attacker snaps1→0, jerk48.50→39.37; defender0snaps unchanged.
Actual Godot import confirms0snaps/holds for both roles; final recovery63/64
captures were inspected. Full4 export parity passes315 unrelated +2 selected.

Frozen scoped export `/tmp/aegis-running-wrap-candidate4.glb`, SHA256
`cedcc2aef246de69bed55729b9d0ae433bd8d8860fa30c2dc683fcfde47ed573`;
307400bytes,2clips,2.2s,60Hz. Editable native review file
`/tmp/aegis-running-wrap-candidate4.blend`. The native is retained at
`tools/blender/animations/running_grapple_inverted_drop.blend`, and supersedes the candidate3 native. `build_candidate.py` reproduces native,
mesh/curve audit and scoped GLB from the canonical builder and frozen fixture.

The already-produced FULL candidate3 library is retained separately at
`/tmp/aegis-running-wrap-candidate3-full.glb` (SHA256
`3f5dc5733dd043b591476adc6f415172349df44f9097d6d779dac6b2699ccc17`).
Its audit proves all315unselected clips BIT-EXACT to published and both selected
clips EXACT to frozen scoped3. It still contains the rejected recovery snap;
do not integrate it as the final library. Full4 follows imported cadence pass.
