class_name WrestlerController
extends CharacterBody3D
## Grey-box wrestler controller (Phase 2). Wires WrestlerFSM + CombatSystem +
## GrappleRig + MoveDef into a playable, deterministic loop: locomotion,
## strikes, tie-up -> grapple -> move -> down -> pin/submission -> getup,
## plus irish whip / running attack. Visuals are placeholder capsules —
## this exists purely to give the gauntlet loop something on-brief to
## improve (see ARCHITECTURE.md, "grey-box MVP").
##
## Runs entirely off ReplaySystem.get_input() so live play and replay
## playback exercise the same code path (determinism contract).

signal knocked_down(wrestler: WrestlerController)
signal pin_started(attacker: WrestlerController, defender: WrestlerController)
signal move_landed(attacker: WrestlerController, defender: WrestlerController, move: MoveDef)
## His comeback has started (MatchReferee decides when; see fire_up()).
signal fired_up(wrestler: WrestlerController)
## A strike parried and countered (Phase 4 reversals): `reverser` read it.
signal reversed(reverser: WrestlerController, striker: WrestlerController, move: MoveDef)

const MOVE_SPEED := 3.5
const RUN_SPEED := 7.0
const TIE_UP_RANGE := 1.4
## How close an opponent has to be for a strike or running attack to be worth
## STARTING, and the fallback contact test for moves that carry no authored
## contact volume (see MoveDef.contact_offset).
##
## This is no longer what decides whether a strike LANDS. It used to be: one
## 1.15m sphere between the two capsule origins, shared by every strike in the
## game, which could not tell a jab from a boot or forwards from backwards.
## _strike_reaches() replaced it with the move's own measured contact volume.
##
## The number itself was honest when it was written -- forward kinematics over
## `Punch_Jab` put the fist 0.76m ahead of the origin, plus the 0.4m capsule
## -- but that clip is gone, and the authored jab that replaced it reaches
## 0.655m. Kept at 1.15 because as a "close enough to throw at" gate it wants
## to be slightly generous: the strike still has to reach on its own.
const STRIKE_HIT_RANGE := 1.15
## Downward acceleration (m/s^2) applied whenever a wrestler is off the mat.
## The project sets no custom gravity, so this matches Godot's own 3D default
## rather than inventing a value -- ARCHITECTURE.md's "Reference-driven
## tuning" rule applies here as much as anywhere, and no reference footage
## covers fall speed.
const GRAVITY := 9.8
## Inside this distance a moving wrestler faces his opponent and strafes;
## outside it he faces where he is going.
##
## 2.5 m is WrestlerAI.run_engage_distance -- the distance at which the AI
## stops walking in and charges. That is already this project's definition of
## "close enough that this is a fight rather than a traversal", so the facing
## rule uses the same line rather than inventing a second one. Past it a
## wrestler is crossing the ring and should look where he is running; inside
## it he is working, and a worker keeps his eyes on the other man.
const FACE_OPPONENT_RANGE := 2.5
## Damage a wrestler must take *since his last knockdown* to be knocked off
## his feet again -- see _damage_at_last_knockdown, which is the half of this
## that makes a knockdown an event rather than a latch on a rising total.
##
## This was MAX_LIMB_DAMAGE * 2.0 (200), which made the pin path
## unreachable: MatchReferee routes a downed opponent to a submission once
## his worst limb passes SUBMISSION_LIMB_THRESHOLD (70) and to a pin
## otherwise, but every MoveDef loads torso damage heaviest, so torso is
## far past 70 long before the total reaches 200. Measured over twelve
## seeds before the change: zero pin attempts, every match a submission,
## with the whole pin/kickout system -- minigame, three-count, tests --
## reachable only by forcing it. Two of the five capture beats
## ARCHITECTURE.md requires are pin beats, so it also voided every capture.
##
## Set below the damage at which one limb crosses the submission threshold,
## so an early knockdown is a pin and a late one, after a limb has been
## worked over, is a submission. This is a *reachability* value, not a feel
## claim: gauntlet/refs/timings.md has nothing to measure it against, and
## it is chosen as the value that produces both finishes across the seeds
## rather than one that traces to reference footage.
const KNOCKDOWN_DAMAGE := 100.0

## How long a knocked-down wrestler stays prone before rising on his own.
## Not a getup *animation* duration -- that is GETUP_RISE_TICKS below, and
## gauntlet/refs/timings.md's getup entry compared its measured animation
## durations against this constant, which is the wrong quantity. The
## reference's own prone time was ~7.5s in the one instance it noted, but
## most of that was the attacker's taunt playing out rather than a fixed
## timer, so this stays a reachability value.
const GETUP_TICKS := 90 # 1.5s
## How long a man a slam left on the mat (MoveDef.leaves_defender_down) lies
## there before rising, when the slam did not also knock him down. Half a
## knockdown's GETUP_TICKS: long enough to read as having been dropped,
## short of reading as beaten. A presentation value; gauntlet/refs/ measures
## no slam.
const THROWN_DOWN_TICKS := 240 # 4s -- was 0.75s; see DOWN_TICKS_STRIKE
## How long a man stays down, by what put him there (match flow to 2K26,
## gauntlet/refs/match_engine_2k26.md section 3). Measured with
## tools/probe/flow_probe.tscn, ours was back up in 2.9 s (median) and a move
## landed every 1.1 s; 2K26's man stays down 5-27 s, longer after the bigger
## move, while the man in control works him. GETUP_TICKS stays the short
## "stirring" lie after a kickout (MatchReferee).
const DOWN_TICKS_STRIKE := 300   # 5 s: knocked down by strikes or a grapple
const DOWN_TICKS_POWER := 540    # 9 s: a power move or a signature
const DOWN_TICKS_FINISHER := 780 # 13 s: a finisher
## The slow rise in stages (Getup_Staged): roll over, get his wind on hands and
## knees, push up. 93 frames at 30 fps. The input-driven rise stays the quick
## one, GETUP_RISE_FAST_TICKS.
const GETUP_STAGED_TICKS := 186
## Hauled to his feet by the other man (ground_pickup / getup_hauled).
const PICKUP_TICKS := 72
## After a finisher is kicked out of, the man who threw it sells on the mat too
## (Getup_Staged, from PIN_ATTACKER), and the man under it stirs this long
## before his own staged rise.
const DOUBLE_DOWN_STIR_TICKS := 60
## The tier of whatever last knocked him down (CombatSystem.Tier, -1 for
## strikes): MatchReferee covers only after the bigger ones.
var knockdown_tier := -1


static func down_ticks_for(tier: int) -> int:
	if tier >= CombatSystem.Tier.FINISHER:
		return DOWN_TICKS_FINISHER
	if tier >= CombatSystem.Tier.POWER:
		return DOWN_TICKS_POWER
	return DOWN_TICKS_STRIKE

## The rise itself: mat to a standing fighting stance.
##
## Two numbers rather than one, because gauntlet/refs/timings.md measured
## two and says so: ~2.10s for the default rise (366.07s -> 368.20s) and
## ~1.14s when the wrestler triggers a quick recovery himself (330.43s ->
## 331.57s, with an "R1 INSTANT RECOVERY" prompt visible right at
## rise-start). That is not sample variance -- it is a two-speed mechanic,
## and the entry ends by saying any constant this project tunes later
## should probably be two numbers.
##
## Both were an unnamed literal `20` inside _process_down() -- 0.33s, about
## a sixth of the measured default rise, applied identically whether the
## wrestler was rising on his own or beating the count. So the project had
## the two-speed mechanic on the *prone* side (an input cuts DOWN short)
## and then threw the distinction away on the rise.
const GETUP_RISE_TICKS := 126 # 2.10s, the measured default rise
const GETUP_RISE_FAST_TICKS := 68 # 1.14s, the measured input-driven rise
## Damage the targeted limb must pass before a submission hold can get a
## tap-out; below it the defender works free. Sits inside the band
## MatchReferee.SUBMISSION_LIMB_THRESHOLD opens, so early holds are escapes
## and late ones finish. A reachability value, not a feel claim.
const SUBMISSION_ESCAPE_LIMB := 60.0
const HIT_REACT_TICKS := 20
## The sell after it (gauntlet/refs/match_aaa_plan.md): HIT_REACT is still 20
## ticks of being unable to act -- the frame data the strikes are balanced on
## -- but it no longer springs back to the stance at the end of them. Left
## alone, he plays on through the sell (strikes/sell_head, strikes/sell_gut),
## 40 ticks more, so a blow is sold for a second as it is in 2K26 and not a
## third of one. Anything he does -- a strike, a grapple, a step -- ends it at
## once (inertialized), so it never costs a player a tick. An AI man waits it
## out: his own reversal aside, he does not act until he has sold it.
const SELL_TICKS := 40
## The blow in a run that rocks him: hit while still selling the one before,
## and the one before that, he staggers (STUNNED) instead of flinching -- the
## 2K26 flurry, where the reactions build on each other.
const FLURRY_STUN_AT := 3

## How hard a landed strike shoves the man who took it, and for how long.
##
## Measured with tools/probe/contact_probe.tscn before this existed: across
## seeds 1-3, ZERO of 40 hit reactions moved the struck wrestler by so much as
## a centimetre. _process_timed_state() never touches velocity, so a punch
## landed, a flinch clip played, and the body stayed exactly where it stood --
## which is most of why strikes read as not connecting to anything.
##
## 2.2 m/s decaying by KNOCKBACK_DECAY each tick carries him about 0.13 m over
## the 8 ticks, a stagger rather than a shove: far enough to see, not far
## enough to break the spacing the next strike depends on. These are
## presentation values and are not claimed to match measured footage --
## gauntlet/refs/timings.md has no knockback distance in it.
const KNOCKBACK_SPEED := 2.2
const KNOCKBACK_TICKS := 8
const KNOCKBACK_DECAY := 0.75
const STUNNED_TICKS := 45
## Irish whip tuning. First-pass values, same caveat as every other tuning
## constant in this project: gauntlet/refs/timings.md marks both reversal-
## window length and ring-crossing run speed "pending" (no reference
## footage found), so these aren't cited, just chosen to land somewhere
## contested rather than degenerate. Confirm/retune via a live probe and
## later reference capture, not by feel.
const IRISH_WHIP_LAUNCH_SPEED := 9.0
const IRISH_WHIP_REBOUND_DAMPING := 0.85
const IRISH_WHIP_RETURN_TICKS := 45 # ~0.75s of autopilot return run
## Hard cap on the outbound flight before a rope is hit.
##
## _process_irish_whip() leaves IRISH_WHIP on one thing only: a collision
## with a RING_ROPE_GROUP body. A whip that never reaches a rope -- launched
## along the diagonal, into a corner post, or at an opponent who was already
## against the ropes -- has no other exit, and IRISH_WHIP is not a state
## anything else can pull a wrestler out of. That is a hung match, not a
## missed move.
##
## Sized off the geometry rather than picked: the ring is 6m across
## (gauntlet/refs/ring.md), IRISH_WHIP_LAUNCH_SPEED covers it in well under
## a second, so 120 ticks (2.0s) is far longer than any real crossing and
## still bounded. Exits to RUN, the same state a real rebound hands off to,
## so the wrestler simply finishes on his feet.
const IRISH_WHIP_MAX_TICKS := 120
## Hard cap on a grapple hold that produces no move -- see
## _process_grapple_hold()'s weight-class early return. A real hold resolves
## the same tick the attacker picks a move, so any hold that survives this
## long has nothing to throw; 120 ticks (2.0s) is well past the ~62 ticks a
## rig-driven paired move actually occupies (measured by the reachability
## probe), so it can never cut a legitimate move short.
const GRAPPLE_HOLD_MAX_TICKS := 120
## Group name (see scenes/ring.tscn) the rope StaticBody3D colliders are in
## — lets _process_irish_whip() recognize a rope hit without depending on
## specific node names.
const RING_ROPE_GROUP := "ring_ropes"
## States WrestlerFSM.LEGAL_TRANSITIONS actually allows a TIE_UP transition
## from — both sides of a grapple attempt must be in one of these, or the
## attempt is silently dropped (see the gate in _process_free_movement()).
## Public (not underscore-prefixed) so MatchReferee can gate its own
## tie-up-entry decision with the same legality check — see
## _wants_tie_up_this_tick's doc comment for why entry moved there.
const CAN_ENTER_TIE_UP: Array[WrestlerFSM.State] = [
	WrestlerFSM.State.IDLE,
	WrestlerFSM.State.LOCOMOTION,
]

@export var player_index: int = 0
@export var is_ai: bool = false
@export var strike_move: MoveDef
@export var grapple_move: MoveDef
@export var power_move: MoveDef
@export var signature_move: MoveDef
@export var finisher_move: MoveDef
## This wrestler's own signature (Roster.Entry.signature), also in
## signature_move_pool. The FIRST signature he throws in a match is this one,
## and only later ones come from the seeded draw: a one-in-three draw over the
## one or two signatures a match holds meant Roman went twelve AI matches
## without ever throwing the Superman Punch. It is the move he is known for,
## and the one he sets the Spear up with, so it comes first.
@export var own_signature: MoveDef
var _own_signature_thrown: bool = false
@export var running_attack_move: MoveDef
## Extra moves at each grapple tier, picked between by a seeded draw at the
## moment the attacker commits (see _pick_tier_move()). The single slot
## above stays the tier's guaranteed entry -- an empty pool means that one
## move every time, which is exactly the behaviour before pools existed.
## Extra strikes drawn between alongside strike_move, so a wrestler throws
## more than one punch for a whole match. Same seeded draw as the grapple
## tiers.
@export var strike_move_pool: Array[MoveDef] = []
@export var grapple_move_pool: Array[MoveDef] = []
@export var power_move_pool: Array[MoveDef] = []
@export var signature_move_pool: Array[MoveDef] = []
@export var finisher_move_pool: Array[MoveDef] = []
## Extra running attacks alongside running_attack_move (double-leg
## takedown). Same seeded draw as the tiers, so replays still match.
@export var running_attack_move_pool: Array[MoveDef] = []
## Thrown only at a man trapped in a corner (Roman's corner Spear). Not part
## of any draw: try_corner_spear() is the one way in.
@export var corner_move: MoveDef
## His strike at a man trapped in the corner, in place of his ordinary draw
## (Roman's corner clotheslines, gauntlet/refs/moveset_audit_2k26.md).
@export var corner_strike_move: MoveDef
## His own submission hold, if he has one (Cody's Figure-Four; Roster's
## "submission" tier). MatchReferee has him take it once a match on a man he
## has knocked down mid-match -- see _check_for_downed_opponent_action().
@export var submission_move: MoveDef
## Whether submission_move has been taken this match. Once is the rule.
var _submission_move_used := false
## His dives (Cody's tope suicida and springboard Disaster Kick; Roster's
## "dive" tier): with any here, MatchReferee plays DiveSpot once a match.
@export var dive_moves: Array[MoveDef] = []
## His dive off the top rope onto a man down mid-ring (TopRopeSpot), or null.
@export var top_rope_move: MoveDef
var _top_rope_used := false
## His sweep from the mat at a man standing over him (PossumSpot), or null.
@export var possum_move: MoveDef
var _possum_used := false
## Whether the dives have been taken this match.
var _dive_used := false
## Tier of the last grapple-chain move this wrestler landed, or -1. The
## referee reads it so a man put down by a finisher is pinned,
## never put in a hold.
var last_landed_tier := -1
@export var weight_class: int = 1
## Set by MatchSetup so _pick_tier_move()'s draw is seeded per match rather
## than by the global RNG. Same reasoning as WrestlerAI.setup_jitter().
var match_seed: int = 0
## Incremented on every tier draw so two grapples in one match don't have to
## resolve to the same move. Part of the RNG's seed, never of gameplay state.
var _tier_draws: int = 0
## Attire colourway. Two identical wrestlers were the largest measured gap
## in VISUAL_BAR.md's first priority ("silhouette readability at
## match-camera distance"): both wrestlers instanced the same .glb with the
## same CC0 placeholder materials, so at match-camera distance the frame
## held two interchangeable orange figures and a paired move read as one
## blob.
##
## Measured, not chosen -- see gauntlet/refs/VISUAL_BAR.md's "Silhouette
## separation" section and tools/refs/measure_frame.py. On the reference
## still the two wrestlers sit 0.24-0.31 in relative luminance *below* the
## mat, and only 0.07 apart from each other: the mat separates them by
## value, and they separate from each other by hue. These colourways
## reproduce that relationship rather than an idea of what looks good.
##
## Applied as surface overrides so the shared .glb is never mutated -- both
## wrestlers load the same Mesh resource, and writing to its own surface
## materials would colour both of them (the same shared-resource trap that
## made strike_move's "applied" flag leak between wrestlers).
@export var attire_body: Color = Color(0.13, 0.24, 0.55)
@export var attire_accent: Color = Color(0.30, 0.58, 0.95)
## Skin, which is now most of what a wrestler renders as -- the colourway
## lives on the gear WrestlerAttire builds, not on the whole body.
##
## Both wrestlers are deliberately close in value here and differ mainly in
## warmth. VISUAL_BAR.md measures the reference's two men within 0.07 of each
## other in luminance, separating by hue rather than brightness; skin is what
## carries that, so a large value gap between the two complexions would break
## the very relationship the gear colours are there to satisfy.
@export var skin_tone: Color = Color(0.60, 0.45, 0.35)
## Widens the gear without lengthening the man. One CC0 mannequin at two
## tints read as the same body twice; this is what makes the two silhouettes
## differ in build. Not a reference measurement -- gauntlet/refs/ measures
## nothing about physique -- so it is an engineering value.
@export var physique_bulk: float = 1.0
## Which head/gear identity this wrestler wears (see WrestlerAttire.head_pieces).
## 0 = hair + headband, 1 = mask + eye band, 2 = buzz cut + denim-shorts
## brawler outfit. The two men in match.tscn use different variants so a
## paired move reads as two bodies, not one blob.
@export var body_variant: int = 0
## Uniform visual scale on the inner Skeleton3D only. The CharacterBody3D and
## its capsule collider are untouched, and CharacterModel keeps its yawed,
## unscaled transform (guarded by test_wrestler_model_orientation), so this
## never reaches gameplay state, replay hashes, or the referee's distance
## checks -- it is cosmetic, like the gear. Lets two men built from one
## mannequin differ in height as well as width.
@export var physique_height: float = 1.0
## Widens the rendered body mesh (X/Z) without touching the skeleton, the
## gear, or the capsule. The mannequin's torso is narrow; the reference
## brawler is a heavyweight, and gear-radius bulk alone leaves his bare
## chest narrow. Applied to the Mannequin MeshInstance3D only, so bones,
## attachments, IK, and shared resources are unaffected -- cosmetic.
@export var torso_width: float = 1.0
## What the HUD calls this wrestler. Empty means the node name, which is
## "WrestlerA"/"WrestlerB" -- fine for a fixture scene, useless on a plate a
## player reads. TitleScreen fills it from the roster entry he picked.
@export var display_name: String = ""
## The small line over his name on the entrance lower third: his title, or his
## nickname if he holds none (Roster.Entry.entrance_subtitle()).
@export var entrance_subtitle: String = ""
## Whose ring entrance he performs (EntranceDirector): a roster id with its
## own routine ("roman"), or "" for the generic walk to the ring.
@export var entrance_style: String = ""
@export var character_model_scene: PackedScene = preload(
		"res://assets/characters/wrestler_base.glb")
@export var opponent_path: NodePath
@export var grapple_rig_path: NodePath

var ai: WrestlerAI
var opponent: WrestlerController
var fsm: WrestlerFSM
var combat: CombatSystem
var grapple_rig: GrappleRig
## Retargeted CC0 base mesh's own AnimationPlayer (see
## assets/characters/CREDITS.md).
var anim_player: AnimationPlayer
## Drives anim_player through an AnimationNodeStateMachine built in
## _build_animation_tree() — one state-machine node per WrestlerFSM state,
## wired with a transition for every LEGAL_TRANSITIONS edge, cross-fading
## over ANIMATION_BLEND_TICKS. This is the real ARCHITECTURE.md blend graph
## (not a direct AnimationPlayer.play() switch): _on_fsm_state_changed()
## calls playback.travel() so xfades and state ordering are the engine's
## job, not hand-rolled here.
var anim_tree: AnimationTree
var _anim_playback: AnimationNodeStateMachinePlayback
## The retargeted mesh's Skeleton3D. Public so the *opponent* can read this
## wrestler's chest/hip bones when aiming its grip IK — a grapple needs to
## know where the other torso actually is, which the root position doesn't
## say (mid-throw the body can be upside down a metre off its own origin).
var skeleton: Skeleton3D
## One SkeletonIK3D per arm (index 0 = left, 1 = right) pulling the hands onto
## the opponent while gripping. See _build_ik_rig().
var _arm_ik: Array[SkeletonIK3D] = []
var _grip_targets: Array[Marker3D] = []
## Planted feet for GrappleRig's walk-in (FootPlant). Presentation only.
var foot_plant: FootPlant
var inertializer: Inertializer
var hit_flinch: HitFlinch
var body_life: BodyLife
var foot_lock: FootLock
var rope_reach: RopeReach
var sell_clutch: SellClutch
## Shared 0..1 blend applied to both arms' SkeletonIK3D.interpolation.
var _grip_blend: float = 0.0
## The grip targets and blend as they stood on the last two ticks, in the
## IK's own space, so the hands are drawn between ticks with the rest of him
## (draw_grip_between_ticks). A target placed in the world once a tick sat
## still against his interpolated body until the next one: the hands of a
## lock-up stepped at 60 Hz while everything else moved every frame.
var _grip_prev_local: Array[Vector3] = []
var _grip_cur_local: Array[Vector3] = []
var _grip_blend_prev: float = 0.0
## Span from shoulder to hand in the rest pose, measured in _build_ik_rig().
var _arm_reach: float = 0.0
## State -> clip, queued by whoever is about to enter that state and
## consumed by _take_clip_override(). See its doc comment.
var _state_clip_override: Dictionary = {}
## The sell that follows the hit reaction now playing, and how long is left of
## the one being played in IDLE (SELL_TICKS).
var _sell_clip := ""
var sell_ticks := 0
## Blows taken back to back, each landing before he had finished selling the
## last; the third rocks him (FLURRY_STUN_AT).
var _flurry_hits := 0

