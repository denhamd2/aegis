class_name EntranceDirector
extends Node
## The ring entrances: both men walk out from the stage, down the ramp, up the
## ring steps and through the ropes to their marks, before the bell.
##
## Presentation only, and built so the match cannot tell it happened.
##
## * Everything that plays the match is frozen for the duration -- both
##   wrestlers, their AI, the referee, the grapple rig -- with the same
##   set_physics_process(false) the match end already uses. The referee is the
##   only thing that advances ReplaySystem's tick, and match_setup does not
##   start recording until `bell`, so tick 0 is the bell either way.
## * The wrestlers are moved kinematically. There is no collision anywhere
##   outside the ring -- the stage, ramp and floor are visual only, and
##   keep_inside_the_ring() would snap a man on the ramp back onto the mat --
##   so with their physics frozen the director places the root on each
##   surface's own height, read from ArenaBuilder's constants.
## * Every placement is a pure function of the tick count, so the whole
##   entrance is deterministic and the same every time.
##
## match_setup builds this only when its `entrances` flag is on, which only
## the title screen does. Tests, probes, captures and art shots never see it.
##
## Enter, Space or a pad's A (ui_accept) skips to the bell.

signal bell
## Each beat as it starts, with the shot it is on (SignFans stands up for the
## stare-down's).
signal beat_started(shot: String)
## Every cue a beat fires (pyro, tron, lights), for the sound (MatchAudio).
signal cue(what: String)

# --- Pace and the travelling clips (tools/blender/wrestling_clips.py) --------
## The speed Entrance_Walk's planted foot travels at. Must match the clip.
const WALK_SPEED := 1.6
## Climb_Steps: 1.2 s, the root travelling (fwd 1.26, up 0.86) -- three
## treads of the ring steps, bottom-of-flight floor to top-tread centre.
const CLIMB_SECONDS := 1.2
const CLIMB_TO := Vector2(1.26, 0.86)
## How fast a turn on the spot goes, radians per second.
const TURN_RATE := 5.0

## Apron_Step: 1.0 s, off the top tread and up onto the apron beside the
## post, (fwd 1.0, up 0.24). Rope_Step_Through_Apron: 1.33 s, from the apron
## edge through the ropes onto the mat, (fwd 0.62, up 0).
const APRON_STEP_SECONDS := 1.0
const APRON_ROPE_SECONDS := 1.333
const APRON_ROPE_TO := Vector2(0.62, 0.0)

# --- Where things are ---------------------------------------------------------
## The flight every entrance climbs: the one on the corner diagonal at the
## hard camera's top left, (+3, -3), on the entrance side (ring_builder.gd
## "Steel steps"). He walks in along the diagonal, climbs toward the post,
## steps up onto the apron beside it, and goes through the ropes a pace along
## the -Z side from the post -- never through the post itself.
const ENTRY_CORNER := Vector2(1.0, -1.0)
## Where on the apron he goes through the ropes: this far along the side
## from the post, and on the apron's standing strip (3.0 .. 3.2).
const APRON_ALONG_M := 0.55
const APRON_STAND := 3.12
## Straight out along the diagonal from the climb's start, so he arrives
## square to the flight rather than cutting its corner.
const APPROACH_M := 0.8
## Where the ramp's cut lands him: a few metres short of the ramp foot, in the
## ringside shot. The full 24 m ramp at walking pace would be fifteen seconds
## of one shot; a broadcast cuts it, and so does this.
const CUT_TO_Z := -9.0
## How much of the ramp the tracking shot follows before the cut, in seconds.
const RAMP_SHOWN_SECONDS := 6.0

# --- Timing (ticks at 60 Hz) --------------------------------------------------
const TPS := 60
const OPENING_TICKS := 150
## The stage pose: Win_Celebrate (1.3 s) and a beat after it.
const POSE_TICKS := 114
## Held at his mark, turned to face the ring, before the next man.
const SETTLE_TICKS := 40
## Between the two entrances: the first man's music fades out
## (StageVideo.ENTRANCE_FADE_SECONDS) and the room holds a beat before the
## next man's starts.
const HANDOVER_TICKS := 165
## The face-off before the bell (the owner: "just have them walk up to each
## other to do a face off, then the bell rings"). Both walk in off their
## marks until they are FACEOFF_GAP apart, centre to centre -- chest to chest
## less a hand, as a stare-down is -- hold it, then turn and walk back to
## their marks and turn round, where the bell finds them. The match starts on
## the marks, exactly as it did, so nothing downstream moves.
const FACEOFF_GAP := 0.75
const FACEOFF_WALK_SPEED := 0.9
## Long enough for the stare-down's sequence (FACEOFF_SEQ): the locked-off
## profile, the two over-the-shoulders, the eye cuts and the low hero shot.
const FACEOFF_STARE_TICKS := 330
## Back to the marks: the turn away, and the turn back at the end.
const FACEOFF_TURN_TICKS := 30
## A beat on the marks, facing, before the bell.
const FACEOFF_SET_TICKS := 30

# --- Camera shots (project values; refs/camera.md measures none of these) ---
## The face-off two-shot: from the hard camera's side of the pair, square to
## them, a little under head height, close enough for both heads and chests.
const FACEOFF_CAM_DISTANCE := 3.4
const FACEOFF_CAM_HEIGHT := 1.5
const FACEOFF_CAM_FOV := 34.0
## The pre-match intro before the stare-down (camera_aaa_plan.md A5, 2K26
## thumbnails 0-2), in ticks: the match card over a high wide of the ring;
## the referee checking the man nearer her; then each man close in his
## corner, the one she checked last so she is out of his shot.
const INTRO_CARD_TICKS := 216
const INTRO_CHECK_TICKS := 200
const INTRO_CLOSE_TICKS := 150
const INTRO_CARD_AT := Vector3(-8.0, 4.4, 3.4)
const INTRO_CARD_LOOK := Vector3(0.0, 0.9, 0.0)
const INTRO_CARD_FOV := 40.0
const INTRO_CLOSE_FOV := 22.0
const INTRO_CLOSE_DISTANCE := 2.6
## Every high shot hangs at RIG_CLEAR_Y: just under the light rig over the
## ring (ArenaBuilder.TRUSS_Y 7.6, its keys' bodies down to ~6.9), so the lens
## sees the building under the steel instead of through it. The owner: "the
## camera is above the light rigging above the ring, which blocks the view --
## just underneath it, so we get a clear wide-angle shot".
const RIG_CLEAR_Y := 6.3
const OPENING_AT := Vector3(0.0, RIG_CLEAR_Y, 14.0)
const OPENING_LOOK := Vector3(0.0, 3.0, -30.0)
const OPENING_FOV := 52.0
## The stage: from down the ramp, on a long lens, so the set fills the frame
## behind him.
const STAGE_AT := Vector3(0.0, 1.9, -23.5)
const STAGE_FOV := 40.0
## Walking backwards down the ramp ahead of him.
const TRACK_OFFSET := Vector3(1.3, 1.6, 5.2)
const TRACK_FOV := 44.0
## At ringside on the ring's +X side, inside the barricade, at a cameraman's
## shoulder: the walk in from the ramp foot comes toward it, the diagonal
## steps at the (+3, -3) corner are three-quarter on four metres away, and the
## ropes are in frame. The first version
## stood outside the barricade at (-7.2, -0.25, -7.8) and rendered the whole
## climb behind the barricade panels and the ringside chairs.
const RINGSIDE_AT := Vector3(5.5, 1.0, 0.4)
const RINGSIDE_FOV := 42.0

## The follow spot, in the rafters at the far end of the hall, throwing the
## length of the building onto whoever is walking. Without it he walked the
## ramp in silhouette: nothing in the rig lights the ramp, because nothing in
## a match happens there.
const FOLLOW_SPOT_AT := Vector3(0.0, 17.0, 22.0)
const FOLLOW_SPOT_ENERGY := 40.0
const FOLLOW_SPOT_ANGLE := 3.5
## The walk key (blender-lighting: a key from the front at about 45 degrees,
## warm, soft, with the video wall behind him as the rim). The follow spot is
## 40 m away in the far end: on its own it lost him halfway down the ramp --
## once he was out of the stage wash his front went to silhouette against the
## wall on every steadicam shot. This one rides with him, a few metres ahead,
## to his right and above, like the front-truss followers a real entrance
## hangs, so he is lit from the curtain to the ring.
const WALK_KEY_AHEAD := 4.2
const WALK_KEY_SIDE := 1.6
const WALK_KEY_UP := 3.6
const WALK_KEY_ENERGY := 5.0
const WALK_KEY_ANGLE := 24.0
const WALK_KEY_RANGE := 11.0
## And its partner behind him. The key and the far follow spot both light his
## FRONT, so on every shot from behind him -- the steadicam following him down,
## the over-the-shoulder at the lip -- he walked as a silhouette (the owner
## caught it on the walk-down frames). A real entrance hangs followers on the
## back truss too: this one rides behind, above and to his other side, a
## little cooler, so his back, shoulders and hair are lit from the curtain to
## the ring without flattening the key's modelling from the front.
const WALK_BACK_BEHIND := 3.0
const WALK_BACK_SIDE := -1.4
const WALK_BACK_UP := 3.4
const WALK_BACK_ENERGY := 3.4
const WALK_BACK_ANGLE := 28.0
const WALK_BACK_RANGE := 10.0
## The titantron's light on him (lighting_2k26.md item 11): while his video is
## on the wall and he is out of the ring, a spot in the wall's own colour
## (StageVideo.glow_color) hangs between him and the wall, high, and rakes his
## head and shoulders -- the coloured edge that separates him from the screen
## in 2K26's stage and ramp shots. No shadow, and a faint beam in the haze.
const TRON_RIM_BACK := 2.6
const TRON_RIM_UP := 3.0
const TRON_RIM_ENERGY := 14.0
const TRON_RIM_ANGLE := 22.0
const TRON_RIM_RANGE := 7.0
## Where the wall is, to put the light on his side of it.
const TRON_AT := Vector3(0.0, ArenaBuilder.SCREEN_CENTER_Y, ArenaBuilder.SCREEN_FACE_Z)

# --- Roman Reigns (gauntlet/refs/entrances.md, "Roman: beat sheet") ---------
## Slow and methodical: Walk_Slow_Look travels 0.5 m/s,
## half the generic entrance's pace, and turn his head over the crowd as he
## goes (wrestling_clips.py _methodical_walk).
const ROMAN_WALK_SPEED := 0.5
const ROMAN_WALK_CLIP := "strikes/walk_slow_look"
## How long the very wide of the first pyro holds as he walks out of it.
const ROMAN_FIRST_PYRO_SHOT := 3.0
## He does not come out until the main part of his music hits. Measured off
## the audio of assets/environment/video/roman_entrance.ogv, 0.1 s windows:
## near silence 42.5-44.9 s (RMS 0.011) and the full track slams back at
## 45.0 s (0.132). The broadcast puts the FINGER on that slam, with the pyro
## (R-41: finger 40 s, pyro and cut 42 s) -- so he is out long before it.
const ROMAN_MUSIC_HIT := 45.0
## His music's beat after the hit (camera_aaa_plan.md A4): 71.8 BPM, measured
## by onset autocorrelation over 45-115 s of the same audio, and the grid's
## phase lands on the hit itself (44.95 s). Every cut from the hit to the
## foot of the ramp is a whole number of these, so the cuts land on the music.
const ROMAN_BEAT := 0.836
## Cody's, measured the same way off cody_entrance.ogv: 80.7 BPM (the onset
## track also peaks at its double, 161.5). Drives the moving beams' pulse.
const CODY_BEAT := 0.743
## The hard top light on a man posing in the ring (lighting_2k26.md item 12):
## narrow, white, straight down from under the grid, with the house dark.
const POSE_TOP_UP := 5.0
const POSE_TOP_ENERGY := 110.0
const POSE_TOP_ANGLE := 13.0
const POSE_TOP_COLOR := Color(0.92, 0.96, 1.0)
## While it is on, the light that was outweighing it goes: the follow spot and
## the walk lights out, the ring keys and top fill to POSE_RING_DIM of
## themselves. At 9, with them up, the top light added only 6-19% on his head
## and shoulders (README, "Lighting 2K26 items 5-12").
const POSE_RING_DIM := 0.35
## On the lip before the finger: the slow push-in while he looks the building
## over, then the close-up (R-41 30-40 s, 1:04).
const ROMAN_LIP_PUSH := 4.0
const ROMAN_LIP_FACE := 3.0
## After the slam: the very wide of the pyro, then the finger held under the
## low wide from the ramp until this music time (R-41: 40 s to 58 s).
const ROMAN_PYRO_WIDE := 3 * ROMAN_BEAT
const ROMAN_FINGER_DOWN := ROMAN_MUSIC_HIT + 16 * ROMAN_BEAT
## The room goes red for the pyro and back to blue, in ticks.
const ROMAN_RED_TICKS := 90
## Head bowed at ringside (R-41 2:42-3:04 is twenty seconds; held here four).
const ROMAN_BOW_TICKS := 240
## The walk, cut the way R-41 cuts it: the low ultra-wide steadicam backing
## ahead of him, a very wide from high every six to eight seconds, and once
## over his shoulder down the ramp (R-CJ). [shot, seconds], cycled; each a
## whole number of beats (A4).
## The second pass of the cycle trades the low lens for the chest-high one
## and the barricade track (2K26 Roman 2:35-3:10), so the low ultra-wide is
## his signature, not the whole walk.
const ROMAN_WALK_SHOTS := [["steadicam_low", 6 * ROMAN_BEAT], ["ramp_side_high", 5 * ROMAN_BEAT],
		["face_walk", 5 * ROMAN_BEAT], ["over_shoulder", 5 * ROMAN_BEAT],
		["steadicam_front", 6 * ROMAN_BEAT], ["arena_high", 4 * ROMAN_BEAT],
		["barricade_track", 5 * ROMAN_BEAT], ["face_walk", 5 * ROMAN_BEAT]]
