class_name EntranceDirector
extends Node
## The ring entrances: both men walk out from the stage, down the ramp, up the
## ring steps and through the ropes to their marks, before the bell.
##
## Presentation only, and built so the match cannot tell it happened.
##
## * Everything that plays the match is frozen for the duration -- both
##   wrestlers, their AI, the referee, the grapple rig, the story clock
##   (MatchFlow) -- with the same
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
## Climb_Steps: 55 frames up the four-tier flight, from the floor beyond its
## bottom tread to the platform beside the post.
const CLIMB_SECONDS := 55.0 / 30.0
## How fast a turn on the spot goes, radians per second.
const TURN_RATE := 5.0

## Apron_Step: 1.2 s, off the platform and onto the apron beside the post.
## Rope_Step_Through_Apron: 1.33 s, from the apron edge through the ropes
## onto the mat.
const APRON_STEP_SECONDS := 1.2
const APRON_ROPE_SECONDS := 1.333

## How far each of those clips carries the root, (along, up) -- the route
## _add_route_in builds MUST move him exactly this far, or the boots miss
## the treads: the steps once grew a tier and the clips did not, and he
## floated up them and dropped onto the apron. wrestling_clips.py reads
## these, checks them against the ring's own constants, and keys the boots
## on the treads; test_entrance_route.gd checks the route against them.
## Plain numbers so the clip script can read them.
const CLIMB_FWD := 1.541
const CLIMB_UP := 0.954
const APRON_STEP_FWD := 1.066
const APRON_STEP_UP := 0.04
const APRON_ROPE_FWD := 0.62
const APRON_ROPE_UP := 0.10
const APRON_ROPE_TO := Vector2(APRON_ROPE_FWD, APRON_ROPE_UP)

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
## The way in on camera (2K26's Roman, entrances.md): low behind him onto
## and up the steps, then from inside the ring, low, up at him on the apron.
## Far enough back and out to the side that the steps and the corner are in
## frame past him: at 1.7 m his back filled it (storyboard, 2 Nov).
const STEPS_REAR_BACK := 2.8
const STEPS_REAR_SIDE := 1.5
const STEPS_REAR_HEIGHT := 1.1
const STEPS_REAR_FOV := 50.0
const APRON_LOW_IN := 1.2
const APRON_LOW_HEIGHT := 0.55
const APRON_LOW_FOV := 52.0
## How far through the apron step he starts squaring up to the ropes.
const APRON_TURN_FROM := 0.45
## Where the ramp's cut lands him: a few metres short of the ramp foot, in the
## ringside shot. The full 24 m ramp at walking pace would be fifteen seconds
## of one shot; a broadcast cuts it, and so does this.
const CUT_TO_Z := -9.0
## How much of the ramp the tracking shot follows before the cut, in seconds.
const RAMP_SHOWN_SECONDS := 6.0

# --- Timing (ticks at 60 Hz) --------------------------------------------------
const TPS := 60
## The cold open's pyro and its three angles (EntrancePyro._opening_show, the
## owner's AEW Dynamite reference, 3 Nov): ~12.5 s before the crowd cut.
const OPENING_TICKS := 750
## Excalibur's crowd call and Tony's reply before the entrances. Seven seconds
## covers both clips and the serialized voice-lane gaps.
const EXCALIBUR_CROWD_CALL_TICKS := 420
## Time for Tony's title call to finish before the entrances begin.
const TITLE_MATCH_CALL_TICKS := 240
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
## The slow walk out of the corners, on its own clip authored at this speed
## (Walk_Staredown): on Entrance_Walk (1.6 m/s) the feet slid back a metre a
## second -- the owner's "glitchy walking to their staredown" (2 Nov).
const FACEOFF_WALK_SPEED := 0.6
const FACEOFF_WALK_CLIP := "strikes/walk_staredown"
## From the marks to the corners, on the slow walk authored at this speed
## (Walk_Slow) -- not Entrance_Walk at 1.1, which skated half a metre a second.
## And the turn in there.
const FACEOFF_CORNER_SPEED := 1.0
const FACEOFF_CORNER_CLIP := "strikes/walk_slow"
const FACEOFF_CORNER_TURN_TICKS := 36
## How far in from the turnbuckle pad a man stands in his corner.
const FACEOFF_CORNER_IN := 0.95
## The stare-down's push: from the two-shot (FACEOFF_CAM_*) in to this far
## off the pair, on this lens, both faces in frame.
## The house from the walk out of the corners to the bell (realism, the
## owner, 2 Nov): the crowd down to this share of its match light while the
## ring stays at full -- the broadcast's pre-bell look, and the bright crowd
## no longer silhouettes the two men against it.
const PREBELL_HOUSE_LEVEL := 0.55
const STAREDOWN_CLOSE := 1.3
const STAREDOWN_FOV := 30.0
## The walk out of the corners: its lens, how far in from the frame's sides
## (radians) the men are held, and the furthest back the camera goes.
const FACEOFF_WALK_FOV := 40.0
const FACEOFF_WALK_MARGIN := 0.1
const FACEOFF_WALK_MAX := 9.0
## The broadcast frame (16:9): the lens is vertical.
const FRAME_ASPECT := 16.0 / 9.0
## The stare-down: one slow push into their faces, then the bell.
const FACEOFF_STARE_TICKS := 90
## Their poses at the face-off (faceoff_pose_clip): Kenny's arms-up and
## finger guns run 2.5 s; Roman's finger and Cody's arms hold their last frame.
const FACEOFF_POSE_TICKS := 156
const FACEOFF_POSE_CAM_DISTANCE := 4.4
const FACEOFF_POSE_CAM_FOV := 42.0

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
##
## The entrances have already introduced each wrestler, so these are short
## bridges to the face-off rather than another long round of introductions.
const INTRO_CARD_TICKS := 180
const INTRO_CHECK_TICKS := 120
const INTRO_CLOSE_TICKS := 150
const INTRO_CARD_AT := Vector3(-8.0, 4.4, 3.4)
const INTRO_CARD_LOOK := Vector3(0.0, 0.9, 0.0)
const INTRO_CARD_FOV := 40.0
const INTRO_CLOSE_FOV := 34.0
const INTRO_CLOSE_DISTANCE := 2.9
## How far the corner medium drifts in over its hold, metres.
const INTRO_CLOSE_PUSH := 0.4
## The jib on the corner close-up: from this far out and this low (metres
## from his chest; 0.75 under it is about a metre off the canvas) up to just
## over his eye line.
const INTRO_CRANE_FROM := 3.6
const INTRO_CRANE_LOW := -0.75
const INTRO_CRANE_HIGH := 0.42
## The referee's check: off to the side and in toward the centre.
const REF_CHECK_SIDE := 1.5
const REF_CHECK_IN := 1.5
const REF_CHECK_FOV := 36.0
## The walk out of the corners on a crane: it starts this high and this far
## round from the hard camera's side, and sweeps down and round to eye level
## on the men's line as they close.
const FACEOFF_CRANE_TOP := 3.8
const FACEOFF_CRANE_ARC := 26.0
## Every high shot hangs at RIG_CLEAR_Y: just under the light rig over the
## ring (ArenaBuilder.TRUSS_Y, its keys' bodies ~0.7 m under it), so the lens
## sees the building under the steel instead of through it. The owner: "the
## camera is above the light rigging above the ring, which blocks the view --
## just underneath it, so we get a clear wide-angle shot". Under it is not
## the whole story -- a lens just under a ceiling of lamps still sees the
## ceiling -- so each wide is also aimed so rig_in_frame() is 0 (2 Nov).
const RIG_CLEAR_Y := 6.3
## A wide toward the stage from behind the ring looks along under the ring
## rig: from this low, tilted down onto the ring, the top of frame passes
## between the video wall's top edge and the rig's far lines.
const STAGE_WIDE_LOW_Y := 4.0
## The light rig as a lens sees it (2 Nov, the owner: "I can still see the
## light rigging during the intros ... the wide shots"): the ring grid's
## lines at their PAR cans' lenses, and the fixtures hung under it. Built from
## ArenaLighting's constants -- the numbers tools/blender/overhead_rig.py
## builds the steel from -- so a moved rig moves this with it.
static func rig_points() -> PackedVector3Array:
	var pts := PackedVector3Array()
	var hang := ArenaLighting.HANG_Y
	var cans := hang + ArenaLighting.FIXTURE_TOP - 0.02 - 0.22
	var o := ArenaLighting.RIG_GRID_OUTER
	var reach := ArenaLighting.RIG_GRID_REACH
	for offset: float in [-o, -ArenaLighting.KEY_OFFSET, ArenaLighting.KEY_OFFSET, o]:
		var y := cans if absf(offset) == o else hang + ArenaLighting.FIXTURE_TOP
		var s := -reach
		while s <= reach + 0.01:
			pts.append(Vector3(s, y, offset))
			pts.append(Vector3(offset, y, s))
			s += 0.5
	# The fixtures: keys and audience wash under the inner lines, the top
	# fills between them, the rim pair upstage. Each body hangs ~0.35 down.
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pts.append(Vector3(sx * ArenaLighting.KEY_OFFSET, hang - 0.35, sz * ArenaLighting.KEY_OFFSET))
		pts.append(Vector3(0.0, hang + 0.2 - 0.35, sx * ArenaLighting.TOP_OFFSET_Z))
		pts.append(Vector3(sx * ArenaLighting.KEY_OFFSET, hang - 0.35, 0.0))
		pts.append(Vector3(0.0, hang - 0.35, sx * ArenaLighting.KEY_OFFSET))
		pts.append(Vector3(sx * ArenaLighting.RIM_X, ArenaLighting.RIM_Y - 0.35, ArenaLighting.RIM_Z))
	return pts


## `look`, tipped down until the rig is out of a lens at `at` with vertical
## `fov` (half a degree at a time, at most 30): for the wides that follow a
## man, whose aim is not a constant a test can check.
## The walk's crane at eased progress `e`: [camera, look, fov] for a man at
## `at` walking along `fwd` (flat).
static func crane_front_shot(at: Vector3, fwd: Vector3, e: float,
		height: Vector2 = CRANE_FRONT_HEIGHT, fov: Vector2 = CRANE_FRONT_FOV) -> Array:
	var right := Vector3.UP.cross(-fwd).normalized()
	var cam := at + fwd * lerpf(CRANE_FRONT_AHEAD.x, CRANE_FRONT_AHEAD.y, e) \
			+ right * lerpf(CRANE_FRONT_SIDE.x, CRANE_FRONT_SIDE.y, e) \
			+ Vector3.UP * lerpf(height.x, height.y, e)
	return [cam, at + Vector3.UP * lerpf(CRANE_FRONT_LOOK.x, CRANE_FRONT_LOOK.y, e),
			lerpf(fov.x, fov.y, e)]


# --- Roman's low framings (pure: [camera, look, fov] for a man at `at` going
# or facing along `fwd`, flat). His right is UP.cross(-fwd). -------------------

## The lower-third frame: his crane's landing, held, backing ahead of him.
static func low_lead_shot(at: Vector3, fwd: Vector3) -> Array:
	return crane_front_shot(at, fwd, 1.0, ROMAN_CRANE_HEIGHT, ROMAN_CRANE_FOV)


static func low_wide_up_shot(at: Vector3, fwd: Vector3) -> Array:
	var right := Vector3.UP.cross(-fwd).normalized()
	return [at + fwd * LOW_WIDE_UP_AHEAD + right * LOW_WIDE_UP_SIDE
			+ Vector3.UP * LOW_WIDE_UP_HEIGHT, at + Vector3.UP * LOW_WIDE_UP_LOOK,
			LOW_WIDE_UP_FOV]


## On the side of the aisle away from where he is (the hard camera's, -X, on
## the ramp), inside the barricade, never closer than BARRICADE_LOW_CLEAR to
## the floor under the lens.
static func barricade_low_shot(at: Vector3, fwd: Vector3) -> Array:
	var right := Vector3.UP.cross(-fwd).normalized()
	if right.x * at.x > 0.0:
		right = -right
	var cam := at + right * BARRICADE_LOW_SIDE + fwd * BARRICADE_LOW_AHEAD \
			+ Vector3.UP * BARRICADE_LOW_HEIGHT
	cam.y = maxf(cam.y, surface_y(cam) + BARRICADE_LOW_CLEAR)
	return [cam, at + Vector3.UP * BARRICADE_LOW_LOOK, BARRICADE_LOW_FOV]


static func face_up_shot(at: Vector3, head: Vector3, fwd: Vector3) -> Array:
	var right := Vector3.UP.cross(-fwd).normalized()
	return [at + fwd * FACE_UP_AHEAD + right * FACE_UP_SIDE + Vector3.UP * FACE_UP_HEIGHT,
			head, FACE_UP_FOV]


static func ring_low_up_shot(at: Vector3, fwd: Vector3) -> Array:
	var right := Vector3.UP.cross(-fwd).normalized()
	return [at + fwd * RING_LOW_UP_AHEAD + right * RING_LOW_UP_SIDE
			+ Vector3.UP * RING_LOW_UP_HEIGHT, at + Vector3.UP * RING_LOW_UP_LOOK,
			RING_LOW_UP_FOV]


## At eased progress `e` of its slow arc in.
static func ring_hero_shot(at: Vector3, fwd: Vector3, e: float) -> Array:
	var right := Vector3.UP.cross(-fwd).normalized()
	var a := deg_to_rad(lerpf(RING_HERO_ANGLE.x, RING_HERO_ANGLE.y, e))
	var dir := fwd * cos(a) + right * sin(a)
	return [at + dir * lerpf(RING_HERO_DISTANCE.x, RING_HERO_DISTANCE.y, e)
			+ Vector3.UP * RING_HERO_HEIGHT, at + Vector3.UP * RING_HERO_LOOK, RING_HERO_FOV]


## The ring-arrival crane at eased progress `e` on a man at `man`: [camera,
## look, fov]. `toward` picks the side of the corner it stands (the hard
## camera's).
## Where "corner_low" stands: out past the entry corner's post, low.
static func corner_front_shot() -> Vector3:
	var out := RingBuilder.step_out_dir(ENTRY_CORNER)
	var pad := Vector3(ENTRY_CORNER.x, 0.0, ENTRY_CORNER.y) * RingBuilder.TURNBUCKLE_PAD_XZ
	var right := Vector3.UP.cross(out).normalized()
	return pad + out * CORNER_FRONT_OUT + right * CORNER_FRONT_SIDE \
			+ Vector3.UP * CORNER_FRONT_HEIGHT


static func entry_crane_shot(man: Vector3, toward: Vector3, e: float) -> Array:
	var post := Vector3(ENTRY_CORNER.x * RingBuilder.POST_XZ, 0.0,
			ENTRY_CORNER.y * RingBuilder.POST_XZ)
	var out := RingBuilder.step_out_dir(ENTRY_CORNER)
	var side := Vector3.UP.cross(out).normalized()
	if side.dot(toward - post) < 0.0:
		side = -side
	var cam := post + out * lerpf(ENTRY_CRANE_BACK.x, ENTRY_CRANE_BACK.y, e) \
			+ side * lerpf(ENTRY_CRANE_SIDE.x, ENTRY_CRANE_SIDE.y, e) \
			+ Vector3.UP * lerpf(ENTRY_CRANE_HEIGHT.x, ENTRY_CRANE_HEIGHT.y, e)
	var look := (post + Vector3.UP * 0.8).lerp(man + Vector3.UP * 1.2, ENTRY_CRANE_FOLLOW)
	return [cam, look, lerpf(ENTRY_CRANE_FOV.x, ENTRY_CRANE_FOV.y, e)]


static func rig_clear_look(at: Vector3, look: Vector3, fov: float) -> Vector3:
	var to := look - at
	var right := to.cross(Vector3.UP)
	if right.length_squared() < 0.0001:
		return look
	right = right.normalized()
	for i in 60:
		if rig_in_frame(at, at + to, fov) == 0:
			break
		to = to.rotated(right, deg_to_rad(-0.5))
	return at + to


## How many rig points a lens at `at` looking at `look` with vertical `fov`
## (16:9) has in frame, with `pad_deg` of frame around it so a lamp cannot sit
## on the edge. A wide shot of the intros must make this 0.
static func rig_in_frame(at: Vector3, look: Vector3, fov: float, pad_deg := 1.0,
		aspect := 16.0 / 9.0) -> int:
	var basis := Basis.looking_at(look - at, Vector3.UP)
	var tan_v := tan(deg_to_rad(fov * 0.5 + pad_deg))
	var tan_h := tan(atan(tan(deg_to_rad(fov * 0.5)) * aspect) + deg_to_rad(pad_deg))
	var seen := 0
	for p: Vector3 in rig_points():
		var local := basis.inverse() * (p - at)
		var depth := -local.z
		if depth <= 0.05:
			continue
		if absf(local.y) / depth <= tan_v and absf(local.x) / depth <= tan_h:
			seen += 1
	return seen