## FSM state -> clip from the base mesh's library. Every state gets *some*
## plausible clip from the single-character library on hand — no paired
## grapple animation exists yet (see README's Phase 3 notes), so
## grapple-adjacent states borrow the closest single-character clip as a
## placeholder rather than left in bind pose:
## TIE_UP/GRAPPLE_HOLD -> Interact, MOVE_EXEC -> Punch_Cross,
## PIN_ATTACKER -> Crouch_Idle, PIN_DEFENDER/DOWN -> Death01,
## SUBMISSION_ATTACKER -> Crouch_Idle, SUBMISSION_DEFENDER -> Death01,
## FINISHER -> Sword_Attack, GETUP -> Roll (imperfect — the only
## on-the-ground-to-standing clip in this library).
const STATE_ANIMATIONS := {
	# Authored. The rig's Idle is a relaxed civilian stand with the arms
	# down; a wrestler at rest is coiled and never quite still.
	WrestlerFSM.State.IDLE: "strikes/idle_ready",
	# Authored: circling an opponent, not strolling. Hands stay up.
	WrestlerFSM.State.LOCOMOTION: "strikes/walk_stalk",
	# Authored. Sprint is a jog with the torso upright and the arms barely
	# moving -- no drive in it, which is what a rope run is made of.
	WrestlerFSM.State.RUN: "strikes/run_drive",
	# Generated (see resources/animations/strike_recipes.gd), not the rig's
	# raw Punch_Jab: the raw clip is 0.87s against a 20-tick move, so 38% of
	# it played and the arm cross-faded back to idle still travelling
	# forward. The generated one is cut to the move's own length.
	WrestlerFSM.State.STRIKE: "strikes/strike_jab",
	# "Push" (Push_Loop on the rig -- the importer strips the _Loop suffix) is
	# a two-armed forward shove, which reads as a collar-and-elbow lock-up.
	# This was "Interact", a one-armed reach-and-point: with both wrestlers
	# playing it, a tie-up rendered as two men standing apart pointing past
	# each other, which is the single most-complained-about thing in a
	# captured match.
	WrestlerFSM.State.TIE_UP: "strikes/tie_up_collar",
	WrestlerFSM.State.GRAPPLE_HOLD: "strikes/grapple_hold_neutral",
	# MOVE_EXEC is the beat where a grapple's throw resolves, not a strike.
	# It played Punch_Cross, so a wrestler who had just completed a throw
	# threw a punch at nothing on the way back to idle.
	# Authored. Jump_Land is a man absorbing a drop he took himself.
	WrestlerFSM.State.MOVE_EXEC: "strikes/move_exec_impact",
	# Replaced per hit by _play_hit_reaction() with a head or torso reaction
	# depending on where the damage landed; this is the fallback.
	WrestlerFSM.State.HIT_REACT: "strikes/hit_torso",
	# Authored. Death01 is a man dying -- collapsed and still, arms splayed.
	WrestlerFSM.State.DOWN: "strikes/down_supine",
	# Generated: "Roll" is a tucked forward roll and 0.63s shorter than the
	# state, so the wrestler curled into a ball on the mat and froze in it.
	WrestlerFSM.State.GETUP: "strikes/getup_rise",
	WrestlerFSM.State.IRISH_WHIP: "strikes/irish_whip_throw",
	# Authored clothesline, cut to the 69 frames both running_attack_*.tres
	# share. This was Punch_Cross: a wrestler sprinted the width of the ring
	# and threw a boxing jab, and because neither running-attack MoveDef sets
	# animation_pair_id, BOTH of them did it.
	WrestlerFSM.State.RUNNING_ATTACK: "strikes/running_clothesline",
	# Retimed to STUNNED_TICKS. The raw Hit_Head is 0.43s against a 45-tick
	# (0.75s) state, so the clip ended and the pose froze for 19 ticks.
	WrestlerFSM.State.STUNNED: "strikes/stunned",
	# Generated (see resources/animations/strike_recipes.gd), not Crouch_Idle:
	# that is a man crouching on his own, so the three-count played with the
	# attacker standing beside the fallen man rather than covering him.
	WrestlerFSM.State.PIN_ATTACKER: "strikes/pin_cover",
	WrestlerFSM.State.PIN_DEFENDER: "strikes/down_supine",
	# Authored. Crouch_Idle is a man crouching by himself, not working a hold.
	WrestlerFSM.State.SUBMISSION_ATTACKER: "strikes/submission_work",
	WrestlerFSM.State.SUBMISSION_DEFENDER: "strikes/down_supine",
	# Authored. This was Sword_Attack: a two-handed overhead sword swing, on
	# the biggest moment in a match.
	WrestlerFSM.State.FINISHER: "strikes/finisher_drive",
	# Authored in Blender (tools/blender/wrestling_clips.py) and baked
	# through strike_recipes.gd like the rest. Nothing in the CC0 library
	# celebrates, so unlike every other entry here this one could not have
	# borrowed a clip.
	WrestlerFSM.State.VICTORY: "strikes/win_celebrate",
	# Replaced per man by begin_taunt() with his own gesture (TAUNTS); this is
	# the one a man with none of his own throws.
	WrestlerFSM.State.TAUNT: "strikes/air_punch",
}
## Per-role overrides on top of STATE_ANIMATIONS, looked up first when the
## wrestler is in a grapple and its role is known.
##
## A paired grapple clip animates only the two root transforms -- the throw
## trajectory -- and both wrestlers sit in GRAPPLE_HOLD for its whole
## duration (MOVE_EXEC never fires for a rig-driven move; confirmed live).
## With one clip for both roles, that meant the attacker played the same
## idle-ish gesture as the man he was supposedly throwing: an instrumented
## capture showed the "attacker" standing with an arm out while the
## defender's rigid body arced past him, which reads as nobody grappling
## anybody. Splitting by role gives the attacker a lifting motion and the
## defender a limp one, so the throw at least reads as a throw.
##
## Still borrowed single-character animation, not two rigs actually gripping
## each other -- that needs paired bone tracks (see grapple_rig.gd's header
## for why those aren't simply added to the existing clips).
const ATTACKER_STATE_ANIMATIONS := {
	WrestlerFSM.State.GRAPPLE_HOLD: "strikes/grapple_hold_attacker",
}
const DEFENDER_STATE_ANIMATIONS := {
	WrestlerFSM.State.GRAPPLE_HOLD: "strikes/grapple_hold_defender",
}

## Real bone-level performances for the moves that have one, generated from
## resources/animations/paired_recipes.gd by tools/anim/build_paired_poses.gd.
## These supersede the borrowed clips above, which remain the fallback for a
## move with no recipe.
##
## Delivered through *this* wrestler's own AnimationTree rather than added to
## the paired clip on GrappleRig's AnimationPlayer, because two
## AnimationMixers must never write the same Skeleton3D. So the paired clip
## keeps doing only what it always did -- the two CharacterBody3D root
## transforms, the throw's trajectory -- and the bodies inside them are posed
## here. The two halves are started on the same physics tick and are
## generated to the same length; that is the whole of the synchronisation.
const PairedRecipes := preload("res://resources/animations/paired_recipes.gd")
const PAIRED_POSES := preload("res://resources/animations/paired_poses.tres")
## Strike and hit-reaction clips, cut and stitched from the rig's own by
## tools/anim/build_strike_clips.gd so each one is exactly as long as the
## state that plays it.
const StrikeRecipes := preload("res://resources/animations/strike_recipes.gd")
const STRIKE_CLIPS := preload("res://resources/animations/strike_clips.tres")
## Ticks (at 60Hz) to cross-fade between clips.
const ANIMATION_BLEND_TICKS := 6
## How long the Inertializer carries the old pose into a new clip, by the state
## the clip belongs to. Longer than the crossfade it replaces, because it does
## not mush: from the first tick he moves the way the new clip moves, and only
## the difference fades. A hit lands fast -- a reaction that eased in would
## read as him deciding to react -- and lying down or getting up has the most
## body to move.
const INERTIA_DEFAULT_TICKS := 9
const INERTIA_TICKS := {
	"HIT_REACT": 5, "STUNNED": 6, "STRIKE": 6,
	"DOWN": 12, "GETUP": 12, "WALK_IN": 9, "GRAPPLE_HOLD": 8,
}

var _move_ticks_remaining: int = 0
var _active_move: MoveDef
var _is_grapple_attacker: bool = false
var _pin_minigame: PinMinigame
var _submission_minigame: SubmissionMinigame

## Hits queued against this wrestler this tick, resolved by MatchReferee
## after every wrestler has run its own _physics_process. Godot processes
## scene-tree children in a fixed order every tick (WrestlerA before
## WrestlerB), so applying a hit synchronously — mid opponent's own strike
## resolution — let whichever wrestler updates first always land first and
## silently overwrite the other's in-flight attack. Queuing defers the
## effect to end-of-tick so both wrestlers' decisions this tick are made
## from the same starting state, regardless of node order.
var _pending_hits: Array[MoveDef] = []

## A hit taken while this wrestler was mid-strike, held until the strike ends.
##
## See the deferral in _flush_pending_hits(): the damage is applied
## immediately, only the HIT_REACT transition is deferred, so nothing about who
## wins the exchange changes -- what changes is that the punch already in
## flight is allowed to land instead of being cancelled by the one that beat it.
var _pending_hit_reaction: MoveDef = null
## Ticks of shove left on a landed hit. Counted down in _process_timed_state(),
## which is the only place HIT_REACT advances.
var _knockback_ticks: int = 0

## Whether the current _active_move has already landed its hit this
## attempt. This must live here, not on the MoveDef resource (previously
## tracked via _active_move.set_meta("applied", ...)) — a MoveDef loaded
## from a .tres is one shared Resource instance referenced by both
## wrestlers (e.g. both assigned the same strike_jab.tres), so metadata
## set on it was a single flag fought over by both attackers: whichever
## wrestler's strike landed first marked it "applied" and permanently
## blocked the other wrestler's independent attack from ever landing.
var _active_move_hit_applied: bool = false
var _kickout_input_this_tick: bool = false
var _submission_defender_input_this_tick: bool = false
var _tie_up_input_this_tick: bool = false
## Set by _process_free_movement() whenever this wrestler pressed grapple
## this tick; consumed by MatchReferee (which runs after every wrestler's
## own _physics_process, see _resolve_pending_hits()'s doc comment for why
## that ordering matters) to decide whether to start a tie-up. Entry used to
## happen inline here via a direct opponent.fsm.transition_to(TIE_UP) call —
## but since only one wrestler's _process_free_movement() actually executes
## that branch each tick (whichever comes first in the scene tree), the
## *other* wrestler's FSM state changed mid-tick, before its own
## _physics_process() ran — so its WrestlerAI.poll_input() saw TIE_UP
## already in effect and started counting tie-up mash ticks one tick early,
## every single time, regardless of either wrestler's actual behavior. In an
## AI-vs-AI match with identical, jitter-free mash timing (no RNG in that
## policy by design) that one-tick head start silently decided every single
## tie-up — confirmed live: TieUpMinigame progress at resolution was always
## exactly (9.0, 10.0), the "loser" one tick behind, never closer. Deferring
## the actual transition to MatchReferee (which runs strictly after both
## wrestlers this tick) makes entry happen on a fresh tick for both sides
## uniformly, the same fix shape already used for pin/submission entry.
var _wants_tie_up_this_tick: bool = false

## Set true once this wrestler's IRISH_WHIP flight has hit a rope this whip
## (see _process_irish_whip()) -- guards against reflecting velocity again
## on a later tick's residual collision report, and is reset to false at
## the start of every fresh _begin_irish_whip() call.
var _irish_whip_rebounded: bool = false
## Ticks remaining in the post-rebound "run back toward the original
## attacker" autopilot phase (see _process_irish_whip_return()). While
## positive, RUN is physics-driven (the rebound), not player/AI-steered --
## handing control back immediately would let normal _process_free_movement()
## overwrite the bounce's velocity with whatever the move input says
## (usually zero) the very next tick, killing the rebound instantly.
var _irish_whip_return_ticks_remaining: int = 0
## Who to auto-steer back toward during the whip-return phase -- the
## original attacker, set by _begin_irish_whip().
var _irish_whip_target: WrestlerController

## Whether MatchReferee._check_for_cover() may start a new pin on this
## wrestler right now. True by default and after a genuine knockdown (an
## attacker walking over to cover a freshly-downed opponent is intended to
## work immediately) — but a kickout resets straight back to DOWN with the
## same attacker already standing in cover range, so without this gate
## _check_for_cover() re-matches the very next tick, before GETUP_TICKS or
## the GETUP state ever run, and the wrestler is re-covered forever without
## a real chance to recover or take a fresh hit. Cleared by
## MatchReferee._end_pin() on a kickout, restored once this wrestler
## actually reaches IDLE again (see _process_timed_state()).
var _cover_eligible: bool = true

## Start the next state's clip outright instead of cross-fading into it --
## see _turn_round_on_the_mat().
var _snap_next_animation: bool = false

## Total damage this wrestler had taken the last time he was knocked down.
##
## Knockdown used to be `total_damage() >= KNOCKDOWN_DAMAGE`, which is a
## test on a number that only ever rises: the first time a wrestler crossed
## 100 it became true and it stayed true for the rest of the match, so every
## subsequent hit -- a 4-damage jab included -- put him back on the mat.
##
## Measured across five AI-vs-AI seeds: both wrestlers entered GRAPPLE_HOLD
## exactly three times, in every single seed, and the whole late match was
## strike -> knockdown -> cover -> kickout -> getup -> strike. That is the
## reason the grapple chain this slice is about barely ran: a match played
## two or three of the eighteen authored paired moves and then stopped
## producing tie-ups at all, because the AI's "opponent is down, walk in"
## branch owns every tick a wrestler spends on the mat.
##
## A knockdown is an event, so it is measured from the last one: a wrestler
## goes down again once he has taken another KNOCKDOWN_DAMAGE *since*.
var _damage_at_last_knockdown: float = 0.0
## The match's pacing (MatchFlow), if this match has one; the AI reads its tempo.
var flow: MatchFlow = null

func _ready() -> void:
	# Drawn between physics ticks, so his walk and root motion do not step
	# at 60 Hz on a faster (or uneven) display -- see MatchSmoothing.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	# RingRopes finds the bodies it has to give under by this group.
	add_to_group("wrestlers")
	_install_character_model()
	fsm = WrestlerFSM.new()
	add_child(fsm)
	combat = CombatSystem.new()
	ai = get_node_or_null("AI")
	if ai:
		ai.controller = self

	anim_player = find_child("AnimationPlayer", true, false) as AnimationPlayer
	fsm.state_changed.connect(_on_fsm_state_changed)
	if anim_player:
		# Registered under its own library name so the generated clips can
		# never collide with the .glb's own 43, and so a missing generated
		# clip reads as "paired/x is absent" rather than shadowing something.
		if not anim_player.has_animation_library(PairedRecipes.LIBRARY):
			anim_player.add_animation_library(PairedRecipes.LIBRARY,
					_adapt_animation_library(PAIRED_POSES))
		if not anim_player.has_animation_library(StrikeRecipes.LIBRARY):
			anim_player.add_animation_library(StrikeRecipes.LIBRARY,
					_adapt_animation_library(STRIKE_CLIPS))
		_build_animation_tree()
	skeleton = _find_model_skeleton()
	if skeleton:
		# Height lives on the visual skeleton so the yawed CharacterModel node
		# above it stays exactly as test_wrestler_model_orientation pins it.
		#
		# Applied through the model when it offers apply_physique_height,
		# because a model may be rigged on MORE THAN ONE skeleton and scaling
		# only the one _find_model_skeleton() returns then resizes part of the
		# character inside the rest of it. The Roman model is: body and head on
		# a 114-bone skeleton, hair and beard on a 471-bone one. Scaling only
		# the first inflated WrestlerB's head 5% inside hair that stayed at
		# 1.0, which pushed his scalp through the crown -- he rendered bald
		# while WrestlerA, scaled DOWN to 0.98, kept his hair. Same model, two
		# heights, and it read as two different men.
		var model := anim_player.get_parent() if anim_player else null
		if model and model.has_method("apply_physique_height"):
			model.apply_physique_height(physique_height)
		else:
			skeleton.scale = Vector3.ONE * physique_height
		_build_ik_rig()
		_build_foot_plant()
		_build_inertializer()
		_build_body_life()
		_build_hit_flinch()
		_build_sell_clutch()
		_build_foot_lock()
		_build_rope_reach()
		# Sweat over the match, on the skin materials the model registered.
		if model:
			Sweat.attach(self, model)
		# His eyes on the other man, where the model has eyes that move
		# (RomanModel; EyeAim). Presentation only.
		if model and model.has_method("aim_eyes"):
			model.aim_eyes(_opponent_eye_line)
		_build_worn_follow()
		if _uses_universal_attire():
			WrestlerAttire.build(skeleton, attire_body, attire_accent,
					physique_bulk, body_variant)
	_apply_colorway()

func _adapt_animation_library(source: AnimationLibrary) -> AnimationLibrary:
	var model := anim_player.get_parent()
	if model and model.has_method("adapt_animation_library"):
		return model.adapt_animation_library(source)
	return source

func _uses_universal_attire() -> bool:
	var model := anim_player.get_parent()
	return not model or not model.has_method("uses_universal_attire") \
			or model.uses_universal_attire()

func _skeleton_bone_name(game_bone: String) -> String:
	var model := anim_player.get_parent()
	if model and model.has_method("game_bone_name"):
		return model.game_bone_name(game_bone)
	return game_bone

func _find_model_skeleton() -> Skeleton3D:
	var model := anim_player.get_parent()
	if model and model.has_method("get_game_skeleton"):
		return model.get_game_skeleton()
	return find_child("Skeleton3D", true, false) as Skeleton3D

func _install_character_model() -> void:
	var existing := get_node_or_null("CharacterModel")
	if existing:
		existing.free()
	var model: Node3D = character_model_scene.instantiate() as Node3D
	if not model:
		push_error("Character model scene did not instantiate as Node3D")
		return
	model.name = "CharacterModel"
	model.transform = Transform3D(Basis.from_euler(Vector3(0.0, PI, 0.0)),
			Vector3.ZERO)
	add_child(model)

## Surface 0 of the CC0 base mesh is the body ("M_Main"), surface 1 the
## joint bands ("M_Joints") -- confirmed off the .glb, not assumed.
##
## Both surfaces now take *skin*, not the colourway. The colourway moved onto
## the gear WrestlerAttire builds, because a wrestler whose whole body is one
## saturated colour cannot sit where VISUAL_BAR.md measures the reference's:
## 0.24-0.31 below the mat in value while staying within 0.07 of the other
## man. Skin is the mid value that makes both of those true at once. See
## wrestler_attire.gd's header for the measurement that forced this.
##
## The joint bands take a slightly darker skin rather than the accent: they
## are elbows, knees and shoulders, and colouring them was only ever standing
## in for gear that did not exist yet.
func _apply_colorway() -> void:
	# Width is a node scale, not a material: it is headless-safe (no RID
	# involved) and applies in tests too, so the physique is asserted, not
	# just rendered. The mesh resource itself is never touched -- both
	# wrestlers share it.
	var mesh_instance := find_child("Mannequin", true, false) as MeshInstance3D
	if mesh_instance and mesh_instance.mesh:
		mesh_instance.scale = Vector3(torso_width, 1.0, torso_width)
	# Nothing renders under the headless display server CI runs tests on,
	# and assigning a material there logs `Parameter "material" is null`
	# once per surface: the dummy renderer never compiles the shader, so the
	# material has no RID for it to query instance uniforms from. Skipping
	# costs nothing headless (there is no image) and never fires during a
	# capture, which runs under xvfb with the opengl3 driver rather than
	# --headless. The colourways themselves are asserted in
	# tests/test_wrestler_colorway.gd, which does not need a renderer.
	if DisplayServer.get_name() == "headless":
		return
	if not mesh_instance or not mesh_instance.mesh:
		return
	var colors := [skin_tone, skin_tone.darkened(0.18)]
	for surface in mini(mesh_instance.mesh.get_surface_count(), colors.size()):
		# Duplicated from the mesh's own material rather than built from a
		# bare StandardMaterial3D.new(): a fresh material has no valid RID
		# under the dummy (headless) renderer CI runs tests on, and every
		# instance of one logged `Parameter "material" is null` on load.
		# Duplicating keeps the .glb's material untouched -- both wrestlers
		# share that resource, so writing to it would colour both.
		var source := mesh_instance.mesh.surface_get_material(surface)
		if source == null:
			continue
		var material: StandardMaterial3D = source.duplicate()
		material.albedo_color = colors[surface]
		# Ring lighting is the arena's job, not the attire's: a low
		# specular keeps the four spot rigs from blowing the body back out
		# to the near-white value this is here to fix.
		material.roughness = 0.72
		material.metallic = 0.0
		mesh_instance.set_surface_override_material(surface, material)

## Builds the AnimationNodeStateMachine blend graph: one AnimationNodeAnimation
## per WrestlerFSM state that has a usable clip (STATE_ANIMATIONS), and one
## AnimationNodeStateMachineTransition per WrestlerFSM.LEGAL_TRANSITIONS edge
## between two such states, cross-fading over ANIMATION_BLEND_TICKS. Runtime-
## built rather than authored as a .tscn sub-resource graph so it always
## matches WrestlerFSM's state/transition tables instead of drifting from
## them by hand.
func _build_animation_tree() -> void:
	var state_machine := AnimationNodeStateMachine.new()
	for state_id in STATE_ANIMATIONS:
		var clip_name: String = STATE_ANIMATIONS[state_id]
		if not anim_player.has_animation(clip_name):
			# Loud on purpose. A missing clip used to be a bare `continue`,
			# which silently drops that state from the blend graph: the FSM
			# still transitions correctly and the match still completes, so
			# every headless check passes while the wrestler just stops being
			# animated in that state. Renaming a clip in the .glb is exactly
			# the kind of change that would trip this, and it should fail
			# where it happens rather than turn up in a capture later.
			# tests/test_state_animations.gd guards the table statically too.
			push_error("STATE_ANIMATIONS[%s] names a clip the rig doesn't have: '%s'"
					% [WrestlerFSM.State.keys()[state_id], clip_name])
			continue
		var anim_node := AnimationNodeAnimation.new()
		anim_node.animation = clip_name
		state_machine.add_node(WrestlerFSM.State.keys()[state_id], anim_node)

	# EVERY pair of clip states is connected, not only the FSM's legal edges.
	#
	# The FSM can cross several states in one tick -- a grapple resolves
	# GRAPPLE_HOLD -> MOVE_EXEC -> DOWN in the same call -- and travel() then
	# walks the graph's shortest PATH to the last one, cross-fading through
	# every state on the way. With only the legal edges that path ran through
	# MOVE_EXEC, whose clip is a standing impact pose: every thrown man rose
	# 0.6 m off the mat, arms windmilling, and lay back down over 12 ticks as
	# he entered DOWN. Measured by tools/probe/move_qa.tscn on all 25 moves
	# that end with the victim down. Legality is the FSM's job; the blend
	# graph only needs to get from the pose on screen to the one asked for.
	var blend_seconds := ANIMATION_BLEND_TICKS / float(Engine.physics_ticks_per_second)
	for from_id in WrestlerFSM.LEGAL_TRANSITIONS:
		var from_name: String = WrestlerFSM.State.keys()[from_id]
		if not state_machine.has_node(from_name):
			continue
		for to_id in WrestlerFSM.LEGAL_TRANSITIONS:
			var to_name: String = WrestlerFSM.State.keys()[to_id]
			if to_name == from_name or not state_machine.has_node(to_name):
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = blend_seconds
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			state_machine.add_transition(from_name, to_name, transition)

	# The walk-in's pose (begin_walk_in): reached from anywhere with a longer
	# blend, left with a cut -- its clip IS the first frame of what follows.
	var walk_in := AnimationNodeAnimation.new()
	walk_in.animation = STATE_ANIMATIONS[WrestlerFSM.State.GRAPPLE_HOLD]
	state_machine.add_node(WALK_IN_STATE, walk_in)
	for state_id in STATE_ANIMATIONS:
		var other: String = WrestlerFSM.State.keys()[state_id]
		if not state_machine.has_node(other):
			continue
		var into := AnimationNodeStateMachineTransition.new()
		into.xfade_time = WALK_IN_BLEND_TICKS / float(Engine.physics_ticks_per_second)
		into.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		state_machine.add_transition(other, WALK_IN_STATE, into)
		var out := AnimationNodeStateMachineTransition.new()
		out.xfade_time = blend_seconds
		out.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
		state_machine.add_transition(WALK_IN_STATE, other, out)

	anim_tree = AnimationTree.new()
	add_child(anim_tree)
	anim_tree.tree_root = state_machine
	anim_tree.anim_player = anim_tree.get_path_to(anim_player)
	# Advance on the physics tick, not idle/wall-clock frames (the default) —
	# animation is presentation-only and doesn't feed gameplay state, but an
	# idle-clocked tree would still make playback speed (and therefore what a
	# given tick *looks like*) depend on render framerate, which undermines
	# frame-labeled captures (ARCHITECTURE.md's capture/evidence pipeline)
	# expecting a specific tick to reliably show a specific pose.
	anim_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
	anim_tree.active = true
	_anim_playback = anim_tree["parameters/playback"]
	var idle_name: String = WrestlerFSM.State.keys()[WrestlerFSM.State.IDLE]
	if state_machine.has_node(idle_name):
		_anim_playback.start(idle_name)

## Builds the grip IK: one SkeletonIK3D per arm, solving upperarm -> hand.
##
## The paired grapple clips animate only the two root transforms, and each
## wrestler's skeleton is posed by its own single-character clip, which has no
## idea another body exists. So the attacker performed a lifting motion *near*
## the defender and never touched him -- the "I don't see him lifting him up"
## complaint, which no amount of clip-swapping fixes.
##
## SkeletonIK3D derives from SkeletonModifier3D, so it runs after the
## AnimationMixer writes the pose: the clip supplies the body, this pulls the
## arms onto the opponent on top of it. Contact is therefore emergent and
## holds for every move, including the 13 paired clips still unwritten,
## instead of being keyframed one clip at a time.
##
## Built at runtime for the same reason _build_animation_tree() is: it stays
## derived from the bone names here rather than drifting from them, and it
## avoids needing editable children on the instanced .glb.
##
## Note SkeletonIK3D is Godot's older IK node and marked deprecated. The
## modern replacement, TwoBoneIK3D, was tried first and does nothing on this
## build: in an isolated three-bone skeleton with the chain resolved, the
## target set and influence at 1, the tip bone never leaves its rest pose,
## while SkeletonIK3D lands it within 0.005m of the same target. Measure with
## a BoneAttachment3D if you re-test -- Skeleton3D.get_bone_global_pose()
## returns the *pre-modifier* pose and reports no movement even when a
## modifier is demonstrably working.
func _build_ik_rig() -> void:
	for chain in ARM_CHAINS:
		for role in ["root", "tip"]:
			if skeleton.find_bone(_skeleton_bone_name(chain[role])) < 0:
				push_error("Grip IK: rig has no bone '%s'; arm IK disabled" % chain[role])
				return

	for chain in ARM_CHAINS:
		var ik := SkeletonIK3D.new()
		# Configure before entering the tree: each of root_bone/tip_bone
		# rebuilds the solver chain the moment it's assigned, so setting them
		# on an already-parented node makes the first assignment resolve the
		# other end to -1 and log a build_chain error.
		ik.root_bone = _skeleton_bone_name(chain["root"])
		ik.tip_bone = _skeleton_bone_name(chain["tip"])
		var target := Marker3D.new()
		ik.add_child(target)
		ik.target_node = ik.get_path_to(target)
		skeleton.add_child(ik)
		# interpolation is SkeletonIK3D's own blend, 0 = pure animation pose.
		# Starts fully off so a wrestler who never grapples is posed exactly as
		# he was before this existed.
		ik.interpolation = 0.0
		# Deferred: start() resolves root_bone/tip_bone against the parent
		# skeleton, which SkeletonIK3D only caches in its own _ready(). Called
		# inline right after add_child() it resolves them to -1 and the solver
		# reports "Condition -1 == p_task->root_bone is true" every frame
		# thereafter, doing nothing.
		ik.start.call_deferred()
		_arm_ik.append(ik)
		_grip_targets.append(target)

	_arm_reach = _measure_arm_reach(ARM_CHAINS[0])

