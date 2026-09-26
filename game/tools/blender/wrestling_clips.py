"""Authors every wrestling clip in the match on the CC0 base rig and exports
them as a glTF animation library.

Run with the bpy module (no Blender application required):

    python3 game/tools/blender/wrestling_clips.py

Before authoring or changing a clip here, read the `blender-animation` skill
-----------------------------------------------------------------------------
It is not optional advice and it is not a formality. CLAUDE.md's routing table
already points clip authoring at `blender-animation` (bpy keyframes, F-curves,
easing, bone-space handling) plus `animation` (blocking -> breakdown ->
splining, cycle frame counts), and the pass this file replaced skipped the
first of those. It derived the rig's axis conventions by trial instead, got
the mirrored bones backwards, and shipped 29 clips with the arms hanging at
the sides -- the defect described below.

The reminder lives here, at the point of use, rather than only in CLAUDE.md,
because that is where someone about to edit a pose will actually see it.

Why this was rewritten
----------------------
The previous pass authored these same 29 clips as per-bone Euler degrees,
guessed against a remembered axis map. Rendered on the rig (three angles,
six frames per clip) it was one defect repeated everywhere: the arms hung at
the sides in every clip in the set. Idle_Ready was a mannequin standing
still for 57 frames; Tie_Up_Collar was that same mannequin with a small
torso twist, so a collar-and-elbow lock-up played as two men standing near
each other; Strike_Forearm never raised a hand, so the "contact" frame had
nothing arriving. Only Getup_Rise read, because it is the one clip whose
performance lives in the hips rather than the arms.

The cause was not the numbers, it was that nothing could check them.
`upperarm_r.Y` does not raise the arm from a T-pose rest -- it lowers it --
and a table of joint angles gives no way to notice.

So this file no longer specifies joint angles. It specifies **where the
hands and feet are**, in metres, and `rig_pose.RigPoser` solves the joints
that put them there. A pose is now a claim that can be checked on a rendered
frame: a foot at `up=0.104` is planted on the mat, a fist at `fwd=0.56,
up=1.40` is at the end of a thrown punch at head height, and a hand at
`fwd=0.52, up=1.46` is on the back of the other man's neck. Every clip here
was rendered and looked at before it was committed.

Frame of reference (measured off the rest pose, see rig_pose.RIG_FACTS):

    right / fwd / up, in metres, character-relative. He stands 1.65 m;
    shoulders 1.441, pelvis 0.917 at rest, ankles 0.104 when planted,
    arm reach 0.547 from the shoulder, leg reach 0.829 from the hip.

Timing follows `.claude/skills/animation/references/combat-animation.md`
(anticipation 4-8 frames, action 2-4 and always the shortest, follow-through
4-8, recovery 8-16) and `walk-cycle.md` (contact / down / passing / up).
Contact frames are placed at each move's own `startup_frames` fraction so
that retiming in `resources/animations/strike_recipes.gd` lands the hit on
the tick the MoveDef declares:

    strike_jab        9/31 ticks -> frame  5 of 16
    strike_cross     12/40       -> frame  6 of 20
    strike_kick       8/35       -> frame  5 of 20
    strike_kick_heavy 12/57      -> frame  6 of 29

Clips are authored at 30 fps so every frame lands on a whole 60 Hz tick.
Output is deterministic: the same table produces a byte-identical glb, which
is what lets it be committed and diffed like the .tres bakes.
"""

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from rig_pose import RigPoser, keyed_bones, _euler, vec  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RIG = os.path.join(REPO, "assets", "characters", "wrestler_base.glb")
OUT = os.path.join(REPO, "assets", "animations", "wrestling_clips.glb")

FPS = 30


# --- the base stance ------------------------------------------------------
#
# Every standing clip starts and ends here so they cut together, and every
# clip poses the WHOLE body from it -- hips and legs included -- so a strike
# steps into something instead of inheriting whatever the AnimationTree was
# blending from.
#
# Feet are staggered and planted (both ankles at 0.104): left foot leads,
# right foot back and turned out, which is where a wrestler's weight
# actually sits. The pelvis is dropped from its 0.917 rest to 0.860, which
# is what bends the knees -- there is no knee angle in this file, only a hip
# height and a planted foot, and the solver does the rest.
#
# The lean is NEGATIVE, and that is not a typo. A positive `spine` lean tips
# the torso BACKWARD, whatever rig_pose._euler's docstring says: measured one
# axis at a time off the rest pose, the head sits 0.151 m in front of the
# pelvis at -15 and 0.041 m BEHIND it at +15, monotonic across the range.
# `hips` pitch and `head` pitch invert the same way.
#
# Run_Drive found this first and fixed itself ("needed a negative lean and for
# years had a positive one"), and its note says the stance still carried +12 --
# a slight backward recline inherited by all 29 clips -- because correcting it
# moves every one of them. This is that correction: a wrestler at rest is
# coiled over his front foot, not reclined off it.
#
# The guard widens with it. At the old (0.17, 0.30) / (-0.13, 0.35) the hands
# sat 0.30 m apart -- inside shoulder width, which is 0.384 -- with the elbows
# pinned to the ribs, and rendered they read as a man holding something in
# front of his chest rather than as a guard. They now sit slightly wider than
# the shoulders and further out in front, which is 0.373 m of the arm's 0.547
# reach: bent, not braced.

STANCE = dict(
    pelvis=(0.0, 0.02, 0.860), hips=(0, -8, 0), spine=(-10, 6, 0), head=(2, 8, 0),
    hand_r=(0.24, 0.34, 1.30), hand_l=(-0.21, 0.38, 1.34),
    fist_r=0.8, fist_l=0.8,
    foot_r=(0.23, -0.17, 0.104), foot_l=(-0.19, 0.18, 0.104),
)

# A man on his back: shoulders on the mat, face to the lights, head toward
# +fwd, knees up.
#
# This was authored as hips=(-84, 0, 0) under a comment reading "hips rolled
# back ... head toward -fwd", which is the same sign mistake STANCE's note
# describes: a negative hips pitch tips a man FORWARD. So for as long as the
# pose existed it laid him FACE DOWN -- measured through
# tools/probe/paired_shot.tscn, his chest (spine_03's +Z, which points along
# his facing when he stands) pointed at (0.03, -1.00, 0): straight into the
# canvas. Every knockdown, every cover and every pinfall in the game was
# played on a man lying on his front.
#
# The correction is the smallest one that makes him supine without moving
# him: the same forward pitch, then rolled 180 degrees about his own spine.
# His head stays on the +fwd side and his pelvis where it was, so the cover
# placement and the getup, which are both measured off where the downed man
# lies, are unchanged -- only which way up he is changes. The roll swaps his
# sides, so his right hand and foot are at NEGATIVE `right` here; `head` is
# negative to lift his chin off the mat rather than grind his face into it.
SUPINE = dict(
    pelvis=(0.0, 0.0, 0.175), hips=(-84, 0, 180), spine=(-6, 0, 0), head=(-14, 0, 0),
    hand_r=(-0.40, 0.20, 0.10), hand_l=(0.39, 0.16, 0.10),
    elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
    fist_r=0.2, fist_l=0.2,
    foot_r=(-0.16, -0.52, 0.10), foot_l=(0.15, -0.48, 0.10),
    knee_r=(-0.3, 0.0, 1.0), knee_l=(0.3, 0.0, 1.0),
)


# The ready stance a wrestler holds while he sizes the other man up -- what
# Idle_Ready loops on and what the opening bell shows.
#
# It used to be STANCE itself, and rendered on Roman it read as two men
# holding a beach ball: pelvis 0.86 against a 0.917 rest (knees all but
# straight), torso upright, fists curled together at 1.30-1.34 m. The owner
# flagged it off the match video. A wrestler waiting for a lock-up is coiled:
# knees bent, chest over the lead foot, OPEN hands out in front at belly-to-
# chest height with the elbows down, ready to reach for the collar.
#
# Kept separate from STANCE on purpose. Twenty-nine clips start and end on
# STANCE, and moving it re-poses every one of them; this is the rest pose of
# one clip. The strikes still cut from it cleanly because they re-pose the
# whole body from their first key.
READY = dict(
    pelvis=(0.0, 0.0, 0.780), hips=(-8, -8, 0), spine=(-20, 6, 0),
    head=(8, 8, 0),
    hand_r=(0.30, 0.50, 1.10), hand_l=(-0.27, 0.54, 1.14),
    elbow_r=(0.6, -0.2, -1.0), elbow_l=(-0.6, -0.2, -1.0),
    fist_r=0.3, fist_l=0.3,
    foot_r=(0.27, -0.20, 0.104), foot_l=(-0.23, 0.20, 0.104),
)


def pose(base=None, **over):
    """A pose is the base with a few things moved. Anything not named keeps
    the base's value, which is what makes a clip's table read as the changes
    rather than as 14 unchanged numbers per frame."""
    out = dict(STANCE if base is None else base)
    out.update(over)
    return out


def P(**over):
    return pose(STANCE, **over)


def S(**over):
    return pose(SUPINE, **over)


# --- gait construction ----------------------------------------------------
#
# The two locomotion cycles are generated rather than tabled, because the one
# property that makes a cycle read as walking instead of skating cannot be
# held by hand: while a foot is on the mat it must travel backward at exactly
# the speed the engine translates the body forward. Miss it and the mat slides
# under the boot.
#
# Measured on the tabled versions these replaced, sampling the planted phase
# of the clips the game actually loads (tools/anim/gait_audit.gd reproduces
# it):
#
#   walk_stalk  foot planted 0.85s of a 1.333s cycle, travelling 0.35 m
#               -> 0.42 m/s delivered against MOVE_SPEED 3.5  (6.6x skate)
#   run_drive   foot planted 0.16s of a 0.667s cycle, travelling 0.32 m
#               -> 2.01 m/s delivered against RUN_SPEED 7.0   (7.3x skate)
#
# Contact DURATION is the free variable here, not stride length. Stride is
# capped by the leg -- 0.829 m of thigh+calf means a planted foot can only
# reach about +-0.30 m either side of the hip before the knee locks out -- so
# a faster gait is bought with a shorter, harder contact and more time in the
# air, which is what real sprinting does. The flight phase covers the rest of
# the ground and constrains nothing, because nothing is planted during it.
#
# So each cycle below names its contact windows and its speed, and the foot
# curve falls out of them. `frames`/`speed` and the `seconds` its recipe in
# resources/animations/strike_recipes.gd retimes to must agree: the planted
# rate is travel / (contact_frames / frames * seconds).

# Ankle pitch through a step, in degrees about the rest basis. Positive is
# plantar-flexion (heel up, toe down) -- the sign Strike_Forearm's pivoting
# back foot already uses. A few degrees of toes-up at heel strike, a real
# push-off at toe-off.
HEEL_STRIKE_PITCH = -6.0
TOE_OFF_PITCH = 24.0


# --- clips that travel ------------------------------------------------------
#
# Every clip above is authored IN PLACE: the engine moves the root and the
# clip only poses the body around it. The entrance's step climb and rope
# step-through cannot be authored that way by eye, because what has to hold
# still is a foot on a TREAD, and the tread is fixed in the world while the
# root the clip is expressed against is moving up the stairs under it.
#
# So these are keyed in WORLD space -- metres from where the move starts,
# `fwd` along the travel and `up` from the surface he starts on -- and
# converted to root-relative per frame, with the root travelling in a
# straight line from (0, 0) to `root_to` over the clip. EntranceDirector
# moves the root along exactly that line over exactly this duration, so the
# two cancel and the planted foot stays planted.
#
# Keyed every frame, not at the sparse keys: between two keys a planted foot
# is fixed in the world but its root-relative position changes linearly, and
# the author()'s Bezier easing between sparse relative keys would slide it.

_TRAVEL_FIELDS = ("pelvis", "hand_r", "hand_l", "foot_r", "foot_l")


def _lerp_value(a, b, t):
    if isinstance(a, tuple):
        return tuple(x + (y - x) * t for x, y in zip(a, b))
    if isinstance(a, (int, float)):
        return a + (b - a) * t
    return a


def _world_clip(frames, root_to, keys):
    """Per-frame root-relative poses from sparse world-space keys.

    `keys` is [(frame, full pose dict in world space)], first at 0 and last
    at `frames`. Between keys every field eases with smoothstep, so a swing
    leaves and lands softly and a planted foot, keyed identically either
    side, does not move at all.
    """
    out = []
    for f in range(frames + 1):
        i = 0
        while i + 1 < len(keys) - 1 and keys[i + 1][0] <= f:
            i += 1
        (f0, k0), (f1, k1) = keys[i], keys[i + 1]
        t = 0.0 if f1 == f0 else min(max((f - f0) / float(f1 - f0), 0.0), 1.0)
        t = t * t * (3.0 - 2.0 * t)
        pose_now = {key: _lerp_value(k0[key], k1.get(key, k0[key]), t)
                    for key in k0}
        rf = root_to[0] * f / float(frames)
        ru = root_to[1] * f / float(frames)
        for field in _TRAVEL_FIELDS:
            x, y, z = pose_now[field]
            pose_now[field] = (x, y - rf, z - ru)
        out.append((f, pose_now))
    return out


def _open_hands(frames, curl=0.3):
    """A gait with READY's open hands instead of STANCE's fists."""
    return [(f, dict(p, fist_r=curl, fist_l=curl)) for f, p in frames]


def _gait(frames, fps, speed, contacts, plant_up, lift_up, foot_x,
          pelvis_up, pelvis_dip, hips_yaw, spine, head, hand_fwd, hand_up,
          hand_x, elbow, arm_spread=0.0):
    """One looping in-place gait cycle, keyed every frame.

    `contacts` is {"r": (start_frame, contact_frames), "l": ...}. Inside its
    window a foot sits at `plant_up` and travels backward at `speed`; outside
    it swings forward through an arc peaking at `lift_up`. Frame `frames` is
    computed identically to frame 0, so the loop seam is closed by
    construction rather than by remembering to repeat a pose -- which is the
    defect that put a 0.132 m forearm pop in every run cycle, where frame 0
    named elbow poles and the closing frame did not.
    """
    out = []
    for f in range(frames + 1):
        phase = (f % frames) / float(frames)
        over = {}
        for side, (start, contact) in contacts.items():
            rel = (f - start) % frames
            half = (contact / float(fps)) * speed * 0.5
            if rel <= contact:
                # Planted: backward at exactly `speed`, so the mat holds.
                over["foot_%s" % side] = (
                    foot_x[side], half - (rel / float(fps)) * speed, plant_up)
                # And FLAT. `foot_*` places the ankle; it says nothing about
                # which way the boot points, and without this the foot simply
                # inherits the shin's rotation -- so a leg swung out in front
                # carries the toe down with it and the wrestler walks on
                # points, like a ballet dancer. The longer the stride the
                # worse it looks, so lengthening these cycles made a
                # pre-existing fault far more visible.
                #
                # `ankle` is an ARMATURE-SPACE rotation of the rest basis (see
                # RigPoser._set), and the rig's rest pose stands with its
                # soles flat, so 0 is flat regardless of what the leg above is
                # doing. The roll through contact is heel-strike to toe-off:
                # a few degrees of toes-up as the heel lands, through flat,
                # into a real push-off.
                over["ankle_%s" % side] = (
                    HEEL_STRIKE_PITCH + (TOE_OFF_PITCH - HEEL_STRIKE_PITCH)
                    * (rel / float(contact)), 0.0, 0.0)
            else:
                swing = (rel - contact) / float(frames - contact)
                # Ease the recovery so the foot does not shoot forward at a
                # constant rate -- a swinging leg accelerates and settles.
                eased = swing * swing * (3.0 - 2.0 * swing)
                # The arc is raised to a fractional power so the boot LEAVES
                # the mat, rather than easing off it. A plain sine spends two
                # frames either side of the contact window within a
                # centimetre of the canvas, which reads as a drag and, worse,
                # is indistinguishable from contact: the foot is still
                # effectively planted while the curve has already stopped
                # holding it to the ground speed, so the skate comes back at
                # the edges of every step.
                over["foot_%s" % side] = (
                    foot_x[side], -half + eased * (2.0 * half),
                    plant_up + lift_up * math.sin(math.pi * swing) ** 0.55)
                # Unwind the push-off and set the foot up for the next heel
                # strike, passing through flat rather than hanging pointed.
                over["ankle_%s" % side] = (
                    TOE_OFF_PITCH + (HEEL_STRIKE_PITCH - TOE_OFF_PITCH) * eased,
                    0.0, 0.0)
        # Hips drop once per step (twice per cycle) as each contact absorbs.
        over["pelvis"] = (0.0, 0.0,
                          pelvis_up - pelvis_dip * (0.5 - 0.5 * math.cos(
                              4.0 * math.pi * phase)))
        # Pelvis and shoulders counter-rotate once per cycle, and the arms
        # pump with them.
        #
        # COSINE, not sine, and the difference is the whole gait. The contact
        # windows start at phase 0 and 0.5, where sin() is exactly zero -- so
        # a sine put the arms and the hips at their NEUTRAL midpoint on both
        # contact frames and at their extremes mid-flight, which is precisely
        # backwards. Rendered, the run had both hands tucked together at the
        # chest at the moment a foot landed; it read as a man jogging with his
        # guard up rather than driving. Nothing measured caught it -- the
        # planted-foot rate was correct throughout -- and it is obvious on the
        # first frame anyone looks at.
        swing_yaw = math.cos(2.0 * math.pi * phase)
        over["hips"] = (spine[0] * 0.2, hips_yaw * swing_yaw, 0.0)
        over["spine"] = (spine[1], -hips_yaw * swing_yaw * 0.6, 0.0)
        over["head"] = head
        # Arms pump opposite the legs: the right hand leads when the left
        # foot does.
        for side, sign in (("r", 1.0), ("l", -1.0)):
            drive = sign * swing_yaw
            over["hand_%s" % side] = (
                hand_x[side] + arm_spread * abs(drive),
                hand_fwd[0] + (hand_fwd[1] - hand_fwd[0]) * (0.5 + 0.5 * drive),
                hand_up[0] + (hand_up[1] - hand_up[0]) * (0.5 + 0.5 * drive))
            if elbow:
                over["elbow_%s" % side] = elbow[side]
        out.append((f, P(**over)))
    return out


# --- the clips ------------------------------------------------------------

