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

from rig_pose import RigPoser, keyed_bones  # noqa: E402

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

# A man on his back: hips rolled back to horizontal, shoulders on the mat,
# head toward -fwd. Knees poled UP rather than forward, or the solver
# straightens his legs flat along the canvas.
SUPINE = dict(
    pelvis=(0.0, 0.0, 0.175), hips=(-84, 0, 0), spine=(-6, 0, 0), head=(14, 0, 0),
    hand_r=(0.36, -0.26, 0.11), hand_l=(-0.35, -0.22, 0.11),
    elbow_r=(0.7, -0.5, 0.5), elbow_l=(-0.7, -0.5, 0.5),
    fist_r=0.2, fist_l=0.2,
    foot_r=(0.17, 0.40, 0.10), foot_l=(-0.16, 0.36, 0.10),
    knee_r=(0.3, 0.15, 1.0), knee_l=(-0.3, 0.15, 1.0),
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
            # SIGNED by which side the hand is on. Unsigned, `+ arm_spread`
            # pushes the right hand out and pulls the LEFT one in across the
            # body, so the swing is lopsided and the left arm crosses the
            # navel at the extremes. Walk_Entrance is the first clip to pass a
            # spread at all, so nothing else in this file moves.
            over["hand_%s" % side] = (
                hand_x[side] + math.copysign(arm_spread * abs(drive),
                                             hand_x[side]),
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
        (0,  P()),
        (19, P(pelvis=(-0.02, 0.035, 0.868), spine=(11, 6, -3),
               head=(-3, 10, 0), hand_r=(0.18, 0.32, 1.32),
               hand_l=(-0.12, 0.36, 1.37))),
        # Breath in: the chest lifts and the guard rides up with it.
        (38, P(pelvis=(0.0, 0.02, 0.874), spine=(10, 6, 0), head=(-4, 8, 0),
               hand_r=(0.17, 0.31, 1.34), hand_l=(-0.13, 0.36, 1.38))),
        (56, P(pelvis=(0.03, 0.012, 0.852), spine=(13, 5, 3), head=(-1, 6, 0),
               hand_r=(0.16, 0.29, 1.28), hand_l=(-0.14, 0.34, 1.33))),
        (75, P()),
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
    # Hands stay up and the shoulders counter the hips, which is the part of
    # "stalk" the pose can still keep.
    "Walk_Stalk": _gait(
        frames=16, fps=FPS, speed=3.5,
        contacts={"r": (0, 5), "l": (8, 5)},
        plant_up=0.104, lift_up=0.11,
        foot_x={"r": 0.20, "l": -0.19},
        pelvis_up=0.862, pelvis_dip=0.018,
        hips_yaw=6.0, spine=(4.0, 0.0), head=(-2, 0, 0),
        hand_fwd=(0.26, 0.37), hand_up=(1.29, 1.35),
        hand_x={"r": 0.17, "l": -0.13}, elbow=None),

    # 28 frames / 0.933s, looping: the walk to the ring, and the only gait in
    # this file that is not a fighting pose.
    #
    # Walk_Stalk above cannot do this job and was never meant to. It is a man
    # circling an opponent -- 16 frames, hands up at 1.29-1.35, short steps at
    # MOVE_SPEED -- and played down a 24 m ramp it reads as a wrestler who
    # has spotted someone in the crowd. An entrance is the opposite posture:
    # nobody is in front of him, so the guard comes down and the walk becomes
    # the performance.
    #
    # A WALK, not a run, and that is a construction difference rather than a
    # speed one. Every other cycle here has a flight phase -- Run_Drive spends
    # 70% of its cycle with neither foot down. A walk never does: one foot is
    # always on the mat, with a beat of double support as the weight crosses
    # over. That is what `contacts` says below -- right planted 0-14, left
    # planted 14-28 -- and it is why the two windows sum to the whole cycle
    # instead of leaving a gap.
    #
    # Speed is 1.45 m/s, which is not a game constant and deliberately so: no
    # MoveDef and no WrestlerController speed applies here, because the
    # EntranceDirector moves him rather than the locomotion code. It is
    # measured the other way round -- the director reads
    # ENTRANCE_WALK_SPEED off this number, so the planted foot holds the floor
    # for the same reason Walk_Stalk's does. Change one and the other must
    # follow or the ramp slides under the boot.
    #
    # 14 frames on the mat covering 0.677 m puts the planted foot +-0.338 m
    # either side of the hip, past the +-0.30 m a leg reaches at rest height,
    # so the pelvis drops to 0.845 to buy the reach -- the same trade
    # Run_Drive makes at 0.80 for its +-0.35 m.
    #
    # The arms hang and swing rather than pumping: hand_up 0.92-1.06 is hip
    # height against the guard's 1.29-1.35, and hand_x is wider than any other
    # clip here (0.30 / -0.29 against the stance's 0.24 / -0.21) because a
    # heavyweight does not walk with his arms touching his ribs. arm_spread
    # carries them further out at the extremes of the swing, which is the roll
    # through the shoulders.
    #
    # The ELBOW POLES are the part this got wrong first and it was only visible
    # on a rendered frame. They were (+-0.6, -0.6, -0.3) -- wide and well back
    # -- which threw the elbows out to the sides while the hands stayed at the
    # waist, so the forearms angled inward and the whole thing read as a man
    # walking with his hands on his hips, a lat spread rather than a walk. They
    # are now close to Run_Drive's (+-0.3, -0.9, -0.3): mostly BACKWARD, barely
    # out, which is where an elbow is on a hanging arm. Nothing in the numbers
    # said the first set was wrong; the front view said it immediately.
    #
    # Chest out and chin up: spine +4 is a slight backward lean and head +6
    # lifts the chin, both POSITIVE for the reason the STANCE comment
    # documents at length -- on this rig a positive pitch tips back. The
    # sign is the one thing in this file that has been got wrong twice.
    "Walk_Entrance": _gait(
        frames=28, fps=FPS, speed=1.45,
        contacts={"r": (0, 14), "l": (14, 14)},
        plant_up=0.104, lift_up=0.07,
        foot_x={"r": 0.22, "l": -0.21},
        pelvis_up=0.845, pelvis_dip=0.022,
        hips_yaw=9.0, spine=(4.0, 4.0), head=(6, 0, 0),
        hand_fwd=(-0.24, 0.26), hand_up=(0.92, 1.06),
        hand_x={"r": 0.30, "l": -0.29},
        elbow={"r": (0.26, -0.90, -0.22), "l": (-0.26, -0.90, -0.22)},
        arm_spread=0.04),

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

    # 18 frames / 0.6s, LEFT hook to the head, contact on frame 6 (= tick 12
    # of strike_hook.tres).
    #
    # This clip exists for repetition rather than for a gap in the moveset.
    # Every strike in this file starts and ends at the same STANCE and is
    # drawn from a seeded pool, so with two punches in that pool a long match
    # plays the same two arm motions several dozen times and the eye starts
    # counting them. A third punch that is neither of the other two breaks
    # that up for the cost of one table.
    #
    # It is a hook and not a mirrored jab, and that is forced rather than
    # chosen: STANCE is orthodox and asymmetric -- left foot leading, right
    # foot back and turned out -- so the mirror of a lead-hand jab is a
    # rear-hand punch thrown from a stance nobody is standing in. Mirroring
    # the clip would have meant mirroring the stance, and the stance is what
    # lets every clip here cut into every other one. A hook keeps the lead
    # hand and changes the PATH instead: it comes from outside the shoulder
    # and arrives across, where the jab goes straight down the middle.
    "Strike_Hook": [
        (0,  P()),
        # Load: weight settles onto the lead foot and the left hand drifts
        # OUT, wide of the shoulder -- the wind-up of a hook is lateral, and
        # it is the one punch here you are allowed to see coming.
        (4,  P(pelvis=(0.03, 0.0, 0.852), hips=(0, -12, 0), spine=(-10, -8, 4),
               head=(4, -4, 0),
               hand_l=(-0.34, 0.30, 1.36), hand_r=(0.26, 0.30, 1.28),
               elbow_l=(-0.9, 0.1, -0.2))),
        # Contact: the hand comes ACROSS at head height, not forward -- it
        # arrives 0.30 m off the centre line, which is what makes a hook
        # read as a hook from the hard camera rather than as a wide jab. The
        # hips and the lead shoulder drive it and the back heel lifts.
        (6,  P(pelvis=(-0.01, 0.05, 0.860), hips=(-4, 16, 0),
               spine=(-10, 30, 6), head=(8, -16, 0), clav_l=(0, 18, 0),
               hand_l=(-0.30, 0.54, 1.42), hand_r=(0.22, 0.30, 1.28),
               elbow_l=(-0.9, 0.0, 0.1), fist_l=0.95,
               foot_r=(0.23, -0.17, 0.132), ankle_r=(24, 0, 0))),
        # Through it and turning: a hook has nothing to stop it, so the arm
        # keeps travelling across the body and the torso goes with it.
        (10, P(pelvis=(-0.03, 0.04, 0.854), hips=(-4, 24, 0),
               spine=(-10, 36, 4), head=(6, -20, 0), clav_l=(0, 10, 0),
               hand_l=(-0.06, 0.44, 1.38), hand_r=(0.20, 0.28, 1.26),
               elbow_l=(-0.7, -0.1, 0.1), fist_l=0.8,
               foot_r=(0.23, -0.17, 0.122), ankle_r=(16, 0, 0))),
        # Recovering the guard, still turned out.
        (14, P(pelvis=(-0.01, 0.03, 0.856), hips=(-2, 12, 0),
               spine=(-10, 18, 2), head=(4, -10, 0),
               hand_l=(-0.16, 0.36, 1.36), hand_r=(0.22, 0.32, 1.29),
               fist_l=0.85, foot_r=(0.23, -0.17, 0.110))),
        (18, P()),
    ],

    # 20 frames, right boot to the midsection, contact on frame 5 (= tick 8
    # of strike_kick.tres). Chamber first: the knee comes up folded before
    # anything extends, which is what separates a kick from a swung leg.
    # The arms do what a kicker's arms do -- out for balance, not pumping.
    "Strike_Kick": [
        (0,  P()),
        # Chamber, and the weight goes fully onto the left foot.
        #
        # `ankle_l` appears from here on and it is not cosmetic. The hips
        # open 6 degrees through this kick (yaw -6 to -12) while the plant
        # foot, given no ankle of its own, simply inherits whatever the shin
        # above it is doing -- so the whole rotation of the pelvis was being
        # taken by the standing knee with the boot nailed to the mat. A
        # kicker pivots on the ball of the plant foot; the heel comes round
        # and the knee stays over the toe. The yaw here tracks the hips'
        # so the two stop fighting, and the boot returns to flat as the leg
        # comes back down under him.
        (3,  P(pelvis=(-0.04, 0.0, 0.848), hips=(0, -6, 4), spine=(-4, 0, -6),
               foot_r=(0.16, 0.34, 0.60), knee_r=(0.3, 1.0, 0.1),
               ankle_l=(0, -4, 0),
               hand_r=(0.28, 0.16, 1.26), hand_l=(-0.24, 0.20, 1.30))),
        # Contact: the knee straightens into the target at body height and
        # the torso leans away as the counterweight.
        (5,  P(pelvis=(-0.06, 0.0, 0.852), hips=(6, -10, 8),
               spine=(14, 0, -14), head=(-10, -6, 0),
               foot_r=(0.10, 0.76, 0.92), knee_r=(0.3, 1.0, 0.1),
               ankle_l=(0, -10, 0),
               hand_r=(0.34, -0.08, 1.20), hand_l=(-0.34, 0.12, 1.30))),
        (8,  P(pelvis=(-0.06, 0.0, 0.850), hips=(7, -12, 8),
               spine=(16, 0, -16), head=(-12, -8, 0),
               foot_r=(0.08, 0.82, 0.86), knee_r=(0.3, 1.0, 0.1),
               ankle_l=(0, -12, 0),
               hand_r=(0.36, -0.12, 1.18), hand_l=(-0.36, 0.10, 1.29))),
        # The leg folds back down under him rather than dropping straight.
        (12, P(pelvis=(-0.04, 0.02, 0.846), spine=(-6, 0, -6),
               foot_r=(0.18, 0.28, 0.34), knee_r=(0.3, 1.0, 0.1),
               ankle_l=(0, -5, 0),
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

    # 12 frames / 0.4s. The CROSS's reaction, and deliberately not the jab's
    # played longer.
    #
    # Two things separate them. It turns the head the OTHER way -- negative
    # yaw throughout, where Hit_React_Head is positive -- because the jab is
    # thrown with the left hand and the cross with the right, so the shots
    # arrive on opposite sides of the jaw and cannot spin a man the same
    # direction. And it goes further: the head reaches 34 degrees of yaw
    # against the jab's 26, the guard drops lower, and the recovery takes the
    # whole back half of the clip rather than snapping shut.
    #
    # Length is 0.4s = 24 ticks, which is strike_cross.tres's sell_frames.
    # Authored at 12 frames so it plays at native 30fps speed and the recipe
    # retimes nothing.
    "Hit_React_Head_Med": [
        (0,  P()),
        # Same 2-frame snap the light reaction uses: combat-animation.md's
        # "snap to impact", not an ease into it.
        (2,  P(pelvis=(-0.03, -0.07, 0.846), hips=(3, -8, 0),
               spine=(12, -18, 5), head=(20, -26, 14),
               hand_r=(0.26, 0.14, 1.14), hand_l=(-0.24, 0.20, 1.16),
               fist_r=0.6, fist_l=0.6)),
        # Deepest, and deeper than the jab's: chin thrown right across, the
        # far shoulder pulled after it, weight off the front foot.
        (5,  P(pelvis=(-0.07, -0.14, 0.830), hips=(7, -13, 0),
               spine=(19, -26, 10), head=(25, -34, 19),
               hand_r=(0.34, 0.08, 1.04), hand_l=(-0.30, 0.12, 1.06),
               fist_r=0.45, fist_l=0.45,
               foot_r=(0.25, -0.30, 0.118), foot_l=(-0.22, 0.10, 0.104))),
        # He is still turned out here -- a cross does not let a man square up
        # again in three frames, and the jab's reaction recovering that fast
        # is most of why the two used to look the same.
        (8,  P(pelvis=(-0.04, -0.08, 0.842), hips=(4, -9, 0),
               spine=(10, -17, 6), head=(16, -22, 11),
               hand_r=(0.28, 0.16, 1.16), hand_l=(-0.26, 0.20, 1.19),
               fist_r=0.55, fist_l=0.55,
               foot_r=(0.25, -0.26, 0.110))),
        (12, P()),
    ],

    # 12 frames / 0.4s. The kick's body reaction: the same fold as
    # Hit_React_Torso, but a boot is not a fist and it arrives across the
    # ribs rather than straight in -- so this adds the twist the punch
    # version has none of, and holds the fold two frames longer.
    "Hit_React_Torso_Med": [
        (0,  P()),
        (2,  P(pelvis=(0.0, -0.05, 0.816), hips=(-4, 6, 0),
               spine=(-30, 10, 4), head=(-18, 8, 0),
               hand_r=(0.12, 0.16, 1.10), hand_l=(-0.10, 0.18, 1.12),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8))),
        # Deepest: hips 10 cm down, ribs turned away from the boot, and both
        # elbows come in over the spot it landed on.
        (5,  P(pelvis=(0.0, -0.10, 0.764), hips=(-12, 10, 0),
               spine=(-40, 16, 7), head=(-25, 13, 0),
               hand_r=(0.09, 0.12, 0.99), hand_l=(-0.07, 0.14, 1.01),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104))),
        (8,  P(pelvis=(0.0, -0.06, 0.806), hips=(-7, 5, 0),
               spine=(-26, 8, 3), head=(-16, 6, 0),
               hand_r=(0.12, 0.18, 1.12), hand_l=(-0.09, 0.20, 1.14),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8))),
        (12, P()),
    ],

    # 17 frames / 0.567s = 34 ticks, strike_kick_heavy.tres's sell_frames.
    #
    # gauntlet/refs/timings.md measures the man struck by an isolated heavy
    # blow as "doubled over from ~230.700s and still doubled at 231.100s" --
    # at least 0.4s, with no citable end frame. The light reaction returns to
    # a fighting guard in 0.333s, which is faster than the reference is still
    # bent double, so a heavy strike selling on it was never going to read.
    #
    # The shape follows from that: he does not recover inside this clip. He
    # folds, he STAYS folded through the middle third, and he is still coming
    # back up when it ends -- the AnimationTree's cross-fade into IDLE
    # finishes the rise, which is what keeps the last pose from popping.
    "Hit_React_Torso_Heavy": [
        (0,  P()),
        (2,  P(pelvis=(0.0, -0.06, 0.806), hips=(-6, 5, 0),
               spine=(-34, 9, 4), head=(-20, 7, 0),
               hand_r=(0.11, 0.14, 1.06), hand_l=(-0.09, 0.16, 1.08),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8))),
        # Deepest, and it is a long way down: the hips drop 0.14 m, the chest
        # comes over the knees and both hands cover the ribs.
        (5,  P(pelvis=(0.0, -0.13, 0.718), hips=(-16, 11, 0),
               spine=(-48, 18, 8), head=(-30, 14, 0),
               hand_r=(0.07, 0.10, 0.92), hand_l=(-0.05, 0.12, 0.94),
               elbow_r=(0.5, -0.35, -0.8), elbow_l=(-0.5, -0.35, -0.8),
               fist_r=0.45, fist_l=0.45,
               foot_r=(0.27, -0.26, 0.104), foot_l=(-0.20, 0.14, 0.104))),
        # Held. A man does not bounce out of this -- he stays there while it
        # goes through him, and only his breathing moves.
        (9,  P(pelvis=(0.0, -0.14, 0.710), hips=(-17, 10, 0),
               spine=(-49, 17, 8), head=(-31, 13, 0),
               hand_r=(0.08, 0.09, 0.90), hand_l=(-0.06, 0.11, 0.92),
               elbow_r=(0.5, -0.35, -0.8), elbow_l=(-0.5, -0.35, -0.8),
               fist_r=0.4, fist_l=0.4,
               foot_r=(0.27, -0.26, 0.104), foot_l=(-0.20, 0.14, 0.104))),
        # Starting to come up, and no further: the clip ends mid-rise on
        # purpose, and the blend to IDLE takes it the rest of the way.
        (13, P(pelvis=(0.0, -0.10, 0.772), hips=(-11, 7, 0),
               spine=(-36, 12, 5), head=(-23, 9, 0),
               hand_r=(0.10, 0.13, 1.00), hand_l=(-0.08, 0.15, 1.02),
               elbow_r=(0.5, -0.4, -0.8), elbow_l=(-0.5, -0.4, -0.8),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104))),
        (17, P(pelvis=(0.0, -0.05, 0.824), hips=(-4, 3, 0),
               spine=(-20, 6, 2), head=(-12, 4, 0),
               hand_r=(0.14, 0.22, 1.16), hand_l=(-0.13, 0.26, 1.20),
               fist_r=0.65, fist_l=0.65)),
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
        (13, S(spine=(-9, 0, 0), head=(11, 0, -4),
               foot_r=(0.19, 0.38, 0.10), foot_l=(-0.14, 0.38, 0.10),
               hand_r=(0.37, -0.24, 0.11), hand_l=(-0.34, -0.24, 0.11))),
        (26, S(spine=(-4, 0, 0), head=(16, 0, 5),
               foot_r=(0.15, 0.41, 0.10), foot_l=(-0.18, 0.34, 0.10))),
        (40, S()),
    ],

    # 63 frames / 2.1s. Prone -> off the mat -> onto a knee -> crouched ->
    # standing. Those beats are kept where the previous version had them,
    # and that is behavioural rather than cosmetic: the input-driven fast
    # rise (GETUP_RISE_FAST_TICKS, 1.14s) plays this same clip and is cut
    # off partway through, so moving a beat changes what a fast getup is.
    "Getup_Rise": [
        (0,  S()),
        # Rolls toward his front and gets a hand on the mat.
        (10, S(pelvis=(0.06, 0.0, 0.21), hips=(-70, -20, 22),
               spine=(-4, -14, 0), head=(10, -10, 0),
               hand_r=(0.30, 0.14, 0.09), hand_l=(-0.30, -0.18, 0.13),
               foot_r=(0.20, 0.34, 0.11), foot_l=(-0.10, 0.32, 0.14),
               knee_r=(0.5, 0.3, 0.9), knee_l=(-0.4, 0.4, 0.8))),
        # On all fours: both hands planted, both knees down.
        (22, dict(pelvis=(0.0, -0.02, 0.47), hips=(58, 0, 0),
                  spine=(18, 0, 0), head=(-26, 0, 0),
                  hand_r=(0.24, 0.42, 0.06), hand_l=(-0.22, 0.44, 0.06),
                  elbow_r=(0.6, -0.4, -0.7), elbow_l=(-0.6, -0.4, -0.7),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.17, -0.22, 0.09), foot_l=(-0.17, -0.20, 0.09),
                  knee_r=(0.3, 0.9, -0.3), knee_l=(-0.3, 0.9, -0.3))),
        # Up onto one knee, lead foot planted flat, hand on that knee.
        (34, dict(pelvis=(0.0, 0.01, 0.575), hips=(16, 0, 0),
                  spine=(26, 0, 0), head=(-20, 0, 0),
                  hand_r=(0.22, 0.32, 0.70), hand_l=(-0.26, 0.18, 0.62),
                  fist_r=0.2, fist_l=0.2,
                  foot_r=(0.19, -0.26, 0.09), foot_l=(-0.19, 0.30, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        # Crouched over both feet, driving up through the legs.
        (46, P(pelvis=(0.0, 0.03, 0.745), hips=(12, 0, 0), spine=(28, 0, 0),
               head=(-14, 0, 0),
               hand_r=(0.24, 0.26, 0.96), hand_l=(-0.22, 0.30, 0.98),
               fist_r=0.4, fist_l=0.4,
               foot_r=(0.23, -0.19, 0.104), foot_l=(-0.20, 0.22, 0.104))),
        # Standing, guard still coming up -- not snapped to the stance.
        (56, P(pelvis=(0.0, 0.02, 0.848), spine=(16, 2, 0), head=(-6, 4, 0),
               hand_r=(0.20, 0.28, 1.18), hand_l=(-0.16, 0.32, 1.22),
               fist_r=0.6, fist_l=0.6)),
        (63, P()),
    ],

    # === finishing ======================================================

    # 18 frames / 0.6s. The cover: down onto both knees, chest across him,
    # both hands pressing his shoulders into the mat, eyes on those
    # shoulders because that is what the referee is counting. Hands are open
    # (fist 0.1) -- a cover presses with palms.
    "Pin_Cover": [
        (0,  P(pelvis=(0.0, 0.08, 0.800), hips=(10, 0, 0), spine=(26, 0, 0),
               head=(-4, 0, 0),
               hand_r=(0.24, 0.44, 0.96), hand_l=(-0.22, 0.46, 0.94),
               fist_r=0.0, fist_l=0.0)),
        # Dropping onto the knees.
        (6,  dict(pelvis=(0.0, 0.15, 0.560), hips=(26, 0, 0),
                  spine=(40, 0, 0), head=(-2, 0, 0),
                  hand_r=(0.25, 0.52, 0.52), hand_l=(-0.23, 0.54, 0.50),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.19, -0.20, 0.09), foot_l=(-0.19, -0.18, 0.09),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
        # Chest low, weight through both arms into his shoulders.
        (12, dict(pelvis=(0.0, 0.19, 0.455), hips=(34, 0, 0),
                  spine=(50, 0, 0), head=(8, 0, 0),
                  hand_r=(0.27, 0.60, 0.25), hand_l=(-0.25, 0.62, 0.23),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.19, -0.22, 0.09), foot_l=(-0.19, -0.20, 0.09),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
        # Settles into the press rather than stopping dead on it.
        (18, dict(pelvis=(0.0, 0.20, 0.440), hips=(36, 0, 0),
                  spine=(53, 0, 0), head=(10, 0, 0),
                  hand_r=(0.28, 0.62, 0.21), hand_l=(-0.26, 0.64, 0.19),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.19, -0.22, 0.09), foot_l=(-0.19, -0.20, 0.09),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
    ],

    # 39 frames / 1.3s. There is no celebration anywhere in the 42 source
    # actions, so this could only ever be authored. Load down, explode up
    # onto the toes with both arms overhead (hands at 1.92 -- the shoulder
    # at 1.441 plus almost the full 0.547 reach), settle off the extreme,
    # one smaller second pump. Terminal state: it holds the last pose.
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
    #
    # CONTACT IS FRAME 9, and the beats either side of it are deliberately
    # lopsided. Frame 9 of 35 over 1.150s is 0.296s, which is the 0.300s
    # gauntlet/refs/timings.md measures from a heavy strike's windup to its
    # contact -- so running_attack_*.tres keep startup_frames 18 and the
    # damage lands on the frame the blow does.
    #
    # It was frame 18 (0.591s), twice the measured windup, and the move data
    # was briefly moved to startup 35 to match it. That fixed the mismatch by
    # giving up the measurement, so the clip was retimed instead: the
    # approach compresses into 9 frames and the follow-through gets the other
    # 26. That is the right shape anyway -- he opens MID-STRIDE, already
    # running, so the anticipation happened before frame 0, and a heavy blow
    # carries more follow-through than windup (blender-animation, "Pro
    # animation principles").
    "Running_Clothesline": [
        (0,  P(pelvis=(0.0, 0.04, 0.858), spine=(24, 4, 0), head=(-14, 0, 0),
               foot_r=(0.15, 0.28, 0.115), foot_l=(-0.15, -0.30, 0.22),
               hand_r=(0.22, -0.06, 1.22), hand_l=(-0.16, 0.34, 1.42))),
        (3,  P(pelvis=(0.0, 0.04, 0.870), spine=(23, 0, 0), head=(-13, 0, 0),
               foot_r=(0.15, -0.14, 0.16), foot_l=(-0.15, 0.14, 0.30),
               hand_r=(0.26, 0.10, 1.32), hand_l=(-0.20, 0.10, 1.28))),
        # The arm goes out and locks -- straight, level, at throat height,
        # and pointed FORWARD where a ringside camera sees it in profile.
        # Aimed across the chest (tried first) it hid behind his own torso
        # from the side and read as a man running with his arms tucked in.
        (6, P(pelvis=(0.0, 0.04, 0.862), spine=(16, -8, 0), head=(-10, -6, 0),
               foot_r=(0.15, 0.26, 0.115), foot_l=(-0.15, -0.26, 0.20),
               hand_r=(0.02, 0.50, 1.44), hand_l=(-0.30, -0.10, 1.24),
               elbow_r=(0.5, -0.6, -0.6), fist_r=0.9)),
        # Contact, frame 9: nothing about the arm changes, the BODY arrives.
        (9, P(pelvis=(0.0, 0.06, 0.852), hips=(4, -20, 0),
               spine=(12, -26, 0), head=(-8, -18, 0),
               foot_r=(0.18, 0.10, 0.104), foot_l=(-0.16, -0.22, 0.14),
               hand_r=(-0.20, 0.46, 1.44), hand_l=(-0.34, -0.16, 1.22),
               elbow_r=(0.4, -0.6, -0.6), fist_r=0.9)),
        # Follow-through: he keeps turning, because he cannot not.
        (17, P(pelvis=(0.0, 0.02, 0.836), hips=(6, -40, 0),
               spine=(10, -44, 0), head=(-6, -30, 0),
               foot_r=(0.20, 0.04, 0.104), foot_l=(-0.22, -0.24, 0.104),
               hand_r=(-0.44, 0.14, 1.40), hand_l=(-0.24, -0.28, 1.20),
               fist_r=0.7)),
        (26, P(pelvis=(0.0, 0.02, 0.848), hips=(4, -22, 0),
               spine=(12, -24, 0), head=(-4, -14, 0),
               foot_r=(0.22, -0.06, 0.104), foot_l=(-0.21, -0.10, 0.104),
               hand_r=(-0.10, 0.10, 1.30), hand_l=(-0.18, -0.06, 1.26))),
        (35, P()),
    ],

    # 35 frames / 1.15s, the second running attack, and the first clip it
    # has ever had.
    #
    # running_attack_double_leg.tres shipped with an empty animation_pair_id
    # and therefore played the clothesline: two moves, two damage spreads,
    # one performance. The recipe it used to have was cut because the mocap
    # bake behind it measured head-below-hips on 59 of 69 frames, and the
    # note left in strike_recipes.gd called it "a missing ASSET, not a bug".
    # This is that asset, authored on the rig like everything else here.
    #
    # It is the opposite shape to the clothesline and that is the point of
    # having both. A clothesline is height -- the arm goes out at throat
    # level and the body arrives behind it. A double leg is DEPTH: the level
    # change is the move, the shoulder goes in under the ribs, and the arms
    # come together behind the thighs. Contact is frame 9, the same frame
    # the clothesline lands on, so both running attacks share a
    # startup_frames and the pair stays tunable as one thing.
    #
    # He finishes on his FEET, driving up out of the finish. That is not a
    # stylistic call: RUNNING_ATTACK exits to IDLE, so an attacker who ended
    # this clip on the mat would stand up instantly the moment it handed off.
    "Running_Double_Leg": [
        # Mid-stride, closing. Same running shape the clothesline opens on.
        (0,  P(pelvis=(0.0, 0.04, 0.858), spine=(24, 4, 0), head=(-14, 0, 0),
               foot_r=(0.15, 0.28, 0.115), foot_l=(-0.15, -0.30, 0.22),
               hand_r=(0.22, -0.06, 1.22), hand_l=(-0.16, 0.34, 1.42))),
        (3,  P(pelvis=(0.0, 0.04, 0.846), spine=(26, 0, 0), head=(-14, 0, 0),
               foot_r=(0.15, -0.14, 0.16), foot_l=(-0.15, 0.14, 0.30),
               hand_r=(0.24, 0.12, 1.28), hand_l=(-0.20, 0.16, 1.30))),
        # The level change. This is the beat the whole move lives or dies
        # on: the hips drop nearly a quarter of a metre, the lead knee goes
        # down toward the mat, and the head stays UP -- a level change with
        # the head down is a man falling over, not a takedown.
        (6, P(pelvis=(0.0, 0.10, 0.628), hips=(14, 0, 0), spine=(30, 0, 0),
               head=(-26, 0, 0),
               hand_r=(0.20, 0.46, 0.80), hand_l=(-0.20, 0.48, 0.78),
               elbow_r=(0.6, -0.2, -0.6), elbow_l=(-0.6, -0.2, -0.6),
               fist_r=0.3, fist_l=0.3,
               foot_r=(0.17, 0.10, 0.104), foot_l=(-0.17, -0.34, 0.20),
               knee_r=(0.3, 1.0, 0.0), knee_l=(-0.3, 0.9, 0.2))),
        # Contact, frame 9: the shoulder arrives in the midsection and the
        # hands close BEHIND the thighs -- the arms come together, which is
        # the difference between a tackle and a shove.
        (9, P(pelvis=(0.0, 0.18, 0.556), hips=(20, 0, 0), spine=(40, 0, 0),
               head=(-34, 0, 0),
               hand_r=(0.13, 0.58, 0.44), hand_l=(-0.13, 0.60, 0.42),
               elbow_r=(0.7, -0.1, -0.5), elbow_l=(-0.7, -0.1, -0.5),
               fist_r=0.7, fist_l=0.7,
               foot_r=(0.17, -0.06, 0.104), foot_l=(-0.17, -0.40, 0.104),
               knee_r=(0.3, 1.0, 0.0), knee_l=(-0.3, 1.0, 0.0))),
        # The drive. He does not stop at contact -- the legs keep coming and
        # the hips carry through the space the other man was standing in.
        (17, P(pelvis=(0.0, 0.30, 0.520), hips=(24, 0, 0), spine=(46, 0, 0),
               head=(-38, 0, 0),
               hand_r=(0.11, 0.52, 0.30), hand_l=(-0.11, 0.54, 0.28),
               elbow_r=(0.7, -0.1, -0.5), elbow_l=(-0.7, -0.1, -0.5),
               fist_r=0.8, fist_l=0.8,
               foot_r=(0.18, -0.34, 0.104), foot_l=(-0.18, -0.12, 0.16),
               knee_r=(0.3, 1.0, 0.0), knee_l=(-0.3, 1.0, 0.1))),
        # Up and off him: the hands let go of the legs and he comes back
        # over his own feet.
        (26, P(pelvis=(0.0, 0.12, 0.736), hips=(10, 0, 0), spine=(18, 0, 0),
               head=(-16, 0, 0),
               hand_r=(0.20, 0.40, 0.92), hand_l=(-0.20, 0.42, 0.90),
               fist_r=0.4, fist_l=0.4,
               foot_r=(0.21, -0.20, 0.104), foot_l=(-0.19, 0.10, 0.104))),
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

    # Signature. He drops to the right knee EARLY (frame 12) so the knee is
    # already there when the other man arrives on it, and arches back
    # through the finish.
    "Backbreaker_Attacker": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(18, 0, 0),
               hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
               fist_r=0.6, fist_l=0.6)),
        # Gathers him in.
        (6,  P(pelvis=(0.0, 0.03, 0.822), hips=(10, 0, 0), spine=(26, 0, 0),
               head=(-10, 0, 0),
               hand_r=(0.22, 0.50, 1.10), hand_l=(-0.20, 0.52, 1.08),
               fist_r=0.5, fist_l=0.5)),
        # The kneel: right knee down, left foot planted flat and forward.
        (12, dict(pelvis=(0.0, 0.02, 0.565), hips=(4, 0, 0), spine=(8, 0, 0),
                  head=(-14, 0, 0),
                  hand_r=(0.06, 0.44, 1.06), hand_l=(-0.28, 0.40, 0.92),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.6, fist_l=0.6,
                  foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        # Drives him down across the knee and arches back over it.
        (18, dict(pelvis=(0.0, 0.0, 0.548), hips=(-10, 0, 0),
                  spine=(-12, 0, 0), head=(-18, 0, 0),
                  hand_r=(0.10, 0.40, 0.86), hand_l=(-0.30, 0.34, 0.74),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        (24, dict(pelvis=(0.0, 0.0, 0.554), hips=(-6, 0, 0), spine=(-6, 0, 0),
                  head=(-14, 0, 0),
                  hand_r=(0.11, 0.42, 0.90), hand_l=(-0.29, 0.36, 0.78),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.7, fist_l=0.7,
                  foot_r=(0.20, -0.26, 0.09), foot_l=(-0.20, 0.28, 0.104),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.2, 1.0, 0.1))),
        # He gets UP off the knee, and this frame is why the clip has it.
        #
        # Without it the table went from a kneel at f24 (pelvis 0.554) to the
        # standing stance at f30 (0.860) -- 0.31 m of pelvis in 0.2s with
        # nothing keyed that could produce it, so the bezier simply floated
        # him up off the mat. He now pushes off the planted left foot with
        # the trailing right still on the canvas, which is what a man
        # standing up out of a kneel actually does.
        (27, dict(pelvis=(0.0, 0.05, 0.700), hips=(2, 0, 0), spine=(2, 0, 0),
                  head=(-8, 0, 0),
                  hand_r=(0.16, 0.44, 1.02), hand_l=(-0.26, 0.40, 0.94),
                  elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
                  fist_r=0.6, fist_l=0.6,
                  foot_r=(0.22, -0.22, 0.104), foot_l=(-0.20, 0.24, 0.104),
                  knee_r=(0.3, 0.9, 0.0), knee_l=(-0.2, 1.0, 0.1))),
        (30, P()),
    ],

    # The victim: gathered, taken off his feet, folded backward over the
    # knee on frame 18, then poured off it onto the mat.
    "Backbreaker_Defender": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(18, 0, 0),
               hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
               fist_r=0.6, fist_l=0.6)),
        (6,  P(pelvis=(0.0, -0.02, 0.830), hips=(8, 0, 0), spine=(22, 0, 0),
               head=(6, 0, 0),
               hand_r=(0.26, 0.40, 1.24), hand_l=(-0.24, 0.42, 1.22),
               fist_r=0.62, fist_l=0.62)),
        # Off his feet and turning: legs leave the mat, arms fly out.
        (12, dict(pelvis=(0.0, -0.05, 1.010), hips=(-22, 0, 0),
                  spine=(-18, 0, 0), head=(-14, 0, 0),
                  hand_r=(0.40, 0.10, 1.40), hand_l=(-0.40, 0.06, 1.36),
                  elbow_r=(0.8, -0.3, -0.3), elbow_l=(-0.8, -0.3, -0.3),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.20, 0.36, 0.62), foot_l=(-0.18, 0.40, 0.66),
                  knee_r=(0.3, 0.8, 0.4), knee_l=(-0.3, 0.8, 0.4))),
        # Spine across the knee: arched backward, arms thrown behind him.
        (18, dict(pelvis=(0.0, -0.09, 0.860), hips=(-52, 0, 0),
                  spine=(-34, 0, 0), head=(-30, 0, 0),
                  hand_r=(0.44, -0.24, 1.06), hand_l=(-0.44, -0.28, 1.02),
                  elbow_r=(0.8, -0.4, 0.2), elbow_l=(-0.8, -0.4, 0.2),
                  fist_r=0.1, fist_l=0.1,
                  foot_r=(0.22, 0.44, 0.36), foot_l=(-0.20, 0.48, 0.40),
                  knee_r=(0.3, 0.9, 0.2), knee_l=(-0.3, 0.9, 0.2))),
        # Hangs there a beat -- the moment the crowd is watching.
        (23, dict(pelvis=(0.0, -0.10, 0.845), hips=(-56, 0, 0),
                  spine=(-32, 0, 0), head=(-28, 0, 0),
                  hand_r=(0.45, -0.28, 1.00), hand_l=(-0.45, -0.32, 0.96),
                  elbow_r=(0.8, -0.4, 0.2), elbow_l=(-0.8, -0.4, 0.2),
                  fist_r=0.1, fist_l=0.1,
                  foot_r=(0.22, 0.46, 0.30), foot_l=(-0.20, 0.50, 0.34),
                  knee_r=(0.3, 0.9, 0.2), knee_l=(-0.3, 0.9, 0.2))),
        # Pours off onto the mat.
        (30, S(pelvis=(0.0, -0.10, 0.220), hips=(-78, 0, 0),
               spine=(-14, 0, 0), head=(-8, 0, 0),
               hand_r=(0.40, -0.30, 0.14), hand_l=(-0.38, -0.32, 0.14),
               foot_r=(0.20, 0.42, 0.11), foot_l=(-0.18, 0.44, 0.11))),
    ],

    # Signature. A standing neckbreaker: he takes the head, wrenches it
    # down and across, and stays on his feet -- deliberately, because a
    # sit-out version would leave him on the mat and the state that follows
    # this expects a man who is standing.
    "Neckbreaker_Attacker": [
        (0,  P()),
        # Reaches across and takes the head.
        (8,  P(pelvis=(0.0, 0.03, 0.848), hips=(4, -10, 0), spine=(6, -14, 0),
               head=(-6, -12, 0),
               hand_r=(-0.10, 0.46, 1.54), hand_l=(-0.26, 0.34, 1.42),
               elbow_r=(0.5, -0.5, -0.7), elbow_l=(-0.4, -0.5, -0.7),
               fist_r=0.62, fist_l=0.62)),
        # The wrench: down and across, hips turning under it.
        (14, P(pelvis=(0.0, 0.02, 0.790), hips=(10, -18, 0),
               spine=(30, -26, 0), head=(8, -18, 0),
               hand_r=(-0.20, 0.42, 1.00), hand_l=(-0.32, 0.30, 0.92),
               elbow_r=(0.5, -0.4, -0.7), elbow_l=(-0.4, -0.4, -0.7),
               fist_r=0.7, fist_l=0.7)),
        # Drives it to the mat.
        (20, P(pelvis=(0.0, 0.04, 0.700), hips=(16, -22, 0),
               spine=(44, -30, 0), head=(14, -20, 0),
               hand_r=(-0.24, 0.44, 0.62), hand_l=(-0.36, 0.32, 0.56),
               elbow_r=(0.5, -0.3, -0.7), elbow_l=(-0.4, -0.3, -0.7),
               fist_r=0.8, fist_l=0.8)),
        # Lets go and comes back up.
        (26, P(pelvis=(0.0, 0.02, 0.802), hips=(8, -12, 0),
               spine=(22, -14, 0), head=(-2, -8, 0),
               hand_r=(-0.04, 0.36, 1.06), hand_l=(-0.24, 0.30, 1.02),
               fist_r=0.6, fist_l=0.6)),
        (30, P()),
    ],

    # The victim: chin pulled up, wrenched backward, dropped flat.
    "Neckbreaker_Defender": [
        (0,  P()),
        # Head caught: chin comes up and his hands go to the arm.
        (8,  P(pelvis=(0.0, -0.02, 0.852), spine=(-8, 0, 0), head=(-24, 0, 0),
               hand_r=(0.16, 0.30, 1.44), hand_l=(-0.10, 0.26, 1.46),
               elbow_r=(0.7, -0.4, -0.5), elbow_l=(-0.7, -0.4, -0.5),
               fist_r=0.62, fist_l=0.62)),
        # Wrenched back: the legs buckle under him.
        (14, P(pelvis=(0.0, -0.06, 0.740), hips=(-26, 0, 0),
               spine=(-30, 0, 0), head=(-34, 0, 0),
               hand_r=(0.20, 0.22, 1.34), hand_l=(-0.14, 0.18, 1.36),
               elbow_r=(0.7, -0.4, -0.4), elbow_l=(-0.7, -0.4, -0.4),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.24, -0.14, 0.104), foot_l=(-0.21, 0.14, 0.104))),
        # Dropped: hips hit first, feet out in front of him.
        (20, dict(pelvis=(0.0, -0.12, 0.360), hips=(-68, 0, 0),
                  spine=(-18, 0, 0), head=(-26, 0, 0),
                  hand_r=(0.36, 0.06, 0.30), hand_l=(-0.34, 0.02, 0.28),
                  elbow_r=(0.7, -0.4, 0.3), elbow_l=(-0.7, -0.4, 0.3),
                  fist_r=0.5, fist_l=0.5,
                  foot_r=(0.20, 0.38, 0.14), foot_l=(-0.18, 0.34, 0.14),
                  knee_r=(0.3, 0.6, 0.7), knee_l=(-0.3, 0.6, 0.7))),
        (26, S(pelvis=(0.0, -0.14, 0.200), hips=(-82, 0, 0),
               spine=(-10, 0, 0), head=(-4, 0, 0),
               foot_r=(0.19, 0.42, 0.11), foot_l=(-0.17, 0.38, 0.11))),
        (30, S()),
    ],
}


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

    # Bezier everywhere. Linear interpolation on organic motion reads as
    # mechanical, and a wrestler moving at a constant rate between poses is
    # the clearest tell that a clip was generated rather than performed.
    for fcurve in action.fcurves:
        for key in fcurve.keyframe_points:
            key.interpolation = "BEZIER"
            key.handle_left_type = "AUTO_CLAMPED"
            key.handle_right_type = "AUTO_CLAMPED"
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