## The cold open, shot as the owner's AEW Dynamite reference is (3 Nov):
##   0-5 s    the dark hall: a long lens from behind the ring, down the hall
##            to the stage, the flame chase and the rockets small and bright
##            at the end of it, pushing in a little (low enough, and tight
##            enough, that the ring rig is over the top of frame);
##   5-9 s    in close on the wall, handheld, the flames and rockets past it;
##   9-12.6   low from the side of the deck for the concussion;
##   12.6-15  the crowd: two cuts on the Enda sign as the house roars;
##   15 on    the stage master, the deck movers sweeping, into the entrance.
## [start seconds, camera, look, lens].
const OPENING_AT := Vector3(0.0, 2.0, 18.0)
const OPENING_LOOK := Vector3(0.0, 4.5, -33.0)
const OPENING_FOV := 18.0
const OPENING_CRANE_TO := Vector3(0.0, 2.0, 16.5)
const OPENING_CRANE_LOOK_TO := Vector3(0.0, 4.6, -33.0)
const OPENING_SIGN_SHOT_INDEX := 3
const OPENING_SIGN_ALT_SHOT_INDEX := 4
const OPENING_SIGN_CUE := "opening_enda_sign_raise"
const OPENING_SHOTS := [
	[0.0, OPENING_AT, OPENING_LOOK, OPENING_FOV],
	[5.0, Vector3(-4.0, 2.2, -21.0), Vector3(0.5, 6.0, -35.0), 42.0],
	[9.0, Vector3(-13.0, 1.0, -24.0), Vector3(0.0, 4.5, -32.0), 50.0],
	[12.6, Vector3(4.8, 2.0, -3.8), Vector3(8.05, 1.7, -3.6), 39.0],
	[13.8, Vector3(4.4, 2.1, -2.8), Vector3(8.05, 1.7, -3.6), 36.0],
	[15.0, Vector3(0.0, 6.0, -12.0), Vector3(0.0, 5.5, -37.0), 44.0],
]
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
const FOLLOW_SPOT_ENERGY := 32.0
const FOLLOW_SPOT_ANGLE := 3.5
## The walk key (blender-lighting: a key from the front at about 45 degrees,
## warm, soft, with the video wall behind him as the rim). The follow spot is
## 40 m away in the far end: on its own it lost him halfway down the ramp --
## once he was out of the stage wash his front went to silhouette against the
## wall on every steadicam shot. This one rides with him, a few metres ahead,
## to his right and above, like the front-truss followers a real entrance
## hangs, so he is lit from the curtain to the ring.
const WALK_KEY_AHEAD := 4.2
const WALK_KEY_SIDE := 2.8
const WALK_KEY_UP := 3.6
const WALK_KEY_ENERGY := 6.0
const WALK_KEY_ANGLE := 32.0
const WALK_KEY_RANGE := 11.0
## The camera key (2K26: he is exposed on every angle): a soft front light that
## rides the active shot, a little above and to the side of the lens, aimed
## at his chest. The walk key and back light are fixed to HIM, so a lens off
## their axis -- the side tracks -- saw his far side fall to black.
const CAM_KEY_ENERGY := 0.85
const CAM_KEY_UP := 0.7
const CAM_KEY_SIDE := 0.9
## The camera key on a man in the ring, for the corner intros, the walk out
## of the corners and the stare-down. At 0.5 (the ramp's level halved for
## the shorter throw) they still rendered as silhouettes against the lit
## crowd: the rig over the ring lights the tops of their heads, not the
## fronts the lens sees (the owner, 2 Nov: "I don't want the wrestlers to be
## lit dark when standing in the corners or during the faceoff").
const CAM_KEY_RING_GAIN := 2.0
## The ramp wash: two long throws from either side, high, on the ramp while
## somebody walks it, so the wides read as a lit aisle and not a black slot.
const RAMP_WASH_ENERGY := 6.0
const RAMP_WASH_ANGLE := 22.0
const RAMP_WASH_SIDE := 9.0
const RAMP_WASH_UP := 11.0
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
const WALK_BACK_ENERGY := 5.0
const WALK_BACK_ANGLE := 34.0
const WALK_BACK_RANGE := 10.0
## The walk lights on a bare-chested man. Tuned on Cody in his coat and Roman
## in his vest, the follow spot, the walk key and the camera key burn a bare
## chest to white: Cody's measures (254,232,191) where his coat shows it, and
## Kenny, bare the whole way, walked out with his chest at (254,253,228) and
## his face at (243,225,197). His keys run at this share.
const WALK_LIGHT_GAIN := {"kenny": 0.5}
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
const POSE_TOP_ENERGY := 95.0
const POSE_TOP_ANGLE := 28.0
const POSE_TOP_COLOR := Color(0.92, 0.96, 1.0)
## While it is on, the light that was outweighing it goes: the follow spot and
## the walk lights out, the ring keys and top fill to POSE_RING_DIM of
## themselves. At 9, with them up, the top light added only 6-19% on his head
## and shoulders (README, "Lighting 2K26 items 5-12").
const POSE_RING_DIM := 0.35
## On the lip before the finger: the slow push-in while he looks the building
## over, then the close-up (R-41 30-40 s, 1:04).
## The building before he is seen (the owner, 2 Nov: "too much time spent on
## crowd shots"), then standing in his portal while the music builds. The lip
## takes what is left before the finger (_add_roman_entrance).
const ROMAN_INTRO_SECONDS := 13.0
const ROMAN_PORTAL_HOLD := 7.0
## After the slam: the very wide of the pyro, then the finger held under the
## low wide from the ramp until this music time (R-41: 40 s to 58 s).
const ROMAN_PYRO_WIDE := 3 * ROMAN_BEAT
const ROMAN_FINGER_DOWN := ROMAN_MUSIC_HIT + 16 * ROMAN_BEAT
## The room goes red for the pyro and back to blue, in ticks.
const ROMAN_RED_TICKS := 90
## Head bowed at ringside (R-41 2:42-3:04 is twenty seconds; held here four).
const ROMAN_BOW_TICKS := 240
## The walk (the owner, 9 Nov: "a few too many crane shots ... keep the angles
## below his waist which look up, eg the angle during his lower third").
## Cut on his music's bar lines (four beats from ROMAN_FINGER_DOWN; 34 is the
## one cut off a bar, forced by the 9 s cap) after the one walk crane
## (ROMAN_CRANE_BEATS, its own beat): the side track from the barricade
## between every pair of fronts, so the two low fronts -- the ultra-wide and
## the lower-third frame, about the same size of him -- never cut into each
## other. Explicit, not cycled: with the crane it covers the whole ramp.
## Every lens is below his waist and tilted up at him -- the gimbal an
## operator carries underslung walking backwards down a ramp (the Megalodon
## rig of SmackDown's 2021 entrances), at two focal lengths.
const ROMAN_CRANE_BEATS := 8
const ROMAN_WALK_SHOTS := [["barricade_low", 4 * ROMAN_BEAT], ["low_wide_up", 8 * ROMAN_BEAT],
		["barricade_low", 4 * ROMAN_BEAT], ["low_lead", 10 * ROMAN_BEAT],
		["barricade_low", 6 * ROMAN_BEAT], ["low_wide_up", 8 * ROMAN_BEAT],
		["barricade_low", 4 * ROMAN_BEAT], ["low_lead", 10 * ROMAN_BEAT]]