## Until then the broadcast shows the building and his video: six shots, each
## a slow move eased in and out (blender-cameras: push-ins, a truck, a wide
## establishing lens), in seconds. [from, to, look_from, look_to, fov_from,
## fov_to, seconds]. Lenses as vertical FOV: 53 ~ 24 mm, 38 ~ 35 mm,
## 27 ~ 50 mm, 16 ~ 85 mm.
const ROMAN_INTRO_SHOTS := [
	# The building, the stage empty under his light: high in the far end, a
	# 24 mm wide, trucking across (R-41 0-10 s).
	[Vector3(8.5, RIG_CLEAR_Y, 14.0), Vector3(3.0, RIG_CLEAR_Y + 0.1, 14.5),
		Vector3(0.0, 3.0, -18.0), Vector3(0.0, 3.2, -20.0), 53.0, 50.0, 8.0],
	# His video on the wall, from up level with it over the ramp, pushing
	# in: the screen fills the frame and the empty portals below it stay out
	# of shot (it was taken from low on the ramp, the portals in the bottom
	# of the frame).
	[Vector3(0.0, 6.4, -18.0), Vector3(0.0, 6.5, -21.0),
		Vector3(0.0, 9.2, -36.5), Vector3(0.0, 9.3, -36.5), 30.0, 26.0, 7.0],
	# The building waiting for him: the hard camera side's crowd from
	# ringside, panning along the rows -- stretched to fill the wait, so the
	# next cut is to him already in his portal (the "stage" walk).
	[Vector3(-3.6, 1.7, -1.5), Vector3(-3.6, 1.8, 1.5),
		Vector3(-16.0, 4.6, -6.0), Vector3(-16.0, 4.6, 4.0), 40.0, 38.0, 8.0],
]
## The owner: no close-ups of an empty tunnel, ever. There used to be a long
## lens creeping into the empty portals here -- eleven seconds of it, then
## two and a half -- and Cody's smoke built up in his on a long lens before he
## walked out. The camera now finds the portals only with a man in them
## (test_entrance_cameras: zero ticks).
## The house lights dim for him (blender-lighting's low-key look: fewer,
## harder sources, the key on the subject). The rig drops to this fraction and
## the ambient to AMBIENT_DIM; the follow spot, his portal accents and the
## pyro flashes are left alone, so he is what is lit.
const ROMAN_HOUSE_DIM := 0.5
const ROMAN_AMBIENT_DIM := 0.65
## Cody's walk, after the WHOA brings the house out of the blackout.
const WALK_HOUSE_DIM := 0.5
const WALK_AMBIENT_DIM := 0.65
## The close-ups: an 85 mm on his face walking toward the lens, and one held
## on the stage lip.
const FACE_FOV := 16.0
const FACE_DISTANCE := 3.4
## Beside him as he walks the floor from the ramp foot to the steps.
const FLOOR_TRACK_FOV := 30.0

# --- Cody Rhodes (gauntlet/refs/entrances.md, "Cody: cut to his music") -----
## Every time below is MUSIC time in his video's own audio (cody_entrance.ogv,
## 80 s), measured: the intro's three swells (0.8, 3.6, 6.3 s), the band in at
## 7.9 s, and the sung chant from 22.5 s -- vocal onsets at 22.5, 24.0, 26.0,
## 29.0, 36.5 and the chorus's big held WHOAAA at 43.5 s. Seven WWE.com
## entrance clips were aligned to this track by cross-correlating their audio
## (every one starts on the music, +0.2 s), which put what the broadcast shows
## on it: nobody on camera until the smoke (MITB 22.3 s), out of it on the
## first sung WHOA, the WHOA pose, the pyro 2.5 s into it and the fists 5 s
## into it (C-39), the kneel at the lip (C-MITB), the low WHOA mid-aisle on the
## held WHOAAA (C-SNME). He used to be out on the third intro swell, 16 s early.
const CODY_WHOA_1 := 0.8
const CODY_WHOA_2 := 3.6
const CODY_WHOA_3 := 6.3
const CODY_BAND := 7.9
const CODY_SMOKE := 20.3
## The first sung WHOA: he steps out of the smoke.
const CODY_EMERGE := 22.5
## Arms thrown wide on the chant.
const CODY_WHOA := 24.0
const CODY_PYRO := 26.0
## Both fists driven down.
const CODY_PUNCH := 29.0
## His knee on the mat at the lip.
const CODY_KNEEL := 36.5
## The low WHOA down the ramp, on the held WHOAAA.
const CODY_WHOA_LOW := 43.5
## Where in each clip its accent lands, in ticks: Whoa_Arms' arms are wide on
## frame 11, Kneel's knee down on 22, Whoa_Low's arms wide on 10.
const WHOA_WIDE_AT := 22
const KNEEL_DOWN_AT := 44
const WHOA_LOW_WIDE_AT := 20
## He walks with purpose and works the crowd: Walk_Crowd travels 1.2 m/s.
const CODY_WALK_SPEED := 1.2
const CODY_WALK_CLIP := "strikes/walk_crowd"
## Air_Punch's fist arrives on frame 10: the second pyro.
const CODY_PUNCH_AT := 20
## Kneel: 5.0 s at the top of the ramp (C-MITB 40-44 s).
const CODY_KNEEL_TICKS := 300
## Whoa_Low, played through.
const CODY_WHOA_LOW_TICKS := 200
## His walk, cut as 2K26 cuts it (refs/entrances.md "2K26", Cody 0:58-1:06):
## walking at the lens at chest height, then from behind following, along the
## barricade with the crowd reaching for him, and a wide of the building.
## The owner found the old cut "mostly low angle" -- four low ultra-wide
## steadicam shots on the ramp. Now the low one is used once, on the walk
## from the kneel (Cody's signature in C-39), and the rest sit at eye level.
## [shot, seconds], cycled; whole beats of his music (A4).
const CODY_WALK_SHOTS := [["steadicam_front", 6 * CODY_BEAT], ["over_shoulder", 5 * CODY_BEAT],
		["barricade_track", 5 * CODY_BEAT], ["arena_high", 4 * CODY_BEAT]]
## What he does with his arms on the walk (refs/entrances.md, C-39 / C-SS /
## C-SNME): yells at one side of the aisle with a fist up, points a fan out,
## yells at the other side, one fist to the roof. Each ONCE, one to a beat of
## the walk cut, over the plain walk -- the owner saw the old walk's baked
## fist pump come round every 3.5 s, ten times down the ramp.
## The fist to the roof is left out: it throws his head back, and it landed
## just before the ring, where he looked to be floating.
const CODY_WALK_GESTURES := ["strikes/walk_crowd_shout_l", "strikes/walk_crowd_point",
		"strikes/walk_crowd_shout_r"]
## Walk_Crowd's gait cycle (26 frames at 30 fps) and a gesture clip's length
## (four cycles): a gesture goes in on a cycle boundary of the plain walk and
## hands back on one, so the legs never jump.
const WALK_CYCLE_TICKS := 52
const WALK_GESTURE_TICKS := 208
## Corner_Pose has the arms fully wide by frame 12: the shells burst over the
## ring (EntrancePyro "over_ring").
const CODY_CORNER_PYRO_AT := 24
## Coat_Off has his arms behind him, the coat sliding off, on frame 36.
const COAT_OFF_AT := 72
## Where he stands to climb the corner: this far from the post along the
## diagonal, facing out over it (wrestling_clips.py CORNER_FOOT_*).
const CORNER_ROOT_M := 0.62
## The blackout: the rig to 3% and the ambient to 10%, portal accents off.
## His light in the dark is one cold backlight behind him in his portal, so
## on the WHOAs the camera sees him as a silhouette in the haze.
const CODY_BLACKOUT := 0.03
const CODY_BLACKOUT_AMBIENT := 0.10
const BACKLIGHT_ENERGY := 30.0
const BACKLIGHT_COLOR := Color(0.82, 0.88, 1.0)
const CODY_RED := Color(1.0, 0.12, 0.10)
const CODY_BLUE := Color(0.18, 0.32, 1.0)
## His shots. The dark wide from high behind the hard camera; the long lens
## on his portal from down the ramp (85 mm, pushing in); a steadicam backing
## ahead of him; and the low angle inside the ring up past him in the corner.
const CODY_DARK_AT := Vector3(0.0, RIG_CLEAR_Y, 14.0)
const CODY_DARK_LOOK := Vector3(0.0, 3.0, -30.0)
const CODY_DARK_FOV := 50.0
## His video starting on the big screen: from a crane over the floor, square
## to the wall, the whole screen and the dark stage under it (owner: the old
## cut "stays too long on the crowd" -- the 2K26 intro shows the video).
const TRON_SHOT_AT := Vector3(0.0, 4.5, -17.0)
const TRON_SHOT_FOV := 34.0
const PORTAL_LONG_FOV := Vector2(19.0, 14.0)
const STEADICAM_FOV := 32.0
const CORNER_LOW_AT := Vector3(1.2, 1.25, -1.2)
const CORNER_LOW_FOV := 50.0
## Cues inside his clips, in ticks from the clip's start (clip frame x 2):
## Title_Unbuckle opens the belt on frame 20 and it moves from his waist to
## his left hand on frame 22; Finger_Raise's arm arrives on frame 14 -- the
## pyro hit -- and Ula_Fala_Off has it over his head by frame 20.
const TITLE_UNBUCKLED_AT := 44
const FINGER_PYRO_AT := 28
const ULA_FALA_LIFT_AT := 40
## Prop_Hand_Out_*: 58 frames at 30 fps. The pass is on its frame 26.
const HAND_OUT_SECONDS := 1.933
## The longest a beat will wait for the last prop to reach the table.
const HANDOFF_MAX_WAIT := 60 * 25
## The OTC look is blue (R-41, R-CJ, and his own wall video): his portal
## accents go blue, and red only for the pyro (R-41 42 s).
const ROMAN_BLUE := Color(0.22, 0.52, 1.0)
const ROMAN_PYRO_RED := Color(1.0, 0.10, 0.16)
## His shots. The push-in on the mark: from the ramp, a slow dolly in and a
## lens tightening on him. The hero shot: low at his feet looking up, for the
## title. The wide: the whole set, for the pyro. The ring low: from the mat
## under the ropes, for the finger in the ring.
const PUSH_FROM := Vector3(0.0, 1.8, -24.5)
const PUSH_TO := Vector3(0.0, 1.7, -27.4)
const PUSH_FOV := Vector2(34.0, 28.0)
## Eye level, not a worm's-eye: 2K26's entrance mids sit at chest-to-eye
## height (owner: "I don't like the low camera facing up"; cody_roman_2k26.md).
const HERO_OFFSET := Vector3(0.9, 1.45, 3.0)
const HERO_FOV := 40.0
const STAGE_WIDE_AT := Vector3(0.0, 3.2, -15.0)
const STAGE_WIDE_LOOK := Vector3(0.0, 4.0, -33.0)
const STAGE_WIDE_FOV := 58.0
const RING_LOW_OFFSET := Vector3(-2.2, 1.45, 1.4)
const RING_LOW_FOV := 46.0

# --- The broadcast's shots (refs/entrances.md "Measured off broadcast") ---
## The signature walk shot, both men: an ultra-wide steadicam backing ahead
## of him with the lens at his hips, tilted up past his chest to the roof.
const STEADICAM_LOW_AHEAD := 1.3
const STEADICAM_LOW_HEIGHT := 1.45
const STEADICAM_LOW_FOV := 50.0
## The very wide from high at the far end, over the ring, on him.
const ARENA_HIGH_AT := Vector3(6.5, RIG_CLEAR_Y, 12.0)
const ARENA_HIGH_FOV := 50.0
## Behind him, over his shoulder, down the ramp at the crowd (R-CJ).
const OVER_SHOULDER_FOV := 50.0
## Low on the ramp looking up at him small under the set (R-41 50-58 s).
const RAMP_LOW_WIDE_AT := Vector3(0.0, 1.8, ArenaBuilder.STAGE_FRONT + 8.5)
const RAMP_LOW_WIDE_FOV := 46.0
## A long lens from down the ramp on him at the lip (C-MITB, the kneel).
const RAMP_LONG_BACK := 9.0
const RAMP_LONG_FOV := 22.0
# --- WWE 2K26's entrance shots (gauntlet/refs/entrances.md, "2K26") --------
## High on the crowd side of the ramp, level with him plus a few metres,
## looking across at him walking (2K26 Roman 3:01).
const RAMP_SIDE_HIGH_X := 8.0
const RAMP_SIDE_HIGH_Y := 4.8
const RAMP_SIDE_HIGH_LEAD := 4.0
const RAMP_SIDE_HIGH_FOV := 34.0
## Outside the ring off a corner, high: the whole ring and him in it
## (2K26 Cody 1:33, Roman 4:03).
const RING_HIGH_CORNER_AT := Vector3(-6.2, 4.6, 6.2)
const RING_HIGH_CORNER_FOV := 44.0
## In the ring behind him, looking past him out over the crowd he is
## playing to (2K26 Roman 3:37-3:41).
const RING_BEHIND_OUT_BACK := 2.3
const RING_BEHIND_OUT_FOV := 52.0
## The closing wide from the far end of the hall, under the rig (2K26 Cody
## 1:46-1:55, Roman 4:26-4:30).
const END_WIDE_AT := Vector3(0.0, RIG_CLEAR_Y, 15.5)
const END_WIDE_LOOK := Vector3(0.0, 1.6, 0.0)
const END_WIDE_FOV := 46.0
## Inside the ring, low, behind him as he comes through the ropes (C-SNME).
const RING_BEHIND_FOV := 70.0
## The hard-camera side crowd, for the WHOAs in the dark (C-MITB 12-20 s).
const CROWD_WIDE_AT := Vector3(3.8, 1.6, 1.0)
const CROWD_WIDE_LOOK := Vector3(16.0, 4.5, 0.0)
const CROWD_WIDE_FOV := 40.0
## And the other side's, across the ring toward the far end.
const CROWD_FAR_AT := Vector3(-3.8, 1.6, 2.0)
const CROWD_FAR_LOOK := Vector3(-15.0, 4.8, 9.0)
## The dark house from high on the side, the ring and the floor rows, the
## stage out of frame.
const ARENA_DARK_LOOK := Vector3(-4.0, 0.5, -2.0)
## 2K26's walking shot: ahead of him at chest height, a normal lens.
const STEADICAM_FRONT_AHEAD := 3.2
const STEADICAM_FRONT_HEIGHT := 1.4
const STEADICAM_FRONT_FOV := 40.0
## Alongside from the barricade (C-SS 14-30 s).
const BARRICADE_TRACK_SIDE := 2.4
const BARRICADE_TRACK_AHEAD := 1.2
const BARRICADE_TRACK_HEIGHT := 1.25
const BARRICADE_TRACK_FOV := 38.0
## Roman's bowed head at the steps, close, from his right.
const BOW_SIDE := 1.9
const BOW_AHEAD := 0.7
const BOW_FOV := 26.0
## The smoke he walks out of: a bank of it on the deck, knee deep, in his
## portal mouth (C-MITB 22-26 s) -- a full-height box lit from behind went
## white and hid him.
const SMOKE_SIZE := Vector3(5.0, 1.1, 4.0)
const SMOKE_DENSITY := 0.5

