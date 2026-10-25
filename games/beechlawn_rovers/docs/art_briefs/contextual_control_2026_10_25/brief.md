# BR-002 / BR-021 — contextual first touch and moving reception

Items 2/27 and 21/27, in progress. Owner-approved controls: movement chooses the
outlet, Ctrl cushions close, Sprint deliberately knocks into space with loss risk.
Grounded pass control/receiving and combinations are the scope; additional shooting
variants, aerial claims, heads/body/kit and stadium production remain separate.

## Reference / production contract

Use the archived named player/kit sheets and broadcast reference indexed in
`references/README.md`, the current `footballer_shared.blend`, shipped shared rig,
and original stride add-on. The actual Shane in the 11v11 match is the primary
contact/motion fixture; also check Boardeaux and current keepers. Four original
60 Hz in-place receive actions (standing/moving × left/right), metadata and a
small animation-only GLB. Use create-player's production/animation checks, Blender
director, animation/rigging and Godot-export guides through headless bpy.
Preserve 65-bone rest transforms, body/heads/eyes/grooms/kits and all old clips.
No runtime IK, root-motion ball authority, extracted motion or paid assets.

Priority gaps: generic dribble can consume an incoming pass before receiving;
right-only fixed receiving target; fixed world-space cushion brakes moving
receivers; moving actions can suppress the locomotion gait; stale reception or
buffer cleanup can block quick combinations. Baseline logic/native evidence and
protected hashes are retained here before implementation. Compare motion from
identical pitch-side and broadcast cameras on pitch, never in the sky.

## Intended behaviour / validation

Default outlets: close .45 m, normal .75 m, sprint 1.35 m relative to carrier.
Ctrl takes priority. Relative-velocity cushioning is bounded by physical speed,
existing ball-control ratings and incoming speed. Keeper possession, aerial actions,
committed recovery and first-time strikes keep priority. Only the receiving
actor's automatic spring is deferred; opposing tackles/interceptions remain live.
Receives need a real selected boot within .20 m and local ground-height limits.
Moving receive overlays retain gait/support-leg motion and physics-timed poses.

Verify deterministic serial/foot/mode lifecycle, standing/moving/sprint/angled
receptions, left/right, interruption, misses, lost ownership/restarts, combinations,
both ball choices and uneven/wet ground. Preserve normal acceleration/braking,
kinematic grounding, kick contact guards and shared independent playback. Native
Forward+ moving comparisons and six full matches per venue retain the existing
chance thresholds. Delivery: universal Mac v0.4.2; M1 output/input/1080p60 remains
BR-025 (25/27, in progress), distinct from cloud software Vulkan evidence.

## Implementation and evidence

`PlayerReceiveController` predicts the intended receiver's selected boot before
dribble assistance, binds preparation to the pass serial, and validates actual
toe reach at the exported .20 s marker. A temporary receiver/ball capsule
exception is owned and restored by that preparation; other players remain live.
The impulse follows carrier velocity with bounded relative outlet travel.
First-time pass/shot intent bypasses the trap. Raw movement input, rather than
the assisted cursor's placeholder stick, chooses human outlet direction.
Synchronous whistles cannot rearm a completed/reset receiver.

Four original actions use the unchanged 65-bone rest and ship in an animation-only
add-on; [the audit](animation_audit.json) retains every source pose sample and
marker. [Protected hashes](protected_hashes.json) cover 186 existing character,
texture and shared-source files. Moving overlays retain the pelvis/support leg
and gait phase; standing reception switches to that overlay when running starts.

The original moving-pass repro produced `dribble` before a first touch
([baseline](baseline.log)); disabling only that receiver's spring produced a
physical first touch ([diagnostic](probe_no_spring.log)). The production check
now exercises the same live pass without the diagnostic override. Layer/physics
checks measure integrated close/carry/sprint ball speeds of 4.883/5.506/8.233 m/s
for a 6 m/s carrier. Callback-time velocity getters can still describe the
incoming state, so assertions sample the subsequent physics integration.