## Shoulder-to-hand span in the rest pose — ~0.55m on this 1.83m rig.
func _measure_arm_reach(chain: Dictionary) -> float:
	var shoulder := skeleton.get_bone_global_rest(
			skeleton.find_bone(_skeleton_bone_name(chain["root"]))).origin
	var hand := skeleton.get_bone_global_rest(
			skeleton.find_bone(_skeleton_bone_name(chain["tip"]))).origin
	return shoulder.distance_to(hand)

## True while this wrestler should have hands on the opponent.
func _is_gripping_state() -> bool:
	match fsm.current_state:
		WrestlerFSM.State.TIE_UP:
			return true
		WrestlerFSM.State.GRAPPLE_HOLD:
			# The attacker holds his opponent for the whole move. The
			# defender holds *back* only while he is still on his feet or
			# being loaded -- past the recipe's defender_grips_until he has
			# been thrown, and arms still reaching for the man who threw him
			# read as him hanging in mid-air by them. A move nobody is
			# lifted in (a reversal shove) keeps him gripping throughout.
			return _is_grapple_attacker or _paired_grip_ticks > 0 or in_chain_read()
		_:
			return false

## Aims both grip targets at the opponent and blends the IK in or out.
## Presentation only -- writes bone poses and marker positions, never
## position, velocity or FSM state, so it cannot change a match outcome.
## Presentation tick for a wrestler whose own _physics_process is suspended
## because GrappleRig is driving him through a paired move. GrappleRig calls
## this from its own _physics_process; nothing else should, and while a
## grapple is active the wrestler's _physics_process is by definition not
## running, so the two paths can never both fire on one tick.
func update_paired_presentation() -> void:
	_update_grip_ik()
	if foot_plant:
		foot_plant.advance()


## GrappleRig is about to carry this body from `from` to `to` over `ticks`
## ticks, into the first frame of his half of `move`. Two things, both
## presentation only:
##   * he blends into that first frame now (WALK_IN_STATE), instead of the
##     hold pose snapping to it on the tick the clip starts -- measured up to
##     0.53 m of foot in one tick on the Spear;
##   * his feet step there instead of skating (FootPlant), planned against
##     that pose's stance rather than the one he is standing in.
func begin_walk_in(from: Transform3D, to: Transform3D, ticks: int,
		move: MoveDef = null, is_attacker := false) -> void:
	var start_pose := _first_frame_clip(move, is_attacker)
	var end_feet := []
	if start_pose != "":
		var machine := anim_tree.tree_root as AnimationNodeStateMachine
		(machine.get_node(WALK_IN_STATE) as AnimationNodeAnimation).animation = start_pose
		_inertialize(WALK_IN_STATE)
		_anim_playback.travel(WALK_IN_STATE)
		if foot_plant:
			var rel := from.affine_inverse() * skeleton.global_transform
			for p: Vector3 in foot_plant.first_frame_feet(anim_player.get_animation(start_pose)):
				end_feet.append(rel * p)
	if foot_plant:
		foot_plant.begin(from, to, ticks, end_feet)


## The walk-in's blend-graph node, and how long the blend into it takes: most
## of a short walk-in, so the change of stance happens while he steps.
const WALK_IN_STATE := "WALK_IN"
const WALK_IN_BLEND_TICKS := 9

## A one-frame clip holding the first frame of his half of `move`, made once
## and kept in a runtime library; "" if the move has no half for him.
func _first_frame_clip(move: MoveDef, is_attacker: bool) -> String:
	if move == null or anim_player == null or anim_tree == null:
		return ""
	var clip := PairedRecipes.role_clip(move.animation_pair_id, is_attacker)
	if clip == "" or not anim_player.has_animation(clip):
		return ""
	if not anim_player.has_animation_library(&"walk_in"):
		anim_player.add_animation_library(&"walk_in", AnimationLibrary.new())
	var library := anim_player.get_animation_library(&"walk_in")
	var key := StringName(clip.replace("/", "__"))
	if not library.has_animation(key):
		var still := (anim_player.get_animation(clip).duplicate(true)) as Animation
		for t in still.get_track_count():
			for k in range(still.track_get_key_count(t) - 1, 0, -1):
				still.track_remove_key(t, k)
			if still.track_get_key_count(t) > 0:
				still.track_set_key_time(t, 0, 0.0)
		still.length = 0.1
		still.loop_mode = Animation.LOOP_NONE
		library.add_animation(key, still)
	return "walk_in/%s" % key


func _build_foot_plant() -> void:
	foot_plant = FootPlant.new()
	foot_plant.name = "FootPlant"
	var mapped := []
	for leg: Array in foot_plant.legs:
		mapped.append(leg.map(func(b: String) -> String: return _skeleton_bone_name(b)))
	foot_plant.legs = mapped
	skeleton.add_child(foot_plant)

## The Inertializer (Phase 3 "transitions"): first among the skeleton's
## modifiers, so it smooths the clip's pose and everything after it -- grip
## IK, FootPlant, the eyes -- works on the smoothed one.
func _build_inertializer() -> void:
	inertializer = Inertializer.new()
	inertializer.name = "Inertializer"
	skeleton.add_child(inertializer)
	skeleton.move_child(inertializer, 0)
	inertializer.body = self
	if anim_tree:
		inertializer.watch(anim_tree, _anim_playback)
	# It replaces the crossfades: every edge in the blend graph becomes a cut,
	# and _inertialize() carries the pose across it instead. The graph keeps
	# its crossfades when there is no skeleton to smooth.
	if anim_tree:
		var machine := anim_tree.tree_root as AnimationNodeStateMachine
		for i in machine.get_transition_count():
			machine.get_transition(i).xfade_time = 0.0


## BodyLife: before HitFlinch, so a blow lands on a man already watching,
## breathing and tiring.
func _build_body_life() -> void:
	body_life = BodyLife.new()
	body_life.name = "BodyLife"
	for key: String in body_life.bones.keys():
		body_life.bones[key] = _skeleton_bone_name(key)
	body_life.wrestler = self
	body_life.phase = 0.37 * player_index
	body_life.fidget_seed = 7919 * (player_index + 1)
	skeleton.add_child(body_life)


## Hit-stop: on a big blow both men's poses hold still for a couple of ticks
## at the moment of contact -- the beat that makes a blow read as landing on
## something. Kept to the blows at the top of HitFlinch's scale (a signature,
## a big boot, a spear): 2K26 has no freeze on an ordinary punch at all, and
## held on every cross the match stuttered -- poses still for 3 ticks on
## every second exchange, the "stop motion at certain parts" the owner saw.
## The flinch keeps moving through it. Presentation only: neither the match
## clock nor the clips stop.
const HIT_STOP_HEAVY := 2
const HIT_STOP_MEDIUM := 0
## Only a blow at the top of the scale stops.
const HIT_STOP_STRENGTH := HitFlinch.MAX_STRENGTH


static func hit_stop_ticks_for(strength: float) -> int:
	if strength >= HIT_STOP_STRENGTH - 1e-4:
		return HIT_STOP_HEAVY
	return HIT_STOP_MEDIUM


## Held by the Inertializer: the drawn pose stops, the clip runs on under
## it. Stopping the clip itself -- the tree switched off, or its clock
## stopped -- reset its state machine, and the man came out of the freeze
## playing nothing for the rest of his reaction (measured).
func hit_stop(ticks: int) -> void:
	if inertializer:
		inertializer.freeze(ticks)


## HitFlinch: after the IK and FootPlant, so a man flinches whatever his hands
## and feet are doing; before WornFollow, which carries it to his clothes.
func _build_hit_flinch() -> void:
	hit_flinch = HitFlinch.new()
	hit_flinch.name = "HitFlinch"
	for key: String in hit_flinch.bones.keys():
		hit_flinch.bones[key] = _skeleton_bone_name(key)
	hit_flinch.body = self
	skeleton.add_child(hit_flinch)


## FootLock: after everything that moves the body above the feet (the
## Inertializer's turn, BodyLife, HitFlinch), so it pins the feet under the
## body as it will be drawn; before WornFollow, which carries it to his shoes.
func _build_foot_lock() -> void:
	foot_lock = FootLock.new()
	foot_lock.name = "FootLock"
	var mapped := []
	for leg: Array in foot_lock.legs:
		mapped.append(leg.map(func(b: String) -> String: return _skeleton_bone_name(b)))
	foot_lock.legs = mapped
	foot_lock.wrestler = self
	skeleton.add_child(foot_lock)


## SellClutch: after HitFlinch and BodyLife, so the lean and the hand go on
## top of the look and the breath; before FootLock, which keeps his feet down
## under the lean.
func _build_sell_clutch() -> void:
	sell_clutch = SellClutch.new()
	sell_clutch.name = "SellClutch"
	for key: String in sell_clutch.bones.keys():
		sell_clutch.bones[key] = _skeleton_bone_name(key)
	sell_clutch.wrestler = self
	skeleton.add_child(sell_clutch)


## RopeReach: after FootLock, so a foot reaching for the rope is not pinned
## back to the mat; before WornFollow, which carries it to his clothes.
func _build_rope_reach() -> void:
	rope_reach = RopeReach.new()
	rope_reach.name = "RopeReach"
	var mapped := {}
	for key: String in rope_reach.chains:
		mapped[key] = (rope_reach.chains[key] as Array).map(
				func(b: String) -> String: return _skeleton_bone_name(b))
	rope_reach.chains = mapped
	skeleton.add_child(rope_reach)


## A model dressed on a second skeleton (Roman) gets the body's final pose
## carried across to it, LAST, after every other modifier. See WornFollow.
## His hip height standing at rest, in his own frame, at the size he is
## scaled to. GrappleRig fits how high he lifts a man to it.
func hip_height() -> float:
	if skeleton == null:
		return GrappleRig.AUTHORED_HIP_HEIGHT
	var pelvis := skeleton.find_bone(_skeleton_bone_name("pelvis"))
	if pelvis < 0:
		return GrappleRig.AUTHORED_HIP_HEIGHT
	return (global_transform.affine_inverse()
			* (skeleton.global_transform * skeleton.get_bone_global_rest(pelvis).origin)).y


func _build_worn_follow() -> void:
	var model := anim_player.get_parent()
	if model == null:
		return
	for s: Skeleton3D in model.find_children("", "Skeleton3D", true, false):
		if s == skeleton or s.find_bone(skeleton.get_bone_name(0)) < 0:
			continue
		var follow := WornFollow.new()
		follow.name = "WornFollow"
		skeleton.add_child(follow)
		follow.bind(s)
		return


## Hands the pose on screen over to the clip about to start, over the ticks
## INERTIA_TICKS gives the state it is going to. See Inertializer.
func _inertialize(state_name: String) -> void:
	if inertializer:
		inertializer.inertialize(INERTIA_TICKS.get(state_name, INERTIA_DEFAULT_TICKS),
				StringName(state_name))


func _update_grip_ik() -> void:
	if _arm_ik.is_empty():
		return
	if _paired_grip_ticks > 0:
		_paired_grip_ticks -= 1
	_close_for_lock_up()
	var engaged := _is_gripping_state() and _aim_grip_targets()
	var step := IK_BLEND_PER_TICK if engaged else -IK_BLEND_PER_TICK
	_grip_blend_prev = _grip_blend
	_grip_blend = clampf(_grip_blend + step, 0.0, 1.0)
	for ik in _arm_ik:
		ik.interpolation = _grip_blend
	if _grip_cur_local.size() != _grip_targets.size():
		_grip_cur_local.resize(_grip_targets.size())
		for i in _grip_targets.size():
			_grip_cur_local[i] = _grip_targets[i].position
	_grip_prev_local = _grip_cur_local.duplicate()
	for i in _grip_targets.size():
		_grip_cur_local[i] = _grip_targets[i].position


## Draws the grip between the last two ticks at `f` (Inertializer, before the
## IK solves). The tick's own target goes back on at the next tick.
func draw_grip_between_ticks(f: float) -> void:
	if _grip_prev_local.size() != _grip_targets.size():
		return
	var blend := lerpf(_grip_blend_prev, _grip_blend, f)
	for i in _grip_targets.size():
		_grip_targets[i].position = _grip_prev_local[i].lerp(_grip_cur_local[i], f)
		_arm_ik[i].interpolation = blend


# --- The lock-up's distance --------------------------------------------------
## A collar-and-elbow is chest to chest: foreheads nearly touching, pelvises
## about LOCK_UP_GAP apart. The tie-up starts wherever the two men happened to
## be inside TIE_UP_RANGE (1.4 m) and nothing closed it, so they held the
## "lock-up" 1.1-1.25 m apart -- measured in a live match -- with arms locked
## out at air, which is the pose the owner flagged. So each man's MODEL slides
## toward the other by half the excess, eased in over LOCK_UP_EASE_TICKS and
## back out after.
##
## The model only, never the body: the capsule, position and velocity stay
## exactly where the match put them, so the tie-up minigame, the replay and its
## end-state hash cannot see it. The slide is capped at LOCK_UP_MAX_SLIDE so a
## tie-up at the very edge of range does not skate a model across the mat.
## Set by GrappleRig during a paired move (PairSeparation): how far this
## man's MODEL is eased off the other's body so the two touch instead of
## passing through each other. World space; presentation only, like the
## lock-up slide it is added to. Relaxes back to zero once the move is over.
var paired_separation := Vector3.ZERO
const SEPARATION_RELAX := 0.85

const LOCK_UP_GAP := 0.60
const LOCK_UP_MAX_SLIDE := 0.40
const LOCK_UP_EASE_TICKS := 8
var _lock_up_close := 0.0          # 0-1 eased
var _model_home := Vector3.INF     # the model's own local position


## Re-applies the model's presentation offset (lock-up slide plus paired
## separation) right now, without advancing either ease. GrappleRig calls it
## between separation passes, so each pass measures where the model now is.
func apply_model_offset() -> void:
	var model := anim_player.get_parent() as Node3D if anim_player else null
	if model == null or model == self or _model_home == Vector3.INF:
		return
	var base := model.position - _last_separation_local
	_last_separation_local = global_transform.basis.inverse() * paired_separation
	model.position = base + _last_separation_local


var _last_separation_local := Vector3.ZERO


func _close_for_lock_up() -> void:
	var model := anim_player.get_parent() as Node3D if anim_player else null
	if model == null or model == self:
		return
	if _model_home == Vector3.INF:
		_model_home = model.position
	var locked := (fsm.current_state == WrestlerFSM.State.TIE_UP or in_chain_read()) \
			and opponent != null and is_instance_valid(opponent)
	var step := 1.0 / LOCK_UP_EASE_TICKS
	_lock_up_close = clampf(_lock_up_close + (step if locked else -step), 0.0, 1.0)
	# Out of a paired move, the separation eases back onto the body.
	if not (grapple_rig and grapple_rig.is_active()):
		paired_separation *= SEPARATION_RELAX
		if paired_separation.length() < 0.001:
			paired_separation = Vector3.ZERO
	var separation := global_transform.basis.inverse() * paired_separation
	_last_separation_local = separation
	if _lock_up_close <= 0.0:
		model.position = _model_home + separation
		return
	var to := Vector3.ZERO
	if opponent and is_instance_valid(opponent):
		to = opponent.global_position - global_position
		to.y = 0.0
	var slide := lock_up_slide(to.length())
	var local_dir := (global_transform.basis.inverse() * to.normalized()) \
			if to.length() > 0.001 else Vector3.ZERO
	var eased := smoothstep(0.0, 1.0, _lock_up_close)
	model.position = _model_home + local_dir * slide * eased + separation


## How far one man's model slides in for a lock-up at `gap` metres apart.
static func lock_up_slide(gap: float) -> float:
	return clampf((gap - LOCK_UP_GAP) * 0.5, 0.0, LOCK_UP_MAX_SLIDE)

## Places the two targets on either side of the part of the opponent this
## wrestler is holding. Returns false only when there is nothing to grip, so
## the caller blends back out and leaves the clip's own arm pose alone.
##
## Each target is clamped onto its arm's reach sphere rather than rejected
## when too far: measured, an arm spans 0.547m while the paired clips hold the
## bodies 0.8-1.2m apart, so a hard reach test would never engage at all.
## Clamping gives the honest in-between -- arms fully extended toward the
## opponent when he's beyond reach, hands genuinely on him once he isn't.
func _aim_grip_targets() -> bool:
	if _grip_targets.size() < 2 or not opponent or not is_instance_valid(opponent):
		return false
	if not opponent.skeleton or not skeleton:
		return false
	# The attacker holds his opponent's hips to lift him; everyone else --
	# a tie-up, or a defender holding on to the man lifting him -- holds the
	# chest. Reaching for a lifted victim's chest puts the arms overhead and
	# behind, which reads as nothing at all.
	if fsm.current_state == WrestlerFSM.State.TIE_UP or in_chain_read():
		return _aim_collar_and_elbow()
	# In a paired move, the move says what the attacker holds (PairedContacts).
	if fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD and _is_grapple_attacker \
			and grapple_rig and grapple_rig.is_active():
		var family := PairedContacts.family(grapple_rig._move)
		if family == "none":
			return false
		if family != "":
			var chest := skeleton.global_transform * skeleton.get_bone_global_pose(
					skeleton.find_bone(_skeleton_bone_name("spine_03"))).origin
			var t := PairedContacts.targets(family, opponent, chest)
			if t.size() == 2:
				_grip_targets[0].global_position = _reachable(ARM_CHAINS[0]["root"], t[0])
				_grip_targets[1].global_position = _reachable(ARM_CHAINS[1]["root"], t[1])
				return true
	var lifting := fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD \
			and _is_grapple_attacker
	var anchor_name := GRIP_BONE_LIFT if lifting else GRIP_BONE
	var anchor_bone := opponent.skeleton.find_bone(
		opponent._skeleton_bone_name(anchor_name))
	if anchor_bone < 0:
		return false
	# Position from the bone, lateral axis from the opponent's body: the
	# bone's own basis is a rest-pose artifact of this rig (arms along X) and
	# doesn't track the torso the way the node transform does.
	var anchor := opponent.skeleton.global_transform \
			* opponent.skeleton.get_bone_global_pose(anchor_bone).origin
	var lateral := opponent.global_transform.basis.x.normalized() * GRIP_HALF_WIDTH

	# Godot forward is -Z, so +X is this wrestler's right: index 1 (right arm)
	# takes the +X side of the grip, index 0 (left arm) the -X side.
	_grip_targets[0].global_position = _reachable(ARM_CHAINS[0]["root"], anchor - lateral)
	_grip_targets[1].global_position = _reachable(ARM_CHAINS[1]["root"], anchor + lateral)
	return true

## The collar-and-elbow: the RIGHT hand cups the back of his neck, the LEFT
## grips his right elbow -- the arm he has on your neck. Both men do the same,
## so the arms cross as a real tie-up's do. It used to aim both hands at his
## chest 22 cm either side, which is a two-handed shove; at the old
## tie-up distance it also locked both arms straight out (Roman) or crossed
## them in front of the body (Cody).
func _aim_collar_and_elbow() -> bool:
	var sk := opponent.skeleton
	var neck := sk.find_bone(opponent._skeleton_bone_name(COLLAR_BONE))
	var elbow := sk.find_bone(opponent._skeleton_bone_name(ELBOW_BONE))
	if neck < 0 or elbow < 0:
		return false
	var neck_at := sk.global_transform * sk.get_bone_global_pose(neck).origin
	# Behind the neck: past it along the line from this man to him.
	var across := opponent.global_position - global_position
	across.y = 0.0
	across = across.normalized() if across.length() > 0.001 else Vector3.ZERO
	var collar := neck_at + across * COLLAR_BEHIND + Vector3.UP * COLLAR_UP
	var elbow_at := sk.global_transform * sk.get_bone_global_pose(elbow).origin
	_grip_targets[1].global_position = _reachable(ARM_CHAINS[1]["root"], collar)
	_grip_targets[0].global_position = _reachable(ARM_CHAINS[0]["root"], elbow_at)
	return true

## Nearest point to `target` the named shoulder's arm can actually straighten
## to, stopping just short of full extension.
func _reachable(shoulder_bone_name: String, target: Vector3) -> Vector3:
	var shoulder_bone := skeleton.find_bone(_skeleton_bone_name(shoulder_bone_name))
	if shoulder_bone < 0:
		return target
	var shoulder := skeleton.global_transform \
			* skeleton.get_bone_global_pose(shoulder_bone).origin
	var offset := target - shoulder
	var span := _arm_reach * MAX_EXTENSION
	if offset.length() <= span or offset.length() < 0.001:
		return target
	return shoulder + offset.normalized() * span

## Ticks this wrestler has left of holding on to his opponent during the
## current paired move. Counted down rather than read off the paired
## AnimationPlayer's position so it stays a whole number of physics ticks,
## the same determinism rule TURN_RATE_PER_TICK and IK_BLEND_PER_TICK follow.
var _paired_grip_ticks: int = 0

## Switches this wrestler into his half of `move`'s authored performance, and
## returns whether the move actually had one. Called by GrappleRig.begin()
## for both wrestlers on the same physics tick, which is what keeps the two
## halves and the root trajectory in step.
##
## Restarted with start() rather than travel(): both wrestlers are already in
## GRAPPLE_HOLD by the time the attacker picks a move (_process_grapple_hold
## runs *inside* that state), so travelling to it again is a no-op and the
## pose would inherit the tie-up's playback position instead of beginning at
## the throw's first frame.
func play_paired_pose(move: MoveDef, is_attacker: bool) -> bool:
	if not move or not anim_player or not _anim_playback:
		return false
	var clip := PairedRecipes.role_clip(move.animation_pair_id, is_attacker)
	if clip == "" or not anim_player.has_animation(clip):
		return false
	var state_machine := anim_tree.tree_root as AnimationNodeStateMachine
	var state_name: String = WrestlerFSM.State.keys()[WrestlerFSM.State.GRAPPLE_HOLD]
	if not state_machine.has_node(state_name):
		return false
	var anim_node := state_machine.get_node(state_name) as AnimationNodeAnimation
	if not anim_node:
		return false
	anim_node.animation = clip
	_inertialize(state_name)
	_anim_playback.start(state_name, true)

	var length := anim_player.get_animation(clip).length
	var grip_fraction := 1.0 if is_attacker \
			else PairedRecipes.defender_grip_until(move.animation_pair_id)
	_paired_grip_ticks = int(round(length * grip_fraction
			* Engine.physics_ticks_per_second))
	return true