var _match: Node
var _a: WrestlerController
var _b: WrestlerController
var _camera: MatchCamera
var _hud: Node
var _card: EntranceLowerThird
var _lights: Node
var _follow: SpotLight3D
var _walk_key: SpotLight3D
var _walk_back: SpotLight3D
## Every node frozen for the entrance, with whether it was processing, so the
## bell puts back exactly what was there.
var _frozen: Array = []
## Where each man stands at the bell: his spawn in match.tscn.
var _mark := {}
## Roman's belt and ula fala, per man, and the pyro -- built when needed.
var _props := {}
## Cody's entrance coat, per man.
var _coats := {}
var _pyro: EntrancePyro
## The stage wall, for his own titantron.
var _wall: StageVideo
## Light energies saved while the house is dimmed, to put back exactly.
var _dimmed := {}
var _env: Environment
## Cody's backlight, built on his first WHOA.
var _backlight: SpotLight3D
## Cody's smoke in his portal, while he walks out of it.
var _smoke: FogVolume
## The props' way to the timekeeper's table, and the man who keeps it.
var _handoff: PropHandoff
var _keeper: Timekeeper
## ...and the dry ice that works on every renderer (DryIce), poured at the same
## spot, which keeps rolling and thinning after the fog volume is gone.
var _ice: DryIce
## Beats marked no_follow keep the follow spot off (Cody's silhouettes).
var _follow_off := false
var _tron_rim: SpotLight3D
var _tron_on := false

## The timeline: one entry per beat, built once in begin().
var _beats: Array = []
## The walk gestures: man -> ticks the plain walk has run (its gait phase),
## the gesture waiting for the next cycle boundary, the one playing
## [clip, ticks left], and every one played (tests).
var _walk_clock := {}
var _ropes: RingRopes
var _gesture_pending := {}
var _gesture := {}
var gestures_played: Array[String] = []
var _beat := 0
var _tick := 0
var _done := false


## The crowd's reaction to a pyro hit (CrowdReaction).
const CROWD_PYRO_POP := 0.8
var _crowd: CrowdReaction


func begin(match_root: Node) -> void:
	_match = match_root
	_a = match_root.get_node("WrestlerA")
	_b = match_root.get_node("WrestlerB")
	_camera = match_root.get_node_or_null("MatchCamera") as MatchCamera
	_hud = match_root.get_node_or_null("MatchHUD")
	_lights = match_root.get_node_or_null("LightRig")
	_wall = match_root.find_child("StageVideo", true, false) as StageVideo
	var world: WorldEnvironment = null
	for node in match_root.find_children("*", "WorldEnvironment", true, false):
		world = node as WorldEnvironment
	if world:
		_env = world.environment
	# The timekeeper and the way a man's props reach his table. Both live on
	# in the match: the table, with whatever was set on it.
	var ref := match_root.get_node_or_null("RefereeActor") as RefereeActor
	if ref and match_root.get_node_or_null("Timekeeper") == null:
		_keeper = Timekeeper.new()
		_keeper.name = "Timekeeper"
		match_root.add_child(_keeper)
		_keeper.setup(PropHandoff.KEEPER_POST, Vector3(-1, 0, 0), PropHandoff.TABLE_AT)
		_handoff = PropHandoff.new()
		_handoff.name = "PropHandoff"
		match_root.add_child(_handoff)
		_handoff.setup(ref, _keeper)
	# Phones out for the entrances (CrowdReaction; refs/aaa_gap.md item 11).
	_crowd = get_tree().get_first_node_in_group("crowd_reaction") as CrowdReaction
	if _crowd:
		_crowd.set_flashes(CrowdReaction.ENTRANCE_FLASH_RATE)
		_crowd.pop(0.4)
	# Their marks, squared up to each other. The scene's spawn transforms
	# face OUTWARD (a wrestler faces his node's -Z, and WrestlerA stands at
	# z -1.5 with an identity basis), which the match never showed because
	# WrestlerController turns a man to his opponent from the first tick.
	# The entrance ends on these marks, frozen, so the owner saw both men
	# finish their entrances with their backs to each other.
	for pair: Array in [[_a, _b], [_b, _a]]:
		var me: WrestlerController = pair[0]
		var other: WrestlerController = pair[1]
		var mark := me.global_transform
		var to_other := _flat(other.global_position - me.global_position)
		if to_other.length() > 0.01:
			mark.basis = _facing_basis(to_other)
		_mark[me] = mark

	for w: WrestlerController in [_a, _b]:
		_freeze(w)
		if w.ai:
			_freeze(w.ai)
		w.velocity = Vector3.ZERO
		w.visible = false
	for path in ["MatchReferee", "GrappleRig"]:
		var node := match_root.get_node_or_null(path)
		if node:
			_freeze(node)
	if _hud and "visible" in _hud:
		_hud.visible = false

	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_card = EntranceLowerThird.new()
	layer.add_child(_card)

	_follow = SpotLight3D.new()
	_follow.name = "FollowSpot"
	_follow.light_color = Color(1.0, 0.96, 0.90)
	_follow.light_energy = FOLLOW_SPOT_ENERGY
	_follow.spot_angle = FOLLOW_SPOT_ANGLE
	_follow.spot_angle_attenuation = 0.4
	_follow.spot_range = 80.0
	_follow.spot_attenuation = 0.5
	_follow.light_volumetric_fog_energy = 1.2
	_follow.shadow_enabled = false
	_follow.visible = false
	add_child(_follow)
	_follow.global_position = FOLLOW_SPOT_AT
	_walk_key = SpotLight3D.new()
	_walk_key.name = "WalkKey"
	_walk_key.light_color = Color(1.0, 0.94, 0.86)
	_walk_key.light_energy = WALK_KEY_ENERGY
	_walk_key.spot_angle = WALK_KEY_ANGLE
	_walk_key.spot_angle_attenuation = 1.6
	_walk_key.spot_range = WALK_KEY_RANGE
	_walk_key.spot_attenuation = 0.6
	# No beam in the haze: a light hanging in mid-air must not be seen.
	_walk_key.light_volumetric_fog_energy = 0.0
	_walk_key.light_specular = 0.35
	_walk_key.shadow_enabled = false
	_walk_key.visible = false
	add_child(_walk_key)
	_walk_back = _walk_key.duplicate() as SpotLight3D
	_walk_back.name = "WalkBack"
	_walk_back.light_color = Color(0.88, 0.93, 1.0)
	_walk_back.light_energy = WALK_BACK_ENERGY
	_walk_back.spot_angle = WALK_BACK_ANGLE
	_walk_back.spot_range = WALK_BACK_RANGE
	add_child(_walk_back)

	# The camera is the director's from the first rendered frame, not the
	# first tick -- otherwise frame one is the match camera's hard-cam shot of
	# an empty ring.
	if _camera:
		_camera.set_entrance_shot(OPENING_AT, OPENING_LOOK, OPENING_FOV, true)

	_build_timeline()
	_start_beat()


func _freeze(node: Node) -> void:
	_frozen.append([node, node.is_physics_processing()])
	node.set_physics_process(false)


# ---------------------------------------------------------------------------
# The timeline
# ---------------------------------------------------------------------------

## Each beat is {kind, who, ticks, ...}. Walks carry a polyline; clips carry a
## root line; every beat names its camera shot and whether the card is up.
func _build_timeline() -> void:
	_beats.append({"kind": "opening", "ticks": OPENING_TICKS})
	# The opponent enters first and waits in the ring; the player's man last.
	for pair: Array in [[_b, ArenaBuilder.PORTAL_OFFSET_X, "E"],
			[_a, -ArenaBuilder.PORTAL_OFFSET_X, "W"]]:
		var w: WrestlerController = pair[0]
		if w.entrance_style == "roman":
			_add_roman_entrance(w, pair[1], pair[2])
		elif w.entrance_style == "cody":
			_add_cody_entrance(w, pair[1], pair[2])
		else:
			_add_entrance(w, pair[1], pair[2])
		if w == _b:
			# The handover: he is on his mark and his music fades under the
			# closing wide before the next man's starts -- never one track
			# cut into the next, and never straight from him to an empty
			# tunnel.
			_beats.append({"kind": "hold", "who": w, "ticks": HANDOVER_TICKS,
					"shot": "end_wide"})
	_add_faceoff()


## Walk up, stare down, back to the marks (FACEOFF_GAP's note). Each beat is a
## "pair" beat: both men move at once, each on his own line.
func _add_faceoff() -> void:
	var a: Transform3D = _mark[_a]
	var b: Transform3D = _mark[_b]
	var mid := (a.origin + b.origin) * 0.5
	var a_in := mid + _flat(a.origin - mid).normalized() * (FACEOFF_GAP * 0.5)
	var b_in := mid + _flat(b.origin - mid).normalized() * (FACEOFF_GAP * 0.5)
	var walk := maxi(1, int(ceil(_flat(a.origin).distance_to(_flat(a_in))
			/ FACEOFF_WALK_SPEED * TPS)))
	var face_a := _flat(b.origin - a.origin)
	var face_b := -face_a
	_add_intro(a, b, face_a, face_b)
	_beats.append({"kind": "pair", "ticks": walk, "shot": "faceoff_side", "moves": [
			[_a, a.origin, a_in, face_a, "strikes/entrance_walk"],
			[_b, b.origin, b_in, face_b, "strikes/entrance_walk"]]})
	_beats.append({"kind": "pair", "ticks": FACEOFF_STARE_TICKS, "shot": "faceoff_seq",
			"moves": [[_a, a_in, a_in, face_a, "strikes/face_off"],
					[_b, b_in, b_in, face_b, "strikes/face_off"]]})
	# Back to their marks: turned away, walked, turned round.
	_beats.append({"kind": "pair", "ticks": FACEOFF_TURN_TICKS, "shot": "faceoff",
			"moves": [[_a, a_in, a_in, face_b, "strikes/face_off"],
					[_b, b_in, b_in, face_a, "strikes/face_off"]]})
	_beats.append({"kind": "pair", "ticks": walk, "shot": "faceoff", "moves": [
			[_a, a_in, a.origin, face_b, "strikes/entrance_walk"],
			[_b, b_in, b.origin, face_a, "strikes/entrance_walk"]]})
	_beats.append({"kind": "pair", "ticks": FACEOFF_TURN_TICKS + FACEOFF_SET_TICKS,
			"shot": "faceoff", "moves": [
			[_a, a.origin, a.origin, face_a, _wait_clip(_a)],
			[_b, b.origin, b.origin, face_b, _wait_clip(_b)]]})


## A5: both men on their marks while the broadcast introduces the match.
func _add_intro(a: Transform3D, b: Transform3D, face_a: Vector3, face_b: Vector3) -> void:
	var hold := [[_a, a.origin, a.origin, face_a, _wait_clip(_a)],
			[_b, b.origin, b.origin, face_b, _wait_clip(_b)]]
	var checked := intro_checked(a.origin, b.origin)
	_checked = checked
	var first := _b if checked == _a else _a
	var last := _a if checked == _a else _b
	# Both men are in: the house lights come up for the introductions and
	# the stare-down (owner), not at the bell.
	_beats.append({"kind": "pair", "ticks": INTRO_CARD_TICKS, "shot": "match_card",
			"match_card": true, "moves": hold, "events": [[1, "lights_up"]]})
	_beats.append({"kind": "pair", "ticks": INTRO_CHECK_TICKS, "shot": "ref_check",
			"focus": last, "moves": hold})
	_beats.append({"kind": "pair", "ticks": INTRO_CLOSE_TICKS, "shot": "corner_intro",
			"focus": first, "moves": hold})
	_beats.append({"kind": "pair", "ticks": INTRO_CLOSE_TICKS, "shot": "corner_intro",
			"focus": last, "moves": hold})