## Roman's one walk crane booms but does not zoom (the owner: "a bit too much
## crane zooming"): the lens held, and it lands exactly on `low_lead`, the
## frame under his lower third, 0.85 m over his feet -- under his pelvis
## bone (0.90-0.96 m through his walk, measured), looking up into his chest.
const ROMAN_CRANE_HEIGHT := Vector2(4.2, 0.85)
const ROMAN_CRANE_FOV := Vector2(34.0, 34.0)
## The ultra-wide low gimbal (R-41 1:18-1:52): close ahead of him, a hand to
## his right, the lens below his waist tilted up past his chest to the roof.
const LOW_WIDE_UP_AHEAD := 1.7
const LOW_WIDE_UP_SIDE := 0.3
const LOW_WIDE_UP_HEIGHT := 0.85
const LOW_WIDE_UP_LOOK := 1.6
const LOW_WIDE_UP_FOV := 50.0
## Alongside from the barricade with the lens below his waist. Inside the ramp
## barricade's inner face (RAMP_BARRICADE_OFFSET 2.45 less half its 0.18 m
## panel), never in it, and never under the floor beside the ramp.
const BARRICADE_LOW_SIDE := 2.15
const BARRICADE_LOW_AHEAD := 1.2
const BARRICADE_LOW_HEIGHT := 0.85
const BARRICADE_LOW_LOOK := 1.4
const BARRICADE_LOW_FOV := 38.0
const BARRICADE_LOW_CLEAR := 0.85
## The telephoto face on the lip (R-41 1:04), from his chest up into his eyes.
const FACE_UP_AHEAD := 3.6
const FACE_UP_SIDE := 0.35
const FACE_UP_HEIGHT := 1.45
const FACE_UP_FOV := 16.0
## The finger in the ring (R-39; 2K26 3:28, 3:46): low in front of him, the
## finger up against the lights -- low and tilted enough to look up, not so
## much that the ring rig comes into the top of frame. Measured against
## rig_in_frame: at 3.0 m, 40 degrees and an aim of 1.7 the grid's far lines
## were in it (30 points); from 3.5 m on a 34-degree lens aimed at 1.4 none
## is, and the top of frame is 2.55 m up at him, over the finger.
const RING_LOW_UP_AHEAD := 3.5
const RING_LOW_UP_SIDE := 0.5
const RING_LOW_UP_HEIGHT := 0.85
const RING_LOW_UP_LOOK := 1.4
const RING_LOW_UP_FOV := 34.0
## Hands on hips and the ula fala off: a true three-quarter on his right,
## 40 to 50 degrees round from his facing, low, closing in a little, inside
## the ropes. This close and this far tilted the rig's lamps are behind his
## head, on purpose: 2K26 3:46, "low in the ring, backlit by the rig". (The
## rig-out-of-frame rule is for the wides.)
const RING_HERO_ANGLE := Vector2(40.0, 50.0)
const RING_HERO_DISTANCE := Vector2(2.3, 2.1)
const RING_HERO_HEIGHT := 0.75
const RING_HERO_LOOK := 1.65
const RING_HERO_FOV := 40.0
## His portal on a held long lens (R-41: a static head-on long lens).
const ROMAN_PORTAL_FOV := 16.0
## The lip's three shots, as shares of the time he stands there.
const ROMAN_LIP_SHARES := [0.36, 0.26, 0.38]
## Whose lower third goes up on the director's own clock (the ramp card)
## rather than on the announcer's audio: a commentary line on the shared
## voice lane can hold Justin's name back, and the camera has the card's
## frame waiting for it (`low_lead`).
const CARD_ON_SCHEDULE := ["roman"]
## Until then the broadcast shows the building and his video: six shots, each
## a slow move eased in and out (blender-cameras: push-ins, a truck, a wide
## establishing lens), in seconds. [from, to, look_from, look_to, fov_from,
## fov_to, seconds]. Lenses as vertical FOV: 53 ~ 24 mm, 38 ~ 35 mm,
## 27 ~ 50 mm, 16 ~ 85 mm.
## How far in front of the wall the camera stands for its shot: at 32 degrees
## of vertical lens the 6 m wall fills the frame top to bottom with a little
## over, the bottom edge of the frame stays above the portals (the empty
## tunnel never in shot -- test_entrance_cameras), and a metre or two of each
## end is cropped (the wall is 3:1, the frame 16:9).
const ROMAN_WALL_BACK := 13.5
const ROMAN_INTRO_SHOTS := [
	# The building, the stage empty under his light: high in the far end, a
	# 24 mm wide, trucking across (R-41 0-10 s; 2K26 Roman 1:55).
	# Low enough and tilted down enough that the ring rig's far lines sit
	# over the top of frame while the wall's top is still in it (2 Nov: the
	# rig was across the top of this shot) -- rig_in_frame.
	[Vector3(8.5, STAGE_WIDE_LOW_Y, 14.0), Vector3(3.0, STAGE_WIDE_LOW_Y, 14.5),
		Vector3(4.4, -0.1, -1.5), Vector3(1.6, 0.15, -1.4), 44.0, 44.0, 7.0],
	# His video on the wall, square on and level with its centre, pushing in
	# a little: the whole OTC panel in frame, the portals' tops just under
	# it. It aimed at the wall's old centre (9.2 m; the wall now sits on the
	# three screens below it, SCREEN_CENTER_Y 6.75), so the push rode up over
	# the video into the truss -- the owner, 2 Nov. The last shot of the
	# montage, held to the end of the intro.
	[Vector3(0.0, ArenaBuilder.SCREEN_CENTER_Y - 0.3, ArenaBuilder.SCREEN_FACE_Z + ROMAN_WALL_BACK),
		Vector3(0.0, ArenaBuilder.SCREEN_CENTER_Y - 0.3, ArenaBuilder.SCREEN_FACE_Z + ROMAN_WALL_BACK - 0.6),
		Vector3(0.0, ArenaBuilder.SCREEN_CENTER_Y - 0.25, ArenaBuilder.SCREEN_FACE_Z),
		Vector3(0.0, ArenaBuilder.SCREEN_CENTER_Y - 0.25, ArenaBuilder.SCREEN_FACE_Z), 34.0, 34.0, 6.0],
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
const ROMAN_HOUSE_DIM := 0.50
const ROMAN_AMBIENT_DIM := 0.55
## A darker opening gives the gold launch trails real contrast before the
## house lights return for wrestler entrances.
const OPENING_HOUSE_DIM := 0.22
const OPENING_AMBIENT_DIM := 0.32
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
## 2K26 (cody_entrance_aaa_plan.md step 4, 1:01-1:18): a long waist-up hold
## walking at the lens with the wall behind him, over the shoulder on the
## jacket's back, a close front, then the barricade. `arena_high` is gone: it
## showed him as a dot on a dark ramp, the shot Roman's cut also lost.
## [shot, seconds], cycled; whole beats of his music (A4).
## The owner, 9 Nov: no shots from behind him ("over_shoulder" was): the
## barricade's track alongside, a little ahead, his face and the crowd.
const CODY_WALK_SHOTS := [["crane_front", 8 * CODY_BEAT], ["barricade_track", 5 * CODY_BEAT],
		["steadicam_low", 10 * CODY_BEAT]]
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
## Coat_Off: the coat is clear of both sleeves on frame 48.
const COAT_OFF_AT := 96
## Where he stands to climb the corner: this far from the post along the
## diagonal, facing out over it (wrestling_clips.py CORNER_FOOT_*).
const CORNER_ROOT_M := 0.62
## The blackout: the rig to 3% and the ambient to 10%, portal accents off.
## His light in the dark is one cold backlight behind him in his portal, so
## on the WHOAs the camera sees him as a silhouette in the haze.
const CODY_BLACKOUT := 0.03
const CODY_BLACKOUT_AMBIENT := 0.10
## In his blackout the house is not black but dark and blue (refs/entrances.md,
## Cody "Open": "wide shots of a dark, blue-lit house and the crowd"): the
## audience washes held at this share of their own, tinted. At 3% with the
## rest, his crowd cutaway was 2.7 s of black (3 Nov storyboard).
const CODY_HOUSE_FLOOR := 0.22
const CODY_HOUSE_BLUE := Color(0.32, 0.46, 1.0)
## The stands themselves are emissive (the crowd shader's `crowd_light`,
## 0.3 in the entrance look, 9.0 in the match) and already washed blue
## (ArenaBuilder.CROWD_WASH): this much of it in his blackout reads as a dark,
## blue house. The washes alone left it black on Vulkan.
const CODY_HOUSE_CROWD_LIGHT := 1.5
const BACKLIGHT_ENERGY := 30.0
const BACKLIGHT_COLOR := Color(0.82, 0.88, 1.0)
const CODY_RED := Color(1.0, 0.12, 0.10)
const CODY_BLUE := Color(0.18, 0.32, 1.0)
## His shots. The dark wide from high behind the hard camera; the long lens
## on his portal from down the ramp (85 mm, pushing in); a steadicam backing
## ahead of him; and the low angle inside the ring up past him in the corner.
const CODY_DARK_AT := Vector3(0.0, STAGE_WIDE_LOW_Y, 14.0)
const CODY_DARK_LOOK := Vector3(0.0, 0.33, -2.0)
const CODY_DARK_FOV := 44.0

## Kenny Omega (_add_kenny_entrance). Best knowledge, NOT measured off footage
## -- the owner's call, 27 Oct: nothing of his entrance could be downloaded
## to measure. Times are music seconds into "Battle Cry"
## (assets/audio/music/kenny_entrance.ogg), measured off the track itself:
## loud from the top at ~83 bpm (a beat every 0.72 s); an onset at 20.8 s
## with the kick under it at 21.1; one dip at 35-36 s and the lift at 37.0
## (StageVideo's "chorus").
const KENNY_BEAT := 0.72
## He walks out on the 20.8 s onset...
const KENNY_OUT := 20.8
## ...and his arms go wide on the stage on the lift, the stage pyro with them.
const KENNY_LIFT := 37.0
## Unhurried: Kenny_Walk travels 1.1 m/s.
const KENNY_WALK_SPEED := 1.1
const KENNY_WALK_CLIP := "strikes/kenny_walk"
## Kenny_Stage_Pose throws the arms wide on its frame 12 (24 ticks) and runs
## 5 s; Kenny_Corner_Wings spreads them on its frame 12 and runs 4 s.
const KENNY_PYRO_AT := 24
const KENNY_POSE_TICKS := 300
const KENNY_WINGS_TICKS := 240
## Down the ramp as Cody's cut is, on his beat; hands slapped along one side
## of the aisle and then the other (wrestling_clips.py KENNY_GESTURES).
const KENNY_WALK_SHOTS := [["crane_front", 8 * KENNY_BEAT], ["barricade_track", 5 * KENNY_BEAT],
		["steadicam_low", 10 * KENNY_BEAT]]
const KENNY_WALK_GESTURES := ["strikes/kenny_walk_slap_l", "strikes/kenny_walk_slap_r"]
## His video starting on the big screen: from a crane over the floor, square
## to the wall, the whole screen and the dark stage under it (owner: the old
## cut "stays too long on the crowd" -- the 2K26 intro shows the video).
## Back over the barricade since the wall came down onto the LED screens (20
## Oct): the whole set fits a long lens from there, and the empty stage
## centre stays a far-off part of it, not a close-up, through the push-in.
const TRON_SHOT_AT := Vector3(0.0, 5.4, -8.0)
const TRON_SHOT_FOV := 30.0
const PORTAL_LONG_FOV := Vector2(19.0, 14.0)
const STEADICAM_FOV := 32.0
const CORNER_FRONT_OUT := 3.4
const CORNER_FRONT_SIDE := 0.9
const CORNER_FRONT_HEIGHT := 1.0
const CORNER_FRONT_FOV := 40.0
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
## Kenny's stage, from the owner's Dynamite clip: the set's blue flames on the
## screens, blue light and blue smoke round him.
const KENNY_BLUE := Color(0.26, 0.56, 1.0)
## The clip's white strobe, this many ticks into his walk-out; and his still
## hold in the spotlight after the pose.
const KENNY_STROBE_AT := 150
const KENNY_SPOT_HOLD_TICKS := 240
const ROMAN_PYRO_RED := Color(1.0, 0.10, 0.16)
## His shots. On the mark ("stage_push"): from the ramp, head-on, the whole
## man with his wall above him, five metres off, the lens under his waist --
## locked (the owner, 9 Nov: "a bit too much crane zooming"; it was a dolly
## and a lens tightening on top of the camera's own push-in, and every cut
## out of it was a punch-in on the same axis). The hero shot: low at his feet
## looking up, for the title. The wide: the whole set, for the pyro. The ring
## low: from the mat under the ropes, for the finger in the ring.
const PUSH_FROM := Vector3(0.0, ArenaBuilder.STAGE_DECK_Y + 0.8, ArenaBuilder.STAGE_FRONT - 0.6 + 5.0)
const PUSH_TO := PUSH_FROM
const PUSH_FOV := Vector2(33.0, 33.0)
## Eye level, not a worm's-eye: 2K26's entrance mids sit at chest-to-eye
## height (owner: "I don't like the low camera facing up"; cody_roman_2k26.md).
const HERO_OFFSET := Vector3(0.9, 1.45, 3.0)
const HERO_FOV := 40.0
## Raised a metre and moved two metres toward the stage: the stage wide now
## clears the overhead ring truss in perspective so it no longer lays across
## the LED wall's top edge. Keep the camera below the fixture bodies; moving
## the truss would disturb calibrated ring lighting, and a pitch-only change
## would not alter the truss-to-screen sightline.
const STAGE_WIDE_AT := Vector3(0.0, 4.2, -17.0)
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
const ARENA_HIGH_AT := Vector3(6.5, 5.0, 12.0)
const ARENA_HIGH_FOV := 50.0
## Behind him, over his shoulder, down the ramp at the crowd (R-CJ).
const OVER_SHOULDER_FOV := 50.0
## Low on the ramp looking up at him under the set (R-41 50-58 s): the lens
## 0.8 m over the deck he stands on, below his waist, locked.
const RAMP_LOW_WIDE_AT := Vector3(0.0, ArenaBuilder.STAGE_DECK_Y + 0.8,
		ArenaBuilder.STAGE_FRONT + 8.5)
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
const END_WIDE_LOOK := Vector3(0.0, 0.5, 0.0)
const END_WIDE_FOV := 46.0
## Inside the ring, low, behind him as he comes through the ropes (C-SNME).
const RING_BEHIND_FOV := 70.0
## Through the ropes, wide (stage 8 review: in close, ducking under the top
## rope read as clunky, and it is the hardest piece of body work in the
## entrance). Composed by the blender-cameras / camera-cinematography rules:
## a ~26 mm establishing lens (50 degrees vertical), locked off and panning
## only to follow him; on the +X side like the ringside shot either side of
## it, so his direction of travel does not flip across the cut; high enough
## (2.9 m) to see over the near ropes into the ring; aimed a metre ahead of
## him so he sits on the right third with his lead room into the ring --
## ropes in the foreground, him in the middle ground, the crowd behind.
## Inside the barricade (radius 6.0), or the front rows are in the lens.
## The owner, 9 Nov: "When each wrestler is entering through the ropes ...
## cut to a different angle further zoomed out. Use that same angle when Cody
## is handing his coat to Aubrey. The animations for those isn't great so I
## want to hide them a bit." Every man's step through the ropes and Cody's
## coat hand-off cut to it from the ring arrival's crane (whose clock runs on
## under it), opened out from 50 degrees.
const ROPE_WIDE_AT := Vector3(5.6, 3.1, -0.6)
const ROPE_WIDE_FOV := 60.0
const ROPE_WIDE_LEAD := 1.0
## The hard-camera side crowd, for the WHOAs in the dark (C-MITB 12-20 s).
const CROWD_WIDE_AT := Vector3(3.8, 1.6, 1.0)
const CROWD_WIDE_LOOK := Vector3(16.0, 4.5, 0.0)
const CROWD_WIDE_FOV := 40.0
## And the other side's, across the ring toward the far end.
const CROWD_FAR_AT := Vector3(-3.8, 1.6, 2.0)
const CROWD_FAR_LOOK := Vector3(-15.0, 4.8, 9.0)
## The dark house from high on the side: across the ring to the far side's
## seats, the stage out of frame. It looked down at (-4, -1, -2), tipped under
## the rig on 2 Nov -- in Cody's blackout that was black floor with the stage
## jammed into the top corner (3 Nov storyboard). Tipped by rig_clear_look.
const ARENA_DARK_LOOK := Vector3(-18.0, 4.0, 4.0)
## 2K26's walking shot: ahead of him at chest height, a normal lens.
const STEADICAM_FRONT_AHEAD := 2.6
const STEADICAM_FRONT_HEIGHT := 1.4
const STEADICAM_FRONT_FOV := 28.0
## The walk's crane (the owner, 3 Nov: the half-body shot "looks too stiff
## ... maybe something with the crane?"), in place of steadicam_front on
## every walk. A jib on a dolly backing down ahead of him: it opens high and
## off his right shoulder, looking down on him with the building round him,
## and over the shot the arm booms down and swings in until it is just under
## his chest looking up -- landing where the low tracking shot he likes
## lives -- while the lens tightens from the whole man to knees-up.
## [start, end] of the move, eased; metres from him, his forward and right.
## The ring arrival's crane (the owner, 3 Nov: up the steps, through the
## ropes and the props to Aubrey "I want to keep all of that wide angle
## shots ... consider if a crane camera makes sense"). One jib off the
## entry corner, outside the ring on the hard camera's side: it opens high on
## the steps, the corner and the whole ring, and over ENTRY_CRANE_TICKS
## booms down and in while it keeps him in frame -- the floor, the steps,
## the apron, the ropes, his mark and every hand-off on one move, no cuts.
## It replaced floor_track, steps_rear, ringside, bow_close, apron_low,
## ring_behind_low and ring_low: seven angles in about thirty seconds.
const ENTRY_CRANE_BACK := Vector2(6.5, 5.0)
const ENTRY_CRANE_SIDE := Vector2(4.5, 3.5)
const ENTRY_CRANE_HEIGHT := Vector2(5.2, 2.6)
const ENTRY_CRANE_FOV := Vector2(52.0, 44.0)
const ENTRY_CRANE_TICKS := 900
## How much of the look follows him (the rest stays on the corner): the
## frame drifts with him rather than chasing him.
const ENTRY_CRANE_FOLLOW := 1.0
const CRANE_FRONT_AHEAD := Vector2(4.6, 3.0)
const CRANE_FRONT_HEIGHT := Vector2(4.2, 1.15)
const CRANE_FRONT_SIDE := Vector2(1.4, 0.5)
const CRANE_FRONT_LOOK := Vector2(0.95, 1.5)
const CRANE_FRONT_FOV := Vector2(42.0, 34.0)
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
var title_match := false
var _camera: MatchCamera
var _hud: Node
var _card: EntranceLowerThird
## Justin Roberts: the main-event intro, then each man's call, his name on
## the card the moment it is said (RingAnnouncer).
var _announcer: RingAnnouncer
## Men whose card comes up on the announcer's call rather than half way down
## the ramp, and ticks left on a called card.
var _called := {}
var _name_card_ticks := 0
var _lights: Node
var _follow: SpotLight3D
var _walk_key: SpotLight3D
var _walk_back: SpotLight3D
var _cam_key: SpotLight3D
var _ramp_wash: Array[SpotLight3D] = []
## Every node frozen for the entrance, with whether it was processing, so the
## bell puts back exactly what was there.
var _frozen: Array = []
## Where each man stands at the bell: where the stare-down ends (_add_faceoff).
var _mark := {}
## Where each man's entrance leaves him; _mark becomes the match start.
var _entrance_mark := {}
## This frame's shot has the camera key on men in the ring (_aim_cam_key):
## the follow spot's off branch leaves it on.
var _ring_key_on := false
## Roman's belt and ula fala, per man, and the pyro -- built when needed.
var _props := {}
## Cody's entrance coat, per man.
var _coats := {}
var _pyro: EntrancePyro
## The stage wall, for his own titantron.
var _wall: StageVideo
## Bottom-right "SKIP ENTRANCE": skips only the entrance that is running.
var _skip_button: Button
## Light energies saved while the house is dimmed, to put back exactly.
var _dimmed := {}
## Lights _dim_house re-coloured, and the colour each had.
var _tinted := {}
## Ticks into the ring-arrival crane's move; -1 when it is not on.
var _entry_crane_ticks := -1
var _entry_crane_cut_back := false
## The stands' light before his blackout lifted it (null: not lifted).
var _crowd_light_was: Variant = null
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
var _opening_elapsed := 0.0
var _opening_shot_index := -1
var _done := false


## The crowd's reaction to a pyro hit (CrowdReaction).
const CROWD_PYRO_POP := 0.8
var _crowd: CrowdReaction


func begin(match_root: Node) -> void:
	_match = match_root
	_a = match_root.get_node("WrestlerA")
	_b = match_root.get_node("WrestlerB")
	for w: WrestlerController in [_a, _b]:
		w.set_presentation_rate(true)
	_camera = match_root.get_node_or_null("MatchCamera") as MatchCamera
	_hud = match_root.get_node_or_null("MatchHUD")
	_lights = match_root.get_node_or_null("LightRig")
	_wall = match_root.find_child("StageVideo", true, false) as StageVideo
	_announcer = RingAnnouncer.new()
	_announcer.name = "RingAnnouncer"
	add_child(_announcer)
	_announcer.name_called.connect(_on_name_called)
	var world: WorldEnvironment = null
	for node in match_root.find_children("*", "WorldEnvironment", true, false):
		world = node as WorldEnvironment
	if world:
		_env = world.environment
	# The timekeeper and the way a man's props reach his table. Both live on
	# in the match: the table, with whatever was set on it.
	var ref := match_root.get_node_or_null("RefereeActor") as RefereeActor
	if ref:
		# MatchSetup has usually built him already, with the title on his
		# table (TitlePresentation)
		_keeper = match_root.get_node_or_null("Timekeeper") as Timekeeper
		if _keeper == null:
			_keeper = Timekeeper.new()
			_keeper.name = "Timekeeper"
			match_root.add_child(_keeper)
			_keeper.setup(PropHandoff.KEEPER_POST, Timekeeper.FACE, PropHandoff.TABLE_AT)
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
		# The owner, 9 Nov: "There's still stalling after they hand over
		# their props and finish their entrance poses. They stand in front
		# of each other staring, instead they should just each walk to their
		# corner." Each entrance ends in his corner for the start
		# (faceoff_corner), facing the other man's -- not on a mark in the
		# middle, from which _add_faceoff then walked him to it.
		var corner := faceoff_corner(mark.origin, -1.0 if me == _a else 1.0)
		var other_corner := faceoff_corner(other.global_position, 1.0 if me == _a else -1.0)
		var across := _flat(other_corner - corner)
		mark.origin = Vector3(corner.x, mark.origin.y, corner.z)
		if across.length() > 0.01:
			mark.basis = _facing_basis(across)
		_mark[me] = mark
		_entrance_mark[me] = mark

	for w: WrestlerController in [_a, _b]:
		_freeze(w)
		if w.ai:
			_freeze(w.ai)
		w.velocity = Vector3.ZERO
		w.visible = false
	# MatchFlow too: its clock is the match's story (feeling-out, heat, hope,
	# cut-off, comeback, finish) and counts physics ticks from when it is
	# built. Left running, the five minutes of entrances spent the first five
	# phases before the bell, and every match launched from the menu opened in
	# the comeback and was over in under four minutes.
	for path in ["MatchReferee", "GrappleRig", "MatchFlow"]:
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
	_skip_button = _make_skip_button()
	layer.add_child(_skip_button)

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
	_walk_key.light_color = Color(1.0, 0.98, 0.95)
	_walk_key.light_energy = WALK_KEY_ENERGY
	_walk_key.spot_angle = WALK_KEY_ANGLE
	_walk_key.spot_angle_attenuation = 1.6
	_walk_key.spot_range = WALK_KEY_RANGE
	_walk_key.spot_attenuation = 0.6
	# No beam in the haze: a light hanging in mid-air must not be seen.
	_walk_key.light_volumetric_fog_energy = 0.0
	_walk_key.light_specular = 0.35
	_walk_key.shadow_enabled = true
	_walk_key.light_size = 0.12
	_walk_key.visible = false
	add_child(_walk_key)
	_walk_back = _walk_key.duplicate() as SpotLight3D
	_walk_back.name = "WalkBack"
	_walk_back.light_color = Color(0.88, 0.93, 1.0)
	_walk_back.light_energy = WALK_BACK_ENERGY
	_walk_back.shadow_enabled = false
	_walk_back.spot_angle = WALK_BACK_ANGLE
	_walk_back.spot_range = WALK_BACK_RANGE
	add_child(_walk_back)
	_cam_key = _walk_key.duplicate() as SpotLight3D
	_cam_key.name = "CamKey"
	_cam_key.light_color = Color(1.0, 0.95, 0.88)
	_cam_key.light_energy = CAM_KEY_ENERGY
	_cam_key.shadow_enabled = false
	_cam_key.spot_attenuation = 0.4
	_cam_key.light_specular = 0.25
	add_child(_cam_key)
	for side: float in [-1.0, 1.0]:
		var wash := SpotLight3D.new()
		wash.name = "RampWash"
		wash.light_color = Color(0.92, 0.95, 1.0)
		wash.light_energy = RAMP_WASH_ENERGY
		wash.spot_angle = RAMP_WASH_ANGLE
		wash.spot_angle_attenuation = 1.4
		wash.spot_range = 40.0
		wash.spot_attenuation = 0.5
		wash.light_volumetric_fog_energy = 0.0
		wash.shadow_enabled = false
		wash.visible = false
		wash.set_meta("side", side)
		add_child(wash)
		_ramp_wash.append(wash)

	# The camera is the director's from the first rendered frame, not the
	# first tick -- otherwise frame one is the match camera's hard-cam shot of
	# an empty ring.
	if _camera:
		_camera.set_entrance_shot(OPENING_AT, OPENING_LOOK, OPENING_FOV, true)

	_build_timeline()
	_start_beat()


func voice_announcer() -> RingAnnouncer:
	return _announcer


func _freeze(node: Node) -> void:
	_frozen.append([node, node.is_physics_processing()])
	node.set_physics_process(false)


# ---------------------------------------------------------------------------
# The timeline
# ---------------------------------------------------------------------------

## Each beat is {kind, who, ticks, ...}. Walks carry a polyline; clips carry a
## root line; every beat names its camera shot and whether the card is up.
func _build_timeline() -> void:
	_beats.append({"kind": "opening", "ticks": OPENING_TICKS,
			"events": [[1, "broadcast_open"], [1, "show_dark"], [1, "pyro_opening"]]})
	# Excalibur and Tony open the broadcast. Justin's match announcement is
	# cued on the first beat of the first wrestler's entrance below.
	_beats.append({"kind": "hold", "shot": "opening",
			"events": [[1, "excalibur_crowd"], [1, OPENING_SIGN_CUE]],
			"ticks": EXCALIBUR_CROWD_CALL_TICKS})
	if title_match:
		_beats.append({"kind": "hold", "shot": "opening", "events": [[1, "title_match"]],
				"ticks": TITLE_MATCH_CALL_TICKS})
	# The opponent enters first and waits in the ring; the player's man last.
	# Both walk out of the centre of the 2026 set, between the LED walls; the
	# side still picks which half of the deck heads his cues tint.
	for pair: Array in [[_b, ArenaBuilder.ENTRANCE_X, "E"],
			[_a, ArenaBuilder.ENTRANCE_X, "W"]]:
		var w: WrestlerController = pair[0]
		var first_beat := _beats.size()
		if w.entrance_style == "roman":
			_add_roman_entrance(w, pair[1], pair[2])
		elif w.entrance_style == "cody":
			_add_cody_entrance(w, pair[1], pair[2])
		elif w.entrance_style == "kenny":
			_add_kenny_entrance(w, pair[1], pair[2])
		else:
			_add_entrance(w, pair[1], pair[2])
		if w == _b:
			# The cold open hands the house back as the first entrance starts:
			# its dim is the opening's, and _dim_house holds one dim at a time,
			# so left on it would swallow each man's own (Roman's dim, Cody's
			# blackout).
			var first: Dictionary = _beats[first_beat]
			first["events"] = [[1, "opening_end"]] + (first.get("events", []) as Array)
		if w == _b and RingAnnouncer.has_call("intro"):
			# Start Justin's "one fall" call with the opening of the first
			# entrance, rather than holding the show before the entrance begins.
			var entrance_open: Dictionary = _beats[first_beat]
			entrance_open["events"] = (entrance_open.get("events", []) as Array).duplicate() \
					+ [[1, "announce_intro"]]
		# Whose entrance this is, from its first tick: commentary queued for
		# the last man's that has not been reached yet is dropped (MatchAudio).
		var opening: Dictionary = _beats[first_beat]
		opening["events"] = (opening.get("events", []) as Array).duplicate() \
				+ [[1, "entrance_" + w.entrance_style]]
		if w == _a:
			# The second man's entrance opens clean: the first man's ring
			# shells were still bursting over Roman's building wide (2 Nov).
			opening["events"] = (opening["events"] as Array) + [[1, "pyro_clear"]]
		_schedule_call(w, first_beat)
		if w == _b:
			# The handover: he is on his mark and his music fades under the
			# closing wide before the next man's starts -- never one track
			# cut into the next, and never straight from him to an empty
			# tunnel.
			_beats.append({"kind": "hold", "who": w, "ticks": HANDOVER_TICKS,
					"shot": "end_wide"})
	_add_faceoff()


## How long a called name stays on the card (the ramp card's own cap).
const NAME_CARD_TICKS := RAMP_CARD_TICKS


## Starts `w`'s call early enough that his name is said on the moment his
## card should come up: Cody's on the low WHOA's arms going wide (2K26 puts
## his card up straight after the arms-wide pose), anyone else's half way
## down the ramp, where the ramp card always went up. Counts back through the
## beats from that moment and drops an "announce" cue in the beat it lands in.
func _schedule_call(w: WrestlerController, first_beat: int) -> void:
	var style := w.entrance_style
	var target := _name_moment(w, first_beat)
	if target.is_empty():
		return
	if not RingAnnouncer.has_call(style) or RingAnnouncer.name_at(style) <= 0.0:
		_card_at(w, target)
		return
	var idx: int = target[0]
	var tick: int = int(target[1]) - int(round(RingAnnouncer.name_at(style) * TPS))
	while tick < 1 and idx > first_beat:
		idx -= 1
		tick += beat_ticks(_beats[idx])
	tick = maxi(tick, 1)
	var beat: Dictionary = _beats[idx]
	beat["events"] = (beat.get("events", []) as Array).duplicate() + [[tick, "announce"]]
	# Said inside his own entrance, the name puts his card up. Kenny's is
	# 18.9 s in, and walking first he waits behind Justin's intro besides:
	# his name would come out over the other man's walk. Justin still calls
	# him, but his card goes up on the ramp, as for a man not announced.
	var at := 0
	var start := 0
	var end := 0
	for i in _beats.size():
		if i == idx:
			start = at + tick
		if _beats[i].get("who") == w:
			end = at + beat_ticks(_beats[i])
		at += beat_ticks(_beats[i])
	if w == _b:
		end += HANDOVER_TICKS
	var said := start + int(round(RingAnnouncer.name_at(style) * TPS))
	if w == _b and RingAnnouncer.has_call("intro"):
		said += int(round(RingAnnouncer.length_of("intro") * TPS))
	if said <= end and not (style in CARD_ON_SCHEDULE):
		_called[w] = true
	else:
		# Off the director's clock: the ramp card at half way (or this cue).
		_card_at(w, target)


## His card at `target` ([beat, tick]) for a man whose name does not put it
## up. A walk that crosses half way puts it up itself (_tick_ramp_card); the
## plain entrance's never does -- its tracking shot stops 1.5 m short -- so
## until 27 Oct a man without an entrance of his own (Kenny) had no card.
func _card_at(w: WrestlerController, target: Array) -> void:
	var beat: Dictionary = _beats[int(target[0])]
	if beat.get("ramp_card", false):
		return
	beat["events"] = (beat.get("events", []) as Array).duplicate() + [[int(target[1]), "name_card"]]


## [beat index, tick] at which `w`'s name should be said, or [].
func _name_moment(w: WrestlerController, first_beat: int) -> Array:
	for i in range(first_beat, _beats.size()):
		var beat: Dictionary = _beats[i]
		if beat.get("who") == w and beat.get("clip", "") == "strikes/whoa_low":
			return [i, WHOA_LOW_WIDE_AT]
	var halfway := (ArenaBuilder.STAGE_FRONT + CUT_TO_Z) * 0.5
	for i in range(first_beat, _beats.size()):
		var beat: Dictionary = _beats[i]
		if beat.get("who") != w or beat["kind"] != "walk" or not beat.get("ramp_card", false):
			continue
		var path: Array = beat["path"]
		var a: Vector3 = path[0]
		var b: Vector3 = path[path.size() - 1]
		if (a.z - halfway) * (b.z - halfway) > 0.0:
			continue
		var frac := 0.0 if is_equal_approx(a.z, b.z) else (halfway - a.z) / (b.z - a.z)
		var speed: float = beat.get("speed", WALK_SPEED)
		return [i, maxi(1, int(round(_flat(a).distance_to(_flat(b)) * frac / speed * TPS)))]
	# The plain entrance's tracking shot stops short of half way (6 s down
	# the ramp, RAMP_SHOWN_SECONDS) and cuts to him at CUT_TO_Z, already past
	# it: his card has always gone up on the walk after the cut
	# (_tick_ramp_card), so that is where the name is said.
	for i in range(first_beat, _beats.size()):
		var beat: Dictionary = _beats[i]
		if beat.get("who") == w and beat["kind"] == "walk" and beat.get("cut", false):
			var z: float = (beat["path"][0] as Vector3).z
			if z >= halfway and z <= CUT_TO_Z + 0.5:
				return [i, 1]
	return []


## A beat's length in ticks, as _start_beat() will make it.
func beat_ticks(beat: Dictionary) -> int:
	match beat["kind"]:
		"walk":
			var path: Array = beat["path"]
			var length := 0.0
			for i in path.size() - 1:
				length += _flat(path[i]).distance_to(_flat(path[i + 1]))
			return maxi(1, int(ceil(length / float(beat.get("speed", WALK_SPEED)) * TPS)))
		"turn":
			return SETTLE_TICKS if beat.get("settle", false) else 18
	return int(beat.get("ticks", 1))


## The announcer is saying his name: his card, now.
func _on_name_called(style: String) -> void:
	for w: WrestlerController in [_a, _b]:
		if w.entrance_style == style and _called.has(w) and _beats.size() > 0 \
				and _beats[mini(_beat, _beats.size() - 1)].get("who") == w:
			_card.show_card(w.display_name if w.display_name != "" else String(w.name),
					w.entrance_subtitle)
			_name_card_ticks = NAME_CARD_TICKS
			return


## The start of the match (the owner, 2 Nov: "start off in each corner, walk
## slowly towards each other, camera slowly zooms into their faces for a
## staredown, bell rings and they immediately grapple"). It used to walk up,
## stare, turn and walk back to the marks, and after the bell the two walked
## into each other on a walk cycle to lock up. Now: from his mark each man
## goes to his corner -- diagonally opposite -- and turns in; the intro
## (match card, the check, each man in his corner); the slow walk out to
## FACEOFF_GAP; the stare-down on one slow push into their faces
## ("staredown_push"); and the bell where they stand, so the lock-up is the
## first thing either does. The marks become where the stare ends.
## Each beat is a "pair" beat: both men move at once, each on his own line.
func _add_faceoff() -> void:
	var a: Transform3D = _mark[_a]
	var b: Transform3D = _mark[_b]
	var ca := faceoff_corner(a.origin, -1.0)
	var cb := faceoff_corner(b.origin, 1.0)
	var to_a := _flat(ca - a.origin)
	var to_b := _flat(cb - b.origin)
	var walk_out := maxi(1, int(ceil(maxf(to_a.length(), to_b.length()) / FACEOFF_CORNER_SPEED * TPS)))
	# The house lights come up as they go to their corners, not on the match
	# card: the owner, 2 Nov, "the camera panned to the corners but the
	# wrestlers were not there" -- they were, in the entrance dark. Up on the
	# card, the fade was still under way, and the walk and the card's wide of
	# the corners showed silhouettes.
	# Their entrances end in these corners now (the owner, 9 Nov): a walk
	# only when a skip or a route left a man short of his.
	var walked := maxf(to_a.length(), to_b.length()) > 0.05
	if walked:
		_beats.append({"kind": "pair", "ticks": walk_out, "shot": "faceoff",
				"events": [[1, "lights_up"]], "moves": [
				[_a, a.origin, ca, to_a, FACEOFF_CORNER_CLIP],
				[_b, b.origin, cb, to_b, FACEOFF_CORNER_CLIP]]})
	var face_a := _flat(cb - ca)
	var face_b := -face_a
	_beats.append({"kind": "pair", "ticks": FACEOFF_CORNER_TURN_TICKS, "shot": "faceoff",
			"events": [] if walked else [[1, "lights_up"]], "moves": [
			[_a, ca, ca, face_a, _wait_clip(_a)], [_b, cb, cb, face_b, _wait_clip(_b)]]})
	_add_intro(Transform3D(_facing_basis(face_a), ca), Transform3D(_facing_basis(face_b), cb),
			face_a, face_b)
	var mid := (ca + cb) * 0.5
	var a_in := mid + _flat(ca - mid).normalized() * (FACEOFF_GAP * 0.5)
	var b_in := mid + _flat(cb - mid).normalized() * (FACEOFF_GAP * 0.5)
	var walk_in := maxi(1, int(ceil(_flat(ca).distance_to(_flat(a_in)) / FACEOFF_WALK_SPEED * TPS)))
	_beats.append({"kind": "pair", "ticks": walk_in, "shot": "faceoff_side",
			"events": [[1, "house_down"]], "moves": [
			[_a, ca, a_in, face_a, FACEOFF_WALK_CLIP],
			[_b, cb, b_in, face_b, FACEOFF_WALK_CLIP]]})
	# The owner, 9 Nov: "When they face off, I want each of them to hit their
	# pose. Then they should start with a grapple." Each man's signature
	# (faceoff_pose_clip) nose to nose, then a short stare to the bell; the
	# opening is a grapple (WrestlerAI._opening_grapple_done).
	_beats.append({"kind": "pair", "ticks": FACEOFF_POSE_TICKS, "shot": "staredown_push",
			"pose_wide": true, "events": [[1, "faceoff_tension"], [1, "flash_burst"]],
			"moves": [[_a, a_in, a_in, face_a, faceoff_pose_clip(_a)],
					[_b, b_in, b_in, face_b, faceoff_pose_clip(_b)]]})
	_beats.append({"kind": "pair", "ticks": FACEOFF_STARE_TICKS, "shot": "staredown_push",
			"snap_end": true,
			"moves": [[_a, a_in, a_in, face_a, "strikes/face_off"],
					[_b, b_in, b_in, face_b, "strikes/face_off"]]})
	# The match starts where the stare ends: the bell finds them here.
	_mark[_a] = Transform3D(_facing_basis(face_a), a_in)
	_mark[_b] = Transform3D(_facing_basis(face_b), b_in)


## His signature pose at the face-off: Roman's finger, Cody's arms out,
## Kenny's arms up and finger guns.
static func faceoff_pose_clip(w: WrestlerController) -> String:
	match w.entrance_style:
		"roman":
			return "strikes/finger_hold"
		"cody":
			return "strikes/whoa_arms"
		"kenny":
			return "strikes/kenny_stage_pose"
	return "strikes/win_celebrate"


## A man's corner for the start: the one on his own side of the ring
## (`mark`'s side of the centre line along z), at `x_side` -- the two men take
## diagonally opposite corners -- FACEOFF_CORNER_IN in from the turnbuckles.
static func faceoff_corner(mark: Vector3, x_side: float) -> Vector3:
	var corner := Vector2(x_side, 1.0 if mark.z >= 0.0 else -1.0)
	var pad := Vector3(corner.x * RingBuilder.TURNBUCKLE_PAD_XZ, 0.0,
			corner.y * RingBuilder.TURNBUCKLE_PAD_XZ)
	return pad - RingBuilder.step_out_dir(corner) * FACEOFF_CORNER_IN


## A5: both men on their marks while the broadcast introduces the match.
func _add_intro(a: Transform3D, b: Transform3D, face_a: Vector3, face_b: Vector3) -> void:
	var hold := [[_a, a.origin, a.origin, face_a, _wait_clip(_a)],
			[_b, b.origin, b.origin, face_b, _wait_clip(_b)]]
	var checked := intro_checked(a.origin, b.origin)
	_checked = checked
	var first := _b if checked == _a else _a
	var last := _a if checked == _a else _b
	# Both men are in and lit (lights_up, on the walk to the corners in
	# _add_faceoff): the introductions and the stare-down, not at the bell.
	_beats.append({"kind": "pair", "ticks": INTRO_CARD_TICKS, "shot": "match_card",
			"match_card": true, "moves": hold})
	_beats.append({"kind": "pair", "ticks": INTRO_CHECK_TICKS, "shot": "ref_check",
			"focus": last, "moves": hold})
	_beats.append({"kind": "pair", "ticks": INTRO_CLOSE_TICKS, "shot": "corner_intro",
			"focus": first, "moves": hold})
	_beats.append({"kind": "pair", "ticks": INTRO_CLOSE_TICKS, "shot": "corner_intro",
			"focus": last, "moves": hold})
	_add_cell_lowering(hold)


## Hell in a Cell: the cell has hung in the rafters through the entrances
## (CageBuilder.HOIST_LIFT); with both men introduced it comes down over them
## on its chains (the owner, 11 Nov: "the cell should lower after the
## entrances"). WWE's own write-ups describe the descent as the tension beat
## -- the men in their corners staring up at it -- and give no lighting cue,
## so this is ours: the house down, the cell lit by white strobe hits off the
## truss as it drops, and one big flash and the crowd's pop as it lands.
const CELL_LOWER_SECONDS := 9.0
const CELL_LANDED_HOLD := 1.4
const CELL_STROBE_FIRST := 0.8
const CELL_STROBE_GAP := 0.55
const CELL_HOUSE_DIM := 0.28
const CELL_AMBIENT_DIM := 0.35


func _add_cell_lowering(hold: Array) -> void:
	var cage := CageBuilder.of(_match)
	if cage == null or cage.lift <= 0.0:
		return
	var land := int(round(CELL_LOWER_SECONDS * TPS))
	var events := [[1, "cell_lower"]]
	var t := CELL_STROBE_FIRST
	while t < CELL_LOWER_SECONDS - 0.3:
		events.append([int(round(t * TPS)), "cell_strobe"])
		t += CELL_STROBE_GAP
	events.append([land + 1, "cell_landed"])
	_beats.append({"kind": "pair", "ticks": land + int(round(CELL_LANDED_HOLD * TPS)),
			"shot": "cell_lower", "events": events, "moves": hold})


## Low on the hard camera's side, looking up at the cell hanging over the
## ring, tilting down with it as it comes and easing in a little.
const CELL_LOWER_FROM := Vector3(-11.5, 1.2, 7.2)
const CELL_LOWER_TO := Vector3(-9.6, 2.4, 6.0)
const CELL_LOWER_FOV := 48.0


func cell_lower_shot(cage: CageBuilder, e: float) -> Array:
	var at := CELL_LOWER_FROM.lerp(CELL_LOWER_TO, smoothstep(0.0, 1.0, e))
	var look_y := maxf(cage.spec.base_y + cage.lift + 2.2, 1.2)
	return [at, Vector3(0.0, look_y, 0.0), CELL_LOWER_FOV]


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
			# Keep the pre-bell hold consistent with the faceoff: his hands hang
			# clear of the thighs instead of settling onto his hips or into his gear.
			return "strikes/roman_stand"
		"cody":
			return "strikes/cody_stand"
		"kenny":
			return "strikes/kenny_stand"
	return "strikes/face_off"


func _add_entrance(w: WrestlerController, entrance_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(entrance_x, deck, ArenaBuilder.ENTRANCE_Z)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	# His own titantron and music if he has them (StageVideo.ENTRANCES:
	# Kenny's, the owner's 19 Oct video), from the moment he walks out.
	_beats.append({"kind": "walk", "who": w, "path": [emerge, lip],
			"shot": "stage", "lights": side, "appear": true, "events": [[1, "tron_on"]]})
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
			"shot": "ring_high_corner", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ring_high_corner", "settle": true, "snap_end": true,
			"events": [[SETTLE_TICKS, "tron_off"]]})


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
		# The ula fala only. He wore the AEW title round his waist for a
		# while; it read clunky on the walk (the owner, 19 Oct), so it waits
		# on the timekeeper's table for the winner (TitlePresentation).
		_props[w] = EntranceProps.dress(w, false)
	if beat.has("lights"):
		_portal_lights(beat["lights"], true, beat.get("light_color", Color.TRANSPARENT))
	else:
		_portal_lights("", false)
	if beat.get("match_card", false):
		# Keep this broadcast hold clean: individual wrestler introductions use
		# their own lower thirds, but the owner does not want a VS matchup plate
		# over the ring before the bell.
		_card.hide_card()
	elif beat.get("ramp_card", false):
		pass  # shown by _tick_ramp_card once he is half way down the ramp
	elif beat.get("card", false) and w:
		if not _card.is_showing():
			_card.show_card(w.display_name if w.display_name != "" else String(w.name),
					w.entrance_subtitle)
	elif _name_card_ticks <= 0:
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
			if not beat.get("keep_clip", false):
				w.play_presentation_clip(_wait_clip(w))
		"pair":
			for move: Array in beat["moves"]:
				(move[0] as WrestlerController).play_presentation_clip(move[4])
	# Cut to this beat before the next rendered frame. Otherwise one frame keeps
	# the prior opening-stage angle while the first entrant is still hidden in
	# his entrance hold, making the empty portals visible on the cut.
	_frame(beat, 0.0, true)