func _on_fsm_state_changed(_previous: WrestlerFSM.State, current: WrestlerFSM.State) -> void:
	if current == WrestlerFSM.State.IDLE and _previous == WrestlerFSM.State.GETUP:
		# Up off the mat, holding what hurts.
		_begin_sell(most_hurt(combat.limb_damage, SELL_GETUP_MIN), SELL_GETUP_TICKS)
	if current == WrestlerFSM.State.GRAPPLE_HOLD:
		# A tie-up's hold chains (see "chain wrestling"); a running paired
		# move's does not. Both men reset: either may end up the holder.
		_chain_enabled = _previous == WrestlerFSM.State.TIE_UP
		_chain_links = 0
		_chain_read = 0
		_chain_pick = ""
		_chain_done = false
		_chain_reversal_spent = false
		chain_hold = ""
		if _chain_enabled:
			_set_state_clip(WrestlerFSM.State.GRAPPLE_HOLD, CHAIN_READ_CLIP)
	if current != WrestlerFSM.State.STUNNED and _corner_trapped:
		_corner_trapped = false
		_corner_lockout = CORNER_LOCKOUT_TICKS
	if not _anim_playback:
		return
	var state_machine := anim_tree.tree_root as AnimationNodeStateMachine
	var state_name: String = WrestlerFSM.State.keys()[current]
	if not state_machine.has_node(state_name):
		return
	# Point the state's node at whichever clip this wrestler's current role
	# calls for, before travelling into it. Each wrestler builds its own
	# AnimationNodeStateMachine in _build_animation_tree(), so mutating a node
	# here is instance-local -- it can't leak across wrestlers or matches, and
	# it avoids duplicating every LEGAL_TRANSITIONS edge for role variants.
	# MatchReferee._resolve_tie_up() assigns _is_grapple_attacker *before*
	# transitioning either FSM, so the role is already correct by the time
	# this fires.
	var anim_node := state_machine.get_node(state_name) as AnimationNodeAnimation
	if anim_node:
		anim_node.animation = _take_clip_override(current)
	if _snap_next_animation:
		_snap_next_animation = false
		_anim_playback.start(state_name, true)
		return
	_inertialize(state_name)
	_anim_playback.travel(state_name)

## The clip to enter this state with: a one-shot override if one was queued
## for it, otherwise the state's standing clip.
##
## The override exists because this handler runs *after* whoever asked for a
## specific clip. _play_strike_clip() and _play_hit_reaction() both set the
## node's animation and were both silently undone a moment later by the
## assignment here -- so every kick played the jab and every hit reaction
## played the torso flinch, which is exactly what the renders showed and
## what made the generated clips look broken when they were fine.
##
## An override applies to the very next state entry and nothing after it:
## the whole table is cleared here, not just the entry used. A queued
## request whose transition never happened -- a hit that knocked the
## wrestler down instead of into HIT_REACT, or a _start_move() the FSM
## refused -- would otherwise sit there and be spent on an unrelated hit
## later. Measured across ten landed moves in one match, that mis-picked
## two of them: a jab to the jaw playing the torso flinch and a gutwrench
## slam playing the head snap.
func _take_clip_override(state: WrestlerFSM.State) -> String:
	var clip: String = _state_clip_override.get(state, "")
	_state_clip_override.clear()
	if clip != "":
		return clip
	return clip_for_state(state, _is_grapple_attacker)

## Clip this state should play, honouring the per-role overrides. Public so
## tests can assert the tables resolve to clips the rig actually has.
static func clip_for_state(state: WrestlerFSM.State, is_attacker: bool) -> String:
	var overrides: Dictionary = ATTACKER_STATE_ANIMATIONS if is_attacker \
			else DEFENDER_STATE_ANIMATIONS
	if overrides.has(state):
		return overrides[state]
	return STATE_ANIMATIONS.get(state, "")

## The other man's eyes, in world space, for EyeAim; Vector3.INF with no
## opponent. His head bone plus a few centimetres, as EntranceDirector frames
## a close-up.
func _opponent_eye_line() -> Vector3:
	if opponent == null or not is_instance_valid(opponent):
		return Vector3.INF
	var sk := opponent.skeleton
	if sk:
		var i := sk.find_bone(opponent._skeleton_bone_name("Head"))
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin \
					+ Vector3.UP * 0.06
	return opponent.global_position + Vector3.UP * 1.7


func _resolve_paths() -> void:
	if opponent_path != NodePath():
		opponent = get_node(opponent_path)
	if grapple_rig_path != NodePath():
		grapple_rig = get_node(grapple_rig_path)
	if ai:
		ai.target = opponent

func _physics_process(delta: float) -> void:
	# The model's held half-turn is let go on the AnimationTree's mixer_applied
	# -- which never comes if the tree stops mixing (a paired move or the grapple
	# rig takes the pose over), and then the model stayed turned 180 degrees
	# from the man: the two of them stood back to back in the recorded match
	# (tools/probe/glitch_scan.gd: body facing opposite the controller, dot -1,
	# for 35 ticks). A deadline the signal cannot miss.
	if _model_held and Engine.get_physics_frames() > _model_held_until + MODEL_HOLD_GRACE:
		_release_model_facing(true)
	var live_input := _poll_live_input()
	var input := ReplaySystem.get_input(player_index, live_input) if ReplaySystem else live_input
	fsm._physics_process(delta)
	_read_reversal(input)
	_tick_stamina()
	_tick_sell()
	_string_clock += 1

	match fsm.current_state:
		WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN:
			if input.get("taunt", false) and can_taunt():
				begin_taunt()
			else:
				_process_free_movement(delta, input)
		WrestlerFSM.State.TAUNT:
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.STRIKE:
			_process_active_move(input)
		WrestlerFSM.State.TIE_UP:
			# MatchReferee drives the actual contest (TieUpMinigame) once both
			# wrestlers are in TIE_UP — mirrors PIN_DEFENDER's input capture.
			_tie_up_input_this_tick = input.get("grapple", false)
		WrestlerFSM.State.GRAPPLE_HOLD:
			_process_grapple_hold(input)
		WrestlerFSM.State.MOVE_EXEC:
			_process_active_move(input)
		WrestlerFSM.State.HIT_REACT, WrestlerFSM.State.STUNNED:
			if is_corner_trapped():
				_tick_corner_trap()
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.DOWN:
			_stop_dead()
			_process_down(input)
		WrestlerFSM.State.GETUP:
			_stop_dead()
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.RUNNING_ATTACK:
			_process_active_move(input)
		WrestlerFSM.State.IRISH_WHIP:
			_process_irish_whip()
		WrestlerFSM.State.PIN_ATTACKER:
			# Driven by MatchReferee, except for the last stride into the
			# cover -- see _place_cover().
			_tick_cover_slide()
		WrestlerFSM.State.PIN_DEFENDER:
			# MatchReferee reads this each tick against PinMinigame's target
			# window — a kickout needs the button pressed AND the marker in
			# the window at that instant, not just the marker passing
			# through the window on its own (the marker sweeps the whole
			# range every cycle, so without an input gate every pin would
			# resolve as an automatic kickout before reaching a three-count).
			_kickout_input_this_tick = input.get("strike", false)
		WrestlerFSM.State.SUBMISSION_ATTACKER:
			# Driven by MatchReferee; no continued attacker input needed,
			# same as PIN_ATTACKER's three-count. The only motion is the
			# walk to a hold's spot (_place_figure_four).
			_tick_cover_slide()
		WrestlerFSM.State.SUBMISSION_DEFENDER:
			# Mirrors the PIN_DEFENDER case above, but held rather than
			# just-pressed — SubmissionMinigame is a genuine continuous-hold
			# rate race, not a press-limited fill-meter, so no input gating
			# is needed here beyond reading the raw hold state each tick.
			_submission_defender_input_this_tick = input.get("submission_hold", false)

	if rope_reach:
		rope_reach.advance(fsm.is_in(ROPE_HOLD_STATES))
	_tick_selling()
	if _corner_lockout > 0:
		_corner_lockout -= 1
	_keep_off_downed_body(delta)
	_apply_gravity(delta)
	move_and_slide()
	if _rope_load_body:
		# Out in the ropes on purpose -- the clamp would snap him back.
		_end_rope_load_when_clear()
	else:
		keep_inside_the_ring()
		keep_lying_body_inside_the_ropes()
	_release_cover_contact()
	# After move_and_slide(), so the grip is aimed at where the bodies have
	# actually ended up this tick rather than where they started it.
	_update_grip_ik()


## Half-width the mat allows a wrestler's ORIGIN, as opposed to his mesh.
##
## RingBuilder.MAT_HALF is 3.0 and the capsule is BODY_RADIUS 0.4, so 2.6 puts
## his far side exactly on the mat's edge. It sits deliberately OUTSIDE what
## the ropes already enforce -- scenes/ring.tscn's rope walls are 0.3 thick at
## +-3.1, so their inner faces are at 2.95 and move_and_slide() holds a walking
## man at 2.55 -- which is the point: this never fights the ropes, it only
## catches a body that was never asked to collide with them at all.
const RING_KEEP_IN := 2.6

## Mat level. scenes/ring.tscn's floor box is 0.2 thick at y = -0.1, so its top
## surface is y = 0 and a wrestler's origin sits on it.
const MAT_LEVEL := 0.0

## The backstop that makes leaving the ring impossible.
##
## Measured, seed 4 of tools/probe/strike_connect_probe.tscn: WrestlerB is
## walked out to x = -3.07 over six ticks of a GRAPPLE_HOLD, past the mat's
## own edge at 3.0, and there is no floor collider out there -- the ring's is
## 6 m square and the arena floor has none. He falls for the rest of the
## match. At the 20 000-tick budget he is 411 490 m below the mat, the other
## man cannot reach him to finish it, and every strike thrown at him is
## recorded as a miss "off to the side" at a median 0 degrees off the
## attacker's facing. That one seed contributed 383 of the 386 misses in a
## four-seed run and dragged the measured connect rate from 70% to 10%.
##
## The cause is that GrappleRig SUSPENDS both bodies for the length of a
## paired move and drives their transforms from the clip, so neither one is
## colliding with anything: the ropes are not in that code path. GrappleRig
## clamps the pair's MIDPOINT to RING_HALF_EXTENT (2.0), but each wrestler
## then sits an authored offset away from it, and the offsets reach past the
## mat.
##
## So this is a clamp on each wrestler rather than on the pair, run from both
## paths that can move one: here, after move_and_slide(), and from
## GrappleRig._physics_process() for the bodies it has suspended.
##
## Deterministic arithmetic on one transform -- no physics query, no RNG --
## so it satisfies ARCHITECTURE.md's determinism contract while sitting in
## the middle of gameplay positioning, which is where it has to be.
func keep_inside_the_ring() -> void:
	var p := global_position
	var fixed := p
	fixed.x = clampf(p.x, -RING_KEEP_IN, RING_KEEP_IN)
	fixed.z = clampf(p.z, -RING_KEEP_IN, RING_KEEP_IN)
	# Only ever pushed UP. Paired moves lift a man well clear of the mat and a
	# ceiling would break every throw in the set; nothing legitimately puts
	# him below it.
	fixed.y = maxf(p.y, MAT_LEVEL)
	if fixed == p:
		return
	global_position = fixed
	# A body that has been stopped by the mat is not still falling through it.
	if fixed.y > p.y and velocity.y < 0.0:
		velocity.y = 0.0

## Where a man lying down ends, in his own frame (head up -Z): crown, toes and
## the points of his shoulders. The capsule is a standing man's, so without
## this a body knocked down beside the ropes lay half through them.
const LYING_BODY_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, -0.95), Vector3(0.0, 0.0, 1.15),
	Vector3(0.45, 0.0, -0.5), Vector3(-0.45, 0.0, -0.5),
]
## How far out any of those may reach: the rope line is 3.1 (ROPE_SPAN), and a
## board's length short of ROPE_TOUCH leaves the break reach alone.
const LYING_BODY_LIMIT := 3.05
const LYING_STATES: Array = [
	WrestlerFSM.State.DOWN, WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_DEFENDER,
]


## A man lying down is slid in until all of him is inside the ropes -- never
## through or under them. Position arithmetic only, so it is deterministic.
func keep_lying_body_inside_the_ropes() -> void:
	if not LYING_STATES.has(fsm.current_state):
		return
	var shift := Vector3.ZERO
	for point in LYING_BODY_POINTS:
		var q := global_transform * point
		shift.x = minf(shift.x, LYING_BODY_LIMIT - q.x) if q.x > LYING_BODY_LIMIT else shift.x
		shift.x = maxf(shift.x, -LYING_BODY_LIMIT - q.x) if q.x < -LYING_BODY_LIMIT else shift.x
		shift.z = minf(shift.z, LYING_BODY_LIMIT - q.z) if q.z > LYING_BODY_LIMIT else shift.z
		shift.z = maxf(shift.z, -LYING_BODY_LIMIT - q.z) if q.z < -LYING_BODY_LIMIT else shift.z
	if shift != Vector3.ZERO:
		global_position += shift


## Pull a wrestler back down to the mat.
##
## Nothing in this controller ever wrote velocity.y before: move_and_slide()
## ran every tick, but with a permanently-zero vertical velocity, so a
## wrestler was free to *stay* at whatever height something else left it at.
## Confirmed live -- a defender nudged up onto the attacker's capsule cap
## settled at y=0.400127 and held that value, unchanged, for the next 1600
## ticks and through several more states, visibly hovering above the mat. The
## same mechanism made the older post-whip drift permanent instead of
## self-correcting.
##
## Paired grapple moves are unaffected: GrappleRig._suspend() turns
## _physics_process off for both bodies, so this never fights a clip that
## deliberately puts a wrestler in the air mid-throw.
func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		# Zero rather than leave it accumulating -- otherwise velocity.y grows
		# unboundedly while grounded and the first airborne tick launches the
		# body downward through the mat.
		velocity.y = 0.0
		return
	velocity.y -= GRAVITY * delta

func _poll_live_input() -> Dictionary:
	if is_ai:
		var decided: Dictionary = ai.poll_input() if ai else {}
		# Selling a blow, he waits it out; only a reversal comes through.
		if sell_ticks > 0:
			return {"reversal": decided.get("reversal", false)}
		return decided
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"strike": Input.is_action_just_pressed("strike"),
		"grapple": Input.is_action_just_pressed("grapple"),
		"run": Input.is_action_pressed("run"),
		"submission_hold": Input.is_action_pressed("submission_hold"),
		"reversal": Input.is_action_just_pressed("reversal"),
	}

func _process_free_movement(delta: float, input: Dictionary) -> void:
	if fsm.current_state == WrestlerFSM.State.RUN and _irish_whip_return_ticks_remaining > 0:
		_process_irish_whip_return(input)
		return

	var move_vec: Vector2 = input.get("move", Vector2.ZERO)
	var running: bool = input.get("run", false) and move_vec.length() > 0.1
	var speed := RUN_SPEED if running else MOVE_SPEED
	var direction := Vector3(move_vec.x, 0.0, move_vec.y)

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	if direction.length() > 0.1:
		# Face the MAN, not the direction of travel, once inside fighting
		# distance. A wrestler circling an opponent strafes: his eyes, his
		# guard and his hips stay pointed at the other man while his feet
		# carry him sideways. look_at() on the input direction does the
		# opposite -- it turns his shoulder to the opponent and walks him
		# round in a circle facing the way he is going.
		#
		# This is the single biggest reason strikes did not connect, and it
		# hid behind the old hit test: a 1.15 m sphere between two capsule
		# origins does not care which way anyone is pointing, so a wrestler
		# could fight a whole match side-on and still land everything. Once
		# contact became directional the cost showed up immediately --
		# measured over seeds 2 and 3 with tools/probe/strike_connect_probe,
		# 49 of 50 missed strikes were off to the SIDE rather than short, at
		# a median 97 degrees off the attacker's facing, with the opponent a
		# comfortable 0.36 m inside the move's own reach.
		#
		# _turn_toward_opponent() alone could not dig out of that.
		# TURN_RATE_PER_TICK is 0.12 rad/tick and two men circling in
		# opposite directions swing the bearing between them by roughly 0.11
		# rad/tick at MOVE_SPEED, so an attacker who enters STRIKE already 90
		# degrees off recovers about 8 degrees across a jab's whole startup.
		# The turn during startup is the backstop; this is the fix.
		if opponent and _in_range(FACE_OPPONENT_RANGE):
			_turn_toward_opponent()
		else:
			look_at(global_position + direction, Vector3.UP)
		fsm.transition_to(WrestlerFSM.State.RUN if running else WrestlerFSM.State.LOCOMOTION)
	else:
		_turn_toward_opponent()
		if fsm.current_state != WrestlerFSM.State.IDLE:
			fsm.transition_to(WrestlerFSM.State.IDLE)

	_wants_tie_up_this_tick = false
	if fsm.current_state == WrestlerFSM.State.RUN:
		_maybe_start_running_attack(input)
	elif input.get("strike", false) and strike_move:
		var strike := _pick_string_strike()
		_play_strike_clip(strike)
		_start_move(WrestlerFSM.State.STRIKE, strike)
		combat.spend_stamina(CombatSystem.STAMINA_PER_STRIKE_TICK * strike.total_frames())
	elif input.get("grapple", false):
		_wants_tie_up_this_tick = true

## Yaw toward the opponent while standing still. Facing used to be produced
## *only* as a side effect of movement (look_at() on the input direction, and
## only on a tick with input), so a wrestler that wasn't walking never turned
## — including at match start, where the authored spawn transforms had both
## wrestlers facing along Z while standing apart along X. Measured live: the
## forward vector dotted against the direction to the opponent was exactly
## 0.0 on tick 1, i.e. perfectly perpendicular. Nothing in the match ever
## corrected it, because hits and tie-ups are gated on distance alone.
##
## Turns at a fixed angle per physics tick rather than a wall-clock lerp, so
## the result is identical under ReplaySystem playback at any render
## framerate (same reasoning as anim_tree's physics callback mode).
const TURN_RATE_PER_TICK := 0.12 # radians/tick — ~7deg, a 180 in ~26 ticks

## Grip IK tuning. Bone on the *opponent* the hands reach for while squared
## up: spine_03 is this rig's upper chest (wrestler_bone_map.tres maps it to
## the humanoid UpperChest slot).
const GRIP_BONE := "spine_03"
## What a lifting attacker holds instead — the hips of the man he's carrying.
## During a throw the victim's chest is overhead and behind, and reaching for
## it puts the arms somewhere that reads as nothing at all.
const GRIP_BONE_LIFT := "pelvis"
## The tie-up's grips (_aim_collar_and_elbow): his neck, and his right elbow.
## The collar hand sits COLLAR_BEHIND past the neck bone -- round the back of
## it rather than on his throat -- and COLLAR_UP above it, at the base of the
## skull where a real hand cups.
const COLLAR_BONE := "neck_01"
const ELBOW_BONE := "lowerarm_r"
const COLLAR_BEHIND := 0.07
const COLLAR_UP := 0.03
## Arm chains, index-matched to _arm_ik / _grip_targets.
const ARM_CHAINS := [
	{"root": "upperarm_l", "tip": "hand_l"},
	{"root": "upperarm_r", "tip": "hand_r"},
]
## Half a torso width, so the hands land on the opponent's sides rather than
## converging inside him. The rig's shoulders sit at x=+-0.192.
const GRIP_HALF_WIDTH := 0.22
## Fraction of full arm span a grip target may sit at. A fully straightened
## chain is singular and reads as a locked-out arm.
const MAX_EXTENSION := 0.95
## Blend added per physics tick, so a grip fades in over ~7 ticks rather than
## snapping. Fixed per tick, never a wall-clock lerp — same determinism
## requirement as TURN_RATE_PER_TICK above.
const IK_BLEND_PER_TICK := 0.15

func _turn_toward_opponent() -> void:
	if not opponent or not is_instance_valid(opponent):
		return
	var to_opponent := opponent.global_position - global_position
	to_opponent.y = 0.0
	if to_opponent.length() < 0.01:
		return
	var desired := atan2(-to_opponent.x, -to_opponent.z)
	rotation.y = _step_angle(rotation.y, desired, TURN_RATE_PER_TICK)

## Shortest-arc step from `from` toward `to`, capped at `max_step`.
static func _step_angle(from: float, to: float, max_step: float) -> float:
	var diff := wrapf(to - from, -PI, PI)
	if absf(diff) <= max_step:
		return to
	return from + signf(diff) * max_step

func _in_range(range_m: float) -> bool:
	return opponent != null and global_position.distance_to(opponent.global_position) <= range_m

## The opponent's body as a capsule, read off scenes/wrestler.tscn: radius
## 0.4, total height 1.8, sitting at y = 0.9. A capsule's `height` spans the
## hemispheres too, so the cylindrical axis runs 0.4 .. 1.4 in his own space,
## and everything within BODY_RADIUS of THAT SEGMENT is him.
const BODY_RADIUS := 0.4
const BODY_AXIS_LOW := 0.4
const BODY_AXIS_HIGH := 1.4

## How far in front of this wrestler's origin `move` can connect, as a
## centre-to-centre distance against a standing opponent.
##
## This is the same arithmetic _strike_reaches() does, solved for distance
## rather than evaluated at one, and it exists because the AI has to stand
## somewhere. WrestlerAI used to hold its spacing against STRIKE_HIT_RANGE,
## which was the reach of every strike when there was only one number; now
## that each move reaches as far as its own limb, a single constant cannot
## answer "can I hit him from here" for a pool of four different strikes.
##
## Note the lateral term: a boot that swings across the body (strike_kick_
## heavy's lands 0.148 m off the centre line) spends part of its contact
## sphere sideways, so it reaches slightly less far forward than its offset
## alone suggests.
static func strike_reach(move: MoveDef) -> float:
	if move == null or move.contact_radius <= 0.0:
		return STRIKE_HIT_RANGE
	var span: float = BODY_RADIUS + move.contact_radius
	var lateral: float = move.contact_offset.x
	return -move.contact_offset.z + sqrt(maxf(span * span - lateral * lateral, 0.0))

## The shortest reach among every strike this wrestler might throw.
##
## The AI does not choose which strike it throws -- _pick_tier_move() draws
## from strike_move plus strike_move_pool -- so the only distance at which a
## thrown strike is guaranteed to be able to land is inside the SHORTEST of
## them. Standing where only the longest reaches means the rest swing at air,
## which is exactly what happened when the cross reached 1.07 m and the AI
## circled at 1.10.
func shortest_strike_reach() -> float:
	var shortest := strike_reach(strike_move)
	for move in strike_move_pool:
		if move:
			shortest = minf(shortest, strike_reach(move))
	return shortest

## Does this strike's limb actually reach the opponent's body?
##
## This is the test that used to be `_in_range(STRIKE_HIT_RANGE)` -- one 1.15m
## sphere between the two capsule ORIGINS, shared by every strike in the game
## and evaluated on every tick of the active window. It asked nothing about
## where the striking limb was, which had three consequences, all measured:
##
##   * One range for four limbs. The clips put the striking limb 0.42 / 0.55 /
##     0.82 / 0.82 m in front of the origin (jab / cross / kick / heavy kick),
##     so 1.15 m landed the jab through a third of a metre of clear air and
##     cut both kicks short of where the boot really was. The 1.15 was honest
##     once -- it is 0.76 m of fist plus the 0.4 capsule -- but it was
##     measured on a Punch_Jab clip that no longer exists.
##   * No direction. _turn_toward_opponent() only runs in the idle branch of
##     _process_free_movement(), and nothing updates facing during STRIKE, so
##     a punch thrown while strafing away connected.
##   * No height. A boot and a jab tested identically against a man's origin.
##
## So the move carries a measured `contact_offset` (see MoveDef, baked by
## tools/anim/measure_contact_offsets.gd) and this places a sphere of
## `contact_radius` there, in the attacker's own space, and intersects it with
## the opponent's capsule. Facing and height come out of that for free: an
## offset is a direction as well as a distance.
##
## Deterministic, and deliberately NOT a physics query. ARCHITECTURE.md's
## determinism contract says rigid-body simulation must never feed gameplay
## state, so this reads no Jolt contact and casts no shape -- it is arithmetic
## on two transforms and one baked constant. It also does NOT read the live
## skeleton: a retargeted model poses its bones slightly differently, and
## sampling those would make damage depend on which wrestler was on screen and
## quietly break replay hashes across models.
##
## The offset is sampled at the move's own contact tick and then held for the
## whole active window, so what is really being tested is the volume the limb
## sweeps through those 4-5 ticks rather than its position on each one.
func _strike_reaches(move: MoveDef) -> bool:
	if opponent == null or not is_instance_valid(opponent):
		return false
	# Moves with no authored contact volume -- grapples, paired moves, and the
	# timed stubs -- keep the old proximity test. GrappleRig places both
	# wrestlers itself, so no limb of theirs is being aimed at anything.
	if move == null or move.contact_radius <= 0.0:
		return _in_range(STRIKE_HIT_RANGE)
	var contact := global_transform * move.contact_offset
	var axis_low := opponent.global_transform * Vector3(0.0, BODY_AXIS_LOW, 0.0)
	var axis_high := opponent.global_transform * Vector3(0.0, BODY_AXIS_HIGH, 0.0)
	var nearest := Geometry3D.get_closest_point_to_segment(contact, axis_low, axis_high)
	return contact.distance_to(nearest) <= BODY_RADIUS + move.contact_radius

