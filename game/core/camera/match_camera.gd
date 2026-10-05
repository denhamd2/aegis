class_name MatchCamera
extends Camera3D
## Ringside rig that keeps both wrestlers in frame, plus scripted cuts for
## finishers and the three-count.
##
## The framing is solved from a measurement rather than tuned by hand.
## gauntlet/refs/camera.md now carries subject-fill numbers taken off the
## reference stills with tools/refs/measure_frame.py: a standing wrestler
## occupies 0.675-0.708 of frame height in the strike-exchange framing and
## 0.32-0.41 in the wide standoff. "Fill this fraction of the frame" is a
## quantity a camera can be solved for, so the response to separation is
## fitted through both measured framings (see FIT_SLOPE) instead of scaling
## separation by a multiplier nobody measured.
##
## What this replaced: `distance = clamp(separation * 1.6, 4.0, 9.0)`. At
## tie-up range (1.4m) that is 2.24m, which clamps to the 4.0m floor -- so
## the camera sat at its minimum distance through every grapple in the
## match and a wrestler filled 0.29 of the frame. Measured against the
## reference that is *wider than its widest shot* at the closest moment of
## the fight: the old rig never once framed the action as tightly as the
## reference's standoff, let alone its strike exchange.
##
## Read-only over gameplay state. It polls the referee and the grapple rig
## and never writes to either, so it cannot affect the deterministic tick
## (ARCHITECTURE.md).

## A standing wrestler's height, matching wrestler.tscn's capsule. The fill
## targets below are fractions of the viewport this subtends.
const SUBJECT_HEIGHT := 1.8

## Measured off gauntlet/refs/frames/mid_strike_exchange.jpg: the two
## wrestlers stand 0.675 and 0.708 of the frame's height.
const FILL_ENGAGED := 0.69
## And off wide_standoff_broadcast_angle.jpg: 0.32 and 0.41.
const FILL_STANDOFF := 0.365

## The camera's response to separation, fitted through both measured
## framings: distance = FIT_INTERCEPT + FIT_SLOPE * separation.
##
## Running the projection backwards from each reference frame -- fill and
## the 41-degree lens give a distance, and that distance plus the pair's
## on-screen span gives a separation -- puts the strike exchange at
## (0.74m apart, 3.49m out) and the wide standoff at (2.58m, 6.73m). Two
## points, two parameters: the line through them reproduces both reference
## framings by construction and leaves nothing to choose.
##
## Be clear about what this is worth. The separations are *derived*, not
## measured: they depend on the fill measurement and on the FOV, which
## camera.md itself derives rather than measures. This is inference layered
## on inference. It is defended as reproducing two measured frames, not as
## a measurement of how a real camera tracks -- a frame-stepped clip could
## measure separation directly and should replace it.
##
## What it replaced was worse: `separation * 1.6` clamped to a 4.0m floor,
## which at tie-up range pinned the camera to the floor for every grapple
## in the match and framed a wrestler at 0.29 of the screen.
const FIT_INTERCEPT := 2.19
const FIT_SLOPE := 1.76

## Containment guard -- an engineering limit, NOT a framing claim.
##
## The fit says where the shot should be. This says only that a wrestler
## must not leave the frame, which the fit alone cannot promise once
## max_distance clamps it: corner to corner in this 6m ring is 8.49m, where
## the fit wants 17.1m. No reference measurement backs this number; it is
## the point at which a body reaches the edge of frame, and it is kept
## separate from the fit precisely so the two are not confused.
const CONTAINMENT_WIDTH := 0.9

## Shoulder-to-shoulder allowance either side of the pair's midpoints, so
## containment frames two bodies rather than two points.
const BODY_WIDTH := 0.8

@export var wrestler_a_path: NodePath
@export var wrestler_b_path: NodePath
@export var grapple_rig_path: NodePath
@export var referee_path: NodePath
## Never closer than this, whatever the fill solve asks for. camera.md:
## the standoff camera sits "just outside the near ropes", and this ring's
## ropes are at 3.1m from centre -- so this is the reference's own statement
## about where the camera is, in this ring's units.
@export var min_distance: float = 3.2
@export var max_distance: float = 9.0
## camera.md: the standoff camera "sits roughly at chest-to-head height of
## the wrestlers" -- chest, on a 1.8m subject.
##
## Set by what it puts in frame rather than picked off that range: every
## reference frame carries the *near* ropes across its foreground, and at
## the distance the fill measurement pins, this is the highest the camera
## can sit and still keep more than one of them on screen. Measured by
## unprojecting the near ropes at a range of heights -- at 1.65m only the
## top rope lands inside the frame, at 1.45m the top and middle both do.
## The bottom rope sits 24 degrees below the view axis and cannot be
## recovered without backing off further than the measured fill allows.
##
## The trade is the horizon: this puts the far mat edge at 0.622 of frame
## height where 1.65m put it at 0.599. camera.md measures 0.59 for the
## strike framing and 0.66 for the standoff, so an intermediate shot
## landing between them is where it should be.
@export var height: float = 1.45
## camera.md, on the impact/spot framing: "camera drops lower, closer to mat
## height, for a grounded, low-angle look". Measured as the far mat edge
## sitting at ~0.49 of frame height there against 0.59 in the strike
## framing -- the horizon rises toward centre as the camera drops.
@export var cut_height: float = 0.55
## The three-count is its own shot, and it is the one shot in a match that
## cannot afford the ropes.
##
## cut_height above is 0.55 m, which is BELOW the top rope, so a cover shot
## through it has the near ropes running straight across both bodies. In the
## recorded match the three count is bisected by three rope lines. (I first
## read that as the camera being under the canvas -- it is not; the cover is
## at a sensible height and it is the ropes in front of it that are the
## problem. Checked by rendering the count at ring centre AND at the ropes:
## both are legible except for the lines across them.)
##
## The geometry, for a cover near the ring edge, which is the bad case: the
## pair sit ~0.5 m from the near rope and the camera at min_distance 3.2 m, so
## the rope is 2.7 m of the way to the lens. A sight line from eye height h
## down to a body at 0.3 m clears a 1.3 m rope at that point only when
## h > 1.48 m. 1.90 m takes it comfortably over the top rope and looks DOWN at
## the cover, which is the angle the shot wants anyway.
##
## Geometric, not measured: camera.md carries no pin framing, so this is the
## height that clears a known obstruction rather than a number off a
## reference frame.
@export var three_count_height: float = 1.90
## Aim point for the three-count, in metres above the pair's midpoint. Low,
## because both men are on the mat -- the 0.45 m used by the finisher cut is
## for two men standing.
@export var three_count_aim: float = 0.30
@export var follow_speed: float = 6.0
## A cut snaps harder than the follow-cam drifts. camera.md marks cut
## duration and ease curves as pending real footage, so this is a project
## value: it is not defended as matching anything measured.
@export var cut_speed: float = 14.0