CLIPS = {

    # === locomotion and rest ============================================

    # 75 frames / 2.5s, looping. A wrestler at rest is never still: he
    # breathes, and his weight rocks between two planted feet. The feet do
    # not move at all here, which is what keeps a looping idle from sliding.
    "Idle_Ready": [
        (0,  READY),
        (19, pose(READY, pelvis=(-0.02, 0.01, 0.786), spine=(-21, 6, -3),
                  head=(8, 10, 0), hand_r=(0.29, 0.49, 1.09),
                  hand_l=(-0.28, 0.52, 1.14))),
        # Breath in: the chest lifts and the hands ride up with it.
        (38, pose(READY, pelvis=(0.0, 0.0, 0.792), spine=(-19, 6, 0),
                  head=(7, 8, 0), hand_r=(0.30, 0.50, 1.12),
                  hand_l=(-0.27, 0.54, 1.16))),
        (56, pose(READY, pelvis=(0.02, -0.005, 0.776), spine=(-22, 5, 3),
                  head=(9, 6, 0), hand_r=(0.31, 0.51, 1.07),
                  hand_l=(-0.26, 0.55, 1.12))),
        (75, READY),
    ],

    # 16 frames / 0.533s, looping: two steps, generated by _gait() above.
    #
    # Labelled a stalk, and at MOVE_SPEED 3.5 m/s that is a generous word for
    # it -- 3.5 m/s is a jog, not a circle. The clip is now honest about the
    # speed it is played at rather than about the word: contact is 5 frames
    # (0.167 s) covering 0.583 m, which is 3.50 m/s under the boot, and the
    # remaining 37% of the cycle is flight. The tabled version it replaced
    # delivered 0.42 m/s and the mat slid 6.6x under every step.
    #
    # Hands out and open, READY's reach, so a man walking in for the lock-up
    # carries the pose he waits in instead of snapping back to the curled,
    # chest-high guard the owner flagged off the match video. The shoulders
    # still counter the hips.
    "Walk_Stalk": _open_hands(_gait(
        frames=16, fps=FPS, speed=3.5,
        contacts={"r": (0, 5), "l": (8, 5)},
        plant_up=0.104, lift_up=0.11,
        foot_x={"r": 0.20, "l": -0.19},
        pelvis_up=0.862, pelvis_dip=0.018,
        hips_yaw=6.0, spine=(4.0, 0.0), head=(-2, 0, 0),
        hand_fwd=(0.40, 0.50), hand_up=(1.08, 1.15),
        hand_x={"r": 0.28, "l": -0.25}, elbow=None)),

    # 20 frames / 0.667s, looping: two strides, generated by _gait() above.
    #
    # The torso leans FORWARD, which needed a negative lean and for years had
    # a positive one. Spine lean is measured: at -18 the head sits 0.159 m in
    # front of the pelvis, at +24 it sits 0.107 m BEHIND it
    # (tools/blender/reach_audit.py has the sweep). This clip carried
    # `spine=(24, ...)` under a comment reading "torso drives forward at 24
    # degrees" -- so the sprint has been leaning backwards the whole time, and
    # no measurement caught it because none of them look at the torso. The
    # first rendered frame did.
    #
    # Walk_Stalk above was the same sign and is now upright rather than
    # reclined. Note STANCE itself still carries +12, a slight backward lean
    # that every clip in the set inherits; correcting that moves all 29 and is
    # its own job.
    #
    # A real sprint, which means a short hard contact and a lot of air: 3
    # frames (0.100 s) on the mat covering 0.700 m -- 7.00 m/s, RUN_SPEED
    # exactly -- and 70% of the cycle in flight. The tabled version delivered
    # 2.01 m/s against the same constant.
    #
    # The hips drop to 0.80 through each contact, which is both what absorbing
    # a sprint stride looks like and what buys the leg enough room to reach
    # +-0.35 m either side of the hip without locking the knee (thigh + calf
    # is 0.829 m; at the rest hip height that stride does not fit).
    #
    # Elbow poles are supplied on every frame by the generator, so the arms
    # solve the same way at the seam as anywhere else.
    "Run_Drive": _gait(
        frames=20, fps=FPS, speed=7.0,
        contacts={"r": (0, 3), "l": (10, 3)},
        plant_up=0.104, lift_up=0.26,
        foot_x={"r": 0.15, "l": -0.15},
        pelvis_up=0.872, pelvis_dip=0.072,
        hips_yaw=5.0, spine=(4.0, -18.0), head=(12, 0, 0),
        hand_fwd=(-0.24, 0.28), hand_up=(1.05, 1.32),
        hand_x={"r": 0.21, "l": -0.17},
        elbow={"r": (0.3, -0.9, -0.3), "l": (-0.3, -0.9, -0.3)}),

    # === the lock-up ====================================================

    # 30 frames / 1.0s, looping. Collar-and-elbow: the right hand is high on
    # the back of the other man's neck (fwd 0.52, up 1.46 -- neck height on
    # a man the same size standing 0.8 m away) and the left grips his elbow
    # (out to the left, chest height). Chest square, feet braced wide, and
    # the loop is the two of them pressuring in and giving ground, because a
    # tie-up that holds still is two men leaning on a wall.
    "Tie_Up_Collar": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(18, 0, 0),
               head=(-6, 0, 0),
               hand_r=(0.10, 0.52, 1.46), hand_l=(-0.28, 0.44, 1.28),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Driving in: hips forward, chest over the lead foot.
        (10, P(pelvis=(0.0, 0.05, 0.838), hips=(8, 0, 0), spine=(22, 0, 0),
               head=(-8, 0, 0),
               hand_r=(0.09, 0.55, 1.44), hand_l=(-0.30, 0.47, 1.26),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Giving ground, but not letting go.
        (20, P(pelvis=(0.0, -0.03, 0.850), hips=(5, 0, 0), spine=(15, 0, 0),
               head=(-4, 0, 0),
               hand_r=(0.11, 0.49, 1.48), hand_l=(-0.26, 0.41, 1.30),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        (30, P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(18, 0, 0),
               head=(-6, 0, 0),
               hand_r=(0.10, 0.52, 1.46), hand_l=(-0.28, 0.44, 1.28),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
    ],

    # === strikes ========================================================

    # 16 frames, LEFT hand, contact on frame 5 (= tick 9 of strike_jab.tres
    # after retiming). The fastest thing in the match: 3 frames of
    # anticipation, a 2-frame action, and the rest is recovery.
    #
    # The torso twist used to be NEGATIVE through contact (spine yaw -16),
    # which is the sign that drives the RIGHT shoulder forward -- the torso
    # rotating away from the arm actually throwing the punch. Two things
    # followed from it, and both were measured on the shipped clip:
    #
    #   1. The left shoulder sat at fwd -0.119, BEHIND the body origin, so
    #      the furthest the fist could reach was 0.42 m. The pose table asked
    #      for 0.56, which is 0.685 m from a shoulder with 0.544 m of arm --
    #      14 cm beyond reach. _two_bone_ik clamps to (l1+l2)*0.995 and
    #      solves along the direction, so the truncation ate almost the whole
    #      forward component.
    #   2. Frames 5 and 8 both truncated onto the same reach sphere, which
    #      collapsed them into nearly the same pose. The clip's actual peak
    #      drifted to tick 18 -- six ticks past the contact window
    #      strike_jab.tres declares -- and the punch read as 7 cm of ooze
    #      rather than a strike: 2.83 m/s where the cross manages 7.20.
    #
    # Measured on this rig, sweeping spine yaw with the hips following at
    # half (tools/anim/reach_audit.gd reproduces it):
    #
    #   yaw -16 -> left shoulder fwd -0.106, fist can reach 0.422
    #   yaw   0 -> fwd -0.036, reach 0.492
    #   yaw +28 -> fwd +0.116, reach 0.644
    #   yaw +28 with clav_l protracted +20 -> fwd +0.189, reach 0.717
    #
    # So the twist is positive through contact and the clavicle protracts,
    # which is what a real jab does with its shoulder. The hand target is set
    # at 0.66 fwd, landing the wrist 0.50 m from the shoulder -- 0.92 of the
    # arm, extended but not locked out, and with margin rather than clamped.
    "Strike_Jab": [
        (0,  P()),
        # Anticipation is small and mostly weight -- a jab that winds up is
        # a jab you can see coming. The left shoulder loads BACK (yaw 0,
        # down from the stance's +6), which is the half-beat the drive below
        # unwinds.
        (3,  P(pelvis=(0.02, 0.0, 0.858), hips=(0, -4, 0), spine=(-10, 0, 0),
               hand_l=(-0.18, 0.34, 1.35), hand_r=(0.24, 0.35, 1.31))),
        # Contact: the left shoulder drives through and protracts, the fist
        # arrives at head height 0.66 forward, and the lead foot takes the
        # weight while the back heel pivots off the mat. The head counters
        # the chest so he is still looking at the man he is hitting.
        (5,  P(pelvis=(-0.02, 0.06, 0.862), hips=(-4, 14, 0),
               spine=(-10, 28, 0), head=(8, -20, 0), clav_l=(0, 20, 0),
               hand_l=(-0.06, 0.66, 1.40), hand_r=(0.22, 0.32, 1.30),
               foot_l=(-0.19, 0.18, 0.104), foot_r=(0.23, -0.17, 0.125),
               ankle_r=(20, 0, 0))),
        # Retracting, not stopping: the hand is already on its way back and
        # the shoulder is unwinding, so the clip's peak stays on frame 5.
        (8,  P(pelvis=(-0.01, 0.04, 0.860), hips=(-4, 10, 0),
               spine=(-10, 20, 0), head=(6, -14, 0), clav_l=(0, 12, 0),
               hand_l=(-0.09, 0.52, 1.38), hand_r=(0.22, 0.32, 1.30),
               foot_r=(0.23, -0.17, 0.118), ankle_r=(14, 0, 0))),
        (16, P()),
    ],

    # 20 frames, RIGHT forearm, contact on frame 6 (= tick 12 of
    # strike_cross.tres). The power is in the torso: the wind-up turns the
    # right shoulder back 14 degrees and the contact frame has swung it 20
    # forward, with the back foot pivoting so the hip can follow.
    "Strike_Forearm": [
        (0,  P()),
        (4,  P(pelvis=(0.05, -0.02, 0.852), hips=(0, 4, 0), spine=(-10, 16, 0),
               head=(4, 14, 0),
               hand_r=(0.30, 0.16, 1.32), hand_l=(-0.19, 0.36, 1.35))),
        # Contact: forearm arrives across at head height, hips already open.
        # Contact. The right shoulder drives through and protracts, the same
        # mechanism the jab uses mirrored -- negative yaw and negative clav_r
        # are what carry the RIGHT shoulder forward.
        #
        # This used to ask for 0.55 fwd off a shoulder at +0.079, which is
        # inside reach and so solved cleanly -- the cross was the one strike
        # in the set that measured correctly, and it is what proved the jab's
        # diagnosis. But 0.55 made the cross SHORTER than the jab's 0.655,
        # and a rear-hand cross thrown off a rotating torso is the longer
        # punch of the two, not the shorter one.
        #
        # It also cost the AI its spacing. With a single 1.15 m hit range the
        # difference was invisible; once each strike reached only as far as
        # its own limb, the cross topped out at 1.07 m centre-to-centre while
        # WrestlerAI circles at 1.10 -- so the cross could never land from the
        # distance the AI actually holds.
        #
        # Measured on this rig (tools/blender/reach_audit.py --sweep):
        #
        #   yaw -20            -> right shoulder fwd +0.079, fist reaches 0.607
        #   yaw -30            -> fwd +0.134, reaches 0.662
        #   yaw -30, clav -20  -> fwd +0.205, reaches 0.733
        #
        # 0.68 puts the wrist 0.509 m from the shoulder: 0.94 of the arm,
        # extended and still short of the lockout the solver clamps at.
        (6,  P(pelvis=(-0.02, 0.07, 0.866), hips=(-4, -15, 0),
               spine=(-10, -30, 0), head=(8, 18, 0), clav_r=(0, -20, 0),
               hand_r=(-0.02, 0.68, 1.40), hand_l=(-0.22, 0.28, 1.28),
               foot_r=(0.23, -0.17, 0.125), ankle_r=(22, 0, 0))),
        # Unwinding and retracting, so the clip's peak stays on frame 6 where
        # strike_cross.tres applies its damage.
        (9,  P(pelvis=(-0.03, 0.05, 0.862), hips=(-4, -13, 0),
               spine=(-10, -24, 0), head=(6, 12, 0), clav_r=(0, -12, 0),
               hand_r=(-0.16, 0.56, 1.36), hand_l=(-0.24, 0.26, 1.26),
               foot_r=(0.23, -0.17, 0.120), ankle_r=(18, 0, 0))),
        (20, P()),
    ],

    # 20 frames, right boot to the midsection, contact on frame 5 (= tick 8
    # of strike_kick.tres). Chamber first: the knee comes up folded before
    # anything extends, which is what separates a kick from a swung leg.
    # The arms do what a kicker's arms do -- out for balance, not pumping.
    "Strike_Kick": [
        (0,  P()),
        # Chamber, and the weight goes fully onto the left foot.
        (3,  P(pelvis=(-0.04, 0.0, 0.848), hips=(0, -6, 4), spine=(-4, 0, -6),
               foot_r=(0.16, 0.34, 0.60), knee_r=(0.3, 1.0, 0.1),
               hand_r=(0.28, 0.16, 1.26), hand_l=(-0.24, 0.20, 1.30))),
        # Contact: the knee straightens into the target at body height and
        # the torso leans away as the counterweight.
        (5,  P(pelvis=(-0.06, 0.0, 0.852), hips=(6, -10, 8),
               spine=(14, 0, -14), head=(-10, -6, 0),
               foot_r=(0.10, 0.76, 0.92), knee_r=(0.3, 1.0, 0.1),
               hand_r=(0.34, -0.08, 1.20), hand_l=(-0.34, 0.12, 1.30))),
        (8,  P(pelvis=(-0.06, 0.0, 0.850), hips=(7, -12, 8),
               spine=(16, 0, -16), head=(-12, -8, 0),
               foot_r=(0.08, 0.82, 0.86), knee_r=(0.3, 1.0, 0.1),
               hand_r=(0.36, -0.12, 1.18), hand_l=(-0.36, 0.10, 1.29))),
        # The leg folds back down under him rather than dropping straight.
        (12, P(pelvis=(-0.04, 0.02, 0.846), spine=(-6, 0, -6),
               foot_r=(0.18, 0.28, 0.34), knee_r=(0.3, 1.0, 0.1),
               hand_r=(0.26, 0.18, 1.26), hand_l=(-0.26, 0.22, 1.30))),
        (20, P()),
    ],

    # 29 frames, contact on frame 6 (= tick 12 of strike_kick_heavy.tres).
    # The same boot wound further back and recovered from properly: its
    # length is 40 ticks of recovery, never a slower action phase. It
    # finishes by stepping the kicking foot back down into the stance, which
    # is a real step rather than a slide back to where it started.
    "Strike_Kick_Heavy": [
        (0,  P()),
        # Load: the leg draws back and the hips coil the other way.
        (3,  P(pelvis=(-0.05, 0.0, 0.838), hips=(-2, 10, 4), spine=(-6, 16, 0),
               head=(4, 10, 0),
               foot_r=(0.30, -0.30, 0.14), knee_r=(0.4, 1.0, 0.0),
               hand_r=(0.30, 0.10, 1.28), hand_l=(-0.22, 0.26, 1.34))),
        # Contact: hips whip open through the kick.
        (6,  P(pelvis=(-0.07, 0.0, 0.856), hips=(6, -20, 10),
               spine=(16, -10, -16), head=(-12, -12, 0),
               foot_r=(0.06, 0.80, 1.00), knee_r=(0.3, 1.0, 0.1),
               hand_r=(0.36, -0.14, 1.16), hand_l=(-0.36, 0.10, 1.28))),
        # Follow-through sweeps across the body, hips still turning.
        (10, P(pelvis=(-0.07, 0.0, 0.852), hips=(7, -34, 10),
               spine=(18, -22, -18), head=(-14, -20, 0),
               foot_r=(-0.08, 0.76, 0.94), knee_r=(0.1, 1.0, 0.1),
               hand_r=(0.34, -0.20, 1.14), hand_l=(-0.38, 0.06, 1.26))),
        # The leg comes down across him -- he is now turned out of stance.
        (16, P(pelvis=(-0.04, 0.05, 0.820), hips=(-4, -28, 4),
               spine=(-10, -20, 0), head=(4, -14, 0),
               foot_r=(-0.16, 0.34, 0.22), knee_r=(0.0, 1.0, 0.2),
               hand_r=(0.24, 0.14, 1.22), hand_l=(-0.28, 0.24, 1.28))),
        # Plants crossed in front, weight briefly on the wrong foot.
        (21, P(pelvis=(-0.02, 0.06, 0.804), hips=(-4, -20, 0),
               spine=(-12, -14, 0), head=(4, -8, 0),
               foot_r=(-0.10, 0.30, 0.104), knee_r=(0.0, 1.0, 0.1),
               hand_r=(0.20, 0.20, 1.24), hand_l=(-0.24, 0.28, 1.30))),
        # Steps it back out to the stance -- lifted, not slid.
        (25, P(pelvis=(-0.01, 0.04, 0.834), hips=(-2, -10, 0),
               spine=(-10, -4, 0),
               foot_r=(0.08, 0.04, 0.160), knee_r=(0.2, 1.0, 0.1),
               hand_r=(0.18, 0.26, 1.28), hand_l=(-0.18, 0.32, 1.33))),
        (29, P()),
    ],

    # === taking them ====================================================

    # 12 frames. The head snaps first and furthest, the neck follows, the
    # torso arrives a beat behind -- the overlap that reads as force
    # landing rather than a body turning as one board. He also gives ground:
    # the back foot steps out, because a man who takes a shot and does not
    # move his feet has not been hit.
    "Hit_React_Head": [
        (0,  P()),
        # Impact on frame 2, not frame 5. combat-animation.md's hit reaction
        # is "2-4 frames impact pose, 8-12 frames stagger, snap to impact";
        # the previous version took five frames to reach its deepest pose,
        # which is an ease rather than a snap.
        (2,  P(pelvis=(0.02, -0.06, 0.850), hips=(3, 6, 0),
               spine=(12, 14, -4), head=(20, 20, -12),
               hand_r=(0.24, 0.18, 1.18), hand_l=(-0.20, 0.24, 1.22))),
        # Deepest: guard broken, weight on the back foot, chin turned away,
        # and the whole torso thrown back off the shot.
        #
        # The lean is the number that matters and it was measured, not
        # guessed. tools/probe/pose_compare.tscn reports how far each bone
        # travels from frame 0: this clip moved the head 6.4 cm while
        # Hit_React_Torso, on the same rig through the same code path, moved
        # it 33.8 cm. A head shot was shifting the head a fifth as far as a
        # body shot -- which is the "the opponent is hit and nothing happens"
        # report, and it is a comparison inside this clip set rather than an
        # appeal to how a punch ought to look.
        (4,  P(pelvis=(0.05, -0.12, 0.838), hips=(6, 10, 0),
               spine=(18, 20, -8), head=(24, 26, -16),
               hand_r=(0.30, 0.12, 1.10), hand_l=(-0.26, 0.16, 1.14),
               fist_r=0.55, fist_l=0.55,
               foot_r=(0.28, -0.32, 0.104), foot_l=(-0.18, 0.22, 0.118))),
        (8,  P(pelvis=(0.02, -0.04, 0.852), hips=(2, 6, 0),
               spine=(2, 10, -2), head=(10, 12, -6),
               hand_r=(0.22, 0.23, 1.22), hand_l=(-0.18, 0.28, 1.27),
               foot_r=(0.26, -0.26, 0.104))),
        (12, P()),
    ],

    # 12 frames. A body shot folds him AROUND it -- chest hollows, shoulders
    # close in, knees give and the hips drop 8 cm -- where the head reaction
    # whips him backward. Two different things happening to a man.
    "Hit_React_Torso": [
        (0,  P()),
        (2,  P(pelvis=(0.0, -0.04, 0.822), spine=(-28, 0, 0), head=(-16, 0, 0),
               hand_r=(0.12, 0.18, 1.12), hand_l=(-0.10, 0.20, 1.14),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8))),
        (5,  P(pelvis=(0.0, -0.08, 0.782), hips=(-10, 0, 0), spine=(-36, 0, 0),
               head=(-22, 0, 0),
               hand_r=(0.10, 0.14, 1.04), hand_l=(-0.08, 0.16, 1.06),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8))),
        (8,  P(pelvis=(0.0, -0.04, 0.835), spine=(-20, 0, 0), head=(-12, 0, 0),
               hand_r=(0.14, 0.22, 1.18), hand_l=(-0.11, 0.24, 1.20))),
        (12, P()),
    ],

    # 23 frames / 0.75s. On his feet and gone: guard down, chin dropped,
    # and a stagger step he does not choose. The point is that it never
    # holds a pose -- a frozen stunned clip is the exact defect this
    # replaces.
    "Stunned_Sway": [
        (0,  P(pelvis=(0.04, 0.0, 0.840), hips=(6, 6, 4), spine=(16, -8, 6),
               head=(14, -10, 0),
               hand_r=(0.30, 0.14, 1.05), hand_l=(-0.28, 0.18, 1.08),
               fist_r=0.45, fist_l=0.45)),
        # The stagger: the back foot goes looking for the floor.
        (7,  P(pelvis=(0.07, -0.03, 0.830), hips=(8, -6, 6),
               spine=(14, 10, 8), head=(18, 12, 0),
               hand_r=(0.32, 0.10, 1.02), hand_l=(-0.30, 0.14, 1.04),
               fist_r=0.4, fist_l=0.4,
               foot_r=(0.31, -0.27, 0.104))),
        (14, P(pelvis=(-0.03, 0.03, 0.846), hips=(5, 8, -4),
               spine=(18, -12, -4), head=(12, -16, 0),
               hand_r=(0.27, 0.18, 1.09), hand_l=(-0.25, 0.22, 1.12),
               fist_r=0.45, fist_l=0.45,
               foot_r=(0.31, -0.27, 0.104))),
        (23, P(pelvis=(0.02, 0.0, 0.838), hips=(6, 2, 2), spine=(16, -2, 4),
               head=(15, 4, 0),
               hand_r=(0.29, 0.15, 1.06), hand_l=(-0.27, 0.19, 1.09),
               fist_r=0.45, fist_l=0.45,
               foot_r=(0.31, -0.27, 0.104))),
    ],

    # 40 frames / 1.333s, looping. A dropped wrestler is not a corpse: he is
    # on his back with his knees up, and he is still breathing. The loop is
    # the breath and a knee rocking, nothing else.
    "Down_Supine": [
        (0,  S()),
        (13, S(spine=(-9, 0, 0), head=(-11, 0, -4),
               foot_r=(-0.19, -0.50, 0.10), foot_l=(0.14, -0.50, 0.10),
               hand_r=(-0.41, 0.18, 0.10), hand_l=(0.38, 0.18, 0.10))),
        (26, S(spine=(-4, 0, 0), head=(-16, 0, 5),
               foot_r=(-0.15, -0.53, 0.10), foot_l=(0.18, -0.46, 0.10))),
        (40, S()),
    ],

    # 63 frames / 2.1s. Prone -> off the mat -> onto a knee -> crouched ->
    # standing. Those beats are kept where the previous version had them,
    # and that is behavioural rather than cosmetic: the input-driven fast
    # rise (GETUP_RISE_FAST_TICKS, 1.14s) plays this same clip and is cut
    # off partway through, so moving a beat changes what a fast getup is.
    "Getup_Rise": [
        (0,  S()),
        # Onto his side first. Down on his back is SUPINE's 180-degree roll
        # and the next beat is face-down, and a quaternion key straight
        # across that half-turn has no preferred way round -- the key between
        # decides it, and decides it is a roll rather than a tumble.
        (5,  S(pelvis=(0.03, 0.0, 0.20), hips=(-78, -10, 100),
               spine=(-6, -8, 0), head=(-4, -6, 0),
               hand_r=(0.10, 0.20, 0.30), hand_l=(0.36, 0.10, 0.10),
               elbow_r=(0.4, 0.2, 0.8), elbow_l=(0.7, 0.3, -0.3),
               foot_r=(0.02, -0.46, 0.14), foot_l=(0.16, -0.44, 0.10),
               knee_r=(0.6, 0.2, 0.6), knee_l=(0.8, 0.0, 0.4))),
        # Rolls toward his front and gets a hand on the mat.
        (10, S(pelvis=(0.06, 0.0, 0.21), hips=(-70, -20, 22),
               spine=(-4, -14, 0), head=(10, -10, 0),
               hand_r=(0.30, 0.14, 0.09), hand_l=(-0.30, -0.18, 0.13),
               foot_r=(0.20, 0.34, 0.11), foot_l=(-0.10, 0.32, 0.14),
               knee_r=(0.5, 0.3, 0.9), knee_l=(-0.4, 0.4, 0.8))),
        # Knees drawn up under him, feet off the mat: a breakdown only, the
        # beats either side stay put. Without it the feet travelled from in
        # front to behind him through the canvas (0.17 m deep).
        (16, dict(pelvis=(0.03, -0.01, 0.34), hips=(-64, -10, 10),
                  spine=(-10, -6, 0), head=(16, -4, 0),
                  hand_r=(0.26, 0.30, 0.07), hand_l=(-0.26, 0.20, 0.10),
                  elbow_r=(0.6, -0.4, -0.7), elbow_l=(-0.6, -0.4, -0.7),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.18, 0.02, 0.20), foot_l=(-0.16, 0.00, 0.22),
                  knee_r=(0.3, 0.9, -0.1), knee_l=(-0.3, 0.9, -0.1), free_feet=True)),
        # On all fours: both hands planted, both knees down.
        #
        # This key and the three after it had their leans the wrong way round
        # -- the pitch-sign mistake STANCE's note describes -- so he rose
        # reclining, torso tipped back off his knee. Negative now: over his
        # hands, then over the planted foot, then up.
        (22, dict(pelvis=(0.0, -0.02, 0.47), hips=(-58, 0, 0),
                  spine=(-18, 0, 0), head=(22, 0, 0),
                  hand_r=(0.24, 0.42, 0.06), hand_l=(-0.22, 0.44, 0.06),
                  elbow_r=(0.6, -0.4, -0.7), elbow_l=(-0.6, -0.4, -0.7),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.17, -0.22, 0.09), foot_l=(-0.17, -0.20, 0.09),
                  knee_r=(0.3, 0.9, -0.3), knee_l=(-0.3, 0.9, -0.3))),
        # Up onto one knee, lead foot planted flat, hand on that knee.
        (34, dict(pelvis=(0.0, 0.01, 0.575), hips=(-16, 0, 0),
                  spine=(-26, 0, 0), head=(8, 0, 0),
                  hand_r=(0.22, 0.32, 0.70), hand_l=(-0.26, 0.18, 0.62),
                  fist_r=0.2, fist_l=0.2,
                  foot_r=(0.19, -0.26, 0.09), foot_l=(-0.19, 0.30, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        # Crouched over both feet, driving up through the legs.
        (46, P(pelvis=(0.0, 0.03, 0.745), hips=(-12, 0, 0), spine=(-28, 0, 0),
               head=(6, 0, 0),
               hand_r=(0.24, 0.26, 0.96), hand_l=(-0.22, 0.30, 0.98),
               fist_r=0.4, fist_l=0.4,
               foot_r=(0.23, -0.19, 0.104), foot_l=(-0.20, 0.22, 0.104))),
        # Standing, guard still coming up -- not snapped to the stance.
        (56, P(pelvis=(0.0, 0.02, 0.848), spine=(-14, 2, 0), head=(2, 4, 0),
               hand_r=(0.20, 0.28, 1.18), hand_l=(-0.16, 0.32, 1.22),
               fist_r=0.6, fist_l=0.6)),
        (63, P()),
    ],

    # === finishing ======================================================

    # 18 frames. A LATERAL PRESS: he drops to his knees beside the man and
    # falls forward across his chest, face down, legs sprawled back with the
    # toes dug in, both arms wrapped over to the mat on the far side.
    #
    # It was a kneel -- down onto both knees beside him, torso leaning over,
    # palms on his shoulders -- and the owner asked for the cover a wrestling
    # match actually uses: the attacker lying ON the man, chest to chest. The
    # face-down half comes from the same sign rule SUPINE's note records: a
    # negative `hips` pitch tips a man forward, and -84 lays him on his front.
    #
    # His chest is the part that has to land on the other man's, so the pose
    # is built from there: the torso runs forward from the pelvis a little
    # uphill (-78, not flat) because the pelvis is down on the mat beside the
    # man while the chest is on top of him, 0.20 m up. Placement is
    # WrestlerController.COVER_*: square across the body, pelvis beside his
    # ribs, so the chest lands over his sternum.
    "Pin_Cover": [
        (0,  P(pelvis=(0.0, 0.04, 0.780), hips=(-12, 0, 0), spine=(-28, 0, 0),
               head=(-4, 0, 0),
               hand_r=(0.24, 0.46, 0.94), hand_l=(-0.22, 0.48, 0.92),
               fist_r=0.0, fist_l=0.0)),
        # Onto the knees beside him, already reaching across.
        (5,  dict(pelvis=(0.0, 0.02, 0.540), hips=(-30, 0, 0),
                  spine=(-30, 0, 0), head=(-6, 0, 0),
                  hand_r=(0.22, 0.62, 0.42), hand_l=(-0.12, 0.58, 0.40),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.19, -0.24, 0.09), foot_l=(-0.19, -0.22, 0.09),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
        # Falling across: hips out behind, chest coming down onto his.
        (11, dict(pelvis=(0.0, -0.10, 0.360), hips=(-66, 0, 0),
                  spine=(-8, 0, 0), head=(14, 20, 0),
                  hand_r=(0.20, 0.92, 0.16), hand_l=(-0.30, 0.78, 0.14),
                  elbow_r=(0.9, 0.0, 0.3), elbow_l=(-0.9, 0.0, 0.3),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.17, -0.62, 0.08), foot_l=(-0.17, -0.58, 0.08),
                  knee_r=(0.2, 0.0, -1.0), knee_l=(-0.2, 0.0, -1.0))),
        # Settled: lying across him, legs sprawled for base, toes dug in,
        # head up and turned so the face reads from the hard camera.
        (18, dict(pelvis=(0.0, -0.16, 0.300), hips=(-78, 0, 0),
                  spine=(-4, 0, 0), head=(18, 28, 0),
                  hand_r=(0.18, 0.98, 0.10), hand_l=(-0.32, 0.84, 0.10),
                  elbow_r=(0.9, 0.0, 0.3), elbow_l=(-0.9, 0.0, 0.3),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.20, -0.86, 0.07), foot_l=(-0.20, -0.82, 0.07),
                  ankle_r=(40, 0, 0), ankle_l=(40, 0, 0),
                  knee_r=(0.25, 0.0, -1.0), knee_l=(-0.25, 0.0, -1.0))),
    ],

    # 39 frames / 1.3s. There is no celebration anywhere in the 42 source
    # actions, so this could only ever be authored. Load down, explode up
    # onto the toes with both arms overhead (hands at 1.92 -- the shoulder
    # at 1.441 plus almost the full 0.547 reach), settle off the extreme,
    # one smaller second pump. Terminal state: it holds the last pose.
    # === the ring entrance ==============================================
    #
    # Played by core/match/entrance_director.gd, which moves the root. Nothing
    # in the match itself uses these.

    # 24 frames / 0.8s, looping: a brisk, upright walk to the ring -- chest
    # out, arms swinging low and loose -- where Walk_Stalk is a man circling
    # an opponent with his hands up. Generated like the stalk, so the planted
    # foot travels at exactly the speed the director moves him:
    # EntranceDirector.WALK_SPEED 1.6 m/s. Contact is 12 of 24 frames per
    # foot, so one is always down and neither is in the air -- a walk, not a
    # jog -- and the half-stride that buys is 0.32 m, inside the leg's reach.
    "Entrance_Walk": _open_hands(_gait(
        frames=24, fps=FPS, speed=1.6,
        contacts={"r": (0, 12), "l": (12, 12)},
        plant_up=0.104, lift_up=0.08,
        foot_x={"r": 0.14, "l": -0.13},
        pelvis_up=0.895, pelvis_dip=0.015,
        hips_yaw=7.0, spine=(0.0, 3.0), head=(5, 0, 0),
        hand_fwd=(-0.14, 0.16), hand_up=(0.84, 0.90),
        hand_x={"r": 0.25, "l": -0.23}, elbow=None), curl=0.5),

    # 36 frames / 1.2s: up the three treads of the ring steps, right foot
    # leading, one tread a step. World keys: fwd from the floor spot in front
    # of the bottom tread, up from the floor. The treads (ring.py
    # build_steps, 0.36 m run, 0.287 rise) put the foot targets at fwd
    # 0.54 / 0.90 / 1.26 and tread tops at 0.29 / 0.57 / 0.86, so the root
    # travels (1.26, 0.86): EntranceDirector.CLIMB_TO.
    #
    # Every key keeps both feet inside the 0.829 m leg: the pelvis waits over
    # the trailing foot until the lead one is down, then transfers -- that
    # wait is most of what makes it read as climbing rather than floating up.
    "Climb_Steps": _world_clip(36, (1.26, 0.86), [
        (0,  pose(STANCE, pelvis=(0.0, 0.0, 0.90), hips=(-4, 0, 0),
                  spine=(-6, 0, 0), head=(4, 0, 0),
                  hand_r=(0.25, 0.04, 0.88), hand_l=(-0.23, 0.02, 0.88),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 0.0, 0.104), foot_l=(-0.13, 0.0, 0.104),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        (5,  pose(STANCE, pelvis=(0.0, 0.08, 0.90), hips=(-10, 0, 0),
                  spine=(-10, 0, 0), head=(6, 0, 0),
                  hand_r=(0.25, -0.05, 0.90), hand_l=(-0.23, 0.22, 0.92),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 0.30, 0.50), foot_l=(-0.13, 0.0, 0.104),
                  knee_r=(0.1, 1.0, 0.3), knee_l=(-0.1, 1.0, 0.0))),
        (10, pose(STANCE, pelvis=(0.0, 0.24, 0.85), hips=(-12, 0, 0),
                  spine=(-10, 0, 0), head=(6, 0, 0),
                  hand_r=(0.25, 0.10, 0.92), hand_l=(-0.23, 0.36, 0.96),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 0.54, 0.394), foot_l=(-0.13, 0.0, 0.104),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        (15, pose(STANCE, pelvis=(0.0, 0.46, 1.10), hips=(-10, 0, 0),
                  spine=(-8, 0, 0), head=(5, 0, 0),
                  hand_r=(0.25, 0.62, 1.20), hand_l=(-0.23, 0.38, 1.10),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 0.54, 0.394), foot_l=(-0.13, 0.60, 0.80),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.3))),
        (20, pose(STANCE, pelvis=(0.0, 0.60, 1.20), hips=(-12, 0, 0),
                  spine=(-10, 0, 0), head=(6, 0, 0),
                  hand_r=(0.25, 0.66, 1.26), hand_l=(-0.23, 0.90, 1.34),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 0.54, 0.394), foot_l=(-0.13, 0.90, 0.674),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        (25, pose(STANCE, pelvis=(0.0, 0.84, 1.45), hips=(-10, 0, 0),
                  spine=(-8, 0, 0), head=(5, 0, 0),
                  hand_r=(0.25, 1.12, 1.62), hand_l=(-0.23, 0.86, 1.52),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 1.05, 1.08), foot_l=(-0.13, 0.90, 0.674),
                  knee_r=(0.1, 1.0, 0.3), knee_l=(-0.1, 1.0, 0.0))),
        (30, pose(STANCE, pelvis=(0.0, 0.94, 1.49), hips=(-10, 0, 0),
                  spine=(-8, 0, 0), head=(5, 0, 0),
                  hand_r=(0.25, 1.00, 1.60), hand_l=(-0.23, 1.22, 1.66),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 1.26, 0.964), foot_l=(-0.13, 0.90, 0.674),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        (36, pose(STANCE, pelvis=(0.0, 1.26, 1.74), hips=(-6, 0, 0),
                  spine=(-8, 0, 0), head=(4, 0, 0),
                  hand_r=(0.25, 1.30, 1.74), hand_l=(-0.23, 1.28, 1.74),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, 1.26, 0.964), foot_l=(-0.13, 1.26, 0.964),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
    ]),

    # 48 frames / 1.6s: from the top tread through the ropes onto the mat.
    # World keys: fwd from the top tread's centre, up from its top. The rope
    # line is 0.34 ahead (the ring's 3.1 against the tread centre's 3.44),
    # the mat 0.24 up, the middle rope 1.09 up and the top 1.44. Between the
    # middle and top ropes is how it is done: up onto the apron edge, lead
    # leg high over the middle rope, fold under the top one, straddle, trail
    # leg over, stand. The root travels (0.90, 0.24): EntranceDirector.ROPE_TO.
    #
    # The straddle is the tight key: the hips have to clear the middle rope
    # (1.09) while both feet reach the mat and the apron, which is only
    # possible from the apron -- from the tread the trailing leg is 0.2 m
    # short -- hence the first step up onto it.
    "Rope_Step_Through": _world_clip(48, (0.90, 0.24), [
        (0,  pose(STANCE, pelvis=(0.0, 0.0, 0.86), hips=(-4, 0, 0),
                  spine=(-8, 0, 0), head=(4, 0, 0),
                  hand_r=(0.28, 0.30, 1.40), hand_l=(-0.28, 0.30, 1.40),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.14, 0.0, 0.104), foot_l=(-0.13, 0.0, 0.104),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        # Hands on the top rope, left foot up onto the apron edge.
        (8,  pose(STANCE, pelvis=(0.0, 0.14, 1.00), hips=(-8, 0, 0),
                  spine=(-12, 0, 0), head=(4, 0, 0),
                  hand_r=(0.30, 0.34, 1.44), hand_l=(-0.30, 0.34, 1.44),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.14, 0.0, 0.104), foot_l=(-0.13, 0.28, 0.344),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.2))),
        # Lead leg high over the middle rope; he starts to fold.
        (16, pose(STANCE, pelvis=(0.0, 0.22, 1.10), hips=(-24, 0, 0),
                  spine=(-30, 0, 0), head=(10, 0, 0),
                  hand_r=(0.30, 0.34, 1.44), hand_l=(-0.30, 0.34, 1.44),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.16, 0.42, 1.22), foot_l=(-0.13, 0.28, 0.344),
                  knee_r=(0.1, 0.6, 1.0), knee_l=(-0.1, 1.0, 0.0))),
        # Straddling the middle rope, folded under the top one, lead foot
        # down on the mat inside.
        (24, pose(STANCE, pelvis=(0.0, 0.46, 1.10), hips=(-46, 0, 0),
                  spine=(-30, 0, 0), head=(16, 0, 0),
                  hand_r=(0.30, 0.36, 1.44), hand_l=(-0.30, 0.36, 1.44),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.16, 0.80, 0.344), foot_l=(-0.13, 0.28, 0.344),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        # Weight inside; the trail leg comes over the rope.
        (32, pose(STANCE, pelvis=(0.0, 0.72, 1.12), hips=(-30, 0, 0),
                  spine=(-20, 0, 0), head=(10, 0, 0),
                  hand_r=(0.30, 0.70, 1.20), hand_l=(-0.30, 0.40, 1.40),
                  fist_r=0.5, fist_l=0.6,
                  foot_r=(0.16, 0.80, 0.344), foot_l=(-0.13, 0.42, 1.22),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 0.6, 1.0))),
        (40, pose(STANCE, pelvis=(0.0, 0.82, 1.10), hips=(-12, 0, 0),
                  spine=(-14, 0, 0), head=(6, 0, 0),
                  hand_r=(0.28, 1.00, 1.30), hand_l=(-0.26, 0.96, 1.32),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.16, 0.80, 0.344), foot_l=(-0.13, 0.80, 0.344),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
        # Up, on the mat, in the stance -- so the walk that follows cuts on.
        (48, pose(STANCE, pelvis=(0.0, 0.92, 1.10),
                  hand_r=(STANCE["hand_r"][0], STANCE["hand_r"][1] + 0.90,
                          STANCE["hand_r"][2] + 0.24),
                  hand_l=(STANCE["hand_l"][0], STANCE["hand_l"][1] + 0.90,
                          STANCE["hand_l"][2] + 0.24),
                  foot_r=(STANCE["foot_r"][0], STANCE["foot_r"][1] + 0.90,
                          STANCE["foot_r"][2] + 0.24),
                  foot_l=(STANCE["foot_l"][0], STANCE["foot_l"][1] + 0.90,
                          STANCE["foot_l"][2] + 0.24),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0))),
    ]),

    "Win_Celebrate": [
        (0,  P()),
        # Anticipation: everything sinks and loads downward.
        (5,  P(pelvis=(0.0, 0.0, 0.800), hips=(8, 0, 0), spine=(22, 0, 0),
               head=(14, 0, 0),
               hand_r=(0.30, 0.02, 0.98), hand_l=(-0.28, 0.04, 1.00),
               fist_r=0.5, fist_l=0.5)),
        # The explosion: arms overhead, chest open, heels off the mat.
        (14, P(pelvis=(0.0, -0.02, 0.905), hips=(-6, 0, 0),
               spine=(-14, 0, 0), head=(-20, 0, 0),
               hand_r=(0.34, 0.06, 1.92), hand_l=(-0.32, 0.06, 1.94),
               elbow_r=(0.8, -0.3, -0.4), elbow_l=(-0.8, -0.3, -0.4),
               fist_r=1.0, fist_l=1.0,
               foot_r=(0.23, -0.17, 0.155), foot_l=(-0.19, 0.18, 0.150),
               ankle_r=(28, 0, 0), ankle_l=(28, 0, 0))),
        (22, P(pelvis=(0.0, -0.01, 0.878), spine=(-9, 0, 0), head=(-15, 0, 0),
               hand_r=(0.36, 0.04, 1.84), hand_l=(-0.34, 0.04, 1.86),
               fist_r=1.0, fist_l=1.0,
               foot_r=(0.23, -0.17, 0.112), foot_l=(-0.19, 0.18, 0.110))),
        # A second, smaller pump -- the beat that says he means it.
        (30, P(pelvis=(0.0, -0.02, 0.896), spine=(-13, 0, 0),
               head=(-19, 0, 0),
               hand_r=(0.33, 0.06, 1.90), hand_l=(-0.31, 0.06, 1.92),
               fist_r=1.0, fist_l=1.0,
               foot_r=(0.23, -0.17, 0.130), foot_l=(-0.19, 0.18, 0.128),
               ankle_r=(16, 0, 0), ankle_l=(16, 0, 0))),
        (39, P(pelvis=(0.0, -0.01, 0.880), spine=(-10, 0, 0),
               head=(-16, 0, 0),
               hand_r=(0.35, 0.05, 1.86), hand_l=(-0.33, 0.05, 1.88),
               fist_r=1.0, fist_l=1.0,
               foot_r=(0.23, -0.17, 0.112), foot_l=(-0.19, 0.18, 0.110))),
    ],

    # === the running attack =============================================

    # 35 frames / 1.15s -- the length both running_attack_*.tres share. A
    # clothesline does not swing: the arm is out and LOCKED before contact
    # and the run supplies the force, which is why no retiming of a punch
    # ever produced one. Two strides, the arm comes up on the second, and
    # the follow-through keeps turning him past the man he hit.
    "Running_Clothesline": [
        (0,  P(pelvis=(0.0, 0.04, 0.858), spine=(24, 4, 0), head=(-14, 0, 0),
               foot_r=(0.15, 0.28, 0.115), foot_l=(-0.15, -0.30, 0.22),
               hand_r=(0.22, -0.06, 1.22), hand_l=(-0.16, 0.34, 1.42))),
        (6,  P(pelvis=(0.0, 0.04, 0.870), spine=(23, 0, 0), head=(-13, 0, 0),
               foot_r=(0.15, -0.14, 0.16), foot_l=(-0.15, 0.14, 0.30),
               hand_r=(0.26, 0.10, 1.32), hand_l=(-0.20, 0.10, 1.28))),
        # The arm goes out and locks -- straight, level, at throat height,
        # and pointed FORWARD where a ringside camera sees it in profile.
        # Aimed across the chest (tried first) it hid behind his own torso
        # from the side and read as a man running with his arms tucked in.
        (12, P(pelvis=(0.0, 0.04, 0.862), spine=(16, -8, 0), head=(-10, -6, 0),
               foot_r=(0.15, 0.26, 0.115), foot_l=(-0.15, -0.26, 0.20),
               hand_r=(0.02, 0.50, 1.44), hand_l=(-0.30, -0.10, 1.24),
               elbow_r=(0.5, -0.6, -0.6), fist_r=0.9)),
        # Contact: nothing about the arm changes, the BODY arrives.
        (18, P(pelvis=(0.0, 0.06, 0.852), hips=(4, -20, 0),
               spine=(12, -26, 0), head=(-8, -18, 0),
               foot_r=(0.18, 0.10, 0.104), foot_l=(-0.16, -0.22, 0.14),
               hand_r=(-0.20, 0.46, 1.44), hand_l=(-0.34, -0.16, 1.22),
               elbow_r=(0.4, -0.6, -0.6), fist_r=0.9)),
        # Follow-through: he keeps turning, because he cannot not.
        (24, P(pelvis=(0.0, 0.02, 0.836), hips=(6, -40, 0),
               spine=(10, -44, 0), head=(-6, -30, 0),
               foot_r=(0.20, 0.04, 0.104), foot_l=(-0.22, -0.24, 0.104),
               hand_r=(-0.44, 0.14, 1.40), hand_l=(-0.24, -0.28, 1.20),
               fist_r=0.7)),
        (30, P(pelvis=(0.0, 0.02, 0.848), hips=(4, -22, 0),
               spine=(12, -24, 0), head=(-4, -14, 0),
               foot_r=(0.22, -0.06, 0.104), foot_l=(-0.21, -0.10, 0.104),
               hand_r=(-0.10, 0.10, 1.30), hand_l=(-0.18, -0.06, 1.26))),
        (35, P()),
    ],

    # 24 frames / 0.8s. A whip turns the HIPS and slings the other man past
    # you -- it is not a shove straight ahead. Coil right, open left, and
    # the hand opens at the release because he has let go of a wrist.
    "Irish_Whip_Throw": [
        (0,  P(hand_r=(0.14, 0.42, 1.24), fist_r=0.4)),
        # Coil: hips and shoulders wind back together, weight loads right.
        (6,  P(pelvis=(0.05, -0.04, 0.845), hips=(4, 16, 0), spine=(14, 20, 0),
               head=(-2, 18, 0),
               hand_r=(0.30, 0.16, 1.16), hand_l=(-0.10, 0.30, 1.30),
               fist_r=0.5)),
        # Sling: hips lead, the arm follows them across.
        (12, P(pelvis=(-0.03, 0.06, 0.862), hips=(4, -26, 0),
               spine=(12, -30, 0), head=(-4, -22, 0),
               hand_r=(-0.34, 0.44, 1.30), hand_l=(-0.24, 0.22, 1.26),
               fist_r=0.4)),
        # Release: the hand opens and the arm trails the turn.
        (16, P(pelvis=(-0.04, 0.04, 0.858), hips=(4, -34, 0),
               spine=(10, -38, 0), head=(-4, -26, 0),
               hand_r=(-0.46, 0.30, 1.36), hand_l=(-0.26, 0.18, 1.24),
               fist_r=0.05)),
        (24, P()),
    ],

    # === grapple holds ==================================================

    # 30 frames / 1.0s, looping, role unknown. Both men have hands on each
    # other and neither is winning; the pressure shifts and comes back.
    # This replaced "Interact", a one-armed reach-and-point, which with both
    # wrestlers playing it rendered a lock-up as two men pointing past each
    # other.
    "Grapple_Hold_Neutral": [
        (0,  P(pelvis=(0.0, 0.0, 0.840), hips=(6, 0, 0), spine=(20, 0, 0),
               head=(-4, 0, 0),
               hand_r=(0.12, 0.50, 1.42), hand_l=(-0.26, 0.46, 1.30),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        (10, P(pelvis=(0.0, 0.04, 0.832), hips=(8, -4, 0), spine=(24, -4, 0),
               head=(-6, -4, 0),
               hand_r=(0.11, 0.53, 1.40), hand_l=(-0.28, 0.49, 1.28),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        (20, P(pelvis=(0.0, -0.02, 0.846), hips=(5, 4, 0), spine=(17, 4, 0),
               head=(-3, 4, 0),
               hand_r=(0.13, 0.48, 1.44), hand_l=(-0.24, 0.44, 1.32),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        (30, P(pelvis=(0.0, 0.0, 0.840), hips=(6, 0, 0), spine=(20, 0, 0),
               head=(-4, 0, 0),
               hand_r=(0.12, 0.50, 1.42), hand_l=(-0.26, 0.46, 1.30),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
    ],

    # 30 frames / 1.0s, looping. A front waistlock bends at the waist and
    # wraps LOW -- hands together at the other man's hips, head up and past
    # his shoulder, feet back so he can drive. This replaced
    # "PickUp_Table", which lifts furniture with a straight back.
    "Grapple_Hold_Attacker": [
        (0,  P(pelvis=(0.0, 0.04, 0.800), hips=(10, 0, 0), spine=(42, 0, 0),
               head=(-32, 0, 8),
               hand_r=(0.07, 0.52, 0.92), hand_l=(-0.11, 0.54, 0.90),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
        # Squeezes and tries to break him off the mat.
        (10, P(pelvis=(0.0, 0.02, 0.842), hips=(6, 0, 0), spine=(34, 0, 0),
               head=(-28, 0, 8),
               hand_r=(0.06, 0.50, 1.00), hand_l=(-0.10, 0.52, 0.98),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
        (20, P(pelvis=(0.0, 0.05, 0.792), hips=(11, 0, 0), spine=(44, 0, 0),
               head=(-33, 0, 8),
               hand_r=(0.07, 0.53, 0.89), hand_l=(-0.11, 0.55, 0.87),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
        (30, P(pelvis=(0.0, 0.04, 0.800), hips=(10, 0, 0), spine=(42, 0, 0),
               head=(-32, 0, 8),
               hand_r=(0.07, 0.52, 0.92), hand_l=(-0.11, 0.54, 0.90),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
    ],

    # 30 frames / 1.0s, looping. The man being held played "Death01" -- a
    # corpse. He is bent over the top of the waistlock, hands fighting the
    # grip, feet sprawled back and wide so he cannot be lifted.
    "Grapple_Hold_Defender": [
        (0,  P(pelvis=(0.0, -0.04, 0.780), hips=(12, 0, 0), spine=(46, 0, 0),
               head=(-30, 0, 0),
               hand_r=(0.24, 0.44, 0.90), hand_l=(-0.22, 0.46, 0.88),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.29, -0.34, 0.104), foot_l=(-0.27, -0.30, 0.104))),
        # Sprawls harder -- hips back and down, all of it into his grip.
        (10, P(pelvis=(0.0, -0.08, 0.762), hips=(14, 0, 0), spine=(50, 0, 0),
               head=(-32, 0, 0),
               hand_r=(0.26, 0.46, 0.86), hand_l=(-0.24, 0.48, 0.84),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.29, -0.36, 0.104), foot_l=(-0.27, -0.32, 0.104))),
        (20, P(pelvis=(0.0, -0.02, 0.792), hips=(11, 0, 0), spine=(43, 0, 0),
               head=(-28, 0, 0),
               hand_r=(0.23, 0.42, 0.93), hand_l=(-0.21, 0.44, 0.91),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.29, -0.33, 0.104), foot_l=(-0.27, -0.29, 0.104))),
        (30, P(pelvis=(0.0, -0.04, 0.780), hips=(12, 0, 0), spine=(46, 0, 0),
               head=(-30, 0, 0),
               hand_r=(0.24, 0.44, 0.90), hand_l=(-0.22, 0.46, 0.88),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.29, -0.34, 0.104), foot_l=(-0.27, -0.30, 0.104))),
    ],

    # 18 frames / 0.6s. He has just put someone down: still bent over the
    # spot, chest opening as he comes back up off the impact. This replaced
    # "Jump_Land", which is a man absorbing a drop he took himself.
    "Move_Exec_Impact": [
        (0,  P(pelvis=(0.0, 0.06, 0.720), hips=(14, 0, 0), spine=(42, 0, 0),
               head=(-16, 0, 0),
               hand_r=(0.26, 0.46, 0.34), hand_l=(-0.24, 0.48, 0.36),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.6, fist_l=0.6)),
        (4,  P(pelvis=(0.0, 0.05, 0.762), hips=(11, 0, 0), spine=(32, 0, 0),
               head=(-14, 0, 0),
               hand_r=(0.26, 0.44, 0.52), hand_l=(-0.24, 0.46, 0.54),
               fist_r=0.6, fist_l=0.6)),
        (9,  P(pelvis=(0.0, 0.03, 0.822), hips=(8, 0, 0), spine=(18, 0, 0),
               head=(-8, 0, 0),
               hand_r=(0.24, 0.38, 0.94), hand_l=(-0.20, 0.40, 0.96),
               fist_r=0.5, fist_l=0.5)),
        (18, P()),
    ],

    # 40 frames / 1.333s. The biggest moment in a match, and it used to be
    # "Sword_Attack" -- a man chopping at the air. Load deep, haul up
    # through the LEGS (the hips travel 0.74 -> 0.90 while the hands go from
    # knee height to over his own head), then drive everything down.
    "Finisher_Drive": [
        (0,  P(pelvis=(0.0, 0.07, 0.740), hips=(14, 0, 0), spine=(34, 0, 0),
               head=(-12, 0, 0),
               hand_r=(0.22, 0.50, 0.66), hand_l=(-0.20, 0.52, 0.66),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.27, -0.16, 0.104), foot_l=(-0.25, 0.20, 0.104))),
        # Hauling up: hips extend first, hands follow. That order is the
        # whole reason it reads as lifting weight rather than posing.
        (10, P(pelvis=(0.0, 0.03, 0.880), hips=(2, 0, 0), spine=(10, 0, 0),
               head=(-16, 0, 0),
               hand_r=(0.20, 0.46, 1.16), hand_l=(-0.18, 0.48, 1.16),
               fist_r=0.7, fist_l=0.7,
               foot_r=(0.27, -0.16, 0.104), foot_l=(-0.25, 0.20, 0.104))),
        # The peak: carried high, chest open, up on the toes.
        (16, P(pelvis=(0.0, 0.0, 0.902), hips=(-8, 0, 0), spine=(-10, 0, 0),
               head=(-22, 0, 0),
               hand_r=(0.24, 0.32, 1.62), hand_l=(-0.22, 0.34, 1.64),
               elbow_r=(0.8, -0.2, -0.4), elbow_l=(-0.8, -0.2, -0.4),
               fist_r=0.8, fist_l=0.8,
               foot_r=(0.27, -0.16, 0.140), foot_l=(-0.25, 0.20, 0.136),
               ankle_r=(20, 0, 0), ankle_l=(20, 0, 0))),
        # The drive: everything goes down at once and he goes with it.
        (24, P(pelvis=(0.0, 0.06, 0.660), hips=(20, 0, 0), spine=(42, 0, 0),
               head=(6, 0, 0),
               hand_r=(0.26, 0.56, 0.42), hand_l=(-0.24, 0.58, 0.42),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.8, fist_l=0.8,
               foot_r=(0.27, -0.16, 0.104), foot_l=(-0.25, 0.20, 0.104))),
        (30, P(pelvis=(0.0, 0.07, 0.622), hips=(22, 0, 0), spine=(46, 0, 0),
               head=(10, 0, 0),
               hand_r=(0.27, 0.58, 0.34), hand_l=(-0.25, 0.60, 0.34),
               fist_r=0.7, fist_l=0.7,
               foot_r=(0.27, -0.16, 0.104), foot_l=(-0.25, 0.20, 0.104))),
        (40, P()),
    ],

    # 30 frames / 1.0s, looping. Someone working a hold: down on the right
    # knee -- and the hip height is measured, not picked: the thigh is 0.400
    # long, so a knee resting on the mat puts the hip near 0.55. At 0.62
    # (tried first) the same pose rendered as a man in a deep crouch, which
    # is the "Crouch_Idle" this clip exists to replace.
    # Down on the right knee, both hands gripping, hauling back on the beat and easing off.
    # This replaced "Crouch_Idle", a man crouching by himself.
    "Submission_Work": [
        (0,  dict(pelvis=(0.0, 0.0, 0.545), hips=(14, 0, 0), spine=(22, 0, 0),
                  head=(-14, 0, 0),
                  hand_r=(0.22, 0.46, 0.62), hand_l=(-0.20, 0.48, 0.60),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.20, -0.28, 0.09), foot_l=(-0.20, 0.26, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        # The haul: he sits back into it and the hands come up and in.
        (10, dict(pelvis=(0.0, -0.05, 0.570), hips=(-4, 0, 0),
                  spine=(-8, 0, 0), head=(-20, 0, 0),
                  hand_r=(0.26, 0.26, 0.80), hand_l=(-0.24, 0.28, 0.78),
                  elbow_r=(0.7, -0.4, -0.5), elbow_l=(-0.7, -0.4, -0.5),
                  fist_r=0.7, fist_l=0.7,
                  foot_r=(0.20, -0.28, 0.09), foot_l=(-0.20, 0.26, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        (20, dict(pelvis=(0.0, 0.02, 0.538), hips=(16, 0, 0),
                  spine=(26, 0, 0), head=(-12, 0, 0),
                  hand_r=(0.21, 0.49, 0.58), hand_l=(-0.19, 0.51, 0.56),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.20, -0.28, 0.09), foot_l=(-0.20, 0.26, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        (30, dict(pelvis=(0.0, 0.0, 0.545), hips=(14, 0, 0), spine=(22, 0, 0),
                  head=(-14, 0, 0),
                  hand_r=(0.22, 0.46, 0.62), hand_l=(-0.20, 0.48, 0.60),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.20, -0.28, 0.09), foot_l=(-0.20, 0.26, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
    ],

    # === paired moves ===================================================
    #
    # Both halves of each of these are keyframed against each other beat for
    # beat: the frame the knee lands on the attacker is the frame the
    # defender folds, and the two are retimed onto the same root trajectory
    # by tools/anim/build_paired_poses.gd. Nobody flips and nobody leaves
    # the mat, per the note in resources/animations/paired_recipes.gd.

    # Collar tie -> drag him down -> knee to the midsection -> shove off.
    # 30 frames; the knee lands on frame 18.
    "Clinch_Knee_Attacker": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(18, 0, 0),
               hand_r=(0.10, 0.52, 1.46), hand_l=(-0.28, 0.44, 1.28),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Drags his head down: both hands pull down and back.
        (8,  P(pelvis=(0.0, 0.02, 0.830), hips=(8, 0, 0), spine=(24, 0, 0),
               head=(-10, 0, 0),
               hand_r=(0.10, 0.40, 1.12), hand_l=(-0.22, 0.38, 1.08),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Loads the knee, weight entirely onto the left foot.
        (14, P(pelvis=(-0.04, 0.0, 0.862), hips=(6, -6, 6), spine=(20, 0, -4),
               head=(-10, 0, 0),
               hand_r=(0.11, 0.38, 1.08), hand_l=(-0.21, 0.36, 1.04),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.16, 0.30, 0.62), knee_r=(0.3, 1.0, 0.1),
               foot_l=(-0.24, 0.16, 0.104))),
        # The knee lands, and the hands pull DOWN into it.
        (18, P(pelvis=(-0.05, 0.02, 0.870), hips=(10, -8, 8),
               spine=(10, 0, -6), head=(-6, 0, 0),
               hand_r=(0.12, 0.34, 0.98), hand_l=(-0.20, 0.32, 0.96),
               fist_r=0.7, fist_l=0.7,
               foot_r=(0.12, 0.50, 0.88), knee_r=(0.3, 1.0, 0.1),
               foot_l=(-0.24, 0.16, 0.104))),
        # Shoves him off and gets the foot back down.
        (22, P(pelvis=(-0.02, 0.04, 0.848), hips=(6, 0, 2), spine=(16, 0, 0),
               hand_r=(0.16, 0.54, 1.24), hand_l=(-0.18, 0.56, 1.22),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.20, 0.14, 0.30), knee_r=(0.3, 1.0, 0.1),
               foot_l=(-0.24, 0.16, 0.104))),
        (30, P()),
    ],

    # The other side of it, frame for frame.
    "Clinch_Knee_Defender": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(18, 0, 0),
               hand_r=(0.24, 0.46, 1.34), hand_l=(-0.20, 0.48, 1.32),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        # Dragged down by the head, hands on the arms that are doing it.
        (8,  P(pelvis=(0.0, -0.04, 0.802), hips=(12, 0, 0), spine=(38, 0, 0),
               head=(10, 0, 0),
               hand_r=(0.24, 0.40, 1.10), hand_l=(-0.22, 0.42, 1.08),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        (14, P(pelvis=(0.0, -0.06, 0.788), hips=(14, 0, 0), spine=(44, 0, 0),
               head=(16, 0, 0),
               hand_r=(0.22, 0.36, 1.02), hand_l=(-0.20, 0.38, 1.00),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # The knee lands: he folds hard around it and his hands go to it.
        (18, P(pelvis=(0.0, -0.10, 0.742), hips=(18, 0, 0), spine=(52, 0, 0),
               head=(22, 0, 0),
               hand_r=(0.14, 0.26, 0.94), hand_l=(-0.12, 0.28, 0.92),
               elbow_r=(0.6, -0.3, -0.7), elbow_l=(-0.6, -0.3, -0.7),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Shoved off: he goes backward a step, still folded.
        (22, P(pelvis=(0.0, -0.16, 0.778), hips=(14, 0, 0), spine=(44, 0, 0),
               head=(18, 0, 0),
               hand_r=(0.18, 0.30, 1.02), hand_l=(-0.16, 0.32, 1.00),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.32, 0.104), foot_l=(-0.24, 0.06, 0.140))),
        (30, P()),
    ],

    # Signature. A standing neckbreaker: he takes the head, wrenches it
    # down and across to his right hip, and stays on his feet -- deliberately,
    # because a sit-out version would leave him on the mat and the state that
    # follows this expects a man who is standing.
    #
    # Rewritten against rendered frames. Every lean here was the wrong way
    # round (a positive lean tips a man BACK -- see STANCE), so he reclined
    # while "driving it to the mat"; and the victim's root trajectory lifted
    # him 0.45 m on an arc whose back-tip the rig discards, so what the camera
    # saw was a man floating straight up, draping over the attacker's back
    # and landing on his face. Nobody leaves the mat now: the wrench pulls the
    # victim forward and twists him over, the same forward-pitch-then-roll
    # SUPINE and the body slam are built from, and he lands face-up with his
    # head at the attacker's right boot.
    "Neckbreaker_Attacker": [
        (0,  P()),
        # Reaches across and takes the head.
        (8,  P(pelvis=(0.0, 0.03, 0.848), hips=(-4, -8, 0), spine=(-10, -10, 0),
               head=(-6, -8, 0),
               hand_r=(0.06, 0.60, 1.48), hand_l=(-0.12, 0.58, 1.44),
               elbow_r=(0.5, -0.5, -0.7), elbow_l=(-0.4, -0.5, -0.7),
               fist_r=0.62, fist_l=0.62)),
        # The wrench: down and across to his right hip, turning into it.
        (14, P(pelvis=(0.0, 0.04, 0.780), hips=(-10, -18, 0),
               spine=(-28, -22, 0), head=(-8, -14, 0),
               hand_r=(0.22, 0.44, 0.90), hand_l=(0.06, 0.42, 0.94),
               elbow_r=(0.5, -0.4, -0.7), elbow_l=(-0.4, -0.4, -0.7),
               fist_r=0.7, fist_l=0.7)),
        # Drives it into the mat, bent over it, knees giving with the weight.
        (20, P(pelvis=(0.0, 0.06, 0.660), hips=(-22, -20, 0),
               spine=(-44, -20, 0), head=(-14, -10, 0),
               hand_r=(0.26, 0.20, 0.34), hand_l=(0.14, 0.22, 0.38),
               elbow_r=(0.5, -0.3, -0.7), elbow_l=(-0.4, -0.3, -0.7),
               fist_r=0.8, fist_l=0.8,
               foot_r=(0.25, -0.20, 0.104), foot_l=(-0.21, 0.20, 0.104))),
        # Lets go and comes back up.
        (26, P(pelvis=(0.0, 0.03, 0.790), hips=(-8, -10, 0),
               spine=(-22, -10, 0), head=(-4, -6, 0),
               hand_r=(0.18, 0.32, 0.92), hand_l=(-0.10, 0.34, 1.00),
               fist_r=0.6, fist_l=0.6)),
        (30, P()),
    ],

    # The victim: chin caught, dragged forward and down by the head, twisted
    # over by the wrench, and dropped flat on his back. Head toward +fwd --
    # the attacker's side -- and past the roll his right side is at negative
    # `right`, as in SUPINE.
    "Neckbreaker_Defender": [
        (0,  P()),
        # Head caught: chin comes up and his hands go to the arm.
        (8,  P(pelvis=(0.0, -0.02, 0.852), spine=(-6, 0, 0), head=(18, 0, 0),
               hand_r=(0.16, 0.34, 1.40), hand_l=(-0.10, 0.30, 1.42),
               elbow_r=(0.7, -0.4, -0.5), elbow_l=(-0.7, -0.4, -0.5),
               fist_r=0.62, fist_l=0.62)),
        # Wrenched: dragged forward and down by the head, twisting, feet
        # skidding out from under him.
        (14, dict(pelvis=(0.0, 0.02, 0.700), hips=(-44, 0, 60),
                  spine=(-10, 16, 0), head=(12, 0, 0),
                  hand_r=(0.20, 0.40, 0.90), hand_l=(-0.10, 0.36, 0.96),
                  elbow_r=(0.7, -0.4, -0.4), elbow_l=(-0.7, -0.4, -0.4),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.20, -0.30, 0.14), foot_l=(-0.18, -0.22, 0.20),
                  knee_r=(0.3, 0.6, 0.4), knee_l=(-0.3, 0.6, 0.4))),
        # Over onto his side on the way down.
        (17, dict(pelvis=(0.0, 0.0, 0.420), hips=(-80, 0, 120),
                  spine=(-6, 8, 0), head=(4, 0, 0),
                  hand_r=(0.10, 0.30, 0.50), hand_l=(0.30, 0.20, 0.30),
                  elbow_r=(0.4, 0.2, 0.8), elbow_l=(0.7, 0.3, -0.3),
                  fist_r=0.3, fist_l=0.3,
                  foot_r=(0.0, -0.60, 0.30), foot_l=(0.16, -0.56, 0.26),
                  knee_r=(0.6, 0.2, 0.6), knee_l=(0.8, 0.0, 0.4))),
        # Flat on his back: the impact, arms slapped out.
        (20, S(pelvis=(0.0, 0.0, 0.200), hips=(-88, 0, 180), head=(-2, 0, 0),
               hand_l=(0.54, 0.16, 0.10),
               elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
               fist_r=0.1, fist_l=0.1,
               foot_r=(-0.14, -0.70, 0.22), foot_l=(0.12, -0.72, 0.26))),
        (26, S(pelvis=(0.0, 0.0, 0.185), spine=(-8, 0, 0), head=(-16, 0, 0))),
        (30, S()),
    ],

    # Power. A body slam, 36 frames / 1.2s: scooped, turned, held across the
    # chest, and dropped flat on his back.
    #
    # The victim is carried ALONG HIS OWN AXIS and it is the attacker who
    # turns under him. The thrown man has to land lying the way Down_Supine
    # lies -- along his own facing, head toward +fwd -- or the knockdown that
    # follows spins him a quarter-turn on the mat; and GrappleRig keeps only
    # the yaw of a defender's root key, so turning him means turning his
    # capsule, which is what the rig exists to avoid. So the attacker's root
    # yaws 90 degrees through the lift (paired_recipes.gd, the power_bodyslam
    # trajectory) and the victim, whose facing never changes, ends up lying
    # across the attacker's chest: head over his right arm, legs over his
    # left. That is where a body slam carries a man.
    #
    # Height is all bone pose. The victim's pelvis rises to 1.12 m inside a
    # root that never leaves the mat, which is what keeps the trajectory
    # clear of the airborne-landing invariant in build_paired_moves.gd.
    "Bodyslam_Attacker": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
               hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
               fist_r=0.6, fist_l=0.6)),
        # Ducks in: left arm through the legs, right hand on the chest.
        (7,  P(pelvis=(0.0, 0.10, 0.700), hips=(-10, 0, 0), spine=(-26, 0, 0),
               head=(-8, 0, 0),
               hand_r=(0.16, 0.44, 1.18), hand_l=(-0.12, 0.52, 0.78),
               elbow_r=(0.6, -0.3, -0.7), elbow_l=(-0.5, -0.3, -0.8),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.24, -0.16, 0.104), foot_l=(-0.20, 0.24, 0.104))),
        # Drives up under him, turning.
        (13, P(pelvis=(0.0, 0.04, 0.820), hips=(-4, 0, 0), spine=(-8, 0, 0),
               head=(-10, 0, 0),
               hand_r=(0.22, 0.36, 1.08), hand_l=(-0.28, 0.34, 1.22),
               elbow_r=(0.6, -0.3, -0.7), elbow_l=(-0.6, -0.3, -0.7),
               fist_r=0.6, fist_l=0.6)),
        # Up: he is across the chest, cradled at the shoulders (right arm)
        # and the thighs (left).
        (19, P(pelvis=(0.0, 0.0, 0.870), hips=(2, 0, 0), spine=(4, 0, 0),
               head=(-6, 0, 0),
               hand_r=(0.28, 0.30, 0.96), hand_l=(-0.34, 0.28, 0.94),
               elbow_r=(0.5, -0.4, -0.7), elbow_l=(-0.5, -0.4, -0.7),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.22, -0.14, 0.104), foot_l=(-0.20, 0.16, 0.104))),
        # The hang -- the beat the crowd is watching.
        (24, P(pelvis=(0.0, 0.0, 0.872), hips=(2, 0, 0), spine=(2, 0, 0),
               head=(-8, 0, 0),
               hand_r=(0.28, 0.31, 0.98), hand_l=(-0.34, 0.29, 0.96),
               elbow_r=(0.5, -0.4, -0.7), elbow_l=(-0.5, -0.4, -0.7),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.22, -0.14, 0.104), foot_l=(-0.20, 0.16, 0.104))),
        # The slam: he bends over it and follows the body down.
        (28, P(pelvis=(0.0, 0.08, 0.720), hips=(-18, 0, 0), spine=(-34, 0, 0),
               head=(-18, 0, 0),
               hand_r=(0.30, 0.52, 0.42), hand_l=(-0.34, 0.50, 0.46),
               elbow_r=(0.5, -0.2, -0.8), elbow_l=(-0.5, -0.2, -0.8),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.24, -0.20, 0.104), foot_l=(-0.20, 0.22, 0.104))),
        (31, P(pelvis=(0.0, 0.06, 0.760), hips=(-12, 0, 0), spine=(-26, 0, 0),
               head=(-14, 0, 0),
               hand_r=(0.28, 0.46, 0.60), hand_l=(-0.32, 0.44, 0.64),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.24, -0.20, 0.104), foot_l=(-0.20, 0.22, 0.104))),
        (36, P()),
    ],

    # The victim: grabbed, tipped forward over the arm that scoops him, rolled
    # over onto his back in the cradle, held flat at chest height, dropped.
    #
    # The roll is the same one SUPINE is built from -- forward pitch, then
    # 180 degrees about his own spine -- so the carry, the landing and the
    # knockdown that follows are one orientation and the handoff into
    # Down_Supine is a settle, not a flip. Head toward +fwd (the attacker's
    # right arm), legs toward -fwd (his left). Past the roll his right side is
    # at negative `right`.
    "Bodyslam_Defender": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
               hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
               fist_r=0.6, fist_l=0.6)),
        # Caught: hands to the man ducking under him.
        (7,  P(pelvis=(0.0, -0.02, 0.840), hips=(4, 0, 0), spine=(-18, 0, 0),
               head=(8, 0, 0),
               hand_r=(0.22, 0.36, 1.10), hand_l=(-0.20, 0.38, 1.08),
               fist_r=0.62, fist_l=0.62)),
        # Off his feet, tipped forward over the arm, legs swinging up behind.
        (12, dict(pelvis=(0.0, 0.0, 1.020), hips=(-50, 0, 0),
                  spine=(-10, 0, 0), head=(-10, 0, 0),
                  hand_r=(0.34, 0.44, 0.80), hand_l=(-0.32, 0.46, 0.78),
                  elbow_r=(0.8, -0.3, -0.3), elbow_l=(-0.8, -0.3, -0.3),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.14, -0.62, 0.92), foot_l=(-0.12, -0.58, 0.98),
                  knee_r=(0.2, -0.6, -0.8), knee_l=(-0.2, -0.6, -0.8))),
        # Turning over in the cradle: on his side.
        (16, dict(pelvis=(0.0, 0.0, 1.160), hips=(-86, 0, 90),
                  spine=(-4, 0, 0), head=(-8, 0, 0),
                  hand_r=(0.10, 0.30, 0.86), hand_l=(-0.10, 0.34, 0.92),
                  elbow_r=(0.6, 0.0, -0.8), elbow_l=(-0.6, 0.0, -0.8),
                  fist_r=0.4, fist_l=0.4,
                  foot_r=(-0.12, -0.80, 1.10), foot_l=(0.12, -0.80, 1.18),
                  knee_r=(0.8, 0.0, 0.4), knee_l=(0.8, 0.0, 0.4))),
        # Flat on his back across the chest, 1.1 m up; arms hanging.
        (20, dict(pelvis=(0.0, 0.0, 1.100), hips=(-88, 0, 180),
                  spine=(-4, 0, 0), head=(-10, 0, 0),
                  hand_r=(-0.40, 0.24, 0.76), hand_l=(0.36, 0.26, 0.80),
                  elbow_r=(-0.6, 0.0, -0.8), elbow_l=(0.6, 0.0, -0.8),
                  fist_r=0.3, fist_l=0.3,
                  foot_r=(-0.12, -0.84, 1.04), foot_l=(0.10, -0.86, 1.10),
                  knee_r=(-0.2, 0.0, 1.0), knee_l=(0.2, 0.0, 1.0))),
        (24, dict(pelvis=(0.0, 0.0, 1.120), hips=(-88, 0, 180),
                  spine=(-2, 0, 0), head=(-12, 0, 0),
                  hand_r=(-0.42, 0.22, 0.78), hand_l=(0.38, 0.24, 0.82),
                  elbow_r=(-0.6, 0.0, -0.8), elbow_l=(0.6, 0.0, -0.8),
                  fist_r=0.3, fist_l=0.3,
                  foot_r=(-0.12, -0.84, 1.08), foot_l=(0.10, -0.86, 1.14),
                  knee_r=(-0.2, 0.0, 1.0), knee_l=(0.2, 0.0, 1.0))),
        # Flat on his back. Arms slap out, the legs bounce once.
        (28, S(pelvis=(0.0, 0.0, 0.200), hips=(-88, 0, 180), spine=(-2, 0, 0),
               head=(-4, 0, 0),
               hand_r=(-0.56, 0.14, 0.10), hand_l=(0.56, 0.14, 0.10),
               elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
               fist_r=0.1, fist_l=0.1,
               foot_r=(-0.14, -0.74, 0.28), foot_l=(0.12, -0.76, 0.32),
               knee_r=(-0.3, 0.0, 1.0), knee_l=(0.3, 0.0, 1.0))),
        (31, S(pelvis=(0.0, 0.0, 0.180), spine=(-8, 0, 0), head=(-16, 0, 0),
               hand_r=(-0.46, 0.18, 0.10), hand_l=(0.44, 0.18, 0.10),
               foot_r=(-0.16, -0.62, 0.12), foot_l=(0.14, -0.60, 0.12))),
        (36, S()),
    ],
}


# Signature. A backbreaker, built on the body slam's lift -- which reads --
# rather than a second one derived from scratch: the same scoop, the same
# roll onto his back across the chest, and then instead of the slam the
# attacker drops onto his right knee and brings the victim down with the small
# of his back across the raised left one, arched face-up over it. He hangs
# there a beat and is poured off onto the mat in front, into SUPINE.
#
# This replaces a version whose every lean was the wrong way round (see
# STANCE): the victim, meant to be "arched backward over the knee", was draped
# face-down over the attacker's shoulder and went in head-first.
#
# Sharing the first 20 frames with the body slam is the point, not a
# shortcut: a fix to that lift is a fix to both moves.
#
# The raised knee sits at the attacker's left (-0.20), 0.28 in front and
# about 0.52 up with his pelvis at 0.565; the trajectory
# (paired_recipes.gd, signature_backbreaker) puts the victim's pelvis over
# it, and his spine and head are leaned POSITIVE past SUPINE's roll so he
# drapes down on both sides of it -- the arch.
_KNEEL = dict(
    foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
    knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1),
)
CLIPS["Backbreaker_Attacker"] = [k for k in CLIPS["Bodyslam_Attacker"] if k[0] <= 19] + [
    # Down onto the knee, bringing him with it.
    (24, dict(pelvis=(0.0, 0.02, 0.565), hips=(-6, 0, 0), spine=(-14, 0, 0),
              head=(-16, 0, 0),
              hand_r=(0.10, 0.34, 0.78), hand_l=(-0.42, 0.32, 0.64),
              elbow_r=(0.6, -0.3, -0.7), elbow_l=(-0.7, -0.3, -0.6),
              fist_r=0.5, fist_l=0.5, **_KNEEL)),
    # Presses him down over it: chest on his, one hand on the thighs.
    (29, dict(pelvis=(0.0, 0.03, 0.555), hips=(-10, 0, 0), spine=(-22, 0, 0),
              head=(-18, 0, 0),
              hand_r=(0.10, 0.36, 0.70), hand_l=(-0.44, 0.32, 0.56),
              elbow_r=(0.6, -0.3, -0.7), elbow_l=(-0.7, -0.3, -0.6),
              fist_r=0.4, fist_l=0.4, **_KNEEL)),
    # Tips him off and comes up.
    (33, P(pelvis=(0.0, 0.02, 0.720), hips=(-10, 0, 0), spine=(-20, 0, 0),
           head=(-8, 0, 0),
           hand_r=(0.18, 0.40, 0.80), hand_l=(-0.22, 0.40, 0.76),
           fist_r=0.4, fist_l=0.4)),
    (36, P()),
]

CLIPS["Backbreaker_Defender"] = [k for k in CLIPS["Bodyslam_Defender"] if k[0] <= 20] + [
    # Across the knee: pelvis over it, arched face-up, head and legs hanging.
    (24, dict(pelvis=(0.0, 0.0, 0.640), hips=(-88, 0, 180),
              spine=(26, 0, 0), head=(24, 0, 0),
              hand_r=(-0.44, 0.40, 0.22), hand_l=(0.40, 0.42, 0.24),
              elbow_r=(-0.6, 0.0, -0.8), elbow_l=(0.6, 0.0, -0.8),
              fist_r=0.1, fist_l=0.1,
              foot_r=(-0.14, -0.78, 0.20), foot_l=(0.12, -0.80, 0.24),
              knee_r=(-0.2, 0.0, 1.0), knee_l=(0.2, 0.0, 1.0))),
    # Hangs there -- the beat the crowd is watching.
    (29, dict(pelvis=(0.0, 0.0, 0.630), hips=(-88, 0, 180),
              spine=(30, 0, 0), head=(28, 0, 0),
              hand_r=(-0.44, 0.44, 0.14), hand_l=(0.40, 0.46, 0.16),
              elbow_r=(-0.6, 0.0, -0.8), elbow_l=(0.6, 0.0, -0.8),
              fist_r=0.1, fist_l=0.1,
              foot_r=(-0.14, -0.80, 0.14), foot_l=(0.12, -0.82, 0.18),
              knee_r=(-0.2, 0.0, 1.0), knee_l=(0.2, 0.0, 1.0))),
    # Poured off onto the mat.
    (33, S(pelvis=(0.0, 0.0, 0.210), spine=(-2, 0, 0), head=(-6, 0, 0),
           hand_r=(-0.50, 0.16, 0.10), hand_l=(0.50, 0.16, 0.10),
           foot_r=(-0.14, -0.66, 0.16), foot_l=(0.12, -0.66, 0.18))),
    (36, S()),
]

def _yawed(spec):
    """The same pose turned half round about the vertical, in place: every
    target mirrored through the origin, the hips yawed 180. Spine, head and
    clavicle are relative to the hips and need nothing."""
    out = dict(spec)
    for k in ("pelvis", "hand_r", "hand_l", "foot_r", "foot_l",
              "elbow_r", "elbow_l", "knee_r", "knee_l"):
        if out.get(k):
            r, f, u = out[k]
            out[k] = (-r, -f, u)
    p, y, r = out.get("hips", (0.0, 0.0, 0.0))
    out["hips"] = (p, y + 180, r)
    for k in ("ankle_r", "ankle_l", "wrist_r", "wrist_l"):
        if out.get(k):
            p, y, r = out[k]
            out[k] = (p, y + 180, r)
    return out


# Flat on his back, head AWAY from the attacker: Down_Supine's first frame
# turned half round. WrestlerController turns the root 180 on the tick the
# knockdown starts (MoveDef.defender_lands_head_away) and starts Down_Supine
# with no blend, so this and that are the same pixels.
SUPINE_AWAY = _yawed(SUPINE)


def _back_fall(hit, end, pelvis_hit=0.95, twist=0, skip_hit=False, fall_z=0.62):
    """Knocked flat on his back AWAY from the attacker, the way a real back
    bump goes: straight over backward, feet coming up toward the man who hit
    him, arms slapping out as the shoulders land. Seven frames from the blow
    to the shoulders hitting (0.23 s at 30 fps): four, tried first, dropped
    the head at 18 m/s -- a man shot, not a man bumping.

    This used to spin him: his ROOT yawed a half-turn in the air so he could
    land head toward his own +fwd, where Down_Supine lies. Measured by
    tools/probe/move_qa.tscn, that whipped his hands and feet 1.1-1.7 m in a
    single frame and drove a foot 0.3 m through the mat in every move that
    used it. Now nothing spins: he lands in SUPINE_AWAY, and the half-turn
    happens on the knockdown's first tick, invisibly (see SUPINE_AWAY)."""
    keys = []
    if not skip_hit:
        keys.append((hit, P(pelvis=(0.0, -0.08, pelvis_hit), spine=(22, twist, 0),
                            head=(30, twist, 0),
                            hand_r=(0.36, 0.10, 1.10), hand_l=(-0.34, 0.06, 1.06),
                            fist_r=0.3, fist_l=0.3)))
    keys += [
        # Going over: hips tipped back, feet leaving the mat, chin tucked,
        # arms thrown forward.
        (hit + 3, dict(pelvis=(0.0, -0.20, fall_z), hips=(42, 0, 0),
                       spine=(-12, twist // 2, 0), head=(-18, 0, 0),
                       hand_r=(0.40, 0.46, 0.96), hand_l=(-0.40, 0.44, 0.94),
                       elbow_r=(0.8, -0.3, -0.3), elbow_l=(-0.8, -0.3, -0.3),
                       fist_r=0.2, fist_l=0.2,
                       foot_r=(0.18, 0.36, 0.30), foot_l=(-0.16, 0.40, 0.34),
                       knee_r=(0.2, 0.8, 0.6), knee_l=(-0.2, 0.8, 0.6))),
        # The bump: shoulders flat, arms slapped out, legs up off the mat.
        (hit + 7, _yawed(S(pelvis=(0.0, 0.0, 0.200), head=(-2, 0, 0),
                           hand_r=(-0.56, 0.14, 0.10), hand_l=(0.56, 0.14, 0.10),
                           elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
                           fist_r=0.1, fist_l=0.1,
                           foot_r=(-0.14, -0.72, 0.30), foot_l=(0.12, -0.74, 0.34)))),
        # The legs come down; the settle.
        (hit + 11, _yawed(S(pelvis=(0.0, 0.0, 0.180), spine=(-8, 0, 0),
                           head=(-16, 0, 0)))),
        (end, dict(SUPINE_AWAY)),
    ]
    return keys


def _body(hips, pelvis, **local):
    """Limb targets given in the BODY's frame -- (right, fwd, up) from the
    pelvis as if he were standing -- carried round by the hips rotation.

    Every other target in this file is in the room's frame, which is right
    for a man on his feet and wrong for one rolling or flipping: an arm told
    "0.4 m to your right, on the mat" stays there while the body turns over
    it, and the solver drags it through the canvas to get it there. Keys
    ending in elbow_/knee_ are pole directions and are rotated, not moved."""
    rot = _euler(*hips).to_matrix()
    origin = vec(*pelvis)
    out = dict(hips=hips, pelvis=pelvis)
    for key, v in local.items():
        if not isinstance(v, tuple) or len(v) != 3:
            out[key] = v
            continue
        w = rot @ vec(*v)
        if not (key.startswith("elbow_") or key.startswith("knee_")):
            w = origin + w
        out[key] = (-w.x, -w.y, w.z)
    return out


# Legs tucked in the body's own frame, for a body upside down or turning
# over in the air -- see _body. Given no targets at all (tried first), the
# legs hung at full length and swept a metre a frame at the feet.
_TUCK_LEGS = dict(foot_r=(0.14, 0.30, -0.50), foot_l=(-0.14, 0.30, -0.54),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0), free_feet=True)


# Getting up from sitting or lying (_get_up): knees up, feet pulled in toward
# the seat, leaning forward.
GATHER = dict(pelvis=(0.0, 0.02, 0.260), hips=(16, 0, 0), spine=(-34, 0, 0),
              head=(-4, 0, 0),
              hand_r=(0.28, -0.10, 0.10), hand_l=(-0.28, -0.10, 0.10),
              elbow_r=(0.4, 0.8, 0.2), elbow_l=(-0.4, 0.8, 0.2),
              fist_r=0.0, fist_l=0.0,
              foot_r=(0.20, 0.26, 0.104), foot_l=(-0.18, 0.28, 0.104),
              knee_r=(0.2, 0.4, 1.0), knee_l=(-0.2, 0.4, 1.0))
# Half-way down a sit-out: seat dropping, feet sliding out in front. From
# standing straight to ATK_SEAT the feet swung through the mat on the way.
SIT_DROP = dict(pelvis=(0.0, 0.0, 0.480), hips=(24, 0, 0), spine=(-8, 0, 0),
                head=(-8, 0, 0),
                hand_r=(0.14, 0.34, 0.80), hand_l=(-0.14, 0.34, 0.80),
                fist_r=0.6, fist_l=0.6,
                foot_r=(0.18, 0.34, 0.14), foot_l=(-0.18, 0.30, 0.14),
                knee_r=(0.2, 0.6, 0.8), knee_l=(-0.2, 0.6, 0.8), free_feet=True)


# Up off his side (after a kick that lands him on it): turned half back to
# the front, pushing off the lower hand, top knee up, under knee on the mat,
# both feet still out to his right where his legs lay.
# Straight from the side to the crouch, the under leg swept through the mat.
SIDE_PUSH = dict(pelvis=(0.0, 0.02, 0.340), hips=(-24, 0, -44), spine=(-14, 0, 14),
                 head=(0, 0, 10),
                 hand_r=(0.46, 0.16, 0.08), hand_l=(-0.06, 0.40, 0.40),
                 fist_r=0.0, fist_l=0.2,
                 foot_r=(0.44, 0.24, 0.104), foot_l=(0.30, -0.16, 0.12),
                 knee_r=(0.6, 1.0, 0.4), knee_l=(0.2, 1.0, -0.2))


# Tucked for a roll along the mat: forearms in to the chest, legs long.
_ROLL_LIMBS = dict(
    hand_r=(0.14, 0.16, 0.38), hand_l=(-0.14, 0.16, 0.38),
    elbow_r=(0.4, 0.2, -0.9), elbow_l=(-0.4, 0.2, -0.9),
    foot_r=(0.12, 0.04, -0.80), foot_l=(-0.12, 0.04, -0.80),
    knee_r=(0.0, 1.0, 0.0), knee_l=(0.0, 1.0, 0.0),
    fist_r=0.3, fist_l=0.3, spine=(-4, 0, 0), head=(-6, 0, 0), free_feet=True,
)


def _rolled(theta):
    """Face down (0) through on his side to face up (180), rolling about
    his own long axis, limbs tucked and carried with him."""
    return _body((-86, 0, theta), (0.0, 0.0, 0.25),
                 **_ROLL_LIMBS)


# The prone landing a face-first move ends in, and the roll onto his back
# that hands him to Down_Supine.
#
# The roll used to be three room-frame keys -- face down, on his side, on his
# back -- and the arms, told to stay at fixed spots on the mat while the body
# turned over them, were dragged through the canvas and snapped 1.3 m in a
# frame (tools/probe/move_qa.tscn). It is now carried in the body's own frame
# (_body), tucked, through 60 and 120 degrees.
def _face_first_then_roll(land, end):
    prone = dict(pelvis=(0.0, 0.0, 0.200), hips=(-86, 0, 0), spine=(-2, 0, 0),
                 head=(8, 0, 0),
                 hand_r=(0.46, 0.30, 0.10), hand_l=(-0.46, 0.30, 0.10),
                 elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.7, 0.0, 0.7),
                 fist_r=0.1, fist_l=0.1,
                 foot_r=(0.14, -0.86, 0.12), foot_l=(-0.12, -0.84, 0.12),
                 knee_r=(0.2, 0.0, -1.0), knee_l=(-0.2, 0.0, -1.0))
    # Beats at 0, 5, 8, 11, 14, 18 frames after landing, squeezed to fit.
    span = min(1.0, (end - land) / 19.0)
    at = [land + int(round(x * span)) for x in (0, 5, 8, 11, 14, 18)]
    for i in range(1, len(at)):
        at[i] = max(at[i], at[i - 1] + 1)
    return [
        (at[0], prone),
        (at[1], dict(prone, pelvis=(0.0, 0.0, 0.185), head=(4, 0, 0))),
        (at[2], _rolled(60)),
        (at[3], _rolled(120)),
        (at[4], _rolled(180)),
        (at[5], S(spine=(-8, 0, 0), head=(-14, 0, 0))),
    ] + ([(end, S())] if end > at[5] else [])


# --- finishers ---------------------------------------------------------------
#
# Per-wrestler moves: WrestlerController.finisher_move is set from the roster
# (Roster.Entry.finisher), not from match.tscn, so these belong to one man each.
# Both were researched before they were keyed, and are the moves as their
# wrestlers perform them, reduced to what starts from a lock-up:
#
#   The Spear (Roman Reigns) -- he breaks off, loads low, explodes forward and
#   drives his shoulder into the midsection, lifting the man off his feet and
#   crashing him back-first into the mat. Reigns often throws the short-arm
#   version, a few steps from close range, which is what this is.
#
#   Cross Rhodes (Cody Rhodes) -- a rolling cutter: the opponent is spun by
#   the wrist, his head taken from behind, and Rhodes spins and drops,
#   driving him face-first into the canvas.
#
# Both land the victim in SUPINE's orientation -- on his back, head toward
# +fwd in his own root frame -- because the knockdown that follows plays
# Down_Supine from exactly there. The Spear drives him the OTHER way (head
# away from Roman), so his root yaws a half-turn in the air
# (paired_recipes.gd, finisher_spear) while his bones counter-yaw to keep him
# travelling backward in the world; Cross Rhodes lands him face-down, and he
# rolls onto his back selling it.

# The Spear, 42 frames / 1.4s.
CLIPS["Spear_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Shoves off to make room.
    (6,  P(pelvis=(0.0, -0.04, 0.840), spine=(-6, 0, 0),
           hand_r=(0.18, 0.52, 1.28), hand_l=(-0.18, 0.52, 1.26),
           fist_r=0.1, fist_l=0.1)),
    # Loads: dropped low over wide feet, eyes up on the target, hands clawed.
    (12, P(pelvis=(0.0, -0.05, 0.600), hips=(-30, 0, 0), spine=(-30, 0, 0),
           head=(24, 0, 0),
           hand_r=(0.32, 0.26, 0.52), hand_l=(-0.32, 0.26, 0.52),
           elbow_r=(0.6, -0.2, -0.7), elbow_l=(-0.6, -0.2, -0.7),
           fist_r=0.35, fist_l=0.35,
           foot_r=(0.28, -0.30, 0.104), foot_l=(-0.26, 0.20, 0.104))),
    (16, P(pelvis=(0.0, -0.06, 0.575), hips=(-34, 0, 0), spine=(-34, 0, 0),
           head=(28, 0, 0),
           hand_r=(0.34, 0.24, 0.48), hand_l=(-0.34, 0.24, 0.48),
           elbow_r=(0.6, -0.2, -0.7), elbow_l=(-0.6, -0.2, -0.7),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.28, -0.32, 0.104), foot_l=(-0.26, 0.20, 0.104))),
    # Explodes: torso near flat, shoulder leading, rear leg driving.
    (19, P(pelvis=(0.0, 0.20, 0.720), hips=(-50, 0, 0), spine=(-30, 0, 0),
           head=(30, 0, 0),
           hand_r=(0.30, 0.56, 0.80), hand_l=(-0.30, 0.56, 0.80),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.20, -0.55, 0.20), foot_l=(-0.18, 0.10, 0.104))),
    # Impact: shoulder in the midsection, arms wrapping the waist.
    (21, P(pelvis=(0.0, 0.25, 0.780), hips=(-60, 0, 0), spine=(-25, 0, 0),
           head=(20, 0, 0),
           hand_r=(0.26, 0.72, 0.96), hand_l=(-0.26, 0.72, 0.96),
           elbow_r=(0.7, 0.0, -0.4), elbow_l=(-0.7, 0.0, -0.4),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.20, -0.45, 0.25), foot_l=(-0.18, 0.05, 0.104))),
    # Drives through him and goes down with him.
    (25, dict(pelvis=(0.0, 0.30, 0.450), hips=(-75, 0, 0), spine=(-15, 0, 0),
              head=(10, 0, 0),
              hand_r=(0.26, 0.78, 0.34), hand_l=(-0.26, 0.78, 0.34),
              fist_r=0.4, fist_l=0.4,
              foot_r=(0.20, -0.40, 0.10), foot_l=(-0.20, -0.30, 0.10),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
    # On his knees over him.
    (30, dict(pelvis=(0.0, 0.05, 0.500), hips=(-40, 0, 0), spine=(-30, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.26, 0.60, 0.10), hand_l=(-0.26, 0.60, 0.10),
              fist_r=0.1, fist_l=0.1,
              foot_r=(0.19, -0.22, 0.09), foot_l=(-0.19, -0.20, 0.09),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
    (36, P(pelvis=(0.0, 0.02, 0.750), hips=(-10, 0, 0), spine=(-20, 0, 0),
           hand_r=(0.22, 0.30, 0.90), hand_l=(-0.20, 0.30, 0.90),
           fist_r=0.6, fist_l=0.6)),
    (42, P()),
]

# The Spear's victim. Past frame 21 his root is yawing a half-turn
# (finisher_spear's trajectory: -90 at t0.70 to +90 at t0.83, frames 21-25),
# and each key's hips yaw undoes the part of it already done, so in the world
# he keeps falling straight backward and lands on his back.
CLIPS["Spear_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Shoved back a step.
    (6,  P(pelvis=(0.0, -0.08, 0.830), spine=(8, 0, 0), head=(6, 0, 0),
           hand_r=(0.22, 0.26, 1.12), hand_l=(-0.20, 0.28, 1.10),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.23, -0.24, 0.104), foot_l=(-0.19, 0.10, 0.104))),
    # Squares up, not seeing it coming.
    (14, P(spine=(-4, 0, 0), head=(4, 0, 0),
           hand_r=(0.24, 0.24, 1.02), hand_l=(-0.22, 0.26, 1.00),
           fist_r=0.5, fist_l=0.5)),
    (19, P(spine=(-4, 0, 0), head=(0, 0, 0),
           hand_r=(0.24, 0.26, 1.06), hand_l=(-0.22, 0.28, 1.04),
           fist_r=0.5, fist_l=0.5)),
    # The hit: folded forward over the shoulder, lifted, feet leaving the mat.
    (21, dict(pelvis=(0.0, -0.15, 0.980), hips=(-30, 0, 0), spine=(-40, 0, 0),
              head=(-20, 0, 0),
              hand_r=(0.34, 0.40, 1.10), hand_l=(-0.32, 0.42, 1.08),
              elbow_r=(0.8, -0.3, -0.3), elbow_l=(-0.8, -0.3, -0.3),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, 0.25, 0.32), foot_l=(-0.18, 0.28, 0.36),
              knee_r=(0.3, 0.8, 0.4), knee_l=(-0.3, 0.8, 0.4))),
] + _back_fall(21, 42, skip_hit=True, fall_z=0.76)

# Cross Rhodes, 48 frames / 1.6s. Cody takes the victim's right wrist in his
# left hand and spins him a half-turn so his back is to Cody (the victim's
# ROOT does the spin -- finisher_cross_rhodes's trajectory); hooks the head
# from behind; then leaps, spins a half-turn himself and drops to a seat,
# pulling the head down with him so the victim is driven face-first into the
# mat just behind Cody's shoulder.
CLIPS["Cross_Rhodes_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Takes the wrist.
    (6,  P(spine=(-8, 0, 0),
           hand_r=(0.20, 0.30, 1.10), hand_l=(-0.04, 0.56, 1.10),
           fist_r=0.5, fist_l=0.7)),
    # Whips him round by it.
    (10, P(pelvis=(0.0, -0.03, 0.830), spine=(-4, -14, 0),
           hand_r=(0.22, 0.28, 1.08), hand_l=(-0.16, 0.34, 1.02),
           fist_r=0.5, fist_l=0.7)),
    (14, P(spine=(-8, 0, 0),
           hand_r=(0.20, 0.34, 1.20), hand_l=(-0.18, 0.36, 1.18),
           fist_r=0.5, fist_l=0.5)),
    # Hooks the head from behind.
    (18, P(spine=(-12, 0, 0), head=(-6, 0, 0),
           hand_r=(0.06, 0.44, 1.44), hand_l=(-0.14, 0.40, 1.40),
           elbow_r=(0.6, -0.4, -0.6), elbow_l=(-0.6, -0.4, -0.6),
           fist_r=0.6, fist_l=0.6)),
    # The leap: off his feet, tucked, spinning (the root turns under this).
    (22, dict(pelvis=(0.0, 0.0, 1.000), hips=(-10, 0, 0), spine=(-14, 0, 0),
              head=(-6, 0, 0),
              hand_r=(0.10, 0.34, 1.20), hand_l=(-0.14, 0.32, 1.18),
              fist_r=0.6, fist_l=0.6,
              foot_r=(0.20, 0.10, 0.50), foot_l=(-0.18, 0.14, 0.54),
              knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0))),
    # Seated, the head trapped behind his right shoulder, driven into the mat.
    (26, dict(pelvis=(0.0, 0.0, 0.200), hips=(12, 0, 0), spine=(6, 0, 0),
              head=(-6, 0, 0),
              hand_r=(0.14, -0.26, 0.24), hand_l=(-0.24, -0.06, 0.08),
              elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.6, 0.0, -0.8),
              fist_r=0.6, fist_l=0.0,
              foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))),
    (31, dict(pelvis=(0.0, 0.0, 0.200), hips=(8, 0, 0), spine=(0, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.16, -0.20, 0.20), hand_l=(-0.24, -0.06, 0.08),
              elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.6, 0.0, -0.8),
              fist_r=0.3, fist_l=0.0,
              foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))),
    # Feet drawn in, up onto a knee, then up.
    (34, pose(GATHER)),
    (38, dict(pelvis=(0.0, 0.02, 0.565), hips=(-6, 0, 0), spine=(-14, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.22, 0.30, 0.66), hand_l=(-0.26, 0.20, 0.60),
              fist_r=0.2, fist_l=0.2,
              foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
    (43, P(pelvis=(0.0, 0.02, 0.760), hips=(-10, 0, 0), spine=(-18, 0, 0),
           hand_r=(0.22, 0.30, 0.94), hand_l=(-0.20, 0.30, 0.96),
           fist_r=0.5, fist_l=0.5)),
    (48, P()),
]

# The victim, root-relative throughout: his root is spun a half-turn by the
# wrist (frames 6-14), so after that "forward" is away from Cody. He is
# pulled forward and down by the head, lands face-first -- SUPINE's forward
# pitch without its roll -- and rolls onto his back, the roll SUPINE is built
# from, with a 90-degree key so it goes the short way.
CLIPS["Cross_Rhodes_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Wrist taken: right arm drawn out toward Cody.
    (6,  P(spine=(-10, 0, 0),
           hand_r=(0.08, 0.52, 1.12), hand_l=(-0.22, 0.30, 1.06),
           fist_r=0.4, fist_l=0.5)),
    # Spinning: arms flung, the held one trailing.
    (10, P(pelvis=(0.0, 0.0, 0.830), spine=(-4, 14, 0), head=(0, 10, 0),
           hand_r=(0.40, -0.10, 1.12), hand_l=(-0.40, 0.10, 1.08),
           fist_r=0.4, fist_l=0.3)),
    # Stopped with his back to Cody, off balance.
    (14, P(pelvis=(0.0, 0.0, 0.840), spine=(-2, 0, 0), head=(4, 0, 0),
           hand_r=(0.30, 0.10, 1.00), hand_l=(-0.28, 0.12, 0.98),
           fist_r=0.3, fist_l=0.3)),
    # Head hooked from behind: chin pulled up, hands to the arm at his neck.
    (18, P(pelvis=(0.0, -0.04, 0.830), spine=(6, 0, 0), head=(22, 0, 0),
           hand_r=(0.10, 0.12, 1.44), hand_l=(-0.10, 0.12, 1.44),
           elbow_r=(0.7, 0.3, -0.4), elbow_l=(-0.7, 0.3, -0.4),
           fist_r=0.5, fist_l=0.5)),
    # Yanked forward and down by the head.
    (22, dict(pelvis=(0.0, 0.08, 0.740), hips=(-40, 0, 0), spine=(-14, 0, 0),
              head=(14, 0, 0),
              hand_r=(0.24, 0.40, 1.00), hand_l=(-0.22, 0.42, 1.00),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, -0.18, 0.12), foot_l=(-0.18, -0.10, 0.16))),
] + _face_first_then_roll(26, 48)

# --- per-wrestler signatures ---------------------------------------------------
#
# Like the finishers, these belong to one man each (Roster.Entry.signature,
# added to his signature draw by TitleScreen.configure_match()). Researched
# before they were keyed:
#
#   The Superman Punch (Roman Reigns) -- he charges up by pounding his fist
#   on the mat, runs at the man, brings the rear leg forward as if to kick,
#   snaps it back and leaps into a flying right hand. It is the move he sets
#   the Spear up with.
#
#   The Cody Cutter (Cody Rhodes) -- a springboard cutter: off the ropes,
#   the head caught in a three-quarter facelock in the air, and down, the man
#   driven face-first. There are no ropes in a paired clip's frame, so he
#   runs off the lock-up, turns at where the ropes would be, and comes back.

# The Superman Punch, 42 frames / 1.4s. The victim is knocked flat on his
# back AWAY from Roman, so -- as in the Spear -- his root yaws a half-turn
# while he falls (signature_superman_punch's trajectory, frames 26-31) and
# his bones counter-yaw.
CLIPS["Superman_Punch_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Shoves off.
    (6,  P(pelvis=(0.0, -0.04, 0.840), spine=(-6, 0, 0),
           hand_r=(0.18, 0.52, 1.28), hand_l=(-0.18, 0.52, 1.26),
           fist_r=0.1, fist_l=0.1)),
    # Drops to a crouch, right fist cocked high.
    (9,  P(pelvis=(0.0, -0.04, 0.600), hips=(-24, 0, 0), spine=(-24, 0, 0),
           head=(20, 0, 0),
           hand_r=(0.30, 0.10, 1.10), hand_l=(-0.30, 0.30, 0.50),
           fist_r=1.0, fist_l=0.4,
           foot_r=(0.28, -0.28, 0.104), foot_l=(-0.26, 0.20, 0.104))),
    # Pounds the mat.
    (12, P(pelvis=(0.0, -0.02, 0.540), hips=(-34, 0, 0), spine=(-30, 0, 0),
           head=(24, 0, 0),
           hand_r=(0.26, 0.36, 0.08), hand_l=(-0.30, 0.30, 0.48),
           fist_r=1.0, fist_l=0.4,
           foot_r=(0.28, -0.28, 0.104), foot_l=(-0.26, 0.20, 0.104))),
    # Up and running at him.
    (16, P(pelvis=(0.0, 0.06, 0.800), hips=(-14, 0, 0), spine=(-18, 0, 0),
           head=(8, 0, 0),
           hand_r=(0.24, 0.10, 1.00), hand_l=(-0.22, 0.34, 1.06),
           fist_r=1.0, fist_l=0.7,
           foot_r=(0.16, -0.30, 0.20), foot_l=(-0.14, 0.26, 0.104))),
    (19, P(pelvis=(0.0, 0.06, 0.800), hips=(-14, 0, 0), spine=(-18, 0, 0),
           head=(8, 0, 0),
           hand_r=(0.26, 0.30, 1.04), hand_l=(-0.20, 0.10, 1.00),
           fist_r=1.0, fist_l=0.7,
           foot_r=(0.16, 0.26, 0.104), foot_l=(-0.14, -0.30, 0.20))),
    # The feint: rear knee driven up as if to kick, off the left foot.
    (21, P(pelvis=(0.0, 0.04, 0.880), hips=(-6, 0, 0), spine=(-8, 0, 0),
           head=(4, 0, 0),
           hand_r=(0.30, -0.10, 1.30), hand_l=(-0.20, 0.36, 1.30),
           fist_r=1.0, fist_l=0.8,
           foot_r=(0.18, 0.34, 0.56), foot_l=(-0.14, 0.00, 0.104),
           knee_r=(0.2, 1.0, 0.3))),
    # Airborne: leg snapped back, the right hand cocked behind him -- three
    # frames before the jaw, so the fist travels at a punch's speed (about
    # 12 m/s), not twice it.
    (23, dict(pelvis=(0.0, 0.10, 1.150), hips=(-10, 0, 0), spine=(-12, -16, 0),
              head=(4, 0, 0),
              hand_r=(0.32, -0.26, 1.52), hand_l=(-0.20, 0.42, 1.44),
              fist_r=1.0, fist_l=0.8,
              foot_r=(0.20, -0.50, 0.82), foot_l=(-0.16, 0.10, 0.62),
              knee_r=(0.2, 0.6, -0.6), knee_l=(-0.2, 1.0, 0.1))),
    # Impact: the fist on the jaw, still in the air, the whole body behind it.
    (26, dict(pelvis=(0.0, 0.20, 1.060), hips=(-16, 0, 0), spine=(-24, 20, 0),
              head=(0, 0, 0),
              hand_r=(0.04, 0.72, 1.54), hand_l=(-0.26, 0.10, 1.26),
              fist_r=1.0, fist_l=0.8,
              foot_r=(0.20, -0.40, 0.66), foot_l=(-0.16, 0.10, 0.50),
              knee_r=(0.2, 0.6, -0.6), knee_l=(-0.2, 1.0, 0.1))),
    # Lands, the punch following through down and across.
    (29, P(pelvis=(0.0, 0.10, 0.760), hips=(-12, 0, 0), spine=(-22, 10, 0),
           hand_r=(-0.08, 0.46, 1.06), hand_l=(-0.26, 0.20, 1.02),
           fist_r=1.0, fist_l=0.6,
           foot_r=(0.24, -0.10, 0.104), foot_l=(-0.20, 0.24, 0.104))),
    # Stands over him.
    (35, P(pelvis=(0.0, 0.0, 0.860), spine=(-8, 0, 0), head=(-10, 0, 0),
           hand_r=(0.28, 0.14, 1.00), hand_l=(-0.26, 0.14, 1.00),
           fist_r=1.0, fist_l=1.0)),
    (42, P()),
]

CLIPS["Superman_Punch_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    (6,  P(pelvis=(0.0, -0.08, 0.830), spine=(8, 0, 0), head=(6, 0, 0),
           hand_r=(0.22, 0.26, 1.12), hand_l=(-0.20, 0.28, 1.10),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.23, -0.24, 0.104), foot_l=(-0.19, 0.10, 0.104))),
    # Staggering back to his feet as Roman charges.
    (16, P(spine=(-6, 0, 0), head=(6, 0, 0),
           hand_r=(0.26, 0.24, 1.10), hand_l=(-0.24, 0.26, 1.08),
           fist_r=0.6, fist_l=0.6)),
    (24, P(spine=(-2, 0, 0), head=(8, 0, 0),
           hand_r=(0.24, 0.30, 1.20), hand_l=(-0.22, 0.32, 1.18),
           fist_r=0.7, fist_l=0.7)),
    # The punch lands: head snapped back and round, knees going.
    (26, P(pelvis=(0.0, -0.06, 0.800), spine=(20, -12, 0), head=(30, -20, 0),
           hand_r=(0.36, 0.10, 1.10), hand_l=(-0.34, 0.06, 1.06),
           fist_r=0.3, fist_l=0.3)),
] + _back_fall(26, 42, skip_hit=True)

# The Cody Cutter, 42 frames / 1.4s. Cody shoves off, turns and runs for the
# ropes, turns back off them (the root does both turns), leaps, takes the
# head under his right arm and falls back to a seat; the victim is pulled
# face-first into the mat at Cody's right hip, and rolls onto his back.
CLIPS["Cody_Cutter_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    (5,  P(pelvis=(0.0, -0.04, 0.840), spine=(-6, 0, 0),
           hand_r=(0.18, 0.52, 1.28), hand_l=(-0.18, 0.52, 1.26),
           fist_r=0.1, fist_l=0.1)),
    # Running for the ropes.
    (9,  P(pelvis=(0.0, 0.06, 0.800), hips=(-14, 0, 0), spine=(-16, 0, 0),
           hand_r=(0.24, 0.10, 1.00), hand_l=(-0.22, 0.34, 1.06),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.16, -0.30, 0.20), foot_l=(-0.14, 0.26, 0.104))),
    (12, P(pelvis=(0.0, 0.06, 0.800), hips=(-14, 0, 0), spine=(-16, 0, 0),
           hand_r=(0.26, 0.30, 1.04), hand_l=(-0.20, 0.10, 1.00),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.16, 0.26, 0.104), foot_l=(-0.14, -0.30, 0.20))),
    # Off the ropes: planted, weight back into them.
    (15, P(pelvis=(0.0, -0.06, 0.800), hips=(10, 0, 0), spine=(8, 0, 0),
           hand_r=(0.30, -0.10, 1.20), hand_l=(-0.30, -0.10, 1.20),
           fist_r=0.3, fist_l=0.3,
           foot_r=(0.20, -0.20, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    # Back at him.
    (18, P(pelvis=(0.0, 0.06, 0.800), hips=(-14, 0, 0), spine=(-18, 0, 0),
           hand_r=(0.24, 0.10, 1.00), hand_l=(-0.22, 0.34, 1.06),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.16, -0.30, 0.20), foot_l=(-0.14, 0.26, 0.104))),
    # The leap, reaching for the head.
    (22, dict(pelvis=(0.0, 0.08, 1.100), hips=(-10, 0, 0), spine=(-14, 0, 0),
              head=(0, 0, 0),
              hand_r=(0.10, 0.52, 1.52), hand_l=(-0.20, 0.50, 1.46),
              fist_r=0.5, fist_l=0.5,
              foot_r=(0.20, -0.10, 0.60), foot_l=(-0.18, 0.00, 0.56),
              knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0))),
    # Head under the right arm -- the three-quarter facelock -- in the air.
    (24, dict(pelvis=(0.0, 0.04, 1.020), hips=(0, 0, 0), spine=(-8, 0, 0),
              head=(-4, 0, 0),
              hand_r=(-0.08, 0.56, 1.30), hand_l=(0.08, 0.50, 1.36),
              elbow_r=(0.7, -0.3, -0.5), elbow_l=(-0.6, -0.3, -0.6),
              fist_r=0.6, fist_l=0.6,
              foot_r=(0.20, -0.06, 0.52), foot_l=(-0.18, 0.04, 0.50),
              knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0))),
    # Down on his seat, the head driven into the mat at his right hip.
    (27, dict(pelvis=(0.0, 0.0, 0.200), hips=(12, 0, 0), spine=(4, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.26, 0.20, 0.22), hand_l=(-0.24, -0.06, 0.08),
              elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.6, 0.0, -0.8),
              fist_r=0.6, fist_l=0.0,
              foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))),
    (31, dict(pelvis=(0.0, 0.0, 0.200), hips=(8, 0, 0), spine=(0, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.26, 0.24, 0.18), hand_l=(-0.24, -0.06, 0.08),
              elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.6, 0.0, -0.8),
              fist_r=0.3, fist_l=0.0,
              foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))),
    (33, pose(GATHER)),
    (36, dict(pelvis=(0.0, 0.02, 0.565), hips=(-6, 0, 0), spine=(-14, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.22, 0.30, 0.66), hand_l=(-0.26, 0.20, 0.60),
              fist_r=0.2, fist_l=0.2,
              foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
    (42, P()),
]

CLIPS["Cody_Cutter_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    (5,  P(pelvis=(0.0, -0.08, 0.830), spine=(8, 0, 0), head=(6, 0, 0),
           hand_r=(0.22, 0.26, 1.12), hand_l=(-0.20, 0.28, 1.10),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.23, -0.24, 0.104), foot_l=(-0.19, 0.10, 0.104))),
    # Stumbles forward after him.
    (16, P(spine=(-10, 0, 0), head=(6, 0, 0),
           hand_r=(0.26, 0.26, 1.06), hand_l=(-0.24, 0.28, 1.04),
           fist_r=0.5, fist_l=0.5)),
    (22, P(spine=(-8, 0, 0), head=(10, 0, 0),
           hand_r=(0.26, 0.30, 1.14), hand_l=(-0.24, 0.32, 1.12),
           fist_r=0.5, fist_l=0.5)),
    # Head caught and dragged down.
    (24, dict(pelvis=(0.0, 0.04, 0.780), hips=(-30, 0, 0), spine=(-24, 0, 0),
              head=(-6, 0, 0),
              hand_r=(0.26, 0.36, 0.96), hand_l=(-0.24, 0.38, 0.94),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, -0.16, 0.12), foot_l=(-0.18, -0.08, 0.14))),
] + _face_first_then_roll(27, 42)