## The name card: up once he is half way down the ramp, away at its foot.
## The ramp card is up for at most this long (2K26: the type is on for a few
## seconds, never the whole walk). It sat over him for 10+ s.
const RAMP_CARD_TICKS := 240
## Ticks each man's ramp card has been up.
var _ramp_card_ticks := {}


func _tick_ramp_card(w: WrestlerController) -> void:
	if _called.has(w):
		return  # his card goes up on the announcer's call (_on_name_called)
	var z := w.global_position.z
	var halfway := (ArenaBuilder.STAGE_FRONT + CUT_TO_Z) * 0.5
	var shown: int = _ramp_card_ticks.get(w, 0)
	var in_zone := z >= halfway and z <= CUT_TO_Z + 0.5
	if _card.is_showing() and shown > 0:
		_ramp_card_ticks[w] = shown + 1
		if shown + 1 > RAMP_CARD_TICKS or not in_zone:
			_card.hide_card()
			_ramp_card_ticks[w] = RAMP_CARD_TICKS + 1
		return
	if shown > RAMP_CARD_TICKS:
		return
	if in_zone:
		if not _card.is_showing():
			_card.show_card(w.display_name if w.display_name != "" else String(w.name),
					w.entrance_subtitle)
			_ramp_card_ticks[w] = 1
	elif _card.is_showing():
		_card.hide_card()


## Held while the match-up screen still covers the arena: nothing starts --
## no beat, no pyro, no music -- until TitleScreen releases it on
## MatchStinger.revealing (the owner, 3 Nov: "the pyro actually go off during
## our loading screen so we don't see them. Ensure nothing starts until the
## end of the loading screen"). A match started without the stinger is never
## held. HELD_MAX_TICKS lets go anyway if the release never comes.
var held := false
var _held_ticks := 0
const HELD_MAX_TICKS := 900


func release() -> void:
	held = false


