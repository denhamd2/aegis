A three-minute keyboard 11v11 Sunday-league prototype at Kilmore Drive.

Beechlawn Rovers 27 title screen:
- GPT Image key art now features David Murray and the owner’s likeness for Derek Mitchell (#3), replacing Robbie in the promotional image. Both faces share the campaign lighting and finish; the oval club crest, Uhlsport marks and Thomas Loomes & Co sponsor remain.
- Start Game and Options, with Play (keyboard vs AI) or Watch AI vs AI selection.
- Watch kickoffs/restarts run automatically; Play retains the keyboard controls.
- Saved master volume and native fullscreen preference; Esc returns to title.
- Promotional key art is separate from the in-game character meshes.

Pre-match broadcast and cameras:
- Optional approximately 40-second intro: original shared Blender walk-on and
  warm-up clips, team lineup, roster-labelled portraits, and venue, pitch,
  ball, goal/net and spectator shots. Space/Enter skips straight to kickoff.
- Nine gameplay camera presets, saved height/zoom/angle and C cycling; Close
  Broadcast remains default. These are original camera implementations inspired
  by documented PES 2021 families, not copied PES settings or assets.
- Fixed player spawning duplicating configured rigs: one skeleton per actor,
  no doubled faces or stale T-pose rig. Replacement rigs receive an idle pose
  before the first frame. Braking arms are relaxed in the shared Blender source.
- Repaired leaf-card UV0 in both Blender tree modules and the module builder;
  net mip coverage and chalk filtering improve detail-shot readability.
- Full/skip intro restores kickoff, referee, HUD, animation and camera state in
  Play/Watch, without consuming match time or replaying after goals. Native M1
  frame times and final likeness/garment/environment polish remain open.

Movement/contact update:
- Wide AI carriers gradually improve their shooting angle in the final third,
  instead of always dribbling straight toward the byline.
- Grounded dribble direction follows body turns; nearby players no longer apply competing assistance.
- Pass/shot inputs can interrupt harmless turn recovery; kicked balls get a brief release window.
- Gait blending follows actual speed; running turns preserve moving footwork.
- Shared-human pivot arm poses are relaxed in Blender; other action/contact curves are preserved.
- AI recognizes open shots under trailing pressure and moves into reach of loose balls.
- Pass targeting scores the complete ball path; reachable carriers retain their
  actions instead of yielding to a future interception runner. Successful
  reception resumes carrying, and turnovers cancel obsolete arrival targets.
- Repeatable midfield attacks for both teams pass the physical-shot gate.
  Full matches pass stability checks and report shots; some natural replays
  still contain zero shots. Attacking balance and chance frequency remain open. See `art_briefs/attacking_flow_followup.md`.
- Gemini's reviewed recommendations and the updated implementation backlog are archived with the project.

- 10 outfield players and one goalkeeper per team; a separate referee.
- Shared human body/rig, editable roster/appearance resources and role kits.
- Closer tracking broadcast camera, scoreboard, radar and basic boundary restarts.
- Worn terrain, rough chalk, weathered goals/nets, residential dressing and eight spectators.

Controls: WASD move, Shift sprint, Ctrl close control, E pass/start, Q through ball,
hold/release Space shoot, F tackle, G slide, Tab switch player, C camera, Space/Enter skip intro. Select the canvas first on Web.

Web: https://denhamd2.github.io/aegis/beechlawn-rovers/
Mac: download Beechlawn-Rovers-Mac.zip, extract and open the app. The app is ad-hoc
signed, not Apple-notarized; macOS may require Open Anyway in Privacy & Security.

Validated with automated match/contact/restart checks and software-WebGL captures.
The Mac archive is structurally checked; native Mac playtesting and M1 Pro/16 GB
1080p/60 fps measurement remain pending. Individual facial likeness, exact venue
matching, complete rules and additional formations are still in development.
General foot planting, transition polish and balanced AI chance creation remain open.
Touchlines currently use a prototype ground-pass restart, not a throw-in animation.

Park placement correction (19 October 2026):
- Added the satellite-informed tapered western green, continuing road and
  footpaths, matching boundary outline and reused roadside house instances.
- Softened pitch paint to a faded, matte off-white, retaining the existing
  uneven widths and worn edges for the Sunday-league setting.
- Reviewed the uploaded and archived satellite views; the pitch now sits within
  open park grass, with 35 m before the roadside footpath and 37.75 m to the
  near road edge. Street props and housing move back together.
- Tree placement leaves the central grass apron open; fans stay at the touchline.
- A visual ground apron meets the pitch at grade without obscuring its relief;
  park texture mapping is fixed in world space. Close broadcast settings and
  the 105 x 68 m gameplay pitch remain unchanged.
- Layout distances are approximate; exact boundaries, road bends, venue art
  fidelity and native M1 profiling remain open.
