class_name CrowdChants
extends Node
## When the building chants, and what. MatchAudio tells it what happens --
## who is landing what, a near-fall, a table going up, the bell -- and it
## decides, from that and the room's excitement, whether a chant starts.
##
## A real crowd chants seldom and for a reason: a man fighting back, a
## near-fall in a long match, a table, a stall. So every chant waits for its
## reason, at most one plays at a time, the room rests MIN_GAP seconds after
## one, and the same chant waits SAME_GAP before it is heard again. A reason
## that cannot be served in REASON_LIFE seconds is dropped, not queued: a
## "This is awesome" a minute after the near-fall is a bug.
##
## The chants are built by tools/audio/build_chants.py. Presentation only:
## nothing a match reads comes from here, and its picks are from its own
## seeded generator, never the match's.

## Each chant as it starts, for tests and probes.
signal chanted(chant: String)

const MIN_GAP := 22.0
const SAME_GAP := 110.0
const REASON_LIFE := 4.0
## What the room cannot let pass -- a near-fall, a table going up -- is not
## made to wait out the rest after the last chant (a gasp is not polite), and
## is still answered this long after.
const URGENT: Array[StringName] = [&"chant_this_is_awesome", &"chant_holy_shit", &"chant_tables"]
const URGENT_LIFE := 7.0
## A man "has the match" at this many landed moves inside MOMENTUM_WINDOW.
const MOMENTUM_MOVES := 3
const MOMENTUM_WINDOW := 9.0
## A stall: the room this flat for this long, past the match's opening
## minutes -- and once a match at most: a crowd bored twice is a bad match,
## and the match is not the crowd's to judge that often.
const STALL_EXCITEMENT := 0.12
const STALL_SECONDS := 40.0
const STALL_AFTER := 150.0
const BORING_MAX := 1
## A near-fall is worth "This is awesome" this far into a match (from the
## bell); before it, "Holy shit" at most.
const AWESOME_AFTER := 240.0
## The bell: "You deserve it" for the face at once, "One more match" after a
## long one.
const DESERVE_DELAY := 3.0
const ONE_MORE_DELAY := 17.0
const ONE_MORE_AFTER := 420.0
const CHANT_DB := -3.0
const COUNT_DB := -4.0
var clock := 0.0
## Kept as roster metadata for callers that want to distinguish the match;
## generated wrestler-specific chant files are intentionally never queued.
var cody_here := false
var roman_here := false
var sfx: SfxPool
var _player: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
var _since_end := MIN_GAP          # seconds since the last chant finished
var _last := {}                    # chant -> clock when it last started
var _reasons := {}                 # chant -> clock the reason arose
var _moves := {}                   # favour (-1, 1) -> [clock, ...]
var _flat := 0.0
var _after_bell := -1.0
## When the opening bell went (clock), or -1 before it: nothing but the
## entrances' own chants is sung before the match starts.
var _bell_at := -1.0
var _chant_end := -1.0
var _boring := 0
var _winner_favor := 0.0
var _entrance := ""
var _entrance_t := 0.0
var _entrance_done := {}


func _ready() -> void:
	_rng.seed = 0x0c0d7
	_player = AudioStreamPlayer.new()
	_player.name = "Chant"
	_player.bus = RingAnnouncer.under_bus()
	add_child(_player)


## The take of `chant` to play: one of chant_x_0, chant_x_1, ... or "".
func take_of(chant: String) -> String:
	var n := SfxPool.family_size(chant)
	if n == 0:
		return ""
	return "%s_%d" % [chant, _rng.randi_range(0, n - 1)]


## Whether a chant is still going: by its take's length from when it started
## (clock), not by asking the player -- the same answer in a recording, a
## test with no audio device, and the game.
func is_chanting() -> bool:
	return clock < _chant_end


# --- what happened --------------------------------------------------------

## A move landed by a man the house is for (+1), against (-1), or neither.
func moved(favor: float, pop: float) -> void:
	# Name chants in this build use generated voice assets. Keep reactions
	# event based and generic until clean, licensed recordings are selected.
	pass


## A man fired up on his comeback.
func fired_up(favor: float) -> void:
	pass


## The cover broken after `count` (2 is a near-fall).
func kicked_out(count: int) -> void:
	if count < 2:
		return
	_reason(&"chant_this_is_awesome" if match_time() >= AWESOME_AFTER else &"chant_holy_shit")


