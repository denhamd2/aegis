class_name MatchAudio
extends Node
## What the hall sounds like: the crowd, the bell, the hits, the referee's
## hand on the mat, the pyro. The entrance music is not here -- it is the
## audio track of each man's titantron video, which StageVideo plays.
##
## Presentation only, in the same way as CrowdReaction, and next to it: it
## listens to signals and reads state in _process, and writes nothing a match
## can read. Its sample picks come from SfxPool's own seeded generator, so a
## recording made under Movie Maker (fixed frame time) sounds the same twice.
##
## The mix is a broadcast mix, not a positional one: the crowd all round,
## hits and bumps up front, the way a TV feed carries ring mics.
##
## Sounds are built by tools/audio/build_sfx.py (CC0 sources, listed in
## assets/audio/CREDITS.md).

## The crowd bed never goes silent; the roar layer rides CrowdReaction's
## excitement on top of it.
const BED_DB := -5.0
const BED_EXCITED_DB := -1.0
const ROAR_MAX_DB := 0.0
## Below this the roar is off; it comes in on a curve so a jab does nothing.
const ROAR_FLOOR := 0.08

## A bump: the pelvis falling faster than this and then stopping, low.
const BUMP_FALL_SPEED := 2.0
const BUMP_FULL_SPEED := 5.5
const BUMP_STOP_SPEED := 0.6
## Pelvis height over the man's own feet when he has landed.
const BUMP_LOW := 0.6
const BUMP_COOLDOWN := 0.45
## How far back the fall is remembered while it lands, seconds.
const BUMP_WINDOW := 0.2

## Strikes by damage: a jab is quiet, a bionic elbow is not.
const HIT_DAMAGE_QUIET := 3.0
const HIT_DAMAGE_LOUD := 12.0

## A move worth a pop of its own (CrowdReaction.move_pop at or over this).
const POP_MOVE := 0.45

var sfx: SfxPool
var _bed: AudioStreamPlayer
var _roar: AudioStreamPlayer
var _crowd: CrowdReaction
var _referee: MatchReferee
var _wrestlers: Array = []
var _pelvis := {}        # wrestler -> bone index
var _last_y := {}        # wrestler -> pelvis height last frame
var _falls := {}         # wrestler -> Array of [age, vy] this window
var _cooldown := {}      # wrestler -> seconds until he can bump again
var _count_heard := 0
var _was_pinning := false
var _over := false


func _ready() -> void:
	sfx = SfxPool.new()
	sfx.name = "Sfx"
	add_child(sfx)
	_bed = sfx.make_loop("crowd_bed")
	_roar = sfx.make_loop("crowd_roar")
	_bed.volume_db = BED_DB


## Hooks the match up. Called by match_setup, beside CrowdReaction.watch().
func watch(referee: MatchReferee, wrestlers: Array, crowd: CrowdReaction) -> void:
	_referee = referee
	_crowd = crowd
	_wrestlers = wrestlers
	for w: WrestlerController in wrestlers:
		w.move_landed.connect(_on_move_landed)
		w.reversed.connect(func(_r, _s, _m): sfx.play("whoosh", -6.0))
		w.taunted.connect(func(_w): sfx.play_any("crowd_pop", -9.0))
		w.fired_up.connect(func(_w): sfx.play_any("crowd_pop", -6.0))
		_cooldown[w] = 0.0
		_falls[w] = []
	referee.match_won.connect(_on_match_won)


## The entrances' cues (EntranceDirector.cue): the pyro, and the crowd as a
## man's music hits.
func follow(director: EntranceDirector) -> void:
	director.cue.connect(_on_cue)


## The opening bell, whether after the entrances or on tick one.
func opening_bell() -> void:
	sfx.play("bell_start", -2.0)


func _on_cue(what: String) -> void:
	match what:
		"pyro_stage", "pyro_over_ring":
			sfx.play("pyro_boom", -1.0)
		"pyro_roman":
			# Flame units: the roar of the fire under the boom.
			sfx.play("pyro_boom", -2.0)
			sfx.play("whoosh", -4.0)
		"pyro_cody_hit", "pyro_cody_punch":
			sfx.play("pyro_bang", -2.0)
			sfx.play("pyro_boom", -8.0)
		"strobe":
			sfx.play("pyro_bang", -6.0)
		"tron_on":
			sfx.play_any("crowd_pop", -5.0)


## Which sound a landed move makes the moment it lands, if any. Strikes and
## stomps connect on this tick; slams and throws land later, when the body
## does, and the bump detector hears that instead.
static func hit_sound(move: MoveDef) -> String:
	if move == null:
		return ""
	var file := move.resource_path.get_file().get_basename()
	if file.contains("kick") or file.contains("stomp") or file.contains("knee"):
		return "hit_kick"
	if file.begins_with("strike_") or file.begins_with("ground_") \
			or file.contains("punch") or file.contains("elbow") \
			or file.contains("clothesline") or file.contains("lariat"):
		return "hit_punch"
	return ""