# --- running attacks, from the reference video ---------------------------------
#
# Recreated from a supplied WWE 2K25 reel of 25 running moves ("25 Running
# Moves that should be your Finisher"), each studied at 8 fps from its own
# segment. They are available to every wrestler (match.tscn's
# running_attack_move_pool) and performed by both men: a running attack with a
# recipe here connects and hands both bodies to GrappleRig
# (WrestlerController._begin_running_paired()), so the victim's half is keyed
# against the hit rather than borrowed from a generic reaction.
#
# Every one starts with the runner 1.6 m out at a sprint and the victim
# standing square to him; GrappleRig's lead-in slides the runner onto that
# first key from wherever he connected.

RUN_A = dict(pelvis=(0.0, 0.06, 0.800), hips=(-14, 0, 0), spine=(-18, 0, 0),
             head=(8, 0, 0),
             hand_r=(0.24, 0.10, 1.00), hand_l=(-0.22, 0.34, 1.06),
             fist_r=0.7, fist_l=0.7,
             foot_r=(0.16, -0.30, 0.20), foot_l=(-0.14, 0.26, 0.104))
RUN_B = dict(RUN_A, hand_r=(0.26, 0.30, 1.04), hand_l=(-0.20, 0.10, 1.00),
             foot_r=(0.16, 0.26, 0.104), foot_l=(-0.14, -0.30, 0.20))