## RUN -> RUNNING_ATTACK is the only legal way into RUNNING_ATTACK, so this
## is only ever called while already in RUN (both the player/AI-steered
## case, from _process_free_movement(), and the post-whip autopilot case,
## from _process_irish_whip_return()).
func _maybe_start_running_attack(input: Dictionary) -> void:
	if input.get("strike", false) and running_attack_move and opponent \
			and _in_range(STRIKE_HIT_RANGE) and not UNHITTABLE_STATES.has(opponent.fsm.current_state):
		var move := _pick_tier_move(running_attack_move, running_attack_move_pool)
		if _can_run_into_paired(move):
			_begin_running_paired(move)
			return
		# One state, potentially two performances: point it at this move's
		# clip first (a move with no baked clip keeps the Punch_Cross
		# fallback -- _set_state_clip ignores unknown clips).
		_set_state_clip(WrestlerFSM.State.RUNNING_ATTACK,
				StrikeRecipes.clip(String(move.animation_pair_id)) if move else "")
		_start_move(WrestlerFSM.State.RUNNING_ATTACK, move)

## The corner move, if he has one and the other man is hanging in a corner and
## he is free to run at him. The man is brought out of the trap first
## (STUNNED -> IDLE is legal; STUNNED -> GRAPPLE_HOLD is not), then both go
## through the same paired path as any running attack. Returns whether it
## started.
func try_corner_spear() -> bool:
	if corner_move == null or opponent == null or grapple_rig == null:
		return false
	if not opponent.is_corner_trapped():
		return false
	if not RUNNING_PAIRED_TARGET_STATES.has(fsm.current_state):
		return false
	if not PairedRecipes.RECIPES.has(String(corner_move.animation_pair_id)):
		return false
	opponent.fsm.transition_to(WrestlerFSM.State.IDLE)
	_begin_running_paired(corner_move)
	return true

## States a man can be run into a paired move from: on his feet and not
## already committed to something of his own.
const RUNNING_PAIRED_TARGET_STATES := [
	WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN,
]

## Whether this running attack is a two-man move and can start now.
##
## A running attack with a paired recipe (resources/animations/
## paired_recipes.gd) is performed by both men: the runner's half and the
## victim's half keyed against each other, played through GrappleRig like a
## throw. One without is the old single-character strike, whose victim
## plays a generic hit reaction. The paired version needs the victim on his
## feet and free; otherwise the old path still runs.
func _can_run_into_paired(move: MoveDef) -> bool:
	return move != null and grapple_rig != null \
			and PairedRecipes.RECIPES.has(String(move.animation_pair_id)) \
			and RUNNING_PAIRED_TARGET_STATES.has(opponent.fsm.current_state)

## Starts a paired running attack: no tie-up -- he has already arrived at a
## run -- so both men go straight to GRAPPLE_HOLD with the roles set, and
## GrappleRig plays the move exactly as it would a throw. It resolves through
## _on_grapple_finished(), which applies damage and momentum and puts the
## victim down or into a reaction; a running attack is on no rung of the
## chain, so tier_of() is -1 and nothing is recorded there.
func _begin_running_paired(move: MoveDef) -> void:
	_is_grapple_attacker = true
	opponent._is_grapple_attacker = false
	fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	opponent.fsm.transition_to(WrestlerFSM.State.GRAPPLE_HOLD)
	_active_move = move
	grapple_rig.begin(self, opponent, move)
	grapple_rig.grapple_finished.connect(_on_grapple_finished, CONNECT_ONE_SHOT)

## Called by the attacker's own _process_grapple_hold() when it chooses to
## whip instead of resolving a normal grapple move. Launches the defender
## (this call's `opponent`, from the defender's own perspective once we
## reach into it below) toward the ropes with real velocity -- the actual
## flight and rebound are handled by _process_irish_whip() once physics
## carries the body into a rope collider, not scripted here.
func _begin_irish_whip() -> void:
	var launch_dir := opponent.global_position - global_position
	launch_dir.y = 0.0
	launch_dir = launch_dir.normalized() if launch_dir.length() > 0.01 else Vector3.FORWARD
	opponent.velocity = launch_dir * IRISH_WHIP_LAUNCH_SPEED
	opponent._irish_whip_launch_velocity = opponent.velocity
	opponent._irish_whip_target = self
	opponent._irish_whip_rebounded = false
	# The hold ends here too -- the whip replaces the grapple move.
	_clear_grapple_roles()
	fsm.transition_to(WrestlerFSM.State.IDLE)
	opponent.fsm.transition_to(WrestlerFSM.State.IRISH_WHIP)

## Checks the *previous* tick's move_and_slide() collision report (the
## standard CharacterBody3D pattern -- move_and_slide() itself runs
## unconditionally at the end of _physics_process(), after this match-
## statement dispatch, so a collision from tick T is read here at the top
## of tick T+1) for a hit against a real rope collider (scenes/ring.tscn's
## RING_ROPE_GROUP StaticBody3Ds). On the first such hit, reflects velocity
## off the rope's normal -- a genuine physics bounce, not a scripted
## teleport -- and hands off to RUN, which _process_irish_whip_return()
## then auto-steers back toward the original attacker.
func _process_irish_whip() -> void:
	if _irish_whip_rebounded:
		return
	if _rope_load_tick >= 0:
		_tick_rope_load()
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Node and (collider as Node).is_in_group(RING_ROPE_GROUP):
			_begin_rope_load(collision.get_normal(), collider as Node)
			_tick_rope_load()
			return
	# No rope found in time -- see IRISH_WHIP_MAX_TICKS. Hand back to RUN
	# without a rebound rather than leaving the wrestler in a state with no
	# exit; he keeps whatever velocity the launch gave him and
	# _process_free_movement() takes over from the next tick.
	if fsm.ticks_in_state >= IRISH_WHIP_MAX_TICKS:
		_irish_whip_rebounded = true
		fsm.transition_to(WrestlerFSM.State.RUN)

## THE ROPE LOAD (gauntlet/refs/ropes.md). A body does not bounce off the
## ropes the tick it reaches them; it carries on INTO them, and they stop it
## and throw it back. The rope collider stops the capsule's centre 0.38 m
## short of where his back first touches the real ropes at 3.1, so he first
## travels that gap at full speed (ROPE_LOAD_FREE), then the ropes take him
## ROPE_LOAD_DEPTH further on a half-sine -- a mass on a spring, stopped and
## returned -- and he comes back out of them at the rebound's speed. At 9 m/s
## that is ~14 ticks in the ropes, against the footage's ~0.25 s contact;
## the live ropes (core/ring/ring_ropes.gd) see his back go 0.4 m past their
## line and give that far.
##
## Kinematic and closed-form in ticks, so deterministic. The rope collider he
## is in is excepted from his collision for the load and until he is back
## inside the point where it stopped him, and keep_inside_the_ring() stands
## aside for the same span (it would snap him back to 2.6).
const ROPE_LOAD_FREE := 0.38
const ROPE_LOAD_DEPTH := 0.40
## Longest he can be out in the ropes before being put back regardless -- a
## load interrupted by something that holds him still must not strand him
## outside the ring with the rope collider switched off.
const ROPE_LOAD_MAX_TICKS := 60

## Ticks since this whip's rope load began, or -1 when not loading.
var _rope_load_tick := -1
var _rope_load_from := Vector3.ZERO
var _rope_load_out := Vector3.ZERO
var _rope_load_speed := 0.0
var _rope_load_along := Vector3.ZERO
var _rope_load_body: CollisionObject3D
## What _begin_irish_whip() launched him with -- see _begin_rope_load().
var _irish_whip_launch_velocity := Vector3.ZERO


func _begin_rope_load(normal: Vector3, rope: Node) -> void:
	var inward := Vector3(normal.x, 0.0, normal.z).normalized()
	_rope_load_out = -inward
	# The launch velocity, not `velocity`: move_and_slide() has already slid
	# the tick that reached the collider, taking the part into the rope away.
	var flat := Vector3(_irish_whip_launch_velocity.x, 0.0, _irish_whip_launch_velocity.z)
	_rope_load_speed = maxf(flat.dot(_rope_load_out), 1.0)
	_rope_load_along = flat - _rope_load_out * flat.dot(_rope_load_out)
	_rope_load_from = global_position
	_rope_load_tick = 0
	_rope_load_body = rope as CollisionObject3D
	if _rope_load_body:
		add_collision_exception_with(_rope_load_body)


## Where the load has him `seconds` after it began, as distance out past
## where the collider stopped him; -1 once the ropes have thrown him back.
static func rope_load_offset(seconds: float, speed: float) -> float:
	var t_free := ROPE_LOAD_FREE / speed
	if seconds < t_free:
		return speed * seconds
	var omega := speed / ROPE_LOAD_DEPTH
	var u := seconds - t_free
	if u < PI / omega:
		return ROPE_LOAD_FREE + ROPE_LOAD_DEPTH * sin(omega * u)
	return -1.0


func _tick_rope_load() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	_rope_load_tick += 1
	var x := rope_load_offset(_rope_load_tick * dt, _rope_load_speed)
	if x < 0.0:
		# Thrown back: out of the ropes at the rebound's speed, the way he
		# went in reflected, as the old instant bounce gave.
		global_position = _rope_load_from + _rope_load_out * ROPE_LOAD_FREE \
				+ _rope_load_along * (_rope_load_tick * dt)
		velocity = (-_rope_load_out * _rope_load_speed + _rope_load_along) \
				* IRISH_WHIP_REBOUND_DAMPING
		_irish_whip_rebounded = true
		_irish_whip_return_ticks_remaining = IRISH_WHIP_RETURN_TICKS
		fsm.transition_to(WrestlerFSM.State.RUN)
		return
	var want := _rope_load_from + _rope_load_out * x \
			+ _rope_load_along * (_rope_load_tick * dt)
	want.y = global_position.y
	velocity = (want - global_position) / dt


## Hands the rope collider back once he is inside where it stopped him.
func _end_rope_load_when_clear() -> void:
	var out := (global_position - _rope_load_from).dot(_rope_load_out)
	var loading := _rope_load_tick >= 0 and not _irish_whip_rebounded
	if out > 0.0 and (loading or _rope_load_tick < ROPE_LOAD_MAX_TICKS):
		if not loading:
			_rope_load_tick += 1
		return
	if out > 0.0:
		# Stranded out in the ropes (stopped mid-return): put him back.
		global_position -= _rope_load_out * out
	if is_instance_valid(_rope_load_body):
		remove_collision_exception_with(_rope_load_body)
	_rope_load_body = null
	_rope_load_tick = -1


## Autopilot phase right after a rope rebound -- see
## _irish_whip_return_ticks_remaining's doc comment for why this can't just
## hand control to normal _process_free_movement() immediately. Steers
## deterministically toward _irish_whip_target at RUN_SPEED (no player/AI
## input drives direction here, matching a real rebound's momentum), while
## still allowing a running attack the moment it's in range.
func _process_irish_whip_return(input: Dictionary) -> void:
	_irish_whip_return_ticks_remaining -= 1
	if _irish_whip_target and is_instance_valid(_irish_whip_target):
		var dir := _irish_whip_target.global_position - global_position
		dir.y = 0.0
		if dir.length() > 0.1:
			dir = dir.normalized()
			velocity.x = dir.x * RUN_SPEED
			velocity.z = dir.z * RUN_SPEED
			look_at(global_position + dir, Vector3.UP)
	_maybe_start_running_attack(input)

func _start_move(state: WrestlerFSM.State, move: MoveDef) -> void:
	_active_move = move
	_move_ticks_remaining = move.total_frames()
	_active_move_hit_applied = false
	# None of _start_move()'s states (STRIKE/MOVE_EXEC/RUNNING_ATTACK/
	# HIT_REACT) manage velocity themselves once entered -- _process_
	# active_move()/_process_timed_state() never touch it, so whatever was
	# left over from before (e.g. the irish-whip return autopilot's RUN_SPEED
	# steering, or a rope bounce's velocity.bounce(normal), which can carry a
	# small off-axis Y component if the collision wasn't a clean face hit)
	# just sits there and gets silently consumed by move_and_slide() on
	# every subsequent tick. Confirmed live: a wrestler reversed straight out
	# of a post-whip RUNNING_ATTACK drifted ~0.74m in Y over its 20-tick
	# HIT_REACT window with no other cause -- stale velocity, not gravity
	# (there isn't any) or the reversal animation (which ends at y=0.0).
	velocity = Vector3.ZERO
	fsm.transition_to(state)

## States a wrestler cannot be struck out of by an opposing strike/grapple —
## already down, mid-getup, or committed to a pin/submission/finisher
## sequence. Without this gate a standing opponent can keep striking a
## downed wrestler and re-trigger _go_down() every hit, permanently
## resetting the getup timer so the match can never reach a pin.
const UNHITTABLE_STATES: Array[WrestlerFSM.State] = [
	WrestlerFSM.State.DOWN,
	WrestlerFSM.State.GETUP,
	WrestlerFSM.State.PIN_ATTACKER,
	WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_ATTACKER,
	WrestlerFSM.State.SUBMISSION_DEFENDER,
	WrestlerFSM.State.FINISHER,
	WrestlerFSM.State.MOVE_EXEC,
]

func _process_active_move(input: Dictionary) -> void:
	if not _active_move:
		fsm.transition_to(WrestlerFSM.State.IDLE)
		return
	var frame_offset := _active_move.total_frames() - _move_ticks_remaining
	var in_active_frames := frame_offset >= _active_move.startup_frames \
		and frame_offset < _active_move.startup_frames + _active_move.active_frames

	# Keep turning into the strike until it lands. _strike_reaches() is a
	# DIRECTIONAL test now -- the limb has a position, not just a distance --
	# and facing was previously updated only in the idle branch of
	# _process_free_movement(), never during STRIKE. Without this a wrestler
	# who threw while stepping kept the heading his movement gave him and the
	# punch swung past an opponent standing beside him.
	#
	# It stops at contact rather than running through the recovery, so a
	# strike still commits to where it was aimed: turning through the active
	# frames would let a thrown punch track a man walking out of it.
	if frame_offset < _active_move.startup_frames:
		_turn_toward_opponent()


	if _ground_zone != "":
		_tick_ground_step()
		if in_active_frames and opponent and not _active_move_hit_applied:
			_active_move_hit_applied = true
			if _ground_zone != "pickup" and DOWNED_STATES.has(opponent.fsm.current_state):
				opponent._take_ground_hit(self, _active_move, _ground_zone)
	elif in_active_frames and opponent and _strike_reaches(_active_move) \
			and not UNHITTABLE_STATES.has(opponent.fsm.current_state) \
			and not _active_move_hit_applied:
		_active_move_hit_applied = true
		# Read and parried: nothing lands, and the counter is on its way.
		if not opponent._take_reversal(self, _active_move):
			_apply_move_to_opponent(_active_move)

	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		_active_move_hit_applied = false
		_active_move = null
		_ground_zone = ""
		# A hit taken mid-strike was held back so this punch could land; pay
		# it now. CONSUMED, not queued -- an unconsumed one-shot request spent
		# on an unrelated hit later is a bug this project has had once already
		# (see the note on one-shot clip overrides in references/wiring.md).
		if _pending_hit_reaction:
			var taken := _pending_hit_reaction
			_pending_hit_reaction = null
			_begin_hit_reaction(taken)
			return
		fsm.transition_to(WrestlerFSM.State.IDLE)

func _apply_move_to_opponent(move: MoveDef) -> void:
	if fsm.current_state == WrestlerFSM.State.STRIKE:
		_count_string_hit()
	move_landed.emit(self, opponent, move)
	# Momentum belongs to whoever lands the hit (self), not the wrestler
	# taking it — applied immediately since it's this wrestler's own
	# CombatSystem, not shared, so there's no cross-wrestler race here.
	# The damage itself still goes through the deferred queue below.
	combat.apply_momentum(move)
	opponent._pending_hits.append(move)

# --- in-between behaviour (gauntlet/refs/animation_gap.md, Phase 4) ----------
#
# What a man does between moves, past what BodyLife already gives him
# (breathing, the tired slump, eyes on his man, fidgets):
#
#   * He plays to the crowd. A TAUNT is his own gesture -- Roman's finger to
#     the crowd, Cody's "whoa", the air punch for anyone else -- thrown over a
#     man who is down: once to set up his finisher, once after a power move
#     lands (WrestlerAI decides when). The crowd pops for it.
#   * He sells. Coming up off the mat, and every so often standing, he holds
#     the part that has taken the most -- a hand to the head, the ribs, the
#     knee, the shoulder -- leaning into it (SellClutch).
#   * He paces himself. A worn man walks slower and throws less often
#     (WrestlerAI.fatigue_scale).

## Each man's taunt: clip and how long he holds it, in ticks. Keyed by
## entrance_style, which is who he is.
const TAUNTS := {
	"roman": ["strikes/finger_raise", 110],
	"cody": ["strikes/whoa_low", 140],
	"": ["strikes/air_punch", 90],
}
const TAUNTS_MAX := 2
## Selling: coming up off the mat he holds the part that has taken at least
## SELL_GETUP_MIN, for SELL_GETUP_TICKS; standing, one that has taken
## SELL_IDLE_MIN, for SELL_IDLE_TICKS, every SELL_EVERY ticks or so (seeded
## per man, so two never sell in step).
const SELL_GETUP_MIN := 20.0
const SELL_GETUP_TICKS := 75
const SELL_IDLE_MIN := 45.0
const SELL_IDLE_TICKS := 60
const SELL_EVERY := Vector2i(300, 540)

var _sell_clock := -1
var _sell_draws := 0
## Sells begun this match (probes).
var sells := 0


func _tick_selling() -> void:
	if sell_clutch == null:
		return
	var free := fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION])
	sell_clutch.advance(free)
	if not free:
		return
	if _sell_clock < 0:
		_sell_clock = _next_sell_wait()
	_sell_clock -= 1
	if _sell_clock > 0:
		return
	_sell_clock = _next_sell_wait()
	_begin_sell(most_hurt(combat.limb_damage, SELL_IDLE_MIN), SELL_IDLE_TICKS)


func _next_sell_wait() -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([name, _sell_draws, "sell"])
	_sell_draws += 1
	return rng.randi_range(SELL_EVERY.x, SELL_EVERY.y)


func _begin_sell(part: String, ticks: int) -> void:
	if part == "" or sell_clutch == null:
		return
	sell_clutch.sell(part, ticks)
	sells += 1

signal taunted(wrestler: WrestlerController)

var taunts_used := 0


func taunt_ticks() -> int:
	return int((TAUNTS.get(entrance_style, TAUNTS[""]) as Array)[1])


func can_taunt() -> bool:
	return taunts_used < TAUNTS_MAX and fsm.is_in([WrestlerFSM.State.IDLE,
			WrestlerFSM.State.LOCOMOTION])


func begin_taunt() -> void:
	var t: Array = TAUNTS.get(entrance_style, TAUNTS[""])
	taunts_used += 1
	_set_state_clip(WrestlerFSM.State.TAUNT, String(t[0]))
	_start_move(WrestlerFSM.State.TAUNT, _timed_stub(int(t[1])))
	taunted.emit(self)


## The part of him that has taken the most, as SellClutch names it, or "" if
## nothing has taken enough to sell.
static func most_hurt(limb_damage: Dictionary, at_least: float) -> String:
	var best := ""
	var most := at_least
	for pair: Array in [[CombatSystem.Limb.HEAD, "head"], [CombatSystem.Limb.TORSO, "torso"],
			[CombatSystem.Limb.LEGS, "legs"], [CombatSystem.Limb.ARMS, "arms"]]:
		var d: float = limb_damage.get(pair[0], 0.0)
		if d >= most:
			most = d
			best = pair[1]
	return best


# --- chain wrestling (gauntlet/refs/animation_gap.md, Phase 4) ---------------
#
# Out of a lock-up the two men trade holds before anybody throws anything, the
# way a match opens on TV and 2K's chain wrestling plays it: the man who won
# the tie-up steers a hold with the stick, and the man in it can reverse to
# take the next one himself.
#
# Each hold is one LINK, a paired move (chain_headlock, chain_wristlock,
# chain_waistlock: into the hold, cranked twice, fought free, squared up) that
# GrappleRig plays like any other. Between links is the READ: CHAIN_READ_TICKS
# back in the collar-and-elbow, in which
#   * the holder picks the next hold by the stick, relative to his facing:
#     forward a side headlock, back a go-behind to a waistlock, either side a
#     wristlock -- or nothing, and throws his grapple move when the read ends;
#   * the other man may press Reversal inside CHAIN_REVERSAL_WINDOW to take
#     it over: he becomes the holder and goes straight into CHAIN_COUNTER of
#     the hold he was about to be put in. A press outside the window spends
#     his chance for that read.
# A hold runs to CHAIN_LINKS_MAX links, then the holder throws his move.
#
# Holds wear the man in them a little (2-3 damage to the part held, 2
# momentum to the holder) and cost both some stamina. They are the opening
# of a match, not a way through it.

const CHAIN_HOLDS := {
	"headlock": preload("res://resources/moves/chain_headlock.tres"),
	"wristlock": preload("res://resources/moves/chain_wristlock.tres"),
	"waistlock": preload("res://resources/moves/chain_waistlock.tres"),
}
## What a reversal turns each hold into, for the man who reverses it: out of
## a headlock he goes behind (the classic escape); out of a wristlock he rolls
## through into his own; out of a waistlock he switches behind.
const CHAIN_COUNTER := {
	"headlock": "waistlock", "wristlock": "wristlock", "waistlock": "waistlock",
	"": "wristlock",
}
const CHAIN_LINKS_MAX := 3
const CHAIN_READ_TICKS := 18
## After a reversal the new holder's read is this much shorter: he is already
## moving.
const CHAIN_REVERSAL_HEAD_START := 12
## Ticks into a read inside which a Reversal press takes it over.
const CHAIN_REVERSAL_WINDOW := Vector2i(4, 14)
## A stick push under this is no pick.
const CHAIN_STICK_DEAD := 0.5
## Stamina a hold costs, per link, and a reversal of one.
const STAMINA_CHAIN_HOLDER := 0.02
const STAMINA_CHAIN_HELD := 0.03

signal chain_reversed(reverser: WrestlerController, held: WrestlerController)
## A hold's link has run and its wear landed. Not move_landed: that means a
## move has resolved and both men are out of the hold, and after a link they
## are still in it.
signal chain_hold_landed(holder: WrestlerController, held: WrestlerController, move: MoveDef)

## Whether this hold chains at all: a tie-up's, not a running paired move's.
var _chain_enabled := false
var _chain_links := 0
var _chain_read := 0
var _chain_pick := ""
## True once the AI (or a probe) has said this read is over with no pick.
var _chain_done := false
var _chain_reversal_spent := false
## The hold being played right now, while a link runs.
var chain_hold := ""
## Counters landed out of holds this match (probes).
var chain_reversals := 0


## The hold a stick push asks for, relative to this man's facing.
func chain_hold_for_stick(move: Vector2) -> String:
	return chain_hold_for(move, global_transform.basis)


## The hold a stick push (world x, z) asks for of a man facing `facing`'s -Z.
static func chain_hold_for(move: Vector2, facing: Basis) -> String:
	if move.length() < CHAIN_STICK_DEAD:
		return ""
	var dir := Vector3(move.x, 0.0, move.y).normalized()
	var ahead := dir.dot(-facing.z)
	var side := dir.dot(facing.x)
	if absf(side) > absf(ahead):
		return "wristlock"
	return "headlock" if ahead > 0.0 else "waistlock"


## In the read between links: back in the lock-up, the next hold undecided.
func in_chain_read() -> bool:
	var holder := self if _is_grapple_attacker else opponent
	return holder != null and fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD \
			and holder._chain_enabled and holder._chain_links < CHAIN_LINKS_MAX \
			and holder.chain_hold == "" and not (grapple_rig and grapple_rig.is_active())


## The holder's tick of the read. Returns true while the read goes on (or a
## link has started), false when it is over with nothing picked -- the caller
## then throws the grapple move as it always did.
func _tick_chain_read(input: Dictionary) -> bool:
	if not _chain_enabled or _chain_links >= CHAIN_LINKS_MAX or _chain_done:
		return false
	_chain_read += 1
	var asked: String = String(input.get("chain", ""))
	if asked == "none":
		_chain_done = true
		return false
	if asked == "":
		asked = chain_hold_for_stick(input.get("move", Vector2.ZERO))
	if CHAIN_HOLDS.has(asked):
		_chain_pick = asked
	if _chain_read < CHAIN_READ_TICKS:
		return true
	if _chain_pick == "":
		_chain_done = true
		return false
	_begin_chain_link(_chain_pick)
	return true


