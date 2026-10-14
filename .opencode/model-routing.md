# Model routing

The primary agent runs Muse Spark 1.3 Free (`opencode.json`) and acts as
orchestrator: it breaks features into tickets, tracks state machine logic,
enforces project standards, and dispatches work. It does not switch models
itself mid-session; execution goes to the pinned worker whose model fits
the job. Route every task through this table before starting work.

| The job | Delegate to | Model |
| --- | --- | --- |
| Blender scripts (`bpy`), rigging, bone rolls, root motion, glTF/GLB export, Node3D coordinate spaces, grapple socket alignment, quaternion/IK math, ragdoll blending | `blender-pipeline` | `opencode/step-5-preview-free` |
| Combat controller, grapple/FSM state machines, reversal and timing windows, pin/submission minigames, momentum economy, `AnimationTree` setup, scene architecture, event buses | `godot-combat` | `opencode/muse-spark-1.3-contributor-free` |
| Boilerplate GDScript, UI scripts, console errors, typos, signal tracing, small isolated helpers | `debug-flash` | `opencode/ling-3.1-flash-free` |

Rules:

- The orchestrator plans and tracks; workers execute tickets. A worker
  that finds the task is outside its scope hands it back rather than
  doing adjacent work.
- Match on the job, not on the file type. A `.gd` file holding IK math
  goes to `blender-pipeline`; a `.py` file driving match flow goes to
  `godot-combat`.
- Mixed tasks split at the boundary: Blender-side authoring and
  Godot-side wiring are separate delegations, in that order.
- If a job matches none of the three rows, the orchestrator does it
  directly instead of forcing a delegation.
