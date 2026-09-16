"""Leave a headless `bpy` run without tripping over its teardown.

Every exporter here segfaults on exit under the `bpy` *module* (4.2.0), and
does so **after** the .glb is written and closed:

    $ python3 tools/blender/ring.py --out /tmp/x.glb
    Segmentation fault      (rc 139)
    $ ls -l /tmp/x.glb       # complete, and byte-identical to the committed one

The crash is in the library's own interpreter shutdown, not in any model --
all five exporters do it, from any working directory. It does not happen under
a real `blender --background`, which never returns to CPython at all.

That matters because both build scripts run under `set -euo pipefail`, so a
teardown crash aborts the build after the first model, and a multi-model run
never reaches the second. `build_arena.sh` hit this the moment it was extended
to build the ringside crowd as well as the bowl.

So skip the teardown: `os._exit` ends the process at the point the export is
already complete. It is deliberately NOT a blanket "ignore 139" in the shell.
A crash during a build -- which is a real failure, and has happened while
posing a rig -- still surfaces as a segfault, because this is only reached
once `main` has returned. Exit codes keep meaning what they say.

`os._exit` skips atexit handlers and does not flush Python's own buffers, so
flush first: without it the "ring: N triangles" line is lost when stdout is a
pipe or a log file.
"""

from __future__ import annotations

import os
import sys


def finish(code: int) -> None:
    """End the process with `code`, bypassing `bpy`'s teardown. Never returns."""
    sys.stdout.flush()
    sys.stderr.flush()
    os._exit(code)