## Which man the referee checks: the one whose mark is nearer where she
## waits (RefereeActor.PARK) -- she picks the same one off the same rule.
func intro_checked(a_at: Vector3, b_at: Vector3) -> WrestlerController:
	return _a if _flat(a_at).distance_to(RefereeActor.PARK) <= _flat(b_at).distance_to(RefereeActor.PARK) else _b


## The man the intro's check is on, once the timeline is built.
func checked_man() -> WrestlerController:
	return _checked


var _checked: WrestlerController


## Where she stands to check a man: a metre in front of him, toward the centre.
static func check_spot(man: Vector3) -> Vector3:
	var flat := Vector3(man.x, 0.0, man.z)
	var to_c := -flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	return flat + to_c * 1.0


## What a man does standing in the ring waiting -- never the grapple crouch
## (Idle_Ready), which is a match stance: his own entrance stand if he has
## one, else the face-off's square stance.
static func _wait_clip(w: WrestlerController) -> String:
	match w.entrance_style:
		"roman":
			return "strikes/roman_stand"
		"cody":
			return "strikes/cody_stand"
	return "strikes/face_off"


func _add_entrance(w: WrestlerController, portal_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 1.2)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	_beats.append({"kind": "walk", "who": w, "path": [emerge, lip],
			"shot": "stage", "lights": side, "appear": true})
	_beats.append({"kind": "pose", "who": w, "ticks": POSE_TICKS,
			"clip": "strikes/win_celebrate", "facing": Vector3.BACK,
			"shot": "stage", "lights": side})
	var ramp_end := lip + Vector3.BACK * (WALK_SPEED * RAMP_SHOWN_SECONDS)
	_beats.append({"kind": "walk", "who": w, "path": [lip, ramp_end],
			"shot": "track", "ramp_card": true})
	# The cut: a few metres short of the ramp foot, then round to the steps.
	var inside := _add_route_in(w, Vector3(0.0, 0.0, CUT_TO_Z), WALK_SPEED,
			"strikes/entrance_walk", false)
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w,
			"path": [inside, mark.origin],
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ringside", "settle": true})


func _start_beat() -> void:
	_tick = 0
	_pose_top(null)
	if _beat >= _beats.size():
		_ring_bell()
		return
	var beat: Dictionary = _beats[_beat]
	beat_started.emit(String(beat.get("shot", "")))
	# On a crowd cutaway the beams sweep fast across the stands.
	if _lights and _lights.has_method("crowd_sweep"):
		_lights.crowd_sweep(String(beat.get("shot", "")).begins_with("crowd"))
	var w: WrestlerController = beat.get("who")
	if beat.get("appear", false) and w:
		# Placed in the same step he is shown, or the frame in between renders
		# him standing at his in-ring spawn for a sixtieth of a second.
		_place(w, beat["path"][0], _heading(beat["path"]), true)
		w.visible = true
	_follow_off = beat.get("no_follow", false)
	if beat.get("coat", false) and w and not _coats.has(w):
		_coats[w] = EntranceCoat.dress(w)
	if beat.get("props", false) and w and not _props.has(w):
		# The OTC carries no title (refs/entrances.md): the ula fala only.
		# Roman walks out with the AEW title round his waist (the owner's
		# ask): worn on the pelvis, so it turns and tips with his hips.
		_props[w] = EntranceProps.dress(w, true)
	if beat.has("lights"):
		_portal_lights(beat["lights"], true, beat.get("light_color", Color.TRANSPARENT))
	else:
		_portal_lights("", false)
	if beat.get("match_card", false):
		_card.show_card("%s  VS  %s" % [_card_name(_b), _card_name(_a)], MATCH_CARD_SUBTITLE)
	elif beat.get("ramp_card", false):
		pass  # shown by _tick_ramp_card once he is half way down the ramp
	elif beat.get("card", false) and w:
		if not _card.is_showing():
			_card.show_card(w.display_name if w.display_name != "" else String(w.name),
					w.entrance_subtitle)
	else:
		_card.hide_card()
	match beat["kind"]:
		"walk":
			var path: Array = beat["path"]
			var length := 0.0
			for i in path.size() - 1:
				length += _flat(path[i]).distance_to(_flat(path[i + 1]))
			beat["length"] = length
			var speed: float = beat.get("speed", WALK_SPEED)
			beat["ticks"] = maxi(1, int(ceil(length / speed * TPS)))
			if beat.get("cut", false):
				_place(w, path[0], _heading(path), true)
			if beat.has("gesture"):
				_gesture_pending[w] = beat["gesture"]
			# A gesture already going carries on across the cut.
			if not _gesture.has(w):
				var clip: String = beat.get("walk_clip", "strikes/entrance_walk")
				if w._presentation_clip != clip:
					_walk_clock[w] = 0
				w.play_presentation_clip(clip)
		"pose", "clip":
			_end_gestures(w)
			w.play_presentation_clip(beat["clip"])
			_pose_top(w if beat["kind"] == "pose" and _in_ring(w) else null)
		"turn":
			beat["ticks"] = SETTLE_TICKS if beat.get("settle", false) else 18
			_end_gestures(w)
			w.play_presentation_clip(_wait_clip(w))
		"pair":
			for move: Array in beat["moves"]:
				(move[0] as WrestlerController).play_presentation_clip(move[4])


## The name card: up once he is half way down the ramp, away at its foot.
func _tick_ramp_card(w: WrestlerController) -> void:
	var z := w.global_position.z
	var halfway := (ArenaBuilder.STAGE_FRONT + CUT_TO_Z) * 0.5
	if z >= halfway and z <= CUT_TO_Z + 0.5:
		if not _card.is_showing():
			_card.show_card(w.display_name if w.display_name != "" else String(w.name),
					w.entrance_subtitle)
	elif _card.is_showing():
		_card.hide_card()


func _physics_process(delta: float) -> void:
	if _done or _beat >= _beats.size():
		return
	if Input.is_action_just_pressed("ui_accept"):
		skip()
		return
	var beat: Dictionary = _beats[_beat]
	_tick += 1
	var t := clampf(float(_tick) / float(beat["ticks"]), 0.0, 1.0)
	var w: WrestlerController = beat.get("who")
	for cue: Array in beat.get("events", []):
		if int(cue[0]) == _tick:
			_event(w, cue[1])
	if beat.get("ramp_card", false) and w:
		_tick_ramp_card(w)
	match beat["kind"]:
		"walk":
			var at := _along(beat["path"], t * float(beat["length"]))
			_place(w, at[0], at[1], false, delta)
			_tick_gesture(w, beat)
		"pose":
			_place(w, w.global_position, beat["facing"], false, delta)
		"turn":
			_place(w, w.global_position, beat["facing"], false, delta)
		"pair":
			for move: Array in beat["moves"]:
				var m: WrestlerController = move[0]
				_place(m, (move[1] as Vector3).lerp(move[2], t), move[3], false, delta)
		"clip":
			var from: Vector3 = beat["from"]
			var to: Vector3 = beat["to"]
			w.global_position = from.lerp(to, t)
			w.global_transform.basis = _facing_basis(beat["facing"])
			if beat["clip"] == "strikes/rope_step_through_apron":
				_part_ropes(w, t, beat["facing"])
	_frame_shot(beat, delta)
	_aim_follow_spot(w)
	_aim_tron_rim(w)
	var waiting: bool = beat.get("wait_idle", false) and _handoff != null \
			and not _handoff.is_idle() and _tick < int(beat["ticks"]) + HANDOFF_MAX_WAIT
	if _tick >= int(beat["ticks"]) and not waiting:
		if beat.get("clip", "") == "strikes/rope_step_through_apron":
			_release_ropes()
		_beat += 1
		_start_beat()


## Skip straight to the bell, both men on their marks.
func skip() -> void:
	_beat = _beats.size()
	_ring_bell()


func _ring_bell() -> void:
	if _done:
		return
	_done = true
	_release_ropes()
	_card.hide_card()
	_portal_lights("", false)
	if _follow:
		_follow.visible = false
	if _walk_key:
		_walk_key.visible = false
	if _walk_back:
		_walk_back.visible = false
	# Whatever is still on its way goes to the table, before the men's props go.
	if _handoff:
		_handoff.finish_now()
	for props: EntranceProps in _props.values():
		props.queue_free()
	_props.clear()
	for coat: EntranceCoat in _coats.values():
		coat.queue_free()
	_coats.clear()
	if _pyro:
		_pyro.queue_free()
		_pyro = null
	if _wall:
		_wall.end_entrance()
	_tron_on = false
	if _tron_rim:
		_tron_rim.visible = false
	_dim_house(false)
	_pose_top(null)
	if _backlight:
		_backlight.queue_free()
		_backlight = null
	_smoke_off()
	for w: WrestlerController in [_a, _b]:
		w.global_transform = _mark[w]
		w.velocity = Vector3.ZERO
		w.visible = true
		w.end_presentation()
	for entry: Array in _frozen:
		(entry[0] as Node).set_physics_process(entry[1])
	if _hud and "visible" in _hud:
		_hud.visible = true
	if _camera:
		_camera.resume_master()
	if _crowd:
		_crowd.set_flashes(CrowdReaction.MATCH_FLASH_RATE)
		_crowd.pop(0.7)
	bell.emit()


## Roman Reigns, the OTC, as the broadcast does it (gauntlet/refs/entrances.md
## "Measured off broadcast footage", R-41 and R-CJ). The set blue, the stage
## empty while his music builds; he is found deep in his portal walking at a
## long lens, stops on the lip and looks the building over, a close-up, and
## the finger goes up so that it is in the air when the music slams (45.0 s)
## and the pyro and the red flash go with it. He HOLDS it -- eighteen seconds
## in the footage, under a low wide from the ramp -- then walks the whole way
## down on the low ultra-wide steadicam, cut with very wides from high and a
## look over his shoulder. At ringside, head bowed, eyes shut; up the steps
## and in; the finger to the hard camera, hands on hips, the ula fala off.
## No title: the OTC era.
func _add_roman_entrance(w: WrestlerController, portal_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 1.2)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var blue := {"lights": side, "light_color": ROMAN_BLUE}
	# Backward from the slam: the finger's arm arrives FINGER_PYRO_AT ticks
	# into Finger_Hold, so it starts that much before the slam; before it he
	# stands on the lip (the push-in, then the close-up); before that, the walk
	# out from the portal at his pace. What is left of the music is the empty
	# stage.
	var finger_start := ROMAN_MUSIC_HIT - float(FINGER_PYRO_AT) / TPS
	var stand_start := finger_start - ROMAN_LIP_PUSH - ROMAN_LIP_FACE
	var walk_s := _flat(emerge).distance_to(_flat(lip)) / ROMAN_WALK_SPEED
	var appear := stand_start - walk_s
	_beats.append({"kind": "hold", "who": w,
			"ticks": _secs(0.0, appear), "shot": "intro",
			"events": [[1, "tron_on"], [1, "dim_on"]]})
	var half := emerge.lerp(lip, 0.5)
	# He walks out as the first pyro goes off, on the very wide so the burst
	# reads; then the usual stage cut.
	var early := emerge.lerp(lip, minf(0.4, ROMAN_FIRST_PYRO_SHOT * ROMAN_WALK_SPEED
			/ maxf(_flat(emerge).distance_to(_flat(lip)), 0.01)))
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [emerge, early],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "stage_wide", "appear": true, "props": true,
			"events": [[1, "pyro_stage"]]}))
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [early, half],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "stage"}))
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [half, lip],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "face_walk"}))
	# On the lip: the building looked over, then the close-up.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(0.0, ROMAN_LIP_PUSH),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "stage_push"}))
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(0.0, ROMAN_LIP_FACE),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "face_walk"}))
	# The finger, and on the slam the pyro and the room red, on a very wide.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(finger_start, ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE),
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "hero_low",
			"events": [[FINGER_PYRO_AT, "pyro_roman"], [FINGER_PYRO_AT, "accent_red"],
					[FINGER_PYRO_AT + ROMAN_RED_TICKS, "accent_back"]]}))
	# Held, under the low wide from the ramp.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE, ROMAN_FINGER_DOWN),
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "ramp_low_wide"}))
	# The walk: all of it, cut the way the broadcast cuts it.
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS - 0.2)
	_add_walk_cut(w, lip, foot, ROMAN_WALK_SPEED, ROMAN_WALK_CLIP, ROMAN_WALK_SHOTS,
			[], true)
	# Ringside, the head bowed, then up the steps and through the ropes.
	var in_at := _add_route_in(w, foot, ROMAN_WALK_SPEED, ROMAN_WALK_CLIP, true, "",
			"strikes/head_bow", ROMAN_BOW_TICKS)
	var centre := Vector3(-0.4, 0.0, -0.6)
	_beats.append({"kind": "walk", "who": w, "path": [in_at, centre],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": Vector3.BACK,
			"shot": "ring_low"})
	# The title off his waist and up over his head, the camera low on the
	# mat looking up at it.
	_beats.append({"kind": "pose", "who": w, "ticks": 90,
			"clip": "strikes/title_unbuckle", "facing": Vector3.BACK,
			"shot": "ring_low", "events": [[1, "prop_call_title"],
					[TITLE_UNBUCKLED_AT, "title_held"]]})
	_beats.append({"kind": "pose", "who": w, "ticks": 120,
			"clip": "strikes/title_raise", "facing": Vector3.BACK,
			"shot": "hero_low"})
	# The belt, handed on: Aubrey is at his side by now; the pass is on the
	# 26th frame of his hand-out (PropHandoff.GIVE_CONTACT).
	_beats.append({"kind": "pose", "who": w, "ticks": _secs(0.0, HAND_OUT_SECONDS),
			"clip": "strikes/prop_hand_out_l", "facing": Vector3.BACK,
			"shot": "ring_low", "events": [[1, "prop_pass_title"]]})
	# The finger to the hard camera, then hands on hips, staring, close.
	_beats.append({"kind": "pose", "who": w, "ticks": 240,
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "ring_behind_out"})
	# Hands on hips; Aubrey, back from the timekeeper, comes for the ula fala.
	_beats.append({"kind": "pose", "who": w, "ticks": 300,
			"clip": "strikes/hands_hips", "facing": Vector3.BACK,
			"shot": "face_walk", "events": [[1, "prop_call_fala"]]})
	_beats.append({"kind": "pose", "who": w, "ticks": 90,
			"clip": "strikes/ula_fala_off", "facing": Vector3.BACK,
			"shot": "ring_low", "events": [[ULA_FALA_LIFT_AT, "fala_off"]]})
	_beats.append({"kind": "pose", "who": w, "ticks": _secs(0.0, HAND_OUT_SECONDS),
			"clip": "strikes/prop_hand_out_r", "facing": Vector3.BACK,
			"shot": "ring_low", "events": [[1, "prop_pass_fala"]]})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w, "path": [centre, mark.origin],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "end_wide", "settle": true,
			"events": [[SETTLE_TICKS, "tron_off"], [SETTLE_TICKS, "dim_off"]]})
	# Nothing moves on until the last prop is on the timekeeper's table.
	_beats.append({"kind": "hold", "who": w, "ticks": 30, "shot": "end_wide",
			"wait_idle": true})


