# BR-022 pitch-side player review

The earlier Web asset-review fixture omitted Kilmore Drive scenery and used a level orthographic camera over a plain grass plane. Its close portraits and kit previews showed players against the sky, making them look as though they were standing in clouds. The owner asked for those previews to take place on the pitch.

The review scene now assembles the existing static Kilmore Drive park, the match pitch surface and its faded line mesh on both Web and desktop. The player stands off the centre-line paint. A low perspective camera keeps the grass, park edge, houses and trees in frame. `clean=1` hides diagnostic text for gallery captures. `lighting=soft` uses real, softer daylight and avoids the artificial shade-caster patch on the ground. These are presentation changes to the isolated roster review, not new gameplay or surveyed venue geometry.

The first pitch-side captures revealed an overly dark blue sky in the portrait view. The review now makes a local copy of the photographed sky material and selectively lifts its dark values toward a lighter blue-grey daylight. The match sky shader gains an opt-in control that defaults to zero, so normal match weather remains unchanged.

The nine PNGs here are actual 960×540 Godot Compatibility/WebGL captures of the roster profiles using `software=1&clean=1&pose=idle&frame=2&lighting=soft`. They replace the floating-background images in the published screenshot gallery. Historical material/pose diagnostics remain in their original evidence folders; those still serve art comparison but are no longer used as current player previews.

The scene uses the shared starting head and current kit construction. Individual face likeness, goalkeeper gloves and a convincing save animation are still open. Native M1 appearance and performance remain untested.
