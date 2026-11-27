# ricochet_moveset.md — Ricochet's moveset, and what the game gives him

Research for Ricochet's own moveset, written the way the other refs are: every
claim says where it came from, and every game move named here is a file that
exists in `game/resources/moves/`.

His model is already imported into the Unreal port (`/Game/AegisTest/Ricochet/`,
on `root_Skeleton`); this doc is the moveset half — backlog item 3, "map his
moves to existing/planned Aegis moves".

## Sources

- [All Elite Moves, Ricochet](https://allelitemoves.com/men/Ricochet) — the
  fullest list: finishers Spirit Gun and Vertigo; signatures Northern Lights
  Suplex + Deadlift Brainbuster and Running Shooting Star Press; and a full
  moveset that includes the 630 Senton, Poisonrana, Meteora, Liger Bomb,
  Blue Thunder Bomb, Death Valley Driver, Enzuigiri, Mushroom Stomp, Handspring
  Back Elbow and the kick combos.
- [Smackdown Hotel, Ricochet](https://www.thesmackdownhotel.com/wrestlers/ricochet)
  — the dated finisher history this doc follows: **Spirit Gun** (running
  sliding clothesline to a kneeling opponent, Oct 2024–present) and **Vertigo**
  (spinning Michinoku Driver II, Aug 2024–present) are current; **630° Senton**
  and **Recoil** (single-knee facebreaker) ran 2003–June 2024; **Shooting Star
  Press** 2018–2024; **Benadryller** (fireman's carry into a roundhouse) and
  **People's Moonsault** earlier still.
- [Puroresu System Wiki, Ricochet](https://puroresusystem.fandom.com/wiki/Ricochet)
  and [NJPW Wiki](https://njpw.fandom.com/wiki/Ricochet) — the indie/NJPW layer:
  Dragonrana, Cradle Shock / Vertigo II, Trigo Driver, King's Landing,
  Corkscrew 450° splash, standing shooting star (Heliocentricity), double
  rotation moonsault.
- [VS Battles, Ricochet (WWE)](https://vsbattles.fandom.com/wiki/Ricochet_(WWE))
  — the current AEW spot list: Poisonrana, Avalanche Hurricanrana, Sasuke
  Special, Spaceman Plancha, Meteora (including off the barricade and apron),
  Springboard 450, Springboard Shooting Star, Hidden Blade, Kickback, Tiger
  Feint Kick, Rolling Shotgun Dropkick.
- The FF move files themselves. IDs below are the `.tres` stems under
  `game/resources/moves/` (the `ff/` ones live in `ff/`); the Unreal table's
  row names are the same stems, and `AegisStory.cpp`'s `ff_`-prefixed entries
  are overrides on top of them, not a second set of moves.

## His current match, and what the game does

AEW-era core, Aug 2024–present. Tier is the grapple ladder `WrestlerController`
draws from; **[built]** means the clip and MoveDef both exist and are wired
today, **[closest]** means the move maps onto an existing clip whose action is
adjacent rather than identical, **[none]** means the library has no equivalent.

| Move | How he does it | Game tier | Mapping |
|---|---|---|---|
| **Spirit Gun** | Running, sliding clothesline to a *kneeling* opponent, with the theatrics before it | finisher | **[closest]** `running_leg_lariat` — the run and the slide are there; the kneeling-target check is not |
| **Vertigo** | Spinning Michinoku Driver II — inverted facelock, spun into a sit-out driver | finisher | **[closest]** `ff/sit_out_piledriver_6` — sit-out driver, no spin |
| 630° Senton | Double front somersault from the top | finisher (2003–2024) | **[built]** `ff/splash_630` (54 f startup, 40 f recovery, head 16) |
| Recoil | Single-knee facebreaker — the Codebreaker shape | finisher (2003–2024) | **[built]** `ff/code_breaker_1` (28 f startup), `ff/code_breaker_3` |
| Shooting Star Press | Top rope, sometimes to the floor | signature | **[built]** `ff/diving_shooting_star` |
| Springboard Shooting Star | Off the ropes into the same press | signature | **[built]** same clip; entry tier differs |
| Poisonrana | Standing, snap into the head | signature | **[built]** `ff/poison_rana_1` |
| Avalanche Poisonrana | From the top, opponent seated in the corner | signature | **[built]** `ff/avalanche_poison_rana` |
| 450° Splash | Springboard, sometimes second rope | signature | **[built]** `ff/splash_450_1`, `ff/magic_girl_450_splash` |
| Meteora | Diving double knee, also off the apron and barricade | signature | **[closest]** `ff/running_lariat_slingshot_meteora_combo` (the meteora in sequence); `ff/draping_diving_knee_drop` alone |
| People's Moonsault | Moonsault with the theatrics first | signature | **[closest]** `dive_moonsault` (single rotation, no theatrics) |
| Double rotation moonsault | Two flips, used rarely | signature | **[none]** — `dive_moonsault` is one rotation |
| Sasuke Special | Springboard corkscrew senton to the floor | dive | **[none]** — nearest dive is `dive_tope_suicida` |
| Dragonrana | Springboard somersault huracanrana | dive | **[closest]** `rebound_hurricanrana` |
| Hidden Blade | Swinging back elbow, Ospreay's | strike | **[built]** `ff/sling_blade_3` |
| Backflip kick / handspring kick | Trademark; the handspring version is a signature | strike | **[closest]** `strike_turning_back_kick_body`, `strike_turning_back_kick_knockdown` |
| Bicycle knee | Running, into a standing or doubled man | running | **[built]** `running_bicycle_knee` |
| Mushroom stomp | Leaping stomp on a downed man | running | **[built]** `running_leaping_mushroom_stomp` |
| Kick combo | Rising knee, roundhouse, axe kick | strike | **[built]** `ff/kick_combo` (60 f startup) |
| Northern Lights suplex | Bridging, often rolled into the deadlift brainbuster | grapple | **[built]** `ff/locomotion_northern_lights` |
| Deadlift brainbuster | Deadlifted out of the Northern Lights | grapple | **[built]** `ff/brainbuster_1` |
| Liger Bomb | High-angle powerbomb | power | **[built]** `running_float_over_liger_bomb` |
| Death Valley Driver | Over the shoulder, dropped | power | **[closest]** `ff/dead_eye`, `ff/cemetery_drive` (both 48 f, head 16) |
| Tornado DDT | Around the neck from the side | grapple | **[closest]** `running_tilt_a_whirl_ddt` |
| Fireman's carry (Benadryller) | Carried, dropped into a kick | power | **[closest]** `ff/fireman_carry_bomb_2`, `ff/fireman_carry_buster` |
| Oscutter / springboard cutter | Off the ropes into a cutter | signature | **[built]** `ff/slingshot_cutter`, `signature_cody_cutter` |
| Shotgun dropkick | Running, both boots | running | **[closest]** `running_single_leg_dropkick` |
| Blue Thunder Bomb | Spinning sit-out powerbomb | power | **[none]** — nearest `ff/pop_up_powerbomb_1` |
| Enzuigiri | Heel to the head from behind | strike | **[none]** — `strike_kick_heavy` is the nearest kick |
| Superman punch | Occasional, not a signature | signature-ish | **[built]** `signature_superman_punch` (Roman's file, reusable) |
| Springboard clothesline | Off the ropes | dive | **[none]** — only the grounded `running_attack_clothesline` |

## A moveset that only uses what is built

The tiers are the ones `Roster.Entry.moveset` reads. This is Godot-shaped; the
Unreal DataTable wants the same stems without the `res://` path and without the
`ff_` prefix on the animation pair.

```gdscript
# res://resources/moves/ is M; the FF library is M + "ff/".
{
	"strike": [M + "strike_jab.tres", M + "strike_hook.tres", M + "strike_cross.tres",
			M + "strike_kick_heavy.tres", M + "strike_turning_back_kick_body.tres",
			M + "ff/sling_blade_3.tres", M + "ff/kick_combo.tres"],
	"grapple": [M + "grapple_vertical_suplex.tres", M + "ff/locomotion_northern_lights.tres",
			M + "ff/brainbuster_1.tres", M + "running_tilt_a_whirl_ddt.tres"],
	"power": [M + "ff/pop_up_powerbomb_1.tres", M + "running_float_over_liger_bomb.tres",
			M + "ff/fireman_carry_bomb_2.tres", M + "ff/dead_eye.tres"],
	"signature": [M + "ff/poison_rana_1.tres", M + "ff/slingshot_cutter.tres",
			M + "ff/splash_450_1.tres", M + "ff/avalanche_poison_rana.tres"],
	"running": [M + "running_bicycle_knee.tres", M + "running_leaping_mushroom_stomp.tres",
			M + "running_single_leg_dropkick.tres", M + "running_leg_lariat.tres",
			M + "running_spinning_back_elbow.tres"],
	"dive": [M + "dive_tope_suicida.tres", M + "ff/splash_450_1.tres",
			M + "ff/avalanche_poison_rana.tres"],
	"top_rope": [M + "ff/diving_shooting_star.tres"],
	"corner": [M + "running_corner_knee.tres"],
	"corner_strike": [M + "strike_corner_clothesline.tres"],
	"rebound": [M + "rebound_hurricanrana.tres", M + "ff/slingshot_cutter.tres"],
	"possum": [M + "possum_sweep.tres"],
	"finisher": [M + "ff/splash_630.tres"],
	"finisher_run": [M + "running_leg_lariat.tres"],  # the Spirit Gun stand-in
}
```

Two notes on that block:

- `ff/kick_combo` has a 60-frame startup, the longest in the library, so it
  reads as a sequence rather than a strike. It is first in the strike pool, the
  tier's guaranteed move; drop it to the back if it makes his opening exchange
  feel slow.
- `ff/code_breaker_1` is deliberately **not** in the set even though it is the
  exact Recoil shape: Cody already draws it, and two men sharing a finisher
  makes the roster read as unfinished. It is the obvious first pick if Recoil
  is wanted back as a signature.

## The Unreal port has five tiers, not thirteen

`AegisStory::MovesetOf` builds an `FMoveset` with `Strike`, `Grapple`, `Power`,
`Signature`, `Finisher`, `TauntClip` and `TauntTicks` — nothing else. Its own
comment says the running, corner, rebound, dive and Spear-run tiers "wait for
those set-ups to be ported". So on the Unreal side his aerial game has to sit
in `Signature`/`Finisher` rather than in `dive`/`top_rope`.

The table is not a subset: `DT_AegisMoves` holds **228 rows** and `MoveDefs`
**227**, against this library's 89 base plus 139 FF moves. Every id this doc
names was confirmed present by dumping the DataTable's row names from the
editor (`/Game/AegisTest/Data/DT_AegisMoves`), not inferred from Godot.

The Unreal entry, then:

```cpp
// Splash 630 is his, and the Recoil shape is code_breaker_3 -- Cody already
// draws code_breaker_1, and two men sharing one move reads as unfinished.
FMoveset Ricochet;
Ricochet.Strike = { "strike_jab", "strike_hook", "strike_cross", "strike_kick_heavy",
    "strike_turning_back_kick_body", "strike_front_kick_body" };
Ricochet.Grapple = { "grapple_vertical_suplex", "locomotion_northern_lights",
    "brainbuster_1", "inverted_ddt_1" };
Ricochet.Power = { "tiger_driver_98", "running_float_over_liger_bomb",
    "pop_up_powerbomb_1", "fireman_carry_bomb_2" };
Ricochet.Signature = { "diving_shooting_star", "poison_rana_1",
    "avalanche_poison_rana", "code_breaker_3", "magic_girl_450_splash" };
Ricochet.Finisher = { "splash_630" };
Ricochet.TauntClip = "Point_Crowd";
Ricochet.TauntTicks = 90;
```

## Gaps worth authoring, in order of how much they are "him"

1. **Spirit Gun** — needs a kneeling-target check plus the pre-move theatrics.
   Until then the tier entry is a plain running lariat.
2. **Vertigo** — the 360 spin is the move; the sit-out driver alone reads as
   any Michinoku driver.
3. **Sasuke Special** — the springboard corkscrew senton is his most
   recognisable dive and the library has no corkscrew anything.
4. **Double rotation moonsault / Corkscrew 450** — same missing rotation
   support as the Sasuke.
5. **Blue Thunder Bomb, Enzuigiri, Shotgun dropkick, Springboard
   clothesline** — ordinary enough that a shared clip is fine short-term.

## Checks

- Every ID above resolves to a file that exists; the FF ones were read for
  their frame data (all 6 active frames; startup 28–60, recovery 34–40) and
  their damage split (head 10–18, torso 6–12).
- Looked for them in the Unreal port on 2026-11-27 and the look stopped at the
  tooling. The level that was open held 119 actors — `AegisCrowd`, four cine
  cameras, `BP_ThirdPersonCharacter_C` at (5594.8, 14754.5, 110), 87 static
  meshes — and no `SkeletalMeshActor`. The editor's command bridge answers
  `ping`, `get_actors_in_level`, `find_actors_by_name`, `get_actor_properties`,
  `set_actor_property`, `set_actor_transform`, `spawn_actor`, `delete_actor`
  and `take_screenshot`, and rejects every other name tried — asset search,
  bone read-out, montage playback, viewport camera, level load. Even
  `get_actor_properties` returns only name, class, location, rotation and
  scale, so it does not say which mesh is on the actor.
- Still open, then: whether these clips look right **on his mesh**. His rig is
  a 65-bone Mixamo skeleton retargeted onto the base rig, with a +16.7% arm
  reach mismatch recorded in the rig report, so the arm-led moves in this set
  (Sling Blade, Poisonrana, springboard cutter) are the ones to look at first
  in `tools/probe/paired_shot.tscn`. From outside the editor nothing can start
  a clip, step it, or bring a frame back — `take_screenshot` writes to the
  editor machine's own disk and the response carries only the path — so
  closing this needs either a capture taken at the editor, or four commands
  added to the plugin: a skeletal-mesh and bone read-out, `play_montage` with a
  start time, a pose query at a given frame, and a screenshot returned inside
  the response rather than written out.
- The 630 is a 54-frame startup clip with a 40-frame recovery — the longest
  aerial in the game. It should be the finisher, not a signature, or he will
  spend a fifth of a match in the air.
