# Development roadmap

The owner's gameplay specification is the full target. The milestone plan
below keeps the game playable and measurable while it grows.

See [`backlog.md`](backlog.md) for sequenced tasks and acceptance criteria.

| Milestone | Scope | Status |
| --- | --- | --- |
| 1. Football fundamentals | One player, independent ball, locomotion, dribbling, short/through passing, charged shooting, pitch, goal collisions and goal detection | Prototype implemented; visual/gameplay QA pending |
| 2. Small-sided football | 4v4 (three outfield players and a goalkeeper per side), player switching, teammates, basic opponents, passing targets, tackles and goalkeeper play | 4v4 blockout, Tab switching and short clock in progress |
| 3. Full 11v11 | Formation data, 22 players, role positions, team shapes, attacking runs, broadcast camera and complete presentation | Not started |
| 4. Match rules | Kickoff, boundaries, throw-ins, corners, goal kicks, fouls, offside, cards, substitutions, halves and full-time | Not started |
| 5. Advanced football | Aerial play, skill moves, goalkeeper saves, tactical settings and more animation variety | Not started |
| 6. Polish and performance | Responsive tuning, animation blending/contact, AI refinement and native M1 frame pacing | Not started |

## First milestone gaps

- The current pass prototype has no receiver yet. Milestone 2 adds target selection and
  pass assistance among players.
- Shot release currently applies an impulse from a valid foot-radius window;
  the prototype avatar has no animation contact marker yet. The Blender rig and
  authored kick cycle will replace that timing in the character pass.
- The first goal can detect a crossing and update/reset the score. There is no
  keeper, restart state machine, net deformation or match clock rules yet.
- The low-cost avatar does not use the supplied face sheet. The face, hair,
  boots, crested kit, accurate cloth fit and original animation set need a
  separate rigged character milestone.
- Residential houses, roadside props, crowds, weather variants, HUD radar and
  final broadcast camera framing remain art/presentation tasks.

## In-game validation checklist

1. Confirm WASD and both sticks move in broadcast-camera space; verify sprint,
   acceleration, stops and close-control turns at 60 Hz.
2. Check the ball remains an independent rigid body and dribble touches vary
   with speed and close control. It must escape on a heavy sprint touch.
3. Test pass/through-pass aim, charging/releasing shots at several powers,
   posts, crossbar, ground bounce and a full-ball goal-line crossing.
4. Inspect actual Godot imports for ball scale, material roughness, goal-frame
   collision, camera coverage, visible kit details and any foot sliding.
5. On the M1 Pro, measure frame pacing at 1080p during play. Software-rendered
   frames do not count as performance results.

## Cost targets for M1

The intended render target is stable 60 fps at 1080p on the owner's M1 Pro with
16 GB unified memory. Initial CPU gameplay has one driven player and one ball;
ball physics is one low-complexity sphere at 60 Hz. A later 22-player build
should stagger AI decisions, keep collision shapes primitive, avoid runtime
IK chains, instance background props, and profile animation/physics before
adding more update work. No native Mac timing has been collected yet.
