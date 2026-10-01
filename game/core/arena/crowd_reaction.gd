class_name CrowdReaction
extends Node
## The crowd reacting to the match (gauntlet/refs/aaa_gap.md item 11): up out
## of their seats on a big move, a roar on a near-fall, phones out for the
## entrances.
##
## 2K's crowd reacts and ours sat through everything at the same idle bob.
## This listens to the match and drives two shader globals the crowd material
## reads (ArenaBuilder._crowd_material): `crowd_excitement` (0-1, how hard
## they bounce) and `crowd_flash_rate` (phone flashes per figure per second).
##
## Presentation only, and the direction of every arrow is the point: it
## LISTENS to signals and reads the referee, runs in _process rather than the
## physics tick, and writes nothing but two render globals. Nothing in a match
## can read it, so the replay hash cannot see it (ARCHITECTURE.md).

## Excitement falls by half every this many seconds once nothing is feeding it.
const HALF_LIFE := 2.2
## A move's pop from its total damage: nothing under POP_DAMAGE_FLOOR (a jab
## is not a reaction), full POP_MOVE_MAX at POP_DAMAGE_FULL. Signature moves
## (the finishers' .tres names start "signature_") pop POP_SIGNATURE.
const POP_DAMAGE_FLOOR := 12.0
const POP_DAMAGE_FULL := 26.0
const POP_MOVE_MAX := 0.65
const POP_SIGNATURE := 0.9
## A cover builds tension with each count; a kickout after two is the loudest
## thing in wrestling.
const PIN_TENSION := 0.22
const PIN_PER_COUNT := 0.2
const POP_NEAR_FALL := 1.0
const POP_FIRED_UP := 0.55
## Playing to the crowd (WrestlerController.begin_taunt): they answer him.
const POP_TAUNT := 0.6
## The finish: full, held while the winner celebrates.
const WIN_HOLD := 8.0
## Phone flashes during an entrance, per figure per second. There are a few
## thousand figures, so this is a few dozen flashes a second across the bowl.
const ENTRANCE_FLASH_RATE := 0.012

var excitement := 0.0
var flash_rate := 0.0

var _referee: MatchReferee
var _floor := 0.0          # a level excitement cannot decay below right now
var _hold := 0.0           # seconds _floor stays up
var _pin_peak := 0         # highest count shown in the current cover
var _was_pinning := false


## Hooks the match up. Called by match_setup once the wrestlers exist.
func watch(referee: MatchReferee, wrestlers: Array) -> void:
	_referee = referee
	for w: WrestlerController in wrestlers:
		w.move_landed.connect(_on_move_landed)
		w.fired_up.connect(func(_w): pop(POP_FIRED_UP))
		w.taunted.connect(func(_w): pop(POP_TAUNT))
	referee.match_won.connect(_on_match_won)


func _ready() -> void:
	add_to_group("crowd_reaction")
	_publish()


## Raise excitement to at least `amount` right now.
func pop(amount: float) -> void:
	excitement = maxf(excitement, clampf(amount, 0.0, 1.0))


## Phone flashes on (an entrance) or off (the bell).
func set_flashes(rate: float) -> void:
	flash_rate = maxf(rate, 0.0)


static func move_pop(move: MoveDef) -> float:
	if move == null:
		return 0.0
	if move.resource_path.get_file().begins_with("signature_"):
		return POP_SIGNATURE
	var total := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	return POP_MOVE_MAX * clampf((total - POP_DAMAGE_FLOOR)
			/ (POP_DAMAGE_FULL - POP_DAMAGE_FLOOR), 0.0, 1.0)


## Excitement after `dt` seconds of decay toward `floor_level`.
static func decayed(level: float, dt: float, floor_level := 0.0) -> float:
	var k := pow(0.5, dt / HALF_LIFE)
	return maxf(floor_level + (level - floor_level) * k, floor_level)


func _process(delta: float) -> void:
	_follow_the_cover()
	if _hold > 0.0:
		_hold -= delta
		if _hold <= 0.0:
			_floor = 0.0
	excitement = decayed(excitement, delta, _floor)
	_publish()


func _follow_the_cover() -> void:
	if _referee == null or not is_instance_valid(_referee):
		return
	var pinning: bool = _referee.get("_pinning")
	if pinning:
		_pin_peak = maxi(_pin_peak, _referee.pin_count())
		# Tension builds count by count, and holds through the cover.
		_floor = PIN_TENSION + PIN_PER_COUNT * _pin_peak
		_hold = 0.5
		pop(_floor)
	elif _was_pinning:
		# Out of the cover. If the match did not end on it and he got past
		# two, that was a near-fall.
		if _pin_peak >= 2 and _hold < WIN_HOLD * 0.5:
			pop(POP_NEAR_FALL)
		_pin_peak = 0
	_was_pinning = pinning


func _on_move_landed(_attacker, _defender, move: MoveDef) -> void:
	pop(move_pop(move))


func _on_match_won(_winner, _method) -> void:
	pop(1.0)
	_floor = 0.8
	_hold = WIN_HOLD


func _publish() -> void:
	RenderingServer.global_shader_parameter_set("crowd_excitement", excitement)
	RenderingServer.global_shader_parameter_set("crowd_flash_rate", flash_rate)