STAND = dict(STANCE, hand_r=(0.24, 0.30, 1.16), hand_l=(-0.22, 0.32, 1.14),
             fist_r=0.6, fist_l=0.6)


# Running Knee Lift, 36 frames. Low sprint; off the left foot with the right
# knee driven up into the jaw and both arms thrown high (video frames 6-7);
# lands and carries on past as the victim goes over backward.
CLIPS["Knee_Lift_Attacker"] = [
    (0, pose(RUN_A)), (4, pose(RUN_B)),
    # The plant, right knee already driving up (see _run_in's kick).
    (7, P(pelvis=(0.0, 0.10, 0.740), hips=(-20, 0, 0), spine=(-20, 0, 0),
          hand_r=(0.26, 0.20, 0.90), hand_l=(-0.24, 0.24, 0.92),
          foot_r=(0.16, 0.10, 0.50), foot_l=(-0.14, 0.12, 0.104),
          knee_r=(0.2, 1.0, 0.3))),
    (9, dict(pelvis=(0.0, 0.10, 1.000), hips=(4, 0, 0), spine=(6, 0, 0),
             head=(6, 0, 0),
             hand_r=(0.30, 0.10, 1.76), hand_l=(-0.30, 0.10, 1.74),
             fist_r=0.8, fist_l=0.8,
             foot_r=(0.18, 0.22, 0.78), foot_l=(-0.14, -0.10, 0.40),
             knee_r=(0.2, 1.0, 0.3), knee_l=(-0.2, 1.0, 0.0))),
    (12, P(pelvis=(0.0, 0.06, 0.800), hips=(-10, 0, 0), spine=(-10, 0, 0),
           hand_r=(0.30, 0.10, 1.40), hand_l=(-0.30, 0.10, 1.38),
           foot_r=(0.20, 0.10, 0.104), foot_l=(-0.18, -0.10, 0.104))),
    (18, pose(RUN_B, pelvis=(0.0, 0.03, 0.830), hips=(-6, 0, 0), spine=(-8, 0, 0))),
    (26, pose(STAND)),
    (36, P()),
]
CLIPS["Knee_Lift_Defender"] = [(0, pose(STAND)), (7, pose(STAND, head=(4, 0, 0)))] \
    + _back_fall(9, 36, pelvis_hit=1.00)