## A table stood up for somebody.
func table_set_up() -> void:
	_reason(&"chant_tables")


## The referee's hand coming down: the building counts with him.
func count(n: int, sfx: SfxPool) -> void:
	if n >= 1 and n <= 3:
		sfx.play_any("crowd_count_%d" % n, COUNT_DB, 0.02)


## The opening bell: the match, and its chants, start.
func bell() -> void:
	_bell_at = clock
	_reasons.clear()
	_flat = 0.0


## Seconds since the opening bell, or -1 before it.
func match_time() -> float:
	return clock - _bell_at if _bell_at >= 0.0 else -1.0


## The bell, and who it was for.
func match_over(winner_favor: float) -> void:
	_after_bell = 0.0
	_winner_favor = winner_favor
	# Whatever was going stops for the bell; the room starts over.
	_reasons.clear()


## An entrance started. Music and the crowd bed carry it without generated
## wrestler-specific chants.
func entrance(style: String) -> void:
	_entrance = style
	_entrance_t = 0.0
	_entrance_done.clear()


# --- deciding --------------------------------------------------------------

func _reason(chant: StringName) -> void:
	if not sung_here(String(chant)) or _bell_at < 0.0:
		return
	_reasons[chant] = clock


## Whether this match has the man `chant` is about (or it is about nobody).
## Kept for generic API compatibility; name chants are not scheduled.
func sung_here(chant: String) -> bool:
	if chant.contains("cody"):
		return cody_here
	if chant.contains("roman") or chant.contains("otc"):
		return roman_here
	return true


## What to chant now, of `reasons` (chant -> when it arose), or "" -- the
## whole rule, without the player, so it can be tested.
static func pick(reasons: Dictionary, last: Dictionary, now: float, since_end: float,
		chanting: bool) -> String:
	if chanting:
		return ""
	var best := ""
	var best_at := -INF
	for chant: StringName in reasons:
		var at: float = reasons[chant]
		var urgent := chant in URGENT
		if now - at > (URGENT_LIFE if urgent else REASON_LIFE):
			continue
		if since_end < MIN_GAP and not urgent:
			continue
		if last.has(chant) and now - float(last[chant]) < SAME_GAP:
			continue
		if SfxPool.family_size(String(chant)) == 0:
			continue
		# The freshest reason wins: the crowd answers what just happened.
		if at > best_at:
			best = String(chant)
			best_at = at
	return best


## One step of the room (MatchAudio drives it). `excitement` < 0 means "not
## known this frame".
func tick(delta: float, excitement: float) -> void:
	clock += delta
	if is_chanting():
		_since_end = 0.0
	else:
		_since_end += delta
	if excitement >= 0.0:
		_flat = _flat + delta if excitement < STALL_EXCITEMENT else 0.0
		if _flat >= STALL_SECONDS and match_time() >= STALL_AFTER and _after_bell < 0.0 \
				and _boring < BORING_MAX:
			_reason(&"chant_boring")
			_boring += 1
			_flat = 0.0
	if _after_bell >= 0.0:
		var was := _after_bell
		_after_bell += delta
		if _winner_favor > 0.0 and was < DESERVE_DELAY and _after_bell >= DESERVE_DELAY:
			_start("chant_you_deserve_it")
		# after "You deserve it" has had its say, never over it
		if match_time() >= ONE_MORE_AFTER and _after_bell >= ONE_MORE_DELAY \
				and not is_chanting() and not _last.has(&"chant_one_more_match"):
			_start("chant_one_more_match")
		return
	if _entrance != "":
		_tick_entrance(delta)
	for chant: StringName in _reasons.keys():
		if clock - float(_reasons[chant]) > (URGENT_LIFE if chant in URGENT else REASON_LIFE):
			_reasons.erase(chant)
	var chant := pick(_reasons, _last, clock, _since_end, is_chanting())
	if chant != "":
		_reasons.erase(StringName(chant))
		_start(chant)


func _tick_entrance(delta: float) -> void:
	_entrance_t += delta


func _start(chant: String) -> void:
	var take := take_of(chant)
	if take == "":
		return
	_player.stream = SfxPool.stream(take)
	_player.volume_db = CHANT_DB
	_player.play()
	_chant_end = clock + _player.stream.get_length()
	_since_end = 0.0
	_last[StringName(chant)] = clock
	chanted.emit(chant)