func _physics_process(delta: float) -> void:
	if held:
		_held_ticks += 1
		if _held_ticks < HELD_MAX_TICKS:
			return
		held = false
	_update_skip_button()
	if _done or _beat >= _beats.size():
		return
	if Input.is_action_just_pressed("ui_accept"):
		skip()
		return
	var beat: Dictionary = _beats[_beat]
	_tick += 1
	if _name_card_ticks > 0:
		_name_card_ticks -= 1
		if _name_card_ticks == 0:
			_card.hide_card()
	var t := clampf(float(_tick) / float(beat["ticks"]), 0.0, 1.0)
	var w: WrestlerController = beat.get("who")
	for cue: Array in beat.get("events", []):
		if int(cue[0]) == _tick:
			_event(w, cue[1])
	if beat.get("ramp_card", false) and w:
		_tick_ramp_card(w)
	match beat["kind"]:
		"walk":
			var settle_clip: String = beat.get("settle_clip", "")
			var settle_ticks: int = int(beat.get("settle_ticks", 0))
			if settle_clip != "" and _tick == int(beat["ticks"]) - settle_ticks:
				w.play_presentation_clip(settle_clip)
			var progress := _walk_distance_fraction(beat, t)
			var at := _along(beat["path"], progress * float(beat["length"]))
			_place(w, at[0], at[1], false, delta)
			_tick_gesture(w, beat)
		"pose":
			_place(w, w.global_position, beat["facing"], false, delta)
		"turn":
			_place(w, w.global_position, beat["facing"],
					beat.get("snap_end", false) and _tick >= int(beat["ticks"]), delta)
		"pair":
			for move: Array in beat["moves"]:
				var m: WrestlerController = move[0]
				_place(m, (move[1] as Vector3).lerp(move[2], t), move[3],
						beat.get("snap_end", false) and _tick >= int(beat["ticks"]), delta)
		"clip":
			var from: Vector3 = beat["from"]
			var to: Vector3 = beat["to"]
			w.global_position = from.lerp(to, t) \
					+ Vector3.UP * _plant_offset(w, beat.get("plant", false))
			# Into the clip's heading at the walk's turn rate, not in one
			# frame: the apron step starts ~60 degrees off the climb, and
			# the snap read as a glitch on the way in.
			var face: Vector3 = beat["facing"]
			var want := atan2(-face.x, -face.z)
			if beat.has("face_to"):
				# Squared to the ropes in the step's last paces, eased: it
				# was a separate 76-degree spin on the spot on the 0.2 m
				# apron, boots sliding through the canvas.
				var to_face: Vector3 = beat["face_to"]
				var k := smoothstep(float(beat["turn_from"]), 1.0, t)
				want = lerp_angle(want, atan2(-to_face.x, -to_face.z), k)
				w.rotation.y = rotate_toward(w.rotation.y, want, TURN_RATE * delta)
			else:
				w.rotation.y = rotate_toward(w.rotation.y, want, TURN_RATE * delta)
			if beat["clip"] == "strikes/rope_step_through_apron":
				_part_ropes(w, t, beat["facing"])
	_frame(beat, delta)
	_aim_follow_spot(w)
	_aim_tron_rim(w)
	var waiting: bool = beat.get("wait_idle", false) and _handoff != null \
			and not _handoff.is_idle() and _tick < int(beat["ticks"]) + HANDOFF_MAX_WAIT
	if _tick >= int(beat["ticks"]) and not waiting:
		if beat.get("clip", "") == "strikes/rope_step_through_apron":
			_release_ropes()
		_beat += 1
		_start_beat()


## Normalized root progress for a walk with a terminal animation settle. The
## cubic Hermite tail joins the linear path at its current speed and reaches
## zero speed at the endpoint, preserving both beat duration and total travel.
static func _walk_distance_fraction(beat: Dictionary, t: float) -> float:
	var ticks := int(beat.get("settle_ticks", 0))
	var total := int(beat.get("ticks", 0))
	if ticks <= 0 or total <= 0:
		return clampf(t, 0.0, 1.0)
	var start := 1.0 - float(ticks) / float(total)
	if t <= start:
		return clampf(t, 0.0, 1.0)
	var q := clampf((t - start) / (1.0 - start), 0.0, 1.0)
	var q2 := q * q
	var q3 := q2 * q
	return (2.0 * q3 - 3.0 * q2 + 1.0) * start \
		+ (q3 - 2.0 * q2 + q) * (1.0 - start) \
		+ (-2.0 * q3 + 3.0 * q2)


## Skip straight to the bell, both men on their marks.
func skip() -> void:
	_beat = _beats.size()
	_ring_bell_at_marks(true)


## Small and out of the way, bottom right, above the corner.
func _make_skip_button() -> Button:
	var b := Button.new()
	b.name = "SkipEntrance"
	b.text = "SKIP ENTRANCE  ▸"
	b.focus_mode = Control.FOCUS_NONE
	b.flat = false
	b.anchor_left = 1.0
	b.anchor_right = 1.0
	b.anchor_top = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = -190.0
	b.offset_right = -20.0
	b.offset_top = -56.0
	b.offset_bottom = -20.0
	b.add_theme_font_size_override("font_size", 15)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.border_color = Color(1.0, 1.0, 1.0, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.0, 0.0, 0.0, 0.8)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	b.visible = false
	b.pressed.connect(skip_entrance)
	return b


## Shown only while an entrance is running.
func _update_skip_button() -> void:
	if _skip_button:
		_skip_button.visible = entrance_owner() != null


## Index of the first beat after the entrances (the intro and the face-off).
func _intro_beat() -> int:
	for i in _beats.size():
		if (_beats[i] as Dictionary)["kind"] == "pair":
			return i
	return _beats.size()


## Index of the handover beat that closes the first man's entrance, or -1.
func _handover_beat() -> int:
	for i in _beats.size():
		var b: Dictionary = _beats[i]
		if b.get("shot", "") == "end_wide" and b.get("who") == _b:
			return i
	return -1


## Whose entrance is running now, or null outside them (the intro, the
## face-off, after the bell).
func entrance_owner() -> WrestlerController:
	if _done or _beat >= _intro_beat():
		return null
	var handover := _handover_beat()
	if handover >= 0 and _beat < handover:
		return _b
	if handover >= 0 and _beat == handover:
		return null
	return _a


## Skips just the entrance that is running: that man is tidied away onto his
## mark (props to the table, his lights, smoke and music off) and the show
## picks up where his entrance would have ended -- the handover to the next
## man, or the introductions if he was the last.
func skip_entrance() -> void:
	var who := entrance_owner()
	if who == null:
		return
	_release_ropes()
	_card.hide_card()
	_name_card_ticks = 0
	if _announcer:
		_announcer.stop()
	_portal_lights("", false)
	if _handoff:
		_handoff.finish_now()
	if _props.has(who):
		(_props[who] as Node).queue_free()
		_props.erase(who)
	if _coats.has(who):
		(_coats[who] as Node).queue_free()
		_coats.erase(who)
	_smoke_off()
	if _backlight:
		_backlight.queue_free()
		_backlight = null
	if _wall:
		_wall.end_entrance()
	_tron_on = false
	if _tron_rim:
		_tron_rim.visible = false
	_dim_house(false)
	_pose_top(null)
	# Where his entrance ends, not the match's start (_add_faceoff moves
	# _mark to where the stare ends): the beats after this walk from here.
	who.global_transform = _entrance_mark[who]
	MatchSmoothing.snap(who)
	who.velocity = Vector3.ZERO
	who.visible = true
	_beat = _handover_beat() if who == _b else _intro_beat()
	_start_beat()


func _ring_bell() -> void:
	_ring_bell_at_marks(false)


func _ring_bell_at_marks(place_on_marks: bool) -> void:
	if _done:
		return
	_done = true
	# The house back up with the bell, and the building's flashes go off.
	if _lights and _lights.has_method("set_house_level"):
		_lights.set_house_level(1.0)
	cue.emit("flash_burst")
	_release_ropes()
	_card.hide_card()
	_name_card_ticks = 0
	if _announcer:
		_announcer.stop()
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
		# The entrance route must deliver him to his mark. Resetting the transform
		# here hid route errors in tests and appeared as a teleport at the bell.
		# The explicit skip action is the exception: skip places each wrestler at
		# the match start without running his entrance route.
		if place_on_marks:
			w.global_transform = _mark[w]
		else:
			# The final entrance turn is presentation. Reassert each saved match
			# heading at the handoff so the bell can never inherit a stale facing
			# from the last pose or an interrupted turn.
			w.global_transform.basis = _mark[w].basis
		MatchSmoothing.snap(w)
		w.velocity = Vector3.ZERO
		w.visible = true
		w.end_presentation()
		w.set_presentation_rate(false)
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
func _add_roman_entrance(w: WrestlerController, entrance_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(entrance_x, deck, ArenaBuilder.ENTRANCE_Z)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var blue := {"lights": side, "light_color": ROMAN_BLUE}
	# The owner, 2 Nov: "too much time spent on crowd shots" -- 26 s of the
	# building, his wall and a dark crowd pan before he was seen -- with the
	# whole song kept. So the building gets ROMAN_INTRO_SECONDS (2K26: he is
	# on the stage ~13 s in), and the rest of the build up to the slam
	# (ROMAN_MUSIC_HIT) is him: standing in his portal, the walk out, the lip.
	# Built backward from the slam, as before: the finger's arm arrives
	# FINGER_PYRO_AT ticks into Finger_Hold, so it starts that much early.
	var finger_start := ROMAN_MUSIC_HIT - float(FINGER_PYRO_AT) / TPS
	var walk_s := _flat(emerge).distance_to(_flat(lip)) / ROMAN_WALK_SPEED
	var portal_end := ROMAN_INTRO_SECONDS + ROMAN_PORTAL_HOLD
	var lip_s := maxf(finger_start - portal_end - walk_s, 3.0)
	_beats.append({"kind": "hold", "who": w,
			"ticks": _secs(0.0, ROMAN_INTRO_SECONDS), "shot": "intro",
			# The stage pyro on the intro's last tick, so its wide is up as
			# he appears: fired on his first tick, the long lens showed for
			# one frame between the wall and the pyro wide.
			"events": [[1, "tron_on"], [1, "dim_on"],
					[_secs(0.0, ROMAN_INTRO_SECONDS), "pyro_stage"]]})
	# In his portal, head bowed, while the music builds: the long lens dead on
	# the portal, held (2K26 2:08-2:17, him small under his wall; R-41's static
	# head-on long lens -- no creep, the owner's "too much zooming").
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(ROMAN_INTRO_SECONDS, portal_end),
			"clip": "strikes/head_bow", "facing": Vector3.BACK,
			"shot": "portal_long", "portal": emerge, "push_from": 0, "lens": ROMAN_PORTAL_FOV,
			"push_over": _secs(ROMAN_INTRO_SECONDS, portal_end),
			"appear": true, "props": true, "path": [emerge, emerge + Vector3.BACK * 0.1]}))
	var half := emerge.lerp(lip, 0.5)
	# The walk out: his wall behind him at the long lens, then the low
	# ultra-wide gimbal backing ahead of him to the lip (the owner, 9 Nov: the
	# crane that was here and the chest-high lens are gone).
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [emerge, half],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP, "shot": "stage"}))
	_beats.append(_with(blue, {"kind": "walk", "who": w, "path": [half, lip],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "low_wide_up"}))
	# On the lip, the building looked over: the locked low full figure, the
	# telephoto face, then the low three-quarter -- which carries on, one arc,
	# through the finger going up to the slam (it was a 0.47 s cut to another
	# angle, `hero_low`, straight into the pyro wide).
	var push_s: float = lip_s * float(ROMAN_LIP_SHARES[0])
	var face_s: float = lip_s * float(ROMAN_LIP_SHARES[1])
	var t0 := portal_end + walk_s
	var hero_from := t0 + push_s + face_s
	var hero_ticks := _secs(hero_from, ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE)
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(t0, t0 + push_s),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "stage_push", "locked": true}))
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(t0 + push_s, hero_from),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "face_up", "locked": true}))
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(hero_from, finger_start),
			"clip": "strikes/roman_stand", "facing": Vector3.BACK,
			"shot": "lip_hero", "arc_from": 0, "arc_over": hero_ticks}))
	# The finger, and on the slam the pyro and the room red, on a very wide.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(finger_start, ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE),
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "lip_hero", "arc_from": _secs(hero_from, finger_start),
			"arc_over": hero_ticks,
			"events": [[FINGER_PYRO_AT, "pyro_roman"], [FINGER_PYRO_AT, "accent_red"],
					[FINGER_PYRO_AT + ROMAN_RED_TICKS, "accent_back"]]}))
	# Held, under the low wide from the ramp.
	_beats.append(_with(blue, {"kind": "pose", "who": w,
			"ticks": _secs(ROMAN_MUSIC_HIT + ROMAN_PYRO_WIDE, ROMAN_FINGER_DOWN),
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "ramp_low_wide", "locked": true}))
	# The walk: the one crane off the finger coming down, from high off his
	# right shoulder down onto the lower-third frame, its lens held; then all
	# of the ramp on the low gimbal and the barricade, cut on the bar.
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS - 0.2)
	var crane_to := lip.lerp(foot, minf(ROMAN_CRANE_BEATS * ROMAN_BEAT * ROMAN_WALK_SPEED
			/ _flat(lip).distance_to(_flat(foot)), 1.0))
	_beats.append({"kind": "walk", "who": w, "path": [lip, crane_to],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP, "shot": "crane_front",
			"crane_height": ROMAN_CRANE_HEIGHT, "crane_fov": ROMAN_CRANE_FOV,
			"ramp_card": true})
	_add_walk_cut(w, crane_to, foot, ROMAN_WALK_SPEED, ROMAN_WALK_CLIP, ROMAN_WALK_SHOTS,
			[], true)
	# Ringside, the head bowed, then up the steps and through the ropes.
	var in_at := _add_route_in(w, foot, ROMAN_WALK_SPEED, ROMAN_WALK_CLIP, true, "",
			"strikes/head_bow", ROMAN_BOW_TICKS)
	var centre := Vector3(-0.4, 0.0, -0.6)
	_beats.append({"kind": "walk", "who": w, "path": [in_at, centre],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "entry_crane", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": Vector3.BACK,
			"shot": "entry_crane"})
	# The finger again, from low in front of him, up against the lights (R-39;
	# 2K26 3:28) -- it was on the arrival crane, which by then stands behind
	# him. Then hands on hips, staring, and the ula fala lifted off, on one
	# low three-quarter that closes in a little: Aubrey, back from the
	# timekeeper, walks into it for the ula fala. It used to restart the
	# arrival crane from the top for the ula fala.
	_beats.append({"kind": "pose", "who": w, "ticks": 240,
			"clip": "strikes/finger_hold", "facing": Vector3.BACK,
			"shot": "ring_low_up", "locked": true})
	var hero_ticks_in := 300 + 90
	_beats.append({"kind": "pose", "who": w, "ticks": 300,
			"clip": "strikes/hands_hips", "facing": Vector3.BACK,
			"shot": "ring_hero_low", "arc_from": 0, "arc_over": hero_ticks_in,
			"events": [[1, "prop_call_fala"]]})
	_beats.append({"kind": "pose", "who": w, "ticks": 90,
			"clip": "strikes/ula_fala_off", "facing": Vector3.BACK,
			"shot": "ring_hero_low", "arc_from": 300, "arc_over": hero_ticks_in,
			"events": [[ULA_FALA_LIFT_AT, "fala_off"]]})
	# The hand-off, high on the corner: the whole ring, him and Aubrey (the
	# hard camera's side, R-41 3:24), and on through his walk to his mark.
	_beats.append({"kind": "pose", "who": w, "ticks": _secs(0.0, HAND_OUT_SECONDS),
			"clip": "strikes/prop_hand_out_r", "facing": Vector3.BACK,
			"shot": "ring_high_corner", "events": [[1, "prop_pass_fala"]]})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w, "path": [centre, mark.origin],
			"speed": ROMAN_WALK_SPEED, "walk_clip": ROMAN_WALK_CLIP,
			"shot": "ring_high_corner", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "end_wide", "settle": true, "snap_end": true,
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
func _add_cody_entrance(w: WrestlerController, entrance_x: float, _side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var mouth := Vector3(entrance_x, deck, ArenaBuilder.ENTRANCE_Z)
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
			"events": [[1, "cody_appear"]],
			# A hair over the exact speed, so the tick count rounds to the
			# measured gap and the WHOA lands on its frame.
			"speed": _flat(smoke).distance_to(_flat(mouth))
					/ (float(_secs(CODY_EMERGE, CODY_WHOA - float(WHOA_WIDE_AT) / TPS))
					/ TPS) * 1.000001,
			# The exit lands between gait contacts. Ease the last twelve ticks
			# into his entrance stance while the root decelerates, so the next
			# beat's stationary WHOA wind-up does not catch him mid-stride.
			"walk_clip": CODY_WALK_CLIP, "settle_clip": "strikes/cody_stand",
			"settle_ticks": 12, "shot": "portal_long", "portal": mouth,
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
			"shot": "crane_front"})
	var at_lip := fists_end + to_lip / lip_speed
	if kneel_from - at_lip > 0.6:
		_beats.append({"kind": "pose", "who": w, "lights": "RB",
				"ticks": _secs(at_lip, kneel_from), "clip": "strikes/cody_stand",
				"facing": Vector3.BACK, "shot": "lip_hero"})
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
	var in_at := _add_route_in(w, foot, CODY_WALK_SPEED, CODY_WALK_CLIP, true)
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
			"shot": "entry_crane", "on_mat": true})
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
			"shot": "rope_wide", "pass_facing": inward,
			"events": [[1, "prop_call_coat"], [COAT_OFF_AT, "coat_off"]]})
	_beats.append({"kind": "turn", "who": w, "facing": inward, "shot": "rope_wide"})
	_beats.append({"kind": "pose", "who": w, "ticks": _secs(0.0, HAND_OUT_SECONDS),
			"clip": "strikes/prop_hand_out_r", "facing": inward,
			"shot": "rope_wide", "events": [[1, "prop_pass_coat"]]})
	_beats.append({"kind": "walk", "who": w, "path": [stand, mark.origin],
			"speed": CODY_WALK_SPEED, "walk_clip": CODY_WALK_CLIP,
			"shot": "ring_high_corner", "on_mat": true})
	# On him while the coat goes to the timekeeper's table: the far end wide
	# held empty for the whole carry -- 10.5 s of one static frame on the
	# 3 Nov storyboard. The end wide is the handover's alone.
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "ring_high_corner", "settle": true, "snap_end": true,
			"events": [[SETTLE_TICKS, "tron_off"]]})
	# Nothing moves on until the coat is on the timekeeper's table.
	_beats.append({"kind": "hold", "who": w, "ticks": 30, "shot": "ring_high_corner",
			"wait_idle": true})


