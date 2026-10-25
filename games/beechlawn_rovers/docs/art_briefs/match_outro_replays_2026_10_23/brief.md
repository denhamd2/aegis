# Goals, full-time, replays and final keeper follow-up

Original Blender celebration and handshake clips use the unchanged shared rig.
A four-second scorer/nearby-teammate sequence handles own goals correctly.
Full time shows winners or neutral draw reactions, nearby opponents walk to
handshakes, then a results screen provides working Rematch and Title buttons.
Space/Enter skips; reduced-team and duplicate-goal cases are covered.

A 30Hz twelve-second ring and at most three eight-second bookmarks store actual
root/bone/ball/net poses. Replay ghosts have no scripts, physics bodies, gameplay
groups or events; runtime meshes/materials preserve each head and kit. Live
players, ball, goal detectors, animation evaluation and rules/clock are held.
Skip/finish restores exact pending restart state. Major saves/posts/cards replay
at natural stoppages, and goals replay after celebration. Pose storage has a
60MiB data cap plus a 4MiB metadata allowance. The unskipped full-match check
measured 32,650,200 data bytes and reached results after a 6–5 match.

The final keeper pass replaces lateral reaches with full-body rolled dives,
a low torso collision proxy and normal-speed recovery after fast preparation.
High crosses can be claimed with actual hand reach; rebound gathers lower the
gloves first, held balls follow evaluated hands with gravity compensation, and
stoppages restore the exact standing collider. Mirrored travelling-ball tests
and native dive/high-claim sequences pass. Unchanged body/head/kit resources and
shipping gait leg/root keys remain protected.

Native Forward+ llvmpipe 640×360 fixture stills show original roster assets,
celebration, replay, winners, handshakes, results and physical keeper contacts.
The outro fixture uses scripted poses for visual QA; it is not evidence of a
naturally produced goal. Natural match evidence is recorded separately.
M1 appearance, responsiveness and 1080p60 performance remain hardware gates.

The Xvfb runner now waits for the complete display-number line. The previous
single read could close the pipe between digits and newline, terminating Xvfb.
A split-write regression covers this race. Package verification also runs the
exported Mac resource pack with the matching headless Linux engine to verify
version/source/UTC; that does not execute the Mac binary or certify Mac graphics.
