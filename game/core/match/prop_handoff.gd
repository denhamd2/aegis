class_name PropHandoff
extends Node
## What happens to a man's props at his entrance: the wrestler hands each one,
## in turn, to Aubrey; she carries it to the ropes and hands it through them to
## the timekeeper; he sets it on his table. One prop at a time, every one in a
## hand or on a shoulder or on the table at every moment -- never hidden,
## never moved but by a hand, never a pop.
##
## The prop lives on a Pivot of its own. A "holder" says where the pivot is
## each frame (a bone plus an offset, or a place on the table); changing holder
## starts from wherever the pivot is NOW and eases to the new holder's place
## over BLEND seconds, so the swap on a contact frame is continuous by
## construction. The clips (wrestling_clips.py: Prop_Hand_Out_*, Ref_Reach,
## Ref_Hand_Over, Timekeeper_Take, Ref_Place) put the two hands together on
## the contact frames below; the walkers are placed so they are.
##
## Presentation only: nothing in a match reads any of this.

signal job_finished(kind: String)

## Where it all happens: ringside, the +X side, the hard camera's right.
const FLOOR_Y := -1.1
## Aubrey hands through the ropes from inside them, the timekeeper takes from
## the floor outside, between the bottom and middle ropes' heights.
const REF_PASS_X := 2.38
const KEEPER_PASS_X := 3.68
const PASS_Z := 0.0
const KEEPER_POST := Vector3(KEEPER_PASS_X, FLOOR_Y, -1.5)
const KEEPER_PLACE := Vector3(3.72, FLOOR_Y, 1.0)
const TABLE_AT := Vector3(4.5, FLOOR_Y, 1.6)

## Contact frames of the clips (30 fps): the prop changes hands on these.
const GIVE_CONTACT := 26.0 / 30.0   # Prop_Hand_Out_*
const REACH_CONTACT := 24.0 / 30.0  # Ref_Reach
const REACH_SHOULDER := 46.0 / 30.0
const OVER_CONTACT := 28.0 / 30.0   # Ref_Hand_Over
const TAKE_CONTACT := 26.0 / 30.0   # Timekeeper_Take
const TAKE_SHOULDER := 44.0 / 30.0
const PLACE_CONTACT := 30.0 / 30.0  # Ref_Place
## How long a hand-to-hand move eases for.
const BLEND := 0.22

## Body-frame hand targets (right, forward) the clips reach to, for placing
## the two people so the hands meet.
const HAND_L := Vector2(-0.14, 0.64)   # wrestler, belt hand
const HAND_R := Vector2(0.14, 0.64)    # wrestler, fala hand
const REF_RECEIVE := Vector2(0.14, 0.62)
const REF_GIVE := Vector2(0.14, 0.72)
const KEEPER_TAKE := Vector2(0.16, 0.55)

enum Step { IDLE, APPROACH, RECEIVE, CARRY, PASS, PLACE }

var step := Step.IDLE

var _ref: RefereeActor
var _keeper: Timekeeper
var _jobs: Array = []
var _job := {}
var _clock := 0.0
var _armed := false             # the giver's hand-out has started
var _stage := 0                 # sub-step inside a Step
var _arrived := {}              # who is where they were sent, in CARRY
## Everything the table has been given, in order; and how many of those got
## there by the whole sequence (not by the bell cutting it short).
var delivered: Array[String] = []
var completed := 0
## Every prop in play (on a hand, a shoulder or the table), for the tests.
var carried: Array = []


## One prop on its pivot, and where it is held.
class Carried:
	var kind := ""
	var pivot: Node3D
	var holder := {}
	var blend := 1.0
	var from := Transform3D.IDENTITY

	func swap(to: Dictionary) -> void:
		from = pivot.global_transform
		blend = 0.0
		holder = to

	func on_table() -> bool:
		return holder.get("type", "") == "table"

	func drive(delta: float) -> void:
		if holder.is_empty():
			return
		var target := PropHandoff._holder_transform(holder)
		if blend < 1.0:
			blend = minf(blend + delta / PropHandoff.BLEND, 1.0)
			pivot.global_transform = from.interpolate_with(target, smoothstep(0.0, 1.0, blend))
		else:
			pivot.global_transform = target