# Clothesline From Hell, 36 frames. Sprints in with the right arm cocked,
# swings it through the neck (video frames 2-4); the victim is turned over
# backward three-quarters of a turn -- feet over his head -- and lands face
# down, head toward the attacker, which is SUPINE's pitch without its roll, so
# he rolls straight into it. The attacker ends crouched over him.
CLIPS["CFH_Attacker"] = [
    (0, pose(RUN_A, hand_r=(0.36, -0.30, 1.30), fist_r=1.0)),
    (4, pose(RUN_B, hand_r=(0.38, -0.30, 1.34), fist_r=1.0)),
    (7, P(pelvis=(0.0, 0.06, 0.800), hips=(-10, 0, 0), spine=(-12, -16, 0),
          hand_r=(0.60, 0.26, 1.46), hand_l=(-0.24, 0.20, 1.06), fist_r=1.0,
          foot_r=(0.20, -0.20, 0.104), foot_l=(-0.16, 0.24, 0.104))),
    (9, P(pelvis=(0.0, 0.10, 0.800), hips=(-14, 12, 0), spine=(-14, 24, 0),
          hand_r=(0.18, 0.76, 1.46), hand_l=(-0.30, 0.10, 1.04), fist_r=1.0,
          foot_r=(0.20, -0.10, 0.104), foot_l=(-0.16, 0.30, 0.104))),
    (13, P(pelvis=(0.0, 0.10, 0.780), hips=(-16, 20, 0), spine=(-18, 34, 0),
           hand_r=(-0.34, 0.56, 1.20), hand_l=(-0.30, 0.00, 1.00), fist_r=1.0,
           foot_r=(0.22, -0.10, 0.104), foot_l=(-0.16, 0.34, 0.104))),
    (18, P(pelvis=(0.0, 0.02, 0.600), hips=(-30, 0, 0), spine=(-34, 0, 0),
           head=(-8, 0, 0),
           hand_r=(0.22, 0.28, 0.56), hand_l=(-0.22, 0.28, 0.56),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, 0.20, 0.104))),
    (28, P(pelvis=(0.0, 0.02, 0.620), hips=(-28, 0, 0), spine=(-32, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.22, 0.28, 0.58), hand_l=(-0.22, 0.28, 0.58),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, 0.20, 0.104))),
    (36, P()),
]
# The flip: no foot targets, so the legs stay in line with the hips and the
# whole body turns over as one piece.
_FLIP = dict(spine=(10, 0, 0), head=(10, 0, 0),
             hand_r=(0.50, 0.10, 1.20), hand_l=(-0.50, 0.10, 1.20),
             elbow_r=(0.8, -0.3, 0.2), elbow_l=(-0.8, -0.3, 0.2),
             fist_r=0.2, fist_l=0.2)


