# Presentation batch — priorities 2 and 3

The owner approved related batches with focused commits, one validation and
one Mac deployment per batch. Full-arena/native visual review happens on the
owner's Mac after publication. Native M1 performance remains unverified.

## Result

- Central white move-name flashes are removed. Finisher/Signature readiness
  has a dedicated row above each wrestler's plate. Fired Up gets its own row
  too, so neither status covers the wrestler name.
- The finish starts the winner card/celebration immediately. No ending replay
  can restore an earlier fighting pose. Pending in-match replays are cancelled
  at the finish before the loser is laid out and both controllers are frozen.
- In-match Frequent replays remain available. The options screen offers Off
  and Frequent; legacy Finish enum/CLI values remain readable and do not cause
  an ending replay. The shared replay badge remains available to InstantReplay.

## Validation

**35 distinct cases pass**, zero errors/failures across these runs:

- [Six-suite focused report](focused_tests.xml): 34 cases, 115.430 s, exit 0.
  Covers HUD layout/links, normal and fatal pinfall losers, count-out losers,
  direct winner presentation, a fully buffered finish that must never replay,
  post-match menu and title handoff, plus in-match replay selection/cancellation.
- [Replay/options follow-up](replay_options_tests.xml): five cases, 38.799 s,
  exit 0 after the replay-menu change. Four overlap the earlier run; the added
  case verifies legacy Finish handling and switching Frequent/Off.

The HUD badge tests cover 640×360, 1280×720, 1600×820 and 2560×1600. They check
both sides stay within the viewport, do not intersect the name/health plate,
and fit the actual Finisher/Signature/Fired Up font widths.

Rendered and inspected [1280×720](hud_1280.png) and [640×360](hud_640.png)
using `tools/probe/hud_shot.tscn -- --hud-only`. Both show the real HUD drawing
code with Finisher, Fired Up and Signature active and a landed move emitted.
The centre stays clear and names remain readable. These are HUD-only layout
renders, not full-arena or real-character appearance evidence.

Renderer: Godot 4.6.3, Vulkan Forward+, llvmpipe (LLVM 19.1.7, 256 bits),
24 settle frames, fixed 60 Hz; `LP_NUM_THREADS=2`, `GALLIVM_PERF=nopt`.
Software rasterisation does not establish Mac frame pacing or a 60 fps result.

Focused command (writable XDG directories configured for this executor):

```sh
godot --headless --path game --fixed-fps 60 \
  -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
  -a res://tests/test_match_hud.gd \
  -a res://tests/test_match_hud_links.gd \
  -a res://tests/test_post_match.gd \
  -a res://tests/test_instant_replay.gd \
  -a res://tests/test_post_match_menu.gd \
  -a res://tests/test_title_presentation.gd \
  -c --ignoreHeadlessMode
```

## Delivery

The preceding lighting release was verified at
`d59d830dc51b7ec4bccd89dbd0e0167f7e3f0402`: Mac job succeeded,
`mac-latest` tag SHA matched, and `Aegis.zip` was present (982,707,267 bytes).
This batch is ready for publication. Verify its published tag/asset before
starting the next batch (priorities 4–6, AI and running offence).