## A long walk from `from` to `to` as the broadcast cuts it: consecutive
## walk beats, each on the next of `shots` ([shot, seconds], cycled), so he
## never stops and the cut is only the camera's.
func _add_walk_cut(w: WrestlerController, from: Vector3, to: Vector3, speed: float,
		clip: String, shots: Array, gestures: Array = [], ramp_card := false) -> void:
	var total := _flat(from).distance_to(_flat(to))
	var done := 0.0
	var i := 0
	while done < total - 0.01:
		var shot: Array = shots[i % shots.size()]
		var step := minf(float(shot[1]) * speed, total - done)
		var a := from.lerp(to, done / total)
		var b := from.lerp(to, (done + step) / total)
		var beat := {"kind": "walk", "who": w, "path": [a, b], "speed": speed,
				"walk_clip": clip, "shot": shot[0]}
		if i < gestures.size():
			beat["gesture"] = gestures[i]
		if ramp_card:
			beat["ramp_card"] = true
		_beats.append(beat)
		done += step
		i += 1


## Cody Rhodes, as the broadcast does it (gauntlet/refs/entrances.md
## "Measured off broadcast footage", C-39, C-MITB, C-SS, C-SNME). Black, and
## through the WHOAs the cameras are on the BUILDING -- the crowd, the dark
## wide -- not on him. On the last WHOA he walks out of the smoke in his
## portal, backlit, at a long lens; on the hit, the WHOA pose -- arms straight
## out, palms forward, head back -- and the pyro on a very wide; then both
## fists driven down, and the second burst. To the lip on the low steadicam,
## and there the kneel: down on the right knee, head bowed, then up at the
## crowd. Down the ramp working both sides, the WHOA again low in the aisle,
## round to the steps and in over the ropes with the camera low behind him in
## the ring. Every beat to the hit is on the measured music (CODY_*).
func _add_cody_entrance(w: WrestlerController, portal_x: float, _side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var mouth := Vector3(portal_x, deck, ArenaBuilder.PORTAL_FACE_Z + 0.5)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var foot_of_ramp := Vector3(0.0, 0.0, CUT_TO_Z)
	# He walks out of the smoke at his own pace: far enough back in it that
	# Walk_Crowd's planted foot keeps the mat from sliding under the boot.
	var emerge_s := CODY_WHOA - float(WHOA_WIDE_AT) / TPS - CODY_EMERGE
	var smoke := mouth - Vector3(0.0, 0.0, CODY_WALK_SPEED * emerge_s)
	var dark := {"lights": "OFF", "no_follow": true}
	# The intro and the band: black, the wall, and the building -- the crowd
	# and the dark wide, a strobe on each swell -- never the man.
	_beats.append({"kind": "hold", "who": w, "ticks": _secs(0.0, CODY_WHOA_1),
			"shot": "cody_dark", "lights": "OFF",
			"events": [[1, "tron_on"], [1, "blackout_on"]]})
	# The stage is in it twice, both on the wide from the far end; the rest
	# is the building -- the owner found the old cut "went to the tunnel too
	# soon", three of its six shots on the dark stage.
	# The screen is black until the band hits, so the WHOAs play on the dark
	# house (one short crowd cutaway, not the four it had); then his video
	# starts and the camera is on it, back to the wall again before the smoke.
	for cut: Array in [[CODY_WHOA_1, CODY_WHOA_2, "cody_dark", true],
			[CODY_WHOA_2, CODY_WHOA_3, "crowd_wide", true],
			[CODY_WHOA_3, CODY_BAND, "arena_dark_high", true],
			[CODY_BAND, 12.5, "tron_video", false],
			[12.5, 16.0, "arena_dark_high", false],
			[16.0, CODY_SMOKE, "tron_video", false]]:
		_beats.append(_with(dark, {"kind": "hold", "who": w,
				"ticks": _secs(cut[0], cut[1]), "shot": cut[2],
				"events": [[1, "strobe"]] if cut[3] else []}))
	# The smoke builds in his portal, lit from behind -- seen on the far wide
	# of the dark house, never on a close lens into the empty portal (the
	# owner's note); the long lens finds him as he walks out of it.
	_beats.append(_with(dark, {"kind": "hold", "who": w,
			"ticks": _secs(CODY_SMOKE, CODY_EMERGE), "shot": "cody_dark",
			"portal": mouth, "push_from": 0, "push_over": _secs(CODY_SMOKE, CODY_WHOA),
			"fog_at": smoke, "lights": "RB_LOW",
			"events": [[1, "fog_on"], [1, "backlight_on"]]}))
	# Out of it on the first sung WHOA, at the lens.
	_beats.append({"kind": "walk", "who": w, "appear": true, "coat": true,
			"no_follow": true, "lights": "RB_LOW", "path": [smoke, mouth],
			# A hair over the exact speed, so the tick count rounds to the
			# measured gap and the WHOA lands on its frame.
			"speed": _flat(smoke).distance_to(_flat(mouth))
					/ (float(_secs(CODY_EMERGE, CODY_WHOA - float(WHOA_WIDE_AT) / TPS))
					/ TPS) * 1.000001,
			"walk_clip": CODY_WALK_CLIP, "shot": "portal_long", "portal": mouth,
			"push_from": _secs(CODY_SMOKE, CODY_EMERGE),
			"push_over": _secs(CODY_SMOKE, CODY_WHOA)})
	# THE WHOA: the wind-up, then the arms wide on the chant and the building
	# lit with it; held on the long lens from down the ramp (C-39 21-23 s),
	# the very wide for the pyro (C-39 23.5 s).
	var whoa_from := CODY_WHOA - float(WHOA_WIDE_AT) / TPS
	_beats.append({"kind": "pose", "who": w, "lights": "RB_LOW",
			"ticks": WHOA_WIDE_AT, "clip": "strikes/whoa_arms",
			"facing": Vector3.BACK, "shot": "ramp_long"})
	_beats.append({"kind": "pose", "who": w, "lights": "RB",
			"ticks": _secs(whoa_from, CODY_PYRO) - WHOA_WIDE_AT,
			"clip": "strikes/whoa_arms", "facing": Vector3.BACK, "shot": "ramp_long",
			"events": [[1, "house_walk"], [1, "backlight_off"], [1, "fog_off"]]})
	var punch_from := CODY_PUNCH - float(CODY_PUNCH_AT) / TPS
	_beats.append({"kind": "pose", "who": w, "lights": "RB",
			"ticks": _secs(CODY_PYRO, punch_from), "clip": "strikes/whoa_arms",
			"facing": Vector3.BACK, "shot": "stage_wide",
			"events": [[1, "pyro_cody_hit"]]})
	# The fists, the second burst, the card.
	var fists_end := punch_from + 1.0 + 1.0 / 3.0
	_beats.append({"kind": "pose", "who": w, "lights": "RB",
			"ticks": _secs(punch_from, fists_end), "clip": "strikes/fists_down",
			"facing": Vector3.BACK, "shot": "hero_low",
			"events": [[CODY_PUNCH_AT, "pyro_cody_punch"]]})
	# To the lip on the low steadicam, the card up until he stops; working
	# the crowd there for whatever is left, so the knee lands on its phrase.
	var kneel_from := CODY_KNEEL - float(KNEEL_DOWN_AT) / TPS
	# A short gap goes into his pace, not a stand: a presentation clip held
	# for less than its cross-fade never finishes blending in, and the clip
	# after it was lost with it -- rendered, he stood through the whole kneel
	# behind a 0.33 s stand. Only a gap long enough to blend gets one.
	var to_lip := _flat(mouth).distance_to(_flat(lip))
	var lip_speed := to_lip / (kneel_from - fists_end)
	if lip_speed < CODY_WALK_SPEED * 0.8:
		lip_speed = CODY_WALK_SPEED
	lip_speed = minf(lip_speed, CODY_WALK_SPEED * 1.4)
	_beats.append({"kind": "walk", "who": w, "path": [mouth, lip], "lights": "RB",
			"speed": lip_speed, "walk_clip": CODY_WALK_CLIP,
			"shot": "steadicam_front"})
	var at_lip := fists_end + to_lip / lip_speed
	if kneel_from - at_lip > 0.6:
		_beats.append({"kind": "pose", "who": w, "lights": "RB",
				"ticks": _secs(at_lip, kneel_from), "clip": "strikes/cody_stand",
				"facing": Vector3.BACK, "shot": "over_shoulder"})
	# The kneel at the top of the ramp, on a long lens from down it.
	_beats.append({"kind": "pose", "who": w, "lights": "RB", "ticks": CODY_KNEEL_TICKS,
			"clip": "strikes/kneel", "facing": Vector3.BACK, "shot": "ramp_long"})
	# Down the ramp exactly as far as his pace takes him before the held
	# WHOAAA, and the low WHOA there.
	var kneel_end := kneel_from + float(CODY_KNEEL_TICKS) / TPS
	var low_from := CODY_WHOA_LOW - float(WHOA_LOW_WIDE_AT) / TPS
	var down := CODY_WALK_SPEED * (low_from - kneel_end)
	var mid := lip.lerp(foot_of_ramp, clampf(down / _flat(lip).distance_to(_flat(foot_of_ramp)),
			0.0, 1.0))
	_beats.append({"kind": "walk", "who": w, "path": [lip, mid], "lights": "RB",
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "steadicam_low", "ramp_card": true})
	_beats.append({"kind": "pose", "who": w, "ticks": CODY_WHOA_LOW_TICKS,
			"clip": "strikes/whoa_low", "facing": Vector3.BACK, "shot": "hero_low",
			"ramp_card": true})
	var foot := foot_of_ramp
	_add_walk_cut(w, mid, foot, CODY_WALK_SPEED, CODY_WALK_CLIP, CODY_WALK_SHOTS,
			CODY_WALK_GESTURES, true)
	var in_at := _add_route_in(w, foot, CODY_WALK_SPEED, CODY_WALK_CLIP, true,
			"", "", 0, "ring_behind_low")
	# The corner by the steps: up on the middle rope, facing out over them.
	# (Sourced [S], not in any of the measured clips.)
	# Measured from the turnbuckle pads, which are where the man stands on
	# the ropes -- not the post, which now stands out at the deck corner
	# beyond the turnbuckle hardware (RingBuilder.POST_XZ).
	var post := Vector3(ENTRY_CORNER.x * RingBuilder.TURNBUCKLE_PAD_XZ, 0.0,
			ENTRY_CORNER.y * RingBuilder.TURNBUCKLE_PAD_XZ)
	var out_dir := RingBuilder.step_out_dir(ENTRY_CORNER)
	var stand := post - out_dir * CORNER_ROOT_M
	_beats.append({"kind": "walk", "who": w, "path": [in_at, stand],
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "ring_behind_low", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": out_dir, "shot": "corner_low"})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_climb",
			"ticks": 72, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low"})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_pose",
			"ticks": 180, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low", "events": [[CODY_CORNER_PYRO_AT, "pyro_over_ring"]]})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_down",
			"ticks": 60, "from": stand, "to": stand, "facing": out_dir,
			"shot": "ring_high_corner"})
	# Down off the rope, and the coat comes off to the crew at ringside.
	var mark: Transform3D = _mark[w]
	# He hands it on facing in, toward the middle of the ring: Aubrey comes
	# to him from there, not from the corner post behind him.
	var inward := (Vector3(mark.origin.x - stand.x, 0.0, mark.origin.z - stand.z)).normalized()
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/coat_off",
			"ticks": 120, "from": stand, "to": stand, "facing": out_dir,
			"shot": "ring_low", "pass_facing": inward,
			"events": [[1, "prop_call_coat"], [COAT_OFF_AT, "coat_off"]]})
	_beats.append({"kind": "turn", "who": w, "facing": inward, "shot": "ring_low"})
	_beats.append({"kind": "pose", "who": w, "ticks": _secs(0.0, HAND_OUT_SECONDS),
			"clip": "strikes/prop_hand_out_r", "facing": inward,
			"shot": "ring_low", "events": [[1, "prop_pass_coat"]]})
	_beats.append({"kind": "walk", "who": w, "path": [stand, mark.origin],
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "ringside", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "end_wide", "settle": true, "events": [[SETTLE_TICKS, "tron_off"]]})
	# Nothing moves on until the coat is on the timekeeper's table.
	_beats.append({"kind": "hold", "who": w, "ticks": 30, "shot": "end_wide",
			"wait_idle": true})