# --- The hard camera ---------------------------------------------------------
## The master shot, and the one thing this rig did not have.
##
## A televised match is not covered by a follow-cam. It is covered by a FIXED
## camera high in the bowl on a long lens, cut away from to ringside handhelds
## and back. Everything below the hard camera in this file is the handheld;
## this is the master it cuts from.
##
## The anchor is not invented -- it is a seat in the building
## `tools/blender/arena_bowl.py` already builds. The lower tier's first row is
## BOWL_FIRST_ROW 10.13 out from a plan rectangle of half-extent
## BOWL_STRAIGHT_X 4.425, so on the -X straight side row 1 is 14.56 from ring
## centre; twelve rows of ROW_RUN 0.95 and a CONCOURSE_DEPTH of 2.6 put the
## suite line at 28.56 out, and twelve rises of ROW_RISE 0.48 over a FLOOR_Y
## of -1.10 put it 8.26 up. That is 28.5 / 8.3, and it is where a real hard
## camera stands: at the back of the lower bowl, on the side opposite nothing,
## looking down the ring's own axis.
##
## -X, so the entrance stage on -Z reads frame LEFT and the commentary desk on
## +Z reads frame right -- which is the arrangement
## `gauntlet/refs/lighting/aew_grand_slam_broadcast.png` shows.
@export var hard_cam_position := Vector3(-28.5, 8.3, 0.0)
## 14 degrees vertical, which is a ~98mm lens on a full-frame back.
##
## This is the whole point of separating lens from distance. The handheld's
## 41 degrees is a 32mm lens, and a 32mm lens CANNOT be a master shot from the
## stands -- at 29m it frames the whole bowl. Holding a 1.8m wrestler at the
## same fraction of frame from 29m instead of 3.5m takes a long lens, and the
## compression that comes with it (a flat wall of crowd stacked behind the
## ring) is the single most recognisable property of a broadcast master.
##
## camera.md derives the handheld's 41 degrees from fill plus "just outside
## the near ropes". That premise is about the handheld and says nothing about
## this shot, so this number is NOT inherited from it: it is solved from the
## measured AEW hard-cam fill at this anchor's distance. See camera.md's
## "AEW broadcast framing" section.
@export var hard_cam_fov: float = 14.0
## Aim height above the pair's midpoint. Low, because the camera is looking
## DOWN: aiming at chest from 8.3m up tips the mat out of frame.
@export var hard_cam_aim: float = 0.9

# --- Per-shot lens -----------------------------------------------------------
## The handheld's lens, which is the 41 degrees camera.md solves. It used to
## live in match.tscn as the camera's one `fov`, which is exactly why there
## could only ever be one shot: the lens was a property of the CAMERA rather
## than of the shot it was taking.
@export var ringside_fov: float = 41.0
## Where the handheld stands, as a direction from the ring's centre in the XZ
## plane. -X and slightly +Z: the same broadcast side as the hard camera, off
## the axis so the shot does not look through a corner post, with the entrance
## stage on -Z reading frame left.
@export var ringside_bearing := Vector3(-0.966, 0.0, 0.258)
## The impact cut goes wider as well as lower -- it is close to the bodies, so
## the lens has to open to keep two of them in frame. Project value; camera.md
## marks cut framing as pending real footage.
@export var cut_fov: float = 52.0
## The three-count is the tightest shot in the match and the only one that is
## about one thing: the shoulders on the mat and the hand coming down.
@export var three_count_fov: float = 34.0

# --- The shot clock ----------------------------------------------------------
## How long each shot holds before the rig cuts to the other one.
##
## A broadcast does not sit on one angle. It cuts, and the RHYTHM of those
## cuts is most of what separates a televised match from a video game's
## follow-cam -- longer on the master, shorter on the handheld, and straight
## back to the master.
##
## These are PROJECT VALUES and are not defended as measured. camera.md has
## marked cut duration as "pending real footage" since it was written, and the
## AEW stills in the repo are stills: a still cannot carry a duration. What is
## defended is the shape -- master longer than handheld, both in the seconds
## rather than the tens of seconds -- which is what a shot clock needs to be
## given at all. A frame-stepped clip could measure these and should.
@export var hard_cam_hold: float = 5.5
@export var ringside_hold: float = 4.5

## HARD_CAM is the master and the default. RINGSIDE is what used to be called
## FOLLOW -- the same rig, the same solve, renamed for what it actually is now
## that there is something else for it to be cut against.
## ENTRANCE is not a shot of the match: EntranceDirector drives the camera
## directly while the wrestlers walk to the ring, through set_entrance_shot(),
## and hands back with resume_master() at the bell.
enum Mode { HARD_CAM, RINGSIDE, FINISHER_CUT, THREE_COUNT_CUT, ENTRANCE, FINISHER_AFTER, EVENT_CUT }

# --- The 2K-style gameplay camera (camera_aaa_plan.md B1) --------------------
## In GAMEPLAY coverage (CameraSettings) the handheld is the dynamic ringside
## camera 2K26 plays on, measured off the owner's 2K26 Cody vs Roman match
## (gauntlet/refs/cody_roman_2k26.md): ONE continuous camera for the whole
## match -- 13 cuts in ~475 s between the bell and the winner, a shot of about
## 37 s on average -- just above the top rope, 6-9 m out, panning and drifting
## with the pair. The only cuts are set pieces (the finisher, the pin, the
## finish and replays); there is no shot clock and no cut on a strike.
##
## It still does not orbit: it stays on the broadcast side of the line between
## the two men (the 180-degree rule the hard camera sets), ignores a turn of
## the pair inside GAMEPLAY_DEADZONE, and when they have turned further it PANS
## round to the new side-on bearing at no more than GAMEPLAY_PAN_RATE -- a
## camera operator walking round the apron, not a cut and not a swing.
const GAMEPLAY_HEIGHT := 1.65
const GAMEPLAY_DEADZONE := 0.6    # 34 degrees: a small turn of the pair does not move it
const GAMEPLAY_SETTLE := 0.08     # once panning, it pans until this close to side-on
const GAMEPLAY_PAN_RATE := 0.35   # rad/s: 20 degrees a second at most
const GAMEPLAY_POST_PAN_RATE := 0.7   # a post in the way: it walks faster
## 2K26 frames the pair at about 0.45 of the frame from just outside the ropes;
## the fit alone would bring it in to 3.5 m at a
## tie-up, which is the tight handheld of BROADCAST coverage, not this camera.
const GAMEPLAY_MIN_DISTANCE := 4.2
## How fast the aim point follows the pair: the lens never snaps to a man.
const GAMEPLAY_LOOK_SPEED := 2.5
## The opening wide (the pre-match card), then the gameplay camera for good.
const GAMEPLAY_OPENING_HOLD := 4.0
## The ropes are at 3.1: the camera stays outside them.
const RING_OUTSIDE := 3.55
const POSTS := [Vector3(3.3, 0, 3.3), Vector3(-3.3, 0, 3.3), Vector3(3.3, 0, -3.3), Vector3(-3.3, 0, -3.3)]
const POST_CLEAR := 0.45

