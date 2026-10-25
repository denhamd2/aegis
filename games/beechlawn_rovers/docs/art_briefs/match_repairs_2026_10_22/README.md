# Native match repair review

[Opening storyboard](opening_storyboard.jpg) shows the six shots before walkout.
[Dribbling](movement.mp4), [throw-in](throw.mp4) and [net impact](net.mp4) are native
Forward+ sequences assembled at 10 fps from six 60 Hz simulation steps per draw.
They show actual match actors/controllers/assets, using isolated test positions
for repeatability. Existing character/venue artwork is not claimed as final.

All captures use Godot 4.6.3 Forward+/Vulkan, llvmpipe LLVM 19.1.7,
640×360, 4× MSAA. JSON records scene state for every frame. Capture manifests
record command, timing and bounded cleanup. Slow software-GPU rendering is
not evidence of Mac GPU output or performance; this is simulated playback.

The full montage is sampled at start, middle and end of each shot. Black at
an opening cut is its intentional short fade. The storyboard uses midpoints.
The original numbered PNGs remain in ignored project build storage; selected
frames, sequence movies and SHA256 index are retained here.

See [implementation and test scope](../../match_repairs_2026-10-22.md).
