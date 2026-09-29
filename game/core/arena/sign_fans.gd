class_name SignFans
extends Node3D
## Two fans in the ringside rows opposite the hard camera, holding up signs
## (tools/blender/sign_fan.py; the owner's two reference photographs of a WWE
## crowd show how it is done). They sit for most of the match and stand with
## their signs over their heads only now and then:
##
##   * for the stare-down before the bell -- up as the face-off shot comes up
##     (EntranceDirector.beat_started "faceoff_side"), which looks across the
##     ring at exactly these rows, and back down just after the bell;
##   * once or twice more in the match, on a big moment -- a signature landing
##     or a near-fall -- no sooner than MATCH_GAP apart.
##
## Built by ArenaBuilder into two real ringside chairs (those chairs' crowd
## figures are left out for them); hooked to the match by MatchSetup.
## Presentation only.

## The two boards, and roughly where their chairs are: ringside rows two and
## three (the barricade square at 6 m plus FLOOR_SEAT_START and a row pitch or
## two) on the +X side, which is the side the hard camera at -X and the
## face-off shot both look across the ring at. Either side of the centre line
## by ~3 m, so the two men standing chest to chest in the middle do not hide
## them.
const FANS := [
	["res://assets/environment/signs/enda_fears_omar.jpg", Vector3(8.05, 0.0, -3.6), Color(0.30, 0.13, 0.13)],
	["res://assets/environment/signs/cody_sucks.jpg", Vector3(8.9, 0.0, 3.1), Color(0.14, 0.18, 0.28)],
]
## Held up through the face-off, however long it runs; down this long after
## the bell.
const FACEOFF_HOLD := 30.0
const DOWN_AFTER_BELL := 1.2
## In the match: this many times at most, this far apart, held this long.
const MATCH_RAISES_MAX := 2
const MATCH_GAP := 25.0
const MATCH_HOLD := 4.5
## The second fan is a beat behind the first: two people, not one.
const STAGGER := 0.35

var fans: Array[SignFan] = []
var match_raises := 0
var _since_raise := 1.0e9
var _raised_for_faceoff := false
var _queued: Array = []   # [seconds from now, fan, hold]
var _referee: MatchReferee
var _pin_peak := 0
var _was_pinning := false


func _ready() -> void:
	add_to_group("sign_fans")


## The chair nearest each fan's spot, as indices into `chairs`: those seats
## are theirs, and ArenaBuilder leaves them out of the crowd.
static func pick_seats(chairs: Array[Transform3D]) -> Array[int]:
	var picked: Array[int] = []
	for spec: Array in FANS:
		var spot: Vector3 = spec[1]
		var best := -1
		var best_d := INF
		for i in chairs.size():
			if picked.has(i):
				continue
			var d := Vector2(chairs[i].origin.x - spot.x, chairs[i].origin.z - spot.z).length()
			if d < best_d:
				best_d = d
				best = i
		picked.append(best)
	return picked


## Sits a fan in each picked chair.
func seat(chairs: Array[Transform3D], picked: Array[int]) -> void:
	for n in picked.size():
		if picked[n] < 0:
			continue
		var spec: Array = FANS[n]
		var fan := SignFan.new()
		fan.name = "SignFan%d" % n
		add_child(fan)
		fan.transform = chairs[picked[n]]
		fan.setup(load(spec[0]) as Texture2D, spec[2], 0.37 * n)
		fans.append(fan)


## The match's big moments.
func watch(referee: MatchReferee, wrestlers: Array) -> void:
	_referee = referee
	for w: WrestlerController in wrestlers:
		w.move_landed.connect(func(_a, _d, move: MoveDef) -> void:
			if move and move.resource_path.get_file().begins_with("signature_"):
				_big_moment())
	referee.match_won.connect(func(_w, _m) -> void: _queued.clear())


## The entrances: up for the stare-down, down after the bell.
func follow(director: EntranceDirector) -> void:
	director.beat_started.connect(func(shot: String) -> void:
		if shot == "faceoff_side" and not _raised_for_faceoff:
			_raised_for_faceoff = true
			_raise_all(FACEOFF_HOLD))
	director.bell.connect(func() -> void:
		for fan in fans:
			_queued.append([DOWN_AFTER_BELL, fan, -1.0]))


func _big_moment() -> void:
	if match_raises >= MATCH_RAISES_MAX or _since_raise < MATCH_GAP:
		return
	match_raises += 1
	_raise_all(MATCH_HOLD)


func _raise_all(hold: float) -> void:
	_since_raise = 0.0
	for n in fans.size():
		_queued.append([STAGGER * n, fans[n], hold])


func _process(delta: float) -> void:
	_since_raise += delta
	_follow_the_cover()
	for q: Array in _queued.duplicate():
		q[0] -= delta
		if q[0] > 0.0:
			continue
		_queued.erase(q)
		var fan: SignFan = q[1]
		if float(q[2]) < 0.0:
			fan.sit()
		else:
			fan.raise(float(q[2]))


## A near-fall -- out of a cover that got past two -- is a big moment too.
func _follow_the_cover() -> void:
	if _referee == null or not is_instance_valid(_referee):
		return
	var pinning := _referee.is_pin_active()
	if pinning:
		_pin_peak = maxi(_pin_peak, _referee.pin_count())
	elif _was_pinning:
		if _pin_peak >= 2:
			_big_moment()
		_pin_peak = 0
	_was_pinning = pinning