# --- Event cuts (B3), shake (B4), focus (B5), cutaways (B6) ------------------
## Short cuts to the action, each back to the coverage it cut from. None
## lands within MIN_SHOT of the last cut (D1: no shot under 0.8 s), and none
## pre-empts a finisher or a pin, which have their own shots.
enum Cut { STRIKE, SLAM, HERO, FIRE_UP, CUTAWAY }
const MIN_SHOT := 0.8
## A strike worth a cut: the cross, the uppercut, the elbow, the kicks.
const BIG_STRIKE_DAMAGE := 9.0
const CUT_HOLD := {Cut.STRIKE: 0.85, Cut.SLAM: 0.35, Cut.HERO: 1.5, Cut.FIRE_UP: 1.3, Cut.CUTAWAY: 1.6}
## Trauma (0..1, squared into the shake) per kind of impact.
const TRAUMA_STRIKE := 0.3
const TRAUMA_BIG_STRIKE := 0.45
const TRAUMA_SLAM := 0.55
const TRAUMA_KNOCKDOWN := 0.3
## Where the crowd cutaway looks: the ringside rows on +X, where the sign
## fans sit (SignFans.FANS), from the floor at the far apron.
const CUTAWAY_AT := Vector3(4.3, 1.3, -0.6)
const CUTAWAY_LOOK := Vector3(8.6, 1.9, -0.2)
const CUTAWAY_FOV := 40.0

# --- The finisher, shot as a sequence (blender-cameras) -----------------------
## Only a finisher wins a match now (MatchReferee.can_be_finished), so it is
## the one move the camera stops covering and starts DIRECTING. Three shots
## cut on the paired clip's own progress, then a hold on the aftermath:
##
##   setup    0 .. SETUP_END   a tight three-quarter on the attacker's face,
##                             ~85 mm, pushing in, the crowd soft behind him
##   impact   .. IMPACT_END    down on the mat, square to the pair, ~24 mm --
##                             the spectacle lens -- and the shake as he lands
##   crane    .. the end       high over the man he has just put down, looking
##                             down on him, the lens easing tighter
##   after    FINISHER_AFTER_HOLD s  low and close at the winner's feet, up at
##                             him standing over the body -- then the cover,
##                             which the three-count cut takes
## Two shots, not three: the paired finishers run about 1.6 s, and three cuts
## in that left the crane on screen for 0.3 s (tools/probe/shot_lint.gd, under
## D1's 0.8 s floor). The high angle now belongs to the replay (PostMatch).
const FINISH_SETUP_END := 0.5
const FINISH_IMPACT_END := 1.0
## Where in the impact shot the body lands, and the shake that goes with it.
const FINISH_IMPACT_AT := 0.6
const FINISH_SHAKE := 0.09
const FINISH_SHAKE_DECAY := 3.5
const FINISH_SETUP_FOV := Vector2(24.0, 19.0)
const FINISH_SETUP_DISTANCE := Vector2(2.9, 2.3)
const FINISH_IMPACT_FOV := 58.0
const FINISH_CRANE_FOV := Vector2(44.0, 36.0)
const FINISHER_AFTER_HOLD := 1.6
const FINISH_AFTER_FOV := 50.0
var mode: Mode = Mode.HARD_CAM
## Seconds the current shot has been held. Advanced off the physics delta, so
## it is fixed-step and replays identically; it is never read by anything in
## the tick (ARCHITECTURE.md).
var _held: float = 0.0
## What the last frame was on, so a CUT can snap instead of drifting into
## position over half a second.
var _previous_mode: int = -1
var wrestler_a: Node3D
var wrestler_b: Node3D
var _bearing := Vector3.ZERO
## Seconds since the gameplay bearing last cut, and whether the next frame is
## a cut (placed, not eased into).
var _bearing_age := 0.0
var _snap_next := false
## Whether the gameplay camera is walking round to a new side-on bearing.
var _panning := false
## The gameplay camera's smoothed aim point.
var _look := Vector3.INF
## How many times the gameplay bearing has cut (for tests and probes).
var bearing_cuts := 0
var _cut := -1
var _cut_subject: Node3D
var _cut_other: Node3D
var _cut_hold := 0.0
var _cut_grapple := false
var _cut_return := Mode.HARD_CAM
var _cut_landed := false
var _cut_side := Vector3.ZERO
var _cut_facing := Vector3.ZERO
var _cut_fresh := false
var _cutaway_pending := false
var _sign_fans: Node
var _kickout_reaction := false
const KICKOUT_REACTION_AFTER := 0.9
var grapple_rig: GrappleRig
var referee: MatchReferee

func _ready() -> void:
	wrestler_a = get_node_or_null(wrestler_a_path)
	wrestler_b = get_node_or_null(wrestler_b_path)
	grapple_rig = get_node_or_null(grapple_rig_path)
	referee = get_node_or_null(referee_path)
	if grapple_rig:
		grapple_rig.grapple_started.connect(_on_grapple_started)
		grapple_rig.grapple_finished.connect(_on_grapple_finished)
	for w in [wrestler_a, wrestler_b]:
		var wc := w as WrestlerController
		if wc == null:
			continue
		wc.move_landed.connect(_on_move_landed)
		wc.taunted.connect(func(who): _try_cut(Cut.HERO, who, null))
		wc.fired_up.connect(func(who): _try_cut(Cut.FIRE_UP, who, null))
		wc.knocked_down.connect(func(_who): add_trauma(TRAUMA_KNOCKDOWN))