func setup(referee: RefereeActor, keeper: Timekeeper) -> void:
	_ref = referee
	_keeper = keeper
	_ref.errand_arrived.connect(_on_arrived.bind("ref"))
	_keeper.arrived.connect(_on_arrived.bind("keeper"))


func is_idle() -> bool:
	return step == Step.IDLE and _jobs.is_empty()


## How many props are in someone's hands or on a shoulder right now (not on
## the table): never more than one.
func in_motion() -> int:
	var n := 0
	for c: Carried in carried:
		if not c.on_table():
			n += 1
	return n


## Ask for a prop to be handed on: `kind` is "title" or "fala", `giver` the
## wrestler, `props` his EntranceProps. Starts at once if nothing is going on,
## else waits its turn.
func request(kind: String, giver: WrestlerController, props: EntranceProps,
		facing := Vector3.ZERO) -> void:
	# `facing`: the way he will be facing for the pass (his beat's heading),
	# when he has not turned to it yet.
	_jobs.append({"kind": kind, "giver": giver, "props": props, "facing": facing})
	if step == Step.IDLE:
		_next_job()


## He has taken the necklace off over his head (the director's fala_off cue):
## it is a thing in his hand from this moment, not a skinned shape. Called for
## whichever job asked for it, current or not.
func lift(kind: String) -> void:
	for job: Dictionary in [_job] + _jobs:
		if not job.is_empty() and job["kind"] == kind and not job.has("carried"):
			_take_prop(job)
			return


## The giver's hand-out clip has begun (the director's prop_pass cue).
func giver_begins() -> void:
	if step == Step.RECEIVE and _stage == 0:
		_start_receive()
	else:
		_armed = true


func _next_job() -> void:
	if _jobs.is_empty():
		step = Step.IDLE
		return
	_job = _jobs.pop_front()
	step = Step.APPROACH
	_clock = 0.0
	_armed = false
	_stage = 0
	var giver: WrestlerController = _job["giver"]
	_ref.begin_errand()
	var hand: Vector2 = HAND_L if _job["kind"] == "title" else HAND_R
	var face: Vector3 = _job["facing"] if (_job["facing"] as Vector3).length() > 0.01 else _facing(giver)
	face = Vector3(face.x, 0.0, face.z).normalized()
	var spot := stand_for(giver.global_position, face, hand, REF_RECEIVE)
	_ref.errand_go(spot, -face)


func _on_arrived(who: String) -> void:
	match step:
		Step.APPROACH:
			if who != "ref":
				return
			step = Step.RECEIVE
			_stage = 0
			_ref.errand_idle()
			if _armed:
				_start_receive()
		Step.CARRY:
			_arrived[who] = true
			if _arrived.has("ref") and _arrived.has("keeper"):
				_start_pass()
		Step.PLACE:
			if who == "keeper" and _stage == 0:
				_start_place()


## --- RECEIVE: the wrestler gives, Aubrey takes -------------------------------

func _start_receive() -> void:
	_stage = 1
	_clock = 0.0
	_ref.errand_play("strikes/ref_reach")
	if not _job.has("carried"):
		_take_prop(_job)


