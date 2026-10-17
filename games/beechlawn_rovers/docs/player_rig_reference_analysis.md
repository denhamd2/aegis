# Beechlawn first-player rig reference analysis

## Reference and purpose

The supplied Shane Denham (#8) character sheet is the visual reference for the
first Beechlawn prototype player. The image was supplied in the conversation
and is not currently present as a source file in this checkout. The owner has
supplied Mixamo's Y-Bot as the temporary skeleton and import-pipeline base. It
is a stylized robot mannequin, not a human footballer or a likeness match.

The sheet shows an adult male footballer at approximately 1.80 m, with short
brown hair, fair skin, a blue-and-black vertically striped long-sleeve jersey,
black shorts, dark socks with blue/white bands, and black boots. The full sheet
provides front, side, and back views plus portrait and kit details. The final
player should match those views when the detailed sheet is available in the
workspace.

## Camera and readability

The game is a broadcast-camera 4v4 football prototype. At gameplay distance,
readable human proportions, team-color blocking, foot motion, and ball contact
matter before portrait detail. The Blender proxy uses a neutral three-quarter
inspection camera; the final silhouette and materials still need an in-engine
broadcast-distance check.

## Technical plan

- Real-world scale: 1 Blender unit = 1 metre; target height 1.80 m.
- Y-Bot import: 65 bones, two skinned mesh parts, approximately 27.8k source
  vertices, about 1.805 m tall, and no external image textures. The mesh is
  above the earlier 5,000-triangle final-character target; profile it at 4v4
  and consider a skinned LOD/optimized mesh before using eight copies.
- Rig: preserve the Mixamo bone names and shared humanoid skeleton while
  checking imported bone rest pose, character orientation, and scale in Godot.
  Keep game locomotion authoritative in Godot and prefer in-place clips.
- Animation: 30 fps. The supplied FBX only has a one-frame pose action, which
  is deliberately omitted from the runtime GLB. Loop idle/jog/sprint/close-control clips; provide discrete
  receive, pass, shot, stop/turn, hit-reaction, and get-up clips. Record pass
  and shot contact frames in a sidecar manifest for later Godot event hookup.
- Export: GLB, Y-up, clean armature/mesh hierarchy, animation clips named with
  the `AN_` prefix. Retain the editable `.blend` and repeatable builder script.

## Motion-reference limitation

The Y-Bot FBX and cleaned GLB are now in the project. No usable Mixamo football
motion clips are present yet. The character is validated as a Godot-importable
65-bone, 1.805 m, Y-up skinned rig; a real in-game motion pass still depends on
getting clips and checking them against the player/ball contact context. The
Y-Bot shell remains a rig proxy and must not be mistaken for the final
sheet-matched human character.