func _physics_process(delta: float) -> void:
	if mode == Mode.ENTRANCE:
		# EntranceDirector owns the camera until the bell.
		return
	if not wrestler_a or not wrestler_b:
		return
	_update_mode(delta)
	fov = shot_fov()
	_shake(delta)
	if mode == Mode.FINISHER_CUT and _finisher_shot(delta):
		_previous_mode = mode
		return
	if mode == Mode.FINISHER_AFTER:
		_after_shot(delta)
		_previous_mode = mode
		return
	if mode == Mode.EVENT_CUT and _event_shot(delta):
		_previous_mode = mode
		return
	if mode == Mode.THREE_COUNT_CUT and _pin_shot(delta):
		_previous_mode = mode
		return
	_clear_focus_if_needed()
	_watch_sign_fans()

	var midpoint := (wrestler_a.global_position + wrestler_b.global_position) * 0.5
	var target_position: Vector3
	var aim: float

	if mode == Mode.HARD_CAM:
		# A fixed camera does not follow. It sits in its seat and pans, which
		# is why the master is the shot that reads as coverage rather than as
		# a rig strapped to the wrestlers.
		target_position = hard_cam_position
		aim = hard_cam_aim
	else:
		var separation := wrestler_a.global_position.distance_to(wrestler_b.global_position)
		var distance := framing_distance(separation)
		if mode == Mode.RINGSIDE and CameraSettings.gameplay():
			distance = maxf(distance, GAMEPLAY_MIN_DISTANCE)
		# The bearing is a PROPERTY OF THE SHOT, not of wherever the camera
		# happens to be standing. It used to be read back off the camera's own
		# position -- which worked only because nothing ever moved the camera
		# anywhere else. Now that the rig cuts to a hard camera 28m away, the
		# handheld would have come back square to the ring on the -X axis, and
		# the off-axis 3/4 angle that match.tscn was placed for would have
		# survived exactly one cut.
		var gameplay := mode == Mode.RINGSIDE and CameraSettings.gameplay()
		var bearing := _gameplay_bearing(delta) if gameplay else ringside_bearing.normalized()
		var to_camera := bearing * distance
		# Three heights, not two. The finisher cut's low angle is deliberate --
		# camera.md: "drops lower, closer to mat height, for a grounded,
		# low-angle look" -- and it frames two men STANDING, so it keeps
		# cut_height. The three-count frames two men on the mat behind a set of
		# ropes, and wants the opposite (see three_count_height).
		var eye_height := height
		aim = 1.0
		if mode == Mode.THREE_COUNT_CUT:
			eye_height = three_count_height
			aim = three_count_aim
		elif mode == Mode.FINISHER_CUT:
			eye_height = cut_height
			# A low cut looks *up* the bodies rather than down at the mat, so
			# the aim point drops with the camera.
			aim = 0.45
		if gameplay:
			eye_height = GAMEPLAY_HEIGHT
			aim = 0.85
		target_position = midpoint + to_camera + Vector3.UP * eye_height
		if gameplay:
			target_position = _outside_ring(target_position, bearing)

	if mode == _previous_mode and not _snap_next:
		var speed := follow_speed if mode == Mode.RINGSIDE else cut_speed
		global_position = global_position.lerp(target_position, 1.0 - exp(-speed * delta))
	else:
		# A CUT IS INSTANT. Lerping into a new shot is a camera move, and a
		# camera move between two angles is the one thing a vision mixer
		# cannot do -- it is the difference between cutting to the hard camera
		# and flying to it. The rig used to lerp into every cut because there
		# was only ever one position to lerp from.
		global_position = target_position
	var look := midpoint + Vector3.UP * aim
	if mode == Mode.RINGSIDE and CameraSettings.gameplay():
		# The lens follows the pair with a lag, so it frames the action rather
		# than locking onto it frame by frame.
		if _look == Vector3.INF or mode != _previous_mode or _snap_next:
			_look = look
		else:
			_look = _look.lerp(look, 1.0 - exp(-GAMEPLAY_LOOK_SPEED * delta))
		look = _look
	_previous_mode = mode
	_snap_next = false
	look_at(look, Vector3.UP)

## Frames an entrance shot: where the camera stands, what it looks at, and
## the lens. `snap` is a cut; otherwise it eases, which is what a camera
## operator walking backwards down a ramp does.
##
## A2: no entrance shot is locked off (2K26's never are). A held shot pushes
## in slowly -- eased, SHOT_PUSH_RATE of the distance a second up to
## SHOT_PUSH_MAX -- and every shot carries a touch of handheld drift. `motion`
## false is the exception: the stare-down's locked-off shots.
const SHOT_PUSH_RATE := 0.025
const SHOT_PUSH_MAX := 0.12
const SHOT_DRIFT := 0.012
var _shot_t := 0.0
var _shot_at := Vector3.INF
var _shot_look := Vector3.INF


func set_entrance_shot(at: Vector3, look: Vector3, lens: float, snap: bool,
		delta: float = 1.0 / 60.0, motion: bool = true) -> void:
	mode = Mode.ENTRANCE
	_previous_mode = Mode.ENTRANCE
	fov = lens
	# A new shot is a new framing, not the same one re-asserted each tick.
	if snap and (at.distance_to(_shot_at) > 0.05 or look.distance_to(_shot_look) > 0.05):
		_shot_t = 0.0
	_shot_at = at
	_shot_look = look
	_shot_t += delta
	if motion:
		var reach := at.distance_to(look)
		var e := smoothstep(0.0, SHOT_PUSH_MAX / SHOT_PUSH_RATE, _shot_t)
		if snap:
			at += (look - at).normalized() * reach * SHOT_PUSH_MAX * e
		var drift := SHOT_DRIFT * clampf(reach / 4.0, 0.5, 2.0)
		at += Vector3(sin(_shot_t * 2.2) * 0.6 + sin(_shot_t * 3.7 + 1.0) * 0.4,
				sin(_shot_t * 2.9 + 2.0) * 0.5, 0.0) * drift
	if snap:
		global_position = at
	else:
		global_position = global_position.lerp(at, 1.0 - exp(-5.0 * delta))
	if global_position.distance_to(look) > 0.01:
		look_at(look, Vector3.UP)
	_entrance_focus(global_position.distance_to(look), lens)


# --- Depth of field (refs/aaa_gap.md item 10) --------------------------------
## A close-up on a long lens loses its background, the way a broadcast
## camera's does: the crowd behind a man's head goes soft and he stands out of
## it. Only on the entrance and face-off close-ups -- the match's master is a
## wide shot at 28 m, where everything a viewer needs is in focus, and a
## blurred ring would hide the action.
##
## Lenses at or tighter than DOF_MAX_FOV get it, a little stronger the tighter
## they are; the focus sits on the subject plus DOF_MARGIN so his whole head
## and shoulders stay sharp.
const DOF_MAX_FOV := 40.0
const DOF_MARGIN := 1.2
const DOF_TRANSITION := 6.0
const DOF_AMOUNT := 0.08
var _dof: CameraAttributesPractical


