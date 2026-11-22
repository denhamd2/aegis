# Snap Dragon 3 rear entry and throw clearance

The Mac workflow published `0c15f09`. The exact tag and uploaded Aegis.zip (1,034,159,104 bytes) were verified. [Mac run 45065380236](https://github.com/denhamd2/aegis/actions/runs/45065380236) · [Release receipt](mac-publication.json)

Snap Dragon 3 uses a rear opening. The old root fit placed the defender behind
Kenny and raised the defender's opening root by about 23 cm. The standard
face-to-face pair frame also directed the walk-in across the opponent. Their
positions now start on the mat, with Kenny behind, and the flagged rear recipe
uses the frame that keeps each wrestler on their approach side. A scoped
defender trajectory guides the load, backward travel and recovery. The
defender's own leg keys open the shins around the lift to clear Kenny's torso.

The reference is the owner's Fight Forever compilation at 626.1–628.2 s,
with a replay around 628.7–629.7 s. It shows the rear hold, backward throw
and low release. [Reference video](https://drive.google.com/file/d/1SYI-phi8Ci-WmbtxqtFEswarYHfhKGqc/view)

| Pair | Peak body overlap, before → after | Final peak arm overlap |
| --- | ---: | ---: |
| Default probe roster | 8.0 → 3.3 cm | 6.2 cm |
| Kenny → Cody | 10.0 → 3.3 cm | 6.9 cm |
| Kenny → Roman | 7.9 → 3.4 cm | 6.1 cm |

These are the existing capsule measures at 60 Hz. All final traces pass the
5 cm body and 8 cm arm limits. Aligned post-modifier samples on the candidate
also stay inside both limits. The actual controller delivered one landing,
put the defender in Down, restored physics and restored the original
animation library in all four Kenny-versus-Cody/Roman player-slot checks.

Godot ran 46 focused cases. The placement, retargeting, height release,
paired pose, authoring and pose lint suites passed. The broader cadence check
still reports the existing 29 snaps against its budget of 27; Snap Dragon 3
adds none.

The full Blender export was regenerated and audited. The committed GLB
keeps its existing bytes outside the four affected thigh and calf rotation
buffers. The baked pose library likewise updates only those four tracks. The
move's 2.667 s duration and its damage/reversal data are unchanged. Snap
Dragon 2 retains its separate face-to-face opening.

The side captures show the rear entry, backward arc, kneeling release and
downed pose. They also show lower hand placement than the reference and slack
in the hold during the load. The defender's pose and mat-contact timing need
a separate pass, including the leg lift coming out of the last paired pose
into Down. Review these at normal speed and check actual skin contact.
Native Mac performance still needs measurement.

[Side capture sheet](snap-dragon-3-side.jpg) ·
[Clearance summary](clearance.json) ·
[Controller results](controller.json) ·
[Focused test report](focused-tests.xml)
