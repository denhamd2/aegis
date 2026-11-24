# Aegis aerial move releases

The owner requested work one move at a time, with reusable motion for future
wrestlers and assignments for Cody or Kenny where the move fits their style.
Review each move's takeoff, silhouette, contact, sell and recovery on both
bodies. Use the reference to judge the beats and hand-author the motion on the
Aegis rig. Record the gameplay case and open visual work for each move.
Commit and deploy after every second completed move and verify the exact
Mac commit before starting the next pair. The Cody Cutter was already in
the Mac pipeline when the owner set this cadence. The Diving Frog Splash
and Springboard Moonsault form the first pair.
[Reference compilation](https://drive.google.com/file/d/1SYI-phi8Ci-WmbtxqtFEswarYHfhKGqc/view).

## Order

| Order | Reference move | Wrestler in the catalogue | Aegis delivery |
| ---: | --- | --- | --- |
| 1 | Cody Cutter 4 | Cody Rhodes | Published on Mac at `e50966c`. |
| 2 | Diving Frog Splash | Christian Cage | Authored for the shared top-rope library and assigned to Kenny. |
| 3 | Springboard Moonsault 3 | Chris Jericho | Reworked the existing Cody and Kenny springboard route. |
| 4 | Diving Shooting Star | PAC, Sammy Guevara | Build the takeoff and backward rotation into a forward landing. Fit a roster test candidate only after review. |
| 5 | 450 Splash 1 | Nick Jackson | Build the forward rotation and chest-first landing. |
| 6 | Swanton Bomb | Jeff Hardy | Give the dive its own late rotation and back-first bump. |
| 7 | Coffin Drop 1 | Darby Allin | Author the upright fall and back-first contact separately from the Swanton. |
| 8 | Diving Headbutt 1 | Bryan Danielson | Author both roles and dock the contact to the torso. |
| 9 | Diving Foot Stomp 1 | Riho | Author the vertical drop, grounded sell and landing step. |
| 10 | Draping Diving Knee Drop | Nyla Rose | Add the draped-rope setup and clear it safely on release. |
| 11 | Black Arrow | PAC | Author the twisting shooting-star variant once the base dive is reviewed. |
| 12 | 630 Splash | Sammy Guevara | Give the extended rotation its own takeoff, hold and landing. |
| 13 | Magic Girl Splash 1 | Yuka Sakazaki | Author its distinctive setup and body shape. |
| 14 | Half-Moon Magic Girl Splash 1 | Yuka Sakazaki | Review its transition and contact as a separate move. |
| 15 | Magic Girl 450 Splash | Yuka Sakazaki | Fit her variation to the reviewed forward-rotation family. |
| 16 | Old School Moonsault | Lance Archer | Reuse the relevant flip and build the rope-walk release. |
| 17 | Panama Sunrise 2 | Adam Cole | Treat it as a corner launch into a two-body grapple. |
| 18 | Strong Stomp 2 | Britt Baker | Catalogue entry with a grounded setup. Review after the high-flying moves. |

The same footage also lists the Flying Single Leg Knee Strikes, Diving Judas
Effect, Buckshot Lariat, Rope Fallaway Slam Moonsault, Cody Cutter 5,
Slingshot Cutter, Slingshot Destroyer, Middle Rope Twist of Fate, Avalanche
Poison 'Rana, Running Step-Up Tornillo Kick and the Running
Lariat/Slingshot Meteora Combo. These use the strike, cutter or grapple
systems and belong in the follow-up queue. The existing Mexican Destroyer
work continues separately.
[Catalogue and wrestler attributions](../aew_ff_animation_review.md#the-moves-in-the-video-as-read).

Keep Cody's springboard cutter, Disaster Kick, moonsault and crossbody as
his established choices. Kenny already uses the springboard moonsault and
tope. Review optional additions on their actual models and keep signature
variants for their reference wrestlers where applicable. The other moves
should be playable when assigned to a compatible roster entry.

## Verified footage beats

- **Cody Cutter 4, 6:15–6:17.** Cody plants on the rope, extends inward,
  turns across the standing opponent and brings him down by the head.
  Approximate samples show the push at 375.95 s, the catch around 376.3 s
  and the mat bump around 376.7 s. The older signature loop labelled this
  segment as Disaster Kick. Both of the older cutter and kick clips are
  separate moves in Aegis.
- **Diving Frog Splash, 5:19.5–5:21.** Christian Cage loads on the top
  turnbuckle, takes off at roughly 320.05 s, folds his knees and hands
  together in the air, extends by 320.35 s and lands chest-first around
  320.5 s. The defender absorbs the impact and the attacker rebounds and
  rolls away. The low-angle replay shows the tuck and extension clearly.
- **Springboard Moonsault 3, 4:42–4:44.** Jericho starts in the ring
  with his opponent on his back. He approaches and loads the rope, lifts
  into a backward rotation at roughly 283.0 s, then extends and lands
  chest-first around 283.55 s. The side view shows the tucked legs at
  inversion and the open arms on the descent.

## Springboard Cody Cutter review

Aegis starts this version from the apron. Cody loads the middle rope,
extends and turns inward, catches the head under his right arm and lands
beside the defender with his upper back toward the canvas. The defender
braces with his palms, takes the face-down bump and rolls into Down facing
the apron. The attacker has space to get up alongside him.

| Beat | Reference sample | Aegis 60 Hz tick |
| --- | --- | ---: |
| Leaves the rope | About 375.95 s | 26 |
| Catches the head | About 376.3 s | 48 |
| Both land | About 376.7 s | 70 |
| Returns to gameplay | Footage cuts to replay | 112 |

The first reblock established separate catch and bump beats. Sampling the
right forearm against Roman's head showed it drift up to 44.5 cm from the
head bone during the drop. The second pass moved the shoulder and wrist
with the defender, and the side render showed the catch continuing through
the drop. The following passes reduced the forearm flicks at release and
landing, aligned the planted boots and led the bump with the palms.
The final Blender exports have zero measured one-frame snaps and dead holds
in both roles. The mean angular-speed changes are 120.0 and 78.3 degrees per
sample, compared with 60.0 and 58.4 in the simpler previous roles.

The staged cutter landed with Roman–Cody and Cody–Kenny slot assignments. A
regression checks that damage is applied once at tick 70, Roman finishes
facing the apron in Down, and Cody's clip matches the segment duration.
Gameplay, catalogue, strike-library, pose, authoring and audio checks
passed across 105 distinct cases. The export comparison preserves all
319 other action track payloads. In the final Roman sample the late palm
penetration fell from 7.2 cm to 2.0 cm. Cody's boots stayed within 0.3 cm
of the mat at the sampled landing and brace ticks. The wide camera still
looks through the ropes during the mat bump. The Unreal bundle includes
both aerial roles and exact move duration. Native arena appearance,
independent likeness scoring and Unreal runtime integration remain open.
[Side and match-camera framing](moves/cody_cutter_4.png).
[Godot match sequence](../../../game/core/match/dive_spot.gd).
[Unreal import notes](../../../tools/unreal/MOVE_SYNC.md#springboard-cody-cutter).

Mac build 45269579857 published `e50966c`. The tag, release target and
uploaded 1,034,138,726-byte ZIP were verified. The Unreal move bundle for
that commit also passed its export checks.
[Mac build](https://github.com/denhamd2/aegis/actions/runs/45269579857).
[Unreal bundle](https://github.com/denhamd2/aegis/actions/runs/45269579845).

## Frog Splash and Springboard Moonsault

**Diving Frog Splash.** Kenny turns on the corner, pushes off, tucks his
knees, extends chest-first and rolls to the side. The defender compresses
and settles back into Down. The normal top-rope sequence can hand both
roles into a cover. Aegis applies damage at tick 60, about 0.53 seconds
after the push. In the reference, the flight takes about 0.45 seconds.
Other wrestlers can use the move through their top-rope moveset entry.
[Review frames](moves/diving_frog_splash.png).

**Springboard Moonsault.** The opponent settles on his back during the
apron load. Cody or Kenny opens from the backward rotation and lands
across the torso. The hit moved to tick 72, about 0.60 seconds from
takeoff. Aegis keeps its apron setup. Jericho starts from inside the ring
and lands about 0.55 seconds after takeoff in the reference.
[Review frames](moves/springboard_moonsault_3.png).

The final exports have zero detected one-frame snaps and dead holds
across both roles for both moves. All 56 focused gameplay, catalogue,
table-dive, clip and authoring checks passed. The source export preserved
the original action indices and 319 unrelated action payloads. The updated
Unreal bundle names all
four roles and includes their impact and recovery frame values. Native
M1 performance, Unreal playback and independent likeness scores remain
open. The next pair is Diving Shooting Star and 450 Splash 1.
