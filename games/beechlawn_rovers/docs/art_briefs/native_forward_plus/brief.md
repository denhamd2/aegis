# Native Forward+ football look checks

BR-022, item 22 of 25: in progress. The owner requested captures closer to the
Mac graphics than Web Compatibility. The wrestling capture code was reviewed
read-only: it uses native Forward+/Vulkan, Xvfb, Movie Maker/frame probes and
an evidence manifest. Its files and rules remain untouched.

Football's separate `tools/capture_native.py` uses native Forward+ through
Vulkan/X11 on this cloud's Mesa llvmpipe adapter. The portrait is the actual
John goalkeeper appearance on the pitch, with his blonde highlights and
unchanged brown beard, the source match sky/sun, normal maps, shadows and
4x MSAA. The `match/` view is the actual 11v11 scene and opposite-side Close
Broadcast camera at kickoff, using its sunny weather and real 23-actor roster.
No generated artwork or replacement camera represents the match.

PNG/JSON pairs record the renderer, adapter/API, resolution, player/scene and
quality settings. Manifests include PNG hashes, process commands and cleanup.
The first cold 1280x720 run exceeded its 150-second deadline before readback;
the next 960x540 run saved a valid still but exposed a teardown hang. The
runner now streams logs, enforces a total deadline and bounds cleanup ten
seconds after a fresh saved image/report plus completion marker. Recorded
termination after readback is explicit; it does not certify normal engine exit.
Fresh captures pass image/renderer and script/compiler-error checks. Their
resolution is 960x540, following the practical wrestling cloud review size;
this is not 1080p hardware validation.

The native image shows why browser captures cannot close the Mac art gate:
Forward+ retains different skin/cloth lighting and tone response. Appearance
reviews now use this native path first. Web tests still cover Web startup,
controls, UI and renderer-specific regressions. Headless smoke checks remain
logic/structure checks. Mac graphics parity, animation feel and M1 frame times
need native hardware and stay open, alongside the existing facial finish work.

`heads/` contains the four final native roster portraits. Source/export geometry
and the headless roster/intro regressions are unchanged and pass. The prior Web
portraits used a softer diagnostic sun and lifted review sky; native captures
here use the actual default match sky/sun. They are separate target-renderer
reviews, not a controlled pixel comparison isolating renderer differences.