## Kenny Omega (KENNY_*; best knowledge, unverified against footage). The
## house down and his video on the wall through the opening of his music;
## he walks out on the onset at 20.8 s, unhurried, to the lip, and stands
## there taking the building in until the track lifts at 37 s: arms thrown
## wide, head back, the stage pyro -- then a point out to the crowd. Down the
## ramp slapping hands on both sides, in by the steps, up onto the second
## rope in the corner with his arms spread over the crowd and the ring pyro,
## and down to his mark. (The "Terminator" kneel the crowd claps along to is
## in the ring before a dive, not his entrance -- Wrestling Inc, 2017.)
func _add_kenny_entrance(w: WrestlerController, entrance_x: float, side: String) -> void:
	var deck := ArenaBuilder.STAGE_DECK_Y
	var emerge := Vector3(entrance_x, deck, ArenaBuilder.ENTRANCE_Z)
	var lip := Vector3(0.0, deck, ArenaBuilder.STAGE_FRONT - 0.6)
	var foot_of_ramp := Vector3(0.0, 0.0, CUT_TO_Z)
	# The owner's clip (8 Nov): his stage is blue -- light, smoke and screens.
	var lit := {"lights": side, "light_color": KENNY_BLUE}
	# Every beat up to the pose is placed by its music time, counted in whole
	# ticks from his first: rounding each beat on its own drifted the pyro.
	var first := _beats.size()
	var to := func(music: float) -> int:
		var done := 0
		for i in range(first, _beats.size()):
			done += beat_ticks(_beats[i])
		return int(round(music * TPS)) - done
	# The opening: the video, the building, the stage waiting for him. (Not
	# the crowd: under the dimmed house its wide rendered all but black.)
	_beats.append({"kind": "hold", "who": w, "ticks": to.call(8.0), "shot": "tron_video",
			"events": [[1, "tron_on"], [1, "dim_on"]]})
	for cut: Array in [[12.5, "arena_dark_high"], [16.85, "tron_video"],
			[KENNY_OUT, "stage_wide"]]:
		_beats.append(_with(lit, {"kind": "hold", "who": w, "ticks": to.call(cut[0]),
				"shot": cut[1]}))
	# Out on the onset, to the lip at his own pace.
	var half := emerge.lerp(lip, 0.5)
	# Out of blue smoke (the clip, 0:30): it rises as he walks out and clears
	# on the pyro.
	# The clip (0:30-0:34): from behind him, low, as he walks into the light,
	# and the white strobe a couple of seconds out.
	_beats.append(_with(lit, {"kind": "walk", "who": w, "path": [emerge, half],
			"speed": KENNY_WALK_SPEED, "walk_clip": KENNY_WALK_CLIP, "appear": true,
			"shot": "steadicam_front", "fog_at": emerge,
			"events": [[1, "fog_on"], [KENNY_STROBE_AT, "strobe"]]}))
	_beats.append(_with(lit, {"kind": "walk", "who": w, "path": [half, lip],
			"speed": KENNY_WALK_SPEED, "walk_clip": KENNY_WALK_CLIP, "shot": "steadicam_low"}))
	# On the lip, looking the building over until the lift: pushed in on, the
	# long lens from down the ramp, then close.
	var at_lip := KENNY_OUT + _flat(emerge).distance_to(_flat(lip)) / KENNY_WALK_SPEED
	var pose_from := KENNY_LIFT - float(KENNY_PYRO_AT) / TPS
	for hold: Array in [[lerpf(at_lip, pose_from, 0.45), "stage_push"],
			[lerpf(at_lip, pose_from, 0.7), "ramp_long"], [pose_from, "hero_low"]]:
		var ticks: int = to.call(hold[0])
		if ticks > 0:
			_beats.append(_with(lit, {"kind": "pose", "who": w, "ticks": ticks,
					"clip": "strikes/kenny_stand", "facing": Vector3.BACK, "shot": hold[1]}))
	# The lift: arms wide, the stage pyro on a low hero angle, then the wide
	# for the burst and the point out to the crowd. The house comes up to the
	# walk's level with the pyro, as on Cody's WHOA: left down, his whole walk
	# to the ring rendered in the dark.
	_beats.append(_with(lit, {"kind": "pose", "who": w, "ticks": KENNY_PYRO_AT + 30,
			"clip": "strikes/kenny_stage_pose", "facing": Vector3.BACK, "shot": "hero_low",
			"events": [[KENNY_PYRO_AT, "pyro_kenny"], [KENNY_PYRO_AT, "house_walk"],
					[KENNY_PYRO_AT, "fog_off"]]}))
	_beats.append(_with(lit, {"kind": "pose", "who": w,
			"ticks": KENNY_POSE_TICKS - KENNY_PYRO_AT - 30, "clip": "strikes/kenny_stage_pose",
			"facing": Vector3.BACK, "shot": "stage_wide"}))
	# The clip (0:58-1:06): stood still in the spotlight between the flames a
	# long beat, the building taking him in, before he bursts down the ramp.
	_beats.append(_with(lit, {"kind": "pose", "who": w, "ticks": KENNY_SPOT_HOLD_TICKS,
			"clip": "strikes/kenny_stand", "facing": Vector3.BACK, "shot": "ramp_long"}))
	# Down the ramp, working both sides.
	_add_walk_cut(w, lip, foot_of_ramp, KENNY_WALK_SPEED, KENNY_WALK_CLIP, KENNY_WALK_SHOTS,
			KENNY_WALK_GESTURES, true)
	var in_at := _add_route_in(w, foot_of_ramp, KENNY_WALK_SPEED, KENNY_WALK_CLIP, true)
	# The corner by the steps, up on the second rope facing out (as Cody's).
	var post := Vector3(ENTRY_CORNER.x * RingBuilder.TURNBUCKLE_PAD_XZ, 0.0,
			ENTRY_CORNER.y * RingBuilder.TURNBUCKLE_PAD_XZ)
	var out_dir := RingBuilder.step_out_dir(ENTRY_CORNER)
	var stand := post - out_dir * CORNER_ROOT_M
	_beats.append({"kind": "walk", "who": w, "path": [in_at, stand],
			"speed": KENNY_WALK_SPEED, "walk_clip": KENNY_WALK_CLIP,
			"shot": "entry_crane", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": out_dir, "shot": "corner_low"})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_climb",
			"ticks": 72, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low"})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/kenny_corner_wings",
			"ticks": KENNY_WINGS_TICKS, "from": stand, "to": stand, "facing": out_dir,
			"shot": "corner_low", "events": [[KENNY_PYRO_AT, "pyro_over_ring"]]})
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/corner_down",
			"ticks": 60, "from": stand, "to": stand, "facing": out_dir,
			"shot": "ring_high_corner"})
	var mark: Transform3D = _mark[w]
	_beats.append({"kind": "walk", "who": w, "path": [stand, mark.origin],
			"speed": KENNY_WALK_SPEED, "walk_clip": KENNY_WALK_CLIP,
			"shot": "ring_high_corner", "on_mat": true})
	_beats.append({"kind": "turn", "who": w, "facing": -mark.basis.z,
			"shot": "end_wide", "settle": true, "snap_end": true,
			"events": [[SETTLE_TICKS, "tron_off"], [SETTLE_TICKS, "dim_off"]]})


## The way into the ring every entrance shares, from the ramp's cut to the
## mat, over the diagonal steps (ring_builder.gd "Steel steps"): across the
## floor to the foot of the flight, in along its diagonal, up it toward the
## post, up onto the apron beside the post, and through the ropes a pace along
## the side. Appends the beats; returns where he lands on the mat.
##
## `split_floor` gives the floor walk its own tracking shot up to the
## approach (Roman's); `survey_clip`, if set, is played standing on the apron
## before he goes in; `floor_clip`, if set, is played for `floor_ticks` at the
## foot of the steps, facing them, on a close shot (Roman's bowed head). The
## step through the ropes is on the wide shot, ROPE_WIDE_AT, for every man
## (cut to from the crane and back).
func _add_route_in(w: WrestlerController, cut: Vector3, speed: float,
		walk_clip: String, split_floor: bool, survey_clip := "",
		floor_clip := "", floor_ticks := 0) -> Vector3:
	var out := RingBuilder.step_out_dir(ENTRY_CORNER)
	var top := RingBuilder.step_top_centre(ENTRY_CORNER)
	# Start on the floor beyond the outermost tread. The old start was only
	# 1.26 m out from the top platform, which put the wrestler halfway up the
	# flight while his root was still at floor height. That read as a float
	# before he even began the climb. Derive the start from the same footprint
	# used by RingBuilder's steps collision and visual mesh.
	var apron_corner := Vector3(ENTRY_CORNER.x * RingBuilder.APRON_OUT, 0.0,
			ENTRY_CORNER.y * RingBuilder.APRON_OUT)
	var flight_outer_edge := apron_corner + out * (RingBuilder.STEP_APRON_GAP
			+ RingBuilder.STEP_PLATFORM + RingBuilder.STEP_RUN * RingBuilder.STEP_TREADS)
	var climb_from := flight_outer_edge
	var approach := climb_from + out * APPROACH_M
	var foot := Vector3(0.0, 0.0, -ArenaBuilder.BARRICADE_RADIUS + 0.4)
	# Round onto the flight on a curve, not out past it and back: the walk
	# went 0.8 m beyond the foot of the steps and swung 130 degrees to come
	# back to them -- the owner's "he turns the wrong way" (2 Nov). The curve
	# leaves the barricade line heading along it and arrives on the stairs'
	# own line, the turn spread over its last couple of metres.
	var curve := approach_curve(foot, approach, climb_from)
	if split_floor:
		# Two shots of about equal length, by distance walked (2K26 holds
		# 6-9 s; the one floor shot ran 11.6 s at Roman's pace).
		var walked := [_flat(cut).distance_to(_flat(curve[0]))]
		for i in range(1, curve.size()):
			walked.append(float(walked[-1]) + _flat(curve[i - 1]).distance_to(_flat(curve[i])))
		var split := 1
		while split < curve.size() - 2 and float(walked[split]) < float(walked[-1]) * 0.5:
			split += 1
		_beats.append({"kind": "walk", "who": w, "path": [cut] + curve.slice(0, split + 1),
				"speed": speed, "walk_clip": walk_clip, "shot": "entry_crane", "cut": true})
		_beats.append({"kind": "walk", "who": w, "path": curve.slice(split),
				"speed": speed, "walk_clip": walk_clip, "shot": "entry_crane"})
	else:
		_beats.append({"kind": "walk", "who": w, "path": [cut] + curve,
				"speed": speed, "walk_clip": walk_clip, "shot": "entry_crane", "cut": true})
	_beats.append({"kind": "turn", "who": w, "facing": -out, "shot": "entry_crane"})
	if floor_clip != "":
		_beats.append({"kind": "pose", "who": w, "ticks": floor_ticks,
				"clip": floor_clip, "facing": -out, "shot": "entry_crane"})
	var top_at := Vector3(top.x, RingBuilder.STEP_TOP_Y, top.z)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/climb_steps",
			"ticks": int(round(CLIMB_SECONDS * TPS)),
			"from": Vector3(climb_from.x, surface_y(climb_from), climb_from.z),
			"to": top_at, "facing": -out, "shot": "entry_crane", "plant": true})
	# Onto the apron, a pace along the side from the post.
	var apron := Vector3(ENTRY_CORNER.x * (RingBuilder.TURNBUCKLE_PAD_XZ - APRON_ALONG_M),
			RingBuilder.APRON_TOP,
			ENTRY_CORNER.y * APRON_STAND)
	var across := _flat(apron - top_at)
	# Square to the ropes in the step's last paces -- facing into the ring
	# across the -Z side, in the apron step's close stance (the wait clip's
	# staggered feet do not fit on the 0.2 m apron).
	var into := Vector3(0.0, 0.0, -ENTRY_CORNER.y)
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/apron_step",
			"ticks": int(round(APRON_STEP_SECONDS * TPS)),
			"from": top_at, "to": apron, "facing": across, "shot": "entry_crane",
			"face_to": into, "turn_from": APRON_TURN_FROM, "plant": true})
	if survey_clip != "":
		_beats.append({"kind": "clip", "who": w, "clip": survey_clip,
				"ticks": 60, "from": apron, "to": apron, "facing": into, "shot": "entry_crane"})
	var inside := apron + into * APRON_ROPE_TO.x
	inside.y = 0.0  # the canvas is level with the ring centre; the apron is not.
	_beats.append({"kind": "clip", "who": w, "clip": "strikes/rope_step_through_apron",
			"ticks": int(round(APRON_ROPE_SECONDS * TPS)),
			"from": apron, "to": inside, "facing": into, "shot": "rope_wide", "plant": true})
	return inside


## The floor walk onto the foot of the steps: a quadratic curve from the
## barricade line (`from`) round through `bend` (out along the stairs' line)
## to `to`, the foot of the flight. Its last tangent is the stairs' own line,
## so he arrives facing up them. Points about 0.35 m apart.
static func approach_curve(from: Vector3, bend: Vector3, to: Vector3) -> Array:
	var length := _flat(from).distance_to(_flat(bend)) + _flat(bend).distance_to(_flat(to))
	var n := maxi(4, int(ceil(length / 0.35)))
	var pts: Array = []
	for i in n + 1:
		var u := float(i) / float(n)
		# weighted toward the end, where the turn is
		var q := 1.0 - pow(1.0 - u, 1.6)
		pts.append(from * (1.0 - q) * (1.0 - q) + bend * 2.0 * (1.0 - q) * q + to * q * q)
	return pts


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


## The cold open's two events. They used to sit in _set_backlight's match,
## which only the backlight events reach: the opening's house dim and its
## pyro never fired, only their sound did (MatchAudio) -- under the match-up
## screen (the owner, 3 Nov).
func _opening_event(what: String) -> void:
	match what:
		"broadcast_open":
			_dim_house(true, OPENING_HOUSE_DIM, OPENING_AMBIENT_DIM)
			if _crowd:
				_crowd.pop(1.0)
		"pyro_opening":
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			# No pyro wide: the opening's own shots are its coverage.
			_pyro.fire("opening")
			if _lights and _lights.has_method("sync_beat"):
				_lights.sync_beat(0.5)
			if _crowd:
				_crowd.pop(1.0)


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
		"announce_intro":
			if _announcer:
				_announcer.play("intro")
		"name_card":
			if w:
				_card.show_card(w.display_name if w.display_name != "" else String(w.name),
						w.entrance_subtitle)
				_name_card_ticks = NAME_CARD_TICKS
		"announce":
			if _announcer and w:
				_announcer.play(w.entrance_style)
				# Whose call it was, for a commentator who answers it (Tony
				# after Kenny's, MatchAudio): queued now, he waits in the
				# voice lane until Justin has finished.
				cue.emit("called_" + w.entrance_style)
		"pyro_clear":
			if _pyro:
				_pyro.queue_free()
				_pyro = null
		"lights_up":
			_dim_house(false)
			# The owner, 3 Nov: "still not standing in their corners during
			# the corner camera pan". They were -- in the dark. The cue above
			# has already put up the MATCH look; _dim_house(false) then put
			# back the levels it saved in the last entrance's dark, ring keys
			# included, so the card wide and both corner close-ups were shot
			# on an unlit ring (two silhouettes against a lit crowd) until
			# house_down re-applied the look at the walk-in. Re-apply it here.
			if _lights and _lights.has_method("set_look"):
				_lights.set_look(_lights.look)
		"cell_lower":
			var cage := CageBuilder.of(_match)
			if cage:
				cage.lower(CELL_LOWER_SECONDS)
			_dim_house(true, CELL_HOUSE_DIM, CELL_AMBIENT_DIM)
			if _crowd:
				_crowd.pop(0.5)
		"cell_strobe":
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			var cage_s := CageBuilder.of(_match)
			_pyro.cell_strobe(cage_s.global_position.y + cage_s.spec.top_y if cage_s else 6.0)
		"cell_landed":
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.cell_landed()
			_dim_house(false)
			if _lights and _lights.has_method("set_look"):
				_lights.set_look(_lights.look)
			if _crowd:
				_crowd.pop(1.0)
			if _camera:
				_camera.add_trauma(0.35)
		"house_down":
			# Pre-bell: the crowd down, the ring kept at full (unlike
			# _dim_house, which takes the ring keys down with the house).
			if _lights and _lights.has_method("set_house_level"):
				_lights.set_house_level(PREBELL_HOUSE_LEVEL)
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
		"prop_pass_title":
			if _handoff:
				_handoff.giver_begins("title")
		"prop_pass_fala":
			if _handoff:
				_handoff.giver_begins("fala")
		"prop_pass_coat":
			if _handoff:
				_handoff.giver_begins("coat")
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
			_dim_house(true, CODY_BLACKOUT, CODY_BLACKOUT_AMBIENT, CODY_HOUSE_FLOOR, CODY_HOUSE_BLUE)
			_crowd_light_was = RenderingServer.global_shader_parameter_get("crowd_light")
			if _crowd_light_was == null:
				_crowd_light_was = ArenaLighting.CROWD_LIGHT_ENTRANCE
			RenderingServer.global_shader_parameter_set("crowd_light", CODY_HOUSE_CROWD_LIGHT)
		"backlight_on", "backlight_dim", "backlight_off":
			_set_backlight(w, what)
		"broadcast_open", "pyro_opening":
			_opening_event(what)
		"opening_end":
			_dim_house(false)
			if _lights and _lights.has_method("crowd_sweep"):
				_lights.crowd_sweep(false)
		"strobe", "pyro_cody_hit", "pyro_cody_punch":
			if what == "pyro_cody_hit" and _lights and _lights.has_method("sync_beat"):
				_lights.sync_beat(CODY_BEAT)
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))
			# No pyro wide for his two: his beats already frame them -- the
			# stage wide for the WHOA's comets, the low hero for the fists.
			# The wide (6.5 s, then 4.5 more on the fists) held one far shot
			# from 26 s to 33.5 s: the fists were never seen, and half the walk
			# to the lip went with them (3 Nov storyboard).
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
		"pyro_stage", "pyro_over_ring", "pyro_roman", "pyro_kenny":
			if what == "pyro_roman" and _lights and _lights.has_method("sync_beat"):
				_lights.sync_beat(ROMAN_BEAT)
			if _pyro == null:
				_pyro = EntrancePyro.new()
				_pyro.name = "EntrancePyro"
				add_child(_pyro)
			_pyro.fire(what.trim_prefix("pyro_"))
			_pyro_wide(what.trim_prefix("pyro_"))
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


## The surface under `p` on the way into the ring: the ringside mat, each
## tread of the diagonal steps, the platform, the apron and the canvas. What
## a planted boot stands on (entry_contact.gd measured against the same).
static func entry_surface_y(p: Vector3) -> float:
	var edge := maxf(absf(p.x), absf(p.z))
	if absf(p.x) <= RingBuilder.APRON_OUT and absf(p.z) <= RingBuilder.APRON_OUT:
		return 0.0 if edge < 3.0 else RingBuilder.APRON_TOP
	var floor_y := ArenaBuilder.FLOOR_Y + ArenaBuilder.RINGSIDE_MAT_LIFT
	var corner := ENTRY_CORNER
	var apron_corner := Vector3(corner.x * RingBuilder.APRON_OUT, 0.0, corner.y * RingBuilder.APRON_OUT)
	var out := RingBuilder.step_out_dir(corner)
	var across := Vector3(-corner.y, 0.0, corner.x).normalized()
	var d := p - apron_corner
	var o := d.dot(out)
	var a := d.dot(across)
	var apex := RingBuilder.STEP_APRON_GAP * sqrt(2.0)
	if absf(a) > RingBuilder.STEP_WIDTH * 0.5 or o < -absf(a) + apex:
		return floor_y
	var top_front := apex + RingBuilder.STEP_PLATFORM
	var treads := RingBuilder.STEP_TREADS
	var rise := (RingBuilder.STEP_TOP_Y - RingBuilder.STEP_FLOOR_Y) / treads
	for i in range(treads - 1, -1, -1):
		var front := top_front + RingBuilder.STEP_RUN * (treads - 1 - i)
		if o <= front:
			return RingBuilder.STEP_FLOOR_Y + rise * (i + 1)
	return floor_y