An initial chain of four receive overlays increased dormant 22-player mixer
cost by 51% in the isolated benchmark. One selected clip/seek/blend layer removed
that regression ([before](graph_cost_before.log), [after](graph_cost_after.log),
[repeatable probe](graph_cost_probe.gd)). Off-ball controller fast paths reduced
the same full-match cloud run from about 100 to 81 s without changing simulation
rate or decisions. These are host timings, not target frame-rate measurements.

Both unchanged six-match chance gates pass: Kilmore **28/38 physical shots**, each
team qualifying **6/6**; Arena **22/21**, each team **6/6**. All twelve finish with
ordinary physical football actions, using each kickoff side and three starts.
See [Kilmore results](chances_kilmore/summary.json) and
[Arena results](chances_arena/summary.json). No chance quota or keeper nerf was added.

Full-match startup now has its own 90 s hard bound; simulation retains the
existing 120 s (presentation 180 s) bound. Only the first ready marker starts
that phase, and explicit timeout overrides preserve the old single deadline.
Native C++ animation-condition errors now fail immediately. One old generic
animation test also failed against the pristine v0.4.1 snapshot because it still
expected a planted stop at 4.2 m/s; it now checks the existing stepping brake
and a final planted stop at 2.4 m/s. This changes no runtime braking behavior.

The final focused regression run covers live moving/first-time contacts, gait
and braking, wet ground, aerial contacts/crosses/volleys, possession skills,
low/high/full-stretch keeper saves, recorded replays, discipline, HUD and both
saved ball choices. Arena reruns cover the contextual receiving/edge/layer checks.
The 10 fps render-cap probe still resolves the first physical event as
`first_touch`. A full presentation match reaches results with no automatic skips,
8/5 shots, 5/3 contested shots and a 2–2 score. Relevant logs:
[initial contacts](final_regressions.log),
[remaining regressions](final_regressions_remaining.log),
[Arena receiving](arena_receive_checks.log),
[slow rendering](low_render_receive.log),
[full presentation](full_presentation.log).

The exported resource pack also passes the same external moving-reception probe
at both venues ([packaged contact log](packaged_receive.log)). This runs the
shipping scene, scripts, imported clip and metadata from the PCK; the test itself
stays outside the delivered game. CI repeats this after checking universal
arm64/x86_64 bundle structure, exact source/version/time and all four venue/ball
startup combinations. Historical ObjectDB/resource warnings at headless test
shutdown remain visible; they are separate from script/assertion/native animation
errors and were not relabelled as fixed by this work.

## Native review and remaining acceptance

[Side-by-side motion](receiving_before_after.mp4) shows v0.4.1 on the left and
v0.4.2 on the right, with identical cameras, light, player, inputs and incoming
passes. The baseline snapshot is reconstructed from
`e8dcb73354130cc7e01ebacba2632ce527219e11`; only the review fixture is copied into
it. The final optimized code is used for the after/broadcast captures. Each
sequence samples 300 fixed physics ticks into 100 frames at 20 fps: standing
right/left, moving close-control left, jogging carry right and sprinting left.
The baseline records **2/5** first touches; the new code records **5/5**.
The selected boot reaches the ball while moving receptions keep bent balancing
arms and running support-leg motion. Camera framing includes the player and
grass throughout.

Raw frames, runtime state, adapter and command manifests are retained under
`native_before/`, `native_after/` and `native_broadcast/`;
[after motion](receiving_after.mp4) and
[broadcast motion](receiving_broadcast.mp4) are review copies. Rendering is native
Forward+/Vulkan on llvmpipe at 640×360, with the actual shipped player, pitch,
materials and sun. Other actors are parked to isolate reception. It establishes
integration and visible motion, not M1 graphics parity or real-time frame rate.

This receiving slice is implemented. BR-002 (2/27) and BR-021 (21/27) remain in
progress for their broader contact/animation scope and Mac feel. Next acceptance:
BR-025 (25/27, in progress), run the universal v0.4.2 package on the M1 and assess
first-touch input/space, both venues and sustained 1080p60. Broader turn/intro
footwork and individual facial likeness remain separate open work.