## The held man's tick of the read: a Reversal press in the window takes it.
func _tick_chain_counter(input: Dictionary) -> void:
	if opponent == null or not opponent._chain_enabled or opponent.chain_hold != "" \
			or opponent._chain_links >= CHAIN_LINKS_MAX or opponent._chain_done:
		return
	if not input.get("reversal", false) or _chain_reversal_spent:
		return
	var at := opponent._chain_read
	if at < CHAIN_REVERSAL_WINDOW.x or at > CHAIN_REVERSAL_WINDOW.y:
		_chain_reversal_spent = true
		return
	_take_chain_over()


## Reverses the hold he was about to be put in: he is the holder now, and
## goes into its counter.
func _take_chain_over() -> void:
	var held := opponent
	var counter: String = CHAIN_COUNTER.get(held._chain_pick, "wristlock")
	held._is_grapple_attacker = false
	_is_grapple_attacker = true
	_chain_enabled = true
	_chain_links = held._chain_links
	_chain_done = false
	_chain_pick = counter
	_chain_read = CHAIN_REVERSAL_HEAD_START
	_chain_reversal_spent = false
	held._chain_reversal_spent = false
	held._chain_pick = ""
	held._chain_read = 0
	combat.spend_stamina(CombatSystem.STAMINA_REVERSAL)
	chain_reversals += 1
	chain_reversed.emit(self, held)


func _begin_chain_link(hold: String) -> void:
	var move: MoveDef = CHAIN_HOLDS[hold]
	chain_hold = hold
	_chain_links += 1
	opponent._chain_links = _chain_links
	_active_move = move
	if grapple_rig:
		grapple_rig.begin(self, opponent, move)
		grapple_rig.grapple_finished.connect(_on_chain_link_finished, CONNECT_ONE_SHOT)
	else:
		_on_chain_link_finished(self, opponent)


## A link has run: the hold's wear lands, and both are back in the lock-up
## for the next read.
func _on_chain_link_finished(_attacker: Node3D, _defender: Node3D) -> void:
	var move := _active_move
	_active_move = null
	chain_hold = ""
	if move:
		opponent.combat.apply_damage(move,
				CombatSystem.COMEBACK_DAMAGE_SCALE if combat.is_fired_up() else 1.0)
		opponent._took_moves(1)
		combat.apply_momentum(move)
		chain_hold_landed.emit(self, opponent, move)
	combat.spend_stamina(STAMINA_CHAIN_HOLDER)
	opponent.combat.spend_stamina(STAMINA_CHAIN_HELD)
	_chain_read = 0
	_chain_pick = ""
	_chain_done = false
	opponent._chain_reversal_spent = false
	for w: WrestlerController in [self, opponent]:
		w._restart_state_clip(WrestlerFSM.State.GRAPPLE_HOLD, CHAIN_READ_CLIP)


## The read is played in the collar-and-elbow.
const CHAIN_READ_CLIP := "strikes/tie_up_collar"


# --- the corner (gauntlet/refs/animation_gap.md, Phase 4: position) ----------
#
# A man knocked back into a corner does not stagger free: the turnbuckle stops
# him, and he is trapped against it -- arms hooked over the top rope, chin on
# his chest -- while the other man works him over. Every blow landed on him
# there is taken in the corner (Corner_Hit) and keeps him in it, up to
# CORNER_HITS_MAX; the next one after that, or the clock running out, lets him
# out. A running attack into a trapped man is the corner charge.
#
# Deterministic: where he is and where the blow came from decide it, both read
# off the two bodies' origins, never the skeleton.

## Both |x| and |z| past this, and a man is in a corner's reach.
const CORNER_ZONE := 1.85
## Where a trapped man's origin is put, on both axes: keep_inside_the_ring()'s
## own limit, which backs him into the buckle.
const CORNER_SPOT := 2.6
## How squarely a blow has to drive him at the corner: the cosine between the
## blow's line and the diagonal into it.
const CORNER_DRIVE_MIN := 0.2
## Trapped on the first blow, and again on each blow taken there (the clip
## lengths: corner_slump and corner_hit in strike_recipes.gd).
const CORNER_TRAP_TICKS := 90
const CORNER_HIT_TICKS := 60
## Blows he takes in the corner before the next one gets him out.
const CORNER_HITS_MAX := 3
## Ticks to be driven back into the buckle from where he was hit.
const CORNER_SLIDE_TICKS := 8
## Once out of the corner he cannot be trapped in one again for this long.
## Out of the trap he is still standing in the corner with the other man in
## front of him, so without it the next blow trapped him straight back: one
## seeded match (reversal_tally seed 1) looped 62 traps and never finished.
const CORNER_LOCKOUT_TICKS := 240

var _corner_trapped := false
var _corner_hits := 0
var _corner_spot := Vector3.ZERO
var _corner_slide := 0
## Ticks left before he can be trapped in a corner again.
var _corner_lockout := 0


## Trapped in a corner right now.
func is_corner_trapped() -> bool:
	return _corner_trapped and fsm.current_state == WrestlerFSM.State.STUNNED


## The spot in the corner a blow from `from` drives a man at `pos` into, or a
## non-finite vector when it does not drive him into one.
static func corner_behind(pos: Vector3, from: Vector3) -> Vector3:
	if absf(pos.x) < CORNER_ZONE or absf(pos.z) < CORNER_ZONE:
		return Vector3.INF
	var away := Vector3(pos.x - from.x, 0.0, pos.z - from.z)
	var into := Vector3(signf(pos.x), 0.0, signf(pos.z)).normalized()
	if away.length() < 0.001 or away.normalized().dot(into) < CORNER_DRIVE_MIN:
		return Vector3.INF
	return Vector3(signf(pos.x) * CORNER_SPOT, pos.y, signf(pos.z) * CORNER_SPOT)


## Takes this blow in the corner, if it is one: returns whether it did.
func _try_corner_trap() -> bool:
	if opponent == null:
		return false
	if is_corner_trapped():
		if _corner_hits >= CORNER_HITS_MAX:
			return false
		_corner_hits += 1
		_move_ticks_remaining = CORNER_HIT_TICKS
		_restart_state_clip(WrestlerFSM.State.STUNNED, "strikes/corner_hit")
		return true
	if _corner_lockout > 0 \
			or not WrestlerFSM.LEGAL_TRANSITIONS[fsm.current_state].has(WrestlerFSM.State.STUNNED):
		return false
	var spot := corner_behind(global_position, opponent.global_position)
	if not spot.is_finite():
		return false
	_corner_spot = spot
	_corner_hits = 0
	_corner_slide = CORNER_SLIDE_TICKS
	_set_state_clip(WrestlerFSM.State.STUNNED, "strikes/corner_slump")
	_start_move(WrestlerFSM.State.STUNNED, _timed_stub(CORNER_TRAP_TICKS))
	_corner_trapped = true
	return true


## Each tick trapped: driven back into the buckle, then held there facing out.
func _tick_corner_trap() -> void:
	var dt := 1.0 / Engine.physics_ticks_per_second
	var to := Vector3(_corner_spot.x - global_position.x, 0.0, _corner_spot.z - global_position.z)
	if _corner_slide > 0:
		velocity = to / (_corner_slide * dt)
		_corner_slide -= 1
	else:
		velocity = to / dt if to.length() > 0.01 else Vector3.ZERO
	_knockback_ticks = 0
	var out := Vector3(-signf(_corner_spot.x), 0.0, -signf(_corner_spot.z))
	look_at(global_position + out, Vector3.UP)


## Restarts a state's clip from its first frame while already in the state --
## a travel() to the state he is in is a no-op (see play_paired_pose()).
func _restart_state_clip(state: WrestlerFSM.State, clip: String) -> void:
	if not _anim_playback or not anim_player or not anim_player.has_animation(clip):
		return
	var state_machine := anim_tree.tree_root as AnimationNodeStateMachine
	var state_name: String = WrestlerFSM.State.keys()[state]
	if not state_machine.has_node(state_name):
		return
	var anim_node := state_machine.get_node(state_name) as AnimationNodeAnimation
	if not anim_node:
		return
	anim_node.animation = clip
	_inertialize(state_name)
	_anim_playback.start(state_name, true)


# --- rope breaks (gauntlet/refs/animation_gap.md, Phase 4: position) ---------
#
# A man pinned or held near the ropes gets a hand or a foot on them, and the
# referee breaks it (MatchReferee). Whether he can is read off his origin and
# facing -- where his hands and feet can get to lying there -- never off the
# skeleton, so the same match always breaks the same counts.

## Where a man lying down can reach, in his own frame (his head is up -Z,
## MatchReferee's cover measurements): a hand stretched past his head, a hand
## out to either side, a foot either side.
const ROPE_REACH_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, -1.25),
	Vector3(0.85, 0.0, -0.45), Vector3(-0.85, 0.0, -0.45),
	Vector3(0.2, 0.0, 1.0), Vector3(-0.2, 0.0, 1.0),
]
## A reach that gets this far out is on the rope: the rope line is at
## RingBuilder.ROPE_SPAN 3.1, and a hand closes round it from inside.
const ROPE_TOUCH := 2.98
## States he keeps hold of the rope in once he has it.
const ROPE_HOLD_STATES: Array = [
	WrestlerFSM.State.PIN_DEFENDER, WrestlerFSM.State.SUBMISSION_DEFENDER,
	WrestlerFSM.State.DOWN,
]


## The outward normal of the rope side a man lying at `w` can reach, or ZERO.
static func rope_within_reach(w: Node3D) -> Vector3:
	var best := Vector3.ZERO
	var best_out := ROPE_TOUCH
	for p in ROPE_REACH_POINTS:
		var q := w.global_transform * p
		if absf(q.x) >= best_out:
			best_out = absf(q.x)
			best = Vector3(signf(q.x), 0.0, 0.0)
		if absf(q.z) >= best_out:
			best_out = absf(q.z)
			best = Vector3(0.0, 0.0, signf(q.z))
	return best


## Reaches for the ropes on `side`, getting there in `ticks`.
func reach_for_rope(side: Vector3, ticks: int) -> void:
	if rope_reach:
		rope_reach.reach(side, ticks)


# --- ground attacks (gauntlet/refs/animation_gap.md, Phase 4: position) -------
#
# A man down is worked before he is covered, and what he gets depends on where
# the other man is standing: at his feet, a stomp to the legs -- the damage
# Cody's Figure-Four is built on; beside him, a stomp to the body; at his
# head, a fist driven down from one knee. MatchReferee starts one when the
# standing man is in reach of one of those three, up to GROUND_ATTACKS_MAX
# per knockdown; the man on the mat stays down while he takes them.

const GROUND_STOMP_LEGS := preload("res://resources/moves/ground_stomp_legs.tres")
const GROUND_STOMP_BODY := preload("res://resources/moves/ground_stomp_body.tres")
const GROUND_FIST := preload("res://resources/moves/ground_fist.tres")
const GROUND_PICKUP := preload("res://resources/moves/ground_pickup.tres")
## 2 -> 4 with the longer downs (DOWN_TICKS_*): the man in control works him.
const GROUND_ATTACKS_MAX := 4
## Along a downed man from his pelvis (his own -Z is toward his head): past
## HEAD_ZONE_Z he is at the head, past LEGS_ZONE_Z at the legs.
const HEAD_ZONE_Z := -0.55
const LEGS_ZONE_Z := 0.30
## Where the attacker stands from the point he hits: the stomping boot and the
## fist both land this far in front of him (Ground_Stomp / Ground_Fist).
const GROUND_REACH := 0.45
## And how near he has to be to it for a ground attack to start at all.
const GROUND_START_RANGE := 0.9
## Ticks he takes to step onto his mark as it starts.
const GROUND_STEP_TICKS := 6
## A man hit on the mat stays down at least this much longer.
const GROUND_HOLD_DOWN_TICKS := 30

## Ground blows he takes before the man in control hauls him up, how close to
## his head that man stands to do it, and whether this knockdown's haul is spent.
const PICKUP_AFTER_ATTACKS := 2
const PICKUP_REACH := 0.35
var picked_up := false
var ground_attacks_taken := 0
var _ground_zone := ""
var _ground_step_left := 0
var _ground_step: Vector3 = Vector3.ZERO


## Which part of a downed `victim` a man standing at `pos` is at.
static func downed_zone(victim: WrestlerController, pos: Vector3) -> String:
	return zone_along_body((victim.global_transform.affine_inverse() * pos).z)


## The zone at `z` metres along a downed man from his pelvis, toward his feet.
static func zone_along_body(z: float) -> String:
	if z <= HEAD_ZONE_Z:
		return "head"
	if z >= LEGS_ZONE_Z:
		return "legs"
	return "body"


static func ground_move_for(zone: String) -> MoveDef:
	match zone:
		"head": return GROUND_FIST
		"legs": return GROUND_STOMP_LEGS
	return GROUND_STOMP_BODY


## The point on a downed man a ground attack in `zone` lands on, on the mat.
static func ground_target(victim: WrestlerController, zone: String) -> Vector3:
	var bone := {"head": "Head", "legs": "calf_r", "body": "spine_02"}[zone] as String
	var sk := victim.skeleton
	var p := victim.global_position
	if sk:
		var i := sk.find_bone(victim._skeleton_bone_name(bone))
		if i >= 0:
			p = sk.global_transform * sk.get_bone_global_pose(i).origin
	p.y = victim.global_position.y
	return p


## Whether a ground attack can start now on `victim`, from here.
func can_ground_attack(victim: WrestlerController) -> bool:
	if not DOWNED_STATES.has(victim.fsm.current_state) or victim.fsm.current_state != WrestlerFSM.State.DOWN:
		return false
	if victim.ground_attacks_taken >= GROUND_ATTACKS_MAX:
		return false
	var zone := downed_zone(victim, global_position)
	var move := ground_move_for(zone)
	if victim._move_ticks_remaining < move.startup_frames + 6:
		return false
	var flat := ground_target(victim, zone) - global_position
	flat.y = 0.0
	return flat.length() <= GROUND_START_RANGE


func begin_ground_attack(victim: WrestlerController) -> void:
	var zone := downed_zone(victim, global_position)
	var move := ground_move_for(zone)
	var target := ground_target(victim, zone)
	var flat := target - global_position
	flat.y = 0.0
	var dir := flat.normalized() if flat.length() > 0.01 else -global_basis.z
	look_at(global_position + dir, Vector3.UP)
	_play_strike_clip(move)
	_start_move(WrestlerFSM.State.STRIKE, move)
	combat.spend_stamina(CombatSystem.STAMINA_PER_STRIKE_TICK * move.total_frames())
	_ground_zone = zone
	# Onto his mark over the first few ticks: GROUND_REACH short of the point.
	var mark := target - dir * GROUND_REACH
	_ground_step = (mark - global_position) / float(GROUND_STEP_TICKS)
	_ground_step.y = 0.0
	_ground_step_left = GROUND_STEP_TICKS
	# He is going nowhere while he is being worked.
	victim._move_ticks_remaining = maxi(victim._move_ticks_remaining,
			move.startup_frames + GROUND_HOLD_DOWN_TICKS)


## Whether `victim`, down, is to be hauled to his feet from here: worked over
## enough, the time left long enough for the whole haul, and the man in control
## at his head (not the cover, which is the referee's call).
func can_pickup(victim: WrestlerController) -> bool:
	if victim.fsm.current_state != WrestlerFSM.State.DOWN or victim.picked_up:
		return false
	if victim.ground_attacks_taken < PICKUP_AFTER_ATTACKS:
		return false
	if victim._move_ticks_remaining < PICKUP_TICKS + 30:
		return false
	var flat := ground_target(victim, "head") - global_position
	flat.y = 0.0
	return flat.length() <= GROUND_START_RANGE


## Hauls `victim` up by the arms: he rises on the paired clip while this man
## draws him up, and is left on his feet and hurt, an arm's length off.
func begin_pickup(victim: WrestlerController) -> void:
	var target := ground_target(victim, "head")
	var flat := target - global_position
	flat.y = 0.0
	var dir := flat.normalized() if flat.length() > 0.01 else -global_basis.z
	look_at(global_position + dir, Vector3.UP)
	_play_strike_clip(GROUND_PICKUP)
	_start_move(WrestlerFSM.State.STRIKE, GROUND_PICKUP)
	_ground_zone = "pickup"
	var mark := target - dir * PICKUP_REACH
	_ground_step = (mark - global_position) / float(GROUND_STEP_TICKS)
	_ground_step.y = 0.0
	_ground_step_left = GROUND_STEP_TICKS
	victim.picked_up = true
	victim._set_state_clip(WrestlerFSM.State.GETUP, "strikes/getup_hauled")
	victim.fsm.transition_to(WrestlerFSM.State.GETUP)
	victim._move_ticks_remaining = PICKUP_TICKS


func _tick_ground_step() -> void:
	if _ground_step_left <= 0:
		velocity = Vector3.ZERO
		return
	_ground_step_left -= 1
	velocity = _ground_step * float(Engine.physics_ticks_per_second)


## A ground attack landing on this man, down.
func _take_ground_hit(attacker: WrestlerController, move: MoveDef, zone: String) -> void:
	ground_attacks_taken += 1
	combat.apply_damage(move, CombatSystem.COMEBACK_DAMAGE_SCALE if attacker.combat.is_fired_up() else 1.0)
	_took_moves(1)
	attacker.combat.apply_momentum(move)
	attacker.move_landed.emit(attacker, self, move)
	_move_ticks_remaining = maxi(_move_ticks_remaining, GROUND_HOLD_DOWN_TICKS)
	if hit_flinch:
		hit_flinch.hit(attacker.global_position, zone, HitFlinch.strength_of(move))


# --- reversals (gauntlet/refs/animation_gap.md, Phase 4) ---------------------
#
# A strike can be read: pressed inside its window (MoveDef.reversal_window_*,
# measured frames around its contact, opened REVERSAL_LEAD frames early so a
# man can commit before the fist arrives), the defender parries it off line
# and counters down the gap it opened (strike_parry, Parry_Counter). Too early
# or at nothing and he is locked out for REVERSAL_LOCKOUT ticks -- guessing is
# the one thing it must not reward. Every attempt costs stamina, and the AI's
# chance of reading one scales with his (WrestlerAI._roll_reversal).
#
# The old counters were cut because a strike simply vanished. This one is two
# beats nobody can miss: a forearm up that sweeps the punch aside, and a
# straight right to the jaw that the striker flinches from.

const REVERSAL_MOVE := preload("res://resources/moves/strike_parry.tres")
const REVERSAL_LEAD := 6
const REVERSAL_LOCKOUT := 30
## States he can parry from: on his feet with his hands free.
const CAN_REVERSE := [WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION]

var _reversal_armed := false
var _reversal_lockout := 0
## Reversals landed, for probes and the HUD.
var reversals_landed := 0


## Whether `move`, thrown by `striker`, is at a frame a reversal can read.
static func in_reversal_window(move: MoveDef, frame: int) -> bool:
	return move != null and move.reversal_window_end > 0 \
			and frame >= move.reversal_window_start - REVERSAL_LEAD \
			and frame <= move.reversal_window_end


func _read_reversal(input: Dictionary) -> void:
	if _reversal_lockout > 0:
		_reversal_lockout -= 1
	if _reversal_armed and (opponent == null or opponent.fsm.current_state != WrestlerFSM.State.STRIKE):
		# The strike he read never arrived (missed, or cut short).
		_reversal_armed = false
	if not input.get("reversal", false) or _reversal_lockout > 0 or _reversal_armed:
		return
	combat.spend_stamina(CombatSystem.STAMINA_REVERSAL)
	var striker := opponent
	if striker and striker.fsm.current_state == WrestlerFSM.State.STRIKE and striker._active_move \
			and in_reversal_window(striker._active_move, striker.strike_frame()):
		_reversal_armed = true
	else:
		_reversal_lockout = REVERSAL_LOCKOUT


## Frames into the strike he is throwing.
func strike_frame() -> int:
	return _active_move.total_frames() - _move_ticks_remaining if _active_move else -1


## Called by the striker at contact. True if this man read it: he parries and
## counters, and the strike does nothing.
func _take_reversal(striker: WrestlerController, move: MoveDef) -> bool:
	if not _reversal_armed:
		return false
	_reversal_armed = false
	if not CAN_REVERSE.has(fsm.current_state):
		return false
	reversals_landed += 1
	_turn_toward_opponent()
	_play_strike_clip(REVERSAL_MOVE)
	_start_move(WrestlerFSM.State.STRIKE, REVERSAL_MOVE)
	reversed.emit(self, striker, move)
	return true


## Stamina's per-tick ledger: running costs, standing and lying win it back.
func _tick_stamina() -> void:
	match fsm.current_state:
		WrestlerFSM.State.RUN:
			combat.spend_stamina(CombatSystem.STAMINA_RUN_TICK)
		WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION:
			combat.regen_stamina(CombatSystem.STAMINA_REGEN_TICK)
		WrestlerFSM.State.DOWN, WrestlerFSM.State.GETUP:
			combat.regen_stamina(CombatSystem.STAMINA_REGEN_DOWN_TICK)


## Whether this hit knocks the wrestler down, rather than staggering him.
func _would_be_knocked_down() -> bool:
	return combat.wear - _damage_at_last_knockdown >= KNOCKDOWN_DAMAGE

## Called by MatchReferee once every wrestler has finished its own
## _physics_process for this tick.
func _resolve_pending_hits() -> void:
	if _pending_hits.is_empty():
		return
	# The wrestler may have moved into an unhittable state (e.g. its own
	# pin cover) between when this hit was queued and now — drop the
	# reaction (not the damage numbers, which are harmless) rather than
	# force an illegal FSM transition.
	var moves := _pending_hits.duplicate()
	_pending_hits.clear()
	if UNHITTABLE_STATES.has(fsm.current_state):
		return
	# The only hitter is the other man, so his comeback decides the scale.
	var hitter_fired_up := opponent != null and opponent.combat.is_fired_up()
	for move in moves:
		combat.apply_damage(move, CombatSystem.COMEBACK_DAMAGE_SCALE if hitter_fired_up else 1.0)
	_took_moves(moves.size())
	# Every blow that lands shows on him, whatever he is doing -- mid-punch
	# included, where the reaction clip has to wait (below). A man fired up
	# no-sells: he takes it without giving.
	if hit_flinch and opponent and not combat.is_fired_up():
		var last: MoveDef = moves[moves.size() - 1]
		var strength := HitFlinch.strength_of(last)
		hit_flinch.hit(opponent.global_position, HitFlinch.zone_of(last), strength)
		var stop := hit_stop_ticks_for(strength)
		if stop > 0:
			hit_stop(stop)
			opponent.hit_stop(stop)
	if _would_be_knocked_down():
		# Dropped mid-swing: the punch dies with him, so nothing is held over.
		_pending_hit_reaction = null
		_go_down()
		return
	# A punch already thrown lands. Measured with
	# tools/probe/strike_connect_probe.tscn over seeds 1-3 before this: of 64
	# strikes thrown, only 33 landed, and the reason was NOT spacing -- zero
	# were out of range. 22 of them were INTERRUPTED, cancelled mid-wind-up by
	# taking a hit, so they never reached the frames where contact is tested.
	# Both men throw at once, the first contact frame to land cancels the
	# other's punch, and what that looks like on screen is a wrestler winding
	# up and then nothing happening -- a punch that does not connect, and an
	# opponent who never reacts because he was never hit.
	#
	# So the damage still applies this instant (the exchange is still decided
	# by who lands first), but the reaction WAITS for the punch to finish
	# rather than eating it. Both men connect and both then react, which is
	# what trading blows actually looks like. A knockdown still interrupts --
	# a man dropped mid-swing is not finishing the swing.
	# Fired up, he no-sells: the damage is real, but he does not flinch. The
	# man beating him down watches his offence stop working -- the first
	# beat of every comeback.
	if combat.is_fired_up():
		return
	if fsm.current_state == WrestlerFSM.State.STRIKE:
		_pending_hit_reaction = moves[moves.size() - 1]
		return
	_begin_hit_reaction(moves[moves.size() - 1])

## Keeps the heat count (CombatSystem.unanswered_hits): this wrestler has
## just taken count moves, and the man who landed them has answered him.
func _took_moves(count: int) -> void:
	combat.unanswered_hits += count
	if opponent:
		opponent.combat.unanswered_hits = 0

## Starts this wrestler's comeback -- see CombatSystem's comeback section.
## Called by MatchReferee, which decides when one is earned.
func fire_up() -> void:
	combat.start_comeback()
	fired_up.emit(self)

