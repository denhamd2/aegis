class_name EntranceCamera
extends Camera3D
## The three shots the walk to the ring is covered in. Current only while
## EntranceDirector is running; MatchCamera takes the frame back at the handoff.
##
## ## Why this is not a fifth MatchCamera.Mode
##
## MatchCamera's whole job is a framing SOLVE: it takes the separation between
## two wrestlers and returns the distance that puts them at FILL_ENGAGED or
## FILL_STANDOFF of the frame height, against FIT_INTERCEPT and FIT_SLOPE
## measured off the reference corpus and pinned by tests/test_camera_framing.gd.
## Every one of those numbers assumes two men in a six-metre ring.
##
## During an entrance there is one man, he is up to 37m from the ring, and the
## other is standing still on his mark. `MatchCamera._physics_process()` reads
## `(wrestler_a.global_position + wrestler_b.global_position) * 0.5` as the
## thing to look at, which during an entrance is a point in the seats halfway
## between the ramp and the ring. There is no framing question here that the
## solve answers, and adding a mode that bypasses it would mean a mode that
## skips `framing_distance()` -- at which point it is this file with a worse
## name and a shared `_held` clock.
##
## So: nothing here feeds the solve, and nothing here can move it.
##
## ## The shots
##
## Cut, not mixed. A hard cut between shots is what broadcast coverage of an
## entrance is; a camera that flies from the stage to ringside over two seconds
## is a video-game camera and reads as one.
##
## STAGE is the money shot the set was built for -- `arena_builder.gd`'s header
## says the stage reads frame-left in the master "via stage_wide/entrance
## framings as well as the broadcast edge", and this is that framing. RAMP
## tracks him down, held off-axis so the bowl is behind him rather than the
## empty floor. APRON is low and close as he climbs, because the climb is the
## one moment in an entrance with a physical action in it.

enum Shot { STAGE, RAMP, APRON }

## Lens per shot. The stage is wide because the set is 12m across and the
## point of the shot is the set; the ramp is a long lens so the walk compresses
## and he reads as approaching rather than as shrinking; the apron is wide
## again because it is close.
const SHOT_FOV := {
	# 34, not the 46 this started on. At 46 from 20m the frame's vertical
	# half-extent is 8.5m, which put the whole 5.4m video wall across the top of
	# the shot -- and the wall plays its clip freely outside a capture run (see
	# StageVideo's header), so that was a blown white slab over the man the shot
	# is of. The longer lens frames the portals and the deck, with the bottom of
	# the wall behind them, which is what an entrance shot is of.
	Shot.STAGE: 34.0,
	Shot.RAMP: 34.0,
	Shot.APRON: 52.0,
}

## Where each shot's camera sits, in world metres. The stage camera is out on
## the floor looking back up the ramp; the ramp camera is off the walk's own
## axis (+X) and low, so the seating bowl fills the background instead of the
## void above the boards; the apron camera is at the corner the steps are on.
const SHOT_POSITION := {
	Shot.STAGE: Vector3(3.1, 0.95, -19.0),
	Shot.RAMP: Vector3(7.4, 1.35, -12.0),
	Shot.APRON: Vector3(-7.0, 0.55, -5.4),
}

## Height above the subject's feet the shot aims at. Chest, not head: a camera
## aimed at the head of a man 25m away puts him in the bottom third of frame.
const AIM_HEIGHT := 1.15

## How closely the aim follows the subject, per tick. 1.0 snaps, which on a
## long lens turns every footfall into a jitter. This is a camera operator's
## hand: it lags, then catches up.
const AIM_LAG := 0.14

var shot: Shot = Shot.STAGE
## What the shots look at. Set by EntranceDirector each leg; the camera never
## looks anything up itself, so it cannot outlive the wrestler it was covering.
var subject: Node3D = null

var _aim: Vector3 = Vector3.ZERO
var _has_aim := false


func _ready() -> void:
	# Never current on its own. match.tscn ships MatchCamera current, and a
	# second camera that made itself current in _ready() would silently take
	# every probe and every capture in the repo -- which point at
	# scenes/play.tscn and scenes/match.tscn, where no entrance runs.
	current = false


## Cuts to `next`, snapping the aim so the first frame of the new shot is
## already framed. Without the snap the cut is followed by a half-second swing
## from wherever the last shot was pointing.
func cut_to(next: Shot) -> void:
	shot = next
	fov = SHOT_FOV[next]
	position = SHOT_POSITION[next]
	_has_aim = false


func _physics_process(_delta: float) -> void:
	if not current or subject == null or not is_instance_valid(subject):
		return
	var target := subject.global_position + Vector3(0.0, AIM_HEIGHT, 0.0)
	if _has_aim:
		_aim = _aim.lerp(target, AIM_LAG)
	else:
		_aim = target
		_has_aim = true
	# Degenerate only if the camera is standing on the subject, which none of
	# SHOT_POSITION is.
	if _aim.distance_to(global_position) > 0.01:
		look_at(_aim, Vector3.UP)