## Puts a job's prop on a pivot of its own, in the giver's hand.
func _take_prop(job: Dictionary) -> void:
	var giver: WrestlerController = job["giver"]
	var props: EntranceProps = job["props"]
	var prop: Node3D
	var grip := Vector3.ZERO
	if job["kind"] == "title":
		prop = props.take_title()
	else:
		prop = props.take_fala()
		grip = props.fala_neck_rest()
	if prop == null:
		return
	var c := Carried.new()
	c.kind = job["kind"]
	c.pivot = Node3D.new()
	c.pivot.name = "Pivot_" + String(job["kind"])
	c.pivot.top_level = true
	add_child(c.pivot)
	# The pivot sits where the prop is now; what is held is its grip.
	c.pivot.global_transform = prop.global_transform * Transform3D(Basis.IDENTITY, grip)
	prop.reparent(c.pivot, true)
	var hand := "hand_l" if job["kind"] == "title" else "hand_r"
	c.holder = _bone_holder(giver.skeleton, giver._skeleton_bone_name(hand), giver, Vector3.ZERO)
	c.from = c.pivot.global_transform
	job["carried"] = c
	carried.append(c)


func _process(delta: float) -> void:
	for c: Carried in carried:
		c.drive(delta)
	if step == Step.IDLE:
		return
	_clock += delta
	match step:
		Step.RECEIVE:
			_receive_tick()
		Step.PASS:
			_pass_tick()
		Step.PLACE:
			_place_tick()


func _receive_tick() -> void:
	var c: Carried = _job.get("carried")
	if c == null or _stage < 1:
		return
	if _stage == 1 and _clock >= REACH_CONTACT:
		# Contact: into her hand, easing over BLEND.
		c.swap(_bone_holder(_ref.skeleton(), "hand_r", _ref, Vector3.ZERO))
		_stage = 2
	elif _stage == 2 and _clock >= REACH_SHOULDER:
		c.swap(_bone_holder(_ref.skeleton(), "clavicle_r", _ref, SHOULDER_OFFSET))
		_stage = 3
		_start_carry()


## Over her right shoulder, in her yaw frame: a little up, a little back.
const SHOULDER_OFFSET := Vector3(0.0, 0.10, -0.04)


func _start_carry() -> void:
	step = Step.CARRY
	_stage = 0
	_clock = 0.0
	_arrived.clear()
	var face := Vector3(1, 0, 0)
	# Where her hand and his meet: she stands so that her hand_r and his
	# hand_r are one point (hands are right/forward; he faces her).
	var keeper_at := Vector3(KEEPER_PASS_X, FLOOR_Y, PASS_Z)
	var ref_at := stand_for(keeper_at, -face, KEEPER_TAKE, REF_GIVE)
	_ref.errand_go(Vector3(REF_PASS_X, 0.0, ref_at.z), face)
	_keeper.go(keeper_at, -face)


## --- PASS: through the ropes ------------------------------------------------

func _start_pass() -> void:
	step = Step.PASS
	_stage = 0
	_clock = 0.0
	_ref.errand_play("strikes/ref_hand_over")
	_keeper.play("strikes/timekeeper_take")


func _pass_tick() -> void:
	var c: Carried = _job["carried"]
	if _stage == 0 and _clock >= OVER_CONTACT:
		c.swap(_bone_holder(_keeper.skeleton(), "hand_r", _keeper, Vector3.ZERO))
		_stage = 1
	elif _stage == 1 and _clock >= TAKE_SHOULDER:
		c.swap(_bone_holder(_keeper.skeleton(), "clavicle_r", _keeper, SHOULDER_OFFSET))
		# She is done: back to her spot. He takes it to the table.
		_ref.end_errand()
		step = Step.PLACE
		_stage = 0
		_clock = 0.0
		_keeper.go(KEEPER_PLACE, Vector3(1, 0, 0))


## --- PLACE: onto the table --------------------------------------------------

func _start_place() -> void:
	_stage = 1
	_clock = 0.0
	_keeper.play("strikes/ref_place")


func _place_tick() -> void:
	var c: Carried = _job["carried"]
	if _stage == 1 and _clock >= PLACE_CONTACT:
		c.swap(_table_holder(String(_job["kind"])))
		_stage = 2
	elif _stage == 2 and _clock >= _keeper.clip_length("strikes/ref_place"):
		var kind := String(_job["kind"])
		delivered.append(kind)
		completed += 1
		_keeper.go(KEEPER_POST, Vector3(-1, 0, 0))
		_job = {}
		step = Step.IDLE
		job_finished.emit(kind)
		_next_job()