## The way into the ring every entrance shares, from the ramp's cut to the
## mat, over the diagonal steps (ring_builder.gd "Steel steps"): across the
## floor to the foot of the flight, in along its diagonal, up it toward the
## post, up onto the apron beside the post, and through the ropes a pace along
## the side. Appends the beats; returns where he lands on the mat.
##
## `split_floor` gives the floor walk its own tracking shot up to the
## approach (Roman's); `survey_clip`, if set, is played standing on the apron
## before he goes in; `floor_clip`, if set, is played for `floor_ticks` at the
## foot of the steps, facing them, on a close shot (Roman's bowed head);
## `entry_shot` frames the step through the ropes (Cody's is from inside the
## ring, low, behind him).
func _add_route_in(w: WrestlerController, cut: Vector3, speed: float,
		walk_clip: String, split_floor: bool, survey_clip := "",
		floor_clip := "", floor_ticks := 0, entry_shot := "ringside") -> Vector3:
	var out := RingBuilder.step_out_dir(ENTRY_CORNER)
	var top := RingBuilder.step_top_centre(ENTRY_CORNER)
	var climb_from := top + out * CLIMB_TO.x
	var approach := climb_from + out * APPROACH_M
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS + 0.4)
	if split_floor:
		_beats.append({"kind": "walk", "who": w, "path": [cut, foot, approach],
				"speed": speed, "walk_clip": walk_clip, "shot": "floor_track", "cut": true})
		_beats.append({"kind": "walk", "who": w, "path": [approach, climb_from],
				"speed": speed, "walk_clip": walk_clip, "shot": "ringside"})
	else:
		_beats.append({"kind": "walk", "who": w, "path": [cut, foot, approach, climb_from],
				"speed": speed, "walk_clip": walk_clip, "shot": "ringside", "cut": true})
	_beats.append({"kind": "turn", "who": w, "facing": -out, "shot": "ringside"})
	if floor_clip != "":
		_beats.append({"kind": "pose", "who": w, "ticks": floor_ticks,
				"clip": floor_clip, "facing": -out, "shot": "bow_close"})
	var top_at := Vector3(top.x, ArenaBuilder.FLOOR_Y + CLIMB_TO.y, top.z)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/climb_steps",
			"ticks": int(round(CLIMB_SECONDS * TPS)),
			"from": Vector3(climb_from.x, ArenaBuilder.FLOOR_Y, climb_from.z),
			"to": top_at, "facing": -out, "shot": "ringside"})
	# Onto the apron, a pace along the side from the post.
	var apron := Vector3(ENTRY_CORNER.x * (RingBuilder.TURNBUCKLE_PAD_XZ - APRON_ALONG_M), 0.0,
			ENTRY_CORNER.y * APRON_STAND)
	var across := _flat(apron - top_at)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/apron_step",
			"ticks": int(round(APRON_STEP_SECONDS * TPS)),
			"from": top_at, "to": apron, "facing": across, "shot": "ringside"})
	# Square to the ropes: facing into the ring across the -Z side.
	var into := Vector3(0.0, 0.0, -ENTRY_CORNER.y)
	_beats.append({"kind": "turn", "who": w, "facing": into, "shot": "ringside"})
	if survey_clip != "":
		_beats.append({"kind": "clip", "who": w, "clip": survey_clip,
				"ticks": 60, "from": apron, "to": apron, "facing": into, "shot": "ringside"})
	var inside := apron + into * APRON_ROPE_TO.x
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/rope_step_through_apron",
			"ticks": int(round(APRON_ROPE_SECONDS * TPS)),
			"from": apron, "to": inside, "facing": into, "shot": entry_shot})
	return inside


## Through the ropes from the apron (refs/ropes.md): his left hand takes the
## top rope and lifts it as he ducks under, the middle rope sits down under
## his thigh, and both are eased back as he stands up inside. In clip frames
## of Rope_Step_Through_Apron (40): hands on the top rope from 0, the lead
## leg over by 6 and down inside by 12, ducked under by 18, the trail leg
## over by 30, up by 40.
const ROPE_GRIP := [0.0, 3.0, 25.0, 35.0]
const ROPE_PRESS := [4.0, 12.0, 26.0, 34.0]
## How far the middle rope goes down under him.
const ROPE_PRESS_M := 0.18


## The weight of a hold at clip frame `f`, from [in, full, out, gone] frames.
static func hold_weight(f: float, keys: Array) -> float:
	if f <= keys[0] or f >= keys[3]:
		return 0.0
	if f < keys[1]:
		return smoothstep(keys[0], keys[1], f)
	if f > keys[2]:
		return 1.0 - smoothstep(keys[2], keys[3], f)
	return 1.0


func _part_ropes(w: WrestlerController, t: float, into: Vector3) -> void:
	if _ropes == null:
		_ropes = get_parent().find_child("LiveRopes", true, false) as RingRopes
		if _ropes == null:
			return
	var f := t * 40.0
	var hand := w._bone_world("hand_l")
	if hand != Vector3.INF:
		_ropes.hold("entry_grip", hand, RingBuilder.ROPE_HEIGHT_TOP, hold_weight(f, ROPE_GRIP))
	var hips := w._bone_world("pelvis")
	if hips != Vector3.INF:
		var n := _flat(into).normalized()
		var on_line := hips + n * (-RingBuilder.ROPE_SPAN - hips.dot(n))
		on_line.y = _ropes.global_position.y + RingBuilder.ROPE_HEIGHT_MIDDLE - ROPE_PRESS_M
		_ropes.hold("entry_press", on_line, RingBuilder.ROPE_HEIGHT_MIDDLE,
				hold_weight(f, ROPE_PRESS), false)


func _release_ropes() -> void:
	if _ropes:
		_ropes.release("entry_grip")
		_ropes.release("entry_press")


## One tick of the walk gestures: a waiting one goes in on the plain walk's
## next cycle boundary, and a finished one hands back to the plain walk,
## which then starts its cycle where the gesture's ended.
func _tick_gesture(w: WrestlerController, beat: Dictionary) -> void:
	if _gesture.has(w):
		_gesture[w][1] -= 1
		if _gesture[w][1] <= 0:
			_gesture.erase(w)
			_walk_clock[w] = 0
			w.play_presentation_clip(beat.get("walk_clip", "strikes/entrance_walk"))
		return
	_walk_clock[w] = int(_walk_clock.get(w, 0)) + 1
	if _gesture_pending.has(w) and int(_walk_clock[w]) % WALK_CYCLE_TICKS == 0:
		var clip: String = _gesture_pending[w]
		_gesture_pending.erase(w)
		_gesture[w] = [clip, WALK_GESTURE_TICKS]
		gestures_played.append(clip)
		w.play_presentation_clip(clip)


## He has stopped walking: no gesture waits or carries on into the stop.
func _end_gestures(w: WrestlerController) -> void:
	if w:
		_gesture.erase(w)
		_gesture_pending.erase(w)


## Ticks between two music times.
static func _secs(from: float, to: float) -> int:
	return int(round((to - from) * TPS))


## Cody's backlight: one cold spot in his portal behind him, aimed down the
## ramp at the camera, so he is a shape against light in the haze.
func _set_backlight(w: WrestlerController, what: String) -> void:
	if _backlight == null:
		_backlight = SpotLight3D.new()
		_backlight.name = "Backlight"
		_backlight.light_color = BACKLIGHT_COLOR
		_backlight.spot_angle = 28.0
		_backlight.spot_range = 40.0
		_backlight.light_volumetric_fog_energy = 3.0
		# No shadow: its cone cast a dark disc on the deck under the smoke.
		_backlight.shadow_enabled = false
		add_child(_backlight)
		_backlight.global_position = w.global_position + Vector3(0.0, 3.4, -2.6)
		_backlight.look_at(w.global_position + Vector3(0.0, 1.2, 6.0), Vector3.UP)
	match what:
		"backlight_on":
			_backlight.light_energy = BACKLIGHT_ENERGY
			_backlight.visible = true
		"backlight_dim":
			_backlight.light_energy = BACKLIGHT_ENERGY * 0.3
		"backlight_off":
			_backlight.visible = false


static func _with(base: Dictionary, beat: Dictionary) -> Dictionary:
	var out := base.duplicate()
	out.merge(beat, true)
	return out


## Where the man in the current beat faces, or ZERO if it does not say.
func _beat_facing() -> Vector3:
	return (_beats[mini(_beat, _beats.size() - 1)] as Dictionary).get("facing", Vector3.ZERO)


## A cue inside a beat.
func _event(w: WrestlerController, what: String) -> void:
	cue.emit(what)
	var props: EntranceProps = _props.get(w)
	match what:
		"lights_up":
			_dim_house(false)
		"title_held":
			if props:
				props.set_title("held")
		"title_down":
			if props and _handoff == null:
				props.set_title("")
		"prop_call_title":
			if props and _handoff:
				_handoff.request("title", w, props, _beat_facing())
		"prop_call_fala":
			if props and _handoff:
				_handoff.request("fala", w, props, _beat_facing())
		"prop_pass_title", "prop_pass_fala", "prop_pass_coat":
			if _handoff:
				_handoff.giver_begins()
		"prop_call_coat":
			var worn: EntranceCoat = _coats.get(w)
			if worn and _handoff:
				var beat: Dictionary = _beats[mini(_beat, _beats.size() - 1)]
				_handoff.request("coat", w, worn, beat.get("pass_facing", _beat_facing()))
		"coat_off":
			var coat: EntranceCoat = _coats.get(w)
			if coat and _handoff:
				# Off his shoulders and into his hand: a folded coat now.
				_handoff.lift("coat")
			elif coat:
				coat.set_worn(false)
		"fala_off":
			if props and _handoff:
				# Over his head and into his hand: a thing he holds now.
				_handoff.lift("fala")
			elif props:
				props.set_fala_visible(false)
		"tron_on":
			_tron_on = true
			if _tron_rim:
				_tron_rim.light_color = StageVideo.glow_color(w.entrance_style)
			if _wall:
				_wall.play_entrance(w.entrance_style)
		"tron_off":
			_tron_on = false
			if _wall:
				_wall.end_entrance()
		"dim_on":
			_dim_house(true)
		"blackout_on":
			_dim_house(true, CODY_BLACKOUT, CODY_BLACKOUT_AMBIENT)
		"backlight_on", "backlight_dim", "backlight_off":
			_set_backlight(w, what)
		"strobe", "pyro_cody_hit", "pyro_cody_punch":
			if what == "pyro_cody_hit" and _lights and _lights.has_method("sync_beat"):
				_lights.sync_beat(CODY_BEAT)
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))
			if _crowd:
				_crowd.pop(CROWD_PYRO_POP)
		"house_walk":
			# Out of the blackout on the WHOA, but only to the walk's level:
			# the house stays down through the walk, as 2K26's concert look
			# does (refs/lighting_2k26.md item 7) -- it used to come all the
			# way back up here.
			_dim_house(false)
			_dim_house(true, WALK_HOUSE_DIM, WALK_AMBIENT_DIM)
		"dim_off":
			_dim_house(false)
		"accent_red":
			_accents_to(ROMAN_PYRO_RED, 3.0)
		"accent_back":
			var now: Dictionary = _beats[mini(_beat, _beats.size() - 1)]
			_portal_lights(now.get("lights", ""), now.has("lights"),
					now.get("light_color", Color.TRANSPARENT))
		"fog_on":
			_smoke_on(w)
		"fog_off":
			_smoke_off()
		"pyro_stage", "pyro_over_ring", "pyro_roman":
			if what == "pyro_roman" and _lights and _lights.has_method("sync_beat"):
				_lights.sync_beat(ROMAN_BEAT)
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))
			if _crowd:
				_crowd.pop(CROWD_PYRO_POP)


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

## The surface height at a point: stage deck, ramp, or the floor.
static func surface_y(p: Vector3) -> float:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var foot_z := -ArenaBuilder.BARRICADE_RADIUS
	var floor_y := ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT
	if p.z <= ArenaBuilder.STAGE_FRONT:
		return deck
	if p.z < foot_z and absf(p.x) <= ArenaBuilder.RAMP_HALF_WIDTH + 0.2:
		# entrance_set.py's wedge: the deck at the stage lip down to 0.04 over
		# the floor at the ramp foot, straight.
		var u := (p.z - ArenaBuilder.STAGE_FRONT) / (foot_z - ArenaBuilder.STAGE_FRONT)
		return lerpf(deck, ArenaBuilder.FLOOR_Y + 0.04, u)
	return floor_y


## A point and a heading `distance` metres along a polyline, on the surface.
func _along(path: Array, distance: float) -> Array:
	var left := distance
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var seg := _flat(a).distance_to(_flat(b))
		if left <= seg or i == path.size() - 2:
			var p := a.lerp(b, clampf(left / maxf(seg, 0.0001), 0.0, 1.0))
			return [p, b - a]
		left -= seg
	return [path[-1], Vector3.BACK]


func _heading(path: Array) -> Vector3:
	return (path[1] as Vector3) - (path[0] as Vector3)