## Takes a hit: the reaction clip, the state, and the shove that sells it.
##
## The shove is set AFTER _start_move(), which zeroes velocity -- setting it
## before would be silently thrown away. It then survives because
## _process_timed_state() leaves velocity alone and move_and_slide() consumes
## whatever is there, which is the same mechanism that used to let stale
## velocity leak across states (see _start_move()'s own note) -- used
## deliberately here, and decayed to nothing rather than left running.
func _begin_hit_reaction(move: MoveDef) -> void:
	# Backed into a corner, the turnbuckle takes it: trapped there, or hit
	# again while he is.
	if _try_corner_trap():
		return
	# Hit by a man in the middle of his comeback, he is rocked -- the longer
	# STUNNED stagger, not a flinch -- so the run can string together. The
	# state existed, with its clip, and nothing had ever entered it.
	# STUNNED is not legal out of every state HIT_REACT is (a second stagger,
	# a getup, a tie-up); those take the ordinary reaction.
	var selling := sell_ticks > 0 or fsm.current_state == WrestlerFSM.State.HIT_REACT
	_flurry_hits = _flurry_hits + 1 if selling else 1
	var rocked := _flurry_hits >= FLURRY_STUN_AT
	if (rocked or opponent and opponent.combat.is_fired_up()) \
			and WrestlerFSM.LEGAL_TRANSITIONS[fsm.current_state].has(WrestlerFSM.State.STUNNED):
		if rocked:
			_flurry_hits = 0
		_start_move(WrestlerFSM.State.STUNNED, _timed_stub(STUNNED_TICKS))
	else:
		_play_hit_reaction(move)
		_start_move(WrestlerFSM.State.HIT_REACT, _timed_stub(HIT_REACT_TICKS))
	var away := Vector3.ZERO
	if opponent:
		away = global_position - opponent.global_position
		away.y = 0.0
	if away.length() < 0.001:
		# Coincident, or no opponent: shove him onto his own back foot rather
		# than picking a direction at random.
		away = global_transform.basis.z
		away.y = 0.0
	if away.length() < 0.001:
		return
	velocity = away.normalized() * KNOCKBACK_SPEED
	_knockback_ticks = KNOCKBACK_TICKS

## Points the STRIKE state at this strike's own clip before entering it.
##
## Every strike played the same jab regardless of which MoveDef was thrown,
## so a kick and a punch were the same animation with different numbers
## attached. A move with no generated clip keeps whatever the state already
## had, which is the jab.
## Puts this wrestler into his celebration. Called by MatchSetup off the
## referee's match_won, for the winner only.
##
## VICTORY is terminal in WrestlerFSM, so this is one-way: it stops the AI
## (there is nobody left to fight), cancels anything in flight, and lets the
## clip hold its final pose. Idempotent, because the referee guards
## _match_over but a replay or a probe may call it twice.
## Plays a clip that belongs to no FSM state -- the ring entrance's walk,
## climb and rope step -- while the controller is frozen for the entrance.
##
## The AnimationTree has one node per state and nothing else, so this borrows
## the IDLE and LOCOMOTION nodes, alternating between them so every change is
## a travel() and therefore a cross-fade rather than a pop. end_presentation()
## puts both back before the bell.
var _presentation_node := "IDLE"
var _presentation_clip := ""

## `cut` starts the clip on its first frame with no crossfade -- for a clip
## whose first frame IS the last one's pose seen from a root that has just
## been turned round (DiveSpot's rope rebound, which ends running the other
## way). Crossfaded, the hips would blend 180 degrees of yaw back to 0 and
## the man would spin on the spot.
func play_presentation_clip(clip: String, cut := false) -> void:
	if not anim_tree or clip == _presentation_clip \
			or not anim_player.has_animation(clip):
		return
	var machine := anim_tree.tree_root as AnimationNodeStateMachine
	var next := "LOCOMOTION" if _presentation_node == "IDLE" else "IDLE"
	var node := machine.get_node(next) as AnimationNodeAnimation
	if node == null:
		return
	node.animation = clip
	if cut:
		_anim_playback.start(next, true)
	else:
		_inertialize(next)
		_anim_playback.travel(next)
	_presentation_node = next
	_presentation_clip = clip


## `keep_pose`: hand the state machine back without cutting to IDLE, so the
## next state the match puts him in is carried from the pose he is in
## (TopRopeSpot: lying across the man, into the cover).
func end_presentation(keep_pose := false) -> void:
	if not anim_tree:
		return
	var machine := anim_tree.tree_root as AnimationNodeStateMachine
	for state: WrestlerFSM.State in [WrestlerFSM.State.IDLE,
			WrestlerFSM.State.LOCOMOTION]:
		var node := machine.get_node(WrestlerFSM.State.keys()[state]) \
				as AnimationNodeAnimation
		if node:
			node.animation = clip_for_state(state, false)
	_presentation_node = "IDLE"
	_presentation_clip = ""
	if not keep_pose:
		_anim_playback.start("IDLE", true)


func celebrate() -> void:
	if fsm.current_state == WrestlerFSM.State.VICTORY:
		return
	_active_move = null
	_pending_hit_reaction = null
	velocity = Vector3.ZERO
	if ai:
		ai.set_physics_process(false)
	fsm.transition_to(WrestlerFSM.State.VICTORY)


## The winner's arm taken up by the referee: swaps VICTORY's clip for
## Win_Arm_Raised (his left wrist in her hand). Only valid once celebrate() has
## put him in VICTORY.
func raise_arm() -> void:
	if fsm.current_state != WrestlerFSM.State.VICTORY or not anim_tree \
			or not anim_player.has_animation("strikes/win_arm_raised"):
		return
	var machine := anim_tree.tree_root as AnimationNodeStateMachine
	var node := machine.get_node("VICTORY") as AnimationNodeAnimation
	if node == null or node.animation == "strikes/win_arm_raised":
		return
	node.animation = "strikes/win_arm_raised"
	_anim_playback.start("VICTORY", true)


func _play_strike_clip(move: MoveDef) -> void:
	_set_state_clip(WrestlerFSM.State.STRIKE,
			StrikeRecipes.clip(String(move.animation_pair_id)) if move else "")

## Points the HIT_REACT state at a head or torso reaction before entering
## it, from where the landed move actually did its damage.
##
## Every hit played Hit_Chest before this -- a jab to the jaw and a
## spinebuster to the ribs produced the same flinch -- which is most of why
## strikes read as not connecting to anything in particular.
func _play_hit_reaction(move: MoveDef) -> void:
	var reaction := StrikeRecipes.reaction_for(move)
	_set_state_clip(WrestlerFSM.State.HIT_REACT, reaction)
	_sell_clip = StrikeRecipes.sell_for(reaction)

## Swaps which clip a state's node plays, before the FSM enters it. The
## AnimationTree is built once from STATE_ANIMATIONS, so this is how a state
## that needs more than one clip gets one -- the same approach
## play_paired_pose() uses to give each grapple role its own performance.
## Counts the sell down. It ends early the moment he leaves IDLE (he did
## something, or was hit again); run out in IDLE, he goes back to the stance
## he loops on, carried in by the Inertializer.
func _tick_sell() -> void:
	if sell_ticks <= 0:
		return
	if fsm.current_state != WrestlerFSM.State.IDLE:
		sell_ticks = 0
		return
	sell_ticks -= 1
	if sell_ticks == 0:
		_restart_state_clip(WrestlerFSM.State.IDLE,
				clip_for_state(WrestlerFSM.State.IDLE, _is_grapple_attacker))


func _set_state_clip(state: WrestlerFSM.State, clip: String) -> void:
	if not anim_tree or clip == "" or not anim_player.has_animation(clip):
		return
	_state_clip_override[state] = clip

func _timed_stub(ticks: int) -> MoveDef:
	var stub := MoveDef.new()
	stub.startup_frames = ticks
	stub.active_frames = 0
	stub.recovery_frames = 0
	return stub

func _process_grapple_hold(input: Dictionary) -> void:
	if not _is_grapple_attacker:
		# The defender has nothing to press while the attacker's paired move
		# plays: he waits it out. Between chain links he may reverse.
		_tick_chain_counter(input)
		return
	if input.get("run", false):
		_begin_irish_whip()
		return
	# Chain wrestling first: the read, and the holds it strings together.
	if _tick_chain_read(input):
		return
	# Pick the rung FIRST, then ask whether it can be thrown.
	#
	# This used to test grapple_move -- the BASE rung -- before choosing a
	# tier, which quietly made the whole grapple chain depend on the bottom of
	# it: with no base grapple move the guard returned early every tick, so a
	# signature or finisher the momentum ladder had earned could never be
	# thrown either. That is fine while the base rung is always populated and
	# wrong the moment it is not, which is exactly what removing the three
	# throw-style grapples does.
	var move: MoveDef = null
	if combat.can_finisher() and finisher_move:
		move = _pick_tier_move(finisher_move, finisher_move_pool)
	elif combat.can_signature() and signature_move:
		if own_signature and not _own_signature_thrown \
				and opponent.weight_class >= own_signature.weight_class_min \
				and opponent.weight_class <= own_signature.weight_class_max:
			move = own_signature
			_own_signature_thrown = true
		else:
			move = _pick_tier_move(signature_move, signature_move_pool)
	elif combat.can_power() and power_move:
		move = _pick_tier_move(power_move, power_move_pool)
	else:
		move = _pick_tier_move(grapple_move, grapple_move_pool)

	if not move or opponent.weight_class < move.weight_class_min \
			or opponent.weight_class > move.weight_class_max:
		# Nothing this attacker can legally throw at this opponent. That was
		# a bare `return`, retried every tick with no timeout -- both
		# wrestlers held in GRAPPLE_HOLD forever, and GRAPPLE_HOLD is not a
		# state anything else pulls them out of.
		#
		# Reachable by design now rather than "one bad .tres away": with the
		# grapple rung emptied, a tie-up thrown before the ladder has earned a
		# signature has nothing to resolve to, and this is the path that ends
		# it cleanly.
		#
		# Break the hold: both sides back to IDLE, which is where a whip
		# already sends the attacker, so the match carries on and the tie-up
		# can simply happen again.
		if fsm.ticks_in_state >= GRAPPLE_HOLD_MAX_TICKS:
			_release_grapple_hold()
		return

	_active_move = move
	if grapple_rig:
		grapple_rig.begin(self, opponent, move)
		grapple_rig.grapple_finished.connect(_on_grapple_finished, CONNECT_ONE_SHOT)
	else:
		_resolve_grapple_move(move)

## Which rung of the grapple chain a move belongs to, or -1 for anything
## that isn't one (a strike, a running attack). There is no tier
## field on MoveDef -- a move's tier is which slot it was drawn from -- so
## the man who threw it is the one who can say.
func tier_of(move: MoveDef) -> int:
	if move == null:
		return -1
	if move == finisher_move or finisher_move_pool.has(move):
		return CombatSystem.Tier.FINISHER
	if move == signature_move or signature_move_pool.has(move):
		return CombatSystem.Tier.SIGNATURE
	if move == power_move or power_move_pool.has(move):
		return CombatSystem.Tier.POWER
	if move == grapple_move or grapple_move_pool.has(move):
		return CombatSystem.Tier.GRAPPLE
	return -1

## Whether a move is one of this wrestler's finishers — asked by MatchCamera
## to know whether a cut is worth taking.
func is_finisher(move: MoveDef) -> bool:
	return tier_of(move) == CombatSystem.Tier.FINISHER

## Draws one move from a tier: the tier's guaranteed move plus whatever its
## pool adds, filtered to what this opponent's weight class allows.
##
## Seeded rather than random, because a paired move's outcome feeds damage
## and momentum and therefore the match: the same (match_seed, player_index,
## draw count) must always produce the same move, or replays stop matching.
## The multipliers are deliberately different from WrestlerAI._should_whip()'s
## so the two decisions don't move in lockstep across a match.
## Strike strings (gauntlet/refs/match_aaa_plan.md): 2K26's strikes come in
## combinations -- right, right, then the big one -- not one random shot per
## press. A strike thrown within STRING_WINDOW_TICKS of the last one landing
## carries the string on: the second is a light shot again, the third the
## heaviest he has. Out of a string, the draw is the tier draw as before.
const STRING_WINDOW_TICKS := 60
const STRING_LENGTH := 3
var _string_hits := 0
var _string_last := -1000
var _string_clock := 0


func _pick_string_strike() -> MoveDef:
	if corner_strike_move and opponent and opponent.is_corner_trapped():
		return corner_strike_move
	if _string_hits <= 0 or _string_clock - _string_last > STRING_WINDOW_TICKS \
			or strike_move_pool.is_empty():
		_string_hits = 0
		return _pick_tier_move(strike_move, strike_move_pool)
	var choices: Array[MoveDef] = [strike_move]
	for candidate: MoveDef in strike_move_pool:
		if candidate and opponent.weight_class >= candidate.weight_class_min \
				and opponent.weight_class <= candidate.weight_class_max:
			choices.append(candidate)
	choices.sort_custom(func(x: MoveDef, y: MoveDef) -> bool:
		return StrikeRecipes.total_damage(x) < StrikeRecipes.total_damage(y))
	if _string_hits >= STRING_LENGTH - 1:
		return choices[choices.size() - 1]
	# Still light: the lighter half, the shot he did not just throw first.
	var light := choices.slice(0, maxi(1, choices.size() / 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 8192 + player_index * 131 + _tier_draws
	_tier_draws += 1
	return light[rng.randi_range(0, light.size() - 1)]


## A strike of his landed: the string goes on, or ends on its heavy shot.
func _count_string_hit() -> void:
	_string_hits = 0 if _string_hits + 1 >= STRING_LENGTH else _string_hits + 1
	_string_last = _string_clock


func _pick_tier_move(primary: MoveDef, pool: Array[MoveDef]) -> MoveDef:
	if pool.is_empty():
		return primary
	var choices: Array[MoveDef] = [primary]
	for candidate: MoveDef in pool:
		if not candidate:
			continue
		if opponent.weight_class < candidate.weight_class_min:
			continue
		if opponent.weight_class > candidate.weight_class_max:
			continue
		choices.append(candidate)
	if choices.size() == 1:
		return primary
	var rng := RandomNumberGenerator.new()
	rng.seed = match_seed * 8192 + player_index * 131 + _tier_draws
	_tier_draws += 1
	return choices[rng.randi_range(0, choices.size() - 1)]

## Breaks a grapple hold that produced no move, returning both wrestlers to
## a legal free state. GRAPPLE_HOLD -> IDLE is already legal for both sides
## (it is the same exit _begin_irish_whip() gives the attacker).
func _release_grapple_hold() -> void:
	_clear_grapple_roles()
	fsm.transition_to(WrestlerFSM.State.IDLE)
	if opponent and opponent.fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD:
		opponent.fsm.transition_to(WrestlerFSM.State.IDLE)

## Drops the attacker/defender roles once a grapple is over.
##
## _is_grapple_attacker used to be set only, never cleared: whoever won the
## last tie-up stayed flagged as the attacker until the *next* one
## reassigned it (MatchReferee._resolve_tie_up()). Harmless in practice
## today -- ATTACKER_STATE_ANIMATIONS only reads it inside GRAPPLE_HOLD, and
## WrestlerAI only acts on it in the same state -- but it is a latch on
## role state that outlives the role, which is the exact shape of the
## knockdown bug (a latch on a quantity that only rises; see
## _damage_at_last_knockdown and test_knockdown_is_an_event.gd). Cleared at
## the end of the grapple so the flag never describes a grapple that isn't
## happening.
func _clear_grapple_roles() -> void:
	_is_grapple_attacker = false
	if opponent:
		opponent._is_grapple_attacker = false

func _on_grapple_finished(_attacker: Node3D, _defender: Node3D) -> void:
	var move := _active_move
	_active_move = null
	last_landed_tier = tier_of(move)
	_resolve_grapple_move(move)

func _resolve_grapple_move(move: MoveDef) -> void:
	fsm.transition_to(WrestlerFSM.State.MOVE_EXEC)
	# Defender rides the same paired move (GrappleRig drove both skeletons in
	# lockstep) so it must also be in MOVE_EXEC before taking a hit reaction —
	# GRAPPLE_HOLD -> HIT_REACT/DOWN is not a legal transition on its own.
	opponent.fsm.transition_to(WrestlerFSM.State.MOVE_EXEC)
	move_landed.emit(self, opponent, move)
	combat.apply_momentum(move)
	# Recorded on landing rather than on selection: a grapple that gets
	# reversed was never thrown, so it must not unlock the rung above it.
	combat.record_tier(tier_of(move))
	# Applied directly rather than through _apply_move_to_opponent's
	# _pending_hits queue: that queue exists so MatchReferee can arbitrate
	# two wrestlers striking each other the *same* tick regardless of
	# scene-tree node order — irrelevant here, a grapple has one
	# deterministic attacker already fully resolved. Routing through it
	# broke every grapple: _resolve_pending_hits() checks the defender's
	# *own* current state before applying, and the MOVE_EXEC transition
	# just above (required to legally reach HIT_REACT/DOWN from
	# GRAPPLE_HOLD) is also, for an unrelated reason, in UNHITTABLE_STATES
	# (protecting a wrestler already mid-strike-startup from a second
	# simultaneous hit) — so every queued grapple hit was silently dropped
	# the instant it was queued, damage never accumulated, and a match
	# never progressed past tie-up -> grapple -> repeat.
	opponent.combat.apply_damage(move,
			CombatSystem.COMEBACK_DAMAGE_SCALE if combat.is_fired_up() else 1.0)
	opponent._took_moves(1)
	combat.spend_stamina(CombatSystem.STAMINA_GRAPPLE_ATTACKER)
	opponent.combat.spend_stamina(CombatSystem.STAMINA_GRAPPLE_DEFENDER)
	# The grapple is over as of here -- drop the roles before the FSM moves
	# on, so nothing downstream reads an attacker flag for a finished move.
	_clear_grapple_roles()
	fsm.transition_to(WrestlerFSM.State.IDLE)
	if move and move.defender_lands_head_away:
		opponent._turn_round_on_the_mat()
	if opponent._would_be_knocked_down():
		opponent._go_down(tier_of(move))
	elif move and move.leaves_defender_down:
		opponent._lie_down_after_throw()
	else:
		opponent._start_move(WrestlerFSM.State.HIT_REACT, opponent._timed_stub(HIT_REACT_TICKS))

## Turns a man lying on his back half round about his own pelvis, and asks
## for the next state's clip to start with no blend.
##
## For a move that lands him head away from the attacker
## (MoveDef.defender_lands_head_away): its last pose is Down_Supine's first
## turned half round, so after this turn the knockdown clip starts on exactly
## the pose already on screen. A blend here would be a blend between two
## poses 180 degrees apart in the new frame.
func _turn_round_on_the_mat() -> void:
	global_transform = Transform3D(global_transform.basis.rotated(Vector3.UP, PI),
			global_position)
	_snap_next_animation = true
	if inertializer:
		inertializer.skip_next_turn()
	_hold_model_facing()


## The body turns now, but the clip that matches it lands a tick later: a
## state machine with no crossfade outputs the old state for one more tick
## (Inertializer, measured). For that tick the man lay turned round in the
## OLD pose -- his head flashed 1.2 m to the other side of him and back
## (tools/probe/transition_pops.tscn --world, "DOWN (new clip)", 2.7 m kick).
## So the model is held facing the way it was until his hips show the new
## clip's half-turn, then let go on that same tick. Presentation only: the
## body, and everything the match reads, turned at once as before.
const MODEL_HOLD_TICKS := 4
## Ticks past the hold before it is let go whether or not the mixer ran.
const MODEL_HOLD_GRACE := 2
var _model_held := false
var _model_held_hips := Quaternion.IDENTITY
var _model_held_until := 0


func _hold_model_facing() -> void:
	var model := anim_player.get_parent() as Node3D if anim_player else null
	if model == null or skeleton == null or anim_tree == null:
		return
	var hips := skeleton.find_bone(_skeleton_bone_name("pelvis"))
	if hips < 0:
		return
	if not _model_held:
		model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * model.transform
	_model_held = true
	_model_held_hips = skeleton.get_bone_pose_rotation(hips)
	_model_held_until = Engine.get_physics_frames() + MODEL_HOLD_TICKS
	if not anim_tree.mixer_applied.is_connected(_release_model_facing):
		anim_tree.mixer_applied.connect(_release_model_facing)


func _release_model_facing(force := false) -> void:
	if not _model_held:
		return
	var hips := skeleton.find_bone(_skeleton_bone_name("pelvis"))
	var turned := _model_held_hips.angle_to(skeleton.get_bone_pose_rotation(hips)) > PI * 0.5
	if not force and not turned and Engine.get_physics_frames() < _model_held_until:
		return
	var model := anim_player.get_parent() as Node3D
	model.transform = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) * model.transform
	_model_held = false

## A thrown man left lying where the throw put him, without it counting as a
## knockdown.
##
## Everything _go_down() does beyond the state change is knockdown
## bookkeeping, and none of it applies: _damage_at_last_knockdown is what
## WrestlerAI measures "one signature from finished" against, so resetting
## it on a mid-match slam would push the finish back by a whole knockdown;
## and knocked_down is what the probes count. He is also NOT cover-eligible.
## A cover on a man who has not been knocked down is a cover he kicks out of
## at no cost, and every finish in this match is supposed to be a pinfall on
## a man who was -- _process_timed_state() restores eligibility once he is
## back on his feet.
func _lie_down_after_throw() -> void:
	_stop_dead()
	fsm.transition_to(WrestlerFSM.State.DOWN)
	ground_attacks_taken = 0
	_move_ticks_remaining = THROWN_DOWN_TICKS
	_cover_eligible = false

func _go_down(tier := -1) -> void:
	if fsm.current_state == WrestlerFSM.State.HIT_REACT or fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN, WrestlerFSM.State.STRIKE]):
		fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	_stop_dead()
	fsm.transition_to(WrestlerFSM.State.DOWN)
	ground_attacks_taken = 0
	picked_up = false
	_damage_at_last_knockdown = combat.wear
	# A knockdown is not undone: what he has taken so far cannot be healed.
	combat.heal_floor = combat.wear
	combat.green = 0.0
	_move_ticks_remaining = down_ticks_for(tier)
	knockdown_tier = tier
	combat.cut_off_comeback()
	_cover_eligible = true
	knocked_down.emit(self)

## A man on the mat goes nowhere under his own steam.
##
## The match recording showed wrestlers gliding across the ring flat on their
## backs, 3-5 m at a time. tools/probe/glitch_scan.gd caught every one of them
## the same way: knocked down out of a RUN (a running attack countered, a
## clothesline met), he entered DOWN with his 7 m/s run velocity still set --
## _go_down() changed state without touching velocity, and nothing in DOWN or
## GETUP ever did either -- so move_and_slide() carried him on, most visibly
## as he got up (he had been lying against the ropes, which held him until
## the rise lifted him off them). The grapple rig and the cover place a downed
## man by position, never by velocity, so clearing it costs nothing.
func _stop_dead() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
	_knockback_ticks = 0


func _process_down(input: Dictionary) -> void:
	_move_ticks_remaining -= 1
	# Which of the two measured rises this is depends on who ended the
	# prone state: a wrestler who pressed his way up gets the fast one, a
	# wrestler whose timer simply ran out gets the default.
	# A man who has just fired up does not lie there: he is up on the fast
	# rise whether or not anything was pressed.
	var pressed_up: bool = input.get("strike", false) \
			or (combat != null and combat.is_fired_up())
	if pressed_up or _move_ticks_remaining <= 0:
		if not pressed_up:
			_set_state_clip(WrestlerFSM.State.GETUP, "strikes/getup_staged")
		fsm.transition_to(WrestlerFSM.State.GETUP)
		_move_ticks_remaining = GETUP_RISE_FAST_TICKS if pressed_up else GETUP_STAGED_TICKS

func _process_timed_state(input: Dictionary, next_state: WrestlerFSM.State) -> void:
	# Bleed the hit's shove off. Without the decay the velocity set in
	# _begin_hit_reaction() would be consumed at full speed for the whole
	# 20-tick reaction and carry the man most of a metre.
	if _knockback_ticks > 0:
		_knockback_ticks -= 1
		velocity *= KNOCKBACK_DECAY
		if _knockback_ticks == 0:
			velocity = Vector3.ZERO
	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		# Out of a hit reaction into IDLE: sell it (SELL_TICKS).
		if fsm.current_state == WrestlerFSM.State.HIT_REACT \
				and next_state == WrestlerFSM.State.IDLE and _sell_clip != "":
			_set_state_clip(WrestlerFSM.State.IDLE, _sell_clip)
			sell_ticks = SELL_TICKS
		_sell_clip = ""
		# Also covers GETUP -> IDLE, the only place a wrestler that lost
		# _cover_eligible to a kickout (see the field's own doc comment)
		# gets it back — harmless to set unconditionally for the
		# HIT_REACT/STUNNED -> IDLE case too, since it's already true there.
		_cover_eligible = true
		fsm.transition_to(next_state)

