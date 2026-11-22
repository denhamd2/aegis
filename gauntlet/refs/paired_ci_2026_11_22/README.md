# Mexican Destroyer timing and paired CI triage

[Mac run 45016972098](https://github.com/denhamd2/aegis/actions/runs/45016972098)
published `6afc76d`. The exact release tag and uploaded Aegis.zip
(1,034,157,765 bytes) were verified. The
[full CI run](https://github.com/denhamd2/aegis/actions/runs/45016972094)
was still running at publication. See the [release receipt](mac_publication.json).

The paired root trajectory ran for 2.533 s, but both body pose clips ran for
3.333 s. When the rig reached the end of the root trajectory, both bodies
still had roughly a quarter of the performance left. The scoped production
bake now runs both roles for 2.533 s and keeps the original poses and their
relative timing. The MoveDef, Blender source and the trajectories are untouched.

The library comparison found changes in just 2 of 148 clips. All 11,172 key
values in those clips match the previous bake. The largest normalized key-time
difference is below 0.00000008. All 34 tests in the paired pose, FF library and
Roman landing fit suites pass, including the duration assertion that failed
on `29cfb01`. A 60 Hz Kenny–Cody controller probe also followed the real
grapple-hold completion path. The move landed once, the defender entered
Down, and both wrestlers resumed physics processing.

| 60 Hz paired clearance probe | Peak body overlap before → after | Peak arm overlap before → after |
| --- | ---: | ---: |
| Default probe roster | 0.036 → 0.025 m | 0.074 → 0.058 m |
| Kenny attacks Cody | 0.166 → 0.048 m | 0.116 → 0.096 m |
| Kenny attacks Roman | 0.139 → 0.099 m | 0.109 → 0.091 m |

The last two rows still need combat pose fitting. The body threshold is
0.05 m and the arm threshold is 0.08 m. This is a timing correction.
PoseLint still reports two attacker hands crossing the torso in the current
source, and the source cadence audit flagged three snaps across the roles.
Native Mac appearance and frame pacing are unmeasured.

## Remaining CI and animation work

[Previous main CI](https://github.com/denhamd2/aegis/actions/runs/44918077062)
ran 1,377 cases with 14 failures and one error. After the duration fix,
prioritize source pose and cadence faults and the remaining paired contact
regressions:

- Snap Dragon 3 has 0.080 m of overlap. It intentionally begins with both men
  facing the same way for the rear nelson, so the universal opposed-facing
  assertion is also too broad. Verify the behind position on the posed pair
  before changing the placement test. Snap Dragon 2 opens face-to-face.
- Cross Rhodes has an existing 0.094 m median facelock gap against a 0.05 m
  limit. Its repair needs work on the two authored roles.
- Existing coverage also reports Roman and Cody walk-arm jerk, commentary,
  Kenny beard coverage, prop handoff and the fire material error. The
  `IDLE -> FINISHER` log entry is from an intentional assertion in a passing
  transition test.
- Roman's separate running-drop impact fit is already deployed. Late boot
  and back contact, Cody's penetration, the Down transition and grapple
  teardown remain queued in the [landing-fit evidence](../roman_landing_fit_2026_11_16/README.md).

## Reproduce

```sh
AEGIS_PAIRED_MOVES=ff_mexican_destroyer godot --headless --path game -s res://tools/anim/build_paired_poses.gd
godot --headless --path game --fixed-fps 60 tools/probe/pair_clearance.tscn -- --moves ff/mexican_destroyer --wrestlers kenny,roman
```