## Puts a man at `at` (dropped onto the surface under it, or the mat), easing
## his facing toward `heading` -- a walker turns into a corner, he does not
## snap to it.
func _place(w: WrestlerController, at: Vector3, heading: Vector3, snap: bool,
		delta: float = 1.0 / 60.0) -> void:
	var p := at
	p.y = surface_y(at) if absf(at.x) > 3.2 or absf(at.z) > 3.2 else 0.0
	w.global_position = p
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length() < 0.001:
		return
	var want := atan2(-flat.x, -flat.z)
	if snap:
		w.rotation.y = want
	else:
		w.rotation.y = rotate_toward(w.rotation.y, want, TURN_RATE * delta)


static func _facing_basis(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.x, -dir.z))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------------------
# Camera and lights
# ---------------------------------------------------------------------------

func _frame_shot(beat: Dictionary, delta: float) -> void:
	if not _camera:
		return
	var w: WrestlerController = beat.get("who")
	var first := _tick == 1
	match beat.get("shot", beat["kind"]):
		"opening":
			_camera.set_entrance_shot(OPENING_AT, OPENING_LOOK, OPENING_FOV, true)
		"stage":
			_camera.set_entrance_shot(STAGE_AT, w.global_position + Vector3.UP * 1.3,
					STAGE_FOV, first and not _was_shot("stage"))
		"track":
			_camera.set_entrance_shot(w.global_position + TRACK_OFFSET,
					w.global_position + Vector3.UP * 1.35, TRACK_FOV, first, delta)
		"intro":
			_intro_shot()
		"cody_dark":
			_camera.set_entrance_shot(CODY_DARK_AT, CODY_DARK_LOOK, CODY_DARK_FOV, true)
		"tron_video":
			_camera.set_entrance_shot(TRON_SHOT_AT, TRON_AT, TRON_SHOT_FOV, true)
		"portal_long":
			# From down the ramp, dead on his portal, the lens creeping in
			# across the three WHOAs.
			var portal: Vector3 = beat.get("portal", w.global_position)
			var e := clampf(float(_tick + int(beat.get("push_from", 0)))
					/ float(beat.get("push_over", 400)), 0.0, 1.0)
			_camera.set_entrance_shot(Vector3(portal.x * 0.55, 1.6, -21.0),
					portal + Vector3.UP * 1.5,
					lerpf(PORTAL_LONG_FOV.x, PORTAL_LONG_FOV.y, e), true)
		"steadicam":
			var fwd3 := -w.global_transform.basis.z
			_camera.set_entrance_shot(w.global_position + fwd3 * 3.2 + Vector3.UP * 1.55,
					w.global_position + Vector3.UP * 1.5, STEADICAM_FOV, first, delta)
		"corner_low":
			_camera.set_entrance_shot(CORNER_LOW_AT, _head_of(w), CORNER_LOW_FOV, true)
		"face_walk":
			var head := _head_of(w)
			var fwd := -w.global_transform.basis.z
			var right := w.global_transform.basis.x
			_camera.set_entrance_shot(head + fwd * FACE_DISTANCE + right * 0.35
					+ Vector3.UP * 0.05, head, FACE_FOV, first, delta)
		"floor_track":
			var fwd2 := -w.global_transform.basis.z
			var right2 := w.global_transform.basis.x
			_camera.set_entrance_shot(w.global_position + fwd2 * 4.2 - right2 * 1.6
					+ Vector3.UP * 1.5, w.global_position + Vector3.UP * 1.45,
					FLOOR_TRACK_FOV, first, delta)
		"stage_push":
			var t := clampf(float(_tick) / float(beat["ticks"]), 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			_camera.set_entrance_shot(PUSH_FROM.lerp(PUSH_TO, e),
					w.global_position + Vector3.UP * 1.45,
					lerpf(PUSH_FOV.x, PUSH_FOV.y, e), true)
		"hero_low":
			_camera.set_entrance_shot(w.global_position + HERO_OFFSET,
					w.global_position + Vector3.UP * 1.6, HERO_FOV, true)
		"stage_wide":
			_camera.set_entrance_shot(STAGE_WIDE_AT, STAGE_WIDE_LOOK, STAGE_WIDE_FOV, true)
		"ring_low":
			_camera.set_entrance_shot(w.global_position + RING_LOW_OFFSET,
					w.global_position + Vector3.UP * 1.5, RING_LOW_FOV, true)
		"ringside":
			_camera.set_entrance_shot(RINGSIDE_AT, w.global_position + Vector3.UP * 1.0,
					RINGSIDE_FOV, true)
		"steadicam_front":
			# 2K26's walk: backing ahead of him at chest height on a normal
			# lens, his face and the set behind him.
			var f8 := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(w.global_position + f8 * STEADICAM_FRONT_AHEAD
					+ Vector3.UP * STEADICAM_FRONT_HEIGHT,
					w.global_position + Vector3.UP * 1.45, STEADICAM_FRONT_FOV, first, delta)
		"barricade_track":
			# Alongside him from the barricade, a little ahead, the crowd on the
			# far side behind him.
			var f9 := _flat(-w.global_transform.basis.z).normalized()
			var r9 := Vector3.UP.cross(-f9).normalized()
			if r9.x * w.global_position.x > 0.0:
				r9 = -r9
			_camera.set_entrance_shot(w.global_position + r9 * BARRICADE_TRACK_SIDE
					+ f9 * BARRICADE_TRACK_AHEAD + Vector3.UP * BARRICADE_TRACK_HEIGHT,
					w.global_position + Vector3.UP * 1.35, BARRICADE_TRACK_FOV, first, delta)
		"crowd_far":
			_camera.set_entrance_shot(CROWD_FAR_AT, CROWD_FAR_LOOK, CROWD_WIDE_FOV, true)
		"arena_dark_high":
			_camera.set_entrance_shot(ARENA_HIGH_AT, ARENA_DARK_LOOK, ARENA_HIGH_FOV, true)
		"steadicam_low":
			# Backing ahead of him, lens at his hips, tilted up past his chest.
			var f4 := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(w.global_position + f4 * STEADICAM_LOW_AHEAD
					+ Vector3.UP * STEADICAM_LOW_HEIGHT,
					w.global_position + Vector3.UP * 1.55, STEADICAM_LOW_FOV, first, delta)
		"arena_high":
			_camera.set_entrance_shot(ARENA_HIGH_AT, w.global_position + Vector3.UP * 1.0,
					ARENA_HIGH_FOV, true)
		"over_shoulder":
			var f5 := _flat(-w.global_transform.basis.z).normalized()
			var r5 := w.global_transform.basis.x
			_camera.set_entrance_shot(w.global_position - f5 * 1.8 + r5 * 0.45
					+ Vector3.UP * 1.8, w.global_position + f5 * 12.0 + Vector3.UP * 0.8,
					OVER_SHOULDER_FOV, first, delta)
		"ramp_low_wide":
			_camera.set_entrance_shot(RAMP_LOW_WIDE_AT, w.global_position + Vector3.UP * 2.2,
					RAMP_LOW_WIDE_FOV, true)
		"ramp_long":
			_camera.set_entrance_shot(Vector3(w.global_position.x * 0.5, 0.9,
					w.global_position.z + RAMP_LONG_BACK), w.global_position + Vector3.UP * 1.0,
					RAMP_LONG_FOV, true)
		"ring_behind_low":
			var f6 := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(w.global_position - f6 * 1.6 + Vector3.UP * 1.5,
					w.global_position + f6 * 3.0 + Vector3.UP * 1.4, RING_BEHIND_FOV,
					first, delta)
		"bow_close":
			# From his right and a little in front: straight ahead of him at the
			# steps is the ring post, which the lens would shoot through.
			var hb := _head_of(w)
			var fb := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(hb + w.global_transform.basis.x * BOW_SIDE
					+ fb * BOW_AHEAD, hb + Vector3.DOWN * 0.12, BOW_FOV, true)
		"crowd_wide":
			_camera.set_entrance_shot(CROWD_WIDE_AT, CROWD_WIDE_LOOK, CROWD_WIDE_FOV, true)
		"ramp_side_high":
			var side_x := RAMP_SIDE_HIGH_X if w.global_position.x <= 0.0 else -RAMP_SIDE_HIGH_X
			_camera.set_entrance_shot(Vector3(side_x, RAMP_SIDE_HIGH_Y,
					w.global_position.z + RAMP_SIDE_HIGH_LEAD),
					w.global_position + Vector3.UP * 1.2, RAMP_SIDE_HIGH_FOV, first, delta)
		"ring_high_corner":
			_camera.set_entrance_shot(RING_HIGH_CORNER_AT, w.global_position + Vector3.UP * 1.0,
					RING_HIGH_CORNER_FOV, true)
		"ring_behind_out":
			var f7 := _flat(-w.global_transform.basis.z).normalized()
			var r7 := Vector3.UP.cross(-f7).normalized()
			_camera.set_entrance_shot(w.global_position - f7 * RING_BEHIND_OUT_BACK
					+ r7 * 0.5 + Vector3.UP * 1.2,
					w.global_position + f7 * 10.0 + Vector3.UP * 3.0,
					RING_BEHIND_OUT_FOV, true)
		"end_wide":
			_camera.set_entrance_shot(END_WIDE_AT, END_WIDE_LOOK, END_WIDE_FOV, true)
		"faceoff_seq":
			_faceoff_seq(delta)
		"match_card":
			# A5: high on the hard camera's side, the whole ring, a slow push.
			_camera.set_entrance_shot(INTRO_CARD_AT, INTRO_CARD_LOOK, INTRO_CARD_FOV, first, delta)
		"corner_intro":
			_intro_close(beat, first, delta)
		"ref_check":
			_intro_close(beat, first, delta)
		"faceoff_side":
			# F1, the walk to the centre: square to the line between them,
			# wide, at eye height -- then the sequence takes the stare.
			var mid := (_a.global_position + _b.global_position) * 0.5
			var across := _flat(_b.global_position - _a.global_position).normalized()
			var side := Vector3.UP.cross(across).normalized()
			if side.dot(_camera.hard_cam_position - mid) < 0.0:
				side = -side
			_camera.set_entrance_shot(mid + side * FACEOFF_CAM_DISTANCE
					+ Vector3.UP * FACEOFF_CAM_HEIGHT, mid + Vector3.UP * 1.45,
					FACEOFF_CAM_FOV, first and not _was_shot("faceoff_side"), delta)
		"faceoff":
			# The hard camera's own seat and lens, so the bell does not cut.
			_camera.set_entrance_shot(_camera.hard_cam_position,
					(_a.global_position + _b.global_position) * 0.5
					+ Vector3.UP * _camera.hard_cam_aim, _camera.hard_cam_fov,
					not _was_shot("faceoff"), delta)


## The pre-entrance montage: which of ROMAN_INTRO_SHOTS the hold is in, and
## how far through its move, eased (smoothstep) so every move starts and
## settles gently. A new shot is a cut.
# ---------------------------------------------------------------------------
# The stare-down (camera_aaa_plan.md A6, "The face-off", F2-F6)
# ---------------------------------------------------------------------------
#
# The one place a broadcast holds still, then tightens: a locked-off profile
# two-shot with nothing but a slow push; over one man's shoulder onto the
# other's face, and the reverse -- both from the SAME side of the line
# between them (the 180-degree rule); their eyes, cut back and forth, each
# cut shorter than the last; and from the mat between them, up at both.
# F1 (the walk in) is "faceoff_side"; F7 (back to the wide as the referee
# steps between them) is "faceoff", the hard camera.
##  [ends at (s), shot]
const FACEOFF_SEQ := [[1.6, "profile"], [2.6, "ots_a"], [3.6, "ots_b"],
		[4.05, "eyes_a"], [4.45, "eyes_b"], [4.8, "eyes_a"], [5.1, "eyes_b"], [9.9, "low_hero"]]
const FACEOFF_OTS_FOV := 26.0     # ~85 mm
const FACEOFF_EYES_FOV := 13.0    # ~135 mm
const FACEOFF_HERO_FOV := 58.0    # ~24 mm


static func faceoff_shot_at(seconds: float) -> String:
	for step: Array in FACEOFF_SEQ:
		if seconds < float(step[0]):
			return step[1]
	return FACEOFF_SEQ[-1][1]


func _faceoff_seq(delta: float) -> void:
	var t := float(_tick) / TPS
	var shot := faceoff_shot_at(t)
	var cut := shot != faceoff_shot_at(maxf(t - 1.0 / TPS, 0.0)) or _tick <= 1
	var ha := _head_of(_a)
	var hb := _head_of(_b)
	var mid := (_a.global_position + _b.global_position) * 0.5
	var across := _flat(_b.global_position - _a.global_position).normalized()
	var side := Vector3.UP.cross(across).normalized()
	if side.dot(_camera.hard_cam_position - mid) < 0.0:
		side = -side
	match shot:
		"profile":
			var e := smoothstep(0.0, 1.6, t)
			_camera.set_entrance_shot(mid + side * lerpf(FACEOFF_CAM_DISTANCE, 2.9, e)
					+ Vector3.UP * FACEOFF_CAM_HEIGHT, mid + Vector3.UP * 1.5,
					FACEOFF_CAM_FOV, cut, delta)
		"ots_a", "ots_b":
			var near := ha if shot == "ots_a" else hb
			var far := hb if shot == "ots_a" else ha
			var back := _flat(near - far).normalized()
			_camera.set_entrance_shot(near + back * 0.75 + side * 0.38 + Vector3.UP * 0.02,
					far + Vector3.DOWN * 0.04, FACEOFF_OTS_FOV, true, delta, false)
		"eyes_a", "eyes_b":
			var who := ha if shot == "eyes_a" else hb
			var other := hb if shot == "eyes_a" else ha
			var toward := _flat(other - who).normalized()
			_camera.set_entrance_shot(who + toward * 0.95 + side * 0.18,
					who, FACEOFF_EYES_FOV, true, delta, false)
		_:
			_camera.set_entrance_shot(mid + side * 1.15 + Vector3.UP * 0.32,
					mid + Vector3.UP * 1.55, FACEOFF_HERO_FOV, cut, delta)


func _intro_shot() -> void:
	_camera_intro(intro_shot_at(float(_tick) / TPS, float(_beats[_beat]["ticks"]) / TPS))


## Which of ROMAN_INTRO_SHOTS is up `at` seconds into a hold of `hold`
## seconds, and how far through its move: [shot index, t]. The last shot is
## stretched to the end of the hold, so the montage never runs out early.
static func intro_shot_at(at: float, hold: float) -> Array:
	var last := ROMAN_INTRO_SHOTS.size() - 1
	var start := 0.0
	for i in last:
		var length: float = ROMAN_INTRO_SHOTS[i][6]
		if at <= start + length:
			return [i, clampf((at - start) / length, 0.0, 1.0)]
		start += length
	var rest := maxf(hold - start, float(ROMAN_INTRO_SHOTS[last][6]))
	return [last, clampf((at - start) / rest, 0.0, 1.0)]


func _camera_intro(pick: Array) -> void:
	var shot: Array = ROMAN_INTRO_SHOTS[pick[0]]
	var t: float = pick[1]
	var e := t * t * (3.0 - 2.0 * t)
	_camera.set_entrance_shot((shot[0] as Vector3).lerp(shot[1], e),
			(shot[2] as Vector3).lerp(shot[3], e), lerpf(shot[4], shot[5], e), true)


const MATCH_CARD_SUBTITLE := "AEW WORLD CHAMPIONSHIP"


static func _card_name(w: WrestlerController) -> String:
	var n := w.display_name if w.display_name != "" else String(w.name)
	var parts := n.split(" ")
	return parts[parts.size() - 1].to_upper()


## A5: close on him in his corner, from the centre of the ring; for the
## check, wider and off his shoulder, so the referee walks into it.
func _intro_close(beat: Dictionary, first: bool, delta: float) -> void:
	var man: WrestlerController = beat["focus"]
	var head := _head_of(man)
	var flat := _flat(man.global_position)
	var to_c := -flat.normalized() if flat.length() > 0.1 else Vector3.FORWARD
	var side := Vector3.UP.cross(to_c).normalized()
	if side.dot(_camera.hard_cam_position - man.global_position) < 0.0:
		side = -side
	if beat["shot"] == "corner_intro":
		_camera.set_entrance_shot(head + to_c * INTRO_CLOSE_DISTANCE + side * 0.45
				+ Vector3.DOWN * 0.12, head, INTRO_CLOSE_FOV, first, delta)
	else:
		_camera.set_entrance_shot(man.global_position + to_c * 2.9 + side * 1.4
				+ Vector3.UP * 1.45, man.global_position + Vector3.UP * 1.3, 34.0,
				first, delta)


## His head, for the close-ups: the head bone if the rig has one, else a
## fixed height over his root.
func _head_of(w: WrestlerController) -> Vector3:
	var sk := w.skeleton
	if sk:
		var i := sk.find_bone(w._skeleton_bone_name("Head"))
		if i >= 0:
			return sk.global_transform * sk.get_bone_global_pose(i).origin \
					+ Vector3.UP * 0.08
	return w.global_position + Vector3.UP * 1.75


## Every portal accent to one colour and a multiple of its own energy: the
## room going red on Roman's pyro.
func _accents_to(color: Color, gain: float) -> void:
	if not _lights:
		return
	for child in _lights.get_children():
		if child is SpotLight3D and String(child.name).begins_with("Accent"):
			var light := child as SpotLight3D
			if not light.has_meta("base_energy"):
				light.set_meta("base_energy", light.light_energy)
			if not light.has_meta("base_color"):
				light.set_meta("base_color", light.light_color)
			light.light_color = color
			light.light_energy = float(light.get_meta("base_energy")) * gain


## Cody walks out of smoke (C-MITB 22-26 s, C-SNME 20-24 s): a dense fog
## volume filling his portal mouth, lit by his backlight behind it. Freed on
## the hit.
func _smoke_on(w: WrestlerController) -> void:
	if _smoke:
		return
	var at: Vector3 = (_beats[mini(_beat, _beats.size() - 1)] as Dictionary).get(
			"fog_at", w.global_position)
	_smoke = FogVolume.new()
	_smoke.name = "PortalSmoke"
	_smoke.size = SMOKE_SIZE
	var mat := FogMaterial.new()
	mat.density = SMOKE_DENSITY
	mat.albedo = Color(0.9, 0.92, 1.0)
	mat.edge_fade = 0.6
	_smoke.material = mat
	add_child(_smoke)
	_smoke.global_position = at + Vector3(0.0, SMOKE_SIZE.y * 0.5, 0.0)
	# The same bank as particles: the FogVolume does nothing on the web.
	_ice = DryIce.new()
	_ice.name = "DryIce"
	add_child(_ice)
	_ice.start(at, Vector3(0, 0, 1))


func _smoke_off() -> void:
	if _smoke:
		_smoke.queue_free()
		_smoke = null
	if _ice:
		# Stops pouring; what is already out lingers and dissipates.
		_ice.stop()
		_ice = null


## Dims the house for his entrance, or puts it back. Every rig light except
## the portal accents (the entrance's own cue) goes to ROMAN_HOUSE_DIM of
## itself, and the ambient to ROMAN_AMBIENT_DIM; the originals are kept and
## restored exactly.
func _dim_house(on: bool, rig: float = ROMAN_HOUSE_DIM,
		ambient: float = ROMAN_AMBIENT_DIM) -> void:
	if on == not _dimmed.is_empty():
		return
	if _lights and "house_dim" in _lights:
		_lights.house_dim = rig if on else 1.0
	if on:
		if _lights:
			for child in _lights.get_children():
				if child is Light3D and not String(child.name).begins_with("Accent"):
					_dimmed[child] = (child as Light3D).light_energy
					(child as Light3D).light_energy *= rig
					if _pose_dimmed.has(child):
						# Mid-pose: the house's original is the one before the pose.
						var was: Array = _pose_dimmed[child]
						_dimmed[child] = was[0]
						_pose_dimmed[child] = [was[0] * rig, (child as Light3D).light_energy]
		if _env:
			_dimmed[_env] = _env.ambient_light_energy
			_env.ambient_light_energy *= ambient
		return
	for key in _dimmed:
		if key is Light3D and is_instance_valid(key):
			(key as Light3D).light_energy = _dimmed[key]
		elif key == _env:
			_env.ambient_light_energy = _dimmed[key]
	_dimmed.clear()


var _top: SpotLight3D


## Item 12: the top light on `w` posing in the ring; null puts it out.
func _pose_top(w: WrestlerController) -> void:
	if w == null:
		if _top:
			_top.visible = false
		_pose_dim(false)
		return
	if _top == null:
		_top = SpotLight3D.new()
		_top.name = "PoseTop"
		_top.light_color = POSE_TOP_COLOR
		_top.light_energy = POSE_TOP_ENERGY
		_top.spot_angle = POSE_TOP_ANGLE
		_top.spot_angle_attenuation = 0.6
		_top.spot_range = POSE_TOP_UP + 2.0
		_top.shadow_enabled = true
		_top.light_volumetric_fog_energy = 1.4
		add_child(_top)
	_top.visible = true
	_pose_dim(true)
	var at := w.global_position + Vector3.UP * POSE_TOP_UP
	_top.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), at)


