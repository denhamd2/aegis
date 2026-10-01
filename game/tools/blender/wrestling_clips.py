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


# Roman's entrance posture (gauntlet/refs/entrances.md): upright and square,
# chest out, weight even on both feet, both arms hanging still -- the AEW
# title is round his waist and the ula fala on his chest. It is
# the opposite of READY on purpose -- a man sizing someone up is coiled; the
# Tribal Chief walking to the ring is not, and "no wasted movement" is what
# sells it.
ROMAN_STAND = dict(
    pelvis=(0.0, 0.0, 0.900), hips=(0, 0, 0), spine=(4, 0, 0), head=(2, 0, 0),
    hand_r=(0.25, -0.02, 0.92), hand_l=(-0.25, -0.02, 0.92),
    elbow_r=(0.5, -0.4, -1.0), elbow_l=(-0.5, -0.4, -1.0),
    fist_r=0.45, fist_l=0.45,
    foot_r=(0.16, 0.0, 0.104), foot_l=(-0.16, 0.02, 0.104),
)


# Roman in the ring after the finger (refs/entrances.md [V], R-41 3:42):
# hands on the hips -- on the iliac crests, thumbs back -- elbows out wide,
# chest up, weight square.
ROMAN_HIPS = dict(
    ROMAN_STAND, spine=(4, 0, 0), head=(0, 0, 0),
    hand_r=(0.21, 0.02, 1.02), hand_l=(-0.21, 0.02, 1.02),
    elbow_r=(1.0, -0.5, 0.1), elbow_l=(-1.0, -0.5, 0.1),
    fist_r=0.25, fist_l=0.25,
    foot_r=(0.18, 0.0, 0.104), foot_l=(-0.18, 0.02, 0.104),
)


