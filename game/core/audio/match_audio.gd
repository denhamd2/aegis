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

## The crowd is five loops of different lengths (52 / 23 / 41 s, so no seam
## is ever heard twice together) riding one slewed intensity, plus a roar on
## the excitement and, by who is hurting whom, boos or a cheer. Levels in dB
## at intensity 0 and 1; nothing steps, every layer slews to its target.
const BED_DB := -9.0
const BED_EXCITED_DB := -3.0
const WALLA_A_DB := [-26.0, -9.0]
const WALLA_B_DB := [-32.0, -8.0]
const ROAR_MAX_DB := 0.0
## Below this the roar is off; it comes in on a curve so a jab does nothing.
const ROAR_FLOOR := 0.08
## How fast a layer's level closes on its target, per second.
const SLEW_RATE := 1.6
## The match builds: a quiet feeling-out, a room that has warmed by the
## PHASE_FULL second. Added under the excitement as a floor on the intensity.
const PHASE_FULL := 300.0
const PHASE_FLOOR_MAX := 0.32
## Boos and cheers die away by half every this many seconds.
const HEAT_HALF_LIFE := 4.5
const HEAT_ON_DB := -6.0
const HEAT_OFF_DB := -42.0

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
var _walla_a: AudioStreamPlayer
var _walla_b: AudioStreamPlayer
var _boo_loop: AudioStreamPlayer
var _cheer_loop: AudioStreamPlayer
var _roar: AudioStreamPlayer
## The slewed 0-1 driver of the beds, the match's clock, and the two heats.
var intensity := 0.0
var boo := 0.0
var cheer := 0.0
var _clock := 0.0
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
	_walla_a = sfx.make_loop("crowd_walla_a")
	_walla_b = sfx.make_loop("crowd_walla_b")
	_boo_loop = sfx.make_loop("crowd_boo")
	_cheer_loop = sfx.make_loop("crowd_cheer")
	_roar = sfx.make_loop("crowd_roar")
	_bed.volume_db = BED_DB
	# Out of step from the first frame: each layer starts somewhere else in
	# its own loop (deterministic -- SfxPool's seeded generator, not the match's).
	for p: AudioStreamPlayer in [_bed, _walla_a, _walla_b, _boo_loop, _cheer_loop, _roar]:
		var length: float = p.stream.get_length()
		p.seek(fposmod(length * float(hash(String(p.name)) % 1000) / 1000.0, length))


## Hooks the match up. Called by match_setup, beside CrowdReaction.watch().
func watch(referee: MatchReferee, wrestlers: Array, crowd: CrowdReaction) -> void:
	_referee = referee
	_crowd = crowd
	_wrestlers = wrestlers
	for w: WrestlerController in wrestlers:
		w.move_landed.connect(_on_move_landed)
		w.reversed.connect(func(_r, _s, _m): sfx.play("whoosh", -6.0))
		w.taunted.connect(func(who): _heat(who, 0.5); sfx.play_any("crowd_pop", -9.0))
		w.fired_up.connect(func(who): _heat(who, 0.7); sfx.play_any("crowd_pop", -6.0))
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


## Who the house is behind: -1 for the heel (Roman Reigns), +1 for the face
## (Cody Rhodes), 0 for anyone else. By name, the way the roster presents them.
static func favor_of(display_name: String) -> float:
	var n := display_name.to_upper()
	if n.contains("ROMAN") or n.contains("REIGNS"):
		return -1.0
	if n.contains("CODY") or n.contains("RHODES"):
		return 1.0
	return 0.0


## The match's warm-up as a floor under the intensity: 0 at the bell, full by
## PHASE_FULL seconds, on a curve that is slow to begin with.
static func phase_floor(clock: float) -> float:
	return PHASE_FLOOR_MAX * smoothstep(0.0, 1.0, clock / PHASE_FULL)


## Each loop's target level for an intensity (0-1), by layer name.
static func bed_levels(i: float) -> Dictionary:
	i = clampf(i, 0.0, 1.0)
	return {
		"bed": lerpf(BED_DB, BED_EXCITED_DB, i),
		"walla_a": lerpf(WALLA_A_DB[0], WALLA_A_DB[1], i),
		"walla_b": lerpf(WALLA_B_DB[0], WALLA_B_DB[1], i * i),
	}


## A heat (boos or a cheer, 0-1) as a level: off below a whisper.
static func heat_db(heat: float) -> float:
	if heat < 0.02:
		return -80.0
	return lerpf(HEAT_OFF_DB, HEAT_ON_DB, clampf(heat, 0.0, 1.0))


## The heat after `delta` more seconds with nothing feeding it.
static func cool(heat: float, delta: float) -> float:
	return heat * pow(0.5, delta / HEAT_HALF_LIFE)


## Boos for the heel's doing, a cheer for the face's.
func _heat(who: Variant, amount: float) -> void:
	if who == null or not (who is WrestlerController):
		return
	var f := favor_of((who as WrestlerController).display_name)
	if f < 0.0:
		boo = minf(boo + amount, 1.0)
	elif f > 0.0:
		cheer = minf(cheer + amount, 1.0)


func _on_move_landed(attacker, _defender, move: MoveDef) -> void:
	_heat(attacker, 0.12 + 0.5 * CrowdReaction.move_pop(move))
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
	if not _over:
		_clock += delta
	# The driver: the room's excitement over the match's warm-up, slewed so a
	# pop swells the beds and a lull lets them fall, never a step.
	var target := maxf(excitement, phase_floor(_clock))
	intensity = lerpf(intensity, target, 1.0 - exp(-delta * 1.2))
	boo = cool(boo, delta)
	cheer = cool(cheer, delta)
	var levels := bed_levels(intensity)
	_slew(_bed, levels["bed"], delta)
	_slew(_walla_a, levels["walla_a"], delta)
	_slew(_walla_b, levels["walla_b"], delta)
	_slew(_boo_loop, heat_db(boo), delta)
	_slew(_cheer_loop, heat_db(cheer), delta)
	if _roar:
		var level := clampf((excitement - ROAR_FLOOR) / (1.0 - ROAR_FLOOR), 0.0, 1.0)
		_roar.volume_db = ROAR_MAX_DB + linear_to_db(maxf(pow(level, 1.5), 0.0001))
	_hear_the_count()
	for w: WrestlerController in _wrestlers:
		if is_instance_valid(w):
			_hear_bumps(w, delta)


func _slew(p: AudioStreamPlayer, db: float, delta: float) -> void:
	if p:
		p.volume_db = lerpf(p.volume_db, db, 1.0 - exp(-delta * SLEW_RATE))


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