## Each man's root lifted or lowered so his lower boot is on what it stands
## on, through the entry clips (the owner, 2 Nov: Roman "floats" on the way
## in). The clips are keyed for the base rig; a rig with a longer leg or a
## wider stance -- Roman's, Kenny's -- left both boots 3-7 cm over the apron
## and one 9 cm into it on the turn (entry_contact). Measured off the pose
## each tick with the last correction taken out, eased, clamped; it eases
## back to nothing on the beats that follow.
const PLANT_ANKLE := 0.104
const PLANT_MAX := 0.15
const PLANT_EASE := 0.25
var _plant := {}


func _plant_offset(w: WrestlerController, planting: bool) -> float:
	var was: float = _plant.get(w, 0.0)
	var want := 0.0
	if planting:
		# The boot he stands on: the one nearer its own surface. Not simply
		# the lower one -- squaring up on the 0.2 m apron a wide stance puts
		# the front boot over the canvas line, 0.10 m higher, and planting
		# that one lifted the other off the apron.
		var errs: Array[float] = []
		for bone: String in ["foot_l", "foot_r"]:
			var fp := w._bone_world(bone)
			if fp != Vector3.INF:
				errs.append(fp.y - PLANT_ANKLE - entry_surface_y(fp) - was)
		if errs.is_empty():
			want = was
		else:
			var stand: float = errs[0]
			for e: float in errs:
				if absf(e) < absf(stand):
					stand = e
			want = clampf(-stand, -PLANT_MAX, PLANT_MAX)
	var now := lerpf(was, want, PLANT_EASE)
	if absf(now) < 0.0005 and not planting:
		now = 0.0
	_plant[w] = now
	return now


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
	var edge := maxf(absf(at.x), absf(at.z))
	if edge > RingBuilder.APRON_OUT:
		p.y = surface_y(at)
	elif edge > RingBuilder.APRON_OUT - 0.35:
		p.y = RingBuilder.APRON_TOP
	else:
		p.y = 0.0
	w.global_position = p + Vector3.UP * _plant_offset(w, false)
	var flat := Vector3(heading.x, 0.0, heading.z)
	if flat.length() < 0.001:
		if snap:
			MatchSmoothing.snap(w)
		return
	var want := atan2(-flat.x, -flat.z)
	if snap:
		w.rotation.y = want
		MatchSmoothing.snap(w)
	else:
		w.rotation.y = rotate_toward(w.rotation.y, want, TURN_RATE * delta)


static func _facing_basis(dir: Vector3) -> Basis:
	return Basis(Vector3.UP, atan2(-dir.x, -dir.z))


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# ---------------------------------------------------------------------------
# Camera and lights
# ---------------------------------------------------------------------------

## The owner, 19 Oct: whenever pyro goes off, the camera goes wide enough to
## take all of it in -- the barrage over the set and the seats, or the shells
## over the ring -- and holds there while it bursts, then cuts back to the
## beat's own shot. Seconds per cue: the barrage's waves and the last burst's
## fade (EntrancePyro.VOLLEYS, WHOA_VOLLEYS).
const PYRO_WIDE_SECONDS := {"opening": 4.5, "stage": 4.5, "roman": 5.0, "cody_hit": 6.5,
		"cody_punch": 4.5, "over_ring": 4.0}
## Over the set: from the stage side of the ring rig (2 Nov: from over the
## ropes it looked up through the rig's lines), down the ramp, the
## deck at the bottom of frame and the bursts 20 m up at the top.
const PYRO_SET_WIDE_AT := Vector3(0.0, 4.5, -12.0)
const PYRO_SET_WIDE_LOOK := Vector3(0.0, 9.0, -31.0)
const PYRO_SET_WIDE_FOV := 64.0
## Over the ring: from the hard-camera side, high, the four corners' shells in.
const PYRO_RING_WIDE_AT := Vector3(0.0, 5.0, 13.0)
const PYRO_RING_WIDE_LOOK := Vector3(0.0, 0.0, 0.0)
const PYRO_RING_WIDE_FOV := 56.0
var _pyro_wide_ticks := 0
var _pyro_wide_ring := false
var _pyro_wide_cut := false


func _pyro_wide(cue: String) -> void:
	var ring := cue == "over_ring"
	_pyro_wide_cut = _pyro_wide_ticks <= 0 or ring != _pyro_wide_ring
	_pyro_wide_ring = ring
	_pyro_wide_ticks = maxi(_pyro_wide_ticks if not _pyro_wide_cut else 0,
			int(float(PYRO_WIDE_SECONDS.get(cue, 4.5)) * TPS))


## Whether the pyro wide holds the camera now (tests, probes).
func pyro_wide_on() -> bool:
	return _pyro_wide_ticks > 0


## The beat's shot -- or, while pyro is going off, the pyro wide.
func _frame(beat: Dictionary, delta: float, force_cut := false) -> void:
	_ring_key_on = false
	if _pyro_wide_ticks <= 0 or not _camera:
		_frame_shot(beat, delta, force_cut)
		return
	if delta > 0.0:
		_pyro_wide_ticks -= 1
	if _pyro_wide_ticks <= 0:
		_frame_shot(beat, delta, true)   # back to his shot on a cut
		return
	if _pyro_wide_ring:
		_camera.set_entrance_shot(PYRO_RING_WIDE_AT, PYRO_RING_WIDE_LOOK, PYRO_RING_WIDE_FOV,
				_pyro_wide_cut, delta)
	else:
		_camera.set_entrance_shot(PYRO_SET_WIDE_AT, PYRO_SET_WIDE_LOOK, PYRO_SET_WIDE_FOV,
				_pyro_wide_cut, delta)
	_pyro_wide_cut = false


func _frame_shot(beat: Dictionary, delta: float, force_cut := false) -> void:
	if not _camera:
		return
	if beat.get("shot", "") == "rope_wide":
		# The wide is a cut away inside the ring arrival, not the end of it:
		# the crane's clock runs on under it, and it cuts back in where it
		# would have been rather than booming down again from the top.
		if _entry_crane_ticks >= 0:
			if delta > 0.0:
				_entry_crane_ticks += 1
			_entry_crane_cut_back = true
	elif beat.get("shot", "") != "entry_crane":
		_entry_crane_ticks = -1
	var w: WrestlerController = beat.get("who")
	var first := force_cut or _tick == 1
	match beat.get("shot", beat["kind"]):
		"opening":
			_opening_elapsed += delta
			var opening := opening_shot_at(_opening_elapsed)
			var new_shot := int(opening[0]) != _opening_shot_index
			_opening_shot_index = int(opening[0])
			if new_shot and _lights:
				# The house roars on the cut to it, and the deck movers go wide
				# over the crowd while the camera is on it.
				var on_crowd := _opening_shot_index in [OPENING_SIGN_SHOT_INDEX,
						OPENING_SIGN_ALT_SHOT_INDEX]
				if _lights.has_method("crowd_sweep"):
					_lights.crowd_sweep(on_crowd)
				if on_crowd and _crowd:
					_crowd.pop(1.0)
				# The house comes up for the crowd (AEW's crowd shots are lit
				# faces) and goes back down to the show for the stage master.
				if on_crowd and _opening_shot_index == OPENING_SIGN_SHOT_INDEX:
					cue.emit("opening_house_up")
				elif _opening_shot_index == OPENING_SHOTS.size() - 1:
					cue.emit("show_dark")
			if int(opening[0]) in [OPENING_SIGN_SHOT_INDEX, OPENING_SIGN_ALT_SHOT_INDEX]:
				_opening_sign_shot(first or new_shot, delta,
						int(opening[0]) == OPENING_SIGN_ALT_SHOT_INDEX)
			else:
				_camera.set_entrance_shot(opening[1], opening[2], opening[3],
						first or new_shot, delta)
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
			# Roman's is held on one lens (R-41: a static head-on long lens).
			var lens_p: float = beat.get("lens", lerpf(PORTAL_LONG_FOV.x, PORTAL_LONG_FOV.y, e))
			_camera.set_entrance_shot(Vector3(portal.x * 0.55, 1.6, -21.0),
					portal + Vector3.UP * 1.5, lens_p, true, delta, true,
					not beat.has("lens"))
		"steadicam":
			var fwd3 := -w.global_transform.basis.z
			_camera.set_entrance_shot(w.global_position + fwd3 * 3.2 + Vector3.UP * 1.55,
					w.global_position + Vector3.UP * 1.5, STEADICAM_FOV, first, delta)
		"corner_low":
			# The owner, 9 Nov: "The camera angle behind the wrestlers during
			# the entrances, get rid of it as it looks bad." This was inside
			# the ring behind him as he faced out from the turnbuckles. Now
			# outside the corner, low on the floor in front of him and a
			# little to the side, up at him on the ropes with the building
			# behind him (as PostMatch frames the winner's corner).
			var at_c := corner_front_shot()
			_camera.set_entrance_shot(at_c, _head_of(w) + Vector3.DOWN * 0.1, CORNER_FRONT_FOV,
					first and not _was_shot("corner_low"), delta)
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
					lerpf(PUSH_FOV.x, PUSH_FOV.y, e), true, delta, true,
					not beat.get("locked", false))
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
		"entry_crane":
			# One move across beats: its clock runs while the shot does, and it
			# cuts in only when it starts.
			if _entry_crane_ticks < 0:
				_entry_crane_ticks = 0
			elif delta > 0.0:
				_entry_crane_ticks += 1
			var e_r := smoothstep(0.0, 1.0, float(_entry_crane_ticks) / float(ENTRY_CRANE_TICKS))
			var rc := entry_crane_shot(w.global_position, _camera.hard_cam_position, e_r)
			_camera.set_entrance_shot(rc[0], rig_clear_look(rc[0], rc[1], rc[2]), rc[2],
					_entry_crane_ticks == 0 or _entry_crane_cut_back, delta)
			_entry_crane_cut_back = false
		"crane_front":
			var fc := _flat(-w.global_transform.basis.z).normalized()
			var e_c := smoothstep(0.0, 1.0, float(_tick) / maxf(float(beat["ticks"]), 1.0))
			var crane := crane_front_shot(w.global_position, fc, e_c,
					beat.get("crane_height", CRANE_FRONT_HEIGHT), beat.get("crane_fov", CRANE_FRONT_FOV))
			_camera.set_entrance_shot(crane[0], crane[1], crane[2], first, delta)
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
			_camera.set_entrance_shot(ARENA_HIGH_AT, rig_clear_look(ARENA_HIGH_AT, ARENA_DARK_LOOK,
					ARENA_HIGH_FOV), ARENA_HIGH_FOV, true)
		"steadicam_low":
			# Backing ahead of him, lens at his hips, tilted up past his chest.
			var f4 := _flat(-w.global_transform.basis.z).normalized()
			_camera.set_entrance_shot(w.global_position + f4 * STEADICAM_LOW_AHEAD
					+ Vector3.UP * STEADICAM_LOW_HEIGHT,
					w.global_position + Vector3.UP * 1.55, STEADICAM_LOW_FOV, first, delta)
		"arena_high":
			_camera.set_entrance_shot(ARENA_HIGH_AT, rig_clear_look(ARENA_HIGH_AT,
					w.global_position + Vector3.UP * 1.0, ARENA_HIGH_FOV), ARENA_HIGH_FOV, true)
		"over_shoulder":
			var f5 := _flat(-w.global_transform.basis.z).normalized()
			var r5 := w.global_transform.basis.x
			# Tipped under the ring rig: from the ramp, level, the grid was
			# across the top of the walk's wide (2 Nov, tmp rig probe).
			var at5 := w.global_position - f5 * 1.8 + r5 * 0.45 + Vector3.UP * 1.8
			_camera.set_entrance_shot(at5, rig_clear_look(at5,
					w.global_position + f5 * 12.0 + Vector3.UP * 0.8, OVER_SHOULDER_FOV),
					OVER_SHOULDER_FOV, first, delta)
		"ramp_low_wide":
			_camera.set_entrance_shot(RAMP_LOW_WIDE_AT, w.global_position
					+ Vector3.UP * (2.0 if beat.get("locked", false) else 2.2),
					RAMP_LOW_WIDE_FOV, true, delta, true, not beat.get("locked", false))
		"ramp_long":
			_camera.set_entrance_shot(Vector3(w.global_position.x * 0.5, 0.9,
					w.global_position.z + RAMP_LONG_BACK), w.global_position + Vector3.UP * 1.0,
					RAMP_LONG_FOV, true)
		"rope_wide":
			var into_r := Vector3(0.0, 0.0, -ENTRY_CORNER.y)
			_camera.set_entrance_shot(ROPE_WIDE_AT, w.global_position + into_r * ROPE_WIDE_LEAD
					+ Vector3.UP * 1.0, ROPE_WIDE_FOV, first, delta)
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
		"low_lead":
			var sl := low_lead_shot(w.global_position, _flat(-w.global_transform.basis.z).normalized())
			_camera.set_entrance_shot(sl[0], sl[1], sl[2], first, delta)
		"low_wide_up":
			var sw := low_wide_up_shot(w.global_position,
					_flat(-w.global_transform.basis.z).normalized())
			_camera.set_entrance_shot(sw[0], sw[1], sw[2], first, delta)
		"barricade_low":
			var sb := barricade_low_shot(w.global_position,
					_flat(-w.global_transform.basis.z).normalized())
			_camera.set_entrance_shot(sb[0], sb[1], sb[2], first, delta)
		"face_up":
			var sf := face_up_shot(w.global_position, _head_of(w),
					_flat(-w.global_transform.basis.z).normalized())
			_camera.set_entrance_shot(sf[0], sf[1], sf[2], first, delta, true, false)
		"ring_low_up":
			var su := ring_low_up_shot(w.global_position,
					_flat(-w.global_transform.basis.z).normalized())
			_camera.set_entrance_shot(su[0], su[1], su[2], first, delta, true, false)
		"ring_hero_low":
			var e_rh := smoothstep(0.0, 1.0, float(_tick + int(beat.get("arc_from", 0)))
					/ maxf(float(beat.get("arc_over", beat["ticks"])), 1.0))
			var sh := ring_hero_shot(w.global_position,
					_flat(-w.global_transform.basis.z).normalized(), e_rh)
			_camera.set_entrance_shot(sh[0], sh[1], sh[2],
					first and not _was_shot("ring_hero_low"), delta)
		"ring_high_corner":
			_camera.set_entrance_shot(RING_HIGH_CORNER_AT, w.global_position + Vector3.UP * 1.0,
					RING_HIGH_CORNER_FOV, true)
		"lip_hero":
			# On the lip: low, three-quarter from his left, looking up at him
			# with his wall behind -- a slow arc in (2K26's hero grammar).
			# One arc across beats when the beat says so (Roman's lip and finger).
			var e_h := smoothstep(0.0, 1.0, float(_tick + int(beat.get("arc_from", 0)))
					/ maxf(float(beat.get("arc_over", beat["ticks"])), 1.0))
			var side_h := Vector3(-1.0, 0.0, 0.0).rotated(Vector3.UP, lerpf(0.55, 0.35, e_h))
			_camera.set_entrance_shot(w.global_position + side_h * lerpf(3.4, 2.8, e_h)
					+ Vector3.UP * 0.75, w.global_position + Vector3.UP * 1.55, 34.0,
					first and not _was_shot("lip_hero"), delta)
		"steps_rear":
			# 2K26 Roman 3:15-3:24: low, behind him and to the side, tracking
			# him round onto the steps and up them, the ring ahead of him.
			var fr := _flat(-w.global_transform.basis.z).normalized()
			var sr := Vector3.UP.cross(fr).normalized()
			if sr.dot(_flat(w.global_position)) < 0.0:
				sr = -sr
			var at_r := w.global_position - fr * STEPS_REAR_BACK + sr * STEPS_REAR_SIDE \
					+ Vector3.UP * STEPS_REAR_HEIGHT
			# never out past the barricade, into the front row
			var lim := ArenaBuilder.BARRICADE_RADIUS - 0.5
			at_r.x = clampf(at_r.x, -lim, lim)
			at_r.z = clampf(at_r.z, -lim, lim)
			_camera.set_entrance_shot(at_r, w.global_position + fr * 2.2 + Vector3.UP * 1.3,
					STEPS_REAR_FOV, first and not _was_shot("steps_rear"), delta)
		"apron_low":
			# 2K26 Roman 3:28-3:32: from inside the ring, low, up at him at the
			# corner -- along the apron and in through the ropes.
			var corner_dir := Vector3(ENTRY_CORNER.x, 0.0, ENTRY_CORNER.y).normalized()
			_camera.set_entrance_shot(corner_dir * APRON_LOW_IN + Vector3.UP * APRON_LOW_HEIGHT,
					_head_of(w) + Vector3.DOWN * 0.25, APRON_LOW_FOV,
					first and not _was_shot("apron_low"), delta)
		"ring_behind_out":
			var f7 := _flat(-w.global_transform.basis.z).normalized()
			var r7 := Vector3.UP.cross(-f7).normalized()
			_camera.set_entrance_shot(w.global_position - f7 * RING_BEHIND_OUT_BACK
					+ r7 * 0.5 + Vector3.UP * 1.2,
					w.global_position + f7 * 10.0 + Vector3.UP * 3.0,
					RING_BEHIND_OUT_FOV, true)
		"end_wide":
			_camera.set_entrance_shot(END_WIDE_AT, END_WIDE_LOOK, END_WIDE_FOV, true)
		"cell_lower":
			var cage_c := CageBuilder.of(_match)
			if cage_c:
				var sh := cell_lower_shot(cage_c, float(_tick) / maxf(float(beat["ticks"]), 1.0))
				_camera.set_entrance_shot(sh[0], sh[1], sh[2], first, delta)
		"staredown_push":
			_staredown_push(first, delta)
		"match_card":
			# A5: high on the hard camera's side, the whole ring, a slow push.
			_camera.set_entrance_shot(INTRO_CARD_AT, INTRO_CARD_LOOK, INTRO_CARD_FOV, first, delta)
		"corner_intro":
			_intro_close(beat, first, delta)
		"ref_check":
			_intro_close(beat, first, delta)
		"faceoff_side":
			# F1, the walk out of the corners to the centre: from the hard
			# camera's side of the ring at eye height, as far back as holds
			# both men in frame (from diagonally opposite corners they start
			# ~5.5 m apart -- square to their line at FACEOFF_CAM_DISTANCE the
			# frame held empty canvas between them), closing in as they come.
			# On a crane (the owner, 2 Nov): high and round to one side as they
			# leave their corners, sweeping down and round to eye level as
			# they close -- where the stare's push picks it up.
			var mid := (_a.global_position + _b.global_position) * 0.5
			var e_c := smoothstep(0.0, 1.0, float(_tick) / maxf(float(beat["ticks"]), 1.0))
			var crane := faceoff_crane(e_c)
			var bearing := _flat(_camera.hard_cam_position - mid).normalized() \
					.rotated(Vector3.UP, deg_to_rad(crane[1]))
			var back := walk_in_distance(_a.global_position, _b.global_position, bearing)
			_camera.set_entrance_shot(mid + bearing * back + Vector3.UP * float(crane[0]),
					mid + Vector3.UP * lerpf(1.0, 1.3, e_c), FACEOFF_WALK_FOV,
					first and not _was_shot("faceoff_side"), delta)
			_key_on_pair()
		"faceoff":
			if _cam_key:
				_cam_key.visible = false
			# The hard camera's own seat and lens, so the bell does not cut.
			_camera.set_entrance_shot(_camera.hard_cam_position,
					(_a.global_position + _b.global_position) * 0.5
					+ Vector3.UP * _camera.hard_cam_aim, _camera.hard_cam_fov,
					not _was_shot("faceoff"), delta)