# Cody's entrance posture (gauntlet/refs/entrances.md): up on the balls of
# his feet, chest high, chin up, arms loose and a little away from the body
# -- a showman waiting for the music, not a man guarding.
CODY_STAND = dict(
    pelvis=(0.0, 0.0, 0.905), hips=(0, 0, 0), spine=(6, 0, 0), head=(6, 0, 0),
    hand_r=(0.29, 0.02, 0.95), hand_l=(-0.29, 0.02, 0.95),
    elbow_r=(0.6, -0.4, -1.0), elbow_l=(-0.6, -0.4, -1.0),
    fist_r=0.4, fist_l=0.4,
    foot_r=(0.17, 0.02, 0.104), foot_l=(-0.17, -0.02, 0.104),
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


# Trapped in a corner (Corner_Slump, Corner_Hit): backed into the buckle,
# which is behind him on the diagonal, weight sagging into the ropes, arms
# hooked over the top rope -- elbows up on it at 1.2 m, forearms hanging
# down behind it -- and his chin on his chest.
CORNER_HANG = dict(
    pelvis=(0.02, -0.17, 0.765), hips=(8, 0, 2), spine=(20, -4, 4), head=(-34, -6, 4),
    hand_r=(0.48, -0.36, 0.96), hand_l=(-0.48, -0.36, 0.96),
    elbow_r=(0.6, -0.4, 0.7), elbow_l=(-0.6, -0.4, 0.7),
    fist_r=0.15, fist_l=0.15,
    foot_r=(0.25, 0.14, 0.104), foot_l=(-0.23, 0.18, 0.104),
)


def C(**over):
    return pose(CORNER_HANG, **over)


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


def _methodical_walk():
    """Roman's walk to the ring, at half his normal pace, looking around.

    0.5 m/s: a 1.6 s cycle (48 frames) of two shorter steps with a long
    double-support -- 28 of the 48 frames on each foot, so both boots are on
    the ground for a third of every step. That overlap is what makes a walk
    read as deliberate rather than as a slow-motion stride: the body settles
    on each foot before it commits to the next.

    Three cycles (144 frames, 4.8 s) so the head can do something the gait
    does not: it holds forward, turns slowly to his left and HOLDS on the
    crowd, back through centre, to his right and holds, and home. Eased key
    to key (smoothstep), the chin a little up throughout, and the upper
    spine follows the head by a quarter -- a man surveying the room turns
    from the chest, not just the neck.
    """
    # Measured off the broadcast (gauntlet/refs/entrances.md, R-41
    # 1:18-2:18, the low steadicam): the arms hang a hand's width OFF his
    # sides -- the lats hold them out -- palms back, barely swinging; chin a
    # little down, eyes up and out; the head turns slowly and holds.
    cycle = _open_hands(_gait(
        frames=48, fps=FPS, speed=0.5,
        contacts={"r": (0, 28), "l": (24, 28)},
        plant_up=0.104, lift_up=0.045,
        foot_x={"r": 0.15, "l": -0.14},
        pelvis_up=0.905, pelvis_dip=0.008,
        hips_yaw=3.0, spine=(0.0, 5.0), head=(-4, 0, 0),
        hand_fwd=(-0.05, 0.02), hand_up=(0.92, 0.93),
        hand_x={"r": 0.31, "l": -0.30}, elbow=None), curl=0.40)
    # (frame, yaw degrees): + is to his left.
    looks = [(0, 0.0), (22, 0.0), (48, 30.0), (70, 30.0), (88, 0.0),
             (100, 0.0), (122, -28.0), (138, -28.0), (144, 0.0)]
    out = []
    for f in range(144 + 1):
        i = 0
        while i + 1 < len(looks) - 1 and looks[i + 1][0] <= f:
            i += 1
        (f0, y0), (f1, y1) = looks[i], looks[i + 1]
        t = min(max((f - f0) / float(f1 - f0), 0.0), 1.0)
        yaw = y0 + (y1 - y0) * t * t * (3.0 - 2.0 * t)
        base = cycle[f % 48][1]
        sp = base["spine"]
        out.append((f, dict(base, head=(-4.0, yaw * 0.75, 0.0),
                            spine=(sp[0], sp[1] + yaw * 0.25, sp[2]))))
    return out


def _crowd_walk():
    """Cody's walk to the ring: 1.2 m/s, working the building.

    A brisker cycle than Roman's (26 frames, two 0.52 m steps, a shorter
    double support) with the arms swinging free; four cycles (104 frames,
    3.5 s) so the upper body can play over it: the head sweeps his left
    crowd, then his right, and on the third cycle the right fist pumps up
    over his head and comes back down -- the "fists up, singing along" of
    the refs -- while the legs keep walking underneath."""
    cycle = _open_hands(_gait(
        frames=26, fps=FPS, speed=1.2,
        contacts={"r": (0, 15), "l": (13, 15)},
        plant_up=0.104, lift_up=0.06,
        foot_x={"r": 0.15, "l": -0.14},
        pelvis_up=0.905, pelvis_dip=0.020,
        hips_yaw=6.0, spine=(0.0, 7.0), head=(6, 0, 0),
        hand_fwd=(-0.14, 0.16), hand_up=(0.90, 0.97),
        hand_x={"r": 0.28, "l": -0.27}, elbow=None), curl=0.5)
    # Broadcast (C-39 WHOA sheet 8-15 s, C-SS 14-30 s): he never looks
    # ahead for long -- the head swings well out to each side of the aisle.
    looks = [(0, 0.0), (8, 40.0), (32, 40.0), (44, -38.0), (68, -38.0),
             (84, 0.0), (104, 0.0)]
    pump = [(0, 0.0), (52, 0.0), (58, 1.0), (72, 1.0), (80, 0.0), (104, 0.0)]

    def curve(keys, f):
        i = 0
        while i + 1 < len(keys) - 1 and keys[i + 1][0] <= f:
            i += 1
        (f0, y0), (f1, y1) = keys[i], keys[i + 1]
        t = min(max((f - f0) / float(f1 - f0), 0.0), 1.0)
        return y0 + (y1 - y0) * t * t * (3.0 - 2.0 * t)
    out = []
    for f in range(104 + 1):
        base = cycle[f % 26][1]
        yaw = curve(looks, f)
        up = curve(pump, f)
        sp = base["spine"]
        pose_f = dict(base, head=(6.0 + 6.0 * up, yaw * 0.75, 0.0),
                      spine=(sp[0], sp[1] + yaw * 0.25, sp[2]))
        if up > 0.0:
            hx, hf, hu = base["hand_r"]
            pose_f["hand_r"] = (hx + (0.22 - hx) * up, hf + (0.08 - hf) * up,
                                hu + (2.02 - hu) * up)
            pose_f["elbow_r"] = (1.0, 0.0, -0.2 + 0.4 * up)
            pose_f["fist_r"] = 0.5 + 0.5 * up
        out.append((f, pose_f))
    return out


## The corner. He climbs the corner by the ring steps from INSIDE the ring,
## facing out over the post, and stands on the middle rope. Ring geometry
## (core/ring/ring_builder.gd): posts at +-3.0, the middle rope 0.75 above the
## mat. The director stands his root CORNER_ROOT_M from the post along the
## diagonal (EntranceDirector.CORNER_ROOT_M); in his frame the post is then
## straight ahead and the two ropes run back from it at 45 degrees, so each
## boot sits on a rope 0.35 m from the post: (+-0.247, 0.62 - 0.247, 0.75).
CORNER_FOOT_UP = 0.75 + 0.104
CORNER_FOOT_FWD = 0.62 - 0.247
CORNER_ON = dict(
    CODY_STAND, pelvis=(0.0, 0.30, 1.62), hips=(-6, 0, 0), spine=(8, 0, 0),
    head=(8, 0, 0),
    hand_r=(0.30, 0.46, 1.14), hand_l=(-0.30, 0.46, 1.14),
    elbow_r=(1.0, -0.4, -0.4), elbow_l=(-1.0, -0.4, -0.4),
    fist_r=0.8, fist_l=0.8,
    foot_r=(0.247, CORNER_FOOT_FWD, CORNER_FOOT_UP),
    foot_l=(-0.247, CORNER_FOOT_FWD, CORNER_FOOT_UP),
    knee_r=(0.3, 1.0, 0.0), knee_l=(-0.3, 1.0, 0.0))


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

def _shifted(base, fwd, up):
    """`base` moved `fwd` forward and `up` upward in world space: every
    travelling field (pelvis, hands, feet) together."""
    out = dict(base)
    for field in _TRAVEL_FIELDS:
        x, y, z = base[field]
        out[field] = (x, y + fwd, z + up)
    return out


## Rope_Step_Through's world keys: fwd from the top tread's centre, up from
## its top. Shared with Rope_Step_Through_Apron, which starts on the apron.
ROPE_STEP_KEYS = [

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

]


def _apron_rope_keys():
    """ROPE_STEP_KEYS from frame 8 on, moved to start on the apron edge."""
    keys = []
    for frame, key in ROPE_STEP_KEYS:
        if frame < 8:
            continue
        keys.append((frame - 8, _shifted(key, -0.28, -0.24)))
    # Frame 0: both boots on the apron edge, not one still on the tread.
    first = dict(keys[0][1])
    first["foot_r"] = (0.14, 0.0, 0.104)
    first["foot_l"] = (-0.13, 0.0, 0.104)
    first["pelvis"] = (0.0, -0.04, 0.86)
    keys[0] = (0, first)
    return keys


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

    # 30 frames / 1.0s, looping. Collar-and-elbow, as the owner asked for it
    # after the first one read as two men flinging their arms at the air:
    # both men LEAN IN from the hips with the hips kept back, so they meet at
    # the chest and shoulders, not the belly; the head turns off to the side
    # so it goes past his, cheek to cheek, rather than butting foreheads. The
    # hands here are only where the grip IK blends FROM -- in the match it puts
    # the right hand behind the other man's neck and the left on his right
    # elbow (WrestlerController._aim_collar_and_elbow), and the models close to
    # lock-up distance (LOCK_UP_GAP). Feet staggered and braced, left foot
    # forward, and the loop is the struggle: drive in, give a little, drive.
    "Tie_Up_Collar": [
        (0,  P(pelvis=(0.0, -0.05, 0.820), hips=(-12, 0, 0), spine=(-24, 0, 0),
               head=(14, 14, 0),
               hand_r=(0.06, 0.40, 1.52), hand_l=(-0.12, 0.36, 1.22),
               elbow_r=(0.8, 0.2, 0.5), elbow_l=(-0.7, -0.5, -0.3),
               fist_r=0.35, fist_l=0.7,
               foot_r=(0.24, -0.30, 0.104), foot_l=(-0.22, 0.18, 0.104))),
        # Driving in: chest over the lead foot, weight on the ball of the
        # back foot.
        (10, P(pelvis=(0.0, -0.01, 0.812), hips=(-14, 0, 0), spine=(-28, 0, 0),
               head=(16, 14, 0),
               hand_r=(0.06, 0.43, 1.50), hand_l=(-0.12, 0.39, 1.20),
               elbow_r=(0.8, 0.2, 0.5), elbow_l=(-0.7, -0.5, -0.3),
               fist_r=0.35, fist_l=0.7,
               foot_r=(0.24, -0.30, 0.104), foot_l=(-0.22, 0.18, 0.104))),
        # Giving ground, not letting go.
        (20, P(pelvis=(0.0, -0.08, 0.826), hips=(-10, 0, 0), spine=(-21, 0, 0),
               head=(12, 12, 0),
               hand_r=(0.06, 0.38, 1.53), hand_l=(-0.12, 0.34, 1.24),
               elbow_r=(0.8, 0.2, 0.5), elbow_l=(-0.7, -0.5, -0.3),
               fist_r=0.35, fist_l=0.7,
               foot_r=(0.24, -0.30, 0.104), foot_l=(-0.22, 0.18, 0.104))),
        (30, P(pelvis=(0.0, -0.05, 0.820), hips=(-12, 0, 0), spine=(-24, 0, 0),
               head=(14, 14, 0),
               hand_r=(0.06, 0.40, 1.52), hand_l=(-0.12, 0.36, 1.22),
               elbow_r=(0.8, 0.2, 0.5), elbow_l=(-0.7, -0.5, -0.3),
               fist_r=0.35, fist_l=0.7,
               foot_r=(0.24, -0.30, 0.104), foot_l=(-0.22, 0.18, 0.104))),
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

    # Cody's strikes (refs/cody_moveset.md) -------------------------------

    # 27 frames / 0.9 s: the BIONIC ELBOW, his father's. The shimmy first --
    # the hips wiggled side to side, fists up at the chest, playing to the
    # building -- then the right elbow cocked high and driven down and
    # forward into the side of the head, lunging so it reaches from the 1.1 m
    # the AI circles at (see Strike_Forearm's note on reach). Contact frame
    # 15 = tick 30, strike_bionic_elbow.tres's startup.
    "Strike_Bionic_Elbow": [
        (0,  P()),
        (4,  P(pelvis=(0.03, 0.0, 0.830), hips=(0, 12, 0), spine=(0, -8, 0),
               head=(4, -6, 0),
               hand_r=(0.20, 0.20, 1.30), hand_l=(-0.20, 0.20, 1.30),
               fist_r=0.9, fist_l=0.9)),
        (8,  P(pelvis=(-0.03, 0.0, 0.830), hips=(0, -12, 0), spine=(0, 8, 0),
               head=(4, 6, 0),
               hand_r=(0.20, 0.20, 1.30), hand_l=(-0.20, 0.20, 1.30),
               fist_r=0.9, fist_l=0.9)),
        # Cocked: the elbow up, the fist by his ear.
        (12, P(pelvis=(0.0, -0.02, 0.870), hips=(0, 10, 0), spine=(6, 14, 0),
               head=(4, -8, 0),
               hand_r=(0.18, -0.02, 1.64), elbow_r=(0.4, 0.5, 0.8),
               hand_l=(-0.22, 0.24, 1.28), fist_r=0.9, fist_l=0.8)),
        # CONTACT: down and through, the body behind it.
        (15, P(pelvis=(-0.02, 0.12, 0.840), hips=(-6, -16, 0), spine=(-14, -26, 0),
               head=(6, 14, 0), clav_r=(0, -18, 0),
               hand_r=(0.00, 0.66, 1.40), elbow_r=(0.5, 1.0, 0.3),
               hand_l=(-0.24, 0.20, 1.20), fist_r=0.95, fist_l=0.8,
               foot_l=(-0.19, 0.36, 0.104))),
        (18, P(pelvis=(-0.02, 0.10, 0.830), hips=(-6, -14, 0), spine=(-16, -22, 0),
               head=(4, 10, 0),
               hand_r=(-0.10, 0.54, 1.14), elbow_r=(0.5, 1.0, 0.0),
               hand_l=(-0.24, 0.20, 1.18), fist_r=0.9, fist_l=0.8,
               foot_l=(-0.19, 0.36, 0.104))),
        (27, P()),
    ],

    # 24 frames / 0.8 s: the DROPDOWN UPPERCUT. He drops low under the man
    # (5) and springs straight up with the right hand into the chin, up on
    # his toes (11: contact = tick 22, strike_dropdown_uppercut.tres).
    "Strike_Dropdown_Uppercut": [
        (0,  P()),
        (5,  P(pelvis=(0.0, 0.04, 0.600), hips=(-30, 0, 0), spine=(-24, 0, 0),
               head=(14, 0, 0),
               # Out in front of the dipped chest: at fwd 0.24-0.26 the
               # forward-pitched torso swallowed both hands (PoseLint).
               hand_r=(0.28, 0.44, 0.80), hand_l=(-0.26, 0.46, 0.82),
               fist_r=0.9, fist_l=0.8,
               foot_r=(0.25, -0.12, 0.104), foot_l=(-0.23, 0.18, 0.104),
               knee_r=(0.3, 1.0, 0.2), knee_l=(-0.3, 1.0, 0.2))),
        (9,  P(pelvis=(0.0, 0.08, 0.800), hips=(-10, -6, 0), spine=(-8, -10, 0),
               head=(8, 0, 0),
               hand_r=(0.10, 0.42, 1.10), hand_l=(-0.24, 0.24, 1.10),
               fist_r=1.0, fist_l=0.8)),
        # CONTACT: up through the chin, on his toes.
        (11, P(pelvis=(0.0, 0.12, 0.930), hips=(4, -12, 0), spine=(8, -18, 0),
               head=(-4, 8, 0), clav_r=(0, -14, 0),
               hand_r=(0.02, 0.62, 1.60), elbow_r=(0.6, -0.3, -0.8),
               hand_l=(-0.26, 0.20, 1.12), fist_r=1.0, fist_l=0.8,
               foot_r=(0.23, -0.17, 0.150), ankle_r=(24, 0, 0),
               foot_l=(-0.19, 0.20, 0.140), ankle_l=(20, 0, 0))),
        (14, P(pelvis=(0.0, 0.10, 0.900), hips=(2, -10, 0), spine=(6, -14, 0),
               head=(-2, 6, 0),
               hand_r=(0.00, 0.48, 1.78), elbow_r=(0.6, -0.3, -0.8),
               hand_l=(-0.26, 0.20, 1.12), fist_r=1.0, fist_l=0.8)),
        (24, P()),
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

    # Ground attacks (gauntlet/refs/animation_gap.md, Phase 4: position).
    # A man down is worked before he is covered, and what he gets depends on
    # where the other man stands: at his legs or body, a stomp; at his head,
    # a fist driven down from one knee.
    #
    # 18 frames / 0.6s: the STOMP. Knee up and eyes on the target, then the
    # boot driven flat down to 0.24 m -- the top of a man lying on the mat,
    # not the canvas -- with the body dropping behind it. Contact frame 7 =
    # tick 14, ground_stomp.tres's startup.
    "Ground_Stomp": [
        (0,  P()),
        (4,  P(pelvis=(0.02, 0.0, 0.870), spine=(-14, 0, 0), head=(-28, 0, 0),
               foot_r=(0.12, 0.30, 0.46), knee_r=(0.2, 1.0, 0.4),
               hand_r=(0.30, 0.20, 1.20), hand_l=(-0.30, 0.24, 1.22))),
        (7,  P(pelvis=(0.02, 0.04, 0.820), spine=(-20, 0, 0), head=(-34, 0, 0),
               foot_r=(0.10, 0.46, 0.24), knee_r=(0.2, 1.0, 0.3),
               hand_r=(0.34, 0.10, 1.10), hand_l=(-0.34, 0.14, 1.12))),
        (10, P(pelvis=(0.02, 0.02, 0.840), spine=(-16, 0, 0), head=(-30, 0, 0),
               foot_r=(0.12, 0.40, 0.30), knee_r=(0.2, 1.0, 0.3))),
        (18, P()),
    ],

    # 22 frames / 0.733s: the FIST DROP, at the head. Down onto the left
    # knee beside him, right hand cocked at the shoulder, then driven down to
    # his head at 0.26 m. Contact frame 11 = tick 22, ground_fist.tres's.
    "Ground_Fist": [
        (0,  P()),
        # A step, not a slide: the right foot lifts to go forward into the
        # kneel. Sliding it along the mat between the stance and the kneel
        # drove its ball 7 cm into the canvas (PoseLint below_mat).
        (3,  P(pelvis=(0.0, 0.03, 0.780), spine=(-18, 0, 0), head=(-20, 0, 0),
               foot_r=(0.19, 0.10, 0.20), knee_r=(0.2, 1.0, 0.3), ankle_r=(-10, 0, 0),
               hand_r=(0.24, 0.20, 1.10))),
        (7,  P(pelvis=(0.0, 0.04, 0.520), hips=(-6, 0, 0), spine=(-40, 0, 0),
               head=(-36, 0, 0),
               foot_r=(0.16, 0.34, 0.104), knee_r=(0.2, 1.0, 0.2),
               foot_l=(-0.15, -0.40, 0.13), knee_l=(-0.2, 1.0, -0.6),
               ankle_l=(40, 0, 0),
               hand_r=(0.22, 0.12, 1.00), hand_l=(-0.20, 0.36, 0.60))),
        (11, P(pelvis=(0.0, 0.08, 0.450), hips=(-8, 0, 0), spine=(-55, -10, 0),
               head=(-40, 0, 0), clav_r=(0, -12, 0),
               foot_r=(0.16, 0.34, 0.104), knee_r=(0.2, 1.0, 0.2),
               foot_l=(-0.15, -0.40, 0.13), knee_l=(-0.2, 1.0, -0.6),
               ankle_l=(40, 0, 0),
               hand_r=(0.04, 0.58, 0.26), hand_l=(-0.22, 0.34, 0.58))),
        (14, P(pelvis=(0.0, 0.06, 0.480), hips=(-6, 0, 0), spine=(-48, -4, 0),
               head=(-38, 0, 0),
               foot_r=(0.16, 0.34, 0.104), knee_r=(0.2, 1.0, 0.2),
               foot_l=(-0.15, -0.40, 0.13), knee_l=(-0.2, 1.0, -0.6),
               ankle_l=(40, 0, 0),
               hand_r=(0.14, 0.40, 0.60), hand_l=(-0.20, 0.36, 0.60))),
        # And a step back out of it.
        (18, P(pelvis=(0.0, 0.03, 0.760), spine=(-20, 0, 0), head=(-20, 0, 0),
               foot_r=(0.19, 0.08, 0.20), knee_r=(0.2, 1.0, 0.3), ankle_r=(-10, 0, 0),
               hand_r=(0.24, 0.26, 1.10))),
        (22, P()),
    ],

    # 20 frames / 0.667s: the REVERSAL (gauntlet/refs/animation_gap.md,
    # Phase 4). The old counters were cut because they did not read -- a
    # strike simply vanished. This one is two beats the eye cannot miss: the
    # lead forearm comes up in front of the face and sweeps the punch off
    # line to his left (frames 3-6), and the rear hand comes straight back
    # down the gap it opened (frame 9) -- the cross's own measured contact
    # frame (Strike_Forearm, frame 6), so it reaches from the 1.1 m the AI
    # circles at. Counter contact frame 9 = tick 18, strike_parry's hit.
    "Parry_Counter": [
        (0,  P()),
        # Forearm up, vertical in front of the face; the left shoulder turns
        # into the punch to meet it, chin down behind it.
        (3,  P(pelvis=(0.01, 0.0, 0.850), hips=(0, 6, 0), spine=(-12, 14, 0),
               head=(10, 4, 0),
               hand_l=(-0.02, 0.36, 1.52), hand_r=(0.22, 0.26, 1.30))),
        # The sweep: the forearm carries the punch out past his left ear, and
        # the right fist is loaded at the chin.
        (6,  P(pelvis=(0.02, -0.01, 0.846), hips=(0, 10, 0), spine=(-12, 18, 0),
               head=(8, 6, 0),
               hand_l=(-0.34, 0.40, 1.44), hand_r=(0.20, 0.22, 1.32))),
        # The counter: the cross's contact pose.
        (9,  P(pelvis=(-0.02, 0.07, 0.866), hips=(-4, -15, 0),
               spine=(-10, -30, 0), head=(8, 18, 0), clav_r=(0, -20, 0),
               hand_r=(-0.02, 0.68, 1.40), hand_l=(-0.26, 0.30, 1.34),
               foot_r=(0.23, -0.17, 0.125), ankle_r=(22, 0, 0))),
        (12, P(pelvis=(-0.03, 0.05, 0.862), hips=(-4, -13, 0),
               spine=(-10, -24, 0), head=(6, 12, 0), clav_r=(0, -12, 0),
               hand_r=(-0.16, 0.56, 1.36), hand_l=(-0.24, 0.26, 1.26),
               foot_r=(0.23, -0.17, 0.120), ankle_r=(18, 0, 0))),
        (20, P()),
    ],

    # The corner (gauntlet/refs/animation_gap.md, Phase 4: position). A man
    # knocked back into a corner does not stagger free: the turnbuckle stops
    # him, and he is trapped against it with his arms hooked over the top
    # rope while the other man works him over. He faces OUT of the corner,
    # which is behind him on the diagonal; the two top ropes run forward
    # from it at 45 degrees, so at 0.6 m either side of him they pass about
    # 0.1 m behind his shoulders at 1.2 m -- that is where the hands go.
    #
    # 45 frames / 1.5s: the SLUMP. Driven back into the buckle (frame 3):
    # the whiplash throws the head back and the arms up and over the ropes.
    # The head comes forward off the rebound (7), then he hangs there,
    # breathing, chin down, weight in the ropes (12-38), and gathers himself
    # to come out (45), which is where the stance picks him up.
    "Corner_Slump": [
        (0,  P()),
        (3,  C(pelvis=(0.0, -0.18, 0.820), hips=(10, 0, 0), spine=(28, 0, 0),
               head=(30, 0, 0), hand_r=(0.50, -0.34, 1.04), hand_l=(-0.50, -0.34, 1.04),
               foot_r=(0.22, -0.02, 0.104), foot_l=(-0.20, 0.08, 0.104))),
        (7,  C(spine=(16, 0, 0), head=(-20, 0, 0), pelvis=(0.0, -0.16, 0.770))),
        (12, C()),
        # Breathing: the chest lifts and the head with it, twice.
        (22, C(pelvis=(0.02, -0.16, 0.760), spine=(22, -2, 4), head=(-28, -4, 4))),
        (30, C(head=(-38, -8, 4))),
        (38, C(pelvis=(0.02, -0.16, 0.760), spine=(21, -2, 3), head=(-30, -4, 2))),
        # Pushing off the ropes: hands come off, weight forward over the feet.
        (45, P(pelvis=(0.0, -0.04, 0.830), hips=(0, 0, 0), spine=(0, 0, 0),
               head=(-8, 0, 0),
               hand_r=(0.34, 0.16, 1.08), hand_l=(-0.32, 0.18, 1.10),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.24, 0.02, 0.104), foot_l=(-0.20, 0.14, 0.104))),
    ],

    # 30 frames / 1.0s: HIT IN THE CORNER. From the hang, the blow drives
    # his back into the buckle again -- head and chest thrown back, the
    # arms jolting up on the rope (frame 2) -- the head whips forward off it
    # (5), and he sags back into the hang (12-30). It starts and ends on the
    # slump's hang pose so a string of them runs together.
    "Corner_Hit": [
        (0,  C()),
        (2,  C(pelvis=(0.0, -0.21, 0.800), hips=(12, 0, 0), spine=(32, 0, 0),
               head=(32, 0, 0), hand_r=(0.50, -0.34, 1.06), hand_l=(-0.50, -0.34, 1.06))),
        (5,  C(spine=(14, 0, 0), head=(-40, 0, 0))),
        (12, C(pelvis=(0.02, -0.17, 0.755))),
        (30, C()),
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
               # Hands and feet higher than they rest: the clip is blended
               # in joint space between keys, and from these the blend swept
               # a foot 12 cm and a hand 10 cm under the mat (PoseLint).
               hand_r=(0.10, 0.20, 0.30), hand_l=(0.36, 0.10, 0.16),
               elbow_r=(0.4, 0.2, 0.8), elbow_l=(0.7, 0.3, -0.3),
               foot_r=(0.02, -0.46, 0.24), foot_l=(0.16, -0.44, 0.18),
               ankle_r=(30, 0, 0), ankle_l=(30, 0, 0),
               knee_r=(0.6, 0.2, 0.6), knee_l=(0.8, 0.0, 0.4))),
        # Rolls toward his front and gets a hand on the mat.
        (10, S(pelvis=(0.06, 0.0, 0.21), hips=(-70, -20, 22),
               spine=(-4, -14, 0), head=(10, -10, 0),
               hand_r=(0.30, 0.14, 0.22), hand_l=(-0.30, -0.18, 0.16),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.20, 0.34, 0.15), foot_l=(-0.10, 0.32, 0.16),
               ankle_r=(30, 0, 0), ankle_l=(30, 0, 0),
               knee_r=(0.5, 0.3, 0.9), knee_l=(-0.4, 0.4, 0.8))),
        # Knees drawn up under him, feet off the mat: a breakdown only, the
        # beats either side stay put. Without it the feet travelled from in
        # front to behind him through the canvas (0.17 m deep).
        # Solved, midway between 10 and 16: blended in joint space, the
        # right arm swung down through an arc and put the hand at 5 cm with
        # the fingers 9 cm into the mat at frame 13 (PoseLint; traced frame
        # by frame). The hand is held at 20 cm here.
        (13, dict(pelvis=(0.045, -0.005, 0.275), hips=(-67, -15, 16),
                  spine=(-7, -10, 0), head=(13, -7, 0),
                  hand_r=(0.28, 0.22, 0.20), hand_l=(-0.28, 0.01, 0.16),
                  elbow_r=(0.6, -0.4, -0.7), elbow_l=(-0.6, -0.4, -0.7),
                  fist_r=0.65, fist_l=0.65,
                  foot_r=(0.19, 0.18, 0.18), foot_l=(-0.13, 0.16, 0.19),
                  ankle_r=(30, 0, 0), ankle_l=(30, 0, 0),
                  knee_r=(0.4, 0.6, 0.4), knee_l=(-0.35, 0.65, 0.35), free_feet=True)),
        (16, dict(pelvis=(0.03, -0.01, 0.34), hips=(-64, -10, 10),
                  spine=(-10, -6, 0), head=(16, -4, 0),
                  # Posted on the knuckles at 0.12, not flat at 0.07: open
                  # and that low, his fingers went 9 cm into the mat on the
                  # way in (PoseLint).
                  hand_r=(0.26, 0.30, 0.12), hand_l=(-0.26, 0.20, 0.12),
                  elbow_r=(0.6, -0.4, -0.7), elbow_l=(-0.6, -0.4, -0.7),
                  fist_r=0.7, fist_l=0.7,
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
                  ankle_r=(30, 0, 0), ankle_l=(30, 0, 0),
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
                  foot_r=(0.19, -0.24, 0.11), foot_l=(-0.19, -0.22, 0.11),
                  ankle_r=(20, 0, 0), ankle_l=(20, 0, 0),
                  knee_r=(0.3, 0.9, -0.2), knee_l=(-0.3, 0.9, -0.2))),
        # Falling across: hips out behind, chest coming down onto his.
        # Solved between 5 and 11 rather than blended: the joint-space blend
        # swung the ball of the foot 10 cm through the canvas as the legs
        # went back (PoseLint).
        (8,  dict(pelvis=(0.0, -0.04, 0.450), hips=(-48, 0, 0),
                  spine=(-19, 0, 0), head=(4, 10, 0),
                  hand_r=(0.21, 0.78, 0.28), hand_l=(-0.22, 0.68, 0.26),
                  elbow_r=(0.9, 0.0, 0.3), elbow_l=(-0.9, 0.0, 0.3),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.18, -0.46, 0.12), foot_l=(-0.18, -0.42, 0.12),
                  ankle_r=(30, 0, 0), ankle_l=(30, 0, 0),
                  knee_r=(0.25, 0.4, -0.6), knee_l=(-0.25, 0.4, -0.6))),
        (11, dict(pelvis=(0.0, -0.10, 0.360), hips=(-66, 0, 0),
                  spine=(-8, 0, 0), head=(14, 20, 0),
                  hand_r=(0.20, 0.92, 0.16), hand_l=(-0.30, 0.78, 0.14),
                  elbow_r=(0.9, 0.0, 0.3), elbow_l=(-0.9, 0.0, 0.3),
                  fist_r=0.0, fist_l=0.0,
                  # Further back and a touch higher: at -0.62 the hip-to-foot
                  # span was short of the leg, the knee dropped toward its
                  # mat-ward pole and went 5.5 cm INTO the canvas (PoseLint).
                  foot_r=(0.17, -0.72, 0.11), foot_l=(-0.17, -0.68, 0.11),
                  ankle_r=(40, 0, 0), ankle_l=(40, 0, 0),
                  knee_r=(0.2, 0.0, -1.0), knee_l=(-0.2, 0.0, -1.0))),
        # Settled: lying across him, legs sprawled for base, toes dug in,
        # head up and turned so the face reads from the hard camera.
        (18, dict(pelvis=(0.0, -0.16, 0.300), hips=(-78, 0, 0),
                  spine=(-4, 0, 0), head=(18, 28, 0),
                  hand_r=(0.18, 0.98, 0.10), hand_l=(-0.32, 0.84, 0.10),
                  elbow_r=(0.9, 0.0, 0.3), elbow_l=(-0.9, 0.0, 0.3),
                  fist_r=0.0, fist_l=0.0,
                  foot_r=(0.20, -0.95, 0.11), foot_l=(-0.20, -0.91, 0.11),
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
    "Rope_Step_Through": _world_clip(48, (0.90, 0.24), ROPE_STEP_KEYS),

    # 40 frames / 1.33s: the same step through the ropes, from the APRON --
    # where the diagonal steps leave him (ring_builder.gd "Steel steps"). The
    # keys are Rope_Step_Through's from the moment he is up on the apron
    # (its frame 8), moved back 0.28 and down 0.24 so they start on the
    # apron edge, with both feet already on it. The root travels (0.62, 0):
    # EntranceDirector.APRON_ROPE_TO.
    "Rope_Step_Through_Apron": _world_clip(40, (0.62, 0.0), _apron_rope_keys()),

    # 30 frames / 1.0s: off the top tread of the diagonal steps and up onto
    # the apron beside the post: the right boot up (14), the left follows
    # (22), standing on the apron (30), 1.0 along and 0.24 up. The root
    # travels (1.0, 0.24): EntranceDirector.APRON_STEP_TO.
    "Apron_Step": _world_clip(30, (1.0, 0.24), [
        (0,  _shifted(STANCE, 0.0, 0.0)),
        (8,  dict(_shifted(STANCE, 0.10, 0.0), foot_r=(0.23, 0.30, 0.40),
                  foot_l=(-0.19, 0.18, 0.104))),
        (14, dict(_shifted(STANCE, 0.34, 0.08), foot_r=(0.23, 0.50, 0.344),
                  foot_l=(-0.19, 0.18, 0.104))),
        (22, dict(_shifted(STANCE, 0.66, 0.20), foot_r=(0.23, 0.50, 0.344),
                  foot_l=(-0.19, 0.80, 0.50))),
        (30, _shifted(STANCE, 1.0, 0.24)),
    ]),

    # === Roman's entrance (gauntlet/refs/entrances.md) =====================
    #
    # Every one of these is still on purpose. The research's one unanimous
    # line about the entrance is its pace: slow, eyes front, no wasted
    # movement. So the arms barely swing, the head does not move, and the
    # raises are held long enough to read on a wide shot.

    # 30 frames / 1.0s, looping: the slow walk, 1.0 m/s -- EntranceDirector's
    # Roman pace, against the 1.6 m/s the other men walk at. Contact 15 of 30
    # per foot, so one is always down; the half stride that buys is 0.25 m.
    "Walk_Slow": _open_hands(_gait(
        frames=30, fps=FPS, speed=1.0,
        contacts={"r": (0, 15), "l": (15, 15)},
        plant_up=0.104, lift_up=0.06,
        foot_x={"r": 0.15, "l": -0.14},
        pelvis_up=0.905, pelvis_dip=0.010,
        hips_yaw=4.0, spine=(0.0, 4.0), head=(2, 0, 0),
        hand_fwd=(-0.06, 0.06), hand_up=(0.90, 0.92),
        hand_x={"r": 0.25, "l": -0.24}, elbow=None), curl=0.45),

    # 144 frames / 4.8s, looping: his walk to the ring at 0.5 m/s, surveying
    # the building as he goes (_methodical_walk).
    "Walk_Slow_Look": _methodical_walk(),

    # 60 frames / 2.0s, looping: standing on his mark. He breathes and that
    # is all -- the camera is supposed to wait on him, not watch him fidget.
    "Roman_Stand": [
        (0,  ROMAN_STAND),
        (30, pose(ROMAN_STAND, pelvis=(0.0, 0.0, 0.906), spine=(5, 0, 0))),
        (60, ROMAN_STAND),
    ],

    # 45 frames / 1.5s: the title off his waist. Chin down to the buckle,
    # both hands to it (frame 10), the belt opened (frame 20), and the left
    # hand brings it away to his side (32) -- the director hands the prop
    # from his waist to that hand on frame 22 (EntranceDirector.
    # TITLE_UNBUCKLED_AT) -- then back to his stance, belt in hand.
    "Title_Unbuckle": [
        (0,  ROMAN_STAND),
        (10, pose(ROMAN_STAND, spine=(-8, 0, 0), head=(-16, 0, 0),
                  hand_r=(0.07, 0.20, 1.03), hand_l=(-0.07, 0.20, 1.03),
                  elbow_r=(1.0, -0.4, -0.6), elbow_l=(-1.0, -0.4, -0.6),
                  fist_r=0.7, fist_l=0.7)),
        (20, pose(ROMAN_STAND, spine=(-6, 0, 0), head=(-12, 0, 0),
                  hand_r=(0.16, 0.20, 1.03), hand_l=(-0.16, 0.20, 1.03),
                  elbow_r=(1.0, -0.4, -0.6), elbow_l=(-1.0, -0.4, -0.6),
                  fist_r=0.8, fist_l=0.9)),
        (32, pose(ROMAN_STAND, spine=(0, 0, 0), head=(0, 0, 0),
                  hand_l=(-0.26, 0.10, 1.00), elbow_l=(-0.7, -0.4, -0.8),
                  fist_l=0.95)),
        (45, pose(ROMAN_STAND, fist_l=0.95)),
    ],

    # 60 frames / 2.0s: the title overhead. The belt is already in his left
    # hand, so it goes straight up from the shoulder, arm locked, and HOLDS
    # (frames 16-44) -- the beat the pyro is cued against is the finger that
    # follows, but this one is held long enough to read on its own.
    "Title_Raise": [
        (0,  ROMAN_STAND),
        (10, pose(ROMAN_STAND, spine=(6, 0, 0), head=(4, 0, 0),
                  hand_l=(-0.20, 0.10, 1.70), elbow_l=(-1.0, 0.0, 0.2),
                  fist_l=1.0)),
        (16, pose(ROMAN_STAND, spine=(8, 0, 0), head=(10, 0, 0),
                  hand_l=(-0.22, 0.06, 1.98), elbow_l=(-1.0, 0.0, 0.3),
                  fist_l=1.0)),
        (44, pose(ROMAN_STAND, spine=(8, 0, 0), head=(10, 0, 0),
                  hand_l=(-0.22, 0.07, 1.97), elbow_l=(-1.0, 0.0, 0.3),
                  fist_l=1.0)),
        (54, pose(ROMAN_STAND, spine=(5, 0, 0), head=(4, 0, 0),
                  hand_l=(-0.18, 0.12, 1.55), elbow_l=(-1.0, -0.1, -0.2),
                  fist_l=0.9)),
        (60, ROMAN_STAND),
    ],

    # 60 frames / 2.0s: the finger. Right hand up, index finger to the sky
    # (`point_r`, rig_pose.py), chin lifted, eyes up with it. The pyro is cued
    # on frame 14 -- EntranceDirector.FINGER_PYRO_AT -- when the arm arrives.
    "Finger_Raise": [
        (0,  ROMAN_STAND),
        (8,  pose(ROMAN_STAND, spine=(5, 0, 0), head=(6, 0, 0),
                  hand_r=(0.20, 0.14, 1.62), elbow_r=(1.0, -0.2, -0.2),
                  fist_r=0.9, point_r=True)),
        (14, pose(ROMAN_STAND, spine=(7, 0, 0), head=(14, 0, 0),
                  hand_r=(0.20, 0.10, 1.97), elbow_r=(1.0, 0.0, 0.2),
                  fist_r=0.95, point_r=True)),
        (46, pose(ROMAN_STAND, spine=(7, 0, 0), head=(14, 0, 0),
                  hand_r=(0.20, 0.10, 1.96), elbow_r=(1.0, 0.0, 0.2),
                  fist_r=0.95, point_r=True)),
        (54, pose(ROMAN_STAND, spine=(5, 0, 0), head=(4, 0, 0),
                  hand_r=(0.24, 0.04, 1.20), elbow_r=(0.6, -0.4, -0.8),
                  fist_r=0.6)),
        (60, ROMAN_STAND),
    ],

    # 45 frames / 1.5s: the ula fala off -- both hands to it, up over the
    # head, and out in front of him to hand it off. The title has already
    # gone by now (the director puts it down before this), so both hands
    # are free. The necklace prop moves to his right hand at frame 18
    # (EntranceDirector.ULA_FALA_LIFT_AT) and is gone when the clip ends.
    "Ula_Fala_Off": [
        (0,  pose(ROMAN_STAND, hand_l=(-0.25, -0.02, 0.92),
                  elbow_l=(-0.5, -0.4, -1.0), fist_l=0.45)),
        (10, pose(ROMAN_STAND, head=(-6, 0, 0),
                  hand_r=(0.12, 0.16, 1.36), hand_l=(-0.12, 0.16, 1.36),
                  elbow_r=(1.0, -0.4, -0.6), elbow_l=(-1.0, -0.4, -0.6),
                  fist_r=0.6, fist_l=0.6)),
        (20, pose(ROMAN_STAND, head=(-4, 0, 0),
                  hand_r=(0.14, 0.06, 1.84), hand_l=(-0.14, 0.06, 1.84),
                  elbow_r=(1.0, 0.0, 0.2), elbow_l=(-1.0, 0.0, 0.2),
                  fist_r=0.7, fist_l=0.7)),
        (32, pose(ROMAN_STAND, spine=(-4, 0, 0),
                  hand_r=(0.12, 0.50, 1.44), hand_l=(-0.20, 0.10, 1.10),
                  elbow_r=(0.8, -0.2, -0.6), elbow_l=(-0.6, -0.4, -1.0),
                  fist_r=0.7, fist_l=0.45)),
        (45, pose(ROMAN_STAND, hand_l=(-0.25, -0.02, 0.92),
                  elbow_l=(-0.5, -0.4, -1.0), fist_l=0.45)),
    ],


    # === Roman, OTC, measured off the broadcast (refs/entrances.md [V]) ====

    # 30 frames / 1.0s: the finger, raised and HELD -- the clip ends on the
    # held pose, and a non-looping clip holds its last frame, so the director
    # keeps it up as long as the beat runs (R-41: 40 s to 58 s, eighteen
    # seconds). Right arm straight up over the shoulder, fist closed round
    # the index finger, chin LEVEL -- he looks out at the building, not up
    # at the finger. Arrives on frame 14 (FINGER_PYRO_AT): the pyro.
    "Finger_Hold": [
        (0,  ROMAN_STAND),
        (8,  pose(ROMAN_STAND, spine=(4, 0, 0), head=(2, 0, 0),
                  hand_r=(0.21, 0.10, 1.60), elbow_r=(1.0, -0.2, -0.2),
                  fist_r=0.95, point_r=True)),
        (14, pose(ROMAN_STAND, spine=(5, 0, 0), head=(3, 0, 0),
                  hand_r=(0.19, 0.06, 2.00), elbow_r=(1.0, 0.0, 0.2),
                  fist_r=0.95, point_r=True)),
        (30, pose(ROMAN_STAND, spine=(5, 0, 0), head=(3, 0, 0),
                  hand_r=(0.19, 0.06, 2.00), elbow_r=(1.0, 0.0, 0.2),
                  fist_r=0.95, point_r=True)),
    ],

    # 90 frames / 3.0s: at ringside, before the steps (R-41 2:42-3:04): the
    # chin comes down to his chest and stays there -- eyes shut, a private
    # moment in a building of 60,000 -- then the head comes up slowly.
    "Head_Bow": [
        (0,  ROMAN_STAND),
        (18, pose(ROMAN_STAND, spine=(-9, 0, 0), head=(-44, 0, 0),
                  pelvis=(0.0, 0.0, 0.897))),
        (66, pose(ROMAN_STAND, spine=(-10, 0, 0), head=(-46, 0, 0),
                  pelvis=(0.0, 0.0, 0.895))),
        (90, ROMAN_STAND),
    ],

    # 120 frames / 4.0s, looping: in the ring after the finger (R-41
    # 3:42-3:54): hands on the hips, elbows out, square to the hard camera,
    # and a slow look across the ring and back.
    "Hands_Hips": [
        (0,   ROMAN_HIPS),
        (40,  pose(ROMAN_HIPS, head=(0, 14, 0), spine=(4, 4, 0))),
        (70,  pose(ROMAN_HIPS, head=(0, 14, 0), spine=(4, 4, 0))),
        (100, pose(ROMAN_HIPS, head=(0, -10, 0), spine=(4, -3, 0))),
        (120, ROMAN_HIPS),
    ],

    # === Cody (gauntlet/refs/entrances.md, Cody's beat sheet) =============

    # 60 frames / 2.0s, looping: waiting on his mark, bouncing on his toes.
    "Cody_Stand": [
        (0,  CODY_STAND),
        (15, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.89), spine=(7, 0, 0))),
        (30, CODY_STAND),
        (45, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.89), spine=(7, 0, 0))),
        (60, CODY_STAND),
    ],

    # 150 frames / 5.0s: THE WHOA, cut to his music (entrance_director.gd,
    # CODY_WHOA): a beat of anticipation, the arms thrown wide and up on
    # frame 11 -- the chant's first sung WHOA -- and HELD through the pyro
    # (frame 71, where his chest lifts to it) until the fists drive down on
    # the next phrase. A held pose is never a frozen one: he breathes, the
    # head goes back to drink it in, the hands drift. It drops to the stand on
    # its last frames, which is the cock Fists_Down punches out of.
    "Whoa_Arms": [
        (0,  CODY_STAND),
        (5,  pose(CODY_STAND, pelvis=(0.0, 0.0, 0.86), spine=(-6, 0, 0),
                  head=(-4, 0, 0),
                  hand_r=(0.18, 0.18, 1.08), hand_l=(-0.18, 0.18, 1.08),
                  elbow_r=(1.0, -0.4, -0.6), elbow_l=(-1.0, -0.4, -0.6),
                  fist_r=0.8, fist_l=0.8)),
        # Thrown: a touch past the hold, and it settles back.
        (11, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.92), spine=(16, 0, 0),
                  head=(22, 0, 0),
                  hand_r=(0.84, 0.06, 1.77), hand_l=(-0.84, 0.06, 1.77),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.15, fist_l=0.15)),
        (17, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.91), spine=(14, 0, 0),
                  head=(22, 0, 0),
                  hand_r=(0.82, 0.06, 1.72), hand_l=(-0.82, 0.06, 1.72),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        # Breathing it in, head going back.
        (44, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.905), spine=(17, 0, 0),
                  head=(28, 0, 0),
                  hand_r=(0.83, 0.04, 1.75), hand_l=(-0.83, 0.04, 1.75),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        (62, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.905), spine=(14, 0, 0),
                  head=(24, 0, 0),
                  hand_r=(0.82, 0.06, 1.72), hand_l=(-0.82, 0.06, 1.72),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        # The pyro: the chest lifts to it.
        (72, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.93), spine=(20, 0, 0),
                  head=(30, 0, 0),
                  hand_r=(0.85, 0.04, 1.80), hand_l=(-0.85, 0.04, 1.80),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.1, fist_l=0.1)),
        (96, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.91), spine=(16, 0, 0),
                  head=(24, 0, 4),
                  hand_r=(0.83, 0.05, 1.74), hand_l=(-0.83, 0.05, 1.74),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        (130, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.91), spine=(15, 0, 0),
                   head=(20, 0, -3),
                   hand_r=(0.82, 0.06, 1.72), hand_l=(-0.82, 0.06, 1.72),
                   elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                   fist_r=0.3, fist_l=0.3)),
        (141, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.90), spine=(12, 0, 0),
                   head=(14, 0, 0),
                   hand_r=(0.78, 0.08, 1.66), hand_l=(-0.78, 0.08, 1.66),
                   elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                   fist_r=0.6, fist_l=0.6)),
        (150, CODY_STAND),
    ],

    # 30 frames / 1.0s: both fists up, the second WHOA.
    "Fists_Up": [
        (0,  CODY_STAND),
        (8,  pose(CODY_STAND, spine=(10, 0, 0), head=(14, 0, 0),
                  hand_r=(0.32, 0.06, 1.98), hand_l=(-0.32, 0.06, 1.98),
                  elbow_r=(1.0, 0.0, 0.0), elbow_l=(-1.0, 0.0, 0.0),
                  fist_r=1.0, fist_l=1.0)),
        (30, pose(CODY_STAND, spine=(10, 0, 0), head=(14, 0, 0),
                  hand_r=(0.33, 0.06, 1.99), hand_l=(-0.33, 0.06, 1.99),
                  elbow_r=(1.0, 0.0, 0.0), elbow_l=(-1.0, 0.0, 0.0),
                  fist_r=1.0, fist_l=1.0)),
    ],

    # 21 frames / 0.7s: the load into the drop -- down into a crouch, hands
    # on his knees, head up at the crowd.
    "Whoa_Crouch": [
        (0,  CODY_STAND),
        (12, pose(CODY_STAND, pelvis=(0.0, -0.06, 0.64), hips=(-30, 0, 0),
                  spine=(-18, 0, 0), head=(20, 0, 0),
                  hand_r=(0.20, 0.30, 0.64), hand_l=(-0.20, 0.30, 0.64),
                  elbow_r=(1.0, -0.2, -0.4), elbow_l=(-1.0, -0.2, -0.4),
                  foot_r=(0.24, 0.02, 0.104), foot_l=(-0.24, -0.02, 0.104),
                  fist_r=0.6, fist_l=0.6)),
        (21, pose(CODY_STAND, pelvis=(0.0, -0.06, 0.62), hips=(-32, 0, 0),
                  spine=(-18, 0, 0), head=(22, 0, 0),
                  hand_r=(0.20, 0.30, 0.62), hand_l=(-0.20, 0.30, 0.62),
                  elbow_r=(1.0, -0.2, -0.4), elbow_l=(-1.0, -0.2, -0.4),
                  foot_r=(0.24, 0.02, 0.104), foot_l=(-0.24, -0.02, 0.104),
                  fist_r=0.6, fist_l=0.6)),
    ],

    # 45 frames / 1.5s: the punch at the sky. Cocked at the shoulder (6),
    # up (10 -- EntranceDirector.CODY_PUNCH_AT, the second pyro), held.
    "Air_Punch": [
        (0,  CODY_STAND),
        (6,  pose(CODY_STAND, spine=(-4, 0, 0), pelvis=(0.0, 0.0, 0.87),
                  hand_r=(0.24, 0.10, 1.40), elbow_r=(1.0, -0.4, -0.8),
                  fist_r=1.0)),
        (10, pose(CODY_STAND, spine=(10, 0, 0), head=(16, 0, 0),
                  hand_r=(0.22, 0.10, 2.04), elbow_r=(1.0, 0.0, 0.2),
                  hand_l=(-0.30, 0.10, 1.05), fist_r=1.0, fist_l=0.9)),
        (34, pose(CODY_STAND, spine=(10, 0, 0), head=(16, 0, 0),
                  hand_r=(0.22, 0.10, 2.03), elbow_r=(1.0, 0.0, 0.2),
                  hand_l=(-0.30, 0.10, 1.05), fist_r=1.0, fist_l=0.9)),
        (45, CODY_STAND),
    ],

    # 60 frames / 2.0s: pointing out to the crowd on his right, head
    # following the finger.
    "Point_Crowd": [
        (0,  CODY_STAND),
        (10, pose(CODY_STAND, head=(8, -30, 0), spine=(6, -10, 0),
                  hand_r=(0.72, 0.36, 1.58), elbow_r=(1.0, -0.2, 0.0),
                  fist_r=0.95, point_r=True)),
        (46, pose(CODY_STAND, head=(8, -34, 0), spine=(6, -12, 0),
                  hand_r=(0.73, 0.38, 1.60), elbow_r=(1.0, -0.2, 0.0),
                  fist_r=0.95, point_r=True)),
        (60, CODY_STAND),
    ],

    # 60 frames / 2.0s: the coat off. Hands to the lapels (12), shoulders
    # rolled back and the arms swept down behind him as it slides off (24,
    # 36), then forward as he hands it to the ringside crew (48). The
    # director takes the coat away on frame 36 (EntranceDirector.
    # COAT_OFF_AT), when his arms are behind him and it would be falling.
    "Coat_Off": [
        (0,  CODY_STAND),
        (12, pose(CODY_STAND, spine=(-2, 0, 0), head=(-6, 0, 0),
                  hand_r=(0.12, 0.16, 1.40), hand_l=(-0.12, 0.16, 1.40),
                  elbow_r=(1.0, -0.4, -0.6), elbow_l=(-1.0, -0.4, -0.6),
                  fist_r=0.8, fist_l=0.8)),
        (24, pose(CODY_STAND, spine=(10, 0, 0), head=(6, 0, 0),
                  hand_r=(0.30, -0.14, 1.04), hand_l=(-0.30, -0.14, 1.04),
                  elbow_r=(1.0, 0.4, -0.6), elbow_l=(-1.0, 0.4, -0.6),
                  fist_r=0.7, fist_l=0.7)),
        (36, pose(CODY_STAND, spine=(12, 0, 0), head=(8, 0, 0),
                  hand_r=(0.22, -0.26, 0.96), hand_l=(-0.22, -0.26, 0.96),
                  elbow_r=(1.0, 0.6, -0.4), elbow_l=(-1.0, 0.6, -0.4),
                  fist_r=0.8, fist_l=0.8)),
        (48, pose(CODY_STAND, hand_r=(0.30, 0.40, 1.10),
                  elbow_r=(0.8, -0.4, -0.6), fist_r=0.8)),
        (60, CODY_STAND),
    ],

    # === Cody, measured off the broadcast (refs/entrances.md [V]) ==========

    # 30 frames / 1.0s: after the WHOA, both fists DRIVEN DOWN (C-39 26 s):
    # cocked at the chest (6), punched down past the hips with the knees
    # dipping (10 -- CODY_PUNCH_AT, the second burst), held, up again.
    "Fists_Down": [
        (0,  CODY_STAND),
        (6,  pose(CODY_STAND, pelvis=(0.0, 0.0, 0.92), spine=(10, 0, 0),
                  head=(12, 0, 0),
                  hand_r=(0.26, 0.20, 1.42), hand_l=(-0.26, 0.20, 1.42),
                  elbow_r=(1.0, -0.4, -0.2), elbow_l=(-1.0, -0.4, -0.2),
                  fist_r=1.0, fist_l=1.0)),
        (10, pose(CODY_STAND, pelvis=(0.0, 0.02, 0.84), spine=(-6, 0, 0),
                  head=(14, 0, 0),
                  hand_r=(0.30, 0.12, 0.80), hand_l=(-0.30, 0.12, 0.80),
                  elbow_r=(1.0, 0.2, -0.4), elbow_l=(-1.0, 0.2, -0.4),
                  foot_r=(0.22, 0.02, 0.104), foot_l=(-0.22, -0.02, 0.104),
                  fist_r=1.0, fist_l=1.0)),
        (22, pose(CODY_STAND, pelvis=(0.0, 0.02, 0.85), spine=(-4, 0, 0),
                  head=(16, 0, 0),
                  hand_r=(0.31, 0.12, 0.82), hand_l=(-0.31, 0.12, 0.82),
                  elbow_r=(1.0, 0.2, -0.4), elbow_l=(-1.0, 0.2, -0.4),
                  foot_r=(0.22, 0.02, 0.104), foot_l=(-0.22, -0.02, 0.104),
                  fist_r=1.0, fist_l=1.0)),
        (30, CODY_STAND),
    ],

    # 150 frames / 5.0s: THE KNEEL at the top of the ramp (C-MITB 40-44 s,
    # C-SS 4 s). The left foot steps forward (10), he goes down onto the
    # RIGHT knee (22), left forearm across the left knee, right hand on his
    # right thigh, head DOWN; held (22-80); the head comes up to the crowd
    # (96), held; and he rises (138). The root stays put -- the pelvis drops
    # in root space, as Corner_Climb raises it.
    "Kneel": [
        (0,   CODY_STAND),
        (10,  pose(CODY_STAND, pelvis=(0.0, 0.08, 0.82), spine=(-6, 0, 0),
                   head=(-6, 0, 0),
                   foot_l=(-0.16, 0.36, 0.104), knee_l=(-0.2, 1.0, 0.2))),
        (22,  pose(CODY_STAND, pelvis=(0.0, 0.04, 0.53), hips=(-4, 0, 0),
                   spine=(-16, 0, 0), head=(-30, 0, 0),
                   foot_r=(0.15, -0.40, 0.13), knee_r=(0.2, 1.0, -0.6),
                   ankle_r=(40, 0, 0),
                   foot_l=(-0.16, 0.40, 0.104), knee_l=(-0.2, 1.0, 0.3),
                   hand_l=(-0.04, 0.46, 0.58), elbow_l=(-1.0, 0.2, 0.0),
                   hand_r=(0.22, 0.22, 0.60), elbow_r=(1.0, 0.0, -0.4),
                   fist_l=0.5, fist_r=0.4)),
        (80,  pose(CODY_STAND, pelvis=(0.0, 0.04, 0.52), hips=(-4, 0, 0),
                   spine=(-17, 0, 0), head=(-32, 0, 0),
                   foot_r=(0.15, -0.40, 0.13), knee_r=(0.2, 1.0, -0.6),
                   ankle_r=(40, 0, 0),
                   foot_l=(-0.16, 0.40, 0.104), knee_l=(-0.2, 1.0, 0.3),
                   hand_l=(-0.04, 0.46, 0.57), elbow_l=(-1.0, 0.2, 0.0),
                   hand_r=(0.22, 0.22, 0.59), elbow_r=(1.0, 0.0, -0.4),
                   fist_l=0.5, fist_r=0.4)),
        (96,  pose(CODY_STAND, pelvis=(0.0, 0.04, 0.54), hips=(-2, 0, 0),
                   spine=(4, 0, 0), head=(16, 0, 0),
                   foot_r=(0.15, -0.40, 0.13), knee_r=(0.2, 1.0, -0.6),
                   ankle_r=(40, 0, 0),
                   foot_l=(-0.16, 0.40, 0.104), knee_l=(-0.2, 1.0, 0.3),
                   hand_l=(-0.04, 0.46, 0.60), elbow_l=(-1.0, 0.2, 0.0),
                   hand_r=(0.22, 0.22, 0.62), elbow_r=(1.0, 0.0, -0.4),
                   fist_l=0.5, fist_r=0.4)),
        (118, pose(CODY_STAND, pelvis=(0.0, 0.04, 0.54), hips=(-2, 0, 0),
                   spine=(5, 0, 0), head=(18, 0, 0),
                   foot_r=(0.15, -0.40, 0.13), knee_r=(0.2, 1.0, -0.6),
                   ankle_r=(40, 0, 0),
                   foot_l=(-0.16, 0.40, 0.104), knee_l=(-0.2, 1.0, 0.3),
                   hand_l=(-0.04, 0.46, 0.60), elbow_l=(-1.0, 0.2, 0.0),
                   hand_r=(0.22, 0.22, 0.62), elbow_r=(1.0, 0.0, -0.4),
                   fist_l=0.5, fist_r=0.4)),
        (138, pose(CODY_STAND, pelvis=(0.0, 0.06, 0.84), spine=(2, 0, 0),
                   head=(10, 0, 0),
                   foot_l=(-0.16, 0.30, 0.104), knee_l=(-0.2, 1.0, 0.2))),
        (150, CODY_STAND),
    ],

    # 100 frames / 3.33s: the WHOA again, low, down the ramp -- on the
    # chorus's big held WHOAAA (43.5 s in his music; entrance_director.gd
    # CODY_WHOA_LOW): feet wide, knees bent, arms straight out level, palms
    # forward, chest up. Wide on frame 10, sunk into it, and pushed wider on
    # the second held WHOA (45.5 s: frame 70), then up to the stand.
    "Whoa_Low": [
        (0,  CODY_STAND),
        (10, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.780), spine=(10, 0, 0),
                  head=(16, 0, 0),
                  foot_r=(0.33, 0.0, 0.104), foot_l=(-0.33, 0.0, 0.104),
                  knee_r=(0.6, 1.0, 0.0), knee_l=(-0.6, 1.0, 0.0),
                  hand_r=(0.80, 0.08, 1.32), hand_l=(-0.80, 0.08, 1.32),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.1, fist_l=0.1)),
        (18, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.760), spine=(12, 0, 0),
                  head=(18, 0, 0),
                  foot_r=(0.33, 0.0, 0.104), foot_l=(-0.33, 0.0, 0.104),
                  knee_r=(0.6, 1.0, 0.0), knee_l=(-0.6, 1.0, 0.0),
                  hand_r=(0.81, 0.08, 1.30), hand_l=(-0.81, 0.08, 1.30),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.1, fist_l=0.1)),
        (44, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.765), spine=(14, 0, 0),
                  head=(22, 0, 0),
                  foot_r=(0.33, 0.0, 0.104), foot_l=(-0.33, 0.0, 0.104),
                  knee_r=(0.6, 1.0, 0.0), knee_l=(-0.6, 1.0, 0.0),
                  hand_r=(0.81, 0.08, 1.33), hand_l=(-0.81, 0.08, 1.33),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.1, fist_l=0.1)),
        (62, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.770), spine=(11, 0, 0),
                  head=(18, 0, -4),
                  foot_r=(0.33, 0.0, 0.104), foot_l=(-0.33, 0.0, 0.104),
                  knee_r=(0.6, 1.0, 0.0), knee_l=(-0.6, 1.0, 0.0),
                  hand_r=(0.80, 0.08, 1.31), hand_l=(-0.80, 0.08, 1.31),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.1, fist_l=0.1)),
        (70, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.750), spine=(16, 0, 0),
                  head=(26, 0, 0),
                  foot_r=(0.33, 0.0, 0.104), foot_l=(-0.33, 0.0, 0.104),
                  knee_r=(0.6, 1.0, 0.0), knee_l=(-0.6, 1.0, 0.0),
                  hand_r=(0.84, 0.08, 1.40), hand_l=(-0.84, 0.08, 1.40),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.0, fist_l=0.0)),
        (90, pose(CODY_STAND, pelvis=(0.0, 0.0, 0.765), spine=(12, 0, 0),
                  head=(18, 0, 3),
                  foot_r=(0.33, 0.0, 0.104), foot_l=(-0.33, 0.0, 0.104),
                  knee_r=(0.6, 1.0, 0.0), knee_l=(-0.6, 1.0, 0.0),
                  hand_r=(0.81, 0.08, 1.32), hand_l=(-0.81, 0.08, 1.32),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        (100, CODY_STAND),
    ],

    # 104 frames / 3.5s, looping: _crowd_walk.
    "Walk_Crowd": _crowd_walk(),

    # 36 frames / 1.2s: up onto the middle rope in the corner, facing out.
    # Hands to the top rope first (8), the right boot onto its rope (16),
    # the weight over it and the left boot up (26), standing (36). The root
    # stays on the mat: everything rises in root space.
    "Corner_Climb": [
        (0,  CODY_STAND),
        (8,  pose(CODY_STAND, spine=(-6, 0, 0),
                  hand_r=(0.30, 0.46, 1.14), hand_l=(-0.30, 0.46, 1.14),
                  elbow_r=(1.0, -0.4, -0.4), elbow_l=(-1.0, -0.4, -0.4),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.22, 0.20, 0.50))),
        (16, pose(CODY_STAND, pelvis=(0.0, 0.14, 1.06), hips=(-12, 0, 0),
                  spine=(-6, 0, 0),
                  hand_r=(0.30, 0.46, 1.14), hand_l=(-0.30, 0.46, 1.14),
                  elbow_r=(1.0, -0.4, -0.4), elbow_l=(-1.0, -0.4, -0.4),
                  fist_r=0.8, fist_l=0.8,
                  foot_r=(0.247, CORNER_FOOT_FWD, CORNER_FOOT_UP),
                  knee_r=(0.3, 1.0, 0.0))),
        (26, pose(CORNER_ON, pelvis=(0.0, 0.26, 1.48), hips=(-10, 0, 0),
                  foot_l=(-0.22, 0.30, 0.70))),
        (36, CORNER_ON),
    ],

    # 90 frames / 3.0s: on the rope, the arms come off the top rope and go
    # WIDE over the crowd (12), chest out, head back; held to 72; back to
    # the rope by 90.
    "Corner_Pose": [
        (0,  CORNER_ON),
        (12, pose(CORNER_ON, spine=(16, 0, 0), head=(20, 0, 0),
                  hand_r=(0.86, 0.34, 1.98), hand_l=(-0.86, 0.34, 1.98),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        (72, pose(CORNER_ON, spine=(17, 0, 0), head=(22, 0, 0),
                  hand_r=(0.87, 0.34, 2.00), hand_l=(-0.87, 0.34, 2.00),
                  elbow_r=(1.0, -0.2, 0.2), elbow_l=(-1.0, -0.2, 0.2),
                  fist_r=0.2, fist_l=0.2)),
        (90, CORNER_ON),
    ],

    # 30 frames / 1.0s: back down to the mat, left boot first.
    "Corner_Down": [
        (0,  CORNER_ON),
        (10, pose(CORNER_ON, pelvis=(0.0, 0.20, 1.40), hips=(-10, 0, 0),
                  foot_l=(-0.17, 0.10, 0.40))),
        (18, pose(CODY_STAND, pelvis=(0.0, 0.12, 1.02), hips=(-12, 0, 0),
                  hand_r=(0.30, 0.46, 1.14), hand_l=(-0.30, 0.46, 1.14),
                  elbow_r=(1.0, -0.4, -0.4), elbow_l=(-1.0, -0.4, -0.4),
                  foot_r=(0.247, CORNER_FOOT_FWD, CORNER_FOOT_UP),
                  knee_r=(0.3, 1.0, 0.0))),
        (30, CODY_STAND),
    ],

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
    #
    # These three, Tie_Up_Collar and Move_Exec_Impact were authored with a
    # POSITIVE hips/spine pitch under notes saying "bends at the waist" --
    # and a positive pitch tips a man BACKWARD (see STANCE). Every lock-up and
    # grapple hold in the game played as two backbends with arms reaching at
    # the air; the owner flagged both. The pitches are negated, head included
    # (the head was lifted against a forward lean that was never there).

    # 30 frames / 1.0s, looping, role unknown. Both men have hands on each
    # other and neither is winning; the pressure shifts and comes back.
    # This replaced "Interact", a one-armed reach-and-point, which with both
    # wrestlers playing it rendered a lock-up as two men pointing past each
    # other.
    "Grapple_Hold_Neutral": [
        (0,  P(pelvis=(0.0, 0.0, 0.840), hips=(-6, 0, 0), spine=(-20, 0, 0),
               head=(4, 0, 0),
               hand_r=(0.12, 0.50, 1.42), hand_l=(-0.26, 0.46, 1.30),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        (10, P(pelvis=(0.0, 0.04, 0.832), hips=(-8, -4, 0), spine=(-24, -4, 0),
               head=(6, -4, 0),
               hand_r=(0.11, 0.53, 1.40), hand_l=(-0.28, 0.49, 1.28),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        (20, P(pelvis=(0.0, -0.02, 0.846), hips=(-5, 4, 0), spine=(-17, 4, 0),
               head=(3, 4, 0),
               hand_r=(0.13, 0.48, 1.44), hand_l=(-0.24, 0.44, 1.32),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        (30, P(pelvis=(0.0, 0.0, 0.840), hips=(-6, 0, 0), spine=(-20, 0, 0),
               head=(4, 0, 0),
               hand_r=(0.12, 0.50, 1.42), hand_l=(-0.26, 0.46, 1.30),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
    ],

    # 30 frames / 1.0s, looping. A front waistlock bends at the waist and
    # wraps LOW -- hands together at the other man's hips, head up and past
    # his shoulder, feet back so he can drive. This replaced
    # "PickUp_Table", which lifts furniture with a straight back.
    "Grapple_Hold_Attacker": [
        (0,  P(pelvis=(0.0, 0.04, 0.800), hips=(-10, 0, 0), spine=(-42, 0, 0),
               head=(32, 0, 8),
               hand_r=(0.07, 0.52, 0.92), hand_l=(-0.11, 0.54, 0.90),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
        # Squeezes and tries to break him off the mat.
        (10, P(pelvis=(0.0, 0.02, 0.842), hips=(-6, 0, 0), spine=(-34, 0, 0),
               head=(28, 0, 8),
               hand_r=(0.06, 0.50, 1.00), hand_l=(-0.10, 0.52, 0.98),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
        (20, P(pelvis=(0.0, 0.05, 0.792), hips=(-11, 0, 0), spine=(-44, 0, 0),
               head=(33, 0, 8),
               hand_r=(0.07, 0.53, 0.89), hand_l=(-0.11, 0.55, 0.87),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
        (30, P(pelvis=(0.0, 0.04, 0.800), hips=(-10, 0, 0), spine=(-42, 0, 0),
               head=(32, 0, 8),
               hand_r=(0.07, 0.52, 0.92), hand_l=(-0.11, 0.54, 0.90),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.08, 0.104))),
    ],

    # 30 frames / 1.0s, looping. The man being held played "Death01" -- a
    # corpse. He is bent over the top of the waistlock, hands fighting the
    # grip, feet sprawled back and wide so he cannot be lifted.
    "Grapple_Hold_Defender": [
        (0,  P(pelvis=(0.0, -0.04, 0.780), hips=(-12, 0, 0), spine=(-46, 0, 0),
               head=(30, 0, 0),
               hand_r=(0.24, 0.44, 0.90), hand_l=(-0.22, 0.46, 0.88),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.29, -0.34, 0.104), foot_l=(-0.27, -0.30, 0.104))),
        # Sprawls harder -- hips back and down, all of it into his grip.
        (10, P(pelvis=(0.0, -0.08, 0.762), hips=(-14, 0, 0), spine=(-50, 0, 0),
               head=(32, 0, 0),
               hand_r=(0.26, 0.46, 0.86), hand_l=(-0.24, 0.48, 0.84),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.29, -0.36, 0.104), foot_l=(-0.27, -0.32, 0.104))),
        (20, P(pelvis=(0.0, -0.02, 0.792), hips=(-11, 0, 0), spine=(-43, 0, 0),
               head=(28, 0, 0),
               hand_r=(0.23, 0.42, 0.93), hand_l=(-0.21, 0.44, 0.91),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.29, -0.33, 0.104), foot_l=(-0.27, -0.29, 0.104))),
        (30, P(pelvis=(0.0, -0.04, 0.780), hips=(-12, 0, 0), spine=(-46, 0, 0),
               head=(30, 0, 0),
               hand_r=(0.24, 0.44, 0.90), hand_l=(-0.22, 0.46, 0.88),
               elbow_r=(0.8, -0.2, -0.5), elbow_l=(-0.8, -0.2, -0.5),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.29, -0.34, 0.104), foot_l=(-0.27, -0.30, 0.104))),
    ],

    # 18 frames / 0.6s. He has just put someone down: still bent over the
    # spot, chest opening as he comes back up off the impact. This replaced
    # "Jump_Land", which is a man absorbing a drop he took himself.
    "Move_Exec_Impact": [
        (0,  P(pelvis=(0.0, 0.06, 0.720), hips=(-14, 0, 0), spine=(-42, 0, 0),
               head=(16, 0, 0),
               hand_r=(0.26, 0.46, 0.34), hand_l=(-0.24, 0.48, 0.36),
               elbow_r=(0.7, -0.3, -0.6), elbow_l=(-0.7, -0.3, -0.6),
               fist_r=0.6, fist_l=0.6)),
        (4,  P(pelvis=(0.0, 0.05, 0.762), hips=(-11, 0, 0), spine=(-32, 0, 0),
               head=(14, 0, 0),
               hand_r=(0.26, 0.44, 0.52), hand_l=(-0.24, 0.46, 0.54),
               fist_r=0.6, fist_l=0.6)),
        (9,  P(pelvis=(0.0, 0.03, 0.822), hips=(-8, 0, 0), spine=(-18, 0, 0),
               head=(8, 0, 0),
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
    #
    # Both halves had every pitch the wrong way round (positive tips a man
    # BACK -- see STANCE): the attacker reclined while "dragging his head
    # down", and the defender arched back to 52 degrees at the knee, taking
    # his stomach AWAY from it -- a man bending over backwards off a knee. The
    # hips, spine and head pitches are negated on every key of both halves, so
    # the beats stay locked together: the attacker leans in over him, and the
    # defender folds forward around the knee.
    "Clinch_Knee_Attacker": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(-6, 0, 0), spine=(-18, 0, 0),
               hand_r=(0.10, 0.52, 1.46), hand_l=(-0.28, 0.44, 1.28),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Drags his head down: both hands pull down and back.
        (8,  P(pelvis=(0.0, 0.02, 0.830), hips=(-8, 0, 0), spine=(-24, 0, 0),
               head=(10, 0, 0),
               hand_r=(0.10, 0.40, 1.12), hand_l=(-0.22, 0.38, 1.08),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Loads the knee, weight entirely onto the left foot.
        (14, P(pelvis=(-0.04, 0.0, 0.862), hips=(-6, -6, 6), spine=(-20, 0, -4),
               head=(10, 0, 0),
               hand_r=(0.11, 0.38, 1.08), hand_l=(-0.21, 0.36, 1.04),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.16, 0.30, 0.62), knee_r=(0.3, 1.0, 0.1),
               foot_l=(-0.24, 0.16, 0.104))),
        # The knee lands, and the hands pull DOWN into it.
        (18, P(pelvis=(-0.05, 0.02, 0.870), hips=(-10, -8, 8),
               spine=(-10, 0, -6), head=(6, 0, 0),
               hand_r=(0.12, 0.34, 0.98), hand_l=(-0.20, 0.32, 0.96),
               fist_r=0.7, fist_l=0.7,
               foot_r=(0.12, 0.50, 0.88), knee_r=(0.3, 1.0, 0.1),
               foot_l=(-0.24, 0.16, 0.104))),
        # Shoves him off and gets the foot back down.
        (22, P(pelvis=(-0.02, 0.04, 0.848), hips=(-6, 0, 2), spine=(-16, 0, 0),
               hand_r=(0.16, 0.54, 1.24), hand_l=(-0.18, 0.56, 1.22),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.20, 0.14, 0.30), knee_r=(0.3, 1.0, 0.1),
               foot_l=(-0.24, 0.16, 0.104))),
        (30, P()),
    ],

    # The other side of it, frame for frame.
    "Clinch_Knee_Defender": [
        (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(-6, 0, 0), spine=(-18, 0, 0),
               hand_r=(0.24, 0.46, 1.34), hand_l=(-0.20, 0.48, 1.32),
               fist_r=0.6, fist_l=0.6,
               foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.18, 0.104))),
        # Dragged down by the head, hands on the arms that are doing it.
        (8,  P(pelvis=(0.0, -0.04, 0.802), hips=(-12, 0, 0), spine=(-38, 0, 0),
               head=(-10, 0, 0),
               hand_r=(0.24, 0.40, 1.10), hand_l=(-0.22, 0.42, 1.08),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        (14, P(pelvis=(0.0, -0.06, 0.788), hips=(-14, 0, 0), spine=(-44, 0, 0),
               head=(-16, 0, 0),
               hand_r=(0.22, 0.36, 1.02), hand_l=(-0.20, 0.38, 1.00),
               fist_r=0.5, fist_l=0.5,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # The knee lands: he folds hard around it and his hands go to it.
        (18, P(pelvis=(0.0, -0.10, 0.742), hips=(-18, 0, 0), spine=(-52, 0, 0),
               head=(-22, 0, 0),
               hand_r=(0.14, 0.26, 0.94), hand_l=(-0.12, 0.28, 0.92),
               elbow_r=(0.6, -0.3, -0.7), elbow_l=(-0.6, -0.3, -0.7),
               fist_r=0.62, fist_l=0.62,
               foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.16, 0.104))),
        # Shoved off: he goes backward a step, still folded.
        (22, P(pelvis=(0.0, -0.16, 0.778), hips=(-14, 0, 0), spine=(-44, 0, 0),
               head=(-18, 0, 0),
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
              # Both clear of his flank: at fwd 0.10-0.20 each sat inside
              # the torso of a man turned on his side (PoseLint).
              hand_r=(0.70, 0.34, 0.20), hand_l=(-0.10, 0.46, 0.84),
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

# --- Cody Rhodes's moveset (gauntlet/refs/cody_moveset.md) -----------------
#
# The moves he hits in nearly every WWE match, researched before keyed (All
# Elite Moves' list, WWE 2K signature sets, and the broadcast clips used for
# his entrance). Keyed with the blender-animation skill's rules: every beat a
# pose the rig can reach, rotations no more than ~60 degrees apart so the
# quaternion keys cannot take the long way round, and anything turning over
# carried in its own body frame (_body).

# Powerslam, 45 frames / 1.5 s. The body slam's scoop and roll (frames 0-19,
# shared, so the lift that reads is the lift both use), then instead of the
# drop he steps in and falls forward WITH him, chest to chest, landing across
# him on his knees -- which is the whole difference between a powerslam and a
# slam -- holds him there, and gets up.
_ON_TOP = dict(pelvis=(0.0, 0.00, 0.440), hips=(-70, 0, 0), spine=(-10, 0, 0),
               head=(-6, 0, 0),
               hand_r=(0.42, 0.62, 0.12), hand_l=(-0.42, 0.62, 0.12),
               elbow_r=(0.8, 0.0, 0.4), elbow_l=(-0.8, 0.0, 0.4),
               fist_r=0.3, fist_l=0.3,
               foot_r=(0.20, -0.52, 0.12), foot_l=(-0.20, -0.48, 0.12),
               knee_r=(0.2, 0.3, -1.0), knee_l=(-0.2, 0.3, -1.0))
CLIPS["Powerslam_Attacker"] = [k for k in CLIPS["Bodyslam_Attacker"] if k[0] <= 19] + [
    # A step in, still carrying him across the chest.
    (23, P(pelvis=(0.0, 0.08, 0.860), hips=(-2, 0, 0), spine=(-2, 0, 0),
           head=(-8, 0, 0),
           hand_r=(0.28, 0.34, 0.96), hand_l=(-0.34, 0.32, 0.94),
           elbow_r=(0.5, -0.4, -0.7), elbow_l=(-0.5, -0.4, -0.7),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.22, -0.12, 0.104), foot_l=(-0.20, 0.30, 0.104))),
    # Falling forward with him.
    (27, dict(pelvis=(0.0, 0.10, 0.640), hips=(-40, 0, 0), spine=(-16, 0, 0),
              head=(-10, 0, 0),
              hand_r=(0.32, 0.56, 0.52), hand_l=(-0.36, 0.54, 0.54),
              elbow_r=(0.6, -0.2, -0.6), elbow_l=(-0.6, -0.2, -0.6),
              fist_r=0.5, fist_l=0.5,
              foot_r=(0.22, -0.30, 0.104), foot_l=(-0.20, 0.10, 0.20),
              knee_r=(0.2, 1.0, -0.2), knee_l=(-0.2, 1.0, 0.0))),
    # Across him, chest on chest, on his knees.
    (30, dict(_ON_TOP)),
    (40, dict(_ON_TOP, pelvis=(0.0, 0.00, 0.450), spine=(-8, 0, 0), head=(-2, 0, 0))),
    (43, pose(CROUCH)),
    (45, P()),
]
CLIPS["Powerslam_Defender"] = [k for k in CLIPS["Bodyslam_Defender"] if k[0] <= 20] + [
    (24, CLIPS["Bodyslam_Defender"][[k[0] for k in CLIPS["Bodyslam_Defender"]].index(24)][1]),
    # Driven flat, with the man on top of him.
    (29, S(pelvis=(0.0, 0.0, 0.200), hips=(-88, 0, 180), spine=(-2, 0, 0),
           head=(-4, 0, 0),
           hand_r=(-0.56, 0.14, 0.10), hand_l=(0.56, 0.14, 0.10),
           elbow_r=(-0.7, 0.3, -0.3), elbow_l=(0.7, 0.3, -0.3),
           fist_r=0.1, fist_l=0.1,
           foot_r=(-0.14, -0.74, 0.20), foot_l=(0.12, -0.76, 0.24),
           knee_r=(-0.3, 0.0, 1.0), knee_l=(0.3, 0.0, 1.0))),
    (33, S(pelvis=(0.0, 0.0, 0.180), spine=(-8, 0, 0), head=(-12, 0, 0),
           hand_r=(-0.46, 0.18, 0.10), hand_l=(0.44, 0.18, 0.10))),
    (45, S()),
]

# The Disaster Kick, 42 frames / 1.4 s -- his spinning heel kick. Out of the
# lock-up he shoves the man off a step, plants and spins (the root does the
# turn, three quarters of it, paired_recipes.gd), and the right leg comes
# round straight, the heel into the side of the head, the body leaning away
# from it; he lands the leg and finishes the turn facing him. The victim goes
# over backward.
CLIPS["Disaster_Kick_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # The shove.
    (5,  P(pelvis=(0.0, -0.04, 0.840), spine=(-6, 0, 0),
           hand_r=(0.18, 0.56, 1.28), hand_l=(-0.18, 0.56, 1.26),
           fist_r=0.1, fist_l=0.1)),
    # Plants the left foot and winds up, turning.
    (10, P(pelvis=(0.0, 0.0, 0.860), hips=(0, -30, 0), spine=(0, -24, 0),
           head=(0, 24, 0),
           hand_r=(0.22, 0.20, 1.22), hand_l=(-0.24, 0.10, 1.20),
           fist_r=0.8, fist_l=0.8,
           foot_r=(0.20, -0.14, 0.104), foot_l=(-0.16, 0.10, 0.104))),
    # Spinning on the left foot, the right knee chambered.
    (14, dict(pelvis=(0.0, 0.0, 0.900), hips=(-6, 0, -8), spine=(6, 0, -6),
              head=(0, 0, 0),
              hand_r=(0.30, 0.12, 1.30), hand_l=(-0.34, 0.10, 1.26),
              fist_r=0.8, fist_l=0.8,
              foot_r=(0.34, -0.06, 0.66), knee_r=(0.8, 0.5, 0.2),
              foot_l=(-0.12, 0.02, 0.104), knee_l=(-0.2, 1.0, 0.0))),
    # CONTACT: the leg straight out to his right at head height, heel first,
    # the body leaning away over the standing leg.
    (18, dict(pelvis=(-0.06, 0.0, 0.950), hips=(0, 0, -30), spine=(0, 0, -18),
              head=(0, 0, -12),
              hand_r=(0.24, 0.16, 1.34), hand_l=(-0.56, 0.08, 1.20),
              fist_r=0.8, fist_l=0.6,
              foot_r=(0.96, 0.00, 1.52), knee_r=(0.2, 1.0, 0.3),
              foot_l=(-0.10, 0.00, 0.104), knee_l=(-0.2, 1.0, 0.0))),
    # Following through, the leg sweeping on round.
    (21, dict(pelvis=(-0.04, 0.0, 0.920), hips=(0, 0, -20), spine=(0, 0, -12),
              head=(0, 0, -8),
              hand_r=(0.24, 0.16, 1.30), hand_l=(-0.46, 0.08, 1.18),
              fist_r=0.8, fist_l=0.6,
              foot_r=(0.60, -0.46, 1.06), knee_r=(0.4, 0.4, 0.8),
              foot_l=(-0.10, 0.00, 0.104), knee_l=(-0.2, 1.0, 0.0))),
    (25, P(pelvis=(0.0, 0.0, 0.840), spine=(-6, 0, 0),
           hand_r=(0.26, 0.24, 1.14), hand_l=(-0.24, 0.26, 1.12),
           foot_r=(0.24, -0.20, 0.104), foot_l=(-0.20, 0.12, 0.104))),
    (30, pose(STAND)),
    (42, P()),
]
CLIPS["Disaster_Kick_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Shoved off a step.
    (5,  P(pelvis=(0.0, -0.08, 0.830), spine=(8, 0, 0), head=(6, 0, 0),
           hand_r=(0.22, 0.26, 1.12), hand_l=(-0.20, 0.28, 1.10),
           fist_r=0.4, fist_l=0.4,
           foot_r=(0.23, -0.24, 0.104), foot_l=(-0.19, 0.10, 0.104))),
    (12, P(spine=(-6, 0, 0), head=(6, 0, 0),
           hand_r=(0.26, 0.24, 1.10), hand_l=(-0.24, 0.26, 1.08),
           fist_r=0.6, fist_l=0.6)),
] + _back_fall(18, 42, pelvis_hit=0.90, twist=-40)

# The delayed vertical suplex, 72 frames / 2.4 s. Front facelock, his arm
# over Cody's neck; lifted straight up until he is upside down and vertical
# -- and HELD there, a full second, which is the "delayed" (and the point:
# Cody plays to the crowd with a man upside down over him); then Cody falls
# back and the man goes over the top, flat on his back beyond Cody's head.
# The victim's inversion is bone pose in his own body frame (_body), keyed in
# steps no wider than 55 degrees; his root carries him over Cody's
# (paired_recipes.gd grapple_vertical_suplex).
_SUPLEX_ATK_HOLD = P(pelvis=(0.0, -0.04, 0.900), hips=(2, 0, 0), spine=(12, 0, 0),
                     head=(4, 0, 0),
                     hand_r=(0.06, 0.16, 1.56), hand_l=(-0.12, 0.14, 1.52),
                     elbow_r=(0.7, -0.2, 0.2), elbow_l=(-0.7, -0.2, 0.2),
                     fist_r=0.8, fist_l=0.8,
                     foot_r=(0.24, -0.06, 0.104), foot_l=(-0.22, 0.08, 0.104))
CLIPS["Vertical_Suplex_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # The front facelock, the other hand in his tights.
    (6,  _facelock(0.800, hand_l=(-0.10, 0.44, 0.96), elbow_l=(-0.7, -0.2, -0.6))),
    # Sits into the lift.
    (12, P(pelvis=(0.0, 0.02, 0.720), hips=(-8, 0, 0), spine=(-10, 0, 0),
           head=(-4, 0, 0),
           hand_r=(0.06, 0.34, 1.24), hand_l=(-0.10, 0.30, 1.00),
           fist_r=0.7, fist_l=0.7,
           foot_r=(0.26, -0.06, 0.104), foot_l=(-0.24, 0.08, 0.104))),
    # Driving him up.
    (17, P(pelvis=(0.0, -0.02, 0.880), hips=(4, 0, 0), spine=(8, 0, 0),
           head=(-2, 0, 0),
           hand_r=(0.05, 0.22, 1.46), hand_l=(-0.12, 0.20, 1.40),
           fist_r=0.8, fist_l=0.8,
           foot_r=(0.24, -0.06, 0.104), foot_l=(-0.22, 0.08, 0.104))),
    (21, dict(_SUPLEX_ATK_HOLD)),
    # The hold: a slow shift of the weight, chin up, the building counting.
    (36, dict(_SUPLEX_ATK_HOLD, pelvis=(0.0, -0.05, 0.895), spine=(14, 0, 0),
              head=(8, 0, 0))),
    (50, dict(_SUPLEX_ATK_HOLD)),
    # Over backward, taking him with him.
    (55, dict(pelvis=(0.0, -0.20, 0.620), hips=(40, 0, 0), spine=(10, 0, 0),
              head=(-20, 0, 0),
              hand_r=(0.20, -0.10, 1.30), hand_l=(-0.20, -0.10, 1.30),
              fist_r=0.6, fist_l=0.6,
              foot_r=(0.18, 0.40, 0.104), foot_l=(-0.18, 0.36, 0.104))),
    (59, pose(ATK_BACK, hand_r=(0.20, -0.60, 0.40), hand_l=(-0.20, -0.60, 0.40))),
] + _get_up(64, 72, lying=True)

# The victim's arms and legs while he is carried upside down: hugging round
# Cody, legs long -- given in the BODY frame, so they turn with him.
_SUPLEX_LIMBS = dict(spine=(-6, 0, 0), head=(-8, 0, 0),
                     hand_r=(0.30, 0.30, 0.30), hand_l=(-0.30, 0.30, 0.30),
                     elbow_r=(0.8, -0.3, -0.3), elbow_l=(-0.8, -0.3, -0.3),
                     fist_r=0.4, fist_l=0.4,
                     foot_r=(0.12, 0.04, -0.82), foot_l=(-0.12, 0.02, -0.82),
                     knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0), free_feet=True)
CLIPS["Vertical_Suplex_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Bent into the facelock, his right arm over Cody's neck.
    (6,  pose(VICTIM_BENT, hand_r=(0.12, 0.46, 1.30), elbow_r=(0.6, -0.3, 0.2))),
    # Off his feet.
    (12, _body((-55, 0, 0), (0.0, 0.04, 1.080), **dict(_TUCK_LEGS, spine=(-10, 0, 0),
               head=(-8, 0, 0), hand_r=(0.30, 0.30, 0.40), hand_l=(-0.30, 0.30, 0.40),
               fist_r=0.4, fist_l=0.4))),
    (16, _body((-110, 0, 0), (0.0, 0.08, 1.600), **_SUPLEX_LIMBS)),
    # Straight up and down, upside down over him.
    (20, _body((-165, 0, 0), (0.0, 0.10, 2.050), **_SUPLEX_LIMBS)),
    (36, _body((-168, 0, 0), (0.0, 0.10, 2.060), **_SUPLEX_LIMBS)),
    (50, _body((-165, 0, 0), (0.0, 0.10, 2.050), **_SUPLEX_LIMBS)),
    # Over the top.
    (54, _body((-215, 0, 0), (0.0, 0.10, 1.700), **_SUPLEX_LIMBS)),
    (57, _body((-250, 0, 0), (0.0, 0.00, 0.900), **dict(_SUPLEX_LIMBS,
               hand_r=(0.50, 0.00, 0.40), hand_l=(-0.50, 0.00, 0.40)))),
    # Flat on his back beyond Cody's head -- head toward him, which is
    # SUPINE_AWAY (MoveDef.defender_lands_head_away).
    (59, dict(SUPINE_AWAY, pelvis=(0.0, 0.0, 0.220))),
    (72, dict(SUPINE_AWAY)),
]

# The Alabama Slam, 60 frames / 2.0 s. He ducks in, and the man is hoisted
# upside down over his shoulders, hanging down his back, legs held at
# Cody's shoulders; a beat there; then Cody heaves him back up over the top
# and slams him down in front, back first, and follows him down bent over
# the legs. The victim's whole turn is one direction (pitch rising, -150 to
# +90), keyed in 50-60 degree steps in his body frame; his root travels from
# in front of Cody to under him and out in front again.
_ALA_LIMBS = dict(spine=(-8, 0, 0), head=(-10, 0, 0),
                  hand_r=(0.30, 0.20, 0.36), hand_l=(-0.30, 0.20, 0.36),
                  elbow_r=(0.8, -0.3, -0.3), elbow_l=(-0.8, -0.3, -0.3),
                  fist_r=0.3, fist_l=0.3,
                  foot_r=(0.14, 0.30, -0.46), foot_l=(-0.14, 0.30, -0.48),
                  knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0), free_feet=True)
_ALA_HOLD = P(pelvis=(0.0, 0.0, 0.860), spine=(4, 0, 0), head=(6, 0, 0),
              hand_r=(0.22, 0.08, 1.56), hand_l=(-0.22, 0.08, 1.56),
              elbow_r=(0.8, -0.3, 0.0), elbow_l=(-0.8, -0.3, 0.0),
              fist_r=0.8, fist_l=0.8,
              foot_r=(0.24, -0.06, 0.104), foot_l=(-0.22, 0.08, 0.104))
CLIPS["Alabama_Slam_Attacker"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.12, 0.50, 1.40), hand_l=(-0.26, 0.46, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Ducks in under him, arms round the thighs.
    (7,  P(pelvis=(0.0, 0.12, 0.660), hips=(-30, 0, 0), spine=(-30, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.20, 0.44, 0.90), hand_l=(-0.20, 0.44, 0.90),
           fist_r=0.7, fist_l=0.7,
           foot_r=(0.26, -0.10, 0.104), foot_l=(-0.24, 0.16, 0.104))),
    # Up, the man over his shoulders.
    (14, dict(_ALA_HOLD)),
    (30, dict(_ALA_HOLD, spine=(6, 0, 0), head=(10, 0, 0))),
    # The heave: up and over the top.
    (35, P(pelvis=(0.0, 0.02, 0.900), hips=(4, 0, 0), spine=(10, 0, 0),
           head=(8, 0, 0),
           hand_r=(0.22, 0.10, 1.74), hand_l=(-0.22, 0.10, 1.74),
           fist_r=0.8, fist_l=0.8)),
    # Down with him, bent over the legs.
    (40, P(pelvis=(0.0, 0.12, 0.620), hips=(-30, 0, 0), spine=(-38, 0, 0),
           head=(-14, 0, 0),
           hand_r=(0.24, 0.60, 0.52), hand_l=(-0.24, 0.60, 0.52),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.22, 0.104))),
    (46, P(pelvis=(0.0, 0.06, 0.760), hips=(-12, 0, 0), spine=(-24, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.24, 0.40, 0.70), hand_l=(-0.24, 0.40, 0.70))),
    (60, P()),
]
CLIPS["Alabama_Slam_Defender"] = [
    (0,  P(pelvis=(0.0, 0.0, 0.845), hips=(6, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.22, 0.46, 1.32), hand_l=(-0.20, 0.48, 1.30),
           fist_r=0.6, fist_l=0.6)),
    # Bent over the man ducking under him.
    (7,  pose(VICTIM_BENT, pelvis=(0.0, 0.06, 0.860), hips=(-50, 0, 0))),
    (10, _body((-100, 0, 0), (0.0, 0.04, 1.250), **_ALA_LIMBS)),
    # Upside down down his back, knees hooked over his shoulders.
    (14, _body((-150, 0, 0), (0.0, 0.00, 1.560), **_ALA_LIMBS)),
    (30, _body((-148, 0, 0), (0.0, 0.00, 1.570), **_ALA_LIMBS)),
    # Heaved back up and over the top of him.
    (33, _body((-100, 0, 0), (0.0, -0.04, 1.720), **_ALA_LIMBS)),
    (35, _body((-45, 0, 0), (0.0, -0.08, 1.860), **_ALA_LIMBS)),
    (37, _body((10, 0, 0), (0.0, -0.10, 1.760), **dict(_ALA_LIMBS,
               hand_r=(0.50, 0.00, 0.40), hand_l=(-0.50, 0.00, 0.40)))),
    (39, _body((60, 0, 0), (0.0, -0.10, 1.050), **dict(_ALA_LIMBS,
               hand_r=(0.50, 0.00, 0.40), hand_l=(-0.50, 0.00, 0.40)))),
    # Back first, head away from Cody: SUPINE_AWAY.
    (41, dict(SUPINE_AWAY, pelvis=(0.0, 0.0, 0.230))),
    (46, dict(SUPINE_AWAY, pelvis=(0.0, 0.0, 0.190))),
    (60, dict(SUPINE_AWAY)),
]


# The Figure-Four leglock, 180 frames / 6.0 s, played by the two SUBMISSION_*
# states rather than GrappleRig: the man is already down, and
# WrestlerController._place_figure_four() stands Cody at his feet facing up
# his body, FIGURE_FOUR_BEHIND_FEET_M (1.0 m) back from his root on his own
# heading. So in Cody's frame the downed man's pelvis is at fwd +1.00 and
# his boots (Down_Supine's, at his own fwd -0.50) are at +0.50.
#
# The hold as Cody works it (refs/cody_moveset.md): grab both ankles, lift,
# cross the man's LEFT shin over his right knee -- the "4" -- step in, sit
# down and lie back with his own right leg hooked over the crossed ankle,
# then bridge his hips to put the pressure on. Locked by frame 62 (2.07 s);
# MoveDef.startup_frames is that, and the struggle only starts from there.
# Frames 62-180 are the pressure: three bridges, the victim sitting up to
# reach for the leg and slapping the mat between them. Not looped -- the
# hold can outlast the clip, and the last frame is Cody flat and hooked.
_F4_HOOK = dict(foot_r=(-0.08, 0.70, 0.42), foot_l=(0.20, 0.70, 0.14),
                knee_r=(0.0, 0.2, 1.0), knee_l=(0.3, 0.2, 1.0), free_feet=True)
_F4_BACK = dict(ATK_BACK, **_F4_HOOK)
_F4_BRIDGE = dict(_F4_BACK, pelvis=(0.0, 0.02, 0.330), hips=(66, 0, 0),
                  spine=(10, 0, 0), head=(-26, 0, 0),
                  hand_r=(0.42, -0.24, 0.08), hand_l=(-0.42, -0.24, 0.08),
                  foot_r=(-0.08, 0.68, 0.46), foot_l=(0.20, 0.68, 0.16))
CLIPS["Figure_Four_Attacker"] = [
    (0,  P()),
    # Down over his boots, a hand on each ankle.
    (12, P(pelvis=(0.0, -0.08, 0.620), hips=(-44, 0, 0), spine=(-30, 0, 0),
           head=(-6, 0, 0),
           hand_r=(0.14, 0.46, 0.20), hand_l=(-0.14, 0.44, 0.20),
           fist_r=0.6, fist_l=0.6,
           foot_r=(0.22, -0.12, 0.104), foot_l=(-0.20, 0.05, 0.104))),
    # Up with both legs.
    (24, P(pelvis=(0.0, -0.02, 0.800), hips=(-14, 0, 0), spine=(-16, 0, 0),
           head=(-8, 0, 0),
           hand_r=(0.10, 0.44, 0.54), hand_l=(-0.10, 0.42, 0.54),
           fist_r=0.7, fist_l=0.7,
           foot_r=(0.22, -0.10, 0.104), foot_l=(-0.20, 0.02, 0.104))),
    # The cross: his left shin hauled over his right knee.
    (36, P(pelvis=(0.0, 0.00, 0.780), hips=(-12, 10, 0), spine=(-18, 6, 0),
           head=(-12, 0, 0),
           hand_r=(-0.06, 0.48, 0.50), hand_l=(-0.16, 0.36, 0.50),
           fist_r=0.7, fist_l=0.7,
           foot_r=(0.18, 0.02, 0.104), foot_l=(-0.20, 0.04, 0.104))),
    # Stepping in and sitting down through it, still holding the 4.
    (48, dict(pelvis=(0.0, -0.06, 0.460), hips=(22, 0, 0), spine=(-14, 0, 0),
              head=(-10, 0, 0),
              hand_r=(-0.06, 0.46, 0.40), hand_l=(-0.16, 0.34, 0.38),
              elbow_r=(0.7, -0.3, -0.5), elbow_l=(-0.7, -0.3, -0.5),
              fist_r=0.7, fist_l=0.7,
              foot_r=(0.10, 0.40, 0.18), foot_l=(0.02, 0.44, 0.104),
              knee_r=(0.2, 0.6, 0.8), knee_l=(0.2, 0.6, 0.8))),
    # Seated, his right leg coming over the crossed ankle.
    (56, dict(ATK_SEAT, pelvis=(0.0, 0.0, 0.210), hips=(24, 0, 0),
              hand_r=(0.30, -0.12, 0.10), hand_l=(-0.30, -0.12, 0.10),
              **_F4_HOOK)),
    # Flat on his back: locked.
    (62, dict(_F4_BACK)),
    (74, dict(_F4_BRIDGE)),
    (86, dict(_F4_BACK, head=(-18, 0, 0))),
    (108, dict(_F4_BRIDGE, head=(-30, 20, 0))),
    (122, dict(_F4_BACK, hand_r=(0.48, -0.10, 0.30))),
    (128, dict(_F4_BACK, hand_r=(0.50, -0.12, 0.08))),
    (150, dict(_F4_BRIDGE, head=(-24, -16, 0))),
    (164, dict(_F4_BACK)),
    (180, dict(_F4_BACK)),
]
# The man in it. Down_Supine's frame: head +fwd, boots at fwd -0.50, and
# supine, so his RIGHT side is at negative `right`. His left leg is the one
# crossed: its ankle over his right knee, the knee falling out to his left.
_F4_LEGS = dict(foot_r=(-0.10, -0.80, 0.34), foot_l=(-0.12, -0.46, 0.44),
                knee_r=(-0.2, 0.0, 1.0), knee_l=(1.0, 0.0, 0.9), free_feet=True)
_F4_VICTIM = S(**_F4_LEGS)
CLIPS["Figure_Four_Defender"] = [
    (0,  S()),
    (12, S(foot_r=(-0.15, -0.56, 0.16), foot_l=(0.14, -0.54, 0.16),
           free_feet=True)),
    # Hauled up by the ankles.
    (24, S(foot_r=(-0.10, -0.58, 0.50), foot_l=(0.10, -0.56, 0.50),
           knee_r=(-0.3, 0.2, 1.0), knee_l=(0.3, 0.2, 1.0), free_feet=True)),
    # Crossed.
    (36, S(spine=(-12, 0, 0), head=(-20, 0, 0),
           foot_r=(-0.10, -0.64, 0.46), foot_l=(-0.12, -0.50, 0.48),
           knee_r=(-0.3, 0.2, 1.0), knee_l=(1.0, 0.0, 0.6), free_feet=True)),
    (50, S(spine=(-18, 0, 0), head=(-22, 0, 0),
           foot_r=(-0.10, -0.80, 0.30), foot_l=(-0.10, -0.50, 0.34),
           knee_r=(-0.2, 0.0, 1.0), knee_l=(1.0, 0.0, 0.4), free_feet=True)),
    (62, dict(_F4_VICTIM)),
    # The first bridge: he comes up off the mat, a hand thrown up.
    (74, pose(_F4_VICTIM, spine=(-34, 0, 0), head=(-22, 0, 0),
              hand_r=(-0.34, 0.26, 0.46), hand_l=(0.36, 0.10, 0.10))),
    (80, pose(_F4_VICTIM, spine=(-26, 0, 0), head=(-14, 0, 0),
              hand_r=(-0.44, 0.10, 0.08))),
    # Head thrown back into the mat.
    (92, pose(_F4_VICTIM, spine=(-4, 0, 0), head=(6, 0, -16))),
    # Sitting up, reaching down for the leg.
    (108, pose(_F4_VICTIM, spine=(-42, 0, 0), head=(-26, 0, 0),
               hand_r=(-0.16, -0.26, 0.36), hand_l=(0.16, -0.24, 0.36))),
    (122, pose(_F4_VICTIM, spine=(-14, 0, 0), head=(-12, 0, 8),
               hand_l=(0.40, 0.10, 0.36))),
    (128, pose(_F4_VICTIM, spine=(-12, 0, 0), head=(-10, 0, 8),
               hand_l=(0.44, 0.12, 0.08))),
    (140, pose(_F4_VICTIM, spine=(-4, 0, 0), head=(4, 0, 18))),
    (150, pose(_F4_VICTIM, spine=(-36, 0, 0), head=(-24, 0, 0),
               hand_r=(-0.16, -0.22, 0.34), hand_l=(0.16, -0.20, 0.34))),
    (166, pose(_F4_VICTIM, spine=(-10, 0, 0), head=(-10, 0, -8))),
    (180, dict(_F4_VICTIM)),
]

# === Cody's dives (core/match/dive_spot.gd) ===============================
#
# A set piece off the ropes, played by DiveSpot with both men's physics
# frozen, like the entrances: every clip here is keyed in WORLD space
# relative to where it starts (_world_clip), and the director moves the root
# along the clip's root line -- so a hand on the apron, a foot on the rope
# and a boot on the floor stay where the ring puts them. The ring, from
# RingBuilder/ArenaBuilder: the mat at 0, the ropes 3.0 m out (middle 0.85,
# top 1.2), the apron to 3.2, the floor 1.094 below the mat.
FLOOR_DROP = 1.094


def _on_floor(pose_dict, fwd):
    """A standing pose moved down to the floor and `fwd` along."""
    out = dict(pose_dict)
    for k in ("pelvis", "hand_r", "hand_l", "foot_r", "foot_l"):
        if out.get(k):
            x, y, z = out[k]
            out[k] = (x, y + fwd, z - FLOOR_DROP)
    return out


def _unified(keys):
    """Every key given every field any key has: a field missing from a key
    takes the nearest earlier key's value (or the first later one's), so
    _world_clip, which walks the first key's fields, drops none of them."""
    names = []
    for _, k in keys:
        for n in k:
            if n not in names:
                names.append(n)
    out = []
    for i, (f, k) in enumerate(keys):
        full = dict(k)
        for n in names:
            if n in full:
                continue
            prev = [kk[n] for _, kk in keys[:i][::-1] if n in kk]
            nxt = [kk[n] for _, kk in keys[i + 1:] if n in kk]
            full[n] = (prev or nxt)[0]
        out.append((f, full))
    return out


HURT = P(pelvis=(0.0, -0.02, 0.840), hips=(-10, 0, 0), spine=(-16, 0, 0),
         head=(-12, 0, 0),
         hand_r=(0.20, 0.22, 1.10), hand_l=(-0.18, 0.26, 1.20),
         fist_r=0.3, fist_l=0.3)

# Out through the ropes, hurt, facing them: bent over the middle rope, sliding
# through between it and the top rope, hands down to the floor, the legs
# coming over, landing crouched on the floor, standing. 46 frames; the root
# travels 1.55 m out and 1.094 down (his start: 2.35 m out, facing the ropes).
CLIPS["Roll_Out_Ropes"] = _world_clip(46, (1.55, -FLOOR_DROP), _unified([
    (0,  pose(HURT)),
    (10, P(pelvis=(0.0, 0.30, 0.960), hips=(-50, 0, 0), spine=(-30, 0, 0),
           head=(-10, 0, 0),
           hand_r=(0.30, 0.62, 1.20), hand_l=(-0.30, 0.62, 1.20),
           fist_r=0.8, fist_l=0.8,
           foot_r=(0.15, 0.05, 0.104), foot_l=(-0.15, 0.10, 0.104))),
    (18, _body((-82, 0, 0), (0.0, 0.85, 1.00),
               hand_r=(0.25, 0.30, 0.75), hand_l=(-0.25, 0.30, 0.75),
               foot_r=(0.14, 0.10, -0.80), foot_l=(-0.14, 0.05, -0.84),
               knee_r=(0.1, 1.0, 0.0), knee_l=(-0.1, 1.0, 0.0), free_feet=True,
               fist_r=0.2, fist_l=0.2)),
    (26, _body((-60, 0, 0), (0.0, 1.25, 0.20),
               hand_r=(0.25, 0.40, 1.40), hand_l=(-0.25, 0.40, 1.40),
               foot_r=(0.14, 0.40, -0.70), foot_l=(-0.14, 0.30, -0.74),
               knee_r=(0.1, 1.0, 0.3), knee_l=(-0.1, 1.0, 0.3), free_feet=True,
               fist_r=0.1, fist_l=0.1)),
    (34, _on_floor(pose(CROUCH), 1.45)),
    (46, _on_floor(pose(HURT), 1.55)),
]))

# The tope suicida: the run's plant at 1.3 m out, head first between the
# middle and top ropes, into the chest of the man standing on the floor at
# 3.9 m, both down on it; Cody rolls through to his knees and up. 60 frames;
# contact on frame 14 (TOPE_CONTACT). Root 2.6 m out, 1.094 down.
_DIVE = dict(hand_r=(0.18, 0.30, 1.80), hand_l=(-0.18, 0.30, 1.80),
             foot_r=(0.12, -0.05, -0.86), foot_l=(-0.12, -0.10, -0.88),
             knee_r=(0.1, -1.0, 0.0), knee_l=(-0.1, -1.0, 0.0),
             fist_r=0.4, fist_l=0.4, free_feet=True,
             spine=(-6, 0, 0), head=(20, 0, 0))
CLIPS["Tope_Attacker"] = _world_clip(60, (2.6, -FLOOR_DROP), _unified([
    (0,  pose(RUN_B, pelvis=(0.0, 0.10, 0.740), hips=(-24, 0, 0))),
    (4,  _body((-55, 0, 0), (0.0, 0.45, 1.00), **_DIVE)),
    (9,  _body((-92, 0, 0), (0.0, 1.35, 1.05), **_DIVE)),
    (14, _body((-112, 0, 0), (0.0, 1.95, 0.55), **_DIVE)),
    (20, _body((-88, 0, 0), (0.0, 2.45, 0.25 - FLOOR_DROP),
               hand_r=(0.40, 0.60, 1.20), hand_l=(-0.40, 0.60, 1.20),
               foot_r=(0.16, -0.10, -0.86), foot_l=(-0.16, -0.12, -0.88),
               knee_r=(0.1, -1.0, 0.0), knee_l=(-0.1, -1.0, 0.0),
               free_feet=True, fist_r=0.1, fist_l=0.1)),
    (36, _on_floor(pose(ONE_KNEE), 2.55)),
    (48, _on_floor(pose(CROUCH), 2.60)),
    (60, _on_floor(P(), 2.60)),
]))
# Standing hurt on the floor facing the ring; taken in the chest on frame 14,
# flat on his back away from the ring, down, and up again. 170 frames.
CLIPS["Tope_Defender"] = [
    (0,  pose(HURT)),
    (8,  pose(HURT, head=(-2, 0, 0), spine=(-6, 0, 0))),
] + _back_fall(14, 44, pelvis_hit=0.84) + [
    (110, dict(SUPINE_AWAY)),
] + _get_up(118, 170, lying=True)

# Back in under the bottom rope from the floor: hands up onto the apron,
# prone and rolled in under the rope, to a knee on the mat, up. 60 frames;
# root 1.3 m in, 1.094 up (his start: on the floor 3.6 m out, facing in).
_PRONE_IN = dict(hand_r=(0.30, 0.25, 0.60), hand_l=(-0.30, 0.25, 0.60),
                 foot_r=(0.14, 0.05, -0.84), foot_l=(-0.14, 0.02, -0.86),
                 knee_r=(0.1, -1.0, 0.0), knee_l=(-0.1, -1.0, 0.0),
                 free_feet=True, fist_r=0.2, fist_l=0.2)
CLIPS["Roll_In"] = _world_clip(60, (1.3, FLOOR_DROP), _unified([
    (0,  pose(HURT)),
    (10, P(pelvis=(0.0, 0.10, 0.800), hips=(-40, 0, 0), spine=(-20, 0, 0),
           hand_r=(0.25, 0.45, FLOOR_DROP + 0.02), hand_l=(-0.25, 0.45, FLOOR_DROP + 0.02),
           fist_r=0.1, fist_l=0.1)),
    (20, _body((-86, 0, 0), (0.0, 0.55, FLOOR_DROP + 0.18), **_PRONE_IN)),
    (30, _body((-86, 0, 0), (0.0, 1.05, FLOOR_DROP + 0.18), **_PRONE_IN)),
    (44, _shifted(ONE_KNEE, 1.25, FLOOR_DROP)),
    (60, _shifted(P(), 1.30, FLOOR_DROP)),
]))

# Up onto the apron from the floor: hands on its edge, a knee up, a foot up,
# standing on it holding the top rope. 36 frames; root 0.45 in, 1.094 up.
CLIPS["Apron_Climb"] = _world_clip(36, (0.45, FLOOR_DROP), _unified([
    (0,  P()),
    (8,  P(pelvis=(0.0, 0.10, 0.800), hips=(-24, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.28, 0.40, FLOOR_DROP + 0.02), hand_l=(-0.28, 0.40, FLOOR_DROP + 0.02),
           fist_r=0.2, fist_l=0.2)),
    (16, P(pelvis=(0.0, 0.22, 1.300), hips=(-40, 0, 0), spine=(-20, 0, 0),
           hand_r=(0.28, 0.50, FLOOR_DROP + 0.30), hand_l=(-0.28, 0.50, FLOOR_DROP + 0.30),
           foot_r=(0.15, 0.40, FLOOR_DROP + 0.10), knee_r=(0.1, 1.0, 0.2),
           foot_l=(-0.15, 0.05, 0.104), free_feet=True,
           fist_r=0.6, fist_l=0.6)),
    (26, P(pelvis=(0.0, 0.40, FLOOR_DROP + 0.70), hips=(-20, 0, 0), spine=(-10, 0, 0),
           hand_r=(0.30, 0.55, FLOOR_DROP + 1.20), hand_l=(-0.30, 0.55, FLOOR_DROP + 1.20),
           foot_r=(0.15, 0.42, FLOOR_DROP + 0.104), foot_l=(-0.15, 0.40, FLOOR_DROP + 0.20),
           free_feet=True, fist_r=0.8, fist_l=0.8)),
    (36, _shifted(P(hand_r=(0.30, 0.10, 1.20), hand_l=(-0.30, 0.10, 1.20),
                    fist_r=0.8, fist_l=0.8), 0.45, FLOOR_DROP)),
]))

# The springboard Disaster Kick: from the apron facing in, a foot up onto the
# middle rope, springing off it, spinning a full turn in the air, the right
# leg sweeping round into the head of the man standing inside at 1.95 m out
# on frame 24 (SPRINGBOARD_CONTACT), landing inside and standing. 48 frames;
# root 0.85 in. The spin is bone pose, keyed in steps of at most 60 degrees.
def _spring_air(yaw, pelvis, **over):
    base = dict(pelvis=pelvis, hips=(-6, yaw, 0), spine=(-6, 0, 0), head=(4, 0, 0),
                hand_r=(0.30, 0.0, 0.0), hand_l=(-0.30, 0.0, 0.0),
                fist_r=0.7, fist_l=0.7)
    arms = _body((-6, yaw, 0), pelvis,
                 hand_r=(0.45, 0.05, 0.40), hand_l=(-0.45, 0.05, 0.40),
                 foot_r=(0.16, 0.20, -0.45), foot_l=(-0.16, 0.10, -0.50),
                 knee_r=(0.2, 1.0, 0.0), knee_l=(-0.2, 1.0, 0.0), free_feet=True)
    base.update({k: v for k, v in arms.items() if k not in ("hips", "pelvis")})
    base.update(over)
    return base


# The hands are ON the top rope and the boot ON the middle one, 0.05 in front
# of the root (the apron stands 0.05 outside the rope line): a boot 0.14 in
# never touched the rope, and with live ropes (core/ring/ring_ropes.gd) a
# springboard that does not press the rope down reads as a man jumping off
# nothing. Weighted, the boot takes the middle rope ~0.12 m down.
CLIPS["Springboard_DK_Attacker"] = _world_clip(48, (0.85, 0.0), _unified([
    (0,  P(hand_r=(0.30, 0.06, 1.25), hand_l=(-0.30, 0.06, 1.25),
           fist_r=0.8, fist_l=0.8)),
    # A boot onto the middle rope beside the post-side hand.
    (8,  P(pelvis=(0.0, 0.05, 1.050), hips=(-10, 0, 0), spine=(-14, 0, 0),
           hand_r=(0.30, 0.08, 1.24), hand_l=(-0.30, 0.08, 1.24),
           foot_r=(0.12, 0.06, 0.80), knee_r=(0.1, 1.0, 0.4),
           foot_l=(-0.14, -0.02, 0.104), free_feet=True,
           fist_r=0.8, fist_l=0.8)),
    # Sprung.
    (13, _spring_air(0, (0.0, 0.30, 1.75))),
    (16, _spring_air(-60, (0.0, 0.40, 1.85))),
    (18, _spring_air(-120, (0.0, 0.48, 1.88))),
    (20, _spring_air(-180, (0.0, 0.55, 1.86))),
    (22, _spring_air(-240, (0.0, 0.60, 1.80))),
    # CONTACT: his right side to the man, the leg straight into the head.
    (24, _spring_air(-270, (0.0, 0.62, 1.72),
                     foot_r=(0.0, 1.20, 1.72), knee_r=(0.0, 0.3, 1.0))),
    (28, _spring_air(-320, (0.0, 0.72, 1.40))),
    (32, _spring_air(-360, (0.0, 0.80, 1.05))),
    (38, _shifted(pose(CROUCH), 0.85, 0.0)),
    (48, _shifted(P(), 0.85, 0.0)),
]))

# The face-off before the bell: nose to nose in the middle of the ring, square
# on, chest up and chin down, arms hanging loose a hand's width off the hips,
# hands half closed. Nothing guarded about it -- the owner's note was that the
# grapple crouch (Idle_Ready) read as ridiculous here; a stare-down is two men
# standing TALL. Alive, not frozen: a slow breath lifts the chest and the
# head settles a touch lower on the exhale. 90 frames, looping.
FACE_OFF = dict(
    pelvis=(0.0, 0.01, 0.905), hips=(0, 0, 0), spine=(3, 0, 0), head=(-7, 0, 0),
    hand_r=(0.27, 0.00, 0.93), hand_l=(-0.27, 0.00, 0.93),
    elbow_r=(0.6, -0.4, -1.0), elbow_l=(-0.6, -0.4, -1.0),
    fist_r=0.55, fist_l=0.55,
    foot_r=(0.17, -0.02, 0.104), foot_l=(-0.17, 0.02, 0.104),
)
CLIPS["Face_Off"] = [
    (0,  FACE_OFF),
    (40, pose(FACE_OFF, pelvis=(0.0, 0.01, 0.911), spine=(6, 0, 0), head=(-5, 0, 0),
              hand_r=(0.28, 0.00, 0.94), hand_l=(-0.28, 0.00, 0.94))),
    (65, pose(FACE_OFF, head=(-8, 1, 0))),
    (90, FACE_OFF),
]


# === The referee (core/match/referee_actor.gd) ===========================
#
# Aubrey Edwards (assets/characters/aubrey_edwards.glb) is rigged on this same
# skeleton, so her clips are authored here like everyone else's. Real refs,
# watched off broadcast footage (gauntlet/refs/referee.md): upright and still
# while the two men are on their feet, bent with the hands on the knees when
# the action goes to the mat, and for a cover DOWN -- on both knees beside the
# pinned man's shoulders, chest low, the left hand posted and the right arm
# coming high and slapping the canvas on each count. Then up, the arm waved
# over the head for the bell, and the winner's hand raised.

# Upright between exchanges: square, weight even, arms loose.
REF_STAND = dict(
    pelvis=(0.0, 0.0, 0.900), hips=(0, 0, 0), spine=(-4, 0, 0), head=(-4, 0, 0),
    hand_r=(0.24, 0.04, 0.90), hand_l=(-0.24, 0.04, 0.90),
    elbow_r=(0.6, -0.4, -1.0), elbow_l=(-0.6, -0.4, -1.0),
    fist_r=0.3, fist_l=0.3,
    foot_r=(0.15, -0.02, 0.104), foot_l=(-0.15, 0.02, 0.104),
)
# Watching the mat: knees bent, chest over them, hands on the thighs just
# above the knee.
REF_WATCH = dict(
    pelvis=(0.0, -0.06, 0.780), hips=(-10, 0, 0), spine=(-28, 0, 0), head=(18, 0, 0),
    hand_r=(0.15, 0.26, 0.64), hand_l=(-0.15, 0.26, 0.64),
    elbow_r=(1.0, -0.2, 0.0), elbow_l=(-1.0, -0.2, 0.0),
    fist_r=0.1, fist_l=0.1,
    foot_r=(0.19, 0.0, 0.104), foot_l=(-0.19, 0.0, 0.104),
)
# Down for the count: both knees on the canvas, chest low over them, the
# head up to see the shoulders; the left hand posted, the right ready.
REF_LOW = dict(
    pelvis=(0.0, 0.0, 0.420), hips=(-34, 0, 0), spine=(-50, 0, 0), head=(46, 0, 0),
    hand_r=(0.24, 0.50, 0.10), hand_l=(-0.22, 0.50, 0.07),
    elbow_r=(1.0, 0.0, 0.2), elbow_l=(-1.0, 0.0, 0.2),
    fist_r=0.1, fist_l=0.1,
    foot_r=(0.15, -0.42, 0.08), foot_l=(-0.15, -0.42, 0.08),
    knee_r=(0.0, 1.0, -0.4), knee_l=(0.0, 1.0, -0.4),
)
# Halfway down (and up): one knee going to the mat.
REF_DROP = pose(REF_WATCH, pelvis=(0.0, -0.10, 0.600), spine=(-36, 0, 0),
                hand_r=(0.20, 0.40, 0.40), hand_l=(-0.20, 0.42, 0.36),
                foot_r=(0.16, -0.30, 0.10), knee_r=(0.0, 1.0, -0.6),
                # The left foot already coming back off the canvas, so the
                # kneel that follows never drags it through (_REF_KNEEL_L).
                foot_l=(-0.18, -0.10, 0.12))

CLIPS["Ref_Stand"] = [
    (0,  REF_STAND),
    (45, pose(REF_STAND, pelvis=(0.0, 0.0, 0.905), spine=(-2, 0, 0), head=(-2, 3, 0))),
    (90, REF_STAND),
]
CLIPS["Ref_Watch"] = [
    (0,  REF_WATCH),
    (45, pose(REF_WATCH, pelvis=(0.0, -0.06, 0.770), head=(20, -4, 0))),
    (90, REF_WATCH),
]
# The left foot on its way back under her as the second knee goes down: just
# off the canvas (z 0.12), which keeps the rig's flat-sole rule on it so every
# key holds the same foot angle and nothing pitches the toes into the mat. Between REF_DROP and REF_LOW the solver otherwise
# swings the trailing foot through the canvas (pose lint: ball_l 0.15 m below
# the mat at mid-drop) -- the knee hint flips from forward to down while the
# foot travels 0.42 m back.
_REF_KNEEL_L = pose(REF_LOW, pelvis=(0.0, -0.06, 0.500), spine=(-44, 0, 0),
                    foot_l=(-0.16, -0.28, 0.12), knee_l=(0.0, 1.0, -0.2))
# 14 frames: from the watch crouch to REF_LOW.
CLIPS["Ref_Count_Down"] = [
    (0,  REF_WATCH),
    (6,  REF_DROP),
    (10, _REF_KNEEL_L),
    (14, REF_LOW),
]
# 20 frames, one count: the arm comes up high, and the palm hits the canvas
# on frame 12 -- RefereeActor starts it 12 frames before each count tick.
CLIPS["Ref_Slap"] = [
    (0,  REF_LOW),
    (7,  pose(REF_LOW, spine=(-38, 0, 0), hand_r=(0.32, 0.36, 1.02), elbow_r=(1.0, 0.0, 0.6),
              fist_r=0.0)),
    (12, pose(REF_LOW, spine=(-56, 0, 0), head=(52, 0, 0), hand_r=(0.24, 0.56, 0.05), fist_r=0.0)),
    (15, pose(REF_LOW, spine=(-53, 0, 0), hand_r=(0.25, 0.52, 0.14), fist_r=0.0)),
    (20, REF_LOW),
]
CLIPS["Ref_Count_Up"] = [
    (0,  REF_LOW),
    (4,  _REF_KNEEL_L),
    (8,  REF_DROP),
    (16, REF_STAND),
]
# 36 frames: the bell -- the right arm up and waved over the head twice.
_BELL_UP = pose(REF_STAND, spine=(2, 0, 0), head=(6, 0, 0),
                hand_r=(0.10, 0.10, 1.95), elbow_r=(1.0, 0.0, 0.3), fist_r=0.0)
CLIPS["Ref_Call_Bell"] = [
    (0,  REF_STAND),
    (6,  _BELL_UP),
    (12, pose(_BELL_UP, hand_r=(0.42, 0.10, 1.86))),
    (18, _BELL_UP),
    (24, pose(_BELL_UP, hand_r=(0.42, 0.10, 1.86))),
    (30, _BELL_UP),
    (36, REF_STAND),
]
# 60 frames, looping from 10: the winner's hand -- her right arm straight up
# beside him, her left at her side, square to the hard camera.
_RAISE = pose(REF_STAND, spine=(3, 0, 0), head=(4, 6, 0),
              hand_r=(0.30, 0.06, 1.93), elbow_r=(1.0, 0.0, 0.2), fist_r=0.6)
CLIPS["Ref_Raise_Hand"] = [
    (0,  REF_STAND),
    (10, _RAISE),
    (35, pose(_RAISE, hand_r=(0.31, 0.07, 1.96), head=(4, 10, 0))),
    (60, _RAISE),
]

# Off the ropes (gauntlet/refs/ropes.md): the last stride turns him side-on,
# the rope-side arm goes over the top rope, and his hip and ribs take the
# middle and top ropes. The ropes give -- the pelvis carries on 0.30 m past
# the rope line at the deepest -- and then throw him back: he pushes off the
# outside foot, lets go of the rope and comes out running the other way.
# 20 frames. The root stays put, 0.5 m inside the ropes, facing them; the
# body turns through 180 degrees in bone pose, so he ends running AWAY from
# the root's facing (the director turns the root round on a cut after it).
REBOUND_ROPE = 0.50
_REBOUND_RUN_OUT = dict(
    pelvis=(0.0, -0.06, 0.800), hips=(-14, 180, 0), spine=(-18, 0, 0),
    head=(8, 0, 0),
    hand_r=(-0.26, -0.30, 1.04), hand_l=(0.20, -0.10, 1.00),
    foot_r=(-0.16, -0.26, 0.104), foot_l=(0.14, 0.30, 0.20),
    fist_r=0.7, fist_l=0.7)
CLIPS["Rope_Rebound"] = _world_clip(20, (0.0, 0.0), _unified([
    (0,  pose(RUN_B)),
    # The turn: planting the rope-side foot, the other already coming round.
    (3,  pose(RUN_B, pelvis=(0.0, 0.30, 0.820), hips=(-8, 50, 0), spine=(-8, 0, 0),
              hand_r=(0.10, 0.52, 1.30), hand_l=(-0.22, 0.30, 1.06),
              foot_r=(0.10, 0.40, 0.104), foot_l=(-0.10, 0.12, 0.20))),
    # Contact: hip on the middle rope, ribs on the top, arm hooked over it.
    (5,  P(pelvis=(0.0, REBOUND_ROPE + 0.02, 0.840), hips=(0, 90, 0),
           spine=(4, 0, 0), head=(4, 0, 0),
           hand_r=(0.00, REBOUND_ROPE + 0.10, 1.27), hand_l=(-0.32, 0.36, 1.08),
           fist_r=0.9, fist_l=0.5,
           foot_r=(0.08, 0.46, 0.104), foot_l=(-0.10, 0.16, 0.104))),
    # Deepest: the ropes wrapped round his side, leaning back into them.
    (8,  P(pelvis=(0.0, REBOUND_ROPE + 0.30, 0.820), hips=(0, 96, 0),
           spine=(9, 0, 0), head=(8, 0, 0),
           hand_r=(0.00, REBOUND_ROPE + 0.40, 1.20), hand_l=(-0.28, 0.62, 1.04),
           fist_r=0.9, fist_l=0.5,
           foot_r=(0.08, 0.46, 0.104), foot_l=(-0.10, 0.16, 0.104))),
    # Thrown back: the ropes return him, still holding on.
    (11, P(pelvis=(0.0, REBOUND_ROPE, 0.840), hips=(-6, 118, 0),
           spine=(0, 0, 0), head=(4, 0, 0),
           hand_r=(0.00, REBOUND_ROPE + 0.08, 1.26), hand_l=(-0.20, 0.26, 1.08),
           fist_r=0.9, fist_l=0.6,
           foot_r=(0.08, 0.46, 0.104), foot_l=(-0.10, 0.16, 0.104))),
    # Off the outside foot, the hand leaving the rope.
    (14, P(pelvis=(0.0, 0.24, 0.810), hips=(-14, 155, 0),
           spine=(-14, 0, 0), head=(6, 0, 0),
           hand_r=(-0.05, 0.40, 1.18), hand_l=(0.10, 0.02, 1.04),
           fist_r=0.7, fist_l=0.7,
           foot_r=(0.02, 0.30, 0.22), foot_l=(-0.06, 0.16, 0.104))),
    (20, _REBOUND_RUN_OUT),
]))


# --- build ----------------------------------------------------------------

# === Chain wrestling (gauntlet/refs/animation_gap.md, Phase 4) ============
#
# The holds two men trade out of a lock-up before anybody throws anything:
# a side headlock, a wristlock, a go-behind to a rear waistlock. Each is one
# LINK -- into the hold, cranked twice, the other man fights free, both square
# up again -- 54 frames / 1.8 s, and WrestlerController strings links
# together, the holder steering which comes next with the stick and the man
# in it reversing to take over. Both halves are keyed against each other
# beat for beat, on the trajectories in paired_recipes.gd:
#
#   frames  0-12  into the hold
#          12-38  held: cranked at 20 and 32
#          38-44  he fights free
#          44-54  squared up again, about 0.9 m apart
#
# Frame 0 and frame 54 are both the stance, so any link follows any other.

# SIDE HEADLOCK. The holder pivots in beside him and turns to face the way
# he faces, the other man's head under his right arm at his hip; the man in
# it is bent double beside him, pushing at his back. Held from frame 12.
_HL_A = dict(pelvis=(0.0, 0.0, 0.830), hips=(-6, 10, 8), spine=(-16, 12, 12),
             head=(10, 16, 0),
             hand_r=(0.14, 0.24, 0.98), hand_l=(0.02, 0.24, 1.00),
             elbow_r=(0.8, -0.4, 0.2), elbow_l=(-0.6, -0.3, -0.5),
             fist_r=0.5, fist_l=0.5,
             foot_r=(0.28, -0.10, 0.104), foot_l=(-0.20, 0.12, 0.104))
_HL_D = dict(pelvis=(0.0, -0.12, 0.740), hips=(-40, 0, 0), spine=(-58, -8, 0),
             head=(24, -30, 0),
             hand_r=(0.04, 0.44, 0.70), hand_l=(-0.28, 0.34, 0.78),
             elbow_r=(0.6, -0.3, -0.6), elbow_l=(-0.8, -0.2, -0.5),
             fist_r=0.4, fist_l=0.3,
             foot_r=(0.26, -0.24, 0.104), foot_l=(-0.24, -0.06, 0.104))

CLIPS["Chain_Headlock_Attacker"] = [
    (0,  P()),
    (6,  P(pelvis=(0.0, 0.04, 0.820), hips=(-6, 20, 0), spine=(-18, 24, 0),
           hand_r=(0.20, 0.40, 1.20), hand_l=(-0.06, 0.40, 1.16),
           foot_r=(0.24, 0.02, 0.104), foot_l=(-0.18, 0.14, 0.104))),
    (12, pose(_HL_A)),
    # The crank: he sits down into it and wrenches the head up and in.
    (20, pose(_HL_A, pelvis=(0.0, 0.0, 0.800), spine=(-22, 16, 18),
              hand_r=(0.14, 0.22, 1.02), hand_l=(0.02, 0.22, 1.04))),
    (26, pose(_HL_A)),
    (32, pose(_HL_A, pelvis=(0.0, 0.0, 0.795), spine=(-24, 18, 20),
              hand_r=(0.14, 0.22, 1.03), hand_l=(0.02, 0.22, 1.05))),
    (38, pose(_HL_A)),
    # Shoved off his back: grip gone, arms out, a stumble step forward.
    (44, P(pelvis=(0.0, 0.08, 0.840), hips=(-4, 0, 0), spine=(-14, 0, 0),
           head=(8, 0, 0),
           hand_r=(0.30, 0.34, 1.10), hand_l=(-0.28, 0.36, 1.12), fist_r=0.3, fist_l=0.3,
           foot_r=(0.24, 0.10, 0.104), foot_l=(-0.20, 0.30, 0.140))),
    (54, P()),
]

CLIPS["Chain_Headlock_Defender"] = [
    (0,  P()),
    (6,  P(pelvis=(0.0, -0.04, 0.820), hips=(-14, 0, 0), spine=(-30, -4, 0),
           head=(10, -16, 0),
           hand_r=(0.14, 0.44, 1.10), hand_l=(-0.20, 0.40, 1.14),
           foot_r=(0.26, -0.22, 0.104), foot_l=(-0.24, 0.02, 0.104))),
    (12, pose(_HL_D)),
    # Wrenched: his head goes lower and his feet dig in.
    (20, pose(_HL_D, pelvis=(0.0, -0.14, 0.725), spine=(-62, -10, 0), head=(28, -34, 0))),
    (26, pose(_HL_D)),
    (32, pose(_HL_D, pelvis=(0.0, -0.14, 0.722), spine=(-64, -10, 0), head=(28, -34, 0))),
    (38, pose(_HL_D, hand_l=(-0.28, 0.36, 0.86), hand_r=(-0.06, 0.42, 0.82))),
    # Fights free: straightens up out of it, both hands driving into his back.
    (44, P(pelvis=(0.0, -0.02, 0.830), hips=(-10, 0, 0), spine=(-22, 0, 0),
           head=(4, 0, 0),
           hand_r=(0.10, 0.56, 1.18), hand_l=(-0.18, 0.54, 1.18),
           elbow_r=(0.6, -0.3, -0.6), elbow_l=(-0.6, -0.3, -0.6),
           fist_r=0.2, fist_l=0.2,
           foot_r=(0.26, -0.16, 0.104), foot_l=(-0.24, 0.12, 0.104))),
    (54, P()),
]

# WRISTLOCK. The holder takes the other man's right wrist in both hands and
# turns it over; he turns away from it, arm straight out to his right and
# bent over it, his other hand clutching the shoulder. Held from frame 12.
_WL_A = dict(pelvis=(0.0, 0.0, 0.840), hips=(-4, 8, 0), spine=(-14, 12, 0),
             head=(6, 6, 0),
             hand_r=(0.06, 0.40, 1.04), hand_l=(-0.06, 0.38, 1.02),
             elbow_r=(0.7, -0.4, -0.5), elbow_l=(-0.7, -0.4, -0.5),
             fist_r=0.6, fist_l=0.6,
             foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.16, 0.104))
_WL_D = dict(pelvis=(0.0, 0.0, 0.820), hips=(-10, 12, -4), spine=(-28, 16, -10),
             head=(8, 30, 0),
             hand_r=(0.72, 0.06, 1.06), hand_l=(0.10, 0.16, 1.30),
             elbow_r=(0.2, -0.3, -0.9), elbow_l=(-0.5, 0.2, -0.8),
             fist_r=0.3, fist_l=0.5,
             foot_r=(0.30, 0.00, 0.104), foot_l=(-0.20, 0.10, 0.104))

CLIPS["Chain_Wristlock_Attacker"] = [
    (0,  P()),
    (6,  P(hand_r=(0.10, 0.52, 1.10), hand_l=(-0.02, 0.50, 1.08), fist_r=0.4, fist_l=0.4)),
    (12, pose(_WL_A)),
    # The twist: he turns the wrist over with his whole upper body.
    (20, pose(_WL_A, hips=(-4, 16, 0), spine=(-16, 26, 0),
              hand_r=(0.10, 0.38, 1.10), hand_l=(-0.02, 0.36, 1.08))),
    (26, pose(_WL_A)),
    (32, pose(_WL_A, hips=(-4, 18, 0), spine=(-16, 28, 0),
              hand_r=(0.10, 0.38, 1.12), hand_l=(-0.02, 0.36, 1.10))),
    (38, pose(_WL_A)),
    # He loses it: the arm is ripped back out of his hands.
    (44, P(pelvis=(0.0, -0.04, 0.850), hips=(2, 0, 0), spine=(-6, 0, 0),
           hand_r=(0.18, 0.44, 1.12), hand_l=(-0.16, 0.42, 1.10), fist_r=0.3, fist_l=0.3)),
    (54, P()),
]

CLIPS["Chain_Wristlock_Defender"] = [
    (0,  P()),
    (6,  P(hand_r=(0.20, 0.50, 1.14), fist_r=0.3)),
    (12, pose(_WL_D)),
    # Turned over: up onto the toes and further round the arm.
    (20, pose(_WL_D, pelvis=(0.0, 0.0, 0.850), spine=(-34, 20, -16), head=(12, 36, 0),
              hand_r=(0.72, 0.04, 1.12), ankle_r=(18, 0, 0), ankle_l=(18, 0, 0),
              foot_r=(0.30, 0.00, 0.120), foot_l=(-0.20, 0.10, 0.120))),
    (26, pose(_WL_D)),
    (32, pose(_WL_D, pelvis=(0.0, 0.0, 0.852), spine=(-36, 22, -16), head=(12, 38, 0),
              hand_r=(0.72, 0.04, 1.13), ankle_r=(18, 0, 0), ankle_l=(18, 0, 0),
              foot_r=(0.30, 0.00, 0.120), foot_l=(-0.20, 0.10, 0.120))),
    (38, pose(_WL_D)),
    # Rips it free and comes round to face him.
    (44, P(pelvis=(0.0, -0.02, 0.840), hips=(-6, 10, 0), spine=(-16, 14, 0),
           hand_r=(0.40, 0.20, 1.10), hand_l=(-0.14, 0.30, 1.20), fist_r=0.4)),
    (54, P()),
]

# GO-BEHIND TO A REAR WAISTLOCK. The holder ducks and circles round his left
# side to his back and locks his hands round the waist, cheek on his back;
# the man in it pries at the hands. Held from frame 14, when he is behind.
_WA_A = dict(pelvis=(0.0, -0.04, 0.750), hips=(-12, 0, 0), spine=(-28, 0, 0),
             head=(6, 24, 0),
             hand_r=(0.12, 0.44, 0.96), hand_l=(-0.12, 0.44, 0.96),
             elbow_r=(0.8, -0.2, -0.3), elbow_l=(-0.8, -0.2, -0.3),
             fist_r=0.5, fist_l=0.5,
             foot_r=(0.26, -0.20, 0.104), foot_l=(-0.24, 0.02, 0.104))
_WA_D = dict(pelvis=(0.0, 0.02, 0.830), hips=(-6, 0, 0), spine=(-14, 0, 0),
             head=(10, 0, 0),
             hand_r=(0.14, 0.24, 0.98), hand_l=(-0.14, 0.24, 0.98),
             elbow_r=(0.9, -0.1, -0.3), elbow_l=(-0.9, -0.1, -0.3),
             fist_r=0.6, fist_l=0.6,
             foot_r=(0.26, -0.06, 0.104), foot_l=(-0.24, 0.10, 0.104))

CLIPS["Chain_Waistlock_Attacker"] = [
    (0,  P()),
    # Ducks under and goes round, low.
    (6,  P(pelvis=(0.0, 0.04, 0.740), hips=(-18, 0, 0), spine=(-30, 0, 0),
           head=(16, 0, 0), hand_r=(0.26, 0.30, 1.00), hand_l=(-0.24, 0.32, 1.00),
           foot_r=(0.22, 0.10, 0.160), foot_l=(-0.22, -0.10, 0.104))),
    (10, P(pelvis=(0.0, 0.04, 0.760), hips=(-16, 0, 0), spine=(-26, 0, 0),
           head=(14, 10, 0), hand_r=(0.24, 0.36, 1.00), hand_l=(-0.22, 0.38, 1.00),
           foot_r=(0.22, -0.10, 0.104), foot_l=(-0.22, 0.12, 0.160))),
    (17, pose(_WA_A)),
    # The squeeze: hips in under him, a lift off the mat that does not come.
    (22, pose(_WA_A, pelvis=(0.0, 0.03, 0.760), hips=(-4, 0, 0), spine=(-10, 0, 0),
              hand_r=(0.12, 0.42, 1.00), hand_l=(-0.12, 0.42, 1.00))),
    (28, pose(_WA_A)),
    (34, pose(_WA_A, pelvis=(0.0, 0.03, 0.758), hips=(-4, 0, 0), spine=(-10, 0, 0),
              hand_r=(0.12, 0.42, 1.01), hand_l=(-0.12, 0.42, 1.01))),
    (38, pose(_WA_A)),
    # The grip is broken and he is left holding air.
    (44, P(pelvis=(0.0, -0.02, 0.830), hips=(-6, 0, 0), spine=(-12, 0, 0),
           hand_r=(0.26, 0.40, 1.02), hand_l=(-0.26, 0.40, 1.02), fist_r=0.3, fist_l=0.3)),
    (54, P()),
]

CLIPS["Chain_Waistlock_Defender"] = [
    (0,  P()),
    # Looks for him as he goes round.
    (8,  P(head=(2, -40, 0), spine=(-10, -10, 0))),
    (14, pose(_WA_D)),
    # Squeezed: lifted onto his toes, hands still at the grip.
    (22, pose(_WA_D, pelvis=(0.0, 0.02, 0.850), spine=(-6, 0, 0), head=(16, 0, 0),
              ankle_r=(20, 0, 0), ankle_l=(20, 0, 0),
              foot_r=(0.26, -0.06, 0.124), foot_l=(-0.24, 0.10, 0.124))),
    (28, pose(_WA_D)),
    (34, pose(_WA_D, pelvis=(0.0, 0.02, 0.852), spine=(-6, 0, 0), head=(16, 0, 0),
              ankle_r=(20, 0, 0), ankle_l=(20, 0, 0),
              foot_r=(0.26, -0.06, 0.124), foot_l=(-0.24, 0.10, 0.124))),
    (38, pose(_WA_D, hand_r=(0.20, 0.20, 0.94), hand_l=(-0.20, 0.20, 0.94))),
    # Pries the hands apart and turns out of it.
    (44, P(pelvis=(0.0, 0.04, 0.830), hips=(-6, 0, 0), spine=(-12, 0, 0),
           head=(6, -20, 0),
           hand_r=(0.34, 0.14, 0.92), hand_l=(-0.34, 0.14, 0.92), fist_r=0.5, fist_l=0.5)),
    (54, P()),
]


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
