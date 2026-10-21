Shared garment construction update (21 October 2026):
- Restored missing forearms beneath short sleeves from the existing CC0 anatomy
  on the shared rig. Existing neck skin, heads and animation curves are retained.
- Connected quad rows and a folded edge replace the torn-looking lower shirt
  and disconnected hem ribbons. Both sleeve variants retain the kit atlas.
- A reshaped rear underarm gusset improves all nine sampled pose diagnostics.
  The source remains at 65 bones, 19 clips and 16 mesh parts, with fewer total
  triangles across variants. Garment fit and individual likeness remain open.
- Actual roster Web reviews and Play/Watch checks accompany the source evidence.
  Native Mac execution and M1 performance remain pending.

Shared shirt fit update (20 October 2026):
- Softer shoulder slope, smoother arm/torso weight transitions and a flatter
  back drape across both sleeve variants. The front chest tear and associated
  scalloped stripe registration are corrected locally.
- Existing collar/cuffs, kit images, independent heads, 65-bone rest rig and
  all 19 clips are retained. Nine fixed poses improve the fold diagnostic;
  rear-armhole pinching remains an open art acceptance item.
- Actual roster Web reviews and assembled 11v11 Play/Watch checks accompany
  the source evidence. Native Mac playtesting and M1 timing remain pending.

Wet pitch, weather and shared kit update (20 October 2026):
- Muddy goalmouths and irregular shallow puddles at both goals, with free CC0
  scanned soil, wet reflections and subtle ripples. Grounded balls physically
  lose speed in water; airborne balls retain their normal flight.
- Options saves Sunny (damp pitch), Cloudy, Light rain and Morning mist.
  Rain includes local precipitation. All builds use inexpensive distance haze;
  clear-weather broadcasts keep the pitch crisp without volumetric fog.
- Shared shirts remove the disconnected throat scrap and repair neck-side
  clearance/weights. Existing kit graphics, individual heads, 65-bone rig and
  all 19 clips remain. Shoulder/underarm refinement and likeness remain open.
- Actual WebGL reviews and bounded physics/menu/11v11 regression checks are
  recorded with the art briefs. Native Mac playtesting and M1 performance
  acceptance remain pending.

Partly cloudy daylight update (19 October 2026):
- A free CC0 photographic 4K sky replaces the featureless gradient, following
  the owner's preference for less overcast weather and direct sunlight.
- Blue openings and detailed clouds, balanced sky colour, slightly warm sun
  aligned to the panorama and cool ambient fill. Real directional shadows
  cover the pitch and nearby surroundings; very light distance haze retains
  clear match visibility. Volumetric fog is disabled for Web compatibility.
- Shared daylight settings serve match and player reviews. Native M1 lighting
  and performance acceptance remain pending; venue/character art is unfinished.

Shared head production update:
- Both teams and the referee now start from Shane's updated neutral head/eyes
  on the existing shared body and animation rig. Per-player sculpt recipes
  retain personal changes when compatible common improvements are rebuilt.
- Head and hair selection are independent. Shane keeps his groom; Des, his
  reused keeper, the referee and reserve Paddy use interim bald silhouettes.
  Other crop hairstyles and all unedited faces remain placeholders.
- Versioned master snapshots reject stale Basis/topology/UV/weight data.
  The create-player guide now routes common and individual edits through this
  pipeline. Assembled 23-actor, pose, intro and Play/Watch checks pass in Godot.
- Individual likeness, facial hair, collars/shoulders and native M1 visual and
  performance acceptance remain open. This is a reusable production foundation.

Previous photo-led character and menu update:
- Photorealistic landing portraits for David Murray and the owner, with clear
  natural-light faces and matching kit style. Existing Play/Watch modes remain.
- Shane has an independent photo-led head/eye/hair package on the shared body
  and animation rig. Refined jaw/chin, cheek, eyelid, nose and mouth forms;
  anatomical skin UVs retained, with a separate restrained smile shape.
  Replaced flat-looking cap hair with a dense curved short groom, geometric
  tuft normals and restrained highlights; other players keep the shared base.
- Both 11v11 and retained 4v4 Shane resources use the same head. Other identities
  and shared body/animations remain intact. Facial likeness remains in review;
  hidden profile shape is estimated from secondary references.
- Updated create-player workflow and production checks for future roster work.

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