## The pre-entrance montage: which of ROMAN_INTRO_SHOTS the hold is in, and
## how far through its move, eased (smoothstep) so every move starts and
## settles gently. A new shot is a cut.
# ---------------------------------------------------------------------------
# The stare-down (camera_aaa_plan.md A6, "The face-off")
# ---------------------------------------------------------------------------
#
# It was two held shots -- a profile two-shot, then a long over-the-shoulder
# (the owner's 2K26 reference, 270-306 s). The owner, 2 Nov: "camera slowly
# zooms into their faces for a staredown, bell rings". So it is now one
# continuous push from the profile two-shot into both faces, no cut
# ("staredown_push"). The walk out of the corners is "faceoff_side"; the walk
# to the corners is "faceoff", the hard camera, on which the referee sends
# them there.


## The walk-in crane at eased progress `e`: [height, degrees round from the
## hard camera's bearing]. Up and round at the start, eye level and square
## at the end.
static func faceoff_crane(e: float) -> Array:
	return [lerpf(FACEOFF_CRANE_TOP, FACEOFF_CAM_HEIGHT, e), lerpf(FACEOFF_CRANE_ARC, 0.0, e)]


## The stare-down as the owner asked for it: one slow push from the profile
## two-shot into their faces over the whole hold, no cut.
func _staredown_push(first: bool, delta: float) -> void:
	if _beats[_beat].get("pose_wide", false):
		_faceoff_pose_wide(first, delta)
		return
	var t := clampf(float(_tick) / maxf(float(_beats[_beat]["ticks"]), 1.0), 0.0, 1.0)
	var e := smoothstep(0.0, 1.0, t)
	var heads := (_head_of(_a) + _head_of(_b)) * 0.5
	var mid := (_a.global_position + _b.global_position) * 0.5
	var across := _flat(_b.global_position - _a.global_position).normalized()
	var side := Vector3.UP.cross(across).normalized()
	if side.dot(_camera.hard_cam_position - mid) < 0.0:
		side = -side
	var at := Vector3(mid.x, mid.y, mid.z) + side * lerpf(FACEOFF_CAM_DISTANCE, STAREDOWN_CLOSE, e) \
			+ Vector3.UP * lerpf(FACEOFF_CAM_HEIGHT, heads.y - mid.y - 0.03, e)
	_camera.set_entrance_shot(at, heads + Vector3.DOWN * lerpf(0.1, 0.02, e),
			lerpf(FACEOFF_CAM_FOV, STAREDOWN_FOV, e), first, delta)
	_key_on_pair()


## Their face-off poses (faceoff_pose_clip): the stare's side, back far
## enough for arms over their heads; the stare's push starts from here.
func _faceoff_pose_wide(first: bool, delta: float) -> void:
	var mid := (_a.global_position + _b.global_position) * 0.5
	var across := _flat(_b.global_position - _a.global_position).normalized()
	var side := Vector3.UP.cross(across).normalized()
	if side.dot(_camera.hard_cam_position - mid) < 0.0:
		side = -side
	_camera.set_entrance_shot(mid + side * FACEOFF_POSE_CAM_DISTANCE + Vector3.UP * 1.35,
			mid + Vector3.UP * 1.45, FACEOFF_POSE_CAM_FOV, first, delta)
	_key_on_pair()


## The camera key (_cam_key) on both men at once, aimed between their chests:
## the walk-in and the stare are in profile under the truss, and without it
## both faces rendered black against the lit crowd.
func _key_on_pair() -> void:
	if _cam_key == null:
		return
	_aim_cam_key(_a, true)
	if _cam_key.visible:
		var chests := (_a.global_position + _b.global_position) * 0.5 + Vector3.UP * 1.45
		_cam_key.spot_range = _cam_key.global_position.distance_to(chests) + 4.0
		_cam_key.spot_angle = clampf(rad_to_deg(atan2(
				_flat(_a.global_position - _b.global_position).length() * 0.5 + 0.9,
				_cam_key.global_position.distance_to(chests))), 4.0, 50.0)
		_cam_key.look_at(chests, Vector3.UP)


## How far back along `bearing` (flat, from their midpoint) the walk-in
## camera stands to hold both men, FACEOFF_WALK_MARGIN in from the frame's
## sides: never nearer than FACEOFF_CAM_DISTANCE.
static func walk_in_distance(a: Vector3, b: Vector3, bearing: Vector3) -> float:
	var mid := (a + b) * 0.5
	var half := atan(tan(deg_to_rad(FACEOFF_WALK_FOV) * 0.5) * FRAME_ASPECT) - FACEOFF_WALK_MARGIN
	var d := FACEOFF_CAM_DISTANCE
	while d < FACEOFF_WALK_MAX:
		var cam := mid + bearing * d
		var fits := true
		for p: Vector3 in [a, b]:
			var v := Vector3(p.x - cam.x, 0.0, p.z - cam.z).normalized()
			if v.angle_to(-bearing) > half:
				fits = false
		if fits:
			return d
		d += 0.1
	return FACEOFF_WALK_MAX


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


## Broadcast-style timed cuts while the announcers open the show. The final
## stage shot holds until the first wrestler's entrance takes over.
static func opening_shot_at(seconds: float) -> Array:
	var selected := 0
	for i in OPENING_SHOTS.size():
		if seconds < float(OPENING_SHOTS[i][0]):
			break
		selected = i
	var shot: Array = OPENING_SHOTS[selected]
	if selected == 0:
		var sweep_length: float = float(OPENING_SHOTS[1][0]) - float(shot[0])
		var sweep := smoothstep(0.0, 1.0, clampf(seconds / sweep_length, 0.0, 1.0))
		return [selected, OPENING_AT.lerp(OPENING_CRANE_TO, sweep),
				OPENING_LOOK.lerp(OPENING_CRANE_LOOK_TO, sweep), shot[3]]
	return [selected, shot[1], shot[2], shot[3]]


## Close on the Enda-sign fan during the opening cutaway. His chair faces the
## ring (local +Z), so the camera sits on the face side and keeps the crowd
## behind him in frame.
func _opening_sign_shot(snap: bool, delta: float, alternate: bool) -> void:
	var at := Vector3(4.8, 2.0, -3.8)
	var focus := Vector3(8.05, 1.7, -3.6)
	var signs := get_tree().get_first_node_in_group("sign_fans") as SignFans
	var fan := signs.enda_easter_egg_fan() if signs else null
	var lens := 39.0
	if fan and is_instance_valid(fan):
		focus = fan.global_position + Vector3.UP * 1.72
		var front := fan.global_transform.basis.z
		front.y = 0.0
		if front.length() > 0.01:
			at = focus + front.normalized() * (3.5 if not alternate else 3.2) \
					+ Vector3.UP * 0.15
			if alternate:
				var across := fan.global_transform.basis.x
				across.y = 0.0
				at += across.normalized() * 1.25
		lens = 36.0 if alternate else 39.0
	_camera.set_entrance_shot(at, focus, lens, snap, delta)


func _camera_intro(pick: Array) -> void:
	var shot: Array = ROMAN_INTRO_SHOTS[pick[0]]
	var t: float = pick[1]
	var e := t * t * (3.0 - 2.0 * t)
	_camera.set_entrance_shot((shot[0] as Vector3).lerp(shot[1], e),
			(shot[2] as Vector3).lerp(shot[3], e), lerpf(shot[4], shot[5], e), true)


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
	var e := smoothstep(0.0, 1.0, float(_tick) / float(beat["ticks"]))
	if beat["shot"] == "corner_intro":
		var shot := intro_crane(head, to_c, side, e)
		_camera.set_entrance_shot(shot[0], shot[1], INTRO_CLOSE_FOV, first, delta)
		_aim_cam_key(man, true)
	else:
		var shot := ref_check_shot(man.global_position, check_spot(man.global_position), side)
		_camera.set_entrance_shot(shot[0], shot[1], REF_CHECK_FOV, first, delta)
		_aim_cam_key(man, true)


## The corner close-up as a jib (the owner, 2 Nov: "smooth crane shots ...
## during wrestlers intros"): from low in front of him, a little to the hard
## camera's side, the arm rises past his chest to just over his eyes as it
## pushes in -- the canvas and the corner at the start, his face at the end.
## [camera, look] at eased progress `e`.
static func intro_crane(head: Vector3, to_c: Vector3, side: Vector3, e: float) -> Array:
	var chest := head + Vector3.DOWN * 0.38
	var dist := lerpf(INTRO_CRANE_FROM, INTRO_CLOSE_DISTANCE - INTRO_CLOSE_PUSH, e)
	var rise := lerpf(INTRO_CRANE_LOW, INTRO_CRANE_HIGH, e)
	var at := chest + to_c * dist + side * lerpf(0.9, 0.55, e) + Vector3.UP * rise
	return [at, chest.lerp(head + Vector3.DOWN * 0.08, e)]


## The referee's check (the owner, 2 Nov: the camera "cuts to them ... it
## actually fits to Aubrey"). It looked at him from 2.9 m in front of his
## corner, and she stands 1 m in front of him checking him -- on that line of
## sight, filling the frame. Now a three-quarter two-shot from inside the
## ring, off to the side (straight to the side is out past the ropes): him in
## his corner, her facing him, about 20 degrees apart in frame. [camera, look].
static func ref_check_shot(man: Vector3, ref_at: Vector3, side: Vector3) -> Array:
	var flat_man := Vector3(man.x, 0.0, man.z)
	var mid := (flat_man + Vector3(ref_at.x, 0.0, ref_at.z)) * 0.5
	var to_c := -flat_man.normalized() if flat_man.length() > 0.1 else Vector3.FORWARD
	return [mid + side * REF_CHECK_SIDE + to_c * REF_CHECK_IN + Vector3.UP * 1.45,
			mid + Vector3.UP * 1.3]


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
		ambient: float = ROMAN_AMBIENT_DIM, house_floor := 0.0,
		house_tint := Color.WHITE) -> void:
	if on == not _dimmed.is_empty():
		return
	if _lights and "house_dim" in _lights:
		_lights.house_dim = rig if on else 1.0
	if on:
		if _lights:
			for child in _lights.get_children():
				if child is Light3D and not String(child.name).begins_with("Accent"):
					_dimmed[child] = (child as Light3D).light_energy
					var share := rig
					if house_floor > rig and String(child.name).begins_with("AudienceWash"):
						# the house held dark and tinted, not black
						share = house_floor
						_tinted[child] = (child as Light3D).light_color
						(child as Light3D).light_color = house_tint
					(child as Light3D).light_energy *= share
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
	for key in _tinted:
		if is_instance_valid(key):
			(key as Light3D).light_color = _tinted[key]
	_tinted.clear()
	if _crowd_light_was != null:
		RenderingServer.global_shader_parameter_set("crowd_light", _crowd_light_was)
		_crowd_light_was = null


var _top: SpotLight3D


## Item 12: the top light on `w` posing in the ring; null puts it out.
## A spot is brought up, not switched: the top light irises in and out over
## POSE_TOP_IRIS seconds instead of appearing in a frame, which read as a
## lighting glitch whenever the cue did not land on a cut.
const POSE_TOP_IRIS := 0.3
var _top_iris: Tween


func _pose_top(w: WrestlerController) -> void:
	if w == null:
		if _top and _top.visible:
			_iris_top(0.0)
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
	if not _top.visible:
		_top.light_energy = 0.0
		_top.visible = true
	_iris_top(POSE_TOP_ENERGY)
	_pose_dim(true)
	# The old beam was vertical and only 13 degrees wide. It lit the crown of
	# his head while his face and raised hand fell outside the cone. Bias it
	# toward his front and aim at the upper chest; the wider, softer pool still
	# reads as a top light but catches the face and finger pose together.
	var forward := _flat(-w.global_transform.basis.z).normalized()
	var at := w.global_position + Vector3.UP * POSE_TOP_UP + forward * 1.2
	_top.global_position = at
	_top.look_at(w.global_position + forward * 0.25 + Vector3.UP * 2.3, Vector3.UP)


func _iris_top(energy: float) -> void:
	if _top_iris and _top_iris.is_valid():
		if is_equal_approx(_top.light_energy, energy):
			return
		_top_iris.kill()
	_top_iris = create_tween()
	_top_iris.tween_property(_top, "light_energy", energy, POSE_TOP_IRIS) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if energy <= 0.0:
		_top_iris.tween_callback(func() -> void: _top.visible = false)


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


## Inside the barricade: ringside, the steps, the apron or the ring. There the
## ring's own rig lights him; the stage's follow spot at full and the tron's
## rim from 20 m behind burned his white coat into a glowing silhouette up
## the steps -- the "ghost" the owner saw go in through the ropes.
static func _at_ring(w: WrestlerController) -> bool:
	var p := w.global_position
	return maxf(absf(p.x), absf(p.z)) < ArenaBuilder.BARRICADE_RADIUS


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
		# Not the camera key when this frame's shot has it on the men in the
		# ring (the corner intros, the walk out, the stare): with nobody
		# walking this branch ran after every such shot and switched it off,
		# and they stood as silhouettes (the owner, 2 Nov).
		if _cam_key and not _ring_key_on:
			_cam_key.visible = false
		for wash: SpotLight3D in _ramp_wash:
			wash.visible = false
		return
	_follow.visible = true
	var gain: float = WALK_LIGHT_GAIN.get(w.entrance_style, 1.0)
	# In the ring the long-throw spot is a glare in the haze and burns his
	# gear white on the low shots (lighting_2k26.md item 10): a third of it.
	_follow.light_energy = FOLLOW_SPOT_ENERGY * (0.35 if _at_ring(w) else 1.0) * gain
	var target := w.global_position + Vector3.UP * 1.1
	if _follow.global_position.distance_to(target) > 0.1:
		_follow.look_at(target, Vector3.UP)
	if _walk_key:
		_walk_key.visible = true
		_walk_key.light_energy = WALK_KEY_ENERGY * gain
		var fwd := _flat(-w.global_transform.basis.z).normalized()
		var right := Vector3.UP.cross(-fwd).normalized()
		_walk_key.global_position = walk_key_at(w.global_position, fwd, right)
		_walk_key.look_at(w.global_position + Vector3.UP * 1.3, Vector3.UP)
		if _walk_back:
			_walk_back.visible = true
			_walk_back.global_position = walk_back_at(w.global_position, fwd, right)
			_walk_back.look_at(w.global_position + Vector3.UP * 1.4, Vector3.UP)
	_aim_cam_key(w)
	_aim_ramp_wash(w)


## The camera key: beside and above the lens, on his chest; off in the ring,
## where the rig lights him.
func _aim_cam_key(w: WrestlerController, in_ring := false) -> void:
	if _cam_key == null or _camera == null:
		return
	if _in_ring(w) and not in_ring:
		_cam_key.visible = false
		return
	# In the ring the lens is three metres off, not ten: half the light.
	_cam_key.light_energy = CAM_KEY_ENERGY * (CAM_KEY_RING_GAIN if in_ring else 1.0) \
			* float(WALK_LIGHT_GAIN.get(w.entrance_style, 1.0))
	var chest := w.global_position + Vector3.UP * 1.3
	var cam := _camera.global_position
	var to := (chest - cam)
	if to.length() < 0.5:
		_cam_key.visible = false
		return
	var right := to.normalized().cross(Vector3.UP).normalized()
	_cam_key.global_position = cam + Vector3.UP * CAM_KEY_UP + right * CAM_KEY_SIDE
	_cam_key.spot_range = to.length() + 4.0
	# A cone a little wider than his body at that distance.
	_cam_key.spot_angle = clampf(rad_to_deg(atan2(1.4, to.length())), 4.0, 40.0)
	_cam_key.visible = true
	_ring_key_on = in_ring
	_cam_key.look_at(chest, Vector3.UP)


## The ramp wash: on while he is on the ramp or the stage front, aimed down
## the aisle a few metres ahead of him.
func _aim_ramp_wash(w: WrestlerController) -> void:
	var on := w.global_position.z < CUT_TO_Z + 2.0 and not _in_ring(w)
	for wash: SpotLight3D in _ramp_wash:
		wash.visible = on
		if on:
			var side: float = wash.get_meta("side")
			var aim := Vector3(0.0, 0.0, w.global_position.z + 3.0)
			wash.global_position = Vector3(side * RAMP_WASH_SIDE, RAMP_WASH_UP, aim.z - 4.0)
			wash.look_at(aim, Vector3.UP)


## Item 11: the wall's coloured light on him, from between him and the wall.
## Out while the wall is on the loop, while he is in the ring (the wall is
## 35 m off) and while Cody's own backlight has the dark.
func _aim_tron_rim(w: WrestlerController) -> void:
	var on := _tron_on and w != null and w.visible and not _at_ring(w) \
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
		# The rig's own figure, not the energy found on the light: the match
		# look parks the stage beams at zero (ArenaLighting.set_look).
		var rig := _lights as ArenaLighting
		var base: float = rig.accent_energy * rig.renderer_gain(light) if rig \
				else float(light.get_meta("base_energy"))
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