static func dof_amount_for(lens: float) -> float:
	if lens > DOF_MAX_FOV:
		return 0.0
	return DOF_AMOUNT * clampf((DOF_MAX_FOV + 6.0 - lens) / 20.0, 0.3, 1.0)


func _entrance_focus(subject_distance: float, lens: float) -> void:
	var amount := dof_amount_for(lens)
	if amount <= 0.0:
		_clear_focus()
		return
	if _dof == null:
		_dof = CameraAttributesPractical.new()
	_dof.dof_blur_far_enabled = true
	_dof.dof_blur_far_distance = subject_distance + DOF_MARGIN
	_dof.dof_blur_far_transition = DOF_TRANSITION
	_dof.dof_blur_amount = amount
	attributes = _dof


func _clear_focus() -> void:
	if attributes == _dof and _dof != null:
		attributes = null


## The lens this shot is taken on.
##
## Separating the lens from the shot is what let the hard camera exist at all.
## Distance and focal length are independent -- the same subject fill comes out
## of a 32mm lens at 3.5m and a 98mm lens at 29m, and those two images look
## nothing alike. With one `fov` on the camera the rig could only ever move,
## never cut to a different lens, so every shot it had was a 32mm shot.
func shot_fov() -> float:
	match mode:
		Mode.HARD_CAM:
			return hard_cam_fov
		Mode.FINISHER_CUT:
			return cut_fov
		Mode.FINISHER_AFTER:
			return FINISH_AFTER_FOV
		Mode.THREE_COUNT_CUT:
			return three_count_fov
		_:
			return ringside_fov

## How long the current shot holds before the clock cuts away from it.
## Returns 0 for the cut modes, which are held by their own event rather than
## by the clock.
func shot_hold() -> float:
	if CameraSettings.gameplay():
		# 2K-style: the gameplay camera is what the match is played on; the
		# master is the cutaway to the wide.
		# The opening wide, once; then the gameplay camera never cuts away on
		# a clock (2K26: one continuous camera).
		match mode:
			Mode.HARD_CAM:
				return GAMEPLAY_OPENING_HOLD
			Mode.RINGSIDE:
				return INF
	match mode:
		Mode.HARD_CAM:
			return hard_cam_hold
		Mode.RINGSIDE:
			return ringside_hold
		_:
			return 0.0

## The distance that frames the shot, in metres from the pair's midpoint.
##
## The fit decides the framing; the guard only stops a wrestler leaving the
## frame. The guard is applied *after* the min/max clamp and is allowed to
## push past max_distance, because an over-wide shot is a worse shot while a
## wrestler off the edge of frame is not a shot at all.
func framing_distance(separation: float) -> float:
	var framed := FIT_INTERCEPT + FIT_SLOPE * maxf(separation, 0.0)
	var distance := clampf(framed, min_distance, max_distance)
	return maxf(distance, containment_distance(separation))

## The closest the camera may sit and still have both bodies inside the
## frame. See CONTAINMENT_WIDTH: a safety limit, not a framing target.
func containment_distance(separation: float) -> float:
	return _distance_for_extent(maxf(separation, 0.0) + BODY_WIDTH,
			CONTAINMENT_WIDTH, _horizontal_fov())

## Distance at which an object of `extent` metres covers `fill` of a view
## `fov` radians across.
##
## Screen position is proportional to tan(angle), not to angle: a subject
## twice as far off-axis is not twice as far across the frame. The first
## version of this divided the field of view by the fill fraction directly,
## which at a 75-degree lens put the solve out by a quarter -- caught by
## probing unproject_position() rather than by reading the formula.
static func _distance_for_extent(extent: float, fill: float, fov: float) -> float:
	return extent / (2.0 * clampf(fill, 0.01, 0.98) * tan(fov * 0.5))

## The lens the FRAMING SOLVE is done against, which is the handheld's -- not
## whatever the camera is currently set to.
##
## This caught the containment guard the moment the master existed. The guard
## and the fill fit both reproduce camera.md's measurements, and those were
## measured on a 41-degree lens; solved against the master's 14 the guard
## demanded 8.6m at the standoff separation where the fit wants 6.7, so the
## engineering limit started choosing the shot. A solve that reads the live
## `fov` is a solve that changes meaning every time the rig cuts.
##
## Godot keeps the vertical axis by default (KEEP_HEIGHT), which makes `fov`
## the vertical field of view; the horizontal one follows from the viewport
## aspect.
func _vertical_fov() -> float:
	if keep_aspect == Camera3D.KEEP_WIDTH:
		return 2.0 * atan(tan(deg_to_rad(ringside_fov) * 0.5) / maxf(_aspect(), 0.01))
	return deg_to_rad(ringside_fov)

func _horizontal_fov() -> float:
	return 2.0 * atan(tan(_vertical_fov() * 0.5) * _aspect())

func _aspect() -> float:
	var viewport := get_viewport()
	if not viewport:
		return 16.0 / 9.0
	var size := viewport.get_visible_rect().size
	if size.y <= 0.0:
		return 16.0 / 9.0
	return size.x / size.y