static func hit_volume(move: MoveDef) -> float:
	var total := move.damage_head + move.damage_torso + move.damage_arms + move.damage_legs
	var t := clampf((total - HIT_DAMAGE_QUIET) / (HIT_DAMAGE_LOUD - HIT_DAMAGE_QUIET), 0.0, 1.0)
	return lerpf(-9.0, 0.0, t)


## Loudness of a bump from how fast he was falling, or NAN for no bump.
static func bump_volume(fall_speed: float) -> float:
	if fall_speed < BUMP_FALL_SPEED:
		return NAN
	var t := clampf((fall_speed - BUMP_FALL_SPEED) / (BUMP_FULL_SPEED - BUMP_FALL_SPEED), 0.0, 1.0)
	return lerpf(-10.0, 0.0, t)


func _on_move_landed(_attacker, _defender, move: MoveDef) -> void:
	var sound := hit_sound(move)
	if sound != "":
		sfx.play_any(sound, hit_volume(move))
	var pop := CrowdReaction.move_pop(move)
	if pop >= POP_MOVE:
		sfx.play_any("crowd_pop", lerpf(-8.0, -2.0, clampf((pop - POP_MOVE) / (1.0 - POP_MOVE), 0.0, 1.0)))


func _on_match_won(_winner, method: String) -> void:
	_over = true
	# The three lands on the tick the match ends, before _process hears the
	# count: slap it here so the hand comes down before the bell, not after.
	if method == "pinfall" and _count_heard < 3:
		_count_heard = 3
		sfx.play_any("count_slap", -1.0)
	sfx.play("bell_end", -1.0)
	sfx.play("crowd_finish", 0.0)


func _process(delta: float) -> void:
	var excitement := _crowd.excitement if _crowd else 0.0
	if _bed:
		_bed.volume_db = lerpf(BED_DB, BED_EXCITED_DB, excitement)
	if _roar:
		var level := clampf((excitement - ROAR_FLOOR) / (1.0 - ROAR_FLOOR), 0.0, 1.0)
		_roar.volume_db = ROAR_MAX_DB + linear_to_db(maxf(pow(level, 1.5), 0.0001))
	_hear_the_count()
	for w: WrestlerController in _wrestlers:
		if is_instance_valid(w):
			_hear_bumps(w, delta)


func _hear_the_count() -> void:
	if _referee == null or not is_instance_valid(_referee):
		return
	var pinning := _referee.is_pin_active()
	if pinning and not _was_pinning:
		_count_heard = 0
	# Read whether or not the cover is still on: the three and the end of
	# the pin land on the same tick, and the count is held up after it.
	var count := _referee.pin_count()
	if count > _count_heard:
		_count_heard = count
		sfx.play_any("count_slap", -1.0)
	if not pinning and _was_pinning and _count_heard >= 2 and not _over:
		# A kickout after two: the gasp. (A three is the bell, not this.)
		sfx.play_any("crowd_ooh", -3.0)
		sfx.play_any("crowd_pop", -4.0)
	_was_pinning = pinning


func _hear_bumps(w: WrestlerController, delta: float) -> void:
	if delta <= 0.0 or w.skeleton == null:
		return
	if not _pelvis.has(w):
		_pelvis[w] = w.skeleton.find_bone(w._skeleton_bone_name("pelvis"))
	var bone: int = _pelvis[w]
	if bone < 0:
		return
	var y := (w.skeleton.global_transform * w.skeleton.get_bone_global_pose(bone).origin).y
	_cooldown[w] = maxf(0.0, float(_cooldown[w]) - delta)
	if not _last_y.has(w):
		_last_y[w] = y
		return
	var vy := (y - float(_last_y[w])) / delta
	_last_y[w] = y
	var falls: Array = _falls[w]
	for f: Array in falls:
		f[0] += delta
	while not falls.is_empty() and float(falls[0][0]) > BUMP_WINDOW:
		falls.pop_front()
	falls.append([0.0, vy])
	if _cooldown[w] > 0.0 or vy < -BUMP_STOP_SPEED:
		return
	if y - w.global_position.y > BUMP_LOW:
		return
	var fastest := 0.0
	for f: Array in falls:
		fastest = maxf(fastest, -float(f[1]))
	var db := bump_volume(fastest)
	if is_nan(db):
		return
	sfx.play_any("bump", db, 0.06)
	_cooldown[w] = BUMP_COOLDOWN
	falls.clear()
