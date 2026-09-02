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

const MOVE_SPEED := 3.5
const RUN_SPEED := 7.0
const TIE_UP_RANGE := 1.4
## Reach for a strike/running-attack to connect.
##
## Measured, not chosen: running forward kinematics over `Punch_Jab`'s own
## tracks puts the fist 0.76m ahead of the wrestler's origin at its contact
## frame, and the opponent's capsule radius is 0.4m, so a punch reaches a
## body whose centre is up to ~1.16m away.
##
## This was 1.8m. Strikes therefore connected from 1.6m -- the distance an
## instrumented match actually recorded them landing at -- which is more
## than half a metre of clear air between the fist and the man it damaged.
## That is the single biggest reason strikes read as not connecting.
const STRIKE_HIT_RANGE := 1.15
## Downward acceleration (m/s^2) applied whenever a wrestler is off the mat.
## The project sets no custom gravity, so this matches Godot's own 3D default
## rather than inventing a value -- ARCHITECTURE.md's "Reference-driven
## tuning" rule applies here as much as anywhere, and no reference footage
## covers fall speed.
const GRAVITY := 9.8
## Total accumulated damage at which a wrestler is knocked off his feet.
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

const GETUP_TICKS := 90 # 1.5s
const HIT_REACT_TICKS := 20
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
@export var weight_class: int = 1
## Set by MatchSetup so _pick_tier_move()'s draw is seeded per match rather
## than by the global RNG. Same reasoning as WrestlerAI.setup_jitter().
var match_seed: int = 0
## Incremented on every tier draw so two grapples in one match don't have to
## resolve to the same move. Part of the RNG's seed, never of gameplay state.
var _tier_draws: int = 0
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
## Shared 0..1 blend applied to both arms' SkeletonIK3D.interpolation.
var _grip_blend: float = 0.0
## Span from shoulder to hand in the rest pose, measured in _build_ik_rig().
var _arm_reach: float = 0.0
## State -> clip, queued by whoever is about to enter that state and
## consumed by _take_clip_override(). See its doc comment.
var _state_clip_override: Dictionary = {}

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
	WrestlerFSM.State.IDLE: "Idle",
	WrestlerFSM.State.LOCOMOTION: "Walk",
	WrestlerFSM.State.RUN: "Sprint",
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
	WrestlerFSM.State.TIE_UP: "Push",
	WrestlerFSM.State.GRAPPLE_HOLD: "Interact",
	# MOVE_EXEC is the beat where a grapple's throw resolves, not a strike.
	# It played Punch_Cross, so a wrestler who had just completed a suplex
	# threw a punch at nothing on the way back to idle.
	WrestlerFSM.State.MOVE_EXEC: "Jump_Land",
	# Replaced per hit by _play_hit_reaction() with a head or torso reaction
	# depending on where the damage landed; this is the fallback.
	WrestlerFSM.State.HIT_REACT: "strikes/hit_torso",
	WrestlerFSM.State.DOWN: "Death01",
	WrestlerFSM.State.GETUP: "Roll",
	WrestlerFSM.State.IRISH_WHIP: "Push",
	WrestlerFSM.State.RUNNING_ATTACK: "Punch_Cross",
	# Retimed to STUNNED_TICKS. The raw Hit_Head is 0.43s against a 45-tick
	# (0.75s) state, so the clip ended and the pose froze for 19 ticks.
	WrestlerFSM.State.STUNNED: "strikes/stunned",
	WrestlerFSM.State.PIN_ATTACKER: "Crouch_Idle",
	WrestlerFSM.State.PIN_DEFENDER: "Death01",
	WrestlerFSM.State.SUBMISSION_ATTACKER: "Crouch_Idle",
	WrestlerFSM.State.SUBMISSION_DEFENDER: "Death01",
	WrestlerFSM.State.FINISHER: "Sword_Attack",
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
	WrestlerFSM.State.GRAPPLE_HOLD: "PickUp_Table", # bend-and-lift
}
const DEFENDER_STATE_ANIMATIONS := {
	WrestlerFSM.State.GRAPPLE_HOLD: "Death01", # limp, being thrown
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
## Whether this wrestler pressed "reversal" this tick. Captured here (same
## shape as _wants_tie_up_this_tick) and consumed by
## MatchReferee._check_for_reversal() after every wrestler's own
## _physics_process for the tick -- a reversal's outcome depends on reading
## the *opponent's* same-tick _active_move/_move_ticks_remaining, exactly
## the class of scene-order bug this session already fixed twice for tie-up
## entry and pending-hit resolution, so it gets the same deferred-to-referee
## treatment rather than being resolved inline here.
var _wants_reversal_this_tick: bool = false

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

func _ready() -> void:
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
			anim_player.add_animation_library(PairedRecipes.LIBRARY, PAIRED_POSES)
		if not anim_player.has_animation_library(StrikeRecipes.LIBRARY):
			anim_player.add_animation_library(StrikeRecipes.LIBRARY, STRIKE_CLIPS)
		_build_animation_tree()
	skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		_build_ik_rig()

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

	var blend_seconds := ANIMATION_BLEND_TICKS / float(Engine.physics_ticks_per_second)
	for from_id in WrestlerFSM.LEGAL_TRANSITIONS:
		var from_name: String = WrestlerFSM.State.keys()[from_id]
		if not state_machine.has_node(from_name):
			continue
		for to_id in WrestlerFSM.LEGAL_TRANSITIONS[from_id]:
			var to_name: String = WrestlerFSM.State.keys()[to_id]
			if to_name == from_name or not state_machine.has_node(to_name):
				continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = blend_seconds
			transition.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			state_machine.add_transition(from_name, to_name, transition)

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
			if skeleton.find_bone(chain[role]) < 0:
				push_error("Grip IK: rig has no bone '%s'; arm IK disabled" % chain[role])
				return

	for chain in ARM_CHAINS:
		var ik := SkeletonIK3D.new()
		# Configure before entering the tree: each of root_bone/tip_bone
		# rebuilds the solver chain the moment it's assigned, so setting them
		# on an already-parented node makes the first assignment resolve the
		# other end to -1 and log a build_chain error.
		ik.root_bone = chain["root"]
		ik.tip_bone = chain["tip"]
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
	var shoulder := skeleton.get_bone_global_rest(skeleton.find_bone(chain["root"])).origin
	var hand := skeleton.get_bone_global_rest(skeleton.find_bone(chain["tip"])).origin
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
			return _is_grapple_attacker or _paired_grip_ticks > 0
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

func _update_grip_ik() -> void:
	if _arm_ik.is_empty():
		return
	if _paired_grip_ticks > 0:
		_paired_grip_ticks -= 1
	var engaged := _is_gripping_state() and _aim_grip_targets()
	var step := IK_BLEND_PER_TICK if engaged else -IK_BLEND_PER_TICK
	_grip_blend = clampf(_grip_blend + step, 0.0, 1.0)
	for ik in _arm_ik:
		ik.interpolation = _grip_blend

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
	var lifting := fsm.current_state == WrestlerFSM.State.GRAPPLE_HOLD \
			and _is_grapple_attacker
	var anchor_name := GRIP_BONE_LIFT if lifting else GRIP_BONE
	var anchor_bone := opponent.skeleton.find_bone(anchor_name)
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

## Nearest point to `target` the named shoulder's arm can actually straighten
## to, stopping just short of full extension.
func _reachable(shoulder_bone_name: String, target: Vector3) -> Vector3:
	var shoulder_bone := skeleton.find_bone(shoulder_bone_name)
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
	_anim_playback.start(state_name, true)

	var length := anim_player.get_animation(clip).length
	var grip_fraction := 1.0 if is_attacker \
			else PairedRecipes.defender_grip_until(move.animation_pair_id)
	_paired_grip_ticks = int(round(length * grip_fraction
			* Engine.physics_ticks_per_second))
	return true

func _on_fsm_state_changed(_previous: WrestlerFSM.State, current: WrestlerFSM.State) -> void:
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

func _resolve_paths() -> void:
	if opponent_path != NodePath():
		opponent = get_node(opponent_path)
	if grapple_rig_path != NodePath():
		grapple_rig = get_node(grapple_rig_path)
	if ai:
		ai.target = opponent

func _physics_process(delta: float) -> void:
	var live_input := _poll_live_input()
	var input := ReplaySystem.get_input(player_index, live_input) if ReplaySystem else live_input
	fsm._physics_process(delta)

	match fsm.current_state:
		WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN:
			_process_free_movement(delta, input)
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
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.DOWN:
			_process_down(input)
		WrestlerFSM.State.GETUP:
			_process_timed_state(input, WrestlerFSM.State.IDLE)
		WrestlerFSM.State.RUNNING_ATTACK:
			_process_active_move(input)
		WrestlerFSM.State.IRISH_WHIP:
			_process_irish_whip()
		WrestlerFSM.State.PIN_ATTACKER:
			pass # driven by MatchReferee
		WrestlerFSM.State.PIN_DEFENDER:
			# MatchReferee reads this each tick against PinMinigame's target
			# window — a kickout needs the button pressed AND the marker in
			# the window at that instant, not just the marker passing
			# through the window on its own (the marker sweeps the whole
			# range every cycle, so without an input gate every pin would
			# resolve as an automatic kickout before reaching a three-count).
			_kickout_input_this_tick = input.get("strike", false)
		WrestlerFSM.State.SUBMISSION_ATTACKER:
			pass # driven by MatchReferee; no continued attacker input needed,
			# same as PIN_ATTACKER's three-count
		WrestlerFSM.State.SUBMISSION_DEFENDER:
			# Mirrors the PIN_DEFENDER case above, but held rather than
			# just-pressed — SubmissionMinigame is a genuine continuous-hold
			# rate race, not a press-limited fill-meter, so no input gating
			# is needed here beyond reading the raw hold state each tick.
			_submission_defender_input_this_tick = input.get("submission_hold", false)

	_apply_gravity(delta)
	move_and_slide()
	# After move_and_slide(), so the grip is aimed at where the bodies have
	# actually ended up this tick rather than where they started it.
	_update_grip_ik()

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
		return ai.poll_input() if ai else {}
	return {
		"move": Input.get_vector("move_left", "move_right", "move_up", "move_down"),
		"strike": Input.is_action_just_pressed("strike"),
		"grapple": Input.is_action_just_pressed("grapple"),
		"run": Input.is_action_pressed("run"),
		"reversal": Input.is_action_just_pressed("reversal"),
		"submission_hold": Input.is_action_pressed("submission_hold"),
	}

func _process_free_movement(delta: float, input: Dictionary) -> void:
	_wants_reversal_this_tick = input.get("reversal", false)
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
		var strike := _pick_tier_move(strike_move, strike_move_pool)
		_play_strike_clip(strike)
		_start_move(WrestlerFSM.State.STRIKE, strike)
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

## RUN -> RUNNING_ATTACK is the only legal way into RUNNING_ATTACK, so this
## is only ever called while already in RUN (both the player/AI-steered
## case, from _process_free_movement(), and the post-whip autopilot case,
## from _process_irish_whip_return()).
func _maybe_start_running_attack(input: Dictionary) -> void:
	if input.get("strike", false) and running_attack_move and opponent \
			and _in_range(STRIKE_HIT_RANGE) and not UNHITTABLE_STATES.has(opponent.fsm.current_state):
		_start_move(WrestlerFSM.State.RUNNING_ATTACK, running_attack_move)

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
	opponent._irish_whip_target = self
	opponent._irish_whip_rebounded = false
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
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Node and (collider as Node).is_in_group(RING_ROPE_GROUP):
			velocity = velocity.bounce(collision.get_normal()) * IRISH_WHIP_REBOUND_DAMPING
			_irish_whip_rebounded = true
			_irish_whip_return_ticks_remaining = IRISH_WHIP_RETURN_TICKS
			fsm.transition_to(WrestlerFSM.State.RUN)
			break

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

	if in_active_frames and opponent and _in_range(STRIKE_HIT_RANGE) \
			and not UNHITTABLE_STATES.has(opponent.fsm.current_state) \
			and not _active_move_hit_applied:
		_apply_move_to_opponent(_active_move)
		_active_move_hit_applied = true

	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		_active_move_hit_applied = false
		fsm.transition_to(WrestlerFSM.State.IDLE)
		_active_move = null

func _apply_move_to_opponent(move: MoveDef) -> void:
	move_landed.emit(self, opponent, move)
	# Momentum belongs to whoever lands the hit (self), not the wrestler
	# taking it — applied immediately since it's this wrestler's own
	# CombatSystem, not shared, so there's no cross-wrestler race here.
	# The damage itself still goes through the deferred queue below.
	combat.apply_momentum(move)
	opponent._pending_hits.append(move)

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
	for move in moves:
		combat.apply_damage(move)
	if combat.total_damage() >= KNOCKDOWN_DAMAGE:
		_go_down()
	else:
		_play_hit_reaction(moves[moves.size() - 1])
		_start_move(WrestlerFSM.State.HIT_REACT, _timed_stub(HIT_REACT_TICKS))

## Points the STRIKE state at this strike's own clip before entering it.
##
## Every strike played the same jab regardless of which MoveDef was thrown,
## so a kick and a punch were the same animation with different numbers
## attached. A move with no generated clip keeps whatever the state already
## had, which is the jab.
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
	_set_state_clip(WrestlerFSM.State.HIT_REACT, StrikeRecipes.reaction_for(move))

## Swaps which clip a state's node plays, before the FSM enters it. The
## AnimationTree is built once from STATE_ANIMATIONS, so this is how a state
## that needs more than one clip gets one -- the same approach
## play_paired_pose() uses to give each grapple role its own performance.
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
		# The defender sits in GRAPPLE_HOLD, not a free-movement state, while
		# the attacker's paired move plays -- capture reversal intent here so
		# MatchReferee._check_for_reversal() can still see it (free-movement
		# states capture it via _process_free_movement(), which never runs
		# for a GRAPPLE_HOLD defender).
		_wants_reversal_this_tick = input.get("reversal", false)
		return
	if input.get("run", false):
		_begin_irish_whip()
		return
	var move := grapple_move
	if not move or opponent.weight_class < move.weight_class_min or opponent.weight_class > move.weight_class_max:
		return
	if combat.can_finisher() and finisher_move:
		move = _pick_tier_move(finisher_move, finisher_move_pool)
	elif combat.can_signature() and signature_move:
		move = _pick_tier_move(signature_move, signature_move_pool)
	elif combat.can_power() and power_move:
		move = _pick_tier_move(power_move, power_move_pool)
	else:
		move = _pick_tier_move(grapple_move, grapple_move_pool)

	_active_move = move
	if grapple_rig:
		grapple_rig.begin(self, opponent, move)
		grapple_rig.grapple_finished.connect(_on_grapple_finished, CONNECT_ONE_SHOT)
	else:
		_resolve_grapple_move(move)

## Draws one move from a tier: the tier's guaranteed move plus whatever its
## pool adds, filtered to what this opponent's weight class allows.
##
## Seeded rather than random, because a paired move's outcome feeds damage
## and momentum and therefore the match: the same (match_seed, player_index,
## draw count) must always produce the same move, or replays stop matching.
## The multipliers are deliberately different from WrestlerAI._should_whip()'s
## so the two decisions don't move in lockstep across a match.
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

func _on_grapple_finished(_attacker: Node3D, _defender: Node3D) -> void:
	var move := _active_move
	_active_move = null
	_resolve_grapple_move(move)

func _resolve_grapple_move(move: MoveDef) -> void:
	fsm.transition_to(WrestlerFSM.State.MOVE_EXEC)
	# Defender rides the same paired move (GrappleRig drove both skeletons in
	# lockstep) so it must also be in MOVE_EXEC before taking a hit reaction —
	# GRAPPLE_HOLD -> HIT_REACT/DOWN is not a legal transition on its own.
	opponent.fsm.transition_to(WrestlerFSM.State.MOVE_EXEC)
	move_landed.emit(self, opponent, move)
	combat.apply_momentum(move)
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
	opponent.combat.apply_damage(move)
	fsm.transition_to(WrestlerFSM.State.IDLE)
	if opponent.combat.total_damage() >= KNOCKDOWN_DAMAGE:
		opponent._go_down()
	else:
		opponent._start_move(WrestlerFSM.State.HIT_REACT, opponent._timed_stub(HIT_REACT_TICKS))

func _go_down() -> void:
	if fsm.current_state == WrestlerFSM.State.HIT_REACT or fsm.is_in([WrestlerFSM.State.IDLE, WrestlerFSM.State.LOCOMOTION, WrestlerFSM.State.RUN, WrestlerFSM.State.STRIKE]):
		fsm.transition_to(WrestlerFSM.State.HIT_REACT)
	fsm.transition_to(WrestlerFSM.State.DOWN)
	_move_ticks_remaining = GETUP_TICKS
	_cover_eligible = true
	knocked_down.emit(self)

func _process_down(input: Dictionary) -> void:
	_move_ticks_remaining -= 1
	if input.get("strike", false) or _move_ticks_remaining <= 0:
		fsm.transition_to(WrestlerFSM.State.GETUP)
		_move_ticks_remaining = 20

func _process_timed_state(input: Dictionary, next_state: WrestlerFSM.State) -> void:
	_move_ticks_remaining -= 1
	if _move_ticks_remaining <= 0:
		# Also covers GETUP -> IDLE, the only place a wrestler that lost
		# _cover_eligible to a kickout (see the field's own doc comment)
		# gets it back — harmless to set unconditionally for the
		# HIT_REACT/STUNNED -> IDLE case too, since it's already true there.
		_cover_eligible = true
		fsm.transition_to(next_state)

## Called by MatchReferee when the attacker covers a downed opponent.
func begin_pin(defender: WrestlerController, seed_value: int) -> void:
	fsm.transition_to(WrestlerFSM.State.PIN_ATTACKER)
	defender.fsm.transition_to(WrestlerFSM.State.PIN_DEFENDER)
	var fraction := defender.combat.kickout_window_fraction(combat.momentum)
	defender._pin_minigame = PinMinigame.new(fraction, seed_value)
	pin_started.emit(self, defender)

func begin_submission(defender: WrestlerController, target_limb: CombatSystem.Limb) -> void:
	fsm.transition_to(WrestlerFSM.State.SUBMISSION_ATTACKER)
	defender.fsm.transition_to(WrestlerFSM.State.SUBMISSION_DEFENDER)
	# submission_break_rate() reads whichever CombatSystem it's called on —
	# it must be the defender's (the limb actually being locked), not the
	# attacker's own. Calling it on `combat` (self, the attacker) silently
	# ignored the defender's real damage entirely, since an attacker's own
	# limbs are rarely damaged on the same limb it's targeting: caught live,
	# not by the unit tests below (which exercise SubmissionMinigame's rate
	# math directly, not this call site) — every attempt escaped regardless
	# of how hurt the targeted limb actually was.
	var attacker_rate := defender.combat.submission_break_rate(target_limb)
	# MatchReferee only ever starts a submission once the targeted limb is at
	# or above SUBMISSION_LIMB_THRESHOLD (70), so attacker_rate here is never
	# actually as low as its theoretical floor of 1.0 — it's really gated to
	# [1.7, 2.0] (1.0 + threshold/100 .. 1.0 + MAX_LIMB_DAMAGE/100). A flat
	# 0.9 defender_rate loses that race every time (100/1.0=100 ticks for the
	# attacker's absolute floor vs 100/0.9=111 for the defender — the
	# attacker always arrives first), so it's retuned to sit inside the
	# realistic gated band: defender-favored just above the threshold floor,
	# attacker-favored near a fully-damaged limb. First-pass value, open to
	# retuning like PROGRESS_THRESHOLD was (see test_submission_minigame.gd).
	var defender_rate := 1.8
	defender._submission_minigame = SubmissionMinigame.new(attacker_rate, defender_rate)
