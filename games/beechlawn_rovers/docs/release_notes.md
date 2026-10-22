# Match behaviour and broadcast repairs

Fixed reproduced dribble launches and skating after locomotion clips stopped.
Both penalty arcs face midfield and the complete selection ring lies on grass.
Real overhead throw-ins replace touchline ground passes. Aim/power restarts,
free kicks, penalties, yellow/second-yellow/red cards and dismissals are added.
Goal-net contact now drives a local bulge while the scored ball keeps moving.
A new eighteen-second opening montage shows posts, net, ball, John O'Rourke,
Boardeaux player Des Feeney and the goalmouth before walkout.

Keyboard restarts: WASD aim; hold/release E throw/pass; Space shoot. Watch mode
restarts automatically. Full advantage/offside laws, final visual polish and
M1 hardware validation remain open. See [repair details](match_repairs_2026-10-22.md).

# Mac-only delivery

The owner retired the football Web version. Releases now contain only the
universal Mac app; football Web exports and Pages publishing are disabled.
Native Forward+ captures and headless logic checks remain the validation path.
Historical Web evidence is retained in the repository. The wrestling Web game
and its Godot export stay separate and unchanged.

# Native Forward+ visual-review workflow

Football now has a separate native Godot Forward+ capture runner using
Vulkan/Xvfb on cloud Linux and the native graphics driver on macOS. New
960x540 portraits and the actual 11v11 broadcast kickoff view record renderer,
adapter, antialiasing, shadows, actor counts and image hashes. These become
the primary cloud appearance evidence; browser checks still cover the Web
build and headless checks cover logic. Process deadlines, live logs and
bounded post-readback cleanup prevent the observed software Vulkan teardown
hang from leaving capture commands running. Native Mac appearance and frame
rate still need hardware validation. Gameplay and wrestling assets are unchanged.

# Four-player head and skin refinement

Shane Denham, John O'Rourke, Boardeaux player Des Feeney and referee Des Feeney
Sr. now have independent reference-led head/eye packages on the shared body,
rig and animation library. The pass refines facial proportions, repairs the
lip-closing deformation, adds individual roughness and fitted directional
scalp/facial-hair grooms, and retains continuous fair skin at the neck.
John's scalp uses blonde highlights; his warm brown beard stays unchanged.
4x MSAA reduces fine-strand and geometry aliasing while retaining shadows.
All eleven Boardeaux actors intentionally reuse their player's Des identity;
the referee remains a separate older face with a grey moustache.

The create-player workflow now records source/export, neck, lip-winding,
material and shared-animation checks, with repeatable four-head authoring.
The earlier skin and daylight-shadow corrections are included. No gameplay
rules or wrestling project assets change in this release. Individual likeness
and facial expression remain in development; native Mac rendering and M1
performance have not been validated by the cloud/Web checks.

# Opposite-touchline broadcast

The landing screen now uses the owner's supplied Beechlawn Rovers 27 wordmark
with red/black/white menu and Options controls. The original photographic player
art and blue/black kits are retained. Play, Watch and keyboard navigation keep
their existing behavior.

During the walkout, TV-style face graphics introduce Beechlawn Rovers first,
then Boardeaux, each in a 4-4-2 with its crest and player-manager. Robbie Roden
manages Beechlawn; Des Feeney fills every Boardeaux slot and manages that side.
Colly Roden now wears 14; Beechlawn's retired number 2 cannot be reassigned.

The opponent is named Boardeaux throughout the title, scoreboard, match messages
and roster shirt prints. The pre-match starting-lineup pan now takes 12 seconds
instead of 4.2, with its smooth start and stop retained.
The intro-to-gameplay handoff also starts on the selected camera's side.

After the home and away walkout graphics, a close-up of referee Des Feeney now
gets a short matching navy/blue lower third. The generated geometric plate is
paired with live Godot text and the in-game referee model, then fades cleanly
into the next pitch-detail shot.

The default Close Broadcast and the other sideline camera presets now view the
match from the opposite side. Their close framing, tracking and editable
height/zoom settings are retained. Keyboard movement remains screen-relative.

Gameplay contact, chance and keeper update (21 October 2026):
- Moving passes/shots use a short setup stride and live boot reach at the
  authored marker; a bounded contact window prevents remote kicks.
