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
@export var hard_cam_hold: float = 7.0
@export var ringside_hold: float = 4.5

## HARD_CAM is the master and the default. RINGSIDE is what used to be called
## FOLLOW -- the same rig, the same solve, renamed for what it actually is now
## that there is something else for it to be cut against.
enum Mode { HARD_CAM, RINGSIDE, FINISHER_CUT, THREE_COUNT_CUT }
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

func _physics_process(delta: float) -> void:
	if not wrestler_a or not wrestler_b:
		return
	_update_mode(delta)
	fov = shot_fov()

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
		# The bearing is a PROPERTY OF THE SHOT, not of wherever the camera
		# happens to be standing. It used to be read back off the camera's own
		# position -- which worked only because nothing ever moved the camera
		# anywhere else. Now that the rig cuts to a hard camera 28m away, the
		# handheld would have come back square to the ring on the -X axis, and
		# the off-axis 3/4 angle that match.tscn was placed for would have
		# survived exactly one cut.
		var to_camera := ringside_bearing.normalized() * distance
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
		target_position = midpoint + to_camera + Vector3.UP * eye_height

	if mode == _previous_mode:
		var speed := follow_speed if mode == Mode.RINGSIDE else cut_speed
		global_position = global_position.lerp(target_position, 1.0 - exp(-speed * delta))
	else:
		# A CUT IS INSTANT. Lerping into a new shot is a camera move, and a
		# camera move between two angles is the one thing a vision mixer
		# cannot do -- it is the difference between cutting to the hard camera
		# and flying to it. The rig used to lerp into every cut because there
		# was only ever one position to lerp from.
		global_position = target_position
	_previous_mode = mode
	look_at(midpoint + Vector3.UP * aim, Vector3.UP)

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
		Mode.THREE_COUNT_CUT:
			return three_count_fov
		_:
			return ringside_fov

## How long the current shot holds before the clock cuts away from it.
## Returns 0 for the cut modes, which are held by their own event rather than
## by the clock.
func shot_hold() -> float:
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
	if referee and referee.is_pin_active():
		mode = Mode.THREE_COUNT_CUT
		_reset_clock_on_change(was)
		return
	if mode == Mode.THREE_COUNT_CUT:
		# Out of the pin and back to the master, not to whatever was on screen
		# before it: a broadcast comes out of a near-fall on the wide.
		mode = Mode.HARD_CAM
	if mode == Mode.FINISHER_CUT:
		if grapple_rig and not grapple_rig.is_active():
			mode = Mode.HARD_CAM
		_reset_clock_on_change(was)
		return

	_held += delta
	var hold := shot_hold()
	if hold > 0.0 and _held >= hold:
		mode = Mode.RINGSIDE if mode == Mode.HARD_CAM else Mode.HARD_CAM
	_reset_clock_on_change(was)

func _reset_clock_on_change(was: Mode) -> void:
	if mode != was:
		_held = 0.0

func _on_grapple_started(attacker: Node3D, _defender: Node3D, move: MoveDef) -> void:
	var wrestler := attacker as WrestlerController
	if wrestler and wrestler.is_finisher(move):
		mode = Mode.FINISHER_CUT
		_held = 0.0

func _on_grapple_finished(_attacker: Node3D, _defender: Node3D) -> void:
	if mode == Mode.FINISHER_CUT:
		mode = Mode.HARD_CAM
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