## The cut modes used to be set by two functions nothing called, and their
## only effect was an early return at the top of _physics_process -- so the
## camera stopped tracking entirely and never resumed. Calling either one
## would have frozen the shot for the rest of the match.
##
## They are driven off the match's own events now, and a cut lasts as long
## as the thing it is cutting to: camera.md marks cut *duration* as pending
## real footage, so rather than invent one, a finisher cut holds while the
## paired move is playing and a three-count cut while the pin is live.
##
## Everything else is the SHOT CLOCK, which is new. Between events the rig
## alternates master and handheld on a timer, which is the coverage pattern a
## televised match actually has. Events pre-empt it: a finisher or a pin cuts
## immediately and resets the clock, so a scheduled cut can never land in the
## middle of a finish.
func _update_mode(delta: float) -> void:
	var was := mode
	if referee and referee.is_pin_active() \
			and not (mode == Mode.FINISHER_AFTER and _held < MIN_SHOT) \
			and not (mode == Mode.FINISHER_CUT and _finish_shot >= 0 and _finish_shot_t < MIN_SHOT):
		mode = Mode.THREE_COUNT_CUT
		_reset_clock_on_change(was)
		return
	if mode == Mode.FINISHER_AFTER:
		_held += delta
		if _held >= FINISHER_AFTER_HOLD:
			mode = master_mode()
			_held = 0.0
		return
	if mode == Mode.THREE_COUNT_CUT:
		# Out of the pin and back to the master, not to whatever was on screen
		# before it: a broadcast comes out of a near-fall on the wide -- and
		# then, a beat later, the crowd reacting to the kickout (B3/B6).
		mode = master_mode()
		_kickout_reaction = referee != null and not referee._match_over and not CameraSettings.gameplay()
	if mode == Mode.FINISHER_CUT:
		if _after_pending and _finish_shot_t >= MIN_SHOT:
			_after_pending = false
			mode = Mode.FINISHER_AFTER
			_held = 0.0
			return
		if grapple_rig and not grapple_rig.is_active() and not _after_pending:
			mode = master_mode()
		_reset_clock_on_change(was)
		return
	if mode == Mode.EVENT_CUT:
		_held += delta
		var bound := _cut_grapple and grapple_rig != null and grapple_rig.is_active()
		if bound:
			_held = minf(_held, 0.0)
		elif _held >= _cut_hold:
			mode = _cut_return
			_cut = -1
			_held = 0.0
		return

	_held += delta
	if _cutaway_pending:
		_cutaway_pending = false
		if (grapple_rig == null or not grapple_rig.is_active()) and _try_cut(Cut.CUTAWAY, wrestler_a, null):
			return
	if _kickout_reaction and mode == Mode.HARD_CAM and _held >= KICKOUT_REACTION_AFTER:
		_kickout_reaction = false
		_try_cut(Cut.CUTAWAY, wrestler_a, null)
		return
	var hold := shot_hold()
	if hold > 0.0 and _held >= hold:
		mode = Mode.RINGSIDE if mode == Mode.HARD_CAM else Mode.HARD_CAM
	_reset_clock_on_change(was)

## Where coverage comes back to after a set piece: the hard camera in
## BROADCAST, the gameplay camera in GAMEPLAY (2K26 comes out of a near-fall
## straight back onto the camera the match is played on).
func master_mode() -> Mode:
	return Mode.RINGSIDE if CameraSettings.gameplay() else Mode.HARD_CAM

func _reset_clock_on_change(was: Mode) -> void:
	if mode != was:
		_held = 0.0

func _on_grapple_started(attacker: Node3D, defender: Node3D, move: MoveDef) -> void:
	var wrestler := attacker as WrestlerController
	if wrestler and wrestler.is_finisher(move):
		mode = Mode.FINISHER_CUT
		_finish_attacker = attacker
		_finish_defender = defender
		_finish_shot = -1
		_finish_side = Vector3.ZERO
		_finish_shot_t = 0.0
		_finish_axes = []
		_after_pending = false
		_held = 0.0
	elif _try_cut(Cut.SLAM, attacker, defender):
		_cut_grapple = true

func _on_grapple_finished(attacker: Node3D, defender: Node3D) -> void:
	if mode == Mode.FINISHER_CUT and _finish_shot >= 0 and _finish_shot_t < MIN_SHOT:
		# The shot on screen gets its minimum first (_update_mode).
		_after_pending = true
		return
	if mode == Mode.FINISHER_CUT:
		mode = Mode.FINISHER_AFTER
		_finish_attacker = attacker
		_finish_defender = defender
		_held = 0.0

func cut_to_finisher() -> void:
	mode = Mode.FINISHER_CUT
	_held = 0.0

func cut_to_three_count() -> void:
	mode = Mode.THREE_COUNT_CUT
	_held = 0.0

## Back to the MASTER. This was `resume_follow`, and it went to the only shot
## there was; coming out of a cut now means coming out onto the hard camera,
## which is where a broadcast goes.
func resume_master() -> void:
	mode = Mode.HARD_CAM
	_held = 0.0
	_clear_focus()

## Back to the camera the match is played on, after a replay or a dive: the
## gameplay camera in GAMEPLAY coverage, the master in BROADCAST.
func resume_play() -> void:
	mode = master_mode()
	_held = 0.0
	_snap_next = true
	_clear_focus()


# --- The finisher sequence -----------------------------------------------------

var _finish_attacker: Node3D
var _finish_defender: Node3D
## Which of the three finisher shots is up (0 setup, 1 impact, 2 crane).
var _finish_shot := -1
var _finish_side := Vector3.ZERO
var _finish_shot_t := 0.0
var _finish_axes: Array = []
var _after_pending := false
var _trauma := 0.0
var _shake_t := 0.0
var _focused := false