## At the bell with a prop still on its way: it goes where it was going, now.
func finish_now() -> void:
	for job: Dictionary in [_job] + _jobs:
		if job.is_empty():
			continue
		if not job.has("carried"):
			_take_prop(job)
		var c: Carried = job.get("carried")
		if c != null and not c.on_table():
			c.swap(_table_holder(String(job["kind"])))
			c.blend = 1.0
			c.pivot.global_transform = _holder_transform(c.holder)
			delivered.append(String(job["kind"]))
	_jobs.clear()
	_job = {}
	step = Step.IDLE
	_ref.end_errand()
	_keeper.idle()
	_keeper.go(KEEPER_POST, Vector3(-1, 0, 0))


## --- holders ----------------------------------------------------------------

## A bone of `skeleton`, with `offset` in the yaw frame of `actor`.
static func _bone_holder(skeleton: Skeleton3D, bone: String, actor: Node3D,
		offset: Vector3) -> Dictionary:
	return {"type": "bone", "skeleton": skeleton, "bone": skeleton.find_bone(bone),
			"actor": actor, "offset": offset}


## The table's two places for a prop: where it lies.
static func _table_holder(kind: String) -> Dictionary:
	var top := TABLE_AT + Vector3(0.0, Timekeeper.TABLE_SIZE.y + 0.03, 0.0)
	var slot := -0.45 if kind == "title" else 0.35
	# Along the table. The belt is authored upright facing -Z, so it lies with
	# its front up after a quarter turn about X; the necklace is a loop around
	# a neck, laid flat the same way (its grip is the neck, so it sits a little
	# proud of the top).
	var basis := Basis(Vector3.UP, PI * 0.5) * Basis(Vector3.RIGHT, PI * 0.5)
	if kind == "fala":
		top.y += 0.03
	return {"type": "table", "xform": Transform3D(basis, top + Vector3(0.0, 0.0, slot))}


static func _holder_transform(holder: Dictionary) -> Transform3D:
	if holder["type"] == "table":
		return holder["xform"]
	var sk: Skeleton3D = holder["skeleton"]
	var actor: Node3D = holder["actor"]
	var bone: int = holder["bone"]
	if sk == null or bone < 0:
		return actor.global_transform
	var origin := (sk.global_transform * sk.get_bone_global_pose(bone)).origin
	# Upright, turned as the holder is: a belt does not tip with a wrist.
	var yaw := _yaw_of(actor)
	var basis := Basis(Vector3.UP, yaw)
	return Transform3D(basis, origin + basis * (holder["offset"] as Vector3))


## The heading of an actor: a wrestler faces his node's -Z, the referee's and
## the timekeeper's model +Z; the prop's plate faces the way its holder does
## (the belt is authored facing -Z, as the wrestlers are).
static func _yaw_of(actor: Node3D) -> float:
	if actor is WrestlerController:
		return actor.global_rotation.y
	return actor.global_rotation.y + PI


## --- geometry ---------------------------------------------------------------

## The direction a wrestler faces: his node's -Z.
static func _facing(w: Node3D) -> Vector3:
	return -w.global_transform.basis.z.slide(Vector3.UP).normalized()


## Where a person with `taker_hand` (right, forward in his own frame) stands to
## put his hand on the point where the giver's `giver_hand` is, facing him.
static func stand_for(giver_pos: Vector3, giver_face: Vector3, giver_hand: Vector2,
		taker_hand: Vector2) -> Vector3:
	var gf := Vector3(giver_face.x, 0.0, giver_face.z).normalized()
	var gr := gf.cross(Vector3.UP)
	var point := Vector3(giver_pos.x, 0.0, giver_pos.z) + gr * giver_hand.x + gf * giver_hand.y
	var tf := -gf
	var tr := tf.cross(Vector3.UP)
	return point - tr * taker_hand.x - tf * taker_hand.y
