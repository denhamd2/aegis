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
@export var follow_speed: float = 6.0
## A cut snaps harder than the follow-cam drifts. camera.md marks cut
## duration and ease curves as pending real footage, so this is a project
## value: it is not defended as matching anything measured.
@export var cut_speed: float = 14.0

enum Mode { FOLLOW, FINISHER_CUT, THREE_COUNT_CUT }
var mode: Mode = Mode.FOLLOW
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
	_update_mode()

	var midpoint := (wrestler_a.global_position + wrestler_b.global_position) * 0.5
	var separation := wrestler_a.global_position.distance_to(wrestler_b.global_position)
	var distance := framing_distance(separation)

	var to_camera := global_position - midpoint
	to_camera.y = 0.0
	if to_camera.length() < 0.01:
		to_camera = Vector3.BACK
	to_camera = to_camera.normalized() * distance

	var eye_height := cut_height if mode != Mode.FOLLOW else height
	var speed := follow_speed if mode == Mode.FOLLOW else cut_speed
	var target_position := midpoint + to_camera + Vector3.UP * eye_height
	global_position = global_position.lerp(target_position, 1.0 - exp(-speed * delta))
	# A low cut looks *up* the bodies rather than down at the mat, so the
	# aim point drops with the camera.
	var aim := 0.45 if mode != Mode.FOLLOW else 1.0
	look_at(midpoint + Vector3.UP * aim, Vector3.UP)

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

## Godot keeps the vertical axis by default (KEEP_HEIGHT), which makes `fov`
## the vertical field of view; the horizontal one follows from the viewport
## aspect. camera.md marks FOV itself as "not derivable from a still", so
## this reads whatever the camera is set to rather than asserting a value --
## the fill targets are the measurement, and distance is what gets solved.
func _vertical_fov() -> float:
	if keep_aspect == Camera3D.KEEP_WIDTH:
		return 2.0 * atan(tan(deg_to_rad(fov) * 0.5) / maxf(_aspect(), 0.01))
	return deg_to_rad(fov)

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
func _update_mode() -> void:
	if referee and referee.is_pin_active():
		mode = Mode.THREE_COUNT_CUT
		return
	if mode == Mode.THREE_COUNT_CUT:
		mode = Mode.FOLLOW
	if mode == Mode.FINISHER_CUT and grapple_rig and not grapple_rig.is_active():
		mode = Mode.FOLLOW

func _on_grapple_started(attacker: Node3D, _defender: Node3D, move: MoveDef) -> void:
	var wrestler := attacker as WrestlerController
	if wrestler and wrestler.is_finisher(move):
		mode = Mode.FINISHER_CUT

func _on_grapple_finished(_attacker: Node3D, _defender: Node3D) -> void:
	if mode == Mode.FINISHER_CUT:
		mode = Mode.FOLLOW

func cut_to_finisher() -> void:
	mode = Mode.FINISHER_CUT

func cut_to_three_count() -> void:
	mode = Mode.THREE_COUNT_CUT

func resume_follow() -> void:
	mode = Mode.FOLLOW