- Ground control waits until a turning player can reach a rear ball, preventing
  the spring from pulling it through his body.
- First-time shots buffer across an incoming pass. Fast returns skip redundant
  anticipation, and completed contact follow-through allows the next ball action.
- AI can shoot into an open corner beside a central blocker. Immediate fully
  covered lanes still discourage a shot. Trailing pressure no longer forces a
  blind backward outlet into a clear attacking route. Clear edge-of-area looks
  use an editable 22 m default; blocked actions preserve their cooldown.
- Keepers read rolling shots above the turf, respect reaction time, prepare
  their standing save before impact, face the ball and choose safer parry sides.
  Low/diving save clips and native M1 playtesting remain pending.

Pitch-side player previews (21 October 2026):
- The isolated roster-review scene now includes Kilmore Drive's static park,
  pitch surface and faded markings, with low perspective cameras for kit and
  portrait views. Web gallery captures show footballers on the pitch instead
  of against a sky-only backdrop.
- A clean capture mode hides diagnostic text; soft daylight keeps real
  shadows without an artificial ground shadow. A lighter blue-grey sky in
  these portraits corrects the overly dark blue source; match weather keeps
  its existing settings. This changes presentation,
  not match physics. BR-022 (22/25) remains open for gloves, individual
  likeness, save motion and native M1 review.

Goalkeeper kit graphics update (21 October 2026):
- John O'Rourke's grey/blue/gold keeper shirt and Bordeaux's charcoal shard
  shirt now use original flat pattern artwork based on the archived kit sheets.
  Supplied crest and lettering are applied separately; roster names and numbers
  remain editable. John's number gets a narrow dark edge for legibility.
- Both kits have reference-led sleeves, black shorts and role-coloured socks.
  The common sock binding UV now follows each role's sock chart. The 65-bone
  rig, geometry, skin weights and 19 clips remain.
- Front/back/save views use both real 11v11 roster paths in Godot. The save
  animation, goalkeeper gloves, individual faces and native Mac rendering
  remain under review within BR-022 (22/25).

Shared fabric response update (21 October 2026):
- Shared kit materials now distinguish cloth, elastic socks and front printing
  through original roughness/knit maps. Pigment/data mip filtering reduces
  jagged distant details. Existing kit artwork, rig, meshes and 19 clips remain.
- Matched source and real-shadow Web sun/shade reviews, role/pose/11v11 checks
  and Play/Watch startup pass. Texture memory increases; native Mac execution
  and M1 performance remain pending. Keeper graphic fidelity and likeness stay
  open under BR-022 (22/25).

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

## 2026-10-21 — shared upper-back cloth and sleeve silhouette

BR-022 (22/25, in progress): the common shirts now span the upper-back hollow
instead of copying the paired anatomical ridges. Long forearms are tapered
by at most 6.7 mm while retaining skin clearance and the cuff join. The same
geometry feeds both teams, keepers and referee. Skin, 65 bone rests, all 19
clips, UVs, kit images, head packages and mesh counts are unchanged.

See `art_briefs/shared_sleeve_fit/brief.md` for matched clay/Web evidence,
both sleeve-variant pose sheets and validation scope. This is a local garment
improvement; collar/raglan finishing, individual likeness and native M1
1080p/60 performance acceptance remain open.

## 2026-10-21 — smooth V collar and shared raglan trim

BR-022 (22/25, in progress): both sleeve variants use a smoother V opening and
supporting yoke, plus a fitted collar and shoulder trim. The existing role
atlas supplies each team's trim colour, so the detail now appears in Godot
as well as Blender. Bone rests, all 19 clips, skin/neck normals, independent
head packages and supplied kit images remain unchanged. The source default
pigment is aligned with the actual home-role atlas.

A regression check reproduces collar/skin intersections on the old source
and clears all sampled collar vertices in nine fixed poses on the new one;
trim triangles remain nondegenerate and uninverted in those poses. Geometry
is 68,244 triangles across all variants, up by 960, with 16 mesh parts. This
is not a measured per-actor render budget or native M1 performance result.
See `art_briefs/shared_collar_raglan/brief.md` for evidence and open art gates.

Review exports now stage their large import-cache copies under the football
project's ignored build directory, after accumulated disposable outputs filled
the cloud runner's smaller `/tmp` filesystem. Per-process deadlines remain.
