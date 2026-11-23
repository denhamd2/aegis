# Running inverted drop landing and recovery

The late Blender settle tucks the heels and brings the back toward the mat
while the wrestler rolls out of the inverted impact. The export preserves the
existing samples through source frame 63, and the attacker and unrelated moves
retain their existing clips. Roman's impact fit still places head skin 2.1 cm
above the mat at source frame 59 and 0.8 cm above at frame 59.5.

Roman's private animation fit advances the protected boot pose by one physics
tick at the start of the settle. His Down clip carries the fitted legs and
back into the neck sell. Cody's private defender clip adjusts the pelvis
height over the impact and settles the legs toward the opening pose of his
own fitted Down clip. These clips fit each roster model on load. Normal
knockdowns continue to use their regular sell clips. The paired and gameplay
clocks remain at 60 Hz, with the same 2.2-second move and Down entry.

The controller probe measures post-modifier skin and gear, with separate boot,
back and head regions. The half-tick runs sample between the standard pose
steps without changing simulation frequency. The probe also saves the drawn
head and pelvis positions to check facing through the Down handoff.

Reproduce from the repository root with imported Godot 4.6.3 resources.

```sh
godot --headless --path game --fixed-fps 60 tools/probe/landing_fit_probe.tscn -- --wrestlers cody,roman --out /tmp/running-drop-roman.json
godot --headless --path game --fixed-fps 60 tools/probe/landing_fit_probe.tscn -- --wrestlers roman,cody --half-tick --out /tmp/running-drop-cody-half.json
```

The settling back and boots can sit slightly above the canvas. The measurements
cover the landing and the first twelve Down ticks. Full-reference acceptance,
other roster fits, and native M1 frame pacing remain open.

All six production runs passed their floor and handoff checks. From source
frame 57 through recovery, the smallest measured skin or gear clearance was
4.3 mm. The horizontal head-to-pelvis direction varied by less than 0.1° across
the handoff in every run. The Roman-only boot adjustment keeps the checked
late boot samples above the mat in both player slots and between ticks.
[Landing measurements](landing-clearance.json).

The focused run passed 42 of 43 checks. The library-wide cadence count
remains 29 against its existing budget of 27. The updated running-drop
defender clip contributes zero cadence snaps. [Focused test report](focused-tests.xml).

The studio side view shows Roman delivering the drop to Cody, from the catch
through the Down transition. The diagnostic renderer tints Cody blue to make
the two bodies easier to distinguish. [Side-view capture](running-drop-side.jpg).

The Unreal trajectory snapshot matches the running-drop root path. Unreal
still needs the new defender animation reimported and retargeted. The Roman
and Cody recovery adaptations are Godot-side and need an equivalent Unreal
implementation or engine-neutral bake. A regenerated trajectory export also
finds stale Snap Dragon 3 and Cross Rhodes entries and a missing Mexican
Destroyer entry in the checked-in Unreal snapshot.

Mac run [45152581720](https://github.com/denhamd2/aegis/actions/runs/45152581720)
published `bf25f3f`. The exact release tag, target commit, and uploaded ZIP
were verified. [Publication receipt](mac-publication.json).