## Ring key or top fill -> [energy before the pose, energy set for it].
var _pose_dimmed := {}


## Takes the ring keys and top fill down for a pose, or puts them back. A
## light something else rewrote in between (set_look, the house dim's
## restore) keeps that value.
func _pose_dim(on: bool) -> void:
	if on == not _pose_dimmed.is_empty():
		return
	if on:
		if _lights:
			for child in _lights.get_children():
				var n := String(child.name)
				if child is Light3D and (n.begins_with("Key") or n.begins_with("Top")):
					var l := child as Light3D
					_pose_dimmed[l] = [l.light_energy, l.light_energy * POSE_RING_DIM]
					l.light_energy *= POSE_RING_DIM
		return
	for l: Light3D in _pose_dimmed:
		if is_instance_valid(l) and is_equal_approx(l.light_energy, _pose_dimmed[l][1]):
			l.light_energy = _pose_dimmed[l][0]
	_pose_dimmed.clear()


static func _in_ring(w: WrestlerController) -> bool:
	var p := w.global_position
	return absf(p.x) < 3.2 and absf(p.z) < 3.2 and p.y > -0.2


## Keeps the follow spot on whoever is walking; off when nobody is.
func _aim_follow_spot(w: WrestlerController) -> void:
	if not _follow:
		return
	if w == null or not w.visible or _follow_off or not _pose_dimmed.is_empty():
		_follow.visible = false
		if _walk_key:
			_walk_key.visible = false
		if _walk_back:
			_walk_back.visible = false
		return
	_follow.visible = true
	# In the ring the long-throw spot is a glare in the haze and burns his
	# gear white on the low shots (lighting_2k26.md item 10): a third of it.
	_follow.light_energy = FOLLOW_SPOT_ENERGY * (0.35 if _in_ring(w) else 1.0)
	var target := w.global_position + Vector3.UP * 1.1
	if _follow.global_position.distance_to(target) > 0.1:
		_follow.look_at(target, Vector3.UP)
	if _walk_key:
		_walk_key.visible = true
		var fwd := _flat(-w.global_transform.basis.z).normalized()
		var right := Vector3.UP.cross(-fwd).normalized()
		_walk_key.global_position = walk_key_at(w.global_position, fwd, right)
		_walk_key.look_at(w.global_position + Vector3.UP * 1.3, Vector3.UP)
		if _walk_back:
			_walk_back.visible = true
			_walk_back.global_position = walk_back_at(w.global_position, fwd, right)
			_walk_back.look_at(w.global_position + Vector3.UP * 1.4, Vector3.UP)


## Item 11: the wall's coloured light on him, from between him and the wall.
## Out while the wall is on the loop, while he is in the ring (the wall is
## 35 m off) and while Cody's own backlight has the dark.
func _aim_tron_rim(w: WrestlerController) -> void:
	var on := _tron_on and w != null and w.visible and not _in_ring(w) \
			and not (_backlight and _backlight.visible)
	if not on:
		if _tron_rim:
			_tron_rim.visible = false
		return
	if _tron_rim == null:
		_tron_rim = SpotLight3D.new()
		_tron_rim.name = "TronRim"
		_tron_rim.light_color = StageVideo.glow_color(w.entrance_style)
		_tron_rim.light_energy = TRON_RIM_ENERGY
		_tron_rim.spot_angle = TRON_RIM_ANGLE
		_tron_rim.spot_angle_attenuation = 1.2
		_tron_rim.spot_range = TRON_RIM_RANGE
		_tron_rim.light_volumetric_fog_energy = 0.3
		_tron_rim.shadow_enabled = false
		add_child(_tron_rim)
	_tron_rim.visible = true
	_tron_rim.global_position = tron_rim_at(w.global_position)
	_tron_rim.look_at(w.global_position + Vector3.UP * 1.5, Vector3.UP)


## Where the tron rim hangs for a man at `at`: toward the wall, above him.
static func tron_rim_at(at: Vector3) -> Vector3:
	var back := _flat(TRON_AT - at).normalized()
	return at + back * TRON_RIM_BACK + Vector3.UP * TRON_RIM_UP


## Where the walk key hangs for a man at `at` facing `fwd`.
static func walk_key_at(at: Vector3, fwd: Vector3, right: Vector3) -> Vector3:
	return at + fwd * WALK_KEY_AHEAD + right * WALK_KEY_SIDE + Vector3.UP * WALK_KEY_UP


## Where the back follower hangs: behind him, above, to his left.
static func walk_back_at(at: Vector3, fwd: Vector3, right: Vector3) -> Vector3:
	return at - fwd * WALK_BACK_BEHIND + right * WALK_BACK_SIDE + Vector3.UP * WALK_BACK_UP


## Whether the previous beat was on the same shot, so a shot carried across
## two beats (the stage walk into the pose) does not re-cut.
func _was_shot(shot: String) -> bool:
	return _beat > 0 and (_beats[_beat - 1] as Dictionary).get("shot", "") == shot


## His portal's accent fixtures come up while he is on the stage.
func _portal_lights(side: String, on: bool, tint: Color = Color.TRANSPARENT) -> void:
	if not _lights:
		return
	for child in _lights.get_children():
		if not (child is SpotLight3D) or not String(child.name).begins_with("Accent"):
			continue
		var light := child as SpotLight3D
		if not light.has_meta("base_energy"):
			light.set_meta("base_energy", light.light_energy)
		if not light.has_meta("base_color"):
			light.set_meta("base_color", light.light_color)
		var base: float = light.get_meta("base_energy")
		var name := String(light.name)
		if on and side == "OFF":
			light.light_energy = 0.0
			continue
		if on and side.begins_with("RB"):
			# Cody's: red on the east portal, blue on the west, both hot.
			light.light_energy = base * (2.4 if side == "RB" else 0.7)
			light.light_color = CODY_RED if name.begins_with("AccentE") else CODY_BLUE
			continue
		var mine := on and name.begins_with("Accent" + side)
		light.light_energy = base * (2.4 if mine else 1.0)
		light.light_color = tint if mine and tint.a > 0.0 else light.get_meta("base_color")