## Frames the finisher. Returns false if there is no paired move to read, and
## the ordinary low cut takes it instead.
func _finisher_shot(delta: float) -> bool:
	if grapple_rig == null or _finish_attacker == null:
		return false
	var active := grapple_rig.is_active()
	if not active and _finish_shot < 0:
		return false
	# Shot by the move's progress, but never a shot under MIN_SHOT: the paired
	# move can end well before its progress reaches 1, and cutting on progress
	# alone left the impact on screen for eight frames (shot_lint).
	var p := grapple_rig.progress() if active else 1.0
	var shot := finish_shot_for(p)
	if _finish_shot >= 0 and shot != _finish_shot and _finish_shot_t < MIN_SHOT:
		shot = _finish_shot
	var cut := shot != _finish_shot
	if cut:
		_finish_shot_t = 0.0
	_finish_shot_t += delta
	if shot == 1 and _finish_shot == 1 and p >= FINISH_IMPACT_AT and _trauma <= 0.0 \
			and not _impact_shaken:
		_trauma = 1.0
		_impact_shaken = true
	if cut:
		_impact_shaken = false
	_finish_shot = shot
	var a := _finish_attacker.global_position
	var d := _finish_defender.global_position if _finish_defender else a
	var mid := (a + d) * 0.5
	# The shot's axes are taken as it is cut and held through it: read live,
	# a pair spun through a slam swung the lens 2-3 m in a frame (shot_lint).
	if cut or _finish_axes.is_empty():
		var f0 := _flat(-_finish_attacker.global_transform.basis.z)
		var x0 := _flat(d - a)
		if x0.length() < 0.2:
			x0 = f0
		_finish_axes = [f0.normalized(), x0.normalized()]
	var fwd: Vector3 = _finish_axes[0]
	var across: Vector3 = _finish_axes[1]
	var side := Vector3.UP.cross(across).normalized()
	# The broadcast side of the ring, so the finisher does not jump the line --
	# chosen once for the whole sequence and the aftermath, or a pair turning
	# through square to the hard camera flips it mid-shot.
	if _finish_side == Vector3.ZERO:
		_finish_side = side if side.dot(hard_cam_position - mid) >= 0.0 else -side
	side = side if side.dot(_finish_side) >= 0.0 else -side
	var at: Vector3
	var look: Vector3
	var lens: float
	match shot:
		0:
			var t := clampf(p / FINISH_SETUP_END, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			var dir := (fwd * 0.75 + side * 0.66).normalized()
			var head := a + Vector3.UP * 1.62
			at = head + dir * lerpf(FINISH_SETUP_DISTANCE.x, FINISH_SETUP_DISTANCE.y, e) \
					+ Vector3.DOWN * 0.18
			look = head + Vector3.DOWN * 0.08
			lens = lerpf(FINISH_SETUP_FOV.x, FINISH_SETUP_FOV.y, e)
			_entrance_focus(at.distance_to(head), lens)
			_focused = true
		1:
			at = mid + side * 3.0 + Vector3.UP * 0.32
			look = mid + Vector3.UP * 0.75
			lens = FINISH_IMPACT_FOV
			_clear_focus_if_needed()
		_:
			var t2 := clampf((p - FINISH_IMPACT_END) / (1.0 - FINISH_IMPACT_END), 0.0, 1.0)
			at = d + side * 1.9 - across.normalized() * 1.4 + Vector3.UP * (3.6 - 0.5 * t2)
			look = d + Vector3.UP * 0.3
			lens = lerpf(FINISH_CRANE_FOV.x, FINISH_CRANE_FOV.y, t2)
	fov = lens
	if cut:
		global_position = at
	else:
		# Within a shot the operator follows the bodies, he does not teleport.
		global_position = global_position.lerp(at, 1.0 - exp(-cut_speed * delta))
	look_at(look, Vector3.UP)
	return true


static func finish_shot_for(p: float) -> int:
	if p < FINISH_SETUP_END:
		return 0
	if p < FINISH_IMPACT_END:
		return 1
	return 2


var _impact_shaken := false


## The aftermath: low at the winner's feet, up past him standing over the man.
func _after_shot(_delta: float) -> void:
	if _finish_attacker == null:
		return
	var a := _finish_attacker.global_position
	var d := _finish_defender.global_position if _finish_defender else a
	var across := _flat(d - a)
	if across.length() < 0.2:
		across = _flat(-_finish_attacker.global_transform.basis.z)
	var side := Vector3.UP.cross(across).normalized()
	if _finish_side == Vector3.ZERO:
		_finish_side = side if side.dot(hard_cam_position - a) >= 0.0 else -side
	side = side if side.dot(_finish_side) >= 0.0 else -side
	var t := clampf(_held / FINISHER_AFTER_HOLD, 0.0, 1.0)
	fov = FINISH_AFTER_FOV
	global_position = a - across.normalized() * 0.9 + side * (1.7 - 0.3 * t) + Vector3.UP * 0.35
	look_at(a + Vector3.UP * (1.45 + 0.1 * t), Vector3.UP)


## Handheld impact shake: a decaying "trauma" drives small offsets of the
## film back (h_offset / v_offset), so the camera's aim is untouched and it
## settles exactly where it was. Presentation only.
func _shake(delta: float) -> void:
	if _trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	_shake_t += delta
	var amt := _trauma * _trauma * FINISH_SHAKE * CameraSettings.shake_scale()
	h_offset = amt * sin(_shake_t * 71.0) * cos(_shake_t * 23.0)
	v_offset = amt * sin(_shake_t * 59.0 + 1.3)
	_trauma = maxf(0.0, _trauma - FINISH_SHAKE_DECAY * delta)


## Kick the shake from outside (a big bump).
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _clear_focus_if_needed() -> void:
	if _focused:
		_focused = false
		_clear_focus()


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


# --- B1: the gameplay camera's bearing ------------------------------------------

func _gameplay_bearing(delta: float) -> Vector3:
	if _bearing == Vector3.ZERO:
		_bearing = ringside_bearing.normalized()
	_bearing_age += delta
	var line := _flat(wrestler_b.global_position - wrestler_a.global_position)
	if line.length() < 0.4:
		return _bearing
	var want := Vector3.UP.cross(line).normalized()
	# The broadcast side of the line, so it never crosses it.
	if want.dot(ringside_bearing) < 0.0:
		want = -want
	var mid := (wrestler_a.global_position + wrestler_b.global_position) * 0.5
	var distance := maxf(framing_distance(line.length()), GAMEPLAY_MIN_DISTANCE)
	for turn in [0.45, -0.9]:
		if not post_in_the_way(mid, want, distance):
			break
		want = want.rotated(Vector3.UP, turn)
	var angle := _bearing.signed_angle_to(want, Vector3.UP)
	var blocked := post_in_the_way(mid, _bearing, distance)
	if absf(angle) > GAMEPLAY_DEADZONE or blocked:
		_panning = true
	if _panning:
		if absf(angle) <= GAMEPLAY_SETTLE and not blocked:
			_panning = false
		else:
			var rate := GAMEPLAY_POST_PAN_RATE if blocked else GAMEPLAY_PAN_RATE
			# Eased in and out over the turn, capped at the operator's pace.
			var step := signf(angle) * minf(absf(angle), rate * delta * clampf(absf(angle) / 0.3, 0.25, 1.0))
			_bearing = _bearing.rotated(Vector3.UP, step).normalized()
	return _bearing


## Whether a ring post stands between a camera `distance` out along
## `bearing` and the point `mid` (in plan).
static func post_in_the_way(mid: Vector3, bearing: Vector3, distance: float) -> bool:
	var a := Vector2(mid.x, mid.z)
	var b := a + Vector2(bearing.x, bearing.z) * distance
	for post: Vector3 in POSTS:
		var p := Vector2(post.x, post.z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		if t > 0.05 and (a + ab * t).distance_to(p) < POST_CLEAR:
			return true
	return false


## Pushed back along its bearing until it is outside the ropes.
static func _outside_ring(p: Vector3, bearing: Vector3) -> Vector3:
	var out := p
	for i in 80:
		if absf(out.x) >= RING_OUTSIDE or absf(out.z) >= RING_OUTSIDE:
			break
		out += bearing * 0.1
	return out


# --- B3-B6: event cuts ------------------------------------------------------------

func _on_move_landed(attacker: WrestlerController, defender: WrestlerController, move: MoveDef) -> void:
	if move == null or grapple_rig != null and grapple_rig.is_active():
		return
	var damage := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	var big := damage >= BIG_STRIKE_DAMAGE
	add_trauma(TRAUMA_BIG_STRIKE if big else TRAUMA_STRIKE)
	if big and String(move.resource_path).get_file().begins_with("strike"):
		_try_cut(Cut.STRIKE, defender, attacker)


## Cuts to `kind` if the shot grammar allows it now.
func _try_cut(kind: int, subject: Node3D, other: Node3D) -> bool:
	if not CameraSettings.cuts_enabled() or subject == null:
		return false
	# 2K26's gameplay camera does not cut on a strike, a slam or a taunt: the
	# shake carries the impact and the shot stays where it is.
	if CameraSettings.gameplay():
		return false
	if mode != Mode.HARD_CAM and mode != Mode.RINGSIDE:
		return false
	if _held < MIN_SHOT or (referee != null and referee.is_pin_active()):
		return false
	_cut_return = Mode.RINGSIDE if CameraSettings.gameplay() else Mode.HARD_CAM
	mode = Mode.EVENT_CUT
	_cut = kind
	_cut_subject = subject
	_cut_other = other
	_cut_hold = CUT_HOLD[kind]
	_cut_grapple = false
	_cut_landed = false
	_cut_side = Vector3.ZERO
	_cut_facing = Vector3.ZERO
	_cut_fresh = true
	_held = 0.0
	return true


## Frames the event cut; false if it has nothing to frame.
func _event_shot(delta: float) -> bool:
	if _cut < 0 or _cut_subject == null or not is_instance_valid(_cut_subject):
		return false
	var s := _cut_subject.global_position
	var o := _cut_other.global_position if _cut_other and is_instance_valid(_cut_other) else s
	var mid := (s + o) * 0.5
	var line := _flat(s - o)
	# His facing as the cut landed: read live, a man turned round mid-cut
	# (the fire-up, a taunt) swung the lens 7 m across him in a frame.
	if _cut_facing == Vector3.ZERO:
		_cut_facing = _flat(-_cut_subject.global_transform.basis.z).normalized()
	var facing := _cut_facing
	if line.length() < 0.2:
		line = facing
	line = line.normalized()
	var side := Vector3.UP.cross(line).normalized()
	# Chosen once, when the cut lands: re-chosen each frame, a pair turning
	# through square to the hard camera flipped it, and the lens jumped
	# across the ring mid-shot (shot_lint: one-frame shots inside slam cuts).
	if _cut_side == Vector3.ZERO:
		_cut_side = side if side.dot(hard_cam_position - mid) >= 0.0 else -side
	side = side if side.dot(_cut_side) >= 0.0 else -side
	var at: Vector3
	var look: Vector3
	var lens: float
	var focus := false
	match _cut:
		Cut.STRIKE:
			# Low three-quarter, close on the man taking it.
			at = mid + side * 2.3 + line * 0.8 + Vector3.UP * 1.05
			look = s + Vector3.UP * 1.35
			lens = 40.0
			focus = true
		Cut.SLAM:
			# Mat level, square to the pair, the lens wide: the landing is
			# the payoff. The shake lands with the body.
			at = mid + side * 3.6 + Vector3.UP * 0.45
			look = mid + Vector3.UP * 0.7
			lens = 52.0
			if grapple_rig and grapple_rig.is_active() and grapple_rig.progress() >= FINISH_IMPACT_AT \
					and not _cut_landed:
				_cut_landed = true
				add_trauma(TRAUMA_SLAM)
		Cut.HERO:
			# The taunt: low, in front of him, up at him against the lights.
			var right := Vector3.UP.cross(-facing).normalized()
			at = s + facing * 2.7 + right * 0.7 + Vector3.UP * 0.55
			look = s + Vector3.UP * 1.5
			lens = 30.0
			focus = true
		Cut.FIRE_UP:
			# The comeback: a slow push in on his face.
			var t := clampf(_held / _cut_hold, 0.0, 1.0)
			var e := t * t * (3.0 - 2.0 * t)
			at = s + facing * lerpf(3.2, 2.0, e) + side * 0.4 + Vector3.UP * 1.5
			look = s + Vector3.UP * 1.45
			lens = 32.0
			focus = true
		Cut.CUTAWAY:
			at = CUTAWAY_AT
			look = CUTAWAY_LOOK
			lens = CUTAWAY_FOV
		_:
			return false
	fov = lens
	# Snap on the cut's own first frame, however it was triggered: a cut
	# raised by a signal mid-frame (the sign fans) used to be drawn first by
	# the ordinary framing, so the next frame eased from the wrong place.
	if _cut_fresh or _previous_mode != Mode.EVENT_CUT:
		_cut_fresh = false
		global_position = at
	else:
		global_position = global_position.lerp(at, 1.0 - exp(-cut_speed * delta))
	look_at(look, Vector3.UP)
	if focus:
		_entrance_focus(global_position.distance_to(look), lens)
		_focused = true
	else:
		_clear_focus_if_needed()
	return true


## The pin: down at the mat by the referee's hand, across the pinned man's
## shoulders -- inside the ring, where Aubrey kneels (RefereeActor), so no
## rope crosses the count. False with no cover to frame.
func _pin_shot(_delta: float) -> bool:
	if referee == null or not referee.is_pin_active() or not CameraSettings.gameplay():
		return false
	var defender: WrestlerController = referee._pin_defender
	if defender == null:
		return false
	var at_spot := RefereeActor.cover_spot(defender, [referee.wrestler_a, referee.wrestler_b])
	var spot: Vector3 = at_spot[0]
	var up_body: Vector3 = -(at_spot[1] as Vector3)
	var side := Vector3.UP.cross(up_body).normalized()
	if side.dot(hard_cam_position - spot) < 0.0:
		side = -side
	var neck: Vector3 = defender._bone_world("neck_01")
	if neck == Vector3.INF:
		neck = defender.global_position
	var at := spot + up_body * 1.2 + side * 1.1 + Vector3.UP * 0.8
	at.x = clampf(at.x, -2.95, 2.95)
	at.z = clampf(at.z, -2.95, 2.95)
	fov = 40.0
	global_position = at
	look_at(Vector3(neck.x, 0.35, neck.z) + side * 0.2, Vector3.UP)
	_clear_focus_if_needed()
	return true


## B6: when the sign fans get up in a quiet moment, cut to them.
func _watch_sign_fans() -> void:
	if _sign_fans == null:
		_sign_fans = get_tree().get_first_node_in_group("sign_fans") if is_inside_tree() else null
		if _sign_fans and _sign_fans.has_signal("raised"):
			_sign_fans.raised.connect(func():
				# Taken at the top of the next frame (_update_mode), never from
				# inside this one: a cut changed mid-frame is drawn by the wrong shot.
				_cutaway_pending = true)
