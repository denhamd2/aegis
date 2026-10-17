# Beechlawn Rovers

An original 3D association-football game prototype inside the Aegis
repository. It has its own Godot project, scenes, scripts and assets. Its
export pipeline can be added independently. Open this directory as a separate
Godot project; the Aegis project remains at `game/`.

The supplied gameplay specification is the product target. Development follows
its milestones in order; features are marked complete only after they work in
the build. The setting is a Sunday-league match at a local park. The current
build is an early 4v4 blockout at the football-fundamentals checkpoint; it
does not yet implement the complete match loop.

## Current checkpoint

- Fixed 60 Hz player and ball simulation.
- Camera-relative keyboard movement with acceleration, turning,
  sprint stamina and close-control modifier.
- An independent regulation-size rigid-body ball, grounded dribble touches,
  buffered short and through-pass commands, and a variable-power shot.
- A broadcast-style tracking camera, match goals and basic scoring/reset.
- A three-minute short-match clock, score display and development telemetry.
- A worn park-pitch setting with lightweight scene geometry.
- Four blockout actors per side, assembled from editable roster data, with
  Tab switching among Beechlawn outfielders and a simple nearest-player chase.
- Basic off-ball support lanes in possession and goal-side recovery positions
  for non-pressing defenders.
- Late-game defensive choices: a trailing side can add a second presser high up
  the pitch, while a leading side drops its defensive line deeper.
- Short turnover transitions: the losing side can counterpress with cover
  retained, while the team winning possession makes more direct support runs.
- Teammate-aware short passes and through-balls, with aim-lane selection,
  opponent-lane avoidance, runner lead, and AI receiver movement.
- A center-spot kickoff, brief goal pause, restart by the team that conceded,
  and a match clock that runs only during open play.
- Basic AI goalkeeper positioning, shot-lane prediction, reaction delay and
  close-range physical saves. Slow shots can be gathered and held briefly
  before a lane-aware teammate distribution using the ball's normal kick
  impulse; authored diving, catching and distribution animations remain future
  work.

The actors are low-cost kit-colour blockouts. They do not yet reproduce the
players' faces or the character-sheet clothing detail. The nearest outfielder
presses the ball; two wide support lanes and compact defensive recovery targets
are still simple formation heuristics, not coordinated full-team tactics.
Complete match rules and authored football animation
clips remain future work.
Bordeaux's four slots use Des Feeney's sheet as a visual base, not as four
separate invented identities.

## Controls

| Action | Keyboard |
| --- | --- |
| Move | WASD |
| Sprint | Shift |
| Close control | Ctrl |
| Ground pass | E |
| Through pass | Q |
| Charge and shoot | Hold/release Space |
| Standing tackle | F |
| Slide tackle | G |
| Switch Beechlawn player | Tab |
| Directional aim | Arrow keys |
| Debug telemetry | F3 |

Arrow keys set the pass lane; E selects a teammate for a ground pass and Q leads
a moving teammate into space. AI receivers make a short run toward their
assigned pass target. A pass can be queued for a short first-time redirect when
a friendly ground ball is closing on the player's kick window. AI defenders
anticipate a reachable point on a moving ball's short path; possession still
changes only at close physical contact. This remains a lightweight 4v4
prototype without authored first-touch animations or advanced interception
decisions.

Sliding tackles commit the player for a short approach before resolving ball
contact. The AI can slide from longer range; opponent-first contact raises a
foul call and does not change possession. Free-kick restarts are not implemented
yet. Running players also have a brief, attribute-weighted shoulder response
when they contest an opponent-held ball side by side; the ball remains governed
by the ordinary possession and contact rules.

The first match slice uses keyboard input only. Press E or Q to take
Beechlawn's kickoff; Bordeaux restarts automatically after a goal pause. The
clock runs for three minutes of open play and then stops at full time. Throw-ins,
corners, fouls and the other full match rules are still being built.

## Blender workflow

The shared skill guides are in `.claude/skills/`. The mesh builder at
`tools/blender/beechlawn/build_training_assets.py` creates an editable `.blend`
source and Godot-ready GLB exports for the regulation goal and worn size-five
fallback ball. The match scene now uses the owner-supplied worn-ball model,
optimized by `tools/blender/beechlawn/optimize_old_used_ball.py`; its runtime
mesh is about 4.4k triangles at 22 cm, while the independent sphere collision
remains the authoritative physics shape. See
[`old_used_ball_source_notice.md`](assets/environment/old_used_ball_source_notice.md)
for its source and non-commercial usage restriction. The editable source is stored at
`tools/blender/beechlawn/beechlawn_training_assets.blend`. It uses Blender
4.3.2 and glTF metallic-roughness materials, with the skill guidance from `environment-artist`,
`blender-modeling`, `blender-materials`, `blender-export`, and `godot-export`.
Generated game assets are kept under this project; the reusable Blender source
and build script live in the repository's shared Blender tools directory.

## Run

Open `games/beechlawn_rovers/project.godot` in Godot 4.6.3, or run:

```sh
godot --path games/beechlawn_rovers
```

The Mac M1 Pro 60 fps target is not yet measured. This first checkpoint uses
one CharacterBody3D, one RigidBody3D, low-cost static pitch geometry and a
single directional light. It avoids runtime IK and per-player tactical loops.

See [`docs/roadmap.md`](docs/roadmap.md) for the staged plan and remaining
acceptance checks, and [`docs/backlog.md`](docs/backlog.md) for the ordered
development backlog.