def _flip(pitch, pelvis):
    """A body turning over in the air, carried in its own frame (_body):
    arms flung out, knees tucked. The flips used to give the legs no target
    at all, so they hung at full length from a body turning 40 degrees a
    frame and swept a metre a frame at the feet."""
    return _body((pitch, 0, 0), pelvis,
                 spine=(10, 0, 0), head=(10, 0, 0),
                 hand_r=(0.50, 0.00, 0.40), hand_l=(-0.50, 0.00, 0.40),
                 elbow_r=(0.8, -0.3, 0.2), elbow_l=(-0.8, -0.3, 0.2),
                 fist_r=0.2, fist_l=0.2,
                 foot_r=(0.14, 0.30, -0.50), foot_l=(-0.14, 0.30, -0.54),
                 knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0), free_feet=True)
CLIPS["CFH_Defender"] = [
    (0, pose(STAND)), (8, pose(STAND, head=(4, 0, 0))),
    (9, P(pelvis=(0.0, -0.06, 0.900), spine=(24, 0, 0), head=(34, 0, 0),
          hand_r=(0.38, 0.10, 1.12), hand_l=(-0.36, 0.06, 1.10),
          fist_r=0.2, fist_l=0.2)),
    (12, _flip(80, (0.0, 0.0, 1.100))),
    (15, _flip(160, (0.0, 0.0, 1.250))),
    (18, _flip(230, (0.0, 0.0, 0.850))),
] + _face_first_then_roll(21, 36)

# Spinning Back Elbow, 36 frames. Plants and spins a full turn to his right
# (the root does the turn); the right elbow swings back into the jaw as his
# back comes round (video frames 5-7). The victim's head is snapped round and
# he goes over backward.
CLIPS["Back_Elbow_Attacker"] = [
    (0, pose(RUN_A)), (4, pose(RUN_B)),
    (8, P(pelvis=(0.0, 0.02, 0.800), hips=(-6, -20, 0), spine=(-8, -30, 0),
          hand_r=(0.30, 0.30, 1.30), hand_l=(-0.26, 0.20, 1.20),
          fist_r=1.0, fist_l=0.8)),
    (12, P(pelvis=(0.0, 0.0, 0.820), hips=(0, -30, 0), spine=(-4, -40, 0),
           head=(0, -40, 0),
           hand_r=(0.24, -0.02, 1.46), hand_l=(-0.24, 0.24, 1.26),
           elbow_r=(0.4, -1.0, 0.2),
           fist_r=1.0, fist_l=0.8)),
    (16, P(pelvis=(0.0, 0.0, 0.820), hips=(0, -10, 0), spine=(-6, -10, 0),
           hand_r=(0.40, 0.10, 1.30), hand_l=(-0.30, 0.20, 1.20),
           fist_r=1.0, fist_l=0.8)),
    (22, pose(STAND)),
    (36, P()),
]
CLIPS["Back_Elbow_Defender"] = [(0, pose(STAND)), (10, pose(STAND, head=(4, 0, 0)))] \
    + _back_fall(12, 36, pelvis_hit=0.90, twist=-40)