## Where the coverer kneels, in the DOWNED man's own frame, in metres.
##
## Measured off the supine pose with tools/probe/pin_shot.tscn, which prints
## the downed man's bones in his own frame while the cover plays:
##
##   Head       local=(-0.000, +0.217, -0.686)
##   spine_03   see the probe -- the chest, about two thirds of the way up
##   pelvis     local=(+0.000, +0.184, +0.000)
##   foot_l     local=(+0.161, +0.105, +0.502)
##
## -- so the body runs up -Z, his facing, toward the head. It used to be
## offset +0.90 along +Z, measured off a pose that has since changed twice
## (first flipped end for end, then rolled face-up): by this build that put
## the coverer past the downed man's boots, which pin_shot showed as a man
## kneeling beside the other's shins.
##
## TOWARD_HEAD puts him level with the chest.
##
## LATERAL is measured to his ROOT, and the cover is a lateral press now: he
## lies face down across the man (wrestling_clips.py, Pin_Cover). In that pose
## his pelvis sits 0.16 m behind his root and his chest about 0.35 m ahead of
## the pelvis, so the chest is ~0.2 m in front of the root. At the kneel's
## 0.55 the chest landed on the mat beside the man; 0.20 lays it over his
## sternum, with the pelvis down on the mat beside his ribs.
const COVER_TOWARD_HEAD_M := 0.40
const COVER_LATERAL_M := 0.20


## Called by MatchReferee when the attacker covers a downed opponent.
func begin_pin(defender: WrestlerController, seed_value: int) -> void:
	fsm.transition_to(WrestlerFSM.State.PIN_ATTACKER)
	defender.fsm.transition_to(WrestlerFSM.State.PIN_DEFENDER)
	_place_cover(defender)
	var fraction := defender.combat.kickout_window_fraction(combat.momentum)
	defender._pin_minigame = PinMinigame.new(fraction, seed_value)
	pin_started.emit(self, defender)

## Kneels the coverer beside the downed man, facing across him.
##
## PIN_ATTACKER's per-tick handler is `pass` -- the state is driven entirely by
## MatchReferee -- so nothing ever moved the attacker once the pin began. He
## simply froze wherever the last strike left him, which is how a captured
## three-count ended up with him standing off to one side, one boot inside the
## fallen man's head.
##
## Placed relative to the DEFENDER's own frame rather than in world axes, so a
## fall in any corner of the ring covers the same way. Deterministic by
## construction: fixed offsets off another body's transform, no randomness and
## no wall-clock, so a replay puts him in the same place.
##
## Position only. The pin's outcome is the kickout minigame and the referee's
## count -- neither reads either man's position -- so this moves what the
## camera sees without touching what the match decides.
func _place_cover(defender: WrestlerController) -> void:
	# The two capsules (r 0.4) stop each other 0.8 m apart, and a man lying
	# ON another is closer than that by design -- the slide would park him
	# short of the cover. The pair stop colliding for the pin, and start again
	# only once they have separated: see _release_cover_contact().
	add_collision_exception_with(defender)
	defender.add_collision_exception_with(self)
	_cover_partner = defender
	var basis := defender.global_transform.basis
	# -Z toward the head, measured (see the constants); +X is his own left.
	var toward_head := -basis.z * COVER_TOWARD_HEAD_M
	var beside := basis.x * COVER_LATERAL_M
	var spot := defender.global_position + toward_head + beside
	# Face square across him -- perpendicular to his body, toward its
	# midline -- so the cover reads from the hard camera rather than showing
	# the coverer's back to the man he is pinning, and so his chest reaches
	# over the downed man's chest rather than angling off toward the hips.
	var target := global_transform
	target.origin = spot
	var across := -beside
	across.y = 0.0
	if across.length() > 0.01:
		target.basis = Basis(Vector3.UP, atan2(-across.x, -across.z))

	# He ARRIVES at the cover rather than appearing in it. Measured with
	# tools/probe/contact_probe.tscn: assigning the transform here was a
	# one-tick jump of up to 0.622 m for the coverer and 0.870 m for the man
	# being covered -- the second and third worst teleports left in a match
	# after the grapple entry snap was fixed.
	#
	# There is a measured window to do it in and it was being wasted:
	# MatchReferee.COUNT_TICKS[0] is 92 ticks (1.53 s) from cover to the first
	# slap, frame-stepped off real footage. The coverer used to teleport on
	# tick 0 and then kneel motionless for the whole of it. The slide happens
	# INSIDE that window and does not move the count.
	_cover_from = global_transform
	_cover_to = target
	_cover_slide_tick = 0
	_cover_slide_ticks = _cover_slide_duration(
			global_position.distance_to(spot))

# ---------------------------------------------------------------------------
# A downed man's body
# ---------------------------------------------------------------------------
#
# A man lying on the mat is still an upright 0.4 m capsule at his pelvis --
# GrappleRig treats lying down as a pose, not a body orientation -- so his
# legs and his head collide with nothing. On the owner's match video his
# raised shins went through the standing man's thigh and chest.
# tools/probe/limb_clearance.tscn measured it: up to 0.12 m of leg inside the
# other body, 259 visible ticks over five seeds, almost all of it with the
# standing man walking, striking or idling over him.
#
# So a downed man has a FOOTPRINT: the line his body lies along, head to
# feet, and a standing wrestler is kept a clearance off it.

## The states a man is on the mat in, legs out.
const DOWNED_STATES: Array[WrestlerFSM.State] = [
	WrestlerFSM.State.DOWN, WrestlerFSM.State.PIN_DEFENDER,
	WrestlerFSM.State.SUBMISSION_DEFENDER, WrestlerFSM.State.GETUP,
]
## The states that are ALLOWED on top of him: the cover and the hold are
## contact by design, and a paired move or the lock-up places both bodies
## through GrappleRig.
const ON_TOP_STATES: Array[WrestlerFSM.State] = [
	WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.SUBMISSION_ATTACKER,
	WrestlerFSM.State.GRAPPLE_HOLD, WrestlerFSM.State.MOVE_EXEC,
	WrestlerFSM.State.FINISHER, WrestlerFSM.State.TIE_UP,
	WrestlerFSM.State.VICTORY,
]
## His body in his own frame, off his root: the head end up -Z, the feet down
## +Z. The supine pose puts Head at -0.69 and the feet at +0.50
## (tools/probe/pin_shot.tscn); a little past both, for the hair and the boots.
const BODY_HEAD_M := 0.75
const BODY_FEET_M := 0.65
## How far a standing wrestler's ROOT stays off that line: his own body
## (a 0.4 m capsule, but a torso is ~0.18 m deep) plus the downed man's limbs
## either side of the line, knees up. Read off limb_clearance.
const BODY_CLEAR_M := 0.55
## The most the guard corrects in one tick. A walk is 0.058 m a tick, so this
## only ever cancels the step that would have gone in; it is not a shove.
## Bigger overlaps -- a man falling onto the spot someone is standing on --
## resolve over a few ticks rather than as a jump.
const BODY_PUSH_MAX_M := 0.06


## His head end and feet end, on the mat plane.
static func downed_body_line(w: WrestlerController) -> PackedVector3Array:
	var along := w.global_transform.basis.z
	along.y = 0.0
	along = along.normalized()
	var root := Vector3(w.global_position.x, 0.0, w.global_position.z)
	return PackedVector3Array([root - along * BODY_HEAD_M,
			root + along * BODY_FEET_M])


## The horizontal correction that takes `pos` back out to BODY_CLEAR_M off
## the line a..b, or zero if it is already clear. Pure, so it can be tested
## without a scene.
static func body_clearance_push(pos: Vector3, a: Vector3, b: Vector3) -> Vector3:
	var flat := Vector3(pos.x, 0.0, pos.z)
	var near := Geometry3D.get_closest_point_to_segment(flat, a, b)
	var off := flat - near
	var d := off.length()
	if d >= BODY_CLEAR_M:
		return Vector3.ZERO
	if d < 0.0001:
		# Dead on the line: out to his left, deterministically.
		off = (b - a).cross(Vector3.UP).normalized()
		d = 0.0
	else:
		off /= d
	return off * minf(BODY_CLEAR_M - d, BODY_PUSH_MAX_M)


## Where to stand to cover him: level with his chest, BODY_CLEAR_M out plus a
## step, on whichever side `from` is already on -- so the walk in never
## crosses the body.
##
## Unless that side is outside the ring. A man down by the ropes has only one
## side to stand on, and the spot on the far side of the ropes is one the ring
## clamp will never let anyone reach: measured on seed 4, the standing man
## walked at it for 97 ticks, pinned between the clamp and this guard with the
## downed man's legs through him. Then it is the other side, and the footprint
## guard walks him round the body to get there.
static func cover_approach_spot(victim: WrestlerController, from: Vector3) -> Vector3:
	var basis := victim.global_transform.basis
	var local := victim.global_transform.affine_inverse() * from
	var side := 1.0 if local.x >= 0.0 else -1.0
	var chest := victim.global_position - basis.z * COVER_TOWARD_HEAD_M
	var out := basis.x * (BODY_CLEAR_M + 0.15)
	var line := downed_body_line(victim)
	# Both sides, each pulled back to where a man can actually STAND -- the
	# rope colliders stop him at ~2.55, inside RING_KEEP_IN -- then the first
	# one that is genuinely clear of the body, his own side first. The second
	# pass of this fix was measured still failing on seed 4: the downed man lay
	# with his head over the ropes, so BOTH chest-side spots clamped into the
	# same corner, 0.51 m off his legs.
	var best := Vector3.ZERO
	var best_clear := -1.0
	for s: float in [side, -side]:
		var spot := chest + out * s
		spot.x = clampf(spot.x, -STANDABLE_M, STANDABLE_M)
		spot.z = clampf(spot.z, -STANDABLE_M, STANDABLE_M)
		var flat := Vector3(spot.x, 0.0, spot.z)
		var clear := flat.distance_to(
				Geometry3D.get_closest_point_to_segment(flat, line[0], line[1]))
		if clear >= BODY_CLEAR_M:
			return spot
		if clear > best_clear:
			best_clear = clear
			best = spot
	return best


## Where a wrestler can actually stand: the rope colliders stop him short of
## RING_KEEP_IN.
const STANDABLE_M := 2.45



## True when `pos` is level with his torso rather than down by his legs --
## the side of him a cover is made from. Past his hips toward his feet is not.
static func is_beside_torso(victim: WrestlerController, pos: Vector3) -> bool:
	var local := victim.global_transform.affine_inverse() * pos
	return local.z <= 0.15


## Steers this wrestler off a downed opponent's body, through velocity, before
## move_and_slide() -- the same reason _tick_cover_slide() steers velocity:
## writing the transform leaves no floor contact and he falls through the mat.
func _keep_off_downed_body(delta: float) -> void:
	if opponent == null or delta <= 0.0:
		return
	if not DOWNED_STATES.has(opponent.fsm.current_state):
		return
	if ON_TOP_STATES.has(fsm.current_state) or DOWNED_STATES.has(fsm.current_state):
		return
	var line := downed_body_line(opponent)
	var next := global_position + velocity * delta
	var push := body_clearance_push(next, line[0], line[1])
	if push == Vector3.ZERO:
		return
	velocity.x += push.x / delta
	velocity.z += push.z / delta


## The man this wrestler covered, while their capsules ignore each other.
var _cover_partner: WrestlerController = null

## Collision between the pair comes back once the pin is over AND they have
## moved apart -- never while they overlap, or the physics engine resolves the
## overlap in a single step and throws one of them across the mat.
## Two capsule radii plus a hair.
const COVER_RELEASE_M := 0.82


func _release_cover_contact() -> void:
	if _cover_partner == null or not is_instance_valid(_cover_partner):
		_cover_partner = null
		return
	if fsm.is_in([WrestlerFSM.State.PIN_ATTACKER, WrestlerFSM.State.SUBMISSION_ATTACKER]):
		return
	var apart := Vector2(global_position.x - _cover_partner.global_position.x,
			global_position.z - _cover_partner.global_position.z).length()
	if apart < COVER_RELEASE_M:
		return
	remove_collision_exception_with(_cover_partner)
	_cover_partner.remove_collision_exception_with(self)
	_cover_partner = null


## Where the cover slide starts and ends, and how far through it is. Ticked in
## _physics_process's PIN_ATTACKER branch, which is otherwise `pass` -- the
## state is driven by MatchReferee, so this is the only thing that moves him.
var _cover_from: Transform3D = Transform3D()
var _cover_to: Transform3D = Transform3D()
var _cover_slide_tick: int = -1
## How long THIS slide takes, set by _cover_slide_duration() when it is armed.
var _cover_slide_ticks: int = COVER_SLIDE_TICKS_MIN

## Shortest the cover slide is allowed to be, for a coverer who is already
## standing over the man: a step away should still read snappy. A presentation
## value rather than a measured one.
const COVER_SLIDE_TICKS_MIN := 12

## Longest it is allowed to be. MatchReferee.COUNT_TICKS[0] is 92 ticks from
## cover to the first slap, so the whole walk has to land inside that with room
## to spare -- he should be settled and still when the hand comes down, not
## arriving on the count.
const COVER_SLIDE_TICKS_MAX := 80

## How fast the coverer is allowed to travel on his way in. MOVE_SPEED, not
## RUN_SPEED: a man dropping into a cover walks the last few steps, he does not
## sprint them.
const COVER_SLIDE_SPEED := MOVE_SPEED

## Ticks to walk `distance` metres without ever exceeding COVER_SLIDE_SPEED.
##
## A fixed duration was the last real teleport in a match. _tick_cover_slide()
## eases with smoothstep, whose peak speed is 1.5x the average, so a fixed
## 12-tick slide moves at 1.5 * d / 0.2s -- fine for a cover from a step away
## and absurd for one from across the ring. Measured on seed 3
## (tools/probe/contact_probe.tscn): 6 one-tick jumps, worst 0.382 m, which is
## 22.9 m/s, over three times RUN_SPEED. Switching the ease from cubic to
## smoothstep had only taken that from 0.475 m -- because easing was never the
## problem, duration was.
##
## Solving 1.5 * d / T <= COVER_SLIDE_SPEED for T gives the line below. The
## MAX clamp is the one case that can still exceed the speed target, and only
## for covers longer than about 3.1 m; beyond that the count window matters
## more than the walking pace.
func _cover_slide_duration(distance: float) -> int:
	var needed := 1.5 * distance * float(Engine.physics_ticks_per_second) \
			/ COVER_SLIDE_SPEED
	return clampi(int(ceil(needed)), COVER_SLIDE_TICKS_MIN, COVER_SLIDE_TICKS_MAX)

## Steers the slide through VELOCITY, not by writing global_transform.
##
## The first version assigned global_transform every tick, and that is a trap
## on a CharacterBody3D: teleporting the body leaves the physics engine with no
## floor contact, so is_on_floor() reads false, _apply_gravity() keeps
## accumulating velocity.y, and the coverer falls THROUGH the mat. Measured on
## seed 3 -- he reached y = -4.81 at tick 1567 and y = -20.08 sixty ticks later,
## still in PIN_ATTACKER, while the man he was covering lay at y = 0.001.
##
## Neither standing probe could see it. floating_probe only flags a body ABOVE
## its limit, so a man falling reads as fine, and contact_probe's teleport test
## is a per-tick delta, which a gravity fall never trips. It surfaced as an
## absurd separation number (64.99 m in a 6 m ring) in feel_probe, on one seed
## of three.
##
## Driving velocity instead lets move_and_slide() do the moving, which is what
## keeps the floor under him. Y is left alone entirely -- gravity owns it --
## and only the horizontal is steered.
## How far behind a downed man's root Cody stands to take the Figure-Four:
## on the man's own heading, off his feet end. wrestling_clips.py's
## Figure_Four_* are authored against exactly this spacing (his pelvis at
## Cody's fwd +1.00, his boots at +0.50). Past the two capsules' 0.8 m, so
## the bodies never need to stop colliding.
const FIGURE_FOUR_BEHIND_FEET_M := 1.0
## Ticks left before the hold is locked and the contest starts. Counted down
## by MatchReferee._tick_submission().
var _submission_lock_ticks := 0
## The hold being worked, while it is; null for a generic submission.
var _submission_hold_move: MoveDef

## Where he stands to take the hold on this man: off his feet end.
##
## Measured off the man's own skeleton -- head to boots, flattened onto the
## mat -- rather than assumed from his node's heading. Assumed, it was wrong
## twice in tools/probe/hold_shot.tscn: once Cody stood over the man's head
## and lay back across his chest, once he faced away and hooked nothing.
static func figure_four_spot(defender: WrestlerController) -> Vector3:
	return defender.global_position + _feet_way(defender) * FIGURE_FOUR_BEHIND_FEET_M

## Unit vector on the mat from a downed man's head toward his boots.
static func _feet_way(defender: WrestlerController) -> Vector3:
	var head := defender._bone_world("neck_01")
	var foot_l := defender._bone_world("foot_l")
	var foot_r := defender._bone_world("foot_r")
	var way := Vector3.ZERO
	if head != Vector3.INF and foot_l != Vector3.INF and foot_r != Vector3.INF:
		way = (foot_l + foot_r) * 0.5 - head
	way.y = 0.0
	if way.length() < 0.2:
		# No skeleton to read: a supine man lies boots toward his node's +Z.
		way = defender.global_transform.basis.z
		way.y = 0.0
	return way.normalized()

func _bone_world(canonical: String) -> Vector3:
	if skeleton == null:
		return Vector3.INF
	var i := skeleton.find_bone(_skeleton_bone_name(canonical))
	if i < 0:
		return Vector3.INF
	return (skeleton.global_transform * skeleton.get_bone_global_pose(i)).origin

## Whether there is room: a man down by the ropes feet-first leaves nowhere
## to stand, and keep_inside_the_ring() would park Cody on top of him.
static func has_room_for_figure_four(defender: WrestlerController) -> bool:
	var spot := figure_four_spot(defender)
	return absf(spot.x) <= RING_KEEP_IN and absf(spot.z) <= RING_KEEP_IN

## Stands him at the downed man's feet, facing up his body, and walks him
## there the way the cover does (_tick_cover_slide), not in one tick.
func _place_figure_four(defender: WrestlerController) -> void:
	# The walk there can cross his body; the pair stop colliding for it, as
	# for the cover, until they are apart again (_release_cover_contact).
	add_collision_exception_with(defender)
	defender.add_collision_exception_with(self)
	_cover_partner = defender
	# Facing up the man's body, toward his head. A wrestler faces down his
	# node's -Z (the clips' `fwd`), so -Z is turned onto the head-ward line.
	var up_body := -_feet_way(defender)
	var target := Transform3D(Basis(Vector3.UP, atan2(-up_body.x, -up_body.z)),
			figure_four_spot(defender))
	target.origin.y = global_position.y
	_cover_from = global_transform
	_cover_to = target
	_cover_slide_tick = 0
	_cover_slide_ticks = _cover_slide_duration(global_position.distance_to(target.origin))

## Out of the hold without the tap: he is flat on his back where he worked
## it, head away from the man, so he turns round on the mat (the snap into
## Down_Supine, as a head-away throw does) and gets up like any man thrown.
func release_submission_hold() -> void:
	_submission_hold_move = null
	_submission_lock_ticks = 0
	_cover_slide_tick = -1
	velocity.x = 0.0
	velocity.z = 0.0
	_turn_round_on_the_mat()
	_lie_down_after_throw()

func _tick_cover_slide() -> void:
	if _cover_slide_tick < 0:
		return
	_cover_slide_tick += 1
	var t := clampf(float(_cover_slide_tick) / float(_cover_slide_ticks), 0.0, 1.0)
	# Smoothstep, NOT the cubic ease-out used for the grapple lock-up. Ease-out
	# front-loads, putting 23% of the travel in the first tick; smoothstep
	# starts and ends slow, so he leans into the walk and settles out of it.
	# The duration this runs over is _cover_slide_duration()'s, which is what
	# actually caps the speed -- see the note there.
	var eased := t * t * (3.0 - 2.0 * t)
	var want := _cover_from.origin.lerp(_cover_to.origin, eased)
	var ticks_per_second := float(Engine.physics_ticks_per_second)
	velocity.x = (want.x - global_position.x) * ticks_per_second
	velocity.z = (want.z - global_position.z) * ticks_per_second
	# The facing is safe to set outright: a basis carries no floor contact.
	global_transform.basis = GrappleRig.blend_transforms(
			_cover_from, _cover_to, eased).basis
	if t >= 1.0:
		_cover_slide_tick = -1
		velocity.x = 0.0
		velocity.z = 0.0


## With `move` (his own hold, e.g. the Figure-Four), both men play the
## move's clip pair ("strikes/<animation_pair_id>_attacker"/"_defender"), he
## is placed where the hold is worked, and the contest waits out
## move.startup_frames -- the application -- before either side's ring fills.
func begin_submission(defender: WrestlerController, target_limb: CombatSystem.Limb,
		move: MoveDef = null) -> void:
	_submission_lock_ticks = 0
	if move:
		_set_state_clip(WrestlerFSM.State.SUBMISSION_ATTACKER,
				"strikes/%s_attacker" % move.animation_pair_id)
		defender._set_state_clip(WrestlerFSM.State.SUBMISSION_DEFENDER,
				"strikes/%s_defender" % move.animation_pair_id)
		_submission_lock_ticks = move.startup_frames
		_submission_hold_move = move
	fsm.transition_to(WrestlerFSM.State.SUBMISSION_ATTACKER)
	defender.fsm.transition_to(WrestlerFSM.State.SUBMISSION_DEFENDER)
	if move:
		_place_figure_four(defender)
	# submission_break_rate() reads whichever CombatSystem it's called on —
	# it must be the defender's (the limb actually being locked), not the
	# attacker's own. Calling it on `combat` (self, the attacker) silently
	# ignored the defender's real damage entirely, since an attacker's own
	# limbs are rarely damaged on the same limb it's targeting: caught live,
	# not by the unit tests below (which exercise SubmissionMinigame's rate
	# math directly, not this call site) — every attempt escaped regardless
	# of how hurt the targeted limb actually was.
	var attacker_rate := defender.combat.submission_break_rate(target_limb)
	# The defender wins the race whenever his rate is the higher one, so this
	# number alone decides how hurt a limb has to be before a hold gets a
	# tap-out: the attacker's rate is 1.0 + limb/MAX_LIMB_DAMAGE, so he wins
	# exactly when the targeted limb is past SUBMISSION_ESCAPE_LIMB.
	#
	# It used to be a flat 1.8, chosen when MatchReferee only started a hold
	# above 70 limb damage (a [1.7, 2.0] attacker band, so 1.8 sat in the
	# middle of it). Lowering that threshold to 55 moved the band to
	# [1.55, 2.0] and left 1.8 above almost all of it -- so every submission
	# the referee actually started was one the defender was guaranteed to
	# escape. Derived from the constant now, so moving the threshold again
	# cannot silently make one side unbeatable.
	#
	# It was then a *flat* 1.0 + SUBMISSION_ESCAPE_LIMB/MAX, which put the
	# crossover in the right place but made the race a knife-edge
	# everywhere: the attacker's rate rises with the limb and the
	# defender's did not move at all, and MatchReferee only starts a hold
	# in a narrow band around the crossover, so the two rates were always
	# within a couple of percent of each other. Measured over ten seeds,
	# every hold in the project ended with the loser's ring at 0.96-0.99 of
	# its break point -- a photo finish every single time, which is not a
	# contest but a comparison of the targeted limb against 60.0 dressed up
	# as one.
	#
	# Mirroring the attacker's slope around the same crossover keeps the
	# "he wins exactly past SUBMISSION_ESCAPE_LIMB" property above and
	# gives the result a margin that grows with the damage: at a limb of 55
	# the defender is 6% faster and works free, at 80 the attacker is 29%
	# faster, at a destroyed limb 67% faster. How hurt a limb has to be is
	# still SUBMISSION_ESCAPE_LIMB's reachability value; only the
	# steepness either side of it is new.
	var limb_damage: float = defender.combat.limb_damage[target_limb]
	var defender_rate := 1.0 + (2.0 * SUBMISSION_ESCAPE_LIMB - limb_damage) / CombatSystem.MAX_LIMB_DAMAGE
	defender._submission_minigame = SubmissionMinigame.new(attacker_rate, defender_rate)


## During the entrances and the post-match nothing reads his pose back, so the
## tree is evaluated every rendered frame instead of every physics tick: on a
## 120 Hz display, or a frame rate that wanders, the physics-rate pose was held
## for an uneven number of frames, which reads as stop motion. At the bell it
## goes back to the tick, where captures and gameplay expect it.
func set_presentation_rate(on: bool) -> void:
	if anim_tree:
		anim_tree.callback_mode_process = (
				AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if on
				else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS)