# Single Leg Dropkick, 36 frames. Takes off and turns side-on in the air, the
# body near level and the right leg driven into the chest (video frames 7-9);
# drops onto his side, then gets up. The victim goes over backward.
CLIPS["SL_Dropkick_Attacker"] = [
    (0, pose(RUN_A)), (4, pose(RUN_B)),
    (7, P(pelvis=(0.0, 0.10, 0.740), hips=(-20, 0, 0), spine=(-16, 0, 0),
          hand_r=(0.26, 0.20, 0.90), hand_l=(-0.24, 0.24, 0.92),
          foot_r=(0.16, 0.10, 0.50), foot_l=(-0.14, 0.12, 0.104),
          knee_r=(0.2, 1.0, 0.3))),
    (10, dict(pelvis=(0.0, 0.10, 1.050), hips=(-10, 0, -70), spine=(0, 0, -10),
              head=(0, 0, 10),
              hand_r=(0.50, 0.00, 1.00), hand_l=(-0.10, 0.10, 1.50),
              fist_r=0.4, fist_l=0.4,
              foot_r=(0.10, 0.90, 1.20), foot_l=(0.40, 0.10, 0.90),
              knee_r=(0.0, 0.0, 1.0), knee_l=(0.0, 1.0, 0.0))),
    (14, dict(pelvis=(0.0, 0.10, 0.520), hips=(-10, 0, -80), spine=(0, 0, -6),
              head=(0, 0, 12),
              hand_r=(0.70, 0.10, 0.20), hand_l=(-0.10, 0.20, 0.80),
              fist_r=0.2, fist_l=0.2)),
    (17, dict(pelvis=(0.0, 0.05, 0.180), hips=(-8, 0, -86), spine=(0, 0, -4),
              head=(0, 0, 16),
              hand_r=(0.70, 0.10, 0.08), hand_l=(0.10, 0.30, 0.30),
              fist_r=0.0, fist_l=0.0)),
    (20, dict(SIDE_PUSH)),
    (24, dict(pelvis=(0.0, 0.0, 0.450), hips=(-30, 0, -20), spine=(-20, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.40, 0.20, 0.06), hand_l=(-0.24, 0.30, 0.40),
              fist_r=0.0, fist_l=0.2,
              foot_r=(0.20, -0.30, 0.09), foot_l=(-0.20, 0.20, 0.104),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
    (28, dict(pelvis=(0.0, 0.02, 0.565), hips=(-6, 0, 0), spine=(-14, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.22, 0.30, 0.66), hand_l=(-0.26, 0.20, 0.60),
              fist_r=0.2, fist_l=0.2,
              foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
    (36, P()),
]
CLIPS["SL_Dropkick_Defender"] = [(0, pose(STAND)), (8, pose(STAND, head=(4, 0, 0)))] \
    + _back_fall(10, 36, pelvis_hit=0.92)

# Tilt-A-Whirl DDT, 60 frames / 2.0s. He runs into the victim, leaps on and
# is swung all the way round his torso -- head down across his back at the
# half-way point (video frames 10-14) -- and comes round in front with the
# head in a front facelock; falls back, spiking it: the victim is driven
# head-first, his legs come up (frames 24-25), he drops back onto his face and
# rolls over. The orbit is the ROOT's (running_tilt_a_whirl_ddt's
# trajectory: a full circle at 0.35 m round the victim, yawing to keep facing
# him); the bones here only carry him over and upside down.
_WHIRL = dict(spine=(-10, 0, 0), head=(-10, 0, 0),
              hand_r=(0.20, 0.35, 0.40), hand_l=(-0.20, 0.35, 0.40),
              fist_r=0.6, fist_l=0.6)
_WHIRL_LAND = _body((-300, 0, 0), (0.0, 0.08, 1.080), **_WHIRL,
                    foot_r=(0.16, 0.12, -0.84), foot_l=(-0.16, 0.08, -0.80),
                    knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0), free_feet=True)
CLIPS["Tilt_DDT_Attacker"] = [
    (0, pose(RUN_A)), (4, pose(RUN_B)),
    (6, P(pelvis=(0.0, 0.06, 0.800), hips=(-10, 0, 0), spine=(-12, 0, 0),
          hand_r=(0.20, 0.44, 1.30), hand_l=(-0.20, 0.44, 1.30), fist_r=0.6, fist_l=0.6)),
    (8,  _body((-70, 0, 0), (0.0, 0.10, 1.100), **_WHIRL, **_TUCK_LEGS)),
    (11, _body((-150, 0, 0), (0.0, 0.10, 1.250), **_WHIRL, **_TUCK_LEGS)),
    (14, _body((-225, 0, 0), (0.0, 0.10, 1.280), **_WHIRL, **_TUCK_LEGS)),
    # Coming upright, legs reaching down for the mat.
    (17, _WHIRL_LAND),
    # Round in front, landing on his feet with the head under his right arm.
    (20, P(pelvis=(0.0, 0.04, 0.820), hips=(-16, 0, 0), spine=(-30, 0, 0),
           head=(-6, 0, 0),
           hand_r=(0.06, 0.34, 1.02), hand_l=(-0.16, 0.30, 1.00),
           elbow_r=(0.7, -0.3, -0.5), elbow_l=(-0.6, -0.3, -0.6),
           fist_r=0.6, fist_l=0.6)),
    (36, P(pelvis=(0.0, 0.04, 0.820), hips=(-16, 0, 0), spine=(-32, 0, 0),
           head=(-8, 0, 0),
           hand_r=(0.06, 0.34, 1.00), hand_l=(-0.16, 0.30, 0.98),
           elbow_r=(0.7, -0.3, -0.5), elbow_l=(-0.6, -0.3, -0.6),
           fist_r=0.6, fist_l=0.6)),
    # Falls back, spiking it.
    (38, pose(SIT_DROP, hand_r=(0.06, 0.32, 0.60), hand_l=(-0.16, 0.28, 0.58))),
    (40, dict(pelvis=(0.0, 0.0, 0.200), hips=(20, 0, 0), spine=(10, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.06, 0.30, 0.30), hand_l=(-0.16, 0.26, 0.28),
              fist_r=0.6, fist_l=0.6,
              foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))),
    (46, dict(pelvis=(0.0, 0.0, 0.200), hips=(10, 0, 0), spine=(4, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.20, 0.10, 0.10), hand_l=(-0.24, -0.06, 0.08),
              fist_r=0.2, fist_l=0.0,
              foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))),
    (49, pose(GATHER)),
    (53, dict(pelvis=(0.0, 0.02, 0.565), hips=(-6, 0, 0), spine=(-14, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.22, 0.30, 0.66), hand_l=(-0.26, 0.20, 0.60),
              fist_r=0.2, fist_l=0.2,
              foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
    (60, P()),
]
CLIPS["Tilt_DDT_Defender"] = [
    (0, pose(STAND)),
    # Catches him as he leaps on, arms round him.
    (7, P(spine=(-8, 0, 0), hand_r=(0.20, 0.40, 1.10), hand_l=(-0.20, 0.40, 1.10),
          fist_r=0.5, fist_l=0.5)),
    (14, P(pelvis=(0.0, 0.0, 0.820), spine=(-14, 0, 0), head=(-6, 0, 0),
           hand_r=(0.26, 0.30, 1.00), hand_l=(-0.24, 0.30, 1.00),
           fist_r=0.4, fist_l=0.4)),
    # Bent forward into the facelock, feet planted under him.
    (20, dict(pelvis=(0.0, -0.06, 0.780), hips=(-40, 0, 0), spine=(-26, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.24, 0.30, 0.80), hand_l=(-0.22, 0.32, 0.78),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, -0.14, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    (36, dict(pelvis=(0.0, -0.06, 0.780), hips=(-42, 0, 0), spine=(-28, 0, 0),
              head=(-12, 0, 0),
              hand_r=(0.24, 0.32, 0.78), hand_l=(-0.22, 0.34, 0.76),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, -0.14, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    # Spiked: head planted, legs coming up behind (no foot targets -- the legs
    # stay in line with the hips).
    (40, _flip(-130, (0.0, 0.10, 0.700))),
    (42, _flip(-150, (0.0, 0.10, 0.800))),
] + _face_first_then_roll(46, 60)

# --- batch 2: shared pieces ----------------------------------------------------

# The attacker flat on his back after going down backward: head toward -fwd,
# face up, legs out in front, knees up. A positive hips pitch is a backward
# tip (see STANCE), so no roll is needed.
ATK_BACK = dict(pelvis=(0.0, 0.0, 0.180), hips=(84, 0, 0), spine=(4, 0, 0),
                head=(-12, 0, 0),
                hand_r=(0.40, -0.30, 0.10), hand_l=(-0.40, -0.30, 0.10),
                elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.7, 0.0, 0.7),
                fist_r=0.1, fist_l=0.1,
                foot_r=(0.16, 0.62, 0.12), foot_l=(-0.16, 0.58, 0.12),
                knee_r=(0.2, 0.2, 1.0), knee_l=(-0.2, 0.2, 1.0))
# Seated on the mat, legs out in front -- the cutters' landing.
ATK_SEAT = dict(pelvis=(0.0, 0.0, 0.200), hips=(12, 0, 0), spine=(4, 0, 0),
                head=(-8, 0, 0),
                hand_r=(0.30, -0.10, 0.10), hand_l=(-0.30, -0.10, 0.10),
                elbow_r=(0.7, 0.0, 0.7), elbow_l=(-0.7, 0.0, 0.7),
                fist_r=0.2, fist_l=0.2,
                foot_r=(0.18, 0.58, 0.104), foot_l=(-0.18, 0.52, 0.104),
                knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))
# Crouched over the man he has just put down.
ATK_OVER = dict(pelvis=(0.0, 0.04, 0.600), hips=(-30, 0, 0), spine=(-32, 0, 0),
                head=(-10, 0, 0),
                hand_r=(0.22, 0.30, 0.56), hand_l=(-0.22, 0.30, 0.56),
                fist_r=0.4, fist_l=0.4,
                foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, 0.20, 0.104))
ONE_KNEE = dict(pelvis=(0.0, 0.02, 0.565), hips=(-6, 0, 0), spine=(-14, 0, 0),
                head=(-8, 0, 0),
                hand_r=(0.22, 0.30, 0.66), hand_l=(-0.26, 0.20, 0.60),
                fist_r=0.2, fist_l=0.2,
                foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
                knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))
# Off the ground, both legs tucked -- the airborne frame most leaps pass
# through.
def _air(z, tuck=False, **over):
    base = dict(pelvis=(0.0, 0.06, z), hips=(-8, 0, 0), spine=(-10, 0, 0),
                head=(4, 0, 0),
                hand_r=(0.30, 0.20, 1.40), hand_l=(-0.30, 0.20, 1.40),
                fist_r=0.6, fist_l=0.6,
                foot_r=(0.20, 0.10, z - 0.40), foot_l=(-0.18, 0.00, z - 0.46),
                knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0))
    base.update(over)
    if tuck:
        # The legs in the body's frame (_body), so they stay folded under a
        # man who is upside down or spinning, not dangling to the room's floor.
        legs = _body(base["hips"], base["pelvis"], **_TUCK_LEGS)
        for k in ("foot_r", "foot_l", "knee_r", "knee_l", "free_feet"):
            base[k] = legs[k]
    return base


def _run_in(kick=False):
    """The run and the plant. With kick, the plant is the take-off: the
    right knee is already driving up (chambered) so the leg reaches the kick
    in two beats. Without the chamber the boot went from trailing behind to
    head height in three frames -- over a metre a frame at the foot."""
    foot_r = (0.16, 0.10, 0.50) if kick else (0.16, -0.20, 0.20)
    extra = dict(knee_r=(0.2, 1.0, 0.3)) if kick else {}
    return [(0, pose(RUN_A)), (4, pose(RUN_B)),
            (7, P(pelvis=(0.0, 0.10, 0.740), hips=(-20, 0, 0), spine=(-20, 0, 0),
                  hand_r=(0.26, 0.20, 0.90), hand_l=(-0.24, 0.24, 0.92),
                  foot_r=foot_r, foot_l=(-0.14, 0.12, 0.104), **extra))]


# Sitting up off his back, weight on his hands behind him, knees up.
SIT_UP = dict(pelvis=(0.0, 0.0, 0.200), hips=(40, 0, 0), spine=(-26, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.26, -0.28, 0.08), hand_l=(-0.26, -0.28, 0.08),
              elbow_r=(0.4, 0.8, 0.2), elbow_l=(-0.4, 0.8, 0.2),
              fist_r=0.0, fist_l=0.0,
              foot_r=(0.18, 0.46, 0.104), foot_l=(-0.18, 0.40, 0.104),
              knee_r=(0.2, 0.3, 1.0), knee_l=(-0.2, 0.3, 1.0))
# Crouched over both feet, a hand on a knee, about to stand.
CROUCH = dict(pelvis=(0.0, 0.06, 0.500), hips=(-36, 0, 0), spine=(-20, 0, 0),
              head=(12, 0, 0),
              hand_r=(0.22, 0.34, 0.58), hand_l=(-0.22, 0.30, 0.56),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, 0.04, 0.104), foot_l=(-0.18, 0.12, 0.104),
              knee_r=(0.3, 1.0, 0.2), knee_l=(-0.3, 1.0, 0.2))


def _get_up(t, end, lying=False, seated=False):
    """Back to his feet: from his back, sit up first; then gather into a
    crouch over both feet; then stand. It used to cut straight from the mat
    to one knee, and every leg in the set swung through the canvas to get
    under him (feet 0.2-0.4 m below it, clip_qa)."""
    keys = []
    if lying:
        keys.append((t, pose(SIT_UP)))
        crouch = t + max(3, (end - t) // 2)
        # Feet drawn in under him, weight coming forward off the hands. The
        # bones interpolate, not the targets: without this beat the foot
        # swung from out in front to under the hips through the canvas.
        if crouch - t >= 4:
            keys.append(((t + crouch) // 2, pose(GATHER)))
        t = crouch
    elif seated:
        # From sitting with the legs out: draw the feet in first, for the
        # same reason as above.
        keys.append((t, pose(GATHER)))
        t = t + max(3, (end - t) // 2)
    keys.append((t, pose(CROUCH)))
    keys.append((end, P()))
    return keys


def _face_fall(hit, end, **hit_over):
    """Struck and dropped forward onto his face, then rolled onto his back --
    head toward the attacker, which is Down_Supine's side."""
    staggered = P(pelvis=(0.0, 0.04, 0.800), spine=(-24, 0, 0), head=(-10, 0, 0),
                  hand_r=(0.30, 0.30, 0.90), hand_l=(-0.28, 0.32, 0.88),
                  fist_r=0.3, fist_l=0.3)
    staggered.update(hit_over)
    # Three frames to go over, three more to land: the four it used to take
    # threw him at the mat faster than he could have fallen.
    return [(hit, staggered),
            (hit + 3, dict(pelvis=(0.0, 0.08, 0.620), hips=(-50, 0, 0),
                           spine=(-14, 0, 0), head=(10, 0, 0),
                           hand_r=(0.34, 0.46, 0.50), hand_l=(-0.32, 0.48, 0.50),
                           fist_r=0.0, fist_l=0.0,
                           foot_r=(0.20, -0.30, 0.22), foot_l=(-0.18, -0.24, 0.24),
                           knee_r=(0.2, 0.4, -0.6), knee_l=(-0.2, 0.4, -0.6)))] \
        + _face_first_then_roll(hit + 6, end)


# Bicycle Knee Strike, 36 frames. Leaps off the left foot and drives the
# right knee into the face, pedalling (video frames 4-6); the victim's head
# snaps back, then he crumples forward onto his face (frames 7-11); the
# attacker lands and walks on past him.
CLIPS["Bicycle_Knee_Attacker"] = _run_in(kick=True) + [
    (9, _air(1.060, hips=(0, 0, 0), spine=(-4, 0, 0),
             hand_r=(0.30, 0.40, 1.30), hand_l=(-0.30, 0.00, 1.20),
             foot_r=(0.18, 0.36, 1.00), foot_l=(-0.16, -0.24, 0.62),
             knee_r=(0.2, 1.0, 0.3))),
    (11, _air(1.000, foot_r=(0.18, 0.00, 0.62), foot_l=(-0.16, 0.30, 0.90),
              knee_l=(-0.2, 1.0, 0.3))),
    (14, P(pelvis=(0.0, 0.06, 0.800), hips=(-10, 0, 0), spine=(-10, 0, 0),
           hand_r=(0.30, 0.10, 1.10), hand_l=(-0.30, 0.10, 1.10),
           foot_r=(0.20, 0.10, 0.104), foot_l=(-0.18, -0.10, 0.104))),
    (22, pose(RUN_B, pelvis=(0.0, 0.03, 0.830), hips=(-6, 0, 0), spine=(-8, 0, 0))),
    (30, pose(STAND)), (36, P()),
]
CLIPS["Bicycle_Knee_Defender"] = [
    (0, pose(STAND)), (8, pose(STAND, head=(4, 0, 0))),
    (9, P(pelvis=(0.0, -0.04, 0.840), spine=(16, 0, 0), head=(28, 0, 0),
          hand_r=(0.36, 0.10, 1.10), hand_l=(-0.34, 0.06, 1.06),
          fist_r=0.3, fist_l=0.3)),
] + _face_fall(12, 36)

# Cave-In, 36 frames. A leap from a step out, knees tucked, both feet driven
# into the chest (video frames 3-5); the victim is stamped flat on his back
# and the attacker comes down crouched over him.
CLIPS["Cave_In_Attacker"] = _run_in() + [
    (10, _air(1.200, hips=(-4, 0, 0), spine=(-10, 0, 0), head=(10, 0, 0),
              hand_r=(0.40, 0.40, 1.60), hand_l=(-0.40, 0.40, 1.60),
              foot_r=(0.16, 0.10, 0.70), foot_l=(-0.16, 0.06, 0.66))),
    (12, _air(1.150, hips=(8, 0, 0), spine=(-4, 0, 0), head=(-10, 0, 0),
              hand_r=(0.40, 0.10, 1.40), hand_l=(-0.40, 0.10, 1.40),
              foot_r=(0.14, 0.40, 0.90), foot_l=(-0.14, 0.40, 0.90),
              knee_r=(0.2, 1.0, 0.2), knee_l=(-0.2, 1.0, 0.2))),
    (15, pose(ATK_OVER)), (26, pose(ATK_OVER)),
    (36, P()),
]
CLIPS["Cave_In_Defender"] = [(0, pose(STAND)), (10, pose(STAND, head=(8, 0, 0)))] \
    + _back_fall(12, 36, pelvis_hit=0.90)

# Claymore, 36 frames. A running leap with the right leg thrown out straight
# into the face, body laid back behind it (video frames 6-8); both men go
# down, the attacker flat on his back.
CLIPS["Claymore_Attacker"] = _run_in(kick=True) + [
    (11, _air(1.100, hips=(30, 0, 0), spine=(10, 0, 0), head=(-20, 0, 0),
              hand_r=(0.40, 0.20, 1.40), hand_l=(-0.30, 0.40, 1.46),
              foot_r=(0.16, 0.80, 1.40), foot_l=(-0.16, 0.10, 0.80),
              knee_r=(0.0, 0.0, 1.0))),
    (14, _air(0.700, hips=(60, 0, 0), spine=(4, 0, 0), head=(-20, 0, 0),
              hand_r=(0.40, -0.10, 0.80), hand_l=(-0.40, -0.10, 0.80),
              foot_r=(0.16, 0.80, 0.90), foot_l=(-0.16, 0.50, 0.60),
              knee_r=(0.0, 0.0, 1.0), knee_l=(0.0, 0.2, 1.0))),
    (17, pose(ATK_BACK)),
] + _get_up(22, 36, lying=True)
CLIPS["Claymore_Defender"] = [(0, pose(STAND)), (9, pose(STAND, head=(4, 0, 0)))] \
    + _back_fall(11, 36, pelvis_hit=0.95)

# Cyclone Kick, 36 frames. Leaps and spins a full turn in the air (the root
# does the turn), the right boot swinging round into the head (video frames
# 3-5); the victim drops forward onto his face.
CLIPS["Cyclone_Kick_Attacker"] = _run_in(kick=True) + [
    (10, _air(1.050, spine=(-10, -30, 0),
              hand_r=(0.40, 0.00, 1.60), hand_l=(-0.30, 0.30, 1.20),
              foot_r=(0.34, 0.20, 1.00), knee_r=(0.3, 1.0, 0.3))),
    (12, _air(1.100, hips=(0, 0, -30), spine=(0, 10, 0),
              hand_r=(0.50, -0.20, 1.50), hand_l=(-0.40, 0.20, 1.10),
              foot_r=(0.50, 0.50, 1.50), foot_l=(-0.10, 0.00, 0.70),
              knee_r=(0.0, 0.0, 1.0))),
    (16, P(pelvis=(0.0, 0.0, 0.740), hips=(-16, 0, 0), spine=(-18, 0, 0),
           hand_r=(0.40, 0.10, 0.90), hand_l=(-0.40, 0.10, 0.90),
           foot_r=(0.24, -0.20, 0.104), foot_l=(-0.22, 0.20, 0.104))),
    (24, pose(STAND)), (36, P()),
]
CLIPS["Cyclone_Kick_Defender"] = [
    (0, pose(STAND)), (11, pose(STAND, head=(4, 0, 0))),
    (12, P(pelvis=(0.0, -0.04, 0.840), spine=(10, 20, 0), head=(20, 30, 0),
           hand_r=(0.36, 0.10, 1.10), hand_l=(-0.34, 0.06, 1.06),
           fist_r=0.3, fist_l=0.3)),
] + _face_fall(14, 36)

# Dragon Twist Cutter, 42 frames. Catches the head in a front facelock on the
# run, springs up and flips forward over it -- inverted above the victim's
# head (video frames 8-11) -- and lands on his back, bringing the head down
# with him: the victim is driven face-first. His orbit over the top is his
# root travelling past the victim (running_dragon_twist_cutter).
CLIPS["Dragon_Twist_Attacker"] = _run_in() + [
    (9, P(pelvis=(0.0, 0.06, 0.800), hips=(-10, 0, 0), spine=(-14, 0, 0),
          hand_r=(0.06, 0.40, 1.40), hand_l=(-0.14, 0.36, 1.36),
          elbow_r=(0.6, -0.4, -0.6), elbow_l=(-0.6, -0.4, -0.6),
          fist_r=0.6, fist_l=0.6)),
    (12, _air(1.300, hips=(-70, 0, 0), spine=(-10, 0, 0), head=(-10, 0, 0),
              hand_r=(0.06, 0.20, 1.10), hand_l=(-0.14, 0.18, 1.10),
              tuck=True)),
    (15, _air(1.500, hips=(-150, 0, 0), spine=(-6, 0, 0), head=(-10, 0, 0),
              hand_r=(0.06, 0.10, 1.10), hand_l=(-0.14, 0.10, 1.10),
              tuck=True)),
    (18, _air(1.000, hips=(-220, 0, 0), spine=(-4, 0, 0), head=(-10, 0, 0),
              hand_r=(0.10, 0.00, 1.10), hand_l=(-0.14, 0.00, 1.10),
              tuck=True)),
    (21, pose(ATK_BACK, hips=(84, 0, 0))),
    (25, pose(ATK_BACK)),
] + _get_up(28, 42, lying=True)
CLIPS["Dragon_Twist_Defender"] = [
    (0, pose(STAND)),
    (9, dict(pelvis=(0.0, -0.04, 0.800), hips=(-30, 0, 0), spine=(-20, 0, 0),
             head=(-6, 0, 0),
             hand_r=(0.26, 0.30, 0.96), hand_l=(-0.24, 0.32, 0.94),
             fist_r=0.4, fist_l=0.4,
             foot_r=(0.20, -0.16, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    (16, dict(pelvis=(0.0, -0.04, 0.760), hips=(-40, 0, 0), spine=(-24, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.26, 0.30, 0.80), hand_l=(-0.24, 0.32, 0.80),
              fist_r=0.4, fist_l=0.4,
              foot_r=(0.20, -0.16, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    # Spiked: pitching forward, feet leaving the mat behind him.
    (18, dict(pelvis=(0.0, 0.04, 0.560), hips=(-62, 0, 0), spine=(-14, 0, 0),
              head=(6, 0, 0),
              hand_r=(0.30, 0.46, 0.40), hand_l=(-0.28, 0.48, 0.40),
              fist_r=0.0, fist_l=0.0,
              foot_r=(0.20, -0.30, 0.22), foot_l=(-0.18, -0.24, 0.24),
              knee_r=(0.2, 0.4, -0.6), knee_l=(-0.2, 0.4, -0.6))),
] + _face_first_then_roll(21, 42)

# Fallaway Moonsault Slam, 42 frames. Leaps into the victim and hooks him,
# chest to chest, then falls backward taking him over the top -- the victim's
# legs pass overhead (video frames 9-11) -- and slams him down on his back
# beyond the attacker's head. The attacker ends flat on his back.
CLIPS["Fallaway_Attacker"] = _run_in() + [
    (9, _air(0.980, hand_r=(0.20, 0.44, 1.20), hand_l=(-0.20, 0.44, 1.24),
             foot_r=(0.20, 0.30, 0.50), foot_l=(-0.18, 0.30, 0.46))),
    (13, dict(pelvis=(0.0, 0.0, 0.700), hips=(40, 0, 0), spine=(10, 0, 0),
              head=(-20, 0, 0),
              hand_r=(0.20, 0.30, 1.30), hand_l=(-0.20, 0.30, 1.30),
              fist_r=0.6, fist_l=0.6,
              foot_r=(0.18, 0.40, 0.104), foot_l=(-0.18, 0.36, 0.104))),
    (18, pose(ATK_BACK, hand_r=(0.20, -0.60, 0.40), hand_l=(-0.20, -0.60, 0.40))),
] + _get_up(24, 42, lying=True)
# Over the top: face-down across the attacker's chest (hips -90), rolled
# face-up in the air on the way down, and flat on his back -- head toward
# +fwd, past the attacker, which is SUPINE. His root travels over the
# attacker's (running_fallaway_moonsault_slam).
CLIPS["Fallaway_Defender"] = [
    (0, pose(STAND)), (8, pose(STAND, head=(4, 0, 0))),
    (10, P(pelvis=(0.0, 0.04, 0.860), spine=(-10, 0, 0),
           hand_r=(0.26, 0.40, 1.10), hand_l=(-0.24, 0.42, 1.10),
           fist_r=0.4, fist_l=0.4)),
    # Timed over nine frames, not six: at six the hands crossed a metre and
    # a half in a frame. Arms held in the body's frame so they turn with him.
    (13, _body((-90, 0, 0), (0.0, 0.0, 1.300), spine=(-4, 0, 0), head=(4, 0, 0),
               hand_r=(0.40, 0.20, 0.30), hand_l=(-0.40, 0.20, 0.30),
               elbow_r=(0.8, -0.3, -0.4), elbow_l=(-0.8, -0.3, -0.4),
               fist_r=0.2, fist_l=0.2, **_TUCK_LEGS)),
    # On his side, arms already opening toward where they will hit the mat.
    (16, dict(_body((-88, 0, 90), (0.0, 0.0, 0.950), spine=(-4, 0, 0), head=(0, 0, 0),
                    fist_r=0.2, fist_l=0.2,
                    foot_r=(0.14, 0.10, -0.80), foot_l=(-0.14, 0.10, -0.80),
                    knee_r=(0.0, 1.0, 0.0), knee_l=(0.0, 1.0, 0.0), free_feet=True),
              hand_r=(-0.34, 0.24, 0.56), hand_l=(0.34, 0.22, 0.96),
              elbow_r=(-0.6, 0.2, -0.6), elbow_l=(0.6, 0.2, 0.6))),
    # A frame off the mat, back square to it, arms spread to slap it.
    (18, S(pelvis=(0.0, 0.0, 0.440), hips=(-84, 0, 170), head=(-2, 0, 0),
           hand_r=(-0.44, 0.20, 0.46), hand_l=(0.43, 0.16, 0.46),
           elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
           fist_r=0.1, fist_l=0.1,
           foot_r=(-0.14, -0.72, 0.60), foot_l=(0.12, -0.74, 0.64))),
    (19, S(pelvis=(0.0, 0.0, 0.200), hips=(-88, 0, 180), head=(-2, 0, 0),
           elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
           fist_r=0.1, fist_l=0.1,
           foot_r=(-0.14, -0.72, 0.30), foot_l=(0.12, -0.74, 0.34))),
    (24, S(pelvis=(0.0, 0.0, 0.180), spine=(-8, 0, 0), head=(-16, 0, 0))),
    (42, S()),
]

# Float-Over Liger Bomb, 60 frames / 2.0s. The float-over is reduced to its
# end: he runs into the victim, forces him forward and bent under him
# (video frames 8-14), hoists him up onto his shoulders sitting up, face to
# the lights (17-22), and sits out, slamming him down back-first in front of
# him (23-30). The victim's root yaws a half-turn through the slam, as in the
# Spear, so he lands the way Down_Supine lies.
CLIPS["Liger_Bomb_Attacker"] = _run_in() + [
    (10, P(pelvis=(0.0, 0.06, 0.780), hips=(-24, 0, 0), spine=(-30, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.20, 0.40, 0.90), hand_l=(-0.20, 0.40, 0.90),
           fist_r=0.6, fist_l=0.6)),
    (22, P(pelvis=(0.0, 0.06, 0.700), hips=(-34, 0, 0), spine=(-40, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.20, 0.40, 0.70), hand_l=(-0.20, 0.40, 0.70),
           fist_r=0.6, fist_l=0.6)),
    # The lift.
    (30, P(pelvis=(0.0, 0.0, 0.860), hips=(0, 0, 0), spine=(4, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.22, 0.20, 1.70), hand_l=(-0.22, 0.20, 1.70),
           fist_r=0.6, fist_l=0.6)),
    (38, P(pelvis=(0.0, 0.0, 0.870), hips=(2, 0, 0), spine=(4, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.22, 0.22, 1.74), hand_l=(-0.22, 0.22, 1.74),
           fist_r=0.6, fist_l=0.6)),
    # Sit-out.
    (40, pose(SIT_DROP, hand_r=(0.24, 0.36, 1.24), hand_l=(-0.24, 0.36, 1.24))),
    (42, pose(ATK_SEAT, hand_r=(0.24, 0.50, 0.30), hand_l=(-0.24, 0.50, 0.30))),
    (50, pose(ATK_SEAT)),
] + _get_up(53, 60, seated=True)
CLIPS["Liger_Bomb_Defender"] = [
    (0, pose(STAND)), (9, pose(STAND, head=(4, 0, 0))),
    (12, dict(pelvis=(0.0, 0.0, 0.760), hips=(-60, 0, 0), spine=(-20, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.30, 0.40, 0.60), hand_l=(-0.28, 0.42, 0.60),
              fist_r=0.4, fist_l=0.4,
              foot_r=(0.20, -0.20, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    (22, dict(pelvis=(0.0, 0.0, 0.740), hips=(-64, 0, 0), spine=(-22, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.30, 0.44, 0.50), hand_l=(-0.28, 0.46, 0.50),
              fist_r=0.4, fist_l=0.4,
              foot_r=(0.20, -0.20, 0.104), foot_l=(-0.18, 0.10, 0.104))),
    # Up on the shoulders, sitting up, legs hanging over the front.
    (30, dict(pelvis=(0.0, 0.10, 1.700), hips=(14, 0, 0), spine=(10, 0, 0),
              head=(10, 0, 0),
              hand_r=(0.40, 0.10, 2.10), hand_l=(-0.40, 0.10, 2.10),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, 0.50, 1.20), foot_l=(-0.18, 0.50, 1.20),
              knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0))),
    (38, dict(pelvis=(0.0, 0.10, 1.720), hips=(16, 0, 0), spine=(14, 0, 0),
              head=(14, 0, 0),
              hand_r=(0.44, 0.10, 2.10), hand_l=(-0.44, 0.10, 2.10),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, 0.50, 1.22), foot_l=(-0.18, 0.50, 1.22),
              knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0))),
] + _back_fall(38, 60, skip_hit=True, fall_z=1.00)

# Hoedown, 36 frames. A jumping knee into the face (video frames 3-4), and on
# the way down the head is caught and he drops to a seat on it, driving the
# victim face-first (5-8).
CLIPS["Hoedown_Attacker"] = _run_in() + [
    (10, _air(1.050, hips=(0, 0, 0), spine=(-6, 0, 0),
              hand_r=(0.30, 0.40, 1.30), hand_l=(-0.30, 0.10, 1.30),
              foot_r=(0.18, 0.36, 1.00), foot_l=(-0.16, -0.20, 0.62),
              knee_r=(0.2, 1.0, 0.3))),
    (13, _air(0.900, spine=(-20, 0, 0), head=(-10, 0, 0),
              hand_r=(0.06, 0.40, 0.90), hand_l=(-0.14, 0.36, 0.90))),
    (16, pose(ATK_SEAT, hand_r=(0.10, 0.40, 0.20), hand_l=(-0.14, 0.40, 0.20))),
    (24, pose(ATK_SEAT)),
] + _get_up(27, 36, seated=True)
CLIPS["Hoedown_Defender"] = [
    (0, pose(STAND)), (9, pose(STAND, head=(4, 0, 0))),
    (10, P(pelvis=(0.0, -0.04, 0.840), spine=(14, 0, 0), head=(26, 0, 0),
           hand_r=(0.36, 0.10, 1.10), hand_l=(-0.34, 0.06, 1.06),
           fist_r=0.3, fist_l=0.3)),
] + _face_fall(13, 36, spine=(-30, 0, 0), head=(-14, 0, 0))

# Jumping Cravate Driver, 36 frames. Leaps and locks both arms round the head
# -- the cravate -- then drops to his side, driving the head into the mat
# (video frames 5-10). The victim goes face-first.
CLIPS["Cravate_Attacker"] = _run_in() + [
    (10, _air(1.000, spine=(-14, 0, 0), head=(-6, 0, 0),
              hand_r=(0.04, 0.46, 1.40), hand_l=(-0.10, 0.46, 1.40),
              elbow_r=(0.7, -0.3, -0.5), elbow_l=(-0.7, -0.3, -0.5))),
    (13, _air(0.800, hips=(10, 0, 0), spine=(-10, 0, 0), head=(-10, 0, 0),
              hand_r=(0.04, 0.40, 0.90), hand_l=(-0.10, 0.40, 0.90),
              elbow_r=(0.7, -0.3, -0.5), elbow_l=(-0.7, -0.3, -0.5))),
    (16, pose(ATK_SEAT, hips=(40, 0, 0), hand_r=(0.04, 0.40, 0.24),
              hand_l=(-0.10, 0.40, 0.24))),
] + _get_up(24, 36, lying=True)
CLIPS["Cravate_Defender"] = [
    (0, pose(STAND)), (9, pose(STAND, head=(4, 0, 0))),
] + _face_fall(12, 36, spine=(-30, 0, 0), head=(-14, 0, 0))

# Last Shot, 36 frames. Leaps with both legs thrown up and forward and the
# arms up (video frames 1-3), hooks the head as he falls back, and takes the
# victim over with him -- the victim's legs go up behind (frame 4) -- both
# flat on their backs.
CLIPS["Last_Shot_Attacker"] = _run_in() + [
    (10, _air(1.050, hips=(20, 0, 0), spine=(0, 0, 0), head=(-10, 0, 0),
              hand_r=(0.20, 0.10, 1.90), hand_l=(-0.20, 0.10, 1.86),
              foot_r=(0.16, 0.60, 1.00), foot_l=(-0.16, 0.56, 0.96),
              knee_r=(0.0, 0.2, 1.0), knee_l=(0.0, 0.2, 1.0))),
    (13, _air(0.800, hips=(50, 0, 0), spine=(0, 0, 0), head=(-20, 0, 0),
              hand_r=(0.10, 0.40, 1.00), hand_l=(-0.10, 0.40, 1.00),
              foot_r=(0.16, 0.60, 0.90), foot_l=(-0.16, 0.56, 0.86),
              knee_r=(0.0, 0.2, 1.0), knee_l=(0.0, 0.2, 1.0))),
    (16, pose(ATK_BACK)),
] + _get_up(24, 36, lying=True)
CLIPS["Last_Shot_Defender"] = [(0, pose(STAND)), (10, pose(STAND, head=(4, 0, 0)))] \
    + [(12, _flip(-60, (0.0, 0.0, 1.000)))] \
    + _face_first_then_roll(15, 36)

# --- batch 3 -------------------------------------------------------------------

# A front facelock grip on the run: head under his right arm.
def _facelock(z=0.800, **over):
    base = P(pelvis=(0.0, 0.06, z), hips=(-10, 0, 0), spine=(-16, 0, 0),
             head=(-6, 0, 0),
             hand_r=(0.06, 0.40, 1.30), hand_l=(-0.14, 0.36, 1.28),
             elbow_r=(0.6, -0.4, -0.6), elbow_l=(-0.6, -0.4, -0.6),
             fist_r=0.6, fist_l=0.6)
    base.update(over)
    return base


VICTIM_BENT = dict(pelvis=(0.0, -0.04, 0.780), hips=(-40, 0, 0), spine=(-24, 0, 0),
                   head=(-10, 0, 0),
                   hand_r=(0.26, 0.30, 0.80), hand_l=(-0.24, 0.32, 0.80),
                   fist_r=0.4, fist_l=0.4,
                   foot_r=(0.20, -0.16, 0.104), foot_l=(-0.18, 0.10, 0.104))

# Leaping Mushroom Stomp, 36 frames. A high leap from a step out, both feet
# brought down on the head and shoulders (video frames 3-6); the victim is
# stamped face-first and the attacker lands on his feet past him.
CLIPS["Mushroom_Stomp_Attacker"] = _run_in() + [
    (10, _air(1.350, hips=(-4, 0, 0), head=(10, 0, 0),
              hand_r=(0.40, 0.40, 1.70), hand_l=(-0.40, 0.40, 1.70),
              foot_r=(0.16, 0.10, 0.90), foot_l=(-0.16, 0.06, 0.86))),
    (12, _air(1.250, hips=(4, 0, 0), head=(-14, 0, 0),
              hand_r=(0.40, 0.10, 1.40), hand_l=(-0.40, 0.10, 1.40),
              foot_r=(0.14, 0.30, 0.80), foot_l=(-0.14, 0.30, 0.80))),
    (15, pose(ATK_OVER, pelvis=(0.0, 0.04, 0.700))),
    (24, pose(STAND)), (36, P()),
]
CLIPS["Mushroom_Stomp_Defender"] = [(0, pose(STAND)), (10, pose(STAND, head=(10, 0, 0)))] \
    + _face_fall(12, 36, pelvis=(0.0, 0.04, 0.700), spine=(-40, 0, 0))

# Leg Lariat, 36 frames. Leaps and swings the right leg across the throat,
# body turned side-on (video frames 13-16); the victim is turned over
# backward, legs up, and lands face-down; the attacker drops to a seat.
CLIPS["Leg_Lariat_Attacker"] = _run_in(kick=True) + [
    (11, _air(1.100, hips=(0, 0, -50), spine=(0, 0, -10),
              hand_r=(0.50, 0.00, 1.20), hand_l=(-0.10, 0.10, 1.50),
              foot_r=(0.10, 0.80, 1.40), foot_l=(0.30, 0.10, 0.80),
              knee_r=(0.0, 0.0, 1.0), knee_l=(0.0, 1.0, 0.0))),
    (14, _air(0.700, hips=(20, 0, -30),
              hand_r=(0.40, -0.10, 0.60), hand_l=(-0.40, -0.10, 0.60),
              foot_r=(0.16, 0.70, 0.60), foot_l=(-0.16, 0.50, 0.50))),
    (16, pose(ATK_SEAT)), (24, pose(ATK_SEAT)),
] + _get_up(27, 36, seated=True)
CLIPS["Leg_Lariat_Defender"] = [
    (0, pose(STAND)), (10, pose(STAND, head=(4, 0, 0))),
    (11, P(pelvis=(0.0, -0.06, 0.900), spine=(24, 0, 0), head=(34, 0, 0),
           hand_r=(0.38, 0.10, 1.12), hand_l=(-0.36, 0.06, 1.10),
           fist_r=0.2, fist_l=0.2)),
    (14, _flip(80, (0.0, 0.0, 1.050))),
    (17, _flip(160, (0.0, 0.0, 1.150))),
    (20, _flip(230, (0.0, 0.0, 0.800))),
] + _face_first_then_roll(23, 36)

# Play of the Day, 36 frames. Takes the head in both hands on the run and
# pulls it down into a leaping knee (video frames 13-15); the victim goes over
# backward.
CLIPS["Play_Of_Day_Attacker"] = _run_in() + [
    (9, _facelock(hand_r=(0.14, 0.52, 1.46), hand_l=(-0.14, 0.52, 1.46))),
    (11, _air(1.000, spine=(-24, 0, 0), head=(-10, 0, 0),
              hand_r=(0.14, 0.46, 1.10), hand_l=(-0.14, 0.46, 1.10),
              foot_r=(0.18, 0.40, 1.00), foot_l=(-0.16, -0.10, 0.60),
              knee_r=(0.2, 1.0, 0.3))),
    (14, P(pelvis=(0.0, 0.06, 0.780), hips=(-14, 0, 0), spine=(-20, 0, 0),
           hand_r=(0.30, 0.20, 1.10), hand_l=(-0.30, 0.20, 1.10))),
    (24, pose(STAND)), (36, P()),
]
CLIPS["Play_Of_Day_Defender"] = [
    (0, pose(STAND)),
    (9, pose(VICTIM_BENT, hips=(-20, 0, 0), spine=(-14, 0, 0))),
    (10, pose(VICTIM_BENT)),
] + _back_fall(12, 36, pelvis_hit=0.90)

# Reverse Swing Neckbreaker, 48 frames. Takes the head, swings himself right
# round the victim -- legs over the top (video frames 12-17) -- and drops to
# a seat behind him with the head on his shoulder; the victim is pulled over
# backward onto his back. The swing is the attacker's root orbiting half a
# circle round the victim to his far side (running_reverse_swing_neckbreaker).
CLIPS["Swing_Neck_Attacker"] = _run_in() + [
    (9, _facelock()),
    (13, _air(1.200, hips=(-60, 0, 30), spine=(-10, 0, 0),
              hand_r=(0.06, 0.20, 1.10), hand_l=(-0.14, 0.18, 1.10),
              tuck=True)),
    (17, _air(1.300, hips=(-100, 0, 60), spine=(-6, 0, 0),
              hand_r=(0.06, 0.10, 1.10), hand_l=(-0.14, 0.10, 1.10),
              tuck=True)),
    (21, _facelock(0.820, hips=(-4, 0, 0), spine=(-6, 0, 0),
                   hand_r=(0.10, 0.20, 1.40), hand_l=(-0.10, 0.20, 1.40))),
    (23, pose(SIT_DROP, hand_r=(0.10, 0.26, 0.90), hand_l=(-0.10, 0.26, 0.90))),
    (25, pose(ATK_SEAT, hand_r=(0.10, 0.30, 0.50), hand_l=(-0.10, 0.30, 0.50))),
    (34, pose(ATK_SEAT)),
] + _get_up(38, 48, seated=True)
CLIPS["Swing_Neck_Defender"] = [
    (0, pose(STAND)),
    (9, pose(VICTIM_BENT, hips=(-20, 0, 0), spine=(-12, 0, 0))),
    (21, P(pelvis=(0.0, -0.04, 0.820), spine=(10, 0, 0), head=(20, 0, 0),
           hand_r=(0.10, 0.12, 1.44), hand_l=(-0.10, 0.12, 1.44),
           fist_r=0.5, fist_l=0.5)),
] + _back_fall(23, 48, pelvis_hit=0.80)

# Rolling Codebreaker, 48 frames. Rolls forward over the victim's back --
# inverted across it (video frames 12-18) -- lands in front of him, springs
# up and catches the jaw on both knees, falling back to a seat (35-39); the
# victim goes over backward. The roll-over is the root travelling past the
# victim and turning to face him (running_rolling_codebreaker).
CLIPS["Codebreaker_Attacker"] = _run_in() + [
    (9, _facelock(hips=(-30, 0, 0), spine=(-30, 0, 0))),
    # An even rotation, about 26 degrees a frame, from the lock to the knee.
    (13, _air(1.300, hips=(-130, 0, 0), tuck=True,
              hand_r=(0.20, 0.30, 0.90), hand_l=(-0.20, 0.30, 0.90))),
    (16, _air(1.250, hips=(-215, 0, 0), tuck=True,
              hand_r=(0.20, 0.30, 0.90), hand_l=(-0.20, 0.30, 0.90))),
    # Carries on over (not back the way he came) to land on the knee.
    # Over the top, still tucked -- the legs open on the next beat.
    (19, _air(1.000, hips=(-295, 0, 0), tuck=True,
              hand_r=(0.20, 0.30, 0.90), hand_l=(-0.20, 0.30, 0.90))),
    # Feet find the mat a beat before the knee does.
    (21, dict(pelvis=(0.0, 0.04, 0.800), hips=(-348, 0, 0), spine=(-14, 0, 0),
              head=(-8, 0, 0),
              hand_r=(0.24, 0.30, 0.90), hand_l=(-0.26, 0.24, 0.86),
              fist_r=0.3, fist_l=0.3,
              foot_r=(0.20, 0.10, 0.20), foot_l=(-0.20, 0.30, 0.18),
              knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1), free_feet=True)),
    (23, pose(ONE_KNEE)),
    (26, P(pelvis=(0.0, 0.0, 0.760), hips=(-10, 0, 0), spine=(-16, 0, 0))),
    (30, _air(1.050, hips=(10, 0, 0), spine=(-10, 0, 0),
              hand_r=(0.10, 0.40, 1.50), hand_l=(-0.10, 0.40, 1.50),
              foot_r=(0.16, 0.30, 0.90), foot_l=(-0.16, 0.30, 0.90),
              knee_r=(0.2, 1.0, 0.3), knee_l=(-0.2, 1.0, 0.3))),
    (33, pose(ATK_SEAT)), (40, pose(ATK_SEAT)),
] + _get_up(41, 48, seated=True)
CLIPS["Codebreaker_Defender"] = [
    (0, pose(STAND)),
    (9, pose(VICTIM_BENT)), (17, pose(VICTIM_BENT)),
    (24, P(spine=(-6, 0, 0), head=(6, 0, 0),
           hand_r=(0.26, 0.24, 1.10), hand_l=(-0.24, 0.26, 1.08))),
    (29, P(spine=(-10, 0, 0), head=(-6, 0, 0),
           hand_r=(0.26, 0.24, 1.10), hand_l=(-0.24, 0.26, 1.08))),
] + _back_fall(31, 48, pelvis_hit=0.90)

# Rolling Thunder Flatliner, 42 frames. A forward roll along the mat into the
# victim (video frames 15-17), up into a front facelock, and falls back
# driving him face-first into the mat (18-23).
CLIPS["Thunder_Flatliner_Attacker"] = [
    (0, pose(RUN_A)), (4, pose(RUN_B)),
    (7, pose(ONE_KNEE)),
    # The forward roll: hands to the mat, chin tucked, over the shoulders
    # with the legs folded (in the body's frame -- see _body), and up onto
    # the knee. Keyed in the room's frame it put his head 0.2 m into the mat.
    (9,  _body((-64, 0, 0), (0.0, 0.14, 0.580), spine=(-26, 0, 0), head=(-20, 0, 0),
               hand_r=(0.20, 0.50, 0.20), hand_l=(-0.20, 0.50, 0.20),
               elbow_r=(0.6, -0.4, 0.0), elbow_l=(-0.6, -0.4, 0.0),
               fist_r=0.0, fist_l=0.0, **_TUCK_LEGS)),
    (11, _body((-160, 0, 0), (0.0, 0.20, 0.600), spine=(-36, 0, 0), head=(-34, 0, 0),
               hand_r=(0.18, 0.30, 0.30), hand_l=(-0.18, 0.30, 0.30),
               elbow_r=(0.5, -0.4, -0.4), elbow_l=(-0.5, -0.4, -0.4),
               fist_r=0.2, fist_l=0.2, **_TUCK_LEGS)),
    (13, _body((-240, 0, 0), (0.0, 0.26, 0.420), spine=(-30, 0, 0), head=(-26, 0, 0),
               hand_r=(0.18, 0.30, 0.30), hand_l=(-0.18, 0.30, 0.30),
               elbow_r=(0.5, -0.4, -0.4), elbow_l=(-0.5, -0.4, -0.4),
               fist_r=0.2, fist_l=0.2, **_TUCK_LEGS)),
    # Out of the roll onto both feet, then down onto the knee.
    (15, dict(pelvis=(0.0, 0.10, 0.460), hips=(-330, 0, 0), spine=(-30, 0, 0),
              head=(-6, 0, 0),
              hand_r=(0.24, 0.36, 0.50), hand_l=(-0.24, 0.36, 0.50),
              fist_r=0.2, fist_l=0.2,
              foot_r=(0.20, 0.02, 0.104), foot_l=(-0.20, 0.20, 0.104),
              knee_r=(0.3, 1.0, 0.3), knee_l=(-0.3, 1.0, 0.3))),
    (17, pose(ONE_KNEE)),
    (19, _facelock(0.820)),
    # Sitting out with the head: seat first, legs shooting out in front.
    (21, dict(pelvis=(0.0, 0.0, 0.460), hips=(36, 0, 0), spine=(-10, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.06, 0.32, 0.60), hand_l=(-0.14, 0.32, 0.60),
              fist_r=0.6, fist_l=0.6,
              foot_r=(0.16, 0.44, 0.14), foot_l=(-0.16, 0.40, 0.14),
              knee_r=(0.2, 0.4, 1.0), knee_l=(-0.2, 0.4, 1.0))),
    (23, pose(ATK_BACK, hand_r=(0.06, 0.30, 0.40), hand_l=(-0.14, 0.30, 0.40))),
] + _get_up(30, 42, lying=True)
CLIPS["Thunder_Flatliner_Defender"] = [
    (0, pose(STAND)), (16, pose(STAND, head=(6, 0, 0))),
    (19, pose(VICTIM_BENT)),
] + _face_fall(21, 42, pelvis=(0.0, 0.06, 0.700), spine=(-40, 0, 0))

# Running Gamengiri, 36 frames. Leaps, turns side-on and whips the right shin
# into the side of the head (video frames 16-19); lands on his side, rolls
# up. The victim drops forward onto his face.
CLIPS["Gamengiri_Attacker"] = _run_in(kick=True) + [
    (11, _air(1.050, hips=(10, 0, -60), spine=(0, 0, -10),
              hand_r=(0.50, 0.00, 1.00), hand_l=(-0.10, 0.10, 1.40),
              foot_r=(0.20, 0.70, 1.60), foot_l=(0.30, 0.10, 0.80),
              knee_r=(0.0, 0.0, 1.0), knee_l=(0.0, 1.0, 0.0))),
    (14, _air(0.620, hips=(-10, 0, -80), tuck=True,
              hand_r=(0.70, 0.10, 0.20), hand_l=(-0.10, 0.20, 0.70))),
    (17, dict(pelvis=(0.0, 0.05, 0.180), hips=(-8, 0, -86), spine=(0, 0, -4),
              head=(0, 0, 16),
              hand_r=(0.70, 0.10, 0.08), hand_l=(0.10, 0.30, 0.30),
              fist_r=0.0, fist_l=0.0)),
    (21, dict(SIDE_PUSH)),
] + _get_up(26, 36)
CLIPS["Gamengiri_Defender"] = [(0, pose(STAND)), (9, pose(STAND, head=(4, 0, 0)))] \
    + _face_fall(11, 36, spine=(-10, 20, 0), head=(-4, 30, 0))

# Spear, running. The finisher's charge from a sprint, without the shove-off
# and load it needs from a lock-up (video frames 55-57): Spear_Attacker's
# explosion, impact and follow-through, fed from the run.
CLIPS["Run_Spear_Attacker"] = [(0, pose(RUN_A)), (4, pose(RUN_B))] + \
    [(k - 12, v) for k, v in CLIPS["Spear_Attacker"] if k >= 16]
CLIPS["Run_Spear_Defender"] = [(0, pose(STAND))] + \
    [(k - 12, v) for k, v in CLIPS["Spear_Defender"] if k >= 19]

# Stundog Millionaire, 42 frames. Leaps into a front facelock, hangs from it
# with his legs swung up (video frames 18-22), and drops to his back, spiking
# the head: the victim's legs go up over him (23-25) before he falls on his
# face.
CLIPS["Stundog_Attacker"] = _run_in() + [
    (9, _facelock()),
    (12, _air(1.050, spine=(-20, 0, 0), head=(-8, 0, 0),
              hand_r=(0.06, 0.36, 1.00), hand_l=(-0.14, 0.34, 1.00),
              foot_r=(0.16, 0.60, 1.00), foot_l=(-0.16, 0.56, 0.96),
              knee_r=(0.0, 0.2, 1.0), knee_l=(0.0, 0.2, 1.0))),
    (15, pose(ATK_SEAT, hips=(40, 0, 0), hand_r=(0.06, 0.34, 0.30),
              hand_l=(-0.14, 0.34, 0.30))),
    (20, pose(ATK_BACK)),
] + _get_up(28, 42, lying=True)
CLIPS["Stundog_Defender"] = [
    (0, pose(STAND)), (9, pose(VICTIM_BENT)),
    (13, _flip(-130, (0.0, 0.10, 0.700))),
    (16, _flip(-150, (0.0, 0.10, 0.800))),
] + _face_first_then_roll(20, 42)

# Tilt-A-Whirl Backstabber, 54 frames. The Tilt-A-Whirl's orbit (video
# frames 13-26), but coming round he lets the victim fall back and drops
# under him: the small of the back lands on his raised knees as he goes down
# on his own back (32-39), and the victim is flat on his.
CLIPS["Backstabber_Attacker"] = [k for k in CLIPS["Tilt_DDT_Attacker"] if k[0] <= 17] + [
    (20, P(pelvis=(0.0, 0.04, 0.820), hips=(-10, 0, 0), spine=(-16, 0, 0),
           hand_r=(0.20, 0.30, 1.30), hand_l=(-0.20, 0.30, 1.30))),
    (28, P(pelvis=(0.0, 0.04, 0.800), hips=(-10, 0, 0), spine=(-16, 0, 0),
           hand_r=(0.20, 0.30, 1.20), hand_l=(-0.20, 0.30, 1.20))),
    # Drops to his seat, the victim's head pulled down onto his shoulder.
    (30, pose(SIT_DROP, hand_r=(0.20, 0.30, 1.00), hand_l=(-0.20, 0.30, 1.00))),
    (34, pose(ATK_BACK, foot_r=(0.16, 0.30, 0.10), foot_l=(-0.16, 0.30, 0.10),
              knee_r=(0.2, 0.2, 1.0), knee_l=(-0.2, 0.2, 1.0))),
] + _get_up(40, 54, lying=True)
CLIPS["Backstabber_Defender"] = [k for k in CLIPS["Tilt_DDT_Defender"] if k[0] <= 14] + [
    (20, P(pelvis=(0.0, 0.0, 0.840), spine=(4, 0, 0), head=(8, 0, 0),
           hand_r=(0.26, 0.20, 1.10), hand_l=(-0.24, 0.20, 1.08))),
    (28, P(pelvis=(0.0, -0.04, 0.820), spine=(14, 0, 0), head=(20, 0, 0),
           hand_r=(0.30, 0.10, 1.20), hand_l=(-0.28, 0.10, 1.18))),
] + _back_fall(31, 54, pelvis_hit=0.70)

# --- build ----------------------------------------------------------------

def load_rig():
    """Fresh scene with just the base rig's armature in it."""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=RIG)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit("expected exactly one armature, got %d" % len(arms))
    bpy.context.scene.render.fps = FPS
    return arms[0]


def clear_actions():
    """Drop the 42 source actions so only authored ones are exported."""
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)


def drop_mesh():
    """Export the skeleton and its clips, not the body.

    The rig's mesh is ~680 KB of the glb and is already shipped by
    wrestler_base.glb and each roster model; carrying a second copy here
    just to hold animation would bloat the repo for nothing.
    """
    for obj in list(bpy.data.objects):
        if obj.type != "ARMATURE":
            bpy.data.objects.remove(obj, do_unlink=True)


def author(poser, arm, name, frames):
    """Keyframe one action from a list of (frame, pose) entries."""
    action = bpy.data.actions.new(name)
    arm.animation_data_clear()
    arm.animation_data_create()
    arm.animation_data.action = action

    bones = keyed_bones(arm)
    for frame, spec in frames:
        poser.apply(spec)
        poser.key(frame, bones)

    # Quaternion keys made sign-continuous, bone by bone.
    #
    # q and -q are the same rotation, and the solver hands back whichever
    # sign the matrix decomposition happens to land on. Blender interpolates
    # a quaternion's four channels independently, so two neighbouring keys of
    # opposite sign interpolate through a rotation that is neither -- the
    # limb swings the long way round between two keys that agree. Measured by
    # tools/probe/move_qa.tscn: Down_Supine's right arm passed 0.31 m under
    # the mat and snapped back 0.57 m in two ticks, once per loop, in every
    # knockdown in the game. Flipping each key into its predecessor's
    # hemisphere changes no pose and removes every such swing.
    for pb in arm.pose.bones:
        path = 'pose.bones["%s"].rotation_quaternion' % pb.name
        curves = [action.fcurves.find(path, index=i) for i in range(4)]
        if any(c is None for c in curves):
            continue
        prev = None
        for k in range(len(curves[0].keyframe_points)):
            q = [c.keyframe_points[k].co[1] for c in curves]
            if prev is not None and sum(a * b for a, b in zip(prev, q)) < 0.0:
                q = [-v for v in q]
                for c, v in zip(curves, q):
                    c.keyframe_points[k].co[1] = v
            prev = q

    # Bezier everywhere. Linear interpolation on organic motion reads as
    # mechanical, and a wrestler moving at a constant rate between poses is
    # the clearest tell that a clip was generated rather than performed.
    for fcurve in action.fcurves:
        for key in fcurve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
        # Recompute the handles from the keys as they now stand. Without it
        # the sign flips above move a key's value and leave its handles
        # aimed at the old one, and the curve bows away between two keys
        # that agree -- Down_Supine's arm still dipped 16 cm mid-interval.
        fcurve.update()
    return action


def export(path):
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_apply=False,
        # Determinism: no timestamps, no generator string churn.
        export_yup=True,
    )


def main():
    arm = load_rig()
    clear_actions()
    poser = RigPoser(arm)
    for name in sorted(CLIPS):
        author(poser, arm, name, CLIPS[name])
    # Every action must survive the export. ACTIONS mode walks the actions
    # that could be assigned to the armature, so the armature must KEEP its
    # animation_data -- clearing it (tried first) exported an armature with
    # 29 actions authored and zero animations in the glb.
    for action in bpy.data.actions:
        action.use_fake_user = True
    drop_mesh()
    export(OUT)
    print("wrote %s (%d clips)" % (OUT, len(CLIPS)))


if __name__ == "__main__":
    main()
